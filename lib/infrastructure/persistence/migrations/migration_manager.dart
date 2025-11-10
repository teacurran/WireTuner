import 'package:logger/logger.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'migration.dart';

/// Result of a migration operation.
///
/// Contains information about which migrations were applied and how long
/// they took, useful for telemetry and user feedback.
class MigrationResult {
  /// Creates a migration result.
  const MigrationResult({
    required this.fromVersion,
    required this.toVersion,
    required this.migrationsApplied,
    required this.durationMs,
  });

  /// The starting format version.
  final int fromVersion;

  /// The final format version after all migrations.
  final int toVersion;

  /// Number of migrations that were applied.
  final int migrationsApplied;

  /// Total duration of all migrations in milliseconds.
  final int durationMs;

  /// Whether any migrations were actually applied.
  bool get wasMigrated => migrationsApplied > 0;

  @override
  String toString() => 'MigrationResult(v$fromVersion→v$toVersion, '
      'applied: $migrationsApplied, duration: ${durationMs}ms)';
}

/// Exception thrown when a migration fails.
class MigrationException implements Exception {
  const MigrationException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'MigrationException: $message${cause != null ? ' (cause: $cause)' : ''}';
}

/// Manages file format version migrations.
///
/// MigrationManager orchestrates the migration process when opening documents
/// with older format versions. It applies migrations sequentially (v1→v2→v3)
/// within transactions to ensure atomicity.
///
/// ## Usage
///
/// ```dart
/// // Register available migrations
/// final manager = MigrationManager(migrations: [
///   Version1To2Migration(),
///   Version2To3Migration(),
/// ]);
///
/// // Apply migrations if needed
/// final result = await manager.applyMigrations(
///   db: database,
///   fromVersion: 1,
///   toVersion: 3,
/// );
///
/// if (result.wasMigrated) {
///   print('Migrated from v${result.fromVersion} to v${result.toVersion}');
/// }
/// ```
///
/// ## Design Principles
///
/// 1. **Sequential Application**: Migrations applied one at a time (v1→v2, then v2→v3)
/// 2. **Transaction Safety**: Each migration runs in its own transaction with rollback on failure
/// 3. **Metadata Consistency**: `format_version` updated within same transaction as migration
/// 4. **Telemetry**: All migrations logged with timing data
/// 5. **Idempotency**: Detects current version to avoid re-running migrations
///
/// ## Integration with LoadService
///
/// MigrationManager is called by LoadService during document opening:
///
/// ```dart
/// // In LoadService._checkFormatVersion():
/// if (formatVersion < kCurrentFormatVersion) {
///   await _migrationManager.applyMigrations(
///     db: db,
///     fromVersion: formatVersion,
///     toVersion: kCurrentFormatVersion,
///   );
/// }
/// ```
///
/// See also:
/// - [Migration] interface for implementing version migrations
/// - [MigrationResult] for migration operation outcomes
/// - `lib/infrastructure/file_ops/version_migrator.dart` for legacy implementation
/// - `docs/adr/004-file-format-versioning.md` for versioning strategy
class MigrationManager {
  /// Creates a MigrationManager with the specified migrations.
  ///
  /// Parameters:
  /// - [migrations]: List of available migrations, applied in order
  ///
  /// Throws [ArgumentError] if migrations are not sequential or have duplicates.
  MigrationManager({required List<Migration> migrations})
      : _migrations = migrations {
    _validateMigrations();
    _buildMigrationMap();
  }

  final List<Migration> _migrations;
  final Map<int, Migration> _migrationMap = {};
  final Logger _logger = Logger();

  /// Applies migrations to bring the database from [fromVersion] to [toVersion].
  ///
  /// This method:
  /// 1. Validates version bounds
  /// 2. Determines which migrations are needed
  /// 3. Applies each migration in a separate transaction
  /// 4. Updates `metadata.format_version` after each migration
  /// 5. Logs timing and telemetry data
  ///
  /// If [fromVersion] equals [toVersion], returns immediately (no-op).
  ///
  /// Parameters:
  /// - [db]: The database to migrate
  /// - [fromVersion]: Current format version
  /// - [toVersion]: Target format version
  ///
  /// Returns [MigrationResult] with migration outcome.
  ///
  /// Throws:
  /// - [MigrationException] if migration path is invalid or migration fails
  /// - [ArgumentError] if version parameters are invalid
  Future<MigrationResult> applyMigrations({
    required Database db,
    required int fromVersion,
    required int toVersion,
  }) async {
    if (fromVersion < 0 || toVersion < 0) {
      throw ArgumentError('Version numbers must be non-negative: '
          'fromVersion=$fromVersion, toVersion=$toVersion');
    }

    if (fromVersion > toVersion) {
      throw MigrationException(
        'Downgrade migrations are not supported. '
        'Cannot migrate from v$fromVersion to v$toVersion.',
      );
    }

    // No migration needed
    if (fromVersion == toVersion) {
      _logger.d('No migration needed: already at v$toVersion');
      return MigrationResult(
        fromVersion: fromVersion,
        toVersion: toVersion,
        migrationsApplied: 0,
        durationMs: 0,
      );
    }

    _logger.i('Starting migrations: v$fromVersion → v$toVersion');
    final startTime = DateTime.now();
    int migrationsApplied = 0;

    try {
      // Apply migrations sequentially
      for (int version = fromVersion; version < toVersion; version++) {
        final nextVersion = version + 1;
        _logger.d('Applying migration: v$version → v$nextVersion');

        final migrationStartTime = DateTime.now();

        // Find migration for this version step
        final migration = _migrationMap[version];
        if (migration == null) {
          throw MigrationException(
            'No migration path exists for v$version → v$nextVersion. '
            'This database version may be too old or too new for this app version.',
          );
        }

        // Apply migration in transaction
        await db.transaction((txn) async {
          // Execute migration logic
          await migration.apply(txn);

          // Update format_version in metadata
          final updateCount = await txn.update(
            'metadata',
            {'format_version': nextVersion},
          );

          if (updateCount == 0) {
            throw MigrationException(
              'Failed to update format_version to $nextVersion. '
              'Metadata table may be empty or corrupted.',
            );
          }

          _logger.d('Updated format_version to $nextVersion');
        });

        final migrationDuration = DateTime.now().difference(migrationStartTime);
        _logger.i(
          'Migration complete: v$version → v$nextVersion '
          '(${migrationDuration.inMilliseconds}ms)',
        );

        migrationsApplied++;
      }

      final totalDuration = DateTime.now().difference(startTime);
      _logger.i(
        'All migrations complete: v$fromVersion → v$toVersion '
        '(${migrationsApplied} migrations, ${totalDuration.inMilliseconds}ms)',
      );

      return MigrationResult(
        fromVersion: fromVersion,
        toVersion: toVersion,
        migrationsApplied: migrationsApplied,
        durationMs: totalDuration.inMilliseconds,
      );
    } catch (e, stackTrace) {
      _logger.e(
        'Migration failed at some step between v$fromVersion and v$toVersion',
        error: e,
        stackTrace: stackTrace,
      );

      if (e is MigrationException) {
        rethrow;
      }

      throw MigrationException(
        'Migration failed: $e',
        cause: e,
      );
    }
  }

  /// Validates that migrations are properly sequenced and non-overlapping.
  void _validateMigrations() {
    final Set<int> seenFromVersions = {};

    for (final migration in _migrations) {
      // Check for sequential versioning
      if (migration.toVersion != migration.fromVersion + 1) {
        throw ArgumentError(
          'Migrations must increment version by exactly 1. '
          'Found: v${migration.fromVersion} → v${migration.toVersion}',
        );
      }

      // Check for duplicate fromVersions
      if (seenFromVersions.contains(migration.fromVersion)) {
        throw ArgumentError(
          'Multiple migrations defined for v${migration.fromVersion}. '
          'Each version can have only one migration.',
        );
      }

      seenFromVersions.add(migration.fromVersion);
    }
  }

  /// Builds a map for fast migration lookup by fromVersion.
  void _buildMigrationMap() {
    for (final migration in _migrations) {
      _migrationMap[migration.fromVersion] = migration;
    }
  }
}
