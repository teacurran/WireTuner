import 'package:logger/logger.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'migration.dart';

/// Migrates database from format v1 to v2.
///
/// **Current Status (Milestone 0.1):** This is a stub implementation.
/// No actual schema changes are made because v2 features (collaboration support)
/// are not yet implemented.
///
/// **Planned Changes for v2 (Milestone 0.2):**
/// - Add `users` table for collaboration support
/// - Add `permissions` table for document access control
/// - Enable multi-user editing capabilities
///
/// **Migration Strategy:**
/// - Create new tables (no data migration needed for new features)
/// - Preserve all existing events and snapshots
/// - Log telemetry for monitoring
///
/// ## Future Implementation (Milestone 0.2)
///
/// When v2 is implemented, this migration will execute:
///
/// ```sql
/// CREATE TABLE users (
///   user_id TEXT PRIMARY KEY,
///   name TEXT NOT NULL,
///   email TEXT NOT NULL,
///   created_at INTEGER NOT NULL
/// );
///
/// CREATE TABLE permissions (
///   document_id TEXT NOT NULL,
///   user_id TEXT NOT NULL,
///   role TEXT NOT NULL CHECK (role IN ('owner', 'editor', 'viewer')),
///   granted_at INTEGER NOT NULL,
///   PRIMARY KEY (document_id, user_id),
///   FOREIGN KEY (document_id) REFERENCES metadata(document_id) ON DELETE CASCADE,
///   FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
/// );
///
/// CREATE INDEX idx_permissions_user ON permissions(user_id);
/// ```
///
/// ## Backward Compatibility
///
/// This migration is **additive only**:
/// - No existing tables are modified
/// - No events are deleted or transformed
/// - Single-user documents continue to work unchanged
/// - Collaboration features are opt-in
///
/// See also:
/// - `api/file_format_spec.md` Section 5.2 (Version Increment Rules)
/// - `docs/adr/004-file-format-versioning.md` for versioning strategy
/// - `lib/infrastructure/file_ops/version_migrator.dart` for legacy implementation
class Version1To2Migration implements Migration {
  final Logger _logger = Logger();

  @override
  int get fromVersion => 1;

  @override
  int get toVersion => 2;

  @override
  Future<void> apply(Transaction txn) async {
    _logger.d('Applying v1 → v2 migration (stub implementation)');

    // Stub implementation for Milestone 0.1
    // Actual implementation will be added in Milestone 0.2
    //
    // Future implementation:
    //
    // _logger.d('Creating users table...');
    // await txn.execute('''
    //   CREATE TABLE users (
    //     user_id TEXT PRIMARY KEY,
    //     name TEXT NOT NULL,
    //     email TEXT NOT NULL,
    //     created_at INTEGER NOT NULL
    //   )
    // ''');
    //
    // _logger.d('Creating permissions table...');
    // await txn.execute('''
    //   CREATE TABLE permissions (
    //     document_id TEXT NOT NULL,
    //     user_id TEXT NOT NULL,
    //     role TEXT NOT NULL CHECK (role IN ('owner', 'editor', 'viewer')),
    //     granted_at INTEGER NOT NULL,
    //     PRIMARY KEY (document_id, user_id),
    //     FOREIGN KEY (document_id) REFERENCES metadata(document_id) ON DELETE CASCADE,
    //     FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
    //   )
    // ''');
    //
    // _logger.d('Creating permissions index...');
    // await txn.execute('''
    //   CREATE INDEX idx_permissions_user ON permissions(user_id)
    // ''');
    //
    // _logger.i('Collaboration tables created successfully');

    _logger.d('v1 → v2 migration stub executed (no changes for Milestone 0.1)');
  }
}
