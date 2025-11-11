<!-- anchor: verification-and-integration-strategy -->
## 5. Verification and Integration Strategy
* **Testing Levels:**
  - **Unit:** Every tool, viewport utility, event/snapshot service, importer/exporter, collaboration transformer, and UI widget includes unit tests referencing FR/NFR IDs; coverage ≥80% for domain/event sourcing code (`flutter test --coverage`, `dart test`).
  - **Integration:** End-to-end flows (pen→save→reload, multi-artboard navigator, collaboration sessions, import/export) run via Flutter integration tests + mocked services; backend GraphQL/WebSocket integration tested with contract suites to ensure schema stability.
  - **Performance:** Automated benchmarks measure load time (<100 ms for 10K events), replay throughput (≥5K events/sec), snapshot duration (<500 ms), thumbnail refresh (<100 ms), FPS ≥60; failures block releases and raise telemetry alerts.
  - **Security & Reliability:** SQLite integrity checks, migration dry-runs, OT conflict fuzzing, and crash-recovery drills; secrets scanning and dependency audits run nightly.
* **CI/CD Pipeline Expectations:**
  - GitHub Actions (macOS, Windows, Linux runners) execute lint/analyze/test, golden diffs, unit/integration/perf suites, and melos-managed package checks; resvg workers build via Docker; Terraform plans produced for infrastructure changes.
  - Quality gates (Task I1.T6) enforce formatting, linting, unit coverage, integration tests, PlantUML regeneration, schema validation, and documentation link checks before merge.
  - Performance suites scheduled nightly; results pushed to telemetry dashboards and compared against baselines with ±5% tolerance.
  - Release pipeline (I5.T5) notarizes DMG/MSI, tags repos, uploads artifacts to S3/CloudFront, updates LaunchDarkly flag defaults, and posts status-page entry.
* **Code Quality Gates:**
  - Static analysis (dart analyze, flutter analyze, clippy for Rust worker) must pass; no TODOs referencing blockers; every PR links FR/NFR IDs.
  - Coverage threshold 80% for domain/infrastructure packages, 70% for UI packages; quality script fails if below.
  - Golden tests compare UI snapshots; drift must be reviewed by UX lead.
  - ADR compliance and directory ownership enforced via lint rules.
* **Artifact Validation:**
  - PlantUML diagrams compiled in CI; generated PNGs/SVGs embedded in docs with checksums.
  - GraphQL/OpenAPI schemas validated using Spectral; clients regenerated when schema changes.
  - Import/export verification uses curated corpus of SVG/AI/PDF samples with diffing harness to guarantee fidelity.
  - Release readiness report (I5.T6) captures KPI evidence, outstanding risks, approvals from architects/QA/Ops.
  - Telemetry dashboards monitored to confirm KPIs remain within SLA after deployment; anomalies trigger rollback/flag toggles per runbooks.

<!-- anchor: glossary -->
## 6. Glossary
* **ADR:** Architectural Decision Record documenting rationale, outcomes, and impacts for significant technical choices.
* **Artboard Navigator:** Root window listing all artboards across documents with thumbnails, tabs, and management actions.
* **Auto-Save Manager:** InteractionEngine service batching events after 200 ms idle, persisting to SQLite, and coordinating manual save checkpoints + snapshots.
* **BackgroundWorkerPool:** Isolate/worker orchestration layer handling snapshots, thumbnail rendering, PDF conversion, and AI import parsing outside the UI thread.
* **Clean Architecture:** Layered approach (Presentation → Application → Domain → Infrastructure) enforcing inward-only dependencies and testability.
* **Collaboration Gateway:** Dart Frog WebSocket/GraphQL service sequencing OT events, broadcasting presence, and validating JWTs.
* **EventStoreServiceAdapter:** SQLite-backed persistence layer storing event log, snapshots, and migrations; exposes replay-friendly APIs.
* **LaunchDarkly:** Managed feature flag platform controlling staged rollouts, kill switches, and experimentation toggles.
* **Operational Transform (OT):** Algorithm reconciling concurrent edits to vector data while preserving intent and deterministic state.
* **ReplayService:** Component that rehydrates document state from snapshots plus events, powering history scrubber and deterministic undo/redo.
* **resvg:** Rust-based SVG rendering library used to convert SVG output into high-fidelity PDF exports.
* **SnapshotManager:** Background isolate service serializing document state on thresholds (500 events/10 min/manual save) with memory safeguards.
* **Telemetry Overlay:** In-app HUD showing FPS, replay rate, snapshot duration, and sampling metrics; tied to opt-in telemetry settings.
* **Wireframe Atlas:** Collection of UI/UX documents describing Navigator, artboard windows, history replay, and collaboration panels for alignment across teams.
