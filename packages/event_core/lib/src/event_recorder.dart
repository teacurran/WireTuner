/// Event recorder with 50ms sampling for continuous user actions.
///
/// This module will provide the core event recording functionality,
/// including sampling of high-frequency interactions like dragging.
library;

/// TODO: Implement event recorder with sampling logic.
///
/// Future implementation will include:
/// - Event capture and validation
/// - 50ms sampling for continuous actions (drag, pan, zoom)
/// - Event batching and commit strategies
/// - Integration with event store persistence
class EventRecorder {
  /// Creates an instance of the event recorder.
  const EventRecorder();

  /// Returns the sampling interval in milliseconds.
  int get samplingIntervalMs => 50;
}
