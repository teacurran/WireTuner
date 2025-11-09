import 'package:freezed_annotation/freezed_annotation.dart';
import 'point.dart';
import 'anchor.dart';
import 'bounds.dart';
import 'dart:math' as math;

part 'segment.freezed.dart';
part 'segment.g.dart';

/// An immutable segment connecting two anchor points by index.
///
/// Segments define how anchors in a path are connected. They store anchor
/// indices (not direct references) to simplify immutability and avoid circular
/// dependencies.
///
/// ## Segment Types
///
/// - **Line**: Straight line segment (ignores control points)
/// - **Bezier**: Cubic Bezier curve using anchor handles as control points
/// - **Arc**: Circular arc segment (placeholder for future implementation)
///
/// ## Bezier Control Points
///
/// For Bezier segments, control points come from the anchors' handles:
/// - Control Point 1: `anchors[startAnchorIndex].handleOut`
/// - Control Point 2: `anchors[endAnchorIndex].handleIn`
///
/// If handles are null, the segment degrades to a straight line.
///
/// ## Example
///
/// ```dart
/// // Create a Bezier segment connecting anchors 0 and 1
/// final segment = Segment.bezier(
///   startAnchorIndex: 0,
///   endAnchorIndex: 1,
/// );
/// ```
@freezed
class Segment with _$Segment {
  const Segment._();

  /// Creates a segment with the given properties.
  ///
  /// - [startAnchorIndex]: Index of the start anchor in the path's anchor list
  /// - [endAnchorIndex]: Index of the end anchor in the path's anchor list
  /// - [segmentType]: Type of connection (line, bezier, or arc)
  const factory Segment({
    required int startAnchorIndex,
    required int endAnchorIndex,
    required SegmentType segmentType,
  }) = _Segment;

  /// Creates a straight line segment.
  factory Segment.line({
    required int startAnchorIndex,
    required int endAnchorIndex,
  }) {
    return Segment(
      startAnchorIndex: startAnchorIndex,
      endAnchorIndex: endAnchorIndex,
      segmentType: SegmentType.line,
    );
  }

  /// Creates a cubic Bezier curve segment.
  factory Segment.bezier({
    required int startAnchorIndex,
    required int endAnchorIndex,
  }) {
    return Segment(
      startAnchorIndex: startAnchorIndex,
      endAnchorIndex: endAnchorIndex,
      segmentType: SegmentType.bezier,
    );
  }

  /// Creates a circular arc segment (placeholder for future implementation).
  factory Segment.arc({
    required int startAnchorIndex,
    required int endAnchorIndex,
  }) {
    return Segment(
      startAnchorIndex: startAnchorIndex,
      endAnchorIndex: endAnchorIndex,
      segmentType: SegmentType.arc,
    );
  }

  /// Deserializes a segment from JSON.
  factory Segment.fromJson(Map<String, dynamic> json) =>
      _$SegmentFromJson(json);

  /// Evaluates the point on this segment at parameter t ∈ [0, 1].
  ///
  /// Requires the actual anchor points to compute the position.
  ///
  /// - For line segments: Linear interpolation
  /// - For Bezier segments: Cubic Bezier evaluation
  /// - For arc segments: Not yet implemented (throws)
  Point pointAt(double t, AnchorPoint startAnchor, AnchorPoint endAnchor) {
    switch (segmentType) {
      case SegmentType.line:
        return _evaluateLine(t, startAnchor, endAnchor);
      case SegmentType.bezier:
        return _evaluateBezier(t, startAnchor, endAnchor);
      case SegmentType.arc:
        throw UnimplementedError('Arc segments are not yet implemented');
    }
  }

  /// Computes the bounding box of this segment.
  ///
  /// - For line segments: Bounds of the two endpoints
  /// - For Bezier segments: Bounds including control points (conservative)
  /// - For arc segments: Not yet implemented (throws)
  Bounds computeBounds(AnchorPoint startAnchor, AnchorPoint endAnchor) {
    switch (segmentType) {
      case SegmentType.line:
        return _computeLineBounds(startAnchor, endAnchor);
      case SegmentType.bezier:
        return _computeBezierBounds(startAnchor, endAnchor);
      case SegmentType.arc:
        throw UnimplementedError('Arc segments are not yet implemented');
    }
  }

  /// Approximates the arc length of this segment.
  ///
  /// Uses numerical integration with the specified number of subdivisions.
  double approximateLength(
    AnchorPoint startAnchor,
    AnchorPoint endAnchor, {
    int subdivisions = 10,
  }) {
    switch (segmentType) {
      case SegmentType.line:
        return startAnchor.position.distanceTo(endAnchor.position);
      case SegmentType.bezier:
        return _approximateBezierLength(
          startAnchor,
          endAnchor,
          subdivisions,
        );
      case SegmentType.arc:
        throw UnimplementedError('Arc segments are not yet implemented');
    }
  }

  // ========== Line Segment Methods ==========

  Point _evaluateLine(
    double t,
    AnchorPoint startAnchor,
    AnchorPoint endAnchor,
  ) {
    return startAnchor.position.lerp(endAnchor.position, t);
  }

  Bounds _computeLineBounds(
    AnchorPoint startAnchor,
    AnchorPoint endAnchor,
  ) {
    return Bounds.fromPoints([startAnchor.position, endAnchor.position]);
  }

  // ========== Bezier Segment Methods ==========

  /// Evaluates a cubic Bezier curve at parameter t using De Casteljau's algorithm.
  ///
  /// The cubic Bezier formula is:
  /// P(t) = (1-t)³·P₀ + 3(1-t)²t·P₁ + 3(1-t)t²·P₂ + t³·P₃
  ///
  /// Where:
  /// - P₀ = startAnchor.position
  /// - P₁ = startAnchor.position + startAnchor.handleOut (or P₀ if null)
  /// - P₂ = endAnchor.position + endAnchor.handleIn (or P₃ if null)
  /// - P₃ = endAnchor.position
  Point _evaluateBezier(
    double t,
    AnchorPoint startAnchor,
    AnchorPoint endAnchor,
  ) {
    final p0 = startAnchor.position;
    final p3 = endAnchor.position;
    final p1 = startAnchor.handleOutAbsolute ?? p0;
    final p2 = endAnchor.handleInAbsolute ?? p3;

    // If both handles are null, degrade to line
    if (p1 == p0 && p2 == p3) {
      return _evaluateLine(t, startAnchor, endAnchor);
    }

    final t2 = t * t;
    final t3 = t2 * t;
    final mt = 1.0 - t;
    final mt2 = mt * mt;
    final mt3 = mt2 * mt;

    return Point(
      x: mt3 * p0.x + 3 * mt2 * t * p1.x + 3 * mt * t2 * p2.x + t3 * p3.x,
      y: mt3 * p0.y + 3 * mt2 * t * p1.y + 3 * mt * t2 * p2.y + t3 * p3.y,
    );
  }

  /// Computes a conservative bounding box for a Bezier curve.
  ///
  /// Uses the control point hull (convex hull of the four control points).
  /// This is conservative (may be larger than the actual curve bounds) but
  /// fast to compute and sufficient for most use cases.
  ///
  /// For a tighter bound, we would need to find curve extrema by solving
  /// the derivative equation, which is more complex.
  Bounds _computeBezierBounds(
    AnchorPoint startAnchor,
    AnchorPoint endAnchor,
  ) {
    final p0 = startAnchor.position;
    final p3 = endAnchor.position;
    final p1 = startAnchor.handleOutAbsolute ?? p0;
    final p2 = endAnchor.handleInAbsolute ?? p3;

    // Control point hull bounds
    final points = [p0, p1, p2, p3];
    return Bounds.fromPoints(points);
  }

  /// Approximates the arc length of a Bezier curve using subdivision.
  ///
  /// Divides the curve into [subdivisions] linear segments and sums their lengths.
  double _approximateBezierLength(
    AnchorPoint startAnchor,
    AnchorPoint endAnchor,
    int subdivisions,
  ) {
    double length = 0.0;
    Point? previousPoint;

    for (int i = 0; i <= subdivisions; i++) {
      final t = i / subdivisions;
      final point = _evaluateBezier(t, startAnchor, endAnchor);

      if (previousPoint != null) {
        length += previousPoint.distanceTo(point);
      }
      previousPoint = point;
    }

    return length;
  }
}

/// Defines the type of connection between two anchor points.
enum SegmentType {
  /// Straight line segment (ignores control points).
  line,

  /// Cubic Bezier curve using anchor handles as control points.
  bezier,

  /// Circular arc segment (placeholder for future implementation).
  arc,
}
