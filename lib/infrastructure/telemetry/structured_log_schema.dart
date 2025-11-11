/// Structured logging schema for WireTuner.
///
/// This module provides standardized log entry models that conform to the
/// shared JSON schema across desktop and backend components as specified
/// in Section 3.6 of the Operational Architecture.
///
/// All log entries include:
/// - component: Component identifier
/// - documentId: Document context (optional)
/// - operationId: Operation correlation ID (optional)
/// - eventType: Event/operation type
/// - latencyMs: Operation latency (optional)
/// - featureFlagContext: Active feature flags
/// - timestamp: ISO 8601 timestamp
/// - level: Log level (DEBUG, INFO, WARN, ERROR)
/// - traceId: OpenTelemetry trace ID for cross-layer debugging
/// - message: Human-readable message
library;

import 'dart:convert';

/// Log levels aligned with OpenTelemetry severity.
enum LogLevel {
  debug('DEBUG'),
  info('INFO'),
  warn('WARN'),
  error('ERROR');

  const LogLevel(this.value);
  final String value;
}

/// Structured log entry following the shared schema.
///
/// All fields are serialized to JSON for structured logging backends
/// (CloudWatch Logs, OpenSearch, etc.).
class StructuredLogEntry {
  /// Creates a structured log entry.
  ///
  /// [component]: Component identifier (e.g., 'InteractionEngine', 'SnapshotManager')
  /// [level]: Log severity level
  /// [message]: Human-readable log message
  /// [eventType]: Event or operation type (e.g., 'EventReplay', 'SnapshotCreated')
  /// [documentId]: Document UUID context (optional)
  /// [operationId]: Operation correlation ID (optional)
  /// [latencyMs]: Operation latency in milliseconds (optional)
  /// [featureFlagContext]: Active feature flags during operation
  /// [traceId]: OpenTelemetry trace ID for distributed tracing (optional)
  /// [metadata]: Additional structured metadata
  StructuredLogEntry({
    required this.component,
    required this.level,
    required this.message,
    required this.eventType,
    this.documentId,
    this.operationId,
    this.latencyMs,
    this.featureFlagContext = const [],
    this.traceId,
    this.metadata = const {},
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Component identifier.
  final String component;

  /// Log level.
  final LogLevel level;

  /// Human-readable message.
  final String message;

  /// Event or operation type.
  final String eventType;

  /// Document UUID context.
  final String? documentId;

  /// Operation correlation ID.
  final String? operationId;

  /// Operation latency in milliseconds.
  final int? latencyMs;

  /// Active feature flags during this operation.
  final List<String> featureFlagContext;

  /// OpenTelemetry trace ID for cross-layer debugging.
  final String? traceId;

  /// Timestamp of log entry.
  final DateTime timestamp;

  /// Additional structured metadata.
  final Map<String, dynamic> metadata;

  /// Converts log entry to JSON map.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'component': component,
      'level': level.value,
      'message': message,
      'eventType': eventType,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'featureFlagContext': featureFlagContext,
    };

    if (documentId != null) json['documentId'] = documentId;
    if (operationId != null) json['operationId'] = operationId;
    if (latencyMs != null) json['latencyMs'] = latencyMs;
    if (traceId != null) json['traceId'] = traceId;
    if (metadata.isNotEmpty) json['metadata'] = metadata;

    return json;
  }

  /// Converts log entry to JSON string.
  String toJsonString() => jsonEncode(toJson());

  @override
  String toString() => toJsonString();

  /// Creates a copy with updated fields.
  StructuredLogEntry copyWith({
    String? component,
    LogLevel? level,
    String? message,
    String? eventType,
    String? documentId,
    String? operationId,
    int? latencyMs,
    List<String>? featureFlagContext,
    String? traceId,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return StructuredLogEntry(
      component: component ?? this.component,
      level: level ?? this.level,
      message: message ?? this.message,
      eventType: eventType ?? this.eventType,
      documentId: documentId ?? this.documentId,
      operationId: operationId ?? this.operationId,
      latencyMs: latencyMs ?? this.latencyMs,
      featureFlagContext: featureFlagContext ?? this.featureFlagContext,
      traceId: traceId ?? this.traceId,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Builder for structured log entries.
///
/// Provides a fluent API for constructing log entries with context
/// from multiple sources (feature flags, trace propagation, etc.).
class StructuredLogBuilder {
  /// Creates a log builder.
  StructuredLogBuilder({
    required this.component,
    this.defaultFeatureFlags = const [],
    this.defaultTraceId,
  });

  /// Component identifier.
  final String component;

  /// Default feature flags to include in all logs.
  final List<String> defaultFeatureFlags;

  /// Default trace ID (can be overridden per log).
  final String? defaultTraceId;

  /// Creates a DEBUG level log entry.
  StructuredLogEntry debug({
    required String message,
    required String eventType,
    String? documentId,
    String? operationId,
    int? latencyMs,
    List<String>? featureFlagContext,
    String? traceId,
    Map<String, dynamic>? metadata,
  }) {
    return StructuredLogEntry(
      component: component,
      level: LogLevel.debug,
      message: message,
      eventType: eventType,
      documentId: documentId,
      operationId: operationId,
      latencyMs: latencyMs,
      featureFlagContext: featureFlagContext ?? defaultFeatureFlags,
      traceId: traceId ?? defaultTraceId,
      metadata: metadata ?? {},
    );
  }

  /// Creates an INFO level log entry.
  StructuredLogEntry info({
    required String message,
    required String eventType,
    String? documentId,
    String? operationId,
    int? latencyMs,
    List<String>? featureFlagContext,
    String? traceId,
    Map<String, dynamic>? metadata,
  }) {
    return StructuredLogEntry(
      component: component,
      level: LogLevel.info,
      message: message,
      eventType: eventType,
      documentId: documentId,
      operationId: operationId,
      latencyMs: latencyMs,
      featureFlagContext: featureFlagContext ?? defaultFeatureFlags,
      traceId: traceId ?? defaultTraceId,
      metadata: metadata ?? {},
    );
  }

  /// Creates a WARN level log entry.
  StructuredLogEntry warn({
    required String message,
    required String eventType,
    String? documentId,
    String? operationId,
    int? latencyMs,
    List<String>? featureFlagContext,
    String? traceId,
    Map<String, dynamic>? metadata,
  }) {
    return StructuredLogEntry(
      component: component,
      level: LogLevel.warn,
      message: message,
      eventType: eventType,
      documentId: documentId,
      operationId: operationId,
      latencyMs: latencyMs,
      featureFlagContext: featureFlagContext ?? defaultFeatureFlags,
      traceId: traceId ?? defaultTraceId,
      metadata: metadata ?? {},
    );
  }

  /// Creates an ERROR level log entry.
  StructuredLogEntry error({
    required String message,
    required String eventType,
    String? documentId,
    String? operationId,
    int? latencyMs,
    List<String>? featureFlagContext,
    String? traceId,
    Map<String, dynamic>? metadata,
  }) {
    return StructuredLogEntry(
      component: component,
      level: LogLevel.error,
      message: message,
      eventType: eventType,
      documentId: documentId,
      operationId: operationId,
      latencyMs: latencyMs,
      featureFlagContext: featureFlagContext ?? defaultFeatureFlags,
      traceId: traceId ?? defaultTraceId,
      metadata: metadata ?? {},
    );
  }
}

/// Metrics catalog field names (Section 3.15).
///
/// These constants ensure consistency when mapping local metrics
/// to the shared catalog.
class MetricsCatalog {
  MetricsCatalog._();

  // Render Metrics
  /// Frames per second metric name.
  static const renderFps = 'render.fps';

  /// Frame render time in milliseconds metric name.
  static const renderFrameTimeMs = 'render.frame_time_ms';

  /// Cursor latency in microseconds metric name.
  static const cursorLatencyUs = 'cursor.latency_us';

  // Persistence Metrics
  /// Event write latency in milliseconds metric name.
  static const eventWriteLatencyMs = 'event.write.latency_ms';

  /// Snapshot duration in milliseconds metric name.
  static const snapshotDurationMs = 'snapshot.duration_ms';

  /// Count of deferred snapshots metric name.
  static const snapshotDeferredCount = 'snapshot.deferred.count';

  /// SQLite WAL checkpoint duration in milliseconds metric name.
  static const sqliteWalCheckpointMs = 'sqlite.wal_checkpoint_ms';

  // Collaboration Metrics
  /// OT transform count metric name.
  static const otTransformCount = 'ot.transform.count';

  /// OT correction latency in milliseconds metric name.
  static const otCorrectionLatencyMs = 'ot.correction.latency_ms';

  /// Active WebSocket sessions count metric name.
  static const websocketActiveSessions = 'websocket.active_sessions';

  /// Presence update rate metric name.
  static const presenceUpdateRate = 'presence.update_rate';

  // Import/Export Metrics
  /// Conversion duration in milliseconds metric name.
  static const conversionDurationMs = 'conversion.duration_ms';

  /// Conversion failures count metric name.
  static const conversionFailures = 'conversion.failures';

  /// Queue depth metric name.
  static const queueDepth = 'queue.depth';

  /// Worker CPU percentage metric name.
  static const workerCpuPct = 'worker.cpu_pct';

  // Telemetry Metrics
  /// Telemetry opt-out ratio metric name.
  static const telemetryOptOutRatio = 'telemetry.opt_out_ratio';

  /// Log upload latency metric name.
  static const logUploadLatency = 'log.upload.latency';

  /// Trace sample rate metric name.
  static const traceSampleRate = 'trace.sample_rate';

  /// Alert acknowledgement latency metric name.
  static const alertAckLatency = 'alert.ack.latency';

  // Security Metrics
  /// Authentication failure count metric name.
  static const authFailureCount = 'auth.failure.count';

  /// JWT refresh latency metric name.
  static const jwtRefreshLatency = 'jwt.refresh.latency';

  /// File I/O traversal blocked count metric name.
  static const fileioTraversalBlocked = 'fileio.traversal_blocked';

  /// Secrets rotation age in days metric name.
  static const secretsRotationAgeDays = 'secrets.rotation.age_days';

  // Compliance Metrics
  /// Retention policy violations count metric name.
  static const retentionPolicyViolations = 'retention.policy.violations';

  /// Audit log size in megabytes metric name.
  static const auditLogSizeMb = 'audit.log.size_mb';

  /// Feature flag lifetime in days metric name.
  static const flagLifetimeDays = 'flag.lifetime_days';

  /// ADR staleness in days metric name.
  static const adrStalenessDays = 'adr.staleness_days';
}
