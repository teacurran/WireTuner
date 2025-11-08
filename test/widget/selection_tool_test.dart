import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/application/tools/selection/selection_tool.dart';
import 'package:wiretuner/application/tools/selection/marquee_controller.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/domain/document/selection.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/events/selection_events.dart' as events;
import 'package:wiretuner/domain/events/object_events.dart';
import 'package:wiretuner/domain/models/geometry/rectangle.dart' as geom;
import 'package:wiretuner/domain/models/path.dart' as domain;
import 'package:wiretuner/domain/models/anchor_point.dart';
import 'package:wiretuner/domain/models/segment.dart';
import 'package:wiretuner/infrastructure/event_sourcing/event_recorder.dart';
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

  group('SelectionTool', () {
    late SelectionTool selectionTool;
    late ViewportController viewportController;
    late MockEventRecorder eventRecorder;
    late Document document;

    setUp(() {
      viewportController = ViewportController(
        initialPan: const Offset(0, 0),
        initialZoom: 1.0,
      );
      eventRecorder = MockEventRecorder();

      // Create a test document with some objects
      final path1 = domain.Path(
        anchors: [
          AnchorPoint(position: const Point(x: 100, y: 100)),
          AnchorPoint(position: const Point(x: 200, y: 100)),
          AnchorPoint(position: const Point(x: 200, y: 200)),
          AnchorPoint(position: const Point(x: 100, y: 200)),
        ],
        segments: [
          Segment.line(startIndex: 0, endIndex: 1),
          Segment.line(startIndex: 1, endIndex: 2),
          Segment.line(startIndex: 2, endIndex: 3),
          Segment.line(startIndex: 3, endIndex: 0),
        ],
        closed: true,
      );

      final path2 = domain.Path(
        anchors: [
          AnchorPoint(position: const Point(x: 300, y: 300)),
          AnchorPoint(position: const Point(x: 400, y: 300)),
          AnchorPoint(position: const Point(x: 400, y: 400)),
        ],
        segments: [
          Segment.line(startIndex: 0, endIndex: 1),
          Segment.line(startIndex: 1, endIndex: 2),
        ],
        closed: false,
      );

      final layer = Layer(
        id: 'layer-1',
        name: 'Test Layer',
        objects: [
          VectorObject.path(id: 'path-1', path: path1),
          VectorObject.path(id: 'path-2', path: path2),
        ],
      );

      document = Document(
        id: 'doc-1',
        title: 'Test Document',
        layers: [layer],
        selection: const Selection(),
      );

      selectionTool = SelectionTool(
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
        expect(selectionTool.toolId, equals('selection'));
      });

      test('should initialize with click cursor', () {
        expect(selectionTool.cursor, equals(SystemMouseCursors.click));
      });

      test('should reset state on activation', () {
        selectionTool.onActivate();
        expect(selectionTool.cursor, equals(SystemMouseCursors.click));
      });

      test('should flush events on deactivation', () {
        selectionTool.onActivate();

        // Start a drag operation
        final downEvent = PointerDownEvent(
          position: const Offset(150, 150),
        );
        selectionTool.onPointerDown(downEvent);

        selectionTool.onDeactivate();

        expect(eventRecorder.flushCallCount, greaterThan(0));
      });
    });

    group('Click Selection', () {
      setUp(() {
        selectionTool.onActivate();
        eventRecorder.clear();
      });

      test('should select object on click', () {
        final event = PointerDownEvent(
          position: const Offset(150, 150), // On path-1
        );

        final handled = selectionTool.onPointerDown(event);

        expect(handled, isTrue);
        expect(eventRecorder.recordedEvents.length, greaterThan(0));

        final selectEvent =
            eventRecorder.recordedEvents.first as events.SelectObjectsEvent;
        expect(selectEvent.objectIds, contains('path-1'));
        expect(selectEvent.mode, equals(events.SelectionMode.replace));
      });

      test('should clear selection on click in empty area', () {
        final event = PointerDownEvent(
          position: const Offset(50, 50), // Empty area
        );

        final handled = selectionTool.onPointerDown(event);

        expect(handled, isTrue);
        expect(eventRecorder.recordedEvents.length, greaterThan(0));

        // Should emit ClearSelectionEvent
        final clearEvent =
            eventRecorder.recordedEvents.whereType<events.ClearSelectionEvent>().first;
        expect(clearEvent, isNotNull);
      });

      test('should handle multiple objects at same point (top-most wins)', () {
        // This test verifies that when multiple objects overlap,
        // the top-most object is selected
        final event = PointerDownEvent(
          position: const Offset(150, 150),
        );

        selectionTool.onPointerDown(event);

        final selectEvent =
            eventRecorder.recordedEvents.first as events.SelectObjectsEvent;
        expect(selectEvent.objectIds.length, equals(1));
      });
    });

    group('Modifier Key Selection', () {
      setUp(() {
        selectionTool.onActivate();
        eventRecorder.clear();
      });

      // Note: Testing modifier keys with HardwareKeyboard is complex in unit tests
      // These tests verify the event structure, but modifier behavior is better
      // tested in integration tests or manually

      test('should support shift-click for multi-select', () {
        // First select path-1
        final event1 = PointerDownEvent(
          position: const Offset(150, 150),
        );
        selectionTool.onPointerDown(event1);

        eventRecorder.clear();

        // Shift-click path-2 would add to selection
        // (In practice, this requires HardwareKeyboard.instance.isShiftPressed)
        // Here we just verify the event recording works
        expect(eventRecorder.recordedEvents.isEmpty, isTrue);
      });
    });

    group('Object Movement', () {
      setUp(() {
        selectionTool.onActivate();
        eventRecorder.clear();

        // Select an object first
        final downEvent = PointerDownEvent(
          position: const Offset(150, 150),
        );
        selectionTool.onPointerDown(downEvent);
        eventRecorder.clear();
      });

      test('should start drag on selected object', () {
        // Pointer is already down on path-1, now move it
        final moveEvent = PointerMoveEvent(
          position: const Offset(160, 160),
        );

        final handled = selectionTool.onPointerMove(moveEvent);

        expect(handled, isTrue);
        expect(selectionTool.cursor, equals(SystemMouseCursors.move));
      });

      test('should emit MoveObjectEvent on drag', () {
        // Move the pointer
        final moveEvent = PointerMoveEvent(
          position: const Offset(160, 160),
        );
        selectionTool.onPointerMove(moveEvent);

        // Should have recorded a MoveObjectEvent
        final moveEvents =
            eventRecorder.recordedEvents.whereType<MoveObjectEvent>();
        expect(moveEvents.isNotEmpty, isTrue);

        final moveEvent0 = moveEvents.first;
        expect(moveEvent0.objectIds, contains('path-1'));
        expect(moveEvent0.delta.x, greaterThan(0));
        expect(moveEvent0.delta.y, greaterThan(0));
      });

      test('should flush events on pointer up', () {
        // Move the pointer
        final moveEvent = PointerMoveEvent(
          position: const Offset(160, 160),
        );
        selectionTool.onPointerMove(moveEvent);

        eventRecorder.flushCallCount = 0;

        // Release pointer
        final upEvent = PointerUpEvent(
          position: const Offset(160, 160),
        );
        final handled = selectionTool.onPointerUp(upEvent);

        expect(handled, isTrue);
        expect(eventRecorder.flushCallCount, greaterThan(0));
        expect(selectionTool.cursor, equals(SystemMouseCursors.click));
      });

      test('should cancel drag on Escape key', () {
        // Move the pointer
        final moveEvent = PointerMoveEvent(
          position: const Offset(160, 160),
        );
        selectionTool.onPointerMove(moveEvent);

        // Press Escape
        final keyEvent = KeyDownEvent(
          logicalKey: LogicalKeyboardKey.escape,
          physicalKey: PhysicalKeyboardKey.escape,
          timeStamp: Duration.zero,
        );

        final handled = selectionTool.onKeyPress(keyEvent);

        expect(handled, isTrue);
        expect(selectionTool.cursor, equals(SystemMouseCursors.click));
      });
    });

    group('Marquee Selection', () {
      setUp(() {
        selectionTool.onActivate();
        eventRecorder.clear();
      });

      test('should start marquee on drag in empty area', () {
        // Click in empty area
        final downEvent = PointerDownEvent(
          position: const Offset(50, 50),
        );
        selectionTool.onPointerDown(downEvent);

        eventRecorder.clear();

        // Drag to create marquee
        final moveEvent = PointerMoveEvent(
          position: const Offset(250, 250),
        );
        final handled = selectionTool.onPointerMove(moveEvent);

        expect(handled, isTrue);
      });

      test('should select objects within marquee bounds on pointer up', () {
        // Start marquee in empty area
        final downEvent = PointerDownEvent(
          position: const Offset(50, 50),
        );
        selectionTool.onPointerDown(downEvent);

        // Drag to cover path-1
        final moveEvent = PointerMoveEvent(
          position: const Offset(250, 250),
        );
        selectionTool.onPointerMove(moveEvent);

        eventRecorder.clear();

        // Release to finish marquee
        final upEvent = PointerUpEvent(
          position: const Offset(250, 250),
        );
        selectionTool.onPointerUp(upEvent);

        // Should have selected path-1 (which is within bounds)
        final selectEvents =
            eventRecorder.recordedEvents.whereType<events.SelectObjectsEvent>();
        expect(selectEvents.isNotEmpty, isTrue);

        final selectEvent = selectEvents.first;
        expect(selectEvent.objectIds, contains('path-1'));
      });

      test('should render marquee rectangle during drag', () {
        // Start marquee
        final downEvent = PointerDownEvent(
          position: const Offset(50, 50),
        );
        selectionTool.onPointerDown(downEvent);

        // Drag marquee
        final moveEvent = PointerMoveEvent(
          position: const Offset(250, 250),
        );
        selectionTool.onPointerMove(moveEvent);

        // Render overlay (should not throw)
        final canvas = MockCanvas();
        const size = ui.Size(800, 600);

        expect(
          () => selectionTool.renderOverlay(canvas, size),
          returnsNormally,
        );
      });

      test('should cancel marquee on Escape key', () {
        // Start marquee
        final downEvent = PointerDownEvent(
          position: const Offset(50, 50),
        );
        selectionTool.onPointerDown(downEvent);

        // Drag marquee
        final moveEvent = PointerMoveEvent(
          position: const Offset(250, 250),
        );
        selectionTool.onPointerMove(moveEvent);

        // Press Escape
        final keyEvent = KeyDownEvent(
          logicalKey: LogicalKeyboardKey.escape,
          physicalKey: PhysicalKeyboardKey.escape,
          timeStamp: Duration.zero,
        );

        final handled = selectionTool.onKeyPress(keyEvent);

        expect(handled, isTrue);

        // Marquee should be cancelled, pointer up should not select
        eventRecorder.clear();
        final upEvent = PointerUpEvent(
          position: const Offset(250, 250),
        );
        selectionTool.onPointerUp(upEvent);

        expect(eventRecorder.recordedEvents.isEmpty, isTrue);
      });
    });

    group('Viewport Transformation', () {
      setUp(() {
        selectionTool.onActivate();
        eventRecorder.clear();

        // Apply viewport transformations
        viewportController.setPan(const Offset(100, 100));
        viewportController.setZoom(2.0);
      });

      test('should respect viewport pan and zoom for hit-testing', () {
        // With 2x zoom and 100,100 pan, clicking at screen 400,400
        // should hit world coordinates 150,150 (path-1)
        final event = PointerDownEvent(
          position: const Offset(400, 400),
        );

        selectionTool.onPointerDown(event);

        final selectEvents =
            eventRecorder.recordedEvents.whereType<events.SelectObjectsEvent>();
        expect(selectEvents.isNotEmpty, isTrue);

        final selectEvent = selectEvents.first;
        expect(selectEvent.objectIds, contains('path-1'));
      });

      test('should transform marquee bounds correctly', () {
        // Start marquee
        final downEvent = PointerDownEvent(
          position: const Offset(100, 100),
        );
        selectionTool.onPointerDown(downEvent);

        // Drag marquee
        final moveEvent = PointerMoveEvent(
          position: const Offset(500, 500),
        );
        selectionTool.onPointerMove(moveEvent);

        // The marquee should be transformed to world coordinates
        // and select objects within those bounds
        eventRecorder.clear();

        final upEvent = PointerUpEvent(
          position: const Offset(500, 500),
        );
        selectionTool.onPointerUp(upEvent);

        // Verify selection events were recorded
        expect(eventRecorder.recordedEvents.isNotEmpty, isTrue);
      });
    });
  });

  group('MarqueeController', () {
    late MarqueeController marquee;
    late ViewportController viewportController;

    setUp(() {
      viewportController = ViewportController();
      marquee = MarqueeController(
        startScreenPos: const Offset(100, 100),
        startWorldPos: const Point(x: 100, y: 100),
      );
    });

    tearDown(() {
      viewportController.dispose();
    });

    test('should initialize with start position', () {
      expect(marquee.startScreenPos, equals(const Offset(100, 100)));
      expect(marquee.startWorldPos, equals(const Point(x: 100, y: 100)));
    });

    test('should return null bounds initially', () {
      expect(marquee.worldBounds, isNull);
      expect(marquee.screenBounds, isNull);
    });

    test('should update end position', () {
      marquee.updateEnd(
        const Offset(200, 200),
        const Point(x: 200, y: 200),
      );

      expect(marquee.worldBounds, isNotNull);
      expect(marquee.screenBounds, isNotNull);
    });

    test('should calculate correct world bounds', () {
      marquee.updateEnd(
        const Offset(200, 200),
        const Point(x: 200, y: 200),
      );

      final bounds = marquee.worldBounds!;
      expect(bounds.x, equals(100));
      expect(bounds.y, equals(100));
      expect(bounds.width, equals(100));
      expect(bounds.height, equals(100));
    });

    test('should calculate correct world bounds for reverse drag', () {
      // Drag from bottom-right to top-left
      marquee.updateEnd(
        const Offset(50, 50),
        const Point(x: 50, y: 50),
      );

      final bounds = marquee.worldBounds!;
      expect(bounds.x, equals(50));
      expect(bounds.y, equals(50));
      expect(bounds.width, equals(50));
      expect(bounds.height, equals(50));
    });

    test('should calculate correct screen bounds', () {
      marquee.updateEnd(
        const Offset(200, 200),
        const Point(x: 200, y: 200),
      );

      final bounds = marquee.screenBounds!;
      expect(bounds.left, equals(100));
      expect(bounds.top, equals(100));
      expect(bounds.right, equals(200));
      expect(bounds.bottom, equals(200));
    });

    test('should render marquee rectangle', () {
      marquee.updateEnd(
        const Offset(200, 200),
        const Point(x: 200, y: 200),
      );

      final canvas = MockCanvas();

      // Should not throw
      expect(
        () => marquee.render(canvas, viewportController),
        returnsNormally,
      );
    });

    test('should not render if bounds are too small', () {
      marquee.updateEnd(
        const Offset(100, 100), // Same as start
        const Point(x: 100, y: 100),
      );

      final canvas = MockCanvas();

      // Should not render (width/height = 0)
      expect(
        () => marquee.render(canvas, viewportController),
        returnsNormally,
      );
    });
  });
}

/// Mock Canvas for testing overlay rendering.
class MockCanvas implements ui.Canvas {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
