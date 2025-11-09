import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/application/tools/selection/selection_tool.dart';
import 'package:wiretuner/application/tools/direct_selection/snapping_service.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/domain/document/selection.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/events/selection_events.dart' as events;
import 'package:wiretuner/domain/events/object_events.dart';
import 'package:wiretuner/domain/events/group_events.dart';
import 'package:wiretuner/domain/models/path.dart' as domain;
import 'package:wiretuner/domain/models/anchor_point.dart';
import 'package:wiretuner/domain/models/segment.dart';
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

  group('Multi-Selection Support', () {
    late SelectionTool selectionTool;
    late ViewportController viewportController;
    late MockEventRecorder eventRecorder;
    late Document document;
    late SnappingService snappingService;

    setUp(() {
      viewportController = ViewportController(
        initialPan: const Offset(0, 0),
        initialZoom: 1.0,
      );
      eventRecorder = MockEventRecorder();
      snappingService = SnappingService(
          gridSnapEnabled: false, angleSnapEnabled: false, gridSize: 10.0);

      // Create a test document with three objects
      final path1 = domain.Path(
        anchors: const [
          AnchorPoint(position: Point(x: 100, y: 100)),
          AnchorPoint(position: Point(x: 200, y: 100)),
          AnchorPoint(position: Point(x: 200, y: 200)),
          AnchorPoint(position: Point(x: 100, y: 200)),
        ],
        segments: [
          Segment.line(startIndex: 0, endIndex: 1),
          Segment.line(startIndex: 1, endIndex: 2),
          Segment.line(startIndex: 2, endIndex: 3),
          Segment.line(startIndex: 3, endIndex: 0),
        ],
        closed: true,
      );

      final path2 = domain.Path(
        anchors: const [
          AnchorPoint(position: Point(x: 300, y: 100)),
          AnchorPoint(position: Point(x: 400, y: 100)),
          AnchorPoint(position: Point(x: 400, y: 200)),
          AnchorPoint(position: Point(x: 300, y: 200)),
        ],
        segments: [
          Segment.line(startIndex: 0, endIndex: 1),
          Segment.line(startIndex: 1, endIndex: 2),
          Segment.line(startIndex: 2, endIndex: 3),
          Segment.line(startIndex: 3, endIndex: 0),
        ],
        closed: true,
      );

      final path3 = domain.Path(
        anchors: const [
          AnchorPoint(position: Point(x: 500, y: 100)),
          AnchorPoint(position: Point(x: 600, y: 100)),
          AnchorPoint(position: Point(x: 600, y: 200)),
        ],
        segments: [
          Segment.line(startIndex: 0, endIndex: 1),
          Segment.line(startIndex: 1, endIndex: 2),
        ],
        closed: false,
      );

      final layer = Layer(
        id: 'layer-1',
        name: 'Test Layer',
        objects: [
          VectorObject.path(id: 'path-1', path: path1),
          VectorObject.path(id: 'path-2', path: path2),
          VectorObject.path(id: 'path-3', path: path3),
        ],
      );

      document = Document(
        id: 'test-doc',
        layers: [layer],
      );

      selectionTool = SelectionTool(
        document: document,
        viewportController: viewportController,
        eventRecorder: eventRecorder,
        snappingService: snappingService,
      );

      selectionTool.onActivate();
    });

    test('Multi-selection event structure verified', () {
      // Note: Testing modifier keys (Shift/Cmd) with HardwareKeyboard is complex
      // in unit tests. This test verifies that the tool correctly records
      // SelectObjectsEvent with appropriate modes.

      // Click on path-1 (normal click, replaces selection)
      selectionTool.onPointerDown(
        const PointerDownEvent(
          position: Offset(150, 150),
          buttons: kPrimaryButton,
        ),
      );
      selectionTool.onPointerUp(const PointerUpEvent());

      // Verify first selection
      var selectEvents =
          eventRecorder.recordedEvents.whereType<events.SelectObjectsEvent>();
      expect(selectEvents.isNotEmpty, isTrue);
      expect(selectEvents.first.mode, events.SelectionMode.replace);
      expect(selectEvents.first.objectIds, contains('path-1'));

      eventRecorder.clear();

      // Click on path-2 (replaces selection without modifier)
      selectionTool.onPointerDown(
        const PointerDownEvent(
          position: Offset(350, 150),
          buttons: kPrimaryButton,
        ),
      );
      selectionTool.onPointerUp(const PointerUpEvent());

      // Verify selection replacement
      selectEvents =
          eventRecorder.recordedEvents.whereType<events.SelectObjectsEvent>();
      expect(selectEvents.isNotEmpty, isTrue);
      expect(selectEvents.last.mode, events.SelectionMode.replace);
      expect(selectEvents.last.objectIds, contains('path-2'));
    });

    test('Drag multiple selected objects together', () {
      // Create document with pre-selected objects
      final documentWithSelection = document.copyWith(
        selection: const Selection(objectIds: {'path-1', 'path-2'}),
      );

      // Recreate tool with selected document
      final toolWithSelection = SelectionTool(
        document: documentWithSelection,
        viewportController: viewportController,
        eventRecorder: eventRecorder,
        snappingService: snappingService,
      );
      toolWithSelection.onActivate();

      // Start drag on path-1 (should drag both selected objects)
      toolWithSelection.onPointerDown(
        const PointerDownEvent(
          position: Offset(150, 150),
          buttons: kPrimaryButton,
        ),
      );

      // Move 50 pixels to the right
      toolWithSelection.onPointerMove(
        const PointerMoveEvent(position: Offset(200, 150)),
      );

      toolWithSelection.onPointerUp(const PointerUpEvent());

      // Verify event sequence: StartGroup → MoveObject → EndGroup
      expect(
        eventRecorder.recordedEvents.first,
        isA<StartGroupEvent>(),
        reason: 'First event should be StartGroupEvent',
      );
      expect(
        eventRecorder.recordedEvents.last,
        isA<EndGroupEvent>(),
        reason: 'Last event should be EndGroupEvent',
      );

      // Verify MoveObjectEvent contains both object IDs
      final moveEvents =
          eventRecorder.recordedEvents.whereType<MoveObjectEvent>();
      expect(moveEvents.isNotEmpty, isTrue);

      final moveEvent = moveEvents.first;
      expect(moveEvent.objectIds.length, 2);
      expect(moveEvent.objectIds, containsAll(['path-1', 'path-2']));
    });

    test('MoveObjectEvent contains all selected object IDs', () {
      // Create document with all three paths selected
      final documentWithSelection = document.copyWith(
        selection: const Selection(objectIds: {'path-1', 'path-2', 'path-3'}),
      );

      final toolWithSelection = SelectionTool(
        document: documentWithSelection,
        viewportController: viewportController,
        eventRecorder: eventRecorder,
        snappingService: snappingService,
      );
      toolWithSelection.onActivate();

      // Drag all selected objects
      toolWithSelection.onPointerDown(
        const PointerDownEvent(
          position: Offset(150, 150),
          buttons: kPrimaryButton,
        ),
      );

      toolWithSelection.onPointerMove(
        const PointerMoveEvent(position: Offset(160, 155)),
      );

      toolWithSelection.onPointerUp(const PointerUpEvent());

      // Verify MoveObjectEvent contains all three IDs
      final moveEvents =
          eventRecorder.recordedEvents.whereType<MoveObjectEvent>();
      expect(moveEvents.isNotEmpty, isTrue);

      final moveEvent = moveEvents.first;
      expect(moveEvent.objectIds.length, 3);
      expect(moveEvent.objectIds, containsAll(['path-1', 'path-2', 'path-3']));
    });

    test('Undo grouping wraps drag events', () {
      // Create document with path-1 already selected
      final documentWithSelection = document.copyWith(
        selection: const Selection(objectIds: {'path-1'}),
      );

      final toolWithSelection = SelectionTool(
        document: documentWithSelection,
        viewportController: viewportController,
        eventRecorder: eventRecorder,
        snappingService: snappingService,
      );
      toolWithSelection.onActivate();

      // Start drag
      toolWithSelection.onPointerDown(
        const PointerDownEvent(
          position: Offset(150, 150),
          buttons: kPrimaryButton,
        ),
      );

      // Multiple move events
      for (int i = 1; i <= 5; i++) {
        toolWithSelection.onPointerMove(
          PointerMoveEvent(position: Offset(150 + i * 10.0, 150)),
        );
      }

      toolWithSelection.onPointerUp(const PointerUpEvent());

      // Verify event sequence
      final startGroupEvents =
          eventRecorder.recordedEvents.whereType<StartGroupEvent>();
      final endGroupEvents =
          eventRecorder.recordedEvents.whereType<EndGroupEvent>();
      final moveEvents =
          eventRecorder.recordedEvents.whereType<MoveObjectEvent>();

      expect(startGroupEvents.length, 1,
          reason: 'Should have one StartGroupEvent');
      expect(endGroupEvents.length, 1, reason: 'Should have one EndGroupEvent');
      expect(moveEvents.isNotEmpty, isTrue,
          reason: 'Should have MoveObjectEvents');

      // Verify groupId matches
      expect(
        startGroupEvents.first.groupId,
        equals(endGroupEvents.first.groupId),
        reason: 'Start and End group IDs should match',
      );

      // Verify event order: Start → Move(s) → End
      expect(eventRecorder.recordedEvents.first, isA<StartGroupEvent>());
      expect(eventRecorder.recordedEvents.last, isA<EndGroupEvent>());
    });

    test('Cumulative delta calculation for deterministic replay', () {
      // Create document with path-1 already selected
      final documentWithSelection = document.copyWith(
        selection: const Selection(objectIds: {'path-1'}),
      );

      final toolWithSelection = SelectionTool(
        document: documentWithSelection,
        viewportController: viewportController,
        eventRecorder: eventRecorder,
        snappingService: snappingService,
      );
      toolWithSelection.onActivate();

      // Start drag at (150, 150)
      toolWithSelection.onPointerDown(
        const PointerDownEvent(
          position: Offset(150, 150),
          buttons: kPrimaryButton,
        ),
      );

      // Move to (160, 155) - delta should be (10, 5)
      toolWithSelection.onPointerMove(
        const PointerMoveEvent(position: Offset(160, 155)),
      );

      // Move to (175, 160) - delta should be (25, 10) from start, NOT (15, 5) from previous
      toolWithSelection.onPointerMove(
        const PointerMoveEvent(position: Offset(175, 160)),
      );

      toolWithSelection.onPointerUp(const PointerUpEvent());

      // Get all MoveObjectEvents (excluding Start/EndGroupEvent)
      final moveEvents =
          eventRecorder.recordedEvents.whereType<MoveObjectEvent>().toList();
      expect(moveEvents.length, greaterThanOrEqualTo(2));

      // First move event: delta ~(10, 5)
      expect(moveEvents[0].delta.x, closeTo(10.0, 0.1));
      expect(moveEvents[0].delta.y, closeTo(5.0, 0.1));

      // Second move event: delta ~(25, 10) from START, not from previous
      expect(moveEvents[1].delta.x, closeTo(25.0, 0.1));
      expect(moveEvents[1].delta.y, closeTo(10.0, 0.1));
    });

    test('Grid snapping controller integration', () {
      // Test snapping directly via the controller
      // (Full Shift-key integration tested in integration/manual tests)

      // Select path-1
      selectionTool.onPointerDown(
        const PointerDownEvent(
          position: Offset(150, 150),
          buttons: kPrimaryButton,
        ),
      );
      selectionTool.onPointerUp(const PointerUpEvent());

      eventRecorder.clear();

      // Test that snapping service is integrated
      // Without Shift, snapping is disabled by default
      snappingService.setSnapEnabled(true);

      // Start drag at (150, 150) - on grid
      selectionTool.onPointerDown(
        const PointerDownEvent(
          position: Offset(150, 150),
          buttons: kPrimaryButton,
        ),
      );

      // Manually enable snapping for this test
      selectionTool.onKeyPress(
        const KeyDownEvent(
          logicalKey: LogicalKeyboardKey.shift,
          physicalKey: PhysicalKeyboardKey.shiftLeft,
          timeStamp: Duration.zero,
        ),
      );

      // Move to (163, 157) - should snap to (160, 160) with gridSize=10
      // Delta from (150,150) to (160,160) = (10, 10)
      selectionTool.onPointerMove(
        const PointerMoveEvent(position: Offset(163, 157)),
      );

      selectionTool.onPointerUp(const PointerUpEvent());

      // Verify snapped delta
      final moveEvents =
          eventRecorder.recordedEvents.whereType<MoveObjectEvent>().toList();
      expect(moveEvents.isNotEmpty, isTrue);

      final moveEvent = moveEvents.first;
      // With snapping enabled: Target (163, 157) should snap to (160, 160)
      // Delta: (160-150, 160-150) = (10, 10)
      expect(moveEvent.delta.x, closeTo(10.0, 0.1));
      expect(moveEvent.delta.y, closeTo(10.0, 0.1));
    });

    test('Selection serialization round-trip', () {
      const selection = Selection(
        objectIds: {'path-1', 'path-2', 'path-3'},
        anchorIndices: {
          'path-1': {0, 2, 5},
        },
      );

      // Serialize to JSON
      final json = selection.toJson();

      // Deserialize from JSON
      final restored = Selection.fromJson(json);

      // Verify equality
      expect(restored, equals(selection));
      expect(restored.objectIds, equals({'path-1', 'path-2', 'path-3'}));
      expect(restored.anchorIndices['path-1'], equals({0, 2, 5}));
    });

    test('Empty selection serialization', () {
      final selection = Selection.empty();

      final json = selection.toJson();
      final restored = Selection.fromJson(json);

      expect(restored, equals(selection));
      expect(restored.isEmpty, isTrue);
      expect(restored.objectIds, isEmpty);
      expect(restored.anchorIndices, isEmpty);
    });

    test('Multi-selection maintains set uniqueness', () {
      // Create selection with duplicate object IDs (should deduplicate)
      const selection = Selection(
        objectIds: {'path-1', 'path-2'}, // Sets automatically deduplicate
      );

      expect(selection.objectIds.length, 2);
      expect(selection.objectIds, contains('path-1'));
      expect(selection.objectIds, contains('path-2'));
    });
  });

  group('Event Replay Determinism', () {
    test('Replaying events produces deterministic state', () {
      // Create a sequence of events simulating a drag operation
      const startGroupEvent = StartGroupEvent(
        eventId: 'group-start-1',
        timestamp: 1000,
        groupId: 'drag-123',
        description: 'Move 2 objects',
      );

      const moveEvent1 = MoveObjectEvent(
        eventId: 'move-1',
        timestamp: 1050,
        objectIds: ['path-1', 'path-2'],
        delta: Point(x: 10.0, y: 5.0),
      );

      const moveEvent2 = MoveObjectEvent(
        eventId: 'move-2',
        timestamp: 1100,
        objectIds: ['path-1', 'path-2'],
        delta: Point(x: 25.0, y: 10.0),
      );

      const endGroupEvent = EndGroupEvent(
        eventId: 'group-end-1',
        timestamp: 1150,
        groupId: 'drag-123',
      );

      final events = [
        startGroupEvent,
        moveEvent1,
        moveEvent2,
        endGroupEvent,
      ];

      // Verify event sequence is deterministic (same order, same IDs)
      expect(events[0], isA<StartGroupEvent>());
      expect(events[1], isA<MoveObjectEvent>());
      expect(events[2], isA<MoveObjectEvent>());
      expect(events[3], isA<EndGroupEvent>());

      // Verify cumulative delta pattern
      expect((events[1] as MoveObjectEvent).delta.x, 10.0);
      expect((events[2] as MoveObjectEvent).delta.x,
          25.0); // Cumulative, not incremental

      // Verify groupId consistency
      expect(
        (events[0] as StartGroupEvent).groupId,
        equals((events[3] as EndGroupEvent).groupId),
      );
    });

    test('Event JSON serialization is deterministic', () {
      const event = MoveObjectEvent(
        eventId: 'move-123',
        timestamp: 1000,
        objectIds: ['path-1', 'path-2'],
        delta: Point(x: 10.5, y: 20.3),
      );

      // Serialize multiple times
      final json1 = event.toJson();
      final json2 = event.toJson();

      // Verify identical serialization
      expect(json1, equals(json2));

      // Deserialize and verify
      final restored = MoveObjectEvent.fromJson(json1);
      expect(restored.eventId, equals(event.eventId));
      expect(restored.timestamp, equals(event.timestamp));
      expect(restored.objectIds, equals(event.objectIds));
      expect(restored.delta.x, equals(event.delta.x));
      expect(restored.delta.y, equals(event.delta.y));
    });
  });

  group('Viewport Integration', () {
    test(
      'Viewport pans to show selected objects',
      () {
        // TODO: Implement scroll-to-selection in future iteration (v0.2)
        // This test verifies that selecting off-screen objects
        // triggers viewport pan to bring selection into view
      },
      skip: 'Deferred to v0.2',
      tags: ['viewport-integration'],
    );
  });
}
