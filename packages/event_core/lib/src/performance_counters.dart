/// Performance measurement utilities for event system instrumentation.
///
/// This module provides lightweight timing and counting helpers for tracking
/// event system performance metrics without adding significant overhead.
library;

/// Helper class for measuring operation durations and maintaining counters.
///
/// Provides a simple API for wrapping timed operations and tracking counts.
/// Designed to be low-overhead (< 1% of measured operation time).
///
/// Example:
/// ```dart
/// final counters = PerformanceCounters();
/// final duration = await counters.measure('event_write', () async {
///   await storeGateway.persistEvent(event);
/// });
/// logger.i('Event persisted in ${duration}ms');
/// ```
class PerformanceCounters {
  /// Creates a new performance counters instance.
  PerformanceCounters();

  /// Measures the duration of a synchronous operation.
  ///
  /// [name]: Optional identifier for the operation (for logging/debugging)
  /// [operation]: The operation to measure
  ///
  /// Returns the elapsed time in milliseconds.
  ///
  /// Example:
  /// ```dart
  /// final durationMs = counters.measureSync('validation', () {
  ///   validateEvent(event);
  /// });
  /// ```
  int measureSync<T>(String name, T Function() operation) {
    final stopwatch = Stopwatch()..start();
    try {
      operation();
      return stopwatch.elapsedMilliseconds;
    } finally {
      stopwatch.stop();
    }
  }

  /// Measures the duration of an asynchronous operation.
  ///
  /// [name]: Optional identifier for the operation (for logging/debugging)
  /// [operation]: The async operation to measure
  ///
  /// Returns a record containing the result and elapsed time in milliseconds.
  ///
  /// Example:
  /// ```dart
  /// final (result, durationMs) = await counters.measure('event_write', () async {
  ///   return await storeGateway.persistEvent(event);
  /// });
  /// metricsSink.recordEvent(durationMs: durationMs);
  /// ```
  Future<(T, int)> measure<T>(
      String name, Future<T> Function() operation) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await operation();
      return (result, stopwatch.elapsedMilliseconds);
    } finally {
      stopwatch.stop();
    }
  }

  /// Times an async operation and returns only the duration.
  ///
  /// Convenience method for when you don't need the operation result,
  /// only the timing information.
  ///
  /// [name]: Optional identifier for the operation
  /// [operation]: The async operation to time
  ///
  /// Returns the elapsed time in milliseconds.
  ///
  /// Example:
  /// ```dart
  /// final durationMs = await counters.time('replay', () async {
  ///   await replayer.replay(fromSequence: 0, toSequence: 100);
  /// });
  /// ```
  Future<int> time(String name, Future<void> Function() operation) async {
    final stopwatch = Stopwatch()..start();
    try {
      await operation();
      return stopwatch.elapsedMilliseconds;
    } finally {
      stopwatch.stop();
    }
  }

  /// Creates a manual stopwatch for multi-stage timing.
  ///
  /// Use this when you need to measure time across multiple async boundaries
  /// or accumulate time from multiple operations.
  ///
  /// Returns a [TimedOperation] that can be stopped manually.
  ///
  /// Example:
  /// ```dart
  /// final timer = counters.startTimer('batch_write');
  /// for (final event in events) {
  ///   await storeGateway.persistEvent(event);
  /// }
  /// final totalMs = timer.stop();
  /// logger.i('Batch write took ${totalMs}ms');
  /// ```
  TimedOperation startTimer(String name) => TimedOperation(name);
}

/// Represents a timed operation that can be stopped manually.
///
/// Use this for measuring operations across multiple async boundaries.
class TimedOperation {
  /// Creates a timed operation with the given name.
  TimedOperation(this.name) : _stopwatch = Stopwatch()..start();

  /// The name/identifier of this operation.
  final String name;

  final Stopwatch _stopwatch;
  bool _stopped = false;

  /// Stops the timer and returns the elapsed milliseconds.
  ///
  /// Subsequent calls return the same elapsed time (timer is not restarted).
  int stop() {
    if (!_stopped) {
      _stopwatch.stop();
      _stopped = true;
    }
    return _stopwatch.elapsedMilliseconds;
  }

  /// Returns the elapsed time without stopping the timer.
  int get elapsedMs => _stopwatch.elapsedMilliseconds;

  /// Returns whether the timer has been stopped.
  bool get isStopped => _stopped;
}
