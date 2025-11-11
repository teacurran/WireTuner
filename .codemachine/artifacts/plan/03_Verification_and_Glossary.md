<!-- anchor: verification-and-integration-strategy -->
## 6. Verification and Integration Strategy

* **Testing Levels:**
  - *Unit:* Geometry, event-core, tool logic, import/export helpers; mandated by Tasks `I2.T3`, `I3.T3`–`I3.T7`, `I5.T4`–`I5.T7`. Coverage target ≥80% for core libraries; enforce via CI gate.
  - *Widget:* Canvas, overlays, history panel, selection/pen interactions; executed in Iterations 2–4 with golden/perf assertions to keep 60 FPS targets honest.
  - *Integration:* Event→canvas replay (`I2.T10`), pen/selection flows (`I3.T10`), save/load round-trips (`I5.T3`), crash recovery (`I4.T9`), platform parity (`I5.T8`). Run nightly and before releases.
  - *Benchmarks:* Render pipeline stress tests (`I2.T9`) and replay throughput stats (I4) feed into performance gating; results stored as artifacts.
  - *Manual QA:* Tooling + parity checklists (`I3.T10`, `I5.T8`) plus history/recovery playbooks ensure UX validation beyond automation.

* **CI/CD:**
  - GitHub Actions workflows triggered on PR/push (lint/tests/diagram validation) and manual release workflow (macOS DMG, Windows EXE) defined in `I1.T7` + `I5.T9`.
  - Matrix runs cover macOS + Windows; Linux optional for headless tests. Failing jobs block merges.
  - Benchmarks + optional integration suites triggered via workflow dispatch, storing JSON/CSV outputs for regression tracking.

* **Code Quality Gates:**
  - `flutter analyze` + custom lint rules enforce immutability, null safety, and documentation. PRs require ≥80% coverage on `vector_engine` + `event_core` packages.
  - Formatting enforced through `dart format`, `just lint`, and pre-commit hooks from `I1.T10`.
  - Security scanning (dependency audit) scheduled weekly; release workflow halts on critical advisories.

* **Artifact Validation:**
  - Diagram lint (PlantUML/Mermaid CLI) embedded in CI ensures syntactic validity before merge.
  - JSON/Markdown specs validated by schema checkers; OpenAPI-style file format spec runs through `spectral lint`.
  - Exporters validated via external CLI tools (`svglint`, `pdfinfo`); AI/SVG import fixtures cross-checked against Adobe Illustrator + browser renders.
  - Manifest sync is part of review checklist—new anchors require corresponding `plan_manifest.json` entries so downstream agents can fetch sections by key.

<!-- anchor: glossary -->
## 7. Glossary

| Term | Definition |
|------|------------|
| **ADR** | Architectural Decision Record capturing context/problem/decision/consequences for traceability. |
| **BCP** | Bezier Control Point used to shape curves during pen/direct selection operations. |
| **CustomPainter** | Flutter API for imperative canvas drawing, powering WireTuner’s viewport + overlays. |
| **Event Sampler** | Service throttling pointer data to 50 ms intervals before persistence. |
| **Hybrid State** | Strategy of storing both final document snapshot and optional history log for replay. |
| **MDI** | Multiple Document Interface; each document runs in its own window while sharing app menu. |
| **Operation Grouping** | Logic bundling multiple sampled events into a single undoable unit based on idle detection. |
| **Snapshot** | Serialized document state stored periodically (≈1000 events) to accelerate loading and scrubbing. |
| **Tier-2 AI Import** | Scope of Adobe Illustrator features supported in v0.1 (gradients, clipping, compound paths, etc.). |
| **WireTuner Manifest** | JSON index mapping anchor keys to file locations, enabling autonomous agents to fetch plan sections without scanning entire files. |
