import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../ot/operation_types.dart';

part 'session.freezed.dart';
part 'session.g.dart';

/// Represents an active collaboration session for a user editing a document.
///
/// Each session maintains WebSocket connection, user identity, OT state,
/// and last activity timestamp for idle timeout enforcement.
class CollaborationSession {
  final String sessionId;
  final String userId;
  final String documentId;
  final WebSocketChannel channel;
  final DateTime connectedAt;
  DateTime lastActivity;
  OTState otState;

  CollaborationSession({
    required this.sessionId,
    required this.userId,
    required this.documentId,
    required this.channel,
    required this.connectedAt,
    required this.otState,
  }) : lastActivity = DateTime.now();

  /// Updates the last activity timestamp.
  void updateActivity() {
    lastActivity = DateTime.now();
  }

  /// Checks if this session has been idle beyond the timeout threshold.
  bool isIdleForDuration(Duration timeout) {
    return DateTime.now().difference(lastActivity) > timeout;
  }

  /// Sends a message through the WebSocket channel.
  void send(Map<String, dynamic> message) {
    channel.sink.add(message);
  }

  /// Closes the WebSocket connection.
  void close([int? code, String? reason]) {
    channel.sink.close(code, reason);
  }
}

/// WebSocket message types for the collaboration protocol.
enum WSMessageType {
  /// Client submits an operation to the server.
  operationSubmit,

  /// Server broadcasts a transformed operation to all clients.
  operationBroadcast,

  /// Server acknowledges receipt of an operation.
  operationAck,

  /// Server requests client to resync due to sequence gap.
  resyncRequest,

  /// Client/server cursor position update for presence.
  cursorUpdate,

  /// Client/server selection state update for presence.
  selectionUpdate,

  /// Presence beacon indicating user is active.
  presenceBeacon,

  /// User joins the collaboration session.
  userJoined,

  /// User leaves the collaboration session.
  userLeft,

  /// Rate limit warning from server.
  rateLimit,

  /// Error message.
  error,

  /// Heartbeat/ping message.
  heartbeat,
}

/// WebSocket message payload for collaboration protocol.
@freezed
class WSMessage with _$WSMessage {
  const factory WSMessage({
    required String type,
    String? operationId,
    Map<String, dynamic>? operation,
    String? userId,
    String? sessionId,
    String? documentId,
    Map<String, dynamic>? cursor,
    List<String>? selection,
    String? error,
    String? reason,
    int? serverSequence,
    int? localSequence,
    int? timestamp,
    Map<String, dynamic>? metadata,
  }) = _WSMessage;

  factory WSMessage.fromJson(Map<String, dynamic> json) =>
      _$WSMessageFromJson(json);
}

/// Presence information for a collaborating user.
@freezed
class UserPresence with _$UserPresence {
  const factory UserPresence({
    required String userId,
    required String sessionId,
    String? displayName,
    String? avatarUrl,
    String? color,
    Map<String, dynamic>? cursor,
    List<String>? selection,
    required DateTime lastSeen,
    @Default('active') String status,
  }) = _UserPresence;

  factory UserPresence.fromJson(Map<String, dynamic> json) =>
      _$UserPresenceFromJson(json);
}

/// Document collaboration room tracking all active sessions.
class CollaborationRoom {
  final String documentId;
  final Map<String, CollaborationSession> sessions;
  final List<OTOperation> operationHistory;
  int serverSequence;
  final DateTime createdAt;
  final int maxConcurrentEditors;

  CollaborationRoom({
    required this.documentId,
    this.maxConcurrentEditors = 10,
  })  : sessions = {},
        operationHistory = [],
        serverSequence = 0,
        createdAt = DateTime.now();

  /// Checks if the room is at capacity.
  bool get isAtCapacity => sessions.length >= maxConcurrentEditors;

  /// Gets the count of active editors.
  int get activeEditorCount => sessions.length;

  /// Adds a session to the room.
  bool addSession(CollaborationSession session) {
    if (isAtCapacity) {
      return false;
    }
    sessions[session.sessionId] = session;
    return true;
  }

  /// Removes a session from the room.
  void removeSession(String sessionId) {
    sessions.remove(sessionId);
  }

  /// Gets a session by ID.
  CollaborationSession? getSession(String sessionId) {
    return sessions[sessionId];
  }

  /// Broadcasts a message to all sessions except the sender.
  void broadcast(Map<String, dynamic> message, {String? excludeSessionId}) {
    for (final session in sessions.values) {
      if (session.sessionId != excludeSessionId) {
        session.send(message);
      }
    }
  }

  /// Broadcasts a message to all sessions including the sender.
  void broadcastToAll(Map<String, dynamic> message) {
    for (final session in sessions.values) {
      session.send(message);
    }
  }

  /// Adds an operation to the history and increments server sequence.
  int addOperation(OTOperation operation) {
    operationHistory.add(operation);
    return ++serverSequence;
  }

  /// Gets operations from a specific sequence number.
  List<OTOperation> getOperationsSince(int sequence) {
    if (sequence < 0 || sequence >= operationHistory.length) {
      return [];
    }
    return operationHistory.sublist(sequence);
  }

  /// Gets all user presence information.
  List<UserPresence> getUserPresences() {
    return sessions.values.map((session) {
      return UserPresence(
        userId: session.userId,
        sessionId: session.sessionId,
        lastSeen: session.lastActivity,
        status: session.isIdleForDuration(const Duration(minutes: 1))
            ? 'idle'
            : 'active',
      );
    }).toList();
  }

  /// Removes idle sessions based on timeout.
  List<String> removeIdleSessions(Duration idleTimeout) {
    final idleSessionIds = <String>[];

    for (final entry in sessions.entries) {
      if (entry.value.isIdleForDuration(idleTimeout)) {
        idleSessionIds.add(entry.key);
      }
    }

    for (final sessionId in idleSessionIds) {
      final session = sessions[sessionId];
      if (session != null) {
        session.close(1000, 'Idle timeout');
        sessions.remove(sessionId);
      }
    }

    return idleSessionIds;
  }
}
