import 'package:freezed_annotation/freezed_annotation.dart';
import 'event_base.dart';

part 'object_events.freezed.dart';
part 'object_events.g.dart';

/// Event representing the movement of one or more objects.
///
/// This event is dispatched when a user drags or moves objects on the canvas.
/// It applies a delta transformation to the specified objects.
@Freezed(toJson: true, fromJson: true)
class MoveObjectEvent extends EventBase with _$MoveObjectEvent {
  /// Creates a new object movement event.
  const factory MoveObjectEvent({
    required String eventId,
    required int timestamp,
    required List<String> objectIds,
    required Point delta,
  }) = _MoveObjectEvent;

  const MoveObjectEvent._();

  /// Creates a MoveObjectEvent from a JSON map.
  factory MoveObjectEvent.fromJson(Map<String, dynamic> json) =>
      _$MoveObjectEventFromJson(json);

  @override
  String get eventType => 'MoveObjectEvent';
}

/// Event representing the creation of a parametric shape.
///
/// This event is dispatched when a user creates a shape using one of the
/// shape tools (rectangle, ellipse, star, polygon).
@Freezed(toJson: true, fromJson: true)
class CreateShapeEvent extends EventBase with _$CreateShapeEvent {
  /// Creates a new shape creation event.
  const factory CreateShapeEvent({
    required String eventId,
    required int timestamp,
    required String shapeId,
    required ShapeType shapeType,
    required Map<String, double> parameters,
    String? fillColor,
    String? strokeColor,
    double? strokeWidth,
    double? opacity,
  }) = _CreateShapeEvent;

  const CreateShapeEvent._();

  /// Creates a CreateShapeEvent from a JSON map.
  factory CreateShapeEvent.fromJson(Map<String, dynamic> json) =>
      _$CreateShapeEventFromJson(json);

  @override
  String get eventType => 'CreateShapeEvent';
}
