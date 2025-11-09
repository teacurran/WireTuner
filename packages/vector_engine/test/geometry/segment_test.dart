import 'package:test/test.dart';
import 'package:vector_engine/vector_engine.dart';
import 'dart:math' as math;

void main() {
  group('Segment', () {
    group('construction', () {
      test('creates line segment', () {
        final segment = Segment.line(
          startAnchorIndex: 0,
          endAnchorIndex: 1,
        );
        expect(segment.startAnchorIndex, 0);
        expect(segment.endAnchorIndex, 1);
        expect(segment.segmentType, SegmentType.line);
      });

      test('creates bezier segment', () {
        final segment = Segment.bezier(
          startAnchorIndex: 0,
          endAnchorIndex: 1,
        );
        expect(segment.segmentType, SegmentType.bezier);
      });

      test('creates arc segment', () {
        final segment = Segment.arc(
          startAnchorIndex: 0,
          endAnchorIndex: 1,
        );
        expect(segment.segmentType, SegmentType.arc);
      });
    });

    group('line segment evaluation', () {
      late AnchorPoint start;
      late AnchorPoint end;
      late Segment segment;

      setUp(() {
        start = AnchorPoint.corner(position: Point(x: 0, y: 0));
        end = AnchorPoint.corner(position: Point(x: 100, y: 100));
        segment = Segment.line(startAnchorIndex: 0, endAnchorIndex: 1);
      });

      test('evaluates point at t=0', () {
        final point = segment.pointAt(0, start, end);
        expect(point, Point(x: 0, y: 0));
      });

      test('evaluates point at t=1', () {
        final point = segment.pointAt(1, start, end);
        expect(point, Point(x: 100, y: 100));
      });

      test('evaluates point at t=0.5', () {
        final point = segment.pointAt(0.5, start, end);
        expect(point, Point(x: 50, y: 50));
      });

      test('computes bounds', () {
        final bounds = segment.computeBounds(start, end);
        expect(bounds.left, 0);
        expect(bounds.top, 0);
        expect(bounds.right, 100);
        expect(bounds.bottom, 100);
      });

      test('approximates length', () {
        final length = segment.approximateLength(start, end);
        expect(length, closeTo(math.sqrt(20000), 1e-10)); // sqrt(100^2 + 100^2)
      });
    });

    group('bezier segment evaluation', () {
      late AnchorPoint start;
      late AnchorPoint end;
      late Segment segment;

      setUp(() {
        // Create a smooth curve
        start = AnchorPoint(
          position: Point(x: 0, y: 0),
          handleOut: Point(x: 50, y: 0),
          anchorType: AnchorType.corner,
        );
        end = AnchorPoint(
          position: Point(x: 100, y: 100),
          handleIn: Point(x: -50, y: 0),
          anchorType: AnchorType.corner,
        );
        segment = Segment.bezier(startAnchorIndex: 0, endAnchorIndex: 1);
      });

      test('evaluates point at t=0', () {
        final point = segment.pointAt(0, start, end);
        expect(point.x, closeTo(0, 1e-10));
        expect(point.y, closeTo(0, 1e-10));
      });

      test('evaluates point at t=1', () {
        final point = segment.pointAt(1, start, end);
        expect(point.x, closeTo(100, 1e-10));
        expect(point.y, closeTo(100, 1e-10));
      });

      test('evaluates point at t=0.5', () {
        final point = segment.pointAt(0.5, start, end);
        // For this specific curve, midpoint should be somewhere in the middle
        expect(point.x, greaterThan(0));
        expect(point.x, lessThan(100));
        expect(point.y, greaterThan(0));
        expect(point.y, lessThan(100));
      });

      test('computes bounds (conservative)', () {
        final bounds = segment.computeBounds(start, end);
        // Should include all control points
        expect(bounds.left, 0);
        expect(bounds.top, 0);
        expect(bounds.right, 100);
        expect(bounds.bottom, 100);
      });

      test('approximates length', () {
        final length = segment.approximateLength(start, end, subdivisions: 10);
        // Bezier curve should be longer than straight line
        final straightLine = start.position.distanceTo(end.position);
        expect(length, greaterThanOrEqualTo(straightLine));
      });

      test('degrades to line when handles are null', () {
        final startNoHandle = AnchorPoint.corner(position: Point(x: 0, y: 0));
        final endNoHandle = AnchorPoint.corner(position: Point(x: 100, y: 100));

        final point = segment.pointAt(0.5, startNoHandle, endNoHandle);
        // Should behave like a line
        expect(point, Point(x: 50, y: 50));
      });
    });

    group('bezier curve mathematics', () {
      test('cubic bezier evaluation at extremes', () {
        final start = AnchorPoint(
          position: Point(x: 0, y: 0),
          handleOut: Point(x: 100, y: 0),
        );
        final end = AnchorPoint(
          position: Point(x: 300, y: 300),
          handleIn: Point(x: -100, y: 0),
        );
        final segment = Segment.bezier(startAnchorIndex: 0, endAnchorIndex: 1);

        // At t=0, should be at start
        final p0 = segment.pointAt(0, start, end);
        expect(p0, start.position);

        // At t=1, should be at end
        final p1 = segment.pointAt(1, start, end);
        expect(p1, end.position);
      });

      test('cubic bezier is smooth curve', () {
        final start = AnchorPoint(
          position: Point(x: 0, y: 0),
          handleOut: Point(x: 33, y: 0),
        );
        final end = AnchorPoint(
          position: Point(x: 100, y: 0),
          handleIn: Point(x: -33, y: 100),
        );
        final segment = Segment.bezier(startAnchorIndex: 0, endAnchorIndex: 1);

        // Sample points along the curve
        final points = <Point>[];
        for (int i = 0; i <= 10; i++) {
          final t = i / 10.0;
          points.add(segment.pointAt(t, start, end));
        }

        // Verify points are monotonically increasing in x
        for (int i = 1; i < points.length; i++) {
          expect(points[i].x, greaterThanOrEqualTo(points[i - 1].x));
        }
      });
    });

    group('equality', () {
      test('segments with same properties are equal', () {
        final s1 = Segment.line(startAnchorIndex: 0, endAnchorIndex: 1);
        final s2 = Segment.line(startAnchorIndex: 0, endAnchorIndex: 1);
        expect(s1, equals(s2));
        expect(s1.hashCode, equals(s2.hashCode));
      });

      test('segments with different indices are not equal', () {
        final s1 = Segment.line(startAnchorIndex: 0, endAnchorIndex: 1);
        final s2 = Segment.line(startAnchorIndex: 0, endAnchorIndex: 2);
        expect(s1, isNot(equals(s2)));
      });

      test('segments with different types are not equal', () {
        final s1 = Segment.line(startAnchorIndex: 0, endAnchorIndex: 1);
        final s2 = Segment.bezier(startAnchorIndex: 0, endAnchorIndex: 1);
        expect(s1, isNot(equals(s2)));
      });
    });

    group('JSON serialization', () {
      test('serializes line segment to JSON', () {
        final segment = Segment.line(startAnchorIndex: 0, endAnchorIndex: 1);
        final json = segment.toJson();
        expect(json['startAnchorIndex'], 0);
        expect(json['endAnchorIndex'], 1);
        expect(json['segmentType'], 'line');
      });

      test('serializes bezier segment to JSON', () {
        final segment = Segment.bezier(startAnchorIndex: 2, endAnchorIndex: 3);
        final json = segment.toJson();
        expect(json['startAnchorIndex'], 2);
        expect(json['endAnchorIndex'], 3);
        expect(json['segmentType'], 'bezier');
      });

      test('deserializes from JSON', () {
        final json = {
          'startAnchorIndex': 0,
          'endAnchorIndex': 1,
          'segmentType': 'bezier',
        };
        final segment = Segment.fromJson(json);
        expect(segment.startAnchorIndex, 0);
        expect(segment.endAnchorIndex, 1);
        expect(segment.segmentType, SegmentType.bezier);
      });

      test('round-trips through JSON', () {
        final original = Segment.bezier(
          startAnchorIndex: 5,
          endAnchorIndex: 10,
        );
        final json = original.toJson();
        final deserialized = Segment.fromJson(json);
        expect(deserialized, equals(original));
      });
    });

    group('arc segments', () {
      test('arc segment throws unimplemented error for pointAt', () {
        final segment = Segment.arc(startAnchorIndex: 0, endAnchorIndex: 1);
        final start = AnchorPoint.corner(position: Point(x: 0, y: 0));
        final end = AnchorPoint.corner(position: Point(x: 100, y: 100));

        expect(
          () => segment.pointAt(0.5, start, end),
          throwsUnimplementedError,
        );
      });

      test('arc segment throws unimplemented error for bounds', () {
        final segment = Segment.arc(startAnchorIndex: 0, endAnchorIndex: 1);
        final start = AnchorPoint.corner(position: Point(x: 0, y: 0));
        final end = AnchorPoint.corner(position: Point(x: 100, y: 100));

        expect(
          () => segment.computeBounds(start, end),
          throwsUnimplementedError,
        );
      });
    });

    group('copyWith', () {
      test('creates copy with new start index', () {
        final original = Segment.line(startAnchorIndex: 0, endAnchorIndex: 1);
        final copy = original.copyWith(startAnchorIndex: 2);
        expect(copy.startAnchorIndex, 2);
        expect(copy.endAnchorIndex, 1);
        expect(copy.segmentType, SegmentType.line);
      });

      test('creates copy with new end index', () {
        final original = Segment.line(startAnchorIndex: 0, endAnchorIndex: 1);
        final copy = original.copyWith(endAnchorIndex: 3);
        expect(copy.startAnchorIndex, 0);
        expect(copy.endAnchorIndex, 3);
      });

      test('creates copy with new type', () {
        final original = Segment.line(startAnchorIndex: 0, endAnchorIndex: 1);
        final copy = original.copyWith(segmentType: SegmentType.bezier);
        expect(copy.segmentType, SegmentType.bezier);
      });
    });
  });
}
