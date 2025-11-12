<!-- anchor: iteration-plan-overview -->
## 5. Iteration Plan
- **Total Iterations Planned:** 5
- **Iteration Dependencies:** I2 depends on foundational architecture/modeling from I1; I3 builds on event/persistence services delivered by I2; I4 extends multi-artboard + navigator work from I3; I5 layers import/export, verification, and release governance on top of earlier iterations.

<!-- anchor: iteration-1-plan -->
### Iteration 1: Platform Blueprint & Workspace Scaffolding
* **Iteration ID:** `I1`
* **Goal:** Stand up the monorepo workspace, baseline tooling, architectural diagrams, and domain modeling artifacts so downstream teams share a single source of truth.
* **Prerequisites:** None.
* **Tasks:**
    <!-- anchor: task-i1-t1 -->
    * **Task 1.1:**
        * **Task ID:** `I1.T1`
        * **Description:** Initialize melos-based Flutter/Dart workspace, set up package boundaries (`packages/app`, `packages/core`, `packages/infrastructure`, `server/*`), and configure lint/test tooling with GitHub Actions skeleton.
        * **Agent Type Hint:** `SetupAgent`
        * **Inputs:** Spec Sections 7.1–7.4, existing repo state.
        * **Input Files**: []
        * **Target Files:** [`melos.yaml`, `packages/app/pubspec.yaml`, `packages/core/pubspec.yaml`, `packages/infrastructure/pubspec.yaml`, `server/collaboration-gateway/pubspec.yaml`, `.github/workflows/ci.yaml`]
        * **Deliverables:** Bootstrapped workspace, pinned dependencies, CI workflow covering analyze/test, README excerpt describing workspace layout.
        * **Acceptance Criteria:** Melos `bootstrap` succeeds; CI job runs analyze+test on placeholder targets; README documents workspace commands; no lint violations.
        * **Dependencies:** None.
        * **Parallelizable:** Yes.
    <!-- anchor: task-i1-t2 -->
    * **Task 1.2:**
        * **Task ID:** `I1.T2`
        * **Description:** Author system context, container, and component diagrams (PlantUML) depicting desktop layers, backend services, and infrastructure per Clean Architecture guidelines.
        * **Agent Type Hint:** `DiagrammingAgent`
        * **Inputs:** Section 2 (Core Architecture), ADR list.
        * **Input Files**: [`docs/diagrams/`]
        * **Target Files:** [`docs/diagrams/system_context.puml`, `docs/diagrams/deployment.puml`, `docs/diagrams/component_overview.puml`]
        * **Deliverables:** Reviewed PlantUML diagrams, embedded PNG/SVG exports if automated, update to `docs/README.md` referencing diagrams.
        * **Acceptance Criteria:** Diagrams compile via PlantUML CI; reflect all major components/services; links added to plan manifest; stakeholders approve during design review.
        * **Dependencies:** `I1.T1` (directory layout, tooling pipeline needed).
        * **Parallelizable:** No.
    <!-- anchor: task-i1-t3 -->
    * **Task 1.3:**
        * **Task ID:** `I1.T3`
        * **Description:** Define canonical domain model, ERD, and JSON schemas covering Document→Artboard→Layer→VectorObject plus Event/Snapshot tables; capture in markdown + schema files.
        * **Agent Type Hint:** `DatabaseAgent`
        * **Inputs:** Sections 3.1–3.3, ADR-003.
        * **Input Files**: [`docs/diagrams/domain_erd.puml`, `docs/reference/`]
        * **Target Files:** [`docs/diagrams/domain_erd.puml`, `docs/reference/event_catalog.md`, `docs/reference/snapshot_schema.json`, `server/sync-api/prisma/schema.prisma`]
        * **Deliverables:** Updated ERD, event catalog table, JSON schema for snapshots, DB schema stub for Sync API.
        * **Acceptance Criteria:** ERD builds; schema validates via `ajv`; event catalog lists FR IDs; Prisma schema passes `prisma validate`.
        * **Dependencies:** `I1.T1`.
        * **Parallelizable:** Yes (after `I1.T1`).
    <!-- anchor: task-i1-t4 -->
    * **Task 1.4:**
        * **Task ID:** `I1.T4`
        * **Description:** Establish shared design token registry (colors, typography, spacing) and automate export to Flutter theme + documentation.
        * **Agent Type Hint:** `FrontendAgent`
        * **Inputs:** UI spec (Section 6), design tokens appendix.
        * **Input Files**: [`docs/ui/tokens.md`]
        * **Target Files:** [`docs/ui/tokens.md`, `packages/app/lib/theme/tokens.dart`, `tools/design-token-exporter/cli.dart`]
        * **Deliverables:** Tokens markdown, generated Dart theme extensions, CLI script to sync tokens.
        * **Acceptance Criteria:** Flutter theme compiles; tokens documented with usage; CLI run logged in README; lint/tests green.
        * **Dependencies:** `I1.T1`.
        * **Parallelizable:** Yes.
    <!-- anchor: task-i1-t5 -->
    * **Task 1.5:**
        * **Task ID:** `I1.T5`
        * **Description:** Draft foundational ADRs (event storage, OT strategy, snapshot policy, undo depth) and set up ADR template + contribution guide.
        * **Agent Type Hint:** `DocumentationAgent`
        * **Inputs:** Section 9 ADR summaries.
        * **Input Files**: [`docs/adr/`]
        * **Target Files:** [`docs/adr/ADR-0001-event-storage.md`, `docs/adr/ADR-0002-ot-strategy.md`, `docs/adr/ADR-0003-snapshot-policy.md`, `docs/adr/ADR-0004-undo-depth.md`, `docs/adr/template.md`]
        * **Deliverables:** Filled ADRs with context/decision/consequences, documented process in CONTRIBUTING.
        * **Acceptance Criteria:** ADRs cross-link to requirements; template merged; CONTRIBUTING updated with ADR workflow.
        * **Dependencies:** `I1.T1`.
        * **Parallelizable:** Yes.
    <!-- anchor: task-i1-t6 -->
    * **Task 1.6:**
        * **Task ID:** `I1.T6`
        * **Description:** Configure baseline CI quality gates (format, lint, unit smoke) and reporting (badge, PR checklist) tied to melos packages.
        * **Agent Type Hint:** `DevOpsAgent`
        * **Inputs:** Task outputs from `I1.T1`, quality guidelines.
        * **Input Files**: [`.github/workflows/`, `scripts/devtools/`]
        * **Target Files:** [`.github/workflows/ci.yaml`, `scripts/devtools/quality_gate.sh`, `docs/qa/quality_gates.md`]
        * **Deliverables:** CI workflow enforcing analyze/test/format, helper script, doc describing gates + badge in README.
        * **Acceptance Criteria:** Workflow passes on clean tree, fails intentionally injected lint error, README badge visible, doc links FR/NFR IDs.
        * **Dependencies:** `I1.T1`.
        * **Parallelizable:** No (needs workspace stabilized).
