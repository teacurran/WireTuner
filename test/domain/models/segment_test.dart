import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/domain/models/segment.dart';

void main() {
  group('Segment', () {
    group('Construction', () {
      test('default constructor creates segment with all required fields', () {
        const segment = Segment(
          startAnchorIndex: 0,
          endAnchorIndex: 1,
          segmentType: SegmentType.line,
        );

        expect(segment.startAnchorIndex, equals(0));
        expect(segment.endAnchorIndex, equals(1));
        expect(segment.segmentType, equals(SegmentType.line));
      });

      test('constructor accepts different anchor indices', () {
        const segment = Segment(
          startAnchorIndex: 5,
          endAnchorIndex: 10,
          segmentType: SegmentType.bezier,
        );

        expect(segment.startAnchorIndex, equals(5));
        expect(segment.endAnchorIndex, equals(10));
        expect(segment.segmentType, equals(SegmentType.bezier));
      });

      test('constructor creates const instance', () {
        const segment = Segment(
          startAnchorIndex: 0,
          endAnchorIndex: 1,
          segmentType: SegmentType.line,
        );

        expect(segment, isNotNull);
      });

      test('constructor accepts zero indices', () {
        const segment = Segment(
          startAnchorIndex: 0,
          endAnchorIndex: 0,
          segmentType: SegmentType.line,
        );

        expect(segment.startAnchorIndex, equals(0));
        expect(segment.endAnchorIndex, equals(0));
      });
    });

    group('Factory constructors', () {
      test('line factory creates line segment', () {
        final segment = Segment.line(
          startIndex: 0,
          endIndex: 1,
        );

        expect(segment.startAnchorIndex, equals(0));
        expect(segment.endAnchorIndex, equals(1));
        expect(segment.segmentType, equals(SegmentType.line));
        expect(segment.isLine, isTrue);
      });

      test('bezier factory creates bezier segment', () {
        final segment = Segment.bezier(
          startIndex: 1,
          endIndex: 2,
        );

        expect(segment.startAnchorIndex, equals(1));
        expect(segment.endAnchorIndex, equals(2));
        expect(segment.segmentType, equals(SegmentType.bezier));
        expect(segment.isBezier, isTrue);
      });

      test('line factory with large indices', () {
        final segment = Segment.line(
          startIndex: 100,
          endIndex: 200,
        );

        expect(segment.startAnchorIndex, equals(100));
        expect(segment.endAnchorIndex, equals(200));
      });

      test('bezier factory with same start and end', () {
        final segment = Segment.bezier(
          startIndex: 5,
          endIndex: 5,
        );

        expect(segment.startAnchorIndex, equals(5));
        expect(segment.endAnchorIndex, equals(5));
      });
    });

    group('Getters', () {
      test('isLine returns true for line segments', () {
        final segment = Segment.line(
          startIndex: 0,
          endIndex: 1,
        );

        expect(segment.isLine, isTrue);
        expect(segment.isBezier, isFalse);
      });

      test('isLine returns false for bezier segments', () {
        final segment = Segment.bezier(
          startIndex: 0,
          endIndex: 1,
        );

        expect(segment.isLine, isFalse);
        expect(segment.isBezier, isTrue);
      });

      test('isLine returns false for arc segments', () {
        const segment = Segment(
          startAnchorIndex: 0,
          endAnchorIndex: 1,
          segmentType: SegmentType.arc,
        );

        expect(segment.isLine, isFalse);
        expect(segment.isBezier, isFalse);
      });

      test('isBezier returns true for bezier segments', () {
        final segment = Segment.bezier(
          startIndex: 0,
          endIndex: 1,
        );

        expect(segment.isBezier, isTrue);
        expect(segment.isLine, isFalse);
      });

      test('isBezier returns false for line segments', () {
        final segment = Segment.line(
          startIndex: 0,
          endIndex: 1,
        );

        expect(segment.isBezier, isFalse);
        expect(segment.isLine, isTrue);
      });

      test('isBezier returns false for arc segments', () {
        const segment = Segment(
          startAnchorIndex: 0,
          endAnchorIndex: 1,
          segmentType: SegmentType.arc,
        );

        expect(segment.isBezier, isFalse);
        expect(segment.isLine, isFalse);
      });
    });

    group('copyWith', () {
      test('copyWith changes startAnchorIndex', () {
        final original = Segment.line(
          startIndex: 0,
          endIndex: 1,
        );

        final updated = original.copyWith(
          startAnchorIndex: 5,
        );

        expect(updated.startAnchorIndex, equals(5));
        expect(updated.endAnchorIndex, equals(original.endAnchorIndex));
        expect(updated.segmentType, equals(original.segmentType));
      });

      test('copyWith changes endAnchorIndex', () {
        final original = Segment.line(
          startIndex: 0,
          endIndex: 1,
        );

        final updated = original.copyWith(
          endAnchorIndex: 10,
        );

        expect(updated.endAnchorIndex, equals(10));
        expect(updated.startAnchorIndex, equals(original.startAnchorIndex));
        expect(updated.segmentType, equals(original.segmentType));
      });

      test('copyWith changes segmentType', () {
        final original = Segment.line(
          startIndex: 0,
          endIndex: 1,
        );

        final updated = original.copyWith(
          segmentType: SegmentType.bezier,
        );

        expect(updated.segmentType, equals(SegmentType.bezier));
        expect(updated.startAnchorIndex, equals(original.startAnchorIndex));
        expect(updated.endAnchorIndex, equals(original.endAnchorIndex));
      });

      test('copyWith leaves unchanged fields intact', () {
        const original = Segment(
          startAnchorIndex: 2,
          endAnchorIndex: 5,
          segmentType: SegmentType.bezier,
        );

        final updated = original.copyWith(
          startAnchorIndex: 3,
        );

        expect(updated.startAnchorIndex, equals(3));
        expect(updated.endAnchorIndex, equals(original.endAnchorIndex));
        expect(updated.segmentType, equals(original.segmentType));
      });

      test('copyWith with no parameters returns equal instance', () {
        const original = Segment(
          startAnchorIndex: 2,
          endAnchorIndex: 5,
          segmentType: SegmentType.bezier,
        );

        final copy = original.copyWith();

        expect(copy, equals(original));
        expect(copy == original, isTrue);
      });

      test('copyWith changes multiple fields at once', () {
        final original = Segment.line(
          startIndex: 0,
          endIndex: 1,
        );

        final updated = original.copyWith(
          startAnchorIndex: 5,
          endAnchorIndex: 10,
          segmentType: SegmentType.bezier,
        );

        expect(updated.startAnchorIndex, equals(5));
        expect(updated.endAnchorIndex, equals(10));
        expect(updated.segmentType, equals(SegmentType.bezier));
      });

      test('copyWith converts line to bezier', () {
        final line = Segment.line(startIndex: 0, endIndex: 1);
        final bezier = line.copyWith(segmentType: SegmentType.bezier);

        expect(bezier.isLine, isFalse);
        expect(bezier.isBezier, isTrue);
        expect(bezier.startAnchorIndex, equals(line.startAnchorIndex));
        expect(bezier.endAnchorIndex, equals(line.endAnchorIndex));
      });

      test('copyWith converts bezier to line', () {
        final bezier = Segment.bezier(startIndex: 0, endIndex: 1);
        final line = bezier.copyWith(segmentType: SegmentType.line);

        expect(line.isBezier, isFalse);
        expect(line.isLine, isTrue);
        expect(line.startAnchorIndex, equals(bezier.startAnchorIndex));
        expect(line.endAnchorIndex, equals(bezier.endAnchorIndex));
      });
    });

    group('Equality and hashCode', () {
      test('identical instances are equal', () {
        final segment = Segment.line(startIndex: 0, endIndex: 1);

        expect(segment == segment, isTrue);
        expect(identical(segment, segment), isTrue);
      });

      test('instances with same values are equal', () {
        const segment1 = Segment(
          startAnchorIndex: 2,
          endAnchorIndex: 5,
          segmentType: SegmentType.bezier,
        );

        const segment2 = Segment(
          startAnchorIndex: 2,
          endAnchorIndex: 5,
          segmentType: SegmentType.bezier,
        );

        expect(segment1 == segment2, isTrue);
        expect(segment1.hashCode, equals(segment2.hashCode));
      });

      test('instances with different startAnchorIndex are not equal', () {
        final segment1 = Segment.line(startIndex: 0, endIndex: 1);
        final segment2 = Segment.line(startIndex: 2, endIndex: 1);

        expect(segment1 == segment2, isFalse);
      });

      test('instances with different endAnchorIndex are not equal', () {
        final segment1 = Segment.line(startIndex: 0, endIndex: 1);
        final segment2 = Segment.line(startIndex: 0, endIndex: 2);

        expect(segment1 == segment2, isFalse);
      });

      test('instances with different segmentType are not equal', () {
        final segment1 = Segment.line(startIndex: 0, endIndex: 1);
        final segment2 = Segment.bezier(startIndex: 0, endIndex: 1);

        expect(segment1 == segment2, isFalse);
      });

      test('hashCode is consistent with equality', () {
        const segment1 = Segment(
          startAnchorIndex: 2,
          endAnchorIndex: 5,
          segmentType: SegmentType.bezier,
        );

        const segment2 = Segment(
          startAnchorIndex: 2,
          endAnchorIndex: 5,
          segmentType: SegmentType.bezier,
        );

        expect(segment1 == segment2, isTrue);
        expect(segment1.hashCode == segment2.hashCode, isTrue);
      });

      test('different instances have different hashCodes (usually)', () {
        final segment1 = Segment.line(startIndex: 0, endIndex: 1);
        final segment2 = Segment.line(startIndex: 2, endIndex: 3);

        // Note: Hash collisions are possible but unlikely for different values
        expect(segment1.hashCode == segment2.hashCode, isFalse);
      });
    });

    group('toString', () {
      test('toString includes all fields for line segment', () {
        final segment = Segment.line(startIndex: 0, endIndex: 1);

        final str = segment.toString();

        expect(str, contains('Segment'));
        expect(str, contains('start'));
        expect(str, contains('0'));
        expect(str, contains('end'));
        expect(str, contains('1'));
        expect(str, contains('type'));
        expect(str, contains('line'));
      });

      test('toString includes all fields for bezier segment', () {
        final segment = Segment.bezier(startIndex: 5, endIndex: 10);

        final str = segment.toString();

        expect(str, contains('Segment'));
        expect(str, contains('start'));
        expect(str, contains('5'));
        expect(str, contains('end'));
        expect(str, contains('10'));
        expect(str, contains('type'));
        expect(str, contains('bezier'));
      });

      test('toString includes all fields for arc segment', () {
        const segment = Segment(
          startAnchorIndex: 2,
          endAnchorIndex: 3,
          segmentType: SegmentType.arc,
        );

        final str = segment.toString();

        expect(str, contains('Segment'));
        expect(str, contains('arc'));
      });
    });

    group('SegmentType enum', () {
      test('enum has correct values', () {
        expect(SegmentType.values.length, equals(3));
        expect(SegmentType.values, contains(SegmentType.line));
        expect(SegmentType.values, contains(SegmentType.bezier));
        expect(SegmentType.values, contains(SegmentType.arc));
      });

      test('enum values are distinct', () {
        expect(SegmentType.line, isNot(equals(SegmentType.bezier)));
        expect(SegmentType.line, isNot(equals(SegmentType.arc)));
        expect(SegmentType.bezier, isNot(equals(SegmentType.arc)));
      });
    });

    group('Edge cases', () {
      test('segment with same start and end index', () {
        final segment = Segment.line(startIndex: 5, endIndex: 5);

        expect(segment.startAnchorIndex, equals(5));
        expect(segment.endAnchorIndex, equals(5));
      });

      test('segment with reversed indices (end < start)', () {
        final segment = Segment.line(startIndex: 10, endIndex: 5);

        expect(segment.startAnchorIndex, equals(10));
        expect(segment.endAnchorIndex, equals(5));
      });

      test('segment with large index values', () {
        final segment = Segment.bezier(
          startIndex: 999999,
          endIndex: 1000000,
        );

        expect(segment.startAnchorIndex, equals(999999));
        expect(segment.endAnchorIndex, equals(1000000));
      });
    });

    group('Immutability', () {
      test('segment fields are final', () {
        const segment = Segment(
          startAnchorIndex: 0,
          endAnchorIndex: 1,
          segmentType: SegmentType.bezier,
        );

        // Verify we can't modify fields (compile-time check)
        // This test just verifies the segment exists and is usable
        expect(segment.startAnchorIndex, isNotNull);
        expect(segment.endAnchorIndex, isNotNull);
        expect(segment.segmentType, isNotNull);
      });
    });

    group('Factory consistency', () {
      test('line factory is equivalent to manual construction', () {
        final factory = Segment.line(startIndex: 0, endIndex: 1);
        const manual = Segment(
          startAnchorIndex: 0,
          endAnchorIndex: 1,
          segmentType: SegmentType.line,
        );

        expect(factory, equals(manual));
      });

      test('bezier factory is equivalent to manual construction', () {
        final factory = Segment.bezier(startIndex: 2, endIndex: 3);
        const manual = Segment(
          startAnchorIndex: 2,
          endAnchorIndex: 3,
          segmentType: SegmentType.bezier,
        );

        expect(factory, equals(manual));
      });
    });
  });
}
