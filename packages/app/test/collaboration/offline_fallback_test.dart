/// Integration tests for offline fallback scenarios.
///
/// Verifies:
/// - Offline state detection and messaging
/// - Reconnection handling
/// - State preservation during disconnects
/// - User experience during network failures
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infrastructure/collaboration/collaboration_client.dart';
import 'package:app/modules/collaboration/presence_panel.dart';
import 'package:app/modules/collaboration/cursor_overlay.dart';
import 'package:app/modules/collaboration/conflict_banner.dart';
import 'package:app/modules/collaboration/collaboration_store.dart';

/// Mock CollaborationClient for offline testing.
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

  bool _isConnectedFlag = true;

  @override
  bool get isConnected => _isConnectedFlag;

  MockCollaborationClient()
      : super(
          serverUrl: 'ws://test',
          authToken: 'test-token',
        );

  void simulateDisconnect() {
    _isConnectedFlag = false;
    _errorController.add('Connection lost: WebSocket disconnected');
  }

  void simulateReconnect() {
    _isConnectedFlag = true;
  }

  void emitPresenceUpdate(UserPresenceUpdate update) {
    _presenceController.add(update);
  }

  void emitCursorUpdate(Map<String, dynamic> data) {
    _cursorController.add(data);
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
  group('Offline Fallback Integration', () {
    late MockCollaborationClient mockClient;

    setUp(() {
      mockClient = MockCollaborationClient();
    });

    tearDown(() {
      mockClient.dispose();
    });

    testWidgets('displays offline indicator in presence panel',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PresencePanel(client: mockClient),
          ),
        ),
      );

      // Initially connected
      expect(find.byIcon(Icons.cloud_done), findsOneWidget);
      expect(find.text('Offline'), findsNothing);

      // Simulate disconnect
      mockClient.simulateDisconnect();
      await tester.pump();

      // Should show offline indicator
      expect(find.text('Offline'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });

    testWidgets('recovers from offline state on reconnect',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PresencePanel(client: mockClient),
          ),
        ),
      );

      // Simulate disconnect
      mockClient.simulateDisconnect();
      await tester.pump();

      expect(find.text('Offline'), findsOneWidget);

      // Reconnect and receive presence update
      mockClient.simulateReconnect();
      mockClient.emitPresenceUpdate(
        UserPresenceUpdate(
          userId: 'user1',
          sessionId: 'session1',
          type: PresenceUpdateType.joined,
        ),
      );

      await tester.pump();

      // Should clear offline state
      expect(find.text('Offline'), findsNothing);
      expect(find.byIcon(Icons.cloud_done), findsOneWidget);
    });

    testWidgets('preserves collaborator state during brief disconnects',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PresencePanel(client: mockClient),
          ),
        ),
      );

      // Add collaborator
      mockClient.emitPresenceUpdate(
        UserPresenceUpdate(
          userId: 'user1',
          sessionId: 'session1',
          type: PresenceUpdateType.joined,
        ),
      );

      await tester.pump();

      expect(find.byType(Tooltip), findsAtLeastNWidgets(1));

      // Simulate brief disconnect
      mockClient.simulateDisconnect();
      await tester.pump();

      // Collaborator should still be shown (not cleared immediately)
      expect(find.byType(Tooltip), findsAtLeastNWidgets(1));

      // Reconnect
      mockClient.simulateReconnect();
      mockClient.emitPresenceUpdate(
        UserPresenceUpdate(
          userId: 'user1',
          sessionId: 'session1',
          type: PresenceUpdateType.snapshot,
        ),
      );

      await tester.pump();

      // Should still have collaborator
      expect(find.byType(Tooltip), findsAtLeastNWidgets(1));
    });

    testWidgets('cursor overlay handles offline gracefully',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CursorOverlay(
              client: mockClient,
              canvasSize: const Size(800, 600),
            ),
          ),
        ),
      );

      // Add cursor while online
      mockClient.emitCursorUpdate({
        'sessionId': 'session1',
        'userId': 'user1',
        'cursor': {'x': 100.0, 'y': 200.0},
      });

      await tester.pump();

      // Go offline
      mockClient.simulateDisconnect();
      await tester.pump();

      // Cursor overlay should still be rendered (no crash)
      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets('conflict banner displays reconnection errors',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConflictBanner(client: mockClient),
          ),
        ),
      );

      // Emit Resync error (typically happens on reconnect)
      mockClient.emitError('Resync required - connection interrupted');

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should display conflict banner
      expect(find.text('Collaboration Conflict'), findsOneWidget);
    });

    testWidgets('store transitions to reconnecting state on error',
        (WidgetTester tester) async {
      final store = CollaborationStore(client: mockClient);
      await store.connect(documentId: 'doc123');

      expect(store.connectionState, equals(CollabConnectionState.connected));

      // Simulate connection error
      mockClient.emitError('WebSocket error: Connection refused');

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Should transition to reconnecting
      expect(store.connectionState, equals(CollabConnectionState.reconnecting));
      expect(store.errorMessage, contains('WebSocket'));

      store.dispose();
    });

    testWidgets('full offline scenario: disconnect -> reconnect -> restore',
        (WidgetTester tester) async {
      final store = CollaborationStore(client: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                PresencePanel(client: mockClient),
                Expanded(
                  child: CursorOverlay(
                    client: mockClient,
                    canvasSize: const Size(800, 600),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await store.connect(documentId: 'doc123');

      // Step 1: Online with collaborators
      mockClient.emitPresenceUpdate(
        UserPresenceUpdate(
          userId: 'alice',
          sessionId: 'session1',
          type: PresenceUpdateType.joined,
        ),
      );

      mockClient.emitCursorUpdate({
        'sessionId': 'session1',
        'userId': 'alice',
        'cursor': {'x': 100.0, 'y': 200.0},
      });

      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(find.byIcon(Icons.cloud_done), findsOneWidget);
      expect(store.collaborators, hasLength(1));
      expect(store.cursors, hasLength(1));

      // Step 2: Go offline
      mockClient.simulateDisconnect();
      await tester.pump();

      expect(find.text('Offline'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);

      // Step 3: Reconnect and receive snapshot
      mockClient.simulateReconnect();

      // Server sends presence snapshot on reconnect
      mockClient.emitPresenceUpdate(
        UserPresenceUpdate(
          userId: 'alice',
          sessionId: 'session1',
          type: PresenceUpdateType.snapshot,
        ),
      );

      // Cursors are restored via stream
      mockClient.emitCursorUpdate({
        'sessionId': 'session1',
        'userId': 'alice',
        'cursor': {'x': 150.0, 'y': 250.0},
      });

      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Step 4: Verify restoration
      expect(find.text('Offline'), findsNothing);
      expect(find.byIcon(Icons.cloud_done), findsOneWidget);
      expect(store.collaborators, hasLength(1));
      expect(store.cursors, hasLength(1));

      store.dispose();
    });

    testWidgets('displays meaningful error messages during failures',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PresencePanel(client: mockClient),
          ),
        ),
      );

      // Emit connection error
      mockClient.simulateDisconnect();
      await tester.pump();

      // Should show tooltip with reconnection message
      final offlineIndicator = find.byTooltip('Offline - attempting to reconnect');
      expect(offlineIndicator, findsOneWidget);
    });

    testWidgets('handles rapid disconnect/reconnect cycles',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PresencePanel(client: mockClient),
          ),
        ),
      );

      // Rapid disconnect/reconnect cycles
      for (int i = 0; i < 5; i++) {
        mockClient.simulateDisconnect();
        await tester.pump();

        mockClient.simulateReconnect();
        mockClient.emitPresenceUpdate(
          UserPresenceUpdate(
            userId: 'user1',
            sessionId: 'session1',
            type: PresenceUpdateType.snapshot,
          ),
        );
        await tester.pump();
      }

      // Should handle gracefully without crashes
      expect(tester.takeException(), isNull);
    });
  });
}
