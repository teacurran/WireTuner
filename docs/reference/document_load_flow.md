# Document Load Flow

**Status:** Active
**Last Updated:** 2025-11-09
**Related:** [File Format Spec](../../api/file_format_spec.md), [SaveService](../../packages/io_services/lib/src/save_service.dart), [Architecture Decision 3](../../.codemachine/artifacts/architecture/06_Rationale_and_Future.md#decision-sqlite)

---

## Overview

This document describes how WireTuner loads `.wiretuner` files, including version compatibility checking, automatic migration, snapshot-based state reconstruction, and error handling flows.

**Key Components:**
- `LoadService`: Orchestrates the load process
- `ConnectionFactory`: Manages SQLite database connections
- `MigrationRunner`: Handles schema upgrades
- `EventReplayer`: Reconstructs document state from events
- `OpenDialogs`: UI for load progress, errors, and warnings

---

## Load Flow Diagram

```
┌─────────────┐
│ User Opens  │
│ File Dialog │
└──────┬──────┘
       │
       v
┌─────────────────────┐
│ LoadService.load()  │
└──────┬──────────────┘
       │
       v
┌──────────────────────┐
│ 1. Check file exists │
│ 2. Open DB connection│
└──────┬───────────────┘
       │
       v
┌────────────────────────┐
│ 3. PRAGMA integrity_   │
│    check (validate DB) │
└──────┬─────────────────┘
       │
       v
┌────────────────────────┐
│ 4. Read metadata table │
│    - document_id       │
│    - title             │
│    - format_version    │
└──────┬─────────────────┘
       │
       v
┌────────────────────────────┐
│ 5. Check Version           │
│ Compatibility              │
└──┬─────────────────────────┘
   │
   ├──[version > current]──> Reject (unsupported)
   │                          Show upgrade dialog
   │
   ├──[version < current]──> Migrate (v0 → v1)
   │                          Run MigrationRunner
   │
   └──[version == current]─> Proceed
                              │
                              v
                    ┌─────────────────────┐
                    │ 6. Get max event    │
                    │    sequence number  │
                    └──────┬──────────────┘
                           │
                           v
                    ┌─────────────────────┐
                    │ 7. Load snapshot +  │
                    │    replay events    │
                    │    (EventReplayer)  │
                    └──────┬──────────────┘
                           │
                           v
                    ┌─────────────────────┐
                    │ 8. Hydrate          │
                    │    UndoNavigator    │
                    └──────┬──────────────┘
                           │
                           v
                    ┌─────────────────────┐
                    │ 9. Update UI        │
                    │    - Recent files   │
                    │    - Success toast  │
                    └─────────────────────┘
```

---

## Step-by-Step Load Process

### 1. File Selection

**UI Entry Points:**
- File → Open menu (Cmd+O / Ctrl+O)
- Recent Files menu
- Drag-and-drop onto app window (future)

**Implementation:**
```dart
final dialogs = OpenDialogs();
final filePath = await dialogs.showOpenDialog(context: context);

if (filePath != null) {
  _loadDocument(filePath);
}
```

### 2. Connection Establishment

**Purpose:** Open SQLite database connection via ConnectionFactory

**Code:**
```dart
final config = DatabaseConfig.file(filePath: filePath);
final db = await _connectionFactory.openConnection(
  documentId: documentId,
  config: config,
  runMigrations: false, // We check version first
);
```

**Errors:**
- `fileNotFound`: File does not exist or was deleted
- `permissionDenied`: No read permissions or file locked
- `corruptedDatabase`: SQLite file is damaged

### 3. Integrity Validation

**Purpose:** Verify database is not corrupted before reading

**Code:**
```dart
final result = await db.rawQuery('PRAGMA integrity_check');
final status = result.first.values.first as String;

if (status != 'ok') {
  // Database is corrupted - show error dialog
}
```

**On Failure:** Show corruption dialog, suggest restoring from backup

### 4. Metadata Validation

**Purpose:** Ensure metadata table exists and contains document info

**Code:**
```dart
final metadata = await db.rawQuery('SELECT * FROM metadata LIMIT 1');

if (metadata.isEmpty) {
  throw LoadFailure(errorType: LoadErrorType.metadataMissing, ...);
}

final fileFormatVersion = metadata.first['format_version'] as int;
final documentTitle = metadata.first['title'] as String;
```

**Schema Reference:**
```sql
CREATE TABLE metadata (
  document_id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  format_version INTEGER NOT NULL,  -- CRITICAL: Must check before opening
  created_at INTEGER NOT NULL,
  modified_at INTEGER NOT NULL,
  author TEXT
);
```

### 5. Version Compatibility Check

**Purpose:** Ensure file format version is supported

**Compatibility Matrix:**

| File Version | App Version | Action | User Experience |
|--------------|-------------|--------|-----------------|
| `1` | `1` | ✅ Open normally | No migration, instant load |
| `0` (legacy) | `1` | ⚙️ Migrate | Show "Upgrading file…" progress |
| `2` (future) | `1` | ❌ Reject | Show "Incompatible File Version" error |

**Implementation:**
```dart
enum VersionCompatibility {
  supported,       // Exact match
  needsMigration,  // Older version
  unsupported,     // Future version
}

VersionCompatibility _checkVersionCompatibility(int fileFormatVersion) {
  if (fileFormatVersion == currentFormatVersion) {
    return VersionCompatibility.supported;
  } else if (fileFormatVersion < currentFormatVersion) {
    return VersionCompatibility.needsMigration;
  } else {
    return VersionCompatibility.unsupported;
  }
}
```

**Error Dialog (Unsupported Version):**
```
Incompatible File Version

This file was created with WireTuner version 2 or newer.
You are running version 1.

Please upgrade to the latest version of WireTuner to open this file.

Download: https://wiretuner.app/download

[Close]
```

### 6. Migration (if needed)

**Purpose:** Upgrade older file formats to current schema

**Migration Path: v0 → v1**

Legacy v0 snapshots lack the versioned header:
- **Raw GZip:** BLOB starts with `0x1f, 0x8b`
- **Raw JSON:** BLOB starts with `{` (0x7B)

**Migration Steps:**
1. Detect legacy format (check magic bytes)
2. Extract payload (decompress if GZip)
3. Parse JSON and validate
4. Re-serialize with v1 header (magic, version, CRC32)
5. Update `metadata.format_version = 1`
6. Log migration event

**Code:**
```dart
final migrationRunner = MigrationRunner(db);
await migrationRunner.runMigrations();

logger.i('[load] Migrated document $documentId from v$fileFormatVersion to v1');
```

**Performance Target:** < 500ms for typical documents (< 10 MB)

### 7. Event Replay

**Purpose:** Reconstruct document state from snapshot + events

**Strategy:**
1. Find most recent snapshot at or before `maxSequence`
2. Validate snapshot CRC32 (detect corruption)
3. Deserialize snapshot BLOB → base Document
4. Query events WHERE `event_sequence > snapshotSeq`
5. Replay events via EventReplayer

**Code:**
```dart
final maxSequence = await eventGateway.getLatestSequenceNumber();

await _eventReplayer.replayFromSnapshot(maxSequence: maxSequence);
```

**Snapshot Corruption Handling:**

If CRC32 validation fails:
1. Log error: `"CRC32 checksum validation failed: expected 0x124B2FA3, got 0x89ABCDEF"`
2. Discard corrupted snapshot
3. Fall back to previous snapshot
4. Replay events from earlier snapshot to current sequence
5. Show warning dialog: "Snapshot Corruption Detected"

**Performance:**
- Target: < 100ms for documents with < 10K events
- Typical: 20-50ms for 1K events

### 8. UndoNavigator Hydration

**Purpose:** Reset undo/redo stacks for the loaded document

**Code:**
```dart
undoNavigator.reset(); // Clear existing state
// Navigator will rebuild stacks as events are replayed
```

**Important:** The navigator must be reset BEFORE replay to avoid stale references to previous documents.

### 9. UI Updates

**Success Flow:**
```dart
// Show success toast
dialogs.showLoadSuccess(
  context: context,
  message: 'Document loaded successfully',
  filePath: filePath,
);

// Update recent files menu
recentFilesManager.addRecentFile(filePath, documentTitle);

// Update window title
setWindowTitle(documentTitle);
```

**Telemetry:**
```dart
logger.i(
  '[load] Completed: doc=$documentId, seq=$maxSequence, '
  'duration=${durationMs}ms, migrated=$wasMigrated, path=$filePath',
);
```

---

## Error Handling

### Error Types

```dart
enum LoadErrorType {
  fileNotFound,       // File does not exist
  permissionDenied,   // Cannot read file
  corruptedDatabase,  // SQLite integrity check failed
  unsupportedVersion, // File version > app version
  migrationFailed,    // Upgrade failed
  snapshotCorrupted,  // CRC32 mismatch
  replayFailed,       // Event replay crashed
  metadataMissing,    // Invalid schema
  unknown,            // Unexpected error
}
```

### Example Error Dialogs

**File Not Found:**
```
Load Failed

File not found: "/path/to/document.wiretuner".

The file may have been moved or deleted.

[OK]
```

**Permission Denied:**
```
Load Failed

Cannot read file: "/path/to/document.wiretuner".

Check file permissions and ensure the file is not locked
by another application.

[OK]
```

**Corrupted Database:**
```
Load Failed

Database corruption detected in "/path/to/document.wiretuner".

The file may be damaged. Consider restoring from a backup.

[OK]
```

---

## Testing

### Unit Tests

**File:** `packages/io_services/test/load_service_test.dart`

Tests cover:
- ✅ Happy path: loading valid document
- ✅ Unsupported version rejection
- ✅ Metadata validation
- ✅ Concurrent load guard
- ✅ Error categorization

**Run:**
```bash
just test-unit packages/io_services
```

### Integration Tests

**File:** `test/integration/test/integration/save_load_roundtrip_test.dart`

Tests cover:
- ✅ Save → Load → Verify state equality
- ✅ Multiple save cycles
- ✅ Event persistence
- ✅ Metadata preservation
- ✅ Version validation

**Run:**
```bash
just test-integration
```

---

## Code Examples

### Basic Load Flow

```dart
import 'package:io_services/io_services.dart';
import 'package:app_shell/app_shell.dart';

class DocumentLoader {
  final LoadService loadService;
  final OpenDialogs dialogs;

  Future<void> openDocument(BuildContext context) async {
    // 1. Show file picker
    final filePath = await dialogs.showOpenDialog(context: context);
    if (filePath == null) return; // User canceled

    // 2. Show progress
    dialogs.showLoadProgress(
      context: context,
      message: 'Loading document...',
    );

    // 3. Perform load
    final result = await loadService.load(
      documentId: 'doc-${DateTime.now().millisecondsSinceEpoch}',
      filePath: filePath,
    );

    // 4. Hide progress
    dialogs.hideLoadProgress(context);

    // 5. Handle result
    switch (result) {
      case LoadSuccess(:final documentId, :final title, :final wasMigrated):
        dialogs.showLoadSuccess(
          context: context,
          message: 'Loaded: $title',
          filePath: filePath,
        );

        if (wasMigrated) {
          // Show migration notice
          logger.i('Document migrated successfully');
        }

      case LoadFailure(:final errorType, :final userMessage):
        dialogs.showLoadError(
          context: context,
          message: userMessage,
          filePath: filePath,
        );

        if (errorType == LoadErrorType.unsupportedVersion) {
          // Optionally show upgrade instructions
        }
    }
  }
}
```

### Version Warning Example

```dart
if (result case LoadFailure(errorType: LoadErrorType.unsupportedVersion, :final userMessage)) {
  await dialogs.showVersionWarning(
    context: context,
    fileVersion: 2,
    appVersion: 1,
  );
}
```

### Snapshot Corruption Recovery

```dart
try {
  await loadService.load(documentId: docId, filePath: path);
} catch (e) {
  if (e is SnapshotCorruptionError) {
    await dialogs.showSnapshotCorruptionWarning(context: context);
    // Load may still succeed via fallback
  }
}
```

---

## Performance Benchmarks

**Target Latencies (Decision 1):**
- Integrity check: < 20ms
- Metadata read: < 10ms
- Version check: < 1ms
- Migration (v0 → v1): < 500ms
- Snapshot load: < 50ms
- Event replay (1K events): < 50ms
- **Total load time: < 100ms** (excluding migration)

**Measured (I4.T9):**
- Load time (no snapshot): ~20-50ms
- Load time (with snapshot): ~10-30ms
- Migration (v0 → v1): ~200-400ms

---

## Related Documentation

- [File Format Specification](../../api/file_format_spec.md) - Normative schema and version rules
- [File Versioning Notes](file_versioning_notes.md) - Implementation guidance
- [SaveService](../../packages/io_services/lib/src/save_service.dart) - Document save orchestrator
- [Architecture Decision 3](../.codemachine/artifacts/architecture/06_Rationale_and_Future.md#decision-sqlite) - SQLite rationale
- [History Panel Checklist](../qa/history_checklist.md) - QA validation steps
- [Crash Recovery Playbook](../qa/recovery_playbook.md) - Recovery validation

---

## Changelog

| Date | Change | Author |
|------|--------|--------|
| 2025-11-09 | Initial document load flow guide | System |

---

**Questions or Issues?**
File issues at [WireTuner GitHub Repository](https://github.com/wiretuner/wiretuner/issues)
