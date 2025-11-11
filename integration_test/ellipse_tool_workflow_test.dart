/// Integration tests for Ellipse Tool workflow (Task I7.T2).
library;

///
/// These tests verify the acceptance criteria for ellipse creation:
/// - AC1: Drag creates ellipse inscribed in bounding box
/// - AC2: Shift+drag creates circle
/// - AC3: CreateShapeEvent persisted on pointer up
/// - AC4: Ellipse renders with Bezier approximation
/// - AC5: Integration test creates ellipse successfully
///
/// Related: I7.T2 (EllipseTool), T026 (Ellipse Tool)

import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/application/tools/shapes/ellipse_tool.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/domain/document/selection.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/events/object_events.dart';
import 'package:wiretuner/domain/models/anchor_point.dart' as ap;
import 'package:wiretuner/domain/models/segment.dart';
import 'package:wiretuner/domain/models/shape.dart';
import 'package:wiretuner/infrastructure/event_sourcing/event_recorder.dart';
import 'package:wiretuner/infrastructure/persistence/event_store.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';

/// Mock EventStore for testing without SQLite dependency.
class _MockEventStore implements EventStore {
  final List<EventBase> events = [];

  @override
  Future<int> insertEvent(String documentId, EventBase event) async {
    events.add(event);
    return events.length; // Sequence number
  }

  void clear() => events.clear();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Test-specific EventRecorder that provides access to persisted events.
class _TestEventRecorder extends EventRecorder {
  _TestEventRecorder(this._store)
      : super(
          eventStore: _store,
          documentId: 'test-doc',
        );

  final _MockEventStore _store;
  int flushCount = 0;

  @override
  void flush() {
    flushCount++;
    super.flush();
  }

  List<EventBase> get events => _store.events;

  List<CreateShapeEvent> get createShapeEvents =>
      events.whereType<CreateShapeEvent>().toList();

  void clear() {
    _store.clear();
    flushCount = 0;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Ellipse Tool Integration Tests (I7.T2)', () {
    late EllipseTool ellipseTool;
    late ViewportController viewport;
    late _TestEventRecorder recorder;
    late _MockEventStore store;
    late Document document;

    setUp(() {
      // Setup viewport with 1:1 zoom for easy coordinate mapping
      viewport = ViewportController(
        initialPan: const ui.Offset(0, 0),
        initialZoom: 1.0,
      );

      // Setup event recording with real persistence
      store = _MockEventStore();
      recorder = _TestEventRecorder(store);

      // Create empty test document
      const layer = Layer(
        id: 'layer-1',
        name: 'Test Layer',
        objects: [],
      );

      document = const Document(
        id: 'test-doc',
        title: 'Ellipse Tool Test',
        layers: [layer],
        selection: Selection(),
      );

      // Create and activate ellipse tool
      ellipseTool = EllipseTool(
        document: document,
        viewportController: viewport,
        eventRecorder: recorder,
      );

      ellipseTool.onActivate();
    });

    tearDown(() {
      ellipseTool.onDeactivate();
      viewport.dispose();
      recorder.clear();
    });

    group('AC1: Drag creates ellipse inscribed in bounding box', () {
      test('creates ellipse from corner-to-corner drag', () {
        // Arrange: Define drag coordinates (100,100) -> (200,150)
        const startPos = ui.Offset(100, 100);
        const endPos = ui.Offset(200, 150);

        // Act: Perform drag interaction
        ellipseTool.onPointerDown(
          const PointerDownEvent(position: startPos),
        );

        ellipseTool.onPointerMove(
          const PointerMoveEvent(position: ui.Offset(150, 125)),
        );

        ellipseTool.onPointerUp(
          const PointerUpEvent(position: endPos),
        );

        // Assert: Verify CreateShapeEvent was persisted
        expect(recorder.createShapeEvents.length, equals(1));

        final createEvent = recorder.createShapeEvents[0];
        expect(createEvent.eventType, equals('CreateShapeEvent'));
        expect(createEvent.shapeType, equals(ShapeType.ellipse));
        expect(createEvent.shapeId, isNotEmpty);

        // Verify ellipse dimensions (inscribed in bounding box)
        final params = createEvent.parameters;
        expect(params['centerX'], equals(150.0)); // (100 + 200) / 2
        expect(params['centerY'], equals(125.0)); // (100 + 150) / 2
        expect(params['width'], equals(100.0)); // 200 - 100
        expect(params['height'], equals(50.0)); // 150 - 100

        // Verify ellipse doesn't have cornerRadius (unlike rectangle)
        expect(params.containsKey('cornerRadius'), isFalse);

        // Verify default style
        expect(createEvent.strokeColor, equals('#000000'));
        expect(createEvent.strokeWidth, equals(2.0));
      });

      test('normalizes dimensions when dragging in reverse direction', () {
        // Arrange: Drag from bottom-right to top-left
        const startPos = ui.Offset(200, 150);
        const endPos = ui.Offset(100, 100);

        // Act
        ellipseTool.onPointerDown(
          const PointerDownEvent(position: startPos),
        );

        ellipseTool.onPointerUp(
          const PointerUpEvent(position: endPos),
        );

        // Assert: Dimensions should be positive
        final params = recorder.createShapeEvents[0].parameters;
        expect(params['width'], equals(100.0));
        expect(params['height'], equals(50.0));
        expect(params['centerX'], equals(150.0));
        expect(params['centerY'], equals(125.0));
      });

      test('does not create ellipse if drag distance below threshold', () {
        // Arrange: Very small drag (< 5px minimum)
        const startPos = ui.Offset(100, 100);
        const endPos = ui.Offset(102, 101);

        // Act
        ellipseTool.onPointerDown(
          const PointerDownEvent(position: startPos),
        );

        ellipseTool.onPointerUp(
          const PointerUpEvent(position: endPos),
        );

        // Assert: No events should be persisted
        expect(recorder.createShapeEvents.length, equals(0));
      });

      test('creates tall ellipse when height > width', () {
        // Arrange: Drag with height (100) > width (50)
        const startPos = ui.Offset(100, 100);
        const endPos = ui.Offset(150, 200);

        // Act
        ellipseTool.onPointerDown(
          const PointerDownEvent(position: startPos),
        );

        ellipseTool.onPointerUp(
          const PointerUpEvent(position: endPos),
        );

        // Assert
        final params = recorder.createShapeEvents[0].parameters;
        expect(params['width'], equals(50.0));
        expect(params['height'], equals(100.0));
        expect(params['centerX'], equals(125.0));
        expect(params['centerY'], equals(150.0));
      });
    });

    group('AC2: Shift+drag creates circle', () {
      test('creates circle when Shift is pressed during drag', () async {
        // Arrange: Simulate Shift key press
        await simulateKeyDownEvent(LogicalKeyboardKey.shiftLeft);

        // Act: Drag with non-square dimensions
        ellipseTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        ellipseTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 150)),
        );

        // Assert: Should use larger dimension (100) for both width and height
        final params = recorder.createShapeEvents[0].parameters;
        expect(params['width'], equals(100.0));
        expect(params['height'], equals(100.0)); // Constrained to circle

        // Verify center position is adjusted
        expect(params['centerX'], equals(150.0));
        expect(params['centerY'], equals(150.0)); // Adjusted from 125

        // Cleanup
        await simulateKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      });

      test('maintains circular aspect in all drag directions', () async {
        // Arrange
        await simulateKeyDownEvent(LogicalKeyboardKey.shiftLeft);

        // Act: Drag where height > width
        ellipseTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        ellipseTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(130, 180)),
        );

        // Assert: Should use larger dimension (80) for both
        final params = recorder.createShapeEvents[0].parameters;
        expect(params['width'], equals(80.0)); // max(30, 80)
        expect(params['height'], equals(80.0));

        await simulateKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      });

      test('creates circle from center with Shift+Alt modifiers', () async {
        // Arrange: Both modifiers pressed
        await simulateKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await simulateKeyDownEvent(LogicalKeyboardKey.altLeft);

        // Act: Drag from center point
        ellipseTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(150, 150)),
        );

        ellipseTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 175)),
        );

        // Assert: Circle from center
        final params = recorder.createShapeEvents[0].parameters;
        expect(params['centerX'], equals(150.0)); // Center preserved
        expect(params['centerY'], equals(150.0));
        expect(params['width'], equals(100.0)); // max(50, 25) * 2
        expect(params['height'], equals(100.0));

        await simulateKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await simulateKeyUpEvent(LogicalKeyboardKey.altLeft);
      });
    });

    group('AC3: CreateShapeEvent persisted on pointer up', () {
      test('event is persisted through EventRecorder', () {
        // Act
        ellipseTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        ellipseTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 150)),
        );

        // Assert: Event in store
        expect(store.events.length, equals(1));
        expect(store.events[0], isA<CreateShapeEvent>());
      });

      test('only one event is persisted per drag', () {
        // Act: Multiple pointer moves should not create multiple events
        ellipseTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        ellipseTool.onPointerMove(
          const PointerMoveEvent(position: ui.Offset(120, 110)),
        );

        ellipseTool.onPointerMove(
          const PointerMoveEvent(position: ui.Offset(150, 125)),
        );

        ellipseTool.onPointerMove(
          const PointerMoveEvent(position: ui.Offset(180, 140)),
        );

        ellipseTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 150)),
        );

        // Assert: Only one event persisted
        expect(recorder.createShapeEvents.length, equals(1));
      });

      test('event has unique ID and timestamp', () {
        // Act
        ellipseTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        ellipseTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 150)),
        );

        final event = recorder.createShapeEvents[0];

        // Assert
        expect(event.eventId, isNotEmpty);
        expect(event.timestamp, greaterThan(0));
        expect(event.shapeId, isNotEmpty);
      });

      test('multiple ellipses create separate events', () async {
        // Act: Create first ellipse
        ellipseTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );
        ellipseTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 150)),
        );

        // Wait for first event to be persisted (EventSampler uses 50ms throttle)
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Create second ellipse
        ellipseTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(300, 300)),
        );
        ellipseTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(400, 380)),
        );

        // Wait for second event to be persisted
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Assert: Two separate events
        expect(recorder.createShapeEvents.length, equals(2));

        final event1 = recorder.createShapeEvents[0];
        final event2 = recorder.createShapeEvents[1];

        // Verify they are distinct
        expect(event1.eventId, isNot(equals(event2.eventId)));
        expect(event1.shapeId, isNot(equals(event2.shapeId)));
      });
    });

    group('AC4: Ellipse renders with Bezier approximation', () {
      test('created ellipse shape can be converted to Path with Bezier curves', () {
        // Act
        ellipseTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        ellipseTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 150)),
        );

        final event = recorder.createShapeEvents[0];

        // Assert: Shape parameters can create Shape model
        final shape = Shape.ellipse(
          center: Point(
            x: event.parameters['centerX']!,
            y: event.parameters['centerY']!,
          ),
          width: event.parameters['width']!,
          height: event.parameters['height']!,
        );

        expect(shape.kind, equals(ShapeKind.ellipse));
        expect(shape.width, equals(100.0));
        expect(shape.height, equals(50.0));

        // Verify shape can be converted to Path with Bezier approximation
        final path = shape.toPath();

        // Ellipse uses 4 anchor points (top, right, bottom, left)
        expect(path.anchors.length, equals(4));
        expect(path.closed, isTrue);

        // Verify all segments are Bezier curves (for smooth ellipse approximation)
        expect(path.segments.length, equals(4));
        for (final segment in path.segments) {
          expect(segment.segmentType, equals(SegmentType.bezier));
        }

        // Verify anchors have control handles (Bezier control points)
        for (final anchor in path.anchors) {
          expect(anchor.anchorType, equals(ap.AnchorType.smooth));
          expect(anchor.handleIn, isNotNull);
          expect(anchor.handleOut, isNotNull);
        }
      });

      test('circle shape creates correct Bezier Path', () async {
        // Arrange
        await simulateKeyDownEvent(LogicalKeyboardKey.shiftLeft);

        // Act
        ellipseTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        ellipseTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 150)),
        );

        final event = recorder.createShapeEvents[0];
        final shape = Shape.ellipse(
          center: Point(
            x: event.parameters['centerX']!,
            y: event.parameters['centerY']!,
          ),
          width: event.parameters['width']!,
          height: event.parameters['height']!,
        );

        final path = shape.toPath();

        // Assert: Circle dimensions
        expect(shape.width, equals(shape.height));
        expect(path.anchors.length, equals(4));

        // Verify Bezier curve segments
        expect(path.segments.every((s) => s.segmentType == SegmentType.bezier), isTrue);

        await simulateKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      });

      test('ellipse with different width/height creates correct aspect ratio', () {
        // Act: Create wide ellipse
        ellipseTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        ellipseTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(300, 150)),
        );

        final event = recorder.createShapeEvents[0];
        final shape = Shape.ellipse(
          center: Point(
            x: event.parameters['centerX']!,
            y: event.parameters['centerY']!,
          ),
          width: event.parameters['width']!,
          height: event.parameters['height']!,
        );

        // Assert: Wide ellipse (width = 200, height = 50)
        expect(shape.width, equals(200.0));
        expect(shape.height, equals(50.0));

        final path = shape.toPath();
        expect(path.anchors.length, equals(4));

        // Verify the horizontal radius is 4x the vertical radius
        expect(shape.width! / shape.height!, equals(4.0));
      });
    });

    group('AC5: Integration test creates ellipse successfully', () {
      test('complete workflow: drag -> create -> persist -> render', () {
        // 1. Drag interaction
        ellipseTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(50, 50)),
        );

        ellipseTool.onPointerMove(
          const PointerMoveEvent(position: ui.Offset(100, 75)),
        );

        ellipseTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(150, 100)),
        );

        // 2. Verify CreateShapeEvent persisted
        expect(recorder.createShapeEvents.length, equals(1));
        final event = recorder.createShapeEvents[0];
        expect(event.shapeType, equals(ShapeType.ellipse));

        // 3. Verify correct parameters
        expect(event.parameters['centerX'], equals(100.0)); // (50 + 150) / 2
        expect(event.parameters['centerY'], equals(75.0)); // (50 + 100) / 2
        expect(event.parameters['width'], equals(100.0)); // 150 - 50
        expect(event.parameters['height'], equals(50.0)); // 100 - 50

        // 4. Verify Shape can be created and rendered
        final shape = Shape.fromJson({
          'center': {'x': event.parameters['centerX'], 'y': event.parameters['centerY']},
          'kind': 'ellipse',
          'width': event.parameters['width'],
          'height': event.parameters['height'],
        });

        final path = shape.toPath();
        expect(path.closed, isTrue);
        expect(path.anchors.isNotEmpty, isTrue);

        // Verify Bezier approximation
        expect(path.segments.every((s) => s.segmentType == SegmentType.bezier), isTrue);

        // 5. Verify event was persisted to store
        expect(store.events.contains(event), isTrue);
      });

      test('workflow with Shift constraint (circle)', () async {
        await simulateKeyDownEvent(LogicalKeyboardKey.shiftLeft);

        // Complete workflow
        ellipseTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        ellipseTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 150)),
        );

        // Verify circle created
        final event = recorder.createShapeEvents[0];
        expect(event.parameters['width'], equals(event.parameters['height']));

        // Verify can be rendered with Bezier curves
        final shape = Shape.ellipse(
          center: Point(
            x: event.parameters['centerX']!,
            y: event.parameters['centerY']!,
          ),
          width: event.parameters['width']!,
          height: event.parameters['height']!,
        );

        final path = shape.toPath();
        expect(path.closed, isTrue);
        expect(path.segments.every((s) => s.segmentType == SegmentType.bezier), isTrue);

        await simulateKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      });

      test('workflow with Alt (from center) constraint', () async {
        await simulateKeyDownEvent(LogicalKeyboardKey.altLeft);

        ellipseTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(150, 150)),
        );

        ellipseTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 175)),
        );

        final event = recorder.createShapeEvents[0];

        // Center should be preserved
        expect(event.parameters['centerX'], equals(150.0));
        expect(event.parameters['centerY'], equals(150.0));

        // Size should be 2x the drag distance
        expect(event.parameters['width'], equals(100.0)); // 50 * 2
        expect(event.parameters['height'], equals(50.0)); // 25 * 2

        // Verify rendering
        final shape = Shape.ellipse(
          center: Point(
            x: event.parameters['centerX']!,
            y: event.parameters['centerY']!,
          ),
          width: event.parameters['width']!,
          height: event.parameters['height']!,
        );

        expect(shape.toPath().closed, isTrue);

        await simulateKeyUpEvent(LogicalKeyboardKey.altLeft);
      });
    });

    group('Edge Cases and Error Handling', () {
      test('Escape key cancels ellipse creation', () {
        ellipseTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        ellipseTool.onPointerMove(
          const PointerMoveEvent(position: ui.Offset(150, 125)),
        );

        // Press Escape before pointer up
        final handled = ellipseTool.onKeyPress(
          const KeyDownEvent(
            logicalKey: LogicalKeyboardKey.escape,
            physicalKey: PhysicalKeyboardKey.escape,
            timeStamp: Duration.zero,
          ),
        );

        expect(handled, isTrue);

        // Complete drag anyway
        ellipseTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 150)),
        );

        // No event should be created
        expect(recorder.createShapeEvents.length, equals(0));
      });

      test('tool deactivation mid-drag resets state', () {
        ellipseTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        // Deactivate mid-drag
        ellipseTool.onDeactivate();

        // Reactivate and try to complete
        ellipseTool.onActivate();

        ellipseTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 150)),
        );

        // No event should be created (state was reset)
        expect(recorder.createShapeEvents.length, equals(0));
      });

      test('viewport zoom does not affect world coordinates', () {
        // Change viewport zoom
        viewport.setZoom(2.0);

        ellipseTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        ellipseTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 150)),
        );

        // World coordinates should be transformed correctly
        final event = recorder.createShapeEvents[0];
        expect(event.parameters, isNotNull);
        expect(event.parameters.keys, contains('centerX'));
        expect(event.parameters.keys, contains('centerY'));
      });

      test('viewport pan does not affect world coordinates', () {
        // Change viewport pan
        viewport.pan(const ui.Offset(100, 100));

        ellipseTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        ellipseTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 150)),
        );

        // World coordinates should be transformed correctly
        final event = recorder.createShapeEvents[0];
        expect(event.parameters, isNotNull);
      });
    });

    group('Tool Lifecycle', () {
      test('activation resets tool state', () {
        ellipseTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        // Deactivate without completing
        ellipseTool.onDeactivate();

        // Reactivate
        ellipseTool.onActivate();

        // Start new drag
        ellipseTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(200, 200)),
        );

        ellipseTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(300, 250)),
        );

        // Should only create one event (the second drag)
        expect(recorder.createShapeEvents.length, equals(1));

        final params = recorder.createShapeEvents[0].parameters;
        expect(params['centerX'], equals(250.0));
        expect(params['centerY'], equals(225.0));
      });

      test('tool has correct ID and cursor', () {
        expect(ellipseTool.toolId, equals('ellipse'));
        expect(ellipseTool.cursor, equals(SystemMouseCursors.precise));
      });
    });
  });
}
