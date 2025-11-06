import 'package:freezed_annotation/freezed_annotation.dart';
import 'event_base.dart';

part 'path_events.freezed.dart';
part 'path_events.g.dart';

/// Event representing the creation of a new path.
///
/// This event is dispatched when a user starts creating a path with the pen tool.
/// It includes the initial anchor point and optional style properties.
@Freezed(toJson: true, fromJson: true)
class CreatePathEvent extends EventBase with _$CreatePathEvent {
  /// Creates a new path creation event.
  const factory CreatePathEvent({
    required String eventId,
    required int timestamp,
    required String pathId,
    required Point startAnchor,
    String? fillColor,
    String? strokeColor,
    double? strokeWidth,
    double? opacity,
  }) = _CreatePathEvent;

  const CreatePathEvent._();

  /// Creates a CreatePathEvent from a JSON map.
  factory CreatePathEvent.fromJson(Map<String, dynamic> json) =>
      _$CreatePathEventFromJson(json);

  @override
  String get eventType => 'CreatePathEvent';
}

/// Event representing the addition of an anchor point to an existing path.
///
/// This event is dispatched when a user adds a new point to a path being drawn.
/// It includes the anchor position, type, and optional Bezier control handles.
@Freezed(toJson: true, fromJson: true)
class AddAnchorEvent extends EventBase with _$AddAnchorEvent {
  /// Creates a new anchor addition event.
  const factory AddAnchorEvent({
    required String eventId,
    required int timestamp,
    required String pathId,
    required Point position,
    @Default(AnchorType.line) AnchorType anchorType,
    Point? handleIn,
    Point? handleOut,
  }) = _AddAnchorEvent;

  const AddAnchorEvent._();

  /// Creates an AddAnchorEvent from a JSON map.
  factory AddAnchorEvent.fromJson(Map<String, dynamic> json) =>
      _$AddAnchorEventFromJson(json);

  @override
  String get eventType => 'AddAnchorEvent';
}

/// Event representing the completion of a path.
///
/// This event is dispatched when a user finishes drawing a path.
/// It marks the path as complete and optionally closes it.
@Freezed(toJson: true, fromJson: true)
class FinishPathEvent extends EventBase with _$FinishPathEvent {
  /// Creates a new path finish event.
  const factory FinishPathEvent({
    required String eventId,
    required int timestamp,
    required String pathId,
    @Default(false) bool closed,
  }) = _FinishPathEvent;

  const FinishPathEvent._();

  /// Creates a FinishPathEvent from a JSON map.
  factory FinishPathEvent.fromJson(Map<String, dynamic> json) =>
      _$FinishPathEventFromJson(json);

  @override
  String get eventType => 'FinishPathEvent';
}

/// Event representing a modification to an existing anchor point.
///
/// This event is dispatched when a user modifies an anchor's position,
/// control handles, or type (line/bezier conversion).
@Freezed(toJson: true, fromJson: true)
class ModifyAnchorEvent extends EventBase with _$ModifyAnchorEvent {
  /// Creates a new anchor modification event.
  const factory ModifyAnchorEvent({
    required String eventId,
    required int timestamp,
    required String pathId,
    required int anchorIndex,
    Point? position,
    Point? handleIn,
    Point? handleOut,
    AnchorType? anchorType,
  }) = _ModifyAnchorEvent;

  const ModifyAnchorEvent._();

  /// Creates a ModifyAnchorEvent from a JSON map.
  factory ModifyAnchorEvent.fromJson(Map<String, dynamic> json) =>
      _$ModifyAnchorEventFromJson(json);

  @override
  String get eventType => 'ModifyAnchorEvent';
}
