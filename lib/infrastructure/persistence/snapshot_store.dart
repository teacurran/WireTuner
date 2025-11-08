import 'dart:typed_data';
import 'package:logger/logger.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Repository for managing snapshot persistence in the SQLite snapshots table.
///
/// Provides CRUD operations for document snapshots, which enable fast document
/// loading by storing periodic state captures. Snapshots are created every
/// 1000 events as per the event sourcing architecture.
///
/// The store handles:
/// - Inserting compressed snapshot BLOBs with metadata
/// - Retrieving the most recent snapshot for a document
/// - Garbage collection of old snapshots to prevent unbounded storage growth
///
/// All database operations use parameterized queries to prevent SQL injection
/// and follow the dependency injection pattern (Database instance passed to constructor).
class SnapshotStore {

  /// Creates a SnapshotStore with the given database connection.
  ///
  /// The database must have the snapshots table schema already created.
  /// Use DatabaseProvider to manage database lifecycle.
  SnapshotStore(this._db);
  final Database _db;
  static final Logger _logger = Logger();

  /// Inserts a snapshot into the database and returns the snapshot_id.
  ///
  /// Snapshots are stored as compressed BLOBs with metadata that tracks
  /// which event sequence the snapshot was taken after. This enables
  /// fast document loading by replaying events from the nearest snapshot.
  ///
  /// Parameters:
  /// - [documentId]: The document this snapshot belongs to (must exist in metadata table)
  /// - [eventSequence]: The event sequence number this snapshot was taken after
  /// - [snapshotData]: Binary snapshot data (typically from SnapshotSerializer)
  /// - [compression]: Compression method used ("gzip" or "none")
  ///
  /// Returns the auto-incremented snapshot_id of the newly created snapshot.
  ///
  /// Throws [StateError] if document doesn't exist (foreign key constraint violation).
  /// This indicates a programming error - snapshots should only be created for
  /// existing documents.
  ///
  /// Example:
  /// ```dart
  /// final serializer = SnapshotSerializer(enableCompression: true);
  /// final snapshotData = serializer.serialize(document);
  /// final snapshotId = await store.insertSnapshot(
  ///   documentId: 'doc123',
  ///   eventSequence: 1000,
  ///   snapshotData: snapshotData,
  ///   compression: 'gzip',
  /// );
  /// ```
  Future<int> insertSnapshot({
    required String documentId,
    required int eventSequence,
    required Uint8List snapshotData,
    required String compression,
  }) async {
    _logger.d(
      'Inserting snapshot: doc=$documentId, seq=$eventSequence, '
      'size=${snapshotData.length} bytes, compression=$compression',
    );

    final createdAt = DateTime.now().millisecondsSinceEpoch;

    try {
      final snapshotId = await _db.rawInsert(
        '''
        INSERT INTO snapshots (document_id, event_sequence, snapshot_data, created_at, compression)
        VALUES (?, ?, ?, ?, ?)
        ''',
        [documentId, eventSequence, snapshotData, createdAt, compression],
      );

      _logger.i(
        'Snapshot inserted: id=$snapshotId, size=${snapshotData.length} bytes',
      );
      return snapshotId;
    } on DatabaseException catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('FOREIGN KEY constraint')) {
        throw StateError('Document $documentId does not exist');
      }
      rethrow;
    }
  }

  /// Returns the most recent snapshot for a document where event_sequence <= maxSequence.
  ///
  /// This is the core method for fast document loading. It finds the nearest
  /// snapshot before or at the requested sequence, allowing the system to:
  /// 1. Load the snapshot (fast)
  /// 2. Replay events from snapshot to current state (minimal events)
  ///
  /// The query uses the idx_snapshots_document index for optimal performance:
  /// - Filters by document_id
  /// - Orders by event_sequence DESC (most recent first)
  /// - Limits to 1 result (the latest snapshot)
  ///
  /// Parameters:
  /// - [documentId]: The document to find snapshot for
  /// - [maxSequence]: Only consider snapshots taken at or before this sequence
  ///
  /// Returns a Map with keys:
  /// - snapshot_id (int): Primary key
  /// - event_sequence (int): Sequence number snapshot was taken after
  /// - snapshot_data (Uint8List): Binary snapshot BLOB
  /// - created_at (int): Unix timestamp in milliseconds
  /// - compression (String): Compression method ("gzip" or "none")
  ///
  /// Returns null if no snapshot exists for this document at or before maxSequence.
  /// This is not an error - it simply means the document needs full event replay.
  ///
  /// Example:
  /// ```dart
  /// // Load document at sequence 5432
  /// final snapshot = await store.getLatestSnapshot('doc123', 5432);
  /// if (snapshot != null) {
  ///   final snapshotSeq = snapshot['event_sequence'] as int;
  ///   final snapshotData = snapshot['snapshot_data'] as Uint8List;
  ///   // Deserialize snapshot and replay events from snapshotSeq+1 to 5432
  /// } else {
  ///   // No snapshot, replay all events from sequence 0
  /// }
  /// ```
  Future<Map<String, dynamic>?> getLatestSnapshot(
    String documentId,
    int maxSequence,
  ) async {
    _logger.d('Fetching latest snapshot: doc=$documentId, maxSeq=$maxSequence');

    final result = await _db.rawQuery(
      '''
      SELECT snapshot_id, event_sequence, snapshot_data, created_at, compression
      FROM snapshots
      WHERE document_id = ? AND event_sequence <= ?
      ORDER BY event_sequence DESC
      LIMIT 1
      ''',
      [documentId, maxSequence],
    );

    if (result.isEmpty) {
      _logger.d('No snapshot found for doc=$documentId, maxSeq=$maxSequence');
      return null;
    }

    final snapshot = result.first;
    final snapshotData = snapshot['snapshot_data'] as Uint8List;
    _logger.i(
      'Snapshot found: id=${snapshot['snapshot_id']}, '
      'seq=${snapshot['event_sequence']}, size=${snapshotData.length} bytes',
    );
    return snapshot;
  }

  /// Deletes old snapshots, keeping only the most recent N snapshots per document.
  ///
  /// This implements the garbage collection strategy to prevent unbounded
  /// storage growth. Snapshots enable fast loading, but we don't need to
  /// keep every snapshot forever - keeping the most recent N provides
  /// redundancy while limiting storage overhead.
  ///
  /// The implementation uses a two-phase approach:
  /// 1. Query for the N most recent snapshots (by event_sequence DESC)
  /// 2. Delete all snapshots NOT in the keep list
  ///
  /// This ensures we always keep the most recent snapshots, which are
  /// most likely to be needed for document loading.
  ///
  /// Parameters:
  /// - [documentId]: The document to prune snapshots for
  /// - [keepCount]: Number of most recent snapshots to retain (default: 10)
  ///
  /// Returns the number of snapshots deleted (0 if fewer than keepCount exist).
  ///
  /// Note: If the document has fewer than keepCount snapshots, nothing is deleted.
  /// This is safe and expected for new documents.
  ///
  /// Example:
  /// ```dart
  /// // Keep only the 10 most recent snapshots
  /// final deleted = await store.deleteOldSnapshots('doc123', keepCount: 10);
  /// print('Pruned $deleted old snapshots');
  /// ```
  Future<int> deleteOldSnapshots(
    String documentId, {
    int keepCount = 10,
  }) async {
    _logger.d('Pruning old snapshots: doc=$documentId, keepCount=$keepCount');

    // Get snapshot IDs to keep (most recent N by event_sequence)
    final snapshotsToKeep = await _db.rawQuery(
      '''
      SELECT snapshot_id
      FROM snapshots
      WHERE document_id = ?
      ORDER BY event_sequence DESC
      LIMIT ?
      ''',
      [documentId, keepCount],
    );

    if (snapshotsToKeep.isEmpty) {
      _logger.d('No snapshots to prune for doc=$documentId');
      return 0;
    }

    // Extract snapshot IDs
    final idsToKeep =
        snapshotsToKeep.map((row) => row['snapshot_id'] as int).toList();

    // If we have fewer snapshots than keepCount, nothing to delete
    final totalSnapshots = await _db.rawQuery(
      'SELECT COUNT(*) as count FROM snapshots WHERE document_id = ?',
      [documentId],
    );
    final total = totalSnapshots.first['count'] as int;

    if (total <= keepCount) {
      _logger.d(
        'Only $total snapshots exist for doc=$documentId, '
        'nothing to delete (keepCount=$keepCount)',
      );
      return 0;
    }

    // Delete all snapshots NOT in the keep list
    final placeholders = List.filled(idsToKeep.length, '?').join(',');
    final deletedCount = await _db.rawDelete(
      '''
      DELETE FROM snapshots
      WHERE document_id = ? AND snapshot_id NOT IN ($placeholders)
      ''',
      [documentId, ...idsToKeep],
    );

    _logger.i(
      'Pruned $deletedCount old snapshots for doc=$documentId '
      '(kept ${idsToKeep.length})',
    );
    return deletedCount;
  }
}
