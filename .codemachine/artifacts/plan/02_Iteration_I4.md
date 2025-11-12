<!-- anchor: iteration-4-plan -->
### Iteration 4: Multi-Artboard, Navigator Lifecycle & Collaboration Hooks
* **Iteration ID:** `I4`
* **Goal:** Finalize multi-artboard persistence, navigator tabs, per-artboard state isolation, window lifecycle, collaboration gateway MVP, and history replay UI.
* **Prerequisites:** `I1`, `I2`, `I3`
* **Tasks:**
    <!-- anchor: task-i4-t1 -->
    * **Task 4.1:**
        * **Task ID:** `I4.T1`
        * **Description:** Extend domain + persistence layers for multi-artboard (list of artboards, per-artboard layers, viewport/selection state) with migrations and version bump to v2.0.0.
        * **Agent Type Hint:** `DatabaseAgent`
        * **Inputs:** FR-029–FR-045, ADR-005.
        * **Input Files**: [`packages/core/lib/models/`, `packages/infrastructure/lib/event_store/`, `docs/reference/event_catalog.md`]
        * **Target Files:** [`packages/core/lib/models/artboard.dart`, `packages/core/lib/models/document.dart`, `packages/infrastructure/lib/event_store/migrations/v2_0_0.dart`, `docs/reference/event_catalog.md`, `docs/adr/ADR-0005-multi-artboard.md`]
        * **Deliverables:** Updated models, migration scripts, ADR, tests covering serialization & replay.
        * **Acceptance Criteria:** Migration converts single artboard docs; events carry artboardId; snapshots validated; version constant bumped.
        * **Dependencies:** `I3.T1`, `I3.T3`.
        * **Parallelizable:** No.
    <!-- anchor: task-i4-t2 -->
    * **Task 4.2:**
        * **Task ID:** `I4.T2`
        * **Description:** Implement navigator thumbnail pipeline (auto-refresh, save-triggered refresh, manual refresh action) with background worker + caching.
        * **Agent Type Hint:** `FrontendAgent`
        * **Inputs:** FR-039, Section 7.5.
        * **Input Files**: [`packages/app/lib/modules/navigator/thumbnail_service.dart`, `packages/core/lib/thumbnail/`]
        * **Target Files:** [`packages/app/lib/modules/navigator/thumbnail_service.dart`, `packages/core/lib/thumbnail/thumbnail_worker.dart`, `packages/app/test/thumbnail_service_test.dart`]
        * **Deliverables:** Thumbnail worker, caching policy, tests ensuring idle/refresh triggers.
        * **Acceptance Criteria:** Updates after 10s idle or save; manual refresh command; caches per artboard; telemetry emits `thumbnail.refresh.age`.
        * **Dependencies:** `I4.T1`.
        * **Parallelizable:** Yes.
    <!-- anchor: task-i4-t3 -->
    * **Task 4.3:**
        * **Task ID:** `I4.T3`
        * **Description:** Deliver full history replay UI + ReplayService checkpoint cache, including scrubber, playback controls, speed adjustments, and preview rendering.
        * **Agent Type Hint:** `FrontendAgent`
        * **Inputs:** ADR-006, Flow J, FR-027.
        * **Input Files**: [`packages/app/lib/modules/history/`, `packages/core/lib/replay/`]
        * **Target Files:** [`packages/core/lib/replay/replay_service.dart`, `packages/app/lib/modules/history/history_window.dart`, `packages/app/lib/modules/history/timeline_widget.dart`, `packages/core/test/replay_service_test.dart`]
        * **Deliverables:** Checkpoint cache, timeline UI, playback logic, tests for seek latency.
        * **Acceptance Criteria:** Checkpoints every 1k events; <50 ms seek target; UI supports 0.5×–10× speeds; telemetry instrumentation added.
        * **Dependencies:** `I2.T3`, `I3.T1`.
        * **Parallelizable:** No.
    <!-- anchor: task-i4-t4 -->
    * **Task 4.4:**
        * **Task ID:** `I4.T4`
        * **Description:** Implement collaboration gateway MVP (Dart Frog) with WebSocket OT channel, GraphQL presence subscription fallback, Redis pub/sub integration, and client CollaborationClient.
        * **Agent Type Hint:** `BackendAgent`
        * **Inputs:** ADR-002, Section 7.9.
        * **Input Files**: [`server/collaboration-gateway/`, `packages/infrastructure/lib/collaboration/`]
        * **Target Files:** [`server/collaboration-gateway/lib/main.dart`, `server/collaboration-gateway/lib/ot/transformers.dart`, `packages/infrastructure/lib/collaboration/collaboration_client.dart`, `server/collaboration-gateway/test/ot_transform_test.dart`]
        * **Deliverables:** WebSocket server, OT transformer library, client integration.
        * **Acceptance Criteria:** Handles ≥10 concurrent editors; OT tests cover anchor/object operations; presence updates propagate; security enforced (JWT validation).
        * **Dependencies:** `I2.T2`, `I3.T1`.
        * **Parallelizable:** No.
    <!-- anchor: task-i4-t5 -->
    * **Task 4.5:**
        * **Task ID:** `I4.T5`
        * **Description:** Build collaboration UI (presence panel, live cursors, conflict banners) with accessibility cues, latency indicators, and offline fallback messaging.
        * **Agent Type Hint:** `FrontendAgent`
        * **Inputs:** Section 6 (presence components), Flow I.
        * **Input Files**: [`packages/app/lib/modules/collaboration/`]
        * **Target Files:** [`packages/app/lib/modules/collaboration/presence_panel.dart`, `packages/app/lib/modules/collaboration/cursor_overlay.dart`, `packages/app/lib/modules/collaboration/conflict_banner.dart`, `packages/app/test/collaboration/*`]
        * **Deliverables:** UI modules, hooking into CollaborationClient events, tests for offline fallback.
        * **Acceptance Criteria:** Presence panel updates in <500 ms; cursors respect color palette; conflict banner actions wired.
        * **Dependencies:** `I4.T4`.
        * **Parallelizable:** No.
    <!-- anchor: task-i4-t6 -->
    * **Task 4.6:**
        * **Task ID:** `I4.T6`
        * **Description:** Implement window lifecycle manager (Navigator root, artboard windows, close prompts, per-window state persistence) and update platform integrations (QuickLook/Explorer hooks).
        * **Agent Type Hint:** `FrontendAgent`
        * **Inputs:** Journey 10–18, FR-040, FR-047, FR-048.
        * **Input Files**: [`packages/app/lib/app_shell/`, `tools/platform/quicklook/`, `tools/platform/explorer/`]
        * **Target Files:** [`packages/app/lib/app_shell/window_manager.dart`, `packages/app/lib/app_shell/navigator_root.dart`, `tools/platform/quicklook/PreviewProvider.swift`, `tools/platform/explorer/preview_handler.cpp`, `packages/app/test/window_manager_test.dart`]
        * **Deliverables:** Window manager, prompts, platform thumbnail generators.
        * **Acceptance Criteria:** Closing Navigator prompts to close document; artboard windows reopen with viewport state; macOS QuickLook & Windows Explorer show thumbnails; tests simulate lifecycle events.
        * **Dependencies:** `I3.T2`, `I3.T3`.
        * **Parallelizable:** Yes.
