/// Integration tests for Pen Tool straight path creation (Task I6.T2).
library;

///
/// These tests verify the acceptance criteria for straight path creation:
/// - AC1: Clicking creates straight segments between anchors
/// - AC2: Anchors have anchorType = corner (line), no handles
/// - AC3: Path renders as expected in canvas
/// - AC4: Integration test creates 5-point straight path successfully
///
/// Related: I6.T1 (PenTool State Machine), T022 (Pen Tool - Straight Segments)

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

  group('Pen Tool Straight Path Integration Tests (I6.T2)', () {
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

    group('AC4: Complete 5-Point Straight Path Workflow', () {
      test('should create 5-point straight path successfully', () async {
        // Clear any events from setUp
        recorder.clear();

        // Define 5 well-spaced points for the path
        final points = [
          const ui.Offset(100, 100), // Point 1 - start
          const ui.Offset(200, 150), // Point 2
          const ui.Offset(300, 100), // Point 3
          const ui.Offset(350, 200), // Point 4
          const ui.Offset(250, 250), // Point 5
        ];

        // Click each point (pointer down + up = click)
        for (int i = 0; i < points.length; i++) {
          penTool.onPointerDown(PointerDownEvent(position: points[i]));
          penTool.onPointerUp(PointerUpEvent(position: points[i]));
          // Wait for events to be persisted between clicks
          await Future.delayed(const Duration(milliseconds: 50));
        }

        // Finish the path with Enter key
        penTool.onKeyPress(
          const KeyDownEvent(
            logicalKey: LogicalKeyboardKey.enter,
            physicalKey: PhysicalKeyboardKey.enter,
            timeStamp: Duration.zero,
          ),
        );

        // Wait for finish events to be persisted
        await Future.delayed(const Duration(milliseconds: 200));

        // Verify complete event sequence:
        // StartGroup, CreatePath, AddAnchor×4, FinishPath, EndGroup
        expect(
          recorder.events.length,
          greaterThanOrEqualTo(7),
          reason:
              'Should have at least StartGroup + CreatePath + 4×AddAnchor + FinishPath + EndGroup',
        );

        // Verify event sequence
        expect(recorder.startGroupEvents.length, greaterThanOrEqualTo(1),
            reason: 'Should have StartGroupEvent');
        expect(recorder.createPathEvents.length, greaterThanOrEqualTo(1),
            reason: 'Should have CreatePathEvent');
        expect(recorder.addAnchorEvents.length, greaterThanOrEqualTo(4),
            reason: '4 additional anchors after initial anchor');
        expect(recorder.finishPathEvents.length, greaterThanOrEqualTo(1),
            reason: 'Should have FinishPathEvent');
        expect(recorder.endGroupEvents.length, greaterThanOrEqualTo(1),
            reason: 'Should have EndGroupEvent');

        // Verify flush was called
        expect(recorder.flushCount, greaterThan(0),
            reason: 'Should flush events on path finish');
      });
    });

    group('AC1 & AC2: Straight Segment Properties', () {
      test('should create anchors with correct type and no handles', () async {
        recorder.clear();

        // Create path with 3 clicks
        final points = [
          const ui.Offset(100, 100),
          const ui.Offset(200, 100),
          const ui.Offset(200, 200),
        ];

        for (final point in points) {
          penTool.onPointerDown(PointerDownEvent(position: point));
          penTool.onPointerUp(PointerUpEvent(position: point));
          await Future.delayed(const Duration(milliseconds: 10));
        }

        await Future.delayed(const Duration(milliseconds: 50));

        // Verify all anchors have line type (corner) with no handles
        for (final event in recorder.addAnchorEvents) {
          expect(
            event.anchorType,
            equals(AnchorType.line),
            reason: 'Straight segments should use line anchor type',
          );
          expect(
            event.handleIn,
            isNull,
            reason: 'Straight anchors should have no handleIn',
          );
          expect(
            event.handleOut,
            isNull,
            reason: 'Straight anchors should have no handleOut',
          );
        }
      });

      test('should create straight segments between anchors', () async {
        recorder.clear();

        // Create 4-point path
        final points = [
          const ui.Offset(100, 100), // Start
          const ui.Offset(200, 100), // Horizontal segment
          const ui.Offset(200, 200), // Vertical segment
          const ui.Offset(100, 200), // Closing horizontal segment
        ];

        for (final point in points) {
          penTool.onPointerDown(PointerDownEvent(position: point));
          penTool.onPointerUp(PointerUpEvent(position: point));
          await Future.delayed(const Duration(milliseconds: 10));
        }

        await Future.delayed(const Duration(milliseconds: 50));

        // Verify 3 straight segments were added (4 points - 1 initial)
        expect(recorder.addAnchorEvents.length, equals(3));

        // Verify anchor positions match expected points
        expect(
          recorder.addAnchorEvents[0].position.x,
          closeTo(200, 1.0),
          reason: 'Second anchor X position',
        );
        expect(
          recorder.addAnchorEvents[0].position.y,
          closeTo(100, 1.0),
          reason: 'Second anchor Y position',
        );

        expect(
          recorder.addAnchorEvents[1].position.x,
          closeTo(200, 1.0),
          reason: 'Third anchor X position',
        );
        expect(
          recorder.addAnchorEvents[1].position.y,
          closeTo(200, 1.0),
          reason: 'Third anchor Y position',
        );

        expect(
          recorder.addAnchorEvents[2].position.x,
          closeTo(100, 1.0),
          reason: 'Fourth anchor X position',
        );
        expect(
          recorder.addAnchorEvents[2].position.y,
          closeTo(200, 1.0),
          reason: 'Fourth anchor Y position',
        );
      });
    });

    group('AC3: Path Rendering', () {
      test('should render path without errors', () async {
        // Create 3-point path
        final points = [
          const ui.Offset(100, 100),
          const ui.Offset(200, 150),
          const ui.Offset(300, 100),
        ];

        for (final point in points) {
          penTool.onPointerDown(PointerDownEvent(position: point));
          penTool.onPointerUp(PointerUpEvent(position: point));
        }

        // Create mock canvas for rendering test
        final canvas = _MockCanvas();
        const size = ui.Size(800, 600);

        // Render overlay - should not throw
        expect(
          () => penTool.renderOverlay(canvas, size),
          returnsNormally,
          reason: 'Path rendering should work without errors',
        );
      });

      test('should expose preview state during path creation', () async {
        recorder.clear();

        // Start path
        penTool.onPointerDown(const PointerDownEvent(position: ui.Offset(100, 100)));
        penTool.onPointerUp(const PointerUpEvent(position: ui.Offset(100, 100)));

        // Add second point
        penTool.onPointerDown(const PointerDownEvent(position: ui.Offset(200, 150)));

        // Verify preview state is available
        final previewState = penTool.previewState;
        expect(previewState.lastAnchorPosition, isNotNull,
            reason: 'Should expose last anchor position');
        expect(previewState.dragStartPosition, isNotNull,
            reason: 'Should track drag start during pointer down');
      });
    });

    group('Event Grouping and Consistency', () {
      test('should maintain consistent path and group IDs', () async {
        recorder.clear();

        // Create 3-point path
        for (int i = 0; i < 3; i++) {
          penTool.onPointerDown(
            PointerDownEvent(position: ui.Offset(100 + i * 50.0, 100)),
          );
          penTool.onPointerUp(
            PointerUpEvent(position: ui.Offset(100 + i * 50.0, 100)),
          );
        }

        // Finish path
        penTool.onKeyPress(
          const KeyDownEvent(
            logicalKey: LogicalKeyboardKey.enter,
            physicalKey: PhysicalKeyboardKey.enter,
            timeStamp: Duration.zero,
          ),
        );

        await Future.delayed(const Duration(milliseconds: 50));

        // Verify group IDs match
        expect(recorder.startGroupEvents.length, equals(1));
        expect(recorder.endGroupEvents.length, equals(1));
        expect(
          recorder.startGroupEvents[0].groupId,
          equals(recorder.endGroupEvents[0].groupId),
          reason: 'Start and end group IDs should match',
        );

        // Verify path IDs match across events
        final pathId = recorder.createPathEvents[0].pathId;
        for (final event in recorder.addAnchorEvents) {
          expect(
            event.pathId,
            equals(pathId),
            reason: 'All anchors should reference same path',
          );
        }
        expect(
          recorder.finishPathEvents[0].pathId,
          equals(pathId),
          reason: 'Finish event should reference same path',
        );
      });

      test('should have monotonically increasing timestamps', () async {
        recorder.clear();

        // Create path with multiple anchors
        for (int i = 0; i < 5; i++) {
          penTool.onPointerDown(
            PointerDownEvent(position: ui.Offset(100 + i * 50.0, 100)),
          );
          penTool.onPointerUp(
            PointerUpEvent(position: ui.Offset(100 + i * 50.0, 100)),
          );
          await Future.delayed(const Duration(milliseconds: 10));
        }

        penTool.onKeyPress(
          const KeyDownEvent(
            logicalKey: LogicalKeyboardKey.enter,
            physicalKey: PhysicalKeyboardKey.enter,
            timeStamp: Duration.zero,
          ),
        );

        await Future.delayed(const Duration(milliseconds: 50));

        // Verify timestamps are monotonically increasing
        for (int i = 1; i < recorder.events.length; i++) {
          expect(
            recorder.events[i].timestamp,
            greaterThanOrEqualTo(recorder.events[i - 1].timestamp),
            reason: 'Event timestamps should be monotonically increasing',
          );
        }
      });

      test('should have unique event IDs', () async {
        recorder.clear();

        // Create 5-point path
        for (int i = 0; i < 5; i++) {
          penTool.onPointerDown(
            PointerDownEvent(position: ui.Offset(100 + i * 50.0, 100)),
          );
          penTool.onPointerUp(
            PointerUpEvent(position: ui.Offset(100 + i * 50.0, 100)),
          );
        }

        penTool.onKeyPress(
          const KeyDownEvent(
            logicalKey: LogicalKeyboardKey.enter,
            physicalKey: PhysicalKeyboardKey.enter,
            timeStamp: Duration.zero,
          ),
        );

        await Future.delayed(const Duration(milliseconds: 50));

        // Collect all event IDs
        final eventIds = recorder.events.map((e) => e.eventId).toSet();

        // Should all be unique
        expect(
          eventIds.length,
          equals(recorder.events.length),
          reason: 'All event IDs should be unique',
        );
      });
    });

    group('Path Completion Methods', () {
      test('should finish path with Enter key', () async {
        recorder.clear();

        // Create 3-point path
        for (int i = 0; i < 3; i++) {
          penTool.onPointerDown(
            PointerDownEvent(position: ui.Offset(100 + i * 50.0, 100)),
          );
          penTool.onPointerUp(
            PointerUpEvent(position: ui.Offset(100 + i * 50.0, 100)),
          );
        }

        recorder.clear();

        // Finish with Enter
        penTool.onKeyPress(
          const KeyDownEvent(
            logicalKey: LogicalKeyboardKey.enter,
            physicalKey: PhysicalKeyboardKey.enter,
            timeStamp: Duration.zero,
          ),
        );

        await Future.delayed(const Duration(milliseconds: 50));

        // Should have FinishPath and EndGroup events
        expect(recorder.finishPathEvents.length, equals(1));
        expect(recorder.finishPathEvents[0].closed, isFalse,
            reason: 'Enter should create open path');
        expect(recorder.endGroupEvents.length, equals(1));
      });

      test('should finish path with double-click', () async {
        recorder.clear();

        // Create 2-point path
        penTool.onPointerDown(const PointerDownEvent(position: ui.Offset(100, 100)));
        penTool.onPointerUp(const PointerUpEvent(position: ui.Offset(100, 100)));
        await Future.delayed(const Duration(milliseconds: 10));

        penTool.onPointerDown(const PointerDownEvent(position: ui.Offset(200, 100)));
        penTool.onPointerUp(const PointerUpEvent(position: ui.Offset(200, 100)));
        await Future.delayed(const Duration(milliseconds: 10));

        recorder.clear();

        // Double-click to finish (within time and distance threshold)
        penTool.onPointerDown(const PointerDownEvent(position: ui.Offset(202, 102)));
        await Future.delayed(const Duration(milliseconds: 50));

        // Should have FinishPath and EndGroup events
        expect(
          recorder.finishPathEvents.isNotEmpty,
          isTrue,
          reason: 'Double-click should finish path',
        );
        expect(recorder.endGroupEvents.isNotEmpty, isTrue);
      });

      test('should cancel path with Escape key', () async {
        recorder.clear();

        // Create 3-point path
        for (int i = 0; i < 3; i++) {
          penTool.onPointerDown(
            PointerDownEvent(position: ui.Offset(100 + i * 50.0, 100)),
          );
          penTool.onPointerUp(
            PointerUpEvent(position: ui.Offset(100 + i * 50.0, 100)),
          );
        }

        recorder.clear();

        // Cancel with Escape
        penTool.onKeyPress(
          const KeyDownEvent(
            logicalKey: LogicalKeyboardKey.escape,
            physicalKey: PhysicalKeyboardKey.escape,
            timeStamp: Duration.zero,
          ),
        );

        await Future.delayed(const Duration(milliseconds: 50));

        // Should only have EndGroup, no FinishPath
        expect(recorder.finishPathEvents.length, equals(0),
            reason: 'Escape should not emit FinishPath');
        expect(recorder.endGroupEvents.length, equals(1),
            reason: 'Escape should emit EndGroup to close undo group');
      });
    });

    group('Angle Constraint (Shift+Click)', () {
      test('should constrain angles to 45° increments with Shift', () async {
        recorder.clear();

        // Start path
        penTool.onPointerDown(const PointerDownEvent(position: ui.Offset(100, 100)));
        penTool.onPointerUp(const PointerUpEvent(position: ui.Offset(100, 100)));

        recorder.clear();

        // Press Shift
        HardwareKeyboard.instance.handleKeyEvent(
          const KeyDownEvent(
            logicalKey: LogicalKeyboardKey.shiftLeft,
            physicalKey: PhysicalKeyboardKey.shiftLeft,
            timeStamp: Duration.zero,
          ),
        );

        // Click at roughly 10° angle (should snap to 0° horizontal)
        penTool.onPointerDown(const PointerDownEvent(position: ui.Offset(200, 110)));
        penTool.onPointerUp(const PointerUpEvent(position: ui.Offset(200, 110)));

        // Release Shift
        HardwareKeyboard.instance.handleKeyEvent(
          const KeyUpEvent(
            logicalKey: LogicalKeyboardKey.shiftLeft,
            physicalKey: PhysicalKeyboardKey.shiftLeft,
            timeStamp: Duration.zero,
          ),
        );

        await Future.delayed(const Duration(milliseconds: 50));

        // Verify anchor was constrained to 0° (Y should match start Y)
        expect(recorder.addAnchorEvents.length, equals(1));
        expect(
          recorder.addAnchorEvents[0].position.y,
          closeTo(100.0, 0.1),
          reason: 'Shift should constrain to 0° horizontal',
        );
      });
    });

    group('Edge Cases', () {
      test('should handle rapid clicks', () async {
        recorder.clear();

        // Rapidly click 5 times with minimal delay
        for (int i = 0; i < 5; i++) {
          penTool.onPointerDown(
            PointerDownEvent(position: ui.Offset(100 + i * 20.0, 100)),
          );
          penTool.onPointerUp(
            PointerUpEvent(position: ui.Offset(100 + i * 20.0, 100)),
          );
          await Future.delayed(const Duration(milliseconds: 1));
        }

        await Future.delayed(const Duration(milliseconds: 50));

        // Should have created all anchors
        expect(recorder.createPathEvents.length, equals(1));
        expect(recorder.addAnchorEvents.length, equals(4),
            reason: 'Should handle rapid clicks correctly');
      });

      test('should distinguish clicks from very short drags', () async {
        recorder.clear();

        // First point
        penTool.onPointerDown(const PointerDownEvent(position: ui.Offset(100, 100)));
        penTool.onPointerUp(const PointerUpEvent(position: ui.Offset(100, 100)));

        recorder.clear();

        // Very short drag (< 5px threshold) - should be treated as click
        penTool.onPointerDown(const PointerDownEvent(position: ui.Offset(200, 100)));
        penTool.onPointerMove(const PointerMoveEvent(position: ui.Offset(202, 101)));
        penTool.onPointerUp(const PointerUpEvent(position: ui.Offset(202, 101)));

        await Future.delayed(const Duration(milliseconds: 50));

        // Should create straight line anchor (not Bezier)
        expect(recorder.addAnchorEvents.length, equals(1));
        expect(
          recorder.addAnchorEvents[0].anchorType,
          equals(AnchorType.line),
          reason: 'Very short drags should be treated as clicks',
        );
        expect(recorder.addAnchorEvents[0].handleIn, isNull);
        expect(recorder.addAnchorEvents[0].handleOut, isNull);
      });

      test('should handle single-anchor path finish', () async {
        recorder.clear();

        // Create path with just one anchor
        penTool.onPointerDown(const PointerDownEvent(position: ui.Offset(100, 100)));
        penTool.onPointerUp(const PointerUpEvent(position: ui.Offset(100, 100)));

        // Wait for initial path creation events to persist
        await Future.delayed(const Duration(milliseconds: 100));

        // Finish immediately
        penTool.onKeyPress(
          const KeyDownEvent(
            logicalKey: LogicalKeyboardKey.enter,
            physicalKey: PhysicalKeyboardKey.enter,
            timeStamp: Duration.zero,
          ),
        );

        // Wait for finish events to persist
        await Future.delayed(const Duration(milliseconds: 100));

        // Should still complete with proper event sequence
        expect(recorder.startGroupEvents.length, greaterThanOrEqualTo(1),
            reason: 'Should have at least one StartGroupEvent');
        expect(recorder.createPathEvents.length, greaterThanOrEqualTo(1),
            reason: 'Should have at least one CreatePathEvent');
        expect(recorder.finishPathEvents.length, greaterThanOrEqualTo(1),
            reason: 'Should have at least one FinishPathEvent');
        expect(recorder.endGroupEvents.length, greaterThanOrEqualTo(1),
            reason: 'Should have at least one EndGroupEvent');
      });
    });
  });
}

/// Mock Canvas for rendering tests.
class _MockCanvas implements ui.Canvas {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    // No-op for rendering tests
  }
}
