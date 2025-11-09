import 'package:test/test.dart';
import 'package:vector_engine/vector_engine.dart';

void main() {
  group('Path', () {
    group('construction', () {
      test('creates path with anchors and segments', () {
        final anchors = [
          AnchorPoint.corner(position: Point(x: 0, y: 0)),
          AnchorPoint.corner(position: Point(x: 100, y: 100)),
        ];
        final segments = [
          Segment.line(startAnchorIndex: 0, endAnchorIndex: 1),
        ];
        final path = Path(anchors: anchors, segments: segments);

        expect(path.anchors.length, 2);
        expect(path.segments.length, 1);
        expect(path.closed, isFalse);
      });

      test('creates empty path', () {
        final path = Path.empty();
        expect(path.isEmpty, isTrue);
        expect(path.anchors.length, 0);
        expect(path.segments.length, 0);
      });

      test('creates path from anchors with automatic segments', () {
        final anchors = [
          AnchorPoint.corner(position: Point(x: 0, y: 0)),
          AnchorPoint.corner(position: Point(x: 100, y: 0)),
          AnchorPoint.corner(position: Point(x: 100, y: 100)),
        ];
        final path = Path.fromAnchors(anchors: anchors);

        expect(path.anchors.length, 3);
        expect(path.segments.length, 2);
        expect(path.segments[0].segmentType, SegmentType.line);
      });

      test('creates closed path from anchors', () {
        final anchors = [
          AnchorPoint.corner(position: Point(x: 0, y: 0)),
          AnchorPoint.corner(position: Point(x: 100, y: 0)),
          AnchorPoint.corner(position: Point(x: 100, y: 100)),
        ];
        final path = Path.fromAnchors(anchors: anchors, closed: true);

        expect(path.closed, isTrue);
        expect(path.effectiveSegmentCount, 3); // 2 explicit + 1 implicit
      });

      test('creates simple line path', () {
        final path = Path.line(
          start: Point(x: 0, y: 0),
          end: Point(x: 100, y: 100),
        );

        expect(path.anchors.length, 2);
        expect(path.segments.length, 1);
        expect(path.closed, isFalse);
      });
    });

    group('properties', () {
      test('isEmpty returns true for empty path', () {
        final path = Path.empty();
        expect(path.isEmpty, isTrue);
        expect(path.isNotEmpty, isFalse);
      });

      test('isEmpty returns false for non-empty path', () {
        final path = Path.line(
          start: Point(x: 0, y: 0),
          end: Point(x: 100, y: 100),
        );
        expect(path.isEmpty, isFalse);
        expect(path.isNotEmpty, isTrue);
      });

      test('isValid returns true for path with 2+ anchors', () {
        final path = Path.line(
          start: Point(x: 0, y: 0),
          end: Point(x: 100, y: 100),
        );
        expect(path.isValid, isTrue);
      });

      test('isValid returns false for path with <2 anchors', () {
        final path = Path(
          anchors: [AnchorPoint.corner(position: Point(x: 0, y: 0))],
          segments: [],
        );
        expect(path.isValid, isFalse);
      });

      test('effectiveSegmentCount includes implicit closing segment', () {
        final path = Path.fromAnchors(
          anchors: [
            AnchorPoint.corner(position: Point(x: 0, y: 0)),
            AnchorPoint.corner(position: Point(x: 100, y: 0)),
            AnchorPoint.corner(position: Point(x: 100, y: 100)),
          ],
          closed: true,
        );
        expect(path.effectiveSegmentCount, 3);
      });

      test('allSegments includes implicit closing segment', () {
        final path = Path.fromAnchors(
          anchors: [
            AnchorPoint.corner(position: Point(x: 0, y: 0)),
            AnchorPoint.corner(position: Point(x: 100, y: 0)),
            AnchorPoint.corner(position: Point(x: 100, y: 100)),
          ],
          closed: true,
        );
        final allSegs = path.allSegments;
        expect(allSegs.length, 3);
        expect(allSegs.last.startAnchorIndex, 2);
        expect(allSegs.last.endAnchorIndex, 0);
      });
    });

    group('bounds calculation', () {
      test('computes bounds for simple line', () {
        final path = Path.line(
          start: Point(x: 10, y: 20),
          end: Point(x: 110, y: 120),
        );
        final bounds = path.bounds();
        expect(bounds.left, 10);
        expect(bounds.top, 20);
        expect(bounds.right, 110);
        expect(bounds.bottom, 120);
      });

      test('computes bounds including handles', () {
        final path = Path(
          anchors: [
            AnchorPoint(
              position: Point(x: 0, y: 0),
              handleOut: Point(x: 50, y: 100), // Extends to (50, 100)
            ),
            AnchorPoint.corner(position: Point(x: 100, y: 0)),
          ],
          segments: [Segment.bezier(startAnchorIndex: 0, endAnchorIndex: 1)],
        );
        final bounds = path.bounds();
        expect(bounds.left, 0);
        expect(bounds.top, 0);
        expect(bounds.right, 100);
        expect(bounds.bottom, 100); // Includes handle extension
      });

      test('returns zero bounds for empty path', () {
        final path = Path.empty();
        final bounds = path.bounds();
        expect(bounds, Bounds.zero());
      });
    });

    group('length calculation', () {
      test('calculates length of simple line', () {
        final path = Path.line(
          start: Point(x: 0, y: 0),
          end: Point(x: 3, y: 4),
        );
        final length = path.length();
        expect(length, closeTo(5.0, 1e-10));
      });

      test('calculates length of multi-segment path', () {
        final path = Path.fromAnchors(
          anchors: [
            AnchorPoint.corner(position: Point(x: 0, y: 0)),
            AnchorPoint.corner(position: Point(x: 10, y: 0)),
            AnchorPoint.corner(position: Point(x: 10, y: 10)),
          ],
        );
        final length = path.length();
        expect(length, closeTo(20.0, 1e-10)); // 10 + 10
      });

      test('includes closing segment for closed path', () {
        final path = Path.fromAnchors(
          anchors: [
            AnchorPoint.corner(position: Point(x: 0, y: 0)),
            AnchorPoint.corner(position: Point(x: 10, y: 0)),
            AnchorPoint.corner(position: Point(x: 10, y: 10)),
          ],
          closed: true,
        );
        final length = path.length();
        // 10 + 10 + sqrt(10^2 + 10^2)
        expect(length, closeTo(20 + 14.142135623730951, 1e-10));
      });

      test('returns 0 for empty path', () {
        final path = Path.empty();
        expect(path.length(), 0.0);
      });
    });

    group('pointAt evaluation', () {
      test('evaluates point at t=0', () {
        final path = Path.line(
          start: Point(x: 0, y: 0),
          end: Point(x: 100, y: 100),
        );
        final point = path.pointAt(0);
        expect(point, Point(x: 0, y: 0));
      });

      test('evaluates point at t=1', () {
        final path = Path.line(
          start: Point(x: 0, y: 0),
          end: Point(x: 100, y: 100),
        );
        final point = path.pointAt(1);
        expect(point, Point(x: 100, y: 100));
      });

      test('evaluates point at t=0.5', () {
        final path = Path.line(
          start: Point(x: 0, y: 0),
          end: Point(x: 100, y: 100),
        );
        final point = path.pointAt(0.5);
        expect(point, Point(x: 50, y: 50));
      });

      test('evaluates point on multi-segment path', () {
        final path = Path.fromAnchors(
          anchors: [
            AnchorPoint.corner(position: Point(x: 0, y: 0)),
            AnchorPoint.corner(position: Point(x: 100, y: 0)),
            AnchorPoint.corner(position: Point(x: 100, y: 100)),
          ],
        );
        // t=0.5 should be halfway through the path (at the second anchor)
        final point = path.pointAt(0.5);
        expect(point, Point(x: 100, y: 0));
      });

      test('throws on empty path', () {
        final path = Path.empty();
        expect(() => path.pointAt(0.5), throwsStateError);
      });

      test('clamps t to [0, 1]', () {
        final path = Path.line(
          start: Point(x: 0, y: 0),
          end: Point(x: 100, y: 100),
        );
        final point = path.pointAt(2.0); // Should clamp to 1.0
        expect(point, Point(x: 100, y: 100));
      });
    });

    group('translation', () {
      test('translates path', () {
        final path = Path.line(
          start: Point(x: 0, y: 0),
          end: Point(x: 100, y: 100),
        );
        final translated = path.translate(Point(x: 10, y: 20));

        expect(translated.anchors[0].position, Point(x: 10, y: 20));
        expect(translated.anchors[1].position, Point(x: 110, y: 120));
      });

      test('translation preserves handles (relative)', () {
        final path = Path(
          anchors: [
            AnchorPoint(
              position: Point(x: 0, y: 0),
              handleOut: Point(x: 50, y: 0),
            ),
            AnchorPoint.corner(position: Point(x: 100, y: 100)),
          ],
          segments: [Segment.bezier(startAnchorIndex: 0, endAnchorIndex: 1)],
        );
        final translated = path.translate(Point(x: 10, y: 20));

        // Handle should remain the same (it's a relative offset)
        expect(translated.anchors[0].handleOut, Point(x: 50, y: 0));
      });
    });

    group('anchor manipulation', () {
      test('adds anchor to path', () {
        final path = Path.line(
          start: Point(x: 0, y: 0),
          end: Point(x: 100, y: 100),
        );
        final newAnchor = AnchorPoint.corner(position: Point(x: 200, y: 200));
        final updated = path.addAnchor(newAnchor);

        expect(updated.anchors.length, 3);
        expect(updated.segments.length, 2);
        expect(updated.anchors[2], newAnchor);
      });

      test('adds first anchor to empty path', () {
        final path = Path.empty();
        final anchor = AnchorPoint.corner(position: Point(x: 10, y: 20));
        final updated = path.addAnchor(anchor);

        expect(updated.anchors.length, 1);
        expect(updated.segments.length, 0);
      });

      test('removes anchor from path', () {
        final path = Path.fromAnchors(
          anchors: [
            AnchorPoint.corner(position: Point(x: 0, y: 0)),
            AnchorPoint.corner(position: Point(x: 50, y: 50)),
            AnchorPoint.corner(position: Point(x: 100, y: 100)),
          ],
        );
        final updated = path.removeAnchor(1);

        expect(updated.anchors.length, 2);
        expect(updated.anchors[0].position, Point(x: 0, y: 0));
        expect(updated.anchors[1].position, Point(x: 100, y: 100));
      });

      test('removes segments referencing removed anchor', () {
        final path = Path.fromAnchors(
          anchors: [
            AnchorPoint.corner(position: Point(x: 0, y: 0)),
            AnchorPoint.corner(position: Point(x: 50, y: 50)),
            AnchorPoint.corner(position: Point(x: 100, y: 100)),
          ],
        );
        final updated = path.removeAnchor(1);

        expect(updated.segments.length, 0); // Both segments referenced anchor 1
      });

      test('updates segment indices when removing anchor', () {
        final path = Path(
          anchors: [
            AnchorPoint.corner(position: Point(x: 0, y: 0)),
            AnchorPoint.corner(position: Point(x: 50, y: 50)),
            AnchorPoint.corner(position: Point(x: 100, y: 100)),
            AnchorPoint.corner(position: Point(x: 150, y: 150)),
          ],
          segments: [
            Segment.line(startAnchorIndex: 0, endAnchorIndex: 1),
            Segment.line(startAnchorIndex: 2, endAnchorIndex: 3),
          ],
        );
        final updated = path.removeAnchor(1);

        // Second segment should now reference indices 1→2 (was 2→3)
        expect(updated.segments.length, 1);
        expect(updated.segments[0].startAnchorIndex, 1);
        expect(updated.segments[0].endAnchorIndex, 2);
      });

      test('throws when removing invalid index', () {
        final path = Path.line(
          start: Point(x: 0, y: 0),
          end: Point(x: 100, y: 100),
        );
        expect(() => path.removeAnchor(5), throwsRangeError);
      });
    });

    group('validation', () {
      test('validates correct indices', () {
        final path = Path.fromAnchors(
          anchors: [
            AnchorPoint.corner(position: Point(x: 0, y: 0)),
            AnchorPoint.corner(position: Point(x: 100, y: 100)),
          ],
        );
        expect(path.validateIndices(), isTrue);
      });

      test('detects invalid indices', () {
        final path = Path(
          anchors: [AnchorPoint.corner(position: Point(x: 0, y: 0))],
          segments: [
            Segment.line(startAnchorIndex: 0, endAnchorIndex: 5), // Invalid!
          ],
        );
        expect(path.validateIndices(), isFalse);
      });
    });

    group('equality', () {
      test('paths with same data are equal', () {
        final p1 = Path.line(start: Point(x: 0, y: 0), end: Point(x: 100, y: 100));
        final p2 = Path.line(start: Point(x: 0, y: 0), end: Point(x: 100, y: 100));
        expect(p1, equals(p2));
        expect(p1.hashCode, equals(p2.hashCode));
      });

      test('paths with different anchors are not equal', () {
        final p1 = Path.line(start: Point(x: 0, y: 0), end: Point(x: 100, y: 100));
        final p2 = Path.line(start: Point(x: 0, y: 0), end: Point(x: 100, y: 101));
        expect(p1, isNot(equals(p2)));
      });
    });

    group('JSON serialization', () {
      test('serializes to JSON', () {
        final path = Path.line(
          start: Point(x: 0, y: 0),
          end: Point(x: 100, y: 100),
        );
        final json = path.toJson();
        expect(json['anchors'], isA<List>());
        expect(json['segments'], isA<List>());
        expect(json['closed'], isFalse);
      });

      test('deserializes from JSON', () {
        final json = {
          'anchors': [
            {
              'position': {'x': 0.0, 'y': 0.0},
              'handleIn': null,
              'handleOut': null,
              'anchorType': 'corner',
            },
            {
              'position': {'x': 100.0, 'y': 100.0},
              'handleIn': null,
              'handleOut': null,
              'anchorType': 'corner',
            },
          ],
          'segments': [
            {
              'startAnchorIndex': 0,
              'endAnchorIndex': 1,
              'segmentType': 'line',
            },
          ],
          'closed': false,
        };
        final path = Path.fromJson(json);
        expect(path.anchors.length, 2);
        expect(path.segments.length, 1);
        expect(path.closed, isFalse);
      });

      test('round-trips through JSON', () {
        final original = Path.line(
          start: Point(x: 10, y: 20),
          end: Point(x: 100, y: 200),
        );
        // Manually construct JSON with proper nesting
        final json = {
          'anchors': [
            {
              'position': {'x': 10.0, 'y': 20.0},
              'handleIn': null,
              'handleOut': null,
              'anchorType': 'corner',
            },
            {
              'position': {'x': 100.0, 'y': 200.0},
              'handleIn': null,
              'handleOut': null,
              'anchorType': 'corner',
            },
          ],
          'segments': [
            {
              'startAnchorIndex': 0,
              'endAnchorIndex': 1,
              'segmentType': 'line',
            },
          ],
          'closed': false,
        };
        final deserialized = Path.fromJson(json);
        expect(deserialized, equals(original));
      });
    });
  });
}
