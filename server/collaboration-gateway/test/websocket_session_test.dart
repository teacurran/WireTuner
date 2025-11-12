import 'dart:async';
import 'package:test/test.dart';
import 'package:collaboration_gateway/models/session.dart';
import 'package:collaboration_gateway/ot/operation_types.dart';
import 'package:collaboration_gateway/middleware/auth_middleware.dart';
import 'package:collaboration_gateway/infra/redis_channel.dart';
import 'package:mocktail/mocktail.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Mock classes for testing
class MockWebSocketChannel extends Mock implements WebSocketChannel {}

class MockWebSocketSink extends Mock implements WebSocketSink {}

class MockStreamController extends Mock
    implements StreamController<Map<String, dynamic>> {}

void main() {
  group('CollaborationSession', () {
    late CollaborationSession session;
    late MockWebSocketChannel mockChannel;
    late MockWebSocketSink mockSink;

    setUp(() {
      mockChannel = MockWebSocketChannel();
      mockSink = MockWebSocketSink();

      when(() => mockChannel.sink).thenReturn(mockSink);

      session = CollaborationSession(
        sessionId: 'session1',
        userId: 'user1',
        documentId: 'doc1',
        channel: mockChannel,
        connectedAt: DateTime.now(),
        otState: const OTState(localSequence: 0, serverSequence: 0),
      );
    });

    test('updates activity timestamp', () {
      final before = session.lastActivity;
      Future.delayed(const Duration(milliseconds: 10), () {
        session.updateActivity();
        expect(session.lastActivity.isAfter(before), true);
      });
    });

    test('detects idle sessions', () {
      expect(session.isIdleForDuration(const Duration(seconds: 1)), false);

      // Simulate old activity
      session.lastActivity =
          DateTime.now().subtract(const Duration(minutes: 10));

      expect(session.isIdleForDuration(const Duration(minutes: 5)), true);
    });

    test('sends messages through WebSocket', () {
      final message = {'type': 'test', 'data': 'hello'};

      when(() => mockSink.add(any())).thenReturn(null);

      session.send(message);

      verify(() => mockSink.add(message)).called(1);
    });

    test('closes WebSocket connection', () {
      when(() => mockSink.close(any(), any()))
          .thenAnswer((_) async => Future.value());

      session.close(1000, 'Normal closure');

      verify(() => mockSink.close(1000, 'Normal closure')).called(1);
    });
  });

  group('CollaborationRoom', () {
    late CollaborationRoom room;
    late CollaborationSession session1;
    late CollaborationSession session2;
    late MockWebSocketChannel mockChannel1;
    late MockWebSocketChannel mockChannel2;
    late MockWebSocketSink mockSink1;
    late MockWebSocketSink mockSink2;

    setUp(() {
      room = CollaborationRoom(documentId: 'doc1', maxConcurrentEditors: 2);

      mockChannel1 = MockWebSocketChannel();
      mockChannel2 = MockWebSocketChannel();
      mockSink1 = MockWebSocketSink();
      mockSink2 = MockWebSocketSink();

      when(() => mockChannel1.sink).thenReturn(mockSink1);
      when(() => mockChannel2.sink).thenReturn(mockSink2);
      when(() => mockSink1.add(any())).thenReturn(null);
      when(() => mockSink2.add(any())).thenReturn(null);

      session1 = CollaborationSession(
        sessionId: 'session1',
        userId: 'user1',
        documentId: 'doc1',
        channel: mockChannel1,
        connectedAt: DateTime.now(),
        otState: const OTState(localSequence: 0, serverSequence: 0),
      );

      session2 = CollaborationSession(
        sessionId: 'session2',
        userId: 'user2',
        documentId: 'doc1',
        channel: mockChannel2,
        connectedAt: DateTime.now(),
        otState: const OTState(localSequence: 0, serverSequence: 0),
      );
    });

    test('enforces concurrency limit', () {
      expect(room.addSession(session1), true);
      expect(room.addSession(session2), true);
      expect(room.isAtCapacity, true);

      final session3 = CollaborationSession(
        sessionId: 'session3',
        userId: 'user3',
        documentId: 'doc1',
        channel: mockChannel1,
        connectedAt: DateTime.now(),
        otState: const OTState(localSequence: 0, serverSequence: 0),
      );

      expect(room.addSession(session3), false);
    });

    test('broadcasts to all sessions except sender', () {
      room.addSession(session1);
      room.addSession(session2);

      final message = {'type': 'test', 'data': 'broadcast'};

      room.broadcast(message, excludeSessionId: 'session1');

      verify(() => mockSink2.add(message)).called(1);
      verifyNever(() => mockSink1.add(message));
    });

    test('broadcasts to all sessions including sender', () {
      room.addSession(session1);
      room.addSession(session2);

      final message = {'type': 'test', 'data': 'broadcast'};

      room.broadcastToAll(message);

      verify(() => mockSink1.add(message)).called(1);
      verify(() => mockSink2.add(message)).called(1);
    });

    test('adds operations and increments server sequence', () {
      final op1 = OTOperation.insert(
        operationId: 'op1',
        userId: 'user1',
        sessionId: 'session1',
        localSequence: 1,
        serverSequence: 0,
        objectId: 'obj1',
        index: 0,
        objectData: {'type': 'path'},
        timestamp: 1000,
      );

      final seq1 = room.addOperation(op1);
      expect(seq1, 1);
      expect(room.serverSequence, 1);

      final op2 = OTOperation.delete(
        operationId: 'op2',
        userId: 'user2',
        sessionId: 'session2',
        localSequence: 1,
        serverSequence: 1,
        targetId: 'obj1',
        timestamp: 1001,
      );

      final seq2 = room.addOperation(op2);
      expect(seq2, 2);
      expect(room.serverSequence, 2);
    });

    test('retrieves operations since sequence', () {
      final op1 = OTOperation.insert(
        operationId: 'op1',
        userId: 'user1',
        sessionId: 'session1',
        localSequence: 1,
        serverSequence: 0,
        objectId: 'obj1',
        index: 0,
        objectData: {'type': 'path'},
        timestamp: 1000,
      );

      final op2 = OTOperation.insert(
        operationId: 'op2',
        userId: 'user1',
        sessionId: 'session1',
        localSequence: 2,
        serverSequence: 1,
        objectId: 'obj2',
        index: 1,
        objectData: {'type': 'shape'},
        timestamp: 1001,
      );

      room.addOperation(op1);
      room.addOperation(op2);

      final ops = room.getOperationsSince(1);
      expect(ops.length, 1);
      expect(ops[0], op2);
    });

    test('removes idle sessions', () {
      room.addSession(session1);
      room.addSession(session2);

      // Make session1 idle
      session1.lastActivity = DateTime.now().subtract(const Duration(minutes: 10));

      when(() => mockSink1.close(any(), any()))
          .thenAnswer((_) async => Future.value());

      final removed = room.removeIdleSessions(const Duration(minutes: 5));

      expect(removed.length, 1);
      expect(removed.contains('session1'), true);
      expect(room.activeEditorCount, 1);
    });

    test('generates user presences', () {
      room.addSession(session1);
      room.addSession(session2);

      // Make session2 idle
      session2.lastActivity = DateTime.now().subtract(const Duration(minutes: 2));

      final presences = room.getUserPresences();

      expect(presences.length, 2);
      expect(presences[0].userId, 'user1');
      expect(presences[0].status, 'active');
      expect(presences[1].userId, 'user2');
      expect(presences[1].status, 'idle');
    });
  });

  group('AuthMiddleware', () {
    late AuthMiddleware authMiddleware;

    setUp(() {
      authMiddleware = AuthMiddleware(jwtSecret: 'test-secret');
    });

    test('creates and validates JWT tokens', () {
      final token = authMiddleware.createToken(
        userId: 'user1',
        displayName: 'Test User',
      );

      expect(token, isNotEmpty);

      final payload = authMiddleware.validateToken(token);
      expect(payload, isNotNull);
      expect(payload!['userId'], 'user1');
      expect(payload['displayName'], 'Test User');
    });

    test('rejects invalid tokens', () {
      expect(
        () => authMiddleware.validateToken('invalid.token.here'),
        throwsA(isA<Exception>()),
      );
    });

    test('extracts user information from payload', () {
      final payload = {
        'userId': 'user123',
        'displayName': 'John Doe',
        'email': 'john@example.com',
      };

      expect(authMiddleware.extractUserId(payload), 'user123');
      expect(authMiddleware.extractDisplayName(payload), 'John Doe');
    });
  });

  group('InMemoryChannel', () {
    late InMemoryChannel channel;

    setUp(() async {
      channel = InMemoryChannel();
      await channel.connect();
    });

    tearDown(() async {
      await channel.disconnect();
    });

    test('publishes and receives operations', () async {
      final received = <Map<String, dynamic>>[];
      final subscription = channel.subscribeToDocument('doc1').listen(received.add);

      await channel.publishOperation('doc1', {'type': 'insert', 'data': 'test'});

      await Future.delayed(const Duration(milliseconds: 50));

      expect(received.length, 1);
      expect(received[0]['type'], 'insert');

      await subscription.cancel();
    });

    test('publishes and receives presence', () async {
      final received = <Map<String, dynamic>>[];
      final subscription = channel.subscribeToPresence('doc1').listen(received.add);

      await channel.publishPresence('doc1', {
        'userId': 'user1',
        'cursor': {'x': 100, 'y': 200}
      });

      await Future.delayed(const Duration(milliseconds: 50));

      expect(received.length, 1);
      expect(received[0]['userId'], 'user1');

      await subscription.cancel();
    });

    test('stores and retrieves session metadata', () async {
      final metadata = {'userId': 'user1', 'documentId': 'doc1'};

      await channel.setSessionMetadata('session1', metadata);

      final retrieved = await channel.getSessionMetadata('session1');
      expect(retrieved, isNotNull);
      expect(retrieved!['userId'], 'user1');
      expect(retrieved['documentId'], 'doc1');
    });

    test('deletes session metadata', () async {
      final metadata = {'userId': 'user1'};
      await channel.setSessionMetadata('session1', metadata);

      await channel.deleteSessionMetadata('session1');

      final retrieved = await channel.getSessionMetadata('session1');
      expect(retrieved, isNull);
    });
  });
}
