import 'package:logger/logger.dart';
import '../../domain/events/event_base.dart';
import 'event_handler_registry.dart';

/// Exception thrown when an event is dispatched without a registered handler.
///
/// This exception indicates a configuration error where an event type is being
/// used in the system but no handler has been registered to process it.
///
/// **Usage Example:**
/// ```dart
/// try {
///   dispatcher.dispatch(state, unknownEvent);
/// } on UnhandledEventException catch (e) {
///   print('Missing handler for: ${e.eventType}');
///   print('Message: ${e.message}');
/// }
/// ```
class UnhandledEventException implements Exception {

  /// Creates an exception for an unhandled event type.
  ///
  /// **Parameters:**
  /// - [message]: Human-readable error description
  /// - [eventType]: The event type that caused the error
  UnhandledEventException(this.message, {required this.eventType});
  /// Descriptive error message explaining the issue.
  final String message;

  /// The event type string that has no registered handler.
  final String eventType;

  @override
  String toString() =>
      'UnhandledEventException: $message (eventType: $eventType)';
}

/// Dispatches events to their registered handlers for state application.
///
/// The [EventDispatcher] is the central routing mechanism for all events in
/// the event sourcing system. It uses the [EventHandlerRegistry] to look up
/// the appropriate handler for each event type and invokes it with the current
/// state.
///
/// **Usage Example:**
/// ```dart
/// // Set up registry with handlers
/// final registry = EventHandlerRegistry();
/// registry.registerHandler('CreatePathEvent', (state, event) {
///   return applyCreatePath(state, event as CreatePathEvent);
/// });
///
/// // Create dispatcher
/// final dispatcher = EventDispatcher(registry);
///
/// // Dispatch events
/// var state = initialState;
/// state = dispatcher.dispatch(state, createPathEvent);
/// state = dispatcher.dispatch(state, addAnchorEvent);
/// ```
///
/// **Key Features:**
/// - **Stateless**: No mutable state, just routes events to handlers
/// - **Pure function**: Returns new state, doesn't mutate input
/// - **Fail-fast**: Throws exception for unhandled events
/// - **Observable**: Logs all dispatch operations for debugging
///
/// **Event Flow:**
/// 1. Event received via dispatch(state, event)
/// 2. Handler looked up in registry using event.eventType
/// 3. If no handler found, throw UnhandledEventException
/// 4. If handler found, invoke handler(state, event)
/// 5. Return new state from handler
///
/// **Design Rationale:**
/// - **Why stateless?** Makes dispatcher thread-safe and easy to test
/// - **Why throw on unhandled events?** Fail-fast approach catches config errors early
/// - **Why use registry injection?** Enables testing with mock registries
/// - **Why log everything?** Essential for debugging event replay issues
///
/// **Thread Safety**: This dispatcher is designed for single-threaded use.
/// All dispatch calls should occur on the main isolate. If concurrent event
/// processing is needed in the future, consider using isolates with immutable
/// state passing.
///
/// **Future Enhancement**: The dispatch method could be made async by changing
/// the return type to `Future<dynamic>` if handlers need async operations
/// (e.g., loading external resources during state reconstruction).
class EventDispatcher {

  /// Creates an [EventDispatcher] with the specified handler registry.
  ///
  /// **Parameters:**
  /// - [registry]: The registry containing all event handler mappings
  ///
  /// **Usage Example:**
  /// ```dart
  /// final registry = EventHandlerRegistry();
  /// // Register handlers...
  /// final dispatcher = EventDispatcher(registry);
  /// ```
  EventDispatcher(this._registry);
  /// The registry containing event type to handler mappings.
  final EventHandlerRegistry _registry;

  /// Logger for debugging and observability.
  final Logger _logger = Logger();

  /// Dispatches an event to its registered handler and returns new state.
  ///
  /// This method looks up the handler for the event's type in the registry,
  /// invokes it with the current state and event, and returns the new state
  /// produced by the handler.
  ///
  /// **Process:**
  /// 1. Log the incoming event type
  /// 2. Look up handler in registry using `event.eventType`
  /// 3. If no handler found, throw [UnhandledEventException]
  /// 4. Invoke handler with current state and event
  /// 5. Log successful completion
  /// 6. Return new state
  ///
  /// **Important:** This method does NOT catch exceptions thrown by handlers.
  /// Handler exceptions indicate bugs and should fail loudly to surface issues
  /// during development and testing.
  ///
  /// **Usage Example:**
  /// ```dart
  /// var state = initialDocumentState;
  ///
  /// // Apply sequence of events
  /// state = dispatcher.dispatch(state, createPathEvent);
  /// state = dispatcher.dispatch(state, addAnchorEvent);
  /// state = dispatcher.dispatch(state, finishPathEvent);
  ///
  /// // state now reflects all three events applied
  /// ```
  ///
  /// **Parameters:**
  /// - [state]: The current state (Document instance in I3, dynamic for now)
  /// - [event]: The event to apply to the state
  ///
  /// **Returns:** The new state after applying the event
  ///
  /// **Throws:**
  /// - [UnhandledEventException] if no handler is registered for event type
  /// - Any exception thrown by the handler (intentionally not caught)
  dynamic dispatch(dynamic state, EventBase event) {
    _logger.d('Dispatching event: ${event.eventType} (id: ${event.eventId})');

    final handler = _registry.getHandler(event.eventType);

    if (handler == null) {
      final errorMessage =
          'No handler registered for event type: ${event.eventType}';
      _logger.e(errorMessage);
      throw UnhandledEventException(
        errorMessage,
        eventType: event.eventType,
      );
    }

    // Invoke handler - let any handler exceptions propagate
    // (they indicate bugs that should fail loudly)
    final newState = handler(state, event);

    _logger.d('Event ${event.eventType} handled successfully');

    return newState;
  }

  /// Dispatches multiple events in sequence, applying each to the result of the previous.
  ///
  /// This is a convenience method for replaying a sequence of events to
  /// reconstruct state. It's equivalent to calling dispatch() in a loop,
  /// but more expressive and easier to read.
  ///
  /// **Usage Example:**
  /// ```dart
  /// final events = [createPathEvent, addAnchorEvent, finishPathEvent];
  /// final finalState = dispatcher.dispatchAll(initialState, events);
  /// ```
  ///
  /// **Parameters:**
  /// - [initialState]: The starting state
  /// - [events]: The sequence of events to apply
  ///
  /// **Returns:** The final state after applying all events
  ///
  /// **Throws:**
  /// - [UnhandledEventException] if any event has no registered handler
  /// - Any exception thrown by any handler
  dynamic dispatchAll(dynamic initialState, List<EventBase> events) {
    _logger.d('Dispatching ${events.length} events in sequence');

    var state = initialState;
    for (final event in events) {
      state = dispatch(state, event);
    }

    _logger.d('Successfully dispatched all ${events.length} events');
    return state;
  }
}
