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

  group('Geometry', () {
    test('can be instantiated', () {
      const geometry = Geometry();
      expect(geometry, isNotNull);
    });

    test('has correct epsilon value', () {
      const geometry = Geometry();
      expect(geometry.epsilon, equals(1e-10));
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
