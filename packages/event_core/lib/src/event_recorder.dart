/// Event recorder with 50ms sampling for continuous user actions.
///
/// This module provides the core event recording functionality,
/// including sampling of high-frequency interactions like dragging.
library;

import 'event_sampler.dart';
import 'event_dispatcher.dart';
import 'event_store_gateway.dart';
import 'metrics_sink.dart';

/// Interface for recording user interaction events.
///
/// Implements the event-driven pattern with automatic sampling of high-frequency
/// events (e.g., drag, pan, zoom) at 50ms intervals per Decision 5.
///
/// All events are persisted to SQLite immediately and dispatched asynchronously
/// to registered handlers to update document state without blocking the UI thread.
///
/// **Threading**: All methods must be called from the UI isolate.
abstract class EventRecorder {
  /// Records a user interaction event with automatic sampling.
  ///
  /// High-frequency events (drag, pan) are sampled at [samplingIntervalMs]
  /// intervals. Discrete events (click, key press) are recorded immediately.
  ///
  /// Events are persisted to SQLite and then dispatched asynchronously to
  /// registered handlers via the [EventDispatcher].
  ///
  /// [event]: Event data as a JSON-serializable map
  ///
  /// Returns a Future that completes when the event is persisted.
  ///
  /// TODO(I1.T5): Implement event validation and sequence numbering.
  Future<void> recordEvent(Map<String, dynamic> event);

  /// Flushes any buffered sampled events immediately.
  ///
  /// Called when a continuous action terminates (e.g., mouse button release)
  /// to ensure the final event position is captured.
  ///
  /// TODO(I1.T5): Implement flush logic for sampled event buffer.
  void flush();

  /// Pauses event recording.
  ///
  /// Used during event replay to prevent recorded events from being
  /// re-recorded, which would create an infinite loop.
  ///
  /// TODO(I1.T5): Implement pause/resume state management.
  void pause();

  /// Resumes event recording after being paused.
  ///
  /// TODO(I1.T5): Implement pause/resume state management.
  void resume();

  /// Returns whether event recording is currently paused.
  bool get isPaused;

  /// Returns the sampling interval in milliseconds (50ms).
  int get samplingIntervalMs;
}

/// Default stub implementation of [EventRecorder].
///
/// Logs method calls and enforces dependency injection of sampler,
/// dispatcher, persistence gateway, and metrics sink.
///
/// TODO(I1.T5): Replace with full implementation that handles event
/// validation, sequence numbering, sampling, persistence, and dispatch.
class DefaultEventRecorder implements EventRecorder {
  /// Creates a default event recorder with injected dependencies.
  ///
  /// All dependencies are required to enforce proper dependency injection
  /// for future implementations.
  ///
  /// [sampler]: Sampling strategy for high-frequency events
  /// [dispatcher]: Asynchronous event dispatcher
  /// [storeGateway]: SQLite persistence gateway
  /// [metricsSink]: Metrics collection sink
  DefaultEventRecorder({
    required EventSampler sampler,
    required EventDispatcher dispatcher,
    required EventStoreGateway storeGateway,
    required MetricsSink metricsSink,
  })  : _sampler = sampler,
        _dispatcher = dispatcher,
        _storeGateway = storeGateway,
        _metricsSink = metricsSink;

  final EventSampler _sampler;
  final EventDispatcher _dispatcher;
  final EventStoreGateway _storeGateway;
  final MetricsSink _metricsSink;

  bool _isPaused = false;

  @override
  Future<void> recordEvent(Map<String, dynamic> event) async {
    if (_isPaused) return;

    // TODO(I1.T5): Implement event recording logic
    // 1. Validate event structure (eventId, timestamp, eventType)
    // 2. Assign sequence number
    // 3. Check if event should be sampled (_sampler.shouldSample)
    // 4. Persist to store (_storeGateway.persistEvent)
    // 5. Dispatch to handlers (_dispatcher.dispatch)
    // 6. Record metrics (_metricsSink.recordEvent)

    print('[EventRecorder] recordEvent called: ${event['eventType']}');
  }

  @override
  void flush() {
    // TODO(I1.T5): Flush sampled event buffer
    _sampler.flush();
    print('[EventRecorder] flush called');
  }

  @override
  void pause() {
    _isPaused = true;
    print('[EventRecorder] pause called');
  }

  @override
  void resume() {
    _isPaused = false;
    print('[EventRecorder] resume called');
  }

  @override
  bool get isPaused => _isPaused;

  @override
  int get samplingIntervalMs => _sampler.samplingIntervalMs;
}
