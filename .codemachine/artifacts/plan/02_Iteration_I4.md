<!-- anchor: iteration-4-plan -->
### Iteration 4: Shape Tools & Direct Manipulation

*   **Iteration ID:** `I4`
*   **Goal:** Deliver parametric shape tools, finalize direct manipulation workflows (anchors, BCPs, objects, multi-select), and define the save/load API contract to align tooling output with persistence expectations.
*   **Prerequisites:** `I1`, `I2`, `I3`
*   **Tasks:**

<!-- anchor: task-i4-t1 -->
*   **Task 4.1:**
    *   **Task ID:** `I4.T1`
    *   **Description:** Implement Rectangle and Ellipse tools (T025/T026) with adjustable radii/aspect locks, leveraging shared shape controller infrastructure.
    *   **Agent Type Hint:** `FrontendAgent`
    *   **Inputs:** Tool framework, geometry models, rendering overlay.
    *   **Input Files:** ["lib/src/tools/shapes/rectangle_tool.dart", "lib/src/tools/shapes/ellipse_tool.dart", "test/widget/shape_tool_rect_ellipse_test.dart"]
    *   **Target Files:** ["lib/src/tools/shapes/rectangle_tool.dart", "lib/src/tools/shapes/ellipse_tool.dart", "lib/src/tools/shapes/shape_base.dart", "test/widget/shape_tool_rect_ellipse_test.dart"]
    *   **Deliverables:** Shape base class, rectangle/ellipse controllers with snapping, preview overlays, widget tests verifying emitted events.
    *   **Acceptance Criteria:**
        - Drag interaction emits CreateShape + UpdateShape events with normalized dimensions.
        - Holding Shift enforces square/circle; Option toggles from center.
        - Tests assert shape parameters stored in Document and render correctly.
    *   **Dependencies:** `I3.T1`, `I2.T6`
    *   **Parallelizable:** Yes

<!-- anchor: task-i4-t2 -->
*   **Task 4.2:**
    *   **Task ID:** `I4.T2`
    *   **Description:** Deliver Polygon and Star tools (T027/T028) with UI for sides/points, inner radius, and rotational alignment; persist parameters for later editing.
    *   **Agent Type Hint:** `FrontendAgent`
    *   **Inputs:** Shape base, geometry utilities.
    *   **Input Files:** ["lib/src/tools/shapes/polygon_tool.dart", "lib/src/tools/shapes/star_tool.dart", "lib/src/domain/models/shape.dart", "test/widget/shape_tool_polygon_star_test.dart"]
    *   **Target Files:** ["lib/src/tools/shapes/polygon_tool.dart", "lib/src/tools/shapes/star_tool.dart", "lib/src/tools/shapes/shape_options_panel.dart", "test/widget/shape_tool_polygon_star_test.dart"]
    *   **Deliverables:** Controllers for polygon/star, property panel widget, tests verifying event payloads and re-editing via direct selection.
    *   **Acceptance Criteria:**
        - Parameter UI updates tool state and emits UpdateShapeParam events.
        - Star inner radius guards against invalid values; polygon sides >= 3 enforced.
        - Replay reproduces identical geometry (verified via golden test hash).
    *   **Dependencies:** `I4.T1`
    *   **Parallelizable:** No

<!-- anchor: task-i4-t3 -->
*   **Task 4.3:**
    *   **Task ID:** `I4.T3`
    *   **Description:** Define Save/Load API contract (OpenAPI v3 YAML + Markdown narrative) covering document IO commands, metadata, version negotiation, and error codes.
    *   **Agent Type Hint:** `DocumentationAgent`
    *   **Inputs:** Sections 2 & 2.1, event schema, snapshot serializer.
    *   **Input Files:** ["api/save_load.yaml", "docs/specs/persistence_contract.md"]
    *   **Target Files:** ["api/save_load.yaml", "docs/specs/persistence_contract.md"]
    *   **Deliverables:** OpenAPI spec (even though local) documenting pseudo-endpoints/methods for save/load/export, Markdown contract describing CLI/GUI triggers.
    *   **Acceptance Criteria:**
        - Spec validates via `openapi-cli lint` (documented command) and includes schemas referencing event snapshot structures.
        - Contract outlines versioning rules, recovery steps, and relation to `.wiretuner` extension.
        - Referenced by I5 persistence tasks as normative source.
    *   **Dependencies:** `I2.T4`, `I2.T3`
    *   **Parallelizable:** Yes

<!-- anchor: task-i4-t4 -->
*   **Task 4.4:**
    *   **Task ID:** `I4.T4`
    *   **Description:** Implement anchor point dragging + BCP handle dragging improvements (T029/T030) with smoothing, snapping, and on-canvas numeric feedback.
    *   **Agent Type Hint:** `FrontendAgent`
    *   **Inputs:** Direct selection tool, telemetry metrics, geometry services.
    *   **Input Files:** ["lib/src/tools/direct_selection/", "lib/src/canvas/overlays/", "test/widget/anchor_drag_test.dart"]
    *   **Target Files:** ["lib/src/tools/direct_selection/anchor_drag_controller.dart", "lib/src/tools/direct_selection/handle_drag_controller.dart", "lib/src/tools/direct_selection/snapping_service.dart", "test/widget/anchor_drag_test.dart"]
    *   **Deliverables:** Enhanced drag controllers with snap-to-grid/path options, UI feedback for angle/length, tests verifying event emission cadence and snapping accuracy.
    *   **Acceptance Criteria:**
        - Snapping toggled via modifier, defaults to 15° increments.
        - Handle drag emits AdjustHandle events with symmetrical toggles; sampler backlog warnings logged if thresholds exceeded.
        - Tests cover simultaneous multi-anchor adjustments and ensure no mutations outside event pipeline.
    *   **Dependencies:** `I3.T4`
    *   **Parallelizable:** No

<!-- anchor: task-i4-t5 -->
*   **Task 4.5:**
    *   **Task ID:** `I4.T5`
    *   **Description:** Implement object dragging and multi-selection support (T031/T032) including bounding-box transforms, constraint modifiers, and multi-select data model updates.
    *   **Agent Type Hint:** `FrontendAgent`
    *   **Inputs:** Selection tool, document selection APIs, viewport transforms.
    *   **Input Files:** ["lib/src/tools/selection/", "lib/src/domain/document/selection.dart", "test/widget/multi_selection_test.dart"]
    *   **Target Files:** ["lib/src/tools/selection/object_drag_controller.dart", "lib/src/domain/document/selection.dart", "test/widget/multi_selection_test.dart"]
    *   **Deliverables:** Object drag controller with grid snapping, SHIFT-proportional scaling, multi-selection data model enhancements, widget tests verifying selection sets.
    *   **Acceptance Criteria:**
        - Multi-select interactions maintain deterministic event sequences on replay.
        - Object drag manipulates transforms, not vertex data; events aggregated per frame.
        - Tests confirm selection serialization and viewport integration (scroll-to-selection option).
    *   **Dependencies:** `I3.T3`, `I3.T4`
    *   **Parallelizable:** No
