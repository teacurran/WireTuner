/// Geometry primitives and mathematical operations for vector graphics.
///
/// This module provides the core geometric building blocks:
/// - [Point]: 2D point with vector arithmetic
/// - [AnchorPoint]: Path vertex with Bezier control handles
/// - [Segment]: Curve segment connecting anchors (line, Bezier, arc)
/// - [Path]: Composite curve made of anchors and segments
/// - [Shape]: Parametric shapes (rectangle, ellipse, polygon, star)
/// - [Bounds]: Axis-aligned bounding box
///
/// ## Coordinate Systems
///
/// All coordinates are in world space (typically pixels at 100% zoom).
/// The origin (0, 0) is at the top-left of the infinite canvas.
///
/// ## Immutability
///
/// All geometry classes are immutable and use Freezed for code generation.
/// Modifications create new instances via `copyWith` methods.
///
/// ## Handle Semantics
///
/// Anchor handles are stored as **relative offsets** from the anchor position,
/// not absolute canvas coordinates. Use `handleInAbsolute` / `handleOutAbsolute`
/// to get absolute positions.
library;

export 'geometry/point.dart';
export 'geometry/anchor.dart';
export 'geometry/segment.dart';
export 'geometry/path.dart';
export 'geometry/shape.dart';
export 'geometry/bounds.dart';

/// Shared numeric tolerance for floating-point comparisons.
///
/// Use this epsilon value for geometric calculations that need to handle
/// floating-point precision issues.
const double kGeometryEpsilon = 1e-10;

/// Returns true if two doubles are approximately equal within epsilon.
bool approximatelyEqual(double a, double b, {double epsilon = kGeometryEpsilon}) {
  return (a - b).abs() < epsilon;
}
