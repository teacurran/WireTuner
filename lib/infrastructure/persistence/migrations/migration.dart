import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Abstract interface for file format version migrations.
///
/// Each migration transforms the database schema and/or data from one
/// format version to the next. Migrations must be:
///
/// 1. **Idempotent**: Safe to run multiple times (though MigrationManager prevents this)
/// 2. **Atomic**: All changes in a single transaction
/// 3. **Sequential**: Applied in version order (v1→v2, v2→v3, etc.)
/// 4. **Backward-Compatible**: Never destructive to event log
///
/// ## Implementation Guidelines
///
/// - Migrations run inside a transaction (handled by MigrationManager)
/// - Do NOT update `metadata.format_version` (MigrationManager handles this)
/// - Log all significant operations for debugging
/// - Handle edge cases (empty tables, missing optional data)
/// - Preserve all events—never delete from event log
///
/// ## Example Implementation
///
/// ```dart
/// class Version1To2Migration implements Migration {
///   @override
///   int get fromVersion => 1;
///
///   @override
///   int get toVersion => 2;
///
///   @override
///   Future<void> apply(Transaction txn) async {
///     // Add collaboration tables
///     await txn.execute('''
///       CREATE TABLE users (
///         user_id TEXT PRIMARY KEY,
///         name TEXT NOT NULL,
///         email TEXT NOT NULL
///       )
///     ''');
///
///     // Log completion
///     Logger().d('Added collaboration tables for v2');
///   }
/// }
/// ```
///
/// See also:
/// - [MigrationManager] for orchestrating migration sequences
/// - `docs/adr/004-file-format-versioning.md` for versioning strategy
abstract class Migration {
  /// The format version this migration starts from.
  ///
  /// Example: For v1→v2 migration, `fromVersion` = 1
  int get fromVersion;

  /// The format version this migration upgrades to.
  ///
  /// Example: For v1→v2 migration, `toVersion` = 2
  int get toVersion;

  /// Applies this migration to the database.
  ///
  /// This method is called within a transaction by [MigrationManager].
  /// Implementations should:
  /// - Make all necessary schema changes (CREATE TABLE, ALTER TABLE, etc.)
  /// - Transform existing data if needed
  /// - Log progress for debugging
  /// - Throw exceptions on failure (transaction will be rolled back)
  ///
  /// Do NOT:
  /// - Update `metadata.format_version` (MigrationManager handles this)
  /// - Start/commit transactions (already in a transaction)
  /// - Delete events from the event log (preserve history)
  ///
  /// Parameters:
  /// - [txn]: The active database transaction
  ///
  /// Throws any exception on failure (causes transaction rollback)
  Future<void> apply(Transaction txn);
}
