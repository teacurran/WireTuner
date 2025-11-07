import 'package:freezed_annotation/freezed_annotation.dart';
import 'event_base.dart';

part 'selection_events.freezed.dart';
part 'selection_events.g.dart';

/// Mode for selection operations.
///
/// Determines how new selections interact with existing selection state.
enum SelectionMode {
  /// Replace existing selection with new selection.
  replace,

  /// Add to existing selection (union).
  add,

  /// Toggle selection state (add if not selected, remove if selected).
  toggle,

  /// Subtract from existing selection (difference).
  subtract,
}

/// Event representing the selection of one or more objects.
///
/// This event is dispatched when a user selects objects on the canvas
/// by clicking, marquee selection, or keyboard shortcuts.
///
/// Related: T004 (Event Model Definition), T021 (Selection and Manipulation)
@Freezed(toJson: true, fromJson: true)
class SelectObjectsEvent extends EventBase with _$SelectObjectsEvent {
  /// Creates a new object selection event.
  const factory SelectObjectsEvent({
    required String eventId,
    required int timestamp,
    required List<String> objectIds,
    @Default(SelectionMode.replace) SelectionMode mode,
  }) = _SelectObjectsEvent;

  const SelectObjectsEvent._();

  /// Creates a SelectObjectsEvent from a JSON map.
  factory SelectObjectsEvent.fromJson(Map<String, dynamic> json) =>
      _$SelectObjectsEventFromJson(json);

  @override
  String get eventType => 'SelectObjectsEvent';
}

/// Event representing the deselection of specific objects.
///
/// This event is dispatched when a user deselects specific objects
/// while maintaining other selections.
///
/// Related: T004 (Event Model Definition), T021 (Selection and Manipulation)
@Freezed(toJson: true, fromJson: true)
class DeselectObjectsEvent extends EventBase with _$DeselectObjectsEvent {
  /// Creates a new object deselection event.
  const factory DeselectObjectsEvent({
    required String eventId,
    required int timestamp,
    required List<String> objectIds,
  }) = _DeselectObjectsEvent;

  const DeselectObjectsEvent._();

  /// Creates a DeselectObjectsEvent from a JSON map.
  factory DeselectObjectsEvent.fromJson(Map<String, dynamic> json) =>
      _$DeselectObjectsEventFromJson(json);

  @override
  String get eventType => 'DeselectObjectsEvent';
}

/// Event representing the clearing of all selections.
///
/// This event is dispatched when a user clears the entire selection,
/// typically by clicking on an empty area of the canvas or pressing Escape.
///
/// Related: T004 (Event Model Definition), T021 (Selection and Manipulation)
@Freezed(toJson: true, fromJson: true)
class ClearSelectionEvent extends EventBase with _$ClearSelectionEvent {
  /// Creates a new clear selection event.
  const factory ClearSelectionEvent({
    required String eventId,
    required int timestamp,
  }) = _ClearSelectionEvent;

  const ClearSelectionEvent._();

  /// Creates a ClearSelectionEvent from a JSON map.
  factory ClearSelectionEvent.fromJson(Map<String, dynamic> json) =>
      _$ClearSelectionEventFromJson(json);

  @override
  String get eventType => 'ClearSelectionEvent';
}
