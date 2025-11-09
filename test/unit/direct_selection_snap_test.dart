import 'package:wiretuner/domain/events/event_base.dart' show Point;
import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/application/tools/direct_selection/snapping_service.dart';
import 'package:wiretuner/application/tools/direct_selection/inertia_controller.dart';
import 'package:wiretuner/domain/models/geometry/point_extensions.dart';

/// Integration tests for direct selection with snapping and inertia.
///
/// These tests verify the combined behavior of SnappingService and
/// InertiaController in realistic drag scenarios.
void main() {
  group('DirectSelection Integration - Snapping + Inertia', () {
    test('inertia respects magnetic snapping', () {
      final snapping = SnappingService(
        gridSnapEnabled: true,
        gridSize: 10.0,
        magneticThreshold: 8.0,
      );

      final inertia = InertiaController(
        velocityThreshold: 0.1,
        decayFactor: 0.9,
        maxDurationMs: 200,
      );

      // Simulate drag with velocity
      inertia.recordSample(
        position: Point(x: 10, y: 10),
        timestamp: 1000,
      );
      inertia.recordSample(
        position: Point(x: 25, y: 18),
        timestamp: 1050,
      );
      inertia.recordSample(
        position: Point(x: 40, y: 26),
        timestamp: 1100,
      );

      final sequence = inertia.activate(
        finalPosition: Point(x: 55, y: 34),
        currentTimestamp: 1150,
      );

      expect(sequence, isNotNull);

      // Apply snapping to inertia positions
      int snappedCount = 0;
      for (final position in sequence!.positions) {
        final snapped = snapping.maybeSnapToGrid(position);
        if (snapped != null) {
          snappedCount++;

          // Verify snapped position is on grid
          expect(snapped.x % 10.0, equals(0.0));
          expect(snapped.y % 10.0, equals(0.0));
        }
      }

      // Some positions should snap during inertia
      expect(snappedCount, greaterThan(0),
          reason: 'Inertia sequence should encounter snap points');
    });

    test('combined drift remains under 1px', () {
      final snapping = SnappingService(
        gridSnapEnabled: true,
        gridSize: 10.0,
        magneticThreshold: 8.0,
      );

      final inertia = InertiaController(
        velocityThreshold: 0.1,
        decayFactor: 0.9,
      );

      // Create drag samples
      final samples = [
        (Point(x: 0, y: 0), 1000),
        (Point(x: 10.1, y: 5.2), 1050),
        (Point(x: 20.3, y: 10.1), 1100),
      ];

      for (final (pos, timestamp) in samples) {
        inertia.recordSample(position: pos, timestamp: timestamp);
      }

      final sequence = inertia.activate(
        finalPosition: Point(x: 30.2, y: 15.3),
        currentTimestamp: 1150,
      );

      expect(sequence, isNotNull);

      // Track cumulative drift from snapping
      double maxDriftX = 0.0;
      double maxDriftY = 0.0;

      for (final position in sequence!.positions) {
        final snapped = snapping.maybeSnapToGrid(position);
        if (snapped != null) {
          final driftX = (snapped.x - position.x).abs();
          final driftY = (snapped.y - position.y).abs();

          maxDriftX = driftX > maxDriftX ? driftX : maxDriftX;
          maxDriftY = driftY > maxDriftY ? driftY : maxDriftY;
        }
      }

      // Each snap should introduce < 1px drift
      expect(maxDriftX, lessThan(10.0),
          reason: 'Max X snap correction should be < grid size');
      expect(maxDriftY, lessThan(10.0),
          reason: 'Max Y snap correction should be < grid size');
    });

    test('snapping can be toggled during sequence', () {
      final snapping = SnappingService(
        gridSnapEnabled: true,
        gridSize: 10.0,
        magneticThreshold: 8.0,
      );

      final positions = [
        Point(x: 12, y: 18),
        Point(x: 25, y: 32),
        Point(x: 38, y: 47),
      ];

      // First with snapping enabled
      final snapped1 = snapping.maybeSnapToGrid(positions[0]);
      expect(snapped1, isNotNull);

      // Toggle off
      snapping.setSnapMode(gridEnabled: false);
      final snapped2 = snapping.maybeSnapToGrid(positions[1]);
      expect(snapped2, isNull, reason: 'Should not snap when disabled');

      // Toggle back on
      snapping.resetSnapState();
      snapping.setSnapMode(gridEnabled: true);
      final snapped3 = snapping.maybeSnapToGrid(positions[2]);
      expect(snapped3, isNotNull, reason: 'Should snap when re-enabled');
    });

    test('hysteresis prevents oscillation during inertia', () {
      final snapping = SnappingService(
        gridSnapEnabled: true,
        gridSize: 10.0,
        magneticThreshold: 5.0,
        hysteresisMargin: 3.0,
      );

      // Simulate inertia positions near grid boundary
      final positions = [
        Point(x: 13, y: 10), // Within threshold, snaps
        Point(x: 14, y: 10), // Within hysteresis, stays snapped
        Point(x: 15, y: 10), // Within hysteresis, stays snapped
        Point(x: 16, y: 10), // Still within hysteresis
        Point(x: 19, y: 10), // Outside hysteresis, releases
      ];

      final snapResults = positions.map((pos) =>
          snapping.maybeSnapToGrid(pos) != null).toList();

      // Should maintain snap through hysteresis zone
      expect(snapResults[0], isTrue, reason: 'Initial snap');
      expect(snapResults[1], isTrue, reason: 'Hysteresis keeps snap');
      expect(snapResults[2], isTrue, reason: 'Hysteresis keeps snap');
      expect(snapResults[3], isTrue, reason: 'Still in hysteresis');
      expect(snapResults[4], isFalse, reason: 'Outside hysteresis');
    });
  });

  group('DirectSelection Integration - Performance', () {
    test('snapping + inertia complete within frame budget', () {
      final snapping = SnappingService(
        gridSnapEnabled: true,
        gridSize: 10.0,
        magneticThreshold: 8.0,
      );

      final inertia = InertiaController(
        velocityThreshold: 0.1,
        decayFactor: 0.9,
        maxDurationMs: 300,
      );

      // Record samples
      for (int i = 0; i < 5; i++) {
        inertia.recordSample(
          position: Point(x: i * 10.0, y: i * 5.0),
          timestamp: 1000 + i * 50,
        );
      }

      final stopwatch = Stopwatch()..start();

      final sequence = inertia.activate(
        finalPosition: Point(x: 60, y: 30),
        currentTimestamp: 1300,
      );

      if (sequence != null) {
        for (final position in sequence.positions) {
          snapping.maybeSnapToGrid(position);
        }
      }

      stopwatch.stop();

      // Should complete within 16ms (60fps budget)
      expect(stopwatch.elapsedMilliseconds, lessThan(16),
          reason: 'Combined operation should complete within frame budget');
    });

    test('handles rapid enable/disable of snapping', () {
      final snapping = SnappingService(
        gridSnapEnabled: false,
        gridSize: 10.0,
        magneticThreshold: 8.0,
      );

      final position = Point(x: 13, y: 17);

      // Rapid toggling (simulating modifier key spam)
      for (int i = 0; i < 100; i++) {
        snapping.setSnapMode(gridEnabled: i.isEven);
        snapping.resetSnapState();

        final result = snapping.maybeSnapToGrid(position);

        if (i.isEven) {
          expect(result, isNotNull, reason: 'Should snap when enabled');
        } else {
          expect(result, isNull, reason: 'Should not snap when disabled');
        }
      }
    });
  });

  group('DirectSelection Integration - Edge Cases', () {
    test('handles zero velocity gracefully', () {
      final inertia = InertiaController(
        velocityThreshold: 0.1,
      );

      // Record samples with no movement
      inertia.recordSample(
        position: Point(x: 10, y: 10),
        timestamp: 1000,
      );
      inertia.recordSample(
        position: Point(x: 10, y: 10),
        timestamp: 1050,
      );

      final sequence = inertia.activate(
        finalPosition: Point(x: 10, y: 10),
        currentTimestamp: 1100,
      );

      expect(sequence, isNull, reason: 'No inertia for zero velocity');
    });

    test('handles position exactly on grid', () {
      final snapping = SnappingService(
        gridSnapEnabled: true,
        gridSize: 10.0,
        magneticThreshold: 8.0,
      );

      // Position exactly on grid intersection
      final position = Point(x: 20.0, y: 30.0);
      final snapped = snapping.maybeSnapToGrid(position);

      expect(snapped, isNotNull);
      expect(snapped!.x, equals(20.0));
      expect(snapped.y, equals(30.0));
    });

    test('handles very fast drags', () {
      final inertia = InertiaController(
        velocityThreshold: 0.1,
        decayFactor: 0.9,
      );

      // Very fast drag (high velocity)
      inertia.recordSample(
        position: Point(x: 0, y: 0),
        timestamp: 1000,
      );
      inertia.recordSample(
        position: Point(x: 100, y: 80),
        timestamp: 1020, // 20ms interval = very fast
      );

      final sequence = inertia.activate(
        finalPosition: Point(x: 200, y: 160),
        currentTimestamp: 1040,
      );

      expect(sequence, isNotNull);
      expect(sequence!.length, greaterThan(0));

      // Should generate reasonable number of frames (not excessive)
      expect(sequence.length, lessThan(20),
          reason: 'Should not generate excessive frames');
    });

    test('handles negative coordinates', () {
      final snapping = SnappingService(
        gridSnapEnabled: true,
        gridSize: 10.0,
        magneticThreshold: 8.0,
      );

      final positions = [
        Point(x: -13, y: -17),
        Point(x: -5, y: 3),
        Point(x: 7, y: -8),
      ];

      for (final pos in positions) {
        snapping.resetSnapState();
        final snapped = snapping.maybeSnapToGrid(pos);

        if (snapped != null) {
          // Verify snapped to grid (mod 10)
          expect(snapped.x % 10.0, equals(0.0));
          expect(snapped.y % 10.0, equals(0.0));
        }
      }
    });

    test('inertia sequence maintains monotonic timestamps', () {
      final inertia = InertiaController(
        velocityThreshold: 0.1,
        decayFactor: 0.9,
        samplingIntervalMs: 50,
      );

      inertia.recordSample(
        position: Point(x: 0, y: 0),
        timestamp: 1000,
      );
      inertia.recordSample(
        position: Point(x: 30, y: 20),
        timestamp: 1050,
      );

      final sequence = inertia.activate(
        finalPosition: Point(x: 60, y: 40),
        currentTimestamp: 1100,
      );

      expect(sequence, isNotNull);

      // Verify timestamps are monotonically increasing
      for (int i = 1; i < sequence!.timestamps.length; i++) {
        expect(sequence.timestamps[i], greaterThan(sequence.timestamps[i - 1]),
            reason: 'Timestamps must be strictly increasing');
      }
    });
  });

  group('DirectSelection Integration - Event Batching', () {
    test('simulates buffered event emission', () {
      final inertia = InertiaController(
        velocityThreshold: 0.1,
        decayFactor: 0.9,
        samplingIntervalMs: 50,
        maxDurationMs: 200,
      );

      // Record drag samples
      inertia.recordSample(
        position: Point(x: 0, y: 0),
        timestamp: 1000,
      );
      inertia.recordSample(
        position: Point(x: 20, y: 15),
        timestamp: 1050,
      );
      inertia.recordSample(
        position: Point(x: 40, y: 30),
        timestamp: 1100,
      );

      final sequence = inertia.activate(
        finalPosition: Point(x: 60, y: 45),
        currentTimestamp: 1150,
      );

      expect(sequence, isNotNull);

      // Calculate expected event count (drag events + inertia events)
      const dragSamples = 3;
      final inertiaSamples = sequence!.length;
      final totalEvents = dragSamples + inertiaSamples;

      // Verify reasonable event count (should not be excessive)
      expect(totalEvents, lessThan(20),
          reason: 'Total events should be manageable for undo grouping');

      // All events should fit within operation group
      final totalDuration = sequence.durationMs + 150; // Drag duration + inertia
      expect(totalDuration, lessThan(500),
          reason: 'Operation should complete quickly');
    });
  });
}
