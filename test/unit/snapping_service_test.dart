import 'package:wiretuner/domain/events/event_base.dart' show Point;
import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/application/tools/direct_selection/snapping_service.dart';
import 'package:wiretuner/domain/models/geometry/point_extensions.dart';

void main() {
  group('SnappingService - Magnetic Grid Snapping', () {
    test('snaps to nearest grid when within threshold', () {
      final service = SnappingService(
        gridSnapEnabled: true,
        gridSize: 10.0,
        magneticThreshold: 8.0,
      );

      // Position 7px away from grid intersection (10, 20)
      final position = Point(x: 13.0, y: 17.0);
      final snapped = service.maybeSnapToGrid(position);

      expect(snapped, isNotNull);
      expect(snapped!.x, equals(10.0));
      expect(snapped.y, equals(20.0));
    });

    test('does not snap when outside threshold', () {
      final service = SnappingService(
        gridSnapEnabled: true,
        gridSize: 10.0,
        magneticThreshold: 5.0,
      );

      // Position 7px away from nearest grid intersection
      final position = Point(x: 13.0, y: 17.0);
      final snapped = service.maybeSnapToGrid(position);

      expect(snapped, isNull);
    });

    test('applies hysteresis to prevent jittering', () {
      final service = SnappingService(
        gridSnapEnabled: true,
        gridSize: 10.0,
        magneticThreshold: 5.0,
        hysteresisMargin: 2.0,
      );

      // First snap - within threshold
      final pos1 = Point(x: 13.0, y: 20.0);
      final snap1 = service.maybeSnapToGrid(pos1);
      expect(snap1, isNotNull);
      expect(snap1!.x, equals(10.0));

      // Move slightly outside original threshold but within hysteresis
      final pos2 = Point(x: 16.5, y: 20.0);
      final snap2 = service.maybeSnapToGrid(pos2);
      expect(snap2, isNotNull, reason: 'Hysteresis should keep snap active');
      expect(snap2!.x, equals(10.0));

      // Move far outside threshold + hysteresis
      final pos3 = Point(x: 18.0, y: 20.0);
      final snap3 = service.maybeSnapToGrid(pos3);
      expect(snap3, isNull, reason: 'Should release snap outside hysteresis');
    });

    test('snaps to correct grid intersection', () {
      final service = SnappingService(
        gridSnapEnabled: true,
        gridSize: 10.0,
        magneticThreshold: 8.0,
      );

      // Test multiple grid intersections
      final testCases = [
        (Point(x: 2.0, y: 3.0), Point(x: 0.0, y: 0.0)),
        (Point(x: 28.0, y: 32.0), Point(x: 30.0, y: 30.0)),
        (Point(x: 95.0, y: 105.0), Point(x: 100.0, y: 100.0)),
      ];

      for (final (input, expected) in testCases) {
        service.resetSnapState();
        final snapped = service.maybeSnapToGrid(input);
        expect(snapped, isNotNull);
        expect(snapped!.x, equals(expected.x),
            reason: 'X should snap to ${expected.x}');
        expect(snapped.y, equals(expected.y),
            reason: 'Y should snap to ${expected.y}');
      }
    });

    test('respects gridSnapEnabled flag', () {
      final service = SnappingService(
        gridSnapEnabled: false,
        gridSize: 10.0,
        magneticThreshold: 8.0,
      );

      final position = Point(x: 13.0, y: 17.0);
      final snapped = service.maybeSnapToGrid(position);

      expect(snapped, isNull, reason: 'Should not snap when disabled');
    });

    test('resetSnapState clears hysteresis', () {
      final service = SnappingService(
        gridSnapEnabled: true,
        gridSize: 10.0,
        magneticThreshold: 5.0,
        hysteresisMargin: 2.0,
      );

      // Snap to grid
      final pos1 = Point(x: 13.0, y: 20.0);
      service.maybeSnapToGrid(pos1);

      // Reset state
      service.resetSnapState();

      // Position outside original threshold should not snap
      final pos2 = Point(x: 16.5, y: 20.0);
      final snap2 = service.maybeSnapToGrid(pos2);
      expect(snap2, isNull, reason: 'Hysteresis should be cleared');
    });
  });

  group('SnappingService - Accuracy', () {
    test('maintains sub-pixel accuracy for grid snapping', () {
      final service = SnappingService(
        gridSnapEnabled: true,
        gridSize: 10.0,
        magneticThreshold: 8.0,
      );

      // Test that snapped positions are exactly on grid
      final positions = [
        Point(x: 10.1, y: 20.2),
        Point(x: 29.9, y: 39.8),
        Point(x: 50.5, y: 60.5),
      ];

      for (final pos in positions) {
        service.resetSnapState();
        final snapped = service.maybeSnapToGrid(pos);
        expect(snapped, isNotNull);

        // Verify exact grid alignment
        final xError = (snapped!.x % service.gridSize).abs();
        final yError = (snapped.y % service.gridSize).abs();

        expect(xError, lessThan(0.001),
            reason: 'X drift should be <0.001px');
        expect(yError, lessThan(0.001),
            reason: 'Y drift should be <0.001px');
      }
    });

    test('angle snapping maintains magnitude exactly', () {
      final service = SnappingService(
        angleSnapEnabled: true,
        angleIncrement: 15.0,
      );

      final testVectors = [
        Point(x: 10.0, y: 5.0),
        Point(x: 20.0, y: 15.0),
        Point(x: -10.0, y: 8.0),
      ];

      for (final vector in testVectors) {
        final originalMagnitude = vector.magnitude;
        final snapped = service.snapHandleToAngle(vector);
        final snappedMagnitude = snapped.magnitude;

        final magnitudeError = (snappedMagnitude - originalMagnitude).abs();
        expect(magnitudeError, lessThan(0.001),
            reason: 'Magnitude should be preserved within 0.001px');
      }
    });
  });

  group('SnappingService - Legacy API', () {
    test('snapToGrid always snaps when enabled (non-magnetic)', () {
      final service = SnappingService(
        gridSnapEnabled: true,
        gridSize: 10.0,
      );

      // Far from grid - should still snap
      final position = Point(x: 23.7, y: 48.2);
      final snapped = service.snapToGrid(position);

      expect(snapped.x, equals(20.0));
      expect(snapped.y, equals(50.0));
    });

    test('setSnapEnabled enables both grid and angle', () {
      final service = SnappingService();

      expect(service.gridSnapEnabled, isFalse);
      expect(service.angleSnapEnabled, isFalse);

      service.setSnapEnabled(true);

      expect(service.gridSnapEnabled, isTrue);
      expect(service.angleSnapEnabled, isTrue);
    });

    test('setSnapMode allows independent control', () {
      final service = SnappingService();

      service.setSnapMode(gridEnabled: true, angleEnabled: false);
      expect(service.gridSnapEnabled, isTrue);
      expect(service.angleSnapEnabled, isFalse);

      service.setSnapMode(gridEnabled: false, angleEnabled: true);
      expect(service.gridSnapEnabled, isFalse);
      expect(service.angleSnapEnabled, isTrue);

      // Partial updates
      service.setSnapMode(gridEnabled: true);
      expect(service.gridSnapEnabled, isTrue);
      expect(service.angleSnapEnabled, isTrue, reason: 'Should not change');
    });
  });

  group('SnappingService - Performance', () {
    test('magnetic snapping completes quickly', () {
      final service = SnappingService(
        gridSnapEnabled: true,
        gridSize: 10.0,
        magneticThreshold: 8.0,
      );

      final stopwatch = Stopwatch()..start();
      const iterations = 1000;

      for (int i = 0; i < iterations; i++) {
        service.resetSnapState();
        service.maybeSnapToGrid(Point(x: i * 0.5, y: i * 0.3));
      }

      stopwatch.stop();
      final avgMicroseconds = stopwatch.elapsedMicroseconds / iterations;

      // Should be < 500 microseconds (0.5ms) per call
      expect(avgMicroseconds, lessThan(500),
          reason: 'Magnetic snapping should be < 0.5ms per call');
    });
  });
}
