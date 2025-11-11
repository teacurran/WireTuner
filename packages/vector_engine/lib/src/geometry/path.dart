import 'package:freezed_annotation/freezed_annotation.dart';
import 'point.dart';
import 'anchor.dart';
import 'segment.dart';
import 'bounds.dart';

part 'path.freezed.dart';
part 'path.g.dart';

/// An immutable vector path composed of anchor points and segments.
///
/// Paths are the fundamental curve primitive in WireTuner. They consist of:
/// - **Anchors**: Ordered list of anchor points (positions + handles)
/// - **Segments**: Ordered list of segments connecting anchors by index
/// - **Closed**: Whether the path loops back to the start
///
/// ## Path Structure Invariants
///
/// 1. **Anchor Ownership**: Paths own the authoritative list of anchors;
///    segments reference anchors by index
/// 2. **Implicit Closing Segment**: For closed paths with n anchors, there are
///    effectively n segments (n-1 explicit + 1 implicit from last to first)
/// 3. **Index Validity**: Segment indices must be valid into the anchors list
///
/// ## Handle Coordinates
///
/// Anchor handles are stored as **relative offsets** from the anchor position.
/// Geometric calculations must convert to absolute positions:
///
/// ```dart
/// final anchor = path.anchors[0];
/// final handleOutAbsolute = anchor.position + anchor.handleOut!;
/// ```
///
/// ## Example
///
/// ```dart
/// // Create a simple triangle path
/// final triangle = Path(
///   anchors: [
///     AnchorPoint.corner(position: Point(x: 100, y: 100)),
///     AnchorPoint.corner(position: Point(x: 200, y: 100)),
///     AnchorPoint.corner(position: Point(x: 150, y: 200)),
///   ],
///   segments: [
///     Segment.line(startAnchorIndex: 0, endAnchorIndex: 1),
///     Segment.line(startAnchorIndex: 1, endAnchorIndex: 2),
///   ],
///   closed: true,  // Implicit segment from anchor 2 to 0
/// );
/// ```
@freezed
class Path with _$Path {
  const Path._();

  /// Creates a path with the given anchors, segments, and closed flag.
  ///
  /// - [anchors]: Ordered list of anchor points (required, must not be empty)
  /// - [segments]: Ordered list of segments connecting anchors (required)
  /// - [closed]: Whether the path loops back to the start (defaults to false)
  const factory Path({
    required List<AnchorPoint> anchors,
    required List<Segment> segments,
    @Default(false) bool closed,
  }) = _Path;

  /// Creates an empty path with no anchors or segments.
  factory Path.empty() => const Path(
        anchors: [],
        segments: [],
        closed: false,
      );

  /// Creates a path from a list of anchors with automatic line segments.
  ///
  /// Generates line segments connecting consecutive anchors.
  ///
  /// ```dart
  /// final path = Path.fromAnchors(
  ///   anchors: [anchor1, anchor2, anchor3],
  ///   closed: true,
  /// );
  /// // Creates 2 explicit segments: 0→1, 1→2
  /// // Plus implicit closing segment: 2→0
  /// ```
  factory Path.fromAnchors({
    required List<AnchorPoint> anchors,
    bool closed = false,
  }) {
    if (anchors.isEmpty) {
      return Path.empty();
    }

    final segments = <Segment>[];
    for (int i = 0; i < anchors.length - 1; i++) {
      segments.add(Segment.line(
        startAnchorIndex: i,
        endAnchorIndex: i + 1,
      ));
    }

    return Path(
      anchors: anchors,
      segments: segments,
      closed: closed,
    );
  }

  /// Creates a simple two-point line path.
  ///
  /// ```dart
  /// final line = Path.line(
  ///   start: Point(x: 0, y: 0),
  ///   end: Point(x: 100, y: 100),
  /// );
  /// ```
  factory Path.line({
    required Point start,
    required Point end,
  }) {
    return Path(
      anchors: [
        AnchorPoint.corner(position: start),
        AnchorPoint.corner(position: end),
      ],
      segments: [
        Segment.line(startAnchorIndex: 0, endAnchorIndex: 1),
      ],
      closed: false,
    );
  }

  /// Deserializes a path from JSON.
  factory Path.fromJson(Map<String, dynamic> json) => _$PathFromJson(json);

  /// Returns true if this path has no anchors.
  bool get isEmpty => anchors.isEmpty;

  /// Returns true if this path has at least one anchor.
  bool get isNotEmpty => anchors.isNotEmpty;

  /// Returns the number of effective segments (including implicit closing segment).
  int get effectiveSegmentCount => closed ? segments.length + 1 : segments.length;

  /// Computes the control point bounding box.
  ///
  /// Includes all anchor positions and handle absolute positions.
  /// This is a conservative bound (may be larger than the actual curve bounds).
  Bounds bounds() {
    if (anchors.isEmpty) {
      return Bounds.zero();
    }

    final points = <Point>[];

    // Add all anchor positions
    for (final anchor in anchors) {
      points.add(anchor.position);

      // Add handle positions (converted to absolute)
      if (anchor.handleInAbsolute != null) {
        points.add(anchor.handleInAbsolute!);
      }
      if (anchor.handleOutAbsolute != null) {
        points.add(anchor.handleOutAbsolute!);
      }
    }

    return Bounds.fromPoints(points);
  }

  /// Approximates the total arc length of the path.
  ///
  /// Uses numerical integration with the specified number of subdivisions
  /// per segment.
  double length({int subdivisions = 10}) {
    if (anchors.isEmpty) return 0.0;

    double totalLength = 0.0;

    // Compute length of explicit segments
    for (final segment in segments) {
      if (segment.startAnchorIndex < anchors.length &&
          segment.endAnchorIndex < anchors.length) {
        final startAnchor = anchors[segment.startAnchorIndex];
        final endAnchor = anchors[segment.endAnchorIndex];
        totalLength += segment.approximateLength(
          startAnchor,
          endAnchor,
          subdivisions: subdivisions,
        );
      }
    }

    // Add closing segment if closed
    if (closed && anchors.length >= 2) {
      final closingSegment = Segment.line(
        startAnchorIndex: anchors.length - 1,
        endAnchorIndex: 0,
      );
      totalLength += closingSegment.approximateLength(
        anchors.last,
        anchors.first,
        subdivisions: subdivisions,
      );
    }

    return totalLength;
  }

  /// Returns the point at normalized parameter t ∈ [0, 1] along the path.
  ///
  /// - t = 0: Start of the path
  /// - t = 1: End of the path (or back to start if closed)
  /// - t ∈ (0, 1): Interpolated position along the path
  ///
  /// This distributes t uniformly across all segments (not by arc length).
  Point pointAt(double t) {
    if (anchors.isEmpty) {
      throw StateError('Cannot evaluate point on empty path');
    }

    if (anchors.length == 1) {
      return anchors.first.position;
    }

    final segmentCount = effectiveSegmentCount;
    if (segmentCount == 0) {
      return anchors.first.position;
    }

    // Clamp t to [0, 1]
    t = t.clamp(0.0, 1.0);

    // Map t to segment index and local t
    final scaledT = t * segmentCount;
    final segmentIndex = (scaledT.floor()).clamp(0, segmentCount - 1);
    final localT = scaledT - segmentIndex;

    // Get the segment (or create implicit closing segment)
    final Segment segment;
    if (segmentIndex < segments.length) {
      segment = segments[segmentIndex];
    } else {
      // Implicit closing segment
      segment = Segment.line(
        startAnchorIndex: anchors.length - 1,
        endAnchorIndex: 0,
      );
    }

    final startAnchor = anchors[segment.startAnchorIndex];
    final endAnchor = anchors[segment.endAnchorIndex];

    return segment.pointAt(localT, startAnchor, endAnchor);
  }

  /// Translates the entire path by the given offset.
  ///
  /// Since handles are relative offsets, only anchor positions are updated.
  Path translate(Point offset) {
    return copyWith(
      anchors: anchors.map((a) => a.translate(offset)).toList(),
    );
  }

  /// Returns all segments including the implicit closing segment (if closed).
  List<Segment> get allSegments {
    if (!closed || anchors.length < 2) {
      return segments;
    }

    return [
      ...segments,
      Segment.line(
        startAnchorIndex: anchors.length - 1,
        endAnchorIndex: 0,
      ),
    ];
  }

  /// Returns true if the path has at least 2 anchors (can be rendered).
  bool get isValid => anchors.length >= 2;

  /// Validates segment indices against the anchors list.
  ///
  /// Returns true if all segment indices are valid.
  bool validateIndices() {
    for (final segment in segments) {
      if (segment.startAnchorIndex < 0 ||
          segment.startAnchorIndex >= anchors.length ||
          segment.endAnchorIndex < 0 ||
          segment.endAnchorIndex >= anchors.length) {
        return false;
      }
    }
    return true;
  }

  /// Returns a path with an additional anchor appended.
  ///
  /// Automatically creates a segment connecting the last anchor to the new one.
  Path addAnchor(AnchorPoint anchor, {SegmentType segmentType = SegmentType.line}) {
    if (anchors.isEmpty) {
      return copyWith(anchors: [anchor]);
    }

    final newSegment = Segment(
      startAnchorIndex: anchors.length - 1,
      endAnchorIndex: anchors.length,
      segmentType: segmentType,
    );

    return copyWith(
      anchors: [...anchors, anchor],
      segments: [...segments, newSegment],
    );
  }

  /// Returns a path with the anchor at the given index removed.
  ///
  /// Also removes any segments that reference the removed anchor.
  /// Updates segment indices to account for the removed anchor.
  Path removeAnchor(int index) {
    if (index < 0 || index >= anchors.length) {
      throw RangeError('Anchor index out of range: $index');
    }

    // Remove the anchor
    final newAnchors = List<AnchorPoint>.from(anchors);
    newAnchors.removeAt(index);

    // Remove segments that reference the removed anchor and update indices
    final newSegments = <Segment>[];
    for (final segment in segments) {
      // Skip segments that reference the removed anchor
      if (segment.startAnchorIndex == index ||
          segment.endAnchorIndex == index) {
        continue;
      }

      // Update indices for anchors after the removed one
      final newStartIndex = segment.startAnchorIndex > index
          ? segment.startAnchorIndex - 1
          : segment.startAnchorIndex;
      final newEndIndex = segment.endAnchorIndex > index
          ? segment.endAnchorIndex - 1
          : segment.endAnchorIndex;

      newSegments.add(segment.copyWith(
        startAnchorIndex: newStartIndex,
        endAnchorIndex: newEndIndex,
      ));
    }

    return copyWith(
      anchors: newAnchors,
      segments: newSegments,
    );
  }
}
