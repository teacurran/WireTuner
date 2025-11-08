import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/application/tools/direct_selection/direct_selection_tool.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/domain/document/selection.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/events/path_events.dart';
import 'package:wiretuner/domain/models/path.dart' as domain;
import 'package:wiretuner/domain/models/anchor_point.dart';
import 'package:wiretuner/domain/models/segment.dart';
import 'package:wiretuner/infrastructure/event_sourcing/event_recorder.dart';
import 'package:wiretuner/infrastructure/telemetry/telemetry_service.dart';
import 'package:wiretuner/presentation/canvas/painter/path_renderer.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';
import 'package:wiretuner/infrastructure/persistence/event_store.dart';

/// Mock EventRecorder for testing.
class MockEventRecorder extends EventRecorder {
  final List<EventBase> recordedEvents = [];
  int flushCallCount = 0;

  MockEventRecorder()
      : super(
          eventStore: _MockEventStore(),
          documentId: 'test-doc',
        );

  @override
  void recordEvent(EventBase event) {
    if (!isPaused) {
      recordedEvents.add(event);
    }
  }

  @override
  void flush() {
    flushCallCount++;
  }

  void clear() {
    recordedEvents.clear();
    flushCallCount = 0;
  }
}

class _MockEventStore implements EventStore {
  @override
  Future<int> insertEvent(String documentId, EventBase event) async {
    return 1; // Return sequence number
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DirectSelectionTool', () {
    late DirectSelectionTool directSelectionTool;
    late ViewportController viewportController;
    late MockEventRecorder eventRecorder;
    late PathRenderer pathRenderer;
    late Document document;

    setUp(() {
      viewportController = ViewportController(
        initialPan: const Offset(0, 0),
        initialZoom: 1.0,
      );
      eventRecorder = MockEventRecorder();
      pathRenderer = PathRenderer();

      final smoothAnchor = AnchorPoint.smooth(
        position: const Point(x: 200, y: 200),
        handleOut: const Point(x: 50, y: 0),
      );

      final path1 = domain.Path(
        anchors: [
          AnchorPoint(position: const Point(x: 100, y: 200)),
          smoothAnchor,
        ],
        segments: [
          Segment.line(startIndex: 0, endIndex: 1),
        ],
        closed: false,
      );

      final layer = Layer(
        id: 'layer-1',
        name: 'Test Layer',
        objects: [
          VectorObject.path(id: 'path-1', path: path1),
        ],
      );

      document = Document(
        id: 'doc-1',
        title: 'Test Document',
        layers: [layer],
        selection: Selection(
          objectIds: {'path-1'},
        ),
      );

      directSelectionTool = DirectSelectionTool(
        document: document,
        viewportController: viewportController,
        eventRecorder: eventRecorder,
        pathRenderer: pathRenderer,
      );
    });

    tearDown(() {
      viewportController.dispose();
    });

    group('Tool Lifecycle', () {
      test('should have correct tool ID', () {
        expect(directSelectionTool.toolId, equals('direct_selection'));
      });

      test('should initialize with precise cursor', () {
        expect(directSelectionTool.cursor, equals(SystemMouseCursors.precise));
      });
    });

    group('Anchor Dragging', () {
      setUp(() {
        directSelectionTool.onActivate();
        eventRecorder.clear();
      });

      test('should emit ModifyAnchorEvent on drag move', () {
        final downEvent = PointerDownEvent(
          position: const Offset(100, 200),
        );
        directSelectionTool.onPointerDown(downEvent);

        eventRecorder.clear();

        final moveEvent = PointerMoveEvent(
          position: const Offset(110, 210),
        );
        directSelectionTool.onPointerMove(moveEvent);

        expect(eventRecorder.recordedEvents.length, greaterThan(0));

        final modifyEvent =
            eventRecorder.recordedEvents.first as ModifyAnchorEvent;
        expect(modifyEvent.pathId, equals('path-1'));
        expect(modifyEvent.anchorIndex, equals(0));
        expect(modifyEvent.position, isNotNull);
      });

      test('should call flush on drag finish', () {
        final downEvent = PointerDownEvent(
          position: const Offset(100, 200),
        );
        directSelectionTool.onPointerDown(downEvent);

        final initialFlushCount = eventRecorder.flushCallCount;

        final upEvent = PointerUpEvent(
          position: const Offset(110, 210),
        );
        directSelectionTool.onPointerUp(upEvent);

        expect(eventRecorder.flushCallCount, equals(initialFlushCount + 1));
      });
    });

    group('Handle Dragging - Smooth Anchor', () {
      setUp(() {
        directSelectionTool.onActivate();
        eventRecorder.clear();
      });

      test('should mirror handleIn when dragging handleOut', () {
        final downEvent = PointerDownEvent(
          position: const Offset(250, 200), // HandleOut position
        );
        directSelectionTool.onPointerDown(downEvent);

        eventRecorder.clear();

        final moveEvent = PointerMoveEvent(
          position: const Offset(260, 220),
        );
        directSelectionTool.onPointerMove(moveEvent);

        expect(eventRecorder.recordedEvents.length, greaterThan(0));

        final modifyEvent =
            eventRecorder.recordedEvents.first as ModifyAnchorEvent;
        expect(modifyEvent.pathId, equals('path-1'));
        expect(modifyEvent.anchorIndex, equals(1));

        expect(modifyEvent.handleOut, isNotNull);
        expect(modifyEvent.handleIn, isNotNull);

        // Handles should be mirrored
        expect(modifyEvent.handleIn!.x, closeTo(-modifyEvent.handleOut!.x, 0.1));
        expect(modifyEvent.handleIn!.y, closeTo(-modifyEvent.handleOut!.y, 0.1));
      });
    });
  });
}
