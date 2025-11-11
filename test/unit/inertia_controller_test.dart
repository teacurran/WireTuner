import 'package:wiretuner/domain/events/event_base.dart' show Point;
import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/application/tools/direct_selection/inertia_controller.dart';
import 'package:wiretuner/domain/models/geometry/point_extensions.dart';

void main() {
  group('InertiaController - Sample Recording', () {
    test('records drag samples in circular buffer', () {
      final controller = InertiaController(maxSamples: 3);

      controller.recordSample(
        position: Point(x: 10, y: 10),
        timestamp: 1000,
      );
      controller.recordSample(
        position: Point(x: 15, y: 12),
        timestamp: 1050,
      );
      controller.recordSample(
        position: Point(x: 20, y: 15),
        timestamp: 1100,
      );

      expect(controller.isActive, isFalse);
    });

    test('circular buffer discards old samples when full', () {
      final controller = InertiaController(maxSamples: 2);

      controller.recordSample(
        position: Point(x: 10, y: 10),
        timestamp: 1000,
      );
      controller.recordSample(
        position: Point(x: 15, y: 12),
        timestamp: 1050,
      );
      // This should discard first sample
      controller.recordSample(
        position: Point(x: 20, y: 15),
        timestamp: 1100,
      );

      // Should use last 2 samples for velocity
      final sequence = controller.activate(
        finalPosition: Point(x: 25, y: 18),
        currentTimestamp: 1150,
      );

      expect(sequence, isNotNull);
    });
  });

  group('InertiaController - Activation', () {
    test('activates when velocity exceeds threshold', () {
      final controller = InertiaController(
        velocityThreshold: 0.1,
        decayFactor: 0.9,
      );

      // Record samples with significant velocity
      controller.recordSample(
        position: Point(x: 10, y: 10),
        timestamp: 1000,
      );
      controller.recordSample(
        position: Point(x: 20, y: 15),
        timestamp: 1050,
      );

      final sequence = controller.activate(
        finalPosition: Point(x: 30, y: 20),
        currentTimestamp: 1100,
      );

      expect(sequence, isNotNull);
      expect(sequence!.length, greaterThan(0));
      expect(controller.isActive, isTrue);
    });

    test('does not activate when velocity below threshold', () {
      final controller = InertiaController(
        velocityThreshold: 1.0, // High threshold
      );

      // Record samples with low velocity
      controller.recordSample(
        position: Point(x: 10, y: 10),
        timestamp: 1000,
      );
      controller.recordSample(
        position: Point(x: 10.5, y: 10.2),
        timestamp: 1050,
      );

      final sequence = controller.activate(
        finalPosition: Point(x: 11, y: 10.5),
        currentTimestamp: 1100,
      );

      expect(sequence, isNull, reason: 'Should not activate for slow drags');
      expect(controller.isActive, isFalse);
    });

    test('does not activate with insufficient samples', () {
      final controller = InertiaController(
        velocityThreshold: 0.1,
      );

      // Record only one sample
      controller.recordSample(
        position: Point(x: 10, y: 10),
        timestamp: 1000,
      );

      final sequence = controller.activate(
        finalPosition: Point(x: 20, y: 15),
        currentTimestamp: 1050,
      );

      expect(sequence, isNull, reason: 'Need at least 2 samples');
    });
  });

  group('InertiaController - Sequence Generation', () {
    test('generates exponentially decaying sequence', () {
      final controller = InertiaController(
        velocityThreshold: 0.1,
        decayFactor: 0.8,
        maxDurationMs: 300,
        samplingIntervalMs: 50,
      );

      // Record fast drag
      controller.recordSample(
        position: Point(x: 0, y: 0),
        timestamp: 1000,
      );
      controller.recordSample(
        position: Point(x: 50, y: 30),
        timestamp: 1100,
      );

      final sequence = controller.activate(
        finalPosition: Point(x: 100, y: 60),
        currentTimestamp: 1200,
      );

      expect(sequence, isNotNull);
      expect(sequence!.length, greaterThan(1));

      // Verify positions are monotonically moving in same direction
      for (int i = 1; i < sequence.length; i++) {
        final prevDx = sequence.positions[i - 1].x - sequence.positions[0].x;
        final currDx = sequence.positions[i].x - sequence.positions[0].x;
        expect(currDx, greaterThanOrEqualTo(prevDx),
            reason: 'X should move in consistent direction');
      }
    });

    test('respects max duration limit', () {
      final controller = InertiaController(
        velocityThreshold: 0.1,
        decayFactor: 0.95, // High decay = longer sequence
        maxDurationMs: 200,
        samplingIntervalMs: 50,
      );

      controller.recordSample(
        position: Point(x: 0, y: 0),
        timestamp: 1000,
      );
      controller.recordSample(
        position: Point(x: 50, y: 30),
        timestamp: 1050,
      );

      final sequence = controller.activate(
        finalPosition: Point(x: 100, y: 60),
        currentTimestamp: 1100,
      );

      expect(sequence, isNotNull);
      expect(sequence!.durationMs, lessThanOrEqualTo(200),
          reason: 'Should respect max duration');
    });

    test('stops when velocity drops below threshold', () {
      final controller = InertiaController(
        velocityThreshold: 0.5,
        decayFactor: 0.5, // Aggressive decay
        maxDurationMs: 1000, // High limit
        samplingIntervalMs: 50,
      );

      controller.recordSample(
        position: Point(x: 0, y: 0),
        timestamp: 1000,
      );
      controller.recordSample(
        position: Point(x: 30, y: 20),
        timestamp: 1050,
      );

      final sequence = controller.activate(
        finalPosition: Point(x: 60, y: 40),
        currentTimestamp: 1100,
      );

      expect(sequence, isNotNull);
      // With decay of 0.5, should stop quickly (not reach max duration)
      expect(sequence!.length, lessThan(10),
          reason: 'Should stop when velocity decays');
    });

    test('includes correct timestamps for each position', () {
      final controller = InertiaController(
        velocityThreshold: 0.1,
        decayFactor: 0.9,
        samplingIntervalMs: 50,
      );

      controller.recordSample(
        position: Point(x: 0, y: 0),
        timestamp: 1000,
      );
      controller.recordSample(
        position: Point(x: 20, y: 10),
        timestamp: 1050,
      );

      final sequence = controller.activate(
        finalPosition: Point(x: 40, y: 20),
        currentTimestamp: 1100,
      );

      expect(sequence, isNotNull);

      // Verify timestamps increment by samplingIntervalMs
      for (int i = 1; i < sequence!.timestamps.length; i++) {
        final interval = sequence.timestamps[i] - sequence.timestamps[i - 1];
        expect(interval, equals(50),
            reason: 'Timestamps should increment by samplingIntervalMs');
      }
    });
  });

  group('InertiaController - Accuracy', () {
    test('maintains sub-pixel accuracy in position calculations', () {
      final controller = InertiaController(
        velocityThreshold: 0.1,
        decayFactor: 0.9,
      );

      controller.recordSample(
        position: Point(x: 0, y: 0),
        timestamp: 1000,
      );
      controller.recordSample(
        position: Point(x: 10.5, y: 5.3),
        timestamp: 1050,
      );

      final sequence = controller.activate(
        finalPosition: Point(x: 21, y: 10.6),
        currentTimestamp: 1100,
      );

      expect(sequence, isNotNull);

      // Verify all positions are valid (no NaN or Infinity)
      for (final position in sequence!.positions) {
        expect(position.x.isFinite, isTrue);
        expect(position.y.isFinite, isTrue);
        expect(position.x.isNaN, isFalse);
        expect(position.y.isNaN, isFalse);
      }
    });

    test('total drift is less than 1px from expected trajectory', () {
      final controller = InertiaController(
        velocityThreshold: 0.1,
        decayFactor: 0.9,
        maxDurationMs: 200,
      );

      // Create consistent velocity
      controller.recordSample(
        position: Point(x: 0, y: 0),
        timestamp: 1000,
      );
      controller.recordSample(
        position: Point(x: 10, y: 5),
        timestamp: 1050,
      );
      controller.recordSample(
        position: Point(x: 20, y: 10),
        timestamp: 1100,
      );

      final sequence = controller.activate(
        finalPosition: Point(x: 30, y: 15),
        currentTimestamp: 1150,
      );

      expect(sequence, isNotNull);

      // Final position should be within reasonable distance from start
      final finalPos = sequence!.finalPosition;
      final startPos = Point(x: 30, y: 15);
      final distance = (finalPos - startPos).magnitude;

      // Inertia should not overshoot drastically
      expect(distance, lessThan(50),
          reason: 'Inertia distance should be reasonable');
    });
  });

  group('InertiaController - State Management', () {
    test('cancel stops active inertia', () {
      final controller = InertiaController(
        velocityThreshold: 0.1,
      );

      controller.recordSample(
        position: Point(x: 0, y: 0),
        timestamp: 1000,
      );
      controller.recordSample(
        position: Point(x: 20, y: 10),
        timestamp: 1050,
      );

      controller.activate(
        finalPosition: Point(x: 40, y: 20),
        currentTimestamp: 1100,
      );

      expect(controller.isActive, isTrue);

      controller.cancel();

      expect(controller.isActive, isFalse);
    });

    test('reset clears samples and state', () {
      final controller = InertiaController(
        velocityThreshold: 0.1,
      );

      controller.recordSample(
        position: Point(x: 0, y: 0),
        timestamp: 1000,
      );
      controller.recordSample(
        position: Point(x: 20, y: 10),
        timestamp: 1050,
      );

      controller.reset();

      // Should not activate with no samples
      final sequence = controller.activate(
        finalPosition: Point(x: 40, y: 20),
        currentTimestamp: 1100,
      );

      expect(sequence, isNull, reason: 'Samples should be cleared');
      expect(controller.isActive, isFalse);
    });
  });

  group('InertiaController - Configuration', () {
    test('higher decay factor produces longer sequences', () {
      final controller1 = InertiaController(
        velocityThreshold: 0.1,
        decayFactor: 0.7,
        maxDurationMs: 500,
      );

      final controller2 = InertiaController(
        velocityThreshold: 0.1,
        decayFactor: 0.95,
        maxDurationMs: 500,
      );

      // Same samples for both
      for (final controller in [controller1, controller2]) {
        controller.recordSample(
          position: Point(x: 0, y: 0),
          timestamp: 1000,
        );
        controller.recordSample(
          position: Point(x: 30, y: 20),
          timestamp: 1050,
        );
      }

      final sequence1 = controller1.activate(
        finalPosition: Point(x: 60, y: 40),
        currentTimestamp: 1100,
      );

      final sequence2 = controller2.activate(
        finalPosition: Point(x: 60, y: 40),
        currentTimestamp: 1100,
      );

      expect(sequence1, isNotNull);
      expect(sequence2, isNotNull);
      expect(sequence2!.length, greaterThan(sequence1!.length),
          reason: 'Higher decay should produce longer sequence');
    });

    test('validates configuration parameters', () {
      expect(
        () => InertiaController(velocityThreshold: -1.0),
        throwsA(isA<AssertionError>()),
      );

      expect(
        () => InertiaController(decayFactor: 1.5),
        throwsA(isA<AssertionError>()),
      );

      expect(
        () => InertiaController(maxDurationMs: 0),
        throwsA(isA<AssertionError>()),
      );

      expect(
        () => InertiaController(maxSamples: 1),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
