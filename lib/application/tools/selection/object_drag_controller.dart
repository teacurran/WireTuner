import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/application/tools/direct_selection/snapping_service.dart';

/// Controller for object drag operations with snapping support.
///
/// This controller encapsulates the logic for calculating drag deltas
/// with optional grid snapping. It is stateless and designed to be used
/// by the SelectionTool to manage object movement operations.
///
/// ## Features
///
/// - **Cumulative Delta Calculation**: Calculates delta from drag start
///   position to ensure deterministic event replay
/// - **Grid Snapping**: Optional snapping to grid intersections
/// - **Constraint Modes**: Support for horizontal/vertical constraints (future)
///
/// ## Design Rationale
///
/// This controller uses a stateless design pattern:
/// - State management is handled by SelectionTool (_dragState)
/// - Controller provides pure functions for delta calculations
/// - SnappingService is injected for grid snapping logic
///
/// This separation enables:
/// - Easy unit testing without UI framework
/// - Reusable snapping logic across tools
/// - Clear separation of concerns
///
/// ## Usage
///
/// ```dart
/// final controller = ObjectDragController(
///   snappingService: snappingService,
/// );
///
/// // Calculate delta with snapping
/// final delta = controller.calculateSnappedDelta(
///   startWorldPos: Point(x: 100, y: 100),
///   currentWorldPos: Point(x: 153, y: 127),
///   snapEnabled: true,
/// );
/// // Returns Point(x: 50, y: 30) with grid snapping at 10px
/// ```
///
/// ## Event Sourcing Integration
///
/// The controller emits **cumulative deltas** from drag start position,
/// not frame-to-frame deltas. This ensures deterministic replay:
///
/// - **Wrong approach**: `delta = current - previous`
///   - Causes cumulative drift on replay
///   - Each event adds to previous position
///
/// - **Correct approach**: `delta = current - start`
///   - Final position is deterministic
///   - Replay produces identical results
///
/// Related: T031 (Object Dragging), I4.T5
class ObjectDragController {
  /// Creates an object drag controller.
  ///
  /// [snappingService] is optional. If null, snapping is disabled.
  ObjectDragController({
    SnappingService? snappingService,
  }) : _snappingService = snappingService;

  final SnappingService? _snappingService;

  /// Calculates the cumulative delta from drag start to current position.
  ///
  /// This method calculates the delta with optional grid snapping applied.
  /// The delta is calculated from the **start position**, not the previous
  /// frame position, to ensure deterministic event replay.
  ///
  /// ## Algorithm
  ///
  /// 1. Calculate raw target position (current world position)
  /// 2. If snapping enabled: Snap target position to grid
  /// 3. Calculate delta: snapped_target - start
  ///
  /// ## Parameters
  ///
  /// - [startWorldPos]: The world position where drag started
  /// - [currentWorldPos]: The current world position of the pointer
  /// - [snapEnabled]: Whether grid snapping should be applied
  ///
  /// ## Returns
  ///
  /// The cumulative delta from start position, with optional snapping.
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Without snapping
  /// final delta = controller.calculateSnappedDelta(
  ///   startWorldPos: Point(x: 100, y: 100),
  ///   currentWorldPos: Point(x: 153, y: 127),
  ///   snapEnabled: false,
  /// );
  /// // Returns Point(x: 53, y: 27)
  ///
  /// // With snapping (gridSize=10)
  /// final snappedDelta = controller.calculateSnappedDelta(
  ///   startWorldPos: Point(x: 100, y: 100),
  ///   currentWorldPos: Point(x: 153, y: 127),
  ///   snapEnabled: true,
  /// );
  /// // Target: (153, 127) → Snapped: (150, 130)
  /// // Returns Point(x: 50, y: 30)
  /// ```
  Point calculateSnappedDelta({
    required Point startWorldPos,
    required Point currentWorldPos,
    required bool snapEnabled,
  }) {
    // Calculate raw target position
    final rawTargetPos = currentWorldPos;

    // Apply grid snapping if enabled and service available
    final snappedTargetPos = snapEnabled && _snappingService != null
        ? _snappingService.snapToGrid(rawTargetPos)
        : rawTargetPos;

    // Calculate cumulative delta from start position
    return Point(
      x: snappedTargetPos.x - startWorldPos.x,
      y: snappedTargetPos.y - startWorldPos.y,
    );
  }

  /// Constrains a delta to horizontal/vertical axes (45° increments).
  ///
  /// **STATUS: Optional feature for future implementation.**
  ///
  /// When shift key is held during drag, constrains movement to:
  /// - Horizontal (0°)
  /// - Vertical (90°)
  /// - Diagonal (45°, 135°, 225°, 315°)
  ///
  /// ## Algorithm
  ///
  /// 1. Calculate angle: atan2(delta.y, delta.x)
  /// 2. Snap angle to nearest 45° increment
  /// 3. Reconstruct delta with snapped angle and original magnitude
  ///
  /// ## Example
  ///
  /// ```dart
  /// final delta = Point(x: 30, y: 10);  // ~18.4° angle
  /// final constrained = controller.constrainDelta(delta);
  /// // Returns delta snapped to 0° (horizontal): Point(x: 31.6, y: 0)
  /// ```
  ///
  /// Related: "SHIFT-proportional scaling" in task description
  /// (interpreted as constrained drag, not scaling)
  Point constrainDelta(Point delta) =>
      // TODO: Implement axis constraint for future iteration
      // This is optional for I4.T5, marked as polish feature
      delta;
}
