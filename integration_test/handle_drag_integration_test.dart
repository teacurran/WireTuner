/// Integration tests for BCP handle dragging (Task I8.T2).
///
/// These tests verify the acceptance criteria for handle drag functionality:
/// - AC1: Dragging handleOut updates curve shape
/// - AC2: Smooth anchor: handleIn updates symmetrically
/// - AC3: Corner anchor: handles move independently
/// - AC4: ModifyAnchorEvent recorded at 50ms intervals
/// - AC5: Integration test adjusts handle and verifies curve
///
/// Related: I8.T1 (Anchor Dragging), I3.T2 (AnchorPoint Model), T030 (BCP Handle Dragging)

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/application/tools/direct_selection/direct_selection_tool.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/domain/document/selection.dart';
import 'package:wiretuner/domain/events/event_base.dart' hide AnchorType;
import 'package:wiretuner/domain/events/path_events.dart';
import 'package:wiretuner/domain/models/anchor_point.dart';
import 'package:wiretuner/domain/models/geometry/point_extensions.dart';
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

  group('BCP Handle Dragging Integration Tests (I8.T2)', () {
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
    });

    tearDown(() {
      viewport.dispose();
    });

    group('AC1 & AC5: Handle Dragging Updates Curve', () {
      test('should drag handleOut and update curve shape', () async {
        // Create path with smooth anchor with initial handles
        final path = domain.Path(
          anchors: [
            AnchorPoint.smooth(
              position: const Point(x: 100, y: 100),
              handleOut: const Point(x: 50, y: 0), // Right-facing handle
            ),
            const AnchorPoint(position: Point(x: 200, y: 100)),
          ],
          segments: [
            Segment.bezier(
              startIndex: 0,
              endIndex: 1,
            ),
          ],
          closed: false,
        );

        document = Document(
          id: 'doc-handle-drag',
          title: 'Handle Drag Test',
          layers: [
            Layer(
              id: 'layer-1',
              name: 'Layer 1',
              objects: [VectorObject.path(id: 'path-1', path: path)],
            ),
          ],
          selection: const Selection(objectIds: {'path-1'}),
        );

        tool = DirectSelectionTool(
          document: document,
          viewportController: viewport,
          eventRecorder: recorder,
          pathRenderer: PathRenderer(),
        );

        tool.onActivate();

        // Click on handleOut at absolute position (150, 100)
        // handleOut is relative (50, 0), anchor at (100, 100) → absolute (150, 100)
        tool.onPointerDown(const PointerDownEvent(position: Offset(150, 100)));

        recorder.clear();

        // Drag handleOut to new position (170, 120)
        // New relative handleOut should be (70, 20)
        tool.onPointerMove(const PointerMoveEvent(position: Offset(170, 120)));

        // Finish drag
        tool.onPointerUp(const PointerUpEvent(position: Offset(170, 120)));

        // Wait for async persistence
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Verify events were recorded
        expect(recorder.anchorEvents, isNotEmpty,
            reason: 'Should record handle drag events');

        // Verify final handleOut position
        final finalEvent = recorder.anchorEvents.last;
        expect(finalEvent.pathId, equals('path-1'));
        expect(finalEvent.anchorIndex, equals(0));
        expect(finalEvent.handleOut, isNotNull,
            reason: 'Should update handleOut');

        // handleOut should be relative offset: (170 - 100, 120 - 100) = (70, 20)
        expect(finalEvent.handleOut!.x, closeTo(70, 1.0),
            reason: 'handleOut X should be 70');
        expect(finalEvent.handleOut!.y, closeTo(20, 1.0),
            reason: 'handleOut Y should be 20');
      });
    });

    group('AC2: Smooth Anchor - Symmetric Handle Update', () {
      test('should update handleIn symmetrically when dragging handleOut',
          () async {
        // Create smooth anchor: handleIn = -handleOut
        final path = domain.Path(
          anchors: [
            AnchorPoint.smooth(
              position: const Point(x: 100, y: 100),
              handleOut: const Point(x: 50, y: 0),
            ),
            const AnchorPoint(position: Point(x: 200, y: 100)),
          ],
          segments: [
            Segment.line(startIndex: 0, endIndex: 1),
          ],
          closed: false,
        );

        document = Document(
          id: 'doc-smooth',
          title: 'Smooth Anchor Test',
          layers: [
            Layer(
              id: 'layer-1',
              name: 'Layer 1',
              objects: [VectorObject.path(id: 'path-1', path: path)],
            ),
          ],
          selection: const Selection(objectIds: {'path-1'}),
        );

        tool = DirectSelectionTool(
          document: document,
          viewportController: viewport,
          eventRecorder: recorder,
          pathRenderer: PathRenderer(),
        );

        tool.onActivate();

        // Initial state: handleOut = (50, 0), handleIn = (-50, 0)

        // Drag handleOut from (150, 100) to (170, 130)
        tool.onPointerDown(const PointerDownEvent(position: Offset(150, 100)));

        recorder.clear();

        tool.onPointerMove(const PointerMoveEvent(position: Offset(170, 130)));
        tool.onPointerUp(const PointerUpEvent(position: Offset(170, 130)));

        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Verify events recorded
        expect(recorder.anchorEvents, isNotEmpty);

        final finalEvent = recorder.anchorEvents.last;

        // New handleOut: (170 - 100, 130 - 100) = (70, 30)
        expect(finalEvent.handleOut, isNotNull);
        expect(finalEvent.handleOut!.x, closeTo(70, 1.0));
        expect(finalEvent.handleOut!.y, closeTo(30, 1.0));

        // Smooth constraint: handleIn = -handleOut
        expect(finalEvent.handleIn, isNotNull,
            reason: 'Smooth anchor should update handleIn symmetrically');
        expect(finalEvent.handleIn!.x, closeTo(-70, 1.0),
            reason: 'handleIn X should be mirrored');
        expect(finalEvent.handleIn!.y, closeTo(-30, 1.0),
            reason: 'handleIn Y should be mirrored');
      });

      test('should maintain smooth constraint when dragging handleIn',
          () async {
        final path = domain.Path(
          anchors: [
            const AnchorPoint(position: Point(x: 100, y: 100)),
            AnchorPoint.smooth(
              position: const Point(x: 200, y: 200),
              handleOut: const Point(x: 40, y: -20),
            ),
          ],
          segments: [
            Segment.line(startIndex: 0, endIndex: 1),
          ],
          closed: false,
        );

        document = Document(
          id: 'doc-smooth-in',
          title: 'Smooth HandleIn Test',
          layers: [
            Layer(
              id: 'layer-1',
              name: 'Layer 1',
              objects: [VectorObject.path(id: 'path-1', path: path)],
            ),
          ],
          selection: const Selection(objectIds: {'path-1'}),
        );

        tool = DirectSelectionTool(
          document: document,
          viewportController: viewport,
          eventRecorder: recorder,
          pathRenderer: PathRenderer(),
        );

        tool.onActivate();

        // Initial: handleOut = (40, -20), handleIn = (-40, 20)
        // Absolute handleIn position: (200 - 40, 200 + 20) = (160, 220)

        // Drag handleIn from (160, 220) to (150, 250)
        tool.onPointerDown(const PointerDownEvent(position: Offset(160, 220)));

        recorder.clear();

        tool.onPointerMove(const PointerMoveEvent(position: Offset(150, 250)));
        tool.onPointerUp(const PointerUpEvent(position: Offset(150, 250)));

        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(recorder.anchorEvents, isNotEmpty);

        final finalEvent = recorder.anchorEvents.last;

        // New handleIn: (150 - 200, 250 - 200) = (-50, 50)
        expect(finalEvent.handleIn, isNotNull);
        expect(finalEvent.handleIn!.x, closeTo(-50, 1.0));
        expect(finalEvent.handleIn!.y, closeTo(50, 1.0));

        // Smooth constraint: handleOut = -handleIn
        expect(finalEvent.handleOut, isNotNull,
            reason: 'Smooth anchor should update handleOut symmetrically');
        expect(finalEvent.handleOut!.x, closeTo(50, 1.0),
            reason: 'handleOut X should be mirrored');
        expect(finalEvent.handleOut!.y, closeTo(-50, 1.0),
            reason: 'handleOut Y should be mirrored');
      });

      test('should verify smooth handles have same magnitude', () async {
        final path = domain.Path(
          anchors: [
            AnchorPoint.smooth(
              position: const Point(x: 100, y: 100),
              handleOut: const Point(x: 30, y: 40), // Magnitude: 50
            ),
            const AnchorPoint(position: Point(x: 200, y: 100)),
          ],
          segments: [
            Segment.line(startIndex: 0, endIndex: 1),
          ],
          closed: false,
        );

        document = Document(
          id: 'doc-smooth-magnitude',
          title: 'Smooth Magnitude Test',
          layers: [
            Layer(
              id: 'layer-1',
              name: 'Layer 1',
              objects: [VectorObject.path(id: 'path-1', path: path)],
            ),
          ],
          selection: const Selection(objectIds: {'path-1'}),
        );

        tool = DirectSelectionTool(
          document: document,
          viewportController: viewport,
          eventRecorder: recorder,
          pathRenderer: PathRenderer(),
        );

        tool.onActivate();

        // Drag handleOut to arbitrary position
        tool.onPointerDown(const PointerDownEvent(position: Offset(130, 140)));

        recorder.clear();

        tool.onPointerMove(const PointerMoveEvent(position: Offset(160, 180)));
        tool.onPointerUp(const PointerUpEvent(position: Offset(160, 180)));

        await Future<void>.delayed(const Duration(milliseconds: 100));

        final finalEvent = recorder.anchorEvents.last;

        // Calculate magnitudes
        final handleOutMag = finalEvent.handleOut!.magnitude;
        final handleInMag = finalEvent.handleIn!.magnitude;

        expect(handleOutMag, closeTo(handleInMag, 0.1),
            reason: 'Smooth anchor handles must have same magnitude');
      });
    });

    group('AC3: Corner Anchor - Independent Handles', () {
      test('should move handleOut independently without affecting handleIn',
          () async {
        // Create corner anchor with independent handles
        final path = domain.Path(
          anchors: [
            AnchorPoint(
              position: const Point(x: 100, y: 100),
              handleIn: const Point(x: -30, y: -10),
              handleOut: const Point(x: 50, y: 0),
              anchorType: AnchorType.corner,
            ),
            const AnchorPoint(position: Point(x: 200, y: 100)),
          ],
          segments: [
            Segment.line(startIndex: 0, endIndex: 1),
          ],
          closed: false,
        );

        document = Document(
          id: 'doc-corner',
          title: 'Corner Anchor Test',
          layers: [
            Layer(
              id: 'layer-1',
              name: 'Layer 1',
              objects: [VectorObject.path(id: 'path-1', path: path)],
            ),
          ],
          selection: const Selection(objectIds: {'path-1'}),
        );

        tool = DirectSelectionTool(
          document: document,
          viewportController: viewport,
          eventRecorder: recorder,
          pathRenderer: PathRenderer(),
        );

        tool.onActivate();

        // Initial: handleOut = (50, 0), handleIn = (-30, -10)

        // Drag handleOut from (150, 100) to (170, 120)
        tool.onPointerDown(const PointerDownEvent(position: Offset(150, 100)));

        recorder.clear();

        tool.onPointerMove(const PointerMoveEvent(position: Offset(170, 120)));
        tool.onPointerUp(const PointerUpEvent(position: Offset(170, 120)));

        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(recorder.anchorEvents, isNotEmpty);

        final finalEvent = recorder.anchorEvents.last;

        // New handleOut: (70, 20)
        expect(finalEvent.handleOut, isNotNull);
        expect(finalEvent.handleOut!.x, closeTo(70, 1.0));
        expect(finalEvent.handleOut!.y, closeTo(20, 1.0));

        // handleIn should remain unchanged (corner allows independent handles)
        // In ModifyAnchorEvent, unchanged fields can be null OR equal to original
        // Check final document state to verify handleIn unchanged
        if (finalEvent.handleIn != null) {
          // If handleIn is in the event, it should match original
          expect(finalEvent.handleIn!.x, closeTo(-30, 1.0),
              reason: 'Corner handleIn should remain unchanged');
          expect(finalEvent.handleIn!.y, closeTo(-10, 1.0),
              reason: 'Corner handleIn should remain unchanged');
        }
        // If handleIn is null in event, it means "no change" which is correct
      });

      test('should move handleIn independently without affecting handleOut',
          () async {
        final path = domain.Path(
          anchors: [
            const AnchorPoint(
              position: Point(x: 100, y: 100),
              handleIn: Point(x: -40, y: -20),
              handleOut: Point(x: 50, y: 10),
              anchorType: AnchorType.corner,
            ),
            const AnchorPoint(position: Point(x: 200, y: 100)),
          ],
          segments: [
            Segment.line(startIndex: 0, endIndex: 1),
          ],
          closed: false,
        );

        document = Document(
          id: 'doc-corner-in',
          title: 'Corner HandleIn Test',
          layers: [
            Layer(
              id: 'layer-1',
              name: 'Layer 1',
              objects: [VectorObject.path(id: 'path-1', path: path)],
            ),
          ],
          selection: const Selection(objectIds: {'path-1'}),
        );

        tool = DirectSelectionTool(
          document: document,
          viewportController: viewport,
          eventRecorder: recorder,
          pathRenderer: PathRenderer(),
        );

        tool.onActivate();

        // Drag handleIn from (60, 80) to (50, 70)
        tool.onPointerDown(const PointerDownEvent(position: Offset(60, 80)));

        recorder.clear();

        tool.onPointerMove(const PointerMoveEvent(position: Offset(50, 70)));
        tool.onPointerUp(const PointerUpEvent(position: Offset(50, 70)));

        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(recorder.anchorEvents, isNotEmpty);

        final finalEvent = recorder.anchorEvents.last;

        // New handleIn: (50 - 100, 70 - 100) = (-50, -30)
        expect(finalEvent.handleIn, isNotNull);
        expect(finalEvent.handleIn!.x, closeTo(-50, 1.0));
        expect(finalEvent.handleIn!.y, closeTo(-30, 1.0));

        // handleOut should remain unchanged
        if (finalEvent.handleOut != null) {
          expect(finalEvent.handleOut!.x, closeTo(50, 1.0),
              reason: 'Corner handleOut should remain unchanged');
          expect(finalEvent.handleOut!.y, closeTo(10, 1.0),
              reason: 'Corner handleOut should remain unchanged');
        }
      });
    });

    group('Symmetric Anchor - Collinear Handles', () {
      test('should maintain collinear handles with different lengths',
          () async {
        // Create symmetric anchor with different handle lengths
        final path = domain.Path(
          anchors: [
            const AnchorPoint(
              position: Point(x: 100, y: 100),
              handleIn: Point(x: -30, y: -10), // Length ~31.6
              handleOut: Point(x: 60, y: 20), // Length ~63.2
              anchorType: AnchorType.symmetric,
            ),
            const AnchorPoint(position: Point(x: 200, y: 100)),
          ],
          segments: [
            Segment.line(startIndex: 0, endIndex: 1),
          ],
          closed: false,
        );

        document = Document(
          id: 'doc-symmetric',
          title: 'Symmetric Anchor Test',
          layers: [
            Layer(
              id: 'layer-1',
              name: 'Layer 1',
              objects: [VectorObject.path(id: 'path-1', path: path)],
            ),
          ],
          selection: const Selection(objectIds: {'path-1'}),
        );

        tool = DirectSelectionTool(
          document: document,
          viewportController: viewport,
          eventRecorder: recorder,
          pathRenderer: PathRenderer(),
        );

        tool.onActivate();

        // Store original handleIn length
        final originalHandleInLength =
            math.sqrt(30 * 30 + 10 * 10); // ~31.6

        // Drag handleOut to new position
        tool.onPointerDown(const PointerDownEvent(position: Offset(160, 120)));

        recorder.clear();

        tool.onPointerMove(const PointerMoveEvent(position: Offset(180, 140)));
        tool.onPointerUp(const PointerUpEvent(position: Offset(180, 140)));

        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(recorder.anchorEvents, isNotEmpty);

        final finalEvent = recorder.anchorEvents.last;

        expect(finalEvent.handleOut, isNotNull);
        expect(finalEvent.handleIn, isNotNull,
            reason: 'Symmetric anchor should update handleIn');

        // Verify handleIn preserves original length
        final newHandleInLength = finalEvent.handleIn!.magnitude;
        expect(newHandleInLength, closeTo(originalHandleInLength, 0.1),
            reason: 'Symmetric anchor should preserve handleIn length');

        // Verify handles are collinear (angle difference = 180°)
        final handleOutAngle = math.atan2(
          finalEvent.handleOut!.y,
          finalEvent.handleOut!.x,
        );
        final handleInAngle = math.atan2(
          finalEvent.handleIn!.y,
          finalEvent.handleIn!.x,
        );
        final angleDiffDeg =
            ((handleOutAngle - handleInAngle).abs() * (180 / math.pi));

        // Angle difference should be 180° (or 0° if wrapped)
        expect(
          angleDiffDeg,
          anyOf(
            closeTo(180, 1.0),
            closeTo(0, 1.0),
          ),
          reason: 'Symmetric handles must be collinear (180° apart)',
        );
      });

      test('should allow different handle lengths after drag', () async {
        final path = domain.Path(
          anchors: [
            const AnchorPoint(
              position: Point(x: 100, y: 100),
              handleIn: Point(x: -20, y: 0), // Length 20
              handleOut: Point(x: 40, y: 0), // Length 40
              anchorType: AnchorType.symmetric,
            ),
            const AnchorPoint(position: Point(x: 200, y: 100)),
          ],
          segments: [
            Segment.line(startIndex: 0, endIndex: 1),
          ],
          closed: false,
        );

        document = Document(
          id: 'doc-symmetric-lengths',
          title: 'Symmetric Lengths Test',
          layers: [
            Layer(
              id: 'layer-1',
              name: 'Layer 1',
              objects: [VectorObject.path(id: 'path-1', path: path)],
            ),
          ],
          selection: const Selection(objectIds: {'path-1'}),
        );

        tool = DirectSelectionTool(
          document: document,
          viewportController: viewport,
          eventRecorder: recorder,
          pathRenderer: PathRenderer(),
        );

        tool.onActivate();

        // Drag handleOut
        tool.onPointerDown(const PointerDownEvent(position: Offset(140, 100)));

        recorder.clear();

        tool.onPointerMove(const PointerMoveEvent(position: Offset(130, 130)));
        tool.onPointerUp(const PointerUpEvent(position: Offset(130, 130)));

        await Future<void>.delayed(const Duration(milliseconds: 100));

        final finalEvent = recorder.anchorEvents.last;

        // Handles should have different lengths (symmetric ≠ smooth)
        final handleOutLength = finalEvent.handleOut!.magnitude;
        final handleInLength = finalEvent.handleIn!.magnitude;

        expect(handleOutLength, isNot(closeTo(handleInLength, 0.1)),
            reason: 'Symmetric handles can have different lengths');

        // But they should still be collinear
        final handleOutNormalized = finalEvent.handleOut! / handleOutLength;
        final handleInNormalized = finalEvent.handleIn! / handleInLength;

        // Normalized vectors should be opposite: norm(handleIn) ≈ -norm(handleOut)
        expect(handleInNormalized.x, closeTo(-handleOutNormalized.x, 0.1));
        expect(handleInNormalized.y, closeTo(-handleOutNormalized.y, 0.1));
      });
    });

    group('AC4: Event Sampling at 50ms Intervals', () {
      test('should sample at ~20 events/second during rapid handle drag',
          () async {
        final path = domain.Path(
          anchors: [
            const AnchorPoint(
              position: Point(x: 100, y: 100),
              handleOut: Point(x: 50, y: 0),
              anchorType: AnchorType.corner,
            ),
            const AnchorPoint(position: Point(x: 200, y: 100)),
          ],
          segments: [
            Segment.line(startIndex: 0, endIndex: 1),
          ],
          closed: false,
        );

        document = Document(
          id: 'doc-sampling',
          title: 'Handle Sampling Test',
          layers: [
            Layer(
              id: 'layer-1',
              name: 'Layer 1',
              objects: [VectorObject.path(id: 'path-1', path: path)],
            ),
          ],
          selection: const Selection(objectIds: {'path-1'}),
        );

        tool = DirectSelectionTool(
          document: document,
          viewportController: viewport,
          eventRecorder: recorder,
          pathRenderer: PathRenderer(),
        );

        tool.onActivate();

        // Start drag on handleOut
        tool.onPointerDown(const PointerDownEvent(position: Offset(150, 100)));

        recorder.clear();

        // Simulate 1 second of rapid dragging (200 moves at 5ms intervals)
        for (int i = 0; i < 200; i++) {
          tool.onPointerMove(
            PointerMoveEvent(position: Offset(150 + i * 0.5, 100 + i * 0.2)),
          );
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }

        // Finish drag
        tool.onPointerUp(const PointerUpEvent(position: Offset(250, 140)));

        // Wait for async persistence
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Verify sampling rate
        final eventsPerSec = recorder.eventsPerSecond;
        expect(eventsPerSec, greaterThan(15),
            reason: 'Should maintain at least 15 FPS');
        expect(eventsPerSec, lessThan(25),
            reason: 'Should not exceed 25 FPS due to 50ms sampling');

        // Log for debugging
        print(
          'Handle drag: Recorded ${recorder.anchorEvents.length} events at ${eventsPerSec.toStringAsFixed(1)} events/sec',
        );
      });

      test('should flush buffered event on pointer up', () async {
        final path = domain.Path(
          anchors: [
            const AnchorPoint(
              position: Point(x: 100, y: 100),
              handleOut: Point(x: 50, y: 0),
              anchorType: AnchorType.corner,
            ),
            const AnchorPoint(position: Point(x: 200, y: 100)),
          ],
          segments: [
            Segment.line(startIndex: 0, endIndex: 1),
          ],
          closed: false,
        );

        document = Document(
          id: 'doc-flush',
          title: 'Handle Flush Test',
          layers: [
            Layer(
              id: 'layer-1',
              name: 'Layer 1',
              objects: [VectorObject.path(id: 'path-1', path: path)],
            ),
          ],
          selection: const Selection(objectIds: {'path-1'}),
        );

        tool = DirectSelectionTool(
          document: document,
          viewportController: viewport,
          eventRecorder: recorder,
          pathRenderer: PathRenderer(),
        );

        tool.onActivate();

        // Start drag
        tool.onPointerDown(const PointerDownEvent(position: Offset(150, 100)));

        final initialFlushes = recorder.flushCount;

        recorder.clear();

        // First move - emitted immediately
        tool.onPointerMove(const PointerMoveEvent(position: Offset(160, 110)));
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final eventsAfterFirst = recorder.anchorEvents.length;

        // Second move quickly (< 50ms) - will be buffered
        tool.onPointerMove(const PointerMoveEvent(position: Offset(170, 120)));
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // Should still have same count (buffered)
        expect(recorder.anchorEvents.length, equals(eventsAfterFirst),
            reason: 'Second event should be buffered');

        // Finish drag - flushes buffered event
        tool.onPointerUp(const PointerUpEvent(position: Offset(170, 120)));
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Verify flush was called
        expect(recorder.flushCount, equals(initialFlushes + 1),
            reason: 'Flush should be called on pointer up');

        // Now should have one more event
        expect(
          recorder.anchorEvents.length,
          greaterThan(eventsAfterFirst),
          reason: 'Flush should emit buffered event',
        );
      });
    });

    group('Complete Workflow Tests', () {
      test('should complete full handle drag workflow', () async {
        final path = domain.Path(
          anchors: [
            AnchorPoint.smooth(
              position: const Point(x: 100, y: 100),
              handleOut: const Point(x: 50, y: 0),
            ),
            const AnchorPoint(position: Point(x: 200, y: 100)),
          ],
          segments: [
            Segment.line(startIndex: 0, endIndex: 1),
          ],
          closed: false,
        );

        document = Document(
          id: 'doc-workflow',
          title: 'Handle Workflow Test',
          layers: [
            Layer(
              id: 'layer-1',
              name: 'Layer 1',
              objects: [VectorObject.path(id: 'path-1', path: path)],
            ),
          ],
          selection: const Selection(objectIds: {'path-1'}),
        );

        tool = DirectSelectionTool(
          document: document,
          viewportController: viewport,
          eventRecorder: recorder,
          pathRenderer: PathRenderer(),
        );

        tool.onActivate();

        // Start drag
        final handled =
            tool.onPointerDown(const PointerDownEvent(position: Offset(150, 100)));
        expect(handled, isTrue, reason: 'Should handle pointer down on handle');

        recorder.clear();

        // Drag in multiple steps
        for (int i = 1; i <= 5; i++) {
          tool.onPointerMove(
            PointerMoveEvent(position: Offset(150 + i * 10.0, 100 + i * 5.0)),
          );
          await Future<void>.delayed(const Duration(milliseconds: 60)); // > 50ms
        }

        // Finish drag
        tool.onPointerUp(const PointerUpEvent(position: Offset(200, 125)));
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Verify complete workflow
        expect(recorder.anchorEvents.length, greaterThan(0),
            reason: 'Should record handle events');
        expect(recorder.flushCount, greaterThan(0),
            reason: 'Should flush on up');

        // Verify all events are ModifyAnchorEvent
        expect(
          recorder.events.every((e) => e is ModifyAnchorEvent),
          isTrue,
          reason: 'All events should be ModifyAnchorEvent',
        );

        // Verify event contains handleOut field (not position)
        final firstEvent = recorder.anchorEvents.first;
        expect(firstEvent.handleOut, isNotNull,
            reason: 'Handle drag should modify handleOut');

        // For smooth anchor, handleIn should also be modified
        expect(firstEvent.handleIn, isNotNull,
            reason: 'Smooth anchor should update handleIn');

        // Verify event sequence
        final lastEvent = recorder.anchorEvents.last;
        expect(firstEvent.pathId, equals('path-1'));
        expect(lastEvent.pathId, equals('path-1'));
        expect(firstEvent.anchorIndex, equals(lastEvent.anchorIndex),
            reason: 'Should drag same anchor throughout');
      });
    });

    group('Edge Cases', () {
      test('should handle zero-length handle (collapsed to anchor)', () async {
        final path = domain.Path(
          anchors: [
            const AnchorPoint(
              position: Point(x: 100, y: 100),
              handleOut: Point(x: 50, y: 0),
              anchorType: AnchorType.symmetric,
            ),
            const AnchorPoint(position: Point(x: 200, y: 100)),
          ],
          segments: [
            Segment.line(startIndex: 0, endIndex: 1),
          ],
          closed: false,
        );

        document = Document(
          id: 'doc-zero-length',
          title: 'Zero Length Handle Test',
          layers: [
            Layer(
              id: 'layer-1',
              name: 'Layer 1',
              objects: [VectorObject.path(id: 'path-1', path: path)],
            ),
          ],
          selection: const Selection(objectIds: {'path-1'}),
        );

        tool = DirectSelectionTool(
          document: document,
          viewportController: viewport,
          eventRecorder: recorder,
          pathRenderer: PathRenderer(),
        );

        tool.onActivate();

        // Drag handleOut to anchor position (collapse handle)
        tool.onPointerDown(const PointerDownEvent(position: Offset(150, 100)));

        recorder.clear();

        tool.onPointerMove(const PointerMoveEvent(position: Offset(100, 100)));
        tool.onPointerUp(const PointerUpEvent(position: Offset(100, 100)));

        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(recorder.anchorEvents, isNotEmpty);

        final finalEvent = recorder.anchorEvents.last;

        // handleOut should be (0, 0) or very close
        expect(finalEvent.handleOut, isNotNull);
        expect(finalEvent.handleOut!.magnitude, lessThan(1.0),
            reason: 'Handle should be collapsed');
      });

      test('should handle smooth anchor with initially null handleIn',
          () async {
        // Create smooth anchor with only handleOut (handleIn will be created)
        final path = domain.Path(
          anchors: [
            AnchorPoint.smooth(
              position: const Point(x: 100, y: 100),
              handleOut: const Point(x: 50, y: 0),
            ),
            const AnchorPoint(position: Point(x: 200, y: 100)),
          ],
          segments: [
            Segment.line(startIndex: 0, endIndex: 1),
          ],
          closed: false,
        );

        document = Document(
          id: 'doc-null-in',
          title: 'Null HandleIn Test',
          layers: [
            Layer(
              id: 'layer-1',
              name: 'Layer 1',
              objects: [VectorObject.path(id: 'path-1', path: path)],
            ),
          ],
          selection: const Selection(objectIds: {'path-1'}),
        );

        tool = DirectSelectionTool(
          document: document,
          viewportController: viewport,
          eventRecorder: recorder,
          pathRenderer: PathRenderer(),
        );

        tool.onActivate();

        // Verify initial state: smooth anchor should have both handles
        final initialAnchor = path.anchors[0];
        expect(initialAnchor.handleIn, isNotNull,
            reason: 'Smooth anchor factory should create handleIn');
        expect(initialAnchor.handleOut, isNotNull);

        // Drag handleOut
        tool.onPointerDown(const PointerDownEvent(position: Offset(150, 100)));

        recorder.clear();

        tool.onPointerMove(const PointerMoveEvent(position: Offset(160, 120)));
        tool.onPointerUp(const PointerUpEvent(position: Offset(160, 120)));

        await Future<void>.delayed(const Duration(milliseconds: 100));

        final finalEvent = recorder.anchorEvents.last;

        // Both handles should be set
        expect(finalEvent.handleOut, isNotNull);
        expect(finalEvent.handleIn, isNotNull,
            reason: 'Smooth constraint should set handleIn');
      });
    });
  });
}
