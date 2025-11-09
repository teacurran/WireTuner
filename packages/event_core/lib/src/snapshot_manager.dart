/// Snapshot manager for periodic document state capture.
///
/// This module provides snapshot creation and management to enable
/// fast document loading without replaying entire event history.
library;

import 'event_store_gateway.dart';
import 'metrics_sink.dart';

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
  /// [snapshotInterval]: Events between snapshots (default: 1000)
  DefaultSnapshotManager({
    required EventStoreGateway storeGateway,
    required MetricsSink metricsSink,
    int snapshotInterval = 1000,
  })  : _storeGateway = storeGateway,
        _metricsSink = metricsSink,
        _snapshotInterval = snapshotInterval;

  final EventStoreGateway _storeGateway;
  final MetricsSink _metricsSink;
  final int _snapshotInterval;

  @override
  Future<void> createSnapshot({
    required Map<String, dynamic> documentState,
    required int sequenceNumber,
  }) async {
    // TODO(I1.T7): Implement snapshot creation
    // 1. Serialize document state to JSON
    // 2. Compress snapshot data (optional)
    // 3. Persist to storage (separate table or file)
    // 4. Record metrics (_metricsSink.recordSnapshot)

    print('[SnapshotManager] createSnapshot called: sequenceNumber=$sequenceNumber');
  }

  @override
  Future<SnapshotData?> loadSnapshot({int? maxSequence}) async {
    // TODO(I1.T7): Implement snapshot loading
    // 1. Query most recent snapshot at or before maxSequence
    // 2. Decompress snapshot data (if compressed)
    // 3. Deserialize to document state
    // 4. Record metrics (_metricsSink.recordSnapshotLoad)

    print('[SnapshotManager] loadSnapshot called: maxSequence=$maxSequence');
    return null;
  }

  @override
  Future<void> pruneSnapshotsBeforeSequence(int sequenceNumber) async {
    // TODO(I1.T7): Implement snapshot pruning
    // 1. Delete snapshots with sequenceNumber < threshold
    // 2. Retain 2-3 recent snapshots for redundancy

    print('[SnapshotManager] pruneSnapshotsBeforeSequence called: sequenceNumber=$sequenceNumber');
  }

  @override
  bool shouldCreateSnapshot(int sequenceNumber) =>
      sequenceNumber > 0 && sequenceNumber % _snapshotInterval == 0;

  @override
  int get snapshotInterval => _snapshotInterval;
}
