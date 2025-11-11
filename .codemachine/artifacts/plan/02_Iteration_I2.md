<!-- anchor: iteration-2-plan -->
### Iteration 2: Vector Engine, Geometry, and Rendering Spine

* **Iteration ID:** `I2`
* **Goal:** Deliver immutable vector data models, geometry utilities, snapshot serialization, and the first rendering pass (canvas, viewport, selection overlay) so tool agents in I3 can operate on reliable primitives.
* **Prerequisites:** Completion of `I1` (workspace, diagrams, event interfaces, SQLite gateway, CI, logging) because vector models depend on base packages and documentation.
* **Iteration Success Indicators:** 95%+ unit test coverage for geometry modules, first render benchmark hitting ≥55 FPS on sample docs, and documented data/schema artifacts referenced by subsequent iterations.

<!-- anchor: task-i2-t1 -->
* **Task 2.1:**
    * **Task ID:** `I2.T1`
    * **Description:** Create the Mermaid ERD describing `events`, `snapshots`, `metadata`, plus derived cache tables (future) and annotate snapshot cadence + compression fields.
    * **Agent Type Hint:** `DiagrammingAgent`
    * **Inputs:** Section 2 data model overview, Decision 1 snapshot rules, Task `I1.T4` schema stub.
    * **Input Files:** [`packages/io_services/lib/src/migrations/base_schema.sql`, `docs/reference/architecture-decisions.md`]
    * **Target Files:** [`docs/diagrams/data_snapshot_erd.mmd`]
    * **Deliverables:** ERD source with legend + anchor, README link, and comment referencing Decision 1.
    * **Acceptance Criteria:** Diagram renders via Mermaid CLI; table/column names align with SQL script; snapshot frequency + compression noted; added to manifest.
    * **Dependencies:** `I1.T4`.
    * **Parallelizable:** Yes (diagram-centric).

<!-- anchor: task-i2-t2 -->
* **Task 2.2:**
    * **Task ID:** `I2.T2`
    * **Description:** Author the vector model specification describing Document, Layer, VectorObject, Path, Shape, Segment, Anchor, Style, Transform, Selection, and Viewport structures with immutability + copyWith rules.
    * **Agent Type Hint:** `DocumentationAgent`
    * **Inputs:** Section 2 data overview, Task `I2.T1` ERD, Task `I1.T6` event schema for ID formats.
    * **Input Files:** [`docs/reference/event_schema.md`, `docs/diagrams/data_snapshot_erd.mmd`]
    * **Target Files:** [`docs/reference/vector_model.md`]
    * **Deliverables:** Markdown doc with UML-style text diagrams, invariants (e.g., anchor handles), serialization guidance, and sample JSON blocks.
    * **Acceptance Criteria:** Each entity lists fields, types, immutability notes; includes at least two examples (rectangle path, Bezier); cross-referenced in README + manifest.
    * **Dependencies:** `I2.T1`.
    * **Parallelizable:** Yes (documentation heavy).

<!-- anchor: task-i2-t3 -->
* **Task 2.3:**
    * **Task ID:** `I2.T3`
    * **Description:** Implement core geometry primitives inside `vector_engine`: points, anchors, segments (line, cubic Bezier, arc), bounding boxes, and conversions between shapes and paths.
    * **Agent Type Hint:** `BackendAgent`
    * **Inputs:** `docs/reference/vector_model.md`, Decisions 5 & 7 requirements (Tier-2 features + undo granularity), Task `I1.T3` interfaces.
    * **Input Files:** [`packages/vector_engine/lib/vector_engine.dart`, `docs/reference/vector_model.md`]
    * **Target Files:** [`packages/vector_engine/lib/src/geometry/anchor.dart`, `packages/vector_engine/lib/src/geometry/segment.dart`, `packages/vector_engine/lib/src/geometry/path.dart`, `packages/vector_engine/test/geometry/segment_test.dart`, `packages/vector_engine/test/geometry/path_test.dart`]
    * **Deliverables:** Dart classes w/ Freezed data (if chosen) or manual immutability, helper methods for curve evaluation, JSON serialization hooks, and thorough geometry tests.
    * **Acceptance Criteria:** Unit tests cover line + Bezier calculations, bounding boxes, equality; code documented referencing Decision 5; `dart test` passes on CI matrix.
    * **Dependencies:** `I1.T3`, `I2.T2`.
    * **Parallelizable:** No (core code path for subsequent tasks).

<!-- anchor: task-i2-t4 -->
* **Task 2.4:**
    * **Task ID:** `I2.T4`
    * **Description:** Build the snapshot serializer/deserializer bridging vector models and SQLite BLOBs, including versioned headers, compression toggles, and schema migration placeholders.
    * **Agent Type Hint:** `BackendAgent`
    * **Inputs:** Tasks `I2.T2`–`I2.T3`, Decision 4 file-versioning rules, `I1.T4` SQLite gateway.
    * **Input Files:** [`packages/event_core/lib/src/snapshot_manager.dart`, `packages/io_services/lib/src/sqlite_gateway.dart`, `docs/reference/vector_model.md`]
    * **Target Files:** [`packages/event_core/lib/src/snapshot_serializer.dart`, `packages/event_core/test/snapshot_serializer_test.dart`, `docs/reference/file_versioning_notes.md`]
    * **Deliverables:** Serializer with CRC/size metadata, tests verifying round-trip fidelity for sample documents, and doc describing version compatibility + downgrade warnings.
    * **Acceptance Criteria:** Snapshot round-trips succeed for sample doc containing paths + shapes; serialization speed measured (<20 ms for medium doc); doc references Decision 4 matrix and includes TODO for degrade flow.
    * **Dependencies:** `I2.T3`, `I1.T4`.
    * **Parallelizable:** No (touches shared persistence code).

<!-- anchor: task-i2-t5 -->
* **Task 2.5:**
    * **Task ID:** `I2.T5`
    * **Description:** Implement the CustomPainter canvas, viewport manager, and selection overlay foundation (bounding boxes, anchor handles) in `packages/app_shell` using mock data until tools exist.
    * **Agent Type Hint:** `FrontendAgent`
    * **Inputs:** Section 2 technology stack, Task `I2.T3` geometry outputs, Task `I1.T8` logging hooks.
    * **Input Files:** [`packages/app_shell/lib/main.dart`, `packages/vector_engine/lib/src/geometry/path.dart`]
    * **Target Files:** [`packages/app_shell/lib/src/canvas/wiretuner_canvas.dart`, `packages/app_shell/lib/src/canvas/viewport_controller.dart`, `packages/app_shell/lib/src/canvas/selection_overlay.dart`, `packages/app_shell/test/widget/canvas_smoke_test.dart`]
    * **Deliverables:** Canvas widget with repaint boundary, pan/zoom gestures, selection overlay placeholders, widget test ensuring tree builds at 60 FPS using golden/perf baseline, and docstring referencing Section 2.
    * **Acceptance Criteria:** Widget test verifies no exceptions; viewport clamps zoom; selection overlay draws handles for mock anchors; logging captures frame times; code passes `flutter analyze`.
    * **Dependencies:** `I2.T3`.
    * **Parallelizable:** Yes (after geometry complete).

<!-- anchor: task-i2-t6 -->
* **Task 2.6:**
    * **Task ID:** `I2.T6`
    * **Description:** Implement rendering of paths/shapes with stroke/fill, gradient placeholders, and GPU-friendly caching strategy; integrate with viewport transforms and add performance profiling overlay toggle.
    * **Agent Type Hint:** `FrontendAgent`
    * **Inputs:** Tasks `I2.T3`, `I2.T5`, Decision 5 supported features, Decision 6 parity requirements.
    * **Input Files:** [`packages/app_shell/lib/src/canvas/wiretuner_canvas.dart`, `docs/reference/ai_import_matrix.md` (placeholder until I5)]
    * **Target Files:** [`packages/app_shell/lib/src/canvas/render_pipeline.dart`, `packages/app_shell/lib/src/canvas/paint_styles.dart`, `packages/app_shell/test/widget/render_pipeline_test.dart`]
    * **Deliverables:** Render pipeline module with caching toggles, gradient TODO markers, tests verifying stroke widths & transforms, and README snippet on performance overlay.
    * **Acceptance Criteria:** Sample document renders correctly in debug mode; tests assert pixel colors (golden) for strokes/fills; performance overlay toggle accessible via keyboard shortcut; parity statement added to doc.
    * **Dependencies:** `I2.T5`.
    * **Parallelizable:** No (extends canvas foundation).

<!-- anchor: task-i2-t7 -->
* **Task 2.7:**
    * **Task ID:** `I2.T7`
    * **Description:** Build geometry-driven hit-testing utilities (point-in-path, distance-to-curve, bounding volume hierarchy) and expose selection queries for upcoming tool work.
    * **Agent Type Hint:** `BackendAgent`
    * **Inputs:** Task `I2.T3` geometry, Task `I2.T5` selection overlay, Section 2 communication patterns for synchronous queries.
    * **Input Files:** [`packages/vector_engine/lib/src/geometry/path.dart`, `packages/vector_engine/lib/src/selection/selection_model.dart`]
    * **Target Files:** [`packages/vector_engine/lib/src/hit_testing/hit_tester.dart`, `packages/vector_engine/lib/src/hit_testing/bvh.dart`, `packages/vector_engine/test/hit_testing/hit_tester_test.dart`, `docs/reference/hit_testing_notes.md`]
    * **Deliverables:** Hit testing service w/ BVH acceleration, tests covering anchor/object selection, doc describing heuristics + edge cases (tolerance, zoom scaling).
    * **Acceptance Criteria:** Hit testing handles 10k objects within target (<2 ms average); tests cover anchors, segments, shapes; doc outlines future spatial indexing improvements and profiling hooks.
    * **Dependencies:** `I2.T3`, `I2.T5`.
    * **Parallelizable:** Yes (after dependencies).

<!-- anchor: task-i2-t8 -->
* **Task 2.8:**
    * **Task ID:** `I2.T8`
    * **Description:** Integrate viewport controller with keyboard shortcuts (space-bar pan, +/- zoom), persistence of viewport state in document, and expose Provider notifiers for UI binding.
    * **Agent Type Hint:** `FrontendAgent`
    * **Inputs:** Task `I2.T5` viewport foundation, Task `I1.T3` provider wiring assumptions, Section 2 communication patterns.
    * **Input Files:** [`packages/app_shell/lib/src/canvas/viewport_controller.dart`, `packages/app_shell/lib/src/state/document_provider.dart`]
    * **Target Files:** [`packages/app_shell/lib/src/canvas/viewport_controller.dart`, `packages/app_shell/lib/src/state/document_provider.dart`, `packages/app_shell/test/widget/viewport_controller_test.dart`]
    * **Deliverables:** Keyboard + mouse gesture bindings, persisted viewport info inside Document, widget tests verifying state sync across Provider consumers, and doc snippet describing shortcuts.
    * **Acceptance Criteria:** Zoom/pan gestures respect min/max; viewport saved/restored on document reopen (mock); tests cover keyboard shortcuts; doc update referencing Section 2 + Decision 6.
    * **Dependencies:** `I2.T5`.
    * **Parallelizable:** Yes.

<!-- anchor: task-i2-t9 -->
* **Task 2.9:**
    * **Task ID:** `I2.T9`
    * **Description:** Create automated performance benchmark harness (e.g., `dev/benchmarks/render_bench.dart`) that renders synthetic docs at varying complexity and records FPS + frame time stats.
    * **Agent Type Hint:** `DevOpsAgent`
    * **Inputs:** Logging hooks from `I1.T8`, rendering pipeline `I2.T6`, viewport controller `I2.T8`.
    * **Input Files:** [`packages/app_shell/lib/src/canvas/render_pipeline.dart`, `packages/event_core/lib/src/metrics.dart`]
    * **Target Files:** [`dev/benchmarks/render_bench.dart`, `dev/benchmarks/README.md`, `scripts/ci/run_benchmarks.sh`]
    * **Deliverables:** Benchmark script, documentation on running + interpreting results, CI optional step (manual trigger) capturing metrics artifact.
    * **Acceptance Criteria:** Benchmark outputs CSV/JSON with FPS, frame time, memory; README explains dataset; script runs headless on macOS/Windows; CI stores artifact when triggered.
    * **Dependencies:** `I2.T6`, `I2.T8`.
    * **Parallelizable:** Yes (post dependencies).

<!-- anchor: task-i2-t10 -->
* **Task 2.10:**
    * **Task ID:** `I2.T10`
    * **Description:** Conduct integration test wiring event replay → snapshot serializer → canvas rendering using mocked events to render a simple rectangle + path, ensuring end-to-end data flow before tools exist.
    * **Agent Type Hint:** `IntegrationAgent`
    * **Inputs:** Tasks `I1.T3`, `I1.T4`, `I2.T3`–`I2.T6`.
    * **Input Files:** [`packages/event_core/lib/src/replayer.dart`, `packages/app_shell/lib/src/canvas/wiretuner_canvas.dart`, `packages/vector_engine/lib/src/geometry/path.dart`]
    * **Target Files:** [`test/integration/event_to_canvas_test.dart`, `test/integration/fixtures/sample_events.json`]
    * **Deliverables:** Integration test verifying document reconstructs from events and renders expected widget tree; fixture data referencing event schema.
    * **Acceptance Criteria:** Test passes headless; asserts number of draw calls + selection overlay states; fixture validated by schema from `I1.T6`; CI marks test as part of integration suite.
    * **Dependencies:** `I2.T3`, `I2.T4`, `I2.T6`.
    * **Parallelizable:** No (ties multiple modules together).

<!-- anchor: task-i2-t11 -->
* **Task 2.11:**
    * **Task ID:** `I2.T11`
    * **Description:** Document a rendering troubleshooting guide summarizing known issues (precision loss, z-fighting, performance dips), diagnostic commands (benchmark harness, perf overlay), and escalation paths for future iterations.
    * **Agent Type Hint:** `DocumentationAgent`
    * **Inputs:** Outputs from Tasks `I2.T5`–`I2.T10`, benchmark results, Section 6 verification expectations.
    * **Input Files:** [`dev/benchmarks/README.md`, `packages/app_shell/lib/src/canvas/wiretuner_canvas.dart`, `docs/reference/vector_model.md`]
    * **Target Files:** [`docs/reference/rendering_troubleshooting.md`]
    * **Deliverables:** Markdown guide with symptom/diagnosis tables, references to metrics, and TODOs for GPU acceleration; linked in README troubleshooting section.
    * **Acceptance Criteria:** Contains at least five scenarios with remediation steps; cross-links to metrics + benchmark docs; passes markdown lint; anchor added for manifest.
    * **Dependencies:** `I2.T9`, `I2.T10`.
    * **Parallelizable:** No (requires completed outputs).
