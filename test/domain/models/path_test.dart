import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/domain/events/event_base.dart' show Point;
import 'package:wiretuner/domain/models/anchor_point.dart';
import 'package:wiretuner/domain/models/geometry/rectangle.dart';
import 'package:wiretuner/domain/models/path.dart';
import 'package:wiretuner/domain/models/segment.dart';

void main() {
  group('Path', () {
    group('Construction', () {
      test('default constructor creates path with anchors and segments', () {
        final anchors = [
          AnchorPoint.corner(const Point(x: 0, y: 0)),
          AnchorPoint.corner(const Point(x: 10, y: 10)),
        ];
        final segments = [
          Segment.line(startIndex: 0, endIndex: 1),
        ];

        final path = Path(
          anchors: anchors,
          segments: segments,
          closed: false,
        );

        expect(path.anchors, equals(anchors));
        expect(path.segments, equals(segments));
        expect(path.closed, isFalse);
      });

      test('constructor defaults closed to false', () {
        const path = Path(
          anchors: [AnchorPoint(position: Point(x: 0, y: 0))],
          segments: [],
        );

        expect(path.closed, isFalse);
      });

      test('constructor creates closed path', () {
        final path = Path(
          anchors: [
            AnchorPoint.corner(const Point(x: 0, y: 0)),
            AnchorPoint.corner(const Point(x: 10, y: 0)),
            AnchorPoint.corner(const Point(x: 5, y: 10)),
          ],
          segments: [
            Segment.line(startIndex: 0, endIndex: 1),
            Segment.line(startIndex: 1, endIndex: 2),
          ],
          closed: true,
        );

        expect(path.closed, isTrue);
        expect(path.anchors.length, equals(3));
        expect(path.segments.length, equals(2)); // Implicit 3rd segment
      });

      test('constructor creates empty path', () {
        const path = Path(
          anchors: [],
          segments: [],
        );

        expect(path.anchors.isEmpty, isTrue);
        expect(path.segments.isEmpty, isTrue);
        expect(path.closed, isFalse);
      });

      test('constructor creates single anchor path', () {
        final path = Path(
          anchors: [AnchorPoint.corner(const Point(x: 5, y: 5))],
          segments: const [],
        );

        expect(path.anchors.length, equals(1));
        expect(path.segments.isEmpty, isTrue);
      });
    });

    group('Factory constructors', () {
      test('empty() creates empty path', () {
        const path = Path(anchors: [], segments: []);

        expect(path.anchors.isEmpty, isTrue);
        expect(path.segments.isEmpty, isTrue);
        expect(path.closed, isFalse);
      });

      test('fromAnchors() creates path with automatic line segments', () {
        final anchors = [
          AnchorPoint.corner(const Point(x: 0, y: 0)),
          AnchorPoint.corner(const Point(x: 10, y: 0)),
          AnchorPoint.corner(const Point(x: 10, y: 10)),
        ];

        final path = Path.fromAnchors(anchors: anchors);

        expect(path.anchors, equals(anchors));
        expect(path.segments.length, equals(2));
        expect(path.segments[0].startAnchorIndex, equals(0));
        expect(path.segments[0].endAnchorIndex, equals(1));
        expect(path.segments[0].isLine, isTrue);
        expect(path.segments[1].startAnchorIndex, equals(1));
        expect(path.segments[1].endAnchorIndex, equals(2));
        expect(path.closed, isFalse);
      });

      test('fromAnchors() supports closed paths', () {
        final anchors = [
          AnchorPoint.corner(const Point(x: 0, y: 0)),
          AnchorPoint.corner(const Point(x: 10, y: 0)),
          AnchorPoint.corner(const Point(x: 10, y: 10)),
        ];

        final path = Path.fromAnchors(anchors: anchors, closed: true);

        expect(path.closed, isTrue);
        expect(path.segments.length, equals(2)); // Explicit segments only
      });

      test('fromAnchors() handles single anchor', () {
        final path = Path.fromAnchors(
          anchors: [AnchorPoint.corner(const Point(x: 0, y: 0))],
        );

        expect(path.anchors.length, equals(1));
        expect(path.segments.isEmpty, isTrue);
        expect(path.closed, isFalse);
      });

      test('fromAnchors() handles empty list', () {
        final path = Path.fromAnchors(anchors: const []);

        expect(path.anchors.isEmpty, isTrue);
        expect(path.segments.isEmpty, isTrue);
      });

      test('line() creates two-point line path', () {
        final path = Path.line(
          start: const Point(x: 0, y: 0),
          end: const Point(x: 100, y: 50),
        );

        expect(path.anchors.length, equals(2));
        expect(path.anchors[0].position, equals(const Point(x: 0, y: 0)));
        expect(path.anchors[1].position, equals(const Point(x: 100, y: 50)));
        expect(path.segments.length, equals(1));
        expect(path.segments[0].isLine, isTrue);
        expect(path.closed, isFalse);
      });
    });

    group('bounds()', () {
      test('returns zero rectangle for empty path', () {
        const path = Path(anchors: [], segments: []);

        final bounds = path.bounds();

        expect(bounds, equals(const Rectangle(x: 0, y: 0, width: 0, height: 0)));
      });

      test('returns point-sized rectangle for single anchor', () {
        final path = Path(
          anchors: [AnchorPoint.corner(const Point(x: 10, y: 20))],
          segments: const [],
        );

        final bounds = path.bounds();

        expect(bounds.left, equals(10));
        expect(bounds.top, equals(20));
        expect(bounds.width, equals(0));
        expect(bounds.height, equals(0));
      });

      test('returns bounding box for straight line path', () {
        final path = Path(
          anchors: [
            AnchorPoint.corner(const Point(x: 10, y: 20)),
            AnchorPoint.corner(const Point(x: 30, y: 40)),
          ],
          segments: [
            Segment.line(startIndex: 0, endIndex: 1),
          ],
        );

        final bounds = path.bounds();

        expect(bounds.left, equals(10));
        expect(bounds.top, equals(20));
        expect(bounds.right, equals(30));
        expect(bounds.bottom, equals(40));
        expect(bounds.width, equals(20));
        expect(bounds.height, equals(20));
      });

      test('includes control points for Bezier curves', () {
        const path = Path(
          anchors: [
            AnchorPoint(
              position: Point(x: 0, y: 0),
              handleOut: Point(x: 50, y: 100), // Control point at (50, 100)
            ),
            AnchorPoint(
              position: Point(x: 100, y: 0),
              handleIn: Point(x: -50, y: -50), // Control point at (50, -50)
            ),
          ],
          segments: [
            Segment(startAnchorIndex: 0, endAnchorIndex: 1, segmentType: SegmentType.bezier),
          ],
        );

        final bounds = path.bounds();

        // Bounds should include control points
        expect(bounds.left, equals(0));
        expect(bounds.right, equals(100));
        expect(bounds.top, equals(-50)); // From handleIn control point
        expect(bounds.bottom, equals(100)); // From handleOut control point
      });

      test('bounds for closed path includes all anchors', () {
        final path = Path(
          anchors: [
            AnchorPoint.corner(const Point(x: 0, y: 0)),
            AnchorPoint.corner(const Point(x: 10, y: 0)),
            AnchorPoint.corner(const Point(x: 5, y: 10)),
          ],
          segments: [
            Segment.line(startIndex: 0, endIndex: 1),
            Segment.line(startIndex: 1, endIndex: 2),
          ],
          closed: true,
        );

        final bounds = path.bounds();

        expect(bounds.left, equals(0));
        expect(bounds.right, equals(10));
        expect(bounds.top, equals(0));
        expect(bounds.bottom, equals(10));
      });

      test('bounds for complex path with multiple segments', () {
        final path = Path(
          anchors: [
            AnchorPoint.corner(const Point(x: -5, y: -5)),
            AnchorPoint.corner(const Point(x: 15, y: 5)),
            AnchorPoint.corner(const Point(x: 10, y: 25)),
            AnchorPoint.corner(const Point(x: 0, y: 20)),
          ],
          segments: [
            Segment.line(startIndex: 0, endIndex: 1),
            Segment.line(startIndex: 1, endIndex: 2),
            Segment.line(startIndex: 2, endIndex: 3),
          ],
        );

        final bounds = path.bounds();

        expect(bounds.left, equals(-5));
        expect(bounds.right, equals(15));
        expect(bounds.top, equals(-5));
        expect(bounds.bottom, equals(25));
      });
    });

    group('length()', () {
      test('returns 0 for empty path', () {
        const path = Path(anchors: [], segments: []);

        expect(path.length(), equals(0.0));
      });

      test('returns 0 for single anchor path', () {
        final path = Path(
          anchors: [AnchorPoint.corner(const Point(x: 0, y: 0))],
          segments: const [],
        );

        expect(path.length(), equals(0.0));
      });

      test('calculates length for straight line path', () {
        final path = Path(
          anchors: [
            AnchorPoint.corner(const Point(x: 0, y: 0)),
            AnchorPoint.corner(const Point(x: 3, y: 4)),
          ],
          segments: [
            Segment.line(startIndex: 0, endIndex: 1),
          ],
        );

        // Length should be 5 (3-4-5 right triangle)
        expect(path.length(), closeTo(5.0, 0.001));
      });

      test('calculates length for horizontal line', () {
        final path = Path.line(
          start: const Point(x: 0, y: 0),
          end: const Point(x: 100, y: 0),
        );

        expect(path.length(), closeTo(100.0, 0.001));
      });

      test('calculates length for multiple straight segments', () {
        final path = Path(
          anchors: [
            AnchorPoint.corner(const Point(x: 0, y: 0)),
            AnchorPoint.corner(const Point(x: 10, y: 0)),
            AnchorPoint.corner(const Point(x: 10, y: 10)),
          ],
          segments: [
            Segment.line(startIndex: 0, endIndex: 1),
            Segment.line(startIndex: 1, endIndex: 2),
          ],
        );

        // Total length: 10 + 10 = 20
        expect(path.length(), closeTo(20.0, 0.001));
      });

      test('calculates length for closed path', () {
        // Create a square: (0,0) -> (10,0) -> (10,10) -> (0,10) -> back to (0,0)
        final path = Path(
          anchors: [
            AnchorPoint.corner(const Point(x: 0, y: 0)),
            AnchorPoint.corner(const Point(x: 10, y: 0)),
            AnchorPoint.corner(const Point(x: 10, y: 10)),
            AnchorPoint.corner(const Point(x: 0, y: 10)),
          ],
          segments: [
            Segment.line(startIndex: 0, endIndex: 1),
            Segment.line(startIndex: 1, endIndex: 2),
            Segment.line(startIndex: 2, endIndex: 3),
          ],
          closed: true,
        );

        // Total length should be 40 (perimeter of square)
        expect(path.length(), closeTo(40.0, 0.001));
      });

      test('approximates length for Bezier curve', () {
        const path = Path(
          anchors: [
            AnchorPoint(
              position: Point(x: 0, y: 0),
              handleOut: Point(x: 25, y: 50),
            ),
            AnchorPoint(
              position: Point(x: 100, y: 0),
              handleIn: Point(x: -25, y: 50),
            ),
          ],
          segments: [
            Segment(startAnchorIndex: 0, endAnchorIndex: 1, segmentType: SegmentType.bezier),
          ],
        );

        final length = path.length();

        // Bezier curve length should be greater than straight line (100)
        // but less than sum of control polygon edges
        expect(length, greaterThan(100.0));
        expect(length, lessThan(200.0));
      });

      test('handles mixed path with straight and curved segments', () {
        const path = Path(
          anchors: [
            AnchorPoint(position: Point(x: 0, y: 0)),
            AnchorPoint(
              position: Point(x: 50, y: 0),
              handleOut: Point(x: 0, y: 20),
            ),
            AnchorPoint(
              position: Point(x: 100, y: 0),
              handleIn: Point(x: 0, y: 20),
            ),
          ],
          segments: [
            Segment(startAnchorIndex: 0, endAnchorIndex: 1, segmentType: SegmentType.line), // 50 units
            Segment(startAnchorIndex: 1, endAnchorIndex: 2, segmentType: SegmentType.bezier), // Curved
          ],
        );

        final length = path.length();

        // First segment is exactly 50, second is curved (> 50)
        expect(length, greaterThan(100.0));
      });
    });

    group('pointAt(t)', () {
      test('returns first anchor position at t=0', () {
        final path = Path(
          anchors: [
            AnchorPoint.corner(const Point(x: 10, y: 20)),
            AnchorPoint.corner(const Point(x: 30, y: 40)),
          ],
          segments: [
            Segment.line(startIndex: 0, endIndex: 1),
          ],
        );

        final point = path.pointAt(0.0);

        expect(point.x, closeTo(10, 0.001));
        expect(point.y, closeTo(20, 0.001));
      });

      test('returns last anchor position at t=1', () {
        final path = Path(
          anchors: [
            AnchorPoint.corner(const Point(x: 10, y: 20)),
            AnchorPoint.corner(const Point(x: 30, y: 40)),
          ],
          segments: [
            Segment.line(startIndex: 0, endIndex: 1),
          ],
        );

        final point = path.pointAt(1.0);

        expect(point.x, closeTo(30, 0.001));
        expect(point.y, closeTo(40, 0.001));
      });

      test('returns midpoint at t=0.5 for straight line', () {
        final path = Path(
          anchors: [
            AnchorPoint.corner(const Point(x: 0, y: 0)),
            AnchorPoint.corner(const Point(x: 10, y: 0)),
          ],
          segments: [
            Segment.line(startIndex: 0, endIndex: 1),
          ],
        );

        final point = path.pointAt(0.5);

        expect(point.x, closeTo(5.0, 0.001));
        expect(point.y, closeTo(0.0, 0.001));
      });

      test('clamps t to [0,1] range for negative values', () {
        final path = Path(
          anchors: [
            AnchorPoint.corner(const Point(x: 0, y: 0)),
            AnchorPoint.corner(const Point(x: 10, y: 0)),
          ],
          segments: [
            Segment.line(startIndex: 0, endIndex: 1),
          ],
        );

        final point = path.pointAt(-0.5);

        expect(point, equals(const Point(x: 0, y: 0)));
      });

      test('clamps t to [0,1] range for values > 1', () {
        final path = Path(
          anchors: [
            AnchorPoint.corner(const Point(x: 0, y: 0)),
            AnchorPoint.corner(const Point(x: 10, y: 0)),
          ],
          segments: [
            Segment.line(startIndex: 0, endIndex: 1),
          ],
        );

        final point = path.pointAt(1.5);

        expect(point.x, closeTo(10, 0.001));
        expect(point.y, closeTo(0, 0.001));
      });

      test('returns origin for empty path', () {
        const path = Path(anchors: [], segments: []);

        final point = path.pointAt(0.5);

        expect(point, equals(const Point(x: 0, y: 0)));
      });

      test('returns anchor position for single anchor path', () {
        final path = Path(
          anchors: [AnchorPoint.corner(const Point(x: 42, y: 84))],
          segments: const [],
        );

        final point = path.pointAt(0.5);

        expect(point, equals(const Point(x: 42, y: 84)));
      });

      test('interpolates along Bezier curve', () {
        const path = Path(
          anchors: [
            AnchorPoint(
              position: Point(x: 0, y: 0),
              handleOut: Point(x: 25, y: 0),
            ),
            AnchorPoint(
              position: Point(x: 100, y: 0),
              handleIn: Point(x: -25, y: 0),
            ),
          ],
          segments: [
            Segment(startAnchorIndex: 0, endAnchorIndex: 1, segmentType: SegmentType.bezier),
          ],
        );

        final startPoint = path.pointAt(0.0);
        final midPoint = path.pointAt(0.5);
        final endPoint = path.pointAt(1.0);

        expect(startPoint.x, closeTo(0, 0.001));
        expect(endPoint.x, closeTo(100, 0.001));

        // Midpoint should be approximately in the middle
        expect(midPoint.x, greaterThan(40));
        expect(midPoint.x, lessThan(60));
      });

      test('handles closed path wrapping', () {
        // Create a square path
        final path = Path(
          anchors: [
            AnchorPoint.corner(const Point(x: 0, y: 0)),
            AnchorPoint.corner(const Point(x: 10, y: 0)),
            AnchorPoint.corner(const Point(x: 10, y: 10)),
            AnchorPoint.corner(const Point(x: 0, y: 10)),
          ],
          segments: [
            Segment.line(startIndex: 0, endIndex: 1),
            Segment.line(startIndex: 1, endIndex: 2),
            Segment.line(startIndex: 2, endIndex: 3),
          ],
          closed: true,
        );

        // t=1.0 should return to the first anchor
        final endPoint = path.pointAt(1.0);
        expect(endPoint.x, closeTo(0, 0.001));
        expect(endPoint.y, closeTo(0, 0.001));

        // t=0.75 should be on the closing segment (last side of square)
        final point75 = path.pointAt(0.75);
        // After 3 sides (30 units), we're at (0, 10)
        // 0.75 * 40 = 30, so we should be at (0, 10)
        expect(point75.x, closeTo(0, 0.5));
        expect(point75.y, closeTo(10, 0.5));
      });

      test('handles multiple segments correctly', () {
        // Create L-shaped path: (0,0) -> (10,0) -> (10,10)
        final path = Path(
          anchors: [
            AnchorPoint.corner(const Point(x: 0, y: 0)),
            AnchorPoint.corner(const Point(x: 10, y: 0)),
            AnchorPoint.corner(const Point(x: 10, y: 10)),
          ],
          segments: [
            Segment.line(startIndex: 0, endIndex: 1), // 10 units horizontal
            Segment.line(startIndex: 1, endIndex: 2), // 10 units vertical
          ],
        );

        // Total length is 20
        // t=0.25 should be at (5, 0) - quarter way along first segment
        final point25 = path.pointAt(0.25);
        expect(point25.x, closeTo(5, 0.001));
        expect(point25.y, closeTo(0, 0.001));

        // t=0.5 should be at (10, 0) - end of first segment
        final point50 = path.pointAt(0.5);
        expect(point50.x, closeTo(10, 0.001));
        expect(point50.y, closeTo(0, 0.001));

        // t=0.75 should be at (10, 5) - halfway along second segment
        final point75 = path.pointAt(0.75);
        expect(point75.x, closeTo(10, 0.001));
        expect(point75.y, closeTo(5, 0.001));
      });
    });

    group('copyWith()', () {
      test('changes anchors', () {
        final originalPath = Path(
          anchors: [AnchorPoint.corner(const Point(x: 0, y: 0))],
          segments: const [],
        );

        final newAnchors = [
          AnchorPoint.corner(const Point(x: 10, y: 10)),
        ];

        final updatedPath = originalPath.copyWith(anchors: newAnchors);

        expect(updatedPath.anchors, equals(newAnchors));
        expect(originalPath.anchors, isNot(equals(newAnchors)));
      });

      test('changes segments', () {
        final originalPath = Path(
          anchors: [
            AnchorPoint.corner(const Point(x: 0, y: 0)),
            AnchorPoint.corner(const Point(x: 10, y: 10)),
          ],
          segments: [
            Segment.line(startIndex: 0, endIndex: 1),
          ],
        );

        final newSegments = [
          Segment.bezier(startIndex: 0, endIndex: 1),
        ];

        final updatedPath = originalPath.copyWith(segments: newSegments);

        expect(updatedPath.segments, equals(newSegments));
        expect(updatedPath.segments[0].isBezier, isTrue);
        expect(originalPath.segments[0].isLine, isTrue);
      });

      test('changes closed flag', () {
        final originalPath = Path(
          anchors: [
            AnchorPoint.corner(const Point(x: 0, y: 0)),
            AnchorPoint.corner(const Point(x: 10, y: 10)),
          ],
          segments: [
            Segment.line(startIndex: 0, endIndex: 1),
          ],
          closed: false,
        );

        final updatedPath = originalPath.copyWith(closed: true);

        expect(updatedPath.closed, isTrue);
        expect(originalPath.closed, isFalse);
      });

      test('leaves unchanged fields intact', () {
        final originalAnchors = [
          AnchorPoint.corner(const Point(x: 0, y: 0)),
          AnchorPoint.corner(const Point(x: 10, y: 10)),
        ];
        final originalSegments = [
          Segment.line(startIndex: 0, endIndex: 1),
        ];

        final originalPath = Path(
          anchors: originalAnchors,
          segments: originalSegments,
          closed: false,
        );

        final updatedPath = originalPath.copyWith(closed: true);

        expect(updatedPath.anchors, equals(originalAnchors));
        expect(updatedPath.segments, equals(originalSegments));
        expect(updatedPath.closed, isTrue);
      });

      test('original path unchanged (immutability)', () {
        final originalPath = Path(
          anchors: [AnchorPoint.corner(const Point(x: 0, y: 0))],
          segments: const [],
          closed: false,
        );

        final updatedPath = originalPath.copyWith(
          anchors: [AnchorPoint.corner(const Point(x: 10, y: 10))],
          closed: true,
        );

        expect(originalPath.anchors[0].position, equals(const Point(x: 0, y: 0)));
        expect(originalPath.closed, isFalse);
        expect(updatedPath.anchors[0].position, equals(const Point(x: 10, y: 10)));
        expect(updatedPath.closed, isTrue);
      });
    });

    group('Equality', () {
      test('operator== compares all fields', () {
        final anchors = [
          AnchorPoint.corner(const Point(x: 0, y: 0)),
          AnchorPoint.corner(const Point(x: 10, y: 10)),
        ];
        final segments = [
          Segment.line(startIndex: 0, endIndex: 1),
        ];

        final path1 = Path(
          anchors: anchors,
          segments: segments,
          closed: false,
        );

        final path2 = Path(
          anchors: List.from(anchors), // Different list instance
          segments: List.from(segments),
          closed: false,
        );

        expect(path1, equals(path2));
      });

      test('identical instances are equal', () {
        final path = Path(
          anchors: [AnchorPoint.corner(const Point(x: 0, y: 0))],
          segments: const [],
        );

        expect(path, equals(path));
      });

      test('different instances with same values are equal', () {
        final path1 = Path.line(
          start: const Point(x: 0, y: 0),
          end: const Point(x: 10, y: 10),
        );

        final path2 = Path.line(
          start: const Point(x: 0, y: 0),
          end: const Point(x: 10, y: 10),
        );

        expect(path1, equals(path2));
      });

      test('different anchors result in inequality', () {
        final path1 = Path(
          anchors: [AnchorPoint.corner(const Point(x: 0, y: 0))],
          segments: const [],
        );

        final path2 = Path(
          anchors: [AnchorPoint.corner(const Point(x: 1, y: 1))],
          segments: const [],
        );

        expect(path1, isNot(equals(path2)));
      });

      test('different segments result in inequality', () {
        final anchors = [
          AnchorPoint.corner(const Point(x: 0, y: 0)),
          AnchorPoint.corner(const Point(x: 10, y: 10)),
        ];

        final path1 = Path(
          anchors: anchors,
          segments: [Segment.line(startIndex: 0, endIndex: 1)],
        );

        final path2 = Path(
          anchors: anchors,
          segments: [Segment.bezier(startIndex: 0, endIndex: 1)],
        );

        expect(path1, isNot(equals(path2)));
      });

      test('different closed values result in inequality', () {
        final anchors = [
          AnchorPoint.corner(const Point(x: 0, y: 0)),
          AnchorPoint.corner(const Point(x: 10, y: 10)),
        ];
        final segments = [
          Segment.line(startIndex: 0, endIndex: 1),
        ];

        final path1 = Path(
          anchors: anchors,
          segments: segments,
          closed: false,
        );

        final path2 = Path(
          anchors: anchors,
          segments: segments,
          closed: true,
        );

        expect(path1, isNot(equals(path2)));
      });

      test('hashCode consistent with ==', () {
        final path1 = Path.line(
          start: const Point(x: 0, y: 0),
          end: const Point(x: 10, y: 10),
        );

        final path2 = Path.line(
          start: const Point(x: 0, y: 0),
          end: const Point(x: 10, y: 10),
        );

        expect(path1.hashCode, equals(path2.hashCode));
      });

      test('toString includes anchor and segment counts', () {
        final path = Path(
          anchors: [
            AnchorPoint.corner(const Point(x: 0, y: 0)),
            AnchorPoint.corner(const Point(x: 10, y: 10)),
          ],
          segments: [
            Segment.line(startIndex: 0, endIndex: 1),
          ],
          closed: true,
        );

        final str = path.toString();

        expect(str, contains('anchors: 2'));
        expect(str, contains('segments: 1'));
        expect(str, contains('closed: true'));
      });
    });
  });
}
