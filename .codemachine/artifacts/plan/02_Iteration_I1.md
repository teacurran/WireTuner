<!-- anchor: iteration-1-plan -->
### Iteration 1: Foundation & Event Core Kickoff

*   **Iteration ID:** `I1`
*   **Goal:** Establish the Flutter desktop workspace, wire up SQLite persistence, and deliver the initial event-sourcing backbone (modeling, recording, persistence, replay) plus baseline architecture artifacts.
*   **Prerequisites:** None
*   **Tasks:**

<!-- anchor: task-i1-t1 -->
*   **Task 1.1:**
    *   **Task ID:** `I1.T1`
    *   **Description:** Initialize the Flutter desktop project, configure analysis/lint rules, set up CI skeleton, and document build/run guidelines referencing T001.
    *   **Agent Type Hint:** `SetupAgent`
    *   **Inputs:** Section 1 overview, existing architecture blueprint (`thoughts/shared/...`), Flutter tooling guides.
    *   **Input Files:** ["README.md", "pubspec.yaml", "analysis_options.yaml", ".github/workflows"]
    *   **Target Files:** ["pubspec.yaml", "analysis_options.yaml", "README.md", ".github/workflows/ci.yml", "lib/main.dart"]
    *   **Deliverables:** Flutter desktop scaffold with macOS/Windows targets enabled, CI workflow stub, contributor guide snippet for setup.
    *   **Acceptance Criteria:**
        - `flutter doctor` passes locally; README documents prerequisites and commands.
        - CI workflow runs `flutter analyze` + `flutter test` on push.
        - Analyzer enforces null-safety, immutability hints, and forbids `print` debugging in lib/.
    *   **Dependencies:** None
    *   **Parallelizable:** Yes

<!-- anchor: task-i1-t2 -->
*   **Task 1.2:**
    *   **Task ID:** `I1.T2`
    *   **Description:** Integrate SQLite via `sqflite_common_ffi`, create persistence service scaffold, and capture the Component Diagram (PlantUML) covering UI shell, event core, vector engine, and persistence (T002, Section 2 key components).
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:** Sections 2 & 2.1, Dissipate reference repo for patterns.
    *   **Input Files:** ["pubspec.yaml", "lib/src/event_sourcing/persistence/", "docs/diagrams/"]
    *   **Target Files:** ["lib/src/event_sourcing/persistence/sqlite_repository.dart", "docs/diagrams/component_overview.puml"]
    *   **Deliverables:** SQLite repository wrapper with open/close migrations, dependency injection hooks, and PlantUML component diagram checked into docs.
    *   **Acceptance Criteria:**
        - Repository exposes CRUD helpers for metadata, events, snapshots, returning Futures.
        - Diagram renders without syntax errors (tested via `./tools/scripts/render_diagram.sh`).
        - Unit tests mock FFI driver to validate database path selection per platform.
    *   **Dependencies:** `I1.T1`
    *   **Parallelizable:** Yes

<!-- anchor: task-i1-t3 -->
*   **Task 1.3:**
    *   **Task ID:** `I1.T3`
    *   **Description:** Formalize the event sourcing architecture (T003) by detailing event lifecycle documentation and producing the Event Flow Sequence diagram showing recorder, sampler, dispatcher, snapshot manager, and undo navigator interactions.
    *   **Agent Type Hint:** `DocumentationAgent`
    *   **Inputs:** Sections 2 & 2.1, `docs/diagrams/component_overview.puml`.
    *   **Input Files:** ["docs/diagrams/component_overview.puml", "docs/diagrams/"]
    *   **Target Files:** ["docs/diagrams/event_flow_sequence.puml", "docs/specs/event_lifecycle.md"]
    *   **Deliverables:** PlantUML sequence diagram, Markdown explainer describing sampling cadence, snapshot cadence, and failure handling.
    *   **Acceptance Criteria:**
        - Diagram compiles; Markdown cross-links to relevant tickets (T003–T008) and includes latency budgets.
        - Document enumerates responsibilities per component and outlines error handling (disk full, corruption) per requirement notes.
        - Reviewed by backend lead (self-review) and referenced by subsequent tasks.
    *   **Dependencies:** `I1.T1`, `I1.T2`
    *   **Parallelizable:** Yes

<!-- anchor: task-i1-t4 -->
*   **Task 1.4:**
    *   **Task ID:** `I1.T4`
    *   **Description:** Define the event model (T004) as immutable classes/enums via Freezed, covering pen, shape, selection, and file ops actions with JSON serialization helpers.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:** Event lifecycle doc, Sections 2 & 2.1.
    *   **Input Files:** ["lib/src/event_sourcing/model/", "pubspec.yaml"]
    *   **Target Files:** ["lib/src/event_sourcing/model/document_event.dart", "lib/src/event_sourcing/model/event_type.dart"]
    *   **Deliverables:** Freezed models + generated `.g.dart` files, registry of event type constants, basic validation utilities.
    *   **Acceptance Criteria:**
        - Covers events for create path, add anchor, move object, shape creation, viewport, save/load markers.
        - Round-trip JSON serialization tests succeed; invalid payloads throw meaningful errors.
        - Documentation comments map each event to ticket IDs for traceability.
    *   **Dependencies:** `I1.T3`
    *   **Parallelizable:** No (depends on finalized architecture inputs)

<!-- anchor: task-i1-t5 -->
*   **Task 1.5:**
    *   **Task ID:** `I1.T5`
    *   **Description:** Implement the event recorder with 50 ms sampler and buffering (T005), tying into Provider notifications and logger hooks.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:** Event model, event flow doc.
    *   **Input Files:** ["lib/src/event_sourcing/recorder/", "lib/src/event_sourcing/model/"]
    *   **Target Files:** ["lib/src/event_sourcing/recorder/event_recorder.dart", "lib/src/event_sourcing/recorder/event_sampler.dart", "test/unit/event_recorder_test.dart"]
    *   **Deliverables:** Recorder service with pause/resume/flush APIs, 50 ms throttling, and unit tests simulating drag events.
    *   **Acceptance Criteria:**
        - Sampler reduces >90% of redundant move events in tests.
        - Recorder writes batches to repository mock and emits ChangeNotifier updates.
        - Logger emits WARN if queue backpressure exceeds configurable threshold.
    *   **Dependencies:** `I1.T4`
    *   **Parallelizable:** No

<!-- anchor: task-i1-t6 -->
*   **Task 1.6:**
    *   **Task ID:** `I1.T6`
    *   **Description:** Build event log persistence and snapshot manager scaffolding (T006, T007) with transactional writes and configurable snapshot cadence.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:** SQLite repo (`I1.T2`), event model (`I1.T4`).
    *   **Input Files:** ["lib/src/event_sourcing/persistence/", "lib/src/event_sourcing/snapshots/", "test/unit/"]
    *   **Target Files:** ["lib/src/event_sourcing/persistence/event_store.dart", "lib/src/event_sourcing/snapshots/snapshot_manager.dart", "test/unit/snapshot_manager_test.dart"]
    *   **Deliverables:** EventStore abstraction with append/query APIs, SnapshotManager storing compressed blobs every 1,000 events, unit tests with in-memory SQLite.
    *   **Acceptance Criteria:**
        - ACID-safe writes validated via transaction tests; WAL mode enabled on desktop.
        - Snapshot creation under 25 ms for 1k anchors sample dataset.
        - Manager exposes hooks for telemetry (events per snapshot, compression ratio).
    *   **Dependencies:** `I1.T2`, `I1.T4`
    *   **Parallelizable:** No

<!-- anchor: task-i1-t7 -->
*   **Task 1.7:**
    *   **Task ID:** `I1.T7`
    *   **Description:** Implement the event replay engine and undo/redo navigator (T008) capable of loading from latest snapshot, replaying deltas, and navigating to arbitrary sequence numbers.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:** EventStore & SnapshotManager, event flow sequence diagram.
    *   **Input Files:** ["lib/src/event_sourcing/replayer/", "lib/src/event_sourcing/model/", "test/unit/"]
    *   **Target Files:** ["lib/src/event_sourcing/replayer/event_replayer.dart", "lib/src/event_sourcing/replayer/event_navigator.dart", "test/unit/event_replayer_test.dart", "test/unit/event_navigator_test.dart"]
    *   **Deliverables:** Replay service with async generators, navigator managing undo/redo stacks via sequence index, regression tests covering corrupted event handling.
    *   **Acceptance Criteria:**
        - Replay 5k-event fixture under 200 ms on CI runner.
        - Navigator gracefully skips gaps/corrupt events with logged warnings.
        - API documented for consumers (tools, save/load) with sample usage snippet.
    *   **Dependencies:** `I1.T5`, `I1.T6`
    *   **Parallelizable:** No
