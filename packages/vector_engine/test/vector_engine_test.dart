import 'package:test/test.dart';
import 'package:vector_engine/vector_engine.dart';

void main() {
  group('VectorModels', () {
    test('can be instantiated', () {
      const models = VectorModels();
      expect(models, isNotNull);
    });

    test('has correct schema version', () {
      const models = VectorModels();
      expect(models.schemaVersion, equals('1.0.0'));
    });
  });

  group('Geometry constants', () {
    test('kGeometryEpsilon has correct value', () {
      expect(kGeometryEpsilon, equals(1e-10));
    });

    test('approximatelyEqual returns true for equal values', () {
      expect(approximatelyEqual(1.0, 1.0), isTrue);
    });

    test('approximatelyEqual returns true for values within epsilon', () {
      expect(approximatelyEqual(1.0, 1.0 + 1e-11), isTrue);
    });

    test('approximatelyEqual returns false for values outside epsilon', () {
      expect(approximatelyEqual(1.0, 1.1), isFalse);
    });
  });

  group('HitTesting', () {
    test('can be instantiated', () {
      const hitTesting = HitTesting();
      expect(hitTesting, isNotNull);
    });

    test('has correct hit tolerance', () {
      const hitTesting = HitTesting();
      expect(hitTesting.hitTolerance, equals(5.0));
    });
  });
}
