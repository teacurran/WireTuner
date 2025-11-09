<!-- anchor: iteration-4-plan -->
### Iteration 4: Direct Manipulation, Undo/Redo, and History UX

* **Iteration ID:** `I4`
* **Goal:** Deliver operation-based undo/redo, history browsing, snapshot tuning, direct manipulation polish (drag handles/objects), and multi-window coordination aligned with Decisions 1, 2, and 7.
* **Prerequisites:** Iterations `I1`–`I3` (workspace, event core, rendering, tool framework) completed.
* **Iteration Success Indicators:** Undo latency <80 ms, history panel scrubbing 5k events/sec, multi-window consistency with isolated undo stacks.

<!-- anchor: task-i4-t1 -->
* **Task 4.1:**
    * **Task ID:** `I4.T1`
    * **Description:** Implement operation grouping service that listens to event recorder, detects idle thresholds (200 ms), and emits operation boundaries with descriptions.
    * **Agent Type Hint:** `BackendAgent`
    * **Inputs:** Decision 7, Task `I1.T3` recorder interfaces, telemetry from `I3.T9`.
    * **Input Files:** [`packages/event_core/lib/src/recorder.dart`, `packages/event_core/lib/src/metrics.dart`, `docs/reference/undo_labels.md`]
    * **Target Files:** [`packages/event_core/lib/src/operation_grouping.dart`, `packages/event_core/test/operation_grouping_test.dart`]
    * **Deliverables:** Grouping service with configurable idle threshold, tests covering continuous typing vs. paused operations, and doc comments referencing Decision 7.
    * **Acceptance Criteria:** Groups contiguous events correctly; exposes API for manual boundaries; tests cover edge cases; metrics log operations/sec.
    * **Dependencies:** `I3.T9`.
    * **Parallelizable:** No (foundation for undo).

<!-- anchor: task-i4-t2 -->
* **Task 4.2:**
    * **Task ID:** `I4.T2`
    * **Description:** Produce Mermaid timeline diagram illustrating undo/redo navigation across snapshots, operations, and event sequences, including redo-branch invalidation.
    * **Agent Type Hint:** `DiagrammingAgent`
    * **Inputs:** Task `I4.T1`, Decision 7, Section 2.1 artifact plan.
    * **Input Files:** [`packages/event_core/lib/src/operation_grouping.dart`, `docs/reference/undo_labels.md`]
    * **Target Files:** [`docs/diagrams/undo_timeline.mmd`]
    * **Deliverables:** Timeline showing events vs. operations, snapshot markers, user actions, and notes about performance targets.
    * **Acceptance Criteria:** Diagram renders via Mermaid CLI; includes anchors; referenced in README/manifest; clearly states redo clearing rules.
    * **Dependencies:** `I4.T1`.
    * **Parallelizable:** Yes.

<!-- anchor: task-i4-t3 -->
* **Task 4.3:**
    * **Task ID:** `I4.T3`
    * **Description:** Implement undo/redo navigator service integrating snapshots, operation grouping, and Provider notifications; expose keyboard bindings (Cmd/Ctrl+Z, Shift+Cmd/Ctrl+Z).
    * **Agent Type Hint:** `BackendAgent`
    * **Inputs:** Tasks `I4.T1`, `I2.T4`, `I2.T10`, `I3.T9`.
    * **Input Files:** [`packages/event_core/lib/src/replayer.dart`, `packages/event_core/lib/src/operation_grouping.dart`, `packages/app_shell/lib/src/state/document_provider.dart`]
    * **Target Files:** [`packages/event_core/lib/src/undo_navigator.dart`, `packages/app_shell/lib/src/state/undo_provider.dart`, `packages/event_core/test/undo_navigator_test.dart`]
    * **Deliverables:** Undo navigator with APIs for undo/redo/scrub, provider integration updating UI, tests covering navigation/resets.
    * **Acceptance Criteria:** Undo respects operation boundaries; redo invalidated on new events; tests cover multi-window state separation; logging includes operation names.
    * **Dependencies:** `I4.T1`, `I2.T4`.
    * **Parallelizable:** No.

<!-- anchor: task-i4-t4 -->
* **Task 4.4:**
    * **Task ID:** `I4.T4`
    * **Description:** Build history panel UI showing chronological operations with thumbnails, search/filter, and scrubber that replays at target 5k events/sec for preview.
    * **Agent Type Hint:** `FrontendAgent`
    * **Inputs:** Undo navigator, render pipeline, telemetry.
    * **Input Files:** [`packages/app_shell/lib/src/state/undo_provider.dart`, `packages/event_core/lib/src/undo_navigator.dart`, `packages/app_shell/lib/src/canvas/wiretuner_canvas.dart`]
    * **Target Files:** [`packages/app_shell/lib/src/ui/history_panel.dart`, `packages/app_shell/lib/src/ui/history_thumbnail_service.dart`, `packages/app_shell/test/widget/history_panel_test.dart`]
    * **Deliverables:** History panel widget, thumbnail generator (offscreen render), tests verifying scroll/search, and doc snippet.
    * **Acceptance Criteria:** Panel loads operations lazily; scrubbing updates canvas within budget; thumbnails cached; tests emulate search + navigation.
    * **Dependencies:** `I4.T3`, `I2.T6`.
    * **Parallelizable:** No.

<!-- anchor: task-i4-t5 -->
* **Task 4.5:**
    * **Task ID:** `I4.T5`
    * **Description:** Enhance direct manipulation flows (object dragging, anchor handles) with inertia options, magnetic grid snapping, and event batching to reduce noise while maintaining accuracy.
    * **Agent Type Hint:** `FrontendAgent`
    * **Inputs:** Tools from `I3`, operation grouping, metrics.
    * **Input Files:** [`packages/tool_framework/lib/src/tools/direct_selection_tool.dart`, `packages/event_core/lib/src/operation_grouping.dart`]
    * **Target Files:** [`packages/tool_framework/lib/src/tools/direct_selection_tool.dart`, `packages/tool_framework/lib/src/snapping/snapping_service.dart`, `packages/tool_framework/test/tools/direct_selection_snap_test.dart`]
    * **Deliverables:** Snapping service, updated tool logic, tests verifying accuracy + buffered events.
    * **Acceptance Criteria:** Snapping toggles respond instantly; operations aggregated elegantly; tests assert drift <1px; doc updates describe grid settings.
    * **Dependencies:** `I4.T1`, `I3.T4`.
    * **Parallelizable:** Yes (after dependencies).

<!-- anchor: task-i4-t6 -->
* **Task 4.6:**
    * **Task ID:** `I4.T6`
    * **Description:** Tune snapshot cadence (default 1000 events) via adaptive strategy (dense editing vs. idle) and surface instrumentation showing snapshot queue/backlog.
    * **Agent Type Hint:** `BackendAgent`
    * **Inputs:** Snapshot serializer, operation grouping metrics, Decision 1.
    * **Input Files:** [`packages/event_core/lib/src/snapshot_manager.dart`, `packages/event_core/lib/src/metrics.dart`]
    * **Target Files:** [`packages/event_core/lib/src/snapshot_manager.dart`, `packages/event_core/test/snapshot_manager_tuning_test.dart`, `docs/reference/snapshot_strategy.md`]
    * **Deliverables:** Adaptive snapshot logic, tests verifying thresholds, reference doc describing heuristics + overrides.
    * **Acceptance Criteria:** Snapshot creation stays under 100 ms; doc explains CLI/env overrides; instrumentation displays queue status in logs.
    * **Dependencies:** `I2.T4`, `I1.T8`.
    * **Parallelizable:** Yes.

<!-- anchor: task-i4-t7 -->
* **Task 4.7:**
    * **Task ID:** `I4.T7`
    * **Description:** Implement multi-window coordination: ensure each document window maintains isolated undo stacks, metrics, and logging context; add window manager tests.
    * **Agent Type Hint:** `BackendAgent`
    * **Inputs:** Decision 2, undo navigator, workspace shell.
    * **Input Files:** [`packages/app_shell/lib/src/window/window_manager.dart`, `packages/event_core/lib/src/undo_navigator.dart`]
    * **Target Files:** [`packages/app_shell/lib/src/window/window_manager.dart`, `packages/app_shell/test/unit/window_manager_test.dart`, `docs/reference/multi_window_notes.md`]
    * **Deliverables:** Window manager enhancements, tests verifying isolation, doc describing lifecycle + cleanup hooks.
    * **Acceptance Criteria:** Opening multiple windows duplicates state cleanly; closing window frees resources; doc references Decision 2; tests simulate 3 windows.
    * **Dependencies:** `I4.T3`.
    * **Parallelizable:** No.

<!-- anchor: task-i4-t8 -->
* **Task 4.8:**
    * **Task ID:** `I4.T8`
    * **Description:** Build timeline scrubber keyboard shortcuts + transport controls (play, pause, step forward/back) for history replay, aligning with Decision 1 performance targets.
    * **Agent Type Hint:** `FrontendAgent`
    * **Inputs:** History panel, undo navigator, event replayer.
    * **Input Files:** [`packages/app_shell/lib/src/ui/history_panel.dart`, `packages/event_core/lib/src/replayer.dart`]
    * **Target Files:** [`packages/app_shell/lib/src/ui/history_transport.dart`, `packages/app_shell/test/widget/history_transport_test.dart`]
    * **Deliverables:** Transport widget, keyboard mapping (J/K/L style), tests verifying playback rates + UI states.
    * **Acceptance Criteria:** Replay hits 5k events/sec target; UI disables controls appropriately; tests cover playback + stepping; user doc updated.
    * **Dependencies:** `I4.T4`.
    * **Parallelizable:** Yes (post history panel).

<!-- anchor: task-i4-t9 -->
* **Task 4.9:**
    * **Task ID:** `I4.T9`
    * **Description:** Add crash recovery validation: simulate crash mid-operation, relaunch app, ensure last snapshot + events restore state; document recovery steps for users.
    * **Agent Type Hint:** `QAAgent`
    * **Inputs:** Snapshot manager, undo navigator, CI benchmark harness.
    * **Input Files:** [`test/integration/event_to_canvas_test.dart`, `packages/event_core/lib/src/snapshot_manager.dart`, `docs/reference/snapshot_strategy.md`]
    * **Target Files:** [`test/integration/crash_recovery_test.dart`, `docs/qa/recovery_playbook.md`]
    * **Deliverables:** Integration test forcing abrupt termination, QA playbook describing manual validation, metrics summary.
    * **Acceptance Criteria:** Recovery test passes; playbook lists reproduction steps; metrics show <100 ms load time; doc references Decision 1.
    * **Dependencies:** `I4.T6`, `I4.T3`.
    * **Parallelizable:** No.

<!-- anchor: task-i4-t10 -->
* **Task 4.10:**
    * **Task ID:** `I4.T10`
    * **Description:** Implement history export/import stubs (JSON) for debugging: allow exporting subsections of event log and re-importing for reproduction, flagged as dev-only feature.
    * **Agent Type Hint:** `BackendAgent`
    * **Inputs:** Event schema, undo navigator, snapshot serializer.
    * **Input Files:** [`docs/reference/event_schema.md`, `packages/event_core/lib/src/undo_navigator.dart`, `packages/event_core/lib/src/snapshot_serializer.dart`]
    * **Target Files:** [`packages/event_core/lib/src/history_exporter.dart`, `packages/event_core/test/history_exporter_test.dart`, `docs/reference/history_debug.md`]
    * **Deliverables:** Export/import API, tests verifying schema compliance, doc describing dev workflow + warnings.
    * **Acceptance Criteria:** Exported JSON validated against schema; import rebuilds state; doc marks feature experimental; CLI command added to `justfile`.
    * **Dependencies:** `I4.T3`, `I2.T4`.
    * **Parallelizable:** Yes (after dependencies).

<!-- anchor: task-i4-t11 -->
* **Task 4.11:**
    * **Task ID:** `I4.T11`
    * **Description:** Update QA + documentation to include undo/redo usage, history panel instructions, troubleshooting tips for timeline playback, and parity verification steps.
    * **Agent Type Hint:** `DocumentationAgent`
    * **Inputs:** Tasks `I4.T1`–`I4.T10`, existing QA docs, Section 6 verification strategy.
    * **Input Files:** [`docs/qa/tooling_checklist.md`, `docs/qa/recovery_playbook.md`, `docs/diagrams/undo_timeline.mmd`]
    * **Target Files:** [`docs/qa/history_checklist.md`, `README.md`, `docs/reference/history_panel_usage.md`]
    * **Deliverables:** New checklist, README history section, reference doc with screenshots/anchors.
    * **Acceptance Criteria:** Documentation references all relevant anchors; QA checklist includes macOS/Windows shortcuts; Markdown lint passes; manifest updated.
    * **Dependencies:** `I4.T8`, `I4.T9`.
    * **Parallelizable:** No.
