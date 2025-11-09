/// Integration tests for anchor point dragging (Task I8.T1).
library;

///
/// These tests verify the acceptance criteria for anchor drag functionality:
/// - AC1: Drag anchor updates position smoothly at ~20 FPS (50ms sampling)
/// - AC2: ModifyAnchorEvent generated every 50ms during drag
/// - AC3: Final position recorded on pointer up
/// - AC4: Anchor stays attached to path
/// - AC5: Integration test drags anchor 100px and verifies position
///
/// Related: I5.T5 (DirectSelectionTool), I2.T2 (Event Sourcing), T029 (Anchor Point Dragging)

import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
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
  List<ModifyAnchorEvent> get anchorEvents =>
      events.whereType<ModifyAnchorEvent>().toList();

  void clear() {
    _store.clear();
    flushCount = 0;
  }

  /// Calculate average events per second based on event timestamps.
  double get eventsPerSecond {
    if (anchorEvents.length < 2) return 0.0;

    final firstTime = anchorEvents.first.timestamp;
    final lastTime = anchorEvents.last.timestamp;
    final durationMs = lastTime - firstTime;

    if (durationMs <= 0) return 0.0;

    return (anchorEvents.length / durationMs) * 1000;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Anchor Drag Integration Tests (I8.T1)', () {
    late DirectSelectionTool tool;
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

      // Create test document with a simple 3-anchor path
      final path = domain.Path(
        anchors: const [
          AnchorPoint(position: Point(x: 100, y: 100)),
          AnchorPoint(position: Point(x: 200, y: 100)),
          AnchorPoint(position: Point(x: 200, y: 200)),
        ],
        segments: [
          Segment.line(startIndex: 0, endIndex: 1),
          Segment.line(startIndex: 1, endIndex: 2),
        ],
        closed: false,
      );

      final layer = Layer(
        id: 'layer-1',
        name: 'Layer 1',
        objects: [VectorObject.path(id: 'path-1', path: path)],
      );

      document = Document(
        id: 'doc-1',
        title: 'Test Document',
        layers: [layer],
        selection: const Selection(objectIds: {'path-1'}),
      );

      // Create tool
      tool = DirectSelectionTool(
        document: document,
        viewportController: viewport,
        eventRecorder: recorder,
        pathRenderer: PathRenderer(),
      );

      tool.onActivate();
    });

    tearDown(() {
      viewport.dispose();
    });

    group('AC5: Drag Anchor 100px Test', () {
      test('should drag anchor 100px and verify final position', () async {
        // Start drag on second anchor at (200, 100)
        tool.onPointerDown(const PointerDownEvent(position: Offset(200, 100)));

        recorder.clear();

        // Drag 100px to the right: (200, 100) → (300, 100)
        tool.onPointerMove(const PointerMoveEvent(position: Offset(300, 100)));

        // Finish drag
        tool.onPointerUp(const PointerUpEvent(position: Offset(300, 100)));

        // Wait for async event persistence
        await Future.delayed(const Duration(milliseconds: 100));

        // Verify events were recorded
        expect(
          recorder.anchorEvents,
          isNotEmpty,
          reason: 'Should record drag events',
        );

        // Verify final anchor position
        final finalEvent = recorder.anchorEvents.last;
        expect(finalEvent.pathId, equals('path-1'));
        expect(finalEvent.anchorIndex, equals(1)); // Second anchor
        expect(finalEvent.position, isNotNull);
        expect(
          finalEvent.position!.x,
          closeTo(300, 1.0),
          reason: 'Anchor moved 100px right',
        );
        expect(
          finalEvent.position!.y,
          closeTo(100, 1.0),
          reason: 'Anchor Y unchanged',
        );
      });
    });

    group('AC1 & AC2: Event Sampling at 50ms', () {
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
          'Recorded ${recorder.anchorEvents.length} events at ${eventsPerSec.toStringAsFixed(1)} events/sec',
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
        expect(recorder.anchorEvents.length, greaterThanOrEqualTo(4),
            reason: 'Should emit event for each 60ms interval');
      });
    });

    group('AC3: Final Position Flush', () {
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

        final eventsAfterFirst = recorder.anchorEvents.length;

        // Second move quickly (< 50ms) - will be buffered
        tool.onPointerMove(const PointerMoveEvent(position: Offset(120, 100)));
        await Future.delayed(const Duration(milliseconds: 20));

        // Should still have same count (buffered)
        expect(recorder.anchorEvents.length, equals(eventsAfterFirst),
            reason: 'Second event should be buffered');

        // Finish drag - flushes buffered event
        tool.onPointerUp(const PointerUpEvent(position: Offset(120, 100)));
        await Future.delayed(const Duration(milliseconds: 100));

        // Now should have one more event
        expect(
          recorder.anchorEvents.length,
          greaterThan(eventsAfterFirst),
          reason: 'Flush should emit buffered event',
        );
      });
    });

    group('AC4: Anchor Attachment', () {
      test('should maintain anchor index throughout drag', () async {
        tool.onPointerDown(const PointerDownEvent(position: Offset(200, 100)));

        recorder.clear();

        // Multiple rapid moves
        for (int i = 0; i < 10; i++) {
          tool.onPointerMove(
            PointerMoveEvent(position: Offset(200 + i * 5.0, 100)),
          );
        }

        tool.onPointerUp(const PointerUpEvent(position: Offset(250, 100)));

        await Future.delayed(const Duration(milliseconds: 100));

        // All events should reference same path and anchor
        for (final event in recorder.anchorEvents) {
          expect(event.pathId, equals('path-1'),
              reason: 'Should stay attached to path');
          expect(event.anchorIndex, equals(1),
              reason: 'Should reference same anchor');
        }
      });
    });

    group('Edge Cases', () {
      test('should drag first anchor (boundary case)', () async {
        tool.onPointerDown(const PointerDownEvent(position: Offset(100, 100)));

        recorder.clear();

        tool.onPointerMove(const PointerMoveEvent(position: Offset(150, 150)));
        await Future.delayed(const Duration(milliseconds: 100));

        expect(recorder.anchorEvents, isNotEmpty);
        expect(recorder.anchorEvents.first.anchorIndex, equals(0));
      });

      test('should drag last anchor (boundary case)', () async {
        tool.onPointerDown(const PointerDownEvent(position: Offset(200, 200)));

        recorder.clear();

        tool.onPointerMove(const PointerMoveEvent(position: Offset(250, 250)));
        await Future.delayed(const Duration(milliseconds: 100));

        expect(recorder.anchorEvents, isNotEmpty);
        expect(recorder.anchorEvents.first.anchorIndex, equals(2));
      });

      test('should handle closed path anchor drag', () async {
        // Create document with closed path
        final closedPath = domain.Path(
          anchors: const [
            AnchorPoint(position: Point(x: 100, y: 100)),
            AnchorPoint(position: Point(x: 200, y: 100)),
            AnchorPoint(position: Point(x: 150, y: 200)),
          ],
          segments: [
            Segment.line(startIndex: 0, endIndex: 1),
            Segment.line(startIndex: 1, endIndex: 2),
            Segment.line(startIndex: 2, endIndex: 0),
          ],
          closed: true,
        );

        final closedDoc = Document(
          id: 'doc-closed',
          title: 'Closed Path Doc',
          layers: [
            Layer(
              id: 'layer-1',
              name: 'Layer 1',
              objects: [VectorObject.path(id: 'closed-path', path: closedPath)],
            ),
          ],
          selection: const Selection(objectIds: {'closed-path'}),
        );

        final closedTool = DirectSelectionTool(
          document: closedDoc,
          viewportController: viewport,
          eventRecorder: recorder,
          pathRenderer: PathRenderer(),
        );

        closedTool.onActivate();
        recorder.clear();

        // Drag first anchor of closed path
        closedTool.onPointerDown(const PointerDownEvent(position: Offset(100, 100)));
        closedTool.onPointerMove(const PointerMoveEvent(position: Offset(110, 110)));
        await Future.delayed(const Duration(milliseconds: 100));

        expect(recorder.anchorEvents, isNotEmpty);
        expect(recorder.anchorEvents.first.pathId, equals('closed-path'));
      });
    });

    group('Complete Workflow', () {
      test('should complete full drag workflow with all events', () async {
        // Start drag
        final handled =
            tool.onPointerDown(const PointerDownEvent(position: Offset(100, 100)));
        expect(handled, isTrue, reason: 'Should handle pointer down');

        recorder.clear();

        // Drag in multiple steps
        for (int i = 1; i <= 5; i++) {
          tool.onPointerMove(
            PointerMoveEvent(position: Offset(100 + i * 20.0, 100)),
          );
          await Future.delayed(const Duration(milliseconds: 60)); // > 50ms
        }

        // Finish drag
        tool.onPointerUp(const PointerUpEvent(position: Offset(200, 100)));
        await Future.delayed(const Duration(milliseconds: 100));

        // Verify complete workflow
        expect(recorder.anchorEvents.length, greaterThan(0),
            reason: 'Should record events');
        expect(recorder.flushCount, greaterThan(0), reason: 'Should flush on up');

        // Verify all events are ModifyAnchorEvent
        expect(
          recorder.events.every((e) => e is ModifyAnchorEvent),
          isTrue,
          reason: 'All events should be ModifyAnchorEvent',
        );

        // Verify event sequence
        final firstEvent = recorder.anchorEvents.first;
        final lastEvent = recorder.anchorEvents.last;

        expect(firstEvent.pathId, equals('path-1'));
        expect(lastEvent.pathId, equals('path-1'));
        expect(firstEvent.anchorIndex, equals(lastEvent.anchorIndex),
            reason: 'Should drag same anchor throughout');
      });
    });
  });
}
