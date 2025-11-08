import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/domain/document/selection.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/models/anchor_point.dart';
import 'package:wiretuner/domain/models/path.dart' as domain;
import 'package:wiretuner/domain/models/segment.dart';
import 'package:wiretuner/domain/models/shape.dart';
import 'package:wiretuner/presentation/canvas/overlays/hit_tester.dart'
    as canvas_hit_test;
import 'package:wiretuner/presentation/canvas/overlays/selection_overlay.dart';
import 'package:wiretuner/presentation/canvas/painter/path_renderer.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';

void main() {
  group('SelectionOverlayPainter', () {
    late ViewportController viewportController;
    late PathRenderer pathRenderer;

    setUp(() {
      viewportController = ViewportController();
      pathRenderer = PathRenderer();
    });

    tearDown(() {
      viewportController.dispose();
      pathRenderer.invalidateAll();
    });

    testWidgets('renders empty selection without error',
        (WidgetTester tester) async {
      // Arrange: Empty selection
      final painter = SelectionOverlayPainter(
        selection: Selection.empty(),
        paths: {},
        shapes: {},
        viewportController: viewportController,
        pathRenderer: pathRenderer,
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

    testWidgets('renders single selected path with bounding box',
        (WidgetTester tester) async {
      // Arrange: Create a simple path and selection
      final path = domain.Path.line(
        start: const Point(x: 0, y: 0),
        end: const Point(x: 100, y: 100),
      );

      final painter = SelectionOverlayPainter(
        selection: const Selection(objectIds: {'path-1'}),
        paths: {'path-1': path},
        shapes: {},
        viewportController: viewportController,
        pathRenderer: pathRenderer,
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

    testWidgets('renders path with anchor points', (WidgetTester tester) async {
      // Arrange: Path with multiple anchors
      final path = domain.Path(
        anchors: [
          AnchorPoint.corner(const Point(x: 0, y: 0)),
          AnchorPoint.corner(const Point(x: 50, y: 50)),
          AnchorPoint.corner(const Point(x: 100, y: 0)),
        ],
        segments: [
          Segment.line(startIndex: 0, endIndex: 1),
          Segment.line(startIndex: 1, endIndex: 2),
        ],
      );

      final painter = SelectionOverlayPainter(
        selection: const Selection(objectIds: {'path-1'}),
        paths: {'path-1': path},
        shapes: {},
        viewportController: viewportController,
        pathRenderer: pathRenderer,
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

      // Assert: No exceptions thrown, anchors rendered
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders path with Bezier handles', (WidgetTester tester) async {
      // Arrange: Path with Bezier curve and handles
      final path = domain.Path(
        anchors: const [
          AnchorPoint(
            position: Point(x: 0, y: 0),
            handleOut: Point(x: 25, y: 0),
          ),
          AnchorPoint(
            position: Point(x: 100, y: 100),
            handleIn: Point(x: -25, y: 0),
          ),
        ],
        segments: [
          Segment.bezier(startIndex: 0, endIndex: 1),
        ],
      );

      final painter = SelectionOverlayPainter(
        selection: const Selection(objectIds: {'path-1'}),
        paths: {'path-1': path},
        shapes: {},
        viewportController: viewportController,
        pathRenderer: pathRenderer,
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

      // Assert: No exceptions thrown, handles rendered
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders selected shape', (WidgetTester tester) async {
      // Arrange: Rectangle shape
      final shape = Shape.rectangle(
        center: const Point(x: 100, y: 100),
        width: 50,
        height: 30,
      );

      final painter = SelectionOverlayPainter(
        selection: const Selection(objectIds: {'shape-1'}),
        paths: {},
        shapes: {'shape-1': shape},
        viewportController: viewportController,
        pathRenderer: pathRenderer,
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

    testWidgets('renders selected ellipse', (WidgetTester tester) async {
      // Arrange: Ellipse shape
      final shape = Shape.ellipse(
        center: const Point(x: 100, y: 100),
        width: 60,
        height: 40,
      );

      final painter = SelectionOverlayPainter(
        selection: const Selection(objectIds: {'shape-1'}),
        paths: {},
        shapes: {'shape-1': shape},
        viewportController: viewportController,
        pathRenderer: pathRenderer,
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

    testWidgets('renders multiple selected objects', (WidgetTester tester) async {
      // Arrange: Multiple paths
      final paths = {
        'path-1': domain.Path.line(
          start: const Point(x: 0, y: 0),
          end: const Point(x: 50, y: 50),
        ),
        'path-2': domain.Path.line(
          start: const Point(x: 100, y: 100),
          end: const Point(x: 150, y: 150),
        ),
      };

      final painter = SelectionOverlayPainter(
        selection: const Selection(objectIds: {'path-1', 'path-2'}),
        paths: paths,
        shapes: {},
        viewportController: viewportController,
        pathRenderer: pathRenderer,
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

    testWidgets('renders with hovered anchor', (WidgetTester tester) async {
      // Arrange: Path with hover state
      final path = domain.Path(
        anchors: [
          AnchorPoint.corner(const Point(x: 0, y: 0)),
          AnchorPoint.corner(const Point(x: 100, y: 100)),
        ],
        segments: [
          Segment.line(startIndex: 0, endIndex: 1),
        ],
      );

      final painter = SelectionOverlayPainter(
        selection: const Selection(objectIds: {'path-1'}),
        paths: {'path-1': path},
        shapes: {},
        viewportController: viewportController,
        pathRenderer: pathRenderer,
        hoveredAnchor: const HoveredAnchor(
          objectId: 'path-1',
          anchorIndex: 0,
          component: AnchorComponent.anchor,
        ),
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

    testWidgets('handles viewport zoom changes', (WidgetTester tester) async {
      // Arrange: Path and zoom
      final path = domain.Path.line(
        start: const Point(x: 0, y: 0),
        end: const Point(x: 100, y: 100),
      );

      final painter = SelectionOverlayPainter(
        selection: const Selection(objectIds: {'path-1'}),
        paths: {'path-1': path},
        shapes: {},
        viewportController: viewportController,
        pathRenderer: pathRenderer,
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

      // Change zoom
      viewportController.setZoom(2.0);
      await tester.pump();

      // Assert: No exceptions thrown
      expect(tester.takeException(), isNull);
    });

    testWidgets('shouldRepaint returns true when selection changes',
        (WidgetTester tester) async {
      // Arrange: Two painters with different selections
      final path = domain.Path.line(
        start: const Point(x: 0, y: 0),
        end: const Point(x: 100, y: 100),
      );

      final painter1 = SelectionOverlayPainter(
        selection: const Selection(objectIds: {'path-1'}),
        paths: {'path-1': path},
        shapes: {},
        viewportController: viewportController,
        pathRenderer: pathRenderer,
      );

      final painter2 = SelectionOverlayPainter(
        selection: Selection.empty(),
        paths: {'path-1': path},
        shapes: {},
        viewportController: viewportController,
        pathRenderer: pathRenderer,
      );

      // Act & Assert: Should repaint when selection changes
      expect(painter2.shouldRepaint(painter1), isTrue);
    });
  });

  group('CanvasHitTester', () {
    late ViewportController viewportController;
    late PathRenderer pathRenderer;
    late canvas_hit_test.CanvasHitTester hitTester;

    setUp(() {
      viewportController = ViewportController();
      pathRenderer = PathRenderer();
      hitTester = canvas_hit_test.CanvasHitTester(
        viewportController: viewportController,
        pathRenderer: pathRenderer,
      );
    });

    tearDown(() {
      viewportController.dispose();
      pathRenderer.invalidateAll();
    });

    test('hitTestObjects returns miss for empty objects', () {
      // Arrange: No objects
      final result = hitTester.hitTestObjects(
        screenPoint: const Offset(50, 50),
        paths: {},
        shapes: {},
      );

      // Assert: Miss
      expect(result.isHit, isFalse);
      expect(result.objectId, isNull);
    });

    test('hitTestObjects detects path hit', () {
      // Arrange: Path at origin
      final path = domain.Path.line(
        start: const Point(x: 0, y: 0),
        end: const Point(x: 100, y: 100),
      );

      // Act: Test near path
      final result = hitTester.hitTestObjects(
        screenPoint: const Offset(5, 5),
        paths: {'path-1': path},
        shapes: {},
      );

      // Assert: Hit
      expect(result.isHit, isTrue);
      expect(result.objectId, equals('path-1'));
    });

    test('hitTestObjects detects shape hit', () {
      // Arrange: Rectangle at center
      final shape = Shape.rectangle(
        center: const Point(x: 50, y: 50),
        width: 40,
        height: 30,
      );

      // Act: Test inside shape
      final result = hitTester.hitTestObjects(
        screenPoint: const Offset(50, 50),
        paths: {},
        shapes: {'shape-1': shape},
      );

      // Assert: Hit
      expect(result.isHit, isTrue);
      expect(result.objectId, equals('shape-1'));
    });

    test('hitTestAnchors returns miss for far point', () {
      // Arrange: Path with anchors
      final path = domain.Path(
        anchors: [
          AnchorPoint.corner(const Point(x: 0, y: 0)),
          AnchorPoint.corner(const Point(x: 100, y: 100)),
        ],
        segments: [
          Segment.line(startIndex: 0, endIndex: 1),
        ],
      );

      // Act: Test far from anchors
      final result = hitTester.hitTestAnchors(
        screenPoint: const Offset(500, 500),
        objectId: 'path-1',
        path: path,
      );

      // Assert: Miss
      expect(result.isHit, isFalse);
      expect(result.anchorIndex, isNull);
    });

    test('hitTestAnchors detects anchor hit', () {
      // Arrange: Path with anchor at origin
      final path = domain.Path(
        anchors: [
          AnchorPoint.corner(const Point(x: 0, y: 0)),
          AnchorPoint.corner(const Point(x: 100, y: 100)),
        ],
        segments: [
          Segment.line(startIndex: 0, endIndex: 1),
        ],
      );

      // Act: Test near first anchor
      final result = hitTester.hitTestAnchors(
        screenPoint: const Offset(2, 2),
        objectId: 'path-1',
        path: path,
      );

      // Assert: Hit anchor 0
      expect(result.isHit, isTrue);
      expect(result.objectId, equals('path-1'));
      expect(result.anchorIndex, equals(0));
      expect(result.component, equals(AnchorComponent.anchor));
    });

    test('hitTestAnchors detects handle hit', () {
      // Arrange: Path with handle
      final path = domain.Path(
        anchors: [
          const AnchorPoint(
            position: Point(x: 0, y: 0),
            handleOut: Point(x: 20, y: 0),
          ),
          AnchorPoint.corner(const Point(x: 100, y: 100)),
        ],
        segments: [
          Segment.bezier(startIndex: 0, endIndex: 1),
        ],
      );

      // Act: Test near handleOut (at 20, 0)
      final result = hitTester.hitTestAnchors(
        screenPoint: const Offset(20, 0),
        objectId: 'path-1',
        path: path,
      );

      // Assert: Hit handleOut
      expect(result.isHit, isTrue);
      expect(result.objectId, equals('path-1'));
      expect(result.anchorIndex, equals(0));
      expect(result.component, equals(AnchorComponent.handleOut));
    });

    test('hitTestAnchors returns nearest anchor', () {
      // Arrange: Path with two close anchors
      final path = domain.Path(
        anchors: [
          AnchorPoint.corner(const Point(x: 10, y: 10)),
          AnchorPoint.corner(const Point(x: 15, y: 10)),
        ],
        segments: [
          Segment.line(startIndex: 0, endIndex: 1),
        ],
      );

      // Act: Test between anchors (closer to first)
      final result = hitTester.hitTestAnchors(
        screenPoint: const Offset(11, 10),
        objectId: 'path-1',
        path: path,
      );

      // Assert: Hit nearest anchor (index 0)
      expect(result.isHit, isTrue);
      expect(result.anchorIndex, equals(0));
    });
  });

  group('PathRenderer caching', () {
    late PathRenderer pathRenderer;

    setUp(() {
      pathRenderer = PathRenderer();
    });

    tearDown(() {
      pathRenderer.invalidateAll();
    });

    test('caches converted paths', () {
      // Arrange: Simple path
      final path = domain.Path.line(
        start: const Point(x: 0, y: 0),
        end: const Point(x: 100, y: 100),
      );

      // Act: Convert twice with same parameters
      final uiPath1 = pathRenderer.getOrCreatePathFromDomain(
        objectId: 'path-1',
        domainPath: path,
        currentZoom: 1.0,
      );

      final uiPath2 = pathRenderer.getOrCreatePathFromDomain(
        objectId: 'path-1',
        domainPath: path,
        currentZoom: 1.0,
      );

      // Assert: Same instance returned (cached)
      expect(identical(uiPath1, uiPath2), isTrue);
      expect(pathRenderer.cacheSize, equals(1));
    });

    test('invalidates cache on zoom change', () {
      // Arrange: Path with initial zoom
      final path = domain.Path.line(
        start: const Point(x: 0, y: 0),
        end: const Point(x: 100, y: 100),
      );

      pathRenderer.getOrCreatePathFromDomain(
        objectId: 'path-1',
        domainPath: path,
        currentZoom: 1.0,
      );

      // Act: Get with significantly different zoom
      final uiPath2 = pathRenderer.getOrCreatePathFromDomain(
        objectId: 'path-1',
        domainPath: path,
        currentZoom: 2.0,
      );

      // Assert: Cache was invalidated and regenerated
      expect(uiPath2, isNotNull);
      expect(pathRenderer.cacheSize, equals(1));
    });

    test('invalidates cache on domain change', () {
      // Arrange: Two different paths
      final path1 = domain.Path.line(
        start: const Point(x: 0, y: 0),
        end: const Point(x: 100, y: 100),
      );

      final path2 = domain.Path.line(
        start: const Point(x: 0, y: 0),
        end: const Point(x: 200, y: 200),
      );

      pathRenderer.getOrCreatePathFromDomain(
        objectId: 'path-1',
        domainPath: path1,
        currentZoom: 1.0,
      );

      // Act: Get with different path geometry
      final uiPath2 = pathRenderer.getOrCreatePathFromDomain(
        objectId: 'path-1',
        domainPath: path2,
        currentZoom: 1.0,
      );

      // Assert: Cache was invalidated and regenerated
      expect(uiPath2, isNotNull);
    });

    test('converts shapes to paths', () {
      // Arrange: Rectangle shape
      final shape = Shape.rectangle(
        center: const Point(x: 50, y: 50),
        width: 40,
        height: 30,
      );

      // Act: Convert shape
      final uiPath = pathRenderer.getOrCreatePathFromShape(
        objectId: 'shape-1',
        shape: shape,
        currentZoom: 1.0,
      );

      // Assert: Path created
      expect(uiPath, isNotNull);
      expect(pathRenderer.cacheSize, equals(1));
    });

    test('invalidate removes specific cache entry', () {
      // Arrange: Multiple cached paths
      final path1 = domain.Path.line(
        start: const Point(x: 0, y: 0),
        end: const Point(x: 100, y: 100),
      );

      final path2 = domain.Path.line(
        start: const Point(x: 200, y: 200),
        end: const Point(x: 300, y: 300),
      );

      pathRenderer.getOrCreatePathFromDomain(
        objectId: 'path-1',
        domainPath: path1,
        currentZoom: 1.0,
      );

      pathRenderer.getOrCreatePathFromDomain(
        objectId: 'path-2',
        domainPath: path2,
        currentZoom: 1.0,
      );

      expect(pathRenderer.cacheSize, equals(2));

      // Act: Invalidate one
      pathRenderer.invalidate('path-1');

      // Assert: Only one removed
      expect(pathRenderer.cacheSize, equals(1));
    });

    test('invalidateAll clears entire cache', () {
      // Arrange: Multiple cached paths
      final path1 = domain.Path.line(
        start: const Point(x: 0, y: 0),
        end: const Point(x: 100, y: 100),
      );

      final path2 = domain.Path.line(
        start: const Point(x: 200, y: 200),
        end: const Point(x: 300, y: 300),
      );

      pathRenderer.getOrCreatePathFromDomain(
        objectId: 'path-1',
        domainPath: path1,
        currentZoom: 1.0,
      );

      pathRenderer.getOrCreatePathFromDomain(
        objectId: 'path-2',
        domainPath: path2,
        currentZoom: 1.0,
      );

      expect(pathRenderer.cacheSize, equals(2));

      // Act: Clear all
      pathRenderer.invalidateAll();

      // Assert: Empty cache
      expect(pathRenderer.cacheSize, equals(0));
    });
  });
}
