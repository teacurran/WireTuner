/// Metrics collection abstraction for event system instrumentation.
///
/// This module defines the interface for collecting performance and usage
/// metrics from the event recorder, replayer, and snapshot manager.
library;

/// Interface for metrics collection and instrumentation.
///
/// Provides hooks for tracking event system performance, event volumes,
/// and operational metrics. Concrete implementations added in Task I1.T8.
abstract class MetricsSink {
  /// Records an event recording operation.
  ///
  /// [eventType]: Type of event recorded (e.g., 'MoveObjectEvent')
  /// [sampled]: Whether the event was sampled or recorded immediately
  /// [durationMs]: Time taken to persist the event (optional)
  ///
  /// TODO(I1.T8): Implement metrics aggregation and export.
  void recordEvent({
    required String eventType,
    required bool sampled,
    int? durationMs,
  });

  /// Records an event replay operation.
  ///
  /// [eventCount]: Number of events replayed
  /// [fromSequence]: Starting sequence number
  /// [toSequence]: Ending sequence number
  /// [durationMs]: Total replay duration in milliseconds
  ///
  /// TODO(I1.T8): Implement replay performance tracking.
  void recordReplay({
    required int eventCount,
    required int fromSequence,
    required int toSequence,
    required int durationMs,
  });

  /// Records a snapshot creation operation.
  ///
  /// [sequenceNumber]: Sequence number of the snapshot
  /// [snapshotSizeBytes]: Size of the serialized snapshot
  /// [durationMs]: Time taken to create and persist the snapshot
  ///
  /// TODO(I1.T8): Implement snapshot metrics collection.
  void recordSnapshot({
    required int sequenceNumber,
    required int snapshotSizeBytes,
    required int durationMs,
  });

  /// Records a snapshot load operation.
  ///
  /// [sequenceNumber]: Sequence number of the loaded snapshot
  /// [durationMs]: Time taken to load and deserialize the snapshot
  ///
  /// TODO(I1.T8): Track snapshot load performance.
  void recordSnapshotLoad({
    required int sequenceNumber,
    required int durationMs,
  });

  /// Flushes buffered metrics to the backend.
  ///
  /// Called periodically or on application shutdown to ensure metrics
  /// are not lost.
  ///
  /// TODO(I1.T8): Implement metric export/upload logic.
  Future<void> flush();
}
