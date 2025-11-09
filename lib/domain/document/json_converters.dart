import 'package:json_annotation/json_annotation.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/models/anchor_point.dart' as ap;
import 'package:wiretuner/domain/models/path.dart';
import 'package:wiretuner/domain/models/segment.dart';
import 'package:wiretuner/domain/models/shape.dart';

/// JSON converter for Point objects.
///
/// Converts Point to/from JSON representation.
class PointConverter implements JsonConverter<Point, Map<String, dynamic>> {
  const PointConverter();

  @override
  Point fromJson(Map<String, dynamic> json) => Point(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
      );

  @override
  Map<String, dynamic> toJson(Point object) => {
        'x': object.x,
        'y': object.y,
      };
}

/// JSON converter for Path objects.
///
/// Converts Path to/from JSON representation for snapshot serialization.
class PathConverter implements JsonConverter<Path, Map<String, dynamic>> {
  const PathConverter();

  @override
  Path fromJson(Map<String, dynamic> json) {
    final anchorsList = json['anchors'] as List;
    final segmentsList = json['segments'] as List;

    final anchors = anchorsList
        .map((a) => _anchorPointFromJson(a as Map<String, dynamic>))
        .toList();

    final segments = segmentsList
        .map((s) => _segmentFromJson(s as Map<String, dynamic>))
        .toList();

    return Path(
      anchors: anchors,
      segments: segments,
      closed: json['closed'] as bool? ?? false,
    );
  }

  @override
  Map<String, dynamic> toJson(Path object) => {
        'anchors': object.anchors.map(_anchorPointToJson).toList(),
        'segments': object.segments.map(_segmentToJson).toList(),
        'closed': object.closed,
      };

  ap.AnchorPoint _anchorPointFromJson(Map<String, dynamic> json) =>
      ap.AnchorPoint(
        position: _pointFromJson(json['position'] as Map<String, dynamic>),
        handleIn: json['handleIn'] != null
            ? _pointFromJson(json['handleIn'] as Map<String, dynamic>)
            : null,
        handleOut: json['handleOut'] != null
            ? _pointFromJson(json['handleOut'] as Map<String, dynamic>)
            : null,
        anchorType: ap.AnchorType.values
            .byName(json['anchorType'] as String? ?? 'corner'),
      );

  Map<String, dynamic> _anchorPointToJson(ap.AnchorPoint anchor) => {
        'position': _pointToJson(anchor.position),
        if (anchor.handleIn != null) 'handleIn': _pointToJson(anchor.handleIn!),
        if (anchor.handleOut != null)
          'handleOut': _pointToJson(anchor.handleOut!),
        'anchorType': anchor.anchorType.name,
      };

  Segment _segmentFromJson(Map<String, dynamic> json) => Segment(
        startAnchorIndex: json['startAnchorIndex'] as int,
        endAnchorIndex: json['endAnchorIndex'] as int,
        segmentType:
            SegmentType.values.byName(json['segmentType'] as String? ?? 'line'),
      );

  Map<String, dynamic> _segmentToJson(Segment segment) => {
        'startAnchorIndex': segment.startAnchorIndex,
        'endAnchorIndex': segment.endAnchorIndex,
        'segmentType': segment.segmentType.name,
      };

  Point _pointFromJson(Map<String, dynamic> json) => Point(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
      );

  Map<String, dynamic> _pointToJson(Point point) => {
        'x': point.x,
        'y': point.y,
      };
}

/// JSON converter for Shape objects.
///
/// Converts Shape to/from JSON representation for snapshot serialization.
/// Note: Shape already has JSON support via Freezed, but we need this
/// converter for consistency with the VectorObject union type.
class ShapeConverter implements JsonConverter<Shape, Map<String, dynamic>> {
  const ShapeConverter();

  @override
  Shape fromJson(Map<String, dynamic> json) => Shape.fromJson(json);

  @override
  Map<String, dynamic> toJson(Shape object) => object.toJson();
}
