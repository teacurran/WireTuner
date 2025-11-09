<!-- anchor: iteration-5-plan -->
### Iteration 5: Persistence, File Format, Import/Export, and Platform Parity

* **Iteration ID:** `I5`
* **Goal:** Finalize save/load flows with semantic versioning, implement SVG/PDF export and Tier-2 AI import, codify interoperability specs, and run platform parity QA culminating in release packaging.
* **Prerequisites:** `I1`–`I4` completed (event core, rendering, tools, undo/history) since persistence must serialize mature document states and import/export rely on vector engine features.
* **Iteration Success Indicators:** Save/load <100 ms on baseline doc, AI import coverage for Tier-2 features with explicit warnings, SVG/PDF outputs validated by external viewers, parity checklist passing for macOS/Windows.

<!-- anchor: task-i5-t1 -->
* **Task 5.1:**
    * **Task ID:** `I5.T1`
    * **Description:** Implement document save orchestrator writing snapshots + metadata into `.wiretuner` SQLite files, handling Save and Save As flows with blocking UI + progress indicators.
    * **Agent Type Hint:** `BackendAgent`
    * **Inputs:** Snapshot serializer, event store, operation grouping for dirty state.
    * **Input Files:** [`packages/event_core/lib/src/snapshot_manager.dart`, `packages/io_services/lib/src/sqlite_gateway.dart`, `packages/app_shell/lib/src/ui/menu_actions.dart`]
    * **Target Files:** [`packages/io_services/lib/src/save_service.dart`, `packages/app_shell/lib/src/ui/save_dialogs.dart`, `packages/io_services/test/save_service_test.dart`]
    * **Deliverables:** Save service with blocking dialogs, dirty-state tracking, unit tests for success/failure (disk full) scenarios.
    * **Acceptance Criteria:** Save completes <100 ms for baseline doc; errors display actionable dialog; tests simulate failure + success; logging captures file path + version.
    * **Dependencies:** `I2.T4`, `I4.T6`.
    * **Parallelizable:** No.

<!-- anchor: task-i5-t2 -->
* **Task 5.2:**
    * **Task ID:** `I5.T2`
    * **Description:** Author `api/file_format_spec.md` describing `.wiretuner` semantic versioning, schema, backward-compatible downgrade flows, and compatibility matrix per Decision 4.
    * **Agent Type Hint:** `DocumentationAgent`
    * **Inputs:** Tasks `I5.T1`, `I2.T4`, Decision 4 table.
    * **Input Files:** [`docs/reference/file_versioning_notes.md`, `docs/diagrams/data_snapshot_erd.mmd`]
    * **Target Files:** [`api/file_format_spec.md`]
    * **Deliverables:** Markdown spec with header structure, field definitions, migration steps, degrade warnings, JSON header example.
    * **Acceptance Criteria:** Document references compatibility matrix, includes Save As degrade workflow, ties to QA plan; markdown lint passes; manifest entry added.
    * **Dependencies:** `I5.T1`.
    * **Parallelizable:** Yes.

<!-- anchor: task-i5-t3 -->
* **Task 5.3:**
    * **Task ID:** `I5.T3`
    * **Description:** Implement load service reading `.wiretuner` files, verifying version compatibility, running migrations, and populating UI (recent files, error dialogs) with degrade warnings.
    * **Agent Type Hint:** `BackendAgent`
    * **Inputs:** Save service, file spec, undo navigator.
    * **Input Files:** [`packages/io_services/lib/src/save_service.dart`, `api/file_format_spec.md`, `packages/event_core/lib/src/undo_navigator.dart`]
    * **Target Files:** [`packages/io_services/lib/src/load_service.dart`, `packages/app_shell/lib/src/ui/open_dialogs.dart`, `packages/io_services/test/load_service_test.dart`, `test/integration/save_load_roundtrip_test.dart`]
    * **Deliverables:** Load service + dialogs, integration test verifying round-trip, degrade warning UI.
    * **Acceptance Criteria:** Load rejects unsupported versions gracefully; integration test uses fixture; warnings show when downgrading features; telemetry logs file versions.
    * **Dependencies:** `I5.T1`, `I5.T2`.
    * **Parallelizable:** No.

<!-- anchor: task-i5-t4 -->
* **Task 5.4:**
    * **Task ID:** `I5.T4`
    * **Description:** Generate AI import feature matrix (Tier-2) documenting supported constructs, partial support, warnings; build parser leveraging PDF structure to extract paths/shapes.
    * **Agent Type Hint:** `BackendAgent`
    * **Inputs:** Decision 5, vector engine, event schema, file format spec.
    * **Input Files:** [`docs/reference/vector_model.md`, `docs/reference/event_schema.md`, `api/file_format_spec.md`]
    * **Target Files:** [`docs/reference/ai_import_matrix.md`, `packages/io_services/lib/src/importers/ai_importer.dart`, `packages/io_services/test/importers/ai_importer_test.dart`]
    * **Deliverables:** Matrix doc, importer converting Tier-2 constructs to events, tests with sample AI fixtures + warning logs.
    * **Acceptance Criteria:** Matrix lists Tier-1/Tier-2 coverage; importer warns on unsupported Tier-3 features; tests verify gradient/stroke conversions; doc cross-links to Decision 5.
    * **Dependencies:** `I2.T3`, `I5.T2`.
    * **Parallelizable:** No.

<!-- anchor: task-i5-t5 -->
* **Task 5.5:**
    * **Task ID:** `I5.T5`
    * **Description:** Implement SVG export (Tier-2) supporting paths, shapes, gradients, clipping masks, compound paths, and metadata; ensure exported files pass W3C validator.
    * **Agent Type Hint:** `BackendAgent`
    * **Inputs:** Vector engine, render pipeline, file spec.
    * **Input Files:** [`packages/vector_engine/lib/src/geometry/path.dart`, `docs/reference/vector_model.md`, `api/file_format_spec.md`]
    * **Target Files:** [`packages/io_services/lib/src/exporters/svg_exporter.dart`, `packages/io_services/test/exporters/svg_exporter_test.dart`, `test/integration/svg_export_test.dart`]
    * **Deliverables:** SVG exporter, unit tests verifying DOM output, integration test comparing against golden file opened via CLI validator.
    * **Acceptance Criteria:** Exporter handles gradients/clipping; tests assert XML equality; validator CLI returns success; doc snippet explains known limitations.
    * **Dependencies:** `I2.T6`, `I5.T2`.
    * **Parallelizable:** Yes (after dependencies).

<!-- anchor: task-i5-t6 -->
* **Task 5.6:**
    * **Task ID:** `I5.T6`
    * **Description:** Implement PDF export leveraging `pdf` package, mapping vector objects to PDF operators, embedding fonts for text-as-path, and verifying output via external viewer tests.
    * **Agent Type Hint:** `BackendAgent`
    * **Inputs:** SVG exporter (for parity), vector engine, performance metrics.
    * **Input Files:** [`packages/io_services/lib/src/exporters/svg_exporter.dart`, `packages/vector_engine/lib/src/geometry/path.dart`]
    * **Target Files:** [`packages/io_services/lib/src/exporters/pdf_exporter.dart`, `packages/io_services/test/exporters/pdf_exporter_test.dart`, `test/integration/pdf_export_test.dart`]
    * **Deliverables:** PDF exporter, tests verifying page size/objects, integration test opening file via `pdfinfo` or similar CLI.
    * **Acceptance Criteria:** PDF opens in Preview/Acrobat without warnings; tests ensure gradients/fills map correctly; documentation lists color management assumptions.
    * **Dependencies:** `I5.T5`.
    * **Parallelizable:** No.

<!-- anchor: task-i5-t7 -->
* **Task 5.7:**
    * **Task ID:** `I5.T7`
    * **Description:** Implement SVG import (Tier-1/Tier-2) to complement AI import, focusing on path, gradient, clipping, and text-as-path conversion with warning logs for unsupported elements.
    * **Agent Type Hint:** `BackendAgent`
    * **Inputs:** SVG exporter knowledge, event schema, vector model.
    * **Input Files:** [`packages/io_services/lib/src/exporters/svg_exporter.dart`, `docs/reference/event_schema.md`, `docs/reference/vector_model.md`]
    * **Target Files:** [`packages/io_services/lib/src/importers/svg_importer.dart`, `packages/io_services/test/importers/svg_importer_test.dart`, `docs/reference/svg_import_notes.md`]
    * **Deliverables:** Importer with DOM parser, tests using sample files, doc describing supported tags/attributes.
    * **Acceptance Criteria:** Imports Round-trip sample doc (export then import) without diff; warnings issued for filters/blend modes; doc lists fallback behaviors.
    * **Dependencies:** `I5.T5`.
    * **Parallelizable:** Yes (post dependencies).

<!-- anchor: task-i5-t8 -->
* **Task 5.8:**
    * **Task ID:** `I5.T8`
    * **Description:** Build platform parity QA checklist + automation (where possible) ensuring keyboard shortcuts, window chrome, file dialogs, and exporters behave identically on macOS/Windows.
    * **Agent Type Hint:** `QAAgent`
    * **Inputs:** Decisions 2 & 6, tasks `I5.T1`–`I5.T7`.
    * **Input Files:** [`docs/qa/platform_parity_checklist.md`, `docs/qa/tooling_checklist.md`, `docs/reference/history_panel_usage.md`]
    * **Target Files:** [`docs/qa/platform_parity_checklist.md`, `test/integration/platform_parity_test.dart`]
    * **Deliverables:** Updated checklist, automated smoke test verifying shortcuts + exports per platform (guarded by tags), report template for manual QA.
    * **Acceptance Criteria:** Checklist covers menus, shortcuts, file pickers; automation verifies parity-critical flows; doc includes sign-off template; manifest updated.
    * **Dependencies:** `I5.T1`–`I5.T7`.
    * **Parallelizable:** No.

<!-- anchor: task-i5-t9 -->
* **Task 5.9:**
    * **Task ID:** `I5.T9`
    * **Description:** Prepare release packaging scripts (macOS notarized DMG, Windows signed installer), update CI pipelines to build artifacts, and document release checklist.
    * **Agent Type Hint:** `DevOpsAgent`
    * **Inputs:** Section 2 deployment plan, CI from `I1.T7`, parity checklist.
    * **Input Files:** [`scripts/ci/run_checks.sh`, `.github/workflows/ci.yml`, `docs/qa/platform_parity_checklist.md`]
    * **Target Files:** [`scripts/ci/build_macos_release.sh`, `scripts/ci/build_windows_release.ps1`, `.github/workflows/release.yml`, `docs/qa/release_checklist.md`]
    * **Deliverables:** Build scripts, release workflow (manual trigger), checklist describing signing/notarization steps.
    * **Acceptance Criteria:** Scripts produce DMG/EXE locally; release workflow uploads artifacts; checklist includes hash verification + gate approvals.
    * **Dependencies:** `I5.T8`.
    * **Parallelizable:** Yes (with caution once parity ready).

<!-- anchor: task-i5-t10 -->
* **Task 5.10:**
    * **Task ID:** `I5.T10`
    * **Description:** Conduct end-to-end regression suite (unit, widget, integration, benchmarks, QA checklists) and create final report summarizing readiness, risks, and follow-up work.
    * **Agent Type Hint:** `QAAgent`
    * **Inputs:** All prior tasks, verification strategy (Section 6), manifest for referencing artifacts.
    * **Input Files:** [`scripts/ci/run_checks.sh`, `docs/qa/platform_parity_checklist.md`, `docs/reference/rendering_troubleshooting.md`]
    * **Target Files:** [`docs/qa/final_report.md`, `docs/qa/test_matrix.csv`]
    * **Deliverables:** Final QA report with pass/fail matrix, backlog of post-v0.1 items, attachments referencing logs/artifacts.
    * **Acceptance Criteria:** Report includes summary, risks, metrics; CSV lists each test suite; document cross-links to plan anchors; stakeholder sign-off recorded.
    * **Dependencies:** `I5.T1`–`I5.T9`.
    * **Parallelizable:** No.

<!-- anchor: task-i5-t11 -->
* **Task 5.11:**
    * **Task ID:** `I5.T11`
    * **Description:** Update README + marketing snippet with feature list (pen, shapes, undo, import/export), include download/install instructions, and link to release artifacts.
    * **Agent Type Hint:** `DocumentationAgent`
    * **Inputs:** Final QA report, release scripts, architecture docs.
    * **Input Files:** [`README.md`, `docs/qa/final_report.md`, `.github/workflows/release.yml`]
    * **Target Files:** [`README.md`, `docs/reference/release_notes.md`]
    * **Deliverables:** Updated README, release notes summarizing highlights/known issues, references to file format spec + troubleshooting docs.
    * **Acceptance Criteria:** README badges updated; release notes mention compatibility matrix + Tier-2 import limitations; Markdown lint passes; manifest updated.
    * **Dependencies:** `I5.T9`, `I5.T10`.
    * **Parallelizable:** No.
