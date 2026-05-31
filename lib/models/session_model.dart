import 'package:cloud_firestore/cloud_firestore.dart';

class SessionModel {
  final String id;
  final String code;
  final String hostId;
  final String hostName;
  final DateTime createdAt;
  final bool isActive;
  final List<SessionParticipant> participants;
  final Map<String, dynamic>? sessionData; // Additional data for your app

  SessionModel({
    required this.id,
    required this.code,
    required this.hostId,
    required this.hostName,
    required this.createdAt,
    required this.isActive,
    this.participants = const [],
    this.sessionData,
  });

  factory SessionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SessionModel(
      id: doc.id,
      code: data['code'] ?? '',
      hostId: data['hostId'] ?? '',
      hostName: data['hostName'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? false,
      participants: (data['participants'] as List?)
              ?.map((p) => SessionParticipant.fromMap(p))
              .toList() ??
          [],
      sessionData: data['sessionData'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'code': code,
      'hostId': hostId,
      'hostName': hostName,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
      'participants': participants.map((p) => p.toMap()).toList(),
      'sessionData': sessionData,
    };
  }

  SessionModel copyWith({
    String? id,
    String? code,
    String? hostId,
    String? hostName,
    DateTime? createdAt,
    bool? isActive,
    List<SessionParticipant>? participants,
    Map<String, dynamic>? sessionData,
  }) {
    return SessionModel(
      id: id ?? this.id,
      code: code ?? this.code,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      participants: participants ?? this.participants,
      sessionData: sessionData ?? this.sessionData,
    );
  }
}

class SessionParticipant {
  final String id;
  final String name;
  final DateTime joinedAt;

  SessionParticipant({
    required this.id,
    required this.name,
    required this.joinedAt,
  });

  factory SessionParticipant.fromMap(Map<String, dynamic> map) {
    return SessionParticipant(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      joinedAt: (map['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'joinedAt': Timestamp.fromDate(joinedAt),
    };
  }
}