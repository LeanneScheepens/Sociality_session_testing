import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/session_model.dart';
import '../services/session_service.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  final SessionService _sessionService = SessionService();
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    try {
      await _sessionService.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      _showError('Failed to initialize: $e');
    }
  }

  void _showError(String message) {
    setState(() => _error = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Future<void> _hostSession() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final session = await _sessionService.hostSession();
      _showSuccess('Session created with code: ${session.code}');
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SessionViewScreen(session: session),
          ),
        );
      }
    } catch (e) {
      _showError('Failed to host session: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _joinSession() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _showError('Please enter a session code');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final session = await _sessionService.joinSession(code);
      _showSuccess('Joined session: ${session.code}');
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SessionViewScreen(session: session),
          ),
        );
      }
    } catch (e) {
      _showError('Failed to join session: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Manager'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.group,
              size: 80,
              color: Colors.deepPurple,
            ),
            const SizedBox(height: 32),
            
            // Host Session Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _hostSession,
              icon: const Icon(Icons.add),
              label: const Text('Host New Session'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Divider
            const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('OR'),
                ),
                Expanded(child: Divider()),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Join Session Input
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'Session Code',
                hintText: 'Enter 6-character code',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.password),
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              onSubmitted: (_) => _joinSession(),
            ),
            
            const SizedBox(height: 16),
            
            // Join Session Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _joinSession,
              icon: const Icon(Icons.login),
              label: const Text('Join Session'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            
            if (_isLoading) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
            
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }
}

class SessionViewScreen extends StatefulWidget {
  final SessionModel session;

  const SessionViewScreen({super.key, required this.session});

  @override
  State<SessionViewScreen> createState() => _SessionViewScreenState();
}

class _SessionViewScreenState extends State<SessionViewScreen> {
  final SessionService _sessionService = SessionService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Session: ${widget.session.code}'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_sessionService.isHost)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _endSession,
              tooltip: 'End Session',
            )
          else
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              onPressed: _leaveSession,
              tooltip: 'Leave Session',
            ),
        ],
      ),
      body: StreamBuilder<SessionModel?>(
        stream: _sessionService.getSessionStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          final session = snapshot.data;
          if (session == null || !session.isActive) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            });
            return const Center(
              child: Text('Session ended'),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Session Info Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.key, color: Colors.deepPurple),
                            const SizedBox(width: 8),
                            Text(
                              'Code: ${session.code}',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.copy),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: session.code));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Code copied!')),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Host: ${session.hostName}'),
                        Text('Created: ${_formatDateTime(session.createdAt)}'),
                        if (_sessionService.isHost)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'You are the host',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Host Section
                Text(
                  '👑 Session Host',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 3,
                  color: Colors.orange.shade50,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange,
                      child: const Icon(Icons.star, color: Colors.white, size: 24),
                    ),
                    title: Row(
                      children: [
                        Text(
                          session.hostName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (session.hostId == _sessionService.currentUserId) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'YOU',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Created session: ${_formatDateTime(session.createdAt)}'),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.circle, color: Colors.green, size: 8),
                            const SizedBox(width: 4),
                            const Text('Online', style: TextStyle(color: Colors.green)),
                          ],
                        ),
                      ],
                    ),
                    trailing: Icon(
                      Icons.admin_panel_settings,
                      color: Colors.orange.shade700,
                      size: 28,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Other Participants Section
                Row(
                  children: [
                    Text(
                      '👥 Participants',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${session.participants.length} total', // Show all participants
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // DEBUG: Show all participants including host
                Expanded(
                  child: session.participants.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_add_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No participants yet...',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          // Debug info
                          Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('🔍 Debug Info:', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text('Total participants: ${session.participants.length}'),
                                Text('Session code: ${session.code}'),
                                Text('Host ID: ${session.hostId}'),
                                Text('Your ID: ${_sessionService.currentUserId}'),
                                Text('Are you host: ${_sessionService.isHost}'),
                                Text('Participant IDs: ${session.participants.map((p) => p.id.substring(0, 8)).join(", ")}'),
                              ],
                            ),
                          ),
                          
                          // Show ALL participants 
                          Expanded(
                            child: ListView.builder(
                              itemCount: session.participants.length,
                              itemBuilder: (context, index) {
                                final participant = session.participants[index];
                                final isCurrentUser = participant.id == _sessionService.currentUserId;
                                final isHost = participant.id == session.hostId;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  elevation: 2,
                                  color: isHost 
                                      ? Colors.orange.shade50 
                                      : isCurrentUser 
                                          ? Colors.blue.shade50 
                                          : null,
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isHost 
                                          ? Colors.orange 
                                          : isCurrentUser 
                                              ? Colors.blue 
                                              : Colors.grey.shade600,
                                      child: Icon(
                                        isHost ? Icons.star : Icons.person,
                                        color: Colors.white,
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Text(
                                          participant.name,
                                          style: TextStyle(
                                            fontWeight: isCurrentUser || isHost ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                        if (isCurrentUser) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.blue,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Text(
                                              'YOU',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                        if (isHost) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.orange,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Text(
                                              'HOST',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Joined: ${_formatDateTime(participant.joinedAt)}'),
                                        Text('ID: ${participant.id.substring(0, 12)}...'),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.circle, color: Colors.green, size: 8),
                                            const SizedBox(width: 4),
                                            const Text('Online', style: TextStyle(color: Colors.green)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _endSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Session'),
        content: const Text('Are you sure you want to end this session? All participants will be disconnected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('End Session'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _sessionService.endSession();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  Future<void> _leaveSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Session'),
        content: const Text('Are you sure you want to leave this session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _sessionService.leaveSession();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }
}