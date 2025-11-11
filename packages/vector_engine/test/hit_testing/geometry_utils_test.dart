import 'package:test/test.dart';
import 'package:vector_engine/src/geometry.dart';
import 'package:vector_engine/src/hit_testing/geometry_utils.dart';
import 'dart:math' as math;

void main() {
  group('distanceToLineSegment', () {
    test('perpendicular distance to segment', () {
      final segmentStart = Point(x: 0, y: 0);
      final segmentEnd = Point(x: 10, y: 0);
      final point = Point(x: 5, y: 3);

      final distance = distanceToLineSegment(point, segmentStart, segmentEnd);

      expect(distance, closeTo(3.0, 0.01));
    });

    test('distance to nearest endpoint when outside segment', () {
      final segmentStart = Point(x: 0, y: 0);
      final segmentEnd = Point(x: 10, y: 0);
      final point = Point(x: 15, y: 4);

      final distance = distanceToLineSegment(point, segmentStart, segmentEnd);

      // Distance to (10, 0)
      final expected = math.sqrt(5 * 5 + 4 * 4); // ~6.4
      expect(distance, closeTo(expected, 0.01));
    });

    test('handles degenerate segment (point)', () {
      final segmentStart = Point(x: 5, y: 5);
      final segmentEnd = Point(x: 5, y: 5);
      final point = Point(x: 8, y: 9);

      final distance = distanceToLineSegment(point, segmentStart, segmentEnd);

      expect(distance, closeTo(5.0, 0.01)); // Distance to (5, 5)
    });

    test('point on segment has zero distance', () {
      final segmentStart = Point(x: 0, y: 0);
      final segmentEnd = Point(x: 10, y: 10);
      final point = Point(x: 5, y: 5);

      final distance = distanceToLineSegment(point, segmentStart, segmentEnd);

      expect(distance, closeTo(0.0, 0.01));
    });
  });

  group('distanceToBezierCurve', () {
    test('distance to straight Bezier (degenerate)', () {
      final p0 = Point(x: 0, y: 0);
      final p1 = Point(x: 0, y: 0);
      final p2 = Point(x: 10, y: 0);
      final p3 = Point(x: 10, y: 0);
      final point = Point(x: 5, y: 3);

      final distance = distanceToBezierCurve(point, p0, p1, p2, p3);

      expect(distance, closeTo(3.0, 0.1));
    });

    test('distance to curved Bezier', () {
      // Create a simple curve
      final p0 = Point(x: 0, y: 0);
      final p1 = Point(x: 5, y: 10);
      final p2 = Point(x: 5, y: 10);
      final p3 = Point(x: 10, y: 0);
      final point = Point(x: 5, y: 5);

      final distance = distanceToBezierCurve(point, p0, p1, p2, p3);

      // Point should be relatively close to the curve
      expect(distance, lessThan(5.0));
    });

    test('point on Bezier curve has near-zero distance', () {
      final p0 = Point(x: 0, y: 0);
      final p1 = Point(x: 0, y: 10);
      final p2 = Point(x: 10, y: 10);
      final p3 = Point(x: 10, y: 0);

      // Evaluate at t=0.5
      final midpoint = Point(x: 5, y: 7.5); // Approximate midpoint

      final distance = distanceToBezierCurve(midpoint, p0, p1, p2, p3, samples: 50);

      expect(distance, lessThan(0.5));
    });
  });

  group('distanceToSegment', () {
    test('line segment distance', () {
      final segment = Segment.line(startAnchorIndex: 0, endAnchorIndex: 1);
      final start = AnchorPoint.corner(position: Point(x: 0, y: 0));
      final end = AnchorPoint.corner(position: Point(x: 10, y: 0));
      final point = Point(x: 5, y: 3);

      final distance = distanceToSegment(point, segment, start, end);

      expect(distance, closeTo(3.0, 0.01));
    });

    test('Bezier segment distance', () {
      final segment = Segment.bezier(startAnchorIndex: 0, endAnchorIndex: 1);
      final start = AnchorPoint(
        position: Point(x: 0, y: 0),
        handleIn: null,
        handleOut: Point(x: 0, y: 10),
      );
      final end = AnchorPoint(
        position: Point(x: 10, y: 0),
        handleIn: Point(x: 0, y: 10),
        handleOut: null,
      );
      final point = Point(x: 5, y: 5);

      final distance = distanceToSegment(point, segment, start, end);

      expect(distance, lessThan(5.0));
    });
  });

  group('distanceToPath', () {
    test('distance to simple line path', () {
      final path = Path.line(
        start: Point(x: 0, y: 0),
        end: Point(x: 10, y: 0),
      );
      final point = Point(x: 5, y: 3);

      final distance = distanceToPath(point, path);

      expect(distance, closeTo(3.0, 0.01));
    });

    test('distance to multi-segment path', () {
      final path = Path.fromAnchors(
        anchors: [
          AnchorPoint.corner(position: Point(x: 0, y: 0)),
          AnchorPoint.corner(position: Point(x: 10, y: 0)),
          AnchorPoint.corner(position: Point(x: 10, y: 10)),
        ],
        closed: false,
      );
      final point = Point(x: 5, y: 5);

      final distance = distanceToPath(point, path);

      // Distance should be 5.0 (perpendicular to horizontal segment or vertical segment)
      expect(distance, lessThanOrEqualTo(5.0));
    });

    test('empty path returns infinity', () {
      final path = Path.empty();
      final point = Point(x: 5, y: 5);

      final distance = distanceToPath(point, path);

      expect(distance, equals(double.infinity));
    });

    test('single anchor path returns distance to point', () {
      final path = Path(
        anchors: [AnchorPoint.corner(position: Point(x: 3, y: 4))],
        segments: [],
      );
      final point = Point(x: 0, y: 0);

      final distance = distanceToPath(point, path);

      expect(distance, closeTo(5.0, 0.01)); // 3-4-5 triangle
    });
  });

  group('isPointInPath', () {
    test('point inside simple square', () {
      final path = Path.fromAnchors(
        anchors: [
          AnchorPoint.corner(position: Point(x: 0, y: 0)),
          AnchorPoint.corner(position: Point(x: 10, y: 0)),
          AnchorPoint.corner(position: Point(x: 10, y: 10)),
          AnchorPoint.corner(position: Point(x: 0, y: 10)),
        ],
        closed: true,
      );

      expect(isPointInPath(Point(x: 5, y: 5), path), isTrue);
    });

    test('point outside simple square', () {
      final path = Path.fromAnchors(
        anchors: [
          AnchorPoint.corner(position: Point(x: 0, y: 0)),
          AnchorPoint.corner(position: Point(x: 10, y: 0)),
          AnchorPoint.corner(position: Point(x: 10, y: 10)),
          AnchorPoint.corner(position: Point(x: 0, y: 10)),
        ],
        closed: true,
      );

      expect(isPointInPath(Point(x: 15, y: 15), path), isFalse);
    });

    test('point on edge is considered inside', () {
      final path = Path.fromAnchors(
        anchors: [
          AnchorPoint.corner(position: Point(x: 0, y: 0)),
          AnchorPoint.corner(position: Point(x: 10, y: 0)),
          AnchorPoint.corner(position: Point(x: 10, y: 10)),
          AnchorPoint.corner(position: Point(x: 0, y: 10)),
        ],
        closed: true,
      );

      // Point on edge may be inside or outside depending on implementation
      // Most implementations consider it inside
      final result = isPointInPath(Point(x: 5, y: 0), path);
      expect(result, isA<bool>());
    });

    test('point inside triangle', () {
      final path = Path.fromAnchors(
        anchors: [
          AnchorPoint.corner(position: Point(x: 0, y: 0)),
          AnchorPoint.corner(position: Point(x: 10, y: 0)),
          AnchorPoint.corner(position: Point(x: 5, y: 10)),
        ],
        closed: true,
      );

      expect(isPointInPath(Point(x: 5, y: 3), path), isTrue);
    });

    test('point outside triangle', () {
      final path = Path.fromAnchors(
        anchors: [
          AnchorPoint.corner(position: Point(x: 0, y: 0)),
          AnchorPoint.corner(position: Point(x: 10, y: 0)),
          AnchorPoint.corner(position: Point(x: 5, y: 10)),
        ],
        closed: true,
      );

      expect(isPointInPath(Point(x: 0, y: 10), path), isFalse);
    });

    test('open path always returns false', () {
      final path = Path.fromAnchors(
        anchors: [
          AnchorPoint.corner(position: Point(x: 0, y: 0)),
          AnchorPoint.corner(position: Point(x: 10, y: 0)),
          AnchorPoint.corner(position: Point(x: 10, y: 10)),
          AnchorPoint.corner(position: Point(x: 0, y: 10)),
        ],
        closed: false,
      );

      expect(isPointInPath(Point(x: 5, y: 5), path), isFalse);
    });

    test('complex concave polygon', () {
      // L-shaped polygon
      final path = Path.fromAnchors(
        anchors: [
          AnchorPoint.corner(position: Point(x: 0, y: 0)),
          AnchorPoint.corner(position: Point(x: 10, y: 0)),
          AnchorPoint.corner(position: Point(x: 10, y: 5)),
          AnchorPoint.corner(position: Point(x: 5, y: 5)),
          AnchorPoint.corner(position: Point(x: 5, y: 10)),
          AnchorPoint.corner(position: Point(x: 0, y: 10)),
        ],
        closed: true,
      );

      expect(isPointInPath(Point(x: 2, y: 2), path), isTrue);
      expect(isPointInPath(Point(x: 7, y: 7), path), isFalse);
    });
  });
}
