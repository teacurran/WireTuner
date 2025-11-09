import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
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

  group('PenTool - Path Closing', () {
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

      penTool.onActivate();
    });

    tearDown(() {
      viewportController.dispose();
    });

    test('should close path when clicking on first anchor', () {
      // Create a triangular path: A -> B -> C -> click on A to close
      const pointA = ui.Offset(100, 100);
      const pointB = ui.Offset(200, 100);
      const pointC = ui.Offset(150, 200);

      // Click at point A (start path)
      penTool.onPointerDown(const PointerDownEvent(
        position: pointA,
      ));
      penTool.onPointerUp(const PointerUpEvent(
        position: pointA,
      ));

      // Click at point B
      penTool.onPointerDown(const PointerDownEvent(
        position: pointB,
      ));
      penTool.onPointerUp(const PointerUpEvent(
        position: pointB,
      ));

      // Click at point C
      penTool.onPointerDown(const PointerDownEvent(
        position: pointC,
      ));
      penTool.onPointerUp(const PointerUpEvent(
        position: pointC,
      ));

      // Click back on point A to close the path
      penTool.onPointerDown(const PointerDownEvent(
        position: pointA,
      ));

      // Verify events
      expect(eventRecorder.recordedEvents.length, equals(6));

      // Event 0: StartGroupEvent
      expect(eventRecorder.recordedEvents[0], isA<StartGroupEvent>());

      // Event 1: CreatePathEvent (first anchor at A)
      expect(eventRecorder.recordedEvents[1], isA<CreatePathEvent>());
      final createEvent = eventRecorder.recordedEvents[1] as CreatePathEvent;
      expect(createEvent.startAnchor.x, closeTo(100, 0.1));
      expect(createEvent.startAnchor.y, closeTo(100, 0.1));

      // Event 2: AddAnchorEvent (anchor at B)
      expect(eventRecorder.recordedEvents[2], isA<AddAnchorEvent>());
      final addEventB = eventRecorder.recordedEvents[2] as AddAnchorEvent;
      expect(addEventB.position.x, closeTo(200, 0.1));
      expect(addEventB.position.y, closeTo(100, 0.1));

      // Event 3: AddAnchorEvent (anchor at C)
      expect(eventRecorder.recordedEvents[3], isA<AddAnchorEvent>());
      final addEventC = eventRecorder.recordedEvents[3] as AddAnchorEvent;
      expect(addEventC.position.x, closeTo(150, 0.1));
      expect(addEventC.position.y, closeTo(200, 0.1));

      // Event 4: FinishPathEvent (closed = true)
      expect(eventRecorder.recordedEvents[4], isA<FinishPathEvent>());
      final finishEvent = eventRecorder.recordedEvents[4] as FinishPathEvent;
      expect(finishEvent.closed, isTrue);

      // Event 5: EndGroupEvent
      expect(eventRecorder.recordedEvents[5], isA<EndGroupEvent>());

      // Verify flush was called
      expect(eventRecorder.flushCallCount, equals(1));
    });

    test('should not close path with less than 3 anchors', () {
      // Try to create a "closed" path with only 2 anchors: A -> B -> click on A
      const pointA = ui.Offset(100, 100);
      const pointB = ui.Offset(200, 100);

      // Click at point A (start path)
      penTool.onPointerDown(const PointerDownEvent(
        position: pointA,
      ));
      penTool.onPointerUp(const PointerUpEvent(
        position: pointA,
      ));

      // Click at point B
      penTool.onPointerDown(const PointerDownEvent(
        position: pointB,
      ));
      penTool.onPointerUp(const PointerUpEvent(
        position: pointB,
      ));

      // Click back on point A - should NOT close (need at least 3 anchors)
      // Instead, it should add another anchor near A
      penTool.onPointerDown(const PointerDownEvent(
        position: pointA,
      ));
      penTool.onPointerUp(const PointerUpEvent(
        position: pointA,
      ));

      // Should have 3 events: StartGroup, CreatePath, AddAnchor (for B), AddAnchor (near A)
      // But NOT FinishPath yet
      expect(eventRecorder.recordedEvents.length, equals(4));
      expect(eventRecorder.recordedEvents[0], isA<StartGroupEvent>());
      expect(eventRecorder.recordedEvents[1], isA<CreatePathEvent>());
      expect(eventRecorder.recordedEvents[2], isA<AddAnchorEvent>());
      expect(eventRecorder.recordedEvents[3], isA<AddAnchorEvent>());

      // No FinishPathEvent yet
      expect(
        eventRecorder.recordedEvents.any((e) => e is FinishPathEvent),
        isFalse,
      );
    });

    test('should close path only when clicking within threshold of first anchor', () {
      // Create a path with 3 anchors, then click NEAR (but outside threshold) first anchor
      const pointA = ui.Offset(100, 100);
      const pointB = ui.Offset(200, 100);
      const pointC = ui.Offset(150, 200);
      const pointNearA = ui.Offset(115, 115); // 15 units away from A (threshold is 10)

      // Click at point A (start path)
      penTool.onPointerDown(const PointerDownEvent(
        position: pointA,
      ));
      penTool.onPointerUp(const PointerUpEvent(
        position: pointA,
      ));

      // Click at point B
      penTool.onPointerDown(const PointerDownEvent(
        position: pointB,
      ));
      penTool.onPointerUp(const PointerUpEvent(
        position: pointB,
      ));

      // Click at point C
      penTool.onPointerDown(const PointerDownEvent(
        position: pointC,
      ));
      penTool.onPointerUp(const PointerUpEvent(
        position: pointC,
      ));

      // Click near (but outside threshold of) point A - should add new anchor, not close
      penTool.onPointerDown(const PointerDownEvent(
        position: pointNearA,
      ));
      penTool.onPointerUp(const PointerUpEvent(
        position: pointNearA,
      ));

      // Should have 5 events: StartGroup, CreatePath, AddAnchor (B), AddAnchor (C), AddAnchor (near A)
      // But NOT FinishPath
      expect(eventRecorder.recordedEvents.length, equals(5));
      expect(eventRecorder.recordedEvents[0], isA<StartGroupEvent>());
      expect(eventRecorder.recordedEvents[1], isA<CreatePathEvent>());
      expect(eventRecorder.recordedEvents[2], isA<AddAnchorEvent>());
      expect(eventRecorder.recordedEvents[3], isA<AddAnchorEvent>());
      expect(eventRecorder.recordedEvents[4], isA<AddAnchorEvent>());

      // No FinishPathEvent yet
      expect(
        eventRecorder.recordedEvents.any((e) => e is FinishPathEvent),
        isFalse,
      );
    });

    test('should create closed path with correct event sequence', () {
      // Verify the complete event sequence for a closed triangular path
      const pointA = ui.Offset(0, 0);
      const pointB = ui.Offset(100, 0);
      const pointC = ui.Offset(50, 100);

      // Create triangle: A -> B -> C -> close at A
      penTool.onPointerDown(const PointerDownEvent(
        position: pointA,
      ));
      penTool.onPointerUp(const PointerUpEvent(
        position: pointA,
      ));

      penTool.onPointerDown(const PointerDownEvent(
        position: pointB,
      ));
      penTool.onPointerUp(const PointerUpEvent(
        position: pointB,
      ));

      penTool.onPointerDown(const PointerDownEvent(
        position: pointC,
      ));
      penTool.onPointerUp(const PointerUpEvent(
        position: pointC,
      ));

      penTool.onPointerDown(const PointerDownEvent(
        position: pointA,
      ));

      // Verify complete event sequence
      expect(eventRecorder.recordedEvents.length, equals(6));

      final startGroup = eventRecorder.recordedEvents[0] as StartGroupEvent;
      final createPath = eventRecorder.recordedEvents[1] as CreatePathEvent;
      final addAnchorB = eventRecorder.recordedEvents[2] as AddAnchorEvent;
      final addAnchorC = eventRecorder.recordedEvents[3] as AddAnchorEvent;
      final finishPath = eventRecorder.recordedEvents[4] as FinishPathEvent;
      final endGroup = eventRecorder.recordedEvents[5] as EndGroupEvent;

      // Verify group IDs match
      expect(startGroup.groupId, equals(endGroup.groupId));

      // Verify path IDs match
      expect(createPath.pathId, equals(addAnchorB.pathId));
      expect(createPath.pathId, equals(addAnchorC.pathId));
      expect(createPath.pathId, equals(finishPath.pathId));

      // Verify closed flag
      expect(finishPath.closed, isTrue);

      // Verify flush was called
      expect(eventRecorder.flushCallCount, equals(1));
    });
  });
}
