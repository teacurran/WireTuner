import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/application/tools/direct_selection/drag_controller.dart';
import 'package:wiretuner/application/tools/direct_selection/handle_drag_controller.dart';
import 'package:wiretuner/application/tools/direct_selection/snapping_service.dart';
import 'package:wiretuner/domain/events/event_base.dart' hide AnchorType;
import 'package:wiretuner/domain/models/anchor_point.dart';
import 'package:wiretuner/presentation/canvas/overlays/selection_overlay.dart';

void main() {
  group('HandleDragController', () {
    late HandleDragController controller;
    late SnappingService snappingService;
    late DragController baseDragController;

    setUp(() {
      baseDragController = DragController();
      snappingService = SnappingService(
        gridSnapEnabled: true,
        angleSnapEnabled: true,
        gridSize: 10.0,
        angleIncrement: 15.0,
      );
      controller = HandleDragController(
        baseDragController: baseDragController,
        snappingService: snappingService,
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

    group('calculateDragUpdate - handleOut', () {
      test('snaps handleOut angle to 15° increments', () {
        final anchor = AnchorPoint.smooth(
          position: const Point(x: 100, y: 100),
          handleOut: const Point(x: 50, y: 0), // 0° angle
        );

        // Drag to create ~21.8° angle (atan2(20, 50))
        // Original handleOut is at (150, 100), drag to (150, 120)
        // New handleOut relative to anchor = (50, 20)
        final result = controller.calculateDragUpdate(
          anchor: anchor,
          delta: const Point(x: 0, y: 20),
          component: AnchorComponent.handleOut,
        );

        // Verify handleOut angle snapped to 15° (nearest 15° increment to ~21.8°)
        final angle = calculateAngleDegrees(result.handleOut!);
        expect(angle, closeTo(15.0, 1.0));

        // Verify smooth anchor constraint: handleIn = -handleOut
        expect(result.handleIn!.x, closeTo(-result.handleOut!.x, 0.1));
        expect(result.handleIn!.y, closeTo(-result.handleOut!.y, 0.1));
      });

      test('preserves handle magnitude after angle snapping', () {
        final anchor = AnchorPoint(
          position: const Point(x: 100, y: 100),
          handleOut: const Point(x: 50, y: 0),
          anchorType: AnchorType.corner,
        );

        // Drag to create ~21.8° angle
        final result = controller.calculateDragUpdate(
          anchor: anchor,
          delta: const Point(x: 0, y: 20),
          component: AnchorComponent.handleOut,
        );

        // Calculate magnitude of snapped handleOut
        final originalMagnitude = math.sqrt(50 * 50 + 20 * 20); // ~53.85
        final snappedMagnitude = math.sqrt(
          result.handleOut!.x * result.handleOut!.x +
              result.handleOut!.y * result.handleOut!.y,
        );

        expect(snappedMagnitude, closeTo(originalMagnitude, 0.1));
      });

      test('maintains smooth anchor constraint after snapping', () {
        final anchor = AnchorPoint.smooth(
          position: const Point(x: 100, y: 100),
          handleOut: const Point(x: 50, y: 0),
        );

        // Drag handleOut
        final result = controller.calculateDragUpdate(
          anchor: anchor,
          delta: const Point(x: 10, y: 20),
          component: AnchorComponent.handleOut,
        );

        // Verify smooth constraint: handleIn = -handleOut (perfect mirror)
        expect(result.handleIn!.x, equals(-result.handleOut!.x));
        expect(result.handleIn!.y, equals(-result.handleOut!.y));
      });

      test('maintains symmetric anchor constraint after snapping', () {
        final anchor = AnchorPoint(
          position: const Point(x: 100, y: 100),
          handleIn: const Point(x: -30, y: 0), // 180°, magnitude 30
          handleOut: const Point(x: 50, y: 0), // 0°, magnitude 50
          anchorType: AnchorType.symmetric,
        );

        // Drag handleOut to create ~21.8° angle
        final result = controller.calculateDragUpdate(
          anchor: anchor,
          delta: const Point(x: 0, y: 20),
          component: AnchorComponent.handleOut,
        );

        // Verify collinearity (handles are opposite angles)
        final handleOutAngle = calculateAngleDegrees(result.handleOut!);
        final handleInAngle = calculateAngleDegrees(result.handleIn!);

        // Angles should be 180° apart (within tolerance)
        final angleDiff = (handleOutAngle - handleInAngle).abs();
        expect(angleDiff, closeTo(180.0, 1.0));

        // Verify handleIn magnitude preserved (30.0)
        final handleInMagnitude = math.sqrt(
          result.handleIn!.x * result.handleIn!.x +
              result.handleIn!.y * result.handleIn!.y,
        );
        expect(handleInMagnitude, closeTo(30.0, 0.1));
      });

      test('corner anchor handles move independently', () {
        final anchor = AnchorPoint(
          position: const Point(x: 100, y: 100),
          handleIn: const Point(x: -20, y: -10),
          handleOut: const Point(x: 50, y: 0),
          anchorType: AnchorType.corner,
        );

        final originalHandleIn = anchor.handleIn;

        // Drag handleOut
        final result = controller.calculateDragUpdate(
          anchor: anchor,
          delta: const Point(x: 0, y: 20),
          component: AnchorComponent.handleOut,
        );

        // Verify handleIn unchanged (corner = independent)
        expect(result.handleIn, equals(originalHandleIn));

        // Verify handleOut changed
        expect(result.handleOut, isNot(equals(anchor.handleOut)));
      });

      test('does not snap when snapping disabled', () {
        snappingService.setSnapEnabled(false);

        final anchor = AnchorPoint(
          position: const Point(x: 100, y: 100),
          handleOut: const Point(x: 50, y: 0),
          anchorType: AnchorType.corner,
        );

        // Drag to create ~21.8° angle
        final result = controller.calculateDragUpdate(
          anchor: anchor,
          delta: const Point(x: 0, y: 20),
          component: AnchorComponent.handleOut,
        );

        // Verify angle NOT snapped (should be ~21.8°)
        final angle = calculateAngleDegrees(result.handleOut!);
        expect(angle, closeTo(21.8, 1.0));
      });
    });

    group('calculateDragUpdate - handleIn', () {
      test('snaps handleIn angle to 15° increments', () {
        final anchor = AnchorPoint.smooth(
          position: const Point(x: 100, y: 100),
          handleOut: const Point(x: 50, y: 0),
        );

        // Drag handleIn (originally at (50, 100)) to (50, 80)
        // New handleIn relative to anchor = (-50, -20)
        final result = controller.calculateDragUpdate(
          anchor: anchor,
          delta: const Point(x: 0, y: -20),
          component: AnchorComponent.handleIn,
        );

        // Verify handleIn angle snapped
        // atan2(-20, -50) = ~201.8° → snaps to 195° (nearest 15° increment)
        final angle = calculateAngleDegrees(result.handleIn!);
        expect(angle, closeTo(195.0, 2.0));

        // Verify smooth anchor constraint: handleOut = -handleIn
        expect(result.handleOut!.x, closeTo(-result.handleIn!.x, 0.1));
        expect(result.handleOut!.y, closeTo(-result.handleIn!.y, 0.1));
      });

      test('maintains smooth constraint when dragging handleIn', () {
        final anchor = AnchorPoint.smooth(
          position: const Point(x: 100, y: 100),
          handleOut: const Point(x: 50, y: 0),
        );

        final result = controller.calculateDragUpdate(
          anchor: anchor,
          delta: const Point(x: -10, y: -20),
          component: AnchorComponent.handleIn,
        );

        // Verify smooth constraint maintained
        expect(result.handleOut!.x, equals(-result.handleIn!.x));
        expect(result.handleOut!.y, equals(-result.handleIn!.y));
      });
    });

    group('calculateFeedbackMetrics', () {
      test('returns correct angle and length metrics', () {
        final handleVector = vectorFromAngle(23.0, 50.0);

        final metrics = controller.calculateFeedbackMetrics(
          handleVector: handleVector,
        );

        // Angle should be snapped to 30° (nearest 15° increment)
        expect(metrics['angle'], closeTo(30.0, 1.0));

        // Length should be preserved
        expect(metrics['length'], closeTo(50.0, 0.1));

        // Should indicate snapping occurred
        expect(metrics['snapped'], isTrue);
      });

      test('indicates no snap when already on angle increment', () {
        final handleVector = vectorFromAngle(30.0, 50.0);

        final metrics = controller.calculateFeedbackMetrics(
          handleVector: handleVector,
        );

        expect(metrics['angle'], closeTo(30.0, 0.1));
        expect(metrics['length'], closeTo(50.0, 0.1));
        expect(metrics['snapped'], isFalse);
      });

      test('handles all 24 angle increments', () {
        for (int i = 0; i < 24; i++) {
          final targetAngle = i * 15.0;
          final testAngle = targetAngle + 5.0; // Offset by 5°

          final handleVector = vectorFromAngle(testAngle, 10.0);
          final metrics = controller.calculateFeedbackMetrics(
            handleVector: handleVector,
          );

          expect(
            metrics['angle'],
            closeTo(targetAngle, 1.0),
            reason: 'Failed for target angle $targetAngle°',
          );
        }
      });

      test('respects snap enabled state', () {
        snappingService.setSnapEnabled(false);

        final handleVector = vectorFromAngle(23.0, 50.0);
        final metrics = controller.calculateFeedbackMetrics(
          handleVector: handleVector,
        );

        // Angle should NOT be snapped
        expect(metrics['angle'], closeTo(23.0, 1.0));
        expect(metrics['snapped'], isFalse);
      });
    });

    group('edge cases', () {
      test('handles zero-length handle vectors', () {
        final anchor = AnchorPoint(
          position: const Point(x: 100, y: 100),
          handleOut: const Point(x: 0, y: 0),
          anchorType: AnchorType.corner,
        );

        final result = controller.calculateDragUpdate(
          anchor: anchor,
          delta: const Point(x: 0, y: 0),
          component: AnchorComponent.handleOut,
        );

        // Should not crash, return valid result
        expect(result.handleOut, isNotNull);
      });

      test('does not mutate input anchor', () {
        final anchor = AnchorPoint.smooth(
          position: const Point(x: 100, y: 100),
          handleOut: const Point(x: 50, y: 0),
        );

        final originalHandleOut = anchor.handleOut;

        controller.calculateDragUpdate(
          anchor: anchor,
          delta: const Point(x: 10, y: 20),
          component: AnchorComponent.handleOut,
        );

        // Verify original anchor unchanged
        expect(anchor.handleOut, equals(originalHandleOut));
      });
    });
  });
}
