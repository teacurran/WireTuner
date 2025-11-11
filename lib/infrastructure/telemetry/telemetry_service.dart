import 'package:flutter/foundation.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_state.dart';
import 'telemetry_config.dart';
import 'structured_log_schema.dart';
import 'otlp_exporter.dart';

/// Service for collecting and logging telemetry data.
///
/// TelemetryService provides centralized telemetry collection for performance
/// monitoring and debugging. It can be configured to log different types of
/// metrics and supports conditional logging based on debug flags.
///
/// ## Features
///
/// - Viewport interaction metrics (FPS, pan delta, zoom)
/// - Conditional logging based on debug mode
/// - Performance threshold warnings
/// - Aggregated metrics over time
///
/// ## Usage
///
/// ```dart
/// final telemetry = TelemetryService();
///
/// // In ViewportBinding
/// ViewportBinding(
///   controller: controller,
///   onTelemetry: telemetry.recordViewportMetric,
///   debugMode: true,
///   child: canvas,
/// )
///
/// // Query metrics
/// final avgFps = telemetry.averageFps;
/// telemetry.printSummary();
/// ```
class TelemetryService with TelemetryGuard {
  /// Creates a telemetry service.
  ///
  /// [config] provides centralized telemetry configuration with opt-out enforcement.
  /// [exporter] handles OTLP export to remote collector (optional).
  /// [verbose] controls whether each metric is logged (default: false).
  /// [fpsWarningThreshold] sets the FPS threshold for warnings (default: 55).
  /// [maxMetricsHistory] limits the metrics history size (default: 1000).
  TelemetryService({
    TelemetryConfig? config,
    OTLPExporter? exporter,
    this.verbose = false,
    this.fpsWarningThreshold = 55.0,
    this.maxMetricsHistory = 1000,
  })  : _config = config ?? TelemetryConfig.disabled(),
        _exporter = exporter,
        _logBuilder = StructuredLogBuilder(
          component: 'TelemetryService',
        ) {
    // Listen for config changes
    _config.addListener(_onConfigChanged);
  }

  final TelemetryConfig _config;
  final OTLPExporter? _exporter;
  final StructuredLogBuilder _logBuilder;

  @override
  TelemetryConfig get telemetryConfig => _config;

  /// Whether telemetry logging is enabled.
  ///
  /// Delegates to TelemetryConfig for centralized opt-out enforcement.
  bool get enabled => _config.enabled;

  /// Whether to print verbose logs for each metric.
  final bool verbose;

  /// Minimum FPS threshold for performance warnings.
  final double fpsWarningThreshold;

  /// List of recorded viewport metrics.
  final List<ViewportTelemetry> _viewportMetrics = [];

  /// Maximum number of metrics to keep in memory.
  final int maxMetricsHistory;

  /// Handles telemetry config changes (opt-out).
  void _onConfigChanged() {
    if (!_config.enabled) {
      // Clear buffers immediately on opt-out
      clear();

      if (kDebugMode) {
        debugPrint('[TelemetryService] Telemetry disabled, metrics cleared');
      }
    }
  }

  /// Records a viewport telemetry metric.
  ///
  /// This is the main entry point for viewport metrics. Connect this
  /// to ViewportBinding.onTelemetry to collect metrics.
  void recordViewportMetric(ViewportTelemetry metric) {
    if (!enabled) return;

    // Add to history
    _viewportMetrics.add(metric);

    // Trim history if too large
    if (_viewportMetrics.length > maxMetricsHistory) {
      _viewportMetrics.removeAt(0);
    }

    // Log if verbose (structured logging)
    if (verbose) {
      final log = _logBuilder.debug(
        message: 'Viewport metric recorded: ${metric.eventType}',
        eventType: 'ViewportMetric',
        latencyMs: metric.fps > 0 ? (1000 / metric.fps).round() : null,
        metadata: {
          'fps': metric.fps,
          'eventType': metric.eventType,
          'panDelta': metric.panDelta?.toString(),
          'zoomLevel': metric.zoomLevel,
        },
      );
      debugPrint(log.toJsonString());
    }

    // Warn on poor performance (structured logging)
    if (metric.fps > 0 && metric.fps < fpsWarningThreshold) {
      final log = _logBuilder.warn(
        message:
            'Performance warning: FPS ${metric.fps.toStringAsFixed(1)} below threshold $fpsWarningThreshold',
        eventType: 'PerformanceWarning',
        metadata: {
          'fps': metric.fps,
          'threshold': fpsWarningThreshold,
          MetricsCatalog.renderFps: metric.fps,
        },
      );
      debugPrint(log.toJsonString());
    }

    // Export to OTLP if configured and sampling allows
    if (_exporter != null && shouldSample()) {
      _exportMetric(metric);
    }
  }

  /// Exports a viewport metric via OTLP.
  void _exportMetric(ViewportTelemetry metric) {
    try {
      final sample = PerformanceSamplePayload.fromViewportTelemetry(
        fps: metric.fps,
        frameTimeMs: metric.fps > 0 ? 1000 / metric.fps : 0,
        platform: defaultTargetPlatform.name,
        telemetryOptIn: _config.enabled,
      );

      _exporter?.recordPerformanceSample(sample);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[TelemetryService] Failed to export metric: $e');
      }
    }
  }

  /// Gets the average FPS over the last N metrics.
  ///
  /// [count] limits how many recent metrics to average (default: 100).
  /// Returns 0.0 if no FPS data is available.
  double getAverageFps({int count = 100}) {
    final recentMetrics = _viewportMetrics
        .where((m) => m.fps > 0)
        .toList()
        .reversed
        .take(count)
        .toList();

    if (recentMetrics.isEmpty) return 0.0;

    final sum = recentMetrics.fold<double>(0.0, (sum, m) => sum + m.fps);
    return sum / recentMetrics.length;
  }

  /// Gets the minimum FPS recorded.
  double get minFps {
    final fpsMetrics = _viewportMetrics.where((m) => m.fps > 0);
    if (fpsMetrics.isEmpty) return 0.0;
    return fpsMetrics.map((m) => m.fps).reduce((a, b) => a < b ? a : b);
  }

  /// Gets the maximum FPS recorded.
  double get maxFps {
    final fpsMetrics = _viewportMetrics.where((m) => m.fps > 0);
    if (fpsMetrics.isEmpty) return 0.0;
    return fpsMetrics.map((m) => m.fps).reduce((a, b) => a > b ? a : b);
  }

  /// Gets the average FPS over all recorded metrics.
  double get averageFps => getAverageFps(count: _viewportMetrics.length);

  /// Gets the total number of recorded metrics.
  int get metricCount => _viewportMetrics.length;

  /// Gets the number of pan events recorded.
  int get panEventCount =>
      _viewportMetrics.where((m) => m.eventType.contains('pan')).length;

  /// Gets the number of zoom events recorded.
  int get zoomEventCount =>
      _viewportMetrics.where((m) => m.eventType.contains('zoom')).length;

  /// Gets the total pan distance in pixels.
  double get totalPanDistance => _viewportMetrics
      .where((m) => m.panDelta != null)
      .fold<double>(0.0, (sum, m) => sum + m.panDelta!.distance);

  /// Gets the average pan delta per pan event.
  double get averagePanDelta {
    final panMetrics =
        _viewportMetrics.where((m) => m.panDelta != null).toList();
    if (panMetrics.isEmpty) return 0.0;

    final totalDistance =
        panMetrics.fold<double>(0.0, (sum, m) => sum + m.panDelta!.distance);
    return totalDistance / panMetrics.length;
  }

  /// Prints a summary of collected telemetry to debug console.
  void printSummary() {
    if (!enabled) {
      debugPrint('[Telemetry] Telemetry is disabled');
      return;
    }

    debugPrint('=== Telemetry Summary ===');
    debugPrint('Total metrics: $metricCount');
    debugPrint('Pan events: $panEventCount');
    debugPrint('Zoom events: $zoomEventCount');
    debugPrint('');
    debugPrint('FPS Statistics:');
    debugPrint('  Average: ${averageFps.toStringAsFixed(1)}');
    debugPrint('  Min: ${minFps.toStringAsFixed(1)}');
    debugPrint('  Max: ${maxFps.toStringAsFixed(1)}');
    debugPrint('');
    debugPrint('Pan Statistics:');
    debugPrint('  Total distance: ${totalPanDistance.toStringAsFixed(1)} px');
    debugPrint('  Average delta: ${averagePanDelta.toStringAsFixed(1)} px');
    debugPrint('========================');
  }

  /// Clears all recorded metrics.
  void clear() {
    _viewportMetrics.clear();
  }

  /// Disposes resources.
  void dispose() {
    _config.removeListener(_onConfigChanged);
    _exporter?.dispose();
  }

  /// Returns a read-only view of recent metrics.
  ///
  /// [count] limits how many recent metrics to return (default: 100).
  List<ViewportTelemetry> getRecentMetrics({int count = 100}) =>
      _viewportMetrics.reversed.take(count).toList();

  /// Returns metrics matching a specific event type.
  List<ViewportTelemetry> getMetricsByType(String eventType) =>
      _viewportMetrics.where((m) => m.eventType == eventType).toList();

  /// Records a snapshot performance metric.
  ///
  /// This method is called by SnapshotManager after each snapshot creation
  /// to track snapshot duration and compression effectiveness.
  ///
  /// Parameters:
  /// - [durationMs]: Time taken to create and persist snapshot
  /// - [compressionRatio]: Ratio of uncompressed to compressed size
  /// - [documentId]: Optional document identifier for correlation
  void recordSnapshotMetric({
    required int durationMs,
    required double compressionRatio,
    String? documentId,
  }) {
    if (!enabled) return;

    // Log snapshot metric (structured logging)
    if (verbose) {
      final log = _logBuilder.debug(
        message: 'Snapshot metric recorded',
        eventType: 'SnapshotMetric',
        latencyMs: durationMs,
        metadata: {
          'durationMs': durationMs,
          'compressionRatio': compressionRatio,
          'documentId': documentId,
          MetricsCatalog.snapshotDuration: durationMs,
        },
      );
      debugPrint(log.toJsonString());
    }

    // Warn if snapshot exceeds NFR threshold (500ms p95)
    if (durationMs > 500) {
      final log = _logBuilder.warn(
        message:
            'Snapshot performance warning: ${durationMs}ms exceeds 500ms threshold',
        eventType: 'SnapshotPerformanceWarning',
        latencyMs: durationMs,
        metadata: {
          'durationMs': durationMs,
          'threshold': 500,
          'compressionRatio': compressionRatio,
          MetricsCatalog.snapshotDuration: durationMs,
        },
      );
      debugPrint(log.toJsonString());
    }

    // Export to OTLP if configured and sampling allows
    if (_exporter != null && shouldSample()) {
      _exportSnapshotMetric(durationMs, compressionRatio, documentId);
    }
  }

  /// Records an event replay performance metric.
  ///
  /// This method tracks event replay throughput to ensure system meets
  /// NFR requirements (>4000 events/sec warning, >5000 events/sec target).
  ///
  /// Parameters:
  /// - [eventsPerSec]: Event replay rate in events per second
  /// - [queueDepth]: Optional queue depth for monitoring backlog
  void recordReplayMetric({
    required double eventsPerSec,
    int? queueDepth,
  }) {
    if (!enabled) return;

    // Log replay metric (structured logging)
    if (verbose) {
      final log = _logBuilder.debug(
        message: 'Replay metric recorded',
        eventType: 'ReplayMetric',
        metadata: {
          'eventsPerSec': eventsPerSec,
          'queueDepth': queueDepth,
          MetricsCatalog.eventReplayRate: eventsPerSec,
        },
      );
      debugPrint(log.toJsonString());
    }

    // Warn if replay rate falls below NFR threshold (5000 events/sec)
    if (eventsPerSec < 5000) {
      final severity = eventsPerSec < 4000 ? 'critical' : 'warning';
      final log = _logBuilder.warn(
        message:
            'Replay performance $severity: ${eventsPerSec.toStringAsFixed(0)} events/sec below 5000 events/sec target',
        eventType: 'ReplayPerformanceWarning',
        metadata: {
          'eventsPerSec': eventsPerSec,
          'severity': severity,
          'targetRate': 5000,
          'queueDepth': queueDepth,
          MetricsCatalog.eventReplayRate: eventsPerSec,
        },
      );
      debugPrint(log.toJsonString());
    }

    // Export to OTLP if configured and sampling allows
    if (_exporter != null && shouldSample()) {
      _exportReplayMetric(eventsPerSec, queueDepth);
    }
  }

  /// Exports snapshot metric via OTLP.
  void _exportSnapshotMetric(
    int durationMs,
    double compressionRatio,
    String? documentId,
  ) {
    try {
      // Create custom payload for snapshot metrics
      // (PerformanceSamplePayload is viewport-specific, so we use generic export)
      final payload = {
        'metric': MetricsCatalog.snapshotDuration,
        'value': durationMs,
        'compressionRatio': compressionRatio,
        'documentId': documentId,
        'platform': defaultTargetPlatform.name,
        'telemetryOptIn': _config.enabled,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      };

      // Note: Actual OTLP export would need OTLPExporter enhancement
      // to support generic metric payloads, not just PerformanceSamplePayload
      if (kDebugMode) {
        debugPrint(
            '[TelemetryService] Snapshot metric export: ${payload.toString()}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[TelemetryService] Failed to export snapshot metric: $e');
      }
    }
  }

  /// Exports replay metric via OTLP.
  void _exportReplayMetric(double eventsPerSec, int? queueDepth) {
    try {
      final payload = {
        'metric': MetricsCatalog.eventReplayRate,
        'value': eventsPerSec,
        'queueDepth': queueDepth,
        'platform': defaultTargetPlatform.name,
        'telemetryOptIn': _config.enabled,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      };

      if (kDebugMode) {
        debugPrint(
            '[TelemetryService] Replay metric export: ${payload.toString()}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[TelemetryService] Failed to export replay metric: $e');
      }
    }
  }
}
