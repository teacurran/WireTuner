/// Instrumentation for snapshot queue and backlog monitoring.
///
/// This module provides visibility into snapshot creation queue depth,
/// processing status, and activity classification for diagnostics.
library;

import 'snapshot_tuning_config.dart';

/// Real-time status of the snapshot creation queue and backlog.
///
/// Used for instrumentation, logging, and performance monitoring to
/// detect when snapshot creation is falling behind event production.
class SnapshotBacklogStatus {
  /// Creates a snapshot backlog status snapshot.
  const SnapshotBacklogStatus({
    required this.pendingSnapshots,
    required this.lastSnapshotSequence,
    required this.currentSequence,
    required this.eventsPerSecond,
    required this.activity,
    required this.effectiveInterval,
  });

  /// Number of snapshots queued or in-progress.
  ///
  /// Incremented when snapshot creation is triggered.
  /// Decremented when snapshot persistence completes.
  ///
  /// **Alert Threshold:** > 3 indicates falling behind.
  final int pendingSnapshots;

  /// Sequence number of the most recently completed snapshot.
  final int lastSnapshotSequence;

  /// Current event sequence number.
  final int currentSequence;

  /// Current editing rate (events/second) from activity window.
  final double eventsPerSecond;

  /// Current activity classification (burst/normal/idle).
  final EditingActivity activity;

  /// Effective snapshot interval after adaptive adjustment.
  final int effectiveInterval;

  /// Returns the number of events since the last snapshot.
  int get eventsSinceSnapshot => currentSequence - lastSnapshotSequence;

  /// Returns true if the queue depth indicates falling behind.
  bool get isFallingBehind => pendingSnapshots > 3;

  /// Returns true if a snapshot should be created soon.
  ///
  /// Defined as within 80% of the effective interval.
  bool get isNearThreshold => eventsSinceSnapshot >= (effectiveInterval * 0.8);

  /// Returns a diagnostic summary string for logging.
  String toLogString() {
    final status = isFallingBehind ? 'FALLING_BEHIND' : 'OK';
    return '[$status] Snapshot queue: $pendingSnapshots pending, '
        '${eventsSinceSnapshot}/${effectiveInterval} events since last, '
        'activity: ${activity.label} (${eventsPerSecond.toStringAsFixed(1)} events/sec)';
  }

  @override
  String toString() => 'SnapshotBacklogStatus('
      'pending: $pendingSnapshots, '
      'lastSeq: $lastSnapshotSequence, '
      'currentSeq: $currentSequence, '
      'rate: ${eventsPerSecond.toStringAsFixed(2)} events/sec, '
      'activity: ${activity.label}, '
      'effectiveInterval: $effectiveInterval)';
}
