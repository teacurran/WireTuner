import 'package:test/test.dart';
import 'package:vector_engine/vector_engine.dart';

void main() {
  group('AnchorPoint', () {
    group('construction', () {
      test('creates anchor with position only', () {
        final anchor = AnchorPoint(
          position: Point(x: 100, y: 200),
        );
        expect(anchor.position, Point(x: 100, y: 200));
        expect(anchor.handleIn, isNull);
        expect(anchor.handleOut, isNull);
        expect(anchor.anchorType, AnchorType.corner);
      });

      test('creates anchor with handles', () {
        final anchor = AnchorPoint(
          position: Point(x: 100, y: 200),
          handleIn: Point(x: -50, y: 0),
          handleOut: Point(x: 50, y: 0),
        );
        expect(anchor.handleIn, Point(x: -50, y: 0));
        expect(anchor.handleOut, Point(x: 50, y: 0));
      });

      test('creates corner anchor', () {
        final anchor = AnchorPoint.corner(
          position: Point(x: 100, y: 200),
        );
        expect(anchor.position, Point(x: 100, y: 200));
        expect(anchor.handleIn, isNull);
        expect(anchor.handleOut, isNull);
        expect(anchor.anchorType, AnchorType.corner);
      });

      test('creates smooth anchor with mirrored handles', () {
        final anchor = AnchorPoint.smooth(
          position: Point(x: 100, y: 200),
          handleOut: Point(x: 50, y: 20),
        );
        expect(anchor.position, Point(x: 100, y: 200));
        expect(anchor.handleOut, Point(x: 50, y: 20));
        expect(anchor.handleIn, Point(x: -50, y: -20));
        expect(anchor.anchorType, AnchorType.smooth);
      });
    });

    group('handle semantics', () {
      test('handles are stored as relative offsets', () {
        final anchor = AnchorPoint(
          position: Point(x: 100, y: 100),
          handleOut: Point(x: 50, y: 0),
        );
        // Handle is relative, not absolute
        expect(anchor.handleOut, Point(x: 50, y: 0));
        expect(anchor.handleOutAbsolute, Point(x: 150, y: 100));
      });

      test('handleInAbsolute returns null when handleIn is null', () {
        final anchor = AnchorPoint.corner(
          position: Point(x: 100, y: 100),
        );
        expect(anchor.handleInAbsolute, isNull);
      });

      test('handleOutAbsolute returns null when handleOut is null', () {
        final anchor = AnchorPoint.corner(
          position: Point(x: 100, y: 100),
        );
        expect(anchor.handleOutAbsolute, isNull);
      });

      test('computes absolute handle positions correctly', () {
        final anchor = AnchorPoint(
          position: Point(x: 100, y: 100),
          handleIn: Point(x: -30, y: -40),
          handleOut: Point(x: 30, y: 40),
        );
        expect(anchor.handleInAbsolute, Point(x: 70, y: 60));
        expect(anchor.handleOutAbsolute, Point(x: 130, y: 140));
      });
    });

    group('anchor types', () {
      test('isCorner returns true for anchor with no handles', () {
        final anchor = AnchorPoint.corner(
          position: Point(x: 100, y: 100),
        );
        expect(anchor.isCorner, isTrue);
        expect(anchor.hasCurve, isFalse);
      });

      test('isCorner returns false for anchor with handles', () {
        final anchor = AnchorPoint(
          position: Point(x: 100, y: 100),
          handleOut: Point(x: 50, y: 0),
        );
        expect(anchor.isCorner, isFalse);
        expect(anchor.hasCurve, isTrue);
      });

      test('hasCurve returns true if handleIn exists', () {
        final anchor = AnchorPoint(
          position: Point(x: 100, y: 100),
          handleIn: Point(x: -50, y: 0),
        );
        expect(anchor.hasCurve, isTrue);
      });

      test('hasCurve returns true if handleOut exists', () {
        final anchor = AnchorPoint(
          position: Point(x: 100, y: 100),
          handleOut: Point(x: 50, y: 0),
        );
        expect(anchor.hasCurve, isTrue);
      });
    });

    group('translation', () {
      test('translates anchor position', () {
        final anchor = AnchorPoint(
          position: Point(x: 100, y: 100),
          handleOut: Point(x: 50, y: 0),
        );
        final translated = anchor.translate(Point(x: 10, y: 20));

        expect(translated.position, Point(x: 110, y: 120));
      });

      test('translation preserves handles (relative)', () {
        final anchor = AnchorPoint(
          position: Point(x: 100, y: 100),
          handleIn: Point(x: -50, y: 0),
          handleOut: Point(x: 50, y: 0),
        );
        final translated = anchor.translate(Point(x: 10, y: 20));

        // Handles remain the same (they're relative offsets)
        expect(translated.handleIn, Point(x: -50, y: 0));
        expect(translated.handleOut, Point(x: 50, y: 0));

        // But absolute positions change
        expect(translated.handleInAbsolute, Point(x: 60, y: 120));
        expect(translated.handleOutAbsolute, Point(x: 160, y: 120));
      });
    });

    group('handle manipulation', () {
      test('setHandleOut updates handleOut for corner anchor', () {
        final anchor = AnchorPoint.corner(
          position: Point(x: 100, y: 100),
        );
        final updated = anchor.setHandleOut(Point(x: 50, y: 20));

        expect(updated.handleOut, Point(x: 50, y: 20));
        expect(updated.handleIn, isNull);
      });

      test('setHandleOut mirrors handleIn for smooth anchor', () {
        final anchor = AnchorPoint.smooth(
          position: Point(x: 100, y: 100),
          handleOut: Point(x: 50, y: 20),
        );
        final updated = anchor.setHandleOut(Point(x: 30, y: 40));

        expect(updated.handleOut, Point(x: 30, y: 40));
        expect(updated.handleIn, Point(x: -30, y: -40));
      });

      test('setHandleIn updates handleIn for corner anchor', () {
        final anchor = AnchorPoint.corner(
          position: Point(x: 100, y: 100),
        );
        final updated = anchor.setHandleIn(Point(x: -50, y: -20));

        expect(updated.handleIn, Point(x: -50, y: -20));
        expect(updated.handleOut, isNull);
      });

      test('setHandleIn mirrors handleOut for smooth anchor', () {
        final anchor = AnchorPoint.smooth(
          position: Point(x: 100, y: 100),
          handleOut: Point(x: 50, y: 20),
        );
        final updated = anchor.setHandleIn(Point(x: -30, y: -40));

        expect(updated.handleIn, Point(x: -30, y: -40));
        expect(updated.handleOut, Point(x: 30, y: 40));
      });

      test('setHandleOut with null removes handle', () {
        final anchor = AnchorPoint(
          position: Point(x: 100, y: 100),
          handleOut: Point(x: 50, y: 0),
        );
        final updated = anchor.setHandleOut(null);

        expect(updated.handleOut, isNull);
      });
    });

    group('equality', () {
      test('anchors with same properties are equal', () {
        final a1 = AnchorPoint(
          position: Point(x: 100, y: 200),
          handleOut: Point(x: 50, y: 0),
        );
        final a2 = AnchorPoint(
          position: Point(x: 100, y: 200),
          handleOut: Point(x: 50, y: 0),
        );
        expect(a1, equals(a2));
        expect(a1.hashCode, equals(a2.hashCode));
      });

      test('anchors with different positions are not equal', () {
        final a1 = AnchorPoint.corner(position: Point(x: 100, y: 200));
        final a2 = AnchorPoint.corner(position: Point(x: 100, y: 201));
        expect(a1, isNot(equals(a2)));
      });

      test('anchors with different handles are not equal', () {
        final a1 = AnchorPoint(
          position: Point(x: 100, y: 200),
          handleOut: Point(x: 50, y: 0),
        );
        final a2 = AnchorPoint(
          position: Point(x: 100, y: 200),
          handleOut: Point(x: 51, y: 0),
        );
        expect(a1, isNot(equals(a2)));
      });
    });

    group('JSON serialization', () {
      test('serializes anchor with no handles to JSON', () {
        final anchor = AnchorPoint.corner(
          position: Point(x: 100, y: 200),
        );
        final json = anchor.toJson();
        // toJson returns nested Point objects, not Maps, so check structure
        expect(json['position'], isA<Point>());
        expect((json['position'] as Point).x, 100.0);
        expect((json['position'] as Point).y, 200.0);
        expect(json['handleIn'], isNull);
        expect(json['handleOut'], isNull);
        expect(json['anchorType'], 'corner');
      });

      test('serializes anchor with handles to JSON', () {
        final anchor = AnchorPoint(
          position: Point(x: 100, y: 200),
          handleIn: Point(x: -50, y: 0),
          handleOut: Point(x: 50, y: 0),
          anchorType: AnchorType.symmetric,
        );
        final json = anchor.toJson();
        // toJson returns nested Point objects, not Maps
        expect(json['position'], isA<Point>());
        expect((json['position'] as Point).x, 100.0);
        expect((json['position'] as Point).y, 200.0);
        expect(json['handleIn'], isA<Point>());
        expect((json['handleIn'] as Point).x, -50.0);
        expect((json['handleIn'] as Point).y, 0.0);
        expect(json['handleOut'], isA<Point>());
        expect((json['handleOut'] as Point).x, 50.0);
        expect((json['handleOut'] as Point).y, 0.0);
        expect(json['anchorType'], 'symmetric');
      });

      test('deserializes anchor from JSON', () {
        final json = {
          'position': {'x': 100.0, 'y': 200.0},
          'handleIn': {'x': -50.0, 'y': 0.0},
          'handleOut': {'x': 50.0, 'y': 0.0},
          'anchorType': 'smooth',
        };
        final anchor = AnchorPoint.fromJson(json);
        expect(anchor.position, Point(x: 100, y: 200));
        expect(anchor.handleIn, Point(x: -50, y: 0));
        expect(anchor.handleOut, Point(x: 50, y: 0));
        expect(anchor.anchorType, AnchorType.smooth);
      });

      test('round-trips through JSON', () {
        final original = AnchorPoint.smooth(
          position: Point(x: 123.456, y: 789.012),
          handleOut: Point(x: 50.5, y: 20.3),
        );
        // Convert to JSON Map structure manually to ensure proper nesting
        final json = {
          'position': original.position.toJson(),
          'handleIn': original.handleIn?.toJson(),
          'handleOut': original.handleOut?.toJson(),
          'anchorType': original.anchorType.name,
        };
        final deserialized = AnchorPoint.fromJson(json);
        expect(deserialized, equals(original));
      });
    });

    group('copyWith', () {
      test('creates copy with new position', () {
        final original = AnchorPoint.corner(
          position: Point(x: 100, y: 200),
        );
        final copy = original.copyWith(
          position: Point(x: 150, y: 250),
        );
        expect(copy.position, Point(x: 150, y: 250));
        expect(copy.anchorType, AnchorType.corner);
      });

      test('creates copy with new handleOut', () {
        final original = AnchorPoint.corner(
          position: Point(x: 100, y: 200),
        );
        final copy = original.copyWith(
          handleOut: Point(x: 50, y: 0),
        );
        expect(copy.handleOut, Point(x: 50, y: 0));
      });

      test('creates copy with new anchorType', () {
        final original = AnchorPoint.corner(
          position: Point(x: 100, y: 200),
        );
        final copy = original.copyWith(
          anchorType: AnchorType.smooth,
        );
        expect(copy.anchorType, AnchorType.smooth);
      });
    });
  });
}
