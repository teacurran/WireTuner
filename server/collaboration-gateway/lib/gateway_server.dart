import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import 'models/session.dart';
import 'middleware/auth_middleware.dart';
import 'infra/redis_channel.dart';
import 'ot/operation_types.dart';
import 'ot/transformers.dart';

/// Main collaboration gateway server managing WebSocket connections and OT operations.
///
/// Handles:
/// - WebSocket connection lifecycle
/// - JWT authentication
/// - Operation transformation and broadcasting
/// - Session management
/// - Redis pub/sub integration
/// - Idle timeout enforcement
class CollaborationGateway {
  final AuthMiddleware authMiddleware;
  final RedisChannel redisChannel;
  final Logger logger;
  final Map<String, CollaborationRoom> rooms;
  final Uuid uuid;
  final Duration idleTimeout;
  final int maxOperationsPerMinute;

  Timer? _idleCheckTimer;

  CollaborationGateway({
    required this.authMiddleware,
    required this.redisChannel,
    Logger? logger,
    this.idleTimeout = const Duration(minutes: 5),
    this.maxOperationsPerMinute = 300,
  })  : logger = logger ?? Logger(),
        rooms = {},
        uuid = const Uuid();

  /// Starts the gateway server.
  Future<void> start() async {
    await redisChannel.connect();
    _startIdleCheckTimer();
    logger.i('Collaboration Gateway started');
  }

  /// Stops the gateway server.
  Future<void> stop() async {
    _idleCheckTimer?.cancel();
    await redisChannel.disconnect();

    // Close all active sessions
    for (final room in rooms.values) {
      for (final session in room.sessions.values) {
        session.close(1001, 'Server shutting down');
      }
    }
    rooms.clear();

    logger.i('Collaboration Gateway stopped');
  }

  /// Creates a WebSocket handler for Shelf.
  Handler createWebSocketHandler() {
    return webSocketHandler((WebSocketChannel channel) {
      logger.d('New WebSocket connection attempt');
      // Note: Authentication happens in the HTTP upgrade request
      // We'll handle it in the outer handler
    });
  }

  /// Creates the main HTTP handler with authentication.
  Handler createHandler() {
    return (Request request) async {
      // Handle WebSocket upgrade requests
      if (WebSocketTransformer.isUpgradeRequest(request.context['shelf.io.connection'] as HttpConnectionInfo?)) {
        // Validate authentication
        final httpRequest = request.context['shelf.io.connection'] as HttpRequest?;
        if (httpRequest == null) {
          return Response.forbidden('Invalid request');
        }

        final authPayload = authMiddleware.validateWebSocketRequest(httpRequest);
        if (authPayload == null) {
          logger.w('WebSocket connection rejected: Invalid authentication');
          return Response.forbidden('Authentication required');
        }

        final userId = authMiddleware.extractUserId(authPayload);
        if (userId == null) {
          return Response.forbidden('Invalid user ID');
        }

        // Extract document ID from query params
        final documentId = request.url.queryParameters['documentId'];
        if (documentId == null) {
          return Response.badRequest(body: 'Missing documentId parameter');
        }

        // Create WebSocket handler
        return _handleWebSocketConnection(userId, documentId, authPayload);
      }

      // Handle HTTP health check
      if (request.url.path == 'health') {
        return Response.ok(jsonEncode({
          'status': 'healthy',
          'rooms': rooms.length,
          'sessions': rooms.values.fold(0, (sum, room) => sum + room.activeEditorCount),
        }));
      }

      return Response.notFound('Not found');
    };
  }

  /// Handles a WebSocket connection for a specific user and document.
  FutureOr<Response> _handleWebSocketConnection(
    String userId,
    String documentId,
    Map<String, dynamic> authPayload,
  ) {
    return webSocketHandler((WebSocketChannel channel) {
      final sessionId = uuid.v4();
      logger.i('WebSocket connected: user=$userId, doc=$documentId, session=$sessionId');

      // Get or create room
      final room = rooms.putIfAbsent(
        documentId,
        () => CollaborationRoom(documentId: documentId),
      );

      // Check capacity
      if (room.isAtCapacity) {
        logger.w('Room at capacity for document $documentId');
        channel.sink.add(jsonEncode({
          'type': 'error',
          'error': 'Document at capacity',
          'reason': 'Maximum ${room.maxConcurrentEditors} concurrent editors reached',
        }));
        channel.sink.close(1008, 'Room at capacity');
        return;
      }

      // Create session
      final session = CollaborationSession(
        sessionId: sessionId,
        userId: userId,
        documentId: documentId,
        channel: channel,
        connectedAt: DateTime.now(),
        otState: const OTState(localSequence: 0, serverSequence: 0),
      );

      room.addSession(session);

      // Subscribe to Redis for cross-instance sync
      final redisSubscription = redisChannel
          .subscribeToDocument(documentId)
          .listen((operation) {
        _handleRedisOperation(documentId, operation);
      });

      // Notify other users
      room.broadcast(
        {
          'type': 'userJoined',
          'userId': userId,
          'sessionId': sessionId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
        excludeSessionId: sessionId,
      );

      // Send current presence to new user
      session.send({
        'type': 'presenceSnapshot',
        'users': room.getUserPresences().map((p) => p.toJson()).toList(),
      });

      // Handle incoming messages
      channel.stream.listen(
        (message) {
          session.updateActivity();
          _handleWebSocketMessage(sessionId, documentId, message);
        },
        onError: (error) {
          logger.e('WebSocket error for session $sessionId: $error');
        },
        onDone: () {
          logger.i('WebSocket closed: session=$sessionId');
          _handleSessionClose(documentId, sessionId);
          redisSubscription.cancel();
        },
      );
    })(Request.get(Uri.parse('ws://localhost')));
  }

  /// Handles an incoming WebSocket message from a client.
  void _handleWebSocketMessage(
    String sessionId,
    String documentId,
    dynamic message,
  ) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final messageType = data['type'] as String?;

      if (messageType == null) {
        logger.w('Message missing type field');
        return;
      }

      final room = rooms[documentId];
      if (room == null) {
        logger.w('Room not found for document $documentId');
        return;
      }

      final session = room.getSession(sessionId);
      if (session == null) {
        logger.w('Session not found: $sessionId');
        return;
      }

      switch (messageType) {
        case 'operationSubmit':
          _handleOperationSubmit(room, session, data);
          break;

        case 'cursorUpdate':
          _handleCursorUpdate(room, session, data);
          break;

        case 'selectionUpdate':
          _handleSelectionUpdate(room, session, data);
          break;

        case 'presenceBeacon':
          session.updateActivity();
          break;

        case 'heartbeat':
          session.send({
            'type': 'heartbeat',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
          break;

        default:
          logger.w('Unknown message type: $messageType');
      }
    } catch (e) {
      logger.e('Error handling WebSocket message: $e');
    }
  }

  /// Handles an operation submission from a client.
  void _handleOperationSubmit(
    CollaborationRoom room,
    CollaborationSession session,
    Map<String, dynamic> data,
  ) {
    try {
      final operationData = data['operation'] as Map<String, dynamic>?;
      if (operationData == null) {
        logger.w('Operation data missing');
        return;
      }

      // Parse the operation
      final operation = OTOperation.fromJson(operationData);

      // Transform against concurrent operations
      // Get all operations since client's last acknowledged server sequence
      final concurrentOps = room.getOperationsSince(session.otState.serverSequence);
      var transformedOp = operation;

      for (final concurrentOp in concurrentOps) {
        transformedOp = transform(transformedOp, concurrentOp);
      }

      // Add to room history and get server sequence
      final serverSequence = room.addOperation(transformedOp);

      // Update session OT state
      session.otState = session.otState.copyWith(
        serverSequence: serverSequence,
      );

      // Broadcast to all clients (including sender)
      final broadcastMessage = {
        'type': 'operationBroadcast',
        'operation': transformedOp.toJson(),
        'serverSequence': serverSequence,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      room.broadcastToAll(broadcastMessage);

      // Publish to Redis for cross-instance sync
      redisChannel.publishOperation(room.documentId, broadcastMessage);

      // Send acknowledgment to sender
      session.send({
        'type': 'operationAck',
        'operationId': operation.when(
          insert: (id, _, __, ___, ____, _____, ______, _______, ________) => id,
          delete: (id, _, __, ___, ____, _____, ______) => id,
          move: (id, _, __, ___, ____, _____, ______, _______, ________) => id,
          modify: (id, _, __, ___, ____, _____, ______, _______, ________) => id,
          transform: (id, _, __, ___, ____, _____, ______, _______) => id,
          modifyAnchor: (id, _, __, ___, ____, _____, ______, _______, ________) => id,
          noOp: (id, _, __, ___, ____, _____, ______) => id,
        ),
        'serverSequence': serverSequence,
      });

      logger.d('Operation processed: serverSeq=$serverSequence');
    } catch (e) {
      logger.e('Error handling operation submit: $e');
      session.send({
        'type': 'error',
        'error': 'Failed to process operation',
        'reason': e.toString(),
      });
    }
  }

  /// Handles a cursor update from a client.
  void _handleCursorUpdate(
    CollaborationRoom room,
    CollaborationSession session,
    Map<String, dynamic> data,
  ) {
    final cursor = data['cursor'] as Map<String, dynamic>?;
    if (cursor == null) return;

    // Broadcast to other clients
    room.broadcast(
      {
        'type': 'cursorUpdate',
        'userId': session.userId,
        'sessionId': session.sessionId,
        'cursor': cursor,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      excludeSessionId: session.sessionId,
    );

    // Publish to Redis
    redisChannel.publishPresence(room.documentId, {
      'type': 'cursor',
      'userId': session.userId,
      'sessionId': session.sessionId,
      'cursor': cursor,
    });
  }

  /// Handles a selection update from a client.
  void _handleSelectionUpdate(
    CollaborationRoom room,
    CollaborationSession session,
    Map<String, dynamic> data,
  ) {
    final selection = data['selection'] as List<dynamic>?;
    if (selection == null) return;

    // Broadcast to other clients
    room.broadcast(
      {
        'type': 'selectionUpdate',
        'userId': session.userId,
        'sessionId': session.sessionId,
        'selection': selection,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      excludeSessionId: session.sessionId,
    );
  }

  /// Handles a Redis operation received from another gateway instance.
  void _handleRedisOperation(String documentId, Map<String, dynamic> operation) {
    final room = rooms[documentId];
    if (room == null) return;

    // This operation was already processed by the originating gateway,
    // so we just need to broadcast it to our local clients
    room.broadcastToAll(operation);
  }

  /// Handles session closure.
  void _handleSessionClose(String documentId, String sessionId) {
    final room = rooms[documentId];
    if (room == null) return;

    final session = room.getSession(sessionId);
    if (session != null) {
      // Notify other users
      room.broadcast(
        {
          'type': 'userLeft',
          'userId': session.userId,
          'sessionId': sessionId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
        excludeSessionId: sessionId,
      );

      room.removeSession(sessionId);

      // Clean up empty rooms
      if (room.activeEditorCount == 0) {
        rooms.remove(documentId);
        logger.d('Removed empty room: $documentId');
      }
    }
  }

  /// Starts periodic idle session checking.
  void _startIdleCheckTimer() {
    _idleCheckTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkIdleSessions();
    });
  }

  /// Checks and removes idle sessions across all rooms.
  void _checkIdleSessions() {
    for (final room in rooms.values) {
      final idleSessions = room.removeIdleSessions(idleTimeout);
      if (idleSessions.isNotEmpty) {
        logger.i('Removed ${idleSessions.length} idle sessions from ${room.documentId}');

        // Notify remaining users
        for (final sessionId in idleSessions) {
          room.broadcastToAll({
            'type': 'userLeft',
            'sessionId': sessionId,
            'reason': 'idle_timeout',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
        }
      }
    }

    // Clean up empty rooms
    rooms.removeWhere((_, room) => room.activeEditorCount == 0);
  }
}
