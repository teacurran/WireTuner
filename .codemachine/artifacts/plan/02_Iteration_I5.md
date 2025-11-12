<!-- anchor: iteration-5-plan -->
### Iteration 5: Import/Export, Verification & Release Readiness
* **Iteration ID:** `I5`
* **Goal:** Complete SVG/PDF/AI import-export pipelines, finalize verification strategy, quality gates, release documentation, and ops automation.
* **Prerequisites:** `I1`–`I4`
* **Tasks:**
    <!-- anchor: task-i5-t1 -->
    * **Task 5.1:**
        * **Task ID:** `I5.T1`
        * **Description:** Implement SVG export (paths, shapes, metadata, per-artboard scope) + JSON archival export with round-trip tests.
        * **Agent Type Hint:** `FrontendAgent`
        * **Inputs:** FR-019, FR-049, Section 7.10.
        * **Input Files**: [`packages/infrastructure/lib/export/`, `packages/app/lib/modules/export/`]
        * **Target Files:** [`packages/infrastructure/lib/export/svg_exporter.dart`, `packages/infrastructure/lib/export/json_exporter.dart`, `packages/app/lib/modules/export/export_dialog.dart`, `packages/infrastructure/test/export/svg_exporter_test.dart`]
        * **Deliverables:** Export services, UI dialog updates, tests comparing Illustrator round-trip.
        * **Acceptance Criteria:** SVG validates vs W3C; JSON export imports back; export dialog shows compatibility warnings.
        * **Dependencies:** `I3.T3`, `I3.T5`.
        * **Parallelizable:** Yes.
    <!-- anchor: task-i5-t2 -->
    * **Task 5.2:**
        * **Task ID:** `I5.T2`
        * **Description:** Integrate PDF export pipeline via resvg worker, queue-based job management, telemetry, and failure handling UI.
        * **Agent Type Hint:** `BackendAgent`
        * **Inputs:** FR-020, Section 7.6.
        * **Input Files**: [`server/worker-export/`, `packages/infrastructure/lib/export/pdf_exporter.dart`]
        * **Target Files:** [`server/worker-export/lib/main.rs` (or Dart/Rust bridge), `packages/infrastructure/lib/export/pdf_exporter.dart`, `packages/app/lib/modules/export/pdf_status_panel.dart`, `server/worker-export/test/pdf_export_test.rs`]
        * **Deliverables:** Worker service, client queue integration, UI status panel.
        * **Acceptance Criteria:** Export completes with vector fidelity; retries on failures; telemetry logs failure reasons; UI shows progress.
        * **Dependencies:** `I5.T1`.
        * **Parallelizable:** No.
    <!-- anchor: task-i5-t3 -->
    * **Task 5.3:**
        * **Task ID:** `I5.T3`
        * **Description:** Build AI (PDF-compatible) import pipeline with compatibility report, warnings, and FR-021 Tier 1/Tier 2 coverage.
        * **Agent Type Hint:** `BackendAgent`
        * **Inputs:** ADR-005, FR-021.
        * **Input Files**: [`packages/infrastructure/lib/import/ai_importer.dart`, `docs/reference/import_warning_catalog.md`]
        * **Target Files:** [`packages/infrastructure/lib/import/ai_importer.dart`, `packages/app/lib/modules/import/import_dialog.dart`, `packages/infrastructure/test/import/ai_importer_test.dart`, `docs/reference/import_warning_catalog.md`]
        * **Deliverables:** Importer, warning catalog, UI integration, regression tests covering sample corpus.
        * **Acceptance Criteria:** Imports Tier 1/Tier 2 features; warns on unsupported; tests run across sample files; docs detail limitations.
        * **Dependencies:** `I3.T3`.
        * **Parallelizable:** Yes.
    <!-- anchor: task-i5-t4 -->
    * **Task 5.4:**
        * **Task ID:** `I5.T4`
        * **Description:** Produce verification & validation strategy (unit/integration/E2E, performance benchmarks, regression suites) and populate traceability matrix.
        * **Agent Type Hint:** `QAAgent`
        * **Inputs:** Section 6 Verification Strategy requirement, QA appendix.
        * **Input Files**: [`docs/qa/verification_matrix.md`, `docs/qa/perf_benchmarks.md`]
        * **Target Files:** [`docs/qa/verification_matrix.md`, `docs/qa/perf_benchmarks.md`, `test/integration/README.md`]
        * **Deliverables:** Updated matrix mapping FR/NFR → tests, benchmark plan, doc describing automated test orchestration.
        * **Acceptance Criteria:** Every FR/NFR mapped; CI includes benchmark stage; doc cross-links to telemetry; sign-off by QA lead.
        * **Dependencies:** `I1.T6`, `I3.T6`.
        * **Parallelizable:** Yes.
    <!-- anchor: task-i5-t5 -->
    * **Task 5.5:**
        * **Task ID:** `I5.T5`
        * **Description:** Finalize release ops: installer pipelines, feature flag rollout plan, runbooks, incident templates, status page automation.
        * **Agent Type Hint:** `DevOpsAgent`
        * **Inputs:** Section 3 (Operational), Section 4 directives.
        * **Input Files**: [`scripts/ops/`, `tools/installer/`, `docs/ops/runbooks/`]
        * **Target Files:** [`scripts/ops/release_pipeline.sh`, `tools/installer/macos/build_dmg.sh`, `tools/installer/windows/build_msi.ps1`, `docs/ops/runbooks/release_checklist.md`, `docs/ops/runbooks/incident_template.md`]
        * **Deliverables:** Automated release scripts, notarization/signing instructions, runbooks, status page integration script.
        * **Acceptance Criteria:** Dry run produces signed DMG/MSI; runbooks reviewed; feature flag rollout steps documented; status page updates automated.
        * **Dependencies:** `I1.T6`, `I4.T6`.
        * **Parallelizable:** No.
    <!-- anchor: task-i5-t6 -->
    * **Task 5.6:**
        * **Task ID:** `I5.T6`
        * **Description:** Conduct end-to-end validation (multi-artboard editing, collaboration, import/export) and compile release readiness report summarizing KPIs, risks, mitigations.
        * **Agent Type Hint:** `QAAgent`
        * **Inputs:** Outputs from Tasks 5.1–5.5, verification matrix.
        * **Input Files**: [`docs/qa/release_report.md`, `docs/qa/test_results/`]
        * **Target Files:** [`docs/qa/release_report.md`, `docs/qa/test_results/iteration5_summary.md`]
        * **Deliverables:** Report capturing test evidence, KPI metrics, open issues, sign-offs.
        * **Acceptance Criteria:** All KPIs meet thresholds; open risks logged with owners; leadership sign-off recorded.
        * **Dependencies:** `I5.T1`, `I5.T2`, `I5.T3`, `I5.T4`, `I5.T5`.
        * **Parallelizable:** No.
