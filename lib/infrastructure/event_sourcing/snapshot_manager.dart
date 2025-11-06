import 'dart:typed_data';

import 'package:logger/logger.dart';

import '../persistence/snapshot_store.dart';
import 'snapshot_serializer.dart';

/// Orchestrates snapshot creation for the event sourcing system.
///
/// The SnapshotManager determines when snapshots should be created based on
/// event count and handles the serialization and persistence workflow.
///
/// **Snapshot Frequency**: Every 1000 events (configurable)
/// **Compression**: gzip enabled by default (10:1 compression ratio)
/// **Storage**: Uses SnapshotStore for SQLite persistence
///
/// **Usage Example:**
/// ```dart
/// final manager = SnapshotManager(
///   snapshotStore: snapshotStore,
///   snapshotFrequency: 1000,
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
  final Logger _logger = Logger();

  /// Creates a SnapshotManager.
  ///
  /// Parameters:
  /// - [snapshotStore]: Repository for persisting snapshots to SQLite
  /// - [snapshotFrequency]: Number of events between snapshots (default: 1000)
  /// - [enableCompression]: Whether to compress snapshots with gzip (default: true)
  SnapshotManager({
    required SnapshotStore snapshotStore,
    this.snapshotFrequency = 1000,
    bool enableCompression = true,
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

    try {
      // Step 1: Serialize document (JSON + gzip compression)
      final Uint8List snapshotData = _serializer.serialize(document);

      _logger.d(
        'Snapshot serialized: ${snapshotData.length} bytes '
        '(compression: ${_serializer.enableCompression ? "gzip" : "none"})',
      );

      // Step 2: Persist to SQLite via SnapshotStore
      final snapshotId = await _snapshotStore.insertSnapshot(
        documentId: documentId,
        eventSequence: eventSequence,
        snapshotData: snapshotData,
        compression: _serializer.enableCompression ? 'gzip' : 'none',
      );

      _logger.i(
        'Snapshot created: id=$snapshotId, doc=$documentId, seq=$eventSequence, '
        'size=${snapshotData.length} bytes',
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
}
