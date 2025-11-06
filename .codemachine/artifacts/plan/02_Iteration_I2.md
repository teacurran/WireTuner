<!-- anchor: iteration-2-plan -->
### Iteration 2: Data Model & Rendering Stack

*   **Iteration ID:** `I2`
*   **Goal:** Complete immutable geometry/data models, formalize persistence schemas, and deliver a performant CustomPainter pipeline with viewport transforms and basic selection visualization.
*   **Prerequisites:** `I1`
*   **Tasks:**

<!-- anchor: task-i2-t1 -->
*   **Task 2.1:**
    *   **Task ID:** `I2.T1`
    *   **Description:** Implement core geometry primitives (T009) and path/shape data models (T010/T011) while authoring the combined Data & Domain ERD (Mermaid) that maps SQLite tables to in-memory aggregates.
    *   **Agent Type Hint:** `DatabaseAgent`
    *   **Inputs:** Sections 2 & 2.1, `I1` event model outputs.
    *   **Input Files:** ["lib/src/domain/models/", "docs/diagrams/data_domain_erd.mmd"]
    *   **Target Files:** ["lib/src/domain/models/path.dart", "lib/src/domain/models/shape.dart", "lib/src/domain/models/segment.dart", "docs/diagrams/data_domain_erd.mmd"]
    *   **Deliverables:** Immutable classes with Freezed, factory helpers, unit tests for serialization, ERD diagram synced with schema definitions.
    *   **Acceptance Criteria:**
        - Supports lines, cubic Beziers, polygons, stars, with validation for smooth/corner anchors.
        - ERD passes Mermaid lint; references table/field names exactly as in SQLite repo.
        - Unit tests cover copyWith semantics and ensure equality relies on deep comparison.
    *   **Dependencies:** `I1.T4`, `I1.T6`
    *   **Parallelizable:** No

<!-- anchor: task-i2-t2 -->
*   **Task 2.2:**
    *   **Task ID:** `I2.T2`
    *   **Description:** Design and implement Canvas System with CustomPainter (T013) plus Rendering Pipeline Diagram communicating flow between document provider, viewport, painter, and overlays.
    *   **Agent Type Hint:** `FrontendAgent`
    *   **Inputs:** Sections 2 & 2.1, ERD.
    *   **Input Files:** ["lib/src/canvas/painter/", "lib/src/canvas/viewport/", "docs/diagrams/rendering_pipeline.puml"]
    *   **Target Files:** ["lib/src/canvas/painter/document_painter.dart", "lib/src/canvas/viewport/viewport_controller.dart", "docs/diagrams/rendering_pipeline.puml", "test/widget/document_painter_test.dart"]
    *   **Deliverables:** CustomPainter subsystem with repaint notifier hooks, viewport controller handling pan/zoom with inertial scrolling, PlantUML diagram describing rendering stages.
    *   **Acceptance Criteria:**
        - Painter renders path outlines with placeholder styles; `flutter test` widget suite validates repaint boundary usage.
        - Viewport controller exposes matrix conversions and clamps zoom (0.05–8.0).
        - Diagram explains dirty-region strategy and indicates telemetry insertion points.
    *   **Dependencies:** `I2.T1`
    *   **Parallelizable:** No

<!-- anchor: task-i2-t3 -->
*   **Task 2.3:**
    *   **Task ID:** `I2.T3`
    *   **Description:** Define Path Data Model behaviors (T009/T010) and capture Event Payload JSON Schema covering all event types plus validation helpers.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:** Event model, ERD, component diagram.
    *   **Input Files:** ["lib/src/event_sourcing/model/", "docs/specs/event_payload.schema.json", "docs/specs/"]
    *   **Target Files:** ["docs/specs/event_payload.schema.json", "docs/specs/event_payload.md", "test/unit/event_schema_validation_test.dart"]
    *   **Deliverables:** Draft JSON Schema (Draft 2020-12), Markdown table for each event, validation tests ensuring schema matches Freezed classes.
    *   **Acceptance Criteria:**
        - Schema validated via `npm exec ajv` (document command) or Dart schema validator; all event fixtures pass.
        - Markdown spec explains sampling metadata fields and upgrade strategy.
        - Tests fail when event model adds new required field without schema update.
    *   **Dependencies:** `I1.T4`, `I2.T1`
    *   **Parallelizable:** Yes

<!-- anchor: task-i2-t4 -->
*   **Task 2.4:**
    *   **Task ID:** `I2.T4`
    *   **Description:** Implement Document aggregate (T012) with layer management, selection snapshot, serialization hooks, and integrate snapshot serialization/deserialization with replay engine.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:** ERD, snapshot manager, geometry models.
    *   **Input Files:** ["lib/src/domain/document/", "lib/src/event_sourcing/snapshots/", "test/unit/"]
    *   **Target Files:** ["lib/src/domain/document/document.dart", "lib/src/domain/document/selection.dart", "lib/src/event_sourcing/snapshots/snapshot_serializer.dart", "test/unit/document_snapshot_test.dart"]
    *   **Deliverables:** Document root class with Freezed, selection helpers, snapshot serializer hooking into SnapshotManager, tests ensuring deterministic serialization.
    *   **Acceptance Criteria:**
        - Snapshot round-trip retains ordering, IDs, selection state.
        - Document exposes query helpers for viewport/hit-test consumers.
        - Serializer handles version field for future migrations.
    *   **Dependencies:** `I2.T1`, `I1.T7`
    *   **Parallelizable:** No

<!-- anchor: task-i2-t5 -->
*   **Task 2.5:**
    *   **Task ID:** `I2.T5`
    *   **Description:** Build viewport transform utilities (T014) and integrate them into canvas interactions; include unit/widget tests for pan/zoom inertia and bounds.
    *   **Agent Type Hint:** `FrontendAgent`
    *   **Inputs:** Viewport controller from `I2.T2`, document model.
    *   **Input Files:** ["lib/src/canvas/viewport/", "lib/src/services/telemetry/", "test/widget/viewport_controller_test.dart"]
    *   **Target Files:** ["lib/src/canvas/viewport/viewport_state.dart", "lib/src/canvas/viewport/viewport_binding.dart", "test/widget/viewport_gesture_test.dart"]
    *   **Deliverables:** Gesture detectors hooking into viewport controller, telemetry metrics (FPS, pan latency) counters, tests verifying transformation matrices.
    *   **Acceptance Criteria:**
        - Drag/scroll gestures update viewport smoothly at 60 FPS on simulator.
        - Telemetry logs include FPS + pan delta when debug flag enabled.
        - Unit tests confirm conversions between world/screen coordinates.
    *   **Dependencies:** `I2.T2`, `I2.T4`
    *   **Parallelizable:** No

<!-- anchor: task-i2-t6 -->
*   **Task 2.6:**
    *   **Task ID:** `I2.T6`
    *   **Description:** Implement path and shape rendering (T015/T016) plus selection visualization (T017) leveraging overlays and hit-testing utilities.
    *   **Agent Type Hint:** `FrontendAgent`
    *   **Inputs:** Document/geometry models, viewport transforms.
    *   **Input Files:** ["lib/src/canvas/overlays/", "lib/src/domain/geometry/", "test/widget/"]
    *   **Target Files:** ["lib/src/canvas/overlays/selection_overlay.dart", "lib/src/canvas/painter/path_renderer.dart", "test/widget/selection_overlay_test.dart"]
    *   **Deliverables:** Renderers for path segments, filled/stroked shapes, selection bounding boxes and anchor handles, widget tests verifying highlight states.
    *   **Acceptance Criteria:**
        - Selection overlay displays anchors/BCPs with correct colors/states.
        - Rendering pipeline handles >1,000 objects within 16 ms average frame (profiled sample doc).
        - Hit-testing returns correct object/anchor IDs for upcoming tool work.
    *   **Dependencies:** `I2.T5`
    *   **Parallelizable:** No
