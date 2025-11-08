import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/models/anchor_point.dart';
import 'package:wiretuner/domain/models/path.dart' as domain;
import 'package:wiretuner/domain/models/segment.dart';
import 'package:wiretuner/presentation/canvas/painter/document_painter.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';

void main() {
  group('DocumentPainter', () {
    late ViewportController viewportController;

    setUp(() {
      viewportController = ViewportController();
    });

    tearDown(() {
      viewportController.dispose();
    });

    testWidgets('renders with RepaintBoundary', (WidgetTester tester) async {
      // Arrange: Create a simple path
      final paths = [
        domain.Path.line(
          start: const Point(x: 0, y: 0),
          end: const Point(x: 100, y: 100),
        ),
      ];

      final painter = DocumentPainter(
        paths: paths,
        viewportController: viewportController,
      );

      // Act: Pump the widget tree with RepaintBoundary
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              key: const ValueKey('canvas_repaint_boundary'),
              child: CustomPaint(
                painter: painter,
                size: const Size(800, 600),
              ),
            ),
          ),
        ),
      );

      // Assert: Verify RepaintBoundary exists in render tree
      final repaintBoundaryFinder = find.byKey(
        const ValueKey('canvas_repaint_boundary'),
      );
      expect(repaintBoundaryFinder, findsOneWidget);

      final renderObject =
          tester.renderObject(repaintBoundaryFinder) as RenderRepaintBoundary;
      expect(renderObject, isA<RenderRepaintBoundary>());
    });

    testWidgets('renders empty document without error',
        (WidgetTester tester) async {
      // Arrange: Empty path list
      final painter = DocumentPainter(
        paths: const [],
        viewportController: viewportController,
      );

      // Act: Pump widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter: painter,
              size: const Size(800, 600),
            ),
          ),
        ),
      );

      // Assert: No exceptions thrown
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders single line path', (WidgetTester tester) async {
      // Arrange: Simple line
      final paths = [
        domain.Path.line(
          start: const Point(x: 0, y: 0),
          end: const Point(x: 100, y: 100),
        ),
      ];

      final painter = DocumentPainter(
        paths: paths,
        viewportController: viewportController,
      );

      // Act: Pump widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter: painter,
              size: const Size(800, 600),
            ),
          ),
        ),
      );

      // Assert: No exceptions thrown
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders bezier curve path', (WidgetTester tester) async {
      // Arrange: Bezier curve with handles
      final paths = [
        domain.Path(
          anchors: const [
            AnchorPoint(
              position: Point(x: 0, y: 0),
              handleOut: Point(x: 50, y: 0),
            ),
            AnchorPoint(
              position: Point(x: 100, y: 100),
              handleIn: Point(x: -50, y: 0),
            ),
          ],
          segments: [
            Segment.bezier(startIndex: 0, endIndex: 1),
          ],
        ),
      ];

      final painter = DocumentPainter(
        paths: paths,
        viewportController: viewportController,
      );

      // Act: Pump widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter: painter,
              size: const Size(800, 600),
            ),
          ),
        ),
      );

      // Assert: No exceptions thrown
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders closed path', (WidgetTester tester) async {
      // Arrange: Closed triangular path
      final paths = [
        domain.Path(
          anchors: [
            AnchorPoint.corner(const Point(x: 0, y: 0)),
            AnchorPoint.corner(const Point(x: 100, y: 0)),
            AnchorPoint.corner(const Point(x: 50, y: 86.6)),
          ],
          segments: [
            Segment.line(startIndex: 0, endIndex: 1),
            Segment.line(startIndex: 1, endIndex: 2),
          ],
          closed: true,
        ),
      ];

      final painter = DocumentPainter(
        paths: paths,
        viewportController: viewportController,
      );

      // Act: Pump widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter: painter,
              size: const Size(800, 600),
            ),
          ),
        ),
      );

      // Assert: No exceptions thrown
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders multiple paths', (WidgetTester tester) async {
      // Arrange: Multiple paths
      final paths = [
        domain.Path.line(
          start: const Point(x: 0, y: 0),
          end: const Point(x: 100, y: 100),
        ),
        domain.Path.line(
          start: const Point(x: 100, y: 0),
          end: const Point(x: 0, y: 100),
        ),
        domain.Path.line(
          start: const Point(x: 50, y: 0),
          end: const Point(x: 50, y: 100),
        ),
      ];

      final painter = DocumentPainter(
        paths: paths,
        viewportController: viewportController,
      );

      // Act: Pump widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter: painter,
              size: const Size(800, 600),
            ),
          ),
        ),
      );

      // Assert: No exceptions thrown
      expect(tester.takeException(), isNull);
    });

    test('shouldRepaint returns true when paths change', () {
      // Arrange
      final paths1 = [
        domain.Path.line(
          start: const Point(x: 0, y: 0),
          end: const Point(x: 100, y: 100),
        ),
      ];
      final paths2 = [
        domain.Path.line(
          start: const Point(x: 0, y: 0),
          end: const Point(x: 200, y: 200),
        ),
      ];

      final painter1 = DocumentPainter(
        paths: paths1,
        viewportController: viewportController,
      );
      final painter2 = DocumentPainter(
        paths: paths2,
        viewportController: viewportController,
      );

      // Act
      final shouldRepaint = painter2.shouldRepaint(painter1);

      // Assert
      expect(shouldRepaint, isTrue);
    });

    test('shouldRepaint returns false when paths unchanged', () {
      // Arrange: Same paths reference
      final paths = [
        domain.Path.line(
          start: const Point(x: 0, y: 0),
          end: const Point(x: 100, y: 100),
        ),
      ];

      final painter1 = DocumentPainter(
        paths: paths,
        viewportController: viewportController,
      );
      final painter2 = DocumentPainter(
        paths: paths,
        viewportController: viewportController,
      );

      // Act
      final shouldRepaint = painter2.shouldRepaint(painter1);

      // Assert
      expect(shouldRepaint, isFalse);
    });

    test('shouldRepaint returns true when viewport controller changes', () {
      // Arrange
      final paths = [
        domain.Path.line(
          start: const Point(x: 0, y: 0),
          end: const Point(x: 100, y: 100),
        ),
      ];

      final controller1 = ViewportController();
      final controller2 = ViewportController();

      final painter1 = DocumentPainter(
        paths: paths,
        viewportController: controller1,
      );
      final painter2 = DocumentPainter(
        paths: paths,
        viewportController: controller2,
      );

      // Act
      final shouldRepaint = painter2.shouldRepaint(painter1);

      // Assert
      expect(shouldRepaint, isTrue);

      // Cleanup
      controller1.dispose();
      controller2.dispose();
    });

    test('shouldRepaint returns true when stroke width changes', () {
      // Arrange
      final paths = [
        domain.Path.line(
          start: const Point(x: 0, y: 0),
          end: const Point(x: 100, y: 100),
        ),
      ];

      final painter1 = DocumentPainter(
        paths: paths,
        viewportController: viewportController,
        strokeWidth: 1.0,
      );
      final painter2 = DocumentPainter(
        paths: paths,
        viewportController: viewportController,
        strokeWidth: 2.0,
      );

      // Act
      final shouldRepaint = painter2.shouldRepaint(painter1);

      // Assert
      expect(shouldRepaint, isTrue);
    });

    test('shouldRepaint returns true when stroke color changes', () {
      // Arrange
      final paths = [
        domain.Path.line(
          start: const Point(x: 0, y: 0),
          end: const Point(x: 100, y: 100),
        ),
      ];

      final painter1 = DocumentPainter(
        paths: paths,
        viewportController: viewportController,
        strokeColor: Colors.black,
      );
      final painter2 = DocumentPainter(
        paths: paths,
        viewportController: viewportController,
        strokeColor: Colors.red,
      );

      // Act
      final shouldRepaint = painter2.shouldRepaint(painter1);

      // Assert
      expect(shouldRepaint, isTrue);
    });

    testWidgets('repaints when viewport changes',
        (WidgetTester tester) async {
      // Arrange
      final paths = [
        domain.Path.line(
          start: const Point(x: 0, y: 0),
          end: const Point(x: 100, y: 100),
        ),
      ];

      final painter = DocumentPainter(
        paths: paths,
        viewportController: viewportController,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter: painter,
              size: const Size(800, 600),
            ),
          ),
        ),
      );

      // Act: Change viewport (pan)
      viewportController.pan(const Offset(50, 50));
      await tester.pump();

      // Assert: Widget rebuilds without error
      expect(tester.takeException(), isNull);
    });

    testWidgets('repaints when viewport zooms', (WidgetTester tester) async {
      // Arrange
      final paths = [
        domain.Path.line(
          start: const Point(x: 0, y: 0),
          end: const Point(x: 100, y: 100),
        ),
      ];

      final painter = DocumentPainter(
        paths: paths,
        viewportController: viewportController,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter: painter,
              size: const Size(800, 600),
            ),
          ),
        ),
      );

      // Act: Change viewport (zoom)
      viewportController.zoom(
        1.5,
        focalPoint: const Offset(400, 300),
      );
      await tester.pump();

      // Assert: Widget rebuilds without error
      expect(tester.takeException(), isNull);
    });
  });

  group('ViewportController', () {
    test('initializes with default values', () {
      final controller = ViewportController();

      expect(controller.panOffset, Offset.zero);
      expect(controller.zoomLevel, 1.0);

      controller.dispose();
    });

    test('initializes with custom values', () {
      final controller = ViewportController(
        initialPan: const Offset(100, 50),
        initialZoom: 2.0,
      );

      expect(controller.panOffset, const Offset(100, 50));
      expect(controller.zoomLevel, 2.0);

      controller.dispose();
    });

    test('clamps initial zoom to valid range', () {
      final controller1 = ViewportController(initialZoom: 0.01);
      expect(
        controller1.zoomLevel,
        ViewportController.minZoom,
      ); // Clamped to 0.05

      final controller2 = ViewportController(initialZoom: 10.0);
      expect(controller2.zoomLevel, ViewportController.maxZoom); // Clamped to 8.0

      controller1.dispose();
      controller2.dispose();
    });

    test('pan updates offset', () {
      final controller = ViewportController();
      controller.pan(const Offset(50, 30));

      expect(controller.panOffset, const Offset(50, 30));

      controller.pan(const Offset(10, 20));
      expect(controller.panOffset, const Offset(60, 50));

      controller.dispose();
    });

    test('setPan sets absolute offset', () {
      final controller = ViewportController();
      controller.setPan(const Offset(100, 200));

      expect(controller.panOffset, const Offset(100, 200));

      controller.dispose();
    });

    test('setZoom clamps to valid range', () {
      final controller = ViewportController();

      controller.setZoom(0.01);
      expect(controller.zoomLevel, ViewportController.minZoom);

      controller.setZoom(10.0);
      expect(controller.zoomLevel, ViewportController.maxZoom);

      controller.setZoom(2.0);
      expect(controller.zoomLevel, 2.0);

      controller.dispose();
    });

    test('zoom clamps to valid range', () {
      final controller = ViewportController(initialZoom: 1.0);

      // Zoom way in (should clamp to max)
      controller.zoom(100.0, focalPoint: Offset.zero);
      expect(controller.zoomLevel, ViewportController.maxZoom);

      // Reset
      controller.setZoom(1.0);

      // Zoom way out (should clamp to min)
      controller.zoom(0.001, focalPoint: Offset.zero);
      expect(controller.zoomLevel, ViewportController.minZoom);

      controller.dispose();
    });

    test('reset returns to default state', () {
      final controller = ViewportController();
      controller.pan(const Offset(100, 200));
      controller.setZoom(2.0);

      controller.reset();

      expect(controller.panOffset, Offset.zero);
      expect(controller.zoomLevel, 1.0);

      controller.dispose();
    });

    test('worldToScreen converts coordinates correctly', () {
      final controller = ViewportController(
        initialPan: const Offset(100, 50),
        initialZoom: 2.0,
      );

      final screenPoint = controller.worldToScreen(const Point(x: 10, y: 20));

      // Expected: (10 * 2.0 + 100, 20 * 2.0 + 50) = (120, 90)
      expect(screenPoint.dx, closeTo(120, 0.001));
      expect(screenPoint.dy, closeTo(90, 0.001));

      controller.dispose();
    });

    test('screenToWorld converts coordinates correctly', () {
      final controller = ViewportController(
        initialPan: const Offset(100, 50),
        initialZoom: 2.0,
      );

      final worldPoint = controller.screenToWorld(const Offset(120, 90));

      // Expected: ((120 - 100) / 2.0, (90 - 50) / 2.0) = (10, 20)
      expect(worldPoint.x, closeTo(10, 0.001));
      expect(worldPoint.y, closeTo(20, 0.001));

      controller.dispose();
    });

    test('worldToScreen and screenToWorld are inverses', () {
      final controller = ViewportController(
        initialPan: const Offset(123, 456),
        initialZoom: 1.5,
      );

      const original = Point(x: 100, y: 200);
      final screen = controller.worldToScreen(original);
      final roundTrip = controller.screenToWorld(screen);

      expect(roundTrip.x, closeTo(original.x, 0.001));
      expect(roundTrip.y, closeTo(original.y, 0.001));

      controller.dispose();
    });

    test('screenDistanceToWorld converts distance correctly', () {
      final controller = ViewportController(initialZoom: 2.0);

      final worldDist = controller.screenDistanceToWorld(100);
      expect(worldDist, closeTo(50, 0.001));

      controller.dispose();
    });

    test('worldDistanceToScreen converts distance correctly', () {
      final controller = ViewportController(initialZoom: 2.0);

      final screenDist = controller.worldDistanceToScreen(50);
      expect(screenDist, closeTo(100, 0.001));

      controller.dispose();
    });

    test('notifies listeners on pan', () {
      final controller = ViewportController();
      var notified = false;
      controller.addListener(() => notified = true);

      controller.pan(const Offset(10, 10));

      expect(notified, isTrue);

      controller.dispose();
    });

    test('notifies listeners on zoom', () {
      final controller = ViewportController();
      var notified = false;
      controller.addListener(() => notified = true);

      controller.zoom(1.5, focalPoint: Offset.zero);

      expect(notified, isTrue);

      controller.dispose();
    });

    test('notifies listeners on reset', () {
      final controller = ViewportController();
      controller.pan(const Offset(100, 100));
      var notified = false;
      controller.addListener(() => notified = true);

      controller.reset();

      expect(notified, isTrue);

      controller.dispose();
    });
  });
}
