import 'package:freezed_annotation/freezed_annotation.dart';
import 'event_base.dart';

part 'group_events.freezed.dart';
part 'group_events.g.dart';

/// Event representing the start of a grouped operation.
///
/// This event marks the beginning of a multi-step operation that should be
/// treated as a single undoable unit. All events between StartGroupEvent and
/// the corresponding EndGroupEvent will be undone/redone together.
///
/// Example: Creating a path with the pen tool (multiple anchor clicks)
/// should be grouped so undo removes the entire path.
///
/// Related: T004 (Event Model Definition), undo/redo system
@Freezed(toJson: true, fromJson: true)
class StartGroupEvent extends EventBase with _$StartGroupEvent {
  /// Creates a new group start event.
  const factory StartGroupEvent({
    required String eventId,
    required int timestamp,
    required String groupId,
    String? description,
  }) = _StartGroupEvent;

  const StartGroupEvent._();

  /// Creates a StartGroupEvent from a JSON map.
  factory StartGroupEvent.fromJson(Map<String, dynamic> json) =>
      _$StartGroupEventFromJson(json);

  @override
  String get eventType => 'StartGroupEvent';
}

/// Event representing the end of a grouped operation.
///
/// This event marks the completion of a multi-step operation started with
/// StartGroupEvent. The groupId must match the corresponding StartGroupEvent.
///
/// Related: T004 (Event Model Definition), undo/redo system
@Freezed(toJson: true, fromJson: true)
class EndGroupEvent extends EventBase with _$EndGroupEvent {
  /// Creates a new group end event.
  const factory EndGroupEvent({
    required String eventId,
    required int timestamp,
    required String groupId,
  }) = _EndGroupEvent;

  const EndGroupEvent._();

  /// Creates an EndGroupEvent from a JSON map.
  factory EndGroupEvent.fromJson(Map<String, dynamic> json) =>
      _$EndGroupEventFromJson(json);

  @override
  String get eventType => 'EndGroupEvent';
}
