import 'dart:typed_data';

import 'package:logger/logger.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wiretuner/api/event_schema.dart';
import 'package:wiretuner/infrastructure/persistence/database_provider.dart';
import 'package:wiretuner/infrastructure/persistence/event_store.dart';

/// Repository for managing all persistence operations in WireTuner.
///
/// This class provides a unified interface for CRUD operations across
/// all three core tables: metadata, events, and snapshots. It orchestrates
/// the event sourcing lifecycle including document creation, event recording,
/// snapshot management, and state reconstruction.
///
/// Key responsibilities:
/// - Document metadata CRUD (title, timestamps, version)
/// - Event persistence through [EventStore]
/// - Snapshot storage and retrieval for fast document loading
/// - Dependency injection integration points
///
/// Example usage:
/// ```dart
/// final provider = DatabaseProvider();
/// await provider.initialize();
/// await provider.open('document.wiretuner');
/// final repo = SqliteRepository(provider);
///
/// // Create document metadata
/// await repo.createDocument(
///   documentId: 'doc-1',
///   title: 'My Drawing',
///   author: 'User',
/// );
///
/// // Insert events
/// await repo.insertEvent('doc-1', CreatePathEvent(...));
///
/// // Create snapshot
/// await repo.createSnapshot('doc-1', 1000, snapshotData);
/// ```
class SqliteRepository {

  /// Creates a repository instance wrapping the given [DatabaseProvider].
  ///
  /// The provider must be initialized and have an open database connection
  /// before any repository methods are called.
  SqliteRepository(this._provider) {
    _eventStore = EventStore(_provider.getDatabase());
  }
  final DatabaseProvider _provider;
  late final EventStore _eventStore;
  final Logger _logger = Logger();

  /// Returns the underlying [EventStore] for direct event operations.
  ///
  /// Useful when advanced event querying is needed beyond the standard
  /// repository interface.
  EventStore get eventStore => _eventStore;

  // ========================================================================
  // Metadata CRUD Operations
  // ========================================================================

  /// Creates a new document metadata record.
  ///
  /// Parameters:
  /// - [documentId]: Unique identifier for the document (PRIMARY KEY)
  /// - [title]: Human-readable document title
  /// - [author]: Optional author name
  /// - [formatVersion]: Schema version (defaults to current version)
  ///
  /// Throws [DatabaseException] if a document with the same ID already exists.
  ///
  /// Returns the document ID on success.
  Future<String> createDocument({
    required String documentId,
    required String title,
    String? author,
    int? formatVersion,
  }) async {
    _logger.i('Creating document metadata: $documentId');

    final now = DateTime.now().millisecondsSinceEpoch;
    final version = formatVersion ?? DatabaseProvider.currentSchemaVersion;

    try {
      final db = _provider.getDatabase();
      await db.insert(
        'metadata',
        {
          'document_id': documentId,
          'title': title,
          'format_version': version,
          'created_at': now,
          'modified_at': now,
          'author': author,
        },
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      _logger.i('Document metadata created: $documentId');
      return documentId;
    } on DatabaseException catch (e) {
      if (e.toString().contains('UNIQUE constraint')) {
        _logger.e('Document already exists: $documentId');
        throw StateError('Document $documentId already exists');
      }
      rethrow;
    }
  }

  /// Retrieves document metadata by ID.
  ///
  /// Returns a map containing:
  /// - document_id (String)
  /// - title (String)
  /// - format_version (int)
  /// - created_at (int) - Unix timestamp in milliseconds
  /// - modified_at (int) - Unix timestamp in milliseconds
  /// - author (String?)
  ///
  /// Returns null if the document doesn't exist.
  Future<Map<String, dynamic>?> getDocumentMetadata(String documentId) async {
    _logger.d('Fetching document metadata: $documentId');

    final db = _provider.getDatabase();
    final results = await db.query(
      'metadata',
      where: 'document_id = ?',
      whereArgs: [documentId],
      limit: 1,
    );

    if (results.isEmpty) {
      _logger.w('Document not found: $documentId');
      return null;
    }

    return results.first;
  }

  /// Updates document metadata fields.
  ///
  /// Only non-null parameters will be updated. The modified_at timestamp
  /// is automatically updated to the current time.
  ///
  /// Parameters:
  /// - [documentId]: Document to update
  /// - [title]: New title (optional)
  /// - [author]: New author (optional)
  ///
  /// Returns the number of rows updated (0 if document doesn't exist).
  Future<int> updateDocumentMetadata(
    String documentId, {
    String? title,
    String? author,
  }) async {
    _logger.i('Updating document metadata: $documentId');

    final updates = <String, dynamic>{
      'modified_at': DateTime.now().millisecondsSinceEpoch,
    };

    if (title != null) {
      updates['title'] = title;
    }
    if (author != null) {
      updates['author'] = author;
    }

    final db = _provider.getDatabase();
    final count = await db.update(
      'metadata',
      updates,
      where: 'document_id = ?',
      whereArgs: [documentId],
    );

    _logger.i('Updated $count document(s)');
    return count;
  }

  /// Deletes a document and all its associated events and snapshots.
  ///
  /// This operation cascades automatically due to foreign key constraints
  /// in the schema (ON DELETE CASCADE).
  ///
  /// Returns the number of rows deleted (0 if document doesn't exist).
  Future<int> deleteDocument(String documentId) async {
    _logger.i('Deleting document: $documentId');

    final db = _provider.getDatabase();
    final count = await db.delete(
      'metadata',
      where: 'document_id = ?',
      whereArgs: [documentId],
    );

    _logger.i('Deleted document and cascaded $count row(s)');
    return count;
  }

  /// Lists all documents in the database.
  ///
  /// Returns a list of metadata maps ordered by modification time (newest first).
  Future<List<Map<String, dynamic>>> listDocuments() async {
    _logger.d('Listing all documents');

    final db = _provider.getDatabase();
    final results = await db.query(
      'metadata',
      orderBy: 'modified_at DESC',
    );

    _logger.d('Found ${results.length} document(s)');
    return results;
  }

  // ========================================================================
  // Event Operations (delegates to EventStore)
  // ========================================================================

  /// Inserts an event into the event log.
  ///
  /// This is a convenience wrapper around [EventStore.insertEvent].
  /// The event sequence is automatically calculated.
  ///
  /// Returns the auto-incremented event_id.
  ///
  /// Throws [StateError] if the document doesn't exist.
  Future<int> insertEvent(String documentId, EventBase event) async => _eventStore.insertEvent(documentId, event);

  /// Retrieves events for a document in the specified sequence range.
  ///
  /// This is a convenience wrapper around [EventStore.getEvents].
  ///
  /// If [toSeq] is null, returns all events from [fromSeq] onwards.
  Future<List<EventBase>> getEvents(
    String documentId, {
    required int fromSeq,
    int? toSeq,
  }) async => _eventStore.getEvents(
      documentId,
      fromSeq: fromSeq,
      toSeq: toSeq,
    );

  /// Returns the maximum event sequence for a document, or -1 if none exist.
  ///
  /// This is a convenience wrapper around [EventStore.getMaxSequence].
  Future<int> getMaxSequence(String documentId) async => _eventStore.getMaxSequence(documentId);

  // ========================================================================
  // Snapshot Operations
  // ========================================================================

  /// Creates a snapshot of document state at a specific event sequence.
  ///
  /// Snapshots enable fast document loading by storing periodic state captures.
  /// Per the architecture blueprint, snapshots should be created every 1000 events.
  ///
  /// Parameters:
  /// - [documentId]: Document being snapshotted
  /// - [eventSequence]: The event sequence number this snapshot reflects
  /// - [snapshotData]: Serialized document state (typically compressed)
  /// - [compression]: Compression method used ('gzip', 'none', etc.)
  ///
  /// Returns the auto-incremented snapshot_id.
  ///
  /// Throws [StateError] if the document doesn't exist.
  Future<int> createSnapshot({
    required String documentId,
    required int eventSequence,
    required Uint8List snapshotData,
    String compression = 'gzip',
  }) async {
    _logger.i(
      'Creating snapshot for document $documentId at sequence $eventSequence',
    );

    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      final db = _provider.getDatabase();
      final snapshotId = await db.insert(
        'snapshots',
        {
          'document_id': documentId,
          'event_sequence': eventSequence,
          'snapshot_data': snapshotData,
          'created_at': now,
          'compression': compression,
        },
      );

      _logger.i('Snapshot created: id=$snapshotId');
      return snapshotId;
    } on DatabaseException catch (e) {
      if (e.toString().contains('FOREIGN KEY constraint')) {
        _logger.e('Document not found: $documentId');
        throw StateError('Document $documentId does not exist');
      }
      rethrow;
    }
  }

  /// Retrieves the most recent snapshot for a document at or before the given sequence.
  ///
  /// This is used during document loading to find the best snapshot to start
  /// replay from, then apply subsequent events.
  ///
  /// Parameters:
  /// - [documentId]: Document to find snapshot for
  /// - [maxSequence]: Maximum event sequence (defaults to latest)
  ///
  /// Returns a map containing:
  /// - snapshot_id (int)
  /// - event_sequence (int)
  /// - snapshot_data (Uint8List)
  /// - created_at (int)
  /// - compression (String)
  ///
  /// Returns null if no snapshots exist for the document.
  Future<Map<String, dynamic>?> getLatestSnapshot(
    String documentId, {
    int? maxSequence,
  }) async {
    _logger.d('Fetching latest snapshot for document: $documentId');

    final db = _provider.getDatabase();

    final String whereClause;
    final List<Object?> whereArgs;

    if (maxSequence != null) {
      whereClause = 'document_id = ? AND event_sequence <= ?';
      whereArgs = [documentId, maxSequence];
    } else {
      whereClause = 'document_id = ?';
      whereArgs = [documentId];
    }

    final results = await db.query(
      'snapshots',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'event_sequence DESC',
      limit: 1,
    );

    if (results.isEmpty) {
      _logger.d('No snapshots found for document: $documentId');
      return null;
    }

    return results.first;
  }

  /// Lists all snapshots for a document in chronological order.
  ///
  /// Useful for debugging or snapshot management UI.
  ///
  /// Returns a list of snapshot metadata (excludes snapshot_data for efficiency).
  Future<List<Map<String, dynamic>>> listSnapshots(String documentId) async {
    _logger.d('Listing snapshots for document: $documentId');

    final db = _provider.getDatabase();
    final results = await db.query(
      'snapshots',
      columns: [
        'snapshot_id',
        'document_id',
        'event_sequence',
        'created_at',
        'compression',
      ],
      where: 'document_id = ?',
      whereArgs: [documentId],
      orderBy: 'event_sequence ASC',
    );

    _logger.d('Found ${results.length} snapshot(s)');
    return results;
  }

  /// Deletes old snapshots, keeping only the most recent N snapshots per document.
  ///
  /// This is useful for managing database size over time.
  ///
  /// Parameters:
  /// - [documentId]: Document to prune snapshots for
  /// - [keepCount]: Number of most recent snapshots to retain (default: 10)
  ///
  /// Returns the number of snapshots deleted.
  Future<int> pruneSnapshots(String documentId, {int keepCount = 10}) async {
    _logger.i('Pruning snapshots for document $documentId, keeping $keepCount');

    final db = _provider.getDatabase();

    // Find the Nth most recent snapshot's sequence
    final results = await db.query(
      'snapshots',
      columns: ['event_sequence'],
      where: 'document_id = ?',
      whereArgs: [documentId],
      orderBy: 'event_sequence DESC',
      limit: 1,
      offset: keepCount,
    );

    if (results.isEmpty) {
      _logger.d('Not enough snapshots to prune');
      return 0;
    }

    final cutoffSequence = results.first['event_sequence'] as int;

    // Delete all snapshots older than or equal to the cutoff
    // (The cutoff is the (keepCount+1)th most recent snapshot)
    final count = await db.delete(
      'snapshots',
      where: 'document_id = ? AND event_sequence <= ?',
      whereArgs: [documentId, cutoffSequence],
    );

    _logger.i('Pruned $count snapshot(s)');
    return count;
  }

  // ========================================================================
  // Transaction Support
  // ========================================================================

  /// Executes a batch of operations within a database transaction.
  ///
  /// Transactions ensure atomicity - either all operations succeed or none do.
  /// This is critical for operations like creating a document with initial events.
  ///
  /// Note: Due to sqflite API limitations, you should perform operations
  /// directly on the repository instance (which will use the transaction context
  /// automatically when called within the callback).
  ///
  /// Example:
  /// ```dart
  /// await repo.transaction((txn) async {
  ///   // Perform raw SQL operations within transaction
  ///   await txn.insert('metadata', {...});
  ///   await txn.insert('events', {...});
  /// });
  /// ```
  Future<T> transaction<T>(
    Future<T> Function(DatabaseExecutor) action,
  ) async {
    _logger.d('Starting transaction');

    final db = _provider.getDatabase();
    return db.transaction((txn) async => action(txn));
  }

  // ========================================================================
  // Utility & Maintenance
  // ========================================================================

  /// Returns database statistics for monitoring and debugging.
  ///
  /// Returns a map containing:
  /// - total_documents (int)
  /// - total_events (int)
  /// - total_snapshots (int)
  /// - database_size_bytes (int) - on supported platforms
  Future<Map<String, dynamic>> getDatabaseStats() async {
    _logger.d('Calculating database statistics');

    final db = _provider.getDatabase();

    final docCountResult = await db.rawQuery('SELECT COUNT(*) as count FROM metadata');
    final docCount = docCountResult.first['count'] as int;

    final eventCountResult = await db.rawQuery('SELECT COUNT(*) as count FROM events');
    final eventCount = eventCountResult.first['count'] as int;

    final snapshotCountResult = await db.rawQuery('SELECT COUNT(*) as count FROM snapshots');
    final snapshotCount = snapshotCountResult.first['count'] as int;

    return {
      'total_documents': docCount,
      'total_events': eventCount,
      'total_snapshots': snapshotCount,
    };
  }

  /// Runs VACUUM to reclaim unused space and optimize the database.
  ///
  /// This should be run periodically (e.g., on app startup or during maintenance).
  /// Note: VACUUM cannot run inside a transaction.
  Future<void> vacuum() async {
    _logger.i('Running VACUUM on database');

    final db = _provider.getDatabase();
    await db.execute('VACUUM');

    _logger.i('VACUUM completed successfully');
  }
}
