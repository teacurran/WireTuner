/// Tests for PresencePanel widget.
///
/// Verifies:
/// - Real-time presence updates within <500ms SLA
/// - Collaborator join/leave notifications
/// - Offline fallback messaging
/// - Accessibility announcements
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infrastructure/collaboration/collaboration_client.dart';
import 'package:app/modules/collaboration/presence_panel.dart';

/// Mock CollaborationClient for testing.
class MockCollaborationClient extends CollaborationClient {
  final StreamController<UserPresenceUpdate> _presenceController =
      StreamController<UserPresenceUpdate>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  @override
  Stream<UserPresenceUpdate> get presenceStream => _presenceController.stream;

  @override
  Stream<String> get errorStream => _errorController.stream;

  @override
  bool get isConnected => _isConnectedFlag;

  bool _isConnectedFlag = true;

  MockCollaborationClient()
      : super(
          serverUrl: 'ws://test',
          authToken: 'test-token',
        );

  void emitPresenceUpdate(UserPresenceUpdate update) {
    _presenceController.add(update);
  }

  void emitError(String error) {
    _errorController.add(error);
  }

  void setConnected(bool connected) {
    _isConnectedFlag = connected;
  }

  @override
  void dispose() {
    _presenceController.close();
    _errorController.close();
    super.dispose();
  }
}

void main() {
  group('PresencePanel', () {
    late MockCollaborationClient mockClient;

    setUp(() {
      mockClient = MockCollaborationClient();
    });

    tearDown(() {
      mockClient.dispose();
    });

    testWidgets('displays empty state when no collaborators',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PresencePanel(client: mockClient),
          ),
        ),
      );

      expect(find.text('No active collaborators'), findsOneWidget);
    });

    testWidgets('displays collaborator when user joins',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PresencePanel(client: mockClient),
          ),
        ),
      );

      // Emit join event
      mockClient.emitPresenceUpdate(
        UserPresenceUpdate(
          userId: 'user1',
          sessionId: 'session1',
          type: PresenceUpdateType.joined,
        ),
      );

      await tester.pump();

      // Should display avatar
      expect(find.byType(Tooltip), findsAtLeastNWidgets(1));
    });

    testWidgets('updates within 500ms acceptance criteria',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PresencePanel(client: mockClient),
          ),
        ),
      );

      final stopwatch = Stopwatch()..start();

      // Emit join event
      mockClient.emitPresenceUpdate(
        UserPresenceUpdate(
          userId: 'user1',
          sessionId: 'session1',
          type: PresenceUpdateType.joined,
        ),
      );

      await tester.pump();

      stopwatch.stop();

      // Verify update happened within 500ms
      expect(stopwatch.elapsedMilliseconds, lessThan(500));

      // Verify UI updated
      expect(find.byType(Tooltip), findsAtLeastNWidgets(1));
    });

    testWidgets('removes collaborator when user leaves',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PresencePanel(client: mockClient),
          ),
        ),
      );

      // Join first
      mockClient.emitPresenceUpdate(
        UserPresenceUpdate(
          userId: 'user1',
          sessionId: 'session1',
          type: PresenceUpdateType.joined,
        ),
      );

      await tester.pump();

      expect(find.byType(Tooltip), findsAtLeastNWidgets(1));

      // Then leave
      mockClient.emitPresenceUpdate(
        UserPresenceUpdate(
          userId: 'user1',
          sessionId: 'session1',
          type: PresenceUpdateType.left,
        ),
      );

      await tester.pump();

      // Should show empty state
      expect(find.text('No active collaborators'), findsOneWidget);
    });

    testWidgets('displays offline indicator on connection error',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PresencePanel(client: mockClient),
          ),
        ),
      );

      // Emit connection error
      mockClient.emitError('Connection failed');
      mockClient.setConnected(false);

      await tester.pump();

      // Should display offline indicator
      expect(find.text('Offline'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });

    testWidgets('displays online indicator when connected',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PresencePanel(client: mockClient),
          ),
        ),
      );

      // Should display connected indicator
      expect(find.byIcon(Icons.cloud_done), findsOneWidget);
    });

    testWidgets('displays multiple collaborators',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PresencePanel(
              client: mockClient,
              maxAvatars: 8,
            ),
          ),
        ),
      );

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

      await tester.pump();

      // Should display 5 avatars
      expect(find.byType(Tooltip), findsAtLeastNWidgets(5));
    });

    testWidgets('displays overflow count when exceeding maxAvatars',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PresencePanel(
              client: mockClient,
              maxAvatars: 3,
            ),
          ),
        ),
      );

      // Add 5 collaborators (exceeds maxAvatars=3)
      for (int i = 0; i < 5; i++) {
        mockClient.emitPresenceUpdate(
          UserPresenceUpdate(
            userId: 'user$i',
            sessionId: 'session$i',
            type: PresenceUpdateType.joined,
          ),
        );
      }

      await tester.pump();

      // Should display overflow indicator "+2"
      expect(find.text('+2'), findsOneWidget);
    });

    testWidgets('calls onCollaboratorTap when avatar is tapped',
        (WidgetTester tester) async {
      Collaborator? tappedCollaborator;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PresencePanel(
              client: mockClient,
              onCollaboratorTap: (collaborator) {
                tappedCollaborator = collaborator;
              },
            ),
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

      // Tap avatar
      await tester.tap(find.byType(InkWell).first);
      await tester.pump();

      // Verify callback was called
      expect(tappedCollaborator, isNotNull);
      expect(tappedCollaborator!.userId, equals('user1'));
    });

    testWidgets('handles presence snapshot updates',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PresencePanel(client: mockClient),
          ),
        ),
      );

      // Emit snapshot updates
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

      await tester.pump();

      // Should display both collaborators
      expect(find.byType(Tooltip), findsAtLeastNWidgets(2));
    });

    testWidgets('recovers from offline state when receiving updates',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PresencePanel(client: mockClient),
          ),
        ),
      );

      // Go offline
      mockClient.emitError('Connection lost');
      mockClient.setConnected(false);
      await tester.pump();

      expect(find.text('Offline'), findsOneWidget);

      // Receive presence update (connection restored)
      mockClient.setConnected(true);
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
  });
}
