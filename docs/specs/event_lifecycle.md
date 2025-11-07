# Event Lifecycle Specification

**Document Version:** 1.0
**Last Updated:** 2025-11-06
**Status:** Active
**Related ADR:** [003-event-sourcing-architecture.md](../adr/003-event-sourcing-architecture.md)

---

## Overview

This document details the complete lifecycle of events in WireTuner's event sourcing architecture, from user interaction through persistence, replay, and navigation. The event sourcing system provides the foundation for unlimited undo/redo, complete audit trails, crash recovery, and future collaborative editing capabilities.

**Key Architectural Principles:**
- All state changes are captured as immutable events stored in an append-only log
- Current application state is derived by replaying events from the log
- High-frequency input is sampled at 50ms intervals to balance fidelity with performance
- Document snapshots are created every 1000 events for fast loading
- All domain models are immutable, with events producing new state instances

---

## Event Lifecycle Phases

The event lifecycle consists of six primary phases, each handled by dedicated components:

### Phase 1: Event Recording (User Input → Event Creation)

**Responsible Components:**
- Tool Controllers (Pen Tool, Selection Tool, Direct Selection Tool, etc.)
- Event Recorder
- Event Sampler

**Flow:**
1. User interacts with the canvas (click, drag, keyboard input)
2. Canvas Widget routes input to Tool Manager
3. Active tool interprets the interaction and determines the appropriate event type
4. For high-frequency input (mouse drag), Event Sampler throttles to 50ms intervals
5. Tool calls Event Recorder to create the event instance
6. Event assigned monotonically increasing sequence number

**Event Types:**
- `CreatePathEvent` - Initiates a new path with starting anchor
- `AddAnchorEvent` - Adds anchor point to active path
- `MoveAnchorEvent` - Repositions an anchor point (sampled during drag)
- `MoveObjectEvent` - Translates entire object (sampled during drag)
- `ModifyStyleEvent` - Changes fill, stroke, or other style properties
- `FinishPathEvent` - Completes path creation
- `DeleteObjectEvent` - Removes object from document

**Latency Budget:** < 5ms from user input to event creation (non-blocking)

**Cross-References:**
- [T003: Event Sourcing Architecture Design](../../.codemachine/inputs/tickets/T003-event-sourcing-architecture-design.md)
- [T005: Event Recorder](../../.codemachine/inputs/tickets/T005-event-recorder.md)

---

### Phase 2: Event Sampling (High-Frequency Input Throttling)

**Responsible Component:** Event Sampler

**Purpose:** Prevent event flood during continuous input operations (dragging anchors, objects, or bezier control points) by sampling at 50ms intervals.

**Behavior:**
- **Continuous Input Detected:** When tool reports rapid input events (< 50ms apart)
- **Buffering:** Event Sampler buffers intermediate positions
- **Emission:** Every 50ms, emits single event representing the latest state
- **Flush on Release:** When input ends (pointer up), emits final position if buffered

**Example:**
A 2-second drag operation with mouse polling at 100Hz (10ms intervals) generates:
- **Without sampling:** ~200 events
- **With 50ms sampling:** ~40 events (5x reduction)

**Rationale:**
- Human perception of smooth motion: ~60 FPS (16.7ms/frame)
- 50ms sampling (20 samples/second) provides perceptually smooth replay
- Reduces storage overhead by 5-10x for drag operations
- Faster document loading and undo/redo performance

**Latency Budget:** < 2ms for sampling logic (lightweight timestamp check)

**Cross-References:**
- [ADR 003 - 50ms Sampling Rate Rationale](../adr/003-event-sourcing-architecture.md#why-50ms-sampling-rate)
- [T005: Event Recorder](../../.codemachine/inputs/tickets/T005-event-recorder.md) (includes sampler logic)

---

### Phase 3: Event Dispatch and Application

**Responsible Components:**
- Event Dispatcher
- Event Handler Registry
- Document State (immutable domain models)

**Flow:**
1. Event Recorder sends event to Event Dispatcher
2. Dispatcher looks up handler in Event Handler Registry using event type as key
3. Handler receives current document state and event
4. Handler creates **new immutable document state** by applying event
5. New state returned to dispatcher
6. UI layer notified via Flutter ChangeNotifier/Provider pattern

**Handler Implementation Pattern:**
```dart
Document handleAddAnchorEvent(Document currentDoc, AddAnchorEvent event) {
  final path = currentDoc.getPath(event.pathId);
  final newPath = path.copyWith(
    anchors: [...path.anchors, event.anchor],
  );
  return currentDoc.copyWith(
    paths: currentDoc.paths.map((p) => p.id == event.pathId ? newPath : p).toList(),
  );
}
```

**Immutability Guarantee:**
- No in-place mutations
- Event application is pure function: `(State, Event) → NewState`
- Thread-safe (future: isolate-based rendering)

**Latency Budget:** < 10ms for event application (depends on document complexity)

**Cross-References:**
- [T005: Event Recorder](../../.codemachine/inputs/tickets/T005-event-recorder.md) (includes dispatcher)
- [T004: Event Model](../../.codemachine/inputs/tickets/T004-event-model.md)
- [Component Diagram - Event Sourcing Core](../diagrams/component_overview.puml)

---

### Phase 4: Event Persistence

**Responsible Components:**
- Event Recorder
- SQLite Repository
- Event Store

**Flow:**
1. After event dispatched and applied, Event Recorder persists to SQLite
2. Event serialized to JSON payload
3. Inserted into `events` table with sequence number, timestamp, type
4. SQLite WAL (Write-Ahead Logging) mode ensures durability

**Database Schema (events table):**
```sql
CREATE TABLE events (
  event_id INTEGER PRIMARY KEY AUTOINCREMENT,
  event_sequence INTEGER NOT NULL UNIQUE,
  event_type TEXT NOT NULL,
  event_payload TEXT NOT NULL, -- JSON
  created_at INTEGER NOT NULL,  -- Unix timestamp
  user_id TEXT,                 -- Future: multi-user collaboration
  CHECK(json_valid(event_payload))
);
```

**Persistence Guarantees:**
- **Atomic:** Each event insert is a single transaction
- **Durable:** WAL mode ensures crash resistance
- **Ordered:** Sequence numbers enforce deterministic replay order

**Latency Budget:** < 15ms for SQLite INSERT (includes JSON serialization and disk I/O)

**Failure Handling:**
- **Disk Full:** Event Recorder retries with exponential backoff (50ms, 100ms, 200ms), then surfaces error to user
- **Write Error:** Transaction rollback, event marked as failed, user notified
- **Corruption Detected:** Integrity check on startup, snapshot recovery if needed

**Cross-References:**
- [ADR 003 - JSON Event Encoding Rationale](../adr/003-event-sourcing-architecture.md#why-json-event-encoding)
- [T006: Event Log Persistence](../../.codemachine/inputs/tickets/T006-event-log-persistence.md)
- [T002: SQLite Integration](../../.codemachine/inputs/tickets/T002-sqlite-integration.md)
- [SQLite Repository Schema](../../lib/infrastructure/persistence/schema.dart)

---

### Phase 5: Snapshot Management

**Responsible Components:**
- Snapshot Manager
- Snapshot Serializer
- SQLite Repository

**Trigger:** Snapshot created every 1000 events

**Flow:**
1. Event Recorder notifies Snapshot Manager on event count milestone (1000, 2000, 3000, etc.)
2. Snapshot Manager requests current document state
3. Snapshot Serializer converts document to binary BLOB (JSON + gzip compression)
4. Snapshot persisted to `snapshots` table with event sequence reference
5. Old snapshots optionally pruned (keep most recent N snapshots)

**Database Schema (snapshots table):**
```sql
CREATE TABLE snapshots (
  snapshot_id INTEGER PRIMARY KEY AUTOINCREMENT,
  event_sequence INTEGER NOT NULL,
  snapshot_data BLOB NOT NULL,  -- gzip-compressed JSON
  created_at INTEGER NOT NULL,  -- Unix timestamp
  FOREIGN KEY(event_sequence) REFERENCES events(event_sequence)
);
```

**Snapshot Cadence Rationale:**
- **Typical Usage:** ~20-30 events/minute → 1000 events ≈ 30-50 minutes of work
- **Load Performance:** Snapshot + up to 1000 events = < 200ms document load
- **Storage Overhead:** ~10-50KB per snapshot (gzip compression ~10:1)
- **Garbage Collection:** Prune snapshots older than 10,000 events (keep 10 recent snapshots)

**Latency Budget:** < 25ms for snapshot creation (serialization + compression + insert)

**Failure Handling:**
- **Serialization Error:** Log warning, continue recording events (snapshot skipped for this milestone)
- **Disk Full:** Abort snapshot creation, warn user, continue event recording
- **Corruption:** Integrity check validates gzip decompression; fallback to previous snapshot if corrupt

**Cross-References:**
- [ADR 003 - Snapshot Frequency Rationale](../adr/003-event-sourcing-architecture.md#why-snapshot-every-1000-events)
- [T007: Snapshot System](../../.codemachine/inputs/tickets/T007-snapshot-system.md)

---

### Phase 6: Event Replay and Navigation

**Responsible Components:**
- Event Replayer
- Event Navigator (Undo/Redo Controller)
- Event Store
- Snapshot Store

**Document Load Flow:**
1. User opens `.wiretuner` file
2. Event Store queries: `SELECT MAX(event_sequence) FROM events` → maxSequence
3. Snapshot Store queries: `SELECT snapshot_data, event_sequence FROM snapshots WHERE event_sequence <= maxSequence ORDER BY event_sequence DESC LIMIT 1`
4. Event Replayer deserializes snapshot BLOB → base document state
5. Event Store queries: `SELECT * FROM events WHERE event_sequence > snapshotSequence ORDER BY event_sequence ASC`
6. Event Replayer applies each event sequentially via Event Dispatcher
7. Final document state displayed to user

**Undo/Redo Flow (Time Travel):**
1. User presses Cmd+Z (undo) or Cmd+Shift+Z (redo)
2. Event Navigator calculates target sequence number (currentSequence - 1 for undo, +1 for redo)
3. Navigator finds nearest snapshot ≤ targetSequence
4. Event Replayer reconstructs state at targetSequence
5. Document updated, UI redraws

**Replay Performance Optimization:**
- **Snapshot Base:** Start from nearest snapshot instead of replaying all events from document creation
- **Maximum Events to Replay:** 1000 (between snapshots)
- **Caching:** Event Navigator caches recently navigated states (LRU cache of 10 states)

**Latency Budgets:**
- **Document Load:** < 200ms (snapshot deserialization + up to 1000 event replays)
- **Undo/Redo:** < 100ms (typically replay < 100 events from cached snapshot)
- **First Load (No Snapshots):** < 1000ms (worst case: replay all events from empty document)

**Failure Handling:**
- **Snapshot Corruption:** Fallback to previous snapshot, warn user of potential data loss
- **Event Corruption:** Halt replay at corrupted event, surface error with sequence number
- **Missing Events:** Detect gaps in sequence numbers, warn user, attempt partial recovery

**Cross-References:**
- [T008: Event Replay Engine](../../.codemachine/inputs/tickets/T008-event-replay-engine.md)
- [T034: Load Document](../../.codemachine/inputs/tickets/T034-load-document.md)
- [Flow 2: Loading a Document (Event Replay)](../diagrams/event_sourcing_sequences.puml) - Lines 93-151
- [Flow 3: Undo Operation (Event Navigation)](../diagrams/event_sourcing_sequences.puml) - Lines 154-209

---

## Component Responsibilities Summary

| Component | Responsibilities | Failure Handling |
|-----------|-----------------|------------------|
| **Event Recorder** | Sample input, create events, assign sequence numbers, trigger persistence | Retry on disk full with backoff; surface errors to user if persistent failure |
| **Event Sampler** | Throttle high-frequency input to 50ms intervals, buffer intermediate states | Flush buffered state on error; log warning if sampling logic fails |
| **Event Dispatcher** | Route events to handlers based on type, orchestrate state application | Log unhandled event types; fail gracefully if handler missing |
| **Event Handler Registry** | Map event types to handler functions, apply events to produce new state | Throw exception on malformed event; rollback state if handler fails |
| **Event Store** | Persist events to SQLite, query events by sequence range | Transaction rollback on write error; integrity checks on startup |
| **Snapshot Manager** | Trigger snapshots every 1000 events, coordinate serialization and persistence | Skip snapshot on error, log warning, continue event recording |
| **Snapshot Serializer** | Serialize document to gzip-compressed JSON BLOB | Abort snapshot on serialization failure; log error with document size |
| **Event Replayer** | Deserialize snapshots, replay events to reconstruct state | Halt replay on corruption, surface error with sequence number |
| **Event Navigator** | Navigate to specific sequence numbers (undo/redo), cache recent states | Clear cache on error, reload from snapshot if cache corrupted |

---

## Latency Budgets (Performance Requirements)

The following latency budgets ensure responsive user experience:

| Operation | Target Latency | Rationale |
|-----------|---------------|-----------|
| Event Creation (User Input → Event) | < 5ms | Non-blocking input handling |
| Event Sampling Logic | < 2ms | Lightweight timestamp check |
| Event Application (State Update) | < 10ms | Depends on document complexity; optimize hot paths |
| Event Persistence (SQLite INSERT) | < 15ms | Includes JSON serialization + disk I/O |
| Snapshot Creation | < 25ms | Serialization + gzip compression + insert |
| Document Load (Snapshot + Events) | < 200ms | Perceived as "instant" by users |
| Undo/Redo Operation | < 100ms | Typically replays < 100 events |
| First Load (No Snapshots) | < 1000ms | Acceptable for first-time open; snapshots improve on subsequent loads |

**Latency Monitoring:**
- Development builds include instrumentation to measure actual latencies
- Performance regression tests in CI/CD pipeline
- Profiling tools (Dart DevTools) used to identify bottlenecks

**Optimization Strategies:**
- Viewport culling during replay (don't render off-screen objects)
- Lazy event deserialization (parse JSON only when needed)
- Background replay in Dart isolate (future optimization)

---

## Error Handling and Resilience

### Disk Full Scenario

**Detection:** SQLite returns `SQLITE_FULL` error code on INSERT

**Event Recorder Response:**
1. Retry with exponential backoff: 50ms, 100ms, 200ms (3 attempts)
2. If all retries fail, surface error to user: "Cannot save changes - disk full"
3. Enter read-only mode: disable editing, allow viewing and export to alternate location

**Snapshot Manager Response:**
1. Abort current snapshot creation
2. Log warning: "Snapshot skipped due to disk full at sequence N"
3. Continue event recording (snapshots are optimization, not critical path)

**Recovery:**
- User frees disk space
- Application retries event persistence on next user action
- Normal operation resumes

---

### Event Corruption Scenario

**Detection:**
- JSON parsing error during event deserialization
- JSON schema validation failure (missing required fields)
- Sequence number gap detected

**Event Replayer Response:**
1. Halt replay at corrupted event sequence number
2. Surface error: "Document corruption detected at event #N"
3. Offer options:
   - **Load Partial:** Display document state up to last valid event
   - **Export Partial:** Export recovered content to new file
   - **Attempt Repair:** Skip corrupted event(s), continue replay (risky)

**Prevention:**
- `CHECK(json_valid(event_payload))` constraint in events table
- Integrity checks on document load (validate sequence numbers)
- Periodic backup prompts (every 30 minutes of editing)

---

### Snapshot Corruption Scenario

**Detection:**
- Gzip decompression failure
- JSON parsing error after decompression
- Schema version mismatch

**Event Replayer Response:**
1. Fallback to previous snapshot (if available)
2. Replay additional events from older snapshot
3. Warn user: "Latest snapshot corrupted - using older snapshot from [timestamp]"
4. Surface potential data loss: "Events from last N minutes may be affected"

**Prevention:**
- Multiple snapshot retention (keep 10 most recent snapshots)
- CRC checksum validation before decompression (future enhancement)
- Snapshot integrity tests on creation

---

## Future Enhancements

### Collaborative Editing (Post-0.1)

**Preparation:** Event log is inherently distributable
- Add `user_id` column to events table (already present in schema)
- Implement Operational Transform (OT) or CRDT conflict resolution
- Network sync layer to exchange events between clients

**Cross-Reference:** [Architecture Overview - Event Sourcing Foundation](../architecture/02_Architecture_Overview.md#event-sourcing-foundation)

---

### Event Compaction (Storage Optimization)

**Problem:** Event log grows unbounded over document lifetime

**Solution:** "Compress History" feature
- Identify intermediate sampled events (e.g., middle events in a drag sequence)
- Remove intermediate events, keep only "keyframe" events
- Recalculate snapshots after compaction

**Trigger:** User-initiated or automatic when document exceeds size threshold

---

### Background Event Replay (Performance Optimization)

**Problem:** Large documents (10,000+ events) may exceed 200ms load latency

**Solution:** Replay events in Dart isolate (background thread)
- Load snapshot on main thread (fast)
- Dispatch event replay to isolate
- Stream partial document updates as replay progresses
- Display loading indicator with progress bar

---

## Appendix: Event Schema Examples

### CreatePathEvent (JSON)

```json
{
  "version": 1,
  "pathId": "path_1234",
  "startAnchor": {
    "position": {"x": 150.0, "y": 200.0},
    "handleIn": null,
    "handleOut": null
  },
  "style": {
    "fillColor": "#FF5733",
    "strokeColor": "#000000",
    "strokeWidth": 2.0
  }
}
```

### MoveAnchorEvent (JSON)

```json
{
  "version": 1,
  "pathId": "path_1234",
  "anchorIndex": 3,
  "delta": {"x": 10.5, "y": -5.2}
}
```

### ModifyStyleEvent (JSON)

```json
{
  "version": 1,
  "objectId": "path_1234",
  "styleChanges": {
    "fillColor": "#3366FF",
    "opacity": 0.8
  }
}
```

---

## Cross-References

### Architecture Documents
- [ADR 003: Event Sourcing Architecture Design](../adr/003-event-sourcing-architecture.md)
- [Architecture Overview - Event Sourcing Foundation](../architecture/02_Architecture_Overview.md#event-sourcing-foundation)
- [System Structure - Event Sourcing Core Components](../architecture/03_System_Structure_and_Data.md#component-event-sourcing)
- [Behavior and Communication - Event-Driven Pattern](../architecture/04_Behavior_and_Communication.md#pattern-event-driven)

### Diagrams
- [Component Overview Diagram](../diagrams/component_overview.puml)
- [Event Flow Sequence Diagram](../diagrams/event_flow_sequence.puml) *(this task's deliverable)*
- [Detailed Event Sourcing Sequences](../diagrams/event_sourcing_sequences.puml)

### Backlog Tickets
- [T003: Event Sourcing Architecture Design](../../.codemachine/inputs/tickets/T003-event-sourcing-architecture-design.md)
- [T004: Event Model](../../.codemachine/inputs/tickets/T004-event-model.md)
- [T005: Event Recorder](../../.codemachine/inputs/tickets/T005-event-recorder.md)
- [T006: Event Log Persistence](../../.codemachine/inputs/tickets/T006-event-log-persistence.md)
- [T007: Snapshot System](../../.codemachine/inputs/tickets/T007-snapshot-system.md)
- [T008: Event Replay Engine](../../.codemachine/inputs/tickets/T008-event-replay-engine.md)

### Implementation
- [SQLite Repository Schema](../../lib/infrastructure/persistence/schema.dart) - Lines 102-118 (events table), 131-144 (snapshots table)

---

**Document Status:** Complete
**Next Review:** After I1.T8 (Event Navigator Implementation)
**Maintainer:** WireTuner Architecture Team
