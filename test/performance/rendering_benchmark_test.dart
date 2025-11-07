import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/domain/document/selection.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/models/anchor_point.dart';
import 'package:wiretuner/domain/models/path.dart' as domain;
import 'package:wiretuner/domain/models/segment.dart';
import 'package:wiretuner/domain/models/shape.dart';
import 'package:wiretuner/presentation/canvas/overlays/selection_overlay.dart';
import 'package:wiretuner/presentation/canvas/painter/document_painter.dart';
import 'package:wiretuner/presentation/canvas/painter/path_renderer.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';

void main() {
  group('Rendering Performance Benchmarks', () {
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

    /// Generates a list of random paths for performance testing.
    List<domain.Path> generateRandomPaths(int count, {int seed = 42}) {
      final random = math.Random(seed);
      final paths = <domain.Path>[];

      for (int i = 0; i < count; i++) {
        // Generate 3-8 anchors per path
        final anchorCount = 3 + random.nextInt(6);
        final anchors = <AnchorPoint>[];

        for (int j = 0; j < anchorCount; j++) {
          final x = random.nextDouble() * 1000;
          final y = random.nextDouble() * 1000;

          // 30% chance of Bezier curve
          if (random.nextDouble() < 0.3) {
            anchors.add(AnchorPoint(
              position: Point(x: x, y: y),
              handleOut: Point(
                x: (random.nextDouble() - 0.5) * 50,
                y: (random.nextDouble() - 0.5) * 50,
              ),
              handleIn: Point(
                x: (random.nextDouble() - 0.5) * 50,
                y: (random.nextDouble() - 0.5) * 50,
              ),
            ));
          } else {
            anchors.add(AnchorPoint.corner(Point(x: x, y: y)));
          }
        }

        // Create segments connecting anchors
        final segments = <Segment>[];
        for (int j = 0; j < anchorCount - 1; j++) {
          final isBezier = anchors[j].handleOut != null ||
              anchors[j + 1].handleIn != null;
          segments.add(isBezier
              ? Segment.bezier(startIndex: j, endIndex: j + 1)
              : Segment.line(startIndex: j, endIndex: j + 1));
        }

        paths.add(domain.Path(
          anchors: anchors,
          segments: segments,
          closed: random.nextBool(),
        ));
      }

      return paths;
    }

    /// Generates a mix of random shapes for performance testing.
    Map<String, Shape> generateRandomShapes(int count, {int seed = 42}) {
      final random = math.Random(seed);
      final shapes = <String, Shape>{};

      for (int i = 0; i < count; i++) {
        final x = random.nextDouble() * 1000;
        final y = random.nextDouble() * 1000;
        final center = Point(x: x, y: y);

        final shapeType = random.nextInt(4);
        Shape shape;

        switch (shapeType) {
          case 0: // Rectangle
            shape = Shape.rectangle(
              center: center,
              width: 20 + random.nextDouble() * 80,
              height: 20 + random.nextDouble() * 80,
              cornerRadius: random.nextDouble() * 10,
            );
            break;
          case 1: // Ellipse
            shape = Shape.ellipse(
              center: center,
              width: 20 + random.nextDouble() * 80,
              height: 20 + random.nextDouble() * 80,
            );
            break;
          case 2: // Polygon
            shape = Shape.polygon(
              center: center,
              radius: 20 + random.nextDouble() * 50,
              sides: 3 + random.nextInt(8),
            );
            break;
          case 3: // Star
            final outerRadius = 20 + random.nextDouble() * 50;
            shape = Shape.star(
              center: center,
              outerRadius: outerRadius,
              innerRadius: outerRadius * (0.3 + random.nextDouble() * 0.4),
              pointCount: 3 + random.nextInt(8),
            );
            break;
          default:
            throw StateError('Unexpected shape type');
        }

        shapes['shape-$i'] = shape;
      }

      return shapes;
    }

    test('DocumentPainter renders 1000 paths within 16ms', () {
      // Arrange: Generate 1000 random paths
      final paths = generateRandomPaths(1000);

      final painter = DocumentPainter(
        paths: paths,
        viewportController: viewportController,
      );

      // Create a canvas for painting
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(1920, 1080); // Full HD resolution

      // Act: Measure paint time
      final stopwatch = Stopwatch()..start();

      painter.paint(canvas, size);

      stopwatch.stop();
      final paintTimeMs = stopwatch.elapsedMicroseconds / 1000;

      // Clean up
      recorder.endRecording();

      // Assert: Paint time should be under 16ms (60 FPS budget)
      print('DocumentPainter: 1000 paths painted in ${paintTimeMs.toStringAsFixed(2)}ms');
      expect(paintTimeMs, lessThan(16.0),
          reason: 'Paint time exceeded 16ms frame budget');
    });

    test('SelectionOverlay renders 100 selected paths within 16ms', () {
      // Arrange: Generate 100 random paths
      final pathsMap = <String, domain.Path>{};
      final paths = generateRandomPaths(100);

      for (int i = 0; i < paths.length; i++) {
        pathsMap['path-$i'] = paths[i];
      }

      // Select all paths
      final selection = Selection(
        objectIds: pathsMap.keys.toSet(),
      );

      final painter = SelectionOverlayPainter(
        selection: selection,
        paths: pathsMap,
        shapes: {},
        viewportController: viewportController,
        pathRenderer: pathRenderer,
      );

      // Create a canvas for painting
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(1920, 1080);

      // Act: Measure paint time
      final stopwatch = Stopwatch()..start();

      painter.paint(canvas, size);

      stopwatch.stop();
      final paintTimeMs = stopwatch.elapsedMicroseconds / 1000;

      // Clean up
      recorder.endRecording();

      // Assert: Paint time should be under 16ms
      print('SelectionOverlay: 100 paths painted in ${paintTimeMs.toStringAsFixed(2)}ms');
      expect(paintTimeMs, lessThan(16.0),
          reason: 'Paint time exceeded 16ms frame budget');
    });

    test('PathRenderer caching provides performance benefit', () {
      // Arrange: Generate 1000 paths
      final paths = generateRandomPaths(1000);

      // Act: Measure first conversion (cache miss)
      final stopwatch1 = Stopwatch()..start();

      for (int i = 0; i < paths.length; i++) {
        pathRenderer.getOrCreatePathFromDomain(
          objectId: 'path-$i',
          domainPath: paths[i],
          currentZoom: 1.0,
        );
      }

      stopwatch1.stop();
      final firstPassMs = stopwatch1.elapsedMicroseconds / 1000;

      // Act: Measure second conversion (cache hit)
      final stopwatch2 = Stopwatch()..start();

      for (int i = 0; i < paths.length; i++) {
        pathRenderer.getOrCreatePathFromDomain(
          objectId: 'path-$i',
          domainPath: paths[i],
          currentZoom: 1.0,
        );
      }

      stopwatch2.stop();
      final secondPassMs = stopwatch2.elapsedMicroseconds / 1000;

      // Assert: Cached lookups should be significantly faster
      print('PathRenderer first pass: ${firstPassMs.toStringAsFixed(2)}ms');
      print('PathRenderer cached pass: ${secondPassMs.toStringAsFixed(2)}ms');
      print('Speedup: ${(firstPassMs / secondPassMs).toStringAsFixed(2)}x');

      expect(secondPassMs, lessThan(firstPassMs * 0.8),
          reason: 'Cache should provide at least 20% speedup');
    });

    test('Mixed document (paths + shapes) renders within 16ms', () {
      // Arrange: Generate 800 paths and 200 shapes
      final paths = generateRandomPaths(800);
      final shapes = generateRandomShapes(200);

      final painter = DocumentPainter(
        paths: paths,
        viewportController: viewportController,
      );

      // Create a canvas for painting
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(1920, 1080);

      // Act: Measure paint time
      final stopwatch = Stopwatch()..start();

      painter.paint(canvas, size);

      stopwatch.stop();
      final paintTimeMs = stopwatch.elapsedMicroseconds / 1000;

      // Clean up
      recorder.endRecording();

      // Assert: Paint time should be under 16ms
      print('Mixed document: 1000 objects painted in ${paintTimeMs.toStringAsFixed(2)}ms');
      expect(paintTimeMs, lessThan(16.0),
          reason: 'Paint time exceeded 16ms frame budget');
    });

    test('Cache hit rate remains high under normal workload', () {
      // Arrange: Generate 1000 paths
      final paths = generateRandomPaths(1000);

      // Simulate normal workload: initial load + 10 repaints
      for (int i = 0; i < paths.length; i++) {
        pathRenderer.getOrCreatePathFromDomain(
          objectId: 'path-$i',
          domainPath: paths[i],
          currentZoom: 1.0,
        );
      }

      final initialCacheSize = pathRenderer.cacheSize;

      // Simulate 10 repaints (cache should remain valid)
      for (int repaint = 0; repaint < 10; repaint++) {
        for (int i = 0; i < paths.length; i++) {
          pathRenderer.getOrCreatePathFromDomain(
            objectId: 'path-$i',
            domainPath: paths[i],
            currentZoom: 1.0,
          );
        }
      }

      // Assert: Cache size should remain stable
      expect(pathRenderer.cacheSize, equals(initialCacheSize),
          reason: 'Cache should not grow unnecessarily');
    });

    test('Zoom changes within threshold do not invalidate cache', () {
      // Arrange: Generate paths and cache them
      final paths = generateRandomPaths(100);

      for (int i = 0; i < paths.length; i++) {
        pathRenderer.getOrCreatePathFromDomain(
          objectId: 'path-$i',
          domainPath: paths[i],
          currentZoom: 1.0,
        );
      }

      // Act: Small zoom changes (within 10% threshold)
      for (int i = 0; i < paths.length; i++) {
        pathRenderer.getOrCreatePathFromDomain(
          objectId: 'path-$i',
          domainPath: paths[i],
          currentZoom: 1.05, // 5% change
        );
      }

      // Assert: Cache still has all entries
      expect(pathRenderer.cacheSize, equals(100));
    });

    test('Large zoom changes invalidate cache as expected', () {
      // Arrange: Generate paths and cache them at zoom 1.0
      final paths = generateRandomPaths(100);

      for (int i = 0; i < paths.length; i++) {
        pathRenderer.getOrCreatePathFromDomain(
          objectId: 'path-$i',
          domainPath: paths[i],
          currentZoom: 1.0,
        );
      }

      // Act: Large zoom change (>10% threshold)
      for (int i = 0; i < paths.length; i++) {
        pathRenderer.getOrCreatePathFromDomain(
          objectId: 'path-$i',
          domainPath: paths[i],
          currentZoom: 2.0, // 100% change
        );
      }

      // Assert: Cache still has entries (regenerated with new zoom)
      expect(pathRenderer.cacheSize, equals(100));
    });
  });
}
