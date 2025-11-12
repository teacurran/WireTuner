import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

/// Client for connecting to the WireTuner Collaboration Gateway.
///
/// Provides WebSocket-based real-time collaboration with:
/// - Operation submission and acknowledgment
/// - Cursor and selection presence
/// - User join/leave notifications
/// - Automatic reconnection
/// - OT state management
///
/// **Usage:**
/// ```dart
/// final client = CollaborationClient(
///   serverUrl: 'ws://localhost:8080',
///   authToken: 'jwt_token_here',
/// );
///
/// await client.connect(documentId: 'doc123');
///
/// // Submit operations
/// client.submitOperation(operation);
///
/// // Listen for remote operations
/// client.operationStream.listen((op) {
///   // Apply remote operation to local state
/// });
/// ```
class CollaborationClient {
  final String serverUrl;
  final String authToken;
  final Duration reconnectDelay;
  final Duration heartbeatInterval;

  WebSocketChannel? _channel;
  String? _documentId;
  String? _sessionId;
  bool _isConnected = false;
  int _localSequence = 0;
  int _serverSequence = 0;

  final StreamController<Map<String, dynamic>> _operationController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _cursorController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _selectionController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<UserPresenceUpdate> _presenceController =
      StreamController<UserPresenceUpdate>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  CollaborationClient({
    required this.serverUrl,
    required this.authToken,
    this.reconnectDelay = const Duration(seconds: 5),
    this.heartbeatInterval = const Duration(seconds: 30),
  });

  /// Stream of operations broadcast from the server.
  Stream<Map<String, dynamic>> get operationStream => _operationController.stream;

  /// Stream of cursor updates from other users.
  Stream<Map<String, dynamic>> get cursorStream => _cursorController.stream;

  /// Stream of selection updates from other users.
  Stream<Map<String, dynamic>> get selectionStream => _selectionController.stream;

  /// Stream of user presence updates (join/leave).
  Stream<UserPresenceUpdate> get presenceStream => _presenceController.stream;

  /// Stream of error messages.
  Stream<String> get errorStream => _errorController.stream;

  /// Whether the client is currently connected.
  bool get isConnected => _isConnected;

  /// Current session ID.
  String? get sessionId => _sessionId;

  /// Current local operation sequence number.
  int get localSequence => _localSequence;

  /// Last acknowledged server sequence number.
  int get serverSequence => _serverSequence;

  /// Connects to the collaboration gateway for a specific document.
  Future<void> connect({required String documentId}) async {
    if (_isConnected) {
      throw StateError('Already connected');
    }

    _documentId = documentId;

    try {
      final uri = Uri.parse('$serverUrl/ws')
          .replace(queryParameters: {'documentId': documentId});

      _channel = WebSocketChannel.connect(
        uri,
        protocols: ['Bearer', authToken],
      );

      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );

      _isConnected = true;
      _startHeartbeat();

      print('Connected to collaboration gateway: $documentId');
    } catch (e) {
      print('Failed to connect: $e');
      _errorController.add('Connection failed: $e');
      _scheduleReconnect();
    }
  }

  /// Disconnects from the collaboration gateway.
  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();

    if (_channel != null) {
      await _channel!.sink.close(status.normalClosure);
      _channel = null;
    }

    _isConnected = false;
    _sessionId = null;
    print('Disconnected from collaboration gateway');
  }

  /// Submits an operation to the server.
  void submitOperation(Map<String, dynamic> operation) {
    if (!_isConnected) {
      throw StateError('Not connected');
    }

    _localSequence++;

    final message = {
      'type': 'operationSubmit',
      'operation': operation,
      'localSequence': _localSequence,
      'serverSequence': _serverSequence,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    _send(message);
  }

  /// Updates cursor position for presence.
  void updateCursor({required double x, required double y}) {
    if (!_isConnected) return;

    _send({
      'type': 'cursorUpdate',
      'cursor': {'x': x, 'y': y},
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Updates selection for presence.
  void updateSelection(List<String> selectedIds) {
    if (!_isConnected) return;

    _send({
      'type': 'selectionUpdate',
      'selection': selectedIds,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Sends a presence beacon to indicate activity.
  void sendPresenceBeacon() {
    if (!_isConnected) return;

    _send({
      'type': 'presenceBeacon',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Internal: Sends a message through the WebSocket.
  void _send(Map<String, dynamic> message) {
    if (_channel == null) return;

    try {
      _channel!.sink.add(jsonEncode(message));
    } catch (e) {
      print('Failed to send message: $e');
      _errorController.add('Send failed: $e');
    }
  }

  /// Internal: Handles incoming WebSocket messages.
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final messageType = data['type'] as String?;

      if (messageType == null) return;

      switch (messageType) {
        case 'operationBroadcast':
          _handleOperationBroadcast(data);
          break;

        case 'operationAck':
          _handleOperationAck(data);
          break;

        case 'cursorUpdate':
          _cursorController.add(data);
          break;

        case 'selectionUpdate':
          _selectionController.add(data);
          break;

        case 'userJoined':
          _presenceController.add(UserPresenceUpdate(
            userId: data['userId'] as String,
            sessionId: data['sessionId'] as String,
            type: PresenceUpdateType.joined,
          ));
          break;

        case 'userLeft':
          _presenceController.add(UserPresenceUpdate(
            userId: data['userId'] as String? ?? '',
            sessionId: data['sessionId'] as String,
            type: PresenceUpdateType.left,
          ));
          break;

        case 'presenceSnapshot':
          final users = data['users'] as List<dynamic>?;
          if (users != null) {
            for (final user in users) {
              _presenceController.add(UserPresenceUpdate(
                userId: user['userId'] as String,
                sessionId: user['sessionId'] as String,
                type: PresenceUpdateType.snapshot,
              ));
            }
          }
          break;

        case 'error':
          final error = data['error'] as String? ?? 'Unknown error';
          _errorController.add(error);
          print('Server error: $error');
          break;

        case 'heartbeat':
          // Server responded to heartbeat
          break;

        case 'resyncRequest':
          _handleResyncRequest(data);
          break;

        case 'rateLimit':
          _errorController.add('Rate limit exceeded');
          print('Warning: Rate limit exceeded');
          break;

        default:
          print('Unknown message type: $messageType');
      }
    } catch (e) {
      print('Error handling message: $e');
    }
  }

  /// Internal: Handles operation broadcast from server.
  void _handleOperationBroadcast(Map<String, dynamic> data) {
    final operation = data['operation'] as Map<String, dynamic>?;
    final serverSeq = data['serverSequence'] as int?;

    if (operation != null && serverSeq != null) {
      _serverSequence = serverSeq;
      _operationController.add(operation);
    }
  }

  /// Internal: Handles operation acknowledgment from server.
  void _handleOperationAck(Map<String, dynamic> data) {
    final serverSeq = data['serverSequence'] as int?;
    if (serverSeq != null) {
      _serverSequence = serverSeq;
      print('Operation acknowledged: serverSeq=$serverSeq');
    }
  }

  /// Internal: Handles resync request from server.
  void _handleResyncRequest(Map<String, dynamic> data) {
    // Server detected a sequence gap, need to resync
    print('Resync requested by server');
    _errorController.add('Resync required - reconnecting');

    // Trigger reconnection to get fresh state
    disconnect().then((_) {
      if (_documentId != null) {
        connect(documentId: _documentId!);
      }
    });
  }

  /// Internal: Handles WebSocket errors.
  void _handleError(error) {
    print('WebSocket error: $error');
    _errorController.add('WebSocket error: $error');
  }

  /// Internal: Handles WebSocket disconnection.
  void _handleDisconnect() {
    print('WebSocket disconnected');
    _isConnected = false;
    _heartbeatTimer?.cancel();

    _scheduleReconnect();
  }

  /// Internal: Schedules automatic reconnection.
  void _scheduleReconnect() {
    if (_reconnectTimer != null) return;

    print('Scheduling reconnect in ${reconnectDelay.inSeconds}s');
    _reconnectTimer = Timer(reconnectDelay, () {
      _reconnectTimer = null;
      if (!_isConnected && _documentId != null) {
        print('Attempting to reconnect...');
        connect(documentId: _documentId!);
      }
    });
  }

  /// Internal: Starts periodic heartbeat.
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (timer) {
      if (_isConnected) {
        _send({
          'type': 'heartbeat',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }
    });
  }

  /// Disposes of resources.
  void dispose() {
    disconnect();
    _operationController.close();
    _cursorController.close();
    _selectionController.close();
    _presenceController.close();
    _errorController.close();
  }
}

/// Type of presence update.
enum PresenceUpdateType {
  joined,
  left,
  snapshot,
}

/// Represents a user presence update event.
class UserPresenceUpdate {
  final String userId;
  final String sessionId;
  final PresenceUpdateType type;

  UserPresenceUpdate({
    required this.userId,
    required this.sessionId,
    required this.type,
  });
}
