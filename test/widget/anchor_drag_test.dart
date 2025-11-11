import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/application/tools/direct_selection/direct_selection_tool.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/domain/document/selection.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/events/path_events.dart';
import 'package:wiretuner/domain/models/anchor_point.dart';
import 'package:wiretuner/domain/models/path.dart' as domain;
import 'package:wiretuner/domain/models/segment.dart';
import 'package:wiretuner/infrastructure/event_sourcing/event_recorder.dart';
import 'package:wiretuner/infrastructure/persistence/event_store.dart';
import 'package:wiretuner/presentation/canvas/painter/path_renderer.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';

/// Mock EventRecorder for testing.
class MockEventRecorder extends EventRecorder {
  MockEventRecorder()
      : super(
          eventStore: _MockEventStore(),
          documentId: 'test-doc',
        );
  final List<EventBase> recordedEvents = [];
  int flushCallCount = 0;

  @override
  void recordEvent(EventBase event) {
    if (!isPaused) {
      recordedEvents.add(event);
    }
  }

  @override
  void flush() {
    flushCallCount++;
  }

  void clear() {
    recordedEvents.clear();
    flushCallCount = 0;
  }
}

class _MockEventStore implements EventStore {
  @override
  Future<int> insertEvent(String documentId, EventBase event) async => 1;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DirectSelectionTool - Anchor Drag with Snapping', () {
    late DirectSelectionTool tool;
    late ViewportController viewportController;
    late MockEventRecorder eventRecorder;
    late PathRenderer pathRenderer;
    late Document document;

    setUp(() {
      viewportController = ViewportController(
        initialPan: const Offset(0, 0),
        initialZoom: 1.0,
      );
      eventRecorder = MockEventRecorder();
      pathRenderer = PathRenderer();

      // Create test path with smooth anchor at (200, 200)
      final smoothAnchor = AnchorPoint.smooth(
        position: const Point(x: 200, y: 200),
        handleOut: const Point(x: 50, y: 0),
      );

      final path1 = domain.Path(
        anchors: [
          const AnchorPoint(position: Point(x: 100, y: 100)),
          smoothAnchor,
        ],
        segments: [
          Segment.line(startIndex: 0, endIndex: 1),
        ],
        closed: false,
      );

      final layer = Layer(
        id: 'layer-1',
        name: 'Test Layer',
        objects: [
          VectorObject.path(id: 'path-1', path: path1),
        ],
      );

      document = Document(
        id: 'test-doc',
        layers: [layer],
        selection: const Selection(objectIds: {'path-1'}),
      );

      tool = DirectSelectionTool(
        document: document,
        viewportController: viewportController,
        eventRecorder: eventRecorder,
        pathRenderer: pathRenderer,
      );

      tool.onActivate();
    });

    tearDown(() {
      tool.onDeactivate();
    });

    test('anchor drag with Shift key snaps to grid', () {
      // Start drag on anchor at (200, 200)
      const downEvent = PointerDownEvent(
        position: Offset(200, 200),
      );
      tool.onPointerDown(downEvent);

      // Press Shift to enable snapping
      const shiftDownEvent = KeyDownEvent(
        logicalKey: LogicalKeyboardKey.shiftLeft,
        physicalKey: PhysicalKeyboardKey.shiftLeft,
        timeStamp: Duration(milliseconds: 0),
      );
      tool.onKeyPress(shiftDownEvent);

      // Drag by (12.3, 5.7) - should snap to (10, 10)
      const moveEvent = PointerMoveEvent(
        position: Offset(212.3, 205.7),
      );
      tool.onPointerMove(moveEvent);

      // Release Shift
      const shiftUpEvent = KeyUpEvent(
        logicalKey: LogicalKeyboardKey.shiftLeft,
        physicalKey: PhysicalKeyboardKey.shiftLeft,
        timeStamp: Duration(milliseconds: 10),
      );
      tool.onKeyPress(shiftUpEvent);

      // End drag
      const upEvent = PointerUpEvent();
      tool.onPointerUp(upEvent);

      // Verify events emitted
      final modifyEvents =
          eventRecorder.recordedEvents.whereType<ModifyAnchorEvent>().toList();

      expect(modifyEvents, isNotEmpty);

      // Verify final position snapped to grid (200 + 10, 200 + 10) = (210, 210)
      final finalEvent = modifyEvents.last;
      expect(finalEvent.position!.x, closeTo(210.0, 1.0));
      expect(finalEvent.position!.y, closeTo(210.0, 1.0));

      // Verify flush called
      expect(eventRecorder.flushCallCount, equals(1));
    });

    test('anchor drag without Shift does not snap', () {
      // Start drag on anchor at (200, 200)
      const downEvent = PointerDownEvent(
        position: Offset(200, 200),
      );
      tool.onPointerDown(downEvent);

      // Drag by (12.3, 5.7) WITHOUT Shift
      const moveEvent = PointerMoveEvent(
        position: Offset(212.3, 205.7),
      );
      tool.onPointerMove(moveEvent);

      // End drag
      const upEvent = PointerUpEvent();
      tool.onPointerUp(upEvent);

      // Verify events emitted
      final modifyEvents =
          eventRecorder.recordedEvents.whereType<ModifyAnchorEvent>().toList();

      expect(modifyEvents, isNotEmpty);

      // Verify final position NOT snapped (200 + 12.3, 200 + 5.7) = (212.3, 205.7)
      final finalEvent = modifyEvents.last;
      expect(finalEvent.position!.x, closeTo(212.3, 1.0));
      expect(finalEvent.position!.y, closeTo(205.7, 1.0));
    });

    test('handle drag with Shift snaps to 15° increments', () {
      // Start drag on handleOut at (250, 200) [anchor at (200, 200) + handle (50, 0)]
      const downEvent = PointerDownEvent(
        position: Offset(250, 200),
      );
      tool.onPointerDown(downEvent);

      // Press Shift to enable snapping
      const shiftDownEvent = KeyDownEvent(
        logicalKey: LogicalKeyboardKey.shiftLeft,
        physicalKey: PhysicalKeyboardKey.shiftLeft,
        timeStamp: Duration(milliseconds: 0),
      );
      tool.onKeyPress(shiftDownEvent);

      // Drag to create ~21.8° angle: (250, 200) -> (250, 220)
      // Original handleOut is (50, 0), drag by (0, 20) = (50, 20)
      // Angle = atan2(20, 50) = ~21.8°
      const moveEvent = PointerMoveEvent(
        position: Offset(250, 220),
      );
      tool.onPointerMove(moveEvent);

      // Release Shift
      const shiftUpEvent = KeyUpEvent(
        logicalKey: LogicalKeyboardKey.shiftLeft,
        physicalKey: PhysicalKeyboardKey.shiftLeft,
        timeStamp: Duration(milliseconds: 10),
      );
      tool.onKeyPress(shiftUpEvent);

      // End drag
      const upEvent = PointerUpEvent();
      tool.onPointerUp(upEvent);

      // Verify events emitted
      final modifyEvents =
          eventRecorder.recordedEvents.whereType<ModifyAnchorEvent>().toList();

      expect(modifyEvents, isNotEmpty);

      // Calculate angle of final handleOut
      final finalEvent = modifyEvents.last;
      final handleOut = finalEvent.handleOut!;
      final angle = math.atan2(handleOut.y, handleOut.x) * (180.0 / math.pi);
      final normalizedAngle = angle < 0 ? angle + 360.0 : angle;

      // Should snap to 15° (nearest 15° increment to ~21.8°)
      expect(normalizedAngle, closeTo(15.0, 2.0));

      // Verify smooth anchor constraint: handleIn = -handleOut
      final handleIn = finalEvent.handleIn!;
      expect(handleIn.x, closeTo(-handleOut.x, 0.1));
      expect(handleIn.y, closeTo(-handleOut.y, 0.1));
    });

    test('verifies event emission cadence for 1-second drag', () {
      // This test simulates a 1-second drag to verify ~20 events/sec cadence

      // Start drag
      const downEvent = PointerDownEvent(
        position: Offset(200, 200),
        timeStamp: Duration(milliseconds: 0),
      );
      tool.onPointerDown(downEvent);

      // Emit 20 move events at 50ms intervals (1 second total)
      for (int i = 1; i <= 20; i++) {
        final moveEvent = PointerMoveEvent(
          position: Offset(200.0 + i * 5, 200.0),
          timeStamp: Duration(milliseconds: i * 50),
        );
        tool.onPointerMove(moveEvent);
      }

      // End drag
      const upEvent = PointerUpEvent(
        timeStamp: Duration(milliseconds: 1000),
      );
      tool.onPointerUp(upEvent);

      // Verify event count (should be 18-22 events for 1 second)
      final modifyEvents =
          eventRecorder.recordedEvents.whereType<ModifyAnchorEvent>().toList();

      expect(modifyEvents.length, greaterThanOrEqualTo(18));
      expect(modifyEvents.length, lessThanOrEqualTo(22));
    });

    test('verifies no mutations outside event pipeline', () {
      // Get original anchor state
      final originalPath = document.layers.first.objects.first.when(
        path: (id, path, _) => path,
        shape: (id, shape, _) => shape.toPath(),
      );
      final originalAnchor = originalPath.anchors[1];
      final originalPosition = originalAnchor.position;

      // Start and end drag
      tool.onPointerDown(const PointerDownEvent(position: Offset(200, 200)));
      tool.onPointerMove(const PointerMoveEvent(position: Offset(210, 210)));
      tool.onPointerUp(const PointerUpEvent());

      // Verify document not mutated (would only change after event replay)
      final currentPath = document.layers.first.objects.first.when(
        path: (id, path, _) => path,
        shape: (id, shape, _) => shape.toPath(),
      );
      final currentAnchor = currentPath.anchors[1];

      // Document should remain unchanged (events are recorded but not applied here)
      expect(currentAnchor.position, equals(originalPosition));
    });

    test('Shift toggle mid-drag switches snap behavior', () {
      // Start drag
      tool.onPointerDown(const PointerDownEvent(position: Offset(200, 200)));

      // Drag without Shift (no snap)
      tool.onPointerMove(
          const PointerMoveEvent(position: Offset(212.3, 205.7)));

      final eventsBeforeShift =
          eventRecorder.recordedEvents.whereType<ModifyAnchorEvent>().length;

      // Press Shift mid-drag
      tool.onKeyPress(
        const KeyDownEvent(
          logicalKey: LogicalKeyboardKey.shiftLeft,
          physicalKey: PhysicalKeyboardKey.shiftLeft,
          timeStamp: Duration(milliseconds: 50),
        ),
      );

      // Drag with Shift (should snap)
      tool.onPointerMove(
          const PointerMoveEvent(position: Offset(222.3, 215.7)));

      // Release Shift
      tool.onKeyPress(
        const KeyUpEvent(
          logicalKey: LogicalKeyboardKey.shiftLeft,
          physicalKey: PhysicalKeyboardKey.shiftLeft,
          timeStamp: Duration(milliseconds: 100),
        ),
      );

      // End drag
      tool.onPointerUp(const PointerUpEvent());

      // Verify multiple events emitted
      final totalEvents =
          eventRecorder.recordedEvents.whereType<ModifyAnchorEvent>().length;

      expect(totalEvents, greaterThan(eventsBeforeShift));
    });
  });

  group('DirectSelectionTool - Multi-Anchor Adjustment (Future)', () {
    test(
      'multi-anchor drag with snapping',
      () {
        // TODO: Implement in I4.T5 (Multi-Selection Support)
        // This test verifies that dragging multiple selected anchors
        // applies snapping consistently to all anchors
      },
      skip: 'Deferred to I4.T5',
    );
  });
}
