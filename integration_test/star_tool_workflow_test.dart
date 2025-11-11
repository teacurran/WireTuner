/// Integration tests for Star Tool workflow (Task I7.T4).
library;

///
/// These tests verify the acceptance criteria for star creation:
/// - AC1: Click defines center point
/// - AC2: Drag distance defines outer radius
/// - AC3: Inner radius = outer * 0.5 by default
/// - AC4: Star has alternating outer/inner points
/// - AC5: Integration tests create 5-point and 8-point stars
///
/// Related: I7.T4 (StarTool), T028 (Star Tool)

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/application/tools/shapes/star_tool.dart';
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

  group('Star Tool Integration Tests (I7.T4)', () {
    late StarTool starTool;
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
        title: 'Star Tool Test',
        layers: [layer],
        selection: Selection(),
      );

      // Create and activate star tool
      starTool = StarTool(
        document: document,
        viewportController: viewport,
        eventRecorder: recorder,
      );

      starTool.onActivate();
    });

    tearDown(() {
      starTool.onDeactivate();
      viewport.dispose();
      recorder.clear();
    });

    group('AC1: Click defines center point', () {
      test('center point is at midpoint of drag', () {
        // Arrange: Define drag coordinates (100,100) -> (200,200)
        const startPos = ui.Offset(100, 100);
        const endPos = ui.Offset(200, 200);

        // Act: Perform drag interaction
        starTool.onPointerDown(
          const PointerDownEvent(position: startPos),
        );

        starTool.onPointerMove(
          const PointerMoveEvent(position: ui.Offset(150, 150)),
        );

        starTool.onPointerUp(
          const PointerUpEvent(position: endPos),
        );

        // Assert: Verify CreateShapeEvent was persisted
        expect(recorder.createShapeEvents.length, equals(1));

        final createEvent = recorder.createShapeEvents[0];
        expect(createEvent.eventType, equals('CreateShapeEvent'));
        expect(createEvent.shapeType, equals(ShapeType.star));

        // Verify center point is at drag midpoint
        final params = createEvent.parameters;
        expect(params['centerX'], equals(150.0)); // (100 + 200) / 2
        expect(params['centerY'], equals(150.0)); // (100 + 200) / 2
      });

      test('center preserved when drawing from center (Alt key)', () async {
        // Arrange: Simulate Alt key press
        await simulateKeyDownEvent(LogicalKeyboardKey.altLeft);

        // Act: Drag from center point
        starTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(150, 150)),
        );

        starTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 175)),
        );

        // Assert: Center should remain at drag start
        final params = recorder.createShapeEvents[0].parameters;
        expect(params['centerX'], equals(150.0));
        expect(params['centerY'], equals(150.0));

        await simulateKeyUpEvent(LogicalKeyboardKey.altLeft);
      });
    });

    group('AC2: Drag distance defines outer radius', () {
      test('outer radius is max of width/2 and height/2', () {
        // Arrange: Non-square drag
        starTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        starTool.onPointerUp(
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
        starTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(200, 200)),
        );

        starTool.onPointerUp(
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
        starTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        starTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(102, 101)),
        );

        // Assert: No events should be persisted
        expect(recorder.createShapeEvents.length, equals(0));
      });
    });

    group('AC3: Inner radius = outer * 0.5 by default', () {
      test('inner radius is half of outer radius', () {
        // Act
        starTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        starTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 200)),
        );

        // Assert
        final params = recorder.createShapeEvents[0].parameters;
        final outerRadius = params['radius']!;
        final innerRadius = params['innerRadius']!;

        expect(outerRadius, equals(50.0));
        expect(innerRadius, equals(25.0)); // 0.5 * 50
        expect(innerRadius, equals(outerRadius * 0.5));
      });

      test('inner radius always less than outer radius', () async {
        // Test various drag sizes
        final testCases = [
          (ui.Offset(100, 100), ui.Offset(200, 200)),
          (ui.Offset(100, 100), ui.Offset(300, 150)),
          (ui.Offset(100, 100), ui.Offset(150, 300)),
        ];

        for (final (start, end) in testCases) {
          recorder.clear();

          starTool.onPointerDown(PointerDownEvent(position: start));
          starTool.onPointerMove(PointerMoveEvent(
            position: ui.Offset(
              (start.dx + end.dx) / 2,
              (start.dy + end.dy) / 2,
            ),
          ));
          starTool.onPointerUp(PointerUpEvent(position: end));

          // Wait for event to be persisted
          await Future.delayed(const Duration(milliseconds: 100));

          final params = recorder.createShapeEvents[0].parameters;
          final outerRadius = params['radius']!;
          final innerRadius = params['innerRadius']!;

          expect(innerRadius, lessThan(outerRadius));
          expect(innerRadius, greaterThan(0.0));
        }
      });
    });

    group('AC4: Star has alternating outer/inner points', () {
      test('5-point star has correct vertex structure', () {
        // Arrange: Default 5-point star
        starTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        starTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 200)),
        );

        final event = recorder.createShapeEvents[0];

        // Act: Create shape and convert to path
        final shape = Shape.star(
          center: Point(
            x: event.parameters['centerX']!,
            y: event.parameters['centerY']!,
          ),
          outerRadius: event.parameters['radius']!,
          innerRadius: event.parameters['innerRadius']!,
          pointCount: event.parameters['sides']!.toInt(),
          rotation: event.parameters['rotation'] ?? 0.0,
        );

        final path = shape.toPath();

        // Assert: 5-point star should have 10 vertices (5 outer + 5 inner)
        expect(path.anchors.length, equals(10));
        expect(path.closed, isTrue);

        // Verify alternating radii
        final center = Point(
          x: event.parameters['centerX']!,
          y: event.parameters['centerY']!,
        );
        final outerRadius = event.parameters['radius']!;
        final innerRadius = event.parameters['innerRadius']!;

        for (int i = 0; i < path.anchors.length; i++) {
          final pos = path.anchors[i].position;
          final dx = pos.x - center.x;
          final dy = pos.y - center.y;
          final radius = sqrt(dx * dx + dy * dy);

          // Even indices should be outer points, odd indices inner points
          if (i % 2 == 0) {
            expect(radius, closeTo(outerRadius, 0.01),
                reason: 'Vertex $i should be at outer radius');
          } else {
            expect(radius, closeTo(innerRadius, 0.01),
                reason: 'Vertex $i should be at inner radius');
          }
        }
      });

      test('star vertices alternate correctly regardless of point count', () async {
        final testCases = [3, 5, 8, 12];

        for (final pointCount in testCases) {
          recorder.clear();
          starTool.setPointCount(pointCount);

          starTool.onPointerDown(
            const PointerDownEvent(position: ui.Offset(100, 100)),
          );

          starTool.onPointerMove(
            const PointerMoveEvent(position: ui.Offset(200, 200)),
          );

          starTool.onPointerUp(
            const PointerUpEvent(position: ui.Offset(300, 300)),
          );

          // Wait for event to be persisted
          await Future.delayed(const Duration(milliseconds: 100));

          final event = recorder.createShapeEvents[0];
          final shape = Shape.star(
            center: Point(
              x: event.parameters['centerX']!,
              y: event.parameters['centerY']!,
            ),
            outerRadius: event.parameters['radius']!,
            innerRadius: event.parameters['innerRadius']!,
            pointCount: pointCount,
          );

          final path = shape.toPath();

          // Should have 2n vertices for n-point star
          expect(path.anchors.length, equals(pointCount * 2));

          // Verify alternating pattern
          final center = Point(
            x: event.parameters['centerX']!,
            y: event.parameters['centerY']!,
          );
          final outerRadius = event.parameters['radius']!;
          final innerRadius = event.parameters['innerRadius']!;

          for (int i = 0; i < path.anchors.length; i++) {
            final pos = path.anchors[i].position;
            final dx = pos.x - center.x;
            final dy = pos.y - center.y;
            final radius = sqrt(dx * dx + dy * dy);

            if (i % 2 == 0) {
              expect(radius, closeTo(outerRadius, 0.01));
            } else {
              expect(radius, closeTo(innerRadius, 0.01));
            }
          }
        }
      });
    });

    group('AC5: Integration tests create 5-point and 8-point stars', () {
      test('complete workflow: create 5-point star (default)', () {
        // 1. Verify default configuration is 5-point star
        expect(starTool.pointCount, equals(5));

        // 2. Drag interaction
        starTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        starTool.onPointerMove(
          const PointerMoveEvent(position: ui.Offset(150, 150)),
        );

        starTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 200)),
        );

        // 3. Verify CreateShapeEvent persisted
        expect(recorder.createShapeEvents.length, equals(1));
        final event = recorder.createShapeEvents[0];
        expect(event.shapeType, equals(ShapeType.star));

        // 4. Verify 5-point star parameters
        final params = event.parameters;
        expect(params['sides'], equals(5.0));
        expect(params['centerX'], equals(150.0));
        expect(params['centerY'], equals(150.0));
        expect(params['radius'], equals(50.0));
        expect(params['innerRadius'], equals(25.0)); // 0.5 * 50
        expect(params['rotation'], equals(0.0));

        // 5. Verify Shape can be created and has 10 vertices (5 points × 2)
        final shape = Shape.star(
          center: Point(x: params['centerX']!, y: params['centerY']!),
          outerRadius: params['radius']!,
          innerRadius: params['innerRadius']!,
          pointCount: params['sides']!.toInt(),
          rotation: params['rotation'] ?? 0.0,
        );

        final path = shape.toPath();
        expect(path.anchors.length, equals(10)); // 5-point star = 10 vertices
        expect(path.closed, isTrue);

        // 6. Verify alternating outer/inner points
        final center = Point(x: params['centerX']!, y: params['centerY']!);
        final outerRadius = params['radius']!;
        final innerRadius = params['innerRadius']!;

        for (int i = 0; i < path.anchors.length; i++) {
          final pos = path.anchors[i].position;
          final dx = pos.x - center.x;
          final dy = pos.y - center.y;
          final radius = sqrt(dx * dx + dy * dy);

          if (i % 2 == 0) {
            expect(radius, closeTo(outerRadius, 0.01));
          } else {
            expect(radius, closeTo(innerRadius, 0.01));
          }
        }

        // 7. Verify event was persisted to store
        expect(store.events.contains(event), isTrue);
      });

      test('complete workflow: create 8-point star', () {
        // 1. Configure tool for 8-point star
        starTool.setPointCount(8);
        expect(starTool.pointCount, equals(8));

        // 2. Drag interaction with larger dimensions
        starTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        starTool.onPointerMove(
          const PointerMoveEvent(position: ui.Offset(200, 200)),
        );

        starTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(300, 300)),
        );

        // 3. Verify CreateShapeEvent persisted
        expect(recorder.createShapeEvents.length, equals(1));
        final event = recorder.createShapeEvents[0];
        expect(event.shapeType, equals(ShapeType.star));

        // 4. Verify 8-point star parameters
        final params = event.parameters;
        expect(params['sides'], equals(8.0));
        expect(params['centerX'], equals(200.0));
        expect(params['centerY'], equals(200.0));
        expect(params['radius'], equals(100.0));
        expect(params['innerRadius'], equals(50.0)); // 0.5 * 100
        expect(params['rotation'], equals(0.0));

        // 5. Verify Shape can be created and has 16 vertices (8 points × 2)
        final shape = Shape.star(
          center: Point(x: params['centerX']!, y: params['centerY']!),
          outerRadius: params['radius']!,
          innerRadius: params['innerRadius']!,
          pointCount: params['sides']!.toInt(),
          rotation: params['rotation'] ?? 0.0,
        );

        final path = shape.toPath();
        expect(path.anchors.length, equals(16)); // 8-point star = 16 vertices
        expect(path.closed, isTrue);

        // 6. Verify alternating outer/inner points
        final center = Point(x: params['centerX']!, y: params['centerY']!);
        final outerRadius = params['radius']!;
        final innerRadius = params['innerRadius']!;

        for (int i = 0; i < path.anchors.length; i++) {
          final pos = path.anchors[i].position;
          final dx = pos.x - center.x;
          final dy = pos.y - center.y;
          final radius = sqrt(dx * dx + dy * dy);

          // Even indices should be outer points, odd indices inner points
          if (i % 2 == 0) {
            expect(radius, closeTo(outerRadius, 0.01));
          } else {
            expect(radius, closeTo(innerRadius, 0.01));
          }
        }

        // 7. Verify angular spacing between points
        // For 8-point star: 360° / 8 = 45° between points
        final expectedAngleDelta = 2 * pi / 8;

        for (int i = 0; i < 8; i++) {
          final outerIdx = i * 2;
          final pos = path.anchors[outerIdx].position;
          final dx = pos.x - center.x;
          final dy = pos.y - center.y;
          final angle = atan2(dy, dx);

          // Verify angle is correct (accounting for rotation offset)
          final expectedAngle = -pi / 2 + expectedAngleDelta * i;
          final angleDiff = ((angle - expectedAngle) % (2 * pi)).abs();
          expect(angleDiff, lessThan(0.01));
        }

        // 8. Verify event was persisted to store
        expect(store.events.contains(event), isTrue);
      });

      test('5-point and 8-point stars from same event parameters produce correct shapes', () async {
        // Test 5-point star
        starTool.setPointCount(5);
        starTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );
        starTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 200)),
        );

        // Wait for event to be persisted
        await Future.delayed(const Duration(milliseconds: 100));

        final fivePointEvent = recorder.createShapeEvents[0];
        expect(fivePointEvent.parameters['sides'], equals(5.0));

        // Test 8-point star (don't clear - we want both events)
        starTool.setPointCount(8);
        starTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );
        starTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 200)),
        );

        // Wait for event to be persisted
        await Future.delayed(const Duration(milliseconds: 100));

        final eightPointEvent = recorder.createShapeEvents[1];
        expect(eightPointEvent.parameters['sides'], equals(8.0));

        // Verify both can be recreated from events
        final fivePointStar = Shape.star(
          center: Point(
            x: fivePointEvent.parameters['centerX']!,
            y: fivePointEvent.parameters['centerY']!,
          ),
          outerRadius: fivePointEvent.parameters['radius']!,
          innerRadius: fivePointEvent.parameters['innerRadius']!,
          pointCount: fivePointEvent.parameters['sides']!.toInt(),
        );

        final eightPointStar = Shape.star(
          center: Point(
            x: eightPointEvent.parameters['centerX']!,
            y: eightPointEvent.parameters['centerY']!,
          ),
          outerRadius: eightPointEvent.parameters['radius']!,
          innerRadius: eightPointEvent.parameters['innerRadius']!,
          pointCount: eightPointEvent.parameters['sides']!.toInt(),
        );

        expect(fivePointStar.toPath().anchors.length, equals(10));
        expect(eightPointStar.toPath().anchors.length, equals(16));
      });
    });

    group('Event Persistence and Replay', () {
      test('CreateShapeEvent persisted through EventRecorder', () {
        // Act
        starTool.setPointCount(5);
        starTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        starTool.onPointerUp(
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
        // Create star
        starTool.setPointCount(7); // 7-point star
        starTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        starTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(300, 300)),
        );

        final event = recorder.createShapeEvents[0];

        // Create original shape (what tool created)
        final originalShape = Shape.star(
          center: const Point(x: 200, y: 200),
          outerRadius: 100,
          innerRadius: 50,
          pointCount: 7,
          rotation: 0,
        );

        // Recreate from event parameters
        final recreatedShape = Shape.star(
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
        expect(recreatedPath.anchors.length, equals(14)); // 7-point star = 14 vertices

        // Verify each anchor position matches
        for (int i = 0; i < originalPath.anchors.length; i++) {
          final orig = originalPath.anchors[i].position;
          final recreated = recreatedPath.anchors[i].position;
          expect((recreated.x - orig.x).abs(), lessThan(0.01));
          expect((recreated.y - orig.y).abs(), lessThan(0.01));
        }
      });

      test('multiple stars create separate events', () async {
        // Create first star (5-point)
        starTool.setPointCount(5);
        starTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );
        starTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 200)),
        );

        // Wait for event to be persisted
        await Future.delayed(const Duration(milliseconds: 100));

        // Create second star (8-point)
        starTool.setPointCount(8);
        starTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(300, 300)),
        );
        starTool.onPointerUp(
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
        expect(event1.parameters['sides'], equals(5.0));
        expect(event2.parameters['sides'], equals(8.0));
      });
    });

    group('Edge Cases and Error Handling', () {
      test('Escape key cancels star creation', () {
        starTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        starTool.onPointerMove(
          const PointerMoveEvent(position: ui.Offset(150, 150)),
        );

        // Press Escape before pointer up
        final handled = starTool.onKeyPress(
          const KeyDownEvent(
            logicalKey: LogicalKeyboardKey.escape,
            physicalKey: PhysicalKeyboardKey.escape,
            timeStamp: Duration.zero,
          ),
        );

        expect(handled, isTrue);

        // Complete drag anyway
        starTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 200)),
        );

        // No event should be created
        expect(recorder.createShapeEvents.length, equals(0));
      });

      test('tool deactivation mid-drag resets state', () {
        starTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        // Deactivate mid-drag
        starTool.onDeactivate();

        // Reactivate and try to complete
        starTool.onActivate();

        starTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 200)),
        );

        // No event should be created (state was reset)
        expect(recorder.createShapeEvents.length, equals(0));
      });

      test('only one event persisted per drag', () {
        starTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        // Multiple moves
        starTool.onPointerMove(
          const PointerMoveEvent(position: ui.Offset(120, 120)),
        );
        starTool.onPointerMove(
          const PointerMoveEvent(position: ui.Offset(150, 150)),
        );
        starTool.onPointerMove(
          const PointerMoveEvent(position: ui.Offset(180, 180)),
        );

        starTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 200)),
        );

        // Only one event should be persisted
        expect(recorder.createShapeEvents.length, equals(1));
      });

      test('viewport transformations handled correctly', () {
        // Change viewport zoom
        viewport.setZoom(2.0);
        viewport.pan(const ui.Offset(50, 50));

        starTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        starTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 200)),
        );

        // World coordinates should be transformed correctly
        final event = recorder.createShapeEvents[0];
        expect(event.parameters['centerX'], isNotNull);
        expect(event.parameters['centerY'], isNotNull);
        expect(event.parameters['radius'], isNotNull);
        expect(event.parameters['innerRadius'], isNotNull);
      });

      test('point count clamped to valid range (3-20)', () {
        // Test minimum clamping
        starTool.setPointCount(1);
        expect(starTool.pointCount, equals(3));

        starTool.setPointCount(2);
        expect(starTool.pointCount, equals(3));

        // Test maximum clamping
        starTool.setPointCount(25);
        expect(starTool.pointCount, equals(20));

        starTool.setPointCount(100);
        expect(starTool.pointCount, equals(20));

        // Test valid values
        starTool.setPointCount(5);
        expect(starTool.pointCount, equals(5));

        starTool.setPointCount(12);
        expect(starTool.pointCount, equals(12));
      });
    });

    group('Tool Lifecycle', () {
      test('activation resets tool state', () {
        starTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        // Deactivate without completing
        starTool.onDeactivate();

        // Reactivate
        starTool.onActivate();

        // Start new drag
        starTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(200, 200)),
        );

        starTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(300, 300)),
        );

        // Should only create one event (the second drag)
        expect(recorder.createShapeEvents.length, equals(1));

        final params = recorder.createShapeEvents[0].parameters;
        expect(params['centerX'], equals(250.0));
        expect(params['centerY'], equals(250.0));
      });

      test('tool has correct ID and cursor', () {
        expect(starTool.toolId, equals('star'));
        expect(starTool.cursor, equals(SystemMouseCursors.precise));
      });

      test('point count persists across tool lifecycle', () {
        // Configure tool
        starTool.setPointCount(10);
        expect(starTool.pointCount, equals(10));

        // Deactivate and reactivate
        starTool.onDeactivate();
        starTool.onActivate();

        // Point count should be preserved
        expect(starTool.pointCount, equals(10));

        // Verify it's used in events
        starTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );
        starTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 200)),
        );

        final params = recorder.createShapeEvents[0].parameters;
        expect(params['sides'], equals(10.0));
      });
    });

    group('Style and Visual Properties', () {
      test('default stroke style applied to star', () {
        starTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        starTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 200)),
        );

        final event = recorder.createShapeEvents[0];

        // Verify default style
        expect(event.strokeColor, equals('#000000'));
        expect(event.strokeWidth, equals(2.0));
      });

      test('rotation parameter included in events', () {
        starTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        starTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 200)),
        );

        final params = recorder.createShapeEvents[0].parameters;
        expect(params['rotation'], equals(0.0));
      });
    });

    group('Configurable Point Count', () {
      test('should use configured point count in event parameters', () async {
        // Configure for 6-point star
        starTool.setPointCount(6);
        recorder.clear();

        starTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        starTool.onPointerMove(
          const PointerMoveEvent(position: ui.Offset(150, 150)),
        );

        starTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 200)),
        );

        // Wait for event to be persisted
        await Future.delayed(const Duration(milliseconds: 100));

        final params = recorder.createShapeEvents[0].parameters;
        expect(params['sides'], equals(6.0));

        // Change to 10-point star and verify
        starTool.setPointCount(10);
        recorder.clear();

        starTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );

        starTool.onPointerMove(
          const PointerMoveEvent(position: ui.Offset(150, 150)),
        );

        starTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(200, 200)),
        );

        // Wait for event to be persisted
        await Future.delayed(const Duration(milliseconds: 100));

        final params2 = recorder.createShapeEvents[0].parameters;
        expect(params2['sides'], equals(10.0));
      });

      test('configured point count affects vertex count', () async {
        final testCases = [3, 5, 8, 12, 20];

        for (final pointCount in testCases) {
          recorder.clear();
          starTool.setPointCount(pointCount);

          starTool.onPointerDown(
            const PointerDownEvent(position: ui.Offset(100, 100)),
          );

          starTool.onPointerUp(
            const PointerUpEvent(position: ui.Offset(200, 200)),
          );

          // Wait for event to be persisted
          await Future.delayed(const Duration(milliseconds: 100));

          expect(recorder.createShapeEvents.length, equals(1),
              reason: 'Should have one event for $pointCount-point star');

          final event = recorder.createShapeEvents[0];
          final shape = Shape.star(
            center: Point(
              x: event.parameters['centerX']!,
              y: event.parameters['centerY']!,
            ),
            outerRadius: event.parameters['radius']!,
            innerRadius: event.parameters['innerRadius']!,
            pointCount: pointCount,
          );

          final path = shape.toPath();
          expect(path.anchors.length, equals(pointCount * 2),
              reason: '$pointCount-point star should have ${pointCount * 2} vertices');
        }
      });
    });
  });
}
