import 'dart:math' as math;

import 'package:wiretuner/application/tools/direct_selection/drag_controller.dart';
import 'package:wiretuner/application/tools/direct_selection/snapping_service.dart';
import 'package:wiretuner/domain/events/event_base.dart' hide AnchorType;
import 'package:wiretuner/domain/models/anchor_point.dart';
import 'package:wiretuner/domain/models/geometry/point_extensions.dart';
import 'package:wiretuner/presentation/canvas/overlays/selection_overlay.dart';

/// Controller for Bezier control point handle dragging with angle snapping support.
///
/// This controller extends the basic drag logic from [DragController]
/// by adding angle snapping constraints (e.g., 15° increments) while
/// preserving anchor type constraints (smooth/symmetric/corner).
///
/// ## Responsibilities
///
/// - Wraps [DragController] to apply anchor type constraints
/// - Applies angle snapping to handle vectors when enabled
/// - Reapplies anchor type constraints after snapping
/// - Returns immutable [DragResult] (no side effects)
/// - Calculates feedback metrics (angle, length) for on-canvas display
///
/// ## Anchor Type Constraint Preservation
///
/// **Critical**: Snapping must preserve anchor type constraints:
/// - **Smooth**: After snapping handleOut, mirror to handleIn (handleIn = -handleOut)
/// - **Symmetric**: After snapping handleOut, maintain collinearity but preserve handleIn length
/// - **Corner**: Handles move independently (no mirroring)
///
/// ## Usage
///
/// ```dart
/// final controller = HandleDragController(
///   baseDragController: DragController(),
///   snappingService: snappingService,
/// );
///
/// final result = controller.calculateDragUpdate(
///   anchor: currentAnchor,
///   delta: Point(x: 10.0, y: 5.0),
///   component: AnchorComponent.handleOut,
/// );
///
/// // result.handleOut will be snapped to 15° if snapping enabled
/// // result.handleIn will be updated to maintain anchor type constraints
/// ```
///
/// ## Performance
///
/// - Angle snapping adds < 1ms overhead per drag event
/// - Total drag calculation: < 2ms (meets acceptance criteria)
class HandleDragController {

  HandleDragController({
    required DragController baseDragController,
    required SnappingService snappingService,
  })  : _baseDragController = baseDragController,
        _snappingService = snappingService;
  /// Base drag controller for applying anchor type constraints.
  final DragController _baseDragController;

  /// Snapping service for angle snapping.
  final SnappingService _snappingService;

  /// Calculates the updated anchor state after a handle drag with angle snapping.
  ///
  /// This method:
  /// 1. Calls base controller to calculate new handle positions (applies anchor type constraints)
  /// 2. Applies angle snapping to the dragged handle
  /// 3. Reapplies anchor type constraints to ensure smooth/symmetric handles remain valid
  /// 4. Returns immutable [DragResult] with snapped handles
  ///
  /// Parameters:
  /// - [anchor]: The current anchor point whose handle is being dragged
  /// - [delta]: The drag delta from the handle's start position (world coordinates)
  /// - [component]: Which handle is being dragged (handleIn or handleOut)
  ///
  /// Returns a [DragResult] with:
  /// - position: Unchanged anchor position
  /// - handleIn: Snapped/mirrored handleIn (if affected by anchor type constraints)
  /// - handleOut: Snapped/mirrored handleOut (if affected by anchor type constraints)
  /// - anchorType: Unchanged anchor type
  DragResult calculateDragUpdate({
    required AnchorPoint anchor,
    required Point delta,
    required AnchorComponent component,
  }) {
    // Call base controller to get unsnapped handles
    // This applies anchor type constraints (smooth/symmetric/corner)
    final baseResult = _baseDragController.calculateDragUpdate(
      anchor: anchor,
      delta: delta,
      component: component,
    );

    // Apply angle snapping to the dragged handle
    Point? snappedHandleIn = baseResult.handleIn;
    Point? snappedHandleOut = baseResult.handleOut;

    if (component == AnchorComponent.handleIn && baseResult.handleIn != null) {
      // Snap handleIn to angle
      snappedHandleIn = _snappingService.snapHandleToAngle(baseResult.handleIn!);

      // Reapply anchor type constraints after snapping
      snappedHandleOut = _applyConstraintsToOppositeHandle(
        draggedHandle: snappedHandleIn,
        oppositeHandle: baseResult.handleOut,
        anchorType: anchor.anchorType,
        isDraggingHandleIn: true,
      );
    } else if (component == AnchorComponent.handleOut &&
        baseResult.handleOut != null) {
      // Snap handleOut to angle
      snappedHandleOut =
          _snappingService.snapHandleToAngle(baseResult.handleOut!);

      // Reapply anchor type constraints after snapping
      snappedHandleIn = _applyConstraintsToOppositeHandle(
        draggedHandle: snappedHandleOut,
        oppositeHandle: baseResult.handleIn,
        anchorType: anchor.anchorType,
        isDraggingHandleIn: false,
      );
    }

    return DragResult(
      position: baseResult.position,
      handleIn: snappedHandleIn,
      handleOut: snappedHandleOut,
      anchorType: baseResult.anchorType,
    );
  }

  /// Applies anchor type constraints to the opposite handle after snapping.
  ///
  /// This ensures that smooth/symmetric anchors maintain their constraints
  /// after angle snapping is applied to the dragged handle.
  ///
  /// Parameters:
  /// - [draggedHandle]: The handle that was just snapped
  /// - [oppositeHandle]: The opposite handle that may need adjustment
  /// - [anchorType]: The anchor type (smooth/symmetric/corner)
  /// - [isDraggingHandleIn]: True if dragging handleIn, false if dragging handleOut
  ///
  /// Returns the adjusted opposite handle, or null if no adjustment needed.
  Point? _applyConstraintsToOppositeHandle({
    required Point draggedHandle,
    required Point? oppositeHandle,
    required AnchorType anchorType,
    required bool isDraggingHandleIn,
  }) {
    switch (anchorType) {
      case AnchorType.smooth:
        // Smooth: perfect mirror (opposite direction, same magnitude)
        return Point(x: -draggedHandle.x, y: -draggedHandle.y);

      case AnchorType.symmetric:
        // Symmetric: collinear but preserve opposite handle length
        final draggedLength = _vectorLength(draggedHandle);
        final oppositeLength = oppositeHandle != null
            ? _vectorLength(oppositeHandle)
            : draggedLength;

        if (draggedLength > 0.001) {
          // Normalize dragged handle and scale to opposite direction with preserved length
          final normalizedX = -draggedHandle.x / draggedLength;
          final normalizedY = -draggedHandle.y / draggedLength;
          return Point(
            x: normalizedX * oppositeLength,
            y: normalizedY * oppositeLength,
          );
        } else {
          // Handle collapsed to anchor - keep existing opposite handle
          return oppositeHandle;
        }

      case AnchorType.corner:
        // Corner: independent handles (no constraints)
        return oppositeHandle;
    }
  }

  /// Calculates feedback metrics for on-canvas display.
  ///
  /// Returns a map containing:
  /// - 'angle': Handle angle in degrees (0-360)
  /// - 'length': Handle length in world units
  /// - 'snapped': Whether handle was snapped to angle
  ///
  /// This data is used by DirectSelectionTool to render feedback overlays.
  Map<String, dynamic> calculateFeedbackMetrics({
    required Point handleVector,
  }) {
    final originalAngle = _calculateAngleDegrees(handleVector);
    final snappedHandle = _snappingService.snapHandleToAngle(handleVector);
    final snappedAngle = _calculateAngleDegrees(snappedHandle);
    final wasSnapped = (originalAngle - snappedAngle).abs() > 0.1;

    return {
      'angle': snappedAngle,
      'length': handleVector.magnitude,
      'snapped': wasSnapped,
    };
  }

  /// Calculates the angle of a handle vector in degrees.
  ///
  /// Returns angle in range [0, 360) degrees, measured counterclockwise
  /// from the positive x-axis (right = 0°, up = 90°, left = 180°, down = 270°).
  double _calculateAngleDegrees(Point handleVector) {
    final radians = math.atan2(handleVector.y, handleVector.x);
    final degrees = radians * (180.0 / math.pi);
    // Normalize to [0, 360)
    return degrees < 0 ? degrees + 360.0 : degrees;
  }

  /// Calculates the length (magnitude) of a vector.
  double _vectorLength(Point vector) => math.sqrt(vector.x * vector.x + vector.y * vector.y);
}
