import 'package:freezed_annotation/freezed_annotation.dart';
import 'point.dart';

part 'anchor.freezed.dart';
part 'anchor.g.dart';

/// Defines the behavior of an anchor point's Bezier control point handles.
///
/// The anchor type determines how the handles interact when one is modified:
/// - [corner]: Handles are independent or absent (allows sharp corners)
/// - [smooth]: Handles are mirrored (same magnitude, opposite directions)
/// - [symmetric]: Handles are collinear (opposite angles, different lengths)
enum AnchorType {
  /// Handles are independent; allows sharp corners or asymmetric curves.
  corner,

  /// Handles are mirrored (same angle, same magnitude); creates smooth flowing curves.
  smooth,

  /// Handles are collinear (opposite angles, different lengths); creates smooth curves
  /// with different curvature on each side.
  symmetric,
}

/// An immutable anchor point in a vector path.
///
/// Anchors define vertex positions and optional Bezier control point handles.
/// Handles are stored as **relative offsets** from the anchor position, not
/// absolute canvas coordinates.
///
/// ## Handle Semantics
///
/// - **handleIn**: Incoming control point (affects curve before this anchor)
/// - **handleOut**: Outgoing control point (affects curve after this anchor)
/// - Both handles are relative offsets from [position]
///
/// ## Example
///
/// ```dart
/// // Create a smooth anchor with symmetric handles
/// final anchor = AnchorPoint(
///   position: Point(x: 100, y: 100),
///   handleOut: Point(x: 50, y: 0),  // 50 units to the right
///   handleIn: Point(x: -50, y: 0),  // 50 units to the left
///   anchorType: AnchorType.smooth,
/// );
/// // Absolute position of handleOut: (150, 100)
/// ```
///
/// ## Removing Handles
///
/// Use the function wrapper pattern to set handles to null:
///
/// ```dart
/// final updated = anchor.copyWith(
///   handleIn: () => null,  // Remove handleIn
/// );
/// ```
@freezed
class AnchorPoint with _$AnchorPoint {
  const AnchorPoint._();

  /// Creates an anchor point with the given properties.
  ///
  /// - [position]: Anchor position in world coordinates (required)
  /// - [handleIn]: Incoming control point as relative offset (optional)
  /// - [handleOut]: Outgoing control point as relative offset (optional)
  /// - [anchorType]: Handle behavior type (defaults to [AnchorType.corner])
  const factory AnchorPoint({
    required Point position,
    Point? handleIn,
    Point? handleOut,
    @Default(AnchorType.corner) AnchorType anchorType,
  }) = _AnchorPoint;

  /// Creates a corner anchor with no handles (sharp corner).
  ///
  /// ```dart
  /// final corner = AnchorPoint.corner(position: Point(x: 100, y: 100));
  /// ```
  factory AnchorPoint.corner({required Point position}) {
    return AnchorPoint(
      position: position,
      anchorType: AnchorType.corner,
    );
  }

  /// Creates a smooth anchor with symmetric handles.
  ///
  /// The [handleOut] is provided, and [handleIn] is automatically set to
  /// its negation (mirrored handle).
  ///
  /// ```dart
  /// final smooth = AnchorPoint.smooth(
  ///   position: Point(x: 100, y: 100),
  ///   handleOut: Point(x: 50, y: 0),
  /// );
  /// // handleIn will be Point(x: -50, y: 0)
  /// ```
  factory AnchorPoint.smooth({
    required Point position,
    required Point handleOut,
  }) {
    return AnchorPoint(
      position: position,
      handleIn: -handleOut,
      handleOut: handleOut,
      anchorType: AnchorType.smooth,
    );
  }

  /// Deserializes an anchor from JSON.
  factory AnchorPoint.fromJson(Map<String, dynamic> json) =>
      _$AnchorPointFromJson(json);

  /// Returns the absolute position of the incoming handle in world coordinates.
  ///
  /// Returns null if [handleIn] is null.
  Point? get handleInAbsolute => handleIn != null ? position + handleIn! : null;

  /// Returns the absolute position of the outgoing handle in world coordinates.
  ///
  /// Returns null if [handleOut] is null.
  Point? get handleOutAbsolute =>
      handleOut != null ? position + handleOut! : null;

  /// Returns true if this anchor has no handles (is a sharp corner).
  bool get isCorner => handleIn == null && handleOut == null;

  /// Returns true if this anchor has at least one handle.
  bool get hasCurve => handleIn != null || handleOut != null;

  /// Translates this anchor by the given offset.
  ///
  /// Since handles are relative offsets, they remain unchanged during translation.
  AnchorPoint translate(Point offset) {
    return copyWith(position: position + offset);
  }

  /// Updates the outgoing handle and mirrors it if this is a smooth anchor.
  ///
  /// For [AnchorType.smooth] anchors, this automatically updates [handleIn]
  /// to be the negation of [newHandleOut].
  AnchorPoint setHandleOut(Point? newHandleOut) {
    if (anchorType == AnchorType.smooth && newHandleOut != null) {
      return copyWith(
        handleOut: newHandleOut,
        handleIn: -newHandleOut,
      );
    }
    return copyWith(handleOut: newHandleOut);
  }

  /// Updates the incoming handle and mirrors it if this is a smooth anchor.
  ///
  /// For [AnchorType.smooth] anchors, this automatically updates [handleOut]
  /// to be the negation of [newHandleIn].
  AnchorPoint setHandleIn(Point? newHandleIn) {
    if (anchorType == AnchorType.smooth && newHandleIn != null) {
      return copyWith(
        handleIn: newHandleIn,
        handleOut: -newHandleIn,
      );
    }
    return copyWith(handleIn: newHandleIn);
  }
}
