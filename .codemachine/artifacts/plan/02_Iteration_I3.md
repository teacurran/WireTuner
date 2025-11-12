<!-- anchor: iteration-3-plan -->
### Iteration 3: Editor Tooling, Viewport & UI Systems
* **Iteration ID:** `I3`
* **Goal:** Implement core drawing/selection tools, viewport controls, screen-space snapping/nudging, and UI shells (Navigator, Inspector, HUDs) grounded in earlier infrastructure.
* **Prerequisites:** `I1`, `I2`
* **Tasks:**
    <!-- anchor: task-i3-t1 -->
    * **Task 3.1:**
        * **Task ID:** `I3.T1`
        * **Description:** Build InteractionEngine tool registry plus Pen, Selection, Direct Selection tool implementations with undo grouping and sampling hooks.
        * **Agent Type Hint:** `FrontendAgent`
        * **Inputs:** FR-001–FR-007, FR-025, Section 7.11.
        * **Input Files**: [`packages/core/lib/tools/`]
        * **Target Files:** [`packages/core/lib/tools/tool_registry.dart`, `packages/core/lib/tools/pen_tool.dart`, `packages/core/lib/tools/selection_tool.dart`, `packages/core/lib/tools/direct_selection_tool.dart`, `packages/core/test/tools/*_test.dart`]
        * **Deliverables:** Tool interfaces, implementations, tests validating sampling & snapping integration.
        * **Acceptance Criteria:** Tools fire correct events; undo boundaries respect 200 ms idle; tests cover anchor creation/move cases.
        * **Dependencies:** `I2.T1`, `I2.T5`.
        * **Parallelizable:** No.
    <!-- anchor: task-i3-t2 -->
    * **Task 3.2:**
        * **Task ID:** `I3.T2`
        * **Description:** Implement viewport controller (zoom, pan, fit, per-artboard state), screen-space grid snapping, and intelligent nudging with toast hints.
        * **Agent Type Hint:** `FrontendAgent`
        * **Inputs:** FR-012, FR-013, FR-028, FR-050, Section 7.11.
        * **Input Files**: [`packages/core/lib/viewport/`, `packages/app/lib/modules/status_bar/`]
        * **Target Files:** [`packages/core/lib/viewport/viewport_controller.dart`, `packages/core/lib/viewport/grid_snapper.dart`, `packages/core/lib/viewport/nudge_service.dart`, `packages/app/lib/modules/status_bar/zoom_indicator.dart`, `packages/core/test/viewport/*`]
        * **Deliverables:** Viewport service, grid snapper, nudge notifications, tests.
        * **Acceptance Criteria:** Viewport state saved per artboard; snapping uses screen-space; toast fires after overshoot; tests enforce conversions.
        * **Dependencies:** `I2.T3`.
        * **Parallelizable:** Yes.
    <!-- anchor: task-i3-t3 -->
    * **Task 3.3:**
        * **Description:** Construct Navigator window UI (tabs, grid, context menus, thumbnail auto-refresh hook) plus associated state providers.
        * **Agent Type Hint:** `FrontendAgent`
        * **Task ID:** `I3.T3`
        * **Inputs:** FR-029–FR-044, Section 3.7 Flow H.
        * **Input Files**: [`packages/app/lib/modules/navigator/`]
        * **Target Files:** [`packages/app/lib/modules/navigator/navigator_window.dart`, `packages/app/lib/modules/navigator/artboard_card.dart`, `packages/app/lib/modules/navigator/context_menu.dart`, `packages/app/lib/modules/navigator/state/navigator_provider.dart`, `packages/app/test/navigator/*`]
        * **Deliverables:** Functional Navigator UI with virtualization, context menus, shortcuts, tests for tab/thumbnail logic.
        * **Acceptance Criteria:** Handles 1000 artboards with virtualization; context menu actions dispatch events; thumbnail refresh respects 10s interval or save trigger.
        * **Dependencies:** `I2.T2`, `I2.T5`.
        * **Parallelizable:** No.
    <!-- anchor: task-i3-t4 -->
    * **Task 3.4:**
        * **Task ID:** `I3.T4`
        * **Description:** Produce UI wireframes + interaction write-ups for artboard window, Navigator, history replay, collaboration overlays per Section 6 (UI spec) and embed into docs.
        * **Agent Type Hint:** `DocumentationAgent`
        * **Inputs:** Section 6 UI/UX architecture, flows A–J.
        * **Input Files**: [`docs/ui/wireframes/`]
        * **Target Files:** [`docs/ui/wireframes/artboard_window.md`, `docs/ui/wireframes/navigator.md`, `docs/ui/wireframes/history_replay.md`, `docs/ui/wireframes/collaboration_panel.md`]
        * **Deliverables:** Annotated wireframes (ASCII/embedded images), interaction notes referencing requirement IDs.
        * **Acceptance Criteria:** Wireframes cover responsive states, accessibility cues; reviewed by UX lead; plan manifest references anchors.
        * **Dependencies:** `I3.T3`.
        * **Parallelizable:** Yes.
    <!-- anchor: task-i3-t5 -->
    * **Task 3.5:**
        * **Task ID:** `I3.T5`
        * **Description:** Implement Inspector + Layer panel organisms (property editors, layer tree, inline rename, lock/visibility) wired to domain models.
        * **Agent Type Hint:** `FrontendAgent`
        * **Inputs:** FR-045, UI tokens, Section 6.2 component specs.
        * **Input Files**: [`packages/app/lib/modules/inspector/`, `packages/app/lib/modules/layers/`]
        * **Target Files:** [`packages/app/lib/modules/inspector/inspector_panel.dart`, `packages/app/lib/modules/layers/layer_tree.dart`, `packages/app/lib/modules/inspector/property_groups/*.dart`, `packages/app/test/inspector/*`]
        * **Deliverables:** Inspector UI, layer tree virtualization, hooking into InteractionEngine selections.
        * **Acceptance Criteria:** Edits dispatch domain commands; accessibility labels present; virtualization handles 100 layers; tests for rename/lock toggles.
        * **Dependencies:** `I3.T1`.
        * **Parallelizable:** Yes.
    <!-- anchor: task-i3-t6 -->
    * **Task 3.6:**
        * **Task ID:** `I3.T6`
        * **Description:** Build performance overlay + telemetry instrumentation surfaces (FPS, replay rate, snapshot duration) along with opt-out aware settings UI.
        * **Agent Type Hint:** `FrontendAgent`
        * **Inputs:** Section 3.6 metrics, Section 6 overlay tokens.
        * **Input Files**: [`packages/app/lib/modules/performance_overlay/`, `packages/app/lib/modules/settings/telemetry_section.dart`]
        * **Target Files:** [`packages/app/lib/modules/performance_overlay/performance_overlay.dart`, `packages/app/lib/modules/settings/telemetry_section.dart`, `packages/app/test/performance_overlay_test.dart`]
        * **Deliverables:** Overlay widget, telemetry toggles, instrumentation hooks into InteractionEngine/SnapshotManager.
        * **Acceptance Criteria:** Overlay draggable/dockable; metrics cross-reference telemetry IDs; opt-out disables emission; tests ensure state persistence.
        * **Dependencies:** `I2.T6`.
        * **Parallelizable:** Yes.
