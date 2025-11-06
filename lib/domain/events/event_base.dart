import 'package:freezed_annotation/freezed_annotation.dart';

part 'event_base.freezed.dart';
part 'event_base.g.dart';

/// Base class for all events in the event sourcing system.
///
/// This abstract class ensures that all events share common fields and behavior.
/// Event subclasses use the @freezed annotation pattern for immutability.
///
/// All events must have:
/// - [eventId]: Unique identifier for the event
/// - [timestamp]: Unix timestamp in milliseconds when event was created
/// - [eventType]: Discriminator string for polymorphic deserialization
abstract class EventBase {
  /// Creates a new event base.
  const EventBase();

  /// The unique identifier for this event.
  String get eventId;

  /// Unix timestamp in milliseconds when this event was created.
  int get timestamp;

  /// The type discriminator used for polymorphic deserialization.
  ///
  /// This should match the class name (e.g., 'CreatePathEvent').
  String get eventType;

  /// Converts this event to a JSON-serializable map.
  Map<String, dynamic> toJson();
}

/// Represents a 2D point with x and y coordinates.
///
/// Used for positions, anchors, and geometric calculations in events.
@freezed
class Point with _$Point {
  /// Creates a point at the specified coordinates.
  const factory Point({
    required double x,
    required double y,
  }) = _Point;

  /// Creates a Point from a JSON map.
  factory Point.fromJson(Map<String, dynamic> json) => _$PointFromJson(json);
}

/// Type of anchor point in a path.
enum AnchorType {
  /// Linear anchor with no curve handles.
  line,

  /// Bezier anchor with control handles for curves.
  bezier,
}

/// Type of parametric shape.
enum ShapeType {
  /// Rectangle shape.
  rectangle,

  /// Ellipse shape.
  ellipse,

  /// Star shape.
  star,

  /// Polygon shape.
  polygon,
}
