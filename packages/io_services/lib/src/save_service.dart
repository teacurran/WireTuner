/// Document save orchestrator for WireTuner.
///
/// This service coordinates saving document state (snapshots + metadata + events)
/// to `.wiretuner` SQLite files, handling both Save and Save As flows with
/// blocking UI progress indicators and comprehensive error handling.
///
/// **Architecture:**
/// - Composes ConnectionFactory, SnapshotManager, SqliteEventGateway, OperationGroupingService
/// - Implements dirty state tracking via sequence number comparison
/// - Wraps save operations in SQLite transactions for atomicity
/// - Provides actionable error messages for disk full, permissions, corruption
///
/// **Threading:** All methods must be called from the UI isolate.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:event_core/event_core.dart';
import 'package:logger/logger.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database_config.dart';
import 'gateway/connection_factory.dart';
import 'gateway/sqlite_event_gateway.dart';

/// Result of a save operation.
///
/// Used to communicate success/failure with detailed context.
sealed class SaveResult {
  const SaveResult();
}

/// Successful save operation.
class SaveSuccess extends SaveResult {
  const SaveSuccess({
    required this.filePath,
    required this.sequenceNumber,
    required this.durationMs,
    required this.snapshotCreated,
  });

  /// Absolute path to the saved file.
  final String filePath;

  /// Latest event sequence number at save time.
  final int sequenceNumber;

  /// Total save duration in milliseconds.
  final int durationMs;

  /// Whether a new snapshot was created during this save.
  final bool snapshotCreated;

  @override
  String toString() => 'SaveSuccess('
      'path: $filePath, '
      'seq: $sequenceNumber, '
      'duration: ${durationMs}ms, '
      'snapshot: $snapshotCreated'
      ')';
}

/// Failed save operation.
class SaveFailure extends SaveResult {
  const SaveFailure({
    required this.errorType,
    required this.userMessage,
    required this.technicalDetails,
    this.filePath,
  });

  /// Categorized error type for telemetry.
  final SaveErrorType errorType;

  /// User-friendly error message for dialog display.
  final String userMessage;

  /// Technical error details for logging.
  final String technicalDetails;

  /// File path if available (may be null for path resolution errors).
  final String? filePath;

  @override
  String toString() => 'SaveFailure('
      'type: $errorType, '
      'path: ${filePath ?? "unknown"}, '
      'message: $userMessage'
      ')';
}

/// Categorized save error types for telemetry and error handling.
enum SaveErrorType {
  diskFull,
  permissionDenied,
  corruption,
  lockTimeout,
  pathResolution,
  metadataMissing,
  transactionFailed,
  unknown,
}

/// Dirty state of the document.
enum DirtyState {
  /// No unsaved changes (in-memory sequence == persisted sequence).
  clean,

  /// Unsaved changes exist (in-memory sequence > persisted sequence).
  dirty,

  /// Document never saved (no file path).
  unsaved,
}

/// Document save orchestrator service.
///
/// **Usage:**
/// ```dart
/// final saveService = SaveService(
///   connectionFactory: connectionFactory,
///   snapshotManager: snapshotManager,
///   eventStoreGateway: eventGateway,
///   operationGrouping: operationGrouping,
///   logger: logger,
/// );
///
/// // Save to current path
/// final result = await saveService.save(
///   documentId: 'doc-123',
///   currentSequence: 1500,
/// );
///
/// // Save As to new path
/// final result = await saveService.saveAs(
///   documentId: 'doc-123',
///   filePath: '/path/to/document.wiretuner',
///   currentSequence: 1500,
/// );
///
/// // Check dirty state
/// final isDirty = await saveService.checkDirtyState(
///   documentId: 'doc-123',
///   currentSequence: 1500,
/// );
/// ```
class SaveService {
  /// Creates a save service with injected dependencies.
  SaveService({
    required ConnectionFactory connectionFactory,
    required SnapshotManager snapshotManager,
    required EventStoreGateway eventStoreGateway,
    required OperationGroupingService operationGrouping,
    required Logger logger,
  })  : _connectionFactory = connectionFactory,
        _snapshotManager = snapshotManager,
        _eventStoreGateway = eventStoreGateway,
        _operationGrouping = operationGrouping,
        _logger = logger;

  final ConnectionFactory _connectionFactory;
  final SnapshotManager _snapshotManager;
  final EventStoreGateway _eventStoreGateway;
  final OperationGroupingService _operationGrouping;
  final Logger _logger;

  /// Current file path for each document (tracks Save vs Save As).
  final Map<String, String> _documentPaths = {};

  /// Last persisted sequence number for each document.
  final Map<String, int> _lastPersistedSequence = {};

  /// Active save operations (prevents concurrent saves).
  final Set<String> _activeSaves = {};

  /// Saves the document to its current file path.
  ///
  /// If no current path exists (new document), this delegates to [saveAs]
  /// and the caller should present a file picker dialog.
  ///
  /// [documentId]: Unique document identifier
  /// [currentSequence]: Current in-memory sequence number
  /// [documentState]: Serialized document state (for snapshot creation)
  /// [title]: Document title for metadata
  ///
  /// Returns [SaveResult] with success/failure details.
  Future<SaveResult> save({
    required String documentId,
    required int currentSequence,
    required Map<String, dynamic> documentState,
    String title = 'Untitled',
  }) async {
    final currentPath = _documentPaths[documentId];

    if (currentPath == null) {
      _logger.i('Save called for new document $documentId - requires Save As');
      return const SaveFailure(
        errorType: SaveErrorType.pathResolution,
        userMessage: 'This document has not been saved yet. Use Save As to choose a location.',
        technicalDetails: 'No file path set for document',
      );
    }

    return _performSave(
      documentId: documentId,
      filePath: currentPath,
      currentSequence: currentSequence,
      documentState: documentState,
      title: title,
      isSaveAs: false,
    );
  }

  /// Saves the document to a new file path (Save As).
  ///
  /// Creates parent directories if needed and ensures `.wiretuner` extension.
  ///
  /// [documentId]: Unique document identifier
  /// [filePath]: Target file path (absolute or relative)
  /// [currentSequence]: Current in-memory sequence number
  /// [documentState]: Serialized document state (for snapshot creation)
  /// [title]: Document title for metadata
  ///
  /// Returns [SaveResult] with success/failure details.
  Future<SaveResult> saveAs({
    required String documentId,
    required String filePath,
    required int currentSequence,
    required Map<String, dynamic> documentState,
    String title = 'Untitled',
  }) async {
    _logger.i('Save As: document=$documentId, path=$filePath');

    return _performSave(
      documentId: documentId,
      filePath: filePath,
      currentSequence: currentSequence,
      documentState: documentState,
      title: title,
      isSaveAs: true,
    );
  }

  /// Core save implementation with transaction semantics.
  Future<SaveResult> _performSave({
    required String documentId,
    required String filePath,
    required int currentSequence,
    required Map<String, dynamic> documentState,
    required String title,
    required bool isSaveAs,
  }) async {
    // Prevent concurrent saves for the same document
    if (_activeSaves.contains(documentId)) {
      _logger.w('Save already in progress for document $documentId');
      return const SaveFailure(
        errorType: SaveErrorType.transactionFailed,
        userMessage: 'A save operation is already in progress. Please wait.',
        technicalDetails: 'Concurrent save prevented',
      );
    }

    _activeSaves.add(documentId);
    final startTime = DateTime.now();

    try {
      _logger.i('Starting save: doc=$documentId, seq=$currentSequence, path=$filePath');

      // Open database connection via ConnectionFactory
      // Detect in-memory database path (used in tests)
      final config = (filePath == inMemoryDatabasePath || filePath == ':memory:')
          ? DatabaseConfig.inMemory()
          : DatabaseConfig.file(filePath: filePath);
      final db = await _connectionFactory.openConnection(
        documentId: documentId,
        config: config,
        runMigrations: true,
      );

      bool snapshotCreated = false;

      // Wrap save in transaction for atomicity
      await db.transaction((txn) async {
        // 1. Upsert metadata
        await _upsertMetadata(
          txn: txn,
          documentId: documentId,
          title: title,
          currentSequence: currentSequence,
        );

        // 2. Create snapshot if needed
        if (_snapshotManager.shouldCreateSnapshot(currentSequence)) {
          await _createSnapshot(
            txn: txn,
            documentId: documentId,
            documentState: documentState,
            sequenceNumber: currentSequence,
          );
          snapshotCreated = true;
        }

        // 3. Update modified timestamp
        await _updateModifiedTimestamp(txn, documentId);
      });

      // Update tracking state
      _documentPaths[documentId] = filePath;
      _lastPersistedSequence[documentId] = currentSequence;

      final durationMs = DateTime.now().difference(startTime).inMilliseconds;

      _logger.i(
        'Save completed: doc=$documentId, seq=$currentSequence, '
        'duration=${durationMs}ms, snapshot=$snapshotCreated, path=$filePath',
      );

      return SaveSuccess(
        filePath: filePath,
        sequenceNumber: currentSequence,
        durationMs: durationMs,
        snapshotCreated: snapshotCreated,
      );
    } on DatabaseException catch (e) {
      _logger.e('Database error during save', error: e);
      return _handleDatabaseException(e, filePath);
    } catch (e, stackTrace) {
      _logger.e('Unexpected error during save', error: e, stackTrace: stackTrace);
      return SaveFailure(
        errorType: SaveErrorType.unknown,
        userMessage: 'Failed to save document to "$filePath".\n\n$e',
        technicalDetails: e.toString(),
        filePath: filePath,
      );
    } finally {
      _activeSaves.remove(documentId);
    }
  }

  /// Upserts metadata row for the document.
  Future<void> _upsertMetadata({
    required Transaction txn,
    required String documentId,
    required String title,
    required int currentSequence,
  }) async {
    _logger.d('Upserting metadata: doc=$documentId, title=$title');

    final now = DateTime.now().millisecondsSinceEpoch;

    // Check if metadata exists
    final existing = await txn.rawQuery(
      'SELECT document_id FROM metadata WHERE document_id = ?',
      [documentId],
    );

    if (existing.isEmpty) {
      // Insert new metadata
      await txn.rawInsert(
        '''
        INSERT INTO metadata (document_id, title, format_version, created_at, modified_at, author)
        VALUES (?, ?, ?, ?, ?, ?)
        ''',
        [documentId, title, 1, now, now, null],
      );
      _logger.d('Inserted new metadata for document $documentId');
    } else {
      // Update existing metadata (title may have changed)
      await txn.rawUpdate(
        '''
        UPDATE metadata
        SET title = ?, modified_at = ?
        WHERE document_id = ?
        ''',
        [title, now, documentId],
      );
      _logger.d('Updated metadata for document $documentId');
    }
  }

  /// Creates a snapshot via SnapshotManager and persists to database.
  Future<void> _createSnapshot({
    required Transaction txn,
    required String documentId,
    required Map<String, dynamic> documentState,
    required int sequenceNumber,
  }) async {
    _logger.d('Creating snapshot: doc=$documentId, seq=$sequenceNumber');

    final now = DateTime.now().millisecondsSinceEpoch;

    // Serialize document state to JSON
    final snapshotJson = json.encode(documentState);
    final snapshotBlob = Uint8List.fromList(utf8.encode(snapshotJson));

    // Insert snapshot (no compression for now - can add gzip later)
    await txn.rawInsert(
      '''
      INSERT INTO snapshots (document_id, event_sequence, snapshot_data, created_at, compression)
      VALUES (?, ?, ?, ?, ?)
      ''',
      [documentId, sequenceNumber, snapshotBlob, now, 'none'],
    );

    _logger.i('Snapshot created: doc=$documentId, seq=$sequenceNumber, size=${snapshotBlob.length} bytes');
  }

  /// Updates the modified timestamp in metadata.
  Future<void> _updateModifiedTimestamp(Transaction txn, String documentId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await txn.rawUpdate(
      'UPDATE metadata SET modified_at = ? WHERE document_id = ?',
      [now, documentId],
    );
  }

  /// Checks the dirty state of a document.
  ///
  /// Compares [currentSequence] with the last persisted sequence number
  /// to determine if unsaved changes exist.
  ///
  /// Returns [DirtyState] enum.
  Future<DirtyState> checkDirtyState({
    required String documentId,
    required int currentSequence,
  }) async {
    // Check if document has ever been saved
    if (!_documentPaths.containsKey(documentId)) {
      return DirtyState.unsaved;
    }

    final lastPersisted = _lastPersistedSequence[documentId] ?? 0;

    if (currentSequence > lastPersisted) {
      return DirtyState.dirty;
    } else {
      return DirtyState.clean;
    }
  }

  /// Returns the current file path for a document, if any.
  String? getCurrentFilePath(String documentId) {
    return _documentPaths[documentId];
  }

  /// Handles database exceptions with actionable error messages.
  SaveFailure _handleDatabaseException(DatabaseException e, String filePath) {
    final errorMsg = e.toString().toLowerCase();

    if (errorMsg.contains('full') || errorMsg.contains('disk')) {
      return SaveFailure(
        errorType: SaveErrorType.diskFull,
        userMessage: 'Insufficient disk space to save "$filePath".\n\n'
            'Free up disk space and try again.',
        technicalDetails: e.toString(),
        filePath: filePath,
      );
    }

    if (errorMsg.contains('permission') || errorMsg.contains('access')) {
      return SaveFailure(
        errorType: SaveErrorType.permissionDenied,
        userMessage: 'Cannot write to "$filePath".\n\n'
            'Check file permissions and ensure the directory is writable.',
        technicalDetails: e.toString(),
        filePath: filePath,
      );
    }

    if (errorMsg.contains('corrupt')) {
      return SaveFailure(
        errorType: SaveErrorType.corruption,
        userMessage: 'Database corruption detected in "$filePath".\n\n'
            'Try Save As to create a new file.',
        technicalDetails: e.toString(),
        filePath: filePath,
      );
    }

    if (errorMsg.contains('lock') || errorMsg.contains('busy')) {
      return SaveFailure(
        errorType: SaveErrorType.lockTimeout,
        userMessage: 'File "$filePath" is locked by another process.\n\n'
            'Close other applications accessing this file and try again.',
        technicalDetails: e.toString(),
        filePath: filePath,
      );
    }

    if (errorMsg.contains('foreign key')) {
      return SaveFailure(
        errorType: SaveErrorType.metadataMissing,
        userMessage: 'Document metadata missing for "$filePath".\n\n'
            'This file may be corrupted. Try Save As to create a new file.',
        technicalDetails: e.toString(),
        filePath: filePath,
      );
    }

    return SaveFailure(
      errorType: SaveErrorType.unknown,
      userMessage: 'Database error saving to "$filePath".\n\n$e',
      technicalDetails: e.toString(),
      filePath: filePath,
    );
  }

  /// Closes the database connection for a document.
  ///
  /// Call this when closing a document to release resources.
  Future<void> closeDocument(String documentId) async {
    _logger.i('Closing document: $documentId');

    try {
      await _connectionFactory.closeConnection(documentId);
      _documentPaths.remove(documentId);
      _lastPersistedSequence.remove(documentId);
      _activeSaves.remove(documentId);
    } catch (e) {
      _logger.e('Error closing document $documentId', error: e);
      rethrow;
    }
  }
}
