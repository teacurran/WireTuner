import 'dart:math' as math;

import 'package:wiretuner/domain/events/event_base.dart' hide AnchorType;
import 'package:wiretuner/domain/models/anchor_point.dart';
import 'package:wiretuner/presentation/canvas/overlays/selection_overlay.dart';

/// Helper class for managing anchor and handle drag operations.
///
/// DragController encapsulates the logic for calculating new anchor positions
/// and handle positions based on drag deltas and anchor type constraints.
///
/// ## Anchor Type Constraints
///
/// - **Smooth**: HandleIn and HandleOut are perfectly mirrored (same magnitude, opposite direction)
/// - **Symmetric**: Handles are collinear (opposite angles) but can have different lengths
/// - **Corner**: Handles move independently
///
/// ## Usage
///
/// ```dart
/// final controller = DragController();
///
/// final result = controller.calculateDragUpdate(
///   anchor: currentAnchor,
///   delta: Point(x: 10, y: 5),
///   component: AnchorComponent.handleOut,
/// );
///
/// // Apply result.position, result.handleIn, result.handleOut to anchor
/// ```
class DragController {
  /// Calculates the updated anchor state after a drag operation.
  ///
  /// Parameters:
  /// - [anchor]: The current anchor point being dragged
  /// - [delta]: The drag delta from the component's start position
  /// - [component]: Which component is being dragged (anchor/handleIn/handleOut)
  ///
  /// Returns a [DragResult] containing the new position and handles.
  DragResult calculateDragUpdate({
    required AnchorPoint anchor,
    required Point delta,
    required AnchorComponent component,
  }) {
    switch (component) {
      case AnchorComponent.anchor:
        return _dragAnchor(anchor, delta);
      case AnchorComponent.handleIn:
        return _dragHandleIn(anchor, delta);
      case AnchorComponent.handleOut:
        return _dragHandleOut(anchor, delta);
    }
  }

  /// Handles dragging the anchor point itself.
  DragResult _dragAnchor(AnchorPoint anchor, Point delta) {
    // When dragging anchor, position moves but handles stay relative
    final newPosition = Point(
      x: anchor.position.x + delta.x,
      y: anchor.position.y + delta.y,
    );

    return DragResult(
      position: newPosition,
      handleIn: anchor.handleIn,
      handleOut: anchor.handleOut,
      anchorType: anchor.anchorType,
    );
  }

  /// Handles dragging the handleIn component.
  DragResult _dragHandleIn(AnchorPoint anchor, Point delta) {
    // Calculate absolute handle position from drag.
    // Delta is relative to the starting absolute position (anchor.position + anchor.handleIn).
    final absoluteHandlePos = anchor.handleIn != null
        ? Point(
            x: anchor.position.x + anchor.handleIn!.x + delta.x,
            y: anchor.position.y + anchor.handleIn!.y + delta.y,
          )
        : Point(
            x: anchor.position.x + delta.x,
            y: anchor.position.y + delta.y,
          );

    // Convert to relative offset
    final newHandleIn = Point(
      x: absoluteHandlePos.x - anchor.position.x,
      y: absoluteHandlePos.y - anchor.position.y,
    );

    Point? newHandleOut;

    // Apply anchor type constraints
    switch (anchor.anchorType) {
      case AnchorType.smooth:
        // Smooth: perfect mirror (opposite direction, same magnitude)
        newHandleOut = Point(x: -newHandleIn.x, y: -newHandleIn.y);
        break;

      case AnchorType.symmetric:
        // Symmetric: collinear but preserve handleOut length
        final handleInLength = _vectorLength(newHandleIn);
        final handleOutLength = anchor.handleOut != null
            ? _vectorLength(anchor.handleOut!)
            : handleInLength;

        if (handleInLength > 0.001) {
          // Normalize and scale to opposite direction with preserved length
          final normalizedX = -newHandleIn.x / handleInLength;
          final normalizedY = -newHandleIn.y / handleInLength;
          newHandleOut = Point(
            x: normalizedX * handleOutLength,
            y: normalizedY * handleOutLength,
          );
        } else {
          // Handle collapsed to anchor - keep existing handleOut
          newHandleOut = anchor.handleOut;
        }
        break;

      case AnchorType.corner:
        // Corner: independent handles
        newHandleOut = anchor.handleOut;
        break;
    }

    return DragResult(
      position: anchor.position,
      handleIn: newHandleIn,
      handleOut: newHandleOut,
      anchorType: anchor.anchorType,
    );
  }

  /// Handles dragging the handleOut component.
  DragResult _dragHandleOut(AnchorPoint anchor, Point delta) {
    // Calculate absolute handle position from drag.
    // Delta is relative to the starting absolute position (anchor.position + anchor.handleOut).
    final absoluteHandlePos = anchor.handleOut != null
        ? Point(
            x: anchor.position.x + anchor.handleOut!.x + delta.x,
            y: anchor.position.y + anchor.handleOut!.y + delta.y,
          )
        : Point(
            x: anchor.position.x + delta.x,
            y: anchor.position.y + delta.y,
          );

    // Convert to relative offset
    final newHandleOut = Point(
      x: absoluteHandlePos.x - anchor.position.x,
      y: absoluteHandlePos.y - anchor.position.y,
    );

    Point? newHandleIn;

    // Apply anchor type constraints
    switch (anchor.anchorType) {
      case AnchorType.smooth:
        // Smooth: perfect mirror (opposite direction, same magnitude)
        newHandleIn = Point(x: -newHandleOut.x, y: -newHandleOut.y);
        break;

      case AnchorType.symmetric:
        // Symmetric: collinear but preserve handleIn length
        final handleOutLength = _vectorLength(newHandleOut);
        final handleInLength = anchor.handleIn != null
            ? _vectorLength(anchor.handleIn!)
            : handleOutLength;

        if (handleOutLength > 0.001) {
          // Normalize and scale to opposite direction with preserved length
          final normalizedX = -newHandleOut.x / handleOutLength;
          final normalizedY = -newHandleOut.y / handleOutLength;
          newHandleIn = Point(
            x: normalizedX * handleInLength,
            y: normalizedY * handleInLength,
          );
        } else {
          // Handle collapsed to anchor - keep existing handleIn
          newHandleIn = anchor.handleIn;
        }
        break;

      case AnchorType.corner:
        // Corner: independent handles
        newHandleIn = anchor.handleIn;
        break;
    }

    return DragResult(
      position: anchor.position,
      handleIn: newHandleIn,
      handleOut: newHandleOut,
      anchorType: anchor.anchorType,
    );
  }

  /// Calculates the length (magnitude) of a vector.
  double _vectorLength(Point vector) =>
      math.sqrt(vector.x * vector.x + vector.y * vector.y);
}

/// Result of a drag calculation.
class DragResult {
  DragResult({
    this.position,
    this.handleIn,
    this.handleOut,
    required this.anchorType,
  });

  /// The new anchor position (null if position unchanged).
  final Point? position;

  /// The new handleIn relative offset (null if no handle).
  final Point? handleIn;

  /// The new handleOut relative offset (null if no handle).
  final Point? handleOut;

  /// The anchor type (may change with Alt/Option modifier).
  final AnchorType anchorType;
}

// AnchorComponent enum is imported from selection_overlay.dart
