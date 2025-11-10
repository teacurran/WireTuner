<!-- anchor: adr-004-file-format-versioning -->
# 004. File Format Versioning

**Status:** Accepted
**Date:** 2025-11-10
**Deciders:** WireTuner Architecture Team

## Context

WireTuner's `.wiretuner` file format must evolve over time to support new features (collaboration, gradients, effects) while maintaining backward compatibility with documents created by older versions of the application. Without a robust versioning strategy, the application would either:

1. **Break Compatibility**: Users cannot open older documents after upgrading the app
2. **Stagnate Features**: New capabilities cannot be added without breaking existing files
3. **Require Manual Migration**: Users must manually convert files, creating friction

The challenge is balancing these requirements:

- **Forward Compatibility**: Newer app versions open older documents seamlessly
- **Version Detection**: Older app versions detect (but gracefully reject) newer documents
- **Graceful Evolution**: Format can accommodate new features without breaking changes
- **User Transparency**: Version mismatches produce clear error messages, not cryptic failures

Real-world scenarios driving this decision:

- **Milestone 0.2 Collaboration**: Adding `users` and `permissions` tables requires format v2
- **Future Gradient Support**: Adding gradient event types and snapshot fields requires format v3
- **Legacy Document Support**: Users opening v1 documents in v3 app expect instant migration

## Decision

We will implement **semantic versioning for the file format** with the following strategy:

### 1. Versioning Scheme

The `.wiretuner` file format uses **integer major versioning** via the `metadata.format_version` column:

```sql
CREATE TABLE metadata (
  document_id TEXT PRIMARY KEY,
  format_version INTEGER NOT NULL DEFAULT 1,
  -- other fields...
);
```

**Current Version:** `1` (Milestone 0.1)

**Version Increment Rules:**

- **Increment version** for backward-incompatible changes:
  - Adding required tables or columns
  - Changing column data types or constraints
  - Introducing event types that older apps cannot safely ignore
  - Altering snapshot binary format in non-backward-compatible ways

- **Do NOT increment version** for forward-compatible changes:
  - Adding optional columns with default values
  - Creating performance indexes
  - Adding event types that older apps can ignore
  - Extending snapshot header reserved bytes

### 2. Migration Architecture

**Automatic Migration on Load:**

When opening a document with `format_version < current_version`, the application automatically migrates the file to the current version. This occurs during `LoadService.load()` before presenting the document to the user.

**Migration Manager Design:**

```dart
class MigrationManager {
  Future<MigrationResult> applyMigrations({
    required Database db,
    required int fromVersion,
    required int toVersion,
  });
}

abstract class Migration {
  int get fromVersion;
  int get toVersion;
  Future<void> apply(Transaction txn);
}
```

**Sequential Migration Chain:**

Migrations are applied incrementally (v1→v2, v2→v3) rather than direct jumps (v1→v3). This:
- Simplifies testing (only test adjacent version pairs)
- Reduces migration complexity (no combinatorial explosion)
- Enables gradual rollouts (users can upgrade incrementally)

**Transaction Safety:**

Each migration runs in its own SQLite transaction with WAL mode:
- Atomicity: Migration either fully succeeds or fully rolls back
- Durability: Original file preserved via WAL until migration completes
- Isolation: No partial state visible during migration

### 3. Version Detection Strategy

**Older App + Newer Document:**

When an older app attempts to open a document with `format_version > app_supported_version`, the app:
1. Detects version mismatch in `LoadService._checkFormatVersion()`
2. Throws `VersionMismatchException` with user-friendly message
3. Displays error: `"This document requires WireTuner vX or later"`
4. Refuses to open document (prevents data corruption)

**Newer App + Older Document:**

When a newer app opens a document with `format_version < app_supported_version`, the app:
1. Detects older version in `LoadService._checkFormatVersion()`
2. Logs migration start: `"Migrating document from vX to vY"`
3. Calls `MigrationManager.applyMigrations()` with sequential migrations
4. Updates `metadata.format_version` within transaction
5. Proceeds with normal document loading

### 4. Backward Compatibility Policy

**Guarantees:**

- **N-1 Compatibility**: Current app version supports documents from previous version
- **Incremental Migration**: Documents can be migrated one version at a time
- **Event Preservation**: Migrations NEVER delete events from event log
- **Graceful Degradation**: Older apps detect newer versions and display clear errors

**Non-Guarantees:**

- **Downgrade Not Supported**: Cannot migrate v3 → v2 → v1 (would require lossy transformation)
- **Unbounded Backward Compatibility**: App may drop support for very old versions (e.g., v5 app may not support v1 documents)
- **Cross-Platform Consistency**: Migration results are guaranteed consistent only on the same platform (macOS, Windows, Linux)

### 5. Migration Authoring Guidelines

**When to Create a New Migration:**

Create a new migration when:
1. Adding required database tables or columns
2. Changing snapshot serialization format
3. Introducing non-ignorable event types
4. Milestone release includes file format changes

**Migration Implementation Checklist:**

- [ ] Implement `Migration` interface with `fromVersion`, `toVersion`, `apply()`
- [ ] Register migration in `MigrationManager` constructor
- [ ] Write unit tests verifying migration transforms data correctly
- [ ] Document breaking changes in migration class documentation
- [ ] Update `api/file_format_spec.md` with version history table
- [ ] Test migration with real v(N-1) documents from previous milestone
- [ ] Verify transaction rollback on migration failure

**Example Migration Template:**

```dart
class VersionNToNPlus1Migration implements Migration {
  @override
  int get fromVersion => N;

  @override
  int get toVersion => N + 1;

  @override
  Future<void> apply(Transaction txn) async {
    // 1. Log migration start
    Logger().d('Applying vN → v(N+1) migration...');

    // 2. Add new tables/columns
    await txn.execute('CREATE TABLE new_feature (...)');

    // 3. Transform existing data if needed
    // (Avoid if possible—additive changes preferred)

    // 4. Log completion
    Logger().i('vN → v(N+1) migration complete');
  }
}
```

## Rationale

### Why Semantic Versioning (Integer Major Only)?

**Simplicity:** Integer-only versioning avoids MAJOR.MINOR.PATCH complexity. File format changes are always breaking (major version bumps) because:
- Older apps cannot parse new tables/events
- Snapshot format changes require decode logic
- Event types must be recognized by all versions in a workflow

**Alternative Considered: MAJOR.MINOR Versioning**

Rejected because:
- Minor versions would signal "ignorable" changes, but SQLite schema additions are rarely truly ignorable
- Adds complexity to version comparison logic
- Doesn't match SQLite's built-in `PRAGMA user_version` convention (integer only)

### Why Automatic Migration Instead of Manual?

**User Experience:** Users expect seamless upgrades. Manual migration:
- Creates friction ("Convert file before opening?")
- Risks data loss (users skip migration, open with wrong version)
- Requires file duplication (original vs. migrated copy)

**Industry Standard:** Adobe Illustrator, Figma, Sketch all auto-migrate on load.

**Safety:** Transaction-based migration with WAL mode provides rollback safety equivalent to manual "save a copy" workflow.

### Why Sequential Migrations (v1→v2→v3) Instead of Direct Jumps?

**Testing Simplicity:**
- Only test N-1 adjacent pairs (v1→v2, v2→v3) instead of N² combinations
- Reduces combinatorial explosion as version count grows

**Implementation Simplicity:**
- Each migration handles one transformation (single responsibility)
- Easier to debug and maintain

**Incremental Rollout:**
- Users can upgrade apps incrementally without skipping versions

**Alternative Considered: Direct Jump Migrations**

Rejected because:
- Would require maintaining v1→v2, v1→v3, v2→v3 separately (3 migrations instead of 2)
- Exponential growth: 10 versions = 45 migration pairs vs. 9 sequential
- Higher bug surface area due to code duplication

### Why Transaction-Per-Migration Instead of Single Transaction?

**Incremental Progress:**
- If v1→v3 migration fails at v2→v3 step, v1→v2 progress is preserved
- User can retry after fixing v2 compatibility issue

**Metadata Consistency:**
- `format_version` updated after each step, not just at end
- File is always in consistent state (never partial migration)

**Telemetry Granularity:**
- Can log "v1→v2 took 50ms, v2→v3 took 120ms" for performance monitoring

**Trade-off:** Slightly slower than single transaction, but improved failure recovery and observability justify cost.

## Consequences

### Positive Consequences

1. **Seamless User Experience**: Users open older documents without manual conversion steps
2. **Safe Evolution**: Format can add features incrementally without breaking existing documents
3. **Clear Error Messages**: Version mismatches produce user-friendly errors, not cryptic crashes
4. **Testable Migrations**: Sequential migration chain simplifies unit testing and verification
5. **Audit Trail**: Migration logs provide debugging insights for support teams
6. **Backward Compatibility**: N-1 compatibility policy allows gradual app upgrades
7. **Transaction Safety**: WAL mode + per-migration transactions prevent data corruption

### Negative Consequences

1. **Migration Complexity**: Each format change requires writing and testing a migration
2. **Unbounded History**: Event log never deleted, files grow unboundedly (mitigated by optional compaction in future)
3. **No Downgrade Path**: Users cannot downgrade app and open newer documents (acceptable trade-off)
4. **Migration Performance Cost**: Large documents (10,000+ events) may take 500ms+ to migrate (acceptable one-time cost)
5. **Testing Burden**: Must test migration with real documents from each previous version
6. **Version Sprawl**: As versions accumulate, maintaining migration chain becomes more complex

### Mitigation Strategies

**Migration Complexity:**
- Provide migration template and documentation
- Keep migrations small and focused (single responsibility)
- Unit tests verify each migration independently

**Testing Burden:**
- Archive sample documents from each milestone for regression testing
- Automated CI tests verify migrations on real documents
- Integration tests cover full migration chains (v1→v2→v3)

**Version Sprawl:**
- Deprecate very old versions after N years (e.g., v1 support dropped in v10)
- Document supported version range in release notes
- Consider "migration fast-forward" for very old documents (v1→v10 directly)

**Performance:**
- Profile migrations during development
- Target < 500ms for typical documents (enforced by unit tests)
- Display progress indicator for long migrations (>1 second)

## Alternatives Considered

### 1. No Versioning (Always Overwrite)

**Description:** Always save documents in latest format, no version field, no migration.

**Why Rejected:**
- Breaks backward compatibility immediately
- Users opening old documents in new app would corrupt files
- No way to detect version mismatches and display errors
- Unacceptable for professional desktop application

### 2. Version-as-App-Version (e.g., "1.2.3")

**Description:** Store app version string instead of format version integer.

**Why Rejected:**
- App version changes more frequently than format (bug fixes, UI tweaks)
- No clear way to determine if migration is needed ("1.2.3" → "1.3.0" requires format change?)
- Complicates version comparison logic (string parsing vs. integer compare)
- Doesn't align with SQLite's `PRAGMA user_version` convention

### 3. All-in-One Transaction for Multi-Step Migration

**Description:** Apply all migrations (v1→v2→v3) in a single transaction.

**Why Rejected:**
- Loss of incremental progress (failure at v2→v3 rolls back v1→v2)
- No per-migration telemetry (cannot isolate performance bottlenecks)
- Metadata inconsistency during migration (version stays at v1 until end)

### 4. Copy-on-Migration (Preserve Original File)

**Description:** Create `.wiretuner.backup` file before migrating.

**Why Rejected:**
- Doubles disk usage for every migration
- Users accumulate orphaned backup files
- WAL mode already provides rollback safety
- Backup creation adds significant time (file copy overhead)

**Compromise:** Document that users should use OS-level backups (Time Machine, File History) for disaster recovery, not in-app backups.

## References

- **Architecture Blueprint Section 5.2**: Format evolution strategy (`.codemachine/artifacts/architecture/06_Rationale_and_Future.md#constraint-compatibility`)
- **File Format Spec Section 5**: Semantic versioning rules (`api/file_format_spec.md#semantic-versioning`)
- **File Format Spec Section 7**: Migration strategies (`api/file_format_spec.md#migration-strategies`)
- **Task I9.T3**: File format versioning implementation (`.codemachine/artifacts/plan/02_Iteration_I9.md#task-i9-t3`)
- **LoadService**: Document loading with version detection (`lib/infrastructure/file_ops/load_service.dart`)
- **MigrationManager**: Migration orchestration logic (`lib/infrastructure/persistence/migrations/migration_manager.dart`)
- **Version1To2Migration**: Example migration implementation (`lib/infrastructure/persistence/migrations/version_1_to_2.dart`)

---

**This ADR establishes the file format versioning strategy that enables WireTuner to evolve gracefully while maintaining backward compatibility. All file format changes must follow the versioning rules, migration guidelines, and compatibility guarantees defined in this document.**
