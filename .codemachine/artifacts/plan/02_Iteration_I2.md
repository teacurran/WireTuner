# Iteration 2: Core Event System

**Version:** 1.0
**Date:** 2025-11-05

---

<!-- anchor: iteration-2-overview -->
### Iteration 2: Core Event System

<!-- anchor: iteration-2-metadata -->
*   **Iteration ID:** `I2`
*   **Goal:** Build the complete event sourcing infrastructure including event recording, persistence, snapshots, and replay
*   **Prerequisites:** I1 (database schema and project setup)

<!-- anchor: iteration-2-tasks -->
*   **Tasks:**

<!-- anchor: task-i2-t1 -->
*   **Task 2.1:**
    *   **Task ID:** `I2.T1`
    *   **Description:** Define event model hierarchy using Dart sealed classes in `lib/domain/events/`. Create base EventBase class with common fields (eventId, timestamp, eventType). Implement sealed class hierarchy for specific events: CreatePathEvent, AddAnchorEvent, MoveObjectEvent, ModifyStyleEvent, etc. Each event class should be immutable and include toJson/fromJson methods for serialization.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:**
        *   Architecture blueprint Section 3.6 (Data Model - Event entities)
        *   Ticket T004 (Event Model)
    *   **Input Files:** []
    *   **Target Files:**
        *   `lib/domain/events/event_base.dart`
        *   `lib/domain/events/path_events.dart`
        *   `lib/domain/events/object_events.dart`
        *   `lib/domain/events/style_events.dart`
        *   `api/event_schema.dart` (consolidated export)
        *   `api/event_types.md` (documentation)
        *   `test/domain/events/event_serialization_test.dart`
    *   **Deliverables:**
        *   Immutable event classes with sealed hierarchy
        *   JSON serialization/deserialization methods
        *   Event schema documentation
        *   Unit tests for serialization round-trip
    *   **Acceptance Criteria:**
        *   All event classes extend EventBase
        *   Sealed class pattern prevents external extension
        *   toJson/fromJson methods work correctly for all event types
        *   Unit tests verify serialization preserves all fields
        *   Event types documented in api/event_types.md
    *   **Dependencies:** `I1.T1` (project setup)
    *   **Parallelizable:** Yes (no dependencies on other I2 tasks yet)

<!-- anchor: task-i2-t2 -->
*   **Task 2.2:**
    *   **Task ID:** `I2.T2`
    *   **Description:** Implement EventSampler in `lib/infrastructure/event_sourcing/event_sampler.dart` to throttle high-frequency input events to 50ms intervals. Use Dart's Timer to buffer events and emit sampled events. Support immediate flush for critical events (tool deactivation, explicit save).
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:**
        *   Architecture blueprint Section 4.1 (Decision 5 - 50ms sampling rate)
        *   Ticket T005 (Event Recorder with Sampling)
    *   **Input Files:**
        *   `lib/domain/events/event_base.dart` (from I2.T1)
    *   **Target Files:**
        *   `lib/infrastructure/event_sourcing/event_sampler.dart`
        *   `test/infrastructure/event_sourcing/event_sampler_test.dart`
    *   **Deliverables:**
        *   EventSampler class with recordEvent(), flush() methods
        *   Timer-based 50ms throttling logic
        *   Unit tests verifying sampling behavior (rapid events collapse to one per 50ms)
    *   **Acceptance Criteria:**
        *   Rapid events (< 50ms apart) are buffered, only last event emitted
        *   Events > 50ms apart are emitted immediately
        *   flush() method emits buffered event immediately
        *   Unit tests confirm sampling rate behavior
    *   **Dependencies:** `I2.T1` (needs event models)
    *   **Parallelizable:** No (needed by I2.T3)

<!-- anchor: task-i2-t3 -->
*   **Task 2.3:**
    *   **Task ID:** `I2.T3`
    *   **Description:** Implement EventRecorder in `lib/infrastructure/event_sourcing/event_recorder.dart` that uses EventSampler to record events and persist them to SQLite via EventStore. Support pause/resume for disabling recording during event replay. Implement event sequence numbering.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:**
        *   Architecture blueprint Section 4.6 (Internal API - EventRecorder)
        *   Ticket T005 (Event Recorder with Sampling)
    *   **Input Files:**
        *   `lib/infrastructure/event_sourcing/event_sampler.dart` (from I2.T2)
        *   `lib/infrastructure/persistence/event_store.dart` (from I2.T4)
    *   **Target Files:**
        *   `lib/infrastructure/event_sourcing/event_recorder.dart`
        *   `test/infrastructure/event_sourcing/event_recorder_test.dart`
    *   **Deliverables:**
        *   EventRecorder class with recordEvent(), pause(), resume(), flush()
        *   Integration with EventSampler for throttling
        *   Integration with EventStore for persistence
        *   Automatic event sequence numbering
    *   **Acceptance Criteria:**
        *   Events persisted to SQLite with correct sequence numbers
        *   pause() stops recording, resume() re-enables
        *   flush() triggers immediate write of buffered events
        *   Unit tests verify recording and persistence
    *   **Dependencies:** `I2.T2` (EventSampler), `I2.T4` (EventStore)
    *   **Parallelizable:** No (depends on I2.T2 and I2.T4)

<!-- anchor: task-i2-t4 -->
*   **Task 2.4:**
    *   **Task ID:** `I2.T4`
    *   **Description:** Implement EventStore in `lib/infrastructure/persistence/event_store.dart` to handle CRUD operations for the events table. Provide methods: insertEvent(), getEvents(fromSeq, toSeq), getMaxSequence(). Use parameterized queries to prevent SQL injection. Write unit tests with in-memory SQLite database.
    *   **Agent Type Hint:** `DatabaseAgent`
    *   **Inputs:**
        *   Architecture blueprint Section 3.6 (ERD - events table schema)
        *   Ticket T006 (Event Log Persistence)
    *   **Input Files:**
        *   `lib/infrastructure/persistence/database_provider.dart` (from I1.T4)
        *   `lib/infrastructure/persistence/schema.dart` (from I1.T5)
    *   **Target Files:**
        *   `lib/infrastructure/persistence/event_store.dart`
        *   `test/infrastructure/persistence/event_store_test.dart`
    *   **Deliverables:**
        *   EventStore class with insertEvent(), getEvents(), getMaxSequence()
        *   Parameterized SQL queries for safety
        *   Unit tests with mock/in-memory database
    *   **Acceptance Criteria:**
        *   insertEvent() adds event to database with auto-incremented sequence
        *   getEvents(fromSeq, toSeq) returns events in order
        *   getMaxSequence() returns highest event_sequence for document
        *   Unit tests pass with 100% code coverage for EventStore
    *   **Dependencies:** `I1.T4` (DatabaseProvider), `I1.T5` (schema), `I2.T1` (event models)
    *   **Parallelizable:** Yes (can be built in parallel with I2.T2)

<!-- anchor: task-i2-t5 -->
*   **Task 2.5:**
    *   **Task ID:** `I2.T5`
    *   **Description:** Implement SnapshotSerializer in `lib/infrastructure/event_sourcing/snapshot_serializer.dart` to convert Document objects to/from binary format. Use Dart's json encoding with optional gzip compression. Implement serialize(Document) and deserialize(Uint8List) methods.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:**
        *   Architecture blueprint Section 3.5 (Component Diagram - SnapshotSerializer)
    *   **Input Files:**
        *   `lib/domain/models/document.dart` (will be created in I3, for now use placeholder)
    *   **Target Files:**
        *   `lib/infrastructure/event_sourcing/snapshot_serializer.dart`
        *   `test/infrastructure/event_sourcing/snapshot_serializer_test.dart`
    *   **Deliverables:**
        *   SnapshotSerializer class with serialize(), deserialize()
        *   JSON encoding with gzip compression option
        *   Unit tests verifying round-trip serialization
    *   **Acceptance Criteria:**
        *   serialize() produces Uint8List from Document
        *   deserialize() reconstructs Document accurately
        *   Compression reduces size by ~10:1 (verify with test data)
        *   Unit tests confirm round-trip preserves all document data
    *   **Dependencies:** None (can use placeholder Document model)
    *   **Parallelizable:** Yes

<!-- anchor: task-i2-t6 -->
*   **Task 2.6:**
    *   **Task ID:** `I2.T6`
    *   **Description:** Implement SnapshotStore in `lib/infrastructure/persistence/snapshot_store.dart` for CRUD operations on snapshots table. Provide methods: insertSnapshot(), getLatestSnapshot(docId, maxSequence), deleteOldSnapshots(). Write unit tests.
    *   **Agent Type Hint:** `DatabaseAgent`
    *   **Inputs:**
        *   Architecture blueprint Section 3.6 (ERD - snapshots table)
    *   **Input Files:**
        *   `lib/infrastructure/persistence/database_provider.dart` (from I1.T4)
    *   **Target Files:**
        *   `lib/infrastructure/persistence/snapshot_store.dart`
        *   `test/infrastructure/persistence/snapshot_store_test.dart`
    *   **Deliverables:**
        *   SnapshotStore class with insertSnapshot(), getLatestSnapshot(), deleteOldSnapshots()
        *   BLOB storage for compressed snapshots
        *   Unit tests
    *   **Acceptance Criteria:**
        *   insertSnapshot() stores BLOB with event_sequence metadata
        *   getLatestSnapshot() returns most recent snapshot ≤ maxSequence
        *   deleteOldSnapshots() removes snapshots older than last N (configurable)
        *   Unit tests pass with in-memory database
    *   **Dependencies:** `I1.T4` (DatabaseProvider), `I2.T5` (SnapshotSerializer)
    *   **Parallelizable:** Yes (can be built in parallel with I2.T4)

<!-- anchor: task-i2-t7 -->
*   **Task 2.7:**
    *   **Task ID:** `I2.T7`
    *   **Description:** Implement SnapshotManager in `lib/infrastructure/event_sourcing/snapshot_manager.dart` to orchestrate snapshot creation. Trigger snapshot every 1000 events (configurable). Use SnapshotSerializer and SnapshotStore. Provide methods: shouldSnapshot(eventCount), createSnapshot(Document).
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:**
        *   Architecture blueprint Section 4.1 (Decision 6 - snapshot frequency)
        *   Ticket T007 (Snapshot System)
    *   **Input Files:**
        *   `lib/infrastructure/event_sourcing/snapshot_serializer.dart` (from I2.T5)
        *   `lib/infrastructure/persistence/snapshot_store.dart` (from I2.T6)
    *   **Target Files:**
        *   `lib/infrastructure/event_sourcing/snapshot_manager.dart`
        *   `test/infrastructure/event_sourcing/snapshot_manager_test.dart`
    *   **Deliverables:**
        *   SnapshotManager class with shouldSnapshot(), createSnapshot()
        *   Configurable snapshot frequency (default: 1000 events)
        *   Integration tests verifying snapshots created at correct intervals
    *   **Acceptance Criteria:**
        *   shouldSnapshot() returns true every 1000 events
        *   createSnapshot() serializes Document and persists to SnapshotStore
        *   Snapshots compressed with gzip
        *   Unit tests confirm frequency logic
    *   **Dependencies:** `I2.T5` (SnapshotSerializer), `I2.T6` (SnapshotStore)
    *   **Parallelizable:** No (depends on I2.T5 and I2.T6)

<!-- anchor: task-i2-t8 -->
*   **Task 2.8:**
    *   **Task ID:** `I2.T8`
    *   **Description:** Implement EventDispatcher and EventHandlerRegistry in `lib/infrastructure/event_sourcing/`. EventDispatcher routes events to registered handlers. EventHandlerRegistry maintains map of EventType → Handler function. Handlers will apply events to Document state (placeholder for now, full implementation in I3).
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:**
        *   Architecture blueprint Section 3.5 (Component Diagram - Event Dispatcher)
    *   **Input Files:**
        *   `lib/domain/events/event_base.dart` (from I2.T1)
    *   **Target Files:**
        *   `lib/infrastructure/event_sourcing/event_dispatcher.dart`
        *   `lib/infrastructure/event_sourcing/event_handler_registry.dart`
        *   `test/infrastructure/event_sourcing/event_dispatcher_test.dart`
    *   **Deliverables:**
        *   EventDispatcher with dispatch(Event) method
        *   EventHandlerRegistry with registerHandler(), getHandler()
        *   Unit tests with mock handlers
    *   **Acceptance Criteria:**
        *   dispatch() looks up handler in registry and invokes it
        *   Handlers receive event and current document state
        *   Unhandled event types throw informative error
        *   Unit tests verify routing logic
    *   **Dependencies:** `I2.T1` (event models)
    *   **Parallelizable:** Yes

<!-- anchor: task-i2-t9 -->
*   **Task 2.9:**
    *   **Task ID:** `I2.T9`
    *   **Description:** Implement EventReplayer in `lib/infrastructure/event_sourcing/event_replayer.dart` to reconstruct document state from events. Provide replay(fromSeq, toSeq) and replayFromSnapshot(maxSeq) methods. Use EventStore, SnapshotStore, and EventDispatcher. Write integration tests loading test document from events.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:**
        *   Architecture blueprint Section 4.4 (Sequence Diagram - Loading document)
        *   Architecture blueprint Section 4.6 (Internal API - EventReplayer)
        *   Ticket T008 (Event Replay Engine)
    *   **Input Files:**
        *   `lib/infrastructure/persistence/event_store.dart` (from I2.T4)
        *   `lib/infrastructure/persistence/snapshot_store.dart` (from I2.T6)
        *   `lib/infrastructure/event_sourcing/event_dispatcher.dart` (from I2.T8)
    *   **Target Files:**
        *   `lib/infrastructure/event_sourcing/event_replayer.dart`
        *   `test/infrastructure/event_sourcing/event_replayer_test.dart`
        *   `integration_test/event_replay_integration_test.dart`
    *   **Deliverables:**
        *   EventReplayer class with replay(), replayFromSnapshot()
        *   Integration with EventStore, SnapshotStore, EventDispatcher
        *   Integration tests with sample event sequences
    *   **Acceptance Criteria:**
        *   replayFromSnapshot() loads snapshot and replays subsequent events
        *   replay(fromSeq, toSeq) replays events in specified range
        *   Reconstructed document state matches expected state after replay
        *   Integration tests pass with test databases containing sample events
    *   **Dependencies:** `I2.T4` (EventStore), `I2.T6` (SnapshotStore), `I2.T8` (EventDispatcher)
    *   **Parallelizable:** No (final integration task)

---

**Iteration 2 Summary:**
*   **Total Tasks:** 9
*   **Estimated Duration:** 7-8 days
*   **Critical Path:** I2.T1 → I2.T2 → I2.T3 (event model → sampling → recording), I2.T4-I2.T6 → I2.T7 (persistence → snapshots), I2.T8 → I2.T9 (dispatch → replay)
*   **Parallelizable Work:** I2.T1, I2.T4, I2.T5, I2.T6, I2.T8 can partially overlap
*   **Deliverables:** Complete event sourcing system with recording, persistence, snapshots, and replay
