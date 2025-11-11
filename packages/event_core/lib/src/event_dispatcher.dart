/// Event dispatcher for routing events to handlers asynchronously.
///
/// This module defines the interface for dispatching events to registered
/// handlers in the next frame to avoid blocking the UI thread.
library;

/// Callback type for event handlers.
///
/// Handlers receive the event type and event data, returning a Future
/// that completes when the event has been processed.
typedef EventHandler = Future<void> Function(
  String eventType,
  Map<String, dynamic> eventData,
);

/// Interface for asynchronous event dispatching.
///
/// Implements the event-driven pattern where events are processed in the
/// next frame to maintain UI responsiveness. Events are dispatched in
/// sequence-number order to ensure deterministic replay.
abstract class EventDispatcher {
  /// Registers a handler for a specific event type.
  ///
  /// Multiple handlers can be registered for the same event type.
  /// Handlers are invoked in registration order.
  ///
  /// Example:
  /// ```dart
  /// dispatcher.registerHandler('MoveObjectEvent', (type, data) async {
  ///   final objectId = data['objectId'];
  ///   final delta = Point.fromJson(data['delta']);
  ///   // Update object position...
  /// });
  /// ```
  void registerHandler(String eventType, EventHandler handler);

  /// Unregisters a specific handler for an event type.
  ///
  /// No-op if the handler was not previously registered.
  void unregisterHandler(String eventType, EventHandler handler);

  /// Dispatches an event to all registered handlers asynchronously.
  ///
  /// Events are queued and processed in the next frame (or microtask)
  /// to avoid blocking the current UI operation.
  ///
  /// Returns a Future that completes when all handlers have processed the event.
  ///
  /// Throws if any handler throws during processing.
  Future<void> dispatch(String eventType, Map<String, dynamic> eventData);

  /// Clears all registered handlers.
  ///
  /// Used for cleanup or when resetting the event system.
  void clearHandlers();
}
