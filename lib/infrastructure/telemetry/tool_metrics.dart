import 'package:flutter/foundation.dart';

/// Telemetry data for tool drag operations.
///
/// ToolTelemetry captures performance metrics for direct manipulation
/// operations like anchor dragging, handle adjustment, and object movement.
///
/// ## Metrics
///
/// - **Duration**: Total time of drag operation in milliseconds
/// - **Event Count**: Number of sampled events emitted during drag
/// - **Events Per Second**: Rate of event emission (expected ~20/sec for 50ms sampling)
/// - **Backlog Occurred**: Whether event sampler buffer experienced backpressure
///
/// ## Usage
///
/// ```dart
/// final metric = ToolTelemetry(
///   toolId: 'direct_selection',
///   operationType: 'drag_anchor',
///   duration: Duration(milliseconds: 1500),
///   eventCount: 30,
///   eventsPerSecond: 20.0,
///   backlogOccurred: false,
/// );
///
/// telemetryService.recordToolMetric(metric);
/// ```
class ToolTelemetry {
  /// Creates a tool telemetry metric.
  ToolTelemetry({
    required this.toolId,
    required this.operationType,
    required this.duration,
    required this.eventCount,
    required this.eventsPerSecond,
    this.backlogOccurred = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Unique identifier for the tool that generated this metric.
  final String toolId;

  /// Type of operation (e.g., 'drag_anchor', 'drag_handle', 'move_object').
  final String operationType;

  /// Duration of the operation.
  final Duration duration;

  /// Number of events emitted during the operation.
  final int eventCount;

  /// Rate of events per second.
  final double eventsPerSecond;

  /// Whether event sampler backlog/backpressure occurred.
  final bool backlogOccurred;

  /// Timestamp when the metric was recorded.
  final DateTime timestamp;

  /// Returns true if this operation exceeded performance thresholds.
  ///
  /// Performance is considered poor if:
  /// - Duration > 2000ms (2 seconds)
  /// - Events per second < 15 (expected ~20 for 50ms sampling)
  /// - Backlog occurred (event sampler buffer overflow)
  bool get hasPerformanceIssue =>
      duration.inMilliseconds > 2000 ||
      eventsPerSecond < 15.0 ||
      backlogOccurred;

  @override
  String toString() => 'ToolTelemetry('
      'tool: $toolId, '
      'operation: $operationType, '
      'duration: ${duration.inMilliseconds}ms, '
      'events: $eventCount, '
      'events/sec: ${eventsPerSecond.toStringAsFixed(1)}, '
      'backlog: $backlogOccurred'
      ')';
}

/// Extension to TelemetryService for tool-specific metrics.
///
/// This extends the base TelemetryService with methods for recording
/// and analyzing tool interaction metrics.
extension ToolMetricsExtension on dynamic {
  /// Records a drag operation metric.
  ///
  /// This method logs tool drag performance and emits warnings if
  /// performance thresholds are exceeded.
  ///
  /// Parameters:
  /// - [duration]: Total drag operation duration
  /// - [eventCount]: Number of events emitted
  /// - [eventsPerSecond]: Rate of event emission
  /// - [toolId]: Tool identifier (default: 'direct_selection')
  /// - [operationType]: Type of drag operation (default: 'drag')
  void recordDragMetrics({
    required Duration duration,
    required int eventCount,
    required double eventsPerSecond,
    String toolId = 'direct_selection',
    String operationType = 'drag',
  }) {
    // Create telemetry metric
    final metric = ToolTelemetry(
      toolId: toolId,
      operationType: operationType,
      duration: duration,
      eventCount: eventCount,
      eventsPerSecond: eventsPerSecond,
      backlogOccurred: false, // Could be enhanced to detect actual backlog
    );

    // Log metric if verbose or has performance issues
    if (metric.hasPerformanceIssue) {
      debugPrint('[Tool Telemetry] Performance warning: $metric');
    } else {
      debugPrint('[Tool Telemetry] $metric');
    }

    // Future: could store metrics in a list similar to viewport metrics
    // For now, we just log them
  }

  /// Records when event sampler backlog/backpressure occurs.
  ///
  /// This is called when the event sampler buffer age exceeds threshold,
  /// indicating the system cannot keep up with event emission rate.
  void recordBackpressure({
    required String toolId,
    required int bufferAgeMs,
    int thresholdMs = 100,
  }) {
    debugPrint(
      '[Tool Telemetry] Backpressure detected: '
      'tool=$toolId, bufferAge=${bufferAgeMs}ms, threshold=${thresholdMs}ms',
    );
  }

  /// Records tool activation.
  void recordToolActivation(String toolId) {
    debugPrint('[Tool Telemetry] Tool activated: $toolId');
  }

  /// Records tool deactivation.
  void recordToolDeactivation(String toolId) {
    debugPrint('[Tool Telemetry] Tool deactivated: $toolId');
  }
}

/// Metrics for anchor and handle manipulation operations.
///
/// AnchorMetrics tracks specific metrics for direct selection tool
/// operations like anchor dragging, handle adjustment, and anchor type
/// conversion.
class AnchorMetrics {
  /// Number of anchor drag operations.
  int anchorDragCount = 0;

  /// Number of handle drag operations.
  int handleDragCount = 0;

  /// Number of anchor type conversions.
  int anchorTypeConversionCount = 0;

  /// Total duration of all drag operations.
  Duration totalDragDuration = Duration.zero;

  /// Total events emitted across all operations.
  int totalEventCount = 0;

  /// Average events per second across all operations.
  double get averageEventsPerSecond {
    if (totalDragDuration.inMilliseconds == 0) return 0.0;
    return totalEventCount / totalDragDuration.inMilliseconds * 1000;
  }

  /// Average drag duration.
  Duration get averageDragDuration {
    final totalOps = anchorDragCount + handleDragCount;
    if (totalOps == 0) return Duration.zero;
    return Duration(
      milliseconds: totalDragDuration.inMilliseconds ~/ totalOps,
    );
  }

  /// Records an anchor drag operation.
  void recordAnchorDrag(Duration duration, int eventCount) {
    anchorDragCount++;
    totalDragDuration += duration;
    totalEventCount += eventCount;
  }

  /// Records a handle drag operation.
  void recordHandleDrag(Duration duration, int eventCount) {
    handleDragCount++;
    totalDragDuration += duration;
    totalEventCount += eventCount;
  }

  /// Records an anchor type conversion.
  void recordAnchorTypeConversion() {
    anchorTypeConversionCount++;
  }

  /// Resets all metrics to zero.
  void reset() {
    anchorDragCount = 0;
    handleDragCount = 0;
    anchorTypeConversionCount = 0;
    totalDragDuration = Duration.zero;
    totalEventCount = 0;
  }

  /// Prints a summary of collected metrics.
  void printSummary() {
    debugPrint('=== Anchor Metrics Summary ===');
    debugPrint('Anchor drags: $anchorDragCount');
    debugPrint('Handle drags: $handleDragCount');
    debugPrint('Anchor type conversions: $anchorTypeConversionCount');
    debugPrint('');
    debugPrint('Performance:');
    debugPrint(
      '  Average drag duration: ${averageDragDuration.inMilliseconds}ms',
    );
    debugPrint(
      '  Average events/sec: ${averageEventsPerSecond.toStringAsFixed(1)}',
    );
    debugPrint('  Total events: $totalEventCount');
    debugPrint('==============================');
  }
}
