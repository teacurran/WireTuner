import 'dart:ui' as ui;
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

  group('PenTool - Handle Adjustment (I6.T4)', () {
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

    group('Basic Handle Adjustment', () {
      setUp(() {
        penTool.onActivate();
        eventRecorder.clear();

        // Start a path (first click)
        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(100, 100),
        ),);
        penTool.onPointerUp(const PointerUpEvent(
          position: ui.Offset(100, 100),
        ),);
        eventRecorder.clear();

        // Add Bezier anchor with initial handles (drag)
        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(200, 100),
        ),);
        penTool.onPointerMove(const PointerMoveEvent(
          position: ui.Offset(250, 150),
        ),);
        penTool.onPointerUp(const PointerUpEvent(
          position: ui.Offset(250, 150),
        ),);
        eventRecorder.clear();
      });

      test('should emit ModifyAnchorEvent when adjusting handles', () {
        // Click last anchor to enter adjustment mode
        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(200, 100),
        ),);

        // Drag to adjust handles
        penTool.onPointerMove(const PointerMoveEvent(
          position: ui.Offset(240, 120),
        ),);

        // Release to commit adjustment
        penTool.onPointerUp(const PointerUpEvent(
          position: ui.Offset(240, 120),
        ),);

        // Should have emitted one ModifyAnchorEvent
        expect(eventRecorder.recordedEvents.length, equals(1));

        final modify = eventRecorder.recordedEvents[0] as ModifyAnchorEvent;
        expect(modify.eventType, equals('ModifyAnchorEvent'));
        expect(modify.pathId, isNotNull);
        expect(modify.anchorIndex, equals(1)); // Second anchor (0-based)
        expect(modify.handleOut, isNotNull);
        expect(modify.handleIn, isNotNull); // Smooth mode by default
      });

      test('should calculate handleOut as relative offset', () {
        // Click last anchor at (200, 100)
        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(200, 100),
        ),);

        // Drag to (240, 120)
        penTool.onPointerMove(const PointerMoveEvent(
          position: ui.Offset(240, 120),
        ),);

        penTool.onPointerUp(const PointerUpEvent(
          position: ui.Offset(240, 120),
        ),);

        final modify = eventRecorder.recordedEvents[0] as ModifyAnchorEvent;

        // handleOut should be relative offset: (240-200, 120-100) = (40, 20)
        expect(modify.handleOut!.x, equals(40.0));
        expect(modify.handleOut!.y, equals(20.0));
      });

      test('should create symmetric handles with mirrored handleIn by default', () {
        // Adjust handles without Alt key
        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(200, 100),
        ),);
        penTool.onPointerMove(const PointerMoveEvent(
          position: ui.Offset(240, 120),
        ),);
        penTool.onPointerUp(const PointerUpEvent(
          position: ui.Offset(240, 120),
        ),);

        final modify = eventRecorder.recordedEvents[0] as ModifyAnchorEvent;

        // Symmetric handles: handleIn should be mirrored (-handleOut)
        // anchorType is null when only modifying handles
        expect(modify.anchorType, isNull);
        expect(modify.handleOut!.x, equals(40.0));
        expect(modify.handleOut!.y, equals(20.0));
        expect(modify.handleIn!.x, equals(-40.0));
        expect(modify.handleIn!.y, equals(-20.0));
      });

      test('should use correct anchor index', () {
        // Add another anchor before adjusting
        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(300, 200),
        ),);
        penTool.onPointerUp(const PointerUpEvent(
          position: ui.Offset(300, 200),
        ),);

        eventRecorder.clear();

        // Now adjust last anchor (index 2)
        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(300, 200),
        ),);
        penTool.onPointerMove(const PointerMoveEvent(
          position: ui.Offset(320, 220),
        ),);
        penTool.onPointerUp(const PointerUpEvent(
          position: ui.Offset(320, 220),
        ),);

        final modify = eventRecorder.recordedEvents[0] as ModifyAnchorEvent;

        // Third anchor should have index 2 (0-based)
        expect(modify.anchorIndex, equals(2));
      });

      test('should return to creating path state after adjustment', () {
        // Click last anchor
        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(200, 100),
        ),);
        penTool.onPointerMove(const PointerMoveEvent(
          position: ui.Offset(240, 120),
        ),);
        penTool.onPointerUp(const PointerUpEvent(
          position: ui.Offset(240, 120),
        ),);

        eventRecorder.clear();

        // Should be able to add another anchor
        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(300, 100),
        ),);
        penTool.onPointerUp(const PointerUpEvent(
          position: ui.Offset(300, 100),
        ),);

        // Should have emitted AddAnchorEvent (not ModifyAnchorEvent)
        expect(eventRecorder.recordedEvents.length, equals(1));
        expect(eventRecorder.recordedEvents[0], isA<AddAnchorEvent>());
      });
    });

    group('Alt Key Toggle for Corner Anchors', () {
      setUp(() {
        penTool.onActivate();
        eventRecorder.clear();

        // Start a path with Bezier anchor
        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(100, 100),
        ),);
        penTool.onPointerUp(const PointerUpEvent(
          position: ui.Offset(100, 100),
        ),);

        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(200, 100),
        ),);
        penTool.onPointerMove(const PointerMoveEvent(
          position: ui.Offset(250, 150),
        ),);
        penTool.onPointerUp(const PointerUpEvent(
          position: ui.Offset(250, 150),
        ),);

        eventRecorder.clear();
      });

      testWidgets('should create independent handles when Alt pressed during adjustment',
          (tester) async {
        // Simulate Alt key pressed
        await tester.sendKeyDownEvent(LogicalKeyboardKey.alt);

        // Adjust handles with Alt key
        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(200, 100),
        ),);
        penTool.onPointerMove(const PointerMoveEvent(
          position: ui.Offset(240, 120),
        ),);
        penTool.onPointerUp(const PointerUpEvent(
          position: ui.Offset(240, 120),
        ),);

        final modify = eventRecorder.recordedEvents[0] as ModifyAnchorEvent;

        // Independent handles: handleIn should be null
        expect(modify.handleOut, isNotNull);
        expect(modify.handleOut!.x, equals(40.0));
        expect(modify.handleOut!.y, equals(20.0));
        expect(modify.handleIn, isNull);

        // Release Alt key
        await tester.sendKeyUpEvent(LogicalKeyboardKey.alt);
      });

      testWidgets('should create symmetric handles when Alt not pressed',
          (tester) async {
        // Adjust handles without Alt key
        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(200, 100),
        ),);
        penTool.onPointerMove(const PointerMoveEvent(
          position: ui.Offset(240, 120),
        ),);
        penTool.onPointerUp(const PointerUpEvent(
          position: ui.Offset(240, 120),
        ),);

        final modify = eventRecorder.recordedEvents[0] as ModifyAnchorEvent;

        // Symmetric handles: handleIn should be mirrored
        expect(modify.handleOut, isNotNull);
        expect(modify.handleIn, isNotNull);
        expect(modify.handleIn!.x, equals(-modify.handleOut!.x));
        expect(modify.handleIn!.y, equals(-modify.handleOut!.y));
      });
    });

    group('Multiple Adjustments', () {
      setUp(() {
        penTool.onActivate();
        eventRecorder.clear();

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
        penTool.onPointerMove(const PointerMoveEvent(
          position: ui.Offset(250, 150),
        ),);
        penTool.onPointerUp(const PointerUpEvent(
          position: ui.Offset(250, 150),
        ),);

        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(300, 100),
        ),);
        penTool.onPointerMove(const PointerMoveEvent(
          position: ui.Offset(350, 150),
        ),);
        penTool.onPointerUp(const PointerUpEvent(
          position: ui.Offset(350, 150),
        ),);

        eventRecorder.clear();
      });

      test('should allow multiple adjustments on same anchor', () {
        // First adjustment
        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(300, 100),
        ),);
        penTool.onPointerMove(const PointerMoveEvent(
          position: ui.Offset(320, 120),
        ),);
        penTool.onPointerUp(const PointerUpEvent(
          position: ui.Offset(320, 120),
        ),);

        expect(eventRecorder.recordedEvents.length, equals(1));
        final modify1 = eventRecorder.recordedEvents[0] as ModifyAnchorEvent;
        expect(modify1.anchorIndex, equals(2));
        expect(modify1.handleOut!.x, equals(20.0));
        expect(modify1.handleOut!.y, equals(20.0));

        eventRecorder.clear();

        // Second adjustment on same anchor
        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(300, 100),
        ),);
        penTool.onPointerMove(const PointerMoveEvent(
          position: ui.Offset(330, 110),
        ),);
        penTool.onPointerUp(const PointerUpEvent(
          position: ui.Offset(330, 110),
        ),);

        expect(eventRecorder.recordedEvents.length, equals(1));
        final modify2 = eventRecorder.recordedEvents[0] as ModifyAnchorEvent;
        expect(modify2.anchorIndex, equals(2)); // Same anchor
        expect(modify2.handleOut!.x, equals(30.0));
        expect(modify2.handleOut!.y, equals(10.0));
      });

      test('should track each adjustment as separate event', () {
        // First adjustment
        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(300, 100),
        ),);
        penTool.onPointerMove(const PointerMoveEvent(
          position: ui.Offset(320, 120),
        ),);
        penTool.onPointerUp(const PointerUpEvent(
          position: ui.Offset(320, 120),
        ),);

        // Second adjustment
        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(300, 100),
        ),);
        penTool.onPointerMove(const PointerMoveEvent(
          position: ui.Offset(330, 110),
        ),);
        penTool.onPointerUp(const PointerUpEvent(
          position: ui.Offset(330, 110),
        ),);

        // Should have 2 ModifyAnchorEvent events
        expect(eventRecorder.recordedEvents.length, equals(2));
        expect(eventRecorder.recordedEvents.every((e) => e is ModifyAnchorEvent),
            isTrue,);
      });
    });

    group('Click Distance Threshold', () {
      setUp(() {
        penTool.onActivate();
        eventRecorder.clear();

        // Create path with Bezier anchor
        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(100, 100),
        ),);
        penTool.onPointerUp(const PointerUpEvent(
          position: ui.Offset(100, 100),
        ),);

        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(200, 100),
        ),);
        penTool.onPointerMove(const PointerMoveEvent(
          position: ui.Offset(250, 150),
        ),);
        penTool.onPointerUp(const PointerUpEvent(
          position: ui.Offset(250, 150),
        ),);

        eventRecorder.clear();
      });

      test('should enter adjustment mode when clicking within threshold (10px)', () {
        // Click 5px away from anchor (within threshold)
        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(205, 100),
        ),);
        penTool.onPointerMove(const PointerMoveEvent(
          position: ui.Offset(240, 120),
        ),);
        penTool.onPointerUp(const PointerUpEvent(
          position: ui.Offset(240, 120),
        ),);

        // Should emit ModifyAnchorEvent
        expect(eventRecorder.recordedEvents.length, equals(1));
        expect(eventRecorder.recordedEvents[0], isA<ModifyAnchorEvent>());
      });

      test('should create new anchor when clicking outside threshold', () {
        // Click 20px away from anchor (outside threshold)
        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(220, 100),
        ),);
        penTool.onPointerUp(const PointerUpEvent(
          position: ui.Offset(220, 100),
        ),);

        // Should emit AddAnchorEvent (new anchor)
        expect(eventRecorder.recordedEvents.length, equals(1));
        expect(eventRecorder.recordedEvents[0], isA<AddAnchorEvent>());
      });
    });

    group('Integration with Path Creation', () {
      test('should integrate handle adjustment into path creation workflow', () {
        penTool.onActivate();
        eventRecorder.clear();

        // Start path
        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(100, 100),
        ),);
        penTool.onPointerUp(const PointerUpEvent(
          position: ui.Offset(100, 100),
        ),);

        // Add Bezier anchor
        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(200, 100),
        ),);
        penTool.onPointerMove(const PointerMoveEvent(
          position: ui.Offset(250, 150),
        ),);
        penTool.onPointerUp(const PointerUpEvent(
          position: ui.Offset(250, 150),
        ),);

        // Adjust handles on last anchor
        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(200, 100),
        ),);
        penTool.onPointerMove(const PointerMoveEvent(
          position: ui.Offset(240, 120),
        ),);
        penTool.onPointerUp(const PointerUpEvent(
          position: ui.Offset(240, 120),
        ),);

        // Add another anchor
        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(300, 100),
        ),);
        penTool.onPointerUp(const PointerUpEvent(
          position: ui.Offset(300, 100),
        ),);

        // Finish path
        penTool.onKeyPress(const KeyDownEvent(
          logicalKey: LogicalKeyboardKey.enter,
          timeStamp: Duration.zero,
          physicalKey: PhysicalKeyboardKey.enter,
        ),);

        // Event sequence:
        // 1. StartGroupEvent
        // 2. CreatePathEvent
        // 3. AddAnchorEvent (Bezier)
        // 4. ModifyAnchorEvent (handle adjustment)
        // 5. AddAnchorEvent (third anchor)
        // 6. FinishPathEvent
        // 7. EndGroupEvent
        expect(eventRecorder.recordedEvents.length, equals(7));

        expect(eventRecorder.recordedEvents[0], isA<StartGroupEvent>());
        expect(eventRecorder.recordedEvents[1], isA<CreatePathEvent>());
        expect(eventRecorder.recordedEvents[2], isA<AddAnchorEvent>());
        expect(eventRecorder.recordedEvents[3], isA<ModifyAnchorEvent>());
        expect(eventRecorder.recordedEvents[4], isA<AddAnchorEvent>());
        expect(eventRecorder.recordedEvents[5], isA<FinishPathEvent>());
        expect(eventRecorder.recordedEvents[6], isA<EndGroupEvent>());

        // Verify ModifyAnchorEvent details
        final modify = eventRecorder.recordedEvents[3] as ModifyAnchorEvent;
        expect(modify.anchorIndex, equals(1));
        expect(modify.handleOut, isNotNull);
        expect(modify.handleIn, isNotNull);
      });

      test('should allow adjusting different anchors sequentially', () {
        penTool.onActivate();
        eventRecorder.clear();

        // Create path with 3 anchors
        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(100, 100),
        ),);
        penTool.onPointerUp(const PointerUpEvent(
          position: ui.Offset(100, 100),
        ),);

        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(200, 100),
        ),);
        penTool.onPointerMove(const PointerMoveEvent(
          position: ui.Offset(250, 150),
        ),);
        penTool.onPointerUp(const PointerUpEvent(
          position: ui.Offset(250, 150),
        ),);

        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(300, 100),
        ),);
        penTool.onPointerMove(const PointerMoveEvent(
          position: ui.Offset(350, 150),
        ),);
        penTool.onPointerUp(const PointerUpEvent(
          position: ui.Offset(350, 150),
        ),);

        eventRecorder.clear();

        // Adjust second anchor (index 1)
        penTool.onPointerDown(const PointerDownEvent(
          position: ui.Offset(200, 100),
        ),);
        penTool.onPointerMove(const PointerMoveEvent(
          position: ui.Offset(220, 110),
        ),);
        penTool.onPointerUp(const PointerUpEvent(
          position: ui.Offset(220, 110),
        ),);

        // Note: Currently can only adjust last anchor during path creation
        // This test documents expected behavior (should create new anchor instead)
        expect(eventRecorder.recordedEvents.length, equals(1));
        expect(eventRecorder.recordedEvents[0], isA<AddAnchorEvent>());
      });
    });
  });
}
