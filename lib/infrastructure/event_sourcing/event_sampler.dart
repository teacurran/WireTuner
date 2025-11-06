import '../../domain/events/event_base.dart';

/// Samples high-frequency events to reduce event log volume.
///
/// The [EventSampler] throttles rapid input events by buffering them
/// and emitting at fixed intervals (default 50ms). This reduces database
/// load during drag operations while maintaining smooth playback.
///
/// Example usage:
/// ```dart
/// final sampler = EventSampler(
///   onEventEmit: (event) => eventRecorder.record(event),
/// );
///
/// // During drag operation:
/// onMouseMove((position) {
///   sampler.recordEvent(MoveObjectEvent(...));
/// });
///
/// // On mouse up:
/// sampler.flush(); // Emit final position
/// ```
///
/// **Algorithm:**
/// 1. User generates rapid input events (e.g., dragging mouse)
/// 2. EventSampler buffers these events
/// 3. If >= 50ms elapsed since last emission, emit immediately
/// 4. If < 50ms elapsed, buffer event (replacing previous buffered event)
/// 5. On flush(), emit final buffered event immediately
///
/// **Performance:**
/// - A 2-second drag without sampling: 200+ events
/// - A 2-second drag with sampling: ~40 events
/// - Reduction: 5x fewer events
class EventSampler {
  /// Creates an [EventSampler] with the specified emission callback.
  ///
  /// The [onEventEmit] callback is invoked whenever an event should be
  /// emitted (either due to elapsed time or explicit flush).
  ///
  /// The optional [samplingInterval] defaults to 50ms. Set to [Duration.zero]
  /// to disable sampling and emit all events immediately.
  EventSampler({
    required this.onEventEmit,
    Duration samplingInterval = const Duration(milliseconds: 50),
  }) : _samplingInterval = samplingInterval;

  /// Callback invoked when an event should be emitted.
  final void Function(EventBase event) onEventEmit;

  /// The sampling interval (default 50ms).
  ///
  /// Events arriving faster than this interval will be buffered.
  /// Setting this to [Duration.zero] disables sampling (all events emitted).
  Duration _samplingInterval;

  /// The most recent buffered event awaiting emission.
  ///
  /// Only one event is buffered at a time. New events replace the old one.
  EventBase? _bufferedEvent;

  /// The timestamp when the last event was emitted.
  ///
  /// Used to determine if enough time has elapsed for the next emission.
  DateTime? _lastEmittedTime;

  /// Records an event, either emitting it immediately or buffering it.
  ///
  /// If the [samplingInterval] has elapsed since the last emission, the event
  /// is emitted immediately. Otherwise, it's buffered and will be emitted
  /// either on the next [recordEvent] call that exceeds the interval, or
  /// when [flush] is called.
  ///
  /// **Behavior:**
  /// - Events >= [samplingInterval] apart: emitted immediately
  /// - Events < [samplingInterval] apart: buffered (last one kept)
  /// - Sampling disabled ([samplingInterval] = 0): all events emitted
  void recordEvent(EventBase event) {
    // If sampling is disabled (zero interval), emit immediately
    if (_samplingInterval == Duration.zero) {
      _emitEvent(event);
      return;
    }

    // Check if enough time has elapsed since last emission
    final now = DateTime.now();
    final shouldEmit = _lastEmittedTime == null ||
        now.difference(_lastEmittedTime!) >= _samplingInterval;

    if (shouldEmit) {
      // Emit immediately and update timestamp
      _emitEvent(event);
    } else {
      // Buffer event (replaces any previously buffered event)
      _bufferedEvent = event;
    }
  }

  /// Emits any buffered event immediately.
  ///
  /// This method is typically called at the end of a high-frequency event
  /// sequence (e.g., when the user releases the mouse after dragging) to
  /// ensure the final event position is captured.
  ///
  /// If no event is buffered, this method does nothing (idempotent).
  ///
  /// **Example:**
  /// ```dart
  /// onMouseUp(() {
  ///   sampler.flush(); // Emit final drag position
  /// });
  /// ```
  void flush() {
    if (_bufferedEvent != null) {
      _emitEvent(_bufferedEvent!);
      _bufferedEvent = null;
    }
  }

  /// Configures the sampling interval.
  ///
  /// This can be used to adjust the throttling rate for different scenarios:
  /// - 50ms (default): Standard drag operations (~20 events/sec)
  /// - 100ms: Slower sampling for less critical updates (~10 events/sec)
  /// - 0ms: Disable sampling (emit all events immediately)
  ///
  /// **Note:** Changing the interval does not affect already-buffered events.
  void setSamplingInterval(Duration interval) {
    _samplingInterval = interval;
  }

  /// Gets the current sampling interval.
  Duration get samplingInterval => _samplingInterval;

  /// Internal method to emit an event and update state.
  void _emitEvent(EventBase event) {
    try {
      onEventEmit(event);
      _lastEmittedTime = DateTime.now();
    } catch (e) {
      // Note: In production, this should use a proper logger (e.g., flutter logger)
      // For now, we rethrow to maintain test visibility
      rethrow;
    }
  }
}
