import 'dart:async';
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wiretuner/api/event_schema.dart';

/// Production-ready EventStore service adapter with SQLite WAL support.
///
/// Implements the full event store service contract from the architecture blueprint,
/// including:
/// - CRUD operations for events with artboard and operation tracking
/// - Auto-save batching with configurable thresholds
/// - WAL integrity checks and checkpoint management
/// - Support for sampled event paths
/// - Transaction-safe batch operations
///
/// **Design Notes:**
/// - Aligns with ADR-001 (Event Sourcing) and ADR-003 (SQLite Storage)
/// - Supports FR-014 (Auto-save) and FR-015 (Manual Save) workflows
/// - Uses TEXT-based event IDs matching blueprint schema (Section 3.2)
/// - Integrates with migration harness for schema evolution
///
/// **References:**
/// - Architecture Blueprint Section 3.2 (Data Model)
/// - Architecture Blueprint Section 3.7.2.3 (Data Coordination)
/// - Appendix B.1 (Event Store Schema)
class EventStoreServiceAdapter {
  EventStoreServiceAdapter(
    this._db, {
    this.autoBatchSize = 50,
    this.autoBatchTimeoutMs = 5000,
  });

  final Database _db;
  final Logger _logger = Logger();

  /// Maximum number of events to accumulate before auto-flushing batch.
  final int autoBatchSize;

  /// Maximum time in milliseconds to wait before auto-flushing batch.
  final int autoBatchTimeoutMs;

  /// Pending events awaiting batch commit.
  final List<_PendingEvent> _pendingBatch = [];

  /// Timer for auto-batch flush.
  Timer? _batchTimer;

  /// Callback invoked after successful batch commit.
  Function()? onBatchCommitted;

  /// Creates a new event in the event store.
  ///
  /// This is the primary method for persisting individual events. It:
  /// 1. Validates the event has a unique event_id
  /// 2. Calculates the next sequence number for the document
  /// 3. Inserts the event with all metadata (artboard_id, operation_id, etc.)
  /// 4. Returns the event_id on success
  ///
  /// Parameters:
  /// - [documentId]: Document to which this event belongs
  /// - [event]: Event object conforming to EventBase contract
  /// - [artboardId]: Optional artboard scope for this event
  /// - [operationId]: Optional operation grouping ID for undo/redo
  /// - [sampledPath]: Optional JSON array of sampled points for high-frequency events
  ///
  /// Throws:
  /// - [StateError] if document doesn't exist or event_id is duplicate
  /// - [DatabaseException] for other database errors
  ///
  /// **Cross-references:**
  /// - FR-014 (Auto-save): Events are persisted immediately but batched for commits
  /// - Section 3.7.2.3: Blocking transactions with commit notifications
  Future<String> createEvent(
    String documentId,
    EventBase event, {
    String? artboardId,
    String? operationId,
    String? sampledPath,
  }) async {
    _logger.d(
        'Creating event: ${event.eventType} for document: $documentId, artboard: $artboardId');

    // Get next sequence number
    final nextSeq = await _getNextSequence(documentId);

    // Serialize event payload
    final payload = json.encode(event.toJson());

    // Convert timestamp to ISO 8601 TEXT format
    final timestamp =
        DateTime.fromMillisecondsSinceEpoch(event.timestamp).toIso8601String();

    try {
      await _db.rawInsert(
        '''
        INSERT INTO events (event_id, document_id, sequence, artboard_id, timestamp, user_id, event_type, event_data, sampled_path, operation_id)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          event.eventId,
          documentId,
          nextSeq,
          artboardId,
          timestamp,
          'local-user', // TODO: Replace with actual user_id from auth context
          event.eventType,
          payload,
          sampledPath,
          operationId,
        ],
      );

      _logger.i('Event created: id=${event.eventId}, sequence=$nextSeq');

      // Update document event count
      await _updateDocumentEventCount(documentId);

      return event.eventId;
    } on DatabaseException catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('UNIQUE constraint')) {
        throw StateError(
          'Event with id ${event.eventId} already exists or sequence $nextSeq is duplicate',
        );
      }
      if (errorMsg.contains('FOREIGN KEY constraint')) {
        throw StateError('Document $documentId does not exist');
      }
      rethrow;
    }
  }

  /// Creates multiple events in a single atomic transaction with auto-save batching.
  ///
  /// This method provides efficient batch insertion with:
  /// - Single transaction for ACID compliance
  /// - Sequence number calculation done once
  /// - Optional delayed commit for auto-save workflows
  ///
  /// When [immediateCommit] is false, events are added to a pending batch
  /// and committed either:
  /// - When batch size reaches [autoBatchSize] threshold
  /// - When [autoBatchTimeoutMs] expires
  /// - When [flushBatch] is called explicitly
  ///
  /// Parameters:
  /// - [documentId]: Document to which events belong
  /// - [events]: List of events to insert
  /// - [artboardIds]: Optional list of artboard IDs (must match events length if provided)
  /// - [operationIds]: Optional list of operation IDs (must match events length if provided)
  /// - [immediateCommit]: If true, commits immediately; if false, batches for later commit
  ///
  /// Returns list of event IDs in the same order as input events.
  ///
  /// **Cross-references:**
  /// - FR-014 (Auto-save): Auto-batch mode enables periodic background saves
  /// - FR-015 (Manual Save): Immediate commit mode for user-initiated saves
  Future<List<String>> createEventsBatch(
    String documentId,
    List<EventBase> events, {
    List<String?>? artboardIds,
    List<String?>? operationIds,
    bool immediateCommit = true,
  }) async {
    if (events.isEmpty) {
      throw ArgumentError('Events list cannot be empty');
    }

    if (artboardIds != null && artboardIds.length != events.length) {
      throw ArgumentError('artboardIds length must match events length');
    }

    if (operationIds != null && operationIds.length != events.length) {
      throw ArgumentError('operationIds length must match events length');
    }

    _logger.d(
        'Batch creating ${events.length} events for document: $documentId (immediate: $immediateCommit)');

    if (!immediateCommit) {
      // Add to pending batch for later commit
      for (int i = 0; i < events.length; i++) {
        _pendingBatch.add(_PendingEvent(
          documentId: documentId,
          event: events[i],
          artboardId: artboardIds?[i],
          operationId: operationIds?[i],
        ));
      }

      // Start or reset batch timer
      _resetBatchTimer();

      // Check if batch size threshold reached
      if (_pendingBatch.length >= autoBatchSize) {
        await flushBatch();
      }

      return events.map((e) => e.eventId).toList();
    }

    // Immediate commit path
    return await _db.transaction((txn) async {
      final eventIds = <String>[];

      // Get starting sequence number once
      final maxSeqResult = await txn.rawQuery(
        'SELECT MAX(sequence) as max_seq FROM events WHERE document_id = ?',
        [documentId],
      );
      int nextSeq = (maxSeqResult.first['max_seq'] as int? ?? -1) + 1;

      // Insert each event with incrementing sequence
      for (int i = 0; i < events.length; i++) {
        final event = events[i];
        final payload = json.encode(event.toJson());
        final timestamp = DateTime.fromMillisecondsSinceEpoch(event.timestamp)
            .toIso8601String();

        try {
          await txn.rawInsert(
            '''
            INSERT INTO events (event_id, document_id, sequence, artboard_id, timestamp, user_id, event_type, event_data, sampled_path, operation_id)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''',
            [
              event.eventId,
              documentId,
              nextSeq,
              artboardIds?[i],
              timestamp,
              'local-user',
              event.eventType,
              payload,
              null, // sampled_path not supported in batch yet
              operationIds?[i],
            ],
          );

          eventIds.add(event.eventId);
          nextSeq++;
        } on DatabaseException catch (e) {
          final errorMsg = e.toString();
          if (errorMsg.contains('UNIQUE constraint')) {
            throw StateError(
              'Event ${event.eventId} already exists or sequence conflict',
            );
          }
          if (errorMsg.contains('FOREIGN KEY constraint')) {
            throw StateError('Document $documentId does not exist');
          }
          rethrow;
        }
      }

      // Update document event count
      await txn.rawUpdate(
        'UPDATE documents SET event_count = event_count + ?, modified_at = ? WHERE id = ?',
        [events.length, DateTime.now().toIso8601String(), documentId],
      );

      _logger.i(
          'Batch created ${eventIds.length} events for document $documentId');
      return eventIds;
    });
  }

  /// Flushes pending batch to database immediately.
  ///
  /// This method commits all events in [_pendingBatch] in a single transaction
  /// and resets the batch state. Called automatically when:
  /// - Batch size reaches [autoBatchSize]
  /// - Batch timeout ([autoBatchTimeoutMs]) expires
  /// - Application explicitly requests flush (e.g., before manual save)
  ///
  /// Returns the number of events committed.
  ///
  /// **Cross-references:**
  /// - FR-014: Auto-save batching for background persistence
  /// - Section 3.7.2.3: Commit notifications to InteractionEngine
  Future<int> flushBatch() async {
    if (_pendingBatch.isEmpty) {
      _logger.d('No pending events to flush');
      return 0;
    }

    _logger.i('Flushing ${_pendingBatch.length} pending events');

    // Cancel batch timer
    _batchTimer?.cancel();
    _batchTimer = null;

    // Group by document for efficient batch insertion
    final eventsByDoc = <String, List<_PendingEvent>>{};
    for (final pending in _pendingBatch) {
      eventsByDoc
          .putIfAbsent(pending.documentId, () => [])
          .add(pending);
    }

    int totalCommitted = 0;

    // Commit each document's events in a transaction
    for (final entry in eventsByDoc.entries) {
      final documentId = entry.key;
      final docEvents = entry.value;

      await createEventsBatch(
        documentId,
        docEvents.map((p) => p.event).toList(),
        artboardIds: docEvents.map((p) => p.artboardId).toList(),
        operationIds: docEvents.map((p) => p.operationId).toList(),
        immediateCommit: true,
      );

      totalCommitted += docEvents.length;
    }

    // Clear pending batch
    _pendingBatch.clear();

    _logger.i('Batch flush completed: $totalCommitted events committed');

    // Notify listeners
    onBatchCommitted?.call();

    return totalCommitted;
  }

  /// Retrieves events for a document in sequence order.
  ///
  /// Parameters:
  /// - [documentId]: Document to query
  /// - [fromSeq]: Starting sequence number (inclusive)
  /// - [toSeq]: Ending sequence number (inclusive, null = latest)
  /// - [artboardId]: Optional filter by artboard
  ///
  /// Returns list of events in ascending sequence order.
  ///
  /// **Cross-references:**
  /// - ReplayService: Uses this for snapshot restoration and delta replay
  /// - Section 3.7.2.3: Event replay with state hash verification
  Future<List<EventBase>> getEvents(
    String documentId, {
    required int fromSeq,
    int? toSeq,
    String? artboardId,
  }) async {
    _logger.d(
        'Fetching events: doc=$documentId, from=$fromSeq, to=$toSeq, artboard=$artboardId');

    final String sql;
    final List<Object?> args;

    if (artboardId != null) {
      // Filter by artboard
      if (toSeq == null) {
        sql = '''
          SELECT event_type, event_data, sampled_path FROM events
          WHERE document_id = ? AND sequence >= ? AND artboard_id = ?
          ORDER BY sequence ASC
        ''';
        args = [documentId, fromSeq, artboardId];
      } else {
        sql = '''
          SELECT event_type, event_data, sampled_path FROM events
          WHERE document_id = ? AND sequence >= ? AND sequence <= ? AND artboard_id = ?
          ORDER BY sequence ASC
        ''';
        args = [documentId, fromSeq, toSeq, artboardId];
      }
    } else {
      // No artboard filter
      if (toSeq == null) {
        sql = '''
          SELECT event_type, event_data, sampled_path FROM events
          WHERE document_id = ? AND sequence >= ?
          ORDER BY sequence ASC
        ''';
        args = [documentId, fromSeq];
      } else {
        sql = '''
          SELECT event_type, event_data, sampled_path FROM events
          WHERE document_id = ? AND sequence >= ? AND sequence <= ?
          ORDER BY sequence ASC
        ''';
        args = [documentId, fromSeq, toSeq];
      }
    }

    final result = await _db.rawQuery(sql, args);

    return result.map((row) {
      final payload = row['event_data'] as String;
      final eventType = row['event_type'] as String;
      final jsonMap = jsonDecode(payload) as Map<String, dynamic>;
      // Add eventType for polymorphic deserialization
      jsonMap['eventType'] = eventType;
      return eventFromJson(jsonMap);
    }).toList();
  }

  /// Updates an existing event's metadata.
  ///
  /// Note: Event payloads are immutable per event sourcing principles.
  /// This method only updates metadata fields like operation_id or sampled_path
  /// which may be enriched after initial creation.
  ///
  /// Parameters:
  /// - [eventId]: Event to update
  /// - [operationId]: New operation ID
  /// - [sampledPath]: New sampled path data
  ///
  /// Returns true if event was found and updated.
  Future<bool> updateEventMetadata(
    String eventId, {
    String? operationId,
    String? sampledPath,
  }) async {
    _logger.d('Updating event metadata: $eventId');

    final updates = <String>[];
    final args = <Object?>[];

    if (operationId != null) {
      updates.add('operation_id = ?');
      args.add(operationId);
    }

    if (sampledPath != null) {
      updates.add('sampled_path = ?');
      args.add(sampledPath);
    }

    if (updates.isEmpty) {
      _logger.w('No updates specified for event $eventId');
      return false;
    }

    args.add(eventId);

    final count = await _db.rawUpdate(
      'UPDATE events SET ${updates.join(', ')} WHERE event_id = ?',
      args,
    );

    return count > 0;
  }

  /// Deletes events before a given sequence number.
  ///
  /// Used for pruning old events after snapshot creation to manage database size.
  /// Should only be called after a verified snapshot exists at that sequence.
  ///
  /// **WARNING:** This is a destructive operation. Ensure snapshot exists first.
  ///
  /// **Cross-references:**
  /// - SnapshotManager: Calls this after successful snapshot creation
  /// - Section 3.7.2.3: Event pruning after snapshot creation
  Future<int> deleteEventsBefore(String documentId, int sequenceNumber) async {
    _logger.w(
        'Deleting events before sequence $sequenceNumber for document $documentId');

    final count = await _db.rawDelete(
      'DELETE FROM events WHERE document_id = ? AND sequence < ?',
      [documentId, sequenceNumber],
    );

    _logger.i('Deleted $count events before sequence $sequenceNumber');
    return count;
  }

  /// Returns the maximum sequence number for a document, or -1 if none exist.
  Future<int> getMaxSequence(String documentId) async {
    final result = await _db.rawQuery(
      'SELECT MAX(sequence) as max_seq FROM events WHERE document_id = ?',
      [documentId],
    );

    final maxSeq = result.first['max_seq'] as int?;
    return maxSeq ?? -1;
  }

  /// Performs WAL checkpoint and integrity check.
  ///
  /// This method:
  /// 1. Runs PRAGMA wal_checkpoint(TRUNCATE) to flush WAL to main DB file
  /// 2. Runs PRAGMA integrity_check to verify database integrity
  /// 3. Returns detailed integrity status
  ///
  /// Should be called:
  /// - Before critical operations (manual save, export)
  /// - Periodically via background worker
  /// - After crashes to verify recovery
  ///
  /// **Cross-references:**
  /// - NFR-REL-001: Crash resistance via WAL + integrity checks
  /// - Section 3.7.2.3: Manual integrity checks via SyncAPI
  Future<IntegrityCheckResult> performIntegrityCheck() async {
    _logger.i('Performing WAL checkpoint and integrity check...');

    try {
      // Step 1: Checkpoint WAL
      final checkpointResult = await _db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
      _logger.d('WAL checkpoint result: $checkpointResult');

      // SQLite returns: {busy, log, checkpointed}
      // where 'log' is the number of WAL frames, and 'checkpointed' is frames written
      final walPages =
          checkpointResult.isNotEmpty ? checkpointResult.first['log'] : null;
      final checkpointedPages = checkpointResult.isNotEmpty
          ? checkpointResult.first['checkpointed']
          : null;

      // Step 2: Integrity check
      final integrityResult = await _db.rawQuery('PRAGMA integrity_check');
      _logger.d('Integrity check result: $integrityResult');

      final isOk = integrityResult.length == 1 &&
          integrityResult.first.values.first == 'ok';

      if (!isOk) {
        _logger.e(
            'Integrity check FAILED: ${integrityResult.map((r) => r.values.join(', ')).join('; ')}');
      }

      return IntegrityCheckResult(
        passed: isOk,
        walPages: walPages as int?,
        checkpointedPages: checkpointedPages as int?,
        errors: isOk
            ? []
            : integrityResult
                .map((r) => r.values.join(', '))
                .toList(),
      );
    } catch (e) {
      _logger.e('Integrity check error: $e');
      return IntegrityCheckResult(
        passed: false,
        errors: ['Exception during integrity check: $e'],
      );
    }
  }

  /// Returns WAL file size and statistics.
  ///
  /// Useful for monitoring and alerting when WAL grows too large,
  /// which may indicate checkpoint failures or high write load.
  ///
  /// **Cross-references:**
  /// - TelemetryService: Reports WAL size metrics
  /// - Section 3.7.2.3: WAL size metrics trigger snapshot creation
  Future<WalStats> getWalStats() async {
    try {
      // Get page count and page size
      final pageSizeResult = await _db.rawQuery('PRAGMA page_size');
      final pageSize =
          pageSizeResult.isNotEmpty ? pageSizeResult.first.values.first as int : 4096;

      final walPagesResult = await _db.rawQuery('PRAGMA wal_autocheckpoint');
      final autoCheckpointPages = walPagesResult.isNotEmpty
          ? walPagesResult.first.values.first as int
          : 1000;

      // Get actual WAL info
      final journalModeResult = await _db.rawQuery('PRAGMA journal_mode');
      final journalMode = journalModeResult.isNotEmpty
          ? journalModeResult.first.values.first as String
          : 'unknown';

      return WalStats(
        pageSize: pageSize,
        autoCheckpointPages: autoCheckpointPages,
        journalMode: journalMode,
      );
    } catch (e) {
      _logger.e('Error getting WAL stats: $e');
      return WalStats(pageSize: 4096, autoCheckpointPages: 1000, journalMode: 'unknown');
    }
  }

  /// Helper: Gets next sequence number for a document.
  Future<int> _getNextSequence(String documentId) async {
    final maxSeq = await getMaxSequence(documentId);
    return maxSeq + 1;
  }

  /// Helper: Updates document event count after event insertion.
  Future<void> _updateDocumentEventCount(String documentId) async {
    await _db.rawUpdate(
      'UPDATE documents SET event_count = event_count + 1, modified_at = ? WHERE id = ?',
      [DateTime.now().toIso8601String(), documentId],
    );
  }

  /// Helper: Resets batch timer for auto-flush.
  void _resetBatchTimer() {
    _batchTimer?.cancel();
    _batchTimer = Timer(
      Duration(milliseconds: autoBatchTimeoutMs),
      () async {
        await flushBatch();
      },
    );
  }

  /// Disposes resources (cancels timers).
  void dispose() {
    _batchTimer?.cancel();
    _batchTimer = null;
    _pendingBatch.clear();
  }
}

/// Pending event awaiting batch commit.
class _PendingEvent {
  _PendingEvent({
    required this.documentId,
    required this.event,
    this.artboardId,
    this.operationId,
  });

  final String documentId;
  final EventBase event;
  final String? artboardId;
  final String? operationId;
}

/// Result of integrity check operation.
class IntegrityCheckResult {
  IntegrityCheckResult({
    required this.passed,
    this.walPages,
    this.checkpointedPages,
    this.errors = const [],
  });

  /// Whether integrity check passed.
  final bool passed;

  /// Number of WAL pages at checkpoint time.
  final int? walPages;

  /// Number of pages successfully checkpointed.
  final int? checkpointedPages;

  /// List of error messages (empty if passed).
  final List<String> errors;

  @override
  String toString() {
    return 'IntegrityCheckResult(passed: $passed, walPages: $walPages, checkpointed: $checkpointedPages, errors: ${errors.length})';
  }
}

/// WAL statistics for monitoring.
class WalStats {
  WalStats({
    required this.pageSize,
    required this.autoCheckpointPages,
    required this.journalMode,
  });

  /// Database page size in bytes.
  final int pageSize;

  /// Auto-checkpoint threshold in pages.
  final int autoCheckpointPages;

  /// Current journal mode (should be 'wal').
  final String journalMode;

  /// Estimated max WAL size before auto-checkpoint.
  int get maxWalSizeBytes => pageSize * autoCheckpointPages;

  @override
  String toString() {
    return 'WalStats(pageSize: $pageSize, autoCheckpoint: $autoCheckpointPages pages, mode: $journalMode, maxWal: ${maxWalSizeBytes / 1024 / 1024}MB)';
  }
}
