import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/infrastructure/event_sourcing/event_replayer.dart';
import 'package:wiretuner/infrastructure/file_ops/file_picker_adapter.dart';
import 'package:wiretuner/infrastructure/file_ops/load_exceptions.dart';
import 'package:wiretuner/infrastructure/file_ops/version_migrator.dart';
import 'package:wiretuner/infrastructure/persistence/database_provider.dart';
import 'package:wiretuner/infrastructure/persistence/event_store.dart';
import 'package:wiretuner/infrastructure/persistence/snapshot_store.dart';

/// Current format version supported by this version of WireTuner.
const int kCurrentFormatVersion = 1;

/// Result of a load operation.
///
/// Contains the reconstructed document and metrics about the load operation
/// for telemetry and user feedback.
class LoadResult {
  /// Creates a load result.
  const LoadResult({
    required this.success,
    required this.document,
    required this.documentId,
    required this.filePath,
    required this.eventCount,
    required this.fileSize,
    required this.durationMs,
    required this.snapshotUsed,
    required this.eventsReplayed,
    this.hadIssues = false,
    this.skippedEventCount = 0,
  });

  /// Whether the load operation succeeded.
  final bool success;

  /// The reconstructed document.
  final Document document;

  /// The document ID that was loaded.
  final String documentId;

  /// Absolute path of the loaded file.
  final String filePath;

  /// Total number of events in the document.
  final int eventCount;

  /// Size of the loaded file in bytes.
  final int fileSize;

  /// Duration of the load operation in milliseconds.
  final int durationMs;

  /// Whether a snapshot was used to optimize load.
  final bool snapshotUsed;

  /// Number of events replayed (after snapshot or from start).
  final int eventsReplayed;

  /// Whether the load encountered issues (corrupt events, warnings).
  final bool hadIssues;

  /// Number of events that were skipped due to corruption.
  final int skippedEventCount;

  @override
  String toString() => 'LoadResult(success: $success, documentId: $documentId, '
      'filePath: $filePath, events: $eventCount, eventsReplayed: $eventsReplayed, '
      'fileSize: $fileSize bytes, duration: ${durationMs}ms, '
      'snapshotUsed: $snapshotUsed, hadIssues: $hadIssues, skipped: $skippedEventCount)';
}

/// Telemetry callback for load operations.
///
/// This callback is invoked after successful load operations to report
/// metrics for monitoring and analytics.
typedef LoadTelemetryCallback = void Function({
  required String documentId,
  required int eventCount,
  required int fileSize,
  required int durationMs,
  required bool snapshotUsed,
  required int eventsReplayed,
});

/// Warning callback for load operations.
///
/// This callback is invoked when the load completes but encountered issues
/// such as corrupt events that were skipped.
typedef LoadWarningCallback = void Function({
  required String message,
  required int skippedCount,
  required List<String> warnings,
});

/// Service for loading documents from disk.
///
/// LoadService implements the Load Document pipeline (T034/T035) by orchestrating:
/// - File picker dialogs for file selection
/// - Database connection management
/// - Format version validation and migration
/// - Document reconstruction via EventReplayer
/// - Graceful error handling for corrupt events
/// - Telemetry logging
///
/// ## Usage
///
/// **Load File (Cmd+O):**
/// ```dart
/// final result = await loadService.load(); // Prompts for file
/// print('Loaded ${result.eventCount} events in ${result.durationMs}ms');
/// ```
///
/// **Load Specific File (Recent Files):**
/// ```dart
/// final result = await loadService.load(filePath: '/path/to/file.wiretuner');
/// ```
///
/// ## Error Handling
///
/// LoadService maps database and file system errors to domain exceptions:
/// - [LoadCancelledException]: User cancelled file picker
/// - [FileNotFoundException]: File does not exist
/// - [VersionMismatchException]: Format version too new
/// - [CorruptDatabaseException]: Invalid database schema or missing metadata
/// - [InvalidFilePathException]: Path validation failures
///
/// ## Graceful Degradation
///
/// LoadService handles corrupt events gracefully:
/// - Corrupt events are skipped during replay
/// - Warnings are logged and surfaced via onLoadWarning callback
/// - Partial document is returned (all non-corrupt events applied)
/// - User is notified of issues via UI alert
class LoadService {
  /// Creates a LoadService.
  ///
  /// Parameters:
  /// - [eventStore]: Repository for event persistence
  /// - [snapshotStore]: Repository for snapshot persistence
  /// - [eventReplayer]: Service for reconstructing document state
  /// - [dbProvider]: Database connection provider
  /// - [filePickerAdapter]: Abstraction for file picker dialogs
  /// - [versionMigrator]: Optional service for migrating older format versions
  /// - [onLoadCompleted]: Optional telemetry callback
  /// - [onLoadWarning]: Optional warning callback for corrupt events
  LoadService({
    required EventStore eventStore,
    required SnapshotStore snapshotStore,
    required EventReplayer eventReplayer,
    required DatabaseProvider dbProvider,
    required FilePickerAdapter filePickerAdapter,
    VersionMigrator? versionMigrator,
    this.onLoadCompleted,
    this.onLoadWarning,
  })  : _eventStore = eventStore,
        _snapshotStore = snapshotStore,
        _eventReplayer = eventReplayer,
        _dbProvider = dbProvider,
        _filePickerAdapter = filePickerAdapter,
        _versionMigrator = versionMigrator;

  final EventStore _eventStore;
  final SnapshotStore _snapshotStore;
  final EventReplayer _eventReplayer;
  final DatabaseProvider _dbProvider;
  final FilePickerAdapter _filePickerAdapter;
  final VersionMigrator? _versionMigrator;
  final LoadTelemetryCallback? onLoadCompleted;
  final LoadWarningCallback? onLoadWarning;
  final Logger _logger = Logger();

  /// Loads a document from disk.
  ///
  /// If [filePath] is null, prompts the user with a file picker dialog.
  /// Otherwise, loads directly from the specified path.
  ///
  /// Parameters:
  /// - [filePath]: Optional path to load from (null triggers file picker)
  ///
  /// Returns [LoadResult] with the reconstructed document and metrics on success.
  ///
  /// Throws:
  /// - [LoadCancelledException]: User cancelled file picker
  /// - [FileNotFoundException]: File does not exist
  /// - [InvalidFilePathException]: File path validation failed
  /// - [VersionMismatchException]: Format version too new for this app
  /// - [CorruptDatabaseException]: Database schema invalid or metadata missing
  /// - [LoadException]: Other database or I/O errors
  Future<LoadResult> load({String? filePath}) async {
    final startTime = DateTime.now();
    _logger.d('Starting load: filePath=$filePath');

    try {
      // Step 1: Resolve file path (prompt if needed)
      String? resolvedPath = filePath;
      if (resolvedPath == null) {
        _logger.d('No file path provided, showing open dialog');
        resolvedPath = await _filePickerAdapter.showOpenDialog();

        if (resolvedPath == null) {
          _logger.i('User cancelled open dialog');
          throw const LoadCancelledException();
        }
      }

      // Step 2: Validate file path
      resolvedPath = _validateLoadPath(resolvedPath);
      _logger.d('Validated file path: $resolvedPath');

      // Step 3: Ensure database is open for this file
      final db = await _ensureDatabaseOpen(resolvedPath);

      // Step 4: Read and validate metadata
      final metadata = await db.query('metadata', limit: 1);

      if (metadata.isEmpty) {
        throw CorruptDatabaseException('No metadata found in database');
      }

      final documentId = metadata.first['document_id'] as String;
      final formatVersion = metadata.first['format_version'] as int;

      _logger.d('Document metadata: id=$documentId, formatVersion=$formatVersion');

      // Step 5: Check format version and run migrations if needed
      await _checkFormatVersion(db, formatVersion);

      // Step 6: Get max event sequence
      final maxSeq = await _eventStore.getMaxSequence(documentId);
      _logger.d('Max event sequence: $maxSeq');

      // Step 7: Reconstruct document via EventReplayer
      final result = await _eventReplayer.replayToSequence(
        documentId: documentId,
        targetSequence: maxSeq,
        continueOnError: true, // Graceful degradation for corrupt events
      );

      final document = result.state as Document;

      // Step 8: Check if snapshot was used
      final snapshot = await _snapshotStore.getLatestSnapshot(
        documentId,
        maxSeq,
      );
      final snapshotUsed = snapshot != null;
      final eventsReplayed = snapshotUsed
          ? maxSeq - (snapshot['event_sequence'] as int)
          : maxSeq + 1;

      // Step 9: Handle corrupt events warnings
      if (result.hasIssues) {
        _logger.w(
          'Document loaded with issues: ${result.skippedSequences.length} events skipped, '
          '${result.warnings.length} warnings: ${result.warnings.join(", ")}',
        );

        onLoadWarning?.call(
          message: 'Some events could not be loaded. '
              'Document may be incomplete. See logs for details.',
          skippedCount: result.skippedSequences.length,
          warnings: result.warnings,
        );
      }

      // Step 10: Collect telemetry metrics
      final endTime = DateTime.now();
      final durationMs = endTime.difference(startTime).inMilliseconds;
      final fileInfo = await File(resolvedPath).stat();
      final fileSize = fileInfo.size;

      _logger.i(
        'Load completed: documentId=$documentId, path=$resolvedPath, '
        'maxSeq=$maxSeq, snapshotUsed=$snapshotUsed, '
        'eventsReplayed=$eventsReplayed, fileSize=$fileSize bytes, '
        'duration=${durationMs}ms, hadIssues=${result.hasIssues}, '
        'skipped=${result.skippedSequences.length}',
      );

      // Step 11: Invoke telemetry callback
      onLoadCompleted?.call(
        documentId: documentId,
        eventCount: maxSeq + 1,
        fileSize: fileSize,
        durationMs: durationMs,
        snapshotUsed: snapshotUsed,
        eventsReplayed: eventsReplayed,
      );

      // Step 12: Return result
      return LoadResult(
        success: true,
        document: document,
        documentId: documentId,
        filePath: resolvedPath,
        eventCount: maxSeq + 1,
        fileSize: fileSize,
        durationMs: durationMs,
        snapshotUsed: snapshotUsed,
        eventsReplayed: eventsReplayed,
        hadIssues: result.hasIssues,
        skippedEventCount: result.skippedSequences.length,
      );
    } on DatabaseException catch (e, stackTrace) {
      _logger.e('Database error during load', error: e, stackTrace: stackTrace);
      _mapDatabaseException(e);
      rethrow; // Should not reach here due to _mapDatabaseException throwing
    } on FileSystemException catch (e, stackTrace) {
      _logger.e('File system error during load', error: e, stackTrace: stackTrace);
      throw FileNotFoundException(
        'Cannot read file: ${e.message}',
        cause: e,
      );
    } on LoadException {
      rethrow; // Already a domain exception
    } catch (e, stackTrace) {
      _logger.e('Unexpected error during load', error: e, stackTrace: stackTrace);
      throw LoadException('Unexpected error during load: $e', cause: e);
    }
  }

  /// Validates a file path for load operations.
  ///
  /// - Ensures file exists
  /// - Ensures path has .wiretuner extension
  ///
  /// Throws [FileNotFoundException] if file does not exist.
  /// Throws [InvalidFilePathException] if validation fails.
  String _validateLoadPath(String filePath) {
    // Ensure file exists
    if (!File(filePath).existsSync()) {
      throw FileNotFoundException('File not found: $filePath');
    }

    // Ensure .wiretuner extension
    if (!filePath.endsWith('.wiretuner')) {
      throw InvalidFilePathException(
        'Invalid file type. Expected .wiretuner file.',
        providedPath: filePath,
      );
    }

    return filePath;
  }

  /// Ensures the database is open for the specified file path.
  ///
  /// If the database is already open for a different file, closes it first.
  /// If the database is already open for the same file, returns it.
  /// If the database is not open, opens it.
  Future<Database> _ensureDatabaseOpen(String filePath) async {
    // If database is open, check if it's for the same file
    if (_dbProvider.isOpen) {
      final currentPath = _dbProvider.getDatabase().path;
      if (currentPath == filePath) {
        _logger.d('Database already open for this file: $filePath');
        return _dbProvider.getDatabase();
      } else {
        _logger.d('Closing database for different file: $currentPath');
        await _dbProvider.close();
      }
    }

    // Open database for target path
    _logger.d('Opening database: $filePath');
    return await _dbProvider.open(filePath);
  }

  /// Checks format version and runs migrations if needed.
  ///
  /// Throws [VersionMismatchException] if format version is newer than app supports.
  Future<void> _checkFormatVersion(Database db, int formatVersion) async {
    if (formatVersion > kCurrentFormatVersion) {
      throw VersionMismatchException(
        'This document requires WireTuner v$formatVersion or later. '
        'Current app version supports v$kCurrentFormatVersion.',
      );
    } else if (formatVersion < kCurrentFormatVersion) {
      _logger.i('Older format detected (v$formatVersion), running migrations...');

      if (_versionMigrator == null) {
        _logger.w(
          'Older format detected but no migrator provided, skipping migration',
        );
      } else {
        await _versionMigrator!.migrate(
          db: db,
          fromVersion: formatVersion,
          toVersion: kCurrentFormatVersion,
        );
      }
    } else {
      _logger.d('Format version matches (v$formatVersion), no migration needed');
    }
  }

  /// Maps SQLite database exceptions to domain exceptions.
  ///
  /// This method always throws - it never returns normally.
  Never _mapDatabaseException(DatabaseException e) {
    final errorMsg = e.toString();

    // Check for corruption errors
    if (errorMsg.contains('SQLITE_CORRUPT') ||
        errorMsg.contains('database disk image is malformed')) {
      throw CorruptDatabaseException(
        'Database file is corrupt. The file may have been damaged.',
        cause: e,
      );
    }

    // Check for schema errors
    if (errorMsg.contains('no such table') ||
        errorMsg.contains('no such column')) {
      throw CorruptDatabaseException(
        'Database schema is invalid. The file may not be a valid WireTuner document.',
        cause: e,
      );
    }

    // Unknown database error
    throw LoadException('Database error: $errorMsg', cause: e);
  }
}
