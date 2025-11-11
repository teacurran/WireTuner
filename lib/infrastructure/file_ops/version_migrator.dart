import 'package:logger/logger.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Service for migrating database format versions.
///
/// VersionMigrator handles sequential migration of WireTuner document databases
/// from older format versions to newer ones. Migrations are applied incrementally
/// (v1→v2→v3) and within transactions to ensure atomicity.
///
/// ## Design Principles
///
/// 1. **Sequential Migrations**: Always migrate one version at a time (v1→v2, then v2→v3)
/// 2. **Idempotent**: Each migration can be safely run multiple times
/// 3. **Atomic**: Each migration runs in a transaction, rollback on failure
/// 4. **Metadata Tracking**: format_version is updated after each successful migration
/// 5. **Telemetry**: All migrations are logged for debugging and monitoring
///
/// ## Usage
///
/// ```dart
/// final migrator = VersionMigrator();
///
/// // Migrate database from v1 to current version
/// await migrator.migrate(
///   db: database,
///   fromVersion: 1,
///   toVersion: 2,
/// );
/// ```
///
/// ## Version History
///
/// - **v1**: Initial release (Milestone 0.1)
///   - Tables: metadata, events, snapshots
///   - Event sourcing with snapshot optimization
///
/// - **v2**: Planned (Milestone 0.2)
///   - Add collaboration tables: users, permissions
///   - Support multi-user editing
///
/// ## Migration Catalog
///
/// Each migration method (e.g., _migrateV1toV2) is responsible for:
/// - Creating new tables/columns
/// - Migrating existing data if needed
/// - Logging progress and telemetry
/// - NOT updating format_version (handled by migrate() method)
class VersionMigrator {
  final Logger _logger = Logger();

  /// Migrates a database from one format version to another.
  ///
  /// Applies all migrations sequentially from [fromVersion] to [toVersion].
  /// Each migration runs in its own transaction with metadata update.
  ///
  /// Parameters:
  /// - [db]: The database to migrate
  /// - [fromVersion]: Current format version of the database
  /// - [toVersion]: Target format version (usually kCurrentFormatVersion)
  ///
  /// Throws [UnsupportedError] if no migration path exists for a version pair.
  ///
  /// Example:
  /// ```dart
  /// // Migrate from v1 to v2
  /// await migrator.migrate(db: db, fromVersion: 1, toVersion: 2);
  /// ```
  Future<void> migrate({
    required Database db,
    required int fromVersion,
    required int toVersion,
  }) async {
    _logger.i('Starting database migration: v$fromVersion → v$toVersion');

    // Apply migrations sequentially
    for (int v = fromVersion; v < toVersion; v++) {
      final nextVersion = v + 1;
      _logger.d('Applying migration: v$v → v$nextVersion');

      final startTime = DateTime.now();

      await db.transaction((txn) async {
        // Apply specific migration
        switch (v) {
          case 1:
            await _migrateV1toV2(txn);
            break;
          default:
            throw UnsupportedError(
              'No migration path exists for v$v → v$nextVersion. '
              'This database version may be too old for this app version.',
            );
        }

        // Update format_version in metadata
        await txn.update(
          'metadata',
          {'format_version': nextVersion},
        );
      });

      final duration = DateTime.now().difference(startTime);
      _logger.i(
        'Migration complete: v$v → v$nextVersion (${duration.inMilliseconds}ms)',
      );
    }

    _logger.i('All migrations complete: v$fromVersion → v$toVersion');
  }

  /// Migrates database from format v1 to v2.
  ///
  /// **Changes in v2 (Planned for Milestone 0.2):**
  /// - Add `users` table for collaboration support
  /// - Add `permissions` table for document access control
  ///
  /// **Migration Strategy:**
  /// - Create new tables (no data migration needed for new features)
  /// - Log telemetry for monitoring
  ///
  /// **Note:** This is a stub for Milestone 0.1. Actual implementation
  /// will be completed in Milestone 0.2 when collaboration features are added.
  ///
  /// Example schema (future):
  /// ```sql
  /// CREATE TABLE users (
  ///   user_id TEXT PRIMARY KEY,
  ///   name TEXT NOT NULL,
  ///   email TEXT NOT NULL
  /// );
  ///
  /// CREATE TABLE permissions (
  ///   document_id TEXT NOT NULL,
  ///   user_id TEXT NOT NULL,
  ///   role TEXT NOT NULL,
  ///   PRIMARY KEY (document_id, user_id)
  /// );
  /// ```
  Future<void> _migrateV1toV2(Transaction txn) async {
    _logger.d('Migrating v1 → v2: Adding collaboration tables (stub)');

    // Stub implementation for Milestone 0.1
    // Actual implementation will be added in Milestone 0.2
    //
    // Future implementation:
    // await txn.execute('''
    //   CREATE TABLE users (
    //     user_id TEXT PRIMARY KEY,
    //     name TEXT NOT NULL,
    //     email TEXT NOT NULL
    //   )
    // ''');
    //
    // await txn.execute('''
    //   CREATE TABLE permissions (
    //     document_id TEXT NOT NULL,
    //     user_id TEXT NOT NULL,
    //     role TEXT NOT NULL,
    //     PRIMARY KEY (document_id, user_id)
    //   )
    // ''');

    _logger.d('v1 → v2 migration stub executed (no changes for Milestone 0.1)');
  }
}
