/// Rolling window tracker for editing activity rate measurement.
///
/// This module provides efficient event rate calculation using a
/// rolling time window to classify editing patterns.
library;

import 'dart:collection';

/// Tracks editing activity within a rolling time window.
///
/// Maintains a lightweight history of event timestamps to compute
/// events/second rates for adaptive snapshot cadence decisions.
///
/// **Performance:**
/// - O(1) amortized time for recording events
/// - O(k) time for rate calculation (where k = events in window)
/// - Minimal memory overhead (stores only timestamps)
///
/// **Thread Safety:** Not thread-safe. Caller must ensure single-threaded access.
class EditingActivityWindow {
  /// Creates an activity window.
  ///
  /// [windowDuration]: Rolling window size (default: 60 seconds)
  /// [getTime]: Optional time provider for testing (defaults to DateTime.now)
  EditingActivityWindow({
    Duration windowDuration = const Duration(seconds: 60),
    DateTime Function()? getTime,
  })  : _windowDuration = windowDuration,
        _getTime = getTime ?? (() => DateTime.now()),
        _eventTimestamps = Queue<DateTime>();

  final Duration _windowDuration;
  final DateTime Function() _getTime;
  final Queue<DateTime> _eventTimestamps;

  // Cached rate calculation
  double? _cachedRate;
  DateTime? _cacheTime;
  static const _cacheDuration = Duration(milliseconds: 100);

  /// Records an event at the current time.
  ///
  /// Automatically prunes events older than the window duration.
  void recordEvent() {
    final now = _getTime();
    _eventTimestamps.add(now);
    _pruneOldEvents(now);
    _invalidateCache();
  }

  /// Returns the current event rate (events/second).
  ///
  /// Calculates based on events within the rolling window.
  /// Returns 0.0 if window is empty.
  ///
  /// **Optimization:** Caches result for 100ms to avoid redundant calculations.
  double get eventsPerSecond {
    final now = _getTime();

    // Return cached value if still fresh
    if (_cachedRate != null &&
        _cacheTime != null &&
        now.difference(_cacheTime!) < _cacheDuration) {
      return _cachedRate!;
    }

    // Prune old events before calculating
    _pruneOldEvents(now);

    if (_eventTimestamps.isEmpty) {
      _cachedRate = 0.0;
      _cacheTime = now;
      return 0.0;
    }

    // Calculate effective window (actual time span of recorded events)
    final oldestEvent = _eventTimestamps.first;
    final effectiveWindowSeconds = now.difference(oldestEvent).inMilliseconds / 1000.0;

    // Avoid division by zero for very short windows
    if (effectiveWindowSeconds < 0.1) {
      // Less than 100ms window → treat as instantaneous burst
      _cachedRate = _eventTimestamps.length / 0.1;
      _cacheTime = now;
      return _cachedRate!;
    }

    _cachedRate = _eventTimestamps.length / effectiveWindowSeconds;
    _cacheTime = now;
    return _cachedRate!;
  }

  /// Returns the number of events in the current window.
  int get eventCount => _eventTimestamps.length;

  /// Returns the effective window duration based on actual events.
  ///
  /// This may be less than the configured window if insufficient time has passed.
  Duration get effectiveWindow {
    if (_eventTimestamps.isEmpty) return Duration.zero;
    final now = _getTime();
    return now.difference(_eventTimestamps.first);
  }

  /// Clears all recorded events.
  void reset() {
    _eventTimestamps.clear();
    _invalidateCache();
  }

  /// Removes events older than the window duration.
  void _pruneOldEvents(DateTime now) {
    final cutoff = now.subtract(_windowDuration);
    while (_eventTimestamps.isNotEmpty && _eventTimestamps.first.isBefore(cutoff)) {
      _eventTimestamps.removeFirst();
    }
  }

  /// Invalidates cached rate calculation.
  void _invalidateCache() {
    _cachedRate = null;
    _cacheTime = null;
  }

  @override
  String toString() => 'EditingActivityWindow('
      'events: $eventCount, '
      'rate: ${eventsPerSecond.toStringAsFixed(2)} events/sec, '
      'window: ${effectiveWindow.inSeconds}s)';
}
