import 'package:test/test.dart';
import 'package:vector_engine/vector_engine.dart';
import 'dart:math' as math;

void main() {
  group('Shape', () {
    group('rectangle construction', () {
      test('creates rectangle shape', () {
        final shape = Shape.rectangle(
          center: Point(x: 100, y: 100),
          width: 200,
          height: 150,
        );
        expect(shape.center, Point(x: 100, y: 100));
        expect(shape.kind, ShapeKind.rectangle);
        expect(shape.width, 200);
        expect(shape.height, 150);
        expect(shape.cornerRadius, 0.0);
        expect(shape.rotation, 0.0);
      });

      test('creates rectangle with corner radius', () {
        final shape = Shape.rectangle(
          center: Point(x: 100, y: 100),
          width: 200,
          height: 150,
          cornerRadius: 10,
        );
        expect(shape.cornerRadius, 10);
      });

      test('creates rotated rectangle', () {
        final shape = Shape.rectangle(
          center: Point(x: 100, y: 100),
          width: 200,
          height: 150,
          rotation: math.pi / 4,
        );
        expect(shape.rotation, math.pi / 4);
      });
    });

    group('ellipse construction', () {
      test('creates ellipse shape', () {
        final shape = Shape.ellipse(
          center: Point(x: 100, y: 100),
          width: 200,
          height: 150,
        );
        expect(shape.center, Point(x: 100, y: 100));
        expect(shape.kind, ShapeKind.ellipse);
        expect(shape.width, 200);
        expect(shape.height, 150);
      });

      test('creates circle shape', () {
        final shape = Shape.circle(
          center: Point(x: 100, y: 100),
          radius: 50,
        );
        expect(shape.kind, ShapeKind.ellipse);
        expect(shape.width, 100);
        expect(shape.height, 100);
      });
    });

    group('polygon construction', () {
      test('creates polygon shape', () {
        final shape = Shape.polygon(
          center: Point(x: 100, y: 100),
          radius: 50,
          sides: 6,
        );
        expect(shape.center, Point(x: 100, y: 100));
        expect(shape.kind, ShapeKind.polygon);
        expect(shape.radius, 50);
        expect(shape.sides, 6);
      });

      test('creates triangle (3 sides)', () {
        final shape = Shape.polygon(
          center: Point(x: 100, y: 100),
          radius: 50,
          sides: 3,
        );
        expect(shape.sides, 3);
      });
    });

    group('star construction', () {
      test('creates star shape', () {
        final shape = Shape.star(
          center: Point(x: 100, y: 100),
          outerRadius: 50,
          innerRadius: 25,
          pointCount: 5,
        );
        expect(shape.center, Point(x: 100, y: 100));
        expect(shape.kind, ShapeKind.star);
        expect(shape.radius, 50);
        expect(shape.innerRadius, 25);
        expect(shape.sides, 5);
      });
    });

    group('rectangle to path conversion', () {
      test('converts simple rectangle to path', () {
        final shape = Shape.rectangle(
          center: Point(x: 100, y: 100),
          width: 200,
          height: 150,
        );
        final path = shape.toPath();

        expect(path.anchors.length, 4); // 4 corners
        expect(path.closed, isTrue);
        expect(path.segments.length, 3); // 3 explicit + 1 implicit
      });

      test('rectangle path has correct corner positions', () {
        final shape = Shape.rectangle(
          center: Point(x: 100, y: 100),
          width: 200,
          height: 150,
        );
        final path = shape.toPath();

        // Check corners (order: TL, TR, BR, BL)
        expect(path.anchors[0].position, Point(x: 0, y: 25)); // Top-left
        expect(path.anchors[1].position, Point(x: 200, y: 25)); // Top-right
        expect(path.anchors[2].position, Point(x: 200, y: 175)); // Bottom-right
        expect(path.anchors[3].position, Point(x: 0, y: 175)); // Bottom-left
      });

      test('converts rounded rectangle to path', () {
        final shape = Shape.rectangle(
          center: Point(x: 100, y: 100),
          width: 200,
          height: 150,
          cornerRadius: 10,
        );
        final path = shape.toPath();

        // Rounded rectangle has 8 anchors (2 per corner for curves)
        expect(path.anchors.length, 8);
        expect(path.closed, isTrue);
      });

      test('rounded rectangle anchors have handles', () {
        final shape = Shape.rectangle(
          center: Point(x: 100, y: 100),
          width: 200,
          height: 150,
          cornerRadius: 10,
        );
        final path = shape.toPath();

        // All anchors should have handles for smooth corners
        for (final anchor in path.anchors) {
          expect(anchor.hasCurve, isTrue);
        }
      });

      test('corner radius is clamped to max value', () {
        final shape = Shape.rectangle(
          center: Point(x: 100, y: 100),
          width: 200,
          height: 150,
          cornerRadius: 200, // Too large
        );
        final path = shape.toPath();

        // Should still create valid path with clamped radius
        expect(path.isValid, isTrue);
        expect(path.anchors.length, 8);
      });
    });

    group('ellipse to path conversion', () {
      test('converts ellipse to path', () {
        final shape = Shape.ellipse(
          center: Point(x: 100, y: 100),
          width: 200,
          height: 150,
        );
        final path = shape.toPath();

        expect(path.anchors.length, 4); // 4 cardinal points
        expect(path.closed, isTrue);
      });

      test('ellipse path anchors have smooth handles', () {
        final shape = Shape.ellipse(
          center: Point(x: 100, y: 100),
          width: 200,
          height: 150,
        );
        final path = shape.toPath();

        for (final anchor in path.anchors) {
          expect(anchor.anchorType, AnchorType.smooth);
          expect(anchor.handleIn, isNotNull);
          expect(anchor.handleOut, isNotNull);
        }
      });

      test('circle creates symmetric ellipse path', () {
        final shape = Shape.circle(
          center: Point(x: 100, y: 100),
          radius: 50,
        );
        final path = shape.toPath();

        expect(path.anchors.length, 4);
        expect(path.closed, isTrue);
      });
    });

    group('polygon to path conversion', () {
      test('converts triangle to path', () {
        final shape = Shape.polygon(
          center: Point(x: 100, y: 100),
          radius: 50,
          sides: 3,
        );
        final path = shape.toPath();

        expect(path.anchors.length, 3);
        expect(path.closed, isTrue);
      });

      test('converts hexagon to path', () {
        final shape = Shape.polygon(
          center: Point(x: 100, y: 100),
          radius: 50,
          sides: 6,
        );
        final path = shape.toPath();

        expect(path.anchors.length, 6);
        expect(path.closed, isTrue);
      });

      test('polygon anchors are corners (no handles)', () {
        final shape = Shape.polygon(
          center: Point(x: 100, y: 100),
          radius: 50,
          sides: 5,
        );
        final path = shape.toPath();

        for (final anchor in path.anchors) {
          expect(anchor.isCorner, isTrue);
        }
      });

      test('polygon with rotation', () {
        final shape = Shape.polygon(
          center: Point(x: 100, y: 100),
          radius: 50,
          sides: 4,
          rotation: math.pi / 4,
        );
        final path = shape.toPath();

        expect(path.anchors.length, 4);
        // First anchor should be rotated
        expect(path.anchors[0].position.x, isNot(closeTo(100, 1)));
      });

      test('throws for polygon with less than 3 sides', () {
        final shape = Shape.polygon(
          center: Point(x: 100, y: 100),
          radius: 50,
          sides: 2,
        );

        expect(() => shape.toPath(), throwsArgumentError);
      });
    });

    group('star to path conversion', () {
      test('converts 5-point star to path', () {
        final shape = Shape.star(
          center: Point(x: 100, y: 100),
          outerRadius: 50,
          innerRadius: 25,
          pointCount: 5,
        );
        final path = shape.toPath();

        // Star has 2 anchors per point (outer + inner)
        expect(path.anchors.length, 10);
        expect(path.closed, isTrue);
      });

      test('star alternates between outer and inner radii', () {
        final shape = Shape.star(
          center: Point(x: 100, y: 100),
          outerRadius: 50,
          innerRadius: 25,
          pointCount: 5,
        );
        final path = shape.toPath();

        final center = shape.center;

        // Check that distances alternate between outer and inner radii
        for (int i = 0; i < path.anchors.length; i++) {
          final distance = path.anchors[i].position.distanceTo(center);
          if (i.isEven) {
            expect(distance, closeTo(50, 1e-10)); // Outer radius
          } else {
            expect(distance, closeTo(25, 1e-10)); // Inner radius
          }
        }
      });

      test('star anchors are corners', () {
        final shape = Shape.star(
          center: Point(x: 100, y: 100),
          outerRadius: 50,
          innerRadius: 25,
          pointCount: 5,
        );
        final path = shape.toPath();

        for (final anchor in path.anchors) {
          expect(anchor.isCorner, isTrue);
        }
      });

      test('throws for star with less than 3 points', () {
        final shape = Shape.star(
          center: Point(x: 100, y: 100),
          outerRadius: 50,
          innerRadius: 25,
          pointCount: 2,
        );

        expect(() => shape.toPath(), throwsArgumentError);
      });

      test('throws for star with innerRadius >= outerRadius', () {
        final shape = Shape.star(
          center: Point(x: 100, y: 100),
          outerRadius: 50,
          innerRadius: 60, // Greater than outer
          pointCount: 5,
        );

        expect(() => shape.toPath(), throwsArgumentError);
      });
    });

    group('equality', () {
      test('shapes with same properties are equal', () {
        final s1 = Shape.rectangle(
          center: Point(x: 100, y: 100),
          width: 200,
          height: 150,
        );
        final s2 = Shape.rectangle(
          center: Point(x: 100, y: 100),
          width: 200,
          height: 150,
        );
        expect(s1, equals(s2));
        expect(s1.hashCode, equals(s2.hashCode));
      });

      test('shapes with different centers are not equal', () {
        final s1 = Shape.rectangle(
          center: Point(x: 100, y: 100),
          width: 200,
          height: 150,
        );
        final s2 = Shape.rectangle(
          center: Point(x: 100, y: 101),
          width: 200,
          height: 150,
        );
        expect(s1, isNot(equals(s2)));
      });

      test('shapes with different kinds are not equal', () {
        final s1 = Shape.circle(
          center: Point(x: 100, y: 100),
          radius: 50,
        );
        final s2 = Shape.polygon(
          center: Point(x: 100, y: 100),
          radius: 50,
          sides: 10,
        );
        expect(s1, isNot(equals(s2)));
      });
    });

    group('JSON serialization', () {
      test('serializes rectangle to JSON', () {
        final shape = Shape.rectangle(
          center: Point(x: 100, y: 100),
          width: 200,
          height: 150,
          cornerRadius: 10,
        );
        final json = shape.toJson();
        // toJson returns nested Point objects, not Maps
        expect(json['center'], isA<Point>());
        expect((json['center'] as Point).x, 100.0);
        expect((json['center'] as Point).y, 100.0);
        expect(json['kind'], 'rectangle');
        expect(json['width'], 200.0);
        expect(json['height'], 150.0);
        expect(json['cornerRadius'], 10.0);
      });

      test('serializes ellipse to JSON', () {
        final shape = Shape.ellipse(
          center: Point(x: 100, y: 100),
          width: 200,
          height: 150,
        );
        final json = shape.toJson();
        expect(json['kind'], 'ellipse');
        expect(json['width'], 200.0);
        expect(json['height'], 150.0);
      });

      test('serializes polygon to JSON', () {
        final shape = Shape.polygon(
          center: Point(x: 100, y: 100),
          radius: 50,
          sides: 6,
        );
        final json = shape.toJson();
        expect(json['kind'], 'polygon');
        expect(json['radius'], 50.0);
        expect(json['sides'], 6);
      });

      test('serializes star to JSON', () {
        final shape = Shape.star(
          center: Point(x: 100, y: 100),
          outerRadius: 50,
          innerRadius: 25,
          pointCount: 5,
        );
        final json = shape.toJson();
        expect(json['kind'], 'star');
        expect(json['radius'], 50.0);
        expect(json['innerRadius'], 25.0);
        expect(json['sides'], 5);
      });

      test('deserializes rectangle from JSON', () {
        final json = {
          'center': {'x': 100.0, 'y': 100.0},
          'kind': 'rectangle',
          'width': 200.0,
          'height': 150.0,
          'cornerRadius': 10.0,
          'rotation': 0.0,
          'sides': 5,
        };
        final shape = Shape.fromJson(json);
        expect(shape.kind, ShapeKind.rectangle);
        expect(shape.width, 200.0);
        expect(shape.height, 150.0);
        expect(shape.cornerRadius, 10.0);
      });

      test('round-trips through JSON', () {
        final original = Shape.star(
          center: Point(x: 123.456, y: 789.012),
          outerRadius: 50.5,
          innerRadius: 25.25,
          pointCount: 7,
          rotation: math.pi / 6,
        );
        // Convert to JSON Map structure manually to ensure proper nesting
        final json = {
          'center': original.center.toJson(),
          'kind': original.kind.name,
          'width': original.width,
          'height': original.height,
          'cornerRadius': original.cornerRadius,
          'radius': original.radius,
          'innerRadius': original.innerRadius,
          'sides': original.sides,
          'rotation': original.rotation,
        };
        final deserialized = Shape.fromJson(json);
        expect(deserialized, equals(original));
      });
    });

    group('copyWith', () {
      test('creates copy with new center', () {
        final original = Shape.rectangle(
          center: Point(x: 100, y: 100),
          width: 200,
          height: 150,
        );
        final copy = original.copyWith(
          center: Point(x: 150, y: 150),
        );
        expect(copy.center, Point(x: 150, y: 150));
        expect(copy.width, 200);
        expect(copy.height, 150);
      });

      test('creates copy with new dimensions', () {
        final original = Shape.rectangle(
          center: Point(x: 100, y: 100),
          width: 200,
          height: 150,
        );
        final copy = original.copyWith(
          width: 300,
          height: 250,
        );
        expect(copy.width, 300);
        expect(copy.height, 250);
      });

      test('creates copy with new rotation', () {
        final original = Shape.polygon(
          center: Point(x: 100, y: 100),
          radius: 50,
          sides: 5,
        );
        final copy = original.copyWith(
          rotation: math.pi / 4,
        );
        expect(copy.rotation, math.pi / 4);
      });
    });
  });
}
