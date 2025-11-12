import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/application/tools/pen/pen_tool.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/domain/document/selection.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/events/path_events.dart';
import 'package:wiretuner/domain/events/group_events.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';

/// Unit tests for PenTool state machine.
///
/// Tests the state machine transitions, event emission, and keyboard handling
/// of the PenTool without requiring full widget integration.
///
/// Coverage focus:
/// - State transitions (IDLE → CREATING_PATH → IDLE)
/// - Event emission (CreatePathEvent, AddAnchorEvent, FinishPathEvent)
/// - Keyboard handling (Enter, ESC)
/// - Double-click detection
/// - Path cancellation
///
/// Related: I6.T1 (Pen Tool State Machine), T021 (Pen Tool Basics)

/// Mock EventRecorder for unit testing.
///
/// Records events emitted by the tool without requiring SQLite persistence.
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

  /// Helper: Get all events of a specific type.
  List<T> getEventsOfType<T>() {
    return recordedEvents.whereType<T>().toList();
  }

  /// Helper: Get the last event of a specific type.
  T? getLastEventOfType<T>() {
    final events = getEventsOfType<T>();
    return events.isEmpty ? null : events.last;
  }
}

void main() {
  // Initialize Flutter test bindings for HardwareKeyboard support
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PenTool State Machine', () {
    late PenTool penTool;
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

      penTool = PenTool(
        document: document,
        viewportController: viewportController,
        eventRecorder: eventRecorder,
      );
    });

    tearDown(() {
      viewportController.dispose();
    });

    group('State: IDLE → CREATING_PATH', () {
      test('First click starts new path (IDLE → CREATING_PATH)', () {
        penTool.onActivate();
        eventRecorder.clear();

        // First pointer down
        const event = PointerDownEvent(
          position: ui.Offset(100, 100),
        );
        final handled = penTool.onPointerDown(event);

        expect(handled, isTrue, reason: 'Tool should handle first click');

        // Verify events: StartGroupEvent + CreatePathEvent
        expect(
          eventRecorder.recordedEvents.length,
          equals(2),
          reason: 'Should emit StartGroupEvent + CreatePathEvent',
        );
        expect(
          eventRecorder.recordedEvents[0],
          isA<StartGroupEvent>(),
          reason: 'First event should be StartGroupEvent',
        );
        expect(
          eventRecorder.recordedEvents[1],
          isA<CreatePathEvent>(),
          reason: 'Second event should be CreatePathEvent',
        );

        // Verify CreatePathEvent details
        final createEvent = eventRecorder.recordedEvents[1] as CreatePathEvent;
        expect(createEvent.pathId, isNotEmpty);
        expect(createEvent.startAnchor.x, closeTo(100.0, 0.1));
        expect(createEvent.startAnchor.y, closeTo(100.0, 0.1));
        expect(createEvent.strokeColor, equals('#000000'));
        expect(createEvent.strokeWidth, equals(2.0));
      });

      test('First click sets up group ID for undo', () {
        penTool.onActivate();
        eventRecorder.clear();

        const event = PointerDownEvent(
          position: ui.Offset(100, 100),
        );
        penTool.onPointerDown(event);

        final startGroup = eventRecorder.recordedEvents[0] as StartGroupEvent;
        expect(startGroup.groupId, isNotEmpty);
        expect(startGroup.description, equals('Create path'));
      });
    });

    group('State: CREATING_PATH → Adding Anchors', () {
      setUp(() {
        penTool.onActivate();
        eventRecorder.clear();

        // Start path (first click)
        const event1 = PointerDownEvent(
          position: ui.Offset(100, 100),
        );
        penTool.onPointerDown(event1);
        const up1 = PointerUpEvent(position: ui.Offset(100, 100));
        penTool.onPointerUp(up1);

        eventRecorder.clear();
      });

      test('Second click adds anchor (AddAnchorEvent)', () {
        // Second click - down and up quickly (straight line)
        const event2 = PointerDownEvent(
          position: ui.Offset(200, 200),
        );
        penTool.onPointerDown(event2);

        const up2 = PointerUpEvent(position: ui.Offset(200, 200));
        final handled = penTool.onPointerUp(up2);

        expect(handled, isTrue, reason: 'Tool should handle anchor addition');

        // Verify AddAnchorEvent emitted
        expect(
          eventRecorder.recordedEvents.length,
          equals(1),
          reason: 'Should emit AddAnchorEvent',
        );
        expect(
          eventRecorder.recordedEvents[0],
          isA<AddAnchorEvent>(),
          reason: 'Event should be AddAnchorEvent',
        );

        final addEvent = eventRecorder.recordedEvents[0] as AddAnchorEvent;
        expect(addEvent.position.x, closeTo(200.0, 0.1));
        expect(addEvent.position.y, closeTo(200.0, 0.1));
        expect(addEvent.anchorType, equals(AnchorType.line));
      });

      test('Multiple clicks add multiple anchors', () {
        // Add 3 more anchors
        final positions = [
          const ui.Offset(200, 200),
          const ui.Offset(300, 200),
          const ui.Offset(300, 300),
        ];

        for (final pos in positions) {
          final down = PointerDownEvent(position: pos);
          penTool.onPointerDown(down);
          final up = PointerUpEvent(position: pos);
          penTool.onPointerUp(up);
        }

        // Verify 3 AddAnchorEvents
        final addEvents = eventRecorder.getEventsOfType<AddAnchorEvent>();
        expect(addEvents.length, equals(3));

        // Verify positions
        expect(addEvents[0].position.x, closeTo(200.0, 0.1));
        expect(addEvents[1].position.x, closeTo(300.0, 0.1));
        expect(addEvents[2].position.y, closeTo(300.0, 0.1));
      });

      test('Short drag (< 5px) creates straight line anchor', () {
        // Drag less than 5px
        const down = PointerDownEvent(position: ui.Offset(200, 200));
        penTool.onPointerDown(down);

        const move = PointerMoveEvent(position: ui.Offset(202, 202));
        penTool.onPointerMove(move);

        const up = PointerUpEvent(position: ui.Offset(202, 202));
        penTool.onPointerUp(up);

        final addEvent = eventRecorder.getLastEventOfType<AddAnchorEvent>();
        expect(addEvent, isNotNull);
        expect(addEvent!.anchorType, equals(AnchorType.line));
        expect(addEvent.handleIn, isNull);
        expect(addEvent.handleOut, isNull);
      });

      test('Long drag (>= 5px) creates Bezier anchor with handles', () {
        // Drag more than 5px
        const down = PointerDownEvent(position: ui.Offset(200, 200));
        penTool.onPointerDown(down);

        const move = PointerMoveEvent(position: ui.Offset(220, 220));
        penTool.onPointerMove(move);

        const up = PointerUpEvent(position: ui.Offset(220, 220));
        penTool.onPointerUp(up);

        final addEvent = eventRecorder.getLastEventOfType<AddAnchorEvent>();
        expect(addEvent, isNotNull);
        expect(addEvent!.anchorType, equals(AnchorType.bezier));
        expect(addEvent.handleOut, isNotNull);
        expect(addEvent.handleIn, isNotNull);

        // Verify handleOut = drag direction
        expect(addEvent.handleOut!.x, closeTo(20.0, 0.1));
        expect(addEvent.handleOut!.y, closeTo(20.0, 0.1));

        // Verify handleIn = -handleOut (smooth anchor)
        expect(addEvent.handleIn!.x, closeTo(-20.0, 0.1));
        expect(addEvent.handleIn!.y, closeTo(-20.0, 0.1));
      });
    });

    group('State: CREATING_PATH → IDLE (Finish Path)', () {
      setUp(() {
        penTool.onActivate();
        eventRecorder.clear();

        // Start path and add one anchor
        const event1 = PointerDownEvent(position: ui.Offset(100, 100));
        penTool.onPointerDown(event1);
        const up1 = PointerUpEvent(position: ui.Offset(100, 100));
        penTool.onPointerUp(up1);

        const event2 = PointerDownEvent(position: ui.Offset(200, 200));
        penTool.onPointerDown(event2);
        const up2 = PointerUpEvent(position: ui.Offset(200, 200));
        penTool.onPointerUp(up2);

        eventRecorder.clear();
      });

      test('Enter key finishes path', () {
        final keyEvent = KeyDownEvent(
          logicalKey: LogicalKeyboardKey.enter,
          physicalKey: PhysicalKeyboardKey.enter,
          timeStamp: Duration.zero,
        );

        final handled = penTool.onKeyPress(keyEvent);

        expect(handled, isTrue, reason: 'Tool should handle Enter key');

        // Verify FinishPathEvent + EndGroupEvent
        expect(
          eventRecorder.recordedEvents.length,
          equals(2),
          reason: 'Should emit FinishPathEvent + EndGroupEvent',
        );
        expect(eventRecorder.recordedEvents[0], isA<FinishPathEvent>());
        expect(eventRecorder.recordedEvents[1], isA<EndGroupEvent>());

        final finishEvent = eventRecorder.recordedEvents[0] as FinishPathEvent;
        expect(finishEvent.closed, isFalse);
        expect(eventRecorder.flushCallCount, greaterThan(0));
      });

      test('Double-click finishes path', () {
        const timestamp1 = 1000;
        const timestamp2 = 1200; // 200ms later (< 500ms threshold)

        // First click
        const down1 = PointerDownEvent(
          position: ui.Offset(300, 300),
        );
        penTool.onPointerDown(down1);

        // Simulate time passing
        // Second click at same position (within 10px threshold)
        const down2 = PointerDownEvent(
          position: ui.Offset(301, 301),
        );
        penTool.onPointerDown(down2);

        // Should finish path
        final finishEvents = eventRecorder.getEventsOfType<FinishPathEvent>();
        expect(
          finishEvents.length,
          equals(1),
          reason: 'Double-click should finish path',
        );
        expect(finishEvents[0].closed, isFalse);
      });

      test('ESC key cancels path', () {
        final keyEvent = KeyDownEvent(
          logicalKey: LogicalKeyboardKey.escape,
          physicalKey: PhysicalKeyboardKey.escape,
          timeStamp: Duration.zero,
        );

        final handled = penTool.onKeyPress(keyEvent);

        expect(handled, isTrue, reason: 'Tool should handle Escape key');

        // Verify EndGroupEvent only (no FinishPathEvent)
        expect(
          eventRecorder.recordedEvents.length,
          equals(1),
          reason: 'Should emit only EndGroupEvent',
        );
        expect(eventRecorder.recordedEvents[0], isA<EndGroupEvent>());

        // No FinishPathEvent = path is canceled
        final finishEvents = eventRecorder.getEventsOfType<FinishPathEvent>();
        expect(finishEvents.isEmpty, isTrue);
      });
    });

    group('State: ADJUSTING_HANDLES', () {
      setUp(() {
        penTool.onActivate();
        eventRecorder.clear();

        // Start path with first anchor
        const event1 = PointerDownEvent(position: ui.Offset(100, 100));
        penTool.onPointerDown(event1);
        const up1 = PointerUpEvent(position: ui.Offset(100, 100));
        penTool.onPointerUp(up1);

        // Add second anchor via drag (creates Bezier)
        const down2 = PointerDownEvent(position: ui.Offset(200, 200));
        penTool.onPointerDown(down2);
        const move2 = PointerMoveEvent(position: ui.Offset(220, 220));
        penTool.onPointerMove(move2);
        const up2 = PointerUpEvent(position: ui.Offset(220, 220));
        penTool.onPointerUp(up2);

        eventRecorder.clear();
      });

      test('Click on last anchor enters ADJUSTING_HANDLES state', () {
        // Click on last anchor (200, 200) - within 10px threshold
        const down = PointerDownEvent(position: ui.Offset(201, 201));
        final handled = penTool.onPointerDown(down);

        expect(handled, isTrue);

        // No events should be emitted yet (just state change)
        expect(eventRecorder.recordedEvents.isEmpty, isTrue);

        // State change verified by next drag emitting ModifyAnchorEvent
      });

      test('Drag from last anchor emits ModifyAnchorEvent', () {
        // Click on last anchor
        const down = PointerDownEvent(position: ui.Offset(200, 200));
        penTool.onPointerDown(down);

        // Drag to adjust handles
        const move = PointerMoveEvent(position: ui.Offset(230, 210));
        penTool.onPointerMove(move);

        const up = PointerUpEvent(position: ui.Offset(230, 210));
        penTool.onPointerUp(up);

        // Should emit ModifyAnchorEvent
        final modifyEvents = eventRecorder.getEventsOfType<ModifyAnchorEvent>();
        expect(modifyEvents.length, equals(1));

        final modifyEvent = modifyEvents[0];
        expect(modifyEvent.anchorIndex, equals(1)); // Second anchor (0-based)
        expect(modifyEvent.handleOut, isNotNull);
        expect(modifyEvent.handleIn, isNotNull);

        // Verify handles
        expect(modifyEvent.handleOut!.x, closeTo(30.0, 0.1));
        expect(modifyEvent.handleOut!.y, closeTo(10.0, 0.1));
        expect(modifyEvent.handleIn!.x, closeTo(-30.0, 0.1));
        expect(modifyEvent.handleIn!.y, closeTo(-10.0, 0.1));
      });

      test('After handle adjustment, returns to CREATING_PATH state', () {
        // Enter handle adjustment
        const down1 = PointerDownEvent(position: ui.Offset(200, 200));
        penTool.onPointerDown(down1);
        const move1 = PointerMoveEvent(position: ui.Offset(230, 210));
        penTool.onPointerMove(move1);
        const up1 = PointerUpEvent(position: ui.Offset(230, 210));
        penTool.onPointerUp(up1);

        eventRecorder.clear();

        // Now clicking elsewhere should add new anchor (CREATING_PATH behavior)
        const down2 = PointerDownEvent(position: ui.Offset(300, 300));
        penTool.onPointerDown(down2);
        const up2 = PointerUpEvent(position: ui.Offset(300, 300));
        penTool.onPointerUp(up2);

        // Should add new anchor
        final addEvents = eventRecorder.getEventsOfType<AddAnchorEvent>();
        expect(addEvents.length, equals(1));
      });
    });

    group('Path Closing', () {
      setUp(() {
        penTool.onActivate();
        eventRecorder.clear();

        // Create path with 3 anchors (minimum for closing)
        final positions = [
          const ui.Offset(100, 100),
          const ui.Offset(200, 100),
          const ui.Offset(200, 200),
        ];

        for (final pos in positions) {
          final down = PointerDownEvent(position: pos);
          penTool.onPointerDown(down);
          final up = PointerUpEvent(position: pos);
          penTool.onPointerUp(up);
        }

        eventRecorder.clear();
      });

      test('Click on first anchor closes path', () {
        // Click on first anchor (100, 100)
        const down = PointerDownEvent(position: ui.Offset(101, 101));
        penTool.onPointerDown(down);

        // Should finish path with closed=true
        final finishEvents = eventRecorder.getEventsOfType<FinishPathEvent>();
        expect(finishEvents.length, equals(1));
        expect(finishEvents[0].closed, isTrue);

        // Should also emit EndGroupEvent
        final endGroupEvents = eventRecorder.getEventsOfType<EndGroupEvent>();
        expect(endGroupEvents.length, equals(1));
      });

      test('Cannot close path with less than 3 anchors', () {
        // Create new path with only 2 anchors
        penTool.onActivate();
        eventRecorder.clear();

        const down1 = PointerDownEvent(position: ui.Offset(100, 100));
        penTool.onPointerDown(down1);
        const up1 = PointerUpEvent(position: ui.Offset(100, 100));
        penTool.onPointerUp(up1);

        const down2 = PointerDownEvent(position: ui.Offset(200, 200));
        penTool.onPointerDown(down2);
        const up2 = PointerUpEvent(position: ui.Offset(200, 200));
        penTool.onPointerUp(up2);

        eventRecorder.clear();

        // Try to click on first anchor
        const down3 = PointerDownEvent(position: ui.Offset(100, 100));
        penTool.onPointerDown(down3);

        // Should NOT close (should add new anchor instead)
        final finishEvents = eventRecorder.getEventsOfType<FinishPathEvent>();
        expect(finishEvents.isEmpty, isTrue);
      });
    });

    group('Tool Lifecycle', () {
      test('Tool has correct ID', () {
        expect(penTool.toolId, equals('pen'));
      });

      test('Tool has precise cursor', () {
        expect(penTool.cursor, equals(SystemMouseCursors.precise));
      });

      test('onActivate resets state to IDLE', () {
        // Start a path
        penTool.onActivate();
        const down = PointerDownEvent(position: ui.Offset(100, 100));
        penTool.onPointerDown(down);

        // Deactivate and reactivate
        penTool.onDeactivate();
        penTool.onActivate();

        eventRecorder.clear();

        // Should be able to start new path (IDLE state)
        const down2 = PointerDownEvent(position: ui.Offset(200, 200));
        penTool.onPointerDown(down2);

        final createEvents = eventRecorder.getEventsOfType<CreatePathEvent>();
        expect(createEvents.length, equals(1));
      });

      test('onDeactivate finishes path if CREATING_PATH', () {
        penTool.onActivate();
        eventRecorder.clear();

        // Start path
        const down = PointerDownEvent(position: ui.Offset(100, 100));
        penTool.onPointerDown(down);

        eventRecorder.clear();

        // Deactivate mid-creation
        penTool.onDeactivate();

        // Should emit FinishPathEvent + EndGroupEvent
        expect(eventRecorder.recordedEvents.length, greaterThanOrEqualTo(2));
        expect(
          eventRecorder.recordedEvents.any((e) => e is FinishPathEvent),
          isTrue,
        );
        expect(
          eventRecorder.recordedEvents.any((e) => e is EndGroupEvent),
          isTrue,
        );
        expect(eventRecorder.flushCallCount, greaterThan(0));
      });
    });

    group('Event Grouping', () {
      test('Entire path creation is one undo group', () {
        penTool.onActivate();
        eventRecorder.clear();

        // Create complete path
        const positions = [
          ui.Offset(100, 100),
          ui.Offset(200, 200),
          ui.Offset(300, 300),
        ];

        for (final pos in positions) {
          final down = PointerDownEvent(position: pos);
          penTool.onPointerDown(down);
          final up = PointerUpEvent(position: pos);
          penTool.onPointerUp(up);
        }

        // Finish path
        final keyEvent = KeyDownEvent(
          logicalKey: LogicalKeyboardKey.enter,
          physicalKey: PhysicalKeyboardKey.enter,
          timeStamp: Duration.zero,
        );
        penTool.onKeyPress(keyEvent);

        // Verify grouping
        final startGroups = eventRecorder.getEventsOfType<StartGroupEvent>();
        final endGroups = eventRecorder.getEventsOfType<EndGroupEvent>();

        expect(startGroups.length, equals(1));
        expect(endGroups.length, equals(1));

        // Same group ID
        expect(startGroups[0].groupId, equals(endGroups[0].groupId));

        // All events between start and end
        final startIndex = eventRecorder.recordedEvents.indexOf(startGroups[0]);
        final endIndex = eventRecorder.recordedEvents.indexOf(endGroups[0]);

        expect(endIndex, greaterThan(startIndex));
        expect(
          endIndex - startIndex,
          greaterThanOrEqualTo(3),
          reason: 'Should have StartGroup, CreatePath, AddAnchors, '
              'FinishPath, EndGroup',
        );
      });

      test('Canceled path still emits EndGroupEvent', () {
        penTool.onActivate();
        eventRecorder.clear();

        // Start path
        const down = PointerDownEvent(position: ui.Offset(100, 100));
        penTool.onPointerDown(down);

        // Cancel
        final keyEvent = KeyDownEvent(
          logicalKey: LogicalKeyboardKey.escape,
          physicalKey: PhysicalKeyboardKey.escape,
          timeStamp: Duration.zero,
        );
        penTool.onKeyPress(keyEvent);

        // Should have StartGroup and EndGroup
        final startGroups = eventRecorder.getEventsOfType<StartGroupEvent>();
        final endGroups = eventRecorder.getEventsOfType<EndGroupEvent>();

        expect(startGroups.length, equals(1));
        expect(endGroups.length, equals(1));
        expect(startGroups[0].groupId, equals(endGroups[0].groupId));
      });
    });

    group('Preview State', () {
      test('Preview state exposes hover position', () {
        penTool.onActivate();

        const move = PointerMoveEvent(position: ui.Offset(150, 150));
        penTool.onPointerMove(move);

        final previewState = penTool.previewState;
        expect(previewState.hoverPosition, isNotNull);
        expect(previewState.hoverPosition!.x, closeTo(150.0, 0.1));
        expect(previewState.hoverPosition!.y, closeTo(150.0, 0.1));
      });

      test('Preview state exposes last anchor position', () {
        penTool.onActivate();

        const down = PointerDownEvent(position: ui.Offset(100, 100));
        penTool.onPointerDown(down);
        const up = PointerUpEvent(position: ui.Offset(100, 100));
        penTool.onPointerUp(up);

        final previewState = penTool.previewState;
        expect(previewState.lastAnchorPosition, isNotNull);
        expect(previewState.lastAnchorPosition!.x, closeTo(100.0, 0.1));
        expect(previewState.lastAnchorPosition!.y, closeTo(100.0, 0.1));
      });

      test('Preview state indicates dragging status', () {
        penTool.onActivate();

        // Start path
        const down1 = PointerDownEvent(position: ui.Offset(100, 100));
        penTool.onPointerDown(down1);
        const up1 = PointerUpEvent(position: ui.Offset(100, 100));
        penTool.onPointerUp(up1);

        expect(penTool.previewState.isDragging, isFalse);

        // Start dragging
        const down2 = PointerDownEvent(position: ui.Offset(200, 200));
        penTool.onPointerDown(down2);

        expect(penTool.previewState.isDragging, isFalse);

        const move = PointerMoveEvent(position: ui.Offset(220, 220));
        penTool.onPointerMove(move);

        expect(penTool.previewState.isDragging, isTrue);

        const up2 = PointerUpEvent(position: ui.Offset(220, 220));
        penTool.onPointerUp(up2);

        expect(penTool.previewState.isDragging, isFalse);
      });
    });

    group('Edge Cases', () {
      test('Multiple activations reset state correctly', () {
        for (var i = 0; i < 3; i++) {
          penTool.onActivate();
          eventRecorder.clear();

          const down = PointerDownEvent(position: ui.Offset(100, 100));
          penTool.onPointerDown(down);

          final createEvents = eventRecorder.getEventsOfType<CreatePathEvent>();
          expect(createEvents.length, equals(1));

          penTool.onDeactivate();
        }
      });

      test('Flush is called on path finish', () {
        penTool.onActivate();
        eventRecorder.clear();

        // Create path
        const down = PointerDownEvent(position: ui.Offset(100, 100));
        penTool.onPointerDown(down);

        final initialFlushCount = eventRecorder.flushCallCount;

        // Finish path
        final keyEvent = KeyDownEvent(
          logicalKey: LogicalKeyboardKey.enter,
          physicalKey: PhysicalKeyboardKey.enter,
          timeStamp: Duration.zero,
        );
        penTool.onKeyPress(keyEvent);

        expect(
          eventRecorder.flushCallCount,
          greaterThan(initialFlushCount),
        );
      });

      test('Unhandled keys return false', () {
        penTool.onActivate();

        final keyEvent = KeyDownEvent(
          logicalKey: LogicalKeyboardKey.keyA,
          physicalKey: PhysicalKeyboardKey.keyA,
          timeStamp: Duration.zero,
        );

        final handled = penTool.onKeyPress(keyEvent);
        expect(handled, isFalse);
      });

      test('Pointer events in IDLE state only handle first click', () {
        penTool.onActivate();
        eventRecorder.clear();

        // Move before any path started
        const move = PointerMoveEvent(position: ui.Offset(100, 100));
        final handled = penTool.onPointerMove(move);

        // Should return false (no active handling)
        expect(handled, isFalse);
        expect(eventRecorder.recordedEvents.isEmpty, isTrue);
      });
    });
  });
}
