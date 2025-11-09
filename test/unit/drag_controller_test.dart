import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/application/tools/direct_selection/anchor_drag_controller.dart';
import 'package:wiretuner/application/tools/direct_selection/drag_controller.dart';
import 'package:wiretuner/application/tools/direct_selection/handle_drag_controller.dart';
import 'package:wiretuner/application/tools/direct_selection/snapping_service.dart';
import 'package:wiretuner/domain/events/event_base.dart' hide AnchorType;
import 'package:wiretuner/domain/models/anchor_point.dart';
import 'package:wiretuner/presentation/canvas/overlays/selection_overlay.dart';

void main() {
  group('AnchorDragController', () {
    late AnchorDragController controller;
    late SnappingService snappingService;

    setUp(() {
      snappingService = SnappingService(
        gridSnapEnabled: true, angleSnapEnabled: true,
        gridSize: 10.0,
        angleIncrement: 15.0,
      );

      controller = AnchorDragController(
        baseDragController: DragController(),
        snappingService: snappingService,
      );
    });

    test('snaps anchor position to grid when enabled', () {
      const anchor = AnchorPoint(
        position: Point(x: 100, y: 100),
        handleOut: Point(x: 50, y: 0),
        handleIn: Point(x: -50, y: 0),
        anchorType: AnchorType.smooth,
      );

      // Drag by (12.3, 5.7) - should snap to (10, 10)
      final result = controller.calculateDragUpdate(
        anchor: anchor,
        delta: const Point(x: 12.3, y: 5.7),
      );

      // Expected snapped position: (100 + 10, 100 + 10) = (110, 110)
      expect(result.position!.x, closeTo(110.0, 0.1));
      expect(result.position!.y, closeTo(110.0, 0.1));

      // Handles should remain unchanged (relative offsets)
      expect(result.handleIn, equals(anchor.handleIn));
      expect(result.handleOut, equals(anchor.handleOut));
    });

    test('returns original position when snap disabled', () {
      snappingService.setSnapEnabled(false);

      const anchor = AnchorPoint(
        position: Point(x: 100, y: 100),
        anchorType: AnchorType.corner,
      );

      final result = controller.calculateDragUpdate(
        anchor: anchor,
        delta: const Point(x: 12.3, y: 5.7),
      );

      // Should be (100 + 12.3, 100 + 5.7) = (112.3, 105.7)
      expect(result.position!.x, closeTo(112.3, 0.1));
      expect(result.position!.y, closeTo(105.7, 0.1));
    });

    test('does not mutate original anchor', () {
      const anchor = AnchorPoint(
        position: Point(x: 100, y: 100),
        handleOut: Point(x: 50, y: 0),
      );

      final originalX = anchor.position.x;
      final originalY = anchor.position.y;

      controller.calculateDragUpdate(
        anchor: anchor,
        delta: const Point(x: 10.3, y: 5.7),
      );

      // Verify original anchor unchanged
      expect(anchor.position.x, equals(originalX));
      expect(anchor.position.y, equals(originalY));
    });

    test('calculateFeedbackMetrics returns correct position', () {
      const position = Point(x: 123.4, y: 567.8);
      const originalPosition = Point(x: 100, y: 100);

      final metrics = controller.calculateFeedbackMetrics(
        position: position,
        originalPosition: originalPosition,
      );

      // With snap enabled, should snap to (120, 570)
      expect(metrics['x'], closeTo(120.0, 0.1));
      expect(metrics['y'], closeTo(570.0, 0.1));
      expect(metrics['snapped'], isTrue);
    });
  });

  group('HandleDragController', () {
    late HandleDragController controller;
    late SnappingService snappingService;

    setUp(() {
      snappingService = SnappingService(
        gridSnapEnabled: true, angleSnapEnabled: true,
        gridSize: 10.0,
        angleIncrement: 15.0,
      );

      controller = HandleDragController(
        baseDragController: DragController(),
        snappingService: snappingService,
      );
    });

    /// Helper to calculate angle in degrees
    double calculateAngleDegrees(Point p) {
      final radians = math.atan2(p.y, p.x);
      final degrees = radians * (180.0 / math.pi);
      return degrees < 0 ? degrees + 360.0 : degrees;
    }

    test('snaps handleOut to nearest 15° increment', () {
      const anchor = AnchorPoint(
        position: Point(x: 100, y: 100),
        handleOut: Point(x: 50, y: 0), // 0° angle
        handleIn: Point(x: -50, y: 0),
        anchorType: AnchorType.corner,
      );

      // Drag handleOut to create ~21.8° angle
      // Original handleOut at (50, 0), drag by (0, 20) = (50, 20)
      // Angle = atan2(20, 50) = ~21.8°
      final result = controller.calculateDragUpdate(
        anchor: anchor,
        delta: const Point(x: 0, y: 20),
        component: AnchorComponent.handleOut,
      );

      // Should snap to 15° (nearest 15° increment to ~21.8°)
      final snappedAngle = calculateAngleDegrees(result.handleOut!);
      expect(snappedAngle, closeTo(15.0, 2.0));
    });

    test('preserves smooth anchor constraints after snapping', () {
      const anchor = AnchorPoint(
        position: Point(x: 100, y: 100),
        handleOut: Point(x: 50, y: 0),
        handleIn: Point(x: -50, y: 0),
        anchorType: AnchorType.smooth,
      );

      // Drag handleOut
      final result = controller.calculateDragUpdate(
        anchor: anchor,
        delta: const Point(x: 0, y: 30),
        component: AnchorComponent.handleOut,
      );

      // For smooth anchor: handleIn = -handleOut (perfect mirror)
      expect(result.handleIn!.x, closeTo(-result.handleOut!.x, 0.01));
      expect(result.handleIn!.y, closeTo(-result.handleOut!.y, 0.01));

      // Verify magnitudes are equal
      final handleOutMag =
          math.sqrt(result.handleOut!.x * result.handleOut!.x +
              result.handleOut!.y * result.handleOut!.y,);
      final handleInMag = math.sqrt(
          result.handleIn!.x * result.handleIn!.x +
              result.handleIn!.y * result.handleIn!.y,);
      expect(handleOutMag, closeTo(handleInMag, 0.01));
    });

    test('preserves symmetric anchor constraints after snapping', () {
      const anchor = AnchorPoint(
        position: Point(x: 100, y: 100),
        handleOut: Point(x: 50, y: 0), // Length 50
        handleIn: Point(x: -30, y: 0), // Length 30 (different)
        anchorType: AnchorType.symmetric,
      );

      // Drag handleOut
      final result = controller.calculateDragUpdate(
        anchor: anchor,
        delta: const Point(x: 0, y: 30),
        component: AnchorComponent.handleOut,
      );

      // For symmetric anchor: handles are collinear (opposite angles)
      final handleOutAngle = calculateAngleDegrees(result.handleOut!);
      final handleInAngle = calculateAngleDegrees(result.handleIn!);

      // Angles should be 180° apart
      final angleDiff = (handleOutAngle - handleInAngle).abs();
      expect(angleDiff, closeTo(180.0, 1.0));

      // HandleIn length should be preserved (30)
      final handleInMag = math.sqrt(
          result.handleIn!.x * result.handleIn!.x +
              result.handleIn!.y * result.handleIn!.y,);
      expect(handleInMag, closeTo(30.0, 0.1));
    });

    test('allows independent handle movement for corner anchors', () {
      const anchor = AnchorPoint(
        position: Point(x: 100, y: 100),
        handleOut: Point(x: 50, y: 0),
        handleIn: Point(x: 0, y: -30), // Different angle from handleOut
        anchorType: AnchorType.corner,
      );

      final originalHandleIn = anchor.handleIn;

      // Drag handleOut
      final result = controller.calculateDragUpdate(
        anchor: anchor,
        delta: const Point(x: 0, y: 30),
        component: AnchorComponent.handleOut,
      );

      // HandleIn should remain unchanged
      expect(result.handleIn, equals(originalHandleIn));

      // HandleOut should be snapped
      final snappedAngle = calculateAngleDegrees(result.handleOut!);
      expect(snappedAngle, closeTo(30.0, 1.0));
    });

    test('does not mutate original anchor', () {
      const anchor = AnchorPoint(
        position: Point(x: 100, y: 100),
        handleOut: Point(x: 50, y: 0),
        anchorType: AnchorType.corner,
      );

      final originalHandleOut = anchor.handleOut;

      controller.calculateDragUpdate(
        anchor: anchor,
        delta: const Point(x: 0, y: 30),
        component: AnchorComponent.handleOut,
      );

      // Verify original anchor unchanged
      expect(anchor.handleOut, equals(originalHandleOut));
    });

    test('returns original handles when snap disabled', () {
      snappingService.setSnapEnabled(false);

      const anchor = AnchorPoint(
        position: Point(x: 100, y: 100),
        handleOut: Point(x: 50, y: 0),
        anchorType: AnchorType.corner,
      );

      // Drag by (0, 20) creates ~21.8° angle (not snapped)
      final result = controller.calculateDragUpdate(
        anchor: anchor,
        delta: const Point(x: 0, y: 20),
        component: AnchorComponent.handleOut,
      );

      // Should be unsnapped: (50, 20)
      expect(result.handleOut!.x, closeTo(50.0, 0.1));
      expect(result.handleOut!.y, closeTo(20.0, 0.1));
    });

    test('calculateFeedbackMetrics returns correct angle and length', () {
      const handleVector = Point(x: 10.0, y: 5.0);

      final metrics = controller.calculateFeedbackMetrics(
        handleVector: handleVector,
      );

      // Original angle ~26.6°, should snap to 30°
      expect(metrics['angle'], closeTo(30.0, 1.0));

      // Length should be sqrt(10^2 + 5^2) = 11.18
      expect(metrics['length'], closeTo(11.18, 0.1));

      expect(metrics['snapped'], isTrue);
    });

    test('handles zero-length vectors without error', () {
      const anchor = AnchorPoint(
        position: Point(x: 100, y: 100),
        handleOut: Point(x: 0, y: 0), // Zero-length
        anchorType: AnchorType.corner,
      );

      final result = controller.calculateDragUpdate(
        anchor: anchor,
        delta: const Point(x: 0, y: 0),
        component: AnchorComponent.handleOut,
      );

      // Should not crash
      expect(result.handleOut, isNotNull);
    });
  });

  group('HandleDragController - HandleIn Dragging', () {
    late HandleDragController controller;
    late SnappingService snappingService;

    setUp(() {
      snappingService = SnappingService(
        gridSnapEnabled: true, angleSnapEnabled: true,
        gridSize: 10.0,
        angleIncrement: 15.0,
      );

      controller = HandleDragController(
        baseDragController: DragController(),
        snappingService: snappingService,
      );
    });

    test('snaps handleIn and updates handleOut for smooth anchor', () {
      const anchor = AnchorPoint(
        position: Point(x: 100, y: 100),
        handleIn: Point(x: -50, y: 0),
        handleOut: Point(x: 50, y: 0),
        anchorType: AnchorType.smooth,
      );

      // Drag handleIn
      final result = controller.calculateDragUpdate(
        anchor: anchor,
        delta: const Point(x: 0, y: -30),
        component: AnchorComponent.handleIn,
      );

      // HandleIn and HandleOut should be perfectly mirrored
      expect(result.handleIn!.x, closeTo(-result.handleOut!.x, 0.01));
      expect(result.handleIn!.y, closeTo(-result.handleOut!.y, 0.01));
    });
  });
}
