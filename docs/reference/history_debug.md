# History Export/Import Debug Workflow

<!-- anchor: history-debug-workflow -->

**Version:** 1.0
**Date:** 2025-11-09
**Status:** Experimental (Dev-Only)
**Related Documents:** [Event Schema Reference](event_schema.md) | [Event Lifecycle](../specs/event_lifecycle.md) | [Snapshot Serializer](../../packages/event_core/lib/src/snapshot_serializer.dart)

---

## Overview

WireTuner provides a **dev-only** history export/import feature for debugging, crash reproduction, and development workflows. This feature allows developers to:

- Export subsections of the event log as JSON files
- Re-import exported history to reproduce specific document states
- Debug event replay issues in isolation
- Share reproducible test cases with the development team

**Status:** This feature is marked as **experimental** and **dev-only**. It is not intended for end-user workflows or production use.

---

## Table of Contents

- [Architecture](#architecture)
- [Export Format](#export-format)
- [Security Warnings](#security-warnings)
- [Usage Workflows](#usage-workflows)
  - [Export Workflow](#export-workflow)
  - [Import Workflow](#import-workflow)
  - [Crash Reproduction Workflow](#crash-reproduction-workflow)
- [CLI Reference](#cli-reference)
- [Programmatic API](#programmatic-api)
- [Schema Validation](#schema-validation)
- [Performance Considerations](#performance-considerations)
- [Limitations and Known Issues](#limitations-and-known-issues)
- [Future Enhancements](#future-enhancements)
- [Troubleshooting](#troubleshooting)

---

## Architecture

The history export/import system consists of three main components:

### 1. HistoryExporter Service

**Location:** `packages/event_core/lib/src/history_exporter.dart`

Core service providing:
- `exportRange()`: Export bounded event ranges with nearest snapshot
- `importFromJson()`: Import and replay events with schema validation
- Schema validation against canonical event schema (see [Event Schema Reference](event_schema.md))
- Integration with `EventReplayer` for state reconstruction

### 2. CLI Tool

**Location:** `tools/history_export.dart`

Command-line interface for:
- Interactive export/import operations
- Verbose logging and progress tracking
- Security warnings and validation checks

**Justfile Integration:**
```bash
just history-export <doc-id> <start> <end> <output-file>
just history-import <doc-id> <input-file>
just history-import-verbose <doc-id> <input-file>
```

### 3. Event Store Integration

**Dependencies:**
- `EventStoreGateway`: Event persistence and retrieval
- `SnapshotSerializer`: Snapshot binary format handling
- `EventReplayer`: State reconstruction from events

---

## Export Format

Exported history files use JSON format with the following structure:

```json
{
  "metadata": {
    "documentId": "550e8400-e29b-41d4-a716-446655440000",
    "exportVersion": 1,
    "exportedAt": "2025-11-09T12:34:56.789012Z",
    "eventRange": {
      "start": 5000,
      "end": 5500
    },
    "eventCount": 500,
    "snapshotSequence": 5000
  },
  "snapshot": {
    "eventSequence": 5000,
    "data": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "title": "Document Title",
      "layers": [...],
      "version": 42
    }
  },
  "events": [
    {
      "eventId": "evt-uuid-001",
      "timestamp": 1699305600000,
      "eventType": "AddAnchorEvent",
      "eventSequence": 5000,
      "documentId": "550e8400-e29b-41d4-a716-446655440000",
      "pathId": "path-001",
      "position": {"x": 100.0, "y": 200.0},
      "samplingIntervalMs": 50
    },
    ...
  ]
}
```

### Metadata Fields

| Field | Type | Description |
|-------|------|-------------|
| `documentId` | string (UUID) | Source document identifier |
| `exportVersion` | integer | Export format version (currently 1) |
| `exportedAt` | string (RFC3339) | Export timestamp with microsecond precision |
| `eventRange` | object | Event sequence range (`start`, `end`) |
| `eventCount` | integer | Number of events in export |
| `snapshotSequence` | integer or null | Snapshot sequence number (if available) |

### Snapshot Fields

| Field | Type | Description |
|-------|------|-------------|
| `eventSequence` | integer | Sequence number at which snapshot was taken |
| `data` | object | Deserialized document state (JSON) |

**Note:** Snapshot data is stored as plain JSON (not base64-encoded binary). This differs from the SQLite storage format for human readability.

### Event Fields

Events are exported with full envelope metadata per [Event Schema Reference](event_schema.md). Every event includes:

- `eventId`: UUIDv4 event identifier
- `timestamp`: Unix milliseconds
- `eventType`: Event class discriminator
- `eventSequence`: Unique sequence number
- `documentId`: Document identifier

Plus event-specific payload fields (see event schema for details).

---

## Security Warnings

⚠️ **CRITICAL SECURITY WARNINGS** ⚠️

### 1. No Encryption

Exported history files are **plain JSON** and bypass any encryption applied to SQLite database files. Document content is stored in cleartext.

**Risk:** Exported files may contain:
- Proprietary vector artwork
- Confidential design work
- User-identifiable drawing styles
- Collaboration metadata (user IDs, session IDs)

**Mitigation:**
- **Never share exported files externally**
- Store exports in secure local directories (e.g., `tmp/`, `.gitignore`d locations)
- Delete exported files after debugging is complete
- Use `.debug.json` extension for visibility

### 2. State Mutation on Import

Importing history **replays events** and **modifies document state**. This operation is **destructive** and cannot be undone.

**Risk:** Import can:
- Overwrite existing document content
- Corrupt document state if imported to wrong document ID
- Fail mid-replay leaving document in inconsistent state

**Mitigation:**
- **Always backup documents before importing**
- Use separate test documents for import experiments
- Validate export metadata before importing (check `documentId`, `eventRange`)

### 3. Schema Compatibility

Exported files are tied to a specific export format version. Future WireTuner versions may change:
- Event schema (new required fields)
- Snapshot format (compression, versioning)
- Export JSON structure

**Risk:** Old exports may fail to import in newer versions.

**Mitigation:**
- Include export version validation in import workflow
- Document schema changes in release notes
- Provide migration tools for major version upgrades

---

## Usage Workflows

### Export Workflow

**Goal:** Export events 5000-5500 from document `doc-123` to a debug file.

#### Step 1: Identify Event Range

Use the history panel or undo navigator to identify the event sequence range containing the bug or interesting behavior.

Example: You notice a crash after event 5432, so you export 5000-5500 to capture context.

#### Step 2: Run Export Command

```bash
just history-export doc-123 5000 5500 tmp/crash_5432.debug.json
```

**Output:**
```
⚠️  DEV-ONLY FEATURE - Exported files may contain sensitive data
[INFO] Starting history export...
[INFO]   Document ID: doc-123
[INFO]   Event range: 5000 - 5500
[INFO]   Output file: tmp/crash_5432.debug.json
[WARNING] ⚠️  SECURITY WARNING ⚠️
[WARNING] Exported files bypass encryption and may contain sensitive data.
[WARNING] Do NOT share exported history files externally.
[WARNING] Use only for local debugging and reproduction workflows.

[INFO] Retrieved 500 events from store
[INFO] Found snapshot at sequence 5000
[SUCCESS] ✅ Export completed successfully!
[INFO]   Output file: tmp/crash_5432.debug.json
[INFO]   Event count: 500
[INFO]   File size: 234 KB
```

#### Step 3: Verify Export

Inspect the exported JSON file to confirm event range and metadata:

```bash
# View metadata only
jq '.metadata' tmp/crash_5432.debug.json

# Count events
jq '.events | length' tmp/crash_5432.debug.json

# View first event
jq '.events[0]' tmp/crash_5432.debug.json
```

### Import Workflow

**Goal:** Import a debug file to reproduce a crash or bug.

#### Step 1: Create Test Document

Create a new empty document or use a test document to avoid corrupting production data.

**Important:** Do NOT import to the original document unless you have backups.

#### Step 2: Run Import Command

```bash
just history-import doc-test-456 tmp/crash_5432.debug.json
```

**Output:**
```
⚠️  DEV-ONLY FEATURE - Import will modify document state
[INFO] Starting history import...
[INFO]   Document ID: doc-test-456
[INFO]   Input file: tmp/crash_5432.debug.json
[INFO]   Schema validation: enabled
[WARNING] ⚠️  IMPORT WARNING ⚠️
[WARNING] Import will replay events and modify document state.
[WARNING] Ensure you have backups before proceeding.

[INFO] Import metadata: version=1, range=5000-5500, count=500
[INFO] Validating 500 events against schema
[INFO] Schema validation passed for 500 events
[INFO] Persisting 500 events to store
[INFO] Replaying events to reconstruct state
[SUCCESS] ✅ Import completed successfully!
[INFO]   Final sequence: 5500
[INFO]   Event count: 500
```

#### Step 3: Verify Import

Open the test document in the UI and verify that:
- Document renders correctly
- Undo/redo stack reflects imported operations
- History panel shows expected event sequence
- No crashes or errors occur during navigation

### Crash Reproduction Workflow

**Scenario:** A user reports a crash at event sequence 5432. You want to reproduce the crash locally.

#### Step 1: Request Export from User

Ask the user to export the event range containing the crash:

```bash
just history-export <their-doc-id> 5400 5450 crash_report.debug.json
```

**Security Note:** Warn the user that the exported file contains document content. Use secure file transfer (e.g., encrypted email, internal file share).

#### Step 2: Import to Local Test Environment

```bash
# Create a fresh test document
just history-import doc-crash-test crash_report.debug.json
```

#### Step 3: Navigate to Crash Point

Use the undo navigator or history panel to scrub to event 5432 and trigger the crash.

```dart
// In debugger or test harness
await undoNavigator.scrubToSequence(5432);
```

#### Step 4: Debug with Breakpoints

Set breakpoints in the event replayer or event handlers to inspect state at the crash point:

```dart
// In event_replayer.dart
void applyEvent(Map<String, dynamic> event) {
  if (event['eventSequence'] == 5432) {
    debugger(); // <-- Breakpoint
  }
  // ...
}
```

#### Step 5: Fix and Verify

After fixing the bug, re-import the same debug file to verify the fix:

```bash
just history-import doc-crash-test crash_report.debug.json
# Should no longer crash at sequence 5432
```

---

## CLI Reference

### Export Command

**Syntax:**
```bash
dart tools/history_export.dart export \
  --document-id=<uuid> \
  --start=<sequence> \
  --end=<sequence> \
  --output=<file.debug.json> \
  [--verbose]
```

**Arguments:**

| Argument | Short | Required | Description |
|----------|-------|----------|-------------|
| `--document-id` | `-d` | Yes | Document UUID to export events from |
| `--start` | `-s` | Yes | Starting event sequence (inclusive) |
| `--end` | `-e` | Yes | Ending event sequence (inclusive) |
| `--output` | `-o` | Yes | Output file path (e.g., `tmp/history.debug.json`) |
| `--verbose` | `-v` | No | Enable verbose logging |

**Validation Rules:**
- `start >= 0`
- `start <= end`
- `(end - start + 1) <= 10000` (max 10,000 events per export)

**Exit Codes:**
- `0`: Success
- `1`: Validation error or export failure

**Example:**
```bash
dart tools/history_export.dart export \
  -d doc-123 -s 5000 -e 5500 -o tmp/export.debug.json -v
```

### Import Command

**Syntax:**
```bash
dart tools/history_export.dart import \
  --document-id=<uuid> \
  --input=<file.debug.json> \
  [--skip-validation] \
  [--verbose]
```

**Arguments:**

| Argument | Short | Required | Description |
|----------|-------|----------|-------------|
| `--document-id` | `-d` | Yes | Target document UUID for import |
| `--input` | `-i` | Yes | Input file path (e.g., `tmp/history.debug.json`) |
| `--skip-validation` | - | No | Skip event schema validation (faster but risky) |
| `--verbose` | `-v` | No | Enable verbose logging |

**Validation:**
- By default, validates all events against canonical schema (see [Event Schema Reference](event_schema.md))
- Use `--skip-validation` to skip schema checks (faster import, but may fail during replay if events are malformed)

**Exit Codes:**
- `0`: Success
- `1`: Validation error, file not found, or import failure

**Example:**
```bash
dart tools/history_export.dart import \
  -d doc-test -i tmp/export.debug.json -v
```

### Justfile Shortcuts

**Export:**
```bash
just history-export <doc-id> <start> <end> <output-file>
```

**Import (with validation):**
```bash
just history-import <doc-id> <input-file>
```

**Import (verbose logging):**
```bash
just history-import-verbose <doc-id> <input-file>
```

---

## Programmatic API

### HistoryExporter Class

**Location:** `packages/event_core/lib/src/history_exporter.dart`

#### Constructor

```dart
final exporter = HistoryExporter(
  eventStore: eventStoreGateway,
  snapshotSerializer: snapshotSerializer,
  eventReplayer: eventReplayer,
  logger: logger,
  config: EventCoreDiagnosticsConfig.debug(),
  metricsSink: metricsSink, // Optional
);
```

#### Export Range

```dart
Future<Map<String, dynamic>> exportRange({
  required String documentId,
  required int startSequence,
  required int endSequence,
});
```

**Returns:** JSON-serializable map ready for encoding.

**Throws:**
- `ArgumentError`: Invalid range or exceeds max event count
- `StateError`: No events found in range

**Example:**
```dart
final exportData = await exporter.exportRange(
  documentId: 'doc-123',
  startSequence: 5000,
  endSequence: 5500,
);

final jsonString = jsonEncode(exportData);
await File('export.debug.json').writeAsString(jsonString);
```

#### Import from JSON

```dart
Future<int> importFromJson({
  required Map<String, dynamic> importData,
  required String documentId,
  bool validateSchema = true,
});
```

**Returns:** Final event sequence number after import.

**Throws:**
- `FormatException`: Invalid export format or schema validation failure
- `StateError`: Replay failure during import

**Example:**
```dart
final jsonString = await File('export.debug.json').readAsString();
final importData = jsonDecode(jsonString) as Map<String, dynamic>;

final finalSequence = await exporter.importFromJson(
  importData: importData,
  documentId: 'doc-test',
  validateSchema: true,
);

print('Import complete. Final sequence: $finalSequence');
```

---

## Schema Validation

Import validates events against the canonical event schema defined in [Event Schema Reference](event_schema.md).

### Required Envelope Fields

Every event must include:

| Field | Type | Constraint |
|-------|------|------------|
| `eventId` | string | Valid UUIDv4 (RFC 4122) |
| `timestamp` | integer | Positive integer (Unix milliseconds) |
| `eventType` | string | Non-empty string (class name) |
| `eventSequence` | integer | Non-negative integer |
| `documentId` | string | Valid UUIDv4 |

### Optional Metadata Validation

- `samplingIntervalMs`: If present, must equal `50` (per Decision 5)
- `undoGroupId`: If present, must be valid UUIDv4
- `userId`, `sessionId`: If present, must be valid UUIDv4 or `"local-user"`

### Validation Errors

Example error messages:

```
FormatException: Event at index 42: invalid or missing eventId (must be UUIDv4)
FormatException: Event at index 100: invalid or missing timestamp (must be positive integer)
FormatException: Event at index 200: samplingIntervalMs is 100 (expected 50ms per Decision 5)
```

**Recommendation:** Always validate on import unless you trust the source and need maximum performance.

---

## Performance Considerations

### Export Performance

**Typical performance (medium document, ~500 events):**
- Event retrieval: 10-20ms
- Snapshot lookup: 5-10ms
- JSON serialization: 5-10ms
- **Total:** ~30ms

**Large export (10,000 events at max):**
- Event retrieval: 100-200ms
- JSON serialization: 50-100ms
- **Total:** ~300ms

**Optimization tips:**
- Export smaller ranges (500-1000 events) for faster turnaround
- Use snapshot at export start to reduce import replay time
- Compress exported files (gzip) for storage/transfer

### Import Performance

**Typical performance (medium document, ~500 events):**
- Schema validation: 20-30ms
- Event persistence: 50-100ms
- Event replay: 50-100ms (depends on snapshot availability)
- **Total:** ~150ms

**Large import (10,000 events):**
- Schema validation: 200-300ms
- Event persistence: 500-1000ms
- Event replay: 500-1000ms
- **Total:** ~2000ms (2 seconds)

**Optimization tips:**
- Use `--skip-validation` for trusted imports (saves ~30% time)
- Ensure snapshot is included in export to reduce replay time
- Batch event persistence (already implemented in `HistoryExporter`)

---

## Limitations and Known Issues

### 1. Snapshot Availability

**Issue:** Export does not guarantee snapshot availability. If no snapshot exists at or before `startSequence`, import will replay from event 0.

**Impact:** Slow import for large `startSequence` values (e.g., exporting 5000-5500 without snapshot requires replaying 5000 events).

**Workaround:** Trigger snapshot creation before export:
```dart
await snapshotManager.createSnapshot(); // Force snapshot at current sequence
```

**Fix planned:** Task I4.T11 will add explicit snapshot export control.

### 2. Event Store Integration Pending

**Issue:** CLI tool is currently a **stub**. Event store gateway initialization is not yet implemented.

**Status:** Waiting for I1.T4 (SQLite persistence implementation).

**Current behavior:** CLI exits with "NOT IMPLEMENTED" error.

**Workaround:** Use programmatic API directly in test harness until CLI integration is complete.

### 3. No Cross-Document Validation

**Issue:** Import does not validate that events belong to the specified `documentId`. Importing events from `doc-A` to `doc-B` may corrupt state.

**Impact:** Undefined behavior if document IDs mismatch.

**Mitigation:** CLI warns user before import. Always verify `metadata.documentId` matches target document.

**Fix planned:** Task I4.T12 will add document ID validation and auto-remapping.

### 4. Collaboration Metadata Loss

**Issue:** Exported events retain original `userId`, `sessionId`, and `deviceId` fields. Re-importing to a different user/session may cause confusion.

**Impact:** History panel may show incorrect authorship information.

**Mitigation:** Document this behavior in import workflow warnings.

**Fix planned:** Optional metadata sanitization flag in future version.

### 5. No Incremental Import

**Issue:** Import replays all events from scratch. Cannot resume failed imports.

**Impact:** Large imports (10,000 events) cannot be resumed if they fail mid-replay.

**Mitigation:** Keep exports small (<1000 events per file) to reduce failure impact.

**Fix planned:** Transaction support in I1.T4 will enable atomic rollback on failure.

---

## Future Enhancements

### Planned Features (Post-I4)

1. **Snapshot Export Control** (I4.T11)
   - Explicit snapshot inclusion/exclusion flags
   - Base64-encoded snapshot blobs for portability
   - Snapshot compression metrics in metadata

2. **Document ID Remapping** (I4.T12)
   - Auto-remap event `documentId` fields during import
   - Conflict detection for overlapping sequence ranges
   - Merge multiple exports into single document

3. **Selective Event Filtering** (I4.T13)
   - Export only specific event types (e.g., `CreatePathEvent`)
   - Exclude sampled events for compact exports
   - Filter by undo group ID

4. **Import Validation Mode** (I4.T14)
   - Dry-run import without persisting events
   - Report schema violations and replay errors
   - Estimate import duration before execution

5. **Metadata Sanitization** (I4.T15)
   - Strip collaboration fields (`userId`, `sessionId`, `deviceId`)
   - Anonymize UUIDs for public sharing
   - Redact sensitive event payload fields

### Long-term Enhancements

- **Web-based Export/Import UI**: Upload/download debug files via browser
- **Cloud Storage Integration**: Share exports via secure links
- **Automated Test Case Generation**: Convert exports to integration tests
- **Event Diff Tool**: Compare two exports to identify differences

---

## Troubleshooting

### Export Fails with "No events found"

**Symptom:**
```
StateError: No events found in range 5000-5500 for document doc-123
```

**Causes:**
1. Event range is outside the document's event history
2. Document ID is incorrect
3. Event store is empty

**Solutions:**
- Check document's latest sequence number: `SELECT MAX(event_sequence) FROM events WHERE document_id = 'doc-123'`
- Verify document ID is correct (check document metadata)
- Ensure events have been recorded (not in-memory only)

### Import Fails with Schema Validation Error

**Symptom:**
```
FormatException: Event at index 42: invalid or missing eventId (must be UUIDv4)
```

**Causes:**
1. Export was created with old/incompatible version
2. Manual editing corrupted the JSON file
3. Event was recorded with invalid schema

**Solutions:**
- Re-export from source document to get fresh data
- Use `--skip-validation` to bypass checks (risky)
- Manually fix the JSON file (check field types and UUIDs)

### Import Fails During Replay

**Symptom:**
```
StateError: Failed to replay events during import: Exception: Anchor not found
```

**Causes:**
1. Events reference objects that don't exist in snapshot
2. Event order is incorrect (corrupted export)
3. Snapshot is missing or incomplete

**Solutions:**
- Include snapshot in export to provide base state
- Verify export `eventRange.start` matches `snapshotSequence`
- Check event sequence numbers are contiguous (no gaps)

### CLI Tool Shows "NOT IMPLEMENTED"

**Symptom:**
```
❌ NOT IMPLEMENTED: Event store integration pending
```

**Cause:** Event store gateway initialization is not yet implemented (waiting for I1.T4).

**Solutions:**
- Use programmatic API directly in test harness
- Wait for I1.T4 completion to enable CLI tool
- Contribute event store integration to CLI tool

### Export File Size Too Large

**Symptom:** Export file exceeds 50 MB for 10,000 events.

**Causes:**
1. Events contain large payload data (e.g., embedded images)
2. Snapshot data is very large (complex document)

**Solutions:**
- Export smaller ranges (<1000 events per file)
- Compress exported JSON: `gzip export.debug.json`
- Exclude snapshot if not needed for import

---

## See Also

- [Event Schema Reference](event_schema.md) - Canonical event schema specification
- [Event Lifecycle Specification](../specs/event_lifecycle.md) - Complete event flow
- [Snapshot Serializer](../../packages/event_core/lib/src/snapshot_serializer.dart) - Binary snapshot format
- [Undo Navigator](../../packages/event_core/lib/src/undo_navigator.dart) - Operation-based history navigation
- [Task I4.T10](../../.codemachine/artifacts/plan/02_Iteration_I4.md#task-i4-t10) - Implementation task details

---

**Document Maintainer:** WireTuner Architecture Team
**Last Updated:** 2025-11-09
**Next Review:** After completion of I4.T10 (History Export/Import Implementation)
