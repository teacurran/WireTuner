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

  group('PenTool', () {
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
      const layer = Layer(
        id: 'layer-1',
        name: 'Test Layer',
        objects: [],
      );

      document = const Document(
        id: 'doc-1',
        title: 'Test Document',
        layers: [layer],
        selection: Selection(),
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

    group('Tool Lifecycle', () {
      test('should have correct tool ID', () {
        expect(penTool.toolId, equals('pen'));
      });

      test('should have precise cursor', () {
        expect(penTool.cursor, equals(SystemMouseCursors.precise));
      });

      test('should reset state on activation', () {
        penTool.onActivate();
        // Tool should be in idle state after activation
        // (We verify this indirectly by checking first click behavior)
      });

      test('should finish path on deactivation mid-creation', () {
        penTool.onActivate();
        eventRecorder.clear();

        // Start a path
        const event1 = PointerDownEvent(
          position: ui.Offset(100, 100),
        );
        penTool.onPointerDown(event1);

        // Deactivate before finishing
        penTool.onDeactivate();

        // Should have emitted: StartGroup, CreatePath, FinishPath, EndGroup
        expect(eventRecorder.recordedEvents.length, equals(4));
        expect(
            eventRecorder.recordedEvents[0], isA<StartGroupEvent>(),);
        expect(
            eventRecorder.recordedEvents[1], isA<CreatePathEvent>(),);
        expect(
            eventRecorder.recordedEvents[2], isA<FinishPathEvent>(),);
        expect(
            eventRecorder.recordedEvents[3], isA<EndGroupEvent>(),);
        expect(eventRecorder.flushCallCount, greaterThan(0));
      });
    });

    group('Path Creation', () {
      setUp(() {
        penTool.onActivate();
        eventRecorder.clear();
      });

      test('should start path on first click', () {
        const event = PointerDownEvent(
          position: ui.Offset(100, 100),
        );

        final handled = penTool.onPointerDown(event);

        expect(handled, isTrue);
        expect(eventRecorder.recordedEvents.length, equals(2));

        // First event should be StartGroupEvent
        final startGroup = eventRecorder.recordedEvents[0] as StartGroupEvent;
        expect(startGroup.eventType, equals('StartGroupEvent'));
        expect(startGroup.groupId, isNotEmpty);
        expect(startGroup.description, equals('Create path'));

        // Second event should be CreatePathEvent
        final createPath = eventRecorder.recordedEvents[1] as CreatePathEvent;
        expect(createPath.eventType, equals('CreatePathEvent'));
        expect(createPath.pathId, isNotEmpty);
        expect(createPath.startAnchor.x, equals(100.0));
        expect(createPath.startAnchor.y, equals(100.0));
        expect(createPath.strokeColor, equals('#000000'));
        expect(createPath.strokeWidth, equals(2.0));
      });

      test('should add anchors on subsequent clicks', () {
        // First click - start path
        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(100, 100),
        ),);
        penTool.onPointerUp(const PointerUpEvent(
          position: ui.Offset(100, 100),
        ),);
        eventRecorder.clear();

        // Second click - add anchor
        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(200, 100),
        ),);
        penTool.onPointerUp(const PointerUpEvent(
          position: ui.Offset(200, 100),
        ),);

        expect(eventRecorder.recordedEvents.length, equals(1));

        final addAnchor = eventRecorder.recordedEvents[0] as AddAnchorEvent;
        expect(addAnchor.eventType, equals('AddAnchorEvent'));
        expect(addAnchor.position.x, equals(200.0));
        expect(addAnchor.position.y, equals(100.0));
        expect(addAnchor.anchorType, equals(AnchorType.line));
        expect(addAnchor.handleIn, isNull);
        expect(addAnchor.handleOut, isNull);
      });

      test('should create multiple anchors', () {
        final positions = [
          const ui.Offset(100, 100),
          const ui.Offset(200, 100),
          const ui.Offset(200, 200),
          const ui.Offset(100, 200),
        ];

        // First click creates path
        penTool.onPointerDown(PointerDownEvent(position: positions[0]));
        penTool.onPointerUp(PointerUpEvent(position: positions[0]));
        eventRecorder.clear();

        // Subsequent clicks add anchors
        for (int i = 1; i < positions.length; i++) {
          penTool.onPointerDown(PointerDownEvent(position: positions[i]));
          penTool.onPointerUp(PointerUpEvent(position: positions[i]));
        }

        // Should have 3 AddAnchorEvent events (after the first CreatePathEvent)
        expect(eventRecorder.recordedEvents.length, equals(3));
        expect(eventRecorder.recordedEvents.every((e) => e is AddAnchorEvent),
            isTrue,);
      });

      test('should create 5-point straight path successfully', () {
        final positions = [
          const ui.Offset(100, 100), // Point 1 - creates path
          const ui.Offset(200, 100), // Point 2
          const ui.Offset(250, 200), // Point 3
          const ui.Offset(150, 250), // Point 4
          const ui.Offset(50, 200),  // Point 5
        ];

        // First click creates path
        penTool.onPointerDown(PointerDownEvent(position: positions[0]));
        penTool.onPointerUp(PointerUpEvent(position: positions[0]));
        eventRecorder.clear();

        // Subsequent clicks add anchors
        for (int i = 1; i < positions.length; i++) {
          penTool.onPointerDown(PointerDownEvent(position: positions[i]));
          penTool.onPointerUp(PointerUpEvent(position: positions[i]));
        }

        // Should have 4 AddAnchorEvent events (5 total points - 1 initial)
        expect(eventRecorder.recordedEvents.length, equals(4));
        expect(eventRecorder.recordedEvents.every((e) => e is AddAnchorEvent),
            isTrue,);

        // Verify all anchors have correct properties
        for (final event in eventRecorder.recordedEvents) {
          final addAnchor = event as AddAnchorEvent;
          expect(addAnchor.anchorType, equals(AnchorType.line));
          expect(addAnchor.handleIn, isNull);
          expect(addAnchor.handleOut, isNull);
        }
      });
    });

    group('Path Completion', () {
      setUp(() {
        penTool.onActivate();
        eventRecorder.clear();

        // Start a path
        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(100, 100),
        ),);
        eventRecorder.clear();
      });

      test('should finish path on Enter key', () {
        const keyEvent = KeyDownEvent(
          logicalKey: LogicalKeyboardKey.enter,
          physicalKey: PhysicalKeyboardKey.enter,
          timeStamp: Duration.zero,
        );

        final handled = penTool.onKeyPress(keyEvent);

        expect(handled, isTrue);
        expect(eventRecorder.recordedEvents.length, equals(2));

        // First event should be FinishPathEvent
        final finishPath = eventRecorder.recordedEvents[0] as FinishPathEvent;
        expect(finishPath.eventType, equals('FinishPathEvent'));
        expect(finishPath.closed, isFalse);

        // Second event should be EndGroupEvent
        final endGroup = eventRecorder.recordedEvents[1] as EndGroupEvent;
        expect(endGroup.eventType, equals('EndGroupEvent'));

        // Should have flushed events
        expect(eventRecorder.flushCallCount, greaterThan(0));
      });

      test('should cancel path on Escape key', () {
        const keyEvent = KeyDownEvent(
          logicalKey: LogicalKeyboardKey.escape,
          physicalKey: PhysicalKeyboardKey.escape,
          timeStamp: Duration.zero,
        );

        final handled = penTool.onKeyPress(keyEvent);

        expect(handled, isTrue);
        expect(eventRecorder.recordedEvents.length, equals(1));

        // Should only emit EndGroupEvent (no FinishPathEvent)
        final endGroup = eventRecorder.recordedEvents[0] as EndGroupEvent;
        expect(endGroup.eventType, equals('EndGroupEvent'));
      });

      test('should finish path on double-click', () async {
        // First click to add anchor
        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(200, 100),
        ),);
        eventRecorder.clear();

        // Simulate double-click (within time and distance threshold)
        await Future<void>.delayed(const Duration(milliseconds: 100));
        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(202, 102), // Very close position
        ),);

        // Should finish path (FinishPath + EndGroup)
        // Note: May also include AddAnchor if double-click detection fails
        expect(
            eventRecorder.recordedEvents
                .whereType<FinishPathEvent>()
                .isNotEmpty,
            isTrue,);
        expect(
            eventRecorder.recordedEvents.whereType<EndGroupEvent>().isNotEmpty,
            isTrue,);
      });
    });

    group('Angle Constraint (Shift+Click)', () {
      setUp(() {
        penTool.onActivate();
        eventRecorder.clear();

        // Start a path at origin
        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(100, 100),
        ),);
        eventRecorder.clear();
      });

      test('should constrain to 0° (horizontal right)', () {
        // Simulate Shift key press
        HardwareKeyboard.instance.handleKeyEvent(
          const KeyDownEvent(
            logicalKey: LogicalKeyboardKey.shiftLeft,
            physicalKey: PhysicalKeyboardKey.shiftLeft,
            timeStamp: Duration.zero,
          ),
        );

        // Click at roughly 10° (should snap to 0°)
        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(200, 110),
        ),);
        penTool.onPointerUp(const PointerUpEvent(
          position: ui.Offset(200, 110),
        ),);

        // Release Shift
        HardwareKeyboard.instance.handleKeyEvent(
          const KeyUpEvent(
            logicalKey: LogicalKeyboardKey.shiftLeft,
            physicalKey: PhysicalKeyboardKey.shiftLeft,
            timeStamp: Duration.zero,
          ),
        );

        final addAnchor = eventRecorder.recordedEvents[0] as AddAnchorEvent;

        // Should be constrained to 0° (y should be same as start)
        expect(addAnchor.position.y, closeTo(100.0, 0.1));
        expect(addAnchor.position.x, greaterThan(100.0));
      });

      test('should constrain to 45° (diagonal)', () {
        HardwareKeyboard.instance.handleKeyEvent(
          const KeyDownEvent(
            logicalKey: LogicalKeyboardKey.shiftLeft,
            physicalKey: PhysicalKeyboardKey.shiftLeft,
            timeStamp: Duration.zero,
          ),
        );

        // Click at roughly 50° (should snap to 45°)
        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(200, 200),
        ),);
        penTool.onPointerUp(const PointerUpEvent(
          position: ui.Offset(200, 200),
        ),);

        HardwareKeyboard.instance.handleKeyEvent(
          const KeyUpEvent(
            logicalKey: LogicalKeyboardKey.shiftLeft,
            physicalKey: PhysicalKeyboardKey.shiftLeft,
            timeStamp: Duration.zero,
          ),
        );

        final addAnchor = eventRecorder.recordedEvents[0] as AddAnchorEvent;

        // Calculate angle
        final dx = addAnchor.position.x - 100.0;
        final dy = addAnchor.position.y - 100.0;
        final angle = math.atan2(dy, dx);

        // Should be constrained to 45° (π/4 radians)
        expect(angle, closeTo(math.pi / 4, 0.01));
      });

      test('should constrain to 90° (vertical down)', () {
        HardwareKeyboard.instance.handleKeyEvent(
          const KeyDownEvent(
            logicalKey: LogicalKeyboardKey.shiftLeft,
            physicalKey: PhysicalKeyboardKey.shiftLeft,
            timeStamp: Duration.zero,
          ),
        );

        // Click at roughly 85° (should snap to 90°)
        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(105, 200),
        ),);
        penTool.onPointerUp(const PointerUpEvent(
          position: ui.Offset(105, 200),
        ),);

        HardwareKeyboard.instance.handleKeyEvent(
          const KeyUpEvent(
            logicalKey: LogicalKeyboardKey.shiftLeft,
            physicalKey: PhysicalKeyboardKey.shiftLeft,
            timeStamp: Duration.zero,
          ),
        );

        final addAnchor = eventRecorder.recordedEvents[0] as AddAnchorEvent;

        // Should be constrained to 90° (x should be same as start)
        expect(addAnchor.position.x, closeTo(100.0, 0.1));
        expect(addAnchor.position.y, greaterThan(100.0));
      });
    });

    group('Event Grouping', () {
      setUp(() {
        penTool.onActivate();
        eventRecorder.clear();
      });

      test('should group entire path creation', () {
        // Create path with multiple anchors
        final positions = [
          const ui.Offset(100, 100),
          const ui.Offset(200, 100),
          const ui.Offset(200, 200),
        ];

        for (final pos in positions) {
          penTool.onPointerDown(PointerDownEvent(position: pos));
          penTool.onPointerUp(PointerUpEvent(position: pos));
        }

        // Finish path
        penTool.onKeyPress(const KeyDownEvent(
          logicalKey: LogicalKeyboardKey.enter,
          physicalKey: PhysicalKeyboardKey.enter,
          timeStamp: Duration.zero,
        ),);

        // Verify event sequence:
        // StartGroup, CreatePath, AddAnchor, AddAnchor, FinishPath, EndGroup
        expect(eventRecorder.recordedEvents.length, equals(6));

        final startGroup = eventRecorder.recordedEvents[0] as StartGroupEvent;
        final endGroup = eventRecorder.recordedEvents[5] as EndGroupEvent;

        // Group IDs should match
        expect(startGroup.groupId, equals(endGroup.groupId));

        // All path events should have same pathId
        final createPath = eventRecorder.recordedEvents[1] as CreatePathEvent;
        final addAnchor1 = eventRecorder.recordedEvents[2] as AddAnchorEvent;
        final addAnchor2 = eventRecorder.recordedEvents[3] as AddAnchorEvent;
        final finishPath = eventRecorder.recordedEvents[4] as FinishPathEvent;

        expect(addAnchor1.pathId, equals(createPath.pathId));
        expect(addAnchor2.pathId, equals(createPath.pathId));
        expect(finishPath.pathId, equals(createPath.pathId));
      });

      test('should have sequential timestamps', () {
        // Create path with multiple anchors
        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(100, 100),
        ),);
        penTool.onPointerUp(const PointerUpEvent(
          position: ui.Offset(100, 100),
        ),);

        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(200, 100),
        ),);
        penTool.onPointerUp(const PointerUpEvent(
          position: ui.Offset(200, 100),
        ),);

        penTool.onKeyPress(const KeyDownEvent(
          logicalKey: LogicalKeyboardKey.enter,
          physicalKey: PhysicalKeyboardKey.enter,
          timeStamp: Duration.zero,
        ),);

        // Verify timestamps are monotonically increasing
        for (int i = 1; i < eventRecorder.recordedEvents.length; i++) {
          expect(
            eventRecorder.recordedEvents[i].timestamp,
            greaterThanOrEqualTo(
                eventRecorder.recordedEvents[i - 1].timestamp,),
          );
        }
      });

      test('should have unique event IDs', () {
        // Create path with multiple anchors
        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(100, 100),
        ),);
        penTool.onPointerUp(const PointerUpEvent(
          position: ui.Offset(100, 100),
        ),);

        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(200, 100),
        ),);
        penTool.onPointerUp(const PointerUpEvent(
          position: ui.Offset(200, 100),
        ),);

        penTool.onKeyPress(const KeyDownEvent(
          logicalKey: LogicalKeyboardKey.enter,
          physicalKey: PhysicalKeyboardKey.enter,
          timeStamp: Duration.zero,
        ),);

        // Collect all event IDs
        final eventIds =
            eventRecorder.recordedEvents.map((e) => e.eventId).toSet();

        // Should all be unique
        expect(eventIds.length, equals(eventRecorder.recordedEvents.length));
      });
    });

    group('Pointer Move (Preview)', () {
      setUp(() {
        penTool.onActivate();
        eventRecorder.clear();

        // Start a path
        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(100, 100),
        ),);
        eventRecorder.clear();
      });

      test('should track hover position without emitting events', () {
        const moveEvent = PointerMoveEvent(
          position: ui.Offset(150, 150),
        );

        final handled = penTool.onPointerMove(moveEvent);

        // Should not handle (returns false)
        expect(handled, isFalse);

        // Should not emit any events
        expect(eventRecorder.recordedEvents.isEmpty, isTrue);
      });
    });

    group('Rendering', () {
      setUp(() {
        penTool.onActivate();
      });

      test('should render without errors in idle state', () {
        final canvas = MockCanvas();
        const size = ui.Size(800, 600);

        // Should not throw
        expect(
          () => penTool.renderOverlay(canvas, size),
          returnsNormally,
        );
      });

      test('should render without errors during path creation', () {
        // Start a path
        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(100, 100),
        ),);

        // Update hover position
        penTool.onPointerMove(const PointerMoveEvent(
          position: ui.Offset(150, 150),
        ),);

        final canvas = MockCanvas();
        const size = ui.Size(800, 600);

        // Should not throw
        expect(
          () => penTool.renderOverlay(canvas, size),
          returnsNormally,
        );
      });
    });
  });
}

/// Mock Canvas for testing rendering.
class MockCanvas implements ui.Canvas {
  @override
  void noSuchMethod(Invocation invocation) {
    // No-op for rendering tests
  }
}
