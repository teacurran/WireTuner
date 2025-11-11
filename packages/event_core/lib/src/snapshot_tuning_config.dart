/// Configuration for adaptive snapshot cadence tuning.
///
/// This module provides configuration for adjusting snapshot creation
/// frequency based on editing activity patterns (burst vs. idle).
library;

import 'dart:io' show Platform;

/// Configuration for adaptive snapshot cadence.
///
/// The snapshot system adjusts its cadence based on editing activity:
/// - **Burst mode**: Dense editing (high events/sec) → reduce interval
/// - **Idle mode**: Sparse editing (low events/sec) → increase interval
/// - **Normal mode**: Moderate editing → use base interval
///
/// **Environment Variables** (all optional, with sensible defaults):
/// - `WIRETUNER_SNAPSHOT_BASE_INTERVAL`: Base event count between snapshots (default: 1000)
/// - `WIRETUNER_SNAPSHOT_BURST_MULTIPLIER`: Multiplier during burst editing (default: 0.5)
/// - `WIRETUNER_SNAPSHOT_IDLE_MULTIPLIER`: Multiplier during idle periods (default: 2.0)
/// - `WIRETUNER_SNAPSHOT_WINDOW_SECONDS`: Activity tracking window in seconds (default: 60)
/// - `WIRETUNER_SNAPSHOT_BURST_THRESHOLD`: Events/sec for burst classification (default: 20.0)
/// - `WIRETUNER_SNAPSHOT_IDLE_THRESHOLD`: Events/sec for idle classification (default: 2.0)
class SnapshotTuningConfig {
  /// Creates a snapshot tuning configuration.
  ///
  /// All parameters are optional and fall back to sensible defaults.
  /// Use [fromEnvironment] factory to load from environment variables.
  const SnapshotTuningConfig({
    this.baseInterval = 1000,
    this.burstMultiplier = 0.5,
    this.idleMultiplier = 2.0,
    this.windowSeconds = 60,
    this.burstThreshold = 20.0,
    this.idleThreshold = 2.0,
  })  : assert(baseInterval > 0, 'baseInterval must be positive'),
        assert(burstMultiplier > 0, 'burstMultiplier must be positive'),
        assert(idleMultiplier > 0, 'idleMultiplier must be positive'),
        assert(windowSeconds > 0, 'windowSeconds must be positive'),
        assert(
            burstThreshold > idleThreshold,
            'burstThreshold must be greater than idleThreshold');

  /// Base number of events between snapshots.
  ///
  /// This is the default interval used during normal editing activity.
  /// Default: 1000 events (≈5-10 minutes of active editing).
  final int baseInterval;

  /// Multiplier applied during burst editing.
  ///
  /// When editing rate exceeds [burstThreshold], the effective interval
  /// becomes `baseInterval * burstMultiplier`.
  ///
  /// Default: 0.5 (snapshots every 500 events during bursts).
  final double burstMultiplier;

  /// Multiplier applied during idle periods.
  ///
  /// When editing rate falls below [idleThreshold], the effective interval
  /// becomes `baseInterval * idleMultiplier`.
  ///
  /// Default: 2.0 (snapshots every 2000 events when idle).
  final double idleMultiplier;

  /// Duration of the rolling activity tracking window (seconds).
  ///
  /// The system tracks events within this window to classify activity.
  /// Shorter windows respond faster to changes; longer windows are more stable.
  ///
  /// Default: 60 seconds.
  final int windowSeconds;

  /// Events per second threshold for burst classification.
  ///
  /// If the rate exceeds this threshold, editing is classified as "burst".
  /// Default: 20 events/sec.
  final double burstThreshold;

  /// Events per second threshold for idle classification.
  ///
  /// If the rate falls below this threshold, editing is classified as "idle".
  /// Default: 2 events/sec.
  final double idleThreshold;

  /// Creates configuration from environment variables.
  ///
  /// Falls back to defaults if variables are not set or invalid.
  /// Logs warnings for invalid values but continues with defaults.
  factory SnapshotTuningConfig.fromEnvironment({
    void Function(String message)? onWarning,
  }) {
    final env = Platform.environment;

    int parseIntOr(String key, int defaultValue) {
      final value = env[key];
      if (value == null) return defaultValue;
      final parsed = int.tryParse(value);
      if (parsed == null || parsed <= 0) {
        onWarning?.call(
            'Invalid $key="$value", must be positive integer. Using default: $defaultValue');
        return defaultValue;
      }
      return parsed;
    }

    double parseDoubleOr(String key, double defaultValue) {
      final value = env[key];
      if (value == null) return defaultValue;
      final parsed = double.tryParse(value);
      if (parsed == null || parsed <= 0) {
        onWarning?.call(
            'Invalid $key="$value", must be positive number. Using default: $defaultValue');
        return defaultValue;
      }
      return parsed;
    }

    final baseInterval =
        parseIntOr('WIRETUNER_SNAPSHOT_BASE_INTERVAL', 1000);
    final burstMultiplier =
        parseDoubleOr('WIRETUNER_SNAPSHOT_BURST_MULTIPLIER', 0.5);
    final idleMultiplier =
        parseDoubleOr('WIRETUNER_SNAPSHOT_IDLE_MULTIPLIER', 2.0);
    final windowSeconds =
        parseIntOr('WIRETUNER_SNAPSHOT_WINDOW_SECONDS', 60);
    final burstThreshold =
        parseDoubleOr('WIRETUNER_SNAPSHOT_BURST_THRESHOLD', 20.0);
    final idleThreshold =
        parseDoubleOr('WIRETUNER_SNAPSHOT_IDLE_THRESHOLD', 2.0);

    // Validate threshold ordering
    if (burstThreshold <= idleThreshold) {
      onWarning?.call(
          'WIRETUNER_SNAPSHOT_BURST_THRESHOLD ($burstThreshold) must be > '
          'WIRETUNER_SNAPSHOT_IDLE_THRESHOLD ($idleThreshold). Using defaults.');
      return const SnapshotTuningConfig();
    }

    return SnapshotTuningConfig(
      baseInterval: baseInterval,
      burstMultiplier: burstMultiplier,
      idleMultiplier: idleMultiplier,
      windowSeconds: windowSeconds,
      burstThreshold: burstThreshold,
      idleThreshold: idleThreshold,
    );
  }

  /// Calculates the effective snapshot interval for the given activity rate.
  ///
  /// Returns the adjusted interval based on current events/second:
  /// - Burst: `baseInterval * burstMultiplier`
  /// - Idle: `baseInterval * idleMultiplier`
  /// - Normal: `baseInterval`
  int effectiveInterval(double eventsPerSecond) {
    if (eventsPerSecond >= burstThreshold) {
      return (baseInterval * burstMultiplier).round();
    } else if (eventsPerSecond <= idleThreshold) {
      return (baseInterval * idleMultiplier).round();
    } else {
      return baseInterval;
    }
  }

  /// Classifies editing activity based on events/second.
  EditingActivity classifyActivity(double eventsPerSecond) {
    if (eventsPerSecond >= burstThreshold) {
      return EditingActivity.burst;
    } else if (eventsPerSecond <= idleThreshold) {
      return EditingActivity.idle;
    } else {
      return EditingActivity.normal;
    }
  }

  @override
  String toString() => 'SnapshotTuningConfig('
      'baseInterval: $baseInterval, '
      'burstMultiplier: $burstMultiplier, '
      'idleMultiplier: $idleMultiplier, '
      'windowSeconds: $windowSeconds, '
      'burstThreshold: $burstThreshold, '
      'idleThreshold: $idleThreshold)';
}

/// Classification of editing activity patterns.
enum EditingActivity {
  /// High-rate editing (≥ burst threshold events/sec).
  burst,

  /// Moderate editing rate.
  normal,

  /// Low-rate editing (≤ idle threshold events/sec).
  idle,
}

/// Extension for human-readable activity labels.
extension EditingActivityLabel on EditingActivity {
  String get label {
    switch (this) {
      case EditingActivity.burst:
        return 'burst';
      case EditingActivity.normal:
        return 'normal';
      case EditingActivity.idle:
        return 'idle';
    }
  }
}
