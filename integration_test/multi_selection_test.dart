import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/domain/document/selection.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/events/selection_events.dart' as events;
import 'package:wiretuner/domain/events/object_events.dart';
import 'package:wiretuner/domain/events/group_events.dart';
import 'package:wiretuner/domain/models/path.dart' as domain;
import 'package:wiretuner/domain/models/anchor_point.dart';
import 'package:wiretuner/domain/models/segment.dart';
import 'package:wiretuner/application/tools/selection/selection_tool.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';

/// Mock event recorder for testing.
class MockEventRecorder {
  final List<EventBase> recordedEvents = [];

  void recordEvent(EventBase event) {
    recordedEvents.add(event);
  }

  void flush() {}

  void clear() {
    recordedEvents.clear();
  }

  List<T> getEventsOfType<T extends EventBase>() =>
      recordedEvents.whereType<T>().toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Multi-Selection Integration Tests', () {
    late Document document;
    late ViewportController viewportController;
    late MockEventRecorder eventRecorder;
    late SelectionTool selectionTool;

    setUp(() {
      // Create a document with three distinct objects
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
          AnchorPoint(position: Point(x: 500, y: 200)),
        ],
        segments: [
          Segment.line(startIndex: 0, endIndex: 1),
          Segment.line(startIndex: 1, endIndex: 2),
          Segment.line(startIndex: 2, endIndex: 3),
          Segment.line(startIndex: 3, endIndex: 0),
        ],
        closed: true,
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

      viewportController = ViewportController(
        initialPan: const Offset(0, 0),
        initialZoom: 1.0,
      );

      eventRecorder = MockEventRecorder();

      selectionTool = SelectionTool(
        document: document,
        viewportController: viewportController,
        eventRecorder: eventRecorder,
      );

      selectionTool.onActivate();
    });

    test('Normal click replaces selection', () async {
      // First, select path-1 with normal click
      await simulateClick(
        selectionTool,
        position: const Offset(150, 150),
      );

      // Verify path-1 is selected with replace mode
      final selectEvents = eventRecorder.getEventsOfType<events.SelectObjectsEvent>();
      expect(selectEvents.length, 1);
      expect(selectEvents.first.mode, events.SelectionMode.replace);
      expect(selectEvents.first.objectIds, ['path-1']);

      eventRecorder.clear();

      // Click on path-2 (should replace selection)
      await simulateClick(
        selectionTool,
        position: const Offset(350, 150),
      );

      // Verify path-2 replaces selection
      final replaceEvents = eventRecorder.getEventsOfType<events.SelectObjectsEvent>();
      expect(replaceEvents.length, 1);
      expect(replaceEvents.first.mode, events.SelectionMode.replace);
      expect(replaceEvents.first.objectIds, ['path-2']);
    });

    test('SelectionTool emits correct SelectionMode events', () async {
      // Verify that SelectionTool code uses correct selection modes
      // (Actual keyboard simulation is tested in widget tests)

      // Click on path-1
      await simulateClick(
        selectionTool,
        position: const Offset(150, 150),
      );

      // Verify replace mode is used
      final selectEvents = eventRecorder.getEventsOfType<events.SelectObjectsEvent>();
      expect(selectEvents.isNotEmpty, isTrue);
      expect(selectEvents.first.mode, events.SelectionMode.replace);
    });

    test('Multiple objects can be selected and dragged together', () async {
      // Create document with pre-selected objects
      final documentWithSelection = document.copyWith(
        selection: const Selection(objectIds: {'path-1', 'path-2', 'path-3'}),
      );

      final toolWithSelection = SelectionTool(
        document: documentWithSelection,
        viewportController: viewportController,
        eventRecorder: eventRecorder,
      );
      toolWithSelection.onActivate();

      eventRecorder.clear();

      // Start drag on path-1
      await simulateDrag(
        toolWithSelection,
        startPosition: const Offset(150, 150),
        endPosition: const Offset(200, 200),
      );

      // Verify event sequence
      final startGroupEvents = eventRecorder.getEventsOfType<StartGroupEvent>();
      final moveEvents = eventRecorder.getEventsOfType<MoveObjectEvent>();
      final endGroupEvents = eventRecorder.getEventsOfType<EndGroupEvent>();

      expect(startGroupEvents.length, 1, reason: 'Should have one StartGroupEvent');
      expect(endGroupEvents.length, 1, reason: 'Should have one EndGroupEvent');
      expect(moveEvents.isNotEmpty, isTrue, reason: 'Should have MoveObjectEvents');

      // Verify all three objects are included in move event
      final finalMoveEvent = moveEvents.last;
      expect(finalMoveEvent.objectIds.length, 3);
      expect(
        finalMoveEvent.objectIds,
        containsAll(['path-1', 'path-2', 'path-3']),
      );

      // Verify group IDs match
      expect(
        startGroupEvents.first.groupId,
        equals(endGroupEvents.first.groupId),
      );
    });

    test('Bounding box encompasses all selected objects', () async {
      // This test verifies the logic for computing unified bounds
      // The actual rendering is tested in widget tests

      // Create document with multiple selected objects
      final documentWithSelection = document.copyWith(
        selection: const Selection(objectIds: {'path-1', 'path-2', 'path-3'}),
      );

      // Verify selection contains all three objects
      expect(documentWithSelection.selection.selectedCount, 3);
      expect(
        documentWithSelection.selection.objectIds,
        containsAll(['path-1', 'path-2', 'path-3']),
      );

      // Get bounds of all selected objects
      final selectedObjects = documentWithSelection.getSelectedObjects();
      expect(selectedObjects.length, 3);

      // Compute expected unified bounds
      final bounds = selectedObjects.map((obj) => obj.getBounds()).toList();

      // Path-1: (100, 100) to (200, 200)
      // Path-2: (300, 100) to (400, 200)
      // Path-3: (500, 100) to (600, 200)
      // Union: (100, 100) to (600, 200)

      double minX = bounds.first.x;
      double minY = bounds.first.y;
      double maxX = bounds.first.x + bounds.first.width;
      double maxY = bounds.first.y + bounds.first.height;

      for (final rect in bounds.skip(1)) {
        minX = minX < rect.x ? minX : rect.x;
        minY = minY < rect.y ? minY : rect.y;
        final rectMaxX = rect.x + rect.width;
        final rectMaxY = rect.y + rect.height;
        maxX = maxX > rectMaxX ? maxX : rectMaxX;
        maxY = maxY > rectMaxY ? maxY : rectMaxY;
      }

      // Verify unified bounds
      expect(minX, 100.0);
      expect(minY, 100.0);
      expect(maxX, 600.0);
      expect(maxY, 200.0);
      expect(maxX - minX, 500.0); // Width
      expect(maxY - minY, 100.0); // Height
    });

    test('Selection model stores multiple object IDs', () {
      // Test selection model helpers
      final selection = Selection.empty();

      // Add first object
      final selection1 = selection.addObject('path-1');
      expect(selection1.contains('path-1'), isTrue);
      expect(selection1.selectedCount, 1);

      // Add second object
      final selection2 = selection1.addObject('path-2');
      expect(selection2.contains('path-1'), isTrue);
      expect(selection2.contains('path-2'), isTrue);
      expect(selection2.selectedCount, 2);

      // Add multiple objects at once
      final selection3 = selection.addObjects(['path-1', 'path-2', 'path-3']);
      expect(selection3.selectedCount, 3);
      expect(selection3.objectIds, {'path-1', 'path-2', 'path-3'});

      // Remove object
      final selection4 = selection3.removeObject('path-2');
      expect(selection4.selectedCount, 2);
      expect(selection4.contains('path-2'), isFalse);
      expect(selection4.contains('path-1'), isTrue);
      expect(selection4.contains('path-3'), isTrue);
    });

    test('Marquee selection selects multiple objects', () async {
      // Marquee around path-2 and path-3
      await simulateMarquee(
        selectionTool,
        startPosition: const Offset(280, 80),
        endPosition: const Offset(620, 220),
      );

      // Verify marquee selection (default replace mode without modifiers)
      final selectEvents = eventRecorder.getEventsOfType<events.SelectObjectsEvent>();
      expect(selectEvents.length, 1);

      // Should select path-2 and path-3
      expect(selectEvents.first.objectIds.length, 2);
      expect(selectEvents.first.objectIds, containsAll(['path-2', 'path-3']));
    });

    test('Empty area click clears selection', () async {
      // Start with selection
      final documentWithSelection = document.copyWith(
        selection: const Selection(objectIds: {'path-1', 'path-2'}),
      );

      final toolWithSelection = SelectionTool(
        document: documentWithSelection,
        viewportController: viewportController,
        eventRecorder: eventRecorder,
      );
      toolWithSelection.onActivate();

      eventRecorder.clear();

      // Click on empty area
      await simulateClick(
        toolWithSelection,
        position: const Offset(50, 50), // Empty area
      );

      // Verify clear selection event
      final clearEvents = eventRecorder.getEventsOfType<events.ClearSelectionEvent>();
      expect(clearEvents.length, 1);
    });
  });
}

/// Helper to simulate a click.
Future<void> simulateClick(
  SelectionTool tool, {
  required Offset position,
}) async {
  tool.onPointerDown(PointerDownEvent(
    position: position,
    buttons: kPrimaryButton,
  ));
  tool.onPointerUp(PointerUpEvent(position: position));
}

/// Helper to simulate a drag operation.
Future<void> simulateDrag(
  SelectionTool tool, {
  required Offset startPosition,
  required Offset endPosition,
}) async {
  tool.onPointerDown(PointerDownEvent(
    position: startPosition,
    buttons: kPrimaryButton,
  ));
  tool.onPointerMove(PointerMoveEvent(position: endPosition));
  tool.onPointerUp(PointerUpEvent(position: endPosition));
}

/// Helper to simulate a marquee selection.
Future<void> simulateMarquee(
  SelectionTool tool, {
  required Offset startPosition,
  required Offset endPosition,
}) async {
  tool.onPointerDown(PointerDownEvent(
    position: startPosition,
    buttons: kPrimaryButton,
  ));
  tool.onPointerMove(PointerMoveEvent(position: endPosition));
  tool.onPointerUp(PointerUpEvent(position: endPosition));
}
