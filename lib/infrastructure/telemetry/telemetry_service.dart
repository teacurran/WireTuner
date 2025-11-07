import 'package:flutter/foundation.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_state.dart';

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
class TelemetryService {
  /// Whether telemetry logging is enabled.
  bool enabled;

  /// Whether to print verbose logs for each metric.
  final bool verbose;

  /// Minimum FPS threshold for performance warnings.
  final double fpsWarningThreshold;

  /// List of recorded viewport metrics.
  final List<ViewportTelemetry> _viewportMetrics = [];

  /// Maximum number of metrics to keep in memory.
  final int maxMetricsHistory;

  /// Creates a telemetry service.
  ///
  /// [enabled] controls whether metrics are recorded (default: debug mode).
  /// [verbose] controls whether each metric is logged (default: false).
  /// [fpsWarningThreshold] sets the FPS threshold for warnings (default: 55).
  /// [maxMetricsHistory] limits the metrics history size (default: 1000).
  TelemetryService({
    bool? enabled,
    this.verbose = false,
    this.fpsWarningThreshold = 55.0,
    this.maxMetricsHistory = 1000,
  }) : enabled = enabled ?? kDebugMode;

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

    // Log if verbose
    if (verbose) {
      debugPrint('[Telemetry] $metric');
    }

    // Warn on poor performance
    if (metric.fps > 0 && metric.fps < fpsWarningThreshold) {
      debugPrint(
        '[Telemetry] Performance warning: FPS ${metric.fps.toStringAsFixed(1)} '
        'below threshold $fpsWarningThreshold',
      );
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
  double get totalPanDistance {
    return _viewportMetrics
        .where((m) => m.panDelta != null)
        .fold<double>(0.0, (sum, m) => sum + m.panDelta!.distance);
  }

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

  /// Returns a read-only view of recent metrics.
  ///
  /// [count] limits how many recent metrics to return (default: 100).
  List<ViewportTelemetry> getRecentMetrics({int count = 100}) {
    return _viewportMetrics.reversed.take(count).toList();
  }

  /// Returns metrics matching a specific event type.
  List<ViewportTelemetry> getMetricsByType(String eventType) {
    return _viewportMetrics.where((m) => m.eventType == eventType).toList();
  }
}
