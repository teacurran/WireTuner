import 'package:test/test.dart';
import 'package:vector_engine/src/geometry.dart';
import 'package:vector_engine/src/hit_testing/bvh.dart';

void main() {
  group('BVH construction', () {
    test('empty BVH', () {
      final bvh = BVH.build(<BVHEntry<String>>[]);
      final stats = bvh.getStats();

      expect(stats.totalEntries, equals(0));
      expect(stats.leafCount, equals(1)); // Empty leaf
    });

    test('single entry BVH', () {
      final entries = [
        BVHEntry<String>(
          id: 'obj1',
          bounds: Bounds.fromLTRB(left: 0, top: 0, right: 10, bottom: 10),
          data: 'object1',
        ),
      ];

      final bvh = BVH.build(entries);
      final stats = bvh.getStats();

      expect(stats.totalEntries, equals(1));
      expect(stats.leafCount, equals(1));
      expect(stats.branchCount, equals(0));
    });

    test('multiple entries within leaf threshold', () {
      final entries = List.generate(
        5,
        (i) => BVHEntry<String>(
          id: 'obj$i',
          bounds: Bounds.fromLTRB(
            left: i * 10.0,
            top: 0,
            right: i * 10.0 + 10,
            bottom: 10,
          ),
          data: 'object$i',
        ),
      );

      final bvh = BVH.build(entries);
      final stats = bvh.getStats();

      expect(stats.totalEntries, equals(5));
      expect(stats.leafCount, equals(1)); // Below max leaf size
    });

    test('many entries create branches', () {
      final entries = List.generate(
        100,
        (i) => BVHEntry<String>(
          id: 'obj$i',
          bounds: Bounds.fromLTRB(
            left: (i % 10) * 10.0,
            top: (i ~/ 10) * 10.0,
            right: (i % 10) * 10.0 + 10,
            bottom: (i ~/ 10) * 10.0 + 10,
          ),
          data: 'object$i',
        ),
      );

      final bvh = BVH.build(entries);
      final stats = bvh.getStats();

      expect(stats.totalEntries, equals(100));
      expect(stats.leafCount, greaterThan(1)); // Should have split
      expect(stats.branchCount, greaterThan(0));
      expect(stats.maxDepth, greaterThan(0));
    });
  });

  group('BVH point queries', () {
    late BVH<String> bvh;

    setUp(() {
      // Create a 10x10 grid of objects
      final entries = List.generate(
        100,
        (i) => BVHEntry<String>(
          id: 'obj$i',
          bounds: Bounds.fromLTRB(
            left: (i % 10) * 10.0,
            top: (i ~/ 10) * 10.0,
            right: (i % 10) * 10.0 + 10,
            bottom: (i ~/ 10) * 10.0 + 10,
          ),
          data: 'object$i',
        ),
      );

      bvh = BVH.build(entries);
    });

    test('query point inside single object bounds', () {
      final point = Point(x: 5, y: 5); // Inside obj0
      final results = bvh.query(point, tolerance: 0);

      expect(results.length, equals(1));
      expect(results.first.id, equals('obj0'));
    });

    test('query point with tolerance finds nearby objects', () {
      final point = Point(x: 10, y: 10); // On border between objects
      final results = bvh.query(point, tolerance: 1);

      // Should find multiple objects near this point
      expect(results.length, greaterThan(1));
    });

    test('query point outside all bounds with no tolerance', () {
      final point = Point(x: 200, y: 200); // Far outside
      final results = bvh.query(point, tolerance: 0);

      expect(results, isEmpty);
    });

    test('query point outside bounds with large tolerance', () {
      final point = Point(x: -5, y: -5); // Just outside
      final results = bvh.query(point, tolerance: 10);

      // Should find obj0 (at 0,0 to 10,10)
      expect(results, isNotEmpty);
    });

    test('results are sorted by distance', () {
      final point = Point(x: 15, y: 15);
      final results = bvh.query(point, tolerance: 20);

      // Should find multiple objects, sorted by distance
      if (results.length > 1) {
        for (int i = 0; i < results.length - 1; i++) {
          final distA = results[i].bounds.distanceToPoint(point).abs();
          final distB = results[i + 1].bounds.distanceToPoint(point).abs();
          expect(distA, lessThanOrEqualTo(distB));
        }
      }
    });
  });

  group('BVH bounds queries', () {
    late BVH<String> bvh;

    setUp(() {
      // Create a 10x10 grid of objects
      final entries = List.generate(
        100,
        (i) => BVHEntry<String>(
          id: 'obj$i',
          bounds: Bounds.fromLTRB(
            left: (i % 10) * 10.0,
            top: (i ~/ 10) * 10.0,
            right: (i % 10) * 10.0 + 10,
            bottom: (i ~/ 10) * 10.0 + 10,
          ),
          data: 'object$i',
        ),
      );

      bvh = BVH.build(entries);
    });

    test('query fully contained bounds', () {
      final queryBounds = Bounds.fromLTRB(left: 0, top: 0, right: 20, bottom: 20);
      final results = bvh.queryBounds(queryBounds);

      // Should find objects that intersect the 20x20 region
      // Objects at (0,0), (10,0), (0,10), (10,10) all intersect
      expect(results.length, greaterThanOrEqualTo(4));
      expect(results.length, lessThanOrEqualTo(9));
    });

    test('query partially overlapping bounds', () {
      final queryBounds = Bounds.fromLTRB(left: 5, top: 5, right: 15, bottom: 15);
      final results = bvh.queryBounds(queryBounds);

      // Should find objects that overlap this region
      expect(results.length, greaterThan(0));
    });

    test('query non-intersecting bounds', () {
      final queryBounds = Bounds.fromLTRB(left: 200, top: 200, right: 300, bottom: 300);
      final results = bvh.queryBounds(queryBounds);

      expect(results, isEmpty);
    });

    test('query encompassing all bounds', () {
      final queryBounds = Bounds.fromLTRB(left: -10, top: -10, right: 200, bottom: 200);
      final results = bvh.queryBounds(queryBounds);

      // Should find all 100 objects
      expect(results.length, equals(100));
    });
  });

  group('BVH statistics', () {
    test('balanced tree statistics', () {
      final entries = List.generate(
        64,
        (i) => BVHEntry<String>(
          id: 'obj$i',
          bounds: Bounds.fromLTRB(
            left: (i % 8) * 10.0,
            top: (i ~/ 8) * 10.0,
            right: (i % 8) * 10.0 + 10,
            bottom: (i ~/ 8) * 10.0 + 10,
          ),
          data: 'object$i',
        ),
      );

      final bvh = BVH.build(entries);
      final stats = bvh.getStats();

      expect(stats.totalEntries, equals(64));
      expect(stats.leafCount, greaterThan(0));
      expect(stats.branchCount, greaterThan(0));
      expect(stats.averageLeafSize, lessThanOrEqualTo(BVH.maxLeafSize.toDouble()));
    });

    test('stats toString includes all fields', () {
      final entries = [
        BVHEntry<String>(
          id: 'obj1',
          bounds: Bounds.fromLTRB(left: 0, top: 0, right: 10, bottom: 10),
          data: 'object1',
        ),
      ];

      final bvh = BVH.build(entries);
      final stats = bvh.getStats();
      final str = stats.toString();

      expect(str, contains('leaves'));
      expect(str, contains('branches'));
      expect(str, contains('entries'));
      expect(str, contains('maxDepth'));
      expect(str, contains('avgLeafSize'));
    });
  });

  group('BVH edge cases', () {
    test('overlapping objects', () {
      final entries = [
        BVHEntry<String>(
          id: 'obj1',
          bounds: Bounds.fromLTRB(left: 0, top: 0, right: 20, bottom: 20),
          data: 'object1',
        ),
        BVHEntry<String>(
          id: 'obj2',
          bounds: Bounds.fromLTRB(left: 10, top: 10, right: 30, bottom: 30),
          data: 'object2',
        ),
      ];

      final bvh = BVH.build(entries);
      final point = Point(x: 15, y: 15); // In both
      final results = bvh.query(point, tolerance: 0);

      expect(results.length, equals(2));
    });

    test('zero-size bounds', () {
      final entries = [
        BVHEntry<String>(
          id: 'obj1',
          bounds: Bounds.fromLTRB(left: 5, top: 5, right: 5, bottom: 5),
          data: 'point',
        ),
      ];

      final bvh = BVH.build(entries);
      final point = Point(x: 5, y: 5);
      final results = bvh.query(point, tolerance: 0);

      expect(results.length, equals(1));
    });

    test('very large bounds', () {
      final entries = [
        BVHEntry<String>(
          id: 'obj1',
          bounds: Bounds.fromLTRB(left: -1000, top: -1000, right: 1000, bottom: 1000),
          data: 'huge',
        ),
      ];

      final bvh = BVH.build(entries);
      final point = Point(x: 0, y: 0);
      final results = bvh.query(point, tolerance: 0);

      expect(results.length, equals(1));
    });
  });
}
