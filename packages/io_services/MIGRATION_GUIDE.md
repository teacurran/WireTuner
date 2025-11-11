# Migration Guide

## Overview

The `io_services` package uses a version-based migration system to manage database schema evolution. This guide explains how the migration system works and how to add new migrations.

## Current Schema Version

**Version 1**: Base schema with `metadata`, `events`, and `snapshots` tables

## Migration System Architecture

### Components

1. **MigrationRunner** (`lib/src/migrations/migration_runner.dart`)
   - Manages migration execution
   - Tracks database version
   - Applies pending migrations sequentially
   - Verifies schema integrity

2. **Base Schema DDL** (`lib/src/migrations/base_schema_ddl.dart`)
   - Dart constants defining schema SQL statements
   - Used for programmatic schema creation
   - Single source of truth for version 1 schema

3. **SQL Documentation** (`lib/src/migrations/base_schema.sql`)
   - Documented SQL script with detailed comments
   - Explains design rationale and constraints
   - Reference for understanding the schema

### How It Works

1. `ConnectionFactory.openConnection()` opens a database handle
2. If `runMigrations: true` (default), creates a `MigrationRunner`
3. Migration runner checks current database version via `PRAGMA user_version`
4. Applies pending migrations from `currentVersion + 1` to `targetVersion`
5. Updates database version after each successful migration
6. Connection is added to pool and returned

## Migration Flow Diagram

```
┌─────────────────────────┐
│   openConnection()      │
└──────────┬──────────────┘
           │
           ▼
┌──────────────────────────┐
│   Open SQLite handle     │
│   (sqflite_common_ffi)   │
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────────┐
│  MigrationRunner         │
│  .runMigrations()        │
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────────┐
│  Check PRAGMA            │
│  user_version            │
└──────────┬───────────────┘
           │
           ▼
  ┌────────┴──────────┐
  │ Version = target? │
  └─────┬─────────┬───┘
       YES       NO
        │         │
        │         ▼
        │  ┌──────────────────┐
        │  │  Apply migration │
        │  │  version N+1     │
        │  └──────┬───────────┘
        │         │
        │         ▼
        │  ┌──────────────────┐
        │  │  Set PRAGMA      │
        │  │  user_version=N+1│
        │  └──────┬───────────┘
        │         │
        │         └─────┐
        │               │
        ▼               ▼
  ┌──────────────────────────┐
  │  Migration complete      │
  └──────────────────────────┘
```

## Adding a New Migration

When you need to modify the schema (add tables, columns, indexes, etc.), follow these steps:

### 1. Increment Version Number

In `migration_runner.dart`:

```dart
class MigrationRunner {
  static const int currentVersion = 2; // Changed from 1
  ...
}
```

### 2. Create Migration DDL

Create `lib/src/migrations/v2_schema_ddl.dart`:

```dart
/// Version 2 migration: Add user_preferences table
const List<String> v2MigrationStatements = [
  '''
  CREATE TABLE user_preferences (
    preference_id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_id TEXT NOT NULL,
    preference_key TEXT NOT NULL,
    preference_value TEXT,
    FOREIGN KEY (document_id) REFERENCES metadata(document_id) ON DELETE CASCADE,
    UNIQUE(document_id, preference_key)
  )
  ''',

  '''
  CREATE INDEX idx_preferences_document
  ON user_preferences(document_id)
  ''',
];
```

### 3. Create SQL Documentation

Create `lib/src/migrations/v2_migration.sql`:

```sql
-- WireTuner Schema Migration v1 → v2
--
-- Purpose: Add user_preferences table for per-document settings
-- Date: 2025-01-XX
--
-- Changes:
-- - New table: user_preferences
-- - New index: idx_preferences_document

CREATE TABLE user_preferences (
  preference_id INTEGER PRIMARY KEY AUTOINCREMENT,
  document_id TEXT NOT NULL,
  preference_key TEXT NOT NULL,
  preference_value TEXT,

  FOREIGN KEY (document_id) REFERENCES metadata(document_id) ON DELETE CASCADE,
  UNIQUE(document_id, preference_key)
);

CREATE INDEX idx_preferences_document
ON user_preferences(document_id);
```

### 4. Update Migration Runner

In `migration_runner.dart`:

```dart
import 'v2_schema_ddl.dart'; // Add import

class MigrationRunner {
  // ...

  Future<void> _applyMigration(int version) async {
    switch (version) {
      case 1:
        await _applyBaseSchema();
        break;
      case 2:                            // Add new case
        await _applyV2Migration();
        break;
      default:
        throw StateError('No migration defined for version $version');
    }
  }

  Future<void> _applyV2Migration() async {
    _logger.d('Executing v2 migration...');

    for (final statement in v2MigrationStatements) {
      final trimmed = statement.trim();
      if (trimmed.isEmpty) {
        continue;
      }

      try {
        await _db.execute(trimmed);
      } catch (e) {
        _logger.e('Failed to execute v2 migration statement', error: e);
        rethrow;
      }
    }

    _logger.i('V2 migration applied successfully');
  }
}
```

### 5. Update Schema Verification

In `verifySchema()`, add checks for new schema elements:

```dart
Future<bool> verifySchema() async {
  // ...existing checks...

  // Check v2 tables (if version >= 2)
  final version = await _db.getVersion();
  if (version >= 2) {
    final prefsTable = await _db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='user_preferences'",
    );
    if (prefsTable.isEmpty) {
      _logger.w('Schema verification failed: user_preferences table missing');
      return false;
    }
  }

  return true;
}
```

### 6. Write Tests

Create `test/v2_migration_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:io_services/io_services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('V2 Migration', () {
    late Database db;
    late MigrationRunner runner;

    setUp(() async {
      db = await openDatabase(inMemoryDatabasePath);
      runner = MigrationRunner(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('applies v2 migration successfully', () async {
      await runner.runMigrations(targetVersion: 2);

      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='user_preferences'",
      );

      expect(tables, hasLength(1));
    });

    test('v2 migration is idempotent', () async {
      await runner.runMigrations(targetVersion: 2);
      await runner.runMigrations(targetVersion: 2); // Should not throw

      final version = await db.getVersion();
      expect(version, equals(2));
    });
  });
}
```

### 7. Update README

Add migration to the README's migration history section.

## Migration Best Practices

### DO:
✅ Always increment version numbers sequentially (no skipping)
✅ Test migrations with real data (create test databases with v1 data, migrate to v2)
✅ Make migrations idempotent when possible
✅ Document WHY the migration is needed, not just WHAT it does
✅ Use transactions for multi-statement migrations
✅ Verify schema after migration

### DON'T:
❌ Never modify existing migrations (create new ones instead)
❌ Never downgrade database versions (migrations are one-way)
❌ Don't delete data without explicit user consent
❌ Don't skip schema verification tests
❌ Don't use database-specific features that break portability

## Rollback Strategy

Database migrations are **one-way only**. There is no automatic rollback.

If a migration fails in production:

1. **Fix forward**: Create a new migration that fixes the issue
2. **Manual intervention**: If necessary, provide a repair tool/script
3. **Data export**: Users can export data, reinstall, and re-import

Never attempt to:
- Decrease the database version
- Manually edit migration files after release
- Skip migrations

## Testing Migrations

### Unit Tests

```dart
test('migration from v1 to v2', () async {
  // 1. Create v1 database
  final db = await openDatabase(inMemoryDatabasePath);
  final runner = MigrationRunner(db);
  await runner.runMigrations(targetVersion: 1);

  // 2. Insert v1 data
  await db.insert('metadata', {...});
  await db.insert('events', {...});

  // 3. Migrate to v2
  await runner.runMigrations(targetVersion: 2);

  // 4. Verify v1 data is intact
  final metadata = await db.query('metadata');
  expect(metadata, hasLength(1));

  // 5. Verify v2 schema exists
  final tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='user_preferences'",
  );
  expect(tables, hasLength(1));
});
```

### Integration Tests

1. Create `.wiretuner` file with v1 schema
2. Populate with realistic data
3. Run migration via `ConnectionFactory`
4. Verify all data preserved
5. Test CRUD operations on new schema

## Schema Versioning Policy

- **Major version**: Breaking schema changes (rare, requires data migration tool)
- **Minor version**: Additive changes (new tables, columns with defaults)
- **Patch version**: Indexes, constraints, non-breaking modifications

Current: **1.0.0** (base schema)

## References

- **Base Schema**: `lib/src/migrations/base_schema.sql`
- **Migration Runner**: `lib/src/migrations/migration_runner.dart`
- **Architecture Doc**: `docs/reference/03_System_Structure_and_Data.md`
- **SQLite Documentation**: https://www.sqlite.org/lang_altertable.html
