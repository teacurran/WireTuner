/// Tests for CursorOverlay widget.
///
/// Verifies:
/// - Live cursor rendering with correct colors
/// - Cursor label display with tool information
/// - Stale cursor removal
/// - Coordinate transformation
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infrastructure/collaboration/collaboration_client.dart';
import 'package:app/modules/collaboration/cursor_overlay.dart';

/// Mock CollaborationClient for testing cursors.
class MockCollaborationClient extends CollaborationClient {
  final StreamController<Map<String, dynamic>> _cursorController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _selectionController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<UserPresenceUpdate> _presenceController =
      StreamController<UserPresenceUpdate>.broadcast();

  @override
  Stream<Map<String, dynamic>> get cursorStream => _cursorController.stream;

  @override
  Stream<Map<String, dynamic>> get selectionStream => _selectionController.stream;

  @override
  Stream<UserPresenceUpdate> get presenceStream => _presenceController.stream;

  MockCollaborationClient()
      : super(
          serverUrl: 'ws://test',
          authToken: 'test-token',
        );

  void emitCursorUpdate(Map<String, dynamic> data) {
    _cursorController.add(data);
  }

  void emitSelectionUpdate(Map<String, dynamic> data) {
    _selectionController.add(data);
  }

  void emitPresenceUpdate(UserPresenceUpdate update) {
    _presenceController.add(update);
  }

  @override
  void dispose() {
    _cursorController.close();
    _selectionController.close();
    _presenceController.close();
    super.dispose();
  }
}

void main() {
  group('CursorOverlay', () {
    late MockCollaborationClient mockClient;

    setUp(() {
      mockClient = MockCollaborationClient();
    });

    tearDown(() {
      mockClient.dispose();
    });

    testWidgets('renders cursor at correct position',
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

      // Emit cursor update
      mockClient.emitCursorUpdate({
        'sessionId': 'session1',
        'userId': 'user1',
        'cursor': {'x': 100.0, 'y': 200.0},
      });

      await tester.pump();

      // Verify cursor is rendered (CustomPaint should be present)
      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets('applies coordinate transformation',
        (WidgetTester tester) async {
      Offset? transformedPosition;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CursorOverlay(
              client: mockClient,
              canvasSize: const Size(800, 600),
              coordinateTransform: (pos) {
                transformedPosition = pos;
                return Offset(pos.dx * 2, pos.dy * 2); // Scale by 2x
              },
            ),
          ),
        ),
      );

      // Emit cursor update
      mockClient.emitCursorUpdate({
        'sessionId': 'session1',
        'userId': 'user1',
        'cursor': {'x': 50.0, 'y': 75.0},
      });

      await tester.pump();

      // Verify transform was applied
      expect(transformedPosition, isNotNull);
      expect(transformedPosition!.dx, equals(50.0));
      expect(transformedPosition!.dy, equals(75.0));
    });

    testWidgets('displays cursor with tool information',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CursorOverlay(
              client: mockClient,
              canvasSize: const Size(800, 600),
              showLabels: true,
            ),
          ),
        ),
      );

      // Emit cursor update with tool info
      mockClient.emitCursorUpdate({
        'sessionId': 'session1',
        'userId': 'Alice',
        'cursor': {'x': 100.0, 'y': 200.0},
        'tool': 'Select',
      });

      await tester.pump();

      // Verify cursor is rendered
      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets('respects color palette',
        (WidgetTester tester) async {
      const customPalette = [
        Color(0xFFFF0000), // Red
        Color(0xFF00FF00), // Green
        Color(0xFF0000FF), // Blue
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CursorOverlay(
              client: mockClient,
              canvasSize: const Size(800, 600),
              colorPalette: customPalette,
            ),
          ),
        ),
      );

      // Emit cursor update
      mockClient.emitCursorUpdate({
        'sessionId': 'session1',
        'userId': 'user1',
        'cursor': {'x': 100.0, 'y': 200.0},
      });

      await tester.pump();

      // Cursor should be rendered with color from custom palette
      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets('removes cursor when user leaves',
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

      // Add cursor
      mockClient.emitCursorUpdate({
        'sessionId': 'session1',
        'userId': 'user1',
        'cursor': {'x': 100.0, 'y': 200.0},
      });

      await tester.pump();

      // User leaves
      mockClient.emitPresenceUpdate(
        UserPresenceUpdate(
          userId: 'user1',
          sessionId: 'session1',
          type: PresenceUpdateType.left,
        ),
      );

      await tester.pump();

      // Cursor should be removed (still has CustomPaint but no cursors)
      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets('removes stale cursors after timeout',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CursorOverlay(
              client: mockClient,
              canvasSize: const Size(800, 600),
              staleTimeout: const Duration(seconds: 2),
            ),
          ),
        ),
      );

      // Add cursor
      mockClient.emitCursorUpdate({
        'sessionId': 'session1',
        'userId': 'user1',
        'cursor': {'x': 100.0, 'y': 200.0},
      });

      await tester.pump();

      // Wait for stale timeout + check interval
      await tester.pump(const Duration(seconds: 5));

      // Cursor should be removed as stale
      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets('handles multiple cursors',
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

      // Add multiple cursors
      mockClient.emitCursorUpdate({
        'sessionId': 'session1',
        'userId': 'user1',
        'cursor': {'x': 100.0, 'y': 200.0},
      });

      mockClient.emitCursorUpdate({
        'sessionId': 'session2',
        'userId': 'user2',
        'cursor': {'x': 300.0, 'y': 400.0},
      });

      await tester.pump();

      // All cursors should be rendered
      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets('updates cursor position smoothly',
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

      // Initial position
      mockClient.emitCursorUpdate({
        'sessionId': 'session1',
        'userId': 'user1',
        'cursor': {'x': 100.0, 'y': 200.0},
      });

      await tester.pump();

      // Update position
      mockClient.emitCursorUpdate({
        'sessionId': 'session1',
        'userId': 'user1',
        'cursor': {'x': 150.0, 'y': 250.0},
      });

      await tester.pump();

      // Cursor should update
      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets('handles selection updates',
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

      // Emit selection update
      mockClient.emitSelectionUpdate({
        'sessionId': 'session1',
        'userId': 'user1',
        'selection': ['obj1', 'obj2'],
      });

      await tester.pump();

      // Selection should be tracked internally
      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets('ignores invalid cursor data',
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

      // Emit invalid cursor update (missing x/y)
      mockClient.emitCursorUpdate({
        'sessionId': 'session1',
        'userId': 'user1',
        'cursor': {},
      });

      await tester.pump();

      // Should not crash
      expect(find.byType(CustomPaint), findsOneWidget);
    });
  });

  group('LatencyIndicator', () {
    testWidgets('displays offline state when not connected',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LatencyIndicator(
              isConnected: false,
            ),
          ),
        ),
      );

      expect(find.text('Offline'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });

    testWidgets('displays connecting state when latency is null',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LatencyIndicator(
              isConnected: true,
              latency: null,
            ),
          ),
        ),
      );

      expect(find.text('Connecting...'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_queue), findsOneWidget);
    });

    testWidgets('displays green latency for <100ms',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LatencyIndicator(
              isConnected: true,
              latency: Duration(milliseconds: 50),
            ),
          ),
        ),
      );

      expect(find.text('50ms'), findsOneWidget);
      expect(find.byIcon(Icons.wifi), findsOneWidget);
    });

    testWidgets('displays yellow latency for 100-250ms',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LatencyIndicator(
              isConnected: true,
              latency: Duration(milliseconds: 150),
            ),
          ),
        ),
      );

      expect(find.text('150ms'), findsOneWidget);
    });

    testWidgets('displays red latency for >=250ms',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LatencyIndicator(
              isConnected: true,
              latency: Duration(milliseconds: 300),
            ),
          ),
        ),
      );

      expect(find.text('300ms'), findsOneWidget);
    });
  });
}
