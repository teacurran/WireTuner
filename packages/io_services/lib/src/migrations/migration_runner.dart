import 'package:logger/logger.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'base_schema_ddl.dart';

/// Manages database schema migrations for WireTuner.
///
/// This class handles:
/// - Initial schema creation from base schema DDL
/// - Future version migrations
/// - Schema verification
///
/// The migration system is designed to be extensible for future schema changes
/// while maintaining backward compatibility.
class MigrationRunner {
  MigrationRunner(this._db);

  final Database _db;
  static final Logger _logger = Logger();

  /// Current schema version.
  static const int currentVersion = 1;

  /// Applies migrations to bring the database to the current schema version.
  ///
  /// This method:
  /// 1. Checks the current database version
  /// 2. Applies any pending migrations in sequence
  /// 3. Updates the database version
  ///
  /// For version 1 (new databases), executes the base schema DDL.
  /// Future versions will apply incremental migration scripts.
  Future<void> runMigrations({int targetVersion = currentVersion}) async {
    _logger.i('Running migrations to version $targetVersion...');

    final currentDbVersion = await _db.getVersion();
    _logger.d('Current database version: $currentDbVersion');

    if (currentDbVersion == targetVersion) {
      _logger.i('Database already at target version $targetVersion');
      return;
    }

    if (currentDbVersion > targetVersion) {
      throw StateError(
        'Database version ($currentDbVersion) is newer than target version ($targetVersion). '
        'Downgrade migrations are not supported.',
      );
    }

    // Apply migrations sequentially
    for (int version = currentDbVersion + 1; version <= targetVersion; version++) {
      _logger.i('Applying migration to version $version...');
      await _applyMigration(version);
      await _db.setVersion(version);
      _logger.i('Successfully migrated to version $version');
    }

    _logger.i('All migrations completed successfully');
  }

  /// Applies a specific migration version.
  Future<void> _applyMigration(int version) async {
    switch (version) {
      case 1:
        await _applyBaseSchema();
        break;
      default:
        throw StateError('No migration defined for version $version');
    }
  }

  /// Applies the base schema DDL.
  ///
  /// This migration creates the initial event sourcing schema with:
  /// - metadata table
  /// - events table (append-only log)
  /// - snapshots table
  /// - Performance indexes
  /// - WAL mode and foreign key constraints
  Future<void> _applyBaseSchema() async {
    _logger.d('Executing base schema DDL...');

    for (final statement in baseSchemaStatements) {
      final trimmed = statement.trim();
      if (trimmed.isEmpty) {
        continue;
      }

      try {
        await _db.execute(trimmed);
      } catch (e) {
        _logger.e('Failed to execute DDL statement', error: e);
        rethrow;
      }
    }

    _logger.i('Base schema applied successfully');
  }

  /// Verifies schema integrity by checking table and index existence.
  ///
  /// Returns true if all required schema elements exist, false otherwise.
  Future<bool> verifySchema() async {
    _logger.d('Verifying schema integrity...');

    try {
      // Check tables exist
      final tables = await _db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('metadata', 'events', 'snapshots')",
      );

      if (tables.length != 3) {
        _logger.w('Schema verification failed: Expected 3 tables, found ${tables.length}');
        return false;
      }

      // Check indexes exist
      final indexes = await _db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND name IN ('idx_events_document_sequence', 'idx_snapshots_document')",
      );

      if (indexes.length != 2) {
        _logger.w('Schema verification failed: Expected 2 indexes, found ${indexes.length}');
        return false;
      }

      // Check foreign keys are enabled
      final fkResult = await _db.rawQuery('PRAGMA foreign_keys');
      final fkEnabled = fkResult.first['foreign_keys'] == 1;

      if (!fkEnabled) {
        _logger.w('Schema verification failed: Foreign keys not enabled');
        return false;
      }

      _logger.i('Schema verification passed');
      return true;
    } catch (e) {
      _logger.e('Schema verification error: $e');
      return false;
    }
  }
}
