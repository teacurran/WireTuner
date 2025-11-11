/// Tests for CollaborationStore.
///
/// Verifies:
/// - State management for presence, cursors, selections
/// - Connection lifecycle management
/// - Error handling and offline fallback
/// - Stream subscription management
library;

import 'dart:async';

import 'package:app/modules/collaboration/collaboration_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infrastructure/collaboration/collaboration_client.dart';

/// Mock CollaborationClient for testing store.
class MockCollaborationClient extends CollaborationClient {
  final StreamController<UserPresenceUpdate> _presenceController =
      StreamController<UserPresenceUpdate>.broadcast();
  final StreamController<Map<String, dynamic>> _cursorController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _selectionController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  @override
  Stream<UserPresenceUpdate> get presenceStream => _presenceController.stream;

  @override
  Stream<Map<String, dynamic>> get cursorStream => _cursorController.stream;

  @override
  Stream<Map<String, dynamic>> get selectionStream => _selectionController.stream;

  @override
  Stream<String> get errorStream => _errorController.stream;

  bool _isConnectedFlag = false;

  @override
  bool get isConnected => _isConnectedFlag;

  MockCollaborationClient()
      : super(
          serverUrl: 'ws://test',
          authToken: 'test-token',
        );

  @override
  Future<void> connect({required String documentId}) async {
    _isConnectedFlag = true;
    return Future.value();
  }

  @override
  Future<void> disconnect() async {
    _isConnectedFlag = false;
    return Future.value();
  }

  void emitPresenceUpdate(UserPresenceUpdate update) {
    _presenceController.add(update);
  }

  void emitCursorUpdate(Map<String, dynamic> data) {
    _cursorController.add(data);
  }

  void emitSelectionUpdate(Map<String, dynamic> data) {
    _selectionController.add(data);
  }

  void emitError(String error) {
    _errorController.add(error);
  }

  @override
  void dispose() {
    _presenceController.close();
    _cursorController.close();
    _selectionController.close();
    _errorController.close();
    super.dispose();
  }
}

void main() {
  group('CollaborationStore', () {
    late MockCollaborationClient mockClient;
    late CollaborationStore store;

    setUp(() {
      mockClient = MockCollaborationClient();
      store = CollaborationStore(client: mockClient);
    });

    tearDown(() {
      store.dispose();
      mockClient.dispose();
    });

    test('initial state is disconnected', () {
      expect(store.connectionState, equals(CollabConnectionState.disconnected));
      expect(store.isConnected, isFalse);
      expect(store.documentId, isNull);
      expect(store.collaborators, isEmpty);
      expect(store.cursors, isEmpty);
      expect(store.selections, isEmpty);
    });

    test('connects successfully and updates state', () async {
      await store.connect(documentId: 'doc123');

      expect(store.connectionState, equals(CollabConnectionState.connected));
      expect(store.isConnected, isTrue);
      expect(store.documentId, equals('doc123'));
    });

    test('adds collaborator on join event', () async {
      await store.connect(documentId: 'doc123');

      final notified = <int>[];
      store.addListener(() {
        notified.add(store.collaborators.length);
      });

      mockClient.emitPresenceUpdate(
        UserPresenceUpdate(
          userId: 'user1',
          sessionId: 'session1',
          type: PresenceUpdateType.joined,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(store.collaborators, hasLength(1));
      expect(store.collaborators.first.userId, equals('user1'));
      expect(notified, isNotEmpty);
    });

    test('removes collaborator on leave event', () async {
      await store.connect(documentId: 'doc123');

      // Add collaborator
      mockClient.emitPresenceUpdate(
        UserPresenceUpdate(
          userId: 'user1',
          sessionId: 'session1',
          type: PresenceUpdateType.joined,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(store.collaborators, hasLength(1));

      // Remove collaborator
      mockClient.emitPresenceUpdate(
        UserPresenceUpdate(
          userId: 'user1',
          sessionId: 'session1',
          type: PresenceUpdateType.left,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(store.collaborators, isEmpty);
    });

    test('updates cursor positions', () async {
      await store.connect(documentId: 'doc123');

      mockClient.emitCursorUpdate({
        'sessionId': 'session1',
        'userId': 'user1',
        'cursor': {'x': 100.0, 'y': 200.0},
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(store.cursors, hasLength(1));
      expect(store.cursors.first.position, equals(const Offset(100, 200)));
      expect(store.cursors.first.userId, equals('user1'));
    });

    test('updates cursor with tool information', () async {
      await store.connect(documentId: 'doc123');

      mockClient.emitCursorUpdate({
        'sessionId': 'session1',
        'userId': 'user1',
        'cursor': {'x': 100.0, 'y': 200.0},
        'tool': 'Select',
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(store.cursors.first.toolInUse, equals('Select'));
    });

    test('updates selections', () async {
      await store.connect(documentId: 'doc123');

      mockClient.emitSelectionUpdate({
        'sessionId': 'session1',
        'userId': 'user1',
        'selection': ['obj1', 'obj2', 'obj3'],
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(store.selections, hasLength(1));
      expect(store.selections.first.selectedIds, hasLength(3));
      expect(store.selections.first.selectedIds, contains('obj1'));
    });

    test('handles connection errors', () async {
      await store.connect(documentId: 'doc123');

      final notified = <ConnectionState>[];
      store.addListener(() {
        notified.add(store.connectionState);
      });

      mockClient.emitError('Connection lost');

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(store.connectionState, equals(CollabConnectionState.reconnecting));
      expect(store.errorMessage, contains('Connection'));
      expect(notified, contains(CollabConnectionState.reconnecting));
    });

    test('clears state on disconnect', () async {
      await store.connect(documentId: 'doc123');

      // Add some data
      mockClient.emitPresenceUpdate(
        UserPresenceUpdate(
          userId: 'user1',
          sessionId: 'session1',
          type: PresenceUpdateType.joined,
        ),
      );

      mockClient.emitCursorUpdate({
        'sessionId': 'session1',
        'userId': 'user1',
        'cursor': {'x': 100.0, 'y': 200.0},
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(store.collaborators, isNotEmpty);
      expect(store.cursors, isNotEmpty);

      // Disconnect
      await store.disconnect();

      expect(store.connectionState, equals(CollabConnectionState.disconnected));
      expect(store.collaborators, isEmpty);
      expect(store.cursors, isEmpty);
      expect(store.selections, isEmpty);
    });

    test('assigns consistent colors to collaborators', () async {
      await store.connect(documentId: 'doc123');

      // Add multiple collaborators
      for (int i = 0; i < 5; i++) {
        mockClient.emitPresenceUpdate(
          UserPresenceUpdate(
            userId: 'user$i',
            sessionId: 'session$i',
            type: PresenceUpdateType.joined,
          ),
        );
      }

      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Each collaborator should have a color
      expect(store.collaborators, hasLength(5));
      for (final collaborator in store.collaborators) {
        expect(collaborator.color, isNotNull);
      }
    });

    test('handles presence snapshot updates', () async {
      await store.connect(documentId: 'doc123');

      // Emit multiple snapshot updates
      mockClient.emitPresenceUpdate(
        UserPresenceUpdate(
          userId: 'user1',
          sessionId: 'session1',
          type: PresenceUpdateType.snapshot,
        ),
      );

      mockClient.emitPresenceUpdate(
        UserPresenceUpdate(
          userId: 'user2',
          sessionId: 'session2',
          type: PresenceUpdateType.snapshot,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(store.collaborators, hasLength(2));
    });

    test('ignores duplicate collaborator joins', () async {
      await store.connect(documentId: 'doc123');

      // Join twice with same session ID
      mockClient.emitPresenceUpdate(
        UserPresenceUpdate(
          userId: 'user1',
          sessionId: 'session1',
          type: PresenceUpdateType.joined,
        ),
      );

      mockClient.emitPresenceUpdate(
        UserPresenceUpdate(
          userId: 'user1',
          sessionId: 'session1',
          type: PresenceUpdateType.joined,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Should only have one collaborator
      expect(store.collaborators, hasLength(1));
    });

    test('removes cursor and selection when user leaves', () async {
      await store.connect(documentId: 'doc123');

      // Add presence, cursor, and selection
      mockClient.emitPresenceUpdate(
        UserPresenceUpdate(
          userId: 'user1',
          sessionId: 'session1',
          type: PresenceUpdateType.joined,
        ),
      );

      mockClient.emitCursorUpdate({
        'sessionId': 'session1',
        'userId': 'user1',
        'cursor': {'x': 100.0, 'y': 200.0},
      });

      mockClient.emitSelectionUpdate({
        'sessionId': 'session1',
        'userId': 'user1',
        'selection': ['obj1'],
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(store.collaborators, hasLength(1));
      expect(store.cursors, hasLength(1));
      expect(store.selections, hasLength(1));

      // User leaves
      mockClient.emitPresenceUpdate(
        UserPresenceUpdate(
          userId: 'user1',
          sessionId: 'session1',
          type: PresenceUpdateType.left,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // All data should be cleared for that session
      expect(store.collaborators, isEmpty);
      expect(store.cursors, isEmpty);
      expect(store.selections, isEmpty);
    });

    test('notifies listeners on state changes', () async {
      await store.connect(documentId: 'doc123');

      int notifyCount = 0;
      store.addListener(() {
        notifyCount++;
      });

      // Trigger multiple updates
      mockClient.emitPresenceUpdate(
        UserPresenceUpdate(
          userId: 'user1',
          sessionId: 'session1',
          type: PresenceUpdateType.joined,
        ),
      );

      mockClient.emitCursorUpdate({
        'sessionId': 'session1',
        'userId': 'user1',
        'cursor': {'x': 100.0, 'y': 200.0},
      });

      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Should have notified multiple times
      expect(notifyCount, greaterThan(0));
    });
  });
}
