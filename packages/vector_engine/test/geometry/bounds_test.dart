import 'package:test/test.dart';
import 'package:vector_engine/vector_engine.dart';

void main() {
  group('Bounds', () {
    group('construction', () {
      test('creates bounds from min and max points', () {
        final bounds = Bounds(
          min: Point(x: 10, y: 20),
          max: Point(x: 100, y: 200),
        );
        expect(bounds.min, Point(x: 10, y: 20));
        expect(bounds.max, Point(x: 100, y: 200));
      });

      test('creates bounds from LTRB', () {
        final bounds = Bounds.fromLTRB(
          left: 10,
          top: 20,
          right: 100,
          bottom: 200,
        );
        expect(bounds.left, 10);
        expect(bounds.top, 20);
        expect(bounds.right, 100);
        expect(bounds.bottom, 200);
      });

      test('creates bounds from center and size', () {
        final bounds = Bounds.fromCenter(
          center: Point(x: 50, y: 50),
          width: 100,
          height: 80,
        );
        expect(bounds.left, 0);
        expect(bounds.top, 10);
        expect(bounds.right, 100);
        expect(bounds.bottom, 90);
      });

      test('creates bounds from points', () {
        final points = [
          Point(x: 10, y: 20),
          Point(x: 100, y: 50),
          Point(x: 30, y: 200),
        ];
        final bounds = Bounds.fromPoints(points);
        expect(bounds.left, 10);
        expect(bounds.top, 20);
        expect(bounds.right, 100);
        expect(bounds.bottom, 200);
      });

      test('throws on empty points list', () {
        expect(
          () => Bounds.fromPoints([]),
          throwsArgumentError,
        );
      });

      test('creates zero bounds', () {
        final bounds = Bounds.zero();
        expect(bounds.left, 0);
        expect(bounds.top, 0);
        expect(bounds.right, 0);
        expect(bounds.bottom, 0);
      });
    });

    group('properties', () {
      late Bounds bounds;

      setUp(() {
        bounds = Bounds.fromLTRB(
          left: 10,
          top: 20,
          right: 110,
          bottom: 120,
        );
      });

      test('returns correct width', () {
        expect(bounds.width, 100);
      });

      test('returns correct height', () {
        expect(bounds.height, 100);
      });

      test('returns correct center', () {
        expect(bounds.center, Point(x: 60, y: 70));
      });

      test('returns correct corners', () {
        expect(bounds.topLeft, Point(x: 10, y: 20));
        expect(bounds.topRight, Point(x: 110, y: 20));
        expect(bounds.bottomLeft, Point(x: 10, y: 120));
        expect(bounds.bottomRight, Point(x: 110, y: 120));
      });

      test('returns correct area', () {
        expect(bounds.area, 10000);
      });

      test('isEmpty returns true for zero area', () {
        final empty = Bounds.fromLTRB(left: 10, top: 20, right: 10, bottom: 20);
        expect(empty.isEmpty, isTrue);
      });

      test('isEmpty returns false for non-zero area', () {
        expect(bounds.isEmpty, isFalse);
      });

      test('returns corners list in clockwise order', () {
        final corners = bounds.corners;
        expect(corners.length, 4);
        expect(corners[0], bounds.topLeft);
        expect(corners[1], bounds.topRight);
        expect(corners[2], bounds.bottomRight);
        expect(corners[3], bounds.bottomLeft);
      });
    });

    group('containment', () {
      late Bounds bounds;

      setUp(() {
        bounds = Bounds.fromLTRB(
          left: 10,
          top: 20,
          right: 110,
          bottom: 120,
        );
      });

      test('contains point inside', () {
        expect(bounds.containsPoint(Point(x: 50, y: 50)), isTrue);
      });

      test('contains point on edge', () {
        expect(bounds.containsPoint(Point(x: 10, y: 50)), isTrue);
        expect(bounds.containsPoint(Point(x: 110, y: 50)), isTrue);
      });

      test('does not contain point outside', () {
        expect(bounds.containsPoint(Point(x: 5, y: 50)), isFalse);
        expect(bounds.containsPoint(Point(x: 150, y: 50)), isFalse);
      });

      test('contains smaller bounds', () {
        final smaller = Bounds.fromLTRB(
          left: 20,
          top: 30,
          right: 100,
          bottom: 110,
        );
        expect(bounds.containsBounds(smaller), isTrue);
      });

      test('does not contain overlapping bounds', () {
        final overlapping = Bounds.fromLTRB(
          left: 5,
          top: 30,
          right: 100,
          bottom: 110,
        );
        expect(bounds.containsBounds(overlapping), isFalse);
      });
    });

    group('intersection', () {
      test('detects intersection', () {
        final b1 = Bounds.fromLTRB(left: 0, top: 0, right: 100, bottom: 100);
        final b2 = Bounds.fromLTRB(left: 50, top: 50, right: 150, bottom: 150);
        expect(b1.intersects(b2), isTrue);
      });

      test('detects non-intersection', () {
        final b1 = Bounds.fromLTRB(left: 0, top: 0, right: 100, bottom: 100);
        final b2 = Bounds.fromLTRB(left: 110, top: 110, right: 200, bottom: 200);
        expect(b1.intersects(b2), isFalse);
      });

      test('computes intersection bounds', () {
        final b1 = Bounds.fromLTRB(left: 0, top: 0, right: 100, bottom: 100);
        final b2 = Bounds.fromLTRB(left: 50, top: 50, right: 150, bottom: 150);
        final intersection = b1.intersection(b2);
        expect(intersection, isNotNull);
        expect(intersection!.left, 50);
        expect(intersection.top, 50);
        expect(intersection.right, 100);
        expect(intersection.bottom, 100);
      });

      test('returns null for non-intersecting bounds', () {
        final b1 = Bounds.fromLTRB(left: 0, top: 0, right: 100, bottom: 100);
        final b2 = Bounds.fromLTRB(left: 110, top: 110, right: 200, bottom: 200);
        expect(b1.intersection(b2), isNull);
      });
    });

    group('union', () {
      test('computes union bounds', () {
        final b1 = Bounds.fromLTRB(left: 0, top: 0, right: 100, bottom: 100);
        final b2 = Bounds.fromLTRB(left: 50, top: 50, right: 150, bottom: 150);
        final union = b1.union(b2);
        expect(union.left, 0);
        expect(union.top, 0);
        expect(union.right, 150);
        expect(union.bottom, 150);
      });

      test('union with non-overlapping bounds', () {
        final b1 = Bounds.fromLTRB(left: 0, top: 0, right: 100, bottom: 100);
        final b2 = Bounds.fromLTRB(left: 110, top: 110, right: 200, bottom: 200);
        final union = b1.union(b2);
        expect(union.left, 0);
        expect(union.top, 0);
        expect(union.right, 200);
        expect(union.bottom, 200);
      });
    });

    group('expansion', () {
      late Bounds bounds;

      setUp(() {
        bounds = Bounds.fromLTRB(
          left: 10,
          top: 20,
          right: 110,
          bottom: 120,
        );
      });

      test('expands bounds uniformly', () {
        final expanded = bounds.expand(10);
        expect(expanded.left, 0);
        expect(expanded.top, 10);
        expect(expanded.right, 120);
        expect(expanded.bottom, 130);
      });

      test('expands to include point inside (no change)', () {
        final point = Point(x: 50, y: 50);
        final expanded = bounds.expandToInclude(point);
        expect(expanded, bounds);
      });

      test('expands to include point outside', () {
        final point = Point(x: 150, y: 150);
        final expanded = bounds.expandToInclude(point);
        expect(expanded.left, 10);
        expect(expanded.top, 20);
        expect(expanded.right, 150);
        expect(expanded.bottom, 150);
      });

      test('expands to include another bounds', () {
        final other = Bounds.fromLTRB(
          left: 100,
          top: 100,
          right: 200,
          bottom: 200,
        );
        final expanded = bounds.expandToIncludeBounds(other);
        expect(expanded.left, 10);
        expect(expanded.top, 20);
        expect(expanded.right, 200);
        expect(expanded.bottom, 200);
      });
    });

    group('transformations', () {
      late Bounds bounds;

      setUp(() {
        bounds = Bounds.fromLTRB(
          left: 10,
          top: 20,
          right: 110,
          bottom: 120,
        );
      });

      test('translates bounds', () {
        final translated = bounds.translate(Point(x: 5, y: 10));
        expect(translated.left, 15);
        expect(translated.top, 30);
        expect(translated.right, 115);
        expect(translated.bottom, 130);
      });

      test('scales bounds', () {
        final scaled = bounds.scale(2, 0.5);
        expect(scaled.left, 20);
        expect(scaled.top, 10);
        expect(scaled.right, 220);
        expect(scaled.bottom, 60);
      });

      test('uniform scales bounds', () {
        final scaled = bounds.uniformScale(2);
        expect(scaled.left, 20);
        expect(scaled.top, 40);
        expect(scaled.right, 220);
        expect(scaled.bottom, 240);
      });
    });

    group('distance', () {
      late Bounds bounds;

      setUp(() {
        bounds = Bounds.fromLTRB(
          left: 10,
          top: 20,
          right: 110,
          bottom: 120,
        );
      });

      test('distance to point inside is negative', () {
        final point = Point(x: 60, y: 70);
        final distance = bounds.distanceToPoint(point);
        expect(distance, lessThan(0));
      });

      test('distance to point outside', () {
        final point = Point(x: 150, y: 70);
        final distance = bounds.distanceToPoint(point);
        expect(distance, closeTo(40, 1e-10));
      });

      test('distance to point on edge is negative or zero', () {
        final point = Point(x: 10, y: 70);
        final distance = bounds.distanceToPoint(point);
        expect(distance, lessThanOrEqualTo(0));
      });
    });

    group('equality', () {
      test('bounds with same coordinates are equal', () {
        final b1 = Bounds.fromLTRB(left: 10, top: 20, right: 100, bottom: 200);
        final b2 = Bounds.fromLTRB(left: 10, top: 20, right: 100, bottom: 200);
        expect(b1, equals(b2));
        expect(b1.hashCode, equals(b2.hashCode));
      });

      test('bounds with different coordinates are not equal', () {
        final b1 = Bounds.fromLTRB(left: 10, top: 20, right: 100, bottom: 200);
        final b2 = Bounds.fromLTRB(left: 10, top: 20, right: 100, bottom: 201);
        expect(b1, isNot(equals(b2)));
      });
    });

    group('JSON serialization', () {
      test('serializes to JSON', () {
        final bounds = Bounds.fromLTRB(
          left: 10,
          top: 20,
          right: 100,
          bottom: 200,
        );
        final json = bounds.toJson();
        expect(json, isA<Map<String, dynamic>>());
      });

      test('deserializes from JSON', () {
        final json = {
          'min': {'x': 10.0, 'y': 20.0},
          'max': {'x': 100.0, 'y': 200.0},
        };
        final bounds = Bounds.fromJson(json);
        expect(bounds.left, 10);
        expect(bounds.top, 20);
        expect(bounds.right, 100);
        expect(bounds.bottom, 200);
      });

      test('round-trips through JSON', () {
        final original = Bounds.fromLTRB(
          left: 12.34,
          top: 56.78,
          right: 90.12,
          bottom: 34.56,
        );
        final json = {
          'min': original.min.toJson(),
          'max': original.max.toJson(),
        };
        final deserialized = Bounds.fromJson(json);
        expect(deserialized, equals(original));
      });
    });
  });
}
