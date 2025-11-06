import 'package:logger/logger.dart';
import '../../domain/events/event_base.dart';
import '../persistence/event_store.dart';
import 'event_sampler.dart';

/// Records events to the event sourcing system with sampling and persistence.
///
/// The [EventRecorder] is responsible for:
/// - Accepting events from tools and user interactions
/// - Throttling high-frequency events via [EventSampler] (50ms sampling)
/// - Persisting sampled events to SQLite via [EventStore]
/// - Supporting pause/resume for event replay scenarios
/// - Providing flush capability for immediate persistence
///
/// **Usage Example:**
/// ```dart
/// final recorder = EventRecorder(
///   eventStore: eventStore,
///   documentId: 'doc-123',
/// );
///
/// // Record user actions
/// recorder.recordEvent(CreatePathEvent(...));
/// recorder.recordEvent(MoveObjectEvent(...));
///
/// // Flush on tool deactivation
/// recorder.flush();
///
/// // Pause during event replay to avoid circular recording
/// recorder.pause();
/// try {
///   await replayer.replay(events);
/// } finally {
///   recorder.resume();
/// }
/// ```
///
/// **Key Features:**
/// - **Sampling**: Uses EventSampler to throttle rapid events (e.g., drag operations)
/// - **Auto-sequencing**: EventStore automatically assigns sequence numbers
/// - **Pause/Resume**: Prevents recording during event replay or undo operations
/// - **Fire-and-forget**: Recording is synchronous, persistence is async (no blocking)
class EventRecorder {
  final EventStore _eventStore;
  final String _documentId;
  late final EventSampler _sampler;
  bool _isPaused = false;
  final Logger _logger = Logger();

  /// Creates an [EventRecorder] for the specified document.
  ///
  /// The [eventStore] is used for persisting events to SQLite.
  /// The [documentId] identifies which document these events belong to.
  ///
  /// **Note**: Each document should have its own EventRecorder instance.
  EventRecorder({
    required EventStore eventStore,
    required String documentId,
  })  : _eventStore = eventStore,
        _documentId = documentId {
    // Initialize sampler with persistence callback
    _sampler = EventSampler(
      onEventEmit: _persistEvent,
    );
    _logger.i('EventRecorder initialized for document: $_documentId');
  }

  /// Records an event to the event sourcing system.
  ///
  /// The event is passed through the EventSampler for throttling, then
  /// persisted asynchronously to the EventStore. If recording is paused
  /// (e.g., during event replay), the event is silently ignored.
  ///
  /// **Behavior:**
  /// - If paused: event is ignored
  /// - If not paused: event is sampled (throttled) and persisted
  ///
  /// **Performance:**
  /// - This method is synchronous and returns immediately
  /// - Persistence happens asynchronously in the background
  /// - Tools are not blocked by database writes
  ///
  /// Example:
  /// ```dart
  /// recorder.recordEvent(CreatePathEvent(
  ///   eventId: uuid.v4(),
  ///   timestamp: DateTime.now().millisecondsSinceEpoch,
  ///   pathId: 'path-1',
  ///   startAnchor: Point(x: 100, y: 200),
  /// ));
  /// ```
  void recordEvent(EventBase event) {
    if (_isPaused) {
      _logger.d('Recording paused, ignoring event: ${event.eventType}');
      return;
    }

    _logger.d('Recording event: ${event.eventType}');
    _sampler.recordEvent(event);
  }

  /// Pauses event recording.
  ///
  /// While paused, calls to [recordEvent] are ignored. This is used during
  /// event replay or undo operations to prevent circular event creation.
  ///
  /// **Example:**
  /// ```dart
  /// // During event replay
  /// recorder.pause();
  /// try {
  ///   for (final event in events) {
  ///     await dispatcher.apply(event); // Updates state without recording
  ///   }
  /// } finally {
  ///   recorder.resume(); // Always resume, even on error
  /// }
  /// ```
  ///
  /// **Note:** Pausing does not clear buffered events. Call [flush] before
  /// pausing if you need to ensure all events are persisted.
  void pause() {
    _isPaused = true;
    _logger.i('Event recording paused');
  }

  /// Resumes event recording after a [pause].
  ///
  /// After resuming, calls to [recordEvent] will be processed normally.
  ///
  /// **Note:** This does NOT flush buffered events. Any events buffered
  /// before the pause remain buffered.
  void resume() {
    _isPaused = false;
    _logger.i('Event recording resumed');
  }

  /// Flushes any buffered events immediately.
  ///
  /// This triggers the EventSampler to emit its buffered event (if any)
  /// immediately, bypassing the normal 50ms throttle. Typically called:
  /// - When a tool is deactivated (e.g., user releases mouse)
  /// - Before saving the document
  /// - On application shutdown
  ///
  /// **Behavior:**
  /// - If paused: does nothing (logs warning)
  /// - If not paused: delegates to EventSampler.flush()
  ///
  /// Example:
  /// ```dart
  /// // On mouse up after drag operation
  /// onMouseUp(() {
  ///   recorder.flush(); // Persist final drag position
  /// });
  /// ```
  void flush() {
    if (_isPaused) {
      _logger.w('Cannot flush while recording is paused');
      return;
    }

    _logger.d('Flushing buffered events');
    _sampler.flush();
  }

  /// Returns true if event recording is currently paused.
  ///
  /// Useful for debugging or displaying UI state (e.g., "Replay Mode" indicator).
  bool get isPaused => _isPaused;

  /// Internal callback invoked by EventSampler when an event should be persisted.
  ///
  /// This method:
  /// 1. Calls EventStore.insertEvent() to persist the event to SQLite
  /// 2. Logs success (event_id and type)
  /// 3. Handles errors gracefully (logs error, doesn't crash)
  ///
  /// **Error Handling:**
  /// - Database errors are logged but do not throw
  /// - This prevents tool operations from crashing due to persistence failures
  /// - In production, consider showing a user notification for critical failures
  ///
  /// **Concurrency:**
  /// - This is an async callback, but EventSampler doesn't await it (fire-and-forget)
  /// - Multiple events may be persisting concurrently
  /// - EventStore handles sequence numbering correctly via database transactions
  void _persistEvent(EventBase event) async {
    try {
      final eventId = await _eventStore.insertEvent(_documentId, event);
      _logger.d(
        'Event persisted: id=$eventId, type=${event.eventType}, doc=$_documentId',
      );
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to persist event: ${event.eventType}',
        error: e,
        stackTrace: stackTrace,
      );
      // TODO: In production, consider showing a user notification
      // for critical persistence failures (e.g., disk full, database corruption)
    }
  }
}
