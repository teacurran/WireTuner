<!-- anchor: iteration-2-plan -->
### Iteration 2: Persistence & Service Contracts
* **Iteration ID:** `I2`
* **Goal:** Implement core event-store services, snapshot engine, GraphQL/OpenAPI contracts, and backend scaffolding required for replay, auto-save, and telemetry.
* **Prerequisites:** `I1`
* **Tasks:**
    <!-- anchor: task-i2-t1 -->
    * **Task 2.1:**
        * **Task ID:** `I2.T1`
        * **Description:** Implement EventStoreServiceAdapter (SQLite WAL) with CRUD, integrity checks, auto-save batching, and migration harness.
        * **Agent Type Hint:** `BackendAgent`
        * **Inputs:** ADR-001, ADR-003, Section 3.2.
        * **Input Files**: [`packages/infrastructure/lib/event_store/`]
        * **Target Files:** [`packages/infrastructure/lib/event_store/event_store_service.dart`, `packages/infrastructure/test/event_store_service_test.dart`, `docs/reference/event_catalog.md`]
        * **Deliverables:** Production-ready adapter, unit tests covering create/read/update flows, updated event catalog with finalized columns.
        * **Acceptance Criteria:** Tests pass; WAL integrity checks script added; doc cross-links FR-014/FR-015.
        * **Dependencies:** `I1.T3`.
        * **Parallelizable:** No.
    <!-- anchor: task-i2-t2 -->
    * **Task 2.2:**
        * **Task ID:** `I2.T2`
        * **Description:** Author GraphQL schema + resolvers for document summary, settings, artboard CRUD, and presence metadata; include OpenAPI for telemetry ingest.
        * **Agent Type Hint:** `BackendAgent`
        * **Inputs:** Section 3.7 (API), Section 5 table.
        * **Input Files**: [`api/schema.graphql`, `server/sync-api/lib/`]
        * **Target Files:** [`api/schema.graphql`, `server/sync-api/lib/main.dart`, `server/sync-api/lib/resolvers/document_resolver.dart`, `api/telemetry.yaml`]
        * **Deliverables:** Valid schema with CI checks, resolver stubs hitting PostgreSQL mocks, telemetry endpoint spec.
        * **Acceptance Criteria:** `graphql-schema-lint` passes; sample queries documented; telemetry spec validated via Spectral.
        * **Dependencies:** `I1.T1`, `I1.T3`.
        * **Parallelizable:** Yes.
    <!-- anchor: task-i2-t3 -->
    * **Task 2.3:**
        * **Task ID:** `I2.T3`
        * **Description:** Build SnapshotManager (background isolate) with configurable thresholds, memory guard, and compression utilities.
        * **Agent Type Hint:** `FrontendAgent`
        * **Inputs:** ADR-004, Section 7.7.
        * **Input Files**: [`packages/core/lib/snapshot/`]
        * **Target Files:** [`packages/core/lib/snapshot/snapshot_manager.dart`, `packages/core/test/snapshot_manager_test.dart`, `docs/reference/snapshot_schema.json`]
        * **Deliverables:** Snapshot service, tests covering thresholds/memory guard, schema updates.
        * **Acceptance Criteria:** compute() isolate usage verified; memory guard unit tests; telemetry hooks stubbed; links to FR-026/NFR-PERF-006.
        * **Dependencies:** `I2.T1`.
        * **Parallelizable:** No.
    <!-- anchor: task-i2-t4 -->
    * **Task 2.4:**
        * **Task ID:** `I2.T4`
        * **Description:** Produce interaction sequence diagrams (pen tool, direct selection, save/snapshot, import flow) aligning with new services.
        * **Agent Type Hint:** `DiagrammingAgent`
        * **Inputs:** Section 3.7 flows, ADR-001/004, FR references.
        * **Input Files**: [`docs/diagrams/sequence/`]
        * **Target Files:** [`docs/diagrams/sequence/pen_flow.puml`, `docs/diagrams/sequence/direct_selection_flow.puml`, `docs/diagrams/sequence/save_snapshot_flow.puml`, `docs/diagrams/sequence/import_flow.puml`]
        * **Deliverables:** Validated PlantUML sequence diagrams, embedded references in docs.
        * **Acceptance Criteria:** Diagrams compile; reviewed by Behavior architect; references added to plan manifest.
        * **Dependencies:** `I1.T2`, `I2.T1`.
        * **Parallelizable:** Yes.
    <!-- anchor: task-i2-t5 -->
    * **Task 2.5:**
        * **Task ID:** `I2.T5`
        * **Description:** Implement auto-save manager + manual save workflow (debounce, dedup, snapshot hook, status UI plumbing) inside InteractionEngine.
        * **Agent Type Hint:** `FrontendAgent`
        * **Inputs:** FR-014, Section 7.12, sequence diagrams.
        * **Input Files**: [`packages/core/lib/interaction/auto_save_manager.dart`, `packages/app/lib/modules/status_bar/`]
        * **Target Files:** [`packages/core/lib/interaction/auto_save_manager.dart`, `packages/app/lib/modules/status_bar/save_indicator.dart`, `packages/core/test/auto_save_manager_test.dart`]
        * **Deliverables:** Auto-save + manual save pipeline, status indicator widget, tests verifying debounce & dedup.
        * **Acceptance Criteria:** Auto-save triggers after 200 ms idle; manual save dedup; snapshot hook invoked; UI indicator accessible.
        * **Dependencies:** `I2.T1`, `I2.T3`.
        * **Parallelizable:** No.
    <!-- anchor: task-i2-t6 -->
    * **Task 2.6:**
        * **Task ID:** `I2.T6`
        * **Description:** Harden telemetry + logging infrastructure (OpenTelemetry exporters, structured log schema, opt-out enforcement) for client and server.
        * **Agent Type Hint:** `DevOpsAgent`
        * **Inputs:** Section 3.6 observability, Section 6 metrics catalog.
        * **Input Files**: [`packages/app/lib/telemetry/`, `server/telemetry-collector/`]
        * **Target Files:** [`packages/app/lib/telemetry/telemetry_client.dart`, `server/telemetry-collector/lib/main.dart`, `docs/qa/telemetry_policy.md`]
        * **Deliverables:** Telemetry client with opt-out gating, collector service stub, policy doc.
        * **Acceptance Criteria:** Telemetry disabled when `telemetryEnabled=false`; collector receives OTLP payload; doc references compliance steps.
        * **Dependencies:** `I1.T1`.
        * **Parallelizable:** Yes.
