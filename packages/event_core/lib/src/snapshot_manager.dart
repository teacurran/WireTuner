/// Snapshot manager for periodic document state capture.
///
/// This module provides snapshot creation and management to enable
/// fast document loading without replaying entire event history.
library;

import 'package:logger/logger.dart';

import 'event_store_gateway.dart';
import 'metrics_sink.dart';
import 'performance_counters.dart';
import 'diagnostics_config.dart';

/// Interface for managing document state snapshots.
///
/// Snapshots are created at configurable intervals (default: every 1000 events)
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
  ///
  /// Returns a Future that completes when the snapshot is persisted.
  ///
  /// TODO(I1.T7): Implement snapshot serialization and persistence.
  Future<void> createSnapshot({
    required Map<String, dynamic> documentState,
    required int sequenceNumber,
  });

  /// Loads the most recent snapshot at or before the specified sequence number.
  ///
  /// [maxSequence]: Maximum sequence number (null = latest snapshot)
  ///
  /// Returns the deserialized document state and the snapshot's sequence number.
  /// Returns null if no snapshot exists.
  ///
  /// TODO(I1.T7): Implement snapshot retrieval from storage.
  Future<SnapshotData?> loadSnapshot({int? maxSequence});

  /// Deletes snapshots older than the specified sequence number.
  ///
  /// Used for storage optimization after creating new snapshots.
  /// Typically retains 2-3 recent snapshots for redundancy.
  ///
  /// TODO(I1.T7): Implement snapshot pruning logic.
  Future<void> pruneSnapshotsBeforeSequence(int sequenceNumber);

  /// Returns whether a snapshot should be created at the given sequence number.
  ///
  /// Snapshots are created at [snapshotInterval] event increments.
  /// For example, with interval=1000, snapshots are created at sequences
  /// 1000, 2000, 3000, etc.
  bool shouldCreateSnapshot(int sequenceNumber);

  /// Returns the snapshot interval (events between snapshots).
  ///
  /// Default: 1000 events
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

/// Default stub implementation of [SnapshotManager].
///
/// Logs method calls and enforces dependency injection of store gateway
/// and metrics sink.
///
/// TODO(I1.T7): Replace with full implementation that handles snapshot
/// serialization, compression, persistence, and retrieval.
class DefaultSnapshotManager implements SnapshotManager {
  /// Creates a default snapshot manager with injected dependencies.
  ///
  /// All dependencies are required to enforce proper dependency injection
  /// for future implementations.
  ///
  /// [storeGateway]: SQLite persistence gateway for storing snapshots
  /// [metricsSink]: Metrics collection sink
  /// [logger]: Logger instance for structured logging
  /// [config]: Diagnostics configuration
  /// [snapshotInterval]: Events between snapshots (default: 1000)
  DefaultSnapshotManager({
    required EventStoreGateway storeGateway,
    required MetricsSink metricsSink,
    required Logger logger,
    required EventCoreDiagnosticsConfig config,
    int snapshotInterval = 1000,
  })  : _storeGateway = storeGateway,
        _metricsSink = metricsSink,
        _logger = logger,
        _config = config,
        _snapshotInterval = snapshotInterval,
        _counters = PerformanceCounters();

  final EventStoreGateway _storeGateway;
  final MetricsSink _metricsSink;
  final Logger _logger;
  final EventCoreDiagnosticsConfig _config;
  final int _snapshotInterval;
  final PerformanceCounters _counters;

  @override
  Future<void> createSnapshot({
    required Map<String, dynamic> documentState,
    required int sequenceNumber,
  }) async {
    _logger.i('Creating snapshot at sequence $sequenceNumber');

    try {
      // TODO(I1.T7): Implement snapshot creation
      // 1. Serialize document state to JSON
      // 2. Compress snapshot data (optional)
      // 3. Persist to storage (separate table or file)

      // Measure snapshot creation duration (placeholder until I1.T7)
      final durationMs = await _counters.time('snapshot_create', () async {
        // Placeholder: actual snapshot persistence will happen in I1.T7
        if (_config.enableDetailedLogging) {
          _logger
              .d('Serializing and persisting snapshot at seq=$sequenceNumber');
        }
      });

      // Record metrics (placeholder size until I1.T7)
      _metricsSink.recordSnapshot(
        sequenceNumber: sequenceNumber,
        snapshotSizeBytes: 0, // TODO(I1.T7): Calculate actual serialized size
        durationMs: durationMs,
      );
    } catch (e, stackTrace) {
      _logger.e('Snapshot creation failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<SnapshotData?> loadSnapshot({int? maxSequence}) async {
    _logger.i('Loading snapshot: maxSequence=$maxSequence');

    try {
      // TODO(I1.T7): Implement snapshot loading
      // 1. Query most recent snapshot at or before maxSequence
      // 2. Decompress snapshot data (if compressed)
      // 3. Deserialize to document state

      // Measure snapshot load duration (placeholder until I1.T7)
      final durationMs = await _counters.time('snapshot_load', () async {
        // Placeholder: actual snapshot loading will happen in I1.T7
        if (_config.enableDetailedLogging) {
          _logger.d('Querying and deserializing snapshot');
        }
      });

      // Record metrics (placeholder until I1.T7)
      if (maxSequence != null) {
        _metricsSink.recordSnapshotLoad(
          sequenceNumber: maxSequence,
          durationMs: durationMs,
        );
      }

      return null; // TODO(I1.T7): Return actual snapshot data
    } catch (e, stackTrace) {
      _logger.e('Snapshot load failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> pruneSnapshotsBeforeSequence(int sequenceNumber) async {
    _logger.i('Pruning snapshots before sequence $sequenceNumber');

    try {
      // TODO(I1.T7): Implement snapshot pruning
      // 1. Delete snapshots with sequenceNumber < threshold
      // 2. Retain 2-3 recent snapshots for redundancy

      if (_config.enableDetailedLogging) {
        _logger.d('Deleting old snapshots before seq=$sequenceNumber');
      }
    } catch (e, stackTrace) {
      _logger.e('Snapshot pruning failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  bool shouldCreateSnapshot(int sequenceNumber) =>
      sequenceNumber > 0 && sequenceNumber % _snapshotInterval == 0;

  @override
  int get snapshotInterval => _snapshotInterval;
}
