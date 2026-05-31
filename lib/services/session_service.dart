import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/session_model.dart';

class SessionService {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Uuid _uuid = const Uuid();

  StreamSubscription<DocumentSnapshot>? _sessionSubscription;
  SessionModel? _currentSession;
  bool _isHost = false;
  String? _currentUserId;
  String? _currentUserName;

  // Getters
  SessionModel? get currentSession => _currentSession;
  bool get isHost => _isHost;
  bool get isInSession => _currentSession != null;
  String? get currentUserId => _currentUserId;

  /// Initialize service and sign in anonymously
  Future<void> initialize() async {
    if (_auth.currentUser == null) {
      final userCredential = await _auth.signInAnonymously();
      _currentUserId = userCredential.user!.uid;
      _currentUserName = 'User${_currentUserId!.substring(0, 6)}';
    } else {
      _currentUserId = _auth.currentUser!.uid;
      _currentUserName = 'User${_currentUserId!.substring(0, 6)}';
    }
    
    // FOR TESTING: Add random suffix to make different tabs unique
    _currentUserId = '${_currentUserId}_${DateTime.now().millisecondsSinceEpoch}';
    _currentUserName = '${_currentUserName}_${Random().nextInt(1000)}';
  }

  /// Generate a unique 6-character session code
  String _generateSessionCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random random = Random();
    return String.fromCharCodes(Iterable.generate(
        6, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  /// Host a new session
  Future<SessionModel> hostSession({Map<String, dynamic>? sessionData}) async {
    await initialize();
    
    // End current session if hosting
    if (_currentSession != null && _isHost) {
      await endSession();
    }

    String code;
    bool isUnique = false;
    
    // Ensure code is unique
    do {
      code = _generateSessionCode();
      final existing = await _firestore
          .collection('sessions')
          .where('code', isEqualTo: code)
          .where('isActive', isEqualTo: true)
          .get();
      isUnique = existing.docs.isEmpty;
    } while (!isUnique);

    final sessionId = _uuid.v4();
    final session = SessionModel(
      id: sessionId,
      code: code,
      hostId: _currentUserId!,
      hostName: _currentUserName!,
      createdAt: DateTime.now(),
      isActive: true,
      participants: [
        SessionParticipant(
          id: _currentUserId!,
          name: _currentUserName!,
          joinedAt: DateTime.now(),
        )
      ],
      sessionData: sessionData,
    );

    // Create session in Firestore
    await _firestore
        .collection('sessions')
        .doc(sessionId)
        .set(session.toFirestore());

    _currentSession = session;
    _isHost = true;

    // Listen for session changes
    _startSessionListener(sessionId);

    return session;
  }

  /// Join an existing session
  Future<SessionModel> joinSession(String code) async {
    await initialize();
    
    // Leave current session if in one
    if (_currentSession != null) {
      await leaveSession();
    }

    // Find session by code
    final querySnapshot = await _firestore
        .collection('sessions')
        .where('code', isEqualTo: code.toUpperCase())
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception('Session not found or inactive');
    }

    final sessionDoc = querySnapshot.docs.first;
    final session = SessionModel.fromFirestore(sessionDoc);

    // Add participant to session
    final newParticipant = SessionParticipant(
      id: _currentUserId!,
      name: _currentUserName!,
      joinedAt: DateTime.now(),
    );

    final updatedParticipants = [
      ...session.participants.where((p) => p.id != _currentUserId),
      newParticipant,
    ];

    await _firestore.collection('sessions').doc(session.id).update({
      'participants': updatedParticipants.map((p) => p.toMap()).toList(),
    });

    _currentSession = session.copyWith(participants: updatedParticipants);
    _isHost = false;

    // Listen for session changes
    _startSessionListener(session.id);

    return _currentSession!;
  }

  /// Leave current session (as participant)
  Future<void> leaveSession() async {
    if (_currentSession == null || _isHost) return;

    final updatedParticipants = _currentSession!.participants
        .where((p) => p.id != _currentUserId)
        .toList();

    await _firestore.collection('sessions').doc(_currentSession!.id).update({
      'participants': updatedParticipants.map((p) => p.toMap()).toList(),
    });

    _stopSessionListener();
    _currentSession = null;
    _isHost = false;
  }

  /// End session (host only)
  Future<void> endSession() async {
    if (_currentSession == null || !_isHost) return;

    // Mark session as inactive
    await _firestore.collection('sessions').doc(_currentSession!.id).update({
      'isActive': false,
    });

    _stopSessionListener();
    _currentSession = null;
    _isHost = false;
  }

  /// Update session data
  Future<void> updateSessionData(Map<String, dynamic> data) async {
    if (_currentSession == null || !_isHost) return;

    await _firestore.collection('sessions').doc(_currentSession!.id).update({
      'sessionData': data,
    });
  }

  /// Start listening for session changes
  void _startSessionListener(String sessionId) {
    _sessionSubscription?.cancel();
    _sessionSubscription = _firestore
        .collection('sessions')
        .doc(sessionId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) {
        // Session was deleted
        _currentSession = null;
        _isHost = false;
        return;
      }

      final updatedSession = SessionModel.fromFirestore(snapshot);
      
      // If session becomes inactive, leave
      if (!updatedSession.isActive) {
        _currentSession = null;
        _isHost = false;
        return;
      }

      _currentSession = updatedSession;
    });
  }

  /// Stop listening for session changes
  void _stopSessionListener() {
    _sessionSubscription?.cancel();
    _sessionSubscription = null;
  }

  /// Get session stream for real-time updates
  Stream<SessionModel?> getSessionStream() {
    if (_currentSession == null) {
      return Stream.value(null);
    }

    return _firestore
        .collection('sessions')
        .doc(_currentSession!.id)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      
      final session = SessionModel.fromFirestore(snapshot);
      return session.isActive ? session : null;
    });
  }

  /// Cleanup - call when app is closed
  void dispose() {
    _stopSessionListener();
    if (_isHost && _currentSession != null) {
      endSession();
    } else if (_currentSession != null) {
      leaveSession();
    }
  }
}