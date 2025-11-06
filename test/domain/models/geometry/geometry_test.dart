import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/models/geometry/point_extensions.dart';
import 'package:wiretuner/domain/models/geometry/rectangle.dart';
import 'package:wiretuner/domain/models/transform.dart';

void main() {
  group('Point Extensions', () {
    group('distanceTo', () {
      test('calculates correct distance for 3-4-5 triangle', () {
        final p1 = const Point(x: 0, y: 0);
        final p2 = const Point(x: 3, y: 4);
        expect(p1.distanceTo(p2), equals(5.0));
      });

      test('returns 0 for same point', () {
        final p1 = const Point(x: 5, y: 10);
        expect(p1.distanceTo(p1), equals(0.0));
      });

      test('handles negative coordinates', () {
        final p1 = const Point(x: -3, y: -4);
        final p2 = const Point(x: 0, y: 0);
        expect(p1.distanceTo(p2), equals(5.0));
      });
    });

    group('operator +', () {
      test('adds points correctly', () {
        final p1 = const Point(x: 1, y: 2);
        final p2 = const Point(x: 3, y: 4);
        final result = p1 + p2;
        expect(result.x, equals(4));
        expect(result.y, equals(6));
      });

      test('handles negative values', () {
        final p1 = const Point(x: 5, y: 10);
        final p2 = const Point(x: -2, y: -3);
        final result = p1 + p2;
        expect(result.x, equals(3));
        expect(result.y, equals(7));
      });
    });

    group('operator -', () {
      test('subtracts points correctly', () {
        final p1 = const Point(x: 5, y: 7);
        final p2 = const Point(x: 2, y: 3);
        final result = p1 - p2;
        expect(result.x, equals(3));
        expect(result.y, equals(4));
      });

      test('handles negative results', () {
        final p1 = const Point(x: 2, y: 3);
        final p2 = const Point(x: 5, y: 7);
        final result = p1 - p2;
        expect(result.x, equals(-3));
        expect(result.y, equals(-4));
      });
    });

    group('operator *', () {
      test('scales point correctly', () {
        final p = const Point(x: 2, y: 3);
        final result = p * 2.5;
        expect(result.x, equals(5.0));
        expect(result.y, equals(7.5));
      });

      test('handles negative scalar', () {
        final p = const Point(x: 2, y: 3);
        final result = p * -2;
        expect(result.x, equals(-4));
        expect(result.y, equals(-6));
      });

      test('handles zero scalar', () {
        final p = const Point(x: 5, y: 10);
        final result = p * 0;
        expect(result.x, equals(0));
        expect(result.y, equals(0));
      });
    });

    group('operator /', () {
      test('divides point correctly', () {
        final p = const Point(x: 10, y: 20);
        final result = p / 2;
        expect(result.x, equals(5));
        expect(result.y, equals(10));
      });

      test('handles fractional division', () {
        final p = const Point(x: 5, y: 10);
        final result = p / 2.5;
        expect(result.x, equals(2));
        expect(result.y, equals(4));
      });
    });

    group('operator - (unary)', () {
      test('negates point correctly', () {
        final p = const Point(x: 3, y: -4);
        final result = -p;
        expect(result.x, equals(-3));
        expect(result.y, equals(4));
      });
    });

    group('magnitude', () {
      test('calculates magnitude correctly', () {
        final p = const Point(x: 3, y: 4);
        expect(p.magnitude, equals(5.0));
      });

      test('returns 0 for origin', () {
        final p = const Point(x: 0, y: 0);
        expect(p.magnitude, equals(0.0));
      });
    });

    group('normalized', () {
      test('returns unit vector', () {
        final p = const Point(x: 3, y: 4);
        final normalized = p.normalized;
        expect(normalized.x, closeTo(0.6, 0.0001));
        expect(normalized.y, closeTo(0.8, 0.0001));
        expect(normalized.magnitude, closeTo(1.0, 0.0001));
      });

      test('returns same point for zero vector', () {
        final p = const Point(x: 0, y: 0);
        final normalized = p.normalized;
        expect(normalized.x, equals(0));
        expect(normalized.y, equals(0));
      });
    });

    group('dot', () {
      test('calculates dot product correctly', () {
        final p1 = const Point(x: 2, y: 3);
        final p2 = const Point(x: 4, y: 5);
        expect(p1.dot(p2), equals(23.0)); // 2*4 + 3*5 = 23
      });
    });

    group('cross', () {
      test('calculates cross product correctly', () {
        final p1 = const Point(x: 2, y: 3);
        final p2 = const Point(x: 4, y: 5);
        expect(p1.cross(p2), equals(-2.0)); // 2*5 - 3*4 = -2
      });
    });
  });

  group('Rectangle', () {
    group('constructor', () {
      test('creates rectangle correctly', () {
        const rect = Rectangle(x: 10, y: 20, width: 100, height: 50);
        expect(rect.x, equals(10));
        expect(rect.y, equals(20));
        expect(rect.width, equals(100));
        expect(rect.height, equals(50));
      });
    });

    group('fromLTRB', () {
      test('creates rectangle from bounds', () {
        final rect = Rectangle.fromLTRB(10, 20, 110, 70);
        expect(rect.x, equals(10));
        expect(rect.y, equals(20));
        expect(rect.width, equals(100));
        expect(rect.height, equals(50));
      });
    });

    group('fromCenter', () {
      test('creates rectangle from center point', () {
        final rect = Rectangle.fromCenter(
          center: const Point(x: 50, y: 50),
          width: 40,
          height: 30,
        );
        expect(rect.x, equals(30));
        expect(rect.y, equals(35));
        expect(rect.width, equals(40));
        expect(rect.height, equals(30));
      });
    });

    group('fromPoints', () {
      test('creates rectangle from two corner points', () {
        final rect = Rectangle.fromPoints(
          const Point(x: 10, y: 20),
          const Point(x: 110, y: 70),
        );
        expect(rect.x, equals(10));
        expect(rect.y, equals(20));
        expect(rect.width, equals(100));
        expect(rect.height, equals(50));
      });

      test('handles points in any order', () {
        final rect = Rectangle.fromPoints(
          const Point(x: 110, y: 70),
          const Point(x: 10, y: 20),
        );
        expect(rect.x, equals(10));
        expect(rect.y, equals(20));
        expect(rect.width, equals(100));
        expect(rect.height, equals(50));
      });
    });

    group('getters', () {
      test('left returns x', () {
        const rect = Rectangle(x: 10, y: 20, width: 100, height: 50);
        expect(rect.left, equals(10));
      });

      test('top returns y', () {
        const rect = Rectangle(x: 10, y: 20, width: 100, height: 50);
        expect(rect.top, equals(20));
      });

      test('right returns x + width', () {
        const rect = Rectangle(x: 10, y: 20, width: 100, height: 50);
        expect(rect.right, equals(110));
      });

      test('bottom returns y + height', () {
        const rect = Rectangle(x: 10, y: 20, width: 100, height: 50);
        expect(rect.bottom, equals(70));
      });

      test('center returns center point', () {
        const rect = Rectangle(x: 10, y: 20, width: 100, height: 50);
        final center = rect.center;
        expect(center.x, equals(60));
        expect(center.y, equals(45));
      });

      test('topLeft returns top-left corner', () {
        const rect = Rectangle(x: 10, y: 20, width: 100, height: 50);
        final corner = rect.topLeft;
        expect(corner.x, equals(10));
        expect(corner.y, equals(20));
      });

      test('bottomRight returns bottom-right corner', () {
        const rect = Rectangle(x: 10, y: 20, width: 100, height: 50);
        final corner = rect.bottomRight;
        expect(corner.x, equals(110));
        expect(corner.y, equals(70));
      });
    });

    group('containsPoint', () {
      test('returns true for point inside', () {
        const rect = Rectangle(x: 0, y: 0, width: 10, height: 10);
        expect(rect.containsPoint(const Point(x: 5, y: 5)), isTrue);
      });

      test('returns false for point outside', () {
        const rect = Rectangle(x: 0, y: 0, width: 10, height: 10);
        expect(rect.containsPoint(const Point(x: 15, y: 5)), isFalse);
      });

      test('returns true for point on edge', () {
        const rect = Rectangle(x: 0, y: 0, width: 10, height: 10);
        expect(rect.containsPoint(const Point(x: 10, y: 10)), isTrue);
        expect(rect.containsPoint(const Point(x: 0, y: 0)), isTrue);
      });
    });

    group('containsRectangle', () {
      test('returns true for rectangle inside', () {
        const outer = Rectangle(x: 0, y: 0, width: 100, height: 100);
        const inner = Rectangle(x: 10, y: 10, width: 20, height: 20);
        expect(outer.containsRectangle(inner), isTrue);
      });

      test('returns false for overlapping rectangle', () {
        const r1 = Rectangle(x: 0, y: 0, width: 10, height: 10);
        const r2 = Rectangle(x: 5, y: 5, width: 10, height: 10);
        expect(r1.containsRectangle(r2), isFalse);
      });
    });

    group('intersection', () {
      test('returns correct intersection for overlapping rectangles', () {
        const r1 = Rectangle(x: 0, y: 0, width: 10, height: 10);
        const r2 = Rectangle(x: 5, y: 5, width: 10, height: 10);
        final result = r1.intersection(r2);
        expect(result, isNotNull);
        expect(result!.x, equals(5));
        expect(result.y, equals(5));
        expect(result.width, equals(5));
        expect(result.height, equals(5));
      });

      test('returns null for non-overlapping rectangles', () {
        const r1 = Rectangle(x: 0, y: 0, width: 10, height: 10);
        const r2 = Rectangle(x: 20, y: 20, width: 10, height: 10);
        final result = r1.intersection(r2);
        expect(result, isNull);
      });

      test('handles partial overlap', () {
        const r1 = Rectangle(x: 0, y: 0, width: 10, height: 10);
        const r2 = Rectangle(x: 5, y: 0, width: 10, height: 10);
        final result = r1.intersection(r2);
        expect(result, isNotNull);
        expect(result!.x, equals(5));
        expect(result.y, equals(0));
        expect(result.width, equals(5));
        expect(result.height, equals(10));
      });

      test('handles touching edges', () {
        const r1 = Rectangle(x: 0, y: 0, width: 10, height: 10);
        const r2 = Rectangle(x: 10, y: 0, width: 10, height: 10);
        final result = r1.intersection(r2);
        expect(result, isNull);
      });
    });

    group('union', () {
      test('returns correct bounding rectangle', () {
        const r1 = Rectangle(x: 0, y: 0, width: 10, height: 10);
        const r2 = Rectangle(x: 5, y: 5, width: 10, height: 10);
        final result = r1.union(r2);
        expect(result.x, equals(0));
        expect(result.y, equals(0));
        expect(result.width, equals(15));
        expect(result.height, equals(15));
      });

      test('handles non-overlapping rectangles', () {
        const r1 = Rectangle(x: 0, y: 0, width: 10, height: 10);
        const r2 = Rectangle(x: 20, y: 20, width: 10, height: 10);
        final result = r1.union(r2);
        expect(result.x, equals(0));
        expect(result.y, equals(0));
        expect(result.width, equals(30));
        expect(result.height, equals(30));
      });
    });

    group('overlaps', () {
      test('returns true for overlapping rectangles', () {
        const r1 = Rectangle(x: 0, y: 0, width: 10, height: 10);
        const r2 = Rectangle(x: 5, y: 5, width: 10, height: 10);
        expect(r1.overlaps(r2), isTrue);
      });

      test('returns false for non-overlapping rectangles', () {
        const r1 = Rectangle(x: 0, y: 0, width: 10, height: 10);
        const r2 = Rectangle(x: 20, y: 20, width: 10, height: 10);
        expect(r1.overlaps(r2), isFalse);
      });

      test('returns false for touching edges', () {
        const r1 = Rectangle(x: 0, y: 0, width: 10, height: 10);
        const r2 = Rectangle(x: 10, y: 0, width: 10, height: 10);
        expect(r1.overlaps(r2), isFalse);
      });
    });

    group('inflate', () {
      test('expands rectangle correctly', () {
        const rect = Rectangle(x: 10, y: 10, width: 20, height: 20);
        final expanded = rect.inflate(5);
        expect(expanded.x, equals(5));
        expect(expanded.y, equals(5));
        expect(expanded.width, equals(30));
        expect(expanded.height, equals(30));
      });

      test('shrinks rectangle with negative value', () {
        const rect = Rectangle(x: 10, y: 10, width: 20, height: 20);
        final shrunk = rect.inflate(-5);
        expect(shrunk.x, equals(15));
        expect(shrunk.y, equals(15));
        expect(shrunk.width, equals(10));
        expect(shrunk.height, equals(10));
      });
    });

    group('inflateXY', () {
      test('expands rectangle with different x and y', () {
        const rect = Rectangle(x: 10, y: 10, width: 20, height: 20);
        final expanded = rect.inflateXY(5, 3);
        expect(expanded.x, equals(5));
        expect(expanded.y, equals(7));
        expect(expanded.width, equals(30));
        expect(expanded.height, equals(26));
      });
    });

    group('translate', () {
      test('moves rectangle correctly', () {
        const rect = Rectangle(x: 10, y: 10, width: 20, height: 20);
        final shifted = rect.translate(5, 3);
        expect(shifted.x, equals(15));
        expect(shifted.y, equals(13));
        expect(shifted.width, equals(20));
        expect(shifted.height, equals(20));
      });
    });

    group('equality', () {
      test('equal rectangles are equal', () {
        const r1 = Rectangle(x: 10, y: 20, width: 100, height: 50);
        const r2 = Rectangle(x: 10, y: 20, width: 100, height: 50);
        expect(r1, equals(r2));
        expect(r1.hashCode, equals(r2.hashCode));
      });

      test('different rectangles are not equal', () {
        const r1 = Rectangle(x: 10, y: 20, width: 100, height: 50);
        const r2 = Rectangle(x: 10, y: 20, width: 100, height: 51);
        expect(r1, isNot(equals(r2)));
      });
    });

    group('edge cases', () {
      test('handles zero-sized rectangle', () {
        const rect = Rectangle(x: 10, y: 10, width: 0, height: 0);
        expect(rect.isEmpty, isTrue);
        expect(rect.hasArea, isFalse);
      });

      test('handles negative width/height', () {
        const rect = Rectangle(x: 10, y: 10, width: -5, height: -5);
        expect(rect.isEmpty, isTrue);
      });

      test('handles very large coordinates', () {
        const rect = Rectangle(x: 1e10, y: 1e10, width: 1e10, height: 1e10);
        expect(rect.right, equals(2e10));
        expect(rect.bottom, equals(2e10));
      });
    });
  });

  group('Transform', () {
    group('identity', () {
      test('creates identity transform', () {
        final t = Transform.identity();
        expect(t.isIdentity, isTrue);
      });

      test('identity transform does not change points', () {
        final t = Transform.identity();
        const p = Point(x: 5, y: 10);
        final result = t.transformPoint(p);
        expect(result.x, equals(5));
        expect(result.y, equals(10));
      });
    });

    group('translate', () {
      test('moves point correctly', () {
        final t = Transform.translate(10, 20);
        const p = Point(x: 5, y: 5);
        final result = t.transformPoint(p);
        expect(result.x, equals(15));
        expect(result.y, equals(25));
      });

      test('handles negative offsets', () {
        final t = Transform.translate(-10, -20);
        const p = Point(x: 5, y: 25);
        final result = t.transformPoint(p);
        expect(result.x, equals(-5));
        expect(result.y, equals(5));
      });
    });

    group('rotate', () {
      test('rotates point 90 degrees', () {
        final t = Transform.rotate(math.pi / 2);
        const p = Point(x: 1, y: 0);
        final result = t.transformPoint(p);
        expect(result.x, closeTo(0, 0.0001));
        expect(result.y, closeTo(1, 0.0001));
      });

      test('rotates point 180 degrees', () {
        final t = Transform.rotate(math.pi);
        const p = Point(x: 1, y: 0);
        final result = t.transformPoint(p);
        expect(result.x, closeTo(-1, 0.0001));
        expect(result.y, closeTo(0, 0.0001));
      });

      test('rotates point 270 degrees', () {
        final t = Transform.rotate(3 * math.pi / 2);
        const p = Point(x: 1, y: 0);
        final result = t.transformPoint(p);
        expect(result.x, closeTo(0, 0.0001));
        expect(result.y, closeTo(-1, 0.0001));
      });
    });

    group('rotateAround', () {
      test('rotates around center point', () {
        final t = Transform.rotateAround(
          angle: math.pi / 2,
          center: const Point(x: 5, y: 5),
        );
        const p = Point(x: 6, y: 5);
        final result = t.transformPoint(p);
        expect(result.x, closeTo(5, 0.0001));
        expect(result.y, closeTo(6, 0.0001));
      });
    });

    group('scale', () {
      test('scales point correctly', () {
        final t = Transform.scale(2, 3);
        const p = Point(x: 5, y: 10);
        final result = t.transformPoint(p);
        expect(result.x, equals(10));
        expect(result.y, equals(30));
      });

      test('handles negative scale', () {
        final t = Transform.scale(-1, 1);
        const p = Point(x: 5, y: 10);
        final result = t.transformPoint(p);
        expect(result.x, equals(-5));
        expect(result.y, equals(10));
      });

      test('handles zero scale', () {
        final t = Transform.scale(0, 0);
        const p = Point(x: 5, y: 10);
        final result = t.transformPoint(p);
        expect(result.x, equals(0));
        expect(result.y, equals(0));
      });
    });

    group('uniformScale', () {
      test('scales uniformly', () {
        final t = Transform.uniformScale(2);
        const p = Point(x: 3, y: 4);
        final result = t.transformPoint(p);
        expect(result.x, equals(6));
        expect(result.y, equals(8));
      });
    });

    group('scaleAround', () {
      test('scales around center point', () {
        final t = Transform.scaleAround(
          sx: 2,
          sy: 2,
          center: const Point(x: 5, y: 5),
        );
        const p = Point(x: 10, y: 10);
        final result = t.transformPoint(p);
        expect(result.x, equals(15));
        expect(result.y, equals(15));
      });
    });

    group('compose', () {
      test('composes transforms correctly - translate then scale', () {
        final t1 = Transform.translate(10, 0);
        final t2 = Transform.scale(2, 1);
        final combined = t1.compose(t2);
        const p = Point(x: 5, y: 0);
        final result = combined.transformPoint(p);
        // First translate: (5, 0) -> (15, 0)
        // Then scale: (15, 0) -> (30, 0)
        expect(result.x, equals(30));
        expect(result.y, equals(0));
      });

      test('composes transforms correctly - scale then translate', () {
        final t1 = Transform.scale(2, 1);
        final t2 = Transform.translate(10, 0);
        final combined = t1.compose(t2);
        const p = Point(x: 5, y: 0);
        final result = combined.transformPoint(p);
        // First scale: (5, 0) -> (10, 0)
        // Then translate: (10, 0) -> (20, 0)
        expect(result.x, equals(20));
        expect(result.y, equals(0));
      });
    });

    group('transformRectangle', () {
      test('translates rectangle correctly', () {
        final t = Transform.translate(10, 20);
        const r = Rectangle(x: 0, y: 0, width: 10, height: 10);
        final result = t.transformRectangle(r);
        expect(result.x, equals(10));
        expect(result.y, equals(20));
        expect(result.width, equals(10));
        expect(result.height, equals(10));
      });

      test('scales rectangle correctly', () {
        final t = Transform.scale(2, 3);
        const r = Rectangle(x: 0, y: 0, width: 10, height: 10);
        final result = t.transformRectangle(r);
        expect(result.x, equals(0));
        expect(result.y, equals(0));
        expect(result.width, equals(20));
        expect(result.height, equals(30));
      });

      test('rotates rectangle and returns bounding box', () {
        final t = Transform.rotate(math.pi / 4); // 45 degrees
        const r = Rectangle(x: 0, y: 0, width: 10, height: 0);
        final result = t.transformRectangle(r);
        // Rotated horizontal line becomes diagonal
        expect(result.width, closeTo(math.sqrt(50), 0.0001));
        expect(result.height, closeTo(math.sqrt(50), 0.0001));
      });
    });

    group('invert', () {
      test('inverts translate transform', () {
        final t = Transform.translate(10, 20);
        final inverse = t.invert();
        expect(inverse, isNotNull);
        const p = Point(x: 5, y: 5);
        final transformed = t.transformPoint(p);
        final original = inverse!.transformPoint(transformed);
        expect(original.x, closeTo(5, 0.0001));
        expect(original.y, closeTo(5, 0.0001));
      });

      test('inverts scale transform', () {
        final t = Transform.scale(2, 3);
        final inverse = t.invert();
        expect(inverse, isNotNull);
        const p = Point(x: 10, y: 15);
        final transformed = t.transformPoint(p);
        final original = inverse!.transformPoint(transformed);
        expect(original.x, closeTo(10, 0.0001));
        expect(original.y, closeTo(15, 0.0001));
      });

      test('returns null for non-invertible transform', () {
        final t = Transform.scale(0, 0);
        final inverse = t.invert();
        expect(inverse, isNull);
      });
    });

    group('translation getter', () {
      test('extracts translation', () {
        final t = Transform.translate(10, 20);
        final translation = t.translation;
        expect(translation.x, equals(10));
        expect(translation.y, equals(20));
      });
    });

    group('rotation getter', () {
      test('extracts rotation angle', () {
        final t = Transform.rotate(math.pi / 2);
        final rotation = t.rotation;
        expect(rotation, closeTo(math.pi / 2, 0.0001));
      });
    });

    group('scale getter', () {
      test('extracts scale factors', () {
        final t = Transform.scale(2, 3);
        final scale = t.scale;
        expect(scale.x, closeTo(2, 0.0001));
        expect(scale.y, closeTo(3, 0.0001));
      });
    });

    group('equality', () {
      test('equal transforms are equal', () {
        final t1 = Transform.translate(10, 20);
        final t2 = Transform.translate(10, 20);
        expect(t1, equals(t2));
        expect(t1.hashCode, equals(t2.hashCode));
      });

      test('different transforms are not equal', () {
        final t1 = Transform.translate(10, 20);
        final t2 = Transform.translate(10, 21);
        expect(t1, isNot(equals(t2)));
      });
    });

    group('edge cases', () {
      test('handles very large coordinates', () {
        final t = Transform.translate(1e6, 1e6);
        const p = Point(x: 5, y: 5);
        final result = t.transformPoint(p);
        expect(result.x, closeTo(1e6 + 5, 0.01));
        expect(result.y, closeTo(1e6 + 5, 0.01));
      });

      test('handles multiple compositions', () {
        final t1 = Transform.translate(10, 0);
        final t2 = Transform.scale(2, 1);
        final t3 = Transform.rotate(math.pi);
        final combined = t1.compose(t2).compose(t3);
        const p = Point(x: 1, y: 0);
        final result = combined.transformPoint(p);
        // Should apply all three transformations
        expect(result, isNotNull);
      });
    });
  });
}
