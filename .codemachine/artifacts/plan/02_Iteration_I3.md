<!-- anchor: iteration-3-plan -->
### Iteration 3: Tool System & Pen Workflow

*   **Iteration ID:** `I3`
*   **Goal:** Build the extensible tool framework, deliver selection/direct selection experiences, and implement the full pen workflow (anchors, straight segments, Bezier curves, BCP adjustments) with supporting diagrams and telemetry.
*   **Prerequisites:** `I1`, `I2`
*   **Tasks:**

<!-- anchor: task-i3-t1 -->
*   **Task 3.1:**
    *   **Task ID:** `I3.T1`
    *   **Description:** Create the Tool Framework (T018) including `ToolManager`, base `ITool` interface, cursor service, overlay hooks, and integrate with Provider/app shell.
    *   **Agent Type Hint:** `FrontendAgent`
    *   **Inputs:** Sections 2 & 2.1, rendering outputs, selection overlay.
    *   **Input Files:** ["lib/src/tools/framework/", "lib/src/app/shell/", "test/unit/tool_manager_test.dart"]
    *   **Target Files:** ["lib/src/tools/framework/tool_manager.dart", "lib/src/tools/framework/tool_interface.dart", "lib/src/tools/framework/cursor_service.dart", "test/unit/tool_manager_test.dart"]
    *   **Deliverables:** Tool lifecycle APIs (activate/deactivate), keyboard routing, cursor management, unit tests for state transitions.
    *   **Acceptance Criteria:**
        - Tools register/unregister cleanly; only one active tool at a time.
        - Cursor updates propagate within <1 frame.
        - Test suite covers tool activation, hotkeys, and ensures overlays render via callbacks.
    *   **Dependencies:** `I2.T6`
    *   **Parallelizable:** No

<!-- anchor: task-i3-t2 -->
*   **Task 3.2:**
    *   **Task ID:** `I3.T2`
    *   **Description:** Document the Tool Interaction Sequence (PlantUML) focusing on pen + selection flows and pointer sampling, aligning with event recorder behavior.
    *   **Agent Type Hint:** `DiagrammingAgent`
    *   **Inputs:** Tool framework, event flow doc.
    *   **Input Files:** ["docs/diagrams/tool_interaction_sequence.puml", "docs/specs/event_lifecycle.md"]
    *   **Target Files:** ["docs/diagrams/tool_interaction_sequence.puml", "docs/specs/tool_interactions.md"]
    *   **Deliverables:** Sequence diagram + narrative describing pointer down/move/up events, event batching, and undo grouping.
    *   **Acceptance Criteria:**
        - Diagram renders; includes states for `ToolManager`, `PenTool`, `EventRecorder`, `SnapshotManager`.
        - Markdown outlines undo grouping rules (start/end markers) and acceptance for sampling accuracy.
    *   **Dependencies:** `I3.T1`
    *   **Parallelizable:** Yes

<!-- anchor: task-i3-t3 -->
*   **Task 3.3:**
    *   **Task ID:** `I3.T3`
    *   **Description:** Implement Selection Tool (T019) including marquee selection, object transforms, and integration with selection overlay/telemetry.
    *   **Agent Type Hint:** `FrontendAgent`
    *   **Inputs:** Tool framework, selection overlay, document query APIs.
    *   **Input Files:** ["lib/src/tools/selection/", "lib/src/domain/document/", "test/widget/selection_tool_test.dart"]
    *   **Target Files:** ["lib/src/tools/selection/selection_tool.dart", "lib/src/tools/selection/marquee_controller.dart", "test/widget/selection_tool_test.dart"]
    *   **Deliverables:** Selection tool with Shift/Cmd modifiers, marquee rectangle, translations emitting MoveObject events, widget tests verifying selection states.
    *   **Acceptance Criteria:**
        - Tool selects via click, multi-select via modifiers, and marquee respects viewport transforms.
        - Event recorder receives MoveObject events with aggregated deltas.
        - Tests assert selection state updates and overlays highlight correctly.
    *   **Dependencies:** `I3.T1`
    *   **Parallelizable:** No

<!-- anchor: task-i3-t4 -->
*   **Task 3.4:**
    *   **Task ID:** `I3.T4`
    *   **Description:** Deliver Direct Selection Tool (T020) for anchor/BCP interaction, hooking into hit-testing and event sampling, plus telemetry instrumentation for drag latency.
    *   **Agent Type Hint:** `FrontendAgent`
    *   **Inputs:** Selection overlay, event recorder, tool diagram.
    *   **Input Files:** ["lib/src/tools/direct_selection/", "lib/src/domain/geometry/", "test/widget/direct_selection_tool_test.dart"]
    *   **Target Files:** ["lib/src/tools/direct_selection/direct_selection_tool.dart", "lib/src/tools/direct_selection/drag_controller.dart", "test/widget/direct_selection_tool_test.dart", "lib/src/services/telemetry/tool_metrics.dart"]
    *   **Deliverables:** Direct selection interactions (anchor selection, BCP display, drag), telemetry counters (events/sec, latency), tests for anchor hit logic.
    *   **Acceptance Criteria:**
        - Dragging anchors emits MoveAnchor events at 50 ms cadence with final flush on pointer up.
        - Telemetry event logged when drag > threshold (configurable) or sampler backlog occurs.
        - Tests verify BCP symmetry toggles and anchor type conversions.
    *   **Dependencies:** `I3.T3`
    *   **Parallelizable:** No

<!-- anchor: task-i3-t5 -->
*   **Task 3.5:**
    *   **Task ID:** `I3.T5`
    *   **Description:** Implement Pen Tool anchor placement and straight segments (T021/T022) with visual preview, undo grouping, and event emission.
    *   **Agent Type Hint:** `FrontendAgent`
    *   **Inputs:** Tool framework, tool interaction doc, path models.
    *   **Input Files:** ["lib/src/tools/pen/", "lib/src/domain/models/", "test/widget/pen_tool_straight_test.dart"]
    *   **Target Files:** ["lib/src/tools/pen/pen_tool.dart", "lib/src/tools/pen/pen_preview_overlay.dart", "test/widget/pen_tool_straight_test.dart"]
    *   **Deliverables:** Pen tool state machine (idle, creating path, editing), preview overlay for forthcoming segment, tests verifying anchor creation order and event payloads.
    *   **Acceptance Criteria:**
        - Single-click adds anchor; Enter/double-click completes open path; Shift+click constrains angles.
        - Recorder receives CreatePath + AddAnchor events with sequential IDs.
        - Undo removes entire path creation session via grouping tokens.
    *   **Dependencies:** `I3.T4`
    *   **Parallelizable:** No

<!-- anchor: task-i3-t6 -->
*   **Task 3.6:**
    *   **Task ID:** `I3.T6`
    *   **Description:** Extend Pen Tool for Bezier curves and BCP adjustments (T023/T024), including drag-to-curve gestures, BCP symmetry toggles, and BCP adjustment UI.
    *   **Agent Type Hint:** `FrontendAgent`
    *   **Inputs:** Pen tool base, direct selection behaviors, geometry utilities.
    *   **Input Files:** ["lib/src/tools/pen/", "lib/src/domain/geometry/", "test/widget/pen_tool_bezier_test.dart"]
    *   **Target Files:** ["lib/src/tools/pen/pen_bezier_controller.dart", "lib/src/tools/pen/pen_handle_overlay.dart", "test/widget/pen_tool_bezier_test.dart"]
    *   **Deliverables:** Drag-to-create Bezier segments, automatic BCP mirroring, handle editing prior to path completion, tests covering symmetric/corner anchor transitions.
    *   **Acceptance Criteria:**
        - Holding mouse drag during anchor placement emits AddAnchor with handle vectors scaled to drag distance.
        - ALT/Option toggles corner/smooth anchor types mid-gesture.
        - BCP adjustments emit AdjustHandle events and replay deterministically.
    *   **Dependencies:** `I3.T5`
    *   **Parallelizable:** No
