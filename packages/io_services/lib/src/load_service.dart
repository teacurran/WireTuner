/// Document load orchestrator for WireTuner.
///
/// This service coordinates loading `.wiretuner` files, handling version
/// compatibility checking, automatic migration, snapshot-based state
/// reconstruction, and error reporting with user-friendly dialogs.
///
/// **Architecture:**
/// - Mirrors SaveService structure for consistency
/// - Composes ConnectionFactory, SnapshotManager, EventStoreGateway, EventReplayer
/// - Validates file format version before any state mutation
/// - Runs migrations via MigrationRunner when needed
/// - Reconstructs document state via snapshot + event replay
/// - Logs telemetry for version compatibility and load performance
///
/// **Threading:** All methods must be called from the UI isolate.
library;

import 'dart:async';
import 'package:event_core/event_core.dart';
import 'package:logger/logger.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database_config.dart';
import 'gateway/connection_factory.dart';
import 'gateway/sqlite_event_gateway.dart';
import 'migrations/migration_runner.dart';

/// Result of a load operation.
///
/// Used to communicate success/failure with detailed context.
sealed class LoadResult {
  const LoadResult();
}

/// Successful load operation.
class LoadSuccess extends LoadResult {
  const LoadSuccess({
    required this.filePath,
    required this.documentId,
    required this.title,
    required this.currentSequence,
    required this.durationMs,
    required this.formatVersion,
    required this.wasMigrated,
    this.degradeWarnings,
  });

  /// Absolute path to the loaded file.
  final String filePath;

  /// Document ID from metadata.
  final String documentId;

  /// Document title from metadata.
  final String title;

  /// Final event sequence number after load.
  final int currentSequence;

  /// Total load duration in milliseconds.
  final int durationMs;

  /// File format version (before migration).
  final int formatVersion;

  /// Whether automatic migration was performed.
  final bool wasMigrated;

  /// Optional warnings for downgrade scenarios (future → past version).
  final List<String>? degradeWarnings;

  @override
  String toString() => 'LoadSuccess('
      'path: $filePath, '
      'doc: $documentId, '
      'title: $title, '
      'seq: $currentSequence, '
      'duration: ${durationMs}ms, '
      'version: $formatVersion, '
      'migrated: $wasMigrated'
      ')';
}

/// Failed load operation.
class LoadFailure extends LoadResult {
  const LoadFailure({
    required this.errorType,
    required this.userMessage,
    required this.technicalDetails,
    this.filePath,
  });

  /// Categorized error type for telemetry.
  final LoadErrorType errorType;

  /// User-friendly error message for dialog display.
  final String userMessage;

  /// Technical error details for logging.
  final String technicalDetails;

  /// File path if available (may be null for path resolution errors).
  final String? filePath;

  @override
  String toString() => 'LoadFailure('
      'type: $errorType, '
      'path: ${filePath ?? "unknown"}, '
      'message: $userMessage'
      ')';
}

/// Categorized load error types for telemetry and error handling.
enum LoadErrorType {
  fileNotFound,
  permissionDenied,
  corruptedDatabase,
  unsupportedVersion,
  migrationFailed,
  snapshotCorrupted,
  replayFailed,
  metadataMissing,
  unknown,
}

/// Version compatibility verdict.
enum VersionCompatibility {
  /// Exact match - no migration needed.
  supported,

  /// Older version - automatic migration required.
  needsMigration,

  /// Future version - refuse to open.
  unsupported,
}

/// Document load orchestrator service.
///
/// **Usage:**
/// ```dart
/// final loadService = LoadService(
///   connectionFactory: connectionFactory,
///   snapshotManager: snapshotManager,
///   eventStoreGateway: eventGateway,
///   eventReplayer: eventReplayer,
///   logger: logger,
/// );
///
/// // Load existing document
/// final result = await loadService.load(
///   documentId: 'doc-123',
///   filePath: '/path/to/document.wiretuner',
/// );
///
/// // Check result
/// switch (result) {
///   case LoadSuccess(:final documentId, :final currentSequence):
///     print('Loaded $documentId at sequence $currentSequence');
///   case LoadFailure(:final userMessage):
///     showErrorDialog(userMessage);
/// }
/// ```
class LoadService {
  /// Creates a load service with injected dependencies.
  LoadService({
    required ConnectionFactory connectionFactory,
    required SnapshotManager snapshotManager,
    required EventStoreGateway Function(Database db, String documentId)
        eventStoreGatewayFactory,
    required EventReplayer eventReplayer,
    required Logger logger,
  })  : _connectionFactory = connectionFactory,
        _snapshotManager = snapshotManager,
        _eventStoreGatewayFactory = eventStoreGatewayFactory,
        _eventReplayer = eventReplayer,
        _logger = logger;

  final ConnectionFactory _connectionFactory;
  final SnapshotManager _snapshotManager;
  final EventStoreGateway Function(Database db, String documentId)
      _eventStoreGatewayFactory;
  final EventReplayer _eventReplayer;
  final Logger _logger;

  /// Current format version supported by this application.
  static const int currentFormatVersion = 1;

  /// Active load operations (prevents concurrent loads of same document).
  final Map<String, Completer<LoadResult>> _activeLoads = {};

  /// Loaded document paths (tracks which documents are open).
  final Map<String, String> _documentPaths = {};

  /// Loads a document from a `.wiretuner` file.
  ///
  /// Performs the following steps:
  /// 1. Validates file existence and permissions
  /// 2. Opens database connection
  /// 3. Checks format version compatibility
  /// 4. Runs migrations if needed
  /// 5. Validates database integrity (PRAGMA checks)
  /// 6. Loads snapshot + replays events
  /// 7. Returns LoadResult with success/failure details
  ///
  /// [documentId]: Unique document identifier (used for connection pooling)
  /// [filePath]: Path to `.wiretuner` file (absolute or relative)
  ///
  /// Returns [LoadResult] with success/failure details.
  Future<LoadResult> load({
    required String documentId,
    required String filePath,
  }) async {
    // Prevent concurrent loads for the same document
    if (_activeLoads.containsKey(documentId)) {
      _logger.w('Load already in progress for document $documentId');
      return _activeLoads[documentId]!.future;
    }

    final completer = Completer<LoadResult>();
    _activeLoads[documentId] = completer;

    try {
      final result = await _performLoad(
        documentId: documentId,
        filePath: filePath,
      );
      completer.complete(result);
      return result;
    } catch (e, stackTrace) {
      _logger.e('Unexpected error during load', error: e, stackTrace: stackTrace);
      final failure = LoadFailure(
        errorType: LoadErrorType.unknown,
        userMessage: 'Failed to load document from "$filePath".\n\n$e',
        technicalDetails: e.toString(),
        filePath: filePath,
      );
      completer.complete(failure);
      return failure;
    } finally {
      _activeLoads.remove(documentId);
    }
  }

  /// Core load implementation with error handling.
  Future<LoadResult> _performLoad({
    required String documentId,
    required String filePath,
  }) async {
    final startTime = DateTime.now();
    _logger.i('[load] Starting: doc=$documentId, path=$filePath');

    try {
      // Open database connection
      final config = DatabaseConfig.file(filePath: filePath);
      final db = await _connectionFactory.openConnection(
        documentId: documentId,
        config: config,
        runMigrations: false, // We'll run migrations manually after version check
      );

      // Perform integrity checks
      final integrityResult = await _checkIntegrity(db, filePath);
      if (integrityResult != null) {
        return integrityResult; // Corrupted database
      }

      // Check metadata exists
      final metadataResult = await _validateMetadata(db, filePath);
      if (metadataResult is LoadFailure) {
        return metadataResult;
      }

      final metadata = metadataResult as Map<String, dynamic>;
      final fileFormatVersion = metadata['format_version'] as int;
      final documentTitle = metadata['title'] as String;

      // Check version compatibility
      final compatibility = _checkVersionCompatibility(fileFormatVersion);

      _logger.i(
        '[load] doc=$documentId format=$fileFormatVersion '
        'compatibility=$compatibility source=$filePath',
      );

      // Handle unsupported versions
      if (compatibility == VersionCompatibility.unsupported) {
        return LoadFailure(
          errorType: LoadErrorType.unsupportedVersion,
          userMessage: 'Incompatible File Version\n\n'
              'This file was created with WireTuner version $fileFormatVersion or newer.\n'
              'You are running version $currentFormatVersion.\n\n'
              'Please upgrade to the latest version of WireTuner to open this file.\n\n'
              'Download: https://wiretuner.app/download',
          technicalDetails: 'File format version $fileFormatVersion > app version $currentFormatVersion',
          filePath: filePath,
        );
      }

      // Run migrations if needed
      bool wasMigrated = false;
      if (compatibility == VersionCompatibility.needsMigration) {
        _logger.i('[load] Migration required: v$fileFormatVersion → v$currentFormatVersion');
        final migrationResult = await _runMigrations(db, documentId, filePath);
        if (migrationResult is LoadFailure) {
          return migrationResult;
        }
        wasMigrated = true;
      }

      // Get maximum event sequence
      final eventGateway = _eventStoreGatewayFactory(db, documentId);
      final maxSequence = await eventGateway.getLatestSequenceNumber();

      _logger.d('[load] doc=$documentId maxSequence=$maxSequence');

      // Load snapshot and replay events
      final replayResult = await _loadAndReplay(
        documentId: documentId,
        maxSequence: maxSequence,
      );

      if (replayResult is LoadFailure) {
        return replayResult;
      }

      // Track document path
      _documentPaths[documentId] = filePath;

      final durationMs = DateTime.now().difference(startTime).inMilliseconds;

      _logger.i(
        '[load] Completed: doc=$documentId, seq=$maxSequence, '
        'duration=${durationMs}ms, migrated=$wasMigrated, path=$filePath',
      );

      return LoadSuccess(
        filePath: filePath,
        documentId: documentId,
        title: documentTitle,
        currentSequence: maxSequence,
        durationMs: durationMs,
        formatVersion: fileFormatVersion,
        wasMigrated: wasMigrated,
      );
    } on DatabaseException catch (e) {
      _logger.e('Database error during load', error: e);
      return _handleDatabaseException(e, filePath);
    }
  }

  /// Checks database integrity using PRAGMA integrity_check.
  Future<LoadFailure?> _checkIntegrity(Database db, String filePath) async {
    try {
      final result = await db.rawQuery('PRAGMA integrity_check');
      final status = result.first.values.first as String;

      if (status != 'ok') {
        _logger.e('Database integrity check failed: $status');
        return LoadFailure(
          errorType: LoadErrorType.corruptedDatabase,
          userMessage: 'Database file is corrupted and cannot be opened.\n\n'
              'File: $filePath\n\n'
              'Consider restoring from a backup.',
          technicalDetails: 'PRAGMA integrity_check returned: $status',
          filePath: filePath,
        );
      }

      _logger.d('[load] Integrity check passed for $filePath');
      return null;
    } catch (e) {
      _logger.e('Error during integrity check', error: e);
      return LoadFailure(
        errorType: LoadErrorType.corruptedDatabase,
        userMessage: 'Failed to validate database integrity.\n\n$e',
        technicalDetails: e.toString(),
        filePath: filePath,
      );
    }
  }

  /// Validates metadata table exists and has exactly one row.
  Future<dynamic> _validateMetadata(Database db, String filePath) async {
    try {
      // Check metadata table exists
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='metadata'",
      );

      if (tables.isEmpty) {
        _logger.e('Metadata table missing');
        return LoadFailure(
          errorType: LoadErrorType.metadataMissing,
          userMessage: 'Invalid .wiretuner file: missing metadata table.\n\n'
              'This file may be corrupted or was created by an incompatible version.',
          technicalDetails: 'metadata table does not exist',
          filePath: filePath,
        );
      }

      // Read metadata
      final metadata = await db.rawQuery('SELECT * FROM metadata LIMIT 1');

      if (metadata.isEmpty) {
        _logger.e('Metadata table is empty');
        return LoadFailure(
          errorType: LoadErrorType.metadataMissing,
          userMessage: 'Invalid .wiretuner file: metadata is missing.\n\n'
              'This file may be corrupted.',
          technicalDetails: 'metadata table has 0 rows',
          filePath: filePath,
        );
      }

      return metadata.first;
    } catch (e) {
      _logger.e('Error reading metadata', error: e);
      return LoadFailure(
        errorType: LoadErrorType.metadataMissing,
        userMessage: 'Failed to read document metadata.\n\n$e',
        technicalDetails: e.toString(),
        filePath: filePath,
      );
    }
  }

  /// Checks version compatibility.
  VersionCompatibility _checkVersionCompatibility(int fileFormatVersion) {
    if (fileFormatVersion == currentFormatVersion) {
      return VersionCompatibility.supported;
    } else if (fileFormatVersion < currentFormatVersion) {
      return VersionCompatibility.needsMigration;
    } else {
      return VersionCompatibility.unsupported;
    }
  }

  /// Runs database migrations.
  Future<dynamic> _runMigrations(
    Database db,
    String documentId,
    String filePath,
  ) async {
    try {
      _logger.i('[load] Running migrations for doc=$documentId');

      // Use MigrationRunner from ConnectionFactory
      final migrationRunner = MigrationRunner(db);
      await migrationRunner.runMigrations();

      _logger.i('[load] Migrations completed for doc=$documentId');
      return null; // Success
    } catch (e, stackTrace) {
      _logger.e('Migration failed', error: e, stackTrace: stackTrace);
      return LoadFailure(
        errorType: LoadErrorType.migrationFailed,
        userMessage: 'Failed to upgrade file format.\n\n'
            'The file may be from an incompatible version.\n\n'
            'Error: $e',
        technicalDetails: e.toString(),
        filePath: filePath,
      );
    }
  }

  /// Loads snapshot and replays events to reconstruct document state.
  Future<dynamic> _loadAndReplay({
    required String documentId,
    required int maxSequence,
  }) async {
    try {
      _logger.d('[load] Replaying events: doc=$documentId, maxSeq=$maxSequence');

      // Use EventReplayer to reconstruct state
      await _eventReplayer.replayFromSnapshot(maxSequence: maxSequence);

      _logger.i('[load] Replay completed: doc=$documentId');
      return null; // Success
    } catch (e, stackTrace) {
      _logger.e('Event replay failed', error: e, stackTrace: stackTrace);
      return LoadFailure(
        errorType: LoadErrorType.replayFailed,
        userMessage: 'Failed to reconstruct document state.\n\n'
            'The event history may be corrupted.\n\n'
            'Error: $e',
        technicalDetails: e.toString(),
      );
    }
  }

  /// Handles database exceptions with actionable error messages.
  LoadFailure _handleDatabaseException(DatabaseException e, String filePath) {
    final errorMsg = e.toString().toLowerCase();

    if (errorMsg.contains('not found') || errorMsg.contains('no such')) {
      return LoadFailure(
        errorType: LoadErrorType.fileNotFound,
        userMessage: 'File not found: "$filePath".\n\n'
            'The file may have been moved or deleted.',
        technicalDetails: e.toString(),
        filePath: filePath,
      );
    }

    if (errorMsg.contains('permission') || errorMsg.contains('access')) {
      return LoadFailure(
        errorType: LoadErrorType.permissionDenied,
        userMessage: 'Cannot read file: "$filePath".\n\n'
            'Check file permissions and ensure the file is not locked by another application.',
        technicalDetails: e.toString(),
        filePath: filePath,
      );
    }

    if (errorMsg.contains('corrupt')) {
      return LoadFailure(
        errorType: LoadErrorType.corruptedDatabase,
        userMessage: 'Database corruption detected in "$filePath".\n\n'
            'The file may be damaged. Consider restoring from a backup.',
        technicalDetails: e.toString(),
        filePath: filePath,
      );
    }

    return LoadFailure(
      errorType: LoadErrorType.unknown,
      userMessage: 'Database error loading "$filePath".\n\n$e',
      technicalDetails: e.toString(),
      filePath: filePath,
    );
  }

  /// Returns the current file path for a document, if any.
  String? getCurrentFilePath(String documentId) {
    return _documentPaths[documentId];
  }

  /// Closes the database connection for a document.
  ///
  /// Call this when closing a document to release resources.
  Future<void> closeDocument(String documentId) async {
    _logger.i('Closing document: $documentId');

    try {
      await _connectionFactory.closeConnection(documentId);
      _documentPaths.remove(documentId);
      _activeLoads.remove(documentId);
    } catch (e) {
      _logger.e('Error closing document $documentId', error: e);
      rethrow;
    }
  }
}
