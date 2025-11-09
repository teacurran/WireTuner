/// Hit testing for selection and manipulation of vector graphics.
///
/// This module will provide hit testing functionality to determine
/// which objects, anchor points, or control points are under the cursor.
library;

/// TODO: Implement hit testing logic.
///
/// Future implementation will include:
/// - Point-in-path testing
/// - Stroke hit testing with configurable tolerance
/// - Anchor point and control point hit detection
/// - Bounding box hit testing for performance optimization
/// - Z-order aware selection (topmost object)
class HitTesting {
  /// Creates an instance of the hit testing utilities.
  const HitTesting();

  /// Returns the default hit test tolerance in pixels.
  double get hitTolerance => 5.0;
}
