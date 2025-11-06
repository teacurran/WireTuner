# T035: File Format Versioning System

## Status
- **Phase**: 8 - File Operations
- **Priority**: High
- **Estimated Effort**: 0.5 days
- **Dependencies**: T034

## Overview
Implement schema migration system for forward compatibility.

## Objectives
- Track schema version in database
- Implement migration functions
- Reject incompatible newer versions
- Migrate older versions to current schema

## Implementation
```dart
class SchemaM igrations {
  static const migrations = {
    1: _migrateV0toV1,
    2: _migrateV1toV2,
    // Future migrations...
  };

  static Future<void> migrate(Database db, int fromVersion, int toVersion) async {
    for (int v = fromVersion + 1; v <= toVersion; v++) {
      if (migrations.containsKey(v)) {
        await migrations[v]!(db);
        await _updateSchemaVersion(db, v);
      }
    }
  }

  static Future<void> _migrateV0toV1(Database db) async {
    // Example: Add new column
    await db.execute('ALTER TABLE events ADD COLUMN new_field TEXT');
  }
}
```

## Success Criteria
- [ ] Old files open in new app versions
- [ ] New files rejected by old app versions
- [ ] Migrations run automatically
- [ ] Data integrity preserved after migration

## References
- T003: Architecture Design (versioning section)
