import '../../domain/events/event_base.dart';

/// Signature for event handler functions.
///
/// Event handlers are pure functions that take the current state and an event,
/// and return the new state after applying the event.
///
/// **Key Properties:**
/// - **Pure function**: No side effects, deterministic output
/// - **Immutability**: Returns NEW state, never mutates input state
/// - **Type safety**: Will be `Document Function(Document, EventBase)` in I3
///
/// **Usage Example:**
/// ```dart
/// EventHandler createPathHandler = (state, event) {
///   final createEvent = event as CreatePathEvent;
///   // Return new state with path added (immutable update)
///   return state.copyWith(
///     paths: {...state.paths, createEvent.pathId: Path.empty()},
///   );
/// };
/// ```
///
/// **Note:** Currently uses `dynamic` for state type since the Document model
/// doesn't exist yet (will be implemented in Iteration 3). This will be changed
/// to strongly-typed `Document` once available.
typedef EventHandler = dynamic Function(dynamic state, EventBase event);

/// Registry that maps event types to their handler functions.
///
/// The [EventHandlerRegistry] maintains a lookup table of event type strings
/// to handler functions. This enables the [EventDispatcher] to route events
/// to the correct handler for state application.
///
/// **Usage Example:**
/// ```dart
/// final registry = EventHandlerRegistry();
///
/// // Register handlers for different event types
/// registry.registerHandler('CreatePathEvent', (state, event) {
///   // Apply CreatePathEvent to state
///   return newState;
/// });
///
/// registry.registerHandler('AddAnchorEvent', (state, event) {
///   // Apply AddAnchorEvent to state
///   return newState;
/// });
///
/// // Look up handler
/// final handler = registry.getHandler('CreatePathEvent');
/// if (handler != null) {
///   final newState = handler(currentState, event);
/// }
/// ```
///
/// **Key Design Decisions:**
/// - **String keys**: Uses `event.eventType` (e.g., "CreatePathEvent") as key
/// - **Runtime registration**: Handlers can be registered dynamically
/// - **Overwrite semantics**: Registering same event type twice overwrites
/// - **Null-safe**: getHandler() returns null for unregistered types
///
/// **Thread Safety**: This registry is NOT thread-safe. All registration
/// should occur on the main isolate before concurrent access.
class EventHandlerRegistry {
  /// Internal map storing event type to handler function mappings.
  final Map<String, EventHandler> _handlers = {};

  /// Registers a handler function for the specified event type.
  ///
  /// The [eventType] parameter must match the `eventType` getter value from
  /// the corresponding event class. For example, "CreatePathEvent" for the
  /// [CreatePathEvent] class.
  ///
  /// **Important:** If a handler already exists for this event type, it will
  /// be overwritten with the new handler.
  ///
  /// **Usage Example:**
  /// ```dart
  /// registry.registerHandler('CreatePathEvent', (state, event) {
  ///   final createEvent = event as CreatePathEvent;
  ///   return applyCreatePath(state, createEvent);
  /// });
  /// ```
  ///
  /// **Parameters:**
  /// - [eventType]: The event type string (must match event.eventType exactly)
  /// - [handler]: The pure function to handle this event type
  void registerHandler(String eventType, EventHandler handler) {
    _handlers[eventType] = handler;
  }

  /// Retrieves the handler function for the specified event type.
  ///
  /// Returns the registered handler function if one exists, or null if no
  /// handler is registered for the given event type.
  ///
  /// **Usage Example:**
  /// ```dart
  /// final handler = registry.getHandler('CreatePathEvent');
  /// if (handler != null) {
  ///   final newState = handler(state, event);
  /// } else {
  ///   throw Exception('No handler for CreatePathEvent');
  /// }
  /// ```
  ///
  /// **Parameters:**
  /// - [eventType]: The event type string to look up
  ///
  /// **Returns:** The handler function, or null if not registered
  EventHandler? getHandler(String eventType) {
    return _handlers[eventType];
  }

  /// Checks whether a handler is registered for the specified event type.
  ///
  /// This is a convenience method that's equivalent to checking if
  /// `getHandler(eventType) != null`, but more explicit.
  ///
  /// **Usage Example:**
  /// ```dart
  /// if (registry.hasHandler('CreatePathEvent')) {
  ///   // Safe to dispatch this event type
  ///   dispatcher.dispatch(state, event);
  /// } else {
  ///   // Handle missing handler case
  /// }
  /// ```
  ///
  /// **Parameters:**
  /// - [eventType]: The event type string to check
  ///
  /// **Returns:** true if a handler is registered, false otherwise
  bool hasHandler(String eventType) {
    return _handlers.containsKey(eventType);
  }

  /// Returns the number of registered handlers.
  ///
  /// Useful for debugging and testing to verify that handlers are registered.
  ///
  /// **Usage Example:**
  /// ```dart
  /// print('Registered ${registry.handlerCount} handlers');
  /// ```
  int get handlerCount => _handlers.length;

  /// Removes the handler for the specified event type.
  ///
  /// Returns true if a handler was removed, false if no handler was registered.
  ///
  /// **Usage Example:**
  /// ```dart
  /// registry.removeHandler('CreatePathEvent');
  /// ```
  ///
  /// **Parameters:**
  /// - [eventType]: The event type string to remove
  ///
  /// **Returns:** true if handler was removed, false otherwise
  bool removeHandler(String eventType) {
    return _handlers.remove(eventType) != null;
  }

  /// Clears all registered handlers.
  ///
  /// Useful for testing or resetting the registry to a clean state.
  ///
  /// **Usage Example:**
  /// ```dart
  /// registry.clear();
  /// assert(registry.handlerCount == 0);
  /// ```
  void clear() {
    _handlers.clear();
  }
}
