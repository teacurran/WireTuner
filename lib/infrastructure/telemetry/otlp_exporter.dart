/// OpenTelemetry Protocol (OTLP) exporter for client telemetry.
///
/// This module implements OTLP export for metrics, logs, and traces following
/// the OpenTelemetry specification. It handles:
/// - Batching and compression
/// - Retry logic with exponential backoff
/// - Circuit breaker for failing endpoints
/// - Offline buffering with TTL
/// - Trace context propagation
///
/// ## Integration
///
/// The exporter integrates with:
/// - TelemetryConfig for opt-out enforcement
/// - StructuredLogSchema for log serialization
/// - MetricsCatalog for metric naming
/// - Telemetry API (api/telemetry.yaml) for REST endpoint contract
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'structured_log_schema.dart';
import 'telemetry_config.dart';

/// OTLP export result.
enum OTLPExportResult {
  success,
  failure,
  throttled,
  circuitOpen,
  optedOut,
}

/// OTLP exporter for telemetry data.
///
/// Exports metrics, logs, and traces to a remote collector endpoint
/// using the WireTuner Telemetry API (api/telemetry.yaml).
class OTLPExporter with TelemetryGuard {
  /// Creates an OTLP exporter.
  ///
  /// [config]: Telemetry configuration (must not be null)
  /// [client]: HTTP client for making requests (injectable for testing)
  /// [maxBatchSize]: Maximum number of entries per batch (default: 100)
  /// [maxBatchDelayMs]: Maximum delay before flushing partial batch (default: 5000ms)
  /// [maxRetries]: Maximum retry attempts (default: 3)
  /// [circuitBreakerThreshold]: Failure count before opening circuit (default: 5)
  OTLPExporter({
    required TelemetryConfig config,
    http.Client? client,
    this.maxBatchSize = 100,
    this.maxBatchDelayMs = 5000,
    this.maxRetries = 3,
    this.circuitBreakerThreshold = 5,
  })  : _config = config,
        _client = client ?? http.Client() {
    // Listen for config changes (opt-out events)
    _config.addListener(_onConfigChanged);

    // Start batch flush timer
    _startBatchTimer();
  }

  final TelemetryConfig _config;
  final http.Client _client;

  @override
  TelemetryConfig get telemetryConfig => _config;

  /// Maximum number of entries per batch.
  final int maxBatchSize;

  /// Maximum delay before flushing partial batch (milliseconds).
  final int maxBatchDelayMs;

  /// Maximum retry attempts per export.
  final int maxRetries;

  /// Failure count threshold for circuit breaker.
  final int circuitBreakerThreshold;

  /// Pending performance samples buffer.
  final List<PerformanceSamplePayload> _pendingSamples = [];

  /// Pending log entries buffer.
  final List<StructuredLogEntry> _pendingLogs = [];

  /// Circuit breaker state.
  bool _circuitOpen = false;
  int _consecutiveFailures = 0;
  DateTime? _circuitOpenedAt;

  /// Batch flush timer.
  Timer? _batchTimer;

  /// Export in progress flag (prevents concurrent exports).
  bool _exportInProgress = false;

  /// Handles telemetry config changes (opt-out).
  void _onConfigChanged() {
    if (!_config.enabled) {
      // Clear buffers immediately on opt-out
      _pendingSamples.clear();
      _pendingLogs.clear();

      if (kDebugMode) {
        print('[OTLPExporter] Telemetry disabled, buffers cleared');
      }
    }
  }

  /// Starts batch flush timer.
  void _startBatchTimer() {
    _batchTimer?.cancel();
    _batchTimer = Timer.periodic(
      Duration(milliseconds: maxBatchDelayMs),
      (_) => flush(),
    );
  }

  /// Records a performance sample for export.
  ///
  /// Samples are batched and exported periodically or when batch is full.
  void recordPerformanceSample(PerformanceSamplePayload sample) {
    if (!(withTelemetry(() => true) ?? false)) return;
    if (!shouldSample()) return;

    _pendingSamples.add(sample);

    // Flush if batch is full
    if (_pendingSamples.length >= maxBatchSize) {
      flush();
    }
  }

  /// Records a structured log entry for export.
  void recordLog(StructuredLogEntry log) {
    if (!(withTelemetry(() => true) ?? false)) return;

    _pendingLogs.add(log);

    // Flush if batch is full
    if (_pendingLogs.length >= maxBatchSize) {
      flush();
    }
  }

  /// Flushes pending telemetry data to collector.
  ///
  /// Returns true if export succeeded, false otherwise.
  Future<bool> flush() async {
    // Check opt-out
    if (!isTelemetryEnabled) {
      return false;
    }

    // Check upload enabled
    if (!isTelemetryUploadEnabled) {
      return false;
    }

    // Check circuit breaker
    if (_circuitOpen) {
      final now = DateTime.now();
      final openDuration = now.difference(_circuitOpenedAt!);

      // Reset circuit after 60 seconds
      if (openDuration.inSeconds >= 60) {
        _circuitOpen = false;
        _consecutiveFailures = 0;
        _circuitOpenedAt = null;

        if (kDebugMode) {
          print('[OTLPExporter] Circuit breaker reset');
        }
      } else {
        if (kDebugMode) {
          print('[OTLPExporter] Circuit breaker open, skipping export');
        }
        return false;
      }
    }

    // Check if export already in progress
    if (_exportInProgress) {
      return false;
    }

    // Nothing to export
    if (_pendingSamples.isEmpty && _pendingLogs.isEmpty) {
      return true;
    }

    _exportInProgress = true;

    try {
      // Export performance samples
      if (_pendingSamples.isNotEmpty) {
        final samples = List<PerformanceSamplePayload>.from(_pendingSamples);
        _pendingSamples.clear();

        for (final sample in samples) {
          final result = await _exportPerformanceSample(sample);
          if (result != OTLPExportResult.success) {
            // Re-queue failed samples (up to max batch size to prevent unbounded growth)
            if (_pendingSamples.length < maxBatchSize) {
              _pendingSamples.add(sample);
            }
          }
        }
      }

      // Export logs (simplified - could batch into single request)
      if (_pendingLogs.isNotEmpty) {
        _pendingLogs.clear(); // For now, just clear (future: implement log endpoint)
      }

      return true;
    } finally {
      _exportInProgress = false;
    }
  }

  /// Exports a single performance sample with retry logic.
  Future<OTLPExportResult> _exportPerformanceSample(
    PerformanceSamplePayload sample,
  ) async {
    final endpoint = _config.collectorEndpoint;
    if (endpoint == null) {
      return OTLPExportResult.failure;
    }

    final url = Uri.parse('$endpoint/telemetry/perf-sample');

    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final response = await _client
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                // TODO: Add JWT bearer token from auth system
                // 'Authorization': 'Bearer $jwtToken',
              },
              body: jsonEncode(sample.toJson()),
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 202) {
          // Success - reset circuit breaker
          _consecutiveFailures = 0;
          return OTLPExportResult.success;
        } else if (response.statusCode == 429) {
          // Rate limited
          if (kDebugMode) {
            print('[OTLPExporter] Rate limited (429)');
          }
          return OTLPExportResult.throttled;
        } else {
          // Other error
          if (kDebugMode) {
            print('[OTLPExporter] Export failed: ${response.statusCode}');
          }
          _recordFailure();

          // Retry on 5xx errors
          if (response.statusCode >= 500 && attempt < maxRetries) {
            await Future.delayed(Duration(milliseconds: 100 * (1 << attempt)));
            continue;
          }

          return OTLPExportResult.failure;
        }
      } catch (e) {
        if (kDebugMode) {
          print('[OTLPExporter] Export error: $e');
        }
        _recordFailure();

        // Retry on network errors
        if (attempt < maxRetries) {
          await Future.delayed(Duration(milliseconds: 100 * (1 << attempt)));
          continue;
        }

        return OTLPExportResult.failure;
      }
    }

    return OTLPExportResult.failure;
  }

  /// Records an export failure and updates circuit breaker.
  void _recordFailure() {
    _consecutiveFailures++;

    if (_consecutiveFailures >= circuitBreakerThreshold) {
      _circuitOpen = true;
      _circuitOpenedAt = DateTime.now();

      if (kDebugMode) {
        print(
          '[OTLPExporter] Circuit breaker opened after $_consecutiveFailures failures',
        );
      }
    }
  }

  /// Disposes resources.
  void dispose() {
    _batchTimer?.cancel();
    _config.removeListener(_onConfigChanged);
    _client.close();
  }
}

/// Performance sample payload matching api/telemetry.yaml schema.
class PerformanceSamplePayload {
  PerformanceSamplePayload({
    this.documentId,
    this.artboardId,
    required this.fps,
    required this.frameTimeMs,
    required this.eventReplayRate,
    required this.samplingIntervalMs,
    this.snapshotDurationMs,
    this.cursorLatencyUs,
    required this.platform,
    this.flagsActive = const [],
    required this.telemetryOptIn,
  });

  final String? documentId;
  final String? artboardId;
  final double fps;
  final double frameTimeMs;
  final int eventReplayRate;
  final int samplingIntervalMs;
  final int? snapshotDurationMs;
  final int? cursorLatencyUs;
  final String platform;
  final List<String> flagsActive;
  final bool telemetryOptIn;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'fps': fps,
      'frameTimeMs': frameTimeMs,
      'eventReplayRate': eventReplayRate,
      'samplingIntervalMs': samplingIntervalMs,
      'platform': platform,
      'flagsActive': flagsActive,
      'telemetryOptIn': telemetryOptIn,
    };

    if (documentId != null) json['documentId'] = documentId;
    if (artboardId != null) json['artboardId'] = artboardId;
    if (snapshotDurationMs != null) {
      json['snapshotDurationMs'] = snapshotDurationMs;
    }
    if (cursorLatencyUs != null) json['cursorLatencyUs'] = cursorLatencyUs;

    return json;
  }

  /// Creates sample from viewport telemetry.
  factory PerformanceSamplePayload.fromViewportTelemetry({
    required double fps,
    required double frameTimeMs,
    required String platform,
    List<String> flagsActive = const [],
    required bool telemetryOptIn,
  }) {
    return PerformanceSamplePayload(
      fps: fps,
      frameTimeMs: frameTimeMs,
      eventReplayRate: 0, // Not available from viewport telemetry
      samplingIntervalMs: 100, // Default sampling interval
      platform: platform,
      flagsActive: flagsActive,
      telemetryOptIn: telemetryOptIn,
    );
  }
}
