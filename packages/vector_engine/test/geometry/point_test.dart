import 'package:test/test.dart';
import 'package:vector_engine/vector_engine.dart';
import 'dart:math' as math;

void main() {
  group('Point', () {
    group('construction', () {
      test('creates point with given coordinates', () {
        final point = Point(x: 10, y: 20);
        expect(point.x, 10);
        expect(point.y, 20);
      });

      test('creates zero point', () {
        final point = Point.zero();
        expect(point.x, 0);
        expect(point.y, 0);
      });
    });

    group('equality', () {
      test('points with same coordinates are equal', () {
        final p1 = Point(x: 10, y: 20);
        final p2 = Point(x: 10, y: 20);
        expect(p1, equals(p2));
        expect(p1.hashCode, equals(p2.hashCode));
      });

      test('points with different coordinates are not equal', () {
        final p1 = Point(x: 10, y: 20);
        final p2 = Point(x: 10, y: 21);
        expect(p1, isNot(equals(p2)));
      });
    });

    group('JSON serialization', () {
      test('serializes to JSON', () {
        final point = Point(x: 10.5, y: 20.7);
        final json = point.toJson();
        expect(json, {'x': 10.5, 'y': 20.7});
      });

      test('deserializes from JSON', () {
        final json = {'x': 10.5, 'y': 20.7};
        final point = Point.fromJson(json);
        expect(point.x, 10.5);
        expect(point.y, 20.7);
      });

      test('round-trips through JSON', () {
        final original = Point(x: 123.456, y: 789.012);
        final json = original.toJson();
        final deserialized = Point.fromJson(json);
        expect(deserialized, equals(original));
      });
    });

    group('distance calculations', () {
      test('calculates distance between points', () {
        final p1 = Point(x: 0, y: 0);
        final p2 = Point(x: 3, y: 4);
        expect(p1.distanceTo(p2), 5.0);
      });

      test('distance to self is zero', () {
        final p = Point(x: 10, y: 20);
        expect(p.distanceTo(p), 0.0);
      });

      test('calculates squared distance', () {
        final p1 = Point(x: 0, y: 0);
        final p2 = Point(x: 3, y: 4);
        expect(p1.distanceSquaredTo(p2), 25.0);
      });

      test('calculates magnitude', () {
        final p = Point(x: 3, y: 4);
        expect(p.magnitude, 5.0);
      });

      test('calculates squared magnitude', () {
        final p = Point(x: 3, y: 4);
        expect(p.magnitudeSquared, 25.0);
      });
    });

    group('vector operations', () {
      test('normalizes vector', () {
        final p = Point(x: 3, y: 4);
        final normalized = p.normalize();
        expect(normalized.magnitude, closeTo(1.0, 1e-10));
        expect(normalized.x, closeTo(0.6, 1e-10));
        expect(normalized.y, closeTo(0.8, 1e-10));
      });

      test('normalizing zero vector returns zero', () {
        final p = Point.zero();
        final normalized = p.normalize();
        expect(normalized, Point.zero());
      });

      test('calculates dot product', () {
        final p1 = Point(x: 2, y: 3);
        final p2 = Point(x: 4, y: 5);
        expect(p1.dot(p2), 23.0); // 2*4 + 3*5 = 23
      });

      test('calculates cross product (2D)', () {
        final p1 = Point(x: 2, y: 3);
        final p2 = Point(x: 4, y: 5);
        expect(p1.cross(p2), -2.0); // 2*5 - 3*4 = -2
      });

      test('calculates angle', () {
        final p = Point(x: 1, y: 0);
        expect(p.angle, 0.0);

        final p2 = Point(x: 0, y: 1);
        expect(p2.angle, closeTo(math.pi / 2, 1e-10));

        final p3 = Point(x: -1, y: 0);
        expect(p3.angle, closeTo(math.pi, 1e-10));
      });

      test('calculates angle to another point', () {
        final p1 = Point(x: 0, y: 0);
        final p2 = Point(x: 1, y: 1);
        expect(p1.angleTo(p2), closeTo(math.pi / 4, 1e-10));
      });
    });

    group('arithmetic operators', () {
      test('adds points', () {
        final p1 = Point(x: 10, y: 20);
        final p2 = Point(x: 5, y: 7);
        final result = p1 + p2;
        expect(result, Point(x: 15, y: 27));
      });

      test('subtracts points', () {
        final p1 = Point(x: 10, y: 20);
        final p2 = Point(x: 5, y: 7);
        final result = p1 - p2;
        expect(result, Point(x: 5, y: 13));
      });

      test('multiplies by scalar', () {
        final p = Point(x: 10, y: 20);
        final result = p * 2.5;
        expect(result, Point(x: 25, y: 50));
      });

      test('divides by scalar', () {
        final p = Point(x: 10, y: 20);
        final result = p / 2.0;
        expect(result, Point(x: 5, y: 10));
      });

      test('negates point', () {
        final p = Point(x: 10, y: -20);
        final result = -p;
        expect(result, Point(x: -10, y: 20));
      });
    });

    group('interpolation', () {
      test('lerp at t=0 returns start point', () {
        final p1 = Point(x: 0, y: 0);
        final p2 = Point(x: 100, y: 100);
        final result = p1.lerp(p2, 0.0);
        expect(result, p1);
      });

      test('lerp at t=1 returns end point', () {
        final p1 = Point(x: 0, y: 0);
        final p2 = Point(x: 100, y: 100);
        final result = p1.lerp(p2, 1.0);
        expect(result, p2);
      });

      test('lerp at t=0.5 returns midpoint', () {
        final p1 = Point(x: 0, y: 0);
        final p2 = Point(x: 100, y: 100);
        final result = p1.lerp(p2, 0.5);
        expect(result, Point(x: 50, y: 50));
      });

      test('lerp supports extrapolation', () {
        final p1 = Point(x: 0, y: 0);
        final p2 = Point(x: 100, y: 100);
        final result = p1.lerp(p2, 2.0);
        expect(result, Point(x: 200, y: 200));
      });
    });

    group('rotation', () {
      test('rotates point around origin', () {
        final p = Point(x: 1, y: 0);
        final rotated = p.rotate(math.pi / 2); // 90 degrees
        expect(rotated.x, closeTo(0, 1e-10));
        expect(rotated.y, closeTo(1, 1e-10));
      });

      test('rotates point 180 degrees', () {
        final p = Point(x: 1, y: 0);
        final rotated = p.rotate(math.pi); // 180 degrees
        expect(rotated.x, closeTo(-1, 1e-10));
        expect(rotated.y, closeTo(0, 1e-10));
      });

      test('rotates point around custom center', () {
        final p = Point(x: 2, y: 0);
        final center = Point(x: 1, y: 0);
        final rotated = p.rotateAround(center, math.pi / 2);
        expect(rotated.x, closeTo(1, 1e-10));
        expect(rotated.y, closeTo(1, 1e-10));
      });

      test('rotating around self returns self', () {
        final p = Point(x: 10, y: 20);
        final rotated = p.rotateAround(p, math.pi / 2);
        expect(rotated.x, closeTo(p.x, 1e-10));
        expect(rotated.y, closeTo(p.y, 1e-10));
      });
    });

    group('copyWith', () {
      test('creates copy with new x', () {
        final original = Point(x: 10, y: 20);
        final copy = original.copyWith(x: 30);
        expect(copy.x, 30);
        expect(copy.y, 20);
      });

      test('creates copy with new y', () {
        final original = Point(x: 10, y: 20);
        final copy = original.copyWith(y: 40);
        expect(copy.x, 10);
        expect(copy.y, 40);
      });

      test('creates copy with both coordinates', () {
        final original = Point(x: 10, y: 20);
        final copy = original.copyWith(x: 30, y: 40);
        expect(copy.x, 30);
        expect(copy.y, 40);
      });
    });
  });
}
