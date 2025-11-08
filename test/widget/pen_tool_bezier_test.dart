import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/application/tools/pen/pen_tool.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/domain/document/selection.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/events/path_events.dart';
import 'package:wiretuner/domain/events/group_events.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';

/// Mock EventRecorder for testing.
class MockEventRecorder {
  final List<EventBase> recordedEvents = [];
  int flushCallCount = 0;
  bool _isPaused = false;

  void recordEvent(EventBase event) {
    if (!_isPaused) {
      recordedEvents.add(event);
    }
  }

  void flush() {
    flushCallCount++;
  }

  void pause() {
    _isPaused = true;
  }

  void resume() {
    _isPaused = false;
  }

  bool get isPaused => _isPaused;

  void clear() {
    recordedEvents.clear();
    flushCallCount = 0;
  }
}

void main() {
  // Initialize Flutter test bindings for HardwareKeyboard support
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PenTool - Bezier Curves', () {
    late PenTool penTool;
    late ViewportController viewportController;
    late MockEventRecorder eventRecorder;
    late Document document;

    setUp(() {
      viewportController = ViewportController(
        initialPan: const ui.Offset(0, 0),
        initialZoom: 1.0,
      );
      eventRecorder = MockEventRecorder();

      // Create an empty test document
      final layer = Layer(
        id: 'layer-1',
        name: 'Test Layer',
        objects: [],
      );

      document = Document(
        id: 'doc-1',
        title: 'Test Document',
        layers: [layer],
        selection: const Selection(),
      );

      penTool = PenTool(
        document: document,
        viewportController: viewportController,
        eventRecorder: eventRecorder,
      );
    });

    tearDown(() {
      viewportController.dispose();
    });

    group('Drag-to-Create Bezier Anchors', () {
      setUp(() {
        penTool.onActivate();
        eventRecorder.clear();

        // Start a path (first click)
        penTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(100, 100),
        ));
        penTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(100, 100),
        ));
        eventRecorder.clear();
      });

      test('should create Bezier anchor with handles when dragging', () {
        // Pointer down at anchor position
        penTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(200, 100),
        ));

        // Pointer move to drag position
        penTool.onPointerMove(PointerMoveEvent(
          position: const ui.Offset(250, 100),
        ));

        // Pointer up to complete gesture
        penTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(250, 100),
        ));

        // Should have emitted one AddAnchorEvent
        expect(eventRecorder.recordedEvents.length, equals(1));

        final addAnchor = eventRecorder.recordedEvents[0] as AddAnchorEvent;
        expect(addAnchor.eventType, equals('AddAnchorEvent'));
        expect(addAnchor.position.x, equals(200.0));
        expect(addAnchor.position.y, equals(100.0));
        expect(addAnchor.anchorType, equals(AnchorType.bezier));

        // Verify handleOut is relative offset from anchor to drag position
        expect(addAnchor.handleOut, isNotNull);
        expect(addAnchor.handleOut!.x, equals(50.0)); // 250 - 200
        expect(addAnchor.handleOut!.y, equals(0.0)); // 100 - 100

        // Verify handleIn is mirrored (-handleOut) for smooth anchor
        expect(addAnchor.handleIn, isNotNull);
        expect(addAnchor.handleIn!.x, equals(-50.0));
        expect(addAnchor.handleIn!.y, equals(0.0));
      });

      test('should scale handle magnitude with drag distance', () {
        // Test shorter drag (25px)
        penTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(200, 100),
        ));
        penTool.onPointerMove(PointerMoveEvent(
          position: const ui.Offset(225, 100),
        ));
        penTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(225, 100),
        ));

        final addAnchor1 = eventRecorder.recordedEvents.last as AddAnchorEvent;
        final magnitude1 = math.sqrt(
          addAnchor1.handleOut!.x * addAnchor1.handleOut!.x +
          addAnchor1.handleOut!.y * addAnchor1.handleOut!.y,
        );

        eventRecorder.clear();

        // Test longer drag (100px)
        penTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(300, 100),
        ));
        penTool.onPointerMove(PointerMoveEvent(
          position: const ui.Offset(400, 100),
        ));
        penTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(400, 100),
        ));

        final addAnchor2 = eventRecorder.recordedEvents.last as AddAnchorEvent;
        final magnitude2 = math.sqrt(
          addAnchor2.handleOut!.x * addAnchor2.handleOut!.x +
          addAnchor2.handleOut!.y * addAnchor2.handleOut!.y,
        );

        // Longer drag should produce larger handle magnitude
        expect(magnitude2, greaterThan(magnitude1));
        expect(magnitude1, closeTo(25.0, 0.1));
        expect(magnitude2, closeTo(100.0, 0.1));
      });

      test('should create Bezier anchor with diagonal drag', () {
        // Drag at 45-degree angle
        penTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(200, 100),
        ));
        penTool.onPointerMove(PointerMoveEvent(
          position: const ui.Offset(250, 150),
        ));
        penTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(250, 150),
        ));

        final addAnchor = eventRecorder.recordedEvents[0] as AddAnchorEvent;

        // Verify handleOut direction
        expect(addAnchor.handleOut!.x, equals(50.0));
        expect(addAnchor.handleOut!.y, equals(50.0));

        // Verify handleIn is mirrored
        expect(addAnchor.handleIn!.x, equals(-50.0));
        expect(addAnchor.handleIn!.y, equals(-50.0));
      });

      test('should store handles as relative offsets, not absolute positions', () {
        // Anchor at (200, 150), drag to (250, 170)
        // Using coordinates different from path start to avoid double-click detection
        penTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(200, 150),
        ));
        penTool.onPointerMove(PointerMoveEvent(
          position: const ui.Offset(250, 170),
        ));
        penTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(250, 170),
        ));

        final addAnchor = eventRecorder.recordedEvents[0] as AddAnchorEvent;

        // Anchor position
        expect(addAnchor.position.x, equals(200.0));
        expect(addAnchor.position.y, equals(150.0));

        // handleOut should be relative offset, not absolute position
        expect(addAnchor.handleOut!.x, equals(50.0)); // NOT 250
        expect(addAnchor.handleOut!.y, equals(20.0)); // NOT 170
      });
    });

    group('Short Drag Threshold', () {
      setUp(() {
        penTool.onActivate();
        eventRecorder.clear();

        // Start a path
        penTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(100, 100),
        ));
        penTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(100, 100),
        ));
        eventRecorder.clear();
      });

      test('should treat short drag as click (straight line anchor)', () {
        // Very short drag (3px) - below 5px threshold
        penTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(200, 100),
        ));
        penTool.onPointerMove(PointerMoveEvent(
          position: const ui.Offset(203, 100),
        ));
        penTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(203, 100),
        ));

        final addAnchor = eventRecorder.recordedEvents[0] as AddAnchorEvent;

        // Should be line anchor, not Bezier
        expect(addAnchor.anchorType, equals(AnchorType.line));
        expect(addAnchor.handleIn, isNull);
        expect(addAnchor.handleOut, isNull);
      });

      test('should create Bezier anchor when drag exceeds threshold', () {
        // Drag just above threshold (6px)
        penTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(200, 100),
        ));
        penTool.onPointerMove(PointerMoveEvent(
          position: const ui.Offset(206, 100),
        ));
        penTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(206, 100),
        ));

        final addAnchor = eventRecorder.recordedEvents[0] as AddAnchorEvent;

        // Should be Bezier anchor with handles
        expect(addAnchor.anchorType, equals(AnchorType.bezier));
        expect(addAnchor.handleOut, isNotNull);
        expect(addAnchor.handleIn, isNotNull);
      });
    });

    group('Alt Key Toggle for Corner Anchors', () {
      setUp(() {
        penTool.onActivate();
        eventRecorder.clear();

        // Start a path
        penTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(100, 100),
        ));
        penTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(100, 100),
        ));
        eventRecorder.clear();
      });

      testWidgets('should create corner anchor when Alt pressed', (tester) async {
        // Simulate Alt key pressed
        await tester.sendKeyDownEvent(LogicalKeyboardKey.alt);

        // Drag to create Bezier anchor
        penTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(200, 100),
        ));
        penTool.onPointerMove(PointerMoveEvent(
          position: const ui.Offset(250, 100),
        ));
        penTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(250, 100),
        ));

        final addAnchor = eventRecorder.recordedEvents[0] as AddAnchorEvent;

        // Should be Bezier anchor
        expect(addAnchor.anchorType, equals(AnchorType.bezier));

        // Should have handleOut
        expect(addAnchor.handleOut, isNotNull);
        expect(addAnchor.handleOut!.x, equals(50.0));
        expect(addAnchor.handleOut!.y, equals(0.0));

        // Should NOT have handleIn (corner anchor = independent handles)
        expect(addAnchor.handleIn, isNull);

        // Release Alt key
        await tester.sendKeyUpEvent(LogicalKeyboardKey.alt);
      });

      testWidgets('should create smooth anchor when Alt not pressed', (tester) async {
        // No Alt key - should create smooth anchor

        // Drag to create Bezier anchor
        penTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(200, 100),
        ));
        penTool.onPointerMove(PointerMoveEvent(
          position: const ui.Offset(250, 100),
        ));
        penTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(250, 100),
        ));

        final addAnchor = eventRecorder.recordedEvents[0] as AddAnchorEvent;

        // Should be Bezier anchor
        expect(addAnchor.anchorType, equals(AnchorType.bezier));

        // Should have both handles (smooth anchor)
        expect(addAnchor.handleOut, isNotNull);
        expect(addAnchor.handleIn, isNotNull);

        // HandleIn should be mirrored
        expect(addAnchor.handleIn!.x, equals(-addAnchor.handleOut!.x));
        expect(addAnchor.handleIn!.y, equals(-addAnchor.handleOut!.y));
      });
    });

    group('Multiple Bezier Anchors in Path', () {
      setUp(() {
        penTool.onActivate();
        eventRecorder.clear();
      });

      test('should create path with multiple Bezier anchors', () {
        // First anchor (click - creates path)
        penTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(100, 100),
        ));
        penTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(100, 100),
        ));

        // Clear start events
        eventRecorder.clear();

        // Second anchor (drag - Bezier)
        penTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(200, 100),
        ));
        penTool.onPointerMove(PointerMoveEvent(
          position: const ui.Offset(250, 150),
        ));
        penTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(250, 150),
        ));

        // Third anchor (drag - Bezier)
        penTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(300, 200),
        ));
        penTool.onPointerMove(PointerMoveEvent(
          position: const ui.Offset(350, 150),
        ));
        penTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(350, 150),
        ));

        // Should have 2 AddAnchorEvent events
        expect(eventRecorder.recordedEvents.length, equals(2));
        expect(eventRecorder.recordedEvents.every((e) => e is AddAnchorEvent),
            isTrue);

        // Both should be Bezier anchors
        final anchor1 = eventRecorder.recordedEvents[0] as AddAnchorEvent;
        final anchor2 = eventRecorder.recordedEvents[1] as AddAnchorEvent;

        expect(anchor1.anchorType, equals(AnchorType.bezier));
        expect(anchor1.handleOut, isNotNull);
        expect(anchor1.handleIn, isNotNull);

        expect(anchor2.anchorType, equals(AnchorType.bezier));
        expect(anchor2.handleOut, isNotNull);
        expect(anchor2.handleIn, isNotNull);
      });
    });

    group('Mixed Straight and Bezier Anchors', () {
      setUp(() {
        penTool.onActivate();
        eventRecorder.clear();
      });

      test('should create path with alternating line and Bezier anchors', () {
        // First anchor (click - creates path)
        penTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(100, 100),
        ));
        penTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(100, 100),
        ));

        eventRecorder.clear();

        // Second anchor (click - straight line)
        penTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(200, 100),
        ));
        penTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(200, 100),
        ));

        // Third anchor (drag - Bezier)
        penTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(300, 100),
        ));
        penTool.onPointerMove(PointerMoveEvent(
          position: const ui.Offset(350, 150),
        ));
        penTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(350, 150),
        ));

        // Fourth anchor (click - straight line)
        penTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(400, 100),
        ));
        penTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(400, 100),
        ));

        // Should have 3 AddAnchorEvent events
        expect(eventRecorder.recordedEvents.length, equals(3));

        final anchor1 = eventRecorder.recordedEvents[0] as AddAnchorEvent;
        final anchor2 = eventRecorder.recordedEvents[1] as AddAnchorEvent;
        final anchor3 = eventRecorder.recordedEvents[2] as AddAnchorEvent;

        // First should be line
        expect(anchor1.anchorType, equals(AnchorType.line));
        expect(anchor1.handleOut, isNull);

        // Second should be Bezier
        expect(anchor2.anchorType, equals(AnchorType.bezier));
        expect(anchor2.handleOut, isNotNull);

        // Third should be line
        expect(anchor3.anchorType, equals(AnchorType.line));
        expect(anchor3.handleOut, isNull);
      });
    });

    group('State Cleanup', () {
      test('should clear drag state on tool deactivation mid-drag', () {
        penTool.onActivate();
        eventRecorder.clear();

        // Start a path
        penTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(100, 100),
        ));
        penTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(100, 100),
        ));

        eventRecorder.clear();

        // Start dragging
        penTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(200, 100),
        ));
        penTool.onPointerMove(PointerMoveEvent(
          position: const ui.Offset(250, 100),
        ));

        // Deactivate before pointer up
        penTool.onDeactivate();

        // Should finish path gracefully (no crash)
        expect(eventRecorder.recordedEvents.length, greaterThan(0));

        // Re-activate should work without issues
        expect(() => penTool.onActivate(), returnsNormally);
      });
    });

    group('Deterministic Replay', () {
      test('should emit events that can be replayed deterministically', () {
        penTool.onActivate();
        eventRecorder.clear();

        // Create path
        penTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(100, 100),
        ));
        penTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(100, 100),
        ));

        // Add Bezier anchor
        penTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(200, 150),
        ));
        penTool.onPointerMove(PointerMoveEvent(
          position: const ui.Offset(250, 100),
        ));
        penTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(250, 100),
        ));

        final events = List<EventBase>.from(eventRecorder.recordedEvents);

        // Clear and replay events
        eventRecorder.clear();

        // Events should contain all necessary data for deterministic replay
        final createPath = events.firstWhere((e) => e is CreatePathEvent) as CreatePathEvent;
        final addAnchor = events.firstWhere((e) => e is AddAnchorEvent) as AddAnchorEvent;

        // Verify CreatePathEvent has complete data
        expect(createPath.pathId, isNotEmpty);
        expect(createPath.startAnchor.x, equals(100.0));
        expect(createPath.startAnchor.y, equals(100.0));

        // Verify AddAnchorEvent has complete data for Bezier curve
        expect(addAnchor.pathId, equals(createPath.pathId));
        expect(addAnchor.position.x, equals(200.0));
        expect(addAnchor.position.y, equals(150.0));
        expect(addAnchor.handleOut!.x, equals(50.0));
        expect(addAnchor.handleOut!.y, equals(-50.0));
        expect(addAnchor.handleIn!.x, equals(-50.0));
        expect(addAnchor.handleIn!.y, equals(50.0));

        // Handles as relative offsets ensure coordinate-system independence
        // Replaying these events should produce identical geometry
      });
    });
  });
}
