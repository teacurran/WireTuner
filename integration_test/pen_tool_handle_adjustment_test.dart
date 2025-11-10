/// Integration tests for Pen Tool handle adjustment (Task I6.T4).
library;

///
/// These tests verify the acceptance criteria for BCP (Bezier Control Point) adjustment:
/// - AC1: Clicking last anchor enters ADJUSTING_HANDLES state
/// - AC2: Dragging adjusts handleOut
/// - AC3: Alt+drag adjusts handleOut independently (corner type)
/// - AC4: ModifyAnchorEvent persisted to event log
/// - AC5: Integration test adjusts handle and verifies curve shape
///
/// Related: I6.T3 (Bezier Curves), T024 (Pen Tool - Adjust BCPs)

import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/application/tools/pen/pen_tool.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/domain/document/selection.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/events/path_events.dart';
import 'package:wiretuner/domain/events/group_events.dart';
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

  List<StartGroupEvent> get startGroupEvents =>
      events.whereType<StartGroupEvent>().toList();
  List<CreatePathEvent> get createPathEvents =>
      events.whereType<CreatePathEvent>().toList();
  List<AddAnchorEvent> get addAnchorEvents =>
      events.whereType<AddAnchorEvent>().toList();
  List<ModifyAnchorEvent> get modifyAnchorEvents =>
      events.whereType<ModifyAnchorEvent>().toList();
  List<FinishPathEvent> get finishPathEvents =>
      events.whereType<FinishPathEvent>().toList();
  List<EndGroupEvent> get endGroupEvents =>
      events.whereType<EndGroupEvent>().toList();

  void clear() {
    _store.clear();
    flushCount = 0;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pen Tool Handle Adjustment Integration Tests (I6.T4)', () {
    late PenTool penTool;
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
        id: 'doc-1',
        title: 'Test Document',
        layers: [layer],
        selection: Selection(),
      );

      // Create and activate pen tool
      penTool = PenTool(
        document: document,
        viewportController: viewport,
        eventRecorder: recorder,
      );

      penTool.onActivate();
    });

    tearDown(() {
      viewport.dispose();
    });

    group('AC1: Click Last Anchor Enters Handle Adjustment Mode', () {
      test('should enter ADJUSTING_HANDLES state when clicking last anchor',
          () async {
        recorder.clear();

        // Start path with first anchor
        penTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );
        penTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(100, 100)),
        );

        await Future.delayed(const Duration(milliseconds: 100));

        // Add second anchor with Bezier curve
        penTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(200, 100)),
        );
        penTool.onPointerMove(
          const PointerMoveEvent(position: ui.Offset(250, 150)),
        );
        penTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(250, 150)),
        );

        await Future.delayed(const Duration(milliseconds: 100));

        // Click on last anchor (within 10px threshold)
        // Last anchor is at (200, 100)
        penTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(205, 105)),
        );

        // Verify preview state indicates handle adjustment mode
        expect(
          penTool.previewState.isAdjustingHandles,
          isTrue,
          reason: 'Should be in handle adjustment mode after clicking last anchor',
        );

        // Clean up - release pointer
        penTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(205, 105)),
        );
      });

      test('should NOT enter adjustment mode when clicking far from last anchor',
          () async {
        recorder.clear();

        // Start path with first anchor
        penTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );
        penTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(100, 100)),
        );

        await Future.delayed(const Duration(milliseconds: 100));

        // Add second anchor with Bezier curve
        penTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(200, 100)),
        );
        penTool.onPointerMove(
          const PointerMoveEvent(position: ui.Offset(250, 150)),
        );
        penTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(250, 150)),
        );

        await Future.delayed(const Duration(milliseconds: 100));

        // Click far from last anchor (> 10px threshold)
        penTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(300, 100)),
        );

        // Should NOT be in adjustment mode
        expect(
          penTool.previewState.isAdjustingHandles,
          isFalse,
          reason: 'Should not enter adjustment mode when clicking away from last anchor',
        );

        // Clean up - complete the anchor placement
        penTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(300, 100)),
        );
      });
    });

    group('AC2: Dragging Adjusts handleOut', () {
      test('should adjust handleOut when dragging from last anchor', () async {
        recorder.clear();

        // Start path with first anchor
        penTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );
        penTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(100, 100)),
        );

        await Future.delayed(const Duration(milliseconds: 100));

        // Add second anchor with initial Bezier curve
        penTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(200, 100)),
        );
        penTool.onPointerMove(
          const PointerMoveEvent(position: ui.Offset(250, 150)),
        );
        penTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(250, 150)),
        );

        await Future.delayed(const Duration(milliseconds: 100));

        // Click on last anchor and drag to adjust handles
        penTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(200, 100)),
        );
        penTool.onPointerMove(
          const PointerMoveEvent(position: ui.Offset(280, 120)),
        );
        penTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(280, 120)),
        );

        await Future.delayed(const Duration(milliseconds: 200));

        // Find ModifyAnchorEvent
        final modifyEvents = recorder.modifyAnchorEvents;

        expect(
          modifyEvents.length,
          equals(1),
          reason: 'Should emit ModifyAnchorEvent for handle adjustment',
        );

        final modifyEvent = modifyEvents.first;

        // AC2: Verify handleOut was adjusted to new drag position
        expect(
          modifyEvent.handleOut,
          isNotNull,
          reason: 'ModifyAnchorEvent should contain adjusted handleOut',
        );

        expect(
          modifyEvent.handleOut!.x,
          equals(80.0),
          reason: 'handleOut.x should be relative offset (280 - 200)',
        );

        expect(
          modifyEvent.handleOut!.y,
          equals(20.0),
          reason: 'handleOut.y should be relative offset (120 - 100)',
        );

        // Verify it's modifying the correct anchor (last anchor = index 1)
        expect(
          modifyEvent.anchorIndex,
          equals(1),
          reason: 'Should modify the last anchor (second anchor, index 1)',
        );

        // Verify pathId matches
        final createPath = recorder.createPathEvents.first;
        expect(
          modifyEvent.pathId,
          equals(createPath.pathId),
          reason: 'ModifyAnchorEvent should reference correct path',
        );
      });
    });

    group('AC3: Alt+Drag Independent Handle Adjustment (Corner Type)', () {
      test('should adjust handleOut independently when Alt key is pressed',
          () async {
        recorder.clear();

        // Start path with first anchor
        penTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );
        penTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(100, 100)),
        );

        await Future.delayed(const Duration(milliseconds: 100));

        // Add second anchor with initial Bezier curve (symmetric handles)
        penTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(200, 100)),
        );
        penTool.onPointerMove(
          const PointerMoveEvent(position: ui.Offset(250, 150)),
        );
        penTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(250, 150)),
        );

        await Future.delayed(const Duration(milliseconds: 100));

        // Verify initial anchor has symmetric handles
        final initialAnchor = recorder.addAnchorEvents
            .where((a) => a.anchorType == AnchorType.bezier)
            .first;

        expect(
          initialAnchor.handleIn,
          isNotNull,
          reason: 'Initial anchor should have symmetric handleIn',
        );

        expect(
          initialAnchor.handleIn!.x,
          equals(-initialAnchor.handleOut!.x),
          reason: 'Initial handleIn.x should be mirrored',
        );

        // Clear events for handle adjustment test
        recorder.clear();

        // Simulate Alt key press
        HardwareKeyboard.instance.handleKeyEvent(
          const KeyDownEvent(
            logicalKey: LogicalKeyboardKey.altLeft,
            physicalKey: PhysicalKeyboardKey.altLeft,
            timeStamp: Duration.zero,
          ),
        );

        // Click on last anchor and drag to adjust handles with Alt pressed
        penTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(200, 100)),
        );
        penTool.onPointerMove(
          const PointerMoveEvent(position: ui.Offset(280, 80)),
        );
        penTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(280, 80)),
        );

        await Future.delayed(const Duration(milliseconds: 200));

        // Find ModifyAnchorEvent
        final modifyEvents = recorder.modifyAnchorEvents;

        expect(
          modifyEvents.length,
          equals(1),
          reason: 'Should emit ModifyAnchorEvent for handle adjustment',
        );

        final modifyEvent = modifyEvents.first;

        // AC3: Verify handleOut was adjusted independently (no handleIn)
        expect(
          modifyEvent.handleOut,
          isNotNull,
          reason: 'ModifyAnchorEvent should contain adjusted handleOut',
        );

        expect(
          modifyEvent.handleOut!.x,
          equals(80.0),
          reason: 'handleOut.x should be relative offset (280 - 200)',
        );

        expect(
          modifyEvent.handleOut!.y,
          equals(-20.0),
          reason: 'handleOut.y should be relative offset (80 - 100)',
        );

        // Corner anchor: handleIn should be null (independent handles)
        expect(
          modifyEvent.handleIn,
          isNull,
          reason: 'Alt+drag should break symmetry (corner anchor, no handleIn)',
        );

        // Clean up - release Alt key
        HardwareKeyboard.instance.handleKeyEvent(
          const KeyUpEvent(
            logicalKey: LogicalKeyboardKey.altLeft,
            physicalKey: PhysicalKeyboardKey.altLeft,
            timeStamp: Duration.zero,
          ),
        );
      });

      test('should maintain symmetric handles when Alt key is NOT pressed',
          () async {
        recorder.clear();

        // Start path with first anchor
        penTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );
        penTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(100, 100)),
        );

        await Future.delayed(const Duration(milliseconds: 100));

        // Add second anchor with initial Bezier curve
        penTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(200, 100)),
        );
        penTool.onPointerMove(
          const PointerMoveEvent(position: ui.Offset(250, 150)),
        );
        penTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(250, 150)),
        );

        await Future.delayed(const Duration(milliseconds: 100));

        // Clear events for handle adjustment test
        recorder.clear();

        // Click on last anchor and drag WITHOUT Alt key
        penTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(200, 100)),
        );
        penTool.onPointerMove(
          const PointerMoveEvent(position: ui.Offset(280, 120)),
        );
        penTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(280, 120)),
        );

        await Future.delayed(const Duration(milliseconds: 200));

        // Find ModifyAnchorEvent
        final modifyEvents = recorder.modifyAnchorEvents;
        final modifyEvent = modifyEvents.first;

        // Without Alt: handles should be symmetric
        expect(
          modifyEvent.handleIn,
          isNotNull,
          reason: 'Without Alt, should maintain symmetric handleIn',
        );

        expect(
          modifyEvent.handleIn!.x,
          equals(-modifyEvent.handleOut!.x),
          reason: 'handleIn.x should be mirrored version of handleOut.x',
        );

        expect(
          modifyEvent.handleIn!.y,
          equals(-modifyEvent.handleOut!.y),
          reason: 'handleIn.y should be mirrored version of handleOut.y',
        );
      });
    });

    group('AC4: ModifyAnchorEvent Persistence', () {
      test('should persist ModifyAnchorEvent to event log', () async {
        recorder.clear();

        // Start path with first anchor
        penTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );
        penTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(100, 100)),
        );

        await Future.delayed(const Duration(milliseconds: 100));

        // Add second anchor with Bezier curve
        penTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(200, 100)),
        );
        penTool.onPointerMove(
          const PointerMoveEvent(position: ui.Offset(250, 150)),
        );
        penTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(250, 150)),
        );

        await Future.delayed(const Duration(milliseconds: 100));

        // Adjust handles
        penTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(200, 100)),
        );
        penTool.onPointerMove(
          const PointerMoveEvent(position: ui.Offset(270, 130)),
        );
        penTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(270, 130)),
        );

        await Future.delayed(const Duration(milliseconds: 200));

        // AC4: Verify event is in the store
        final allEvents = recorder.events;

        expect(
          allEvents.whereType<ModifyAnchorEvent>().length,
          equals(1),
          reason: 'ModifyAnchorEvent should be persisted to event log',
        );

        // Verify event structure for replay
        final modifyEvent = recorder.modifyAnchorEvents.first;

        expect(modifyEvent.eventId, isNotEmpty,
            reason: 'Should have unique event ID');
        expect(modifyEvent.timestamp, greaterThan(0),
            reason: 'Should have valid timestamp');
        expect(modifyEvent.pathId, isNotEmpty,
            reason: 'Should reference path ID');
        expect(modifyEvent.anchorIndex, equals(1),
            reason: 'Should have anchor index');
        expect(modifyEvent.handleOut, isNotNull,
            reason: 'Should contain handle data');
      });
    });

    group('AC5: Complete Handle Adjustment Workflow', () {
      test('should adjust handles and verify curve shape changes', () async {
        recorder.clear();

        // Create path with Bezier curve
        // Point 1: Start anchor
        penTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 200)),
        );
        penTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(100, 200)),
        );

        await Future.delayed(const Duration(milliseconds: 100));

        // Point 2: Bezier anchor - drag upward
        penTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(200, 200)),
        );
        penTool.onPointerMove(
          const PointerMoveEvent(position: ui.Offset(250, 150)),
        );
        penTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(250, 150)),
        );

        await Future.delayed(const Duration(milliseconds: 100));

        // Capture initial handle values
        final initialAnchor = recorder.addAnchorEvents
            .where((a) => a.anchorType == AnchorType.bezier)
            .first;

        final initialHandleOutX = initialAnchor.handleOut!.x;
        final initialHandleOutY = initialAnchor.handleOut!.y;

        expect(initialHandleOutX, equals(50.0),
            reason: 'Initial handleOut X = 250 - 200');
        expect(initialHandleOutY, equals(-50.0),
            reason: 'Initial handleOut Y = 150 - 200 (upward)');

        // Clear events for adjustment test
        recorder.clear();

        // Adjust handle - drag downward (opposite direction)
        penTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(200, 200)),
        );
        penTool.onPointerMove(
          const PointerMoveEvent(position: ui.Offset(250, 250)),
        );
        penTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(250, 250)),
        );

        await Future.delayed(const Duration(milliseconds: 200));

        // Verify handle was adjusted
        final modifyEvent = recorder.modifyAnchorEvents.first;

        expect(
          modifyEvent.handleOut!.x,
          equals(50.0),
          reason: 'Adjusted handleOut X = 250 - 200',
        );

        expect(
          modifyEvent.handleOut!.y,
          equals(50.0),
          reason: 'Adjusted handleOut Y = 250 - 200 (downward)',
        );

        // AC5: Verify curve shape changed - Y direction flipped
        expect(
          initialHandleOutY < 0,
          isTrue,
          reason: 'Initial curve pointed upward (negative Y)',
        );

        expect(
          modifyEvent.handleOut!.y > 0,
          isTrue,
          reason: 'Adjusted curve points downward (positive Y)',
        );

        // Verify the adjustment produced a valid curve transformation
        // The magnitude changed and direction inverted
        final initialMagnitude = math.sqrt(
          initialHandleOutX * initialHandleOutX +
              initialHandleOutY * initialHandleOutY,
        );

        final adjustedMagnitude = math.sqrt(
          modifyEvent.handleOut!.x * modifyEvent.handleOut!.x +
              modifyEvent.handleOut!.y * modifyEvent.handleOut!.y,
        );

        expect(
          adjustedMagnitude,
          greaterThan(0),
          reason: 'Adjusted handle should have positive magnitude',
        );

        // Both magnitudes should be similar (both ~70.7 for 50,±50 vectors)
        expect(
          (adjustedMagnitude - initialMagnitude).abs(),
          lessThan(0.1),
          reason: 'Handle magnitudes should be similar (direction changed, not length)',
        );
      });

      test('should support multiple handle adjustments on same anchor',
          () async {
        recorder.clear();

        // Create path with Bezier anchor
        penTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );
        penTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(100, 100)),
        );

        await Future.delayed(const Duration(milliseconds: 100));

        penTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(200, 100)),
        );
        penTool.onPointerMove(
          const PointerMoveEvent(position: ui.Offset(250, 150)),
        );
        penTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(250, 150)),
        );

        await Future.delayed(const Duration(milliseconds: 100));

        // First adjustment
        penTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(200, 100)),
        );
        penTool.onPointerMove(
          const PointerMoveEvent(position: ui.Offset(270, 130)),
        );
        penTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(270, 130)),
        );

        await Future.delayed(const Duration(milliseconds: 100));

        // Second adjustment (different direction)
        penTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(200, 100)),
        );
        penTool.onPointerMove(
          const PointerMoveEvent(position: ui.Offset(230, 80)),
        );
        penTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(230, 80)),
        );

        await Future.delayed(const Duration(milliseconds: 200));

        // Verify both adjustments were recorded
        expect(
          recorder.modifyAnchorEvents.length,
          equals(2),
          reason: 'Should record multiple handle adjustments',
        );

        final firstAdjustment = recorder.modifyAnchorEvents[0];
        final secondAdjustment = recorder.modifyAnchorEvents[1];

        // Verify first adjustment
        expect(firstAdjustment.handleOut!.x, equals(70.0));
        expect(firstAdjustment.handleOut!.y, equals(30.0));

        // Verify second adjustment (different handle values)
        expect(secondAdjustment.handleOut!.x, equals(30.0));
        expect(secondAdjustment.handleOut!.y, equals(-20.0));

        // Both should reference same anchor
        expect(
          firstAdjustment.anchorIndex,
          equals(secondAdjustment.anchorIndex),
          reason: 'Both adjustments should target same anchor',
        );
      });
    });

    group('Shift Key Constraint During Handle Adjustment', () {
      test('should constrain handle angle to 45° when Shift is pressed',
          () async {
        recorder.clear();

        // Create path with Bezier anchor
        penTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(100, 100)),
        );
        penTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(100, 100)),
        );

        await Future.delayed(const Duration(milliseconds: 100));

        penTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(200, 100)),
        );
        penTool.onPointerMove(
          const PointerMoveEvent(position: ui.Offset(250, 150)),
        );
        penTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(250, 150)),
        );

        await Future.delayed(const Duration(milliseconds: 100));

        // Clear events
        recorder.clear();

        // Simulate Shift key press
        HardwareKeyboard.instance.handleKeyEvent(
          const KeyDownEvent(
            logicalKey: LogicalKeyboardKey.shiftLeft,
            physicalKey: PhysicalKeyboardKey.shiftLeft,
            timeStamp: Duration.zero,
          ),
        );

        // Adjust handle with Shift pressed (drag to arbitrary angle)
        penTool.onPointerDown(
          const PointerDownEvent(position: ui.Offset(200, 100)),
        );
        penTool.onPointerMove(
          const PointerMoveEvent(position: ui.Offset(260, 130)), // ~30° angle
        );
        penTool.onPointerUp(
          const PointerUpEvent(position: ui.Offset(260, 130)),
        );

        await Future.delayed(const Duration(milliseconds: 200));

        final modifyEvent = recorder.modifyAnchorEvents.first;

        // Calculate angle of adjusted handle
        final angle = math.atan2(
          modifyEvent.handleOut!.y,
          modifyEvent.handleOut!.x,
        );

        // Convert to degrees
        final angleDegrees = angle * 180 / math.pi;

        // Should be snapped to nearest 45° increment (0, 45, 90, 135, etc.)
        // Since we dragged to (260, 130) from (200, 100), that's roughly 30°,
        // which should snap to 45°
        expect(
          (angleDegrees - 45).abs(),
          lessThan(1.0),
          reason: 'Handle angle should be constrained to 45° when Shift pressed (angleDegrees=$angleDegrees)',
        );

        // Clean up - release Shift key
        HardwareKeyboard.instance.handleKeyEvent(
          const KeyUpEvent(
            logicalKey: LogicalKeyboardKey.shiftLeft,
            physicalKey: PhysicalKeyboardKey.shiftLeft,
            timeStamp: Duration.zero,
          ),
        );
      });
    });
  });
}
