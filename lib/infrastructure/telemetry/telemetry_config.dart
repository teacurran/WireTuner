/// Centralized telemetry configuration with opt-out enforcement.
///
/// This module provides a single source of truth for telemetry opt-in/opt-out
/// state, ensuring consistent enforcement across all telemetry collection
/// paths (viewport metrics, tool telemetry, crash reports, OTLP exports).
///
/// ## Opt-out Enforcement
///
/// The opt-out flag is checked BEFORE any data collection occurs. When
/// telemetry is disabled:
/// - No metrics are collected or buffered locally
/// - No logs are uploaded to remote endpoints
/// - Existing buffers are cleared immediately
/// - Audit trail records opt-out state changes
///
/// ## Integration Points
///
/// This configuration integrates with:
/// - TelemetryService (viewport metrics)
/// - ToolTelemetry (tool operation metrics)
/// - OTLPExporter (OpenTelemetry export)
/// - EventCoreDiagnosticsConfig (event sourcing telemetry)
/// - Settings/preferences system
library;

import 'package:flutter/foundation.dart';

/// Centralized telemetry configuration.
///
/// Provides opt-in/opt-out state management with change notifications
/// for immediate propagation to all telemetry subsystems.
class TelemetryConfig extends ChangeNotifier {
  /// Creates telemetry configuration.
  ///
  /// [enabled]: Whether telemetry is enabled (default: false for privacy-first)
  /// [samplingRate]: Sampling rate for metrics (0.0-1.0, default: 1.0)
  /// [uploadEnabled]: Whether remote upload is enabled (default: enabled if telemetry enabled)
  /// [retentionDays]: Local log retention in days (default: 30)
  /// [collectorEndpoint]: Remote collector endpoint URL
  TelemetryConfig({
    bool? enabled,
    this.samplingRate = 1.0,
    bool? uploadEnabled,
    this.retentionDays = 30,
    this.collectorEndpoint,
  })  : _enabled = enabled ?? false,
        _uploadEnabled = uploadEnabled ?? (enabled ?? false);

  /// Creates a debug-mode configuration (telemetry enabled, no upload).
  factory TelemetryConfig.debug() => TelemetryConfig(
        enabled: true,
        uploadEnabled: false,
        samplingRate: 1.0,
      );

  /// Creates a production configuration with remote upload.
  factory TelemetryConfig.production({
    required bool enabled,
    required String collectorEndpoint,
    double samplingRate = 0.1, // 10% sampling for production
  }) =>
      TelemetryConfig(
        enabled: enabled,
        uploadEnabled: enabled,
        samplingRate: samplingRate,
        collectorEndpoint: collectorEndpoint,
      );

  /// Creates a configuration with telemetry completely disabled.
  factory TelemetryConfig.disabled() => TelemetryConfig(
        enabled: false,
        uploadEnabled: false,
        samplingRate: 0.0,
      );

  /// Creates configuration from JSON.
  factory TelemetryConfig.fromJson(Map<String, dynamic> json) =>
      TelemetryConfig(
        enabled: json['enabled'] as bool? ?? false,
        uploadEnabled: json['uploadEnabled'] as bool?,
        samplingRate: (json['samplingRate'] as num?)?.toDouble() ?? 1.0,
        retentionDays: json['retentionDays'] as int? ?? 30,
        collectorEndpoint: json['collectorEndpoint'] as String?,
      );

  bool _enabled;
  bool _uploadEnabled;

  /// Whether telemetry collection is enabled.
  ///
  /// When false, no telemetry data is collected, buffered, or uploaded.
  bool get enabled => _enabled;

  /// Sets telemetry enabled state.
  ///
  /// When transitioning from enabled to disabled, all subsystems are
  /// notified to clear buffers and stop collection immediately.
  set enabled(bool value) {
    if (_enabled != value) {
      final wasEnabled = _enabled;
      _enabled = value;

      // Record opt-out state change in audit trail
      _recordAuditEvent(
        wasEnabled: wasEnabled,
        nowEnabled: value,
      );

      // Notify all listeners (telemetry subsystems)
      notifyListeners();
    }
  }

  /// Whether remote upload is enabled.
  ///
  /// Even when telemetry is enabled, uploads can be separately disabled
  /// for offline/local-only operation.
  bool get uploadEnabled => _uploadEnabled && _enabled;

  set uploadEnabled(bool value) {
    if (_uploadEnabled != value) {
      _uploadEnabled = value;
      notifyListeners();
    }
  }

  /// Sampling rate for metrics (0.0 = no sampling, 1.0 = all events).
  ///
  /// Used to reduce overhead and bandwidth for high-frequency metrics.
  final double samplingRate;

  /// Local log retention period in days.
  ///
  /// Logs older than this are automatically purged to comply with
  /// retention policies (Section 3.6).
  final int retentionDays;

  /// Remote collector endpoint URL.
  ///
  /// If null, remote upload is disabled regardless of uploadEnabled flag.
  final String? collectorEndpoint;

  /// Audit trail of opt-in/opt-out events (in-memory, for this session).
  final List<TelemetryAuditEvent> _auditTrail = [];

  /// Returns read-only view of audit trail.
  List<TelemetryAuditEvent> get auditTrail => List.unmodifiable(_auditTrail);

  /// Records telemetry state change in audit trail.
  void _recordAuditEvent({
    required bool wasEnabled,
    required bool nowEnabled,
  }) {
    _auditTrail.add(
      TelemetryAuditEvent(
        timestamp: DateTime.now(),
        wasEnabled: wasEnabled,
        nowEnabled: nowEnabled,
      ),
    );

    // Trim audit trail to prevent unbounded growth
    if (_auditTrail.length > 1000) {
      _auditTrail.removeAt(0);
    }

    if (kDebugMode) {
      print(
        '[TelemetryConfig] State change: wasEnabled=$wasEnabled, nowEnabled=$nowEnabled',
      );
    }
  }

  /// Converts configuration to JSON for persistence.
  Map<String, dynamic> toJson() => {
        'enabled': _enabled,
        'uploadEnabled': _uploadEnabled,
        'samplingRate': samplingRate,
        'retentionDays': retentionDays,
        'collectorEndpoint': collectorEndpoint,
      };

  @override
  String toString() => 'TelemetryConfig('
      'enabled: $enabled, '
      'uploadEnabled: $uploadEnabled, '
      'samplingRate: $samplingRate, '
      'retentionDays: $retentionDays, '
      'collectorEndpoint: ${collectorEndpoint ?? "none"}'
      ')';
}

/// Audit event recording telemetry state changes.
///
/// Used for compliance verification and debugging opt-out issues.
class TelemetryAuditEvent {
  /// Creates a telemetry audit event.
  TelemetryAuditEvent({
    required this.timestamp,
    required this.wasEnabled,
    required this.nowEnabled,
  });

  /// Timestamp of state change.
  final DateTime timestamp;

  /// Previous enabled state.
  final bool wasEnabled;

  /// New enabled state.
  final bool nowEnabled;

  /// Converts audit event to JSON.
  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toUtc().toIso8601String(),
        'wasEnabled': wasEnabled,
        'nowEnabled': nowEnabled,
        'action': nowEnabled ? 'opt-in' : 'opt-out',
      };

  @override
  String toString() {
    final action = nowEnabled ? 'opted in' : 'opted out';
    return 'TelemetryAuditEvent(${timestamp.toIso8601String()}: $action)';
  }
}

/// Privacy-compliant telemetry guard mixin.
///
/// Provides convenience methods for checking telemetry opt-in state
/// before collecting or emitting metrics.
mixin TelemetryGuard {
  /// Gets the telemetry configuration.
  ///
  /// Implementations must provide access to the shared TelemetryConfig instance.
  TelemetryConfig get telemetryConfig;

  /// Checks if telemetry is enabled.
  bool get isTelemetryEnabled => telemetryConfig.enabled;

  /// Checks if telemetry upload is enabled.
  bool get isTelemetryUploadEnabled => telemetryConfig.uploadEnabled;

  /// Executes action only if telemetry is enabled.
  ///
  /// Returns result of action, or null if telemetry is disabled.
  T? withTelemetry<T>(T Function() action) {
    if (!isTelemetryEnabled) return null;
    return action();
  }

  /// Executes async action only if telemetry is enabled.
  Future<T?> withTelemetryAsync<T>(Future<T> Function() action) async {
    if (!isTelemetryEnabled) return null;
    return action();
  }

  /// Samples action based on sampling rate.
  ///
  /// Returns true if action should proceed (based on sampling rate).
  bool shouldSample() {
    if (!isTelemetryEnabled) return false;
    final rate = telemetryConfig.samplingRate;
    if (rate >= 1.0) return true;
    if (rate <= 0.0) return false;

    // Simple random sampling
    return (DateTime.now().microsecondsSinceEpoch % 100) < (rate * 100);
  }
}
