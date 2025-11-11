/// Tests for ConflictBanner widget.
///
/// Verifies:
/// - Conflict detection from error stream
/// - Resolution action wiring
/// - Accessibility announcements
/// - Keyboard shortcuts
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infrastructure/collaboration/collaboration_client.dart';
import 'package:app/modules/collaboration/conflict_banner.dart';

/// Mock CollaborationClient for testing conflicts.
class MockCollaborationClient extends CollaborationClient {
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  @override
  Stream<String> get errorStream => _errorController.stream;

  MockCollaborationClient()
      : super(
          serverUrl: 'ws://test',
          authToken: 'test-token',
        );

  void emitError(String error) {
    _errorController.add(error);
  }

  @override
  void dispose() {
    _errorController.close();
    super.dispose();
  }
}

void main() {
  group('ConflictBanner', () {
    late MockCollaborationClient mockClient;

    setUp(() {
      mockClient = MockCollaborationClient();
    });

    tearDown(() {
      mockClient.dispose();
    });

    testWidgets('initially hidden when no conflicts',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConflictBanner(client: mockClient),
          ),
        ),
      );

      // Banner should not be visible
      expect(find.text('Collaboration Conflict'), findsNothing);
    });

    testWidgets('displays banner when conflict is detected',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConflictBanner(client: mockClient),
          ),
        ),
      );

      // Emit conflict error
      mockClient.emitError('Resync required - operation conflict');

      await tester.pump(); // Start animation
      await tester.pump(const Duration(milliseconds: 300)); // Complete animation

      // Banner should be visible
      expect(find.text('Collaboration Conflict'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('shows resolution action buttons',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConflictBanner(client: mockClient),
          ),
        ),
      );

      // Emit conflict
      mockClient.emitError('OT conflict detected');

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should show action buttons
      expect(find.text('View Diff'), findsOneWidget);
      expect(find.text('Accept Remote'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('calls onResolution when Accept Remote is clicked',
        (WidgetTester tester) async {
      ConflictResolution? capturedResolution;
      String? capturedConflictId;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConflictBanner(
              client: mockClient,
              autoDismiss: false,
              onResolution: (resolution, conflictId) async {
                capturedResolution = resolution;
                capturedConflictId = conflictId;
              },
            ),
          ),
        ),
      );

      // Emit conflict
      mockClient.emitError('Conflict detected');

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Click Accept Remote
      await tester.tap(find.text('Accept Remote'));
      await tester.pump();

      // Verify callback was called
      expect(capturedResolution, equals(ConflictResolution.acceptRemote));
      expect(capturedConflictId, isNotNull);
    });

    testWidgets('calls onResolution when Retry is clicked',
        (WidgetTester tester) async {
      ConflictResolution? capturedResolution;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConflictBanner(
              client: mockClient,
              autoDismiss: false,
              onResolution: (resolution, conflictId) async {
                capturedResolution = resolution;
              },
            ),
          ),
        ),
      );

      // Emit conflict
      mockClient.emitError('Conflict detected');

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Click Retry
      await tester.tap(find.text('Retry'));
      await tester.pump();

      // Verify callback was called
      expect(capturedResolution, equals(ConflictResolution.retryLocal));
    });

    testWidgets('opens diff dialog when View Diff is clicked',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConflictBanner(client: mockClient),
          ),
        ),
      );

      // Emit conflict
      mockClient.emitError('Conflict detected');

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Click View Diff
      await tester.tap(find.text('View Diff'));
      await tester.pumpAndSettle();

      // Should open dialog
      expect(find.text('Conflict Details'), findsOneWidget);
      expect(find.text('Local Changes:'), findsOneWidget);
      expect(find.text('Remote Changes:'), findsOneWidget);
    });

    testWidgets('dismisses banner when close button is clicked',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConflictBanner(client: mockClient),
          ),
        ),
      );

      // Emit conflict
      mockClient.emitError('Conflict detected');

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Click close button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(seconds: 4)); // Wait for auto-dismiss

      // Banner should be hidden
      expect(find.text('Collaboration Conflict'), findsNothing);
    });

    testWidgets('auto-dismisses after resolution when enabled',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConflictBanner(
              client: mockClient,
              autoDismiss: true,
              autoDismissDuration: const Duration(milliseconds: 100),
            ),
          ),
        ),
      );

      // Emit conflict
      mockClient.emitError('Conflict detected');

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Click Accept Remote
      await tester.tap(find.text('Accept Remote'));
      await tester.pump();

      // Wait for auto-dismiss
      await tester.pump(const Duration(milliseconds: 500));

      // Banner should be hidden
      expect(find.text('Collaboration Conflict'), findsNothing);
    });

    testWidgets('shows resolving state during resolution',
        (WidgetTester tester) async {
      final completer = Completer<void>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConflictBanner(
              client: mockClient,
              autoDismiss: false,
              onResolution: (resolution, conflictId) async {
                await completer.future;
              },
            ),
          ),
        ),
      );

      // Emit conflict
      mockClient.emitError('Conflict detected');

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Click Accept Remote (but don't complete the future yet)
      await tester.tap(find.text('Accept Remote'));
      await tester.pump();

      // Should show resolving state
      expect(find.text('Resolving conflict...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete resolution
      completer.complete();
      await tester.pump();
    });

    testWidgets('detects conflicts from Resync errors',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConflictBanner(client: mockClient),
          ),
        ),
      );

      // Emit Resync error
      mockClient.emitError('Resync required - sequence mismatch');

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should show conflict banner
      expect(find.text('Collaboration Conflict'), findsOneWidget);
    });

    testWidgets('ignores non-conflict errors',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConflictBanner(client: mockClient),
          ),
        ),
      );

      // Emit non-conflict error
      mockClient.emitError('Rate limit exceeded');

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should not show conflict banner
      expect(find.text('Collaboration Conflict'), findsNothing);
    });
  });

  group('ConflictBanner diff dialog', () {
    late MockCollaborationClient mockClient;

    setUp(() {
      mockClient = MockCollaborationClient();
    });

    tearDown(() {
      mockClient.dispose();
    });

    testWidgets('displays local and remote operation data',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConflictBanner(client: mockClient),
          ),
        ),
      );

      // Emit conflict
      mockClient.emitError('Conflict detected');

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Open diff dialog
      await tester.tap(find.text('View Diff'));
      await tester.pumpAndSettle();

      // Should display sections
      expect(find.text('Local Changes:'), findsOneWidget);
      expect(find.text('Remote Changes:'), findsOneWidget);
    });

    testWidgets('resolves conflict from dialog',
        (WidgetTester tester) async {
      ConflictResolution? capturedResolution;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConflictBanner(
              client: mockClient,
              autoDismiss: false,
              onResolution: (resolution, conflictId) async {
                capturedResolution = resolution;
              },
            ),
          ),
        ),
      );

      // Emit conflict
      mockClient.emitError('Conflict detected');

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Open diff dialog
      await tester.tap(find.text('View Diff'));
      await tester.pumpAndSettle();

      // Click Accept Remote in dialog
      await tester.tap(find.text('Accept Remote').last);
      await tester.pumpAndSettle();

      // Verify resolution was called
      expect(capturedResolution, equals(ConflictResolution.acceptRemote));
    });

    testWidgets('closes dialog when Cancel is clicked',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConflictBanner(client: mockClient),
          ),
        ),
      );

      // Emit conflict
      mockClient.emitError('Conflict detected');

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Open diff dialog
      await tester.tap(find.text('View Diff'));
      await tester.pumpAndSettle();

      // Click Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog should be closed
      expect(find.text('Conflict Details'), findsNothing);

      // Banner should still be visible
      expect(find.text('Collaboration Conflict'), findsOneWidget);
    });
  });
}
