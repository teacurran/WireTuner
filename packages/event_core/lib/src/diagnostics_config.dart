/// Configuration for event core logging and metrics behavior.
///
/// This module defines toggleable diagnostics settings for controlling
/// logging verbosity and metrics collection in different build modes.
library;

import 'package:logger/logger.dart';

/// Configuration for event core diagnostics (logging + metrics).
///
/// Controls log levels, metrics collection, and diagnostic behavior.
/// Typically configured once at application startup with different
/// settings for debug vs. release builds.
///
/// Example:
/// ```dart
/// // Debug configuration
/// final debugConfig = EventCoreDiagnosticsConfig(
///   logLevel: Level.debug,
///   enableMetrics: true,
///   enableDetailedLogging: true,
/// );
///
/// // Release configuration
/// final releaseConfig = EventCoreDiagnosticsConfig(
///   logLevel: Level.info,
///   enableMetrics: true,
///   enableDetailedLogging: false,
/// );
/// ```
class EventCoreDiagnosticsConfig {
  /// Creates a diagnostics configuration.
  ///
  /// [logLevel]: Minimum log level to output (default: Level.info)
  /// [enableMetrics]: Whether to collect performance metrics (default: true)
  /// [enableDetailedLogging]: Enable verbose logging for debugging (default: false)
  const EventCoreDiagnosticsConfig({
    this.logLevel = Level.info,
    this.enableMetrics = true,
    this.enableDetailedLogging = false,
  });

  /// Minimum log level to output.
  ///
  /// Levels (in order of severity):
  /// - Level.trace: Most verbose, every operation
  /// - Level.debug: Detailed flow, state changes
  /// - Level.info: Key lifecycle events
  /// - Level.warning: Recoverable issues
  /// - Level.error: Unrecoverable failures
  final Level logLevel;

  /// Whether to collect and record performance metrics.
  ///
  /// When enabled, event recorder/replayer/snapshot manager will measure
  /// operation durations and forward to MetricsSink.
  ///
  /// Overhead is minimal (< 1% of operation time), so safe to enable
  /// in release builds for production monitoring.
  final bool enableMetrics;

  /// Enable detailed logging for debugging.
  ///
  /// When true, logs include additional context like:
  /// - Event payload previews (first 100 chars)
  /// - Sequence numbers and timestamps
  /// - Intermediate state during replay
  ///
  /// Should be disabled in release builds to reduce log volume.
  final bool enableDetailedLogging;

  /// Creates a debug-optimized configuration.
  ///
  /// - Level.debug logging
  /// - Metrics enabled
  /// - Detailed logging enabled
  factory EventCoreDiagnosticsConfig.debug() =>
      const EventCoreDiagnosticsConfig(
        logLevel: Level.debug,
        enableMetrics: true,
        enableDetailedLogging: true,
      );

  /// Creates a release-optimized configuration.
  ///
  /// - Level.info logging
  /// - Metrics enabled
  /// - Detailed logging disabled
  factory EventCoreDiagnosticsConfig.release() =>
      const EventCoreDiagnosticsConfig(
        logLevel: Level.info,
        enableMetrics: true,
        enableDetailedLogging: false,
      );

  /// Creates a configuration with metrics and logging disabled.
  ///
  /// Useful for unit tests where you don't want log output.
  factory EventCoreDiagnosticsConfig.silent() =>
      const EventCoreDiagnosticsConfig(
        logLevel: Level.off,
        enableMetrics: false,
        enableDetailedLogging: false,
      );

  /// Returns whether a given log level should be emitted.
  bool shouldLog(Level level) => level.index >= logLevel.index;

  @override
  String toString() => 'EventCoreDiagnosticsConfig('
      'logLevel: $logLevel, '
      'enableMetrics: $enableMetrics, '
      'enableDetailedLogging: $enableDetailedLogging'
      ')';
}
