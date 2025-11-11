import 'package:freezed_annotation/freezed_annotation.dart';
import 'event_base.dart';

part 'viewport_events.freezed.dart';
part 'viewport_events.g.dart';

/// Event representing a viewport pan (translation) operation.
///
/// This event is dispatched when a user pans the viewport by dragging
/// the canvas with the hand tool or two-finger trackpad gesture.
/// The delta represents the change in viewport position.
///
/// Related: T004 (Event Model Definition), T019 (Viewport Controls)
@Freezed(toJson: true, fromJson: true)
class ViewportPanEvent extends EventBase with _$ViewportPanEvent {
  /// Creates a new viewport pan event.
  const factory ViewportPanEvent({
    required String eventId,
    required int timestamp,
    required Point delta,
  }) = _ViewportPanEvent;

  const ViewportPanEvent._();

  /// Creates a ViewportPanEvent from a JSON map.
  factory ViewportPanEvent.fromJson(Map<String, dynamic> json) =>
      _$ViewportPanEventFromJson(json);

  @override
  String get eventType => 'ViewportPanEvent';
}

/// Event representing a viewport zoom operation.
///
/// This event is dispatched when a user zooms the viewport using
/// scroll wheel, pinch gesture, or zoom tool. The zoom factor is
/// multiplicative (1.0 = no change, 2.0 = double size, 0.5 = half size).
/// The focal point determines the zoom center in canvas coordinates.
///
/// Related: T004 (Event Model Definition), T019 (Viewport Controls)
@Freezed(toJson: true, fromJson: true)
class ViewportZoomEvent extends EventBase with _$ViewportZoomEvent {
  /// Creates a new viewport zoom event.
  const factory ViewportZoomEvent({
    required String eventId,
    required int timestamp,
    required double factor,
    required Point focalPoint,
  }) = _ViewportZoomEvent;

  const ViewportZoomEvent._();

  /// Creates a ViewportZoomEvent from a JSON map.
  factory ViewportZoomEvent.fromJson(Map<String, dynamic> json) =>
      _$ViewportZoomEventFromJson(json);

  @override
  String get eventType => 'ViewportZoomEvent';
}

/// Event representing a viewport reset to default view.
///
/// This event is dispatched when a user resets the viewport to the
/// default view (100% zoom, centered on origin), typically via a
/// keyboard shortcut or menu command.
///
/// Related: T004 (Event Model Definition), T019 (Viewport Controls)
@Freezed(toJson: true, fromJson: true)
class ViewportResetEvent extends EventBase with _$ViewportResetEvent {
  /// Creates a new viewport reset event.
  const factory ViewportResetEvent({
    required String eventId,
    required int timestamp,
  }) = _ViewportResetEvent;

  const ViewportResetEvent._();

  /// Creates a ViewportResetEvent from a JSON map.
  factory ViewportResetEvent.fromJson(Map<String, dynamic> json) =>
      _$ViewportResetEventFromJson(json);

  @override
  String get eventType => 'ViewportResetEvent';
}
