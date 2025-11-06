import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/models/anchor_point.dart';
import 'package:wiretuner/domain/models/geometry/point_extensions.dart';
import 'package:wiretuner/domain/models/geometry/rectangle.dart';
import 'package:wiretuner/domain/models/segment.dart';

/// Represents an immutable vector path composed of anchor points and segments.
///
/// A path is a fundamental building block in the vector editing system. It
/// consists of:
/// - A list of [anchors] that define positions and curve control points
/// - A list of [segments] that connect anchors (by index) with lines or curves
/// - A [closed] flag indicating whether the path loops back to the start
///
/// ## Path Structure
///
/// Paths own the authoritative list of [AnchorPoint] objects. Segments
/// reference these anchors by index rather than storing direct references,
/// which avoids circular dependencies and simplifies the data model.
///
/// For closed paths, there is an implicit segment from the last anchor to
/// the first anchor. This affects geometric calculations like [bounds],
/// [length], and [pointAt].
///
/// ## Immutability
///
/// Path follows the immutable domain model pattern:
/// - All fields are final
/// - Lists are exposed directly (callers must not modify them)
/// - Use [copyWith] to create modified versions
/// - Value equality via operator==
///
/// ## Examples
///
/// Create a simple line path:
/// ```dart
/// final path = Path(
///   anchors: [
///     AnchorPoint.corner(Point(x: 0, y: 0)),
///     AnchorPoint.corner(Point(x: 100, y: 100)),
///   ],
///   segments: [
///     Segment.line(startIndex: 0, endIndex: 1),
///   ],
/// );
/// ```
///
/// Create a closed triangular path:
/// ```dart
/// final triangle = Path(
///   anchors: [
///     AnchorPoint.corner(Point(x: 0, y: 0)),
///     AnchorPoint.corner(Point(x: 100, y: 0)),
///     AnchorPoint.corner(Point(x: 50, y: 86.6)),
///   ],
///   segments: [
///     Segment.line(startIndex: 0, endIndex: 1),
///     Segment.line(startIndex: 1, endIndex: 2),
///   ],
///   closed: true, // Implicit segment from index 2 to 0
/// );
/// ```
///
/// Create a curved path with Bezier segments:
/// ```dart
/// final curve = Path(
///   anchors: [
///     AnchorPoint(
///       position: Point(x: 0, y: 0),
///       handleOut: Point(x: 50, y: 0),
///     ),
///     AnchorPoint(
///       position: Point(x: 100, y: 100),
///       handleIn: Point(x: -50, y: 0),
///     ),
///   ],
///   segments: [
///     Segment.bezier(startIndex: 0, endIndex: 1),
///   ],
/// );
/// ```
///
/// Query path geometry:
/// ```dart
/// final rect = path.bounds(); // Bounding rectangle
/// final len = path.length(); // Total arc length
/// final midpoint = path.pointAt(0.5); // Point halfway along path
/// ```
@immutable
class Path {
  /// The anchor points that define this path.
  ///
  /// Segments reference these anchors by index. The list must contain
  /// at least one anchor for a valid path. Empty anchor lists are allowed
  /// but represent degenerate paths with zero length and bounds.
  ///
  /// Each anchor defines a position and optional Bezier control point handles
  /// that affect the curvature of adjacent segments.
  final List<AnchorPoint> anchors;

  /// The segments that connect anchor points.
  ///
  /// Each segment's [Segment.startAnchorIndex] and [Segment.endAnchorIndex]
  /// must be valid indices into the [anchors] list.
  ///
  /// Segments define the type of connection (line or Bezier curve) between
  /// two anchors. The number of segments is typically `anchors.length - 1`
  /// for open paths, but can vary if anchors are not fully connected.
  final List<Segment> segments;

  /// Whether this path is closed.
  ///
  /// If true, an implicit segment connects the last anchor to the first
  /// anchor, creating a closed loop. This affects geometric calculations:
  /// - [bounds] includes the closing segment's control points
  /// - [length] includes the closing segment's arc length
  /// - [pointAt] can traverse the closing segment
  ///
  /// For a closed path with n anchors, there are effectively n segments
  /// (n-1 explicit + 1 implicit).
  final bool closed;

  /// Creates a path with the specified anchors and segments.
  ///
  /// The [anchors] list defines the positions and control points.
  /// The [segments] list defines how anchors are connected.
  /// The [closed] flag (default false) controls whether the path loops back.
  ///
  /// **Validation**: This constructor does not validate that segment indices
  /// are within bounds. Invalid indices will cause runtime errors when
  /// geometric methods are called. Use [_validateSegmentIndices] in debug
  /// mode if validation is needed.
  const Path({
    required this.anchors,
    required this.segments,
    this.closed = false,
  });

  /// Creates an empty path with no anchors or segments.
  ///
  /// Empty paths have zero length and zero-sized bounds at the origin.
  ///
  /// Example:
  /// ```dart
  /// final empty = Path.empty();
  /// assert(empty.anchors.isEmpty);
  /// assert(empty.length() == 0);
  /// ```
  factory Path.empty() => const Path(
        anchors: [],
        segments: [],
        closed: false,
      );

  /// Creates a path from a list of anchor points with automatic line segments.
  ///
  /// Segments are automatically created as line segments connecting
  /// consecutive anchors. This is a convenient factory for creating
  /// simple polyline paths.
  ///
  /// If [anchors] has fewer than 2 elements, no segments are created.
  ///
  /// Example:
  /// ```dart
  /// final polyline = Path.fromAnchors(
  ///   anchors: [
  ///     AnchorPoint.corner(Point(x: 0, y: 0)),
  ///     AnchorPoint.corner(Point(x: 50, y: 50)),
  ///     AnchorPoint.corner(Point(x: 100, y: 0)),
  ///   ],
  ///   closed: false,
  /// );
  /// // Creates 2 line segments: 0->1 and 1->2
  /// ```
  factory Path.fromAnchors({
    required List<AnchorPoint> anchors,
    bool closed = false,
  }) {
    if (anchors.length < 2) {
      return Path(
        anchors: anchors,
        segments: const [],
        closed: false,
      );
    }

    final segments = <Segment>[];
    for (int i = 0; i < anchors.length - 1; i++) {
      segments.add(Segment.line(startIndex: i, endIndex: i + 1));
    }

    return Path(
      anchors: anchors,
      segments: segments,
      closed: closed,
    );
  }

  /// Creates a simple two-point line path.
  ///
  /// Convenience factory for creating a straight line from [start] to [end].
  ///
  /// Example:
  /// ```dart
  /// final line = Path.line(
  ///   start: Point(x: 0, y: 0),
  ///   end: Point(x: 100, y: 50),
  /// );
  /// ```
  factory Path.line({
    required Point start,
    required Point end,
  }) =>
      Path(
        anchors: [
          AnchorPoint.corner(start),
          AnchorPoint.corner(end),
        ],
        segments: [
          Segment.line(startIndex: 0, endIndex: 1),
        ],
        closed: false,
      );

  /// Calculates the bounding rectangle that contains all points in this path.
  ///
  /// Uses the **control point bounds** approach: the bounding box includes
  /// all anchor positions and their Bezier control point absolute positions.
  /// This is computationally simpler than true Bezier bounds and provides
  /// a conservative bound (the true curve is guaranteed to be inside).
  ///
  /// For closed paths, all anchors including their handles are considered,
  /// but no special handling is needed for the implicit closing segment
  /// since it connects existing anchors.
  ///
  /// Returns a zero-sized rectangle at the origin for empty paths.
  ///
  /// Example:
  /// ```dart
  /// final path = Path.line(
  ///   start: Point(x: 10, y: 20),
  ///   end: Point(x: 110, y: 70),
  /// );
  /// final bounds = path.bounds();
  /// // bounds: Rectangle(x: 10, y: 20, width: 100, height: 50)
  /// ```
  Rectangle bounds() {
    if (anchors.isEmpty) {
      return const Rectangle(x: 0, y: 0, width: 0, height: 0);
    }

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final anchor in anchors) {
      // Include anchor position
      minX = math.min(minX, anchor.position.x);
      minY = math.min(minY, anchor.position.y);
      maxX = math.max(maxX, anchor.position.x);
      maxY = math.max(maxY, anchor.position.y);

      // Include handleIn control point (if exists)
      // Note: handles are relative offsets, must add to position
      if (anchor.handleIn != null) {
        final handleInAbs = anchor.position + anchor.handleIn!;
        minX = math.min(minX, handleInAbs.x);
        minY = math.min(minY, handleInAbs.y);
        maxX = math.max(maxX, handleInAbs.x);
        maxY = math.max(maxY, handleInAbs.y);
      }

      // Include handleOut control point (if exists)
      if (anchor.handleOut != null) {
        final handleOutAbs = anchor.position + anchor.handleOut!;
        minX = math.min(minX, handleOutAbs.x);
        minY = math.min(minY, handleOutAbs.y);
        maxX = math.max(maxX, handleOutAbs.x);
        maxY = math.max(maxY, handleOutAbs.y);
      }
    }

    return Rectangle.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Calculates the total arc length of this path.
  ///
  /// The length is computed by summing the lengths of all segments:
  /// - For line segments: Euclidean distance between anchors
  /// - For Bezier segments: Approximate arc length using subdivision
  ///
  /// For closed paths, the implicit closing segment (from last anchor to
  /// first anchor) is included in the total length.
  ///
  /// Returns 0 for empty paths or paths with no segments.
  ///
  /// **Accuracy**: Bezier arc lengths are approximated using 10 subdivisions,
  /// which is sufficient for UI purposes but not mathematically exact.
  ///
  /// Example:
  /// ```dart
  /// final path = Path.line(
  ///   start: Point(x: 0, y: 0),
  ///   end: Point(x: 3, y: 4),
  /// );
  /// print(path.length()); // 5.0 (3-4-5 right triangle)
  /// ```
  double length() {
    if (anchors.isEmpty) return 0.0;

    double totalLength = 0.0;

    // Calculate length of explicit segments
    for (final segment in segments) {
      final startAnchor = anchors[segment.startAnchorIndex];
      final endAnchor = anchors[segment.endAnchorIndex];
      totalLength += _segmentLength(segment, startAnchor, endAnchor);
    }

    // For closed paths, add implicit closing segment
    if (closed && anchors.length > 1) {
      final lastAnchor = anchors.last;
      final firstAnchor = anchors.first;

      // Determine closing segment type based on handles
      // If either anchor has handles, treat as Bezier, otherwise line
      final hasHandles =
          lastAnchor.handleOut != null || firstAnchor.handleIn != null;

      if (hasHandles) {
        totalLength += _bezierLength(lastAnchor, firstAnchor);
      } else {
        totalLength += lastAnchor.position.distanceTo(firstAnchor.position);
      }
    }

    return totalLength;
  }

  /// Returns the point at normalized parameter [t] along this path.
  ///
  /// The parameter [t] is in the range [0, 1], where:
  /// - t = 0: first anchor position
  /// - t = 1: last anchor position (or first for closed paths)
  /// - t = 0.5: point halfway along the path's arc length
  ///
  /// Values outside [0, 1] are clamped to the valid range.
  ///
  /// The implementation walks through segments, accumulating distance until
  /// the target distance (t * total length) is reached, then evaluates the
  /// containing segment at its local parameter.
  ///
  /// Returns the first anchor position for empty or single-anchor paths.
  ///
  /// Example:
  /// ```dart
  /// final path = Path.line(
  ///   start: Point(x: 0, y: 0),
  ///   end: Point(x: 100, y: 0),
  /// );
  /// final midpoint = path.pointAt(0.5);
  /// // midpoint: Point(x: 50, y: 0)
  /// ```
  Point pointAt(double t) {
    // Clamp t to [0, 1]
    t = t.clamp(0.0, 1.0);

    if (anchors.isEmpty) {
      return const Point(x: 0, y: 0);
    }
    if (anchors.length == 1) {
      return anchors.first.position;
    }

    final totalLength = length();
    if (totalLength == 0) {
      return anchors.first.position;
    }

    final targetDistance = totalLength * t;
    double cumulativeDistance = 0.0;

    // Walk through explicit segments
    for (final segment in segments) {
      final startAnchor = anchors[segment.startAnchorIndex];
      final endAnchor = anchors[segment.endAnchorIndex];

      final segmentLength = _segmentLength(segment, startAnchor, endAnchor);

      // Use small epsilon for floating point comparison
      const double epsilon = 0.0001;
      if (cumulativeDistance + segmentLength >= targetDistance - epsilon) {
        // Target point is within this segment
        final localT = segmentLength > 0
            ? (targetDistance - cumulativeDistance) / segmentLength
            : 0.0;
        return _evaluateSegmentAt(segment, startAnchor, endAnchor, localT);
      }

      cumulativeDistance += segmentLength;
    }

    // For closed paths, check implicit closing segment
    if (closed && anchors.length > 1) {
      final lastAnchor = anchors.last;
      final firstAnchor = anchors.first;

      final hasHandles =
          lastAnchor.handleOut != null || firstAnchor.handleIn != null;

      final closingLength = hasHandles
          ? _bezierLength(lastAnchor, firstAnchor)
          : lastAnchor.position.distanceTo(firstAnchor.position);

      const double epsilon = 0.0001;
      if (cumulativeDistance + closingLength >= targetDistance - epsilon) {
        // Target point is within closing segment
        final localT = closingLength > 0
            ? (targetDistance - cumulativeDistance) / closingLength
            : 0.0;

        if (hasHandles) {
          return _evaluateBezier(lastAnchor, firstAnchor, localT);
        } else {
          // Linear interpolation for line segment
          final startPos = lastAnchor.position;
          final endPos = firstAnchor.position;
          return Point(
            x: startPos.x + (endPos.x - startPos.x) * localT,
            y: startPos.y + (endPos.y - startPos.y) * localT,
          );
        }
      }
    }

    // Fallback: return last anchor position (or first if closed)
    return closed ? anchors.first.position : anchors.last.position;
  }

  /// Calculates the length of a single segment.
  double _segmentLength(
    Segment segment,
    AnchorPoint start,
    AnchorPoint end,
  ) {
    if (segment.isLine) {
      return start.position.distanceTo(end.position);
    } else if (segment.isBezier) {
      return _bezierLength(start, end);
    }
    return 0.0; // Arc segments not yet implemented
  }

  /// Approximates the arc length of a Bezier curve segment.
  ///
  /// Uses subdivision method: divides the curve into 10 straight line
  /// segments and sums their lengths. This provides reasonable accuracy
  /// for UI purposes (typically within 1% of true arc length).
  double _bezierLength(AnchorPoint start, AnchorPoint end) {
    const int subdivisions = 10;
    double length = 0.0;

    Point prevPoint = start.position;

    for (int i = 1; i <= subdivisions; i++) {
      final t = i / subdivisions;
      final point = _evaluateBezier(start, end, t);
      length += prevPoint.distanceTo(point);
      prevPoint = point;
    }

    return length;
  }

  /// Evaluates a Bezier curve at parameter t in [0, 1].
  ///
  /// Uses the cubic Bezier formula:
  /// P(t) = (1-t)³P₀ + 3(1-t)²tP₁ + 3(1-t)t²P₂ + t³P₃
  ///
  /// Where:
  /// - P₀ = start anchor position
  /// - P₁ = start anchor handleOut (absolute position)
  /// - P₂ = end anchor handleIn (absolute position)
  /// - P₃ = end anchor position
  ///
  /// If control points are null, they default to the anchor positions,
  /// which degrades the curve to a straight line.
  Point _evaluateBezier(AnchorPoint start, AnchorPoint end, double t) {
    final p0 = start.position;
    final p1 =
        start.handleOut != null ? start.position + start.handleOut! : p0;
    final p2 = end.handleIn != null ? end.position + end.handleIn! : end.position;
    final p3 = end.position;

    final t2 = t * t;
    final t3 = t2 * t;
    final mt = 1 - t;
    final mt2 = mt * mt;
    final mt3 = mt2 * mt;

    return Point(
      x: mt3 * p0.x + 3 * mt2 * t * p1.x + 3 * mt * t2 * p2.x + t3 * p3.x,
      y: mt3 * p0.y + 3 * mt2 * t * p1.y + 3 * mt * t2 * p2.y + t3 * p3.y,
    );
  }

  /// Evaluates a segment at parameter t in [0, 1].
  Point _evaluateSegmentAt(
    Segment segment,
    AnchorPoint start,
    AnchorPoint end,
    double t,
  ) {
    if (segment.isLine) {
      // Linear interpolation
      final startPos = start.position;
      final endPos = end.position;
      return Point(
        x: startPos.x + (endPos.x - startPos.x) * t,
        y: startPos.y + (endPos.y - startPos.y) * t,
      );
    } else if (segment.isBezier) {
      return _evaluateBezier(start, end, t);
    }
    return start.position; // Fallback for unsupported segment types
  }

  /// Creates a copy of this path with modified fields.
  ///
  /// All parameters are optional. Fields not specified will retain their
  /// current values from this instance.
  ///
  /// **Important**: To preserve immutability, create new lists when modifying:
  /// ```dart
  /// // Add an anchor (create new list)
  /// final updated = path.copyWith(
  ///   anchors: [...path.anchors, newAnchor],
  /// );
  ///
  /// // Or use List.from
  /// final updated2 = path.copyWith(
  ///   anchors: List<AnchorPoint>.from(path.anchors)..add(newAnchor),
  /// );
  /// ```
  Path copyWith({
    List<AnchorPoint>? anchors,
    List<Segment>? segments,
    bool? closed,
  }) =>
      Path(
        anchors: anchors ?? this.anchors,
        segments: segments ?? this.segments,
        closed: closed ?? this.closed,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Path) return false;

    // Compare list lengths first for early exit
    if (anchors.length != other.anchors.length) return false;
    if (segments.length != other.segments.length) return false;

    // Compare anchors element-by-element
    for (int i = 0; i < anchors.length; i++) {
      if (anchors[i] != other.anchors[i]) return false;
    }

    // Compare segments element-by-element
    for (int i = 0; i < segments.length; i++) {
      if (segments[i] != other.segments[i]) return false;
    }

    return closed == other.closed;
  }

  @override
  int get hashCode => Object.hashAll([
        ...anchors.map((a) => a.hashCode),
        ...segments.map((s) => s.hashCode),
        closed,
      ]);

  @override
  String toString() => 'Path(anchors: ${anchors.length}, '
      'segments: ${segments.length}, closed: $closed)';
}
