import 'package:freezed_annotation/freezed_annotation.dart';
import 'event_base.dart';

part 'style_events.freezed.dart';
part 'style_events.g.dart';

/// Event representing a modification to an object's visual style.
///
/// This event is dispatched when a user changes the visual properties
/// of an object such as fill color, stroke color, width, or opacity.
@Freezed(toJson: true, fromJson: true)
class ModifyStyleEvent extends EventBase with _$ModifyStyleEvent {
  /// Creates a new style modification event.
  const factory ModifyStyleEvent({
    required String eventId,
    required int timestamp,
    required String objectId,
    String? fillColor,
    String? strokeColor,
    double? strokeWidth,
    double? opacity,
  }) = _ModifyStyleEvent;

  const ModifyStyleEvent._();

  /// Creates a ModifyStyleEvent from a JSON map.
  factory ModifyStyleEvent.fromJson(Map<String, dynamic> json) =>
      _$ModifyStyleEventFromJson(json);

  @override
  String get eventType => 'ModifyStyleEvent';
}
