/// Integration tests for Polygon Tool workflow (Task I7.T3).
library;

///
/// These tests verify the acceptance criteria for polygon creation:
/// - AC1: Click defines center point
/// - AC2: Drag distance defines radius
/// - AC3: Polygon has correct number of sides
/// - AC4: Regular polygon (all sides equal length)
/// - AC5: Integration tests create 3-sided and 8-sided polygons
///
/// Related: I7.T3 (PolygonTool), T027 (Polygon Tool)

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/application/tools/shapes/polygon_tool.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/domain/document/selection.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/events/object_events.dart';
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

  group('Polygon Tool Integration Tests (I7.T3)', () {
    late PolygonTool polygonTool;
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
        title: 'Polygon Tool Test',
        layers: [layer],
        selection: Selection(),
      );

      // Create and activate polygon tool
      polygonTool = PolygonTool(
        document: document,
        viewportController: viewport,
        eventRecorder: recorder,
      );

      polygonTool.onActivate();
    });

    tearDown(() {
      polygonTool.onDeactivate();
      viewport.dispose();
      recorder.clear();
    });

    group('AC1: Click defines center point', () {
      test('center point is at midpoint of drag', () {
        // Arrange: Define drag coordinates (100,100) -> (200,200)
        const startPos = ui.Offset(100, 100);
        const endPos = ui.Offset(200, 200);

        // Act: Perform drag interaction
        polygonTool.onPointerDown(
          const PointerDownEvent(position: startPos),
        );

        polygonTool.onPointerMove(
          const PointerMoveEvent(position: ui.Offset(150, 150)),
        );

        polygonTool.onPointerUp(
          const PointerUpEvent(position: endPos),
        );

        // Assert: Verify CreateShapeEvent was persisted
        expect(recorder.createShapeEvents.length, equals(1));

        final createEvent = recorder.createShapeEvents[0];
        expect(createEvent.eventType, equals('CreateShapeEvent'));
        expect(createEvent.shapeType, equals(ShapeType.polygon));

        // Verify center point is at drag midpoint
        final params = createEvent.parameters;
        expect(params['centerX'], equals(150.0)); // (100 + 200) / 2
        expect(params['centerY'], equals(150.0)); // (100 + 200) / 2
      });

      test('center preserved when drawing from center (Alt key)', () async {
        // Arrange: Simulate Alt key press
        await simulateKeyDownEvent(LogicalKeyboardKey.altLeft);

        // Act: Drag from center point
        polygonTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(150, 150)),
        );

        polygonTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 175)),
        );

        // Assert: Center should remain at drag start
        final params = recorder.createShapeEvents[0].parameters;
        expect(params['centerX'], equals(150.0));
        expect(params['centerY'], equals(150.0));

        await simulateKeyUpEvent(LogicalKeyboardKey.altLeft);
      });
    });

    group('AC2: Drag distance defines radius', () {
      test('radius is max of width/2 and height/2', () {
        // Arrange: Non-square drag
        polygonTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        polygonTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(300, 200)),
        );

        // Assert: Width = 200, Height = 100 → radius = max(100, 50) = 100
        final params = recorder.createShapeEvents[0].parameters;
        expect(params['radius'], equals(100.0));
        expect(params['centerX'], equals(200.0));
        expect(params['centerY'], equals(150.0));
      });

      test('radius computed correctly in all drag directions', () {
        // Arrange: Drag from bottom-right to top-left (reverse)
        polygonTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(200, 200)),
        );

        polygonTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(100, 100)),
        );

        // Assert: Dimensions should be normalized
        final params = recorder.createShapeEvents[0].parameters;
        expect(params['radius'], equals(50.0)); // max(100/2, 100/2)
        expect(params['centerX'], equals(150.0));
        expect(params['centerY'], equals(150.0));
      });

      test('minimum drag distance threshold enforced', () {
        // Arrange: Very small drag (< 5px minimum)
        polygonTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        polygonTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(102, 101)),
        );

        // Assert: No events should be persisted
        expect(recorder.createShapeEvents.length, equals(0));
      });
    });

    group('AC3: Polygon has correct number of sides', () {
      test('default hexagon (6 sides) created', () {
        // Act
        polygonTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        polygonTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 200)),
        );

        // Assert
        final params = recorder.createShapeEvents[0].parameters;
        expect(params['sides'], equals(6.0)); // Default hexagon
      });

      test('side count configurable and persisted in event', () {
        // Arrange: Configure for pentagon
        polygonTool.setSideCount(5);
        expect(polygonTool.sideCount, equals(5));

        // Act
        polygonTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        polygonTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 200)),
        );

        // Assert
        final params = recorder.createShapeEvents[0].parameters;
        expect(params['sides'], equals(5.0));
      });

      test('side count clamped to valid range (3-20)', () {
        // Test minimum clamping
        polygonTool.setSideCount(1);
        expect(polygonTool.sideCount, equals(3));

        polygonTool.setSideCount(2);
        expect(polygonTool.sideCount, equals(3));

        // Test maximum clamping
        polygonTool.setSideCount(25);
        expect(polygonTool.sideCount, equals(20));

        // Test valid values
        polygonTool.setSideCount(7);
        expect(polygonTool.sideCount, equals(7));
      });
    });

    group('AC4: Regular polygon (all sides equal length)', () {
      test('hexagon has equal side lengths', () {
        // Arrange: Default hexagon (6 sides)
        polygonTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        polygonTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 200)),
        );

        final event = recorder.createShapeEvents[0];

        // Act: Create shape and convert to path
        final shape = Shape.polygon(
          center: Point(
            x: event.parameters['centerX']!,
            y: event.parameters['centerY']!,
          ),
          radius: event.parameters['radius']!,
          sides: event.parameters['sides']!.toInt(),
          rotation: event.parameters['rotation'] ?? 0.0,
        );

        final path = shape.toPath();

        // Assert: Verify all sides are equal length
        final distances = <double>[];
        for (int i = 0; i < path.anchors.length; i++) {
          final current = path.anchors[i].position;
          final next = path.anchors[(i + 1) % path.anchors.length].position;
          final dx = next.x - current.x;
          final dy = next.y - current.y;
          distances.add(sqrt(dx * dx + dy * dy));
        }

        // All sides should be approximately equal
        final avgDistance = distances.reduce((a, b) => a + b) / distances.length;
        for (final distance in distances) {
          expect((distance - avgDistance).abs(), lessThan(0.01));
        }
      });

      test('polygon vertices are equidistant from center', () {
        // Arrange
        polygonTool.setSideCount(5); // Pentagon
        polygonTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        polygonTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 200)),
        );

        final event = recorder.createShapeEvents[0];

        // Act: Create shape
        final shape = Shape.polygon(
          center: Point(
            x: event.parameters['centerX']!,
            y: event.parameters['centerY']!,
          ),
          radius: event.parameters['radius']!,
          sides: 5,
          rotation: 0,
        );

        final path = shape.toPath();
        final center = Point(
          x: event.parameters['centerX']!,
          y: event.parameters['centerY']!,
        );
        final expectedRadius = event.parameters['radius']!;

        // Assert: All vertices equidistant from center
        for (final anchor in path.anchors) {
          final dx = anchor.position.x - center.x;
          final dy = anchor.position.y - center.y;
          final distance = sqrt(dx * dx + dy * dy);
          expect(distance, closeTo(expectedRadius, 0.01));
        }
      });
    });

    group('AC5: Integration tests create 3-sided and 8-sided polygons', () {
      test('complete workflow: create triangle (3 sides)', () {
        // 1. Configure tool for triangle
        polygonTool.setSideCount(3);
        expect(polygonTool.sideCount, equals(3));

        // 2. Drag interaction
        polygonTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        polygonTool.onPointerMove(
          const PointerMoveEvent(position: ui.Offset(150, 150)),
        );

        polygonTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 200)),
        );

        // 3. Verify CreateShapeEvent persisted
        expect(recorder.createShapeEvents.length, equals(1));
        final event = recorder.createShapeEvents[0];
        expect(event.shapeType, equals(ShapeType.polygon));

        // 4. Verify triangle parameters
        final params = event.parameters;
        expect(params['sides'], equals(3.0));
        expect(params['centerX'], equals(150.0));
        expect(params['centerY'], equals(150.0));
        expect(params['radius'], equals(50.0));
        expect(params['rotation'], equals(0.0));

        // 5. Verify Shape can be created and has 3 vertices
        final shape = Shape.polygon(
          center: Point(x: params['centerX']!, y: params['centerY']!),
          radius: params['radius']!,
          sides: params['sides']!.toInt(),
          rotation: params['rotation'] ?? 0.0,
        );

        final path = shape.toPath();
        expect(path.anchors.length, equals(3)); // Triangle has 3 vertices
        expect(path.closed, isTrue);

        // 6. Verify triangle is regular (all sides equal)
        final distances = <double>[];
        for (int i = 0; i < path.anchors.length; i++) {
          final current = path.anchors[i].position;
          final next = path.anchors[(i + 1) % path.anchors.length].position;
          final dx = next.x - current.x;
          final dy = next.y - current.y;
          distances.add(sqrt(dx * dx + dy * dy));
        }

        final avgDistance = distances.reduce((a, b) => a + b) / distances.length;
        for (final distance in distances) {
          expect((distance - avgDistance).abs(), lessThan(0.01));
        }

        // 7. Verify event was persisted to store
        expect(store.events.contains(event), isTrue);
      });

      test('complete workflow: create octagon (8 sides)', () {
        // 1. Configure tool for octagon
        polygonTool.setSideCount(8);
        expect(polygonTool.sideCount, equals(8));

        // 2. Drag interaction with larger dimensions
        polygonTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        polygonTool.onPointerMove(
          const PointerMoveEvent(position: ui.Offset(200, 200)),
        );

        polygonTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(300, 300)),
        );

        // 3. Verify CreateShapeEvent persisted
        expect(recorder.createShapeEvents.length, equals(1));
        final event = recorder.createShapeEvents[0];
        expect(event.shapeType, equals(ShapeType.polygon));

        // 4. Verify octagon parameters
        final params = event.parameters;
        expect(params['sides'], equals(8.0));
        expect(params['centerX'], equals(200.0));
        expect(params['centerY'], equals(200.0));
        expect(params['radius'], equals(100.0));
        expect(params['rotation'], equals(0.0));

        // 5. Verify Shape can be created and has 8 vertices
        final shape = Shape.polygon(
          center: Point(x: params['centerX']!, y: params['centerY']!),
          radius: params['radius']!,
          sides: params['sides']!.toInt(),
          rotation: params['rotation'] ?? 0.0,
        );

        final path = shape.toPath();
        expect(path.anchors.length, equals(8)); // Octagon has 8 vertices
        expect(path.closed, isTrue);

        // 6. Verify octagon is regular (all sides equal)
        final distances = <double>[];
        for (int i = 0; i < path.anchors.length; i++) {
          final current = path.anchors[i].position;
          final next = path.anchors[(i + 1) % path.anchors.length].position;
          final dx = next.x - current.x;
          final dy = next.y - current.y;
          distances.add(sqrt(dx * dx + dy * dy));
        }

        final avgDistance = distances.reduce((a, b) => a + b) / distances.length;
        for (final distance in distances) {
          expect((distance - avgDistance).abs(), lessThan(0.01));
        }

        // 7. Verify all vertices are equidistant from center
        final center = Point(x: params['centerX']!, y: params['centerY']!);
        final expectedRadius = params['radius']!;
        for (final anchor in path.anchors) {
          final dx = anchor.position.x - center.x;
          final dy = anchor.position.y - center.y;
          final distance = sqrt(dx * dx + dy * dy);
          expect(distance, closeTo(expectedRadius, 0.01));
        }

        // 8. Verify event was persisted to store
        expect(store.events.contains(event), isTrue);
      });

      test('triangle and octagon from same event parameters produce correct shapes', () async {
        // Test triangle
        polygonTool.setSideCount(3);
        polygonTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );
        polygonTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 200)),
        );

        // Wait for event to be persisted
        await Future.delayed(const Duration(milliseconds: 100));

        final triangleEvent = recorder.createShapeEvents[0];
        expect(triangleEvent.parameters['sides'], equals(3.0));

        // Test octagon (don't clear - we want both events)
        polygonTool.setSideCount(8);
        polygonTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );
        polygonTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 200)),
        );

        // Wait for event to be persisted
        await Future.delayed(const Duration(milliseconds: 100));

        final octagonEvent = recorder.createShapeEvents[1];
        expect(octagonEvent.parameters['sides'], equals(8.0));

        // Verify both can be recreated from events
        final triangle = Shape.polygon(
          center: Point(
            x: triangleEvent.parameters['centerX']!,
            y: triangleEvent.parameters['centerY']!,
          ),
          radius: triangleEvent.parameters['radius']!,
          sides: triangleEvent.parameters['sides']!.toInt(),
        );

        final octagon = Shape.polygon(
          center: Point(
            x: octagonEvent.parameters['centerX']!,
            y: octagonEvent.parameters['centerY']!,
          ),
          radius: octagonEvent.parameters['radius']!,
          sides: octagonEvent.parameters['sides']!.toInt(),
        );

        expect(triangle.toPath().anchors.length, equals(3));
        expect(octagon.toPath().anchors.length, equals(8));
      });
    });

    group('Event Persistence and Replay', () {
      test('CreateShapeEvent persisted through EventRecorder', () {
        // Act
        polygonTool.setSideCount(6);
        polygonTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        polygonTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 200)),
        );

        // Assert: Event in store
        expect(store.events.length, equals(1));
        expect(store.events[0], isA<CreateShapeEvent>());

        final event = store.events[0] as CreateShapeEvent;
        expect(event.shapeId, isNotEmpty);
        expect(event.eventId, isNotEmpty);
        expect(event.timestamp, greaterThan(0));
      });

      test('event replay produces identical geometry', () {
        // Create polygon
        polygonTool.setSideCount(7); // Heptagon
        polygonTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        polygonTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(300, 300)),
        );

        final event = recorder.createShapeEvents[0];

        // Create original shape (what tool created)
        final originalShape = Shape.polygon(
          center: Point(x: 200, y: 200),
          radius: 100,
          sides: 7,
          rotation: 0,
        );

        // Recreate from event parameters
        final recreatedShape = Shape.polygon(
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
        expect(recreatedPath.anchors.length, equals(7));

        // Verify each anchor position matches
        for (int i = 0; i < originalPath.anchors.length; i++) {
          final orig = originalPath.anchors[i].position;
          final recreated = recreatedPath.anchors[i].position;
          expect((recreated.x - orig.x).abs(), lessThan(0.01));
          expect((recreated.y - orig.y).abs(), lessThan(0.01));
        }
      });

      test('multiple polygons create separate events', () async {
        // Create first polygon (triangle)
        polygonTool.setSideCount(3);
        polygonTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );
        polygonTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 200)),
        );

        // Wait for event to be persisted
        await Future.delayed(const Duration(milliseconds: 100));

        // Create second polygon (octagon)
        polygonTool.setSideCount(8);
        polygonTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(300, 300)),
        );
        polygonTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(500, 500)),
        );

        await Future.delayed(const Duration(milliseconds: 100));

        // Assert: Two separate events
        expect(recorder.createShapeEvents.length, equals(2));

        final event1 = recorder.createShapeEvents[0];
        final event2 = recorder.createShapeEvents[1];

        // Verify they are distinct
        expect(event1.eventId, isNot(equals(event2.eventId)));
        expect(event1.shapeId, isNot(equals(event2.shapeId)));
        expect(event1.parameters['sides'], equals(3.0));
        expect(event2.parameters['sides'], equals(8.0));
      });
    });

    group('Edge Cases and Error Handling', () {
      test('Escape key cancels polygon creation', () {
        polygonTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        polygonTool.onPointerMove(
          const PointerMoveEvent(position: ui.Offset(150, 150)),
        );

        // Press Escape before pointer up
        final handled = polygonTool.onKeyPress(
          const KeyDownEvent(
            logicalKey: LogicalKeyboardKey.escape,
            physicalKey: PhysicalKeyboardKey.escape,
            timeStamp: Duration.zero,
          ),
        );

        expect(handled, isTrue);

        // Complete drag anyway
        polygonTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 200)),
        );

        // No event should be created
        expect(recorder.createShapeEvents.length, equals(0));
      });

      test('tool deactivation mid-drag resets state', () {
        polygonTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        // Deactivate mid-drag
        polygonTool.onDeactivate();

        // Reactivate and try to complete
        polygonTool.onActivate();

        polygonTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 200)),
        );

        // No event should be created (state was reset)
        expect(recorder.createShapeEvents.length, equals(0));
      });

      test('only one event persisted per drag', () {
        polygonTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        // Multiple moves
        polygonTool.onPointerMove(
          const PointerMoveEvent(position: ui.Offset(120, 120)),
        );
        polygonTool.onPointerMove(
          const PointerMoveEvent(position: ui.Offset(150, 150)),
        );
        polygonTool.onPointerMove(
          const PointerMoveEvent(position: ui.Offset(180, 180)),
        );

        polygonTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 200)),
        );

        // Only one event should be persisted
        expect(recorder.createShapeEvents.length, equals(1));
      });

      test('viewport transformations handled correctly', () {
        // Change viewport zoom
        viewport.setZoom(2.0);
        viewport.pan(const ui.Offset(50, 50));

        polygonTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        polygonTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 200)),
        );

        // World coordinates should be transformed correctly
        final event = recorder.createShapeEvents[0];
        expect(event.parameters['centerX'], isNotNull);
        expect(event.parameters['centerY'], isNotNull);
        expect(event.parameters['radius'], isNotNull);
      });
    });

    group('Tool Lifecycle', () {
      test('activation resets tool state', () {
        polygonTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        // Deactivate without completing
        polygonTool.onDeactivate();

        // Reactivate
        polygonTool.onActivate();

        // Start new drag
        polygonTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(200, 200)),
        );

        polygonTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(300, 300)),
        );

        // Should only create one event (the second drag)
        expect(recorder.createShapeEvents.length, equals(1));

        final params = recorder.createShapeEvents[0].parameters;
        expect(params['centerX'], equals(250.0));
        expect(params['centerY'], equals(250.0));
      });

      test('tool has correct ID and cursor', () {
        expect(polygonTool.toolId, equals('polygon'));
        expect(polygonTool.cursor, equals(SystemMouseCursors.precise));
      });

      test('side count persists across tool lifecycle', () {
        // Configure tool
        polygonTool.setSideCount(10);
        expect(polygonTool.sideCount, equals(10));

        // Deactivate and reactivate
        polygonTool.onDeactivate();
        polygonTool.onActivate();

        // Side count should be preserved
        expect(polygonTool.sideCount, equals(10));

        // Verify it's used in events
        polygonTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );
        polygonTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 200)),
        );

        final params = recorder.createShapeEvents[0].parameters;
        expect(params['sides'], equals(10.0));
      });
    });

    group('Style and Visual Properties', () {
      test('default stroke style applied to polygon', () {
        polygonTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        polygonTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 200)),
        );

        final event = recorder.createShapeEvents[0];

        // Verify default style
        expect(event.strokeColor, equals('#000000'));
        expect(event.strokeWidth, equals(2.0));
      });

      test('rotation parameter included in events', () {
        polygonTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        polygonTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 200)),
        );

        final params = recorder.createShapeEvents[0].parameters;
        expect(params['rotation'], equals(0.0));
      });
    });
  });
}
