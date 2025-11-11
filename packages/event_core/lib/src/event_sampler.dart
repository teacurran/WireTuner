/// Event sampling abstraction for high-frequency input throttling.
///
/// This module defines the interface for sampling high-frequency events
/// (e.g., mouse drag, pan, zoom) according to the 50ms sampling rule.
library;

/// Interface for sampling high-frequency user input events.
///
/// Implements the 50ms sampling strategy described in Decision 5 to reduce
/// event volume while maintaining smooth replay quality.
///
/// During a 2-second drag operation, sampling reduces ~200+ raw mouse events
/// down to ~40 sampled events, balancing storage efficiency with replay fidelity.
abstract class EventSampler {
  /// Returns the sampling interval in milliseconds.
  ///
  /// Default: 50ms (20 events/second for smooth replay)
  int get samplingIntervalMs;

  /// Determines whether an event should be recorded based on sampling rules.
  ///
  /// High-frequency events (drag, pan) are throttled to [samplingIntervalMs].
  /// Discrete events (click, key press) are always recorded.
  ///
  /// Returns true if the event should be recorded.
  bool shouldSample(String eventType, int timestamp);

  /// Flushes any buffered sampled events immediately.
  ///
  /// Called when sampling should terminate (e.g., mouse button release,
  /// touch end) to ensure the final event position is captured.
  void flush();

  /// Resets the sampler state.
  ///
  /// Called when starting a new sampling session or clearing state.
  void reset();
}
