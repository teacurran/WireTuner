/// Stub implementation of EventDispatcher for testing and development.
library;

import '../event_dispatcher.dart';

/// Stub implementation of [EventDispatcher] that logs method calls.
///
/// Handlers are stored and invoked asynchronously in the next microtask.
///
/// TODO(I1.T5): Replace with production implementation that handles
/// proper async scheduling, error handling, and handler prioritization.
class StubEventDispatcher implements EventDispatcher {
  /// Creates a stub event dispatcher.
  StubEventDispatcher();

  final Map<String, List<EventHandler>> _handlers = {};

  @override
  void registerHandler(String eventType, EventHandler handler) {
    _handlers.putIfAbsent(eventType, () => []).add(handler);
    print('[StubEventDispatcher] registered handler for $eventType');
  }

  @override
  void unregisterHandler(String eventType, EventHandler handler) {
    _handlers[eventType]?.remove(handler);
    print('[StubEventDispatcher] unregistered handler for $eventType');
  }

  @override
  Future<void> dispatch(String eventType, Map<String, dynamic> eventData) async {
    print('[StubEventDispatcher] dispatching $eventType');

    final handlers = _handlers[eventType];
    if (handlers == null || handlers.isEmpty) {
      return;
    }

    // Invoke handlers in the next microtask to avoid blocking
    await Future.microtask(() async {
      for (final handler in handlers) {
        await handler(eventType, eventData);
      }
    });
  }

  @override
  void clearHandlers() {
    _handlers.clear();
    print('[StubEventDispatcher] cleared all handlers');
  }
}
