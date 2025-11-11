<!-- anchor: design-rationale-and-tradeoffs -->
## 4. Design Rationale & Trade-offs

<!-- anchor: section-4-1-key-decisions -->
### 4.1 Key Decisions Summary
1. **AWS + EKS Baseline:** The foundation mandates AWS as the cloud home with Kubernetes orchestration (EKS) and Dockerized services; this ensures parity with LaunchDarkly, Redis, and PostgreSQL managed offerings while satisfying scalability constraints.
2. **Clean Architecture Monolith on Client:** Presentation → Application → Domain → Infrastructure layering prevents bleed-through between UI and event sourcing; it also keeps undo/redo deterministic and simplifies security reviews.
3. **Hybrid Event Sourcing:** Documents store final state snapshots plus append-only event logs in SQLite; this hybrid model delivers fast loads (<100 ms) and still preserves full replay for collaboration and history features.
4. **Snapshot Strategy:** SnapshotManager constants (500 events or 10 minutes, background isolate) lock operational behavior so UI threads never block; the design also enforces gzip compression and memory headroom checks.
5. **Operational Transform for Multiplayer:** OT guarantees deterministic convergence for vector edits, matching professional expectations and enabling low-latency WebSocket broadcasting.
6. **SVG-to-PDF via resvg:** Conversions rely on a single high-fidelity pipeline; delegating PDF specifics to resvg avoids implementing PDF operators manually while keeping parity with Illustrator.
7. **SQLite-native Types:** Event storage uses INTEGER/REAL/TEXT columns exclusively, preventing endianness issues across macOS and Windows and enabling straightforward debugging.
8. **LaunchDarkly Feature Flags:** Every feature toggles through LaunchDarkly (plus offline mirrors) so risky capabilities ship dark and Ops retains kill switches.
9. **Telemetry Opt-Out Enforcement:** SettingsProfile tracks consent; telemetry services respect opt-out by disconnecting uploads and storing logs locally only.
10. **Grid Snapping & Nudging in Screen Space:** Operational design ensures consistent UX regardless of zoom; documentation and instrumentation enforce this so future contributors do not regress to world-space logic.
11. **Undo Depth Configuration:** UndoManager exposes `MAX_UNDO_DEPTH`, default 100 but unlimited allowed; operational tooling monitors memory pressure and warns beyond 500 operations.
12. **JSON Export for Archival:** A dedicated export path provides Git-friendly diffs and long-term storage, complementing `.wiretuner` SQLite files.
13. **Multi-Artboard Navigator:** Documents treat Navigator as the root window controlling artboard lifecycles; operations and saving semantics revolve around this structure.
14. **Redis Pub/Sub for Collaboration:** Redis balances presence fan-out and queueing while staying manageable under AWS ElastiCache, aligning with blueprint messaging directives.
15. **Observability via OpenTelemetry + Prometheus:** This pairing unifies traces, metrics, and logs across desktop and backend components, satisfying blueprint cross-cutting requirements.

<!-- anchor: section-4-2-alternatives -->
### 4.2 Alternatives Considered
- **Pure Event Sourcing Without Snapshots:** Rejected because load times would scale linearly with event counts and violate NFR-PERF-001; hybrid state retains history while keeping launches under 100 ms.
- **Monolithic Backend Service (No Kubernetes):** Declined since collaboration gateway, import/export workers, telemetry collectors, and SyncAPI benefit from independent scaling; EKS also enforces containerized builds consistent with installer pipelines.
- **CRDT-Based Collaboration:** Considered for offline merge-friendliness but shelved because CRDT semantics complicate precision vector editing; OT is more predictable for anchor-level conflicts.
- **Dual PDF Pipelines (flutter_svg + resvg):** Multi-backend strategy would double validation burden; resvg already meets fidelity goals, so simplicity won.
- **Adaptive Grid Snapping (world space):** Dismissed after UX evaluation showed inconsistent behavior across zoom levels, leading to designer frustration.
- **Unlimited Undo Without Warnings:** Avoided to prevent hidden memory bloat; configuration plus warnings balances freedom and stability.
- **New Cloud Provider:** The foundation explicitly lists AWS due to existing tooling, so Azure/GCP were out of scope without ADR overrides.

<!-- anchor: section-4-3-risks -->
### 4.3 Known Risks & Mitigation
| Risk | Description | Impact | Mitigation |
|------|-------------|--------|------------|
| OT Complexity | Transform logic may contain edge-case bugs for compound paths or simultaneous anchor edits. | High | Maintain comprehensive OT test suite, fuzz concurrent edits, and log correction metrics for anomaly detection. |
| Snapshot Memory Pressure | 4 GB systems may fail to clone large documents for background snapshots. | Medium | Memory headroom checks delay snapshots and raise toasts; Ops collects telemetry to retune thresholds. |
| AI Import Evolution | Adobe format shifts can break Tier 2 importer coverage. | Medium | Maintain sample corpus, run compatibility tests quarterly, emit warnings with remediation hints (convert to SVG). |
| Observability Volume | Metrics/logs/traces could exceed storage budgets and privacy limits. | Medium | Lifecycle policies, anonymization, and opt-out enforcement keep data manageable. |
| Multi-Region Failover | Cross-region replication adds complexity for OT ordering. | Medium | Start with active/passive, document prerequisites, and rehearse failovers before enabling multi-master. |
| Feature Flag Drift | Stale flag context may cause inconsistent user experience offline. | Low | Embed bootstrap payloads in installers and log mismatches for manual bundle updates. |
| Undo Depth Abuse | Unlimited history on huge documents could degrade performance. | Low | Provide warnings at >500 operations, surface file size impacts, and document best practices. |
| GPU Fallback Flapping | Rapid GPU/CPU toggling could create flicker. | Low | Debounce fallback triggers and require user acknowledgement to re-enable GPU. |

<!-- anchor: section-4-4-design-tradeoffs -->
### 4.4 Detailed Trade-offs
- **Hybrid Storage vs. Pure Snapshot:** Hybrid adds complexity (events + snapshots) but unlocks history replay, collaboration, and forensic debugging; pure snapshots would simplify persistence but remove differentiators.
- **Operational Transform vs. Locking:** OT enables simultaneous editing, whereas locking would simplify implementation but block collaborative workflows; locking also conflicts with future roadmap features (presence, history scrub).
- **Screen-Space Snapping vs. Document-Space:** Screen-space ensures predictable visual feedback, but storing world-space coordinates introduces slight rounding complexity; this trade-off favors UX reliability.
- **LaunchDarkly vs. Homegrown Flags:** LaunchDarkly introduces vendor cost but supplies instant targeting, audit trails, and offline mirrors; building an internal system would delay feature rollouts and lack compliance tooling.
- **Resvg FFI vs. Pure Dart PDF:** FFI adds packaging and licensing considerations but dramatically improves fidelity and performance; pure Dart solutions lag behind Illustrator compatibility requirements.
- **EKS vs. ECS:** EKS demands steeper learning but aligns with open-source tooling, GitOps workflows, and portability to air-gapped clusters; ECS would limit our ability to reuse community operators and controllers.
- **Redis Pub/Sub vs. Kafka:** Redis provides low-latency message delivery and simpler ops; Kafka would overkill for current scale and complicate on-prem deployments.
- **Automation Depth vs. Manual Control:** Heavy automation (auto snapshots, auto scaling, auto reporting) risks hiding system behavior, but runbooks and dashboards maintain transparency while reducing toil.

<!-- anchor: section-4-5-rationale-conclusion -->
### 4.5 Rationale Wrap-Up
The architectural selections align tightly with blueprint mandates: AWS/EKS ensures infrastructural consistency, Clean Architecture preserves maintainability, event sourcing plus snapshots capture the creative timeline, and OT unlocks collaboration without compromising determinism.
Operational decisions (LaunchDarkly, Prometheus/OpenTelemetry, Redis, resvg) collectively ensure the platform meets strict performance budgets, supports future features like plugin ecosystems, and stays auditable for compliance.
The documentation discipline (anchors, ADRs, risk registers) keeps the implementation traceable, enabling future architects to evolve components without violating base assumptions.

<!-- anchor: future-considerations -->
## 5. Future Considerations

<!-- anchor: section-5-1-potential-evolution -->
### 5.1 Potential Evolution Paths
- **Multi-Region Active/Active Collaboration:** Implement CRDT-assisted replication or deterministic OT sequencing across regions once telemetry proves need; requires Redis Global Datastore and carefully versioned sequence IDs.
- **Plugin Ecosystem Enablement:** ToolRegistry and OverlayRegistry already expose extension points; future work includes sandbox policies, permissions, and marketplace distribution.
- **Machine Learning Analytics:** Telemetry data (with privacy safeguards) could power recommendation engines, anomaly detection for workflows, or auto-simplification suggestions; pipelines already exist for ingestion.
- **Cloud Document Sync:** With snapshots + JSON exports, enabling seamless multi-device sync or web previews becomes feasible; would require hardened auth flows and storage quotas.
- **GPU-Accelerated Conversion:** Import/export worker pools could use GPU-backed nodes for extreme PDF/AI workloads once cost-benefit analysis justifies it.
- **Advanced Security Controls:** Zero-trust policies, per-artboard access restrictions, and data loss prevention scanning could layer atop existing RBAC and FileAccessService infrastructure.
- **Automation Enhancements:** Self-healing snapshot thresholds, auto-tuning sampling rates per device, and AI-driven incident triage bots align with the operational roadmap.

<!-- anchor: section-5-2-areas-deeper-dive -->
### 5.2 Areas Requiring Deeper Design
1. **CI/CD Hardening:** Need a full blueprint for notarization pipelines, supply chain security (SBOM signing), and staged rollouts for desktop installers.
2. **Offline Collaboration Replay:** Additional design work should detail how edits queued offline merge back into server timelines without conflict explosions.
3. **Telemetry Privacy Controls:** Expand policies for anonymization, redaction, and customer-controlled retention beyond current opt-out toggles.
4. **Disaster Recovery Automation:** Document exact cutover scripts, DNS propagation steps, and integration tests ensuring multi-region readiness.
5. **Support Tooling UX:** While CLIs exist, a unified web console for Ops would streamline diagnostics, reducing dependency on manual commands.
6. **Compliance Evidence Automation:** Build pipelines generating reports, control mappings, and audit packages automatically each release cycle.
7. **Performance Budget Governance:** Define automated tests for boolean operations, typography tools, and upcoming features before they reach production.

<!-- anchor: section-5-3-future-kpi-roadmap -->
### 5.3 Future KPI Roadmap
- Expand KPI set to include customer adoption of multi-artboard features, collaboration session duration, and import fidelity ratings.
- Introduce predictive alerts based on machine learning models trained on historical incidents.
- Enrich scorecards with cost efficiency metrics (compute per active user) to inform pricing strategies.
- Tie roadmap milestones to KPI gates; features cannot exit beta until KPIs meet predetermined thresholds.

<!-- anchor: section-5-4-innovation-guardrails -->
### 5.4 Innovation Guardrails
- Any experimental feature must define rollback criteria, telemetry hooks, and documentation updates before prototype coding begins.
- ADRs must capture experimental learnings even if the feature does not ship, preserving institutional knowledge.
- Sandbox environments allow risky tests (e.g., new collaboration algorithms) without jeopardizing production SLOs.

<!-- anchor: glossary -->
## 6. Glossary
- **ADR:** Architectural Decision Record documenting context, choice, and consequences for major decisions.
- **AOF:** Append-Only File; Redis persistence format used for backups.
- **AppConfig:** AWS service managing dynamic configuration values and deployment strategies.
- **Argo CD:** GitOps tool orchestrating Kubernetes deployments based on repository state.
- **Artboard Navigator:** Root window managing artboard lifecycles, thumbnails, and multi-document tabs.
- **AWS EKS:** Managed Kubernetes service hosting Dockerized backend workloads.
- **Blue/Green Deployment:** Release strategy running two environments in parallel to minimize downtime.
- **CRDT:** Conflict-free replicated data type; alternative to OT for distributed collaboration.
- **Clean Architecture:** Layered approach (Presentation → Application → Domain → Infrastructure) ensuring dependency inversion.
- **Event Sourcing:** Storing state changes as append-only events to permit history replay and auditability.
- **FeatureFlagClient:** Component caching LaunchDarkly evaluations, honoring offline mode requirements.
- **GraphQL:** Query language powering SyncAPI interactions for metadata and settings.
- **LaunchDarkly:** Managed feature flag platform providing targeting, audit logs, and offline bootstrap bundles.
- **OT (Operational Transform):** Algorithm reconciling concurrent edits to keep documents consistent.
- **Prometheus:** Metrics collection system scraping exporters for Kubernetes workloads.
- **ReplayService:** Component that replays events from snapshots to reconstruct document states or drive timeline scrubbers.
- **resvg:** Rust-based SVG renderer used for high-fidelity SVG-to-PDF conversion.
- **SnapshotManager:** Service responsible for creating compressed snapshots on thresholds or manual saves.
- **SQLite WAL:** Write-Ahead Logging mode guaranteeing durability for local `.wiretuner` files.
- **ToolingFramework:** Set of stateless tool implementations (Pen, Selection, etc.) orchestrated by the InteractionEngine.
- **WebSocket Gateway:** Collaboration service streaming events, presence, and OT corrections between clients.

<!-- anchor: section-4-6-constraint-traceability -->
### 4.6 Constraint Traceability
- Every requirement maps to FR/NFR identifiers; for example, FR-026 dictates snapshot backgrounding, and NFR-PERF-006 enforces zero UI blocking.
- Operational constraints (LaunchDarkly usage, AWS exclusivity, Clean Architecture) appear in both blueprint and ADRs, ensuring engineers cannot silently deviate.
- Tooling (melos, justfiles, Terraform modules) encode these constraints so CI fails when drift occurs.
- Documentation cross-links allow future agents to navigate from operational runbooks back to foundational rationale quickly.

<!-- anchor: section-4-7-documentation-strategy -->
### 4.7 Documentation & Knowledge Management Decisions
- Anchored Markdown ensures every concept is addressable, enabling diffable updates and agent collaboration.
- Runbooks, ADRs, and architecture specs sit in the same repository to keep code and docs in lockstep.
- Ops_Docs_Architect owns change logs for installers, telemetry policies, and compliance procedures, preventing divergent narratives.
- PlantUML diagrams regenerate automatically, guaranteeing visual aids match textual updates.

<!-- anchor: section-4-8-ops-collaboration -->
### 4.8 Operations & Development Collaboration
- Shared OKRs align feature velocity with reliability; new functionality cannot ship without corresponding runbooks and monitoring hooks.
- Feature flags require ops approval before production enabling, ensuring rollouts align with capacity and observability readiness.
- Incident reviews include engineering, product, and ops stakeholders so fixes span code, configuration, and documentation.
- Ops feedback channels influence backlog prioritization; for example, improved snapshot inspectors originated from support pain points.

<!-- anchor: section-4-9-tradeoff-catalog -->
### 4.9 Extended Trade-off Catalog
- **SQLite vs. Document-oriented DB:** SQLite suits embedded, offline-first workflows; document stores would add dependencies and hinder portability.
- **Provider Pattern vs. Bloc/Riverpod:** Provider keeps dependencies lightweight and aligns with existing ChangeNotifier patterns; heavier frameworks complicate testing.
- **GraphQL + WebSockets vs. REST-only:** GraphQL simplifies metadata queries while WebSockets deliver low-latency collaboration; REST alone would force polling and degrade UX.
- **Redis Streams vs. SQS-only:** Streams provide ordered job tracking and progress updates, complementing SQS-style durability for longer jobs.
- **Manual CLI Tools vs. GUI Ops Console:** CLI offers scriptability and low overhead; GUI can arrive later once workflows stabilize.

<!-- anchor: section-4-10-risk-register-alignment -->
### 4.10 Risk Register Alignment
- Each risk in Section 8 of the specification has a mitigation owner; for instance, R-011 (multi-document lifecycle complexity) maps to NavigatorService instrumentation and runbooks.
- Risk reviews occur monthly; new findings add to register entries, ensuring transparency.
- Mitigation status ties directly to roadmap tasks, preventing stale risks from lingering without action.

<!-- anchor: section-4-11-decision-verification -->
### 4.11 Decision Verification Activities
- Verification tests confirm Clean Architecture boundaries via import graph linters.
- Snapshot timings track against instrumentation to verify background execution remains within budget.
- OT correctness validated through synthetic concurrency labs and nightly fuzzers.
- LaunchDarkly evaluation counts monitored to ensure caching logic functions as designed.

<!-- anchor: section-4-12-operational-learning -->
### 4.12 Operational Learning Themes
- Early adopters highlighted the need for memory-aware snapshots; now metrics and deferral messaging bring transparency.
- Collaboration pilots emphasized the value of presence decimation; OT corrections log counts to guide further tuning.
- Import/export QA uncovered the importance of warning reports; documentation now formalizes user messaging on unsupported features.

<!-- anchor: section-4-13-summary -->
### 4.13 Summary Statement
Collectively, these decisions exhibit a bias toward deterministic, inspectable systems where ops, developers, and users trust the workflow. Adhering to AWS, Clean Architecture, OT, and LaunchDarkly ensures the project remains coherent even as scope expands.

<!-- anchor: section-5-5-research-threads -->
### 5.5 Research Threads
- **Timeline Rendering Optimizations:** Investigate WebGPU or Metal compute shaders for faster thumbnail production.
- **AI-assisted Replay Narration:** Explore descriptive overlays that summarize operations for training or review.
- **Adaptive Sampling:** Use machine learning to adjust sampling intervals based on device performance and document complexity.
- **Edge Cache for Collaborations:** Evaluate CloudFront Functions or AWS Global Accelerator to reduce latency for geographically dispersed teams.

<!-- anchor: section-5-6-dependency-watchlist -->
### 5.6 Dependency Watchlist
- **Flutter LTS Cadence:** Ensure desktop stability by tracking Flutter’s release calendar and verifying plugin compatibility.
- **resvg Releases:** Monitor upstream updates for security fixes and rendering improvements; maintain internal regression matrix.
- **LaunchDarkly SDK Changes:** Track API deprecations that might affect offline caching modes.
- **Redis Versioning:** Validate compatibility with cluster mode enhancements and memory optimizations.

<!-- anchor: section-5-7-decommission-plan -->
### 5.7 Decommission & Sunsetting Considerations
- Any component slated for replacement (e.g., telemetry collector revamp) requires migration guides, data export tooling, and rollback plans.
- Deprecation notices must reference blueprint anchors and appear in release notes at least two cycles before removal.
- Ops should maintain dual-running periods to gather parity metrics before retiring legacy services.

<!-- anchor: section-5-8-collaboration-expansion -->
### 5.8 Collaboration Expansion Roadmap
- Extend OT to text editing, typography, and boolean operation flows with tailored transformation rules.
- Add presence indicators to Navigator and layer panels, requiring UI/ops coordination for additional telemetry and capacity planning.
- Enable per-artboard permissions, which will need stronger auth service support and migration scripts for existing documents.
- Investigate mobile companion apps for review-only sessions, leveraging same WebSocket pipeline but with view-only credentials.

<!-- anchor: section-5-9-support-readiness -->
### 5.9 Support & Customer Success Preparations
- Create customer-facing guides covering JSON archive workflows, import warning interpretation, and backup strategies.
- Expand analytics to identify customers approaching event or artboard limits so support can proactively advise on document partitioning.
- Offer success workshops demonstrating collaboration best practices and telemetry opt-out controls for compliance teams.

<!-- anchor: section-6-extended-glossary -->
## 6. Glossary (Extended)
- **A/B Guardrail:** Feature flag practice that requires KPI monitors before enabling experiments broadly.
- **ADR Trail:** Ordered list of ADRs mapping how the architecture evolved over time.
- **Air-Gapped Deployment:** Installation variant with no outbound network access; relies on manual sync of configs, flags, and telemetry.
- **App Bundle Manifest:** Installer-embedded JSON describing baseline configs, feature flags, and checksum data for offline validation.
- **BackgroundWorkerPool:** Client or server orchestrator for CPU-intensive tasks running outside UI threads.
- **ChangeNotifier:** Flutter pattern broadcasting state changes to Provider consumers.
- **Cleanroom Build:** Reproducible build executed in isolated CI to prevent supply-chain tampering.
- **CloudFront:** AWS CDN distributing installers and exported artifacts with signed URLs.
- **Compute() Isolate:** Flutter API for offloading work onto background isolates to avoid blocking main thread.
- **ConfigurationService:** Authoritative source for tunables (sampling rates, snapshot intervals, undo depth); replicates via GraphQL.
- **CR (Change Request):** Documented proposal for modifying infrastructure or runtime behavior, linked to blueprint anchors.
- **DeviceInfo Plugin:** Flutter plugin used to fetch memory data before snapshotting.
- **Drift Detection:** Automated Terraform plan checking for divergences between declared and actual infrastructure.
- **ElastiCache:** AWS managed Redis providing pub/sub, streams, and caching capabilities.
- **EOL (End of Life):** Status assigned when a component is scheduled for removal, triggering decommission plans.
- **FeatureFlagClient Bootstrap:** Cached LaunchDarkly payload enabling offline evaluation until network sync occurs.
- **FileAccessService:** Hardened abstraction for validating file system paths and preventing traversal attacks.
- **Gzip Compression:** Snapshot compression strategy reducing storage overhead for serialized documents.
- **IAM Role:** AWS identity granting least-privilege access to services (S3, RDS, Secrets Manager).
- **Incident Postmortem:** Blameless report analyzing outage causes, mitigation, and action items.
- **JSON Export:** Human-readable document snapshot lacking event history but supporting version control workflows.
- **KPI Gate:** Release requirement linking feature rollout to metric thresholds (e.g., replay rate).
- **LaunchDarkly Relay:** Optional component caching flag data at edge locations for performance.
- **LRU Cache:** Strategy used by replay checkpoint storage to cap memory usage.
- **MDI:** Multiple Document Interface; WireTuner uses Navigator windows to manage multiple artboards and documents.
- **OT Correction Count:** Telemetry metric counting how often operational transforms adjust incoming events.
- **Parameter Store:** AWS service holding non-secret configuration values referenced at runtime.
- **PlantUML:** Diagram-as-code tool used for deployment schematics.
- **PostgreSQL:** Relational database storing collaboration metadata, settings, and audit logs in SyncAPI.
- **Prometheus Exporter:** Endpoint exposing metrics for scraping by Prometheus servers.
- **QuickLook/Explorer Extensions:** macOS/Windows shell extensions rendering `.wiretuner` thumbnails via headless pipeline.
- **Redis Stream:** Data structure providing ordered job queues with consumer groups used by ImportExportService.
- **Route 53:** AWS DNS service performing latency-based routing and failover for collaboration endpoints.
- **Runbook:** Step-by-step operational guide tied to alerts and incidents.
- **S3 Lifecycle Policy:** Automation moving artifacts between storage tiers (Standard, Glacier) based on age.
- **Secrets Manager Rotation:** Automatic update of credentials with notification hooks for dependent services.
- **Snapshot Checkpoint:** ReplayService artifact enabling fast timeline seeking at 1,000-event intervals.
- **Status Pill:** UI indicator reflecting offline/online state or other operational statuses inside WireTuner.
- **Terraform Module:** Reusable IaC component provisioning AWS infrastructure according to blueprint.
- **Telemetry Beacon:** Lightweight payload containing anonymized performance metrics.
- **ToolRegistry:** API allowing registration of new tools while enforcing statelessness.
- **UndoManager:** Service enforcing undo stack depth and clearing redo stacks upon new operations.
- **WebSocket Backpressure:** Mechanism controlling OT event flow to avoid overwhelming clients during surges.
