import 'package:flutter/foundation.dart';
import 'package:wiretuner/domain/events/event_base.dart';

/// Type of anchor point defining handle behavior.
///
/// This enum defines how Bezier control point (BCP) handles behave
/// for different anchor types in a vector path.
enum AnchorType {
  /// Corner anchor with independent handles (or no handles).
  ///
  /// Handles can point in any direction independently, allowing
  /// sharp corners or asymmetric curves. This is the default type.
  corner,

  /// Smooth anchor with symmetric handles.
  ///
  /// Handles are mirrored: same angle, same magnitude.
  /// Moving one handle automatically adjusts the other to maintain
  /// the symmetric relationship. Creates smooth, flowing curves.
  smooth,

  /// Symmetric anchor with collinear handles.
  ///
  /// Handles maintain opposite angles (180° apart) but can have
  /// different lengths. This creates smooth curves with different
  /// curvature on each side of the anchor.
  symmetric,
}

/// Represents an immutable anchor point in a vector path.
///
/// An anchor point defines a vertex in a path. It has a [position] and
/// optional Bezier control point handles ([handleIn], [handleOut]) that
/// define how curves connect to this anchor.
///
/// The [anchorType] determines how handles behave:
/// - [AnchorType.corner]: Handles are independent (or absent for sharp corners)
/// - [AnchorType.smooth]: Handles are symmetric (mirrored position)
/// - [AnchorType.symmetric]: Handles are collinear (opposite angles, different lengths)
///
/// ## Handle Coordinates
///
/// Handles ([handleIn] and [handleOut]) are stored as **relative offsets**
/// from the anchor's [position], not as absolute canvas coordinates.
///
/// For example:
/// ```dart
/// final anchor = AnchorPoint(
///   position: Point(x: 100, y: 100),
///   handleOut: Point(x: 50, y: 0),  // 50 units to the right
/// );
/// // Absolute position of handleOut: (150, 100)
/// ```
///
/// ## Examples
///
/// Create a corner anchor (sharp point):
/// ```dart
/// final corner = AnchorPoint.corner(Point(x: 10, y: 10));
/// ```
///
/// Create a smooth anchor with symmetric handles:
/// ```dart
/// final smooth = AnchorPoint.smooth(
///   position: Point(x: 50, y: 50),
///   handleOut: Point(x: 20, y: 0),
/// );
/// // handleIn is automatically set to Point(x: -20, y: 0)
/// ```
///
/// Modify an anchor point:
/// ```dart
/// final updated = anchor.copyWith(
///   position: Point(x: 60, y: 60),
/// );
///
/// // Remove handles
/// final withoutHandles = anchor.copyWith(
///   handleIn: () => null,
///   handleOut: () => null,
/// );
/// ```
@immutable
class AnchorPoint {

  /// Creates an anchor point with the specified position and optional handles.
  ///
  /// The [position] is required and specifies the anchor's location on the canvas.
  /// The [handleIn] and [handleOut] are optional and default to null (no handles).
  /// The [anchorType] defaults to [AnchorType.corner].
  const AnchorPoint({
    required this.position,
    this.handleIn,
    this.handleOut,
    this.anchorType = AnchorType.corner,
  });

  /// Creates a corner anchor with no handles.
  ///
  /// This factory creates a sharp corner at the specified [position]
  /// with no Bezier control points. Segments connecting to this anchor
  /// will be straight lines (or meet at a sharp angle).
  ///
  /// Example:
  /// ```dart
  /// final corner = AnchorPoint.corner(Point(x: 10, y: 10));
  /// assert(corner.isCorner);
  /// assert(!corner.hasCurve);
  /// ```
  factory AnchorPoint.corner(Point position) => AnchorPoint(
        position: position,
        anchorType: AnchorType.corner,
      );

  /// Creates a smooth anchor with symmetric handles.
  ///
  /// The [handleOut] defines the outgoing handle direction and magnitude.
  /// The [handleIn] is automatically set to the opposite direction with
  /// the same magnitude: `handleIn = -handleOut`.
  ///
  /// This creates perfectly smooth curves where the tangent is continuous
  /// through the anchor point.
  ///
  /// Example:
  /// ```dart
  /// final smooth = AnchorPoint.smooth(
  ///   position: Point(x: 50, y: 50),
  ///   handleOut: Point(x: 20, y: 10),
  /// );
  /// // handleIn will be Point(x: -20, y: -10)
  /// ```
  factory AnchorPoint.smooth({
    required Point position,
    required Point handleOut,
  }) =>
      AnchorPoint(
        position: position,
        handleIn: Point(x: -handleOut.x, y: -handleOut.y),
        handleOut: handleOut,
        anchorType: AnchorType.smooth,
      );
  /// The position of this anchor on the canvas.
  final Point position;

  /// The incoming Bezier control point (BCP) handle.
  ///
  /// Null indicates no incoming curve control (straight line or end of path).
  /// The handle is stored as a relative offset from [position], not as
  /// absolute coordinates.
  ///
  /// This handle affects the curve coming INTO this anchor from the
  /// previous segment.
  final Point? handleIn;

  /// The outgoing Bezier control point (BCP) handle.
  ///
  /// Null indicates no outgoing curve control (straight line or end of path).
  /// The handle is stored as a relative offset from [position], not as
  /// absolute coordinates.
  ///
  /// This handle affects the curve going OUT from this anchor to the
  /// next segment.
  final Point? handleOut;

  /// The type of anchor, defining handle behavior.
  ///
  /// Defaults to [AnchorType.corner] for maximum flexibility.
  final AnchorType anchorType;

  /// Whether this anchor has any handles (is a curve anchor).
  ///
  /// Returns true if either [handleIn] or [handleOut] is non-null.
  /// Curve anchors create smooth Bezier curves in the path.
  bool get hasCurve => handleIn != null || handleOut != null;

  /// Whether this is a sharp corner (no handles).
  ///
  /// Returns true if both [handleIn] and [handleOut] are null.
  /// Corner anchors create sharp angles or straight line connections.
  bool get isCorner => handleIn == null && handleOut == null;

  /// Creates a copy of this anchor with modified fields.
  ///
  /// All parameters are optional. Fields not specified will retain their
  /// current values from this instance.
  ///
  /// **Important**: To explicitly set [handleIn] or [handleOut] to null,
  /// use the function wrapper pattern:
  ///
  /// ```dart
  /// // Remove handleIn (set to null)
  /// final updated = anchor.copyWith(
  ///   handleIn: () => null,
  /// );
  ///
  /// // Leave handleIn unchanged, update position
  /// final moved = anchor.copyWith(
  ///   position: Point(x: 20, y: 20),
  /// );
  /// ```
  ///
  /// The function wrapper is necessary to distinguish between "don't change"
  /// (parameter not provided) and "change to null" (parameter provided, returns null).
  AnchorPoint copyWith({
    Point? position,
    Point? Function()? handleIn,
    Point? Function()? handleOut,
    AnchorType? anchorType,
  }) =>
      AnchorPoint(
        position: position ?? this.position,
        handleIn: handleIn != null ? handleIn() : this.handleIn,
        handleOut: handleOut != null ? handleOut() : this.handleOut,
        anchorType: anchorType ?? this.anchorType,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AnchorPoint &&
        other.position == position &&
        other.handleIn == handleIn &&
        other.handleOut == handleOut &&
        other.anchorType == anchorType;
  }

  @override
  int get hashCode => Object.hash(position, handleIn, handleOut, anchorType);

  @override
  String toString() =>
      'AnchorPoint(position: $position, handleIn: $handleIn, '
      'handleOut: $handleOut, anchorType: $anchorType)';
}
