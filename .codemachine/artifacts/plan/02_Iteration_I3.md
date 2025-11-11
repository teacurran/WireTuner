<!-- anchor: iteration-3-plan -->
### Iteration 3: Tool Framework, Selection, and Pen Tool Core

* **Iteration ID:** `I3`
* **Goal:** Establish a robust tool framework with selection/direct-selection tooling, pen tool creation flows, overlays, and cursor/state management so later iterations can add shape tools, direct manipulation, and undo orchestration.
* **Prerequisites:** `I1` (infrastructure) and `I2` (vector engine + rendering). Tools rely on hit testing, viewport controls, and event schema docs delivered earlier.
* **Iteration Success Indicators:** Tool switching latency <30 ms, selection accuracy ≥99% on hit-test suite, pen tool creating closed/open paths recorded as valid events.

<!-- anchor: task-i3-t1 -->
* **Task 3.1:**
    * **Task ID:** `I3.T1`
    * **Description:** Implement the tool framework runtime: `ITool` interface, tool manager, dependency injection wiring, activation/deactivation lifecycle hooks, and provider integration for UI components.
    * **Agent Type Hint:** `BackendAgent`
    * **Inputs:** Section 2 key components, Task `I2.T7` hit testing, Task `I2.T8` viewport notifications.
    * **Input Files:** [`packages/tool_framework/lib/tool_framework.dart`, `packages/vector_engine/lib/src/hit_testing/hit_tester.dart`]
    * **Target Files:** [`packages/tool_framework/lib/src/tool_manager.dart`, `packages/tool_framework/lib/src/tool_registry.dart`, `packages/tool_framework/test/tool_manager_test.dart`, `packages/app_shell/lib/src/state/tool_provider.dart`]
    * **Deliverables:** Tool manager with registration API, active tool stream, hotkey mapping placeholder, plus tests verifying activation order and singleton enforcement.
    * **Acceptance Criteria:** Switching tools triggers lifecycle callbacks; tool provider notifies UI; tests cover invalid activation attempts; documentation references Section 2.
    * **Dependencies:** `I2.T7`, `I2.T8`.
    * **Parallelizable:** No (foundation for remaining tasks).

<!-- anchor: task-i3-t2 -->
* **Task 3.2:**
    * **Task ID:** `I3.T2`
    * **Description:** Produce PlantUML state-machine diagram covering selection, direct selection, and pen tool states (Idle, Hover, PointerDown, Dragging, Commit) with undo grouping markers.
    * **Agent Type Hint:** `DiagrammingAgent`
    * **Inputs:** Task `I3.T1` framework, Decisions 5 & 7, Section 2.1 artifact plan.
    * **Input Files:** [`packages/tool_framework/lib/src/tool_manager.dart`, `docs/reference/event_schema.md`]
    * **Target Files:** [`docs/diagrams/tool_framework_state_machine.puml`]
    * **Deliverables:** Diagram including state transitions, guard conditions, notes for 50 ms sampling, anchors + legend.
    * **Acceptance Criteria:** PlantUML renders cleanly; diagram cross-referenced from README and manifest; includes explicit undo boundary markers and event IDs.
    * **Dependencies:** `I3.T1`.
    * **Parallelizable:** Yes.

<!-- anchor: task-i3-t3 -->
* **Task 3.3:**
    * **Task ID:** `I3.T3`
    * **Description:** Implement Selection Tool supporting object selection (click, marquee), multi-select (Shift), and move operations emitting `MoveObject` events via recorder stub.
    * **Agent Type Hint:** `FrontendAgent`
    * **Inputs:** Tool framework, hit testing, viewport, event recorder interface.
    * **Input Files:** [`packages/tool_framework/lib/src/tool_manager.dart`, `packages/vector_engine/lib/src/hit_testing/hit_tester.dart`, `packages/event_core/lib/src/recorder.dart`]
    * **Target Files:** [`packages/tool_framework/lib/src/tools/selection_tool.dart`, `packages/app_shell/lib/src/canvas/overlays/selection_overlay.dart`, `packages/tool_framework/test/tools/selection_tool_test.dart`]
    * **Deliverables:** Selection tool class, overlay updates for bounding boxes, tests simulating pointer events and verifying event recorder interactions.
    * **Acceptance Criteria:** Tool selects multiple objects, handles keyboard modifiers, emits move events with proper payload, passes widget + unit tests.
    * **Dependencies:** `I3.T1`, `I2.T7`, `I1.T3`.
    * **Parallelizable:** No (foundation for direct selection).

<!-- anchor: task-i3-t4 -->
* **Task 3.4:**
    * **Task ID:** `I3.T4`
    * **Description:** Implement Direct Selection Tool enabling anchor/BCP selection, dragging with 50 ms sampled events, and snapping toggles (grid, angles) for advanced editing.
    * **Agent Type Hint:** `FrontendAgent`
    * **Inputs:** Selection tool behaviors, geometry library, event schema sampling metadata.
    * **Input Files:** [`packages/tool_framework/lib/src/tools/selection_tool.dart`, `packages/vector_engine/lib/src/geometry/path.dart`, `docs/reference/event_schema.md`]
    * **Target Files:** [`packages/tool_framework/lib/src/tools/direct_selection_tool.dart`, `packages/app_shell/lib/src/canvas/overlays/direct_selection_overlay.dart`, `packages/tool_framework/test/tools/direct_selection_tool_test.dart`]
    * **Deliverables:** Direct selection tool class, overlay for handles, tests verifying anchor selection + event emission.
    * **Acceptance Criteria:** Dragging anchors generates `MoveAnchorEvent` sequences respecting sampler; snapping toggle documented; tests hit anchor-level accuracy thresholds.
    * **Dependencies:** `I3.T3`, `I2.T3`, `I1.T3`.
    * **Parallelizable:** No.

<!-- anchor: task-i3-t5 -->
* **Task 3.5:**
    * **Task ID:** `I3.T5`
    * **Description:** Build cursor manager + tool overlays that change cursor icons per tool state and show contextual hints (angle lock, snapping). Integrate with macOS/Windows conventions.
    * **Agent Type Hint:** `FrontendAgent`
    * **Inputs:** Section 2 tech stack, Decisions 6 (parity), Tasks `I3.T1`–`I3.T4`.
    * **Input Files:** [`packages/app_shell/lib/src/state/tool_provider.dart`, `packages/app_shell/lib/src/canvas/selection_overlay.dart`]
    * **Target Files:** [`packages/app_shell/lib/src/ui/cursor_manager.dart`, `packages/app_shell/lib/src/ui/tool_hints.dart`, `packages/app_shell/test/widget/cursor_manager_test.dart`]
    * **Deliverables:** Cursor manager service, UI hints widget, tests verifying platform-specific mappings.
    * **Acceptance Criteria:** Cursor updates within 1 frame; macOS uses `SystemMouseCursors.precise`, Windows uses `basic`; hints internationalization-ready; tests cover parity rules.
    * **Dependencies:** `I3.T3`, `I3.T4`.
    * **Parallelizable:** Yes (once tool states exist).

<!-- anchor: task-i3-t6 -->
* **Task 3.6:**
    * **Task ID:** `I3.T6`
    * **Description:** Implement Pen Tool phase 1—creating anchors, toggling between straight vs. curved points, closing paths, and previewing upcoming segments before commit.
    * **Agent Type Hint:** `FrontendAgent`
    * **Inputs:** Tool framework, geometry, event schema, selection overlay.
    * **Input Files:** [`packages/tool_framework/lib/src/tools/direct_selection_tool.dart`, `packages/vector_engine/lib/src/geometry/path.dart`, `docs/diagrams/tool_framework_state_machine.puml`]
    * **Target Files:** [`packages/tool_framework/lib/src/tools/pen_tool.dart`, `packages/tool_framework/test/tools/pen_tool_creation_test.dart`, `packages/app_shell/lib/src/canvas/overlays/pen_preview_overlay.dart`]
    * **Deliverables:** Pen tool class covering anchor creation + preview lines, overlay for rubber-band preview, tests verifying event payloads for `CreatePath` + `AddAnchor` events.
    * **Acceptance Criteria:** Path creation works for open/closed shapes; preview overlay matches pointer movement; events recorded with correct metadata; tests cover both straight + curved toggles.
    * **Dependencies:** `I3.T4`, `I2.T3`, `I1.T3`.
    * **Parallelizable:** No.

<!-- anchor: task-i3-t7 -->
* **Task 3.7:**
    * **Task ID:** `I3.T7`
    * **Description:** Extend Pen Tool with Bezier curve handles (dragging out BCPs during placement), handle locking (symmetrical/corner), and keyboard modifiers for converting anchors.
    * **Agent Type Hint:** `FrontendAgent`
    * **Inputs:** Task `I3.T6`, geometry library, undo granularity decision.
    * **Input Files:** [`packages/tool_framework/lib/src/tools/pen_tool.dart`, `docs/reference/vector_model.md`, `docs/reference/event_schema.md`]
    * **Target Files:** [`packages/tool_framework/lib/src/tools/pen_tool.dart`, `packages/tool_framework/test/tools/pen_tool_bezier_test.dart`, `docs/reference/pen_tool_usage.md`]
    * **Deliverables:** Enhanced pen tool supporting BCP manipulation, tests verifying handle math + event output, and user-facing doc describing modifiers.
    * **Acceptance Criteria:** Handles obey symmetrical/corner rules; events include handle positions; doc lists keyboard shortcuts; tests assert geometry outputs.
    * **Dependencies:** `I3.T6`.
    * **Parallelizable:** No.

<!-- anchor: task-i3-t8 -->
* **Task 3.8:**
    * **Task ID:** `I3.T8`
    * **Description:** Implement tool overlay rendering order + z-index management to coordinate selection boxes, pen previews, snapping guides, and future shape guides.
    * **Agent Type Hint:** `FrontendAgent`
    * **Inputs:** Tasks `I3.T3`–`I3.T7`, canvas pipeline from `I2`.
    * **Input Files:** [`packages/app_shell/lib/src/canvas/selection_overlay.dart`, `packages/app_shell/lib/src/canvas/wiretuner_canvas.dart`]
    * **Target Files:** [`packages/app_shell/lib/src/canvas/overlay_layer.dart`, `packages/app_shell/lib/src/canvas/overlay_registry.dart`, `packages/app_shell/test/widget/overlay_layer_test.dart`]
    * **Deliverables:** Overlay registry with deterministic stacking, tests verifying order + hit pass-through, documentation snippet.
    * **Acceptance Criteria:** Overlays stack as configured; pointer events route to active overlay; tests cover stacking + removal; README references overlay architecture.
    * **Dependencies:** `I3.T5`, `I3.T7`.
    * **Parallelizable:** Yes (post dependencies).

<!-- anchor: task-i3-t9 -->
* **Task 3.9:**
    * **Task ID:** `I3.T9`
    * **Description:** Add telemetry + undo boundary annotations for tools: ensure operations flush pending sampled events, emit human-readable labels (“Move Rectangle”) for UI, and log tool usage counts.
    * **Agent Type Hint:** `BackendAgent`
    * **Inputs:** Task `I1.T8` metrics, `I3` tool implementations, Decision 7 undo granularity.
    * **Input Files:** [`packages/event_core/lib/src/metrics.dart`, `packages/tool_framework/lib/src/tools/pen_tool.dart`]
    * **Target Files:** [`packages/tool_framework/lib/src/tool_telemetry.dart`, `packages/tool_framework/test/tool_telemetry_test.dart`, `docs/reference/undo_labels.md`]
    * **Deliverables:** Telemetry helper, undo label mapping table, tests verifying labels for each tool, and documentation for UI surfaces.
    * **Acceptance Criteria:** Each tool registers descriptive labels; telemetry aggregated per tool; doc lists operations; metrics exported via logger.
    * **Dependencies:** `I3.T3`–`I3.T7`, `I1.T8`.
    * **Parallelizable:** Yes (after dependencies).

<!-- anchor: task-i3-t10 -->
* **Task 3.10:**
    * **Task ID:** `I3.T10`
    * **Description:** Deliver manual + automated QA scripts covering selection + pen flows: widget tests simulating pointer sequences, integration test verifying events persisted, and QA checklist referencing Decision 6 parity.
    * **Agent Type Hint:** `QAAgent`
    * **Inputs:** All prior I3 tasks, event schema, metrics outputs.
    * **Input Files:** [`packages/tool_framework/test/tools/pen_tool_bezier_test.dart`, `test/integration/event_to_canvas_test.dart`, `docs/reference/pen_tool_usage.md`]
    * **Target Files:** [`test/integration/tool_pen_selection_test.dart`, `docs/qa/tooling_checklist.md`]
    * **Deliverables:** Integration test verifying pen + selection interplay, QA checklist with macOS/Windows steps, recorded expected telemetry ranges.
    * **Acceptance Criteria:** Tests pass headless; QA checklist includes parity notes; telemetry thresholds documented; references anchors for manifest.
    * **Dependencies:** `I3.T3`–`I3.T9`.
    * **Parallelizable:** No (final validation).

<!-- anchor: task-i3-t11 -->
* **Task 3.11:**
    * **Task ID:** `I3.T11`
    * **Description:** Update documentation + onboarding materials (README, developer workflow) with tool usage gifs/screenshots (if possible) and describe how to enable mock events for demos.
    * **Agent Type Hint:** `DocumentationAgent`
    * **Inputs:** Tool outputs, QA checklist, Section 1 goal statement.
    * **Input Files:** [`README.md`, `docs/reference/pen_tool_usage.md`, `docs/qa/tooling_checklist.md`]
    * **Target Files:** [`README.md`, `docs/reference/dev_workflow.md`, `docs/reference/tooling_overview.md`]
    * **Deliverables:** Refreshed docs explaining tool states, keybindings, screenshots/gifs references, plus instructions for running integration tests.
    * **Acceptance Criteria:** README tool section matches shipped features, links to plan anchors; dev workflow doc updated; Markdown lint passes; assets added to `.gitignore` if needed.
    * **Dependencies:** `I3.T6`–`I3.T10`.
    * **Parallelizable:** No (final documentation sweep).
