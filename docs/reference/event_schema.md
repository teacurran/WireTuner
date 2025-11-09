# Event Schema Reference

<!-- anchor: event-schema-reference -->

**Version:** 1.0
**Date:** 2025-11-08
**Status:** Active
**Related Documents:** [Event Payload Specification](../specs/event_payload.md) | [Event Lifecycle](../specs/event_lifecycle.md) | [ADR 003](../adr/003-event-sourcing-architecture.md)

---

## Overview

This document provides the authoritative reference for WireTuner's event schema, covering universal metadata fields, timestamp precision requirements, sampling validation rules, snapshot policies, and collaboration-ready extensions. Every event persisted to the SQLite event store must conform to this schema.

**Schema Scope:**
- Universal envelope metadata (UUIDs, timestamps, event type discriminators)
- Sampling interval specifications and validation rules
- Snapshot cadence and retention policies
- Undo grouping markers for atomic multi-event operations
- Collaboration-ready fields (author, session identifiers)
- Per-event payload schemas with required/optional field specifications

**Key Design Principles:**
1. **Immutability**: Events are append-only; no updates or deletions permitted
2. **Deterministic Replay**: Event sequence order guarantees reproducible state reconstruction
3. **Forward Compatibility**: Optional fields enable schema evolution without breaking changes
4. **Human Readability**: JSON serialization prioritizes debuggability over binary compactness

---

## Table of Contents

- [Universal Event Envelope](#universal-event-envelope)
- [Timestamp Specification](#timestamp-specification)
- [Sampling Metadata and Validation](#sampling-metadata-and-validation)
- [Snapshot Policy](#snapshot-policy)
- [Undo Grouping and Atomicity](#undo-grouping-and-atomicity)
- [Collaboration-Ready Fields](#collaboration-ready-fields)
- [Event Type Examples](#event-type-examples)
  - [Pen Tool Events (Path Creation)](#pen-tool-events-path-creation)
  - [Selection and Movement Events](#selection-and-movement-events)
  - [Shape Creation Events](#shape-creation-events)
- [Validation Checklist](#validation-checklist)
- [Glossary](#glossary)
- [References](#references)

---

## Universal Event Envelope

Every event persisted to the `events` table in SQLite includes these **required** metadata fields, regardless of event type. These fields form the envelope that wraps event-specific payloads.

### Global Metadata Table

| Field Name | Type | Required | Description | Constraints | Default |
|------------|------|----------|-------------|-------------|---------|
| `eventId` | string (UUID) | **Yes** | Globally unique identifier for this event instance | Must be a valid UUIDv4 (RFC 4122) | Generated at creation |
| `timestamp` | integer | **Yes** | Event creation time in Unix milliseconds | Monotonically increasing within a document session | Current system time |
| `eventType` | string | **Yes** | Discriminator for polymorphic deserialization | Must match the Dart class name exactly (e.g., `CreatePathEvent`) | - |
| `eventSequence` | integer | **Yes** | Zero-based sequential index within the document | Unique per document, no gaps permitted | Auto-assigned by Event Recorder |
| `documentId` | string (UUID) | **Yes** | Document to which this event belongs | Must reference valid entry in `metadata` table | Inherited from active document |

**UUID Format Requirement:**
All UUIDs (`eventId`, `documentId`, `pathId`, `shapeId`, etc.) must conform to UUIDv4 format as defined in [RFC 4122](https://tools.ietf.org/html/rfc4122). Example: `550e8400-e29b-41d4-a716-446655440000`

**Event Type Discriminator:**
The `eventType` field is used by the `eventFromJson()` factory (see `lib/api/event_schema.dart`) to route JSON payloads to the correct Dart event class constructor. This field **must** match the class name exactly, including casing.

**Example Envelope:**
```json
{
  "eventId": "550e8400-e29b-41d4-a716-446655440000",
  "timestamp": 1699305600000,
  "eventType": "CreatePathEvent",
  "eventSequence": 42,
  "documentId": "a3c2e1b0-9876-4321-abcd-ef1234567890",
  ...
}
```

---

## Timestamp Specification

### Current Implementation: Millisecond Precision

**Storage Format:** Integer milliseconds since Unix epoch (January 1, 1970 00:00:00 UTC)
**Dart Type:** `int` (see `EventBase.timestamp` in `lib/domain/events/event_base.dart`)
**Example:** `1699305600000` represents November 7, 2023 00:00:00 UTC

**Implementation Note:**
Events are currently persisted with millisecond precision as `int` values in SQLite. This provides sufficient granularity for 50ms sampling intervals and keeps the schema simple.

### Future Target: RFC3339 Microsecond Timestamps

**Dual-Format Policy:**
For enhanced precision and ISO 8601 compliance, WireTuner will support RFC3339 timestamps with microsecond precision for import/export and API integrations:

**Format:** `YYYY-MM-DDTHH:MM:SS.ffffffZ`
**Example:** `2023-11-07T00:00:00.000000Z`
**Precision:** 6 decimal places (microseconds)

**Migration Strategy:**
1. **Phase 1 (Current):** Store as `int` milliseconds internally
2. **Phase 2 (Future):** Export events to external formats as RFC3339 strings
3. **Phase 3 (Future):** Accept both formats on import, normalize to milliseconds internally
4. **Phase 4 (Long-term):** Migrate storage to TEXT column with RFC3339 format if microsecond precision becomes critical

**Backward Compatibility:**
All exported events will include both `timestamp` (int milliseconds) and `timestampRfc3339` (string) fields during the transition period to ensure old readers continue to function.

---

## Sampling Metadata and Validation

### Sampling Strategy by Event Category

WireTuner employs **adaptive sampling** to balance event fidelity with storage efficiency and replay performance. The sampling strategy varies by event category:

| Event Category | Sampling Strategy | Interval | Rationale |
|----------------|-------------------|----------|-----------|
| **Discrete Actions** | None (single event) | N/A | Lifecycle markers, atomic operations (CreatePath, FinishPath, DeleteObject, SelectObjects) |
| **High-Frequency Input** | Time-based sampling | 50ms (~20 FPS) | Drag operations (AddAnchor during pen drag, ModifyAnchor, MoveObject) |
| **Viewport Navigation** | Time-based sampling | 50ms (~20 FPS) | Pan and zoom gestures (ViewportPan, ViewportZoom) |
| **Style Adjustments** | Debounced to final value | On pointer release | Color pickers, opacity sliders (ModifyStyle) |

### 50ms Sampling Interval (Decision 5)

**Source:** [Architecture Decision 5](../../.codemachine/artifacts/architecture/06_Rationale_and_Future.md#decision-50ms-sampling)

**Key Performance Indicators:**
- **Event Reduction:** 2-second drag = 40 events (with sampling) vs. 200+ events (full fidelity) = 5x reduction
- **Perceptual Smoothness:** 20 events/second sufficient for visually smooth replay (human motion perception threshold ~60 FPS, but vector path replay doesn't require per-frame capture)
- **Storage Efficiency:** Smaller event logs enable faster replay and reduced disk usage
- **Replay Performance:** Less strain on SQLite read throughput during document load

**Fidelity Trade-off:**
Sampling introduces slight non-determinism (two users performing identical drags may produce slightly different event sequences), but this is imperceptible in practice and acceptable for workflow reconstruction.

### Validation Rules for Sampled Events

Events subject to sampling **must** include the following optional metadata field:

| Field Name | Type | Required | Description | Constraints |
|------------|------|----------|-------------|-------------|
| `samplingIntervalMs` | integer | No | Sampling interval in milliseconds (if applicable); only present for sampled events | Must be `50` for high-frequency input events |

**Validation Logic:**
1. If event type is `AddAnchorEvent`, `ModifyAnchorEvent`, `MoveObjectEvent`, `ViewportPanEvent`, or `ViewportZoomEvent`:
   - **During drag operations:** `samplingIntervalMs` should be `50` (or omitted if event is discrete)
   - **First/last events:** May omit `samplingIntervalMs` (lifecycle markers)
2. If `samplingIntervalMs` is present and not equal to `50`, log a warning and reject the event during validation

**Example Sampled Event:**
```json
{
  "eventId": "550e8400-e29b-41d4-a716-446655440001",
  "timestamp": 1699305600050,
  "eventType": "AddAnchorEvent",
  "eventSequence": 43,
  "documentId": "a3c2e1b0-9876-4321-abcd-ef1234567890",
  "samplingIntervalMs": 50,
  "pathId": "path_001",
  "position": {"x": 150.0, "y": 250.0},
  "anchorType": "line"
}
```

---

## Snapshot Policy

### Snapshot Frequency (Decision 6)

**Source:** [Architecture Decision 6](../../.codemachine/artifacts/architecture/06_Rationale_and_Future.md#decision-snapshot-frequency)

**Trigger:** Snapshot created every **1000 events**

**Rationale:**
- **Replay Performance:** Avoids replaying entire event history (10,000 events ≈ 1 minute replay time; snapshot every 1000 events reduces to ~50ms)
- **Fast Document Loading:** Load snapshot + recent events (~50-100ms total)
- **Reasonable Overhead:** 1000 events ≈ 5-10 minutes of active editing (at ~20-30 events/minute typical usage)

**Snapshot Storage:**
- **Table:** `snapshots` (see SQLite schema in [System Structure](../../.codemachine/artifacts/architecture/03_System_Structure_and_Data.md#data-model-event-schema))
- **Format:** gzip-compressed JSON BLOB (10:1 compression typical)
- **Size:** ~10 KB - 1 MB per snapshot (depends on document complexity)
- **Retention:** Keep most recent 10 snapshots, prune older snapshots during compaction

**Snapshot Schema:**
```sql
CREATE TABLE snapshots (
  snapshot_id INTEGER PRIMARY KEY AUTOINCREMENT,
  document_id TEXT NOT NULL,
  event_sequence INTEGER NOT NULL,  -- Snapshot taken after this event
  snapshot_data BLOB NOT NULL,      -- gzip-compressed JSON
  created_at INTEGER NOT NULL,      -- Unix timestamp
  compression TEXT DEFAULT 'gzip',
  FOREIGN KEY(document_id) REFERENCES metadata(document_id)
);
```

**Snapshot Cadence Validation:**
- Snapshot Manager validates that snapshot intervals do not exceed 1500 events (50% margin)
- If 1500 events elapse without snapshot, log critical warning and force snapshot creation
- Missing snapshots trigger automatic backfill on next document load

---

## Undo Grouping and Atomicity

### Undo Group Markers

**Problem:** A single user action (e.g., dragging an anchor point for 2 seconds) generates 40 sampled events. Pressing "Undo" should revert the entire drag, not just the last sampled position.

**Solution:** Events include optional undo grouping metadata to mark atomic multi-event operations.

| Field Name | Type | Required | Description | Constraints |
|------------|------|----------|-------------|-------------|
| `undoGroupId` | string (UUID) | No | Groups related events into a single undo action | All events in a drag operation share the same `undoGroupId` |
| `undoGroupStart` | boolean | No | Marks the first event in an undo group | `true` for the first event, omitted for subsequent events |
| `undoGroupEnd` | boolean | No | Marks the last event in an undo group | `true` for the final event, omitted for intermediate events |

**Undo Group Lifecycle:**
1. **Pointer Down (Tool Activates):** First event assigned new `undoGroupId`, `undoGroupStart: true`
2. **Pointer Move (Sampled Events):** Intermediate events share same `undoGroupId`, no start/end flags
3. **Pointer Up (Tool Deactivates):** Final event includes `undoGroupEnd: true`

**Replay Behavior:**
- **Undo (Cmd+Z):** Event Navigator finds the most recent event with `undoGroupEnd: true`, replays to the event **before** the corresponding `undoGroupStart` event
- **Redo (Cmd+Shift+Z):** Replays forward to the next event with `undoGroupEnd: true`

**Example Undo Group (Drag Operation):**
```json
// First event: pointer down
{
  "eventId": "uuid-001",
  "timestamp": 1699305600000,
  "eventType": "AddAnchorEvent",
  "undoGroupId": "group-abc",
  "undoGroupStart": true,
  "pathId": "path_001",
  "position": {"x": 100.0, "y": 200.0}
}

// Intermediate sampled events (39 events omitted)
{
  "eventId": "uuid-002",
  "timestamp": 1699305600050,
  "eventType": "AddAnchorEvent",
  "undoGroupId": "group-abc",
  "samplingIntervalMs": 50,
  "pathId": "path_001",
  "position": {"x": 105.0, "y": 205.0}
}

// Final event: pointer up
{
  "eventId": "uuid-041",
  "timestamp": 1699305602000,
  "eventType": "AddAnchorEvent",
  "undoGroupId": "group-abc",
  "undoGroupEnd": true,
  "pathId": "path_001",
  "position": {"x": 300.0, "y": 400.0}
}
```

**UI Integration (Decision 7):**
Provider-based state management propagates undo group completion notifications to the UI layer, enabling "Undo Move Anchor" menu labels and history panel displays.

---

## Collaboration-Ready Fields

**Future-Proofing for Multi-User Editing:**
WireTuner's event schema includes optional fields to support real-time collaborative editing in future versions (post-0.1). These fields are **not required** for single-user operation but should be included in all events to simplify future migration.

| Field Name | Type | Required | Description | Constraints |
|------------|------|----------|-------------|-------------|
| `userId` | string (UUID) | No | Identifier for the user who created this event | UUIDv4 format; defaults to `"local-user"` in single-user mode |
| `sessionId` | string (UUID) | No | Identifier for the editing session | Unique per app launch; enables session-based replay filtering |
| `deviceId` | string | No | Device identifier (for multi-device sync) | Human-readable string (e.g., "MacBook-Pro-2023") |

**Collaboration Use Cases:**
1. **Multi-User Editing:** Differentiate events by user for conflict resolution (Operational Transform or CRDTs)
2. **Session Filtering:** Replay only events from a specific user or session (useful for debugging or training)
3. **Device Sync:** Track which device originated an event for sync conflict resolution

**Example Collaboration-Ready Event:**
```json
{
  "eventId": "550e8400-e29b-41d4-a716-446655440002",
  "timestamp": 1699305600100,
  "eventType": "CreateShapeEvent",
  "eventSequence": 44,
  "documentId": "a3c2e1b0-9876-4321-abcd-ef1234567890",
  "userId": "user-alice-uuid",
  "sessionId": "session-2023-11-07-uuid",
  "deviceId": "MacBook-Pro-Alice",
  "shapeId": "shape_001",
  "shapeType": "rectangle",
  "parameters": {"x": 50.0, "y": 50.0, "width": 200.0, "height": 100.0}
}
```

**Single-User Default Behavior:**
If collaboration fields are omitted, the Event Recorder defaults:
- `userId` → `"local-user"`
- `sessionId` → Generated once per app launch (UUIDv4)
- `deviceId` → System hostname or `"unknown"`

---

## Event Type Examples

This section provides detailed JSON examples for three representative event categories: pen tool events (path creation), selection/movement events, and shape creation events. For comprehensive event type documentation, see [Event Payload Specification](../specs/event_payload.md).

### Pen Tool Events (Path Creation)

**Lifecycle:** CreatePath → AddAnchor (sampled) → FinishPath

#### CreatePathEvent

**Description:** Initiates a new vector path with a starting anchor point.
**Sampling:** None (discrete lifecycle marker)

**Required Fields:**
- `pathId` (string): Unique identifier for the new path
- `startAnchor` (Point): Initial anchor position `{x: number, y: number}`

**Optional Fields:**
- `fillColor` (string): Hex color (e.g., `"#FF5733"`)
- `strokeColor` (string): Hex color (e.g., `"#000000"`)
- `strokeWidth` (number): Stroke width in pixels (>= 0)
- `opacity` (number): Opacity (0.0 to 1.0)

**Example:**
```json
{
  "eventId": "evt-create-path-001",
  "timestamp": 1699305600000,
  "eventType": "CreatePathEvent",
  "eventSequence": 100,
  "documentId": "doc-uuid",
  "userId": "local-user",
  "sessionId": "session-uuid",
  "pathId": "path_001",
  "startAnchor": {"x": 100.0, "y": 200.0},
  "strokeColor": "#000000",
  "strokeWidth": 2.0,
  "opacity": 1.0
}
```

#### AddAnchorEvent (Sampled)

**Description:** Adds an anchor point to an active path during pen tool drag.
**Sampling:** 50ms intervals during continuous drag

**Required Fields:**
- `pathId` (string): Target path identifier
- `position` (Point): New anchor position

**Optional Fields:**
- `anchorType` (AnchorType): `"line"` or `"bezier"` (default: `"line"`)
- `handleIn` (Point): Incoming Bezier control point handle
- `handleOut` (Point): Outgoing Bezier control point handle
- `samplingIntervalMs` (integer): Should be `50` during drag
- `undoGroupId`, `undoGroupStart`, `undoGroupEnd`: Undo grouping metadata

**Example:**
```json
{
  "eventId": "evt-add-anchor-002",
  "timestamp": 1699305600050,
  "eventType": "AddAnchorEvent",
  "eventSequence": 101,
  "documentId": "doc-uuid",
  "samplingIntervalMs": 50,
  "undoGroupId": "drag-group-001",
  "pathId": "path_001",
  "position": {"x": 150.0, "y": 250.0},
  "anchorType": "bezier",
  "handleIn": {"x": 140.0, "y": 240.0},
  "handleOut": {"x": 160.0, "y": 260.0}
}
```

#### FinishPathEvent

**Description:** Completes path creation, finalizing the path lifecycle.
**Sampling:** None (discrete lifecycle marker)

**Required Fields:**
- `pathId` (string): Path identifier

**Optional Fields:**
- `closed` (boolean): Whether path is closed (default: `false`)

**Example:**
```json
{
  "eventId": "evt-finish-path-003",
  "timestamp": 1699305602000,
  "eventType": "FinishPathEvent",
  "eventSequence": 140,
  "documentId": "doc-uuid",
  "undoGroupId": "drag-group-001",
  "undoGroupEnd": true,
  "pathId": "path_001",
  "closed": false
}
```

---

### Selection and Movement Events

#### SelectObjectsEvent

**Description:** Selects one or more objects on the canvas.
**Sampling:** None (discrete action)

**Required Fields:**
- `objectIds` (string[]): Array of object identifiers to select

**Optional Fields:**
- `mode` (SelectionMode): `"replace"`, `"add"`, `"toggle"`, or `"subtract"` (default: `"replace"`)

**Example:**
```json
{
  "eventId": "evt-select-004",
  "timestamp": 1699305650000,
  "eventType": "SelectObjectsEvent",
  "eventSequence": 200,
  "documentId": "doc-uuid",
  "objectIds": ["path_001", "shape_001"],
  "mode": "add"
}
```

#### MoveObjectEvent (Sampled)

**Description:** Translates selected objects during drag operation.
**Sampling:** 50ms intervals during continuous drag

**Required Fields:**
- `objectIds` (string[]): Objects to move
- `delta` (Point): Translation delta `{x: number, y: number}`

**Optional Fields:**
- `samplingIntervalMs` (integer): Should be `50` during drag
- `undoGroupId`, `undoGroupStart`, `undoGroupEnd`: Undo grouping metadata

**Example:**
```json
{
  "eventId": "evt-move-005",
  "timestamp": 1699305700050,
  "eventType": "MoveObjectEvent",
  "eventSequence": 201,
  "documentId": "doc-uuid",
  "samplingIntervalMs": 50,
  "undoGroupId": "move-group-002",
  "objectIds": ["path_001"],
  "delta": {"x": 10.0, "y": -5.0}
}
```

---

### Shape Creation Events

#### CreateShapeEvent

**Description:** Creates a parametric shape (rectangle, ellipse, polygon, star).
**Sampling:** None (discrete action)

**Required Fields:**
- `shapeId` (string): Unique shape identifier
- `shapeType` (ShapeType): One of `"rectangle"`, `"ellipse"`, `"star"`, `"polygon"`
- `parameters` (object): Shape-specific parameters (see table below)

**Optional Fields:**
- `fillColor`, `strokeColor`, `strokeWidth`, `opacity`: Style properties

**Shape Parameters by Type:**

| ShapeType | Parameters | Description |
|-----------|------------|-------------|
| `rectangle` | `x`, `y`, `width`, `height`, `cornerRadius` (optional) | Top-left position + dimensions |
| `ellipse` | `centerX`, `centerY`, `radiusX`, `radiusY` | Center position + radii |
| `star` | `centerX`, `centerY`, `outerRadius`, `innerRadius`, `points` | Center position + radii + point count |
| `polygon` | `centerX`, `centerY`, `radius`, `sides` | Center position + bounding radius + side count |

**Example (Rectangle):**
```json
{
  "eventId": "evt-create-shape-006",
  "timestamp": 1699305800000,
  "eventType": "CreateShapeEvent",
  "eventSequence": 300,
  "documentId": "doc-uuid",
  "shapeId": "shape_001",
  "shapeType": "rectangle",
  "parameters": {
    "x": 50.0,
    "y": 50.0,
    "width": 200.0,
    "height": 100.0,
    "cornerRadius": 10.0
  },
  "fillColor": "#FF5733",
  "strokeColor": "#000000",
  "strokeWidth": 1.0,
  "opacity": 1.0
}
```

**Example (Ellipse):**
```json
{
  "eventId": "evt-create-shape-007",
  "timestamp": 1699305850000,
  "eventType": "CreateShapeEvent",
  "eventSequence": 301,
  "documentId": "doc-uuid",
  "shapeId": "shape_002",
  "shapeType": "ellipse",
  "parameters": {
    "centerX": 300.0,
    "centerY": 200.0,
    "radiusX": 100.0,
    "radiusY": 50.0
  },
  "fillColor": "#3366FF",
  "opacity": 0.8
}
```

---

## Validation Checklist

Use this checklist to validate events before persistence or during schema compliance audits.

### Required Field Validation

- [ ] **eventId** is a valid UUIDv4 string
- [ ] **timestamp** is a positive integer (Unix milliseconds)
- [ ] **eventType** matches a valid Dart event class name exactly
- [ ] **eventSequence** is a non-negative integer, unique within the document
- [ ] **documentId** is a valid UUIDv4 and references an existing document

### Sampling Validation

- [ ] If event type is high-frequency (`AddAnchorEvent`, `ModifyAnchorEvent`, `MoveObjectEvent`, `ViewportPanEvent`):
  - [ ] During drag: `samplingIntervalMs` is present and equals `50`
  - [ ] First/last events: `samplingIntervalMs` may be omitted
- [ ] If `samplingIntervalMs` is present, verify it equals `50` (reject otherwise)

### Timestamp Precision Validation

- [ ] **Current (0.1):** Timestamps are stored as `int` milliseconds
- [ ] **Future (Import/Export):** If `timestampRfc3339` field is present, validate it matches RFC3339 format with microsecond precision: `YYYY-MM-DDTHH:MM:SS.ffffffZ`

### Snapshot Validation

- [ ] Snapshot created every 1000 events (±50 event tolerance)
- [ ] Snapshot `event_sequence` references a valid event in the `events` table
- [ ] Snapshot data is gzip-compressed JSON
- [ ] Snapshot decompresses successfully and parses as valid JSON

### Undo Grouping Validation

- [ ] If `undoGroupId` is present, it is a valid UUIDv4
- [ ] If `undoGroupStart` is `true`, this is the first event with this `undoGroupId`
- [ ] If `undoGroupEnd` is `true`, this is the last event with this `undoGroupId`
- [ ] All events in an undo group share the same `undoGroupId`

### Collaboration Field Validation

- [ ] If `userId` is present, it is a valid UUIDv4 or the string `"local-user"`
- [ ] If `sessionId` is present, it is a valid UUIDv4
- [ ] If `deviceId` is present, it is a non-empty string

### Event-Specific Payload Validation

- [ ] All event-specific required fields are present (see [Event Payload Specification](../specs/event_payload.md))
- [ ] Field types match schema (e.g., `strokeWidth` is a number, `fillColor` matches hex pattern `^#[0-9A-Fa-f]{6}$`)
- [ ] Enum values are valid (e.g., `anchorType` is `"line"` or `"bezier"`)

---

## Glossary

This glossary defines key terms used throughout the event schema reference. For additional architectural terms, see the [Architecture Glossary](../../.codemachine/artifacts/architecture/03_System_Structure_and_Data.md#glossary).

| Term | Definition |
|------|------------|
| **Anchor Point** | A point on a path that defines segment endpoints; may include Bezier control point handles (BCPs) |
| **BCP** | Bezier Control Point - handles on anchors that define curve shape (handleIn, handleOut) |
| **Discrete Event** | An event representing an atomic action (e.g., CreatePath, SelectObjects) not subject to sampling |
| **Event Envelope** | Universal metadata fields present on all events (eventId, timestamp, eventType, eventSequence, documentId) |
| **Event Sequence** | Zero-based index establishing total order of events within a document (used for deterministic replay) |
| **High-Frequency Input** | User actions generating rapid events (e.g., mouse drag), subject to 50ms sampling |
| **Lifecycle Marker** | Events that mark state transitions (e.g., CreatePath, FinishPath) rather than continuous input |
| **RFC3339** | ISO 8601-compliant timestamp format with timezone (`YYYY-MM-DDTHH:MM:SS.ffffffZ`) |
| **Sampled Event** | An event subject to time-based throttling (50ms interval) to reduce event volume |
| **Snapshot** | Serialized document state at a specific event sequence, stored for fast replay (created every 1000 events) |
| **Undo Group** | Set of related events treated as a single atomic action for undo/redo (e.g., all events in a drag operation) |
| **UUIDv4** | Universally Unique Identifier version 4 (RFC 4122), 128-bit random identifier |

---

## References

### Architecture Documents
- [System Structure and Data Model](../../.codemachine/artifacts/architecture/03_System_Structure_and_Data.md#data-model-event-schema) - SQLite schema design rationale
- [Design Rationale - Decision 1 (Event Sourcing)](../../.codemachine/artifacts/architecture/06_Rationale_and_Future.md#decision-event-sourcing) - Event sourcing architecture choice
- [Design Rationale - Decision 3 (SQLite)](../../.codemachine/artifacts/architecture/06_Rationale_and_Future.md#decision-sqlite) - SQLite as file format rationale
- [Design Rationale - Decision 5 (50ms Sampling)](../../.codemachine/artifacts/architecture/06_Rationale_and_Future.md#decision-50ms-sampling) - Sampling rate justification
- [Design Rationale - Decision 6 (Snapshot Frequency)](../../.codemachine/artifacts/architecture/06_Rationale_and_Future.md#decision-snapshot-frequency) - 1000-event snapshot cadence
- [Design Rationale - Decision 7 (Provider State Management)](../../.codemachine/artifacts/architecture/06_Rationale_and_Future.md#decision-provider-state-mgmt) - UI state propagation

### Specification Documents
- [Event Payload Specification](../specs/event_payload.md) - Exhaustive per-event field definitions and JSON Schema
- [Event Lifecycle Specification](../specs/event_lifecycle.md) - Complete event flow from creation through replay
- [ADR 003: Event Sourcing Architecture](../adr/003-event-sourcing-architecture.md) - Foundational architectural decision record

### Diagrams
- [Event Flow Sequence Diagram](../diagrams/event_flow_sequence.mmd) - Visual representation of event lifecycle (pointer input → sampler → recorder → SQLite → replayer)
- [Component Overview Diagram](../diagrams/component_overview.puml) - Event Sourcing Core component boundaries

### External Standards
- [RFC 4122: UUID Specification](https://tools.ietf.org/html/rfc4122) - UUIDv4 format requirements
- [RFC 3339: Date and Time on the Internet](https://tools.ietf.org/html/rfc3339) - Timestamp format specification
- [SQLite Write-Ahead Logging](https://www.sqlite.org/wal.html) - Durability guarantees for event persistence

---

**Document Maintainer:** WireTuner Architecture Team
**Last Updated:** 2025-11-08
**Next Review:** After completion of I1.T8 (Event Navigator Implementation)
