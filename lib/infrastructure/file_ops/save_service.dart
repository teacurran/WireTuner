import 'dart:convert';
import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wiretuner/api/event_schema.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/infrastructure/event_sourcing/snapshot_manager.dart';
import 'package:wiretuner/infrastructure/file_ops/file_picker_adapter.dart';
import 'package:wiretuner/infrastructure/file_ops/save_exceptions.dart';
import 'package:wiretuner/infrastructure/persistence/database_provider.dart';
import 'package:wiretuner/infrastructure/persistence/event_store.dart';

/// Result of a save operation.
///
/// Contains metrics and metadata about the save operation for telemetry
/// and user feedback.
class SaveResult {
  /// Creates a save result.
  const SaveResult({
    required this.success,
    required this.documentId,
    required this.eventCount,
    required this.snapshotCount,
    required this.snapshotCreated,
    required this.filePath,
    required this.fileSize,
    required this.durationMs,
  });

  /// Whether the save operation succeeded.
  final bool success;

  /// The document ID that was saved.
  final String documentId;

  /// Number of events persisted in this save.
  final int eventCount;

  /// Total number of snapshots in the database after save.
  final int snapshotCount;

  /// Whether a new snapshot was created during this save.
  final bool snapshotCreated;

  /// Absolute path where the document was saved.
  final String filePath;

  /// Size of the saved file in bytes.
  final int fileSize;

  /// Duration of the save operation in milliseconds.
  final int durationMs;

  @override
  String toString() => 'SaveResult(success: $success, documentId: $documentId, '
      'events: $eventCount, snapshots: $snapshotCount, '
      'snapshotCreated: $snapshotCreated, filePath: $filePath, '
      'fileSize: $fileSize bytes, duration: ${durationMs}ms)';
}

/// Telemetry callback for save operations.
///
/// This callback is invoked after successful save operations to report
/// metrics for monitoring and analytics.
typedef SaveTelemetryCallback = void Function({
  required String documentId,
  required int eventCount,
  required int fileSize,
  required int durationMs,
  required bool snapshotCreated,
  required double snapshotRatio,
});

/// Service for persisting documents to disk.
///
/// SaveService implements the Save Document pipeline (T033) by orchestrating:
/// - File picker dialogs for save location
/// - Metadata persistence (created_at, modified_at, title)
/// - Event batch insertion via EventStore
/// - Snapshot creation via SnapshotManager
/// - WAL checkpoint for durability
/// - Telemetry logging
///
/// ## Usage
///
/// **First Save (New Document):**
/// ```dart
/// final result = await saveService.save(
///   documentId: document.id,
///   title: document.title,
///   pendingEvents: eventRecorder.getPendingEvents(document.id),
///   filePath: null, // Triggers file picker
/// );
/// ```
///
/// **Subsequent Save (Existing Document):**
/// ```dart
/// final result = await saveService.save(
///   documentId: document.id,
///   title: document.title,
///   pendingEvents: eventRecorder.getPendingEvents(document.id),
///   filePath: currentFilePath, // Direct save
/// );
/// ```
///
/// **Save As (Copy to New Location):**
/// ```dart
/// final result = await saveService.saveAs(
///   documentId: document.id,
///   title: document.title,
///   allEvents: eventStore.getEvents(document.id, fromSeq: 0),
///   document: document,
/// );
/// ```
///
/// ## Error Handling
///
/// SaveService maps SQLite and file system errors to domain exceptions:
/// - [DiskFullException]: SQLITE_FULL (error code 13)
/// - [PermissionDeniedException]: File permission errors
/// - [InvalidFilePathException]: Path validation failures
/// - [SaveCancelledException]: User cancelled file picker
///
/// ## Atomicity Guarantees
///
/// Save operations use a single database transaction for:
/// - Metadata upsert (INSERT or UPDATE)
/// - Batch event insertion
/// - Snapshot creation (if threshold reached)
///
/// After transaction commit, a WAL checkpoint ensures durability.
class SaveService {
  /// Creates a SaveService.
  ///
  /// Parameters:
  /// - [eventStore]: Repository for event persistence
  /// - [snapshotManager]: Manager for snapshot creation
  /// - [dbProvider]: Database connection provider
  /// - [filePickerAdapter]: Abstraction for file picker dialogs
  /// - [onSaveCompleted]: Optional telemetry callback
  SaveService({
    required EventStore eventStore,
    required SnapshotManager snapshotManager,
    required DatabaseProvider dbProvider,
    required FilePickerAdapter filePickerAdapter,
    this.onSaveCompleted,
  })  : _eventStore = eventStore,
        _snapshotManager = snapshotManager,
        _dbProvider = dbProvider,
        _filePickerAdapter = filePickerAdapter;

  final EventStore _eventStore;
  final SnapshotManager _snapshotManager;
  final DatabaseProvider _dbProvider;
  final FilePickerAdapter _filePickerAdapter;
  final SaveTelemetryCallback? onSaveCompleted;
  final Logger _logger = Logger();

  /// Saves a document to disk.
  ///
  /// If [filePath] is null, prompts the user with a file picker dialog.
  /// Otherwise, saves directly to the specified path.
  ///
  /// Parameters:
  /// - [documentId]: Unique identifier for the document
  /// - [title]: Document title (shown in UI and metadata)
  /// - [pendingEvents]: Events to persist in this save
  /// - [document]: Current document state (for snapshot creation)
  /// - [filePath]: Optional path to save to (null triggers file picker)
  ///
  /// Returns [SaveResult] with metrics on success.
  ///
  /// Throws:
  /// - [SaveCancelledException]: User cancelled file picker
  /// - [InvalidFilePathException]: File path validation failed
  /// - [DiskFullException]: Insufficient disk space
  /// - [PermissionDeniedException]: Cannot write to file
  /// - [SaveException]: Other database or I/O errors
  Future<SaveResult> save({
    required String documentId,
    required String title,
    required List<EventBase> pendingEvents,
    required Document document,
    String? filePath,
  }) async {
    final startTime = DateTime.now();
    _logger.d('Starting save: documentId=$documentId, filePath=$filePath, '
        'pendingEvents=${pendingEvents.length}');

    try {
      // Step 1: Resolve file path (prompt if needed)
      String? resolvedPath = filePath;
      if (resolvedPath == null) {
        _logger.d('No file path provided, showing save dialog');
        resolvedPath = await _filePickerAdapter.showSaveDialog(
          defaultName: '$title.wiretuner',
        );

        if (resolvedPath == null) {
          _logger.i('User cancelled save dialog');
          throw const SaveCancelledException();
        }
      }

      // Step 2: Validate and normalize file path
      resolvedPath = _validateFilePath(resolvedPath);
      _logger.d('Validated file path: $resolvedPath');

      // Step 3: Ensure database is open for this file
      final db = await _ensureDatabaseOpen(resolvedPath);

      // Step 4: Perform atomic save within transaction
      bool snapshotWasCreated = false;
      int totalSnapshots = 0;

      await db.transaction((txn) async {
        // 4a. Upsert metadata (INSERT or UPDATE)
        await _upsertMetadata(
          txn,
          documentId: documentId,
          title: title,
        );

        // 4b. Insert pending events (inline to avoid nested transactions)
        if (pendingEvents.isNotEmpty) {
          _logger.d('Batch inserting ${pendingEvents.length} events for document: $documentId');

          // Get the starting sequence number
          final maxSeqResult = await txn.rawQuery(
            'SELECT MAX(event_sequence) as max_seq FROM events WHERE document_id = ?',
            [documentId],
          );
          int nextSeq = (maxSeqResult.first['max_seq'] as int? ?? -1) + 1;

          // Insert each event with incrementing sequence
          for (final event in pendingEvents) {
            final payload = jsonEncode(event.toJson());

            await txn.rawInsert(
              '''
              INSERT INTO events (document_id, event_sequence, event_type, event_payload, timestamp, user_id)
              VALUES (?, ?, ?, ?, ?, ?)
              ''',
              [documentId, nextSeq, event.eventType, payload, event.timestamp, null],
            );

            nextSeq++;
          }

          _logger.i('Inserted ${pendingEvents.length} events');
        } else {
          _logger.d('No pending events to insert');
        }

        // 4c. Check if snapshot should be created
        final maxSeqResult = await txn.rawQuery(
          'SELECT MAX(event_sequence) as max_seq FROM events WHERE document_id = ?',
          [documentId],
        );
        final maxSeq = maxSeqResult.first['max_seq'] as int? ?? -1;

        if (_snapshotManager.shouldSnapshot(maxSeq)) {
          _logger.d('Snapshot threshold reached at sequence $maxSeq');
          await _snapshotManager.createSnapshot(
            documentId: documentId,
            eventSequence: maxSeq,
            document: document,
          );
          snapshotWasCreated = true;
        }

        // 4d. Count total snapshots for telemetry
        final snapshotCountResult = await txn.rawQuery(
          'SELECT COUNT(*) as count FROM snapshots WHERE document_id = ?',
          [documentId],
        );
        totalSnapshots = snapshotCountResult.first['count'] as int;
      });

      // Step 5: Flush WAL to ensure durability
      await db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
      _logger.d('WAL checkpoint completed');

      // Step 6: Collect telemetry metrics
      final endTime = DateTime.now();
      final durationMs = endTime.difference(startTime).inMilliseconds;
      final fileInfo = await File(resolvedPath).stat();
      final fileSize = fileInfo.size;
      final snapshotRatio = totalSnapshots > 0
          ? (await _eventStore.getMaxSequence(documentId) + 1) /
              (totalSnapshots * _snapshotManager.snapshotFrequency)
          : 0.0;

      _logger.i(
        'Save completed: documentId=$documentId, path=$resolvedPath, '
        'events=${pendingEvents.length}, fileSize=$fileSize bytes, '
        'duration=${durationMs}ms, snapshotCreated=$snapshotWasCreated, '
        'totalSnapshots=$totalSnapshots, snapshotRatio=${snapshotRatio.toStringAsFixed(2)}',
      );

      // Step 7: Invoke telemetry callback
      onSaveCompleted?.call(
        documentId: documentId,
        eventCount: pendingEvents.length,
        fileSize: fileSize,
        durationMs: durationMs,
        snapshotCreated: snapshotWasCreated,
        snapshotRatio: snapshotRatio,
      );

      // Step 8: Return result
      return SaveResult(
        success: true,
        documentId: documentId,
        eventCount: pendingEvents.length,
        snapshotCount: totalSnapshots,
        snapshotCreated: snapshotWasCreated,
        filePath: resolvedPath,
        fileSize: fileSize,
        durationMs: durationMs,
      );
    } on DatabaseException catch (e, stackTrace) {
      _logger.e('Database error during save', error: e, stackTrace: stackTrace);
      _mapDatabaseException(e);
      rethrow; // Should not reach here due to _mapDatabaseException throwing
    } on FileSystemException catch (e, stackTrace) {
      _logger.e('File system error during save', error: e, stackTrace: stackTrace);
      throw PermissionDeniedException(
        'Cannot write to file: ${e.message}',
        cause: e,
      );
    } on SaveException {
      rethrow; // Already a domain exception
    } catch (e, stackTrace) {
      _logger.e('Unexpected error during save', error: e, stackTrace: stackTrace);
      throw SaveException('Unexpected error during save: $e', cause: e);
    }
  }

  /// Saves a document to a new location (Save As).
  ///
  /// This creates a complete copy of the document at a new file path,
  /// including all events and a fresh snapshot. A new document ID is
  /// generated for the copy.
  ///
  /// Parameters:
  /// - [documentId]: Original document ID
  /// - [title]: Document title
  /// - [allEvents]: All events from the original document
  /// - [document]: Current document state
  ///
  /// Returns [SaveResult] with the new document ID and metrics.
  ///
  /// Throws same exceptions as [save].
  Future<SaveResult> saveAs({
    required String documentId,
    required String title,
    required List<EventBase> allEvents,
    required Document document,
  }) async {
    final startTime = DateTime.now();
    _logger.d('Starting Save As: documentId=$documentId, events=${allEvents.length}');

    try {
      // Step 1: Prompt for new file path (always required for Save As)
      final newFilePath = await _filePickerAdapter.showSaveDialog(
        defaultName: '$title.wiretuner',
        suggestedDirectory: _dbProvider.isOpen
            ? path.dirname(_dbProvider.getDatabase().path)
            : null,
      );

      if (newFilePath == null) {
        _logger.i('User cancelled Save As dialog');
        throw const SaveCancelledException();
      }

      // Step 2: Validate file path
      final validatedPath = _validateFilePath(newFilePath);
      _logger.d('Validated Save As path: $validatedPath');

      // Step 3: Close current database if open, open new database
      if (_dbProvider.isOpen) {
        await _dbProvider.close();
      }
      final db = await _dbProvider.open(validatedPath);

      // Step 4: Generate new document ID for the copy
      final newDocumentId = 'doc-${DateTime.now().millisecondsSinceEpoch}';
      _logger.d('Generated new document ID: $newDocumentId');

      // Step 5: Perform atomic Save As within transaction
      await db.transaction((txn) async {
        // 5a. Insert metadata for new document
        await txn.insert('metadata', {
          'document_id': newDocumentId,
          'title': title,
          'format_version': 1,
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'modified_at': DateTime.now().millisecondsSinceEpoch,
          'author': null,
        });
        _logger.d('Inserted metadata for new document');

        // 5b. Copy all events to new document (inline to avoid nested transactions)
        if (allEvents.isNotEmpty) {
          _logger.d('Copying ${allEvents.length} events for document: $newDocumentId');

          int nextSeq = 0;

          // Insert each event with incrementing sequence
          for (final event in allEvents) {
            final payload = jsonEncode(event.toJson());

            await txn.rawInsert(
              '''
              INSERT INTO events (document_id, event_sequence, event_type, event_payload, timestamp, user_id)
              VALUES (?, ?, ?, ?, ?, ?)
              ''',
              [newDocumentId, nextSeq, event.eventType, payload, event.timestamp, null],
            );

            nextSeq++;
          }

          _logger.i('Copied ${allEvents.length} events to new document');
        }

        // 5c. Create initial snapshot for new document
        final maxSeqResult = await txn.rawQuery(
          'SELECT MAX(event_sequence) as max_seq FROM events WHERE document_id = ?',
          [newDocumentId],
        );
        final maxSeq = maxSeqResult.first['max_seq'] as int? ?? -1;

        await _snapshotManager.createSnapshot(
          documentId: newDocumentId,
          eventSequence: maxSeq,
          document: document,
        );
        _logger.d('Created initial snapshot for new document');
      });

      // Step 6: Flush WAL
      await db.execute('PRAGMA wal_checkpoint(TRUNCATE)');

      // Step 7: Collect metrics
      final endTime = DateTime.now();
      final durationMs = endTime.difference(startTime).inMilliseconds;
      final fileInfo = await File(validatedPath).stat();
      final fileSize = fileInfo.size;

      _logger.i(
        'Save As completed: newDocumentId=$newDocumentId, path=$validatedPath, '
        'events=${allEvents.length}, fileSize=$fileSize bytes, duration=${durationMs}ms',
      );

      // Step 8: Invoke telemetry callback
      onSaveCompleted?.call(
        documentId: newDocumentId,
        eventCount: allEvents.length,
        fileSize: fileSize,
        durationMs: durationMs,
        snapshotCreated: true,
        snapshotRatio: 1.0,
      );

      // Step 9: Return result
      return SaveResult(
        success: true,
        documentId: newDocumentId,
        eventCount: allEvents.length,
        snapshotCount: 1,
        snapshotCreated: true,
        filePath: validatedPath,
        fileSize: fileSize,
        durationMs: durationMs,
      );
    } on DatabaseException catch (e, stackTrace) {
      _logger.e('Database error during Save As', error: e, stackTrace: stackTrace);
      _mapDatabaseException(e);
      rethrow;
    } on FileSystemException catch (e, stackTrace) {
      _logger.e('File system error during Save As', error: e, stackTrace: stackTrace);
      throw PermissionDeniedException(
        'Cannot write to file: ${e.message}',
        cause: e,
      );
    } on SaveException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Unexpected error during Save As', error: e, stackTrace: stackTrace);
      throw SaveException('Unexpected error during Save As: $e', cause: e);
    }
  }

  /// Validates and normalizes a file path.
  ///
  /// - Ensures path is absolute
  /// - Adds .wiretuner extension if missing
  ///
  /// Throws [InvalidFilePathException] if validation fails.
  String _validateFilePath(String filePath) {
    // Ensure absolute path
    if (!path.isAbsolute(filePath)) {
      throw InvalidFilePathException(
        'File path must be absolute',
        providedPath: filePath,
      );
    }

    // Ensure .wiretuner extension
    if (!filePath.endsWith('.wiretuner')) {
      return '$filePath.wiretuner';
    }

    return filePath;
  }

  /// Ensures the database is open for the specified file path.
  ///
  /// If the database is already open for a different file, closes it first.
  Future<Database> _ensureDatabaseOpen(String filePath) async {
    // If database is open and matches the target path, reuse it
    if (_dbProvider.isOpen) {
      final currentPath = _dbProvider.getDatabase().path;
      if (currentPath == filePath) {
        _logger.d('Database already open for target path');
        return _dbProvider.getDatabase();
      }

      // Close database for different file
      _logger.d('Closing database for different file: $currentPath');
      await _dbProvider.close();
    }

    // Open database for target path
    _logger.d('Opening database: $filePath');
    return await _dbProvider.open(filePath);
  }

  /// Upserts metadata for a document.
  ///
  /// Inserts a new metadata row if the document doesn't exist,
  /// or updates the existing row if it does.
  Future<void> _upsertMetadata(
    Transaction txn, {
    required String documentId,
    required String title,
  }) async {
    // Check if metadata exists
    final existing = await txn.query(
      'metadata',
      where: 'document_id = ?',
      whereArgs: [documentId],
    );

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    if (existing.isEmpty) {
      // Insert new metadata
      _logger.d('Inserting new metadata for document $documentId');
      await txn.insert('metadata', {
        'document_id': documentId,
        'title': title,
        'format_version': 1,
        'created_at': timestamp,
        'modified_at': timestamp,
        'author': null,
      });
    } else {
      // Update existing metadata
      _logger.d('Updating existing metadata for document $documentId');
      await txn.update(
        'metadata',
        {
          'title': title,
          'modified_at': timestamp,
        },
        where: 'document_id = ?',
        whereArgs: [documentId],
      );
    }
  }

  /// Maps SQLite database exceptions to domain exceptions.
  ///
  /// This method always throws - it never returns normally.
  Never _mapDatabaseException(DatabaseException e) {
    final errorMsg = e.toString();

    // Check for disk full error (SQLITE_FULL = 13)
    if (errorMsg.contains('SQLITE_FULL') || errorMsg.contains('disk full')) {
      throw DiskFullException(
        'Cannot save document - disk full. '
        'Free up disk space and try again.',
        cause: e,
      );
    }

    // Check for permission/readonly errors
    if (errorMsg.contains('readonly') ||
        errorMsg.contains('permission') ||
        errorMsg.contains('SQLITE_READONLY')) {
      throw PermissionDeniedException(
        'Cannot write to file. Check file permissions.',
        cause: e,
      );
    }

    // Unknown database error
    throw SaveException('Database error: $errorMsg', cause: e);
  }
}
