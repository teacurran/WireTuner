/// Stub implementation of EventSampler for testing and development.
library;

import '../event_sampler.dart';

/// Stub implementation of [EventSampler] that logs method calls.
///
/// This implementation uses simple time-based sampling for high-frequency events.
///
/// TODO(I1.T5): Replace with production implementation that handles
/// event buffering, state management, and configurable sampling strategies.
class StubEventSampler implements EventSampler {
  /// Creates a stub event sampler with the specified interval.
  ///
  /// [samplingIntervalMs]: Sampling interval in milliseconds (default: 50ms)
  StubEventSampler({int samplingIntervalMs = 50})
      : _samplingIntervalMs = samplingIntervalMs;

  final int _samplingIntervalMs;
  int _lastSampleTimestamp = 0;

  @override
  int get samplingIntervalMs => _samplingIntervalMs;

  @override
  bool shouldSample(String eventType, int timestamp) {
    // High-frequency events that should be sampled
    const highFrequencyEvents = {
      'MoveObjectEvent',
      'ModifyAnchorEvent',
      'PanEvent',
      'ZoomEvent',
    };

    // Discrete events are always recorded
    if (!highFrequencyEvents.contains(eventType)) {
      return true;
    }

    // Sample high-frequency events at the specified interval
    if (timestamp - _lastSampleTimestamp >= _samplingIntervalMs) {
      _lastSampleTimestamp = timestamp;
      return true;
    }

    return false;
  }

  @override
  void flush() {
    // Reset timestamp to allow next event to be recorded
    _lastSampleTimestamp = 0;
    print('[StubEventSampler] flush called');
  }

  @override
  void reset() {
    _lastSampleTimestamp = 0;
    print('[StubEventSampler] reset called');
  }
}
