import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/application/tools/direct_selection/snapping_service.dart';
import 'package:wiretuner/domain/events/event_base.dart';

void main() {
  group('SnappingService - Grid Snapping', () {
    late SnappingService service;

    setUp(() {
      service = SnappingService(
        snapEnabled: true,
        gridSize: 10.0,
        angleIncrement: 15.0,
      );
    });

    test('snaps to nearest grid intersection', () {
      // Test various positions
      expect(
        service.snapToGrid(const Point(x: 12.3, y: 45.6)),
        equals(const Point(x: 10.0, y: 50.0)),
      );

      expect(
        service.snapToGrid(const Point(x: 17.8, y: 43.2)),
        equals(const Point(x: 20.0, y: 40.0)),
      );

      expect(
        service.snapToGrid(const Point(x: 5.0, y: 5.0)),
        equals(const Point(x: 10.0, y: 10.0)),
      );
    });

    test('snaps exactly on-grid positions correctly', () {
      expect(
        service.snapToGrid(const Point(x: 10.0, y: 20.0)),
        equals(const Point(x: 10.0, y: 20.0)),
      );

      expect(
        service.snapToGrid(const Point(x: 0.0, y: 0.0)),
        equals(const Point(x: 0.0, y: 0.0)),
      );
    });

    test('handles negative coordinates', () {
      expect(
        service.snapToGrid(const Point(x: -12.3, y: -45.6)),
        equals(const Point(x: -10.0, y: -50.0)),
      );

      expect(
        service.snapToGrid(const Point(x: -5.0, y: -5.0)),
        equals(const Point(x: -10.0, y: -10.0)),
      );
    });

    test('returns original position when snap disabled', () {
      service.setSnapEnabled(false);

      const original = Point(x: 12.3, y: 45.6);
      expect(service.snapToGrid(original), equals(original));
    });

    test('uses correct grid size for custom values', () {
      final customService = SnappingService(
        snapEnabled: true,
        gridSize: 25.0,
      );

      expect(
        customService.snapToGrid(const Point(x: 30.0, y: 40.0)),
        equals(const Point(x: 25.0, y: 50.0)),
      );
    });
  });

  group('SnappingService - Angle Snapping', () {
    late SnappingService service;

    setUp(() {
      service = SnappingService(
        snapEnabled: true,
        gridSize: 10.0,
        angleIncrement: 15.0,
      );
    });

    /// Helper to calculate angle in degrees from a point
    double calculateAngleDegrees(Point p) {
      final radians = math.atan2(p.y, p.x);
      final degrees = radians * (180.0 / math.pi);
      return degrees < 0 ? degrees + 360.0 : degrees;
    }

    /// Helper to create a vector from angle and magnitude
    Point vectorFromAngle(double degrees, double magnitude) {
      final radians = degrees * (math.pi / 180.0);
      return Point(
        x: math.cos(radians) * magnitude,
        y: math.sin(radians) * magnitude,
      );
    }

    test('snaps to nearest 15° increment', () {
      const magnitude = 10.0;

      // Test snapping near 0°
      final vec7deg = vectorFromAngle(7.0, magnitude);
      final snapped7 = service.snapHandleToAngle(vec7deg);
      expect(calculateAngleDegrees(snapped7), closeTo(0.0, 0.1));

      // Test snapping near 30°
      final vec23deg = vectorFromAngle(23.0, magnitude);
      final snapped23 = service.snapHandleToAngle(vec23deg);
      expect(calculateAngleDegrees(snapped23), closeTo(30.0, 0.1));

      // Test snapping near 45°
      final vec52deg = vectorFromAngle(52.0, magnitude);
      final snapped52 = service.snapHandleToAngle(vec52deg);
      expect(calculateAngleDegrees(snapped52), closeTo(45.0, 0.1));

      // Test snapping near 90°
      final vec88deg = vectorFromAngle(88.0, magnitude);
      final snapped88 = service.snapHandleToAngle(vec88deg);
      expect(calculateAngleDegrees(snapped88), closeTo(90.0, 0.1));
    });

    test('preserves handle magnitude after snapping', () {
      const originalMagnitude = 50.0;
      final vec = vectorFromAngle(23.0, originalMagnitude);

      final snapped = service.snapHandleToAngle(vec);

      // Calculate snapped magnitude
      final snappedMagnitude =
          math.sqrt(snapped.x * snapped.x + snapped.y * snapped.y);

      expect(snappedMagnitude, closeTo(originalMagnitude, 0.01));
    });

    test('snaps all 24 increments correctly (0°, 15°, 30°, ... 345°)', () {
      const magnitude = 10.0;

      for (int i = 0; i < 24; i++) {
        final targetAngle = i * 15.0;
        final testAngle = targetAngle + 5.0; // Offset by 5°

        final vec = vectorFromAngle(testAngle, magnitude);
        final snapped = service.snapHandleToAngle(vec);

        expect(
          calculateAngleDegrees(snapped),
          closeTo(targetAngle, 0.1),
          reason: 'Failed for target angle $targetAngle°',
        );
      }
    });

    test('handles negative angles (270°, 180°)', () {
      const magnitude = 10.0;

      // Test 270° (down)
      final vec270 = vectorFromAngle(270.0, magnitude);
      final snapped270 = service.snapHandleToAngle(vec270);
      expect(calculateAngleDegrees(snapped270), closeTo(270.0, 0.1));

      // Test 180° (left)
      final vec180 = vectorFromAngle(180.0, magnitude);
      final snapped180 = service.snapHandleToAngle(vec180);
      expect(calculateAngleDegrees(snapped180), closeTo(180.0, 0.1));
    });

    test('returns original vector when snap disabled', () {
      service.setSnapEnabled(false);

      const original = Point(x: 10.0, y: 5.0);
      final snapped = service.snapHandleToAngle(original);

      expect(snapped, equals(original));
    });

    test('handles zero-length vectors', () {
      const zeroVec = Point(x: 0.0, y: 0.0);
      final snapped = service.snapHandleToAngle(zeroVec);

      // Should return Point(0, 0) without error
      expect(snapped.x.isNaN, isFalse);
      expect(snapped.y.isNaN, isFalse);
    });

    test('uses correct angle increment for custom values', () {
      final customService = SnappingService(
        snapEnabled: true,
        angleIncrement: 45.0, // Snap to 45° increments
      );

      final vec23deg = vectorFromAngle(23.0, 10.0);
      final snapped = customService.snapHandleToAngle(vec23deg);

      // Should snap to 0° or 45° (nearest 45° increment)
      // 23° is closer to 0° (diff = 23°) than to 45° (diff = 22°), so snaps to 45°
      expect(calculateAngleDegrees(snapped), closeTo(45.0, 1.0));

      final vec70deg = vectorFromAngle(70.0, 10.0);
      final snapped70 = customService.snapHandleToAngle(vec70deg);

      // Should snap to 90° (nearest 45° increment)
      expect(calculateAngleDegrees(snapped70), closeTo(90.0, 1.0));
    });
  });

  group('SnappingService - Snap Toggle', () {
    test('setSnapEnabled toggles snapping behavior', () {
      final service = SnappingService(
        snapEnabled: false,
        gridSize: 10.0,
      );

      const testPos = Point(x: 12.3, y: 45.6);

      // Initially disabled
      expect(service.snapToGrid(testPos), equals(testPos));

      // Enable snapping
      service.setSnapEnabled(true);
      expect(service.snapToGrid(testPos), equals(const Point(x: 10.0, y: 50.0)));

      // Disable again
      service.setSnapEnabled(false);
      expect(service.snapToGrid(testPos), equals(testPos));
    });
  });

  group('SnappingService - Path Snapping', () {
    test('snapToPath returns null (not implemented)', () {
      final service = SnappingService(snapEnabled: true);

      final result = service.snapToPath(const Point(x: 10, y: 10), []);

      expect(result, isNull);
    });
  });
}
