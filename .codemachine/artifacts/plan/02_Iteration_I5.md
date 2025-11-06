<!-- anchor: iteration-5-plan -->
### Iteration 5: Persistence, Save/Load, Import/Export

*   **Iteration ID:** `I5`
*   **Goal:** Finalize persistence workflows (save/load/versioning), build export (SVG/PDF) and import (AI/SVG) services, and capture the supporting activity diagram plus regression tests to close Milestone 0.1.
*   **Prerequisites:** `I1`, `I2`, `I3`, `I4`
*   **Tasks:**

<!-- anchor: task-i5-t1 -->
*   **Task 5.1:**
    *   **Task ID:** `I5.T1`
    *   **Description:** Implement Save Document pipeline (T033) tying UI commands to EventStore/SnapshotManager, ensuring atomic writes, backups, and telemetry.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:** Save/Load spec, event store, snapshot serializer.
    *   **Input Files:** ["lib/src/services/file_ops/save_service.dart", "lib/src/event_sourcing/persistence/", "test/integration/save_flow_test.dart"]
    *   **Target Files:** ["lib/src/services/file_ops/save_service.dart", "lib/src/services/file_ops/file_picker_adapter.dart", "integration_test/save_flow_test.dart"]
    *   **Deliverables:** Save service with dependency injection, UI command wiring, integration test covering save + reopen scenario.
    *   **Acceptance Criteria:**
        - Save writes metadata/events/snapshots within single WAL-backed transaction; temp file rename ensures atomicity.
        - Telemetry logs file size, event count, snapshot ratio.
        - Integration test verifies reopened document equals pre-save snapshot hash.
    *   **Dependencies:** `I4.T3`, `I1.T7`
    *   **Parallelizable:** No

<!-- anchor: task-i5-t2 -->
*   **Task 5.2:**
    *   **Task ID:** `I5.T2`
    *   **Description:** Implement Load Document + version negotiation (T034/T035) and author File Ops Activity Diagram (Mermaid) covering save/load/export/import flows.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:** Save service, event navigator, persistence contract.
    *   **Input Files:** ["lib/src/services/file_ops/load_service.dart", "docs/diagrams/file_ops_activity.mmd", "test/integration/load_flow_test.dart"]
    *   **Target Files:** ["lib/src/services/file_ops/load_service.dart", "lib/src/services/file_ops/version_migrator.dart", "docs/diagrams/file_ops_activity.mmd", "integration_test/load_upgrade_test.dart"]
    *   **Deliverables:** Load service that selects latest snapshot, replays deltas, runs migrations for older format versions, plus Mermaid activity diagram.
    *   **Acceptance Criteria:**
        - Load handles corrupt events gracefully (skips + warns) and surfaces UI alert.
        - Version migrator upgrades ≤ previous format version tests (fixtures) and writes upgrade notes to telemetry.
        - Diagram illustrates branching for save, load, export, import with error nodes; passes Mermaid CLI validation.
    *   **Dependencies:** `I5.T1`
    *   **Parallelizable:** No

<!-- anchor: task-i5-t3 -->
*   **Task 5.3:**
    *   **Task ID:** `I5.T3`
    *   **Description:** Build SVG export service (T036) translating Document to SVG 1.1, including metadata, transforms, styles, and test harness comparing golden SVG output.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:** Rendering pipeline, document model, persistence contract.
    *   **Input Files:** ["lib/src/services/export/svg_exporter.dart", "test/unit/svg_exporter_test.dart", "docs/specs/export_import.md"]
    *   **Target Files:** ["lib/src/services/export/svg_exporter.dart", "lib/src/services/export/svg_writer.dart", "test/unit/svg_exporter_test.dart"]
    *   **Deliverables:** Export service + writer utilities, tests verifying path/shape serialization, style mapping, and transform preservation.
    *   **Acceptance Criteria:**
        - Supports groups, layers, selection markers removed; output passes `svglint`.
        - Handles >5k objects within 5 s for benchmark doc.
        - Documented limitations (filters, gradients) noted in export spec.
    *   **Dependencies:** `I2.T6`, `I4.T5`
    *   **Parallelizable:** Yes

<!-- anchor: task-i5-t4 -->
*   **Task 5.4:**
    *   **Task ID:** `I5.T4`
    *   **Description:** Implement PDF export (T037) leveraging `pdf` package, ensuring vector fidelity, page sizing, and metadata insertion.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:** SVG exporter, document model.
    *   **Input Files:** ["lib/src/services/export/pdf_exporter.dart", "test/unit/pdf_exporter_test.dart"]
    *   **Target Files:** ["lib/src/services/export/pdf_exporter.dart", "test/unit/pdf_exporter_test.dart"]
    *   **Deliverables:** PDF exporter with artboard/page selection, CMYK color conversion helper, tests verifying Bezier accuracy via path length comparison.
    *   **Acceptance Criteria:**
        - Exported PDF opens in Preview/Adobe without rasterization; vector selectors confirm path presence.
        - Color profiles embedded; metadata includes document title/version.
        - Exports complete with <10 s for benchmark doc.
    *   **Dependencies:** `I5.T3`
    *   **Parallelizable:** No

<!-- anchor: task-i5-t5 -->
*   **Task 5.5:**
    *   **Task ID:** `I5.T5`
    *   **Description:** Implement AI import pipeline (T038) focusing on PDF-based AI files plus SVG import (T039), sharing a common parser abstraction and validation harness.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:** Event schema, document model, persistence contract.
    *   **Input Files:** ["lib/src/services/import/", "test/integration/import_flow_test.dart", "docs/specs/import_compatibility.md"]
    *   **Target Files:** ["lib/src/services/import/ai_importer.dart", "lib/src/services/import/svg_importer.dart", "lib/src/services/import/import_validator.dart", "integration_test/import_roundtrip_test.dart", "docs/specs/import_compatibility.md"]
    *   **Deliverables:** Import services for AI (PDF parser) and SVG (XML parser) that convert inputs into event streams, plus documentation outlining supported features/limitations.
    *   **Acceptance Criteria:**
        - Imports basic shapes, paths, groups, transforms; unsupported features logged but do not crash.
        - Round-trip golden test: import AI/SVG → render → export SVG matches baseline within tolerance.
        - Security constraints (max file size, disabled external entities) enforced.
    *   **Dependencies:** `I5.T2`, `I5.T3`
    *   **Parallelizable:** No
