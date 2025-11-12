import 'dart:async';
import 'dart:convert';
import 'package:redis/redis.dart';
import 'package:logger/logger.dart';

/// Redis pub/sub adapter for broadcasting operations across multiple gateway instances.
///
/// Enables horizontal scaling by allowing multiple collaboration gateway servers
/// to share operation streams via Redis. Each gateway subscribes to document channels
/// and publishes operations to ensure all connected clients receive updates.
class RedisChannel {
  final String host;
  final int port;
  final String? password;
  final Logger logger;

  RedisConnection? _connection;
  PubSub? _pubsub;
  Command? _command;
  final Map<String, StreamController<Map<String, dynamic>>> _subscriptions = {};

  RedisChannel({
    this.host = 'localhost',
    this.port = 6379,
    this.password,
    Logger? logger,
  }) : logger = logger ?? Logger();

  /// Connects to Redis server.
  Future<void> connect() async {
    try {
      _connection = RedisConnection();
      _command = await _connection!.connect(host, port);

      if (password != null) {
        await _command!.send_object(['AUTH', password!]);
      }

      _pubsub = PubSub(_command!);
      logger.i('Connected to Redis at $host:$port');
    } catch (e) {
      logger.e('Failed to connect to Redis: $e');
      rethrow;
    }
  }

  /// Disconnects from Redis server.
  Future<void> disconnect() async {
    try {
      for (final controller in _subscriptions.values) {
        await controller.close();
      }
      _subscriptions.clear();

      await _connection?.close();
      logger.i('Disconnected from Redis');
    } catch (e) {
      logger.e('Error disconnecting from Redis: $e');
    }
  }

  /// Publishes an operation to a document channel.
  ///
  /// The channel name is formatted as "collab:doc:{documentId}".
  Future<void> publishOperation(
      String documentId, Map<String, dynamic> operation) async {
    if (_command == null) {
      throw StateError('Redis not connected');
    }

    final channel = _getDocumentChannel(documentId);
    final payload = jsonEncode(operation);

    try {
      await _command!.send_object(['PUBLISH', channel, payload]);
      logger.d('Published operation to $channel');
    } catch (e) {
      logger.e('Failed to publish to Redis: $e');
      rethrow;
    }
  }

  /// Subscribes to a document channel and returns a stream of operations.
  ///
  /// Multiple subscriptions to the same document share the same underlying
  /// Redis subscription to avoid redundant network traffic.
  Stream<Map<String, dynamic>> subscribeToDocument(String documentId) {
    final channel = _getDocumentChannel(documentId);

    // Return existing subscription if available
    if (_subscriptions.containsKey(channel)) {
      return _subscriptions[channel]!.stream;
    }

    // Create new subscription
    final controller = StreamController<Map<String, dynamic>>.broadcast();
    _subscriptions[channel] = controller;

    _subscribeToChannel(channel, controller);

    return controller.stream;
  }

  /// Unsubscribes from a document channel.
  Future<void> unsubscribeFromDocument(String documentId) async {
    final channel = _getDocumentChannel(documentId);

    if (!_subscriptions.containsKey(channel)) {
      return;
    }

    try {
      _pubsub?.unsubscribe([channel]);
      await _subscriptions[channel]?.close();
      _subscriptions.remove(channel);
      logger.d('Unsubscribed from $channel');
    } catch (e) {
      logger.e('Error unsubscribing from $channel: $e');
    }
  }

  /// Publishes a presence update to a document channel.
  Future<void> publishPresence(
      String documentId, Map<String, dynamic> presence) async {
    if (_command == null) {
      throw StateError('Redis not connected');
    }

    final channel = _getPresenceChannel(documentId);
    final payload = jsonEncode(presence);

    try {
      await _command!.send_object(['PUBLISH', channel, payload]);
      logger.d('Published presence to $channel');
    } catch (e) {
      logger.e('Failed to publish presence: $e');
    }
  }

  /// Subscribes to presence updates for a document.
  Stream<Map<String, dynamic>> subscribeToPresence(String documentId) {
    final channel = _getPresenceChannel(documentId);

    if (_subscriptions.containsKey(channel)) {
      return _subscriptions[channel]!.stream;
    }

    final controller = StreamController<Map<String, dynamic>>.broadcast();
    _subscriptions[channel] = controller;

    _subscribeToChannel(channel, controller);

    return controller.stream;
  }

  /// Stores session metadata in Redis with expiry.
  ///
  /// Used for tracking active sessions across multiple gateway instances.
  Future<void> setSessionMetadata(
    String sessionId,
    Map<String, dynamic> metadata, {
    Duration ttl = const Duration(minutes: 10),
  }) async {
    if (_command == null) {
      throw StateError('Redis not connected');
    }

    final key = 'session:$sessionId';
    final payload = jsonEncode(metadata);

    try {
      await _command!.send_object([
        'SETEX',
        key,
        ttl.inSeconds,
        payload,
      ]);
      logger.d('Stored session metadata for $sessionId');
    } catch (e) {
      logger.e('Failed to store session metadata: $e');
    }
  }

  /// Retrieves session metadata from Redis.
  Future<Map<String, dynamic>?> getSessionMetadata(String sessionId) async {
    if (_command == null) {
      throw StateError('Redis not connected');
    }

    final key = 'session:$sessionId';

    try {
      final result = await _command!.send_object(['GET', key]);
      if (result == null) {
        return null;
      }
      return jsonDecode(result as String) as Map<String, dynamic>;
    } catch (e) {
      logger.e('Failed to get session metadata: $e');
      return null;
    }
  }

  /// Deletes session metadata from Redis.
  Future<void> deleteSessionMetadata(String sessionId) async {
    if (_command == null) {
      throw StateError('Redis not connected');
    }

    final key = 'session:$sessionId';

    try {
      await _command!.send_object(['DEL', key]);
      logger.d('Deleted session metadata for $sessionId');
    } catch (e) {
      logger.e('Failed to delete session metadata: $e');
    }
  }

  /// Internal: Subscribes to a Redis channel and pipes messages to controller.
  void _subscribeToChannel(
    String channel,
    StreamController<Map<String, dynamic>> controller,
  ) {
    _pubsub?.subscribe([channel]);

    _pubsub?.getStream().listen(
      (message) {
        if (message is List && message.length >= 3) {
          final messageType = message[0] as String;
          if (messageType == 'message') {
            final messageChannel = message[1] as String;
            final payload = message[2] as String;

            if (messageChannel == channel) {
              try {
                final data = jsonDecode(payload) as Map<String, dynamic>;
                controller.add(data);
              } catch (e) {
                logger.e('Failed to decode Redis message: $e');
              }
            }
          }
        }
      },
      onError: (error) {
        logger.e('Redis subscription error: $error');
        controller.addError(error);
      },
      onDone: () {
        logger.d('Redis subscription closed for $channel');
        controller.close();
      },
    );

    logger.d('Subscribed to $channel');
  }

  /// Internal: Formats document channel name.
  String _getDocumentChannel(String documentId) => 'collab:doc:$documentId';

  /// Internal: Formats presence channel name.
  String _getPresenceChannel(String documentId) =>
      'collab:presence:$documentId';
}

/// In-memory channel adapter for testing without Redis dependency.
///
/// Provides the same interface as RedisChannel but stores everything in memory.
/// Useful for unit tests and local development.
class InMemoryChannel {
  final Logger logger;
  final Map<String, List<StreamController<Map<String, dynamic>>>> _subscriptions =
      {};
  final Map<String, Map<String, dynamic>> _sessionStore = {};

  InMemoryChannel({Logger? logger}) : logger = logger ?? Logger();

  Future<void> connect() async {
    logger.i('InMemoryChannel connected');
  }

  Future<void> disconnect() async {
    for (final controllers in _subscriptions.values) {
      for (final controller in controllers) {
        await controller.close();
      }
    }
    _subscriptions.clear();
    _sessionStore.clear();
    logger.i('InMemoryChannel disconnected');
  }

  Future<void> publishOperation(
      String documentId, Map<String, dynamic> operation) async {
    final channel = 'collab:doc:$documentId';
    if (_subscriptions.containsKey(channel)) {
      for (final controller in _subscriptions[channel]!) {
        controller.add(operation);
      }
    }
  }

  Stream<Map<String, dynamic>> subscribeToDocument(String documentId) {
    final channel = 'collab:doc:$documentId';
    final controller = StreamController<Map<String, dynamic>>.broadcast();

    _subscriptions.putIfAbsent(channel, () => []).add(controller);

    return controller.stream;
  }

  Future<void> unsubscribeFromDocument(String documentId) async {
    final channel = 'collab:doc:$documentId';
    if (_subscriptions.containsKey(channel)) {
      for (final controller in _subscriptions[channel]!) {
        await controller.close();
      }
      _subscriptions.remove(channel);
    }
  }

  Future<void> publishPresence(
      String documentId, Map<String, dynamic> presence) async {
    final channel = 'collab:presence:$documentId';
    if (_subscriptions.containsKey(channel)) {
      for (final controller in _subscriptions[channel]!) {
        controller.add(presence);
      }
    }
  }

  Stream<Map<String, dynamic>> subscribeToPresence(String documentId) {
    final channel = 'collab:presence:$documentId';
    final controller = StreamController<Map<String, dynamic>>.broadcast();

    _subscriptions.putIfAbsent(channel, () => []).add(controller);

    return controller.stream;
  }

  Future<void> setSessionMetadata(
    String sessionId,
    Map<String, dynamic> metadata, {
    Duration ttl = const Duration(minutes: 10),
  }) async {
    _sessionStore['session:$sessionId'] = metadata;
  }

  Future<Map<String, dynamic>?> getSessionMetadata(String sessionId) async {
    return _sessionStore['session:$sessionId'];
  }

  Future<void> deleteSessionMetadata(String sessionId) async {
    _sessionStore.remove('session:$sessionId');
  }
}
