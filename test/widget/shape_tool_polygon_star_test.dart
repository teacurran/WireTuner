import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/application/tools/shapes/polygon_tool.dart';
import 'package:wiretuner/application/tools/shapes/star_tool.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/domain/document/selection.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/events/object_events.dart';
import 'package:wiretuner/domain/models/shape.dart' as shape_model;
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

/// Helper to verify if two points are close (within epsilon).
Matcher closeToPoint(Point expected, {double epsilon = 0.01}) {
  return _CloseToPoint(expected, epsilon);
}

class _CloseToPoint extends Matcher {
  final Point expected;
  final double epsilon;

  _CloseToPoint(this.expected, this.epsilon);

  @override
  bool matches(item, Map matchState) {
    if (item is! Point) return false;
    final dx = (item.x - expected.x).abs();
    final dy = (item.y - expected.y).abs();
    return dx <= epsilon && dy <= epsilon;
  }

  @override
  Description describe(Description description) {
    return description.add('close to Point(x: ${expected.x}, y: ${expected.y}) within $epsilon');
  }
}

void main() {
  // Initialize Flutter test bindings for HardwareKeyboard support
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PolygonTool', () {
    late PolygonTool polygonTool;
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

      polygonTool = PolygonTool(
        document: document,
        viewportController: viewportController,
        eventRecorder: eventRecorder,
      );

      polygonTool.onActivate();
    });

    tearDown(() {
      polygonTool.onDeactivate();
      viewportController.dispose();
    });

    group('Basic Drag Interaction', () {
      test('should create polygon with correct parameters on drag', () {
        // Drag from (100, 100) to (200, 200)
        polygonTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(100, 100),
        ));

        polygonTool.onPointerMove(PointerMoveEvent(
          position: const ui.Offset(200, 200),
        ));

        polygonTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(200, 200),
        ));

        // Should have emitted one CreateShapeEvent
        expect(eventRecorder.recordedEvents.length, equals(1));

        final createShape =
            eventRecorder.recordedEvents[0] as CreateShapeEvent;
        expect(createShape.eventType, equals('CreateShapeEvent'));
        expect(createShape.shapeType, equals(ShapeType.polygon));

        // Verify parameters
        final params = createShape.parameters;
        expect(params['centerX'], equals(150.0)); // (100 + 200) / 2
        expect(params['centerY'], equals(150.0)); // (100 + 200) / 2
        expect(params['radius'], equals(50.0)); // max(100/2, 100/2)
        expect(params['sides'], equals(5.0)); // Default pentagon
        expect(params['rotation'], equals(0.0));

        // Verify optional style fields
        expect(createShape.strokeColor, equals('#000000'));
        expect(createShape.strokeWidth, equals(2.0));
      });

      test('should normalize dimensions when dragging in any direction', () {
        // Drag from bottom-right to top-left (reverse direction)
        polygonTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(200, 200),
        ));

        polygonTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(100, 100),
        ));

        final createShape =
            eventRecorder.recordedEvents[0] as CreateShapeEvent;
        final params = createShape.parameters;

        // Center should be the same
        expect(params['centerX'], equals(150.0));
        expect(params['centerY'], equals(150.0));
        // Radius should be positive
        expect(params['radius'], equals(50.0));
      });

      test('should use max dimension for non-square drag', () {
        // Drag rectangle: width > height
        polygonTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(100, 100),
        ));

        polygonTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(300, 150),
        ));

        final params =
            (eventRecorder.recordedEvents[0] as CreateShapeEvent).parameters;

        // Width = 200, Height = 50 → max = 100
        expect(params['radius'], equals(100.0));
      });

      test('should not create polygon if drag distance below threshold', () {
        // Very small drag (< 5px)
        polygonTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(100, 100),
        ));

        polygonTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(102, 101),
        ));

        // Should not emit any events
        expect(eventRecorder.recordedEvents.length, equals(0));
      });
    });

    group('Parameter Validation', () {
      test('should enforce minimum 3 sides', () {
        polygonTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(100, 100),
        ));

        polygonTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(200, 200),
        ));

        final params =
            (eventRecorder.recordedEvents[0] as CreateShapeEvent).parameters;

        // Minimum 3 sides enforced
        expect(params['sides']!, greaterThanOrEqualTo(3.0));
      });
    });

    group('Option/Alt Key (Center Draw)', () {
      test('should draw from center when Option key is pressed', () async {
        // Simulate Option/Alt key press
        await simulateKeyDownEvent(LogicalKeyboardKey.altLeft);

        polygonTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(150, 150), // Center
        ));

        polygonTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(200, 175), // 50px right, 25px down
        ));

        final params =
            (eventRecorder.recordedEvents[0] as CreateShapeEvent).parameters;

        // Center should remain at drag start
        expect(params['centerX'], equals(150.0));
        expect(params['centerY'], equals(150.0));

        // Radius should be max of drag distances
        // deltaX = 50, deltaY = 25 → max = 50
        expect(params['radius'], equals(50.0));

        await simulateKeyUpEvent(LogicalKeyboardKey.altLeft);
      });
    });

    group('Event Replay', () {
      test('should reproduce identical geometry from event parameters', () {
        // Create polygon via tool
        polygonTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(100, 100),
        ));

        polygonTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(200, 200),
        ));

        final event = eventRecorder.recordedEvents[0] as CreateShapeEvent;

        // Create original shape (what tool created)
        final originalShape = shape_model.Shape.polygon(
          center: Point(x: 150, y: 150),
          radius: 50,
          sides: 5,
          rotation: 0,
        );

        // Recreate from event parameters
        final recreatedShape = shape_model.Shape.polygon(
          center: Point(
            x: event.parameters['centerX']!,
            y: event.parameters['centerY']!,
          ),
          radius: event.parameters['radius']!,
          sides: event.parameters['sides']!.toInt(),
          rotation: event.parameters['rotation'] ?? 0.0,
        );

        // Compare geometry
        final originalPath = originalShape.toPath();
        final recreatedPath = recreatedShape.toPath();

        expect(recreatedPath.anchors.length, equals(originalPath.anchors.length));
        expect(recreatedPath.anchors.length, equals(5)); // 5-sided polygon

        // Verify each anchor position matches
        for (int i = 0; i < originalPath.anchors.length; i++) {
          expect(
            recreatedPath.anchors[i].position,
            closeToPoint(originalPath.anchors[i].position, epsilon: 0.01),
          );
        }
      });
    });

    group('Escape Key Cancellation', () {
      testWidgets('should cancel polygon creation on Escape',
          (tester) async {
        polygonTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(100, 100),
        ));

        polygonTool.onPointerMove(PointerMoveEvent(
          position: const ui.Offset(200, 200),
        ));

        // Press Escape before pointer up
        await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);

        // The escape key should trigger cancellation
        final handled = polygonTool.onKeyPress(
          KeyDownEvent(
            logicalKey: LogicalKeyboardKey.escape,
            physicalKey: PhysicalKeyboardKey.escape,
            timeStamp: Duration.zero,
          ),
        );

        polygonTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(200, 200),
        ));

        // Should not emit any events (cancelled)
        expect(eventRecorder.recordedEvents.length, equals(0));
        expect(handled, isTrue);

        await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
      });
    });

    group('Tool Lifecycle', () {
      test('should reset state on deactivation', () {
        polygonTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(100, 100),
        ));

        // Deactivate mid-drag
        polygonTool.onDeactivate();

        // Reactivate and try to finish drag
        polygonTool.onActivate();
        polygonTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(200, 200),
        ));

        // Should not emit events (state was reset)
        expect(eventRecorder.recordedEvents.length, equals(0));
      });
    });
  });

  group('StarTool', () {
    late StarTool starTool;
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

      starTool = StarTool(
        document: document,
        viewportController: viewportController,
        eventRecorder: eventRecorder,
      );

      starTool.onActivate();
    });

    tearDown(() {
      starTool.onDeactivate();
      viewportController.dispose();
    });

    group('Basic Drag Interaction', () {
      test('should create star with correct parameters on drag', () {
        // Drag from (100, 100) to (200, 200)
        starTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(100, 100),
        ));

        starTool.onPointerMove(PointerMoveEvent(
          position: const ui.Offset(200, 200),
        ));

        starTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(200, 200),
        ));

        // Should have emitted one CreateShapeEvent
        expect(eventRecorder.recordedEvents.length, equals(1));

        final createShape =
            eventRecorder.recordedEvents[0] as CreateShapeEvent;
        expect(createShape.eventType, equals('CreateShapeEvent'));
        expect(createShape.shapeType, equals(ShapeType.star));

        // Verify parameters
        final params = createShape.parameters;
        expect(params['centerX'], equals(150.0)); // (100 + 200) / 2
        expect(params['centerY'], equals(150.0)); // (100 + 200) / 2
        expect(params['radius'], equals(50.0)); // Outer radius
        expect(params['innerRadius'], equals(25.0)); // 0.5 * outer radius
        expect(params['sides'], equals(5.0)); // Default 5-point star
        expect(params['rotation'], equals(0.0));

        // Verify optional style fields
        expect(createShape.strokeColor, equals('#000000'));
        expect(createShape.strokeWidth, equals(2.0));
      });

      test('should normalize dimensions when dragging in any direction', () {
        // Drag from bottom-right to top-left (reverse direction)
        starTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(200, 200),
        ));

        starTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(100, 100),
        ));

        final createShape =
            eventRecorder.recordedEvents[0] as CreateShapeEvent;
        final params = createShape.parameters;

        // Center should be the same
        expect(params['centerX'], equals(150.0));
        expect(params['centerY'], equals(150.0));
        // Radii should be positive
        expect(params['radius'], equals(50.0));
        expect(params['innerRadius'], equals(25.0));
      });

      test('should use max dimension for non-square drag', () {
        // Drag rectangle: width > height
        starTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(100, 100),
        ));

        starTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(300, 150),
        ));

        final params =
            (eventRecorder.recordedEvents[0] as CreateShapeEvent).parameters;

        // Width = 200, Height = 50 → max = 100
        expect(params['radius'], equals(100.0));
        expect(params['innerRadius'], equals(50.0)); // 0.5 * 100
      });

      test('should not create star if drag distance below threshold', () {
        // Very small drag (< 5px)
        starTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(100, 100),
        ));

        starTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(102, 101),
        ));

        // Should not emit any events
        expect(eventRecorder.recordedEvents.length, equals(0));
      });
    });

    group('Parameter Validation', () {
      test('should enforce innerRadius < outerRadius', () {
        starTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(100, 100),
        ));

        starTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(200, 200),
        ));

        final params =
            (eventRecorder.recordedEvents[0] as CreateShapeEvent).parameters;

        // Inner radius must be less than outer radius
        expect(params['innerRadius']!, lessThan(params['radius']!));
        // Inner radius must be positive
        expect(params['innerRadius']!, greaterThan(0.0));
      });

      test('should enforce minimum 3 points', () {
        starTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(100, 100),
        ));

        starTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(200, 200),
        ));

        final params =
            (eventRecorder.recordedEvents[0] as CreateShapeEvent).parameters;

        // Minimum 3 points enforced
        expect(params['sides']!, greaterThanOrEqualTo(3.0));
      });
    });

    group('Option/Alt Key (Center Draw)', () {
      test('should draw from center when Option key is pressed', () async {
        // Simulate Option/Alt key press
        await simulateKeyDownEvent(LogicalKeyboardKey.altLeft);

        starTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(150, 150), // Center
        ));

        starTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(200, 175), // 50px right, 25px down
        ));

        final params =
            (eventRecorder.recordedEvents[0] as CreateShapeEvent).parameters;

        // Center should remain at drag start
        expect(params['centerX'], equals(150.0));
        expect(params['centerY'], equals(150.0));

        // Radius should be max of drag distances
        // deltaX = 50, deltaY = 25 → max = 50
        expect(params['radius'], equals(50.0));
        expect(params['innerRadius'], equals(25.0)); // 0.5 * 50

        await simulateKeyUpEvent(LogicalKeyboardKey.altLeft);
      });
    });

    group('Event Replay', () {
      test('should reproduce identical geometry from event parameters', () {
        // Create star via tool
        starTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(100, 100),
        ));

        starTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(200, 200),
        ));

        final event = eventRecorder.recordedEvents[0] as CreateShapeEvent;

        // Create original shape (what tool created)
        final originalShape = shape_model.Shape.star(
          center: Point(x: 150, y: 150),
          outerRadius: 50,
          innerRadius: 25,
          pointCount: 5,
          rotation: 0,
        );

        // Recreate from event parameters
        final recreatedShape = shape_model.Shape.star(
          center: Point(
            x: event.parameters['centerX']!,
            y: event.parameters['centerY']!,
          ),
          outerRadius: event.parameters['radius']!,
          innerRadius: event.parameters['innerRadius']!,
          pointCount: event.parameters['sides']!.toInt(),
          rotation: event.parameters['rotation'] ?? 0.0,
        );

        // Compare geometry
        final originalPath = originalShape.toPath();
        final recreatedPath = recreatedShape.toPath();

        expect(recreatedPath.anchors.length, equals(originalPath.anchors.length));
        expect(recreatedPath.anchors.length, equals(10)); // 5-point star = 10 vertices

        // Verify each anchor position matches
        for (int i = 0; i < originalPath.anchors.length; i++) {
          expect(
            recreatedPath.anchors[i].position,
            closeToPoint(originalPath.anchors[i].position, epsilon: 0.01),
          );
        }
      });
    });

    group('Escape Key Cancellation', () {
      testWidgets('should cancel star creation on Escape', (tester) async {
        starTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(100, 100),
        ));

        starTool.onPointerMove(PointerMoveEvent(
          position: const ui.Offset(200, 200),
        ));

        // Press Escape before pointer up
        await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);

        // The escape key should trigger cancellation
        final handled = starTool.onKeyPress(
          KeyDownEvent(
            logicalKey: LogicalKeyboardKey.escape,
            physicalKey: PhysicalKeyboardKey.escape,
            timeStamp: Duration.zero,
          ),
        );

        starTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(200, 200),
        ));

        // Should not emit any events (cancelled)
        expect(eventRecorder.recordedEvents.length, equals(0));
        expect(handled, isTrue);

        await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
      });
    });

    group('Tool Lifecycle', () {
      test('should reset state on deactivation', () {
        starTool.onPointerDown(PointerDownEvent(
          position: const ui.Offset(100, 100),
        ));

        // Deactivate mid-drag
        starTool.onDeactivate();

        // Reactivate and try to finish drag
        starTool.onActivate();
        starTool.onPointerUp(PointerUpEvent(
          position: const ui.Offset(200, 200),
        ));

        // Should not emit events (state was reset)
        expect(eventRecorder.recordedEvents.length, equals(0));
      });
    });
  });
}
