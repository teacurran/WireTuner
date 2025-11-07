import 'dart:typed_data';

import 'package:logger/logger.dart';

import '../persistence/snapshot_store.dart';
import 'snapshot_serializer.dart';

/// Telemetry callback type for snapshot creation events.
///
/// Parameters:
/// - documentId: The document that was snapshotted
/// - eventSequence: The event sequence of the snapshot
/// - uncompressedSize: Size in bytes before compression
/// - compressedSize: Size in bytes after compression
/// - compressionRatio: Ratio of uncompressed to compressed size
/// - durationMs: Time taken to create snapshot in milliseconds
typedef SnapshotTelemetryCallback = void Function({
  required String documentId,
  required int eventSequence,
  required int uncompressedSize,
  required int compressedSize,
  required double compressionRatio,
  required int durationMs,
});

/// Orchestrates snapshot creation for the event sourcing system.
///
/// The SnapshotManager determines when snapshots should be created based on
/// event count and handles the serialization and persistence workflow.
///
/// **Snapshot Frequency**: Every 1000 events (configurable)
/// **Compression**: gzip enabled by default (10:1 compression ratio)
/// **Storage**: Uses SnapshotStore for SQLite persistence
/// **Telemetry**: Exposes hooks for monitoring snapshot performance and compression metrics
///
/// **Usage Example:**
/// ```dart
/// final manager = SnapshotManager(
///   snapshotStore: snapshotStore,
///   snapshotFrequency: 1000,
///   onSnapshotCreated: (
///     documentId: documentId,
///     eventSequence: seq,
///     uncompressedSize: uncompressed,
///     compressedSize: compressed,
///     compressionRatio: ratio,
///     durationMs: duration,
///   ) {
///     print('Snapshot created in ${duration}ms with ${ratio}x compression');
///   },
/// );
///
/// // Check if snapshot needed
/// if (manager.shouldSnapshot(eventCount)) {
///   await manager.createSnapshot(
///     documentId: 'doc-123',
///     eventSequence: eventCount,
///     document: currentDocument,
///   );
/// }
/// ```
class SnapshotManager {
  final SnapshotStore _snapshotStore;
  final SnapshotSerializer _serializer;
  final int snapshotFrequency;
  final SnapshotTelemetryCallback? onSnapshotCreated;
  final Logger _logger = Logger();

  // Telemetry counters
  int _totalSnapshotsCreated = 0;
  int _eventsProcessedSinceLastSnapshot = 0;

  /// Creates a SnapshotManager.
  ///
  /// Parameters:
  /// - [snapshotStore]: Repository for persisting snapshots to SQLite
  /// - [snapshotFrequency]: Number of events between snapshots (default: 1000)
  /// - [enableCompression]: Whether to compress snapshots with gzip (default: true)
  /// - [onSnapshotCreated]: Optional callback for telemetry on snapshot creation
  SnapshotManager({
    required SnapshotStore snapshotStore,
    this.snapshotFrequency = 1000,
    bool enableCompression = true,
    this.onSnapshotCreated,
  })  : _snapshotStore = snapshotStore,
        _serializer = SnapshotSerializer(enableCompression: enableCompression);

  /// Determines if a snapshot should be created based on event count.
  ///
  /// Returns true if eventCount is a multiple of snapshotFrequency.
  ///
  /// Example:
  /// ```dart
  /// shouldSnapshot(999)  → false
  /// shouldSnapshot(1000) → true
  /// shouldSnapshot(1001) → false
  /// shouldSnapshot(2000) → true
  /// ```
  bool shouldSnapshot(int eventCount) {
    if (eventCount <= 0) {
      return false; // No snapshots for non-positive event counts
    }

    final shouldCreate = eventCount % snapshotFrequency == 0;

    if (shouldCreate) {
      _logger.d(
        'Snapshot needed at event $eventCount (frequency: $snapshotFrequency)',
      );
    }

    return shouldCreate;
  }

  /// Creates and persists a snapshot of the current document state.
  ///
  /// This method:
  /// 1. Serializes the document using SnapshotSerializer (with gzip compression)
  /// 2. Persists the snapshot to SQLite via SnapshotStore
  /// 3. Logs snapshot creation with size and compression info
  ///
  /// Parameters:
  /// - [documentId]: The document this snapshot belongs to
  /// - [eventSequence]: The event sequence number this snapshot was taken after
  /// - [document]: The current document state to snapshot (can be Map or object with toJson())
  ///
  /// Throws [StateError] if document doesn't exist in metadata table.
  ///
  /// Example:
  /// ```dart
  /// await manager.createSnapshot(
  ///   documentId: 'doc-123',
  ///   eventSequence: 1000,
  ///   document: currentDocument,
  /// );
  /// ```
  Future<void> createSnapshot({
    required String documentId,
    required int eventSequence,
    required dynamic document,
  }) async {
    _logger.d('Creating snapshot: doc=$documentId, seq=$eventSequence');

    final startTime = DateTime.now();

    try {
      // Step 1: Serialize document to uncompressed JSON first (for telemetry)
      final uncompressedData = _serializer.serializeToJson(document);
      final uncompressedSize = uncompressedData.length;

      // Step 2: Apply compression if enabled
      final Uint8List snapshotData = _serializer.serialize(document);
      final compressedSize = snapshotData.length;

      _logger.d(
        'Snapshot serialized: $compressedSize bytes '
        '(compression: ${_serializer.enableCompression ? "gzip" : "none"})',
      );

      // Step 3: Persist to SQLite via SnapshotStore
      final snapshotId = await _snapshotStore.insertSnapshot(
        documentId: documentId,
        eventSequence: eventSequence,
        snapshotData: snapshotData,
        compression: _serializer.enableCompression ? 'gzip' : 'none',
      );

      // Calculate telemetry metrics
      final endTime = DateTime.now();
      final durationMs = endTime.difference(startTime).inMilliseconds;
      final compressionRatio = uncompressedSize / compressedSize;

      // Update counters
      _totalSnapshotsCreated++;
      final eventsSinceLastSnapshot = eventSequence - _eventsProcessedSinceLastSnapshot;
      _eventsProcessedSinceLastSnapshot = eventSequence;

      _logger.i(
        'Snapshot created: id=$snapshotId, doc=$documentId, seq=$eventSequence, '
        'size=$compressedSize bytes, ratio=${compressionRatio.toStringAsFixed(2)}x, '
        'duration=${durationMs}ms, events_since_last=$eventsSinceLastSnapshot',
      );

      // Invoke telemetry callback if provided
      onSnapshotCreated?.call(
        documentId: documentId,
        eventSequence: eventSequence,
        uncompressedSize: uncompressedSize,
        compressedSize: compressedSize,
        compressionRatio: compressionRatio,
        durationMs: durationMs,
      );
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to create snapshot: doc=$documentId, seq=$eventSequence',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow; // Re-throw to allow caller to handle error
    }
  }

  /// Returns the total number of snapshots created by this manager instance.
  ///
  /// This metric is useful for monitoring snapshot creation frequency and system health.
  int get totalSnapshotsCreated => _totalSnapshotsCreated;

  /// Returns the number of events processed since the last snapshot.
  ///
  /// This metric helps track progress toward the next snapshot threshold.
  int get eventsProcessedSinceLastSnapshot => _eventsProcessedSinceLastSnapshot;
}
