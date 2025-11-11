import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/models/anchor_point.dart' as ap;
import 'package:wiretuner/domain/models/shape.dart';

void main() {
  group('Shape', () {
    group('Factory Constructors', () {
      group('rectangle()', () {
        test('creates rectangle with required parameters', () {
          final rect = Shape.rectangle(
            center: const Point(x: 100, y: 100),
            width: 200,
            height: 150,
          );

          expect(rect.center, equals(const Point(x: 100, y: 100)));
          expect(rect.kind, equals(ShapeKind.rectangle));
          expect(rect.width, equals(200));
          expect(rect.height, equals(150));
          expect(rect.cornerRadius, equals(0));
          expect(rect.rotation, equals(0));
        });

        test('creates rectangle with corner radius', () {
          final rect = Shape.rectangle(
            center: const Point(x: 50, y: 50),
            width: 100,
            height: 80,
            cornerRadius: 10,
          );

          expect(rect.cornerRadius, equals(10));
        });

        test('creates rectangle with rotation', () {
          final rect = Shape.rectangle(
            center: const Point(x: 50, y: 50),
            width: 100,
            height: 80,
            rotation: 0.785398, // 45 degrees
          );

          expect(rect.rotation, closeTo(0.785398, 0.0001));
        });

        test('validates width is positive', () {
          expect(
            () => Shape.rectangle(
              center: const Point(x: 0, y: 0),
              width: 0,
              height: 100,
            ),
            throwsA(isA<AssertionError>()),
          );
        });

        test('validates height is positive', () {
          expect(
            () => Shape.rectangle(
              center: const Point(x: 0, y: 0),
              width: 100,
              height: -10,
            ),
            throwsA(isA<AssertionError>()),
          );
        });

        test('validates corner radius is non-negative', () {
          expect(
            () => Shape.rectangle(
              center: const Point(x: 0, y: 0),
              width: 100,
              height: 100,
              cornerRadius: -5,
            ),
            throwsA(isA<AssertionError>()),
          );
        });

        test('validates corner radius does not exceed half width', () {
          expect(
            () => Shape.rectangle(
              center: const Point(x: 0, y: 0),
              width: 100,
              height: 100,
              cornerRadius: 60,
            ),
            throwsA(isA<AssertionError>()),
          );
        });

        test('validates corner radius does not exceed half height', () {
          expect(
            () => Shape.rectangle(
              center: const Point(x: 0, y: 0),
              width: 100,
              height: 80,
              cornerRadius: 50,
            ),
            throwsA(isA<AssertionError>()),
          );
        });
      });

      group('ellipse()', () {
        test('creates ellipse with required parameters', () {
          final ellipse = Shape.ellipse(
            center: const Point(x: 100, y: 100),
            width: 200,
            height: 150,
          );

          expect(ellipse.center, equals(const Point(x: 100, y: 100)));
          expect(ellipse.kind, equals(ShapeKind.ellipse));
          expect(ellipse.width, equals(200));
          expect(ellipse.height, equals(150));
          expect(ellipse.rotation, equals(0));
        });

        test('creates circle when width equals height', () {
          final circle = Shape.ellipse(
            center: const Point(x: 50, y: 50),
            width: 100,
            height: 100,
          );

          expect(circle.width, equals(circle.height));
        });

        test('validates width is positive', () {
          expect(
            () => Shape.ellipse(
              center: const Point(x: 0, y: 0),
              width: 0,
              height: 100,
            ),
            throwsA(isA<AssertionError>()),
          );
        });

        test('validates height is positive', () {
          expect(
            () => Shape.ellipse(
              center: const Point(x: 0, y: 0),
              width: 100,
              height: 0,
            ),
            throwsA(isA<AssertionError>()),
          );
        });
      });

      group('polygon()', () {
        test('creates polygon with required parameters', () {
          final polygon = Shape.polygon(
            center: const Point(x: 100, y: 100),
            radius: 50,
          );

          expect(polygon.center, equals(const Point(x: 100, y: 100)));
          expect(polygon.kind, equals(ShapeKind.polygon));
          expect(polygon.radius, equals(50));
          expect(polygon.sides, equals(5)); // Default
          expect(polygon.rotation, equals(0));
        });

        test('creates triangle with 3 sides', () {
          final triangle = Shape.polygon(
            center: const Point(x: 0, y: 0),
            radius: 50,
            sides: 3,
          );

          expect(triangle.sides, equals(3));
        });

        test('creates hexagon with 6 sides', () {
          final hexagon = Shape.polygon(
            center: const Point(x: 0, y: 0),
            radius: 50,
            sides: 6,
          );

          expect(hexagon.sides, equals(6));
        });

        test('validates radius is positive', () {
          expect(
            () => Shape.polygon(
              center: const Point(x: 0, y: 0),
              radius: 0,
            ),
            throwsA(isA<AssertionError>()),
          );
        });

        test('validates sides is at least 3', () {
          expect(
            () => Shape.polygon(
              center: const Point(x: 0, y: 0),
              radius: 50,
              sides: 2,
            ),
            throwsA(isA<AssertionError>()),
          );
        });
      });

      group('star()', () {
        test('creates star with required parameters', () {
          final star = Shape.star(
            center: const Point(x: 100, y: 100),
            outerRadius: 60,
            innerRadius: 30,
          );

          expect(star.center, equals(const Point(x: 100, y: 100)));
          expect(star.kind, equals(ShapeKind.star));
          expect(star.radius, equals(60));
          expect(star.innerRadius, equals(30));
          expect(star.sides, equals(5)); // Default point count
          expect(star.rotation, equals(0));
        });

        test('creates 6-pointed star', () {
          final star = Shape.star(
            center: const Point(x: 0, y: 0),
            outerRadius: 50,
            innerRadius: 25,
            pointCount: 6,
          );

          expect(star.sides, equals(6));
        });

        test('validates outer radius is positive', () {
          expect(
            () => Shape.star(
              center: const Point(x: 0, y: 0),
              outerRadius: 0,
              innerRadius: 20,
            ),
            throwsA(isA<AssertionError>()),
          );
        });

        test('validates inner radius is positive', () {
          expect(
            () => Shape.star(
              center: const Point(x: 0, y: 0),
              outerRadius: 50,
              innerRadius: 0,
            ),
            throwsA(isA<AssertionError>()),
          );
        });

        test('validates inner radius is less than outer radius', () {
          expect(
            () => Shape.star(
              center: const Point(x: 0, y: 0),
              outerRadius: 50,
              innerRadius: 60,
            ),
            throwsA(isA<AssertionError>()),
          );
        });

        test('validates point count is at least 3', () {
          expect(
            () => Shape.star(
              center: const Point(x: 0, y: 0),
              outerRadius: 50,
              innerRadius: 25,
              pointCount: 2,
            ),
            throwsA(isA<AssertionError>()),
          );
        });
      });
    });

    group('toPath()', () {
      group('Rectangle', () {
        test('converts simple rectangle to closed path', () {
          final rect = Shape.rectangle(
            center: const Point(x: 50, y: 50),
            width: 100,
            height: 80,
          );

          final path = rect.toPath();

          expect(path.anchors.length, equals(4));
          expect(path.segments.length, equals(3)); // Explicit segments
          expect(path.closed, isTrue);

          // Verify corners are at expected positions
          expect(path.anchors[0].position.x, closeTo(0, 0.001)); // Top-left
          expect(path.anchors[0].position.y, closeTo(10, 0.001));
          expect(path.anchors[1].position.x, closeTo(100, 0.001)); // Top-right
          expect(
              path.anchors[2].position.x, closeTo(100, 0.001)); // Bottom-right
          expect(path.anchors[2].position.y, closeTo(90, 0.001));
          expect(path.anchors[3].position.x, closeTo(0, 0.001)); // Bottom-left

          // All anchors should be corners (no handles)
          for (final anchor in path.anchors) {
            expect(anchor.isCorner, isTrue);
          }
        });

        test('converts rounded rectangle to path with Bezier curves', () {
          final rect = Shape.rectangle(
            center: const Point(x: 50, y: 50),
            width: 100,
            height: 80,
            cornerRadius: 10,
          );

          final path = rect.toPath();

          // Rounded rectangle has 8 anchors (2 per corner for arc)
          expect(path.anchors.length, equals(8));
          expect(path.segments.length, equals(8));
          expect(path.closed, isTrue);

          // All segments should be Bezier
          for (final segment in path.segments) {
            expect(segment.isBezier, isTrue);
          }

          // All anchors should be smooth (have handles)
          for (final anchor in path.anchors) {
            expect(anchor.anchorType, equals(ap.AnchorType.smooth));
            expect(anchor.hasCurve, isTrue);
          }
        });

        test('respects rotation for rectangle', () {
          final rect = Shape.rectangle(
            center: const Point(x: 0, y: 0),
            width: 100,
            height: 100,
            rotation: 1.5708, // 90 degrees
          );

          final path = rect.toPath();

          // After 90-degree rotation, what was top-left is now top-right
          // Due to rotation, corners will be in different positions
          expect(path.anchors.length, equals(4));
        });
      });

      group('Ellipse', () {
        test('converts ellipse to path with 4 Bezier curves', () {
          final ellipse = Shape.ellipse(
            center: const Point(x: 100, y: 100),
            width: 200,
            height: 150,
          );

          final path = ellipse.toPath();

          expect(path.anchors.length, equals(4));
          expect(path.segments.length, equals(4));
          expect(path.closed, isTrue);

          // All segments should be Bezier
          for (final segment in path.segments) {
            expect(segment.isBezier, isTrue);
          }

          // All anchors should be smooth with handles
          for (final anchor in path.anchors) {
            expect(anchor.anchorType, equals(ap.AnchorType.smooth));
            expect(anchor.handleIn, isNotNull);
            expect(anchor.handleOut, isNotNull);
          }

          // Verify anchor positions (cardinal points)
          expect(path.anchors[0].position.x, closeTo(200, 0.001)); // Right
          expect(path.anchors[0].position.y, closeTo(100, 0.001));
          expect(path.anchors[1].position.x, closeTo(100, 0.001)); // Bottom
          expect(path.anchors[1].position.y, closeTo(175, 0.001));
          expect(path.anchors[2].position.x, closeTo(0, 0.001)); // Left
          expect(path.anchors[2].position.y, closeTo(100, 0.001));
          expect(path.anchors[3].position.x, closeTo(100, 0.001)); // Top
          expect(path.anchors[3].position.y, closeTo(25, 0.001));
        });

        test('converts circle to path', () {
          final circle = Shape.ellipse(
            center: const Point(x: 50, y: 50),
            width: 100,
            height: 100,
          );

          final path = circle.toPath();

          expect(path.anchors.length, equals(4));
          expect(path.closed, isTrue);
        });
      });

      group('Polygon', () {
        test('converts triangle to path', () {
          final triangle = Shape.polygon(
            center: const Point(x: 0, y: 0),
            radius: 50,
            sides: 3,
          );

          final path = triangle.toPath();

          expect(path.anchors.length, equals(3));
          expect(path.segments.length, equals(2)); // Explicit segments
          expect(path.closed, isTrue);

          // All anchors should be corners
          for (final anchor in path.anchors) {
            expect(anchor.isCorner, isTrue);
          }
        });

        test('converts hexagon to path', () {
          final hexagon = Shape.polygon(
            center: const Point(x: 100, y: 100),
            radius: 60,
            sides: 6,
          );

          final path = hexagon.toPath();

          expect(path.anchors.length, equals(6));
          expect(path.segments.length, equals(5));
          expect(path.closed, isTrue);
        });

        test('polygon vertices are equidistant from center', () {
          final pentagon = Shape.polygon(
            center: const Point(x: 0, y: 0),
            radius: 50,
            sides: 5,
          );

          final path = pentagon.toPath();

          // All vertices should be approximately 50 units from center
          for (final anchor in path.anchors) {
            final distance = anchor.position.x * anchor.position.x +
                anchor.position.y * anchor.position.y;
            expect(distance, closeTo(50 * 50, 1.0));
          }
        });
      });

      group('Star', () {
        test('converts star to path with alternating radii', () {
          final star = Shape.star(
            center: const Point(x: 100, y: 100),
            outerRadius: 60,
            innerRadius: 30,
            pointCount: 5,
          );

          final path = star.toPath();

          // Star has 2n vertices (n outer + n inner)
          expect(path.anchors.length, equals(10));
          expect(path.segments.length, equals(9));
          expect(path.closed, isTrue);

          // All anchors should be corners
          for (final anchor in path.anchors) {
            expect(anchor.isCorner, isTrue);
          }
        });

        test('star vertices alternate between outer and inner radii', () {
          final star = Shape.star(
            center: const Point(x: 0, y: 0),
            outerRadius: 60,
            innerRadius: 30,
            pointCount: 5,
          );

          final path = star.toPath();

          for (int i = 0; i < path.anchors.length; i++) {
            final anchor = path.anchors[i];
            final distanceSquared = anchor.position.x * anchor.position.x +
                anchor.position.y * anchor.position.y;

            if (i % 2 == 0) {
              // Outer points
              expect(distanceSquared, closeTo(60 * 60, 1.0));
            } else {
              // Inner points
              expect(distanceSquared, closeTo(30 * 30, 1.0));
            }
          }
        });

        test('converts 6-pointed star', () {
          final star = Shape.star(
            center: const Point(x: 50, y: 50),
            outerRadius: 40,
            innerRadius: 20,
            pointCount: 6,
          );

          final path = star.toPath();

          expect(path.anchors.length, equals(12));
        });
      });
    });

    group('Equality and CopyWith (Freezed)', () {
      test('identical shapes are equal', () {
        final shape1 = Shape.rectangle(
          center: const Point(x: 100, y: 100),
          width: 200,
          height: 150,
        );

        final shape2 = Shape.rectangle(
          center: const Point(x: 100, y: 100),
          width: 200,
          height: 150,
        );

        expect(shape1, equals(shape2));
      });

      test('different shapes are not equal', () {
        final rect = Shape.rectangle(
          center: const Point(x: 100, y: 100),
          width: 200,
          height: 150,
        );

        final circle = Shape.ellipse(
          center: const Point(x: 100, y: 100),
          width: 200,
          height: 200,
        );

        expect(rect, isNot(equals(circle)));
      });

      test('copyWith changes only specified fields', () {
        final original = Shape.rectangle(
          center: const Point(x: 100, y: 100),
          width: 200,
          height: 150,
          cornerRadius: 10,
        );

        final modified = original.copyWith(
          width: 250,
          height: 180,
        );

        expect(modified.center, equals(original.center));
        expect(modified.kind, equals(original.kind));
        expect(modified.width, equals(250));
        expect(modified.height, equals(180));
        expect(modified.cornerRadius, equals(10));
      });

      test('copyWith preserves immutability', () {
        final original = Shape.ellipse(
          center: const Point(x: 50, y: 50),
          width: 100,
          height: 80,
        );

        final modified = original.copyWith(
          center: const Point(x: 60, y: 60),
        );

        expect(original.center, equals(const Point(x: 50, y: 50)));
        expect(modified.center, equals(const Point(x: 60, y: 60)));
      });

      test('hashCode is consistent with equality', () {
        final shape1 = Shape.polygon(
          center: const Point(x: 0, y: 0),
          radius: 50,
          sides: 6,
        );

        final shape2 = Shape.polygon(
          center: const Point(x: 0, y: 0),
          radius: 50,
          sides: 6,
        );

        expect(shape1.hashCode, equals(shape2.hashCode));
      });
    });

    group('JSON Serialization (Freezed)', () {
      test('serializes rectangle to JSON', () {
        final rect = Shape.rectangle(
          center: const Point(x: 100, y: 100),
          width: 200,
          height: 150,
          cornerRadius: 10,
          rotation: 0.5,
        );

        final json = rect.toJson();

        expect(json['center'], isNotNull);
        expect(json['center']['x'], equals(100));
        expect(json['center']['y'], equals(100));
        expect(json['kind'], equals('rectangle'));
        expect(json['width'], equals(200));
        expect(json['height'], equals(150));
        expect(json['cornerRadius'], equals(10));
        expect(json['rotation'], equals(0.5));
      });

      test('deserializes rectangle from JSON', () {
        final json = {
          'center': {'x': 100.0, 'y': 100.0},
          'kind': 'rectangle',
          'width': 200.0,
          'height': 150.0,
          'cornerRadius': 10.0,
          'rotation': 0.5,
          'sides': 5, // Default fields must be present
        };

        final shape = Shape.fromJson(json);

        expect(shape.center, equals(const Point(x: 100, y: 100)));
        expect(shape.kind, equals(ShapeKind.rectangle));
        expect(shape.width, equals(200));
        expect(shape.height, equals(150));
        expect(shape.cornerRadius, equals(10));
        expect(shape.rotation, equals(0.5));
      });

      test('round-trip serialization preserves data', () {
        final original = Shape.star(
          center: const Point(x: 50, y: 75),
          outerRadius: 60,
          innerRadius: 30,
          pointCount: 7,
          rotation: 1.5,
        );

        final json = original.toJson();
        final deserialized = Shape.fromJson(json);

        expect(deserialized, equals(original));
      });

      test('serializes ellipse to JSON', () {
        final ellipse = Shape.ellipse(
          center: const Point(x: 200, y: 200),
          width: 300,
          height: 200,
        );

        final json = ellipse.toJson();

        expect(json['kind'], equals('ellipse'));
        expect(json['width'], equals(300));
        expect(json['height'], equals(200));
      });

      test('serializes polygon to JSON', () {
        final polygon = Shape.polygon(
          center: const Point(x: 0, y: 0),
          radius: 50,
          sides: 8,
        );

        final json = polygon.toJson();

        expect(json['kind'], equals('polygon'));
        expect(json['radius'], equals(50));
        expect(json['sides'], equals(8));
      });

      test('JSON can be encoded and decoded with dart:convert', () {
        final shape = Shape.star(
          center: const Point(x: 100, y: 100),
          outerRadius: 50,
          innerRadius: 25,
        );

        final jsonString = jsonEncode(shape.toJson());
        final decoded =
            Shape.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);

        expect(decoded, equals(shape));
      });
    });

    group('Edge Cases', () {
      test('handles very small dimensions', () {
        final tiny = Shape.rectangle(
          center: const Point(x: 0, y: 0),
          width: 0.1,
          height: 0.1,
        );

        final path = tiny.toPath();
        expect(path.anchors.length, equals(4));
      });

      test('handles large radius values', () {
        final large = Shape.polygon(
          center: const Point(x: 0, y: 0),
          radius: 10000,
          sides: 100,
        );

        final path = large.toPath();
        expect(path.anchors.length, equals(100));
      });

      test('handles zero rotation', () {
        final shape = Shape.star(
          center: const Point(x: 0, y: 0),
          outerRadius: 50,
          innerRadius: 25,
          rotation: 0,
        );

        final path = shape.toPath();
        expect(path.anchors.isNotEmpty, isTrue);
      });

      test('handles full rotation (2π)', () {
        final shape1 = Shape.polygon(
          center: const Point(x: 0, y: 0),
          radius: 50,
          sides: 5,
          rotation: 0,
        );

        final shape2 = Shape.polygon(
          center: const Point(x: 0, y: 0),
          radius: 50,
          sides: 5,
          rotation: 6.283185, // 2π
        );

        final path1 = shape1.toPath();
        final path2 = shape2.toPath();

        // Vertices should be in approximately the same positions
        for (int i = 0; i < path1.anchors.length; i++) {
          expect(
            path1.anchors[i].position.x,
            closeTo(path2.anchors[i].position.x, 0.001),
          );
          expect(
            path1.anchors[i].position.y,
            closeTo(path2.anchors[i].position.y, 0.001),
          );
        }
      });
    });
  });
}
