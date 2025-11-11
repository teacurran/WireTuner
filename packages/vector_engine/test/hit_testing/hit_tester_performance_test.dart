import 'package:test/test.dart';
import 'package:vector_engine/src/geometry.dart';
import 'package:vector_engine/src/hit_testing/hit_tester.dart';
import 'dart:math' as math;

void main() {
  group('HitTester performance', () {
    test('10k objects - construction time', () {
      final objects = _generate10kObjects();

      final stopwatch = Stopwatch()..start();
      final hitTester = HitTester.build(objects);
      stopwatch.stop();

      final constructionTimeMs = stopwatch.elapsedMilliseconds;

      print('10k objects construction time: ${constructionTimeMs}ms');
      expect(hitTester.objectCount, equals(10000));

      // Construction should be reasonably fast (< 1 second)
      // This is a guideline, not a hard requirement
      expect(constructionTimeMs, lessThan(1000),
          reason: 'BVH construction should complete within 1s');
    });

    test('10k objects - average query time < 2ms', () {
      final objects = _generate10kObjects();
      final hitTester = HitTester.build(objects);

      final config = HitTestConfig(
        strokeTolerance: 5.0,
        anchorTolerance: 8.0,
      );

      // Generate random query points
      final random = math.Random(42); // Fixed seed for reproducibility
      final queryPoints = List.generate(
        1000,
        (_) => Point(
          x: random.nextDouble() * 1000,
          y: random.nextDouble() * 1000,
        ),
      );

      // Warm up (JIT compilation, caches, etc.)
      for (int i = 0; i < 10; i++) {
        hitTester.hitTest(point: queryPoints[0], config: config);
      }

      // Measure query performance
      final stopwatch = Stopwatch()..start();
      for (final point in queryPoints) {
        hitTester.hitTest(point: point, config: config);
      }
      stopwatch.stop();

      final totalTimeMs = stopwatch.elapsedMilliseconds;
      final averageTimeMs = totalTimeMs / queryPoints.length;

      print('10k objects query stats:');
      print('  Total time: ${totalTimeMs}ms for ${queryPoints.length} queries');
      print('  Average time: ${averageTimeMs.toStringAsFixed(3)}ms per query');
      print('  Queries per second: ${(1000 / averageTimeMs).toStringAsFixed(0)}');

      // Target: < 2ms average query time
      expect(averageTimeMs, lessThan(2.0),
          reason: 'Average query time should be under 2ms for 10k objects');
    });

    test('10k objects - BVH statistics', () {
      final objects = _generate10kObjects();
      final hitTester = HitTester.build(objects);

      final stats = hitTester.getStats();

      print('10k objects BVH stats: $stats');

      expect(stats.totalEntries, equals(10000));
      expect(stats.leafCount, greaterThan(0));
      expect(stats.branchCount, greaterThan(0));

      // Tree should be reasonably balanced
      // For 10k objects, depth should be around log2(10000) ≈ 13-14
      // Allow some slack for unbalanced data
      expect(stats.maxDepth, lessThan(30),
          reason: 'Tree should not be too deep');

      // Average leaf size should be close to maxLeafSize
      expect(stats.averageLeafSize, lessThanOrEqualTo(8.0),
          reason: 'Average leaf size should not exceed max');
    });

    test('10k objects - hit rate statistics', () {
      final objects = _generate10kObjects();
      final hitTester = HitTester.build(objects);

      final config = HitTestConfig(
        strokeTolerance: 5.0,
        testAnchors: false,
      );

      final random = math.Random(42);
      final queryPoints = List.generate(
        1000,
        (_) => Point(
          x: random.nextDouble() * 1000,
          y: random.nextDouble() * 1000,
        ),
      );

      int totalHits = 0;
      for (final point in queryPoints) {
        final hits = hitTester.hitTest(point: point, config: config);
        totalHits += hits.length;
      }

      final averageHitsPerQuery = totalHits / queryPoints.length;

      print('Hit rate stats:');
      print('  Total hits: $totalHits');
      print('  Average hits per query: ${averageHitsPerQuery.toStringAsFixed(2)}');

      // With 10k objects in a 1000x1000 space and 5px tolerance,
      // we expect some hits but not too many
      expect(averageHitsPerQuery, greaterThan(0));
      expect(averageHitsPerQuery, lessThan(100));
    });

    test('10k objects - nearest query performance', () {
      final objects = _generate10kObjects();
      final hitTester = HitTester.build(objects);

      final config = HitTestConfig(
        strokeTolerance: 10.0,
        testAnchors: false,
      );

      final random = math.Random(42);
      final queryPoints = List.generate(
        1000,
        (_) => Point(
          x: random.nextDouble() * 1000,
          y: random.nextDouble() * 1000,
        ),
      );

      final stopwatch = Stopwatch()..start();
      for (final point in queryPoints) {
        hitTester.hitTestNearest(point: point, config: config);
      }
      stopwatch.stop();

      final totalTimeMs = stopwatch.elapsedMilliseconds;
      final averageTimeMs = totalTimeMs / queryPoints.length;

      print('Nearest query stats:');
      print('  Average time: ${averageTimeMs.toStringAsFixed(3)}ms per query');

      // Nearest queries should be similar speed to regular queries
      expect(averageTimeMs, lessThan(2.0));
    });

    test('10k objects - bounds query performance', () {
      final objects = _generate10kObjects();
      final hitTester = HitTester.build(objects);

      final random = math.Random(42);
      final queryBounds = List.generate(
        100,
        (_) {
          final x = random.nextDouble() * 900;
          final y = random.nextDouble() * 900;
          return Bounds.fromLTRB(
            left: x,
            top: y,
            right: x + 100,
            bottom: y + 100,
          );
        },
      );

      final stopwatch = Stopwatch()..start();
      for (final bounds in queryBounds) {
        hitTester.hitTestBounds(bounds);
      }
      stopwatch.stop();

      final totalTimeMs = stopwatch.elapsedMilliseconds;
      final averageTimeMs = totalTimeMs / queryBounds.length;

      print('Bounds query stats:');
      print('  Average time: ${averageTimeMs.toStringAsFixed(3)}ms per query');

      // Bounds queries should be fast
      expect(averageTimeMs, lessThan(5.0));
    });

    test('scalability - increasing object counts', () {
      final counts = [100, 1000, 5000, 10000];
      final results = <int, double>{};

      for (final count in counts) {
        final objects = _generateObjects(count);
        final hitTester = HitTester.build(objects);

        final config = HitTestConfig(strokeTolerance: 5.0, testAnchors: false);
        final random = math.Random(42);
        final queryPoints = List.generate(
          100,
          (_) => Point(
            x: random.nextDouble() * 1000,
            y: random.nextDouble() * 1000,
          ),
        );

        final stopwatch = Stopwatch()..start();
        for (final point in queryPoints) {
          hitTester.hitTest(point: point, config: config);
        }
        stopwatch.stop();

        final averageTimeMs = stopwatch.elapsedMilliseconds / queryPoints.length;
        results[count] = averageTimeMs;

        print('$count objects: ${averageTimeMs.toStringAsFixed(3)}ms per query');
      }

      // Verify O(log n) scaling
      // Query time should grow slowly with object count
      // Allow for 100 objects to have near-zero time (which might be 0.0)
      if (results[100]! > 0.0) {
        expect(results[10000]!, lessThan(results[100]! * 10),
            reason: 'BVH should provide better than linear scaling');
      } else {
        // Just check that 10k is still fast if 100 was too fast to measure
        expect(results[10000]!, lessThan(1.0),
            reason: 'Large object counts should still be fast');
      }
    });
  });

  group('HitTester stress tests', () {
    test('many queries on same objects', () {
      final objects = _generate10kObjects();
      final hitTester = HitTester.build(objects);

      final config = HitTestConfig();
      final point = Point(x: 500, y: 500);

      // Run 10000 queries
      final stopwatch = Stopwatch()..start();
      for (int i = 0; i < 10000; i++) {
        hitTester.hitTest(point: point, config: config);
      }
      stopwatch.stop();

      final averageTimeMs = stopwatch.elapsedMilliseconds / 10000;

      print('Repeated query (10k iterations): ${averageTimeMs.toStringAsFixed(3)}ms');

      expect(averageTimeMs, lessThan(2.0));
    });

    test('dense clustering - many overlapping objects', () {
      // Create 1000 objects all in a small area
      final objects = List.generate(
        1000,
        (i) => HitTestable.path(
          id: 'dense$i',
          path: Path.line(
            start: Point(x: 100 + (i % 10) * 2.0, y: 100 + (i ~/ 10) * 2.0),
            end: Point(x: 105 + (i % 10) * 2.0, y: 105 + (i ~/ 10) * 2.0),
          ),
        ),
      );

      final hitTester = HitTester.build(objects);

      final config = HitTestConfig(strokeTolerance: 10.0, testAnchors: false);
      final point = Point(x: 110, y: 110); // In the cluster

      final stopwatch = Stopwatch()..start();
      final hits = hitTester.hitTest(point: point, config: config);
      stopwatch.stop();

      print('Dense cluster query: ${stopwatch.elapsedMilliseconds}ms, ${hits.length} hits');

      // Should find many hits, but still be fast
      expect(hits.length, greaterThan(10));
      expect(stopwatch.elapsedMilliseconds, lessThan(10));
    });

    test('sparse distribution - objects far apart', () {
      // Create 1000 objects spread out
      final objects = List.generate(
        1000,
        (i) => HitTestable.path(
          id: 'sparse$i',
          path: Path.line(
            start: Point(x: i * 1000.0, y: 0),
            end: Point(x: i * 1000.0 + 10, y: 10),
          ),
        ),
      );

      final hitTester = HitTester.build(objects);

      final config = HitTestConfig(strokeTolerance: 5.0, testAnchors: false);
      final point = Point(x: 500005, y: 5); // Near object 500

      final stopwatch = Stopwatch()..start();
      final hits = hitTester.hitTest(point: point, config: config);
      stopwatch.stop();

      print('Sparse distribution query: ${stopwatch.elapsedMilliseconds}ms');

      // Should be very fast even with 1000 objects
      expect(stopwatch.elapsedMilliseconds, lessThan(5));
    });
  });
}

/// Generates 10,000 test objects in a 1000x1000 space.
List<HitTestable> _generate10kObjects() {
  return _generateObjects(10000);
}

/// Generates the specified number of test objects.
List<HitTestable> _generateObjects(int count) {
  final random = math.Random(42); // Fixed seed for reproducibility
  final objects = <HitTestable>[];

  for (int i = 0; i < count; i++) {
    // Mix of paths and shapes
    if (i % 2 == 0) {
      // Create a line path
      final x1 = random.nextDouble() * 1000;
      final y1 = random.nextDouble() * 1000;
      final x2 = x1 + random.nextDouble() * 50 - 25;
      final y2 = y1 + random.nextDouble() * 50 - 25;

      objects.add(HitTestable.path(
        id: 'path$i',
        path: Path.line(
          start: Point(x: x1, y: y1),
          end: Point(x: x2, y: y2),
        ),
      ));
    } else {
      // Create a rectangle shape
      final x = random.nextDouble() * 1000;
      final y = random.nextDouble() * 1000;
      final width = random.nextDouble() * 20 + 5;
      final height = random.nextDouble() * 20 + 5;

      objects.add(HitTestable.shape(
        id: 'shape$i',
        shape: Shape.rectangle(
          center: Point(x: x + width / 2, y: y + height / 2),
          width: width,
          height: height,
        ),
      ));
    }
  }

  return objects;
}
