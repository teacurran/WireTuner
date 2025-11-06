import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/domain/events/event_base.dart' show Point;
import 'package:wiretuner/domain/models/anchor_point.dart';

void main() {
  group('AnchorPoint', () {
    group('Construction', () {
      test('default constructor creates anchor with required position', () {
        final position = Point(x: 10, y: 20);
        final anchor = AnchorPoint(position: position);

        expect(anchor.position, equals(position));
        expect(anchor.handleIn, isNull);
        expect(anchor.handleOut, isNull);
        expect(anchor.anchorType, equals(AnchorType.corner));
      });

      test('default constructor accepts all optional parameters', () {
        final position = Point(x: 10, y: 20);
        final handleIn = Point(x: -5, y: 0);
        final handleOut = Point(x: 5, y: 0);

        final anchor = AnchorPoint(
          position: position,
          handleIn: handleIn,
          handleOut: handleOut,
          anchorType: AnchorType.smooth,
        );

        expect(anchor.position, equals(position));
        expect(anchor.handleIn, equals(handleIn));
        expect(anchor.handleOut, equals(handleOut));
        expect(anchor.anchorType, equals(AnchorType.smooth));
      });

      test('constructor creates const instance', () {
        const position = Point(x: 10, y: 20);
        const anchor = AnchorPoint(position: position);

        expect(anchor, isNotNull);
      });
    });

    group('Factory constructors', () {
      test('corner factory creates anchor with no handles', () {
        final position = Point(x: 10, y: 20);
        final anchor = AnchorPoint.corner(position);

        expect(anchor.position, equals(position));
        expect(anchor.handleIn, isNull);
        expect(anchor.handleOut, isNull);
        expect(anchor.anchorType, equals(AnchorType.corner));
      });

      test('smooth factory creates anchor with symmetric handles', () {
        final position = Point(x: 50, y: 50);
        final handleOut = Point(x: 20, y: 10);

        final anchor = AnchorPoint.smooth(
          position: position,
          handleOut: handleOut,
        );

        expect(anchor.position, equals(position));
        expect(anchor.handleOut, equals(handleOut));
        expect(anchor.anchorType, equals(AnchorType.smooth));
      });

      test('smooth factory creates opposite handleIn', () {
        final position = Point(x: 50, y: 50);
        final handleOut = Point(x: 20, y: 10);

        final anchor = AnchorPoint.smooth(
          position: position,
          handleOut: handleOut,
        );

        // handleIn should be exactly opposite to handleOut
        expect(anchor.handleIn, equals(Point(x: -20, y: -10)));
      });

      test('smooth factory with zero handleOut creates zero handleIn', () {
        final position = Point(x: 0, y: 0);
        final handleOut = Point(x: 0, y: 0);

        final anchor = AnchorPoint.smooth(
          position: position,
          handleOut: handleOut,
        );

        expect(anchor.handleIn, equals(Point(x: 0, y: 0)));
      });

      test('smooth factory with negative handleOut', () {
        final position = Point(x: 50, y: 50);
        final handleOut = Point(x: -15, y: -5);

        final anchor = AnchorPoint.smooth(
          position: position,
          handleOut: handleOut,
        );

        // handleIn should be opposite (positive values)
        expect(anchor.handleIn, equals(Point(x: 15, y: 5)));
      });
    });

    group('Getters', () {
      test('hasCurve returns true when handleIn is present', () {
        final anchor = AnchorPoint(
          position: Point(x: 10, y: 10),
          handleIn: Point(x: -5, y: 0),
        );

        expect(anchor.hasCurve, isTrue);
      });

      test('hasCurve returns true when handleOut is present', () {
        final anchor = AnchorPoint(
          position: Point(x: 10, y: 10),
          handleOut: Point(x: 5, y: 0),
        );

        expect(anchor.hasCurve, isTrue);
      });

      test('hasCurve returns true when both handles are present', () {
        final anchor = AnchorPoint(
          position: Point(x: 10, y: 10),
          handleIn: Point(x: -5, y: 0),
          handleOut: Point(x: 5, y: 0),
        );

        expect(anchor.hasCurve, isTrue);
      });

      test('hasCurve returns false when no handles', () {
        final anchor = AnchorPoint.corner(Point(x: 10, y: 10));

        expect(anchor.hasCurve, isFalse);
      });

      test('isCorner returns true when no handles', () {
        final anchor = AnchorPoint.corner(Point(x: 10, y: 10));

        expect(anchor.isCorner, isTrue);
      });

      test('isCorner returns false when handleIn present', () {
        final anchor = AnchorPoint(
          position: Point(x: 10, y: 10),
          handleIn: Point(x: -5, y: 0),
        );

        expect(anchor.isCorner, isFalse);
      });

      test('isCorner returns false when handleOut present', () {
        final anchor = AnchorPoint(
          position: Point(x: 10, y: 10),
          handleOut: Point(x: 5, y: 0),
        );

        expect(anchor.isCorner, isFalse);
      });

      test('isCorner returns false when both handles present', () {
        final anchor = AnchorPoint(
          position: Point(x: 10, y: 10),
          handleIn: Point(x: -5, y: 0),
          handleOut: Point(x: 5, y: 0),
        );

        expect(anchor.isCorner, isFalse);
      });
    });

    group('copyWith', () {
      test('copyWith changes position', () {
        final original = AnchorPoint(
          position: Point(x: 10, y: 20),
          handleOut: Point(x: 5, y: 0),
        );

        final updated = original.copyWith(
          position: Point(x: 30, y: 40),
        );

        expect(updated.position, equals(Point(x: 30, y: 40)));
        expect(updated.handleOut, equals(original.handleOut));
        expect(updated.anchorType, equals(original.anchorType));
      });

      test('copyWith changes handleIn', () {
        final original = AnchorPoint(
          position: Point(x: 10, y: 20),
          handleIn: Point(x: -5, y: 0),
        );

        final updated = original.copyWith(
          handleIn: () => Point(x: -10, y: -5),
        );

        expect(updated.handleIn, equals(Point(x: -10, y: -5)));
        expect(updated.position, equals(original.position));
      });

      test('copyWith changes handleOut', () {
        final original = AnchorPoint(
          position: Point(x: 10, y: 20),
          handleOut: Point(x: 5, y: 0),
        );

        final updated = original.copyWith(
          handleOut: () => Point(x: 10, y: 5),
        );

        expect(updated.handleOut, equals(Point(x: 10, y: 5)));
        expect(updated.position, equals(original.position));
      });

      test('copyWith changes anchorType', () {
        final original = AnchorPoint(
          position: Point(x: 10, y: 20),
          anchorType: AnchorType.corner,
        );

        final updated = original.copyWith(
          anchorType: AnchorType.smooth,
        );

        expect(updated.anchorType, equals(AnchorType.smooth));
        expect(updated.position, equals(original.position));
      });

      test('copyWith sets handleIn to null', () {
        final original = AnchorPoint(
          position: Point(x: 10, y: 20),
          handleIn: Point(x: -5, y: 0),
          handleOut: Point(x: 5, y: 0),
        );

        final updated = original.copyWith(
          handleIn: () => null,
        );

        expect(updated.handleIn, isNull);
        expect(updated.handleOut, equals(original.handleOut));
        expect(updated.position, equals(original.position));
      });

      test('copyWith sets handleOut to null', () {
        final original = AnchorPoint(
          position: Point(x: 10, y: 20),
          handleIn: Point(x: -5, y: 0),
          handleOut: Point(x: 5, y: 0),
        );

        final updated = original.copyWith(
          handleOut: () => null,
        );

        expect(updated.handleOut, isNull);
        expect(updated.handleIn, equals(original.handleIn));
        expect(updated.position, equals(original.position));
      });

      test('copyWith sets both handles to null', () {
        final original = AnchorPoint(
          position: Point(x: 10, y: 20),
          handleIn: Point(x: -5, y: 0),
          handleOut: Point(x: 5, y: 0),
        );

        final updated = original.copyWith(
          handleIn: () => null,
          handleOut: () => null,
        );

        expect(updated.handleIn, isNull);
        expect(updated.handleOut, isNull);
        expect(updated.position, equals(original.position));
      });

      test('copyWith leaves unchanged fields intact', () {
        final original = AnchorPoint(
          position: Point(x: 10, y: 20),
          handleIn: Point(x: -5, y: 0),
          handleOut: Point(x: 5, y: 0),
          anchorType: AnchorType.smooth,
        );

        final updated = original.copyWith(
          position: Point(x: 30, y: 40),
        );

        // Only position changed
        expect(updated.position, equals(Point(x: 30, y: 40)));
        expect(updated.handleIn, equals(original.handleIn));
        expect(updated.handleOut, equals(original.handleOut));
        expect(updated.anchorType, equals(original.anchorType));
      });

      test('copyWith with no parameters returns equal instance', () {
        final original = AnchorPoint(
          position: Point(x: 10, y: 20),
          handleIn: Point(x: -5, y: 0),
          handleOut: Point(x: 5, y: 0),
          anchorType: AnchorType.smooth,
        );

        final copy = original.copyWith();

        expect(copy, equals(original));
        expect(copy == original, isTrue);
      });

      test('copyWith changes multiple fields at once', () {
        final original = AnchorPoint(
          position: Point(x: 10, y: 20),
          handleIn: Point(x: -5, y: 0),
          anchorType: AnchorType.corner,
        );

        final updated = original.copyWith(
          position: Point(x: 30, y: 40),
          handleOut: () => Point(x: 10, y: 5),
          anchorType: AnchorType.smooth,
        );

        expect(updated.position, equals(Point(x: 30, y: 40)));
        expect(updated.handleOut, equals(Point(x: 10, y: 5)));
        expect(updated.anchorType, equals(AnchorType.smooth));
        expect(updated.handleIn, equals(original.handleIn));
      });
    });

    group('Equality and hashCode', () {
      test('identical instances are equal', () {
        final anchor = AnchorPoint(position: Point(x: 10, y: 20));

        expect(anchor == anchor, isTrue);
        expect(identical(anchor, anchor), isTrue);
      });

      test('instances with same values are equal', () {
        final anchor1 = AnchorPoint(
          position: Point(x: 10, y: 20),
          handleIn: Point(x: -5, y: 0),
          handleOut: Point(x: 5, y: 0),
          anchorType: AnchorType.smooth,
        );

        final anchor2 = AnchorPoint(
          position: Point(x: 10, y: 20),
          handleIn: Point(x: -5, y: 0),
          handleOut: Point(x: 5, y: 0),
          anchorType: AnchorType.smooth,
        );

        expect(anchor1 == anchor2, isTrue);
        expect(anchor1.hashCode, equals(anchor2.hashCode));
      });

      test('instances with different position are not equal', () {
        final anchor1 = AnchorPoint(position: Point(x: 10, y: 20));
        final anchor2 = AnchorPoint(position: Point(x: 30, y: 40));

        expect(anchor1 == anchor2, isFalse);
      });

      test('instances with different handleIn are not equal', () {
        final anchor1 = AnchorPoint(
          position: Point(x: 10, y: 20),
          handleIn: Point(x: -5, y: 0),
        );
        final anchor2 = AnchorPoint(
          position: Point(x: 10, y: 20),
          handleIn: Point(x: -10, y: 0),
        );

        expect(anchor1 == anchor2, isFalse);
      });

      test('instances with different handleOut are not equal', () {
        final anchor1 = AnchorPoint(
          position: Point(x: 10, y: 20),
          handleOut: Point(x: 5, y: 0),
        );
        final anchor2 = AnchorPoint(
          position: Point(x: 10, y: 20),
          handleOut: Point(x: 10, y: 0),
        );

        expect(anchor1 == anchor2, isFalse);
      });

      test('instances with different anchorType are not equal', () {
        final anchor1 = AnchorPoint(
          position: Point(x: 10, y: 20),
          anchorType: AnchorType.corner,
        );
        final anchor2 = AnchorPoint(
          position: Point(x: 10, y: 20),
          anchorType: AnchorType.smooth,
        );

        expect(anchor1 == anchor2, isFalse);
      });

      test('null handleIn vs present handleIn are not equal', () {
        final anchor1 = AnchorPoint(position: Point(x: 10, y: 20));
        final anchor2 = AnchorPoint(
          position: Point(x: 10, y: 20),
          handleIn: Point(x: -5, y: 0),
        );

        expect(anchor1 == anchor2, isFalse);
      });

      test('hashCode is consistent with equality', () {
        final anchor1 = AnchorPoint(
          position: Point(x: 10, y: 20),
          handleIn: Point(x: -5, y: 0),
          handleOut: Point(x: 5, y: 0),
          anchorType: AnchorType.smooth,
        );

        final anchor2 = AnchorPoint(
          position: Point(x: 10, y: 20),
          handleIn: Point(x: -5, y: 0),
          handleOut: Point(x: 5, y: 0),
          anchorType: AnchorType.smooth,
        );

        expect(anchor1 == anchor2, isTrue);
        expect(anchor1.hashCode == anchor2.hashCode, isTrue);
      });

      test('different instances have different hashCodes (usually)', () {
        final anchor1 = AnchorPoint(position: Point(x: 10, y: 20));
        final anchor2 = AnchorPoint(position: Point(x: 30, y: 40));

        // Note: Hash collisions are possible but unlikely for different values
        expect(anchor1.hashCode == anchor2.hashCode, isFalse);
      });
    });

    group('toString', () {
      test('toString includes all fields', () {
        final anchor = AnchorPoint(
          position: Point(x: 10, y: 20),
          handleIn: Point(x: -5, y: 0),
          handleOut: Point(x: 5, y: 0),
          anchorType: AnchorType.smooth,
        );

        final str = anchor.toString();

        expect(str, contains('AnchorPoint'));
        expect(str, contains('position'));
        expect(str, contains('10'));
        expect(str, contains('20'));
        expect(str, contains('handleIn'));
        expect(str, contains('-5'));
        expect(str, contains('handleOut'));
        expect(str, contains('5'));
        expect(str, contains('anchorType'));
        expect(str, contains('smooth'));
      });

      test('toString handles null handles', () {
        final anchor = AnchorPoint.corner(Point(x: 10, y: 20));

        final str = anchor.toString();

        expect(str, contains('AnchorPoint'));
        expect(str, contains('null'));
      });
    });

    group('AnchorType enum', () {
      test('enum has correct values', () {
        expect(AnchorType.values.length, equals(3));
        expect(AnchorType.values, contains(AnchorType.corner));
        expect(AnchorType.values, contains(AnchorType.smooth));
        expect(AnchorType.values, contains(AnchorType.symmetric));
      });

      test('enum values are distinct', () {
        expect(AnchorType.corner, isNot(equals(AnchorType.smooth)));
        expect(AnchorType.corner, isNot(equals(AnchorType.symmetric)));
        expect(AnchorType.smooth, isNot(equals(AnchorType.symmetric)));
      });
    });

    group('Immutability', () {
      test('anchor point fields are final', () {
        final anchor = AnchorPoint(
          position: Point(x: 10, y: 20),
          handleIn: Point(x: -5, y: 0),
          handleOut: Point(x: 5, y: 0),
        );

        // Verify we can't modify fields (compile-time check)
        // This test just verifies the anchor exists and is usable
        expect(anchor.position, isNotNull);
        expect(anchor.handleIn, isNotNull);
        expect(anchor.handleOut, isNotNull);
      });
    });
  });
}
