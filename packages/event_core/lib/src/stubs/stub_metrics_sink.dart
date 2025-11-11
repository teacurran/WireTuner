/// Stub implementation of MetricsSink for testing and development.
library;

import '../metrics_sink.dart';

/// Stub implementation of [MetricsSink] that logs metrics to console.
///
/// This implementation simply prints metrics for development visibility.
/// Production implementation will aggregate and export to a metrics backend.
///
/// TODO(I1.T8): Replace with production metrics implementation that
/// aggregates data and exports to monitoring systems.
class StubMetricsSink implements MetricsSink {
  /// Creates a stub metrics sink.
  StubMetricsSink();

  @override
  void recordEvent({
    required String eventType,
    required bool sampled,
    int? durationMs,
  }) {
    print(
        '[StubMetricsSink] recordEvent: $eventType (sampled: $sampled, duration: ${durationMs}ms)');
  }

  @override
  void recordReplay({
    required int eventCount,
    required int fromSequence,
    required int toSequence,
    required int durationMs,
  }) {
    print(
        '[StubMetricsSink] recordReplay: $eventCount events from $fromSequence to $toSequence (${durationMs}ms)');
  }

  @override
  void recordSnapshot({
    required int sequenceNumber,
    required int snapshotSizeBytes,
    required int durationMs,
  }) {
    print(
        '[StubMetricsSink] recordSnapshot: seq=$sequenceNumber, size=${snapshotSizeBytes}B (${durationMs}ms)');
  }

  @override
  void recordSnapshotLoad({
    required int sequenceNumber,
    required int durationMs,
  }) {
    print(
        '[StubMetricsSink] recordSnapshotLoad: seq=$sequenceNumber (${durationMs}ms)');
  }

  @override
  Future<void> flush() async {
    print('[StubMetricsSink] flush called');
  }
}
