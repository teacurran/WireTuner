<!-- anchor: iteration-plan-overview -->
## 5. Iteration Plan

* **Total Iterations Planned:** 5 (Large-scale engagement per classification; each iteration averages 8–10 focused tasks so autonomous agents can collaborate without thrashing shared artifacts.)
* **Iteration Dependencies:** I1 establishes workspace, persistence, documentation, and CI scaffolds consumed by I2–I5. I2 depends on I1 outputs for vector engine + rendering. I3 builds on I2 geometry plus I1 tooling interfaces. I4 requires mature tool/event layers from I1–I3 to deliver undo/redo and direct manipulation. I5 reuses all prior iterations for save/load, import/export, and parity validation. Iteration sequencing also enforces artifact readiness (component/sequence diagrams, schema docs) before code-level work ramps up.

<!-- anchor: iteration-1-plan -->
### Iteration 1: Foundation & Event Core Enablement

* **Iteration ID:** `I1`
* **Goal:** Stand up the Flutter workspace, melos packages, SQLite-backed event store skeleton, ADRs, and baseline documentation/diagrams so downstream agents share a consistent contract.
* **Prerequisites:** None.

<!-- anchor: task-i1-t1 -->
* **Task 1.1:**
    * **Task ID:** `I1.T1`
    * **Description:** Initialize the `wiretuner-app` Flutter/melos workspace, create core packages (app_shell, event_core, vector_engine stubs), and wire shared linting plus formatting configs aligned with Section 3.
    * **Agent Type Hint:** `SetupAgent`
    * **Inputs:** Section 1 overview, Directory blueprint (Section 3), Decisions 1 & 2 for tooling expectations.
    * **Input Files:** [`README.md`, `docs/reference/architecture-decisions.md`]
    * **Target Files:** [`pubspec.yaml`, `analysis_options.yaml`, `packages/app_shell/pubspec.yaml`, `packages/event_core/pubspec.yaml`, `packages/vector_engine/pubspec.yaml`, `tools/melos_workspace.yaml`]
    * **Deliverables:** Bootstrapped Flutter workspace with melos config, lint rules, placeholder packages compiling under `flutter analyze`, and a README section outlining workspace commands.
    * **Acceptance Criteria:** `melos bootstrap` succeeds; `flutter analyze` produces zero errors; workspace README snippet links to plan anchors; no platform-specific code yet.
    * **Dependencies:** None.
    * **Parallelizable:** Yes (isolated from other tasks).

<!-- anchor: task-i1-t2 -->
* **Task 1.2:**
    * **Task ID:** `I1.T2`
    * **Description:** Produce the PlantUML component diagram capturing UI shell, tool framework, event recorder/replayer, vector engine, persistence, and import/export boundaries; ensure legend + numbering align with Section 2 terminology.
    * **Agent Type Hint:** `DiagrammingAgent`
    * **Inputs:** Section 2 core architecture, Decisions 1–7, workspace structure from `I1.T1`.
    * **Input Files:** [`docs/reference/architecture-decisions.md`, `docs/reference/system_architecture_blueprint.md`]
    * **Target Files:** [`docs/diagrams/component_overview.puml`]
    * **Deliverables:** PlantUML diagram plus short legend comment; referenced link added to README diagrams section and manifest stub.
    * **Acceptance Criteria:** Diagram renders without syntax errors (`plantuml -check`), matches components listed in Section 2, uses anchors, and includes version/date metadata.
    * **Dependencies:** `I1.T1`.
    * **Parallelizable:** No (downstream tasks rely on completed diagram).

<!-- anchor: task-i1-t3 -->
* **Task 1.3:**
    * **Task ID:** `I1.T3`
    * **Description:** Define event recorder, sampler, dispatcher, and snapshot manager interfaces (Dart abstract classes) plus stub implementations that log calls for future iterations; include dependency injection hooks for SQLite + metrics.
    * **Agent Type Hint:** `BackendAgent`
    * **Inputs:** Section 2 communication patterns, Decision 1 sampling rules, Task `I1.T2` diagram for boundaries.
    * **Input Files:** [`packages/event_core/lib/event_core.dart`, `docs/reference/architecture-decisions.md`]
    * **Target Files:** [`packages/event_core/lib/src/recorder.dart`, `packages/event_core/lib/src/replayer.dart`, `packages/event_core/lib/src/snapshot_manager.dart`, `packages/event_core/lib/event_core.dart`, `packages/event_core/test/unit/event_core_interfaces_test.dart`]
    * **Deliverables:** Interface definitions with doc comments, dependency injection hooks, TODO markers referencing future tasks, and a unit test skeleton verifying interface registration.
    * **Acceptance Criteria:** `dart test packages/event_core/test/unit/event_core_interfaces_test.dart` passes; recorder enforces constructor params for sampler + SQLite gateway; code documented for agents; coverage instrumentation noted.
    * **Dependencies:** `I1.T1`.
    * **Parallelizable:** Yes (after workspace exists).

<!-- anchor: task-i1-t4 -->
* **Task 1.4:**
    * **Task ID:** `I1.T4`
    * **Description:** Establish SQLite integration using `sqflite_common_ffi`, including initialization service, WAL pragma, migration stub applying the base schema for `events`, `snapshots`, `metadata`, and connection pooling for multi-document windows.
    * **Agent Type Hint:** `DatabaseAgent`
    * **Inputs:** Section 2 data model overview, Decisions 1 & 2, Task `I1.T3` interfaces.
    * **Input Files:** [`packages/io_services/lib/src/sqlite_gateway.dart`, `docs/reference/system_architecture_blueprint.md`, `docs/reference/architecture-decisions.md`]
    * **Target Files:** [`packages/io_services/lib/src/sqlite_gateway.dart`, `packages/io_services/lib/src/migrations/base_schema.sql`, `packages/io_services/test/sqlite_gateway_test.dart`, `packages/io_services/lib/io_services.dart`]
    * **Deliverables:** SQLite gateway with connection factory, migration runner, config for file-based/in-memory DBs, and tests validating table creation, WAL toggling, and multi-window handles.
    * **Acceptance Criteria:** Tests run on macOS & Windows targets (CI stub); schema matches ERD placeholders; connection errors bubble with actionable messages; SQL script documented.
    * **Dependencies:** `I1.T3`.
    * **Parallelizable:** No (touches shared persistence code).

<!-- anchor: task-i1-t5 -->
* **Task 1.5:**
    * **Task ID:** `I1.T5`
    * **Description:** Author the Mermaid sequence diagram showing pointer input → sampler → event recorder → SQLite → snapshot manager → replayer → Provider notification flow, aligning with Decision 1 KPIs and logging touchpoints.
    * **Agent Type Hint:** `DiagrammingAgent`
    * **Inputs:** Section 2 communication patterns, Tasks `I1.T3`–`I1.T4` outputs.
    * **Input Files:** [`docs/diagrams/component_overview.puml`, `docs/reference/architecture-decisions.md`]
    * **Target Files:** [`docs/diagrams/event_flow_sequence.mmd`]
    * **Deliverables:** Sequence diagram with participants, notes for sampling intervals, log/metrics markers, and replay performance annotations.
    * **Acceptance Criteria:** Mermaid preview validates; diagram referenced in Section 2.1 + README; anchors inserted for manifest linking; includes latency targets.
    * **Dependencies:** `I1.T2`, `I1.T3`, `I1.T4`.
    * **Parallelizable:** No (depends on prior assets).

<!-- anchor: task-i1-t6 -->
* **Task 1.6:**
    * **Task ID:** `I1.T6`
    * **Description:** Draft the event schema reference covering UUID IDs, RFC3339 microsecond timestamps, payload envelope, sampling metadata, undo grouping markers, and collaboration-ready fields; include JSON examples for pen, selection, and shape events.
    * **Agent Type Hint:** `DocumentationAgent`
    * **Inputs:** Section 2.1 artifact list, Decisions 1, 3, 7, Tasks `I1.T3`–`I1.T5`.
    * **Input Files:** [`docs/reference/architecture-decisions.md`, `docs/diagrams/event_flow_sequence.mmd`]
    * **Target Files:** [`docs/reference/event_schema.md`]
    * **Deliverables:** Markdown spec with table of fields, JSON snippets, sampling validation checklist, and glossary callouts; cross-linked from README + manifest.
    * **Acceptance Criteria:** Includes at least three event types with required/optional fields, notes sampling intervals + snapshot cadence, references timestamp precision, and passes markdown lint.
    * **Dependencies:** `I1.T3`, `I1.T5`.
    * **Parallelizable:** Yes (after dependencies satisfied).

<!-- anchor: task-i1-t7 -->
* **Task 1.7:**
    * **Task ID:** `I1.T7`
    * **Description:** Bootstrap CI workflows covering `flutter analyze`, `dart test`, diagram syntax checks, and SQLite smoke tests on macOS + Windows; include caching for `pub get` and PlantUML rendering hook.
    * **Agent Type Hint:** `DevOpsAgent`
    * **Inputs:** Section 2 deployment notes, Task `I1.T1` workspace, artifact paths from `I1.T2`/`I1.T5`.
    * **Input Files:** [`scripts/ci/README.md`, `docs/diagrams/component_overview.puml`, `docs/diagrams/event_flow_sequence.mmd`]
    * **Target Files:** [`scripts/ci/run_checks.sh`, `.github/workflows/ci.yml`, `scripts/ci/diagram_check.sh`]
    * **Deliverables:** CI pipeline definition with parallel jobs (lint/tests/diagram validation) and documentation for running locally, plus badge snippet for README.
    * **Acceptance Criteria:** Workflow passes using `act` or dry-run; includes matrix for macOS + Windows; diagram check fails on syntax errors; README shows CI badge placeholder.
    * **Dependencies:** `I1.T1`, `I1.T2`, `I1.T5`.
    * **Parallelizable:** Yes (post prerequisites).

<!-- anchor: task-i1-t8 -->
* **Task 1.8:**
    * **Task ID:** `I1.T8`
    * **Description:** Implement structured logging + performance counters for event core (frame time placeholders, event write latency, replay duration) using `logger` and wiring toggles for debug/release plus log rotation guidance.
    * **Agent Type Hint:** `BackendAgent`
    * **Inputs:** Decisions 1 & 6 performance targets, Task `I1.T3` interfaces, Section 6 verification preview (draft), CI scripts from `I1.T7` for log artifact capture.
    * **Input Files:** [`packages/event_core/lib/src/recorder.dart`, `packages/event_core/lib/src/replayer.dart`, `docs/reference/event_schema.md`]
    * **Target Files:** [`packages/event_core/lib/src/metrics.dart`, `packages/event_core/lib/src/recorder.dart`, `packages/event_core/lib/src/replayer.dart`, `packages/event_core/test/metrics_test.dart`, `docs/reference/logging_strategy.md`]
    * **Deliverables:** Metrics helper exposing timers/counters, recorder instrumentation hooks, tests validating metric emission, and a logging strategy note cross-linking to Section 6.
    * **Acceptance Criteria:** Metrics toggled via config; tests verify timers record durations; logging note lists file paths + rotation policy; README references new doc.
    * **Dependencies:** `I1.T3`, `I1.T6`.
    * **Parallelizable:** Yes (subject to dependencies).

<!-- anchor: task-i1-t9 -->
* **Task 1.9:**
    * **Task ID:** `I1.T9`
    * **Description:** Capture ADR-001 documenting the hybrid state + history approach (Decision 1) and ADR-002 summarizing multi-window assumptions (Decision 2) so future deviations remain traceable.
    * **Agent Type Hint:** `DocumentationAgent`
    * **Inputs:** Decisions 1 & 2, Tasks `I1.T3`–`I1.T5` for implemented reality, Section 4 directives.
    * **Input Files:** [`docs/reference/architecture-decisions.md`]
    * **Target Files:** [`docs/adr/ADR-001-hybrid-state-history.md`, `docs/adr/ADR-002-multi-window.md`]
    * **Deliverables:** Two ADR markdown files with context/problem/decision/consequences plus status set to "Accepted" and backlinks to blueprint sections.
    * **Acceptance Criteria:** ADR template followed; links to plan anchors; version + date recorded; README ADR table updated.
    * **Dependencies:** `I1.T3`, `I1.T4`, `I1.T2`.
    * **Parallelizable:** Yes (after dependencies).

<!-- anchor: task-i1-t10 -->
* **Task 1.10:**
    * **Task ID:** `I1.T10`
    * **Description:** Add developer-experience tooling: VS Code + IntelliJ run configurations, `justfile` or `makefile` with common commands, and documentation on using PlantUML/Mermaid CLI locally to keep contributors aligned.
    * **Agent Type Hint:** `SetupAgent`
    * **Inputs:** Task `I1.T1` workspace, `I1.T7` CI commands, Section 4 directive #2 (single atomic writes) for scripting guidance.
    * **Input Files:** [`README.md`, `scripts/ci/run_checks.sh`]
    * **Target Files:** [`.vscode/launch.json`, `.vscode/tasks.json`, `justfile` (or `Makefile`), `docs/reference/dev_workflow.md`]
    * **Deliverables:** Editor configs for lint/test/diagram preview commands, scripted shortcuts mirroring CI, and developer workflow doc describing atomic write expectations.
    * **Acceptance Criteria:** Configurations run without manual tweaks; README links to workflow doc; `just test`/`just diagrams` commands succeed on macOS + Windows shells.
    * **Dependencies:** `I1.T1`, `I1.T7`.
    * **Parallelizable:** Yes (post dependencies).
