<!-- anchor: verification-and-integration-strategy -->
## 6. Verification and Integration Strategy

*   **Testing Levels:**
    - `Unit` – Mandatory for every new service/model; aim ≥80 % coverage on event core, geometry, tool logic; focus on deterministic replay, sampler throttling, serialization.
    - `Widget` – Canvas, overlays, and tool interactions require golden/regression tests; simulate pointer/keyboard gestures via `WidgetTester`, ensuring selection visuals and viewport transforms behave cross-platform.
    - `Integration` – Save/load/import/export flows validated via `integration_test/` with fixture documents; CI runs headless desktop builds to confirm persistence, version migrations, and export fidelity.
    - `Performance` – Profiling scripts (`tools/scripts/profile_rendering.dart`) capture FPS, replay latency, and event sampling efficiency each iteration; regressions beyond ±10 % block merges.
*   **CI/CD Expectations:**
    - GitHub Actions pipeline: lint (`flutter analyze`), unit/widget tests (`flutter test --coverage`), integration suite (desktop headless), diagram/spec validation (PlantUML render, Mermaid CLI, `openapi-cli lint`, JSON Schema lint), and artifact publishing (coverage badge, plan manifest updates).
    - Matrix builds for macOS + Windows release branches ensure platform parity; nightly scheduled job runs heavy performance/import/export suites.
*   **Code Quality Gates:**
    - Analyzer + custom lints (no mutable public fields, forbid `print`, enforce const constructors) must pass; failing lint blocks merge.
    - Coverage threshold: ≥80 % overall, ≥90 % for `lib/src/event_sourcing/**/*`; enforced via coverage report parsing script failing pipeline if unmet.
    - Static analysis for SQL migrations (sqlfluff) and JSON Schema compatibility; PRs lacking updated specs rejected.
    - Manual self-review checklist (in PR template) ensures adherence to sampling, snapshot, undo/redo guidelines before approval.
*   **Artifact Validation:**
    - Diagrams rendered headlessly via PlantUML/Mermaid Docker image; CI ensures `.puml/.mmd` free of syntax errors.
    - OpenAPI + JSON Schema validated using CLI linters; schema diff step highlights breaking changes.
    - Export/import outputs compared against golden fixtures (SVG diff, PDF vector check) using automated scripts plus manual spot verification when schema changes occur.
    - Manifest sync check ensures every anchor referenced in `plan_manifest.json`, preventing orphaned sections for downstream agents.

<!-- anchor: glossary -->
## 7. Glossary

*   **Event Sampler:** Throttling utility that aggregates high-frequency pointer deltas into 50 ms snapshots before persistence.
*   **Snapshot Manager:** Service that serializes Document state every N events (default 1,000) to accelerate replay and recovery.
*   **Tool Manager:** Framework component coordinating active tool lifecycle, cursor updates, and input routing.
*   **Viewport Controller:** Abstraction managing pan/zoom transforms, coordinate conversions, and inertial scrolling.
*   **Selection Overlay:** Canvas overlay that visualizes selected objects, anchors, and BCP handles with interaction affordances.
*   **BCP (Bezier Control Point):** Handle attached to an anchor that defines tangent direction/magnitude for Bezier curves.
*   **Document Aggregate:** Immutable root object containing layers, objects, selection state, and viewport metadata used during replay and rendering.
*   **File Ops Activity Diagram:** Mermaid artifact illustrating branching logic for save, load, export, and import workflows under success/error scenarios.
*   **Version Migrator:** Service transforming persisted data from older `.wiretuner` schema versions to the current model before replay.
*   **Telemetry Hooks:** Logging/metrics instrumentation capturing FPS, replay latency, event backlog, and file size data for diagnostics.
