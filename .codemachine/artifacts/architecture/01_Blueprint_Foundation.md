<!-- anchor: blueprint-foundation -->
# 01_Blueprint_Foundation.md

<!-- anchor: project-scale-and-directives -->
### **1.0 Project Scale & Directives for Architects**

- **Classification:** Large
- **Rationale:** WireTuner combines a professional-grade Flutter desktop suite, a hybrid event-sourced persistence core, full SVG/PDF/AI import-export, multi-artboard windowing, multiplayer collaboration, and strict performance/SLA metrics (e.g., <100 ms load for 10 K events, ≥5 K events/sec replay, ≥60 FPS rendering with ≥20 simultaneous windows). The specification enumerates 50 functional requirements, 30+ non-functional mandates, a multi-version migration path, and an ADR trail—clear signals of a Large endeavor spanning hundreds of KLOC across client and service codebases.
- **Core Directive for Architects:** This is a **Large-scale** program. All downstream designs MUST optimize for high scalability, long-term maintainability, and rigorous Separation of Concerns. Every subsystem (UI shell, interaction engine, persistence, collaboration gateway, telemetry, import/export) SHALL expose explicit contracts so that evolution in one area never propagates accidental coupling elsewhere.
- **Scale Signals for Specialist Teams:** Expect multi-year roadmap continuity, simultaneous platform parity (macOS + Windows), and incremental delivery of advanced capabilities (history replay UI, typography stack, Boolean ops). Plan staffing, testing depth, and documentation volume accordingly.

---

<!-- anchor: standard-kit -->
### **2.0 The "Standard Kit" (Mandatory Technology Stack)**

*This technology stack is the non-negotiable source of truth. All architects MUST adhere to these choices without deviation.*

- **Architectural Style:** Clean layered monolith within the desktop client (Presentation → Application → Domain → Infrastructure) coupled to a service-oriented backend (GraphQL + WebSocket gateway, telemetry ingest, worker queues). Event sourcing is mandatory for state changes, with background snapshotting for fast loads.
- **Frontend:** Flutter 3.x desktop with CustomPainter rendering, Provider/ChangeNotifier for dependency injection, Freezed/json_serializable for immutable models, and Platform Channels limited to OS dialogs/thumbnails. UI composition follows MVU-inspired patterns to simplify undoable interactions.
- **Backend Language/Framework:** Dart Frog (preferred) or Node.js (TypeScript + NestJS) for collaboration and metadata APIs to reuse domain DTOs; lightweight Rust FFI shims permitted only for SVG-to-PDF conversion or performance-critical import parsing.
- **Database(s):** SQLite 3.x (per-document, WAL mode) for events, snapshots, and metadata. PostgreSQL 14+ for collaboration metadata, user profiles, and audit trails. Redis (clustered) for pub/sub fan-out and transient presence caching. Optional S3-compatible object storage for export artifacts and backup snapshots.
- **Cloud Platform:** AWS baseline (S3, RDS, ElastiCache, CloudWatch, EKS). Equivalent GCP/Azure mappings require explicit Foundation Architect approval and documentation of service parity.
- **Containerization:** Docker images for all backend workloads; Kubernetes (EKS) orchestrates collaboration gateway pods, telemetry processors, and conversion workers with autoscaling rules tied to concurrent session counts and job queue depth.
- **Messaging/Queues:** Redis Pub/Sub for low-latency event broadcasts, AWS SQS (or Redis Streams) for background conversions (PDF, AI import) and thumbnail farm tasks. No ad-hoc polling—every long-running task must flow through a queue with idempotent handlers.
- **Build & Packaging:** Flutter build pipelines run via `flutter build macos/windows` with notarization/signing steps. Backend CI/CD uses GitHub Actions → ECR → EKS rolling deploys with canary stages gated by feature flags.
- **Testing Stack:** `flutter_test` + `integration_test` for client, golden image tests for rendering deltas, `melos` for monorepo orchestration, and `dart test`/`jest` for backend services. Performance regression tests must run nightly.
- **Desktop Installers:** macOS DMG with notarization & auto-generated QuickLook plugin; Windows MSI with Explorer thumbnail handler registration and file associations.

---

<!-- anchor: rulebook -->
### **3.0 The "Rulebook" (Cross-Cutting Concerns)**

- **Feature Flag Strategy:** Feature toggles are mandatory for every user-facing or performance-sensitive change. LaunchDarkly (hosted) is the reference implementation; an offline-capable Flagsmith mirror powers air-gapped installs. Flags load through a single FeatureFlagClient with startup bootstrap values and periodic sync. New flags default OFF in production until QA + UX approve, and every flag must include decommission criteria in Ops docs.
- **Observability (Logging, Metrics, Tracing):** Structured JSON logging to stdout (backend) and rotating files (client) is required. Metrics surface through Prometheus `/metrics` endpoints (backend) and perf overlay counters (client) with matching naming conventions. Tracing adopts OpenTelemetry end-to-end; trace IDs originate in the client InteractionEngine and propagate via WebSocket/GraphQL metadata for correlation across services.
- **Security:** TLS 1.3 everywhere, signed installers, sandbox entitlements minimized. AuthService issues short-lived JWTs (15 min) with refresh tokens stored in OS keychains. All file I/O validates canonical paths and ensures `.wiretuner` files are opened read-write exclusively. Backend secrets live in AWS Secrets Manager, never in source.
- **Data Integrity & Consistency:** Event writes require SQLite transactions with immediate fsync, retrying (10 ms, 50 ms, 200 ms) on locks. ReplayService validates deterministic hashes per snapshot; divergence triggers automatic telemetry plus UI warning. Collaboration gateway enforces monotonic sequence assignment even across partitions using Redis-backed counters.
- **Performance Budgets:** Tool activation <50 ms, cursor updates <0.2 ms, viewport switch <16 ms, thumbnail regeneration <100 ms/1 K objects, event replay ≥5 K events/sec, snapshot creation backgrounded with zero UI hitching. Architects must document fallback plans (overlay unregistration, decimated sampling) before budgets are exceeded.
- **Configuration Governance:** All tunables (sampling rate, snapshot thresholds, undo depth, thumbnail cadence) live in ConfigurationService with schema versioning and migration routines. No hard-coded constants outside this service; even experimental values must route through feature flags or config records.
- **Accessibility & Internationalization:** UI text is localized through Flutter's intl tooling; status toasts (anchor visibility, zoom hints) require screen reader labels. Color choices for anchor types must meet WCAG contrast ratios.
- **Testing & Quality Gates:** Unit + integration + golden tests block merges. Performance tests (render FPS, replay rate) run nightly with trend dashboards. Any regression beyond ±5% automatically blocks releases until triaged.
- **Release & Rollback Discipline:** Desktop releases map to semantic versions aligned with file format versions; migrations include reversible scripts and automatic backups. Feature flags plus JSON export/import provide escape hatches without code rollback.

---

<!-- anchor: blueprint -->
### **4.0 The "Blueprint" (Core Components & Boundaries)**

- **System Overview:** WireTuner is a modular desktop-first platform where a Flutter Presentation layer orchestrates artboard windows, the Application layer translates gestures into domain commands, the Domain layer defines immutable document structures, and the Infrastructure layer persists event logs + snapshots. Optional cloud services (collaboration, telemetry, conversion workers) extend capabilities without compromising offline workflows.
- **Core Architectural Principle:** Absolute Separation of Concerns. Presentation widgets dispatch intent but never mutate domain state; Application services mediate tool logic; Domain models remain immutable Freezed classes; Infrastructure handles I/O. Any component replacement (e.g., swapping SVG-to-PDF backend) must affect only the corresponding adapter, not shared business logic.

- **Key Components/Services:**
  - **DesktopShell (Presentation):** Hosts Navigator + artboard windows, coordinates focus, surfaces toolbars/status bars, and owns keyboard shortcut routing while delegating state changes to InteractionEngine.
  - **ToolingFramework:** Defines Tool interfaces (Pen, Selection, Direct Selection, Text, Boolean Ops) with consistent lifecycles (activate, handlePointer, deactivate) and enforces statelessness by pulling context via providers.
  - **InteractionEngine (Application):** Converts tool intents into domain commands, enforces snapping (screen-space grid, arrow nudging), batches undoable operations with 200 ms idle thresholds, and emits user feedback (toasts, hints) per FR-050.
  - **RenderingPipeline:** Multi-layer CustomPainter stack (base geometry, overlays, HUD) with GPU acceleration, CPU fallback heuristics, and deterministic redraw scheduling for Navigator thumbnails and exports.
  - **EventStoreService:** Manages SQLite schema (events, snapshots, metadata), WAL mode, fsync guarantees, version migrations, and corruption detection; exposes streaming readers for replay and analytics.
  - **SnapshotManager:** Background isolate worker that deep-copies document state, serializes to JSON, gzip-compresses, enforces memory headroom checks, and persists snapshots every 500 events, 10 minutes, or manual save triggers.
  - **ReplayService:** Reconstructs document state for loading, history scrubbing, and timeline playback. Maintains checkpoint cache every 1 000 events to enable <50 ms seeks and includes APIs for deterministic hash verification.
  - **NavigatorService:** Controls multi-document tabs, artboard thumbnails (auto-refresh every 10 s idle or on save), context menus (rename, duplicate, delete, export, refresh), drag-to-reorder z-order, and prompts when closing Navigator roots.
  - **ImportExportService:** Handles SVG/AI/PDF/JSON import-export flows, validation, warning reports, and asynchronous conversions (PDF via `resvg`, AI parsing). Integrates with FeatureFlagClient for staged rollouts of new formats.
  - **CollaborationGateway (Cloud):** WebSocket + GraphQL hybrid that sequences multiplayer events using Operational Transform, broadcasts presence/cursors, persists collaboration metadata, and enforces per-document concurrency caps.
  - **SyncAPI:** GraphQL endpoint for document metadata, snapshot exchange, settings sync, and user management. Serves as contract boundary for Ops and Docs teams and powers remote backup/restore workflows.
  - **TelemetryService:** Collects structured logs, metrics, crash dumps, and replay inconsistencies. Provides dashboards, alerting (e.g., snapshot defer rates), and anonymization/opt-out controls.
  - **SettingsService:** Central storage for user/global preferences (sampling intervals, anchor visibility defaults, overlay toggles). Handles migrations, publishes updates, and writes per-document metadata.
  - **FeatureFlagClient:** Caches LaunchDarkly/Flagsmith evaluations, supports offline bootstrapping, and exposes synchronous reads to Presentation/Application layers; also logs flag evaluations for audit.
  - **BackgroundWorkerPool:** Manages queued jobs (thumbnail regeneration, AI import processing, PDF conversion) either locally (Isolates) or remotely (containerized workers) with retries and telemetry hooks.
  - **SecurityGateway:** Encapsulates auth flows, token refresh, secure storage, and signing operations for exports/imports. Ensures third-party libraries never receive direct access to secrets or raw event logs.

---

<!-- anchor: contract -->
### **5.0 The "Contract" (API & Data Definitions)**

- **Primary API Style:** GraphQL (queries/mutations) governs metadata, settings, and snapshot exchange; WebSockets stream real-time events/presence; REST is reserved for telemetry ingest and artifact downloads. OpenAPI/SDL specs are centralized so all teams generate clients from the same source.
- **Data Model - Core Entities:**
  - **User:** `id (UUID)`, `email`, `displayName`, `avatarUrl`, `roles[]`, `platform (macos|windows)`, `createdAt`, `lastActiveAt`, `telemetryOptIn`, `featureFlagOverrides`.
  - **Document:** `id`, `name`, `authorId`, `metadata` (anchorVisibilityMode, samplingPreset, platform), `fileFormatVersion`, `createdAt`, `modifiedAt`, `artboardIds[]`, `snapshotSequence`, `eventCount`, `undoDepthLimit`.
  - **Artboard:** `id`, `documentId`, `name`, `bounds (x,y,width,height)`, `backgroundColor`, `zOrder`, `preset`, `viewportState (zoom, panOffset)`, `selectionState`, `thumbnailRef`, `layers[]` (ids).
  - **Layer:** `id`, `artboardId`, `name`, `visible`, `locked`, `zIndex`, `objectIds[]`, `opacity`, `blendMode` (future-proof).
  - **VectorObject:** `id`, `artboardId`, `layerId`, `type (path|shape|text|compound)`, `transform (translation, rotation, scale)`, `style (fill, stroke, opacity)`, `payload` (variant-specific data), `createdAt`, `modifiedAt`.
  - **VectorPath:** `id`, `objectId`, `anchors[]`, `segments[]`, `closed`, `windingRule`, `precisionMeta (tolerance, tessellation)`.
  - **AnchorPoint:** `id`, `pathId`, `index`, `position`, `handleIn`, `handleOut`, `type (smooth|corner|tangent)`, `constraints (mirrored|independent)`.
  - **Event:** `eventId`, `sequence`, `documentId`, `artboardId?`, `eventType`, `eventData (JSON)`, `timestamp`, `userId`, `operationId`, `sampledPath[]`, `source (local|remote)`.
  - **Snapshot:** `id`, `documentId`, `sequence`, `timestamp`, `stateHash`, `compressedData`, `sizeBytes`, `createdBy`, `compressionAlgorithm`.
  - **CollaborationSession:** `id`, `documentId`, `participantIds[]`, `websocketChannel`, `otBaselineSequence`, `latencyStats`, `presenceData`, `startedAt`, `endedAt?`.
  - **FeatureFlagSetting:** `id`, `flagKey`, `environment`, `defaultValue`, `overrides`, `lastSyncedAt`, `checksum`, `expiresAt?`.
  - **ExportJob:** `id`, `documentId`, `artboardScope`, `format (SVG|PDF|JSON)`, `status (queued|processing|complete|failed)`, `createdAt`, `completedAt`, `artifactUrl`, `warningList`, `backendVersion`.
  - **TelemetryEvent:** `id`, `documentId?`, `clientVersion`, `eventType (crash|performance|warning)`, `payload`, `timestamp`, `optInState`.
  - **SettingsProfile:** `id`, `userId`, `samplingInterval`, `snapshotThresholds`, `anchorVisibilityDefault`, `telemetryEnabled`, `gridSnapEnabled`, `nudgeDistanceOverrides`.
- **API Contracts (Illustrative Snippets):**
  - **GraphQL Mutation `createArtboard`:** Inputs `documentId`, `name`, `preset`, `width`, `height`, `backgroundColor`. Response returns full Artboard DTO plus `operationId`. Side effects: emits `artboard.created` event, schedules thumbnail job, updates NavigatorService caches.
  - **GraphQL Query `documentSummary(id)`** returns `document`, `artboards { id name zOrder }`, `snapshotSequence`, `eventCount`, `collaborationStatus`. Must resolve in <100 ms for docs ≤10 K events.
  - **WebSocket Message `event.broadcast`:** `{ "type": "event.broadcast", "documentId": "...", "sequence": 12345, "event": EventPayload, "otMetadata": {...} }`. Clients ACK to confirm receipt; missed ACKs trigger resync via `event.sync` command.
  - **REST POST `/telemetry/replay-inconsistency`:** Body includes `documentId`, `snapshotSequence`, `eventIds[]`, `stateHashBefore`, `stateHashAfter`, `clientVersion`, `platform`. Response 202 with `correlationId`. Rate limited (per device) to prevent flooding.
  - **REST GET `/exports/{jobId}`:** Requires signed URL; returns artifact metadata (size, checksum) and download link. Jobs expire after 7 days; Ops docs must explain cleanup schedule.
  - **GraphQL Subscription `documentPresence(documentId)`** streams `{ userId, cursorPos, selectionSummary, latency }` updates for UI annotations.

---

<!-- anchor: safety-net -->
### **6.0 The "Safety Net" (Ambiguities & Assumptions)**

- **Identified Ambiguities:**
  - GPU→CPU fallback policies mention warnings but not concrete detection thresholds or recovery logic.
  - AI import Tier 2 scope lists gradients/clip paths yet leaves text preservation expectations unspecified.
  - Multiplayer requirements cite Operational Transform but do not define offline/self-hosted expectations or concurrency caps.
  - Platform integration (QuickLook/Explorer) lacks mandated thumbnail resolution, rendering cadence outside the app, or installer responsibilities.
  - PDF export references multiple backends (flutter_svg+pdf, librsvg, resvg) without deciding on a default for fidelity/licensing.
  - Telemetry opt-out behavior is unspecified for privacy-sensitive or air-gapped deployments.
  - Undo stack configuration mentions unlimited history but omits memory budget guards or warning thresholds.
  - Timeline replay checkpoint generation cadence and eviction policies are not formally described.

- **Governing Assumptions:**
  - **Rendering Fallback:** RenderingPipeline monitors moving average frame time; three consecutive frames >16 ms trigger CPU fallback and performance toast (feature-flagged). Recovery requires five consecutive healthy frames plus user action (toggle in settings) to avoid flapping.
  - **AI Import Text Handling:** Imported text becomes path outlines in v1.0 to guarantee fidelity; editable text surfaces only when source provides live text data and passes capability checks. ImportExportService must log warnings summarizing conversions.
  - **Offline/On-Prem Mode:** When CollaborationGateway is unreachable, client degrades to single-user mode, queuing telemetry locally and disabling real-time presence UI. SyncAPI interactions are wrapped in exponential backoff with user-visible status.
  - **Thumbnail Providers:** QuickLook/Explorer handlers render cached snapshots at 512×512 resolution using headless RenderingPipeline binaries bundled in installers. Ops_Docs_Architect documents registration scripts and update strategy.
  - **PDF Backend Choice:** `resvg` (Rust via FFI) is the authoritative SVG-to-PDF engine for parity with Illustrator. Alternative stacks must prove equal fidelity + licensing compliance before adoption. ImportExportService abstracts backend choice via strategy pattern.
  - **Telemetry Opt-Out:** SettingsProfile includes `telemetryEnabled` (default true). When false, client logs remain local, network telemetry calls are skipped, and Ops docs describe manual export for support cases. Backend honors opt-out flags in every payload.
  - **Undo Depth Guards:** ConfigurationService enforces warning prompts when undo depth exceeds 500 operations or estimated memory >200 MB, suggesting archiving or JSON export. Unlimited mode stays available but requires explicit confirmation.
  - **Replay Checkpoint Lifecycle:** ReplayService generates checkpoints lazily upon first timeline access (interval 1 000 events) and evicts least-used checkpoints when memory pressure exceeds configured thresholds (default 100 MB). Architects must size caches per hardware telemetry and provide override settings.

<!-- anchor: section-1-supplement -->
#### 1.0 Supplemental Execution Guidance

- **Release Tranching:** Plan quarterly platform increments with explicit cross-team checkpoints (Foundation Architect → Structural_Data → Behavior → Ops_Docs). Each increment must deliver a self-contained slice (e.g., multi-artboard Navigator, collaboration OT, advanced typography) with regression test suites and documentation updates.
- **Risk Posture:** Maintain risk registers for GPU fallback, SQLite corruption, AI import fidelity, and collaboration latency. Each risk entry requires owner, mitigation, and contingency triggers that downstream architects inherit.
- **Resourcing Expectations:** Assume parallel squads for Rendering, Tooling, Persistence, Collaboration, and Import/Export. Each squad references this blueprint for constraints and escalates deviations via ADR addenda.
- **Stakeholder Communication:** Weekly architecture sync reviews delta proposals against this blueprint; deviations demand written rationale plus rollback plan. Ops_Docs must be present whenever decisions touch installers, telemetry, or compliance.
- **Dependency Boundaries:** No specialized architect may introduce new runtime dependencies (languages, databases, queues) without Foundation Architect approval. Evaluate additions against portability, licensing, and offline requirements.

<!-- anchor: section-2-supplement -->
#### 2.0 Supplemental Stack Notes

- **Dependency Management:** Pin Flutter/Dart versions via `fvm` and lock backend dependencies using `pubspec.lock`/`package-lock.json`. Security scans (Snyk or Dependabot) must run weekly; upgrades follow blue-green release strategy.
- **Build Tooling:** Adopt `melos` for managing multi-package Flutter workspace, `just` or `make` recipes for backend builds, and `cargo` workflows if Rust FFI modules are introduced. All build steps must be reproducible from CI with zero manual steps.
- **Testing Infrastructure:** Headless GPU testing uses CI runners with Metal (macOS) and DirectX (Windows) virtualization. Snapshot/golden tests store artifacts in Git LFS with naming tied to feature flags.
- **Packaging & Distribution:** DMG/MSI installers include checksum manifests, auto-update hooks (not active yet), and bundled QuickLook/Explorer extensions. Installer scripts enforce prerequisite checks (Visual C++ runtimes, .NET desktop components) without elevating privileges unless necessary.
- **Third-Party Libraries:** SVG parsing relies on Dart `xml`; PDF conversion relies on `resvg` (via FFI) with LGPL compliance review. Multiplayer stack may optionally integrate SurrealDB/Firestore clones only if schema parity is proven; default remains PostgreSQL.
- **DevOps Tooling:** Terraform codifies AWS infrastructure, with separate workspaces for staging/prod. Observability stack (Prometheus, Loki/Grafana or CloudWatch) is provisioned via IaC modules referencing this stack list.

<!-- anchor: section-3-supplement -->
#### 3.0 Supplemental Rule Clarifications

- **Feature Flag Lifecycles:** Every new flag requires metadata: owner, rollout plan, expiry date, kill-switch behavior, and QA validation notes. Flags older than two releases must be reviewed and either removed or refreshed with documented value.
- **Observability Golden Signals:** Standardize metrics: `render.fps`, `event.replay.rate`, `snapshot.duration.ms`, `import.duration.ms`, `websocket.latency.ms`, `ot.transform.failures`. Alerts trigger at predefined SLO breaches (e.g., 95th percentile replay rate <4 K events/sec).
- **Security Reviews:** Introduce STRIDE threat modeling per major feature. All file operations pass through a hardened FileAccessService that validates extensions, canonicalizes paths, and enforces size limits before imports/exports.
- **Data Lifecycle:** Define retention policies: events stored indefinitely per document, telemetry retained 90 days unless flagged, export artifacts auto-expire after 7 days. Ops_Docs must document user data deletion requests and tooling.
- **Compliance:** Prepare SOC 2-ready controls—change management logs, access audits for collaboration services, encryption key rotation schedules. Desktop logging respects GDPR/CCPA by excluding PII unless explicit consent captured.
- **Quality Gates:** Merge criteria include green unit/integration/perf pipelines, updated architecture docs, and ticket links referencing requirement IDs (FR/NFR). Behavior_Architect must assert compliance with tool-level acceptance tests before release candidates.
- **Disaster Recovery:** Collaboration gateway deployments require multi-AZ failover, Redis cluster snapshots, and synthetic transaction monitors. Client auto-save ensures local crash recovery irrespective of backend availability.

<!-- anchor: section-4-supplement -->
#### 4.0 Supplemental Blueprint Mapping

- **Data Flow Narrative:** User gestures enter DesktopShell → InteractionEngine → Domain Commands → EventStoreService (persist) → SnapshotManager (async) → RenderingPipeline (visual update). Multiplayer injection occurs between InteractionEngine and EventStoreService via CollaborationGateway, ensuring local optimistic UI while awaiting authoritative sequences.
- **Component Responsibility Matrix:**
  - **DesktopShell:** UI chrome, shortcut routing, window lifecycle.
  - **ToolingFramework:** Defines behaviors per tool type; reused by Behavior_Architect to add typography/boolean ops.
  - **InteractionEngine:** Maintains operation boundaries, sampling timers, and feeds ReplayService for timeline UI.
  - **RenderingPipeline:** Modular painters (base, overlays, HUD) with plug points for new visualization layers.
  - **EventStoreService:** CRUD for events, snapshots, migrations, integrity checks.
  - **SnapshotManager:** Background creation, compression, storage, eviction.
  - **ReplayService:** Snapshot restore, delta replay, checkpoint management, hash validation.
  - **NavigatorService:** Artboard tabbing, thumbnails, context actions, artboard-level state.
  - **ImportExportService:** Validates and converts vector data, surfaces warnings, integrates queue workers.
  - **CollaborationGateway:** OT sequencing, presence, WebSocket fan-out, GraphQL metadata operations.
  - **SyncAPI:** GraphQL/REST boundary for metadata, settings, backups, and docs integration.
  - **TelemetryService:** Log/metric/trace ingestion, dashboards, alerting, opt-out logic.
  - **SettingsService:** Centralized user/global configuration and propagation.
  - **FeatureFlagClient:** Flag retrieval/cache, evaluation analytics, bootstrap handling.
  - **BackgroundWorkerPool:** Runs blocking jobs (PDF, AI import) outside UI thread/isolate, reports completion.
  - **SecurityGateway:** Manages auth, secure storage, signing, and token lifecycle.
- **Integration Contracts:** Each component exposes well-defined DTOs; e.g., InteractionEngine emits `CommandRequest` objects, EventStoreService persists `EventRecord`s, ReplayService returns `DocumentStateSnapshot`. Architects must stick to these DTOs or update the blueprint before diverging.
- **Fault Containment:** UI-level failures (e.g., overlay painter crash) are sandboxed via try/catch and result in graceful degradation (hide overlay, show warning). Backend failures (collaboration timeout) degrade to offline mode without stopping local edits.
- **Extensibility Hooks:** ToolingFramework and RenderingPipeline expose registry APIs that future plugin systems can adopt without compromising security. ImportExportService uses strategy adapters for each format to ease future additions (e.g., DXF, PSD).

<!-- anchor: section-5-supplement -->
#### 5.0 Supplemental Contract Guidance

- **Versioning:** All DTOs include `schemaVersion`. GraphQL schema changes follow additive-first strategy; breaking changes require new field names plus deprecation notices. WebSocket payloads advertise `protocolVersion` to coordinate OT rules.
- **Validation Rules:**
  - `Document.name` max 200 chars; `Artboard.name` max 100 chars; reject leading/trailing whitespace.
  - `VectorPath.anchors` requires 2–10 000 entries; additional anchors trigger warnings (FR performance limits).
  - `Snapshot.sizeBytes` must remain <25 MB; exceeding size triggers compression tuning recommendations.
  - `ExportJob.format` restricts to enumerated values; invalid combos (e.g., PDF + multi-artboard selection) raise API errors with remediation hints.
- **Sample Payloads:**
  - **Event Example:**
    ```json
    {
      "eventId": "8dd0...",
      "sequence": 12045,
      "documentId": "doc-123",
      "artboardId": "art-3",
      "eventType": "path.anchor.moved",
      "eventData": {
        "pathId": "path-7",
        "anchorIndex": 4,
        "oldPosition": {"x": 100.5, "y": 200.0},
        "newPosition": {"x": 118.0, "y": 212.4},
        "sampledPath": []
      },
      "timestamp": "2025-11-10T14:30:00.123456Z",
      "userId": "user-9",
      "operationId": "op-456"
    }
    ```
  - **GraphQL Query:**
    ```graphql
    query DocumentSummary($id: ID!) {
      document(id: $id) {
        id
        name
        fileFormatVersion
        snapshotSequence
        eventCount
        artboards {
          id
          name
          zOrder
          thumbnailRef
        }
      }
    }
    ```
- **Error Contracts:** APIs return structured errors `{ code, message, remediation }`. Example codes: `EVENT_SEQUENCE_GAP`, `FILE_VERSION_UNSUPPORTED`, `EXPORT_WORKER_TIMEOUT`, `FLAG_EVALUATION_FAILED`.
- **Caching & Consistency:** Clients cache snapshots/events per document with SHA-256 validation. WebSocket resync uses `event.sync` request specifying last-known sequence; server responds with missing events or instructs full snapshot reload.
- **Data Privacy:** TelemetryEvent payloads must strip art content; only metadata (object counts, fps, durations) allowed unless user opts into detailed reporting. CollaborationSession presence updates send coarse selection summaries, not raw geometry.

<!-- anchor: section-6-supplement -->
#### 6.0 Supplemental Ambiguity Resolutions

- **Risk-to-Requirement Mapping:**
  - GPU fallback ambiguity ties to NFR-PERF-003; Behavior_Architect documents detection heuristics and fallback UI copy.
  - AI text handling ambiguity maps to FR-021; ImportExportService ensures warning dialogs cite spec paragraphs.
  - Multiplayer offline handling links to Section 7.9; Structural_Data_Architect defines storage sync modes for later reconciliation.
- **Assumption Validation Tasks:**
  - Prototype GPU fallback detection using synthetic load to confirm threshold behavior before GA.
  - Build AI import test corpus (≥20 files) covering gradients, clips, text to validate outline conversion assumption.
  - Simulate offline installs to verify telemetry opt-out, collaboration degradation, and queue persistence.
  - Benchmark replay checkpoint cache eviction to ensure 100 MB limit holds on 4 GB RAM systems.
- **Escalation Protocol:** Any violation or new ambiguity must produce an ADR addendum referencing this safety net. Ops_Docs teams require 2-week notice for installer, telemetry, or compliance-affecting changes.
- **Audit Trail Expectations:** Maintain linkage from each assumption to validation evidence (test report, benchmark, user study). Store artifacts in shared architecture repo under `/evidence/YYYY-MM-DD`.
- **Success Metrics:** Blueprint adherence judged via release readiness reviews: zero undocumented dependencies, all contracts implemented as specified, and no Sev1 incidents stemming from ambiguous requirements.

<!-- anchor: compliance-checklists -->
#### Architecture Compliance Checklists

1. **Pre-Implementation Review**
   - Verify every new feature maps to documented FR/NFR IDs and cites the corresponding component(s).
   - Ensure no additional data stores, queues, or protocols are introduced; if unavoidable, draft ADR before coding.
   - Confirm feature flags, telemetry hooks, and observability metrics are defined prior to implementation.
2. **Code Complete Review**
   - Validate unit/integration/performance tests exist and reference requirement IDs.
   - Cross-check DTO changes against Section 5 contracts; regenerate schema documentation as needed.
   - Run replay determinism tests (snapshot hash comparison) for any persistence-affecting change.
3. **Release Readiness Review**
   - Confirm Ops_Docs have updated installer scripts, runbooks, and migration guides.
   - Review telemetry dashboards/alerts covering new metrics or feature usage.
   - Ensure rollback/kill-switch procedures are documented and exercised in staging.

<!-- anchor: contract-traceability -->
#### Data Contract Traceability Matrix (Excerpt)

| Requirement | Component Owner | Contract Artifact | Notes |
|-------------|----------------|-------------------|-------|
| FR-029 (Navigator auto-open) | NavigatorService | GraphQL `documentSummary` response fields `artboards[]` | Thumbnail cadence tied to SnapshotManager events. |
| FR-046 (Sampling configuration) | SettingsService | SettingsProfile schema (`samplingInterval`) | Exposed via ConfigurationService + FeatureFlagClient for experiments. |
| FR-050 (Arrow nudging) | InteractionEngine | Command payload `nudgeDelta` | Screen-space conversion utility shared with RenderingPipeline overlays. |
| NFR-PERF-002 (Replay rate) | ReplayService | Telemetry metric `event.replay.rate` | Alert threshold 4 K events/sec (p95). |
| NFR-REL-003 (Integrity check) | EventStoreService | SQLite PRAGMA scripts | Run before load; failures routed to telemetry endpoint. |

<!-- anchor: risk-register-seed -->
#### Initial Risk Register Seeds

- **R-GPU-001:** GPU fallback churn causes flicker. *Mitigation:* Debounce switches, cache last-good renderer, include health telemetry.
- **R-DB-002:** SQLite file corruption on power loss. *Mitigation:* WAL mode + fsync, auto-backup snapshots, corruption detector with recovery tool.
- **R-IMP-003:** AI import drifts from Adobe updates. *Mitigation:* Maintain sample corpus, schedule quarterly compatibility tests, expose user warnings with remediation.
- **R-COL-004:** Collaboration latency spikes beyond OT tolerance. *Mitigation:* Redis latency monitoring, autoscale gateway pods, degrade to single-user mode gracefully.
- **R-OBS-005:** Telemetry opt-out compliance gaps. *Mitigation:* Legal review, toggle in settings, offline log export instructions, audit logs verifying respect of opt-out.

<!-- anchor: roadmap-alignment -->
#### Roadmap Alignment Notes

- **Milestone M1 (Foundational Multi-Artboard):** Deliver NavigatorService, per-artboard state persistence, artboard events/migrations, and updated file format 2.0. Ops_Docs produce migration guides; Structural_Data verifies replay stability.
- **Milestone M2 (History Replay Experience):** Implement ReplayService checkpoints, timeline UI, playback controls, telemetry instrumentation, and export-to-video backlog capture. Behavior_Architect ensures tool interactions feed timeline metadata.
- **Milestone M3 (Collaboration Alpha):** Deploy CollaborationGateway, SyncAPI, OT resolvers, presence overlays, and Redis-backed scaling. Ops_Docs document WebSocket ports, firewall guidance, and offline fallbacks.
- **Milestone M4 (Advanced Vector Suite):** Add typography tooling, boolean ops, envelope transforms, and advanced layer management. RenderingPipeline extends overlay types; ImportExportService updates SVG/PDF writers accordingly.

<!-- anchor: validation-activities -->
#### Validation Activities Per Domain

- **Rendering:** Golden image suite across zoom levels, GPU↔CPU parity tests, anchor visibility mode regressions, performance overlay validation.
- **Tooling:** Pen/selection/direct-selection E2E tests, grid snapping cases at multiple zoom levels, arrow nudging telemetry verification, undo/redo boundary cases.
- **Persistence:** Event flood tests (100 K events), snapshot compression benchmarks, migration simulations (v1→v2), corruption recovery exercises.
- **Collaboration:** Latency injection tests, OT conflict fuzzing, offline resume scenarios, Redis failover drills.
- **Import/Export:** SVG/PDF diffing against Illustrator, AI import warning coverage, JSON round-trip verification, per-artboard export accuracy.
- **Ops/Docs:** Installer smoke tests, QuickLook/Explorer handler verification, telemetry opt-out audit, runbook dry runs.

<!-- anchor: communication-protocols -->
#### Communication Protocol Expectations

- **Design Reviews:** Each component change triggers architecture review with sequence diagrams, DTO diffs, and feature flag plans. Minutes stored in `/architecture/reviews/YYYY-MM-DD.md`.
- **Documentation Syncs:** Ops_Docs receives weekly changelog summarizing migrations, installer changes, telemetry updates, and any assumption revisions.
- **Escalations:** Critical deviations (e.g., need for new database) require 48-hour written notice and Foundation Architect sign-off before code merges.
- **Knowledge Sharing:** Monthly "Blueprint Drift" audits compare implementation to this document; discrepancies produce remediation tickets.

<!-- anchor: future-facing-guards -->
#### Future-Facing Guardrails

- **Plugin API Placeholder:** Even though plugins are out-of-scope, architects must preserve registry boundaries (ToolRegistry, OverlayRegistry) to ease future enablement without core rewrites.
- **Mobile/Tablets:** Specification targets desktop, but maintain platform abstraction layers (input, cursor, viewport) to avoid blocking future touch adaptations.
- **Cloud Sync Evolution:** Design SyncAPI pathways so future realtime cloud storage (e.g., collaborative file system) can hook into existing contracts without altering SQLite format.
- **Analytics Ethics:** Telemetry must remain aggregate-first; personal data requires explicit consent stored in SettingsProfile. Provide anonymization utilities for Ops teams.
