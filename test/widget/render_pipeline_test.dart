import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/models/anchor_point.dart';
import 'package:wiretuner/domain/models/path.dart' as domain;
import 'package:wiretuner/domain/models/segment.dart';
import 'package:wiretuner/domain/models/shape.dart';
import 'package:wiretuner/presentation/canvas/paint_styles.dart';
import 'package:wiretuner/presentation/canvas/painter/path_renderer.dart';
import 'package:wiretuner/presentation/canvas/render_pipeline.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';

void main() {
  group('PaintStyle', () {
    test('creates stroke style with default values', () {
      const style = PaintStyle.stroke();

      expect(style.type, PaintStyleType.stroke);
      expect(style.color, Colors.black);
      expect(style.strokeWidth, 1.0);
      expect(style.strokeCap, StrokeCap.round);
      expect(style.strokeJoin, StrokeJoin.round);
      expect(style.opacity, 1.0);
    });

    test('creates fill style with custom color', () {
      const style = PaintStyle.fill(color: Colors.blue, opacity: 0.5);

      expect(style.type, PaintStyleType.fill);
      expect(style.color, Colors.blue);
      expect(style.opacity, 0.5);
    });

    test('creates stroke-and-fill style', () {
      const style = PaintStyle.strokeAndFill(
        strokeColor: Colors.black,
        fillColor: Colors.white,
        strokeWidth: 2.0,
      );

      expect(style.type, PaintStyleType.strokeAndFill);
      expect(style.strokeWidth, 2.0);
    });

    test('toPaint returns stroke paint for stroke style', () {
      const style = PaintStyle.stroke(
        color: Colors.red,
        strokeWidth: 3.0,
        cap: StrokeCap.square,
      );

      final paint = style.toPaint();

      expect(paint.style, PaintingStyle.stroke);
      expect(paint.color.value, Colors.red.value);
      expect(paint.strokeWidth, 3.0);
      expect(paint.strokeCap, StrokeCap.square);
    });

    test('toPaint returns fill paint for fill style', () {
      const style = PaintStyle.fill(color: Colors.green);

      final paint = style.toPaint();

      expect(paint.style, PaintingStyle.fill);
      expect(paint.color.value, Colors.green.value);
    });

    test('toPaint applies opacity to color', () {
      const style = PaintStyle.stroke(
        color: Colors.blue,
        opacity: 0.5,
      );

      final paint = style.toPaint();

      expect(paint.color.opacity, closeTo(0.5, 0.01));
    });

    test('copyWith creates modified copy', () {
      const original = PaintStyle.stroke(color: Colors.black);
      final copy = original.copyWith(color: Colors.red, strokeWidth: 5.0);

      expect(copy.color, Colors.red);
      expect(copy.strokeWidth, 5.0);
      expect(copy.strokeCap, original.strokeCap); // Unchanged
    });

    test('equality works correctly', () {
      const style1 = PaintStyle.stroke(color: Colors.black, strokeWidth: 2.0);
      const style2 = PaintStyle.stroke(color: Colors.black, strokeWidth: 2.0);
      const style3 = PaintStyle.stroke(color: Colors.red, strokeWidth: 2.0);

      expect(style1, equals(style2));
      expect(style1, isNot(equals(style3)));
    });
  });

  group('RenderPipelineConfig', () {
    test('creates with default values', () {
      const config = RenderPipelineConfig();

      expect(config.enablePathCaching, isTrue);
      expect(config.enableGPUCaching, isFalse);
      expect(config.enableViewportCulling, isFalse);
      expect(config.cullMargin, 100.0);
      expect(config.lodThreshold, 0.25);
      expect(config.minObjectScreenSize, 2.0);
    });

    test('copyWith creates modified copy', () {
      const original = RenderPipelineConfig();
      final copy = original.copyWith(enableViewportCulling: true);

      expect(copy.enableViewportCulling, isTrue);
      expect(copy.enablePathCaching, original.enablePathCaching); // Unchanged
    });
  });

  group('RenderPipeline', () {
    late PathRenderer pathRenderer;
    late ViewportController viewportController;

    setUp(() {
      pathRenderer = PathRenderer();
      viewportController = ViewportController();
    });

    tearDown(() {
      viewportController.dispose();
    });

    test('creates with default config', () {
      final pipeline = RenderPipeline(pathRenderer: pathRenderer);

      expect(pipeline.config.enablePathCaching, isTrue);
    });

    test('creates with custom config', () {
      final pipeline = RenderPipeline(
        pathRenderer: pathRenderer,
        config: const RenderPipelineConfig(
          enableViewportCulling: true,
          enableGPUCaching: true,
        ),
      );

      expect(pipeline.config.enableViewportCulling, isTrue);
      expect(pipeline.config.enableGPUCaching, isTrue);
    });

    testWidgets('renders paths without error', (WidgetTester tester) async {
      final pipeline = RenderPipeline(pathRenderer: pathRenderer);

      final paths = [
        RenderablePath(
          id: 'path-1',
          path: domain.Path.line(
            start: const Point(x: 0, y: 0),
            end: const Point(x: 100, y: 100),
          ),
          style: const PaintStyle.stroke(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter: _TestPainter(
                pipeline: pipeline,
                paths: paths,
                viewportController: viewportController,
              ),
              size: const Size(800, 600),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders shapes without error', (WidgetTester tester) async {
      final pipeline = RenderPipeline(pathRenderer: pathRenderer);

      final shapes = [
        RenderableShape(
          id: 'rect-1',
          shape: Shape.rectangle(
            center: const Point(x: 50, y: 25),
            width: 100,
            height: 50,
          ),
          style: const PaintStyle.fill(color: Colors.blue),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter: _TestPainter(
                pipeline: pipeline,
                shapes: shapes,
                viewportController: viewportController,
              ),
              size: const Size(800, 600),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('collects metrics after render', (WidgetTester tester) async {
      final pipeline = RenderPipeline(pathRenderer: pathRenderer);

      final paths = [
        RenderablePath(
          id: 'path-1',
          path: domain.Path.line(
            start: const Point(x: 0, y: 0),
            end: const Point(x: 100, y: 100),
          ),
          style: const PaintStyle.stroke(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter: _TestPainter(
                pipeline: pipeline,
                paths: paths,
                viewportController: viewportController,
              ),
              size: const Size(800, 600),
            ),
          ),
        ),
      );

      expect(pipeline.lastMetrics, isNotNull);
      expect(pipeline.lastMetrics!.objectsRendered, 1);
      expect(pipeline.lastMetrics!.frameTimeMs, greaterThan(0));
    });

    testWidgets('renders stroke-only paths', (WidgetTester tester) async {
      final pipeline = RenderPipeline(pathRenderer: pathRenderer);

      final paths = [
        RenderablePath(
          id: 'stroke-path',
          path: domain.Path(
            anchors: [
              AnchorPoint.corner(const Point(x: 0, y: 0)),
              AnchorPoint.corner(const Point(x: 100, y: 0)),
              AnchorPoint.corner(const Point(x: 100, y: 100)),
            ],
            segments: [
              Segment.line(startIndex: 0, endIndex: 1),
              Segment.line(startIndex: 1, endIndex: 2),
            ],
          ),
          style: const PaintStyle.stroke(
            color: Colors.red,
            strokeWidth: 2.0,
          ),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter: _TestPainter(
                pipeline: pipeline,
                paths: paths,
                viewportController: viewportController,
              ),
              size: const Size(800, 600),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(pipeline.lastMetrics!.objectsRendered, 1);
    });

    testWidgets('renders fill-only paths', (WidgetTester tester) async {
      final pipeline = RenderPipeline(pathRenderer: pathRenderer);

      final paths = [
        RenderablePath(
          id: 'fill-path',
          path: domain.Path(
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
          style: const PaintStyle.fill(color: Colors.blue),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter: _TestPainter(
                pipeline: pipeline,
                paths: paths,
                viewportController: viewportController,
              ),
              size: const Size(800, 600),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(pipeline.lastMetrics!.objectsRendered, 1);
    });

    testWidgets('renders stroke-and-fill paths', (WidgetTester tester) async {
      final pipeline = RenderPipeline(pathRenderer: pathRenderer);

      final paths = [
        RenderablePath(
          id: 'both-path',
          path: domain.Path(
            anchors: [
              AnchorPoint.corner(const Point(x: 0, y: 0)),
              AnchorPoint.corner(const Point(x: 100, y: 0)),
              AnchorPoint.corner(const Point(x: 100, y: 100)),
              AnchorPoint.corner(const Point(x: 0, y: 100)),
            ],
            segments: [
              Segment.line(startIndex: 0, endIndex: 1),
              Segment.line(startIndex: 1, endIndex: 2),
              Segment.line(startIndex: 2, endIndex: 3),
            ],
            closed: true,
          ),
          style: const PaintStyle.strokeAndFill(
            strokeColor: Colors.black,
            fillColor: Colors.yellow,
            strokeWidth: 1.5,
          ),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter: _TestPainter(
                pipeline: pipeline,
                paths: paths,
                viewportController: viewportController,
              ),
              size: const Size(800, 600),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(pipeline.lastMetrics!.objectsRendered, 1);
    });

    testWidgets('renders multiple objects', (WidgetTester tester) async {
      final pipeline = RenderPipeline(pathRenderer: pathRenderer);

      final paths = List.generate(
        10,
        (i) => RenderablePath(
          id: 'path-$i',
          path: domain.Path.line(
            start: Point(x: i * 10.0, y: 0),
            end: Point(x: i * 10.0, y: 100),
          ),
          style: const PaintStyle.stroke(),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter: _TestPainter(
                pipeline: pipeline,
                paths: paths,
                viewportController: viewportController,
              ),
              size: const Size(800, 600),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(pipeline.lastMetrics!.objectsRendered, 10);
    });

    test('invalidateObject clears specific cache entry', () {
      final pipeline = RenderPipeline(pathRenderer: pathRenderer);

      // Pre-populate cache
      pathRenderer.getOrCreatePathFromDomain(
        objectId: 'test-path',
        domainPath: domain.Path.line(
          start: const Point(x: 0, y: 0),
          end: const Point(x: 100, y: 100),
        ),
        currentZoom: 1.0,
      );

      expect(pathRenderer.cacheSize, 1);

      pipeline.invalidateObject('test-path');

      expect(pathRenderer.cacheSize, 0);
    });

    test('invalidateAll clears all cache entries', () {
      final pipeline = RenderPipeline(pathRenderer: pathRenderer);

      // Pre-populate cache with multiple entries
      for (var i = 0; i < 5; i++) {
        pathRenderer.getOrCreatePathFromDomain(
          objectId: 'path-$i',
          domainPath: domain.Path.line(
            start: const Point(x: 0, y: 0),
            end: Point(x: i * 10.0, y: 100),
          ),
          currentZoom: 1.0,
        );
      }

      expect(pathRenderer.cacheSize, 5);

      pipeline.invalidateAll();

      expect(pathRenderer.cacheSize, 0);
    });
  });

  group('RenderMetrics', () {
    test('calculates FPS correctly', () {
      const metrics = RenderMetrics(
        frameTimeMs: 16.67, // ~60 FPS
        objectsRendered: 10,
        objectsCulled: 5,
        cacheSize: 15,
      );

      expect(metrics.fps, closeTo(60.0, 0.1));
    });

    test('toString formats correctly', () {
      const metrics = RenderMetrics(
        frameTimeMs: 20.0,
        objectsRendered: 5,
        objectsCulled: 3,
        cacheSize: 8,
      );

      final str = metrics.toString();

      expect(str, contains('20.00ms'));
      expect(str, contains('50.0')); // FPS
      expect(str, contains('rendered: 5'));
      expect(str, contains('culled: 3'));
      expect(str, contains('cacheSize: 8'));
    });
  });

  group('Golden Tests', () {
    testWidgets('renders stroke path with correct visual output',
        (WidgetTester tester) async {
      final pipeline = RenderPipeline(pathRenderer: PathRenderer());

      final paths = [
        RenderablePath(
          id: 'red-stroke',
          path: domain.Path(
            anchors: [
              AnchorPoint.corner(const Point(x: 10, y: 10)),
              AnchorPoint.corner(const Point(x: 90, y: 10)),
              AnchorPoint.corner(const Point(x: 90, y: 90)),
              AnchorPoint.corner(const Point(x: 10, y: 90)),
            ],
            segments: [
              Segment.line(startIndex: 0, endIndex: 1),
              Segment.line(startIndex: 1, endIndex: 2),
              Segment.line(startIndex: 2, endIndex: 3),
            ],
            closed: true,
          ),
          style: const PaintStyle.stroke(
            color: Colors.red,
            strokeWidth: 2.0,
          ),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              width: 100,
              height: 100,
              color: Colors.white,
              child: CustomPaint(
                painter: _TestPainter(
                  pipeline: pipeline,
                  paths: paths,
                  viewportController: ViewportController(),
                ),
                size: const Size(100, 100),
              ),
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(Container).first,
        matchesGoldenFile('goldens/stroke_red_square.png'),
      );
    });

    testWidgets('renders fill path with correct visual output',
        (WidgetTester tester) async {
      final pipeline = RenderPipeline(pathRenderer: PathRenderer());

      final paths = [
        RenderablePath(
          id: 'blue-fill',
          path: domain.Path(
            anchors: [
              AnchorPoint.corner(const Point(x: 20, y: 20)),
              AnchorPoint.corner(const Point(x: 80, y: 20)),
              AnchorPoint.corner(const Point(x: 50, y: 80)),
            ],
            segments: [
              Segment.line(startIndex: 0, endIndex: 1),
              Segment.line(startIndex: 1, endIndex: 2),
            ],
            closed: true,
          ),
          style: const PaintStyle.fill(color: Colors.blue),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              width: 100,
              height: 100,
              color: Colors.white,
              child: CustomPaint(
                painter: _TestPainter(
                  pipeline: pipeline,
                  paths: paths,
                  viewportController: ViewportController(),
                ),
                size: const Size(100, 100),
              ),
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(Container).first,
        matchesGoldenFile('goldens/fill_blue_triangle.png'),
      );
    });

    testWidgets('renders stroke-and-fill path with correct visual output',
        (WidgetTester tester) async {
      final pipeline = RenderPipeline(pathRenderer: PathRenderer());

      final paths = [
        RenderablePath(
          id: 'stroke-fill-circle',
          path: Shape.ellipse(
            center: const Point(x: 50, y: 50),
            width: 60,
            height: 60,
          ).toPath(),
          style: const PaintStyle.strokeAndFill(
            strokeColor: Colors.black,
            fillColor: Colors.yellow,
            strokeWidth: 3.0,
          ),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              width: 100,
              height: 100,
              color: Colors.white,
              child: CustomPaint(
                painter: _TestPainter(
                  pipeline: pipeline,
                  paths: paths,
                  viewportController: ViewportController(),
                ),
                size: const Size(100, 100),
              ),
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(Container).first,
        matchesGoldenFile('goldens/stroke_fill_yellow_circle.png'),
      );
    });

    testWidgets('renders transformed paths with correct visual output',
        (WidgetTester tester) async {
      final pipeline = RenderPipeline(pathRenderer: PathRenderer());
      final viewportController = ViewportController();

      // Zoom in 2x
      viewportController.zoom(2.0, focalPoint: const Offset(50, 50));

      final paths = [
        RenderablePath(
          id: 'transformed-line',
          path: domain.Path.line(
            start: const Point(x: 25, y: 25),
            end: const Point(x: 75, y: 75),
          ),
          style: const PaintStyle.stroke(
            color: Colors.green,
            strokeWidth: 4.0,
          ),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              width: 100,
              height: 100,
              color: Colors.white,
              child: CustomPaint(
                painter: _TestPainter(
                  pipeline: pipeline,
                  paths: paths,
                  viewportController: viewportController,
                ),
                size: const Size(100, 100),
              ),
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(Container).first,
        matchesGoldenFile('goldens/transformed_green_line.png'),
      );

      viewportController.dispose();
    });
  });
}

/// Test painter that uses RenderPipeline for rendering.
class _TestPainter extends CustomPainter {
  _TestPainter({
    required this.pipeline,
    required this.viewportController,
    this.paths = const [],
    this.shapes = const [],
  }) : super(repaint: viewportController);

  final RenderPipeline pipeline;
  final ViewportController viewportController;
  final List<RenderablePath> paths;
  final List<RenderableShape> shapes;

  @override
  void paint(Canvas canvas, Size size) {
    pipeline.render(
      canvas: canvas,
      size: size,
      viewportController: viewportController,
      paths: paths,
      shapes: shapes,
    );
  }

  @override
  bool shouldRepaint(covariant _TestPainter oldDelegate) {
    return paths != oldDelegate.paths || shapes != oldDelegate.shapes;
  }
}
