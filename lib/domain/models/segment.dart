import 'package:flutter/foundation.dart';

/// Type of segment connection between anchor points.
///
/// Segments define how two anchor points are connected in a vector path.
/// The type determines the mathematical curve used to render the connection.
enum SegmentType {
  /// Straight line segment (ignores control points).
  ///
  /// The segment is rendered as a straight line from the start anchor
  /// to the end anchor. Any Bezier control points on the anchors are
  /// ignored for this segment.
  line,

  /// Cubic Bezier curve segment using control points.
  ///
  /// The segment is rendered as a cubic Bezier curve. The curve is
  /// controlled by:
  /// - P0: start anchor position
  /// - P1: start anchor's handleOut (control point 1)
  /// - P2: end anchor's handleIn (control point 2)
  /// - P3: end anchor position
  ///
  /// If the control points are null, the segment degrades to a line.
  bezier,

  /// Circular arc segment (future enhancement).
  ///
  /// The segment will be rendered as a circular arc between the start
  /// and end anchors. This is a placeholder for future implementation.
  ///
  /// Arc segments are useful for creating perfect circles, ellipses,
  /// and rounded corners without using Bezier approximations.
  arc,
}

/// Represents an immutable segment connecting two anchor points.
///
/// A segment defines how two anchors are connected in a vector path.
/// It stores references to the start and end anchor indices (within
/// the path's anchor list) and the type of connection.
///
/// ## Design Rationale
///
/// Segments store **anchor indices** rather than AnchorPoint objects
/// to avoid circular references and simplify the data model. The parent
/// Path object owns the list of anchors, and segments reference them
/// by index.
///
/// For Bezier segments, the actual control points come from the anchors'
/// handles:
/// - Control point 1: `anchors[startAnchorIndex].handleOut`
/// - Control point 2: `anchors[endAnchorIndex].handleIn`
///
/// ## Examples
///
/// Create a line segment:
/// ```dart
/// final line = Segment.line(
///   startIndex: 0,
///   endIndex: 1,
/// );
/// ```
///
/// Create a Bezier curve segment:
/// ```dart
/// final curve = Segment.bezier(
///   startIndex: 1,
///   endIndex: 2,
/// );
/// ```
///
/// Modify a segment:
/// ```dart
/// final updated = segment.copyWith(
///   segmentType: SegmentType.line,
/// );
/// ```
@immutable
class Segment {
  /// Creates a segment connecting two anchors.
  ///
  /// The [startAnchorIndex] and [endAnchorIndex] must be valid indices
  /// into the path's anchor list. The [segmentType] determines how the
  /// segment is rendered.
  ///
  /// Note: This constructor does not validate that the indices are valid.
  /// The path that owns this segment is responsible for ensuring the
  /// indices are within bounds.
  const Segment({
    required this.startAnchorIndex,
    required this.endAnchorIndex,
    required this.segmentType,
  });

  /// Creates a straight line segment.
  ///
  /// This factory creates a segment that renders as a straight line
  /// from the start anchor to the end anchor, ignoring any Bezier
  /// control points on the anchors.
  ///
  /// Example:
  /// ```dart
  /// final line = Segment.line(
  ///   startIndex: 0,
  ///   endIndex: 1,
  /// );
  /// assert(line.isLine);
  /// ```
  factory Segment.line({
    required int startIndex,
    required int endIndex,
  }) =>
      Segment(
        startAnchorIndex: startIndex,
        endAnchorIndex: endIndex,
        segmentType: SegmentType.line,
      );

  /// Creates a Bezier curve segment.
  ///
  /// This factory creates a segment that renders as a cubic Bezier curve.
  /// The curve's shape is controlled by the handleOut of the start anchor
  /// and the handleIn of the end anchor.
  ///
  /// Example:
  /// ```dart
  /// final curve = Segment.bezier(
  ///   startIndex: 1,
  ///   endIndex: 2,
  /// );
  /// assert(curve.isBezier);
  /// ```
  factory Segment.bezier({
    required int startIndex,
    required int endIndex,
  }) =>
      Segment(
        startAnchorIndex: startIndex,
        endAnchorIndex: endIndex,
        segmentType: SegmentType.bezier,
      );

  /// Index of the start anchor in the path's anchor list.
  ///
  /// This index must be valid (within bounds) for the path that owns
  /// this segment. The start anchor defines:
  /// - The starting point of the segment (anchor.position)
  /// - For Bezier curves: control point 1 (anchor.handleOut)
  final int startAnchorIndex;

  /// Index of the end anchor in the path's anchor list.
  ///
  /// This index must be valid (within bounds) for the path that owns
  /// this segment. The end anchor defines:
  /// - The ending point of the segment (anchor.position)
  /// - For Bezier curves: control point 2 (anchor.handleIn)
  final int endAnchorIndex;

  /// The type of segment (line, bezier, or arc).
  ///
  /// Determines how the segment is rendered between the start and end anchors.
  final SegmentType segmentType;

  /// Whether this is a line segment.
  ///
  /// Returns true if [segmentType] is [SegmentType.line].
  bool get isLine => segmentType == SegmentType.line;

  /// Whether this is a Bezier curve segment.
  ///
  /// Returns true if [segmentType] is [SegmentType.bezier].
  bool get isBezier => segmentType == SegmentType.bezier;

  /// Creates a copy of this segment with modified fields.
  ///
  /// All parameters are optional. Fields not specified will retain their
  /// current values from this instance.
  ///
  /// Example:
  /// ```dart
  /// // Change segment type from line to bezier
  /// final curved = lineSegment.copyWith(
  ///   segmentType: SegmentType.bezier,
  /// );
  ///
  /// // Update anchor indices
  /// final reindexed = segment.copyWith(
  ///   startAnchorIndex: 2,
  ///   endAnchorIndex: 3,
  /// );
  /// ```
  Segment copyWith({
    int? startAnchorIndex,
    int? endAnchorIndex,
    SegmentType? segmentType,
  }) =>
      Segment(
        startAnchorIndex: startAnchorIndex ?? this.startAnchorIndex,
        endAnchorIndex: endAnchorIndex ?? this.endAnchorIndex,
        segmentType: segmentType ?? this.segmentType,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Segment &&
        other.startAnchorIndex == startAnchorIndex &&
        other.endAnchorIndex == endAnchorIndex &&
        other.segmentType == segmentType;
  }

  @override
  int get hashCode =>
      Object.hash(startAnchorIndex, endAnchorIndex, segmentType);

  @override
  String toString() =>
      'Segment(start: $startAnchorIndex, end: $endAnchorIndex, '
      'type: $segmentType)';
}
