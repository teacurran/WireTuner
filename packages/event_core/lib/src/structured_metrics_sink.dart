/// Production implementation of MetricsSink with structured logging.
///
/// This module provides a production-ready metrics collection implementation
/// that aggregates performance counters and emits structured logs.
library;

import 'package:logger/logger.dart';

import 'metrics_sink.dart';
import 'diagnostics_config.dart';

/// Production implementation of [MetricsSink] that emits structured logs.
///
/// Aggregates metrics in memory and logs them through the Logger interface.
/// Metrics are emitted at appropriate log levels based on thresholds:
/// - Event write > 50ms: WARN
/// - Replay duration > 500ms: INFO (always logged)
/// - Frame drops: WARN
///
/// Example:
/// ```dart
/// final logger = Logger(level: Level.info);
/// final config = EventCoreDiagnosticsConfig.release();
/// final sink = StructuredMetricsSink(logger: logger, config: config);
///
/// sink.recordEvent(
///   eventType: 'MoveObjectEvent',
///   sampled: true,
///   durationMs: 8,
/// );
/// ```
class StructuredMetricsSink implements MetricsSink {
  /// Creates a structured metrics sink.
  ///
  /// [logger]: Logger instance for emitting metrics
  /// [config]: Diagnostics configuration controlling metric behavior
  StructuredMetricsSink({
    required Logger logger,
    required EventCoreDiagnosticsConfig config,
  })  : _logger = logger,
        _config = config;

  final Logger _logger;
  final EventCoreDiagnosticsConfig _config;

  // Aggregated metrics for periodic reporting
  int _eventCount = 0;
  int _sampledEventCount = 0;
  int _totalEventWriteTimeMs = 0;
  int _replayCount = 0;
  int _totalReplayTimeMs = 0;
  int _snapshotCount = 0;
  int _snapshotLoadCount = 0;

  @override
  void recordEvent({
    required String eventType,
    required bool sampled,
    int? durationMs,
  }) {
    if (!_config.enableMetrics) return;

    _eventCount++;
    if (sampled) _sampledEventCount++;
    if (durationMs != null) _totalEventWriteTimeMs += durationMs;

    // Log slow event writes (> 50ms = disk slow)
    if (durationMs != null && durationMs > 50) {
      _logger.w(
        'Slow event write: $eventType took ${durationMs}ms (sampled: $sampled)',
      );
    } else if (_config.enableDetailedLogging) {
      _logger.d(
        'Event recorded: $eventType (sampled: $sampled, duration: ${durationMs}ms)',
      );
    }
  }

  @override
  void recordReplay({
    required int eventCount,
    required int fromSequence,
    required int toSequence,
    required int durationMs,
  }) {
    if (!_config.enableMetrics) return;

    _replayCount++;
    _totalReplayTimeMs += durationMs;

    // Always log replay operations at INFO level (important lifecycle event)
    _logger.i(
      'Replay completed: $eventCount events [$fromSequence → $toSequence] in ${durationMs}ms',
    );

    // Warn if replay exceeds target (500ms for typical documents)
    if (durationMs > 500) {
      _logger.w(
        'Slow replay: ${durationMs}ms for $eventCount events (> 500ms target)',
      );
    }
  }

  @override
  void recordSnapshot({
    required int sequenceNumber,
    required int snapshotSizeBytes,
    required int durationMs,
  }) {
    if (!_config.enableMetrics) return;

    _snapshotCount++;

    final sizeMB = snapshotSizeBytes / (1024 * 1024);

    if (_config.enableDetailedLogging) {
      _logger.d(
        'Snapshot created: seq=$sequenceNumber, size=${sizeMB.toStringAsFixed(2)}MB, duration=${durationMs}ms',
      );
    }

    // Warn on large snapshots (> 100MB = potential memory issue)
    if (snapshotSizeBytes > 100 * 1024 * 1024) {
      _logger.w(
        'Large snapshot: ${sizeMB.toStringAsFixed(2)}MB at seq=$sequenceNumber',
      );
    }
  }

  @override
  void recordSnapshotLoad({
    required int sequenceNumber,
    required int durationMs,
  }) {
    if (!_config.enableMetrics) return;

    _snapshotLoadCount++;

    // Log snapshot loads at INFO level (important for document open performance)
    _logger.i(
      'Snapshot loaded: seq=$sequenceNumber in ${durationMs}ms',
    );

    // Warn if snapshot load is slow (> 1000ms)
    if (durationMs > 1000) {
      _logger.w(
        'Slow snapshot load: ${durationMs}ms for seq=$sequenceNumber',
      );
    }
  }

  @override
  Future<void> flush() async {
    if (!_config.enableMetrics) return;

    // Emit aggregated statistics
    if (_eventCount > 0) {
      final avgWriteTime = _totalEventWriteTimeMs / _eventCount;
      _logger.i(
        'Event metrics: total=$_eventCount, sampled=$_sampledEventCount, '
        'avgWriteTime=${avgWriteTime.toStringAsFixed(2)}ms',
      );
    }

    if (_replayCount > 0) {
      final avgReplayTime = _totalReplayTimeMs / _replayCount;
      _logger.i(
        'Replay metrics: count=$_replayCount, avgDuration=${avgReplayTime.toStringAsFixed(2)}ms',
      );
    }

    if (_snapshotCount > 0) {
      _logger.i(
        'Snapshot metrics: created=$_snapshotCount, loaded=$_snapshotLoadCount',
      );
    }

    // Reset counters after flush
    _eventCount = 0;
    _sampledEventCount = 0;
    _totalEventWriteTimeMs = 0;
    _replayCount = 0;
    _totalReplayTimeMs = 0;
    _snapshotCount = 0;
    _snapshotLoadCount = 0;
  }

  /// Returns current aggregated metrics as a map.
  ///
  /// Useful for debugging or exporting metrics to external systems.
  Map<String, dynamic> getMetrics() => {
        'eventCount': _eventCount,
        'sampledEventCount': _sampledEventCount,
        'totalEventWriteTimeMs': _totalEventWriteTimeMs,
        'avgEventWriteTimeMs':
            _eventCount > 0 ? _totalEventWriteTimeMs / _eventCount : 0.0,
        'replayCount': _replayCount,
        'totalReplayTimeMs': _totalReplayTimeMs,
        'avgReplayTimeMs':
            _replayCount > 0 ? _totalReplayTimeMs / _replayCount : 0.0,
        'snapshotCount': _snapshotCount,
        'snapshotLoadCount': _snapshotLoadCount,
      };
}
