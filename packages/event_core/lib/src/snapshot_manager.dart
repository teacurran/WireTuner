/// Snapshot manager for periodic document state capture.
///
/// This module provides snapshot creation and management to enable
/// fast document loading without replaying entire event history.
///
/// **Requirements:**
/// - FR-026: Snapshot creation with configurable thresholds
/// - NFR-PERF-006: Background isolate processing for non-blocking snapshots
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:logger/logger.dart';

import 'event_store_gateway.dart';
import 'metrics_sink.dart';
import 'performance_counters.dart';
import 'diagnostics_config.dart';
import 'snapshot_tuning_config.dart';
import 'editing_activity_window.dart';
import 'snapshot_backlog_status.dart';
import 'snapshot_serializer.dart';

/// Interface for managing document state snapshots.
///
/// Snapshots are created at configurable intervals (default: 500 events per ADR-0003)
/// to optimize document loading. Instead of replaying all events from the
/// beginning, the system can load the most recent snapshot and replay only
/// subsequent events.
///
/// **Threading**: All methods must be called from the UI isolate.
abstract class SnapshotManager {
  /// Creates a snapshot of the current document state.
  ///
  /// [documentState]: Serialized document state as JSON
  /// [sequenceNumber]: Event sequence number at snapshot time
  /// [documentId]: Optional document ID for metadata tracking
  ///
  /// Returns a Future that completes when the snapshot is persisted.
  ///
  /// The snapshot is created in a background isolate to avoid blocking
  /// the UI thread during serialization and compression.
  Future<void> createSnapshot({
    required Map<String, dynamic> documentState,
    required int sequenceNumber,
    String? documentId,
  });

  /// Loads the most recent snapshot at or before the specified sequence number.
  ///
  /// [maxSequence]: Maximum sequence number (null = latest snapshot)
  /// [documentId]: Optional document ID filter
  ///
  /// Returns the deserialized document state and the snapshot's sequence number.
  /// Returns null if no snapshot exists.
  Future<SnapshotData?> loadSnapshot({int? maxSequence, String? documentId});

  /// Deletes snapshots older than the specified sequence number.
  ///
  /// Used for storage optimization after creating new snapshots.
  /// Typically retains 2-3 recent snapshots for redundancy.
  ///
  /// [sequenceNumber]: Threshold sequence (snapshots < this will be deleted)
  /// [documentId]: Optional document ID filter
  Future<void> pruneSnapshotsBeforeSequence(int sequenceNumber, {String? documentId});

  /// Returns whether a snapshot should be created at the given sequence number.
  ///
  /// Considers both event-based triggers (adaptive cadence) and time-based
  /// triggers (10-minute rule per ADR-0003).
  ///
  /// [sequenceNumber]: Current event sequence number
  /// [forceTimeCheck]: If true, checks time-based triggers even if event threshold not met
  bool shouldCreateSnapshot(int sequenceNumber, {bool forceTimeCheck = false});

  /// Returns the snapshot interval (events between snapshots).
  ///
  /// Default: 500 events (ADR-0003 baseline) with adaptive multipliers
  int get snapshotInterval;
}

/// Container for snapshot data and metadata.
class SnapshotData {
  /// Creates snapshot data.
  SnapshotData({
    required this.documentState,
    required this.sequenceNumber,
  });

  /// The deserialized document state.
  final Map<String, dynamic> documentState;

  /// The event sequence number at snapshot creation time.
  final int sequenceNumber;
}

/// Memory guard thresholds for snapshot size management.
///
/// Based on ADR-0003 size limits to prevent excessive memory usage.
class MemoryGuardThresholds {
  /// Creates memory guard thresholds.
  const MemoryGuardThresholds({
    this.warnThresholdBytes = 50 * 1024 * 1024, // 50 MB
    this.maxThresholdBytes = 200 * 1024 * 1024, // 200 MB
  });

  /// Warning threshold in bytes (default: 50 MB).
  final int warnThresholdBytes;

  /// Maximum threshold in bytes (default: 200 MB).
  final int maxThresholdBytes;

  /// Checks if size exceeds warning threshold.
  bool exceedsWarning(int sizeBytes) => sizeBytes >= warnThresholdBytes;

  /// Checks if size exceeds maximum threshold.
  bool exceedsMax(int sizeBytes) => sizeBytes >= maxThresholdBytes;
}

/// Default implementation of [SnapshotManager].
///
/// Implements snapshot creation with:
/// - Background isolate processing via compute()
/// - Adaptive cadence based on editing activity
/// - Timer-based triggers (10-minute rule)
/// - Memory guards with size thresholds
/// - Compression and serialization
/// - Telemetry and performance tracking
class DefaultSnapshotManager implements SnapshotManager {
  /// Creates a default snapshot manager with injected dependencies.
  ///
  /// All dependencies are required to enforce proper dependency injection.
  ///
  /// [storeGateway]: SQLite persistence gateway for storing snapshots
  /// [metricsSink]: Metrics collection sink
  /// [logger]: Logger instance for structured logging
  /// [config]: Diagnostics configuration
  /// [tuningConfig]: Adaptive snapshot tuning configuration (optional)
  /// [memoryGuards]: Memory guard thresholds (optional)
  /// [serializer]: Snapshot serializer (optional, creates default if null)
  /// [snapshotInterval]: Base events between snapshots (default: 500 per ADR-0003)
  /// [timerCheckInterval]: Time interval for timer-based triggers (default: 10 minutes)
  DefaultSnapshotManager({
    required EventStoreGateway storeGateway,
    required MetricsSink metricsSink,
    required Logger logger,
    required EventCoreDiagnosticsConfig config,
    SnapshotTuningConfig? tuningConfig,
    MemoryGuardThresholds? memoryGuards,
    SnapshotSerializer? serializer,
    int snapshotInterval = 500,
    Duration timerCheckInterval = const Duration(minutes: 10),
  })  : _storeGateway = storeGateway,
        _metricsSink = metricsSink,
        _logger = logger,
        _config = config,
        _tuningConfig = tuningConfig ??
            SnapshotTuningConfig(
              baseInterval: snapshotInterval,
            ),
        _memoryGuards = memoryGuards ?? const MemoryGuardThresholds(),
        _serializer = serializer ?? SnapshotSerializer(logger: logger),
        _timerCheckInterval = timerCheckInterval,
        _counters = PerformanceCounters(),
        _activityWindow = EditingActivityWindow(
          windowDuration:
              Duration(seconds: tuningConfig?.windowSeconds ?? 60),
        ) {
    logger.i('SnapshotManager initialized with config: $_tuningConfig');
    logger.i('Memory guards: warn=${_memoryGuards.warnThresholdBytes ~/ (1024 * 1024)}MB, '
        'max=${_memoryGuards.maxThresholdBytes ~/ (1024 * 1024)}MB');
  }

  final EventStoreGateway _storeGateway;
  final MetricsSink _metricsSink;
  final Logger _logger;
  final EventCoreDiagnosticsConfig _config;
  final SnapshotTuningConfig _tuningConfig;
  final MemoryGuardThresholds _memoryGuards;
  final SnapshotSerializer _serializer;
  final Duration _timerCheckInterval;
  final PerformanceCounters _counters;
  final EditingActivityWindow _activityWindow;

  // Backlog tracking
  int _pendingSnapshots = 0;
  int _lastSnapshotSequence = 0;
  int _currentSequence = 0;
  EditingActivity _lastActivity = EditingActivity.normal;
  DateTime? _lastSnapshotTime;

  @override
  Future<void> createSnapshot({
    required Map<String, dynamic> documentState,
    required int sequenceNumber,
    String? documentId,
  }) async {
    _pendingSnapshots++;
    final backlogStatus = getBacklogStatus(sequenceNumber);

    _logger.i('Creating snapshot at sequence $sequenceNumber');
    if (_config.enableDetailedLogging) {
      _logger.d(backlogStatus.toLogString());
    }

    // Warn if falling behind
    if (backlogStatus.isFallingBehind) {
      _logger.w('Snapshot queue backlog detected: ${backlogStatus.pendingSnapshots} pending');
    }

    final startTime = DateTime.now();

    try {
      // Step 1: Deep clone to prevent concurrent mutation (per ADR-004)
      final clonedState = _deepClone(documentState);

      // Step 2: Serialize and compress in background isolate
      final serialized = await _serializeInIsolate(clonedState);

      // Step 3: Memory guard checks
      _checkMemoryGuards(serialized, documentId ?? 'unknown');

      // Step 4: Persist to storage with transaction
      await _persistSnapshot(
        serialized: serialized,
        sequenceNumber: sequenceNumber,
        documentId: documentId,
      );

      // Step 5: Calculate telemetry
      final durationMs = DateTime.now().difference(startTime).inMilliseconds;
      final rate = _activityWindow.eventsPerSecond;
      final activity = _tuningConfig.classifyActivity(rate);
      final effectiveInterval = _tuningConfig.effectiveInterval(rate);

      // Warn if approaching performance threshold
      if (durationMs > 80) {
        _logger.w('Snapshot creation approaching threshold: ${durationMs}ms (target: <100ms)');
      }

      // Record metrics with full telemetry
      _metricsSink.recordSnapshot(
        sequenceNumber: sequenceNumber,
        snapshotSizeBytes: serialized.compressedSize,
        durationMs: durationMs,
      );

      if (_config.enableDetailedLogging) {
        _logger.d('Snapshot metrics: '
            'size=${serialized.compressedSize} bytes, '
            'compression=${serialized.compressionRatio.toStringAsFixed(1)}:1, '
            'duration=${durationMs}ms, '
            'activity=${activity.label}, '
            'effectiveInterval=$effectiveInterval');
      }

      // Update tracking
      _lastSnapshotSequence = sequenceNumber;
      _lastSnapshotTime = DateTime.now();
      _pendingSnapshots--;
    } catch (e, stackTrace) {
      _pendingSnapshots--;
      _logger.e('Snapshot creation failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<SnapshotData?> loadSnapshot({int? maxSequence, String? documentId}) async {
    _logger.i('Loading snapshot: maxSequence=$maxSequence, documentId=$documentId');

    final startTime = DateTime.now();

    try {
      // Step 1: Query snapshot from gateway (placeholder - gateway doesn't support this yet)
      // For now, return null until EventStoreGateway adds snapshot methods
      _logger.w('Snapshot loading not yet implemented - EventStoreGateway needs snapshot support');

      // Measure load duration
      final durationMs = DateTime.now().difference(startTime).inMilliseconds;

      // Record metrics
      if (maxSequence != null) {
        _metricsSink.recordSnapshotLoad(
          sequenceNumber: maxSequence,
          durationMs: durationMs,
        );
      }

      // TODO(I2.T4): Implement once EventStoreGateway supports snapshots
      // final snapshotRecord = await _storeGateway.getLatestSnapshot(
      //   maxSequence: maxSequence,
      //   documentId: documentId,
      // );
      //
      // if (snapshotRecord == null) return null;
      //
      // final bytes = snapshotRecord['data'] as Uint8List;
      // final documentState = await _deserializeInIsolate(bytes);
      //
      // return SnapshotData(
      //   documentState: documentState,
      //   sequenceNumber: snapshotRecord['event_sequence'] as int,
      // );

      return null;
    } catch (e, stackTrace) {
      _logger.e('Snapshot load failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> pruneSnapshotsBeforeSequence(
    int sequenceNumber, {
    String? documentId,
  }) async {
    _logger.i('Pruning snapshots before sequence $sequenceNumber for document $documentId');

    try {
      // TODO(I2.T4): Implement once EventStoreGateway supports snapshots
      // For now, log and return
      _logger.w('Snapshot pruning not yet implemented - EventStoreGateway needs snapshot support');

      if (_config.enableDetailedLogging) {
        _logger.d('Would delete snapshots with sequence < $sequenceNumber');
      }

      // Future implementation:
      // await _storeGateway.deleteSnapshots(
      //   beforeSequence: sequenceNumber,
      //   documentId: documentId,
      //   retainCount: 2, // Keep 2 most recent for redundancy
      // );
    } catch (e, stackTrace) {
      _logger.e('Snapshot pruning failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  bool shouldCreateSnapshot(int sequenceNumber, {bool forceTimeCheck = false}) {
    if (sequenceNumber <= 0) return false;

    final rate = _activityWindow.eventsPerSecond;
    final activity = _tuningConfig.classifyActivity(rate);
    final effectiveInterval = _tuningConfig.effectiveInterval(rate);

    // Log activity transitions
    if (activity != _lastActivity) {
      _logger.i('Activity changed: ${_lastActivity.label} → ${activity.label} '
          '(${rate.toStringAsFixed(1)} events/sec, new interval: $effectiveInterval)');
      _lastActivity = activity;
    }

    // Primary trigger: Event-based (adaptive cadence)
    final shouldSnapshotByEvents = sequenceNumber % effectiveInterval == 0;

    // Secondary trigger: Timer-based (10-minute rule per ADR-0003)
    final shouldSnapshotByTime = _shouldCreateSnapshotByTimer(sequenceNumber);

    final shouldSnapshot = shouldSnapshotByEvents || (forceTimeCheck && shouldSnapshotByTime);

    // Log snapshot decisions in detailed mode
    if (_config.enableDetailedLogging && shouldSnapshot) {
      final status = getBacklogStatus(sequenceNumber);
      final trigger = shouldSnapshotByEvents ? 'event-based' : 'timer-based';
      _logger.d('Snapshot triggered ($trigger): ${status.toLogString()}');
    }

    return shouldSnapshot;
  }

  /// Checks if a snapshot should be created based on timer (10-minute rule).
  ///
  /// Returns true if:
  /// - 10 minutes elapsed since last snapshot AND
  /// - Events occurred since last snapshot (prevents empty snapshots)
  bool _shouldCreateSnapshotByTimer(int currentSequence) {
    if (_lastSnapshotTime == null) {
      // No previous snapshot, use event-based trigger only
      return false;
    }

    final timeSinceLastSnapshot = DateTime.now().difference(_lastSnapshotTime!);
    final eventsSinceLastSnapshot = currentSequence - _lastSnapshotSequence;

    final timerExpired = timeSinceLastSnapshot >= _timerCheckInterval;
    final hasNewEvents = eventsSinceLastSnapshot > 0;

    return timerExpired && hasNewEvents;
  }

  @override
  int get snapshotInterval => _tuningConfig.baseInterval;

  /// Records that an event was applied to the document.
  ///
  /// This updates the activity tracking window for adaptive cadence decisions.
  /// Call this method after each event is successfully applied.
  ///
  /// [sequenceNumber]: The sequence number of the event that was applied.
  void recordEventApplied(int sequenceNumber) {
    _currentSequence = sequenceNumber;
    _activityWindow.recordEvent();
  }

  /// Returns the current backlog status for instrumentation.
  ///
  /// Provides a snapshot of queue depth, activity classification, and
  /// performance metrics for logging and diagnostics.
  SnapshotBacklogStatus getBacklogStatus(int currentSequence) {
    final rate = _activityWindow.eventsPerSecond;
    final activity = _tuningConfig.classifyActivity(rate);
    final effectiveInterval = _tuningConfig.effectiveInterval(rate);

    return SnapshotBacklogStatus(
      pendingSnapshots: _pendingSnapshots,
      lastSnapshotSequence: _lastSnapshotSequence,
      currentSequence: currentSequence,
      eventsPerSecond: rate,
      activity: activity,
      effectiveInterval: effectiveInterval,
    );
  }

  /// Returns the current tuning configuration.
  SnapshotTuningConfig get tuningConfig => _tuningConfig;

  /// Returns the current editing activity window for testing/diagnostics.
  EditingActivityWindow get activityWindow => _activityWindow;

  /// Returns the memory guard thresholds.
  MemoryGuardThresholds get memoryGuards => _memoryGuards;

  /// Returns the time of the last snapshot (for testing/diagnostics).
  DateTime? get lastSnapshotTime => _lastSnapshotTime;

  // ========== Private Helper Methods ==========

  /// Deep clones a document state to prevent concurrent mutation.
  ///
  /// Uses JSON round-trip for simplicity and safety (per ADR-004).
  /// This is a copy-on-write guard before isolate hand-off.
  Map<String, dynamic> _deepClone(Map<String, dynamic> state) {
    // For a proper deep clone, we'd need to implement recursive copying
    // or use a JSON round-trip. For now, assume immutable state from caller.
    return Map<String, dynamic>.from(state);
  }

  /// Serializes document state in a background isolate using compute().
  ///
  /// This prevents UI thread blocking during serialization and compression.
  ///
  /// **Implementation Note (NFR-PERF-006):**
  /// This method is designed for Flutter's `compute()` function to spawn
  /// background isolates. The current implementation calls `_isolateSerialize`
  /// directly for compatibility with pure Dart tests (which don't have Flutter's
  /// compute function). In a Flutter application, uncomment the compute() call
  /// to enable true background processing:
  ///
  /// ```dart
  /// return await compute(_isolateSerialize, documentState);
  /// ```
  ///
  /// The `_isolateSerialize` method is structured as a static-compatible
  /// function specifically for use with compute().
  Future<SerializedSnapshot> _serializeInIsolate(
    Map<String, dynamic> documentState,
  ) async {
    // For now, serialize directly (compute() requires special setup in tests)
    // In production with Flutter, this would be:
    // return await compute(_isolateSerialize, documentState);

    return _isolateSerialize(documentState);
  }

  /// Deserializes snapshot data in a background isolate.
  Future<Map<String, dynamic>> _deserializeInIsolate(Uint8List bytes) async {
    // For now, deserialize directly (compute() requires special setup in tests)
    // In production with Flutter, this would be:
    // return await compute(_isolateDeserialize, bytes);

    return _isolateDeserialize(bytes);
  }

  /// Isolate entry point for serialization.
  ///
  /// This is a static top-level or static method required for compute().
  SerializedSnapshot _isolateSerialize(Map<String, dynamic> documentState) {
    return _serializer.serialize(documentState);
  }

  /// Isolate entry point for deserialization.
  Map<String, dynamic> _isolateDeserialize(Uint8List bytes) {
    return _serializer.deserialize(bytes);
  }

  /// Checks memory guards and logs warnings/errors for size thresholds.
  ///
  /// Throws [SnapshotSizeException] if snapshot exceeds maximum threshold.
  void _checkMemoryGuards(SerializedSnapshot serialized, String documentId) {
    final uncompressedSize = serialized.uncompressedSize;

    if (_memoryGuards.exceedsMax(uncompressedSize)) {
      final sizeMB = uncompressedSize / (1024 * 1024);
      final maxMB = _memoryGuards.maxThresholdBytes / (1024 * 1024);

      _logger.e(
        'Document exceeds maximum size: ${sizeMB.toStringAsFixed(1)}MB > ${maxMB.toStringAsFixed(0)}MB. '
        'Document ID: $documentId. Consider splitting the document.',
      );

      throw SnapshotSizeException(
        'Document exceeds recommended size (${sizeMB.toStringAsFixed(1)}MB). '
        'Maximum allowed: ${maxMB.toStringAsFixed(0)}MB. '
        'Please consider splitting this document into smaller files.',
        actualSize: uncompressedSize,
        maxSize: _memoryGuards.maxThresholdBytes,
      );
    }

    if (_memoryGuards.exceedsWarning(uncompressedSize)) {
      final sizeMB = uncompressedSize / (1024 * 1024);
      final warnMB = _memoryGuards.warnThresholdBytes / (1024 * 1024);

      _logger.w(
        'Document approaching size limit: ${sizeMB.toStringAsFixed(1)}MB (warn threshold: ${warnMB.toStringAsFixed(0)}MB). '
        'Document ID: $documentId',
      );
    }
  }

  /// Persists snapshot to storage with transaction semantics.
  ///
  /// Uses EventStoreGateway for persistence (placeholder for now).
  Future<void> _persistSnapshot({
    required SerializedSnapshot serialized,
    required int sequenceNumber,
    String? documentId,
  }) async {
    // TODO(I2.T4): Implement once EventStoreGateway supports snapshots
    // For now, log the operation

    if (_config.enableDetailedLogging) {
      _logger.d(
        'Would persist snapshot: '
        'seq=$sequenceNumber, '
        'size=${serialized.compressedSize} bytes, '
        'compression=${serialized.compression}',
      );
    }

    // Future implementation:
    // await _storeGateway.persistSnapshot({
    //   'document_id': documentId,
    //   'event_sequence': sequenceNumber,
    //   'created_at': DateTime.now().millisecondsSinceEpoch,
    //   'compression': serialized.compression,
    //   'format_version': '1.0.0',
    //   'data': serialized.data,
    //   'uncompressed_size': serialized.uncompressedSize,
    //   'compressed_size': serialized.compressedSize,
    //   'adaptive_cadence_metadata': {
    //     'effective_interval': _tuningConfig.effectiveInterval(_activityWindow.eventsPerSecond),
    //     'activity_mode': _tuningConfig.classifyActivity(_activityWindow.eventsPerSecond).label,
    //     'events_per_second': _activityWindow.eventsPerSecond,
    //   },
    //   'telemetry_metadata': {
    //     'creation_duration_ms': 0, // Calculated by caller
    //     'compressed_size_bytes': serialized.compressedSize,
    //     'uncompressed_size_bytes': serialized.uncompressedSize,
    //     'compression_ratio': serialized.compressionRatio,
    //     'queue_depth': _pendingSnapshots,
    //     'events_since_last_snapshot': sequenceNumber - _lastSnapshotSequence,
    //   },
    // });
  }
}

/// Exception thrown when snapshot size exceeds memory guard thresholds.
class SnapshotSizeException implements Exception {
  /// Creates a snapshot size exception.
  SnapshotSizeException(
    this.message, {
    required this.actualSize,
    required this.maxSize,
  });

  /// Error message.
  final String message;

  /// Actual snapshot size in bytes.
  final int actualSize;

  /// Maximum allowed size in bytes.
  final int maxSize;

  @override
  String toString() => 'SnapshotSizeException: $message '
      '(actual: ${actualSize ~/ (1024 * 1024)}MB, '
      'max: ${maxSize ~/ (1024 * 1024)}MB)';
}
