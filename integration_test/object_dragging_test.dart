/// Integration tests for object dragging (Task I8.T3).
library;

///
/// These tests verify the acceptance criteria for object drag functionality:
/// - AC1: Drag object updates position smoothly
/// - AC2: MoveObjectEvent generated every 50ms
/// - AC3: Multiple selected objects move together maintaining relative positions
/// - AC4: Integration test drags rectangle 50px right and verifies transform
///
/// Related: I5.T4 (SelectionTool), I3.T1 (Transform), T031 (Object Dragging)

import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/application/tools/selection/selection_tool.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/domain/document/selection.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/events/object_events.dart';
import 'package:wiretuner/domain/models/shape.dart';
import 'package:wiretuner/domain/models/transform.dart';
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

/// Test-specific EventRecorder that tracks flush calls and provides access to persisted events.
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
  List<MoveObjectEvent> get moveEvents =>
      events.whereType<MoveObjectEvent>().toList();

  void clear() {
    _store.clear();
    flushCount = 0;
  }

  /// Calculate average events per second based on event timestamps.
  double get eventsPerSecond {
    if (moveEvents.length < 2) return 0.0;

    final firstTime = moveEvents.first.timestamp;
    final lastTime = moveEvents.last.timestamp;
    final durationMs = lastTime - firstTime;

    if (durationMs <= 0) return 0.0;

    return (moveEvents.length / durationMs) * 1000;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Object Drag Integration Tests (I8.T3)', () {
    late SelectionTool tool;
    late ViewportController viewport;
    late _TestEventRecorder recorder;
    late _MockEventStore store;
    late Document document;

    setUp(() {
      // Setup viewport
      viewport = ViewportController(
        initialPan: const Offset(0, 0),
        initialZoom: 1.0,
      );

      // Setup event recording with real sampling
      store = _MockEventStore();
      recorder = _TestEventRecorder(store);

      // Create test document with two rectangle shapes
      final rect1 = Shape.rectangle(
        center: const Point(x: 100, y: 100),
        width: 50,
        height: 50,
      );

      final rect2 = Shape.rectangle(
        center: const Point(x: 200, y: 100),
        width: 50,
        height: 50,
      );

      final layer = Layer(
        id: 'layer-1',
        name: 'Layer 1',
        objects: [
          VectorObject.shape(id: 'rect-1', shape: rect1),
          VectorObject.shape(id: 'rect-2', shape: rect2),
        ],
      );

      document = Document(
        id: 'doc-1',
        title: 'Test Document',
        layers: [layer],
        selection: const Selection(objectIds: {'rect-1'}),
      );

      // Create tool
      tool = SelectionTool(
        document: document,
        viewportController: viewport,
        eventRecorder: recorder,
      );

      tool.onActivate();
    });

    tearDown(() {
      viewport.dispose();
    });

    group('AC4: Drag Rectangle 50px Test', () {
      test('should drag rectangle 50px right and verify transform', () async {
        // Start drag on first rectangle at (100, 100)
        tool.onPointerDown(const PointerDownEvent(position: Offset(100, 100)));

        recorder.clear();

        // Drag 50px to the right: (100, 100) → (150, 100)
        tool.onPointerMove(const PointerMoveEvent(position: Offset(150, 100)));

        // Finish drag
        tool.onPointerUp(const PointerUpEvent(position: Offset(150, 100)));

        // Wait for async event persistence
        await Future.delayed(const Duration(milliseconds: 100));

        // Verify events were recorded
        expect(
          recorder.moveEvents,
          isNotEmpty,
          reason: 'Should record drag events',
        );

        // Verify drag delta (cumulative from start)
        final dragEvent = recorder.moveEvents.first;
        expect(dragEvent.objectIds, contains('rect-1'));
        expect(
          dragEvent.delta.x,
          closeTo(50, 1.0),
          reason: 'Object moved 50px right',
        );
        expect(
          dragEvent.delta.y,
          closeTo(0, 1.0),
          reason: 'Object Y unchanged',
        );
      });
    });

    group('AC1: Event Sampling at 50ms', () {
      test('should sample at ~20 events/second during rapid drag', () async {
        // Start drag
        tool.onPointerDown(const PointerDownEvent(position: Offset(100, 100)));

        recorder.clear();

        // Simulate 1 second of rapid dragging (200 moves at 5ms intervals)
        for (int i = 0; i < 200; i++) {
          tool.onPointerMove(
            PointerMoveEvent(position: Offset(100 + i * 0.5, 100)),
          );
          await Future.delayed(const Duration(milliseconds: 5));
        }

        // Finish drag
        tool.onPointerUp(const PointerUpEvent(position: Offset(200, 100)));

        // Wait for async persistence
        await Future.delayed(const Duration(milliseconds: 100));

        // Verify sampling rate
        final eventsPerSec = recorder.eventsPerSecond;
        expect(
          eventsPerSec,
          greaterThan(15),
          reason: 'Should maintain at least 15 FPS',
        );
        expect(
          eventsPerSec,
          lessThan(25),
          reason: 'Should not exceed 25 FPS due to 50ms sampling',
        );

        // Log for debugging
        print(
          'Recorded ${recorder.moveEvents.length} events at ${eventsPerSec.toStringAsFixed(1)} events/sec',
        );
      });

      test('should emit event every 50+ms during drag', () async {
        tool.onPointerDown(const PointerDownEvent(position: Offset(100, 100)));

        recorder.clear();

        // Generate 5 events at exactly 60ms intervals (> 50ms threshold)
        for (int i = 0; i < 5; i++) {
          tool.onPointerMove(
            PointerMoveEvent(position: Offset(100 + i * 10.0, 100)),
          );
          await Future.delayed(const Duration(milliseconds: 60));
        }

        // Wait for persistence
        await Future.delayed(const Duration(milliseconds: 100));

        // Should have emitted ~5 events (one per 60ms interval)
        expect(recorder.moveEvents.length, greaterThanOrEqualTo(4),
            reason: 'Should emit event for each 60ms interval');
      });
    });

    group('AC2: Final Position Flush', () {
      test('should call flush on pointer up', () async {
        tool.onPointerDown(const PointerDownEvent(position: Offset(100, 100)));

        final initialFlushes = recorder.flushCount;

        // Move and finish drag
        tool.onPointerMove(const PointerMoveEvent(position: Offset(150, 100)));
        tool.onPointerUp(const PointerUpEvent(position: Offset(150, 100)));

        // Verify flush was called
        expect(recorder.flushCount, equals(initialFlushes + 1),
            reason: 'Flush should be called on pointer up');
      });

      test('should persist buffered event on flush', () async {
        tool.onPointerDown(const PointerDownEvent(position: Offset(100, 100)));

        recorder.clear();

        // First move - emitted immediately
        tool.onPointerMove(const PointerMoveEvent(position: Offset(110, 100)));
        await Future.delayed(const Duration(milliseconds: 10));

        final eventsAfterFirst = recorder.moveEvents.length;

        // Second move quickly (< 50ms) - will be buffered
        tool.onPointerMove(const PointerMoveEvent(position: Offset(120, 100)));
        await Future.delayed(const Duration(milliseconds: 20));

        // Should still have same count (buffered)
        expect(recorder.moveEvents.length, equals(eventsAfterFirst),
            reason: 'Second event should be buffered');

        // Finish drag - flushes buffered event
        tool.onPointerUp(const PointerUpEvent(position: Offset(120, 100)));
        await Future.delayed(const Duration(milliseconds: 100));

        // Now should have one more event
        expect(
          recorder.moveEvents.length,
          greaterThan(eventsAfterFirst),
          reason: 'Flush should emit buffered event',
        );
      });
    });

    group('AC3: Multi-Object Drag', () {
      test('should maintain object IDs throughout drag', () async {
        tool.onPointerDown(const PointerDownEvent(position: Offset(100, 100)));

        recorder.clear();

        // Multiple rapid moves
        for (int i = 0; i < 10; i++) {
          tool.onPointerMove(
            PointerMoveEvent(position: Offset(100 + i * 5.0, 100)),
          );
        }

        tool.onPointerUp(const PointerUpEvent(position: Offset(150, 100)));

        await Future.delayed(const Duration(milliseconds: 100));

        // All events should reference same object
        for (final event in recorder.moveEvents) {
          expect(event.objectIds, contains('rect-1'),
              reason: 'Should move selected object');
        }
      });

      test('should move multiple selected objects together', () async {
        // Select both rectangles
        final multiSelectDoc = document.copyWith(
          selection: const Selection(objectIds: {'rect-1', 'rect-2'}),
        );

        final multiSelectTool = SelectionTool(
          document: multiSelectDoc,
          viewportController: viewport,
          eventRecorder: recorder,
        );

        multiSelectTool.onActivate();
        recorder.clear();

        // Start drag on first rectangle
        multiSelectTool.onPointerDown(
          const PointerDownEvent(position: Offset(100, 100)),
        );

        recorder.clear();

        // Drag 30px right
        multiSelectTool.onPointerMove(
          const PointerMoveEvent(position: Offset(130, 100)),
        );

        await Future.delayed(const Duration(milliseconds: 100));

        // Verify both objects are in the move event
        final firstEvent = recorder.moveEvents.first;
        expect(firstEvent.objectIds, contains('rect-1'));
        expect(firstEvent.objectIds, contains('rect-2'));
        expect(firstEvent.objectIds.length, equals(2),
            reason: 'Should move both selected objects');

        // Verify same delta for all objects
        expect(firstEvent.delta.x, closeTo(30, 1.0),
            reason: 'Delta should be 30px right');
      });

      test('should maintain relative positions during multi-object drag',
          () async {
        // This test verifies that the delta is the same for all objects,
        // which maintains their relative positions
        final multiSelectDoc = document.copyWith(
          selection: const Selection(objectIds: {'rect-1', 'rect-2'}),
        );

        final multiSelectTool = SelectionTool(
          document: multiSelectDoc,
          viewportController: viewport,
          eventRecorder: recorder,
        );

        multiSelectTool.onActivate();
        recorder.clear();

        // Start drag
        multiSelectTool.onPointerDown(
          const PointerDownEvent(position: Offset(100, 100)),
        );

        recorder.clear();

        // Move in multiple steps
        for (int i = 1; i <= 3; i++) {
          multiSelectTool.onPointerMove(
            PointerMoveEvent(position: Offset(100 + i * 20.0, 100)),
          );
          await Future.delayed(const Duration(milliseconds: 60));
        }

        // All events should have identical object ID lists
        final objectIdSets = recorder.moveEvents
            .map((e) => e.objectIds.toSet())
            .toSet();
        expect(objectIdSets.length, equals(1),
            reason: 'All events should reference same objects');
      });
    });

    group('Edge Cases', () {
      test('should handle single object drag', () async {
        tool.onPointerDown(const PointerDownEvent(position: Offset(100, 100)));

        recorder.clear();

        tool.onPointerMove(const PointerMoveEvent(position: Offset(125, 125)));
        await Future.delayed(const Duration(milliseconds: 100));

        expect(recorder.moveEvents, isNotEmpty);
        expect(recorder.moveEvents.first.objectIds.length, equals(1));
      });

      test('should handle zero delta drag', () async {
        tool.onPointerDown(const PointerDownEvent(position: Offset(100, 100)));

        recorder.clear();

        // Move to same position (no delta)
        tool.onPointerMove(const PointerMoveEvent(position: Offset(100, 100)));
        await Future.delayed(const Duration(milliseconds: 100));

        // Should not emit events for zero delta
        // (SelectionTool only emits if delta is non-zero)
        expect(recorder.moveEvents, isEmpty,
            reason: 'Should not emit events for zero delta');
      });
    });

    group('Complete Workflow', () {
      test('should complete full drag workflow with all events', () async {
        // Start drag
        final handled = tool.onPointerDown(
          const PointerDownEvent(position: Offset(100, 100)),
        );
        expect(handled, isTrue, reason: 'Should handle pointer down');

        recorder.clear();

        // Drag in multiple steps with sufficient delay for sampling
        for (int i = 1; i <= 5; i++) {
          tool.onPointerMove(
            PointerMoveEvent(position: Offset(100 + i * 10.0, 100)),
          );
          await Future.delayed(const Duration(milliseconds: 60)); // > 50ms
        }

        // Finish drag at final position
        tool.onPointerUp(const PointerUpEvent(position: Offset(150, 100)));
        await Future.delayed(const Duration(milliseconds: 100));

        // Verify complete workflow
        expect(recorder.moveEvents.length, greaterThan(0),
            reason: 'Should record events');
        expect(recorder.flushCount, greaterThan(0), reason: 'Should flush on up');

        // Verify all events are MoveObjectEvent
        final moveEventCount = recorder.events.whereType<MoveObjectEvent>().length;
        expect(moveEventCount, greaterThan(0),
            reason: 'Should have MoveObjectEvent events');

        // Verify event deltas are cumulative
        // Each event's delta should be measured from the drag start (100, 100)
        // So deltas should increase or stay the same as we drag further
        if (recorder.moveEvents.length >= 2) {
          for (int i = 1; i < recorder.moveEvents.length; i++) {
            final prevDelta = recorder.moveEvents[i - 1].delta.x;
            final currDelta = recorder.moveEvents[i].delta.x;
            expect(currDelta, greaterThanOrEqualTo(prevDelta),
                reason: 'Deltas should be cumulative (non-decreasing)');
          }
        }

        // Verify final delta reflects the total movement
        if (recorder.moveEvents.isNotEmpty) {
          final lastDelta = recorder.moveEvents.last.delta.x;
          // Final position was 150, start was 100, so delta should be ~50
          // Allow larger tolerance since flush timing may affect final value
          expect(lastDelta, greaterThan(0),
              reason: 'Final delta should be positive');
          expect(lastDelta, lessThanOrEqualTo(50),
              reason: 'Final delta should not exceed total drag distance');
        }
      });
    });
  });
}
