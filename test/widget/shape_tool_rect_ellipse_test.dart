import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/application/tools/shapes/rectangle_tool.dart';
import 'package:wiretuner/application/tools/shapes/ellipse_tool.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/domain/document/selection.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/events/object_events.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';

/// Mock EventRecorder for testing.
class MockEventRecorder {
  final List<EventBase> recordedEvents = [];
  int flushCallCount = 0;

  void recordEvent(EventBase event) {
    recordedEvents.add(event);
  }

  void flush() {
    flushCallCount++;
  }

  void clear() {
    recordedEvents.clear();
    flushCallCount = 0;
  }
}

void main() {
  // Initialize Flutter test bindings for HardwareKeyboard support
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RectangleTool', () {
    late RectangleTool rectangleTool;
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

      rectangleTool = RectangleTool(
        document: document,
        viewportController: viewportController,
        eventRecorder: eventRecorder,
      );

      rectangleTool.onActivate();
    });

    tearDown(() {
      rectangleTool.onDeactivate();
      viewportController.dispose();
    });

    group('Basic Drag Interaction', () {
      test('should create rectangle with correct dimensions on drag', () {
        // Drag from (100, 100) to (200, 150)
        rectangleTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(100, 100),
        ));

        rectangleTool.onPointerMove(PointerMoveEvent(
          position: const ui.Offset(200, 150),
        ));

        rectangleTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(200, 150),
        ));

        // Should have emitted one CreateShapeEvent
        expect(eventRecorder.recordedEvents.length, equals(1));

        final createShape =
            eventRecorder.recordedEvents[0] as CreateShapeEvent;
        expect(createShape.eventType, equals('CreateShapeEvent'));
        expect(createShape.shapeType, equals(ShapeType.rectangle));

        // Verify parameters
        final params = createShape.parameters;
        expect(params['centerX'], equals(150.0)); // (100 + 200) / 2
        expect(params['centerY'], equals(125.0)); // (100 + 150) / 2
        expect(params['width'], equals(100.0)); // 200 - 100
        expect(params['height'], equals(50.0)); // 150 - 100
        expect(params['cornerRadius'], equals(0.0));

        // Verify optional style fields
        expect(createShape.strokeColor, equals('#000000'));
        expect(createShape.strokeWidth, equals(2.0));
      });

      test('should normalize dimensions when dragging in any direction', () {
        // Drag from bottom-right to top-left (reverse direction)
        rectangleTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(200, 150),
        ));

        rectangleTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(100, 100),
        ));

        final createShape =
            eventRecorder.recordedEvents[0] as CreateShapeEvent;
        final params = createShape.parameters;

        // Dimensions should still be positive
        expect(params['width'], equals(100.0));
        expect(params['height'], equals(50.0));
        // Center should be the same
        expect(params['centerX'], equals(150.0));
        expect(params['centerY'], equals(125.0));
      });

      test('should not create rectangle if drag distance below threshold', () {
        // Very small drag (< 5px)
        rectangleTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(100, 100),
        ));

        rectangleTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(102, 101),
        ));

        // Should not emit any events
        expect(eventRecorder.recordedEvents.length, equals(0));
      });
    });

    group('Shift Key Constraint', () {
      test('should create square when Shift is pressed', () async {
        // Simulate Shift key press
        await simulateKeyDownEvent(LogicalKeyboardKey.shiftLeft);

        rectangleTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(100, 100),
        ));

        rectangleTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(200, 150),
        ));

        final createShape =
            eventRecorder.recordedEvents[0] as CreateShapeEvent;
        final params = createShape.parameters;

        // Should use the larger dimension (100) for both width and height
        expect(params['width'], equals(100.0));
        expect(params['height'], equals(100.0));

        // Cleanup
        await simulateKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      });

      test('should maintain square aspect in all drag directions', () async {
        await simulateKeyDownEvent(LogicalKeyboardKey.shiftLeft);

        // Drag with height > width
        rectangleTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(100, 100),
        ));

        rectangleTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(130, 180),
        ));

        final params =
            (eventRecorder.recordedEvents[0] as CreateShapeEvent).parameters;

        // Should use the larger dimension (80) for both
        expect(params['width'], equals(80.0));
        expect(params['height'], equals(80.0));

        await simulateKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      });
    });

    group('Option/Alt Key (Center Draw)', () {
      test('should draw from center when Option key is pressed', () async {
        // Simulate Option/Alt key press
        await simulateKeyDownEvent(LogicalKeyboardKey.altLeft);

        rectangleTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(150, 150), // Center
        ));

        rectangleTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(200, 175), // 50px right, 25px down
        ));

        final params =
            (eventRecorder.recordedEvents[0] as CreateShapeEvent).parameters;

        // Center should remain at drag start
        expect(params['centerX'], equals(150.0));
        expect(params['centerY'], equals(150.0));

        // Width/height should be 2x the drag distance
        expect(params['width'], equals(100.0)); // 50 * 2
        expect(params['height'], equals(50.0)); // 25 * 2

        await simulateKeyUpEvent(LogicalKeyboardKey.altLeft);
      });
    });

    group('Combined Modifiers', () {
      test('should create square from center with Shift+Option', () async {
        await simulateKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await simulateKeyDownEvent(LogicalKeyboardKey.altLeft);

        rectangleTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(150, 150), // Center
        ));

        rectangleTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(200, 175), // 50px right, 25px down
        ));

        final params =
            (eventRecorder.recordedEvents[0] as CreateShapeEvent).parameters;

        // Center should remain at drag start
        expect(params['centerX'], equals(150.0));
        expect(params['centerY'], equals(150.0));

        // Should use larger dimension (50) and double it for square from center
        expect(params['width'], equals(100.0)); // max(50, 25) * 2
        expect(params['height'], equals(100.0));

        await simulateKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await simulateKeyUpEvent(LogicalKeyboardKey.altLeft);
      });
    });

    group('Escape Key Cancellation', () {
      testWidgets('should cancel rectangle creation on Escape',
          (tester) async {
        rectangleTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(100, 100),
        ));

        rectangleTool.onPointerMove(PointerMoveEvent(
          position: const ui.Offset(200, 150),
        ));

        // Press Escape before pointer up
        await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);

        // The escape key should trigger cancellation
        final handled = rectangleTool.onKeyPress(
          KeyDownEvent(
            logicalKey: LogicalKeyboardKey.escape,
            physicalKey: PhysicalKeyboardKey.escape,
            timeStamp: Duration.zero,
          ),
        );

        rectangleTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(200, 150),
        ));

        // Should not emit any events (cancelled)
        expect(eventRecorder.recordedEvents.length, equals(0));
        expect(handled, isTrue);

        await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
      });
    });

    group('Tool Lifecycle', () {
      test('should reset state on deactivation', () {
        rectangleTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(100, 100),
        ));

        // Deactivate mid-drag
        rectangleTool.onDeactivate();

        // Reactivate and try to finish drag
        rectangleTool.onActivate();
        rectangleTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(200, 150),
        ));

        // Should not emit events (state was reset)
        expect(eventRecorder.recordedEvents.length, equals(0));
      });
    });
  });

  group('EllipseTool', () {
    late EllipseTool ellipseTool;
    late ViewportController viewportController;
    late MockEventRecorder eventRecorder;
    late Document document;

    setUp(() {
      viewportController = ViewportController(
        initialPan: const ui.Offset(0, 0),
        initialZoom: 1.0,
      );
      eventRecorder = MockEventRecorder();

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

      ellipseTool = EllipseTool(
        document: document,
        viewportController: viewportController,
        eventRecorder: eventRecorder,
      );

      ellipseTool.onActivate();
    });

    tearDown(() {
      ellipseTool.onDeactivate();
      viewportController.dispose();
    });

    group('Basic Drag Interaction', () {
      test('should create ellipse with correct dimensions on drag', () {
        ellipseTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(100, 100),
        ));

        ellipseTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(200, 150),
        ));

        expect(eventRecorder.recordedEvents.length, equals(1));

        final createShape =
            eventRecorder.recordedEvents[0] as CreateShapeEvent;
        expect(createShape.shapeType, equals(ShapeType.ellipse));

        final params = createShape.parameters;
        expect(params['centerX'], equals(150.0));
        expect(params['centerY'], equals(125.0));
        expect(params['width'], equals(100.0));
        expect(params['height'], equals(50.0));
        // Ellipse doesn't have cornerRadius
        expect(params.containsKey('cornerRadius'), isFalse);
      });

      test('should not create ellipse if drag distance below threshold', () {
        ellipseTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(100, 100),
        ));

        ellipseTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(102, 101),
        ));

        expect(eventRecorder.recordedEvents.length, equals(0));
      });
    });

    group('Shift Key Constraint', () {
      test('should create circle when Shift is pressed', () async {
        await simulateKeyDownEvent(LogicalKeyboardKey.shiftLeft);

        ellipseTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(100, 100),
        ));

        ellipseTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(200, 150),
        ));

        final params =
            (eventRecorder.recordedEvents[0] as CreateShapeEvent).parameters;

        // Should use the larger dimension for both width and height
        expect(params['width'], equals(100.0));
        expect(params['height'], equals(100.0));

        await simulateKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      });
    });

    group('Option/Alt Key (Center Draw)', () {
      test('should draw from center when Option key is pressed', () async {
        await simulateKeyDownEvent(LogicalKeyboardKey.altLeft);

        ellipseTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(150, 150),
        ));

        ellipseTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(200, 175),
        ));

        final params =
            (eventRecorder.recordedEvents[0] as CreateShapeEvent).parameters;

        expect(params['centerX'], equals(150.0));
        expect(params['centerY'], equals(150.0));
        expect(params['width'], equals(100.0)); // 50 * 2
        expect(params['height'], equals(50.0)); // 25 * 2

        await simulateKeyUpEvent(LogicalKeyboardKey.altLeft);
      });
    });

    group('Combined Modifiers', () {
      test('should create circle from center with Shift+Option', () async {
        await simulateKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await simulateKeyDownEvent(LogicalKeyboardKey.altLeft);

        ellipseTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(150, 150),
        ));

        ellipseTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(200, 175),
        ));

        final params =
            (eventRecorder.recordedEvents[0] as CreateShapeEvent).parameters;

        expect(params['centerX'], equals(150.0));
        expect(params['centerY'], equals(150.0));
        expect(params['width'], equals(100.0));
        expect(params['height'], equals(100.0));

        await simulateKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await simulateKeyUpEvent(LogicalKeyboardKey.altLeft);
      });
    });

    group('Escape Key Cancellation', () {
      testWidgets('should cancel ellipse creation on Escape',
          (tester) async {
        ellipseTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(100, 100),
        ));

        await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);

        // The escape key should trigger cancellation
        final handled = ellipseTool.onKeyPress(
          KeyDownEvent(
            logicalKey: LogicalKeyboardKey.escape,
            physicalKey: PhysicalKeyboardKey.escape,
            timeStamp: Duration.zero,
          ),
        );

        ellipseTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(200, 150),
        ));

        expect(eventRecorder.recordedEvents.length, equals(0));
        expect(handled, isTrue);

        await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
      });
    });
  });
}
