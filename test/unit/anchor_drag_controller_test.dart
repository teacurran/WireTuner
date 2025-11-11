import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/application/tools/direct_selection/anchor_drag_controller.dart';
import 'package:wiretuner/application/tools/direct_selection/drag_controller.dart';
import 'package:wiretuner/application/tools/direct_selection/snapping_service.dart';
import 'package:wiretuner/domain/events/event_base.dart' hide AnchorType;
import 'package:wiretuner/domain/models/anchor_point.dart';

void main() {
  group('AnchorDragController', () {
    late AnchorDragController controller;
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
      controller = AnchorDragController(
        baseDragController: baseDragController,
        snappingService: snappingService,
      );
    });

    group('calculateDragUpdate', () {
      test('snaps anchor position to grid when snapping enabled', () {
        final anchor = const AnchorPoint(
          position: Point(x: 100, y: 100),
          handleIn: Point(x: -20, y: 0),
          handleOut: Point(x: 20, y: 0),
        );

        // Drag by (12.3, 5.7) - should snap to (10, 10)
        final result = controller.calculateDragUpdate(
          anchor: anchor,
          delta: const Point(x: 12.3, y: 5.7),
        );

        // Verify position snapped to grid (100 + 10, 100 + 10) = (110, 110)
        expect(result.position!.x, equals(110.0));
        expect(result.position!.y, equals(110.0));

        // Verify handles unchanged (relative to anchor)
        expect(result.handleIn, equals(anchor.handleIn));
        expect(result.handleOut, equals(anchor.handleOut));
      });

      test('does not snap when snapping disabled', () {
        snappingService.setSnapEnabled(false);

        final anchor = const AnchorPoint(
          position: Point(x: 100, y: 100),
        );

        // Drag by (12.3, 5.7)
        final result = controller.calculateDragUpdate(
          anchor: anchor,
          delta: const Point(x: 12.3, y: 5.7),
        );

        // Verify position NOT snapped (100 + 12.3, 100 + 5.7) = (112.3, 105.7)
        expect(result.position!.x, equals(112.3));
        expect(result.position!.y, equals(105.7));
      });

      test('handles negative coordinates correctly', () {
        final anchor = const AnchorPoint(
          position: Point(x: -100, y: -100),
        );

        // Drag by (-12.3, -5.7) - should snap to (-10, -10)
        final result = controller.calculateDragUpdate(
          anchor: anchor,
          delta: const Point(x: -12.3, y: -5.7),
        );

        // Verify position snapped to grid (-100 + -10, -100 + -10) = (-110, -110)
        expect(result.position!.x, equals(-110.0));
        expect(result.position!.y, equals(-110.0));
      });

      test('preserves handles when dragging anchor', () {
        final anchor = AnchorPoint.smooth(
          position: const Point(x: 100, y: 100),
          handleOut: const Point(x: 50, y: 0),
        );

        final result = controller.calculateDragUpdate(
          anchor: anchor,
          delta: const Point(x: 10, y: 10),
        );

        // Verify handles preserved
        expect(result.handleIn!.x, equals(-50.0));
        expect(result.handleIn!.y, equals(0.0));
        expect(result.handleOut!.x, equals(50.0));
        expect(result.handleOut!.y, equals(0.0));

        // Verify anchor type preserved
        expect(result.anchorType, equals(AnchorType.smooth));
      });

      test('does not mutate input anchor', () {
        final anchor = const AnchorPoint(
          position: Point(x: 100, y: 100),
          handleOut: Point(x: 50, y: 0),
        );

        final originalPosition = anchor.position;

        controller.calculateDragUpdate(
          anchor: anchor,
          delta: const Point(x: 10, y: 5),
        );

        // Verify original anchor unchanged
        expect(anchor.position, equals(originalPosition));
      });
    });

    group('calculateFeedbackMetrics', () {
      test('returns correct position metrics', () {
        final metrics = controller.calculateFeedbackMetrics(
          position: const Point(x: 123.4, y: 567.8),
          originalPosition: const Point(x: 100, y: 500),
        );

        // Position should be snapped to grid
        expect(metrics['x'], equals(120.0));
        expect(metrics['y'], equals(570.0));
        expect(metrics['snapped'], isTrue);
      });

      test('indicates no snap when position already on grid', () {
        final metrics = controller.calculateFeedbackMetrics(
          position: const Point(x: 120.0, y: 570.0),
          originalPosition: const Point(x: 100, y: 500),
        );

        expect(metrics['x'], equals(120.0));
        expect(metrics['y'], equals(570.0));
        expect(metrics['snapped'], isFalse);
      });

      test('respects snap enabled state', () {
        snappingService.setSnapEnabled(false);

        final metrics = controller.calculateFeedbackMetrics(
          position: const Point(x: 123.4, y: 567.8),
          originalPosition: const Point(x: 100, y: 500),
        );

        // Position should NOT be snapped
        expect(metrics['x'], equals(123.4));
        expect(metrics['y'], equals(567.8));
        expect(metrics['snapped'], isFalse);
      });
    });
  });
}
