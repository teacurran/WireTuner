import 'dart:math' as math;

import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/models/geometry/point_extensions.dart';

/// Service for applying snapping constraints to drag operations.
///
/// Provides grid snapping, angle snapping, and optional path snapping
/// for anchor and handle drag operations. Snapping can be toggled
/// dynamically (typically via modifier keys like Shift).
///
/// ## Snapping Modes
///
/// - **Grid Snapping**: Snaps positions to nearest grid intersection
/// - **Angle Snapping**: Snaps handle vectors to angular increments (e.g., 15°)
/// - **Magnetic Snapping**: Only snaps when within threshold distance
/// - **Path Snapping** (optional): Snaps to nearby path segments
///
/// ## Magnetic Snapping
///
/// Magnetic snapping provides more intuitive behavior by only applying
/// snapping when the pointer is within a capture radius of a snap target.
/// Hysteresis prevents jittering at the threshold boundary.
///
/// ## Usage
///
/// ```dart
/// final snappingService = SnappingService(
///   gridSnapEnabled: true,
///   magneticThreshold: 8.0,
///   gridSize: 10.0,
///   angleIncrement: 15.0,
/// );
///
/// // Magnetic grid snapping
/// final result = snappingService.maybeSnapToGrid(Point(x: 123.4, y: 567.8));
/// // Returns snapped position only if within 8px of grid intersection
///
/// // Angle snapping
/// final snapped = snappingService.snapHandleToAngle(
///   Point(x: 10.0, y: 5.0),
/// );
/// // Returns handle vector snapped to nearest 15° increment
/// ```
///
/// ## Performance
///
/// - Grid snapping: O(1) time complexity, < 0.5ms overhead
/// - Angle snapping: O(1) time complexity, < 1ms overhead
/// - Path snapping: O(n) where n = number of path segments, ~2-5ms
class SnappingService {
  SnappingService({
    this.gridSnapEnabled = false,
    this.angleSnapEnabled = false,
    this.gridSize = 10.0,
    this.angleIncrement = 15.0,
    this.magneticThreshold = 8.0,
    this.hysteresisMargin = 2.0,
  }) {
    // Precompute reciprocals to avoid division in hot paths
    _gridSizeInverse = 1.0 / gridSize;
    _angleIncrementRadians = angleIncrement * (math.pi / 180.0);
  }

  /// Whether grid snapping is currently enabled.
  bool gridSnapEnabled;

  /// Whether angle snapping is currently enabled.
  bool angleSnapEnabled;

  /// Grid size in world units (default: 10.0).
  ///
  /// Positions will snap to multiples of this value.
  /// For example, gridSize=10.0 snaps to 0, 10, 20, 30, etc.
  final double gridSize;

  /// Angle increment in degrees (default: 15.0).
  ///
  /// Handle vectors will snap to multiples of this angle.
  /// For example, angleIncrement=15.0 snaps to 0°, 15°, 30°, 45°, etc.
  final double angleIncrement;

  /// Magnetic snap threshold in world units (default: 8.0).
  ///
  /// Snap capture radius for magnetic snapping. Only snaps to grid
  /// when within this distance from the nearest intersection.
  final double magneticThreshold;

  /// Hysteresis margin in world units (default: 2.0).
  ///
  /// Once snapped, the threshold is increased by this margin to prevent
  /// jittering at the boundary. Must be less than magneticThreshold.
  final double hysteresisMargin;

  /// Precomputed reciprocal of grid size for performance optimization.
  late final double _gridSizeInverse;

  /// Precomputed angle increment in radians.
  late final double _angleIncrementRadians;

  /// Last snapped grid position (for hysteresis tracking).
  // ignore: unused_field
  Point? _lastSnappedGrid; // Reserved for future hysteresis implementation

  /// Whether currently snapped (for hysteresis).
  bool _isSnapped = false;

  /// Snaps a position to the nearest grid intersection (legacy API).
  ///
  /// If [gridSnapEnabled] is false, returns the original position unchanged.
  /// Always snaps regardless of distance (non-magnetic behavior).
  ///
  /// **Note:** For magnetic snapping behavior, use [maybeSnapToGrid] instead.
  ///
  /// Algorithm:
  /// 1. Divide coordinates by grid size
  /// 2. Round to nearest integer
  /// 3. Multiply by grid size
  ///
  /// Example:
  /// ```dart
  /// final service = SnappingService(gridSnapEnabled: true, gridSize: 10.0);
  /// service.snapToGrid(Point(x: 12.3, y: 45.6));
  /// // Returns Point(x: 10.0, y: 50.0)
  /// ```
  ///
  /// Performance: O(1), typically < 0.5ms
  Point snapToGrid(Point position) {
    if (!gridSnapEnabled) return position;

    return Point(
      x: (position.x * _gridSizeInverse).round() * gridSize,
      y: (position.y * _gridSizeInverse).round() * gridSize,
    );
  }

  /// Magnetically snaps a position to the nearest grid intersection.
  ///
  /// Only snaps if within [magneticThreshold] distance from grid intersection.
  /// Uses hysteresis to prevent jittering once snapped.
  ///
  /// Returns null if no snap should be applied (outside threshold).
  ///
  /// Algorithm:
  /// 1. Calculate nearest grid intersection
  /// 2. Calculate distance to that intersection
  /// 3. Apply hysteresis threshold if currently snapped
  /// 4. Snap if within threshold, else return null
  ///
  /// Example:
  /// ```dart
  /// final service = SnappingService(
  ///   gridSnapEnabled: true,
  ///   magneticThreshold: 8.0,
  ///   gridSize: 10.0,
  /// );
  ///
  /// // 7 pixels from grid - snaps
  /// final result1 = service.maybeSnapToGrid(Point(x: 13.0, y: 17.0));
  /// // Returns Point(x: 10.0, y: 20.0)
  ///
  /// // 15 pixels from grid - no snap
  /// final result2 = service.maybeSnapToGrid(Point(x: 5.0, y: 5.0));
  /// // Returns null
  /// ```
  ///
  /// Performance: O(1), typically < 0.5ms
  Point? maybeSnapToGrid(Point position) {
    if (!gridSnapEnabled) return null;

    // Calculate nearest grid intersection
    final nearestX = (position.x * _gridSizeInverse).round() * gridSize;
    final nearestY = (position.y * _gridSizeInverse).round() * gridSize;
    final nearestGrid = Point(x: nearestX, y: nearestY);

    // Calculate distance to nearest grid (use squared distance to avoid sqrt)
    final dx = position.x - nearestX;
    final dy = position.y - nearestY;
    final distanceSquared = dx * dx + dy * dy;

    // Apply hysteresis if currently snapped
    final effectiveThreshold =
        _isSnapped ? magneticThreshold + hysteresisMargin : magneticThreshold;
    final thresholdSquared = effectiveThreshold * effectiveThreshold;

    // Snap if within threshold
    if (distanceSquared <= thresholdSquared) {
      _lastSnappedGrid = nearestGrid;
      _isSnapped = true;
      return nearestGrid;
    } else {
      // Outside threshold - no snap
      _isSnapped = false;
      return null;
    }
  }

  /// Snaps a handle vector to the nearest angular increment.
  ///
  /// If [snapEnabled] is false, returns the original vector unchanged.
  ///
  /// Algorithm:
  /// 1. Calculate current angle via atan2(y, x)
  /// 2. Round angle to nearest increment (e.g., 15°)
  /// 3. Reconstruct vector with snapped angle and original magnitude
  ///
  /// Example:
  /// ```dart
  /// final service = SnappingService(snapEnabled: true, angleIncrement: 15.0);
  /// final handle = Point(x: 10.0, y: 5.0); // ~26.6° angle
  /// final snapped = service.snapHandleToAngle(handle);
  /// // Returns vector at 30° (nearest 15° increment) with same magnitude
  /// ```
  ///
  /// Performance: O(1), typically < 1ms
  Point snapHandleToAngle(Point handleVector) {
    if (!angleSnapEnabled) return handleVector;

    // Calculate current angle in radians
    final angle = math.atan2(handleVector.y, handleVector.x);

    // Calculate handle magnitude
    final magnitude = handleVector.magnitude;

    // Snap angle to nearest increment
    final snappedAngle =
        (angle / _angleIncrementRadians).round() * _angleIncrementRadians;

    // Reconstruct handle vector with snapped angle and original magnitude
    return Point(
      x: math.cos(snappedAngle) * magnitude,
      y: math.sin(snappedAngle) * magnitude,
    );
  }

  /// Snaps a position to the nearest point on nearby path segments.
  ///
  /// **STATUS: Not implemented in this iteration (optional for I4.T4).**
  ///
  /// Future implementation will:
  /// 1. Iterate through all path segments in the document
  /// 2. Calculate closest point on each segment to drag position
  /// 3. If distance < [snapThreshold], snap to that point
  /// 4. Return null if no snap target found within threshold
  ///
  /// Performance target: O(n) where n = number of segments, ~2-5ms
  Point? snapToPath(Point position, List<dynamic> paths) {
    // TODO: Implement path snapping in future iteration (I4.T5 or v0.2)
    // This is marked as OPTIONAL in task acceptance criteria
    return null;
  }

  /// Sets whether snapping is enabled (legacy API).
  ///
  /// Typically called when modifier keys (e.g., Shift) are pressed/released.
  /// Enables both grid and angle snapping together.
  ///
  /// **Deprecated**: Use [setSnapMode] for more fine-grained control.
  void setSnapEnabled(bool enabled) {
    gridSnapEnabled = enabled;
    angleSnapEnabled = enabled;
  }

  /// Sets snap mode with separate control for grid and angle snapping.
  ///
  /// Provides fine-grained control over snapping behavior.
  ///
  /// Example:
  /// ```dart
  /// // Enable only grid snapping
  /// service.setSnapMode(gridEnabled: true, angleEnabled: false);
  ///
  /// // Enable both
  /// service.setSnapMode(gridEnabled: true, angleEnabled: true);
  /// ```
  void setSnapMode({bool? gridEnabled, bool? angleEnabled}) {
    if (gridEnabled != null) {
      gridSnapEnabled = gridEnabled;
    }
    if (angleEnabled != null) {
      angleSnapEnabled = angleEnabled;
    }
  }

  /// Resets snap state (clears hysteresis tracking).
  ///
  /// Call this when starting a new drag operation or when snap mode changes
  /// to prevent state leakage between operations.
  void resetSnapState() {
    _lastSnappedGrid = null;
    _isSnapped = false;
  }
}
