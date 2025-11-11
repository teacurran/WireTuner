/// Integration layer connecting performance monitoring to telemetry service.
///
/// This module provides helpers for wiring snapshot/replay instrumentation
/// into the telemetry pipeline with proper opt-out enforcement.
library;

import 'package:wiretuner/infrastructure/event_sourcing/snapshot_manager.dart';
import 'package:wiretuner/infrastructure/telemetry/telemetry_service.dart';

/// Creates a telemetry-aware snapshot callback for SnapshotManager.
///
/// This callback adapter forwards snapshot metrics to TelemetryService
/// while respecting opt-out state.
///
/// Usage:
/// ```dart
/// final snapshotManager = SnapshotManager(
///   snapshotStore: snapshotStore,
///   onSnapshotCreated: createSnapshotTelemetryCallback(telemetryService),
/// );
/// ```
SnapshotTelemetryCallback createSnapshotTelemetryCallback(
  TelemetryService telemetryService,
) {
  return ({
    required String documentId,
    required int eventSequence,
    required int uncompressedSize,
    required int compressedSize,
    required double compressionRatio,
    required int durationMs,
  }) {
    // Forward to telemetry service (opt-out checked internally)
    telemetryService.recordSnapshotMetric(
      durationMs: durationMs,
      compressionRatio: compressionRatio,
      documentId: documentId,
    );
  };
}

/// Replay metrics tracker for event replay throughput monitoring.
///
/// Tracks event replay rate over a sliding time window and provides
/// callbacks for telemetry integration.
class ReplayMetricsTracker {
  /// Creates a replay metrics tracker.
  ///
  /// [windowDurationMs]: Time window for rate calculation (default: 1000ms)
  /// [onMetricUpdated]: Callback invoked when metrics are updated
  ReplayMetricsTracker({
    this.windowDurationMs = 1000,
    this.onMetricUpdated,
  });

  /// Time window for rate calculation in milliseconds.
  final int windowDurationMs;

  /// Callback invoked when metrics are updated.
  final void Function(double eventsPerSec, int queueDepth)? onMetricUpdated;

  final List<DateTime> _eventTimestamps = [];
  int _queueDepth = 0;

  /// Records a replay event.
  ///
  /// Call this for each event replayed to track throughput.
  void recordEvent() {
    final now = DateTime.now();
    _eventTimestamps.add(now);

    // Remove timestamps outside window
    final windowStart = now.subtract(Duration(milliseconds: windowDurationMs));
    _eventTimestamps.removeWhere((timestamp) => timestamp.isBefore(windowStart));

    // Calculate rate and invoke callback
    _updateMetrics();
  }

  /// Records multiple replay events at once.
  ///
  /// Use this for batch replay operations.
  void recordEvents(int count) {
    for (var i = 0; i < count; i++) {
      recordEvent();
    }
  }

  /// Updates the replay queue depth.
  ///
  /// Call this when the replay queue depth changes to track backlog.
  void updateQueueDepth(int depth) {
    _queueDepth = depth;
    _updateMetrics();
  }

  /// Calculates and emits current metrics.
  void _updateMetrics() {
    final eventsPerSec = calculateEventsPerSecond();
    onMetricUpdated?.call(eventsPerSec, _queueDepth);
  }

  /// Calculates current events per second rate.
  double calculateEventsPerSecond() {
    if (_eventTimestamps.isEmpty) return 0.0;

    // Events in window / window duration in seconds
    final windowSeconds = windowDurationMs / 1000.0;
    return _eventTimestamps.length / windowSeconds;
  }

  /// Gets the current queue depth.
  int get queueDepth => _queueDepth;

  /// Resets all metrics.
  void reset() {
    _eventTimestamps.clear();
    _queueDepth = 0;
  }
}

/// Creates a replay metrics tracker integrated with telemetry service.
///
/// This helper creates a tracker that automatically forwards metrics
/// to the telemetry service while respecting opt-out state.
///
/// Usage:
/// ```dart
/// final replayTracker = createReplayMetricsTracker(telemetryService);
///
/// // In replay loop:
/// replayTracker.recordEvent();
/// ```
ReplayMetricsTracker createReplayMetricsTracker(
  TelemetryService telemetryService, {
  int windowDurationMs = 1000,
}) {
  return ReplayMetricsTracker(
    windowDurationMs: windowDurationMs,
    onMetricUpdated: (eventsPerSec, queueDepth) {
      // Forward to telemetry service (opt-out checked internally)
      telemetryService.recordReplayMetric(
        eventsPerSec: eventsPerSec,
        queueDepth: queueDepth,
      );
    },
  );
}
