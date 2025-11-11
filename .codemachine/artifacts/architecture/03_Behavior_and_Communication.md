<!-- anchor: proposed-architecture-behavioral-view -->
## 3. Proposed Architecture (Behavioral View)

<!-- anchor: api-design-and-communication -->
### 3.7. API Design & Communication

<!-- anchor: api-style -->
#### 3.7.1 API Style
- GraphQL over HTTPS anchors SyncAPI interactions, letting DesktopShell fetch typed document and artboard metadata with schema introspection and SDL-driven client generation.
- SyncAPI mutations encapsulate document lifecycle commands such as createDocument, createArtboard, and renameArtboard, ensuring optimistic UI alignment with event sourcing.
- GraphQL subscriptions are reserved for low-frequency channels like documentPresence when firewall policies prohibit raw WebSockets, providing a fallback consistent with the hybrid directive.
- The collaboration gateway exposes primary WebSocket endpoints for real-time event broadcasting, enabling InteractionEngine instances to stream operation envelopes at <50 ms latency.
- WebSocket messages serialize foundation-defined Event DTOs with UUIDs, microsecond timestamps, and artboard scope, preserving replay fidelity.
- RESTful endpoints exist only for telemetry ingestion, export artifact downloads, and installer update manifests, keeping the API surface minimal and auditable.
- Export jobs use signed REST URLs so that ImportExportService can upload PDF or SVG bundles without keeping long-lived GraphQL connections open.
- All APIs honor TLS 1.3 with mutual trust anchored in the SecurityGateway, guaranteeing encrypted payloads even for on-prem collaborations.
- JWT-based authentication headers accompany every GraphQL and REST call, while WebSocket upgrades embed the token in the initial handshake per blueprint security mandates.
- FeatureFlagClient bootstraps LaunchDarkly or Flagsmith variations via SyncAPI queries so behavioral toggles can be evaluated offline.
- ConfigurationService surfaces adjustable sampling intervals and snapshot thresholds through GraphQL mutations, guaranteeing single source governance.
- The hybrid event sourcing model uses GraphQL queries to pull latest snapshots from SyncAPI when remote collaboration is enabled, harmonizing local SQLite with cloud backups.
- GraphQL pagination is enforced on artboard and event list queries to keep payloads bounded even for documents approaching the 1 000 artboard ceiling.
- Error reporting relies on GraphQL problem details objects, returning machine-readable codes like EVENT_SEQUENCE_GAP alongside operator-friendly remediation text.
- SyncAPI response envelopes include ETag-style hashes with each document summary so DesktopShell can detect drift before requesting heavy deltas.
- WebSocket channels multiplex collaborative edits, cursor presence, and toast hints by tagging each frame with a message type discriminant.
- BackgroundWorkerPool tasks such as AI import emit status over GraphQL subscription topics, enabling NavigatorService to refresh thumbnails automatically when jobs finish.
- The ReplayService accesses remote checkpoints through GraphQL download links when stakeholders need to scrub events recorded on another machine.
- ImportExportService posts job definitions to REST `/exports` with JSON bodies listing artboard scopes, format, and precision hints defined in FR-041.
- TelemetryService ingestion endpoints accept batched JSON arrays so DesktopShell can trickle performance counters without spamming network requests.
- The API style enforces explicit version negotiation via `X-WireTuner-Api-Version` headers, allowing gradual rollout of schema additions without breaking old clients.
- SyncAPI resolvers return feature flag snapshots to freeze experimentation values for the duration of a session as mandated by the rulebook.
- WebSocket keep-alives are structured as Ping/Pong frames with OT state summaries so collaboration sessions can recover sequence numbers after transient drops.
- GraphQL inputs rely on strong scalar types such as `UUID`, `RFC3339DateTime`, and `AnchorVisibilityModeEnum` to reflect the foundation data models exactly.
- Mutation resolvers emit domain events to PostgreSQL and Redis in addition to acknowledging the client, ensuring real-time watchers receive the same canonical payload.
- SyncAPI enforces concurrency control using conditional mutations that carry the last-known snapshotSequence, preventing lost updates when two NavigatorService instances rename the same artboard.
- WebSocket authorization claims include document role (owner, editor, viewer) so CollaborationGateway can down-scope operations like `object.deleted`.
- Export download URLs embed short-lived tokens minted by SecurityGateway and validated by a CDN edge per blueprint security posture.
- AI import submissions travel over GraphQL because they include structured parameter objects plus attachments referencing staged files in object storage.
- JSON archival exports bypass SyncAPI entirely by having DesktopShell stream the snapshot to disk, but GraphQL informs cloud peers that a new archive exists if collaboration is active.
- Settings synchronization flows run through GraphQL `updateSettingsProfile` mutations so macOS and Windows clients stay aligned on grid snapping defaults.
- The API style dictates that replay timelines never stream over WebSocket; instead, DesktopShell downloads checkpoint batches via HTTP to avoid congesting the real-time channel.
- Portable configuration bundles such as sampling presets are retrieved via GraphQL `configurationBundle` queries keyed by semantic version to honor configuration governance rules.
- WebSocket message schemas embed a `protocolVersion` field, enabling the client to upgrade transformation logic when the OT layer evolves.
- SyncAPI includes a `documentHealth` query returning integrity_check results from SQLite so Ops teams can inspect diagnostics before requesting user action.
- The Telemetry REST API distinguishes crash reports from performance metrics with separate endpoints, letting privacy-conscious deployments disable one without affecting the other.
- GraphQL mutation batching is intentionally disabled to keep auditing straightforward, ensuring each operation corresponds to a single event chain in EventStoreService.
- Presence updates that drive remote cursor rendering use GraphQL subscriptions when raw WebSockets are blocked, guaranteeing parity with the preferred transport.
- API error localization strings are requested via GraphQL `uiLocaleCatalog` queries so DesktopShell can show actionable guidance matching the foundation's usability mandates.
- The API style assumes Clean Architecture boundaries; Presentation talks only to SyncAPI or CollaborationGateway while Infrastructure services handle serialization of domain objects for transport.
- Snapshot downloads leverage HTTP range requests to resume partially received blobs, meeting the reliability requirements for large documents.
- WebSocket channels reuse the same JWT refresh cadence as HTTPS calls, with SecurityGateway pushing silent refresh prompts before expiry.
- GraphQL filter arguments accept artboardId arrays so NavigatorService can hydrate only the thumbnails relevant to the visible tab, conserving bandwidth.
- DesktopShell posts `document.saved` markers to the collaboration stream when manual saves occur so remote observers can align reviews with explicit checkpoints.
- The API governance forbids undocumented headers, so all custom metadata rides in GraphQL `extensions` blocks or WebSocket message envelopes defined in Section 5 of the foundation.
- Binary payloads such as thumbnails never traverse GraphQL; instead, BackgroundWorkerPool writes them to S3-compatible storage and returns references, keeping the API purely textual.
- SyncAPI resolvers read from PostgreSQL caches when collaboration snapshots are uploaded, ensuring DesktopShell can bootstrap from the freshest state even before local events exist.
- WebSocket channels expose a `resumeFromSequence` command that InteractionEngine invokes after reconnecting, satisfying the event sourcing consistency guarantees.
- REST download acknowledgments include SHA-256 checksums derived from SnapshotManager to uphold deterministic state validation across platforms.
- API schema documentation is versioned alongside file format updates so Structural_Data and Behavior architects reason from the exact same contracts.

<!-- anchor: communication-patterns -->
#### 3.7.2 Communication Patterns

<!-- anchor: synchronous-patterns -->
##### 3.7.2.1 Synchronous Request/Response Exchanges
- DesktopShell issues GraphQL `documentSummary` queries through SyncAPI at window focus time to hydrate artboard tabs with the latest metadata snapshots.
- NavigatorService performs paginated `artboards` queries when the user scrolls thumbnails, ensuring only visible cards trigger network reads.
- InteractionEngine invokes `createArtboard` mutations whenever the "+" button is confirmed, passing preset enums defined in the foundation data model.
- SettingsService synchronizes sampling presets by calling `updateSettingsProfile`, and the SyncAPI echoes the normalized profile so the UI can show authoritative values.
- ImportExportService triggers `requestExportJob` mutations synchronously to register job intent before handing control to BackgroundWorkerPool.
- SecurityGateway mediates token refresh via the `refreshSession` mutation, and DesktopShell blocks sensitive commands until new credentials arrive.
- ToolingFramework fetches localized UI text using `uiLocaleCatalog` queries at startup, avoiding disk bundling of stale strings.
- FeatureFlagClient pulls environment-specific decisions via `featureFlagSnapshot`, allowing deterministic tool wiring even when offline fallback kicks in later.
- ReplayService requests checkpoint manifests through `timelineCheckpoints` queries prior to heavy scrubbing sessions to pre-plan caching.
- TelemetryService configuration toggles ride through `telemetryPreferences` queries to decide whether to stream counters live or keep them on disk.
- SyncAPI enforces optimistic concurrency on `renameArtboard` mutations by comparing the submitted `modifiedAt` stamp with Postgres state.
- DesktopShell uses `documentHealth` query results to display corruption warnings without forcing the user to navigate to logs manually.
- InteractionEngine resolves artboard background colors via `artboardProperties` queries when new windows open, aligning rendering with server truth.
- Layer panel refreshes rely on `layersByArtboard` queries, returning visible, locked, and zIndex data in one payload to reduce round trips.
- The collaboration roster is bootstrapped via `collaborationSession` queries so presence overlays initialize with accurate participant names.
- Undo depth limits are retrieved synchronously via `configurationBundle` queries ensuring InputEngine matches server-approved budgets.
- Auto-migration notices leverage `migrationStatus` queries, enabling DesktopShell to warn about upcoming file upgrades before the user saves.
- When a manual save occurs, DesktopShell issues `recordSavePoint` mutation so SyncAPI logs the event for remote reviewers.
- NavigatorService refreshes thumbnail metadata after a rename by calling `thumbnailStatus` queries to confirm the background worker picked up the change.
- ImportExportService validates AI import compatibility by issuing `supportedAiFeatures` queries, ensuring UI dialogs report accurate capability sets.
- Tool cursors referencing remote presets reconcile via `toolBehaviorProfile` queries, delivering consistent latency budgets.
- SnapshotManager registers remote backups using `registerSnapshot` mutations, which respond with storage locations and retention timers.
- When the user toggles anchor visibility, DesktopShell persists the preference through `updateDocumentMetadata` mutations executed synchronously.
- The Artboard Navigator tab order is saved via `reorderArtboards` mutation that syncs zOrder integers right after drag release.
- SecurityGateway exposes `listAuthorizedDevices` queries so DesktopShell can inform the user about other active installs before enabling collaboration.
- SyncAPI returns structured errors for invalid dimensions during `createArtboard`, immediately surfacing FR-031 validation results.
- BackgroundWorkerPool polls `exportJobStatus` queries from SyncAPI to display incremental progress bars within the Navigator.
- ReplayService registers timeline bookmarks with `addTimelineMarker` mutations so collaborators can reference the same event numbers.
- The Settings pane retrieves global defaults via `applicationDefaults` queries, ensuring new documents start with consistent anchor modes.
- DesktopShell invokes `closeDocument` mutation when Navigator root closes, letting backend tear down collaboration sessions gracefully.

<!-- anchor: async-patterns -->
##### 3.7.2.2 Asynchronous & Streaming Channels
- CollaborationGateway maintains persistent WebSocket channels that stream `event.broadcast` frames whenever any InteractionEngine commits an operation.
- InteractionEngine sends `event.submit` frames containing batched pointer samples every 200 ms, and the gateway acknowledges with transformed payloads.
- Presence beacons emit `cursor.update` frames at 250 ms cadence so remote windows render co-author cursors smoothly without saturating bandwidth.
- DesktopShell listens for `toast.hint` frames derived from remote assist features, allowing the UX to surface contextual help triggered by collaborators.
- EventStoreService subscribes to Redis pub/sub topics to reflect remote operations into local SQLite when multi-device editing occurs.
- BackgroundWorkerPool pushes `job.completed` frames down WebSocket so NavigatorService can refresh thumbnails instantly after PDF export.
- SnapshotManager publishes `snapshot.ready` events, enabling ReplayService to rebase its checkpoint cache without rescanning the disk.
- TelemetryService streams `perf.sample` frames to backend collectors only when telemetry is enabled, bundling FPS and replay rate counters.
- FeatureFlagClient receives `flag.update` pushes any time Ops toggles a kill-switch, triggering local reevaluation before user restarts the app.
- The grid snapping overlay subscribes to `settings.broadcast` frames so changes applied on one artboard propagate to others inside the same document session.
- CollaborationGateway emits `ot.resync` commands on WebSocket when sequence gaps exceed safe thresholds, telling clients to pull missing events via SyncAPI.
- ImportExportService posts `job.progress` updates into Redis streams which DesktopShell polls via WebSocket `progress.snapshot` frames.
- NavigatorService registers for `artboard.thumbnail_regenerated` events so it can replace stale previews without user interaction.
- ReplayService monitors `history.marker.shared` frames when collaborators drop pins on interesting timeline positions.
- The QuickLook generator inside BackgroundWorkerPool sends `thumbnail.publish` events so Finder/Explorer caches new previews quickly.
- Telemetry sampling leverages asynchronous `perf.alert` frames whenever frame time budgets are exceeded, prompting the UI to display warnings.
- Import pipelines emit `import.warning` frames carrying unsupported feature lists, allowing the UI to show details even while parsing continues.
- EventStoreService writes `database.lock.retry` telemetry events if SQLite contention occurs, and TelemetryService aggregates them for Ops dashboards.
- CollaborationGateway forwards `selection.sync` frames so remote highlight overlays stay accurate across multiple artboard windows.
- DesktopShell dispatches `document.saved` notifications over WebSocket to inform watchers that a stable checkpoint is available.
- SnapshotManager listens for `manual.save` frames to prioritize snapshot creation after explicit user intent.
- The Settings UI subscribes to `configuration.alert` frames so administrators can push mandatory updates, such as reducing undo depth for constrained hardware.
- WebSocket heartbeats double as `latency.sample` frames, giving CollaborationGateway the data it needs to adjust OT timeouts dynamically.
- ImportExportService receives `job.cancel` frames when users abort exports, allowing workers to terminate threads gracefully.
- ReplayService streams `preview.frame` updates to the timeline UI while rewinding, tying directly into the PlantUML-described flows below.
- TelemetryService ack packets include `correlationId` to confirm ingestion and to satisfy observability traceability requirements.
- NavigatorService receives `document.close` pushes when other devices exit, letting it present cleanup prompts to the current user.
- CollaborationGateway emits `rate.limit` frames when a client exceeds event throughput, nudging InteractionEngine to compress updates.
- BackgroundWorkerPool publishes `ai.import.asset` frames once each chunk of converted geometry is ready for insertion, supporting progressive import previews.
- DesktopShell publishes `presence.away` frames when the OS idle timer fires, ensuring other collaborators understand why cursors stopped moving.

<!-- anchor: data-coordination-patterns -->
##### 3.7.2.3 Data Coordination & Storage Workflows
- EventStoreService writes each event to SQLite WAL using blocking transactions, then emits commit notifications so InteractionEngine can finalize operations.
- SnapshotManager deep copies Document aggregates and hands them to BackgroundWorkerPool isolates, ensuring CPU work stays off the UI thread.
- ReplayService consumes snapshot files plus trailing events, verifying state hashes before handing Document objects back to DesktopShell.
- NavigatorService caches thumbnail metadata in memory but consults EventStoreService to confirm timestamps before trusting a cached preview.
- ImportExportService reads vector objects through the domain repository interfaces, never touching SQLite directly, to uphold Clean Architecture boundaries.
- BackgroundWorkerPool jobs write intermediate results into temporary SQLite tables before finalizing them in the main events table for atomicity.
- SettingsService persists per-document preferences inside the Document metadata blob, which SnapshotManager compresses alongside geometry.
- TelemetryService keeps a rolling buffer on disk so offline installations can later upload aggregated stats via REST once network returns.
- CollaborationGateway writes confirmed operations into PostgreSQL to provide a canonical history for analytics even when clients disconnect mid-session.
- SyncAPI replicates document metadata to Redis caches, enabling low-latency reads for dashboards that monitor active sessions.
- ReplayService stores checkpoint caches in an LRU map keyed by sequence number, evicting least-used entries when memory pressure crosses configured limits.
- EventStoreService exposes `operationLog` streams to the Application layer rather than handing out SQL handles, ensuring each consumer respects grouping semantics.
- SnapshotManager tags snapshots with the feature flag bundle used during creation so ReplayService can detect incompatible replays early.
- ImportExportService writes JSON archives to disk first, verifies SHA-256, then copies to user-selected locations to avoid partial corruption.
- BackgroundWorkerPool uses SQS or Redis streams for work dispatch, ensuring tasks such as PDF conversion survive desktop restarts.
- SecurityGateway stores refresh tokens in platform keychains, and InteractionEngine retrieves them only via sanctioned APIs when network calls are needed.
- TelemetryService redacts user-identifying metadata before writing to local logs, storing only hashed document IDs per compliance rule.
- NavigatorService consults EventStoreService to determine artboard zOrder rather than trusting UI state, preventing drift when remote edits occur.
- ReplayService writes timeline scrub caches to a hidden application directory, cleaning them up when documents close to conserve disk.
- SnapshotManager sequences background jobs, ensuring only one snapshot compresses at a time to avoid memory spikes on 4 GB systems.
- BackgroundWorkerPool receives configuration updates about snapshot thresholds through SettingsService so jobs adapt without restarts.
- EventStoreService exposes health metrics via TelemetryService whenever WAL size exceeds safe thresholds, prompting snapshot creation.
- ImportExportService reads per-artboard layer stacks from domain models, then hands them to Exporters that map directly to SVG or PDF structures.
- DesktopShell relies on SettingsService caches to hydrate new artboards with default viewport states even before EventStoreService commits events.
- CollaborationGateway persists audit logs per event, enabling Ops teams to review who performed destructive operations across distributed clients.
- TelemetryService batches log uploads per document to preserve correlation between performance metrics and editing sessions.
- SnapshotManager validates compressed blob checksums against stored hashes before marking snapshots as ready for restore.
- EventStoreService supports manual integrity checks triggered by SyncAPI so remote diagnostics can run without physical access to the machine.
- ReplayService coordinates with NavigatorService so timeline scrubbing updates the correct artboard window even when multiple windows are open.
- SettingsService writes global defaults to JSON config files but replays them into memory via provider streams to keep the UI reactive.

<!-- anchor: observability-control-loops -->
##### 3.7.2.4 Observability & Control Loops
- TelemetryService attaches correlation IDs from InteractionEngine to every log, enabling distributed tracing between client gestures and backend operations.
- Performance overlay metrics feed into TelemetryService, which in turn emits `perf.alert` frames when thresholds from the rulebook are violated.
- FeatureFlagClient logs evaluation events to TelemetryService so Ops know when a flag influenced a behavior, satisfying audit requirements.
- DesktopShell monitors WebSocket RTT and posts `latency.sample` metrics every 30 seconds for CollaborationGateway dashboards.
- EventStoreService exposes `fsync.duration` counters which TelemetryService aggregates to detect slow disks before data loss occurs.
- SnapshotManager publishes `snapshot.duration` metrics and `snapshot.memoryUsage` gauges, both visible in the performance overlay upon request.
- ReplayService computes `replay.hash` and emits them to TelemetryService; mismatches automatically trigger `history.inconsistency` warnings as prescribed.
- ImportExportService measures conversion durations and sends `export.duration` telemetry so the PDF pipeline can be tuned proactively.
- NavigatorService tracks thumbnail regeneration times and logs `thumbnail.latency` metrics whenever FR-039 budgets are exceeded.
- SettingsService writes `config.change` audit entries each time a slider or toggle adjusts sampling intervals, fully traceable by role.
- CollaborationGateway collects OT conflict counts and pushes `ot.conflict` metrics to Prometheus, ensuring concurrency anomalies surface fast.
- BackgroundWorkerPool increments `job.retry` counters for transparency about conversion reliability and SLO adherence.
- TelemetryService respects opt-out flags by queuing but not transmitting metrics, yet still logs that telemetry was disabled for compliance documentation.
- ToolingFramework adds `tool.activation` metrics so product teams can correlate latency with specific tools like Pen or Boolean Ops.
- EventStoreService instrumentation distinguishes between auto-save and manual-save flush durations, enabling targeted optimization.
- ReplayService collects `timeline.seek` histograms to validate the 50 ms seek objective under real workloads.
- DesktopShell forwards `error.dialog` telemetry events including remediation choices, proving FR-4.2 compliance on actionable messages.
- FeatureFlagClient surfaces `flag.failure` logs when remote evaluations fail, and TelemetryService routes them to alerting pipelines.
- NavigatorService provides `window.lifecycle` events so Ops can correlate artboard window churn with memory usage anomalies.
- SecurityGateway emits `auth.failure` counters to highlight repeated invalid token attempts indicative of configuration drift.
- ImportExportService logs `unsupported.feature` lists as telemetry arrays, enabling the roadmap to prioritize the most frequent AI/SVG gaps.
- BackgroundWorkerPool registers `gpu.fallback` events when rendering jobs drop to CPU, linking back to FR-4.5 risk mitigations.
- TelemetryService ensures every metric includes platform tags (macos, windows) for portability verification per NFR-PORT.
- ReplayService notes `checkpoint.hit` vs `checkpoint.miss` to tune cache sizes based on actual usage.
- SettingsService writes `grid.snap.toggle` events so analytics can confirm adoption of the screen-space snapping improvements.
- EventStoreService instrumentation records `redo.stack.cleared` occurrences, giving UX teams insight into branching behaviors.
- CollaborationGateway attaches `user.role` tags to metrics to ensure viewers are not misattributed as editors in dashboards.
- TelemetryService funnels crash dumps into secure storage referenced by correlation IDs, enabling targeted support follow-ups.
- DesktopShell surfaces telemetry opt-out status in the performance overlay, doubling as a user-facing assurance of privacy settings.
- FeatureFlagClient includes evaluation latency metrics so backend toggles stay within the expected <10 ms response window.

<!-- anchor: key-interaction-flows -->
#### 3.7.3 Key Interaction Flows

> **Note:** Detailed PlantUML sequence diagrams for these flows are available in [`docs/diagrams/sequence/`](../../../docs/diagrams/sequence/), including:
> - [`pen_flow.puml`](../../../docs/diagrams/sequence/pen_flow.puml) - Pen tool path creation with event sourcing
> - [`direct_selection_flow.puml`](../../../docs/diagrams/sequence/direct_selection_flow.puml) - Direct selection drag with collaboration
> - [`save_snapshot_flow.puml`](../../../docs/diagrams/sequence/save_snapshot_flow.puml) - Save and snapshot coordination
> - [`import_flow.puml`](../../../docs/diagrams/sequence/import_flow.puml) - SVG/AI import with background processing

<!-- anchor: flow-a-pen-path -->
##### 3.7.3.1 Flow A: Pen Tool Path Creation with Event Sourcing
- Scenario targets Journey 1, focusing on how DesktopShell, ToolingFramework, and InteractionEngine convert pointer gestures into immutable events.
- The flow emphasizes the 200 ms sampling configuration, showing InteractionEngine's feedback loop with EventStoreService and TelemetryService.
- RenderingPipeline paints previews from incremental Document deltas so the user perceives live feedback without waiting for persistence confirmations.
- SnapshotManager does not create a snapshot mid-gesture but remains notified about event counts for future triggers.
- TelemetryService logs tool activation, sampling overhead, and cursor latency to ensure FR-025 compliance.
- Collaboration is optional here; the focus is on single-user determinism while maintaining WebSocket readiness for future expansions.
- The sequence also illustrates how operation boundaries close once the idle timer fires, feeding undo grouping requirements.
- Additional emphasis is placed on overlay toggles so anchor visuals align with the anchor visibility metadata stored earlier.

~~~plantuml
@startuml
actor User as Designer
participant DesktopShell
participant ToolingFramework
participant InteractionEngine
participant RenderingPipeline
participant EventStoreService
participant SnapshotManager
participant TelemetryService

Designer -> DesktopShell: Hover toolbar
DesktopShell -> ToolingFramework: queryActiveTool()
ToolingFramework --> DesktopShell: SelectionTool
Designer -> DesktopShell: Click Pen Tool icon
DesktopShell -> ToolingFramework: activateTool("pen")
ToolingFramework -> InteractionEngine: registerPointerHandlers(penConfig)
InteractionEngine -> TelemetryService: log(tool="pen",action="activation")
TelemetryService --> InteractionEngine: ack

group Pointer down starts operation
Designer -> DesktopShell: PointerDown(canvasPosition)
DesktopShell -> ToolingFramework: dispatchPointerDown(event)
ToolingFramework -> InteractionEngine: startPath(position, modifiers)
InteractionEngine -> EventStoreService: record(CreatePathEvent)
EventStoreService --> InteractionEngine: eventId+sequence
InteractionEngine -> RenderingPipeline: pushPreview(anchors=1)
RenderingPipeline --> InteractionEngine: previewReady
InteractionEngine -> TelemetryService: log(metric="event.latency")
end

loop Anchor sampling every 200ms
Designer -> DesktopShell: Drag pointer
DesktopShell -> ToolingFramework: pointerMove(sample)
ToolingFramework -> InteractionEngine: updateAnchor(sample)
InteractionEngine -> RenderingPipeline: updatePreviewBezier(sample)
RenderingPipeline --> InteractionEngine: previewFrame
InteractionEngine -> EventStoreService: record(path.anchor.moved candidate)
EventStoreService --> InteractionEngine: conditionalAck
InteractionEngine -> TelemetryService: log(metric="sampling.overhead")
end

group Modifier toggles
Designer -> DesktopShell: Press Shift
DesktopShell -> ToolingFramework: propagateModifier(shift=true)
ToolingFramework -> InteractionEngine: enableGridSnap(screenStep=10px)
InteractionEngine -> RenderingPipeline: showSnapGuide()
RenderingPipeline --> InteractionEngine: guideVisible
end

group Pointer up closes path or continues
Designer -> DesktopShell: PointerUp()
DesktopShell -> ToolingFramework: dispatchPointerUp
ToolingFramework -> InteractionEngine: finalizeSegment()
InteractionEngine -> EventStoreService: record(path.anchor.added)
InteractionEngine -> EventStoreService: recordIfClose(FinishPathEvent)
EventStoreService --> InteractionEngine: sequences
InteractionEngine -> RenderingPipeline: commitPath()
RenderingPipeline --> InteractionEngine: commitComplete
InteractionEngine -> TelemetryService: log(metric="operation.duration")
InteractionEngine -> SnapshotManager: notifyEventDelta(delta=3)
SnapshotManager --> InteractionEngine: thresholdPending
end

alt Idle boundary elapsed (>200ms)
InteractionEngine -> EventStoreService: record(operation.ended)
EventStoreService --> InteractionEngine: idleBoundaryAck
else Continued drawing
InteractionEngine -> EventStoreService: keepOperationOpen()
end

note right of InteractionEngine
Undo grouping obeys 200ms idle threshold.
Grid snapping status travels with each event
so replays mirror the same modifier semantics.
end note

note over TelemetryService
Cursor latency and sampling overhead get persisted
for NFR-PERF-004 validation and dashboard surfacing.
end note
@enduml
~~~

<!-- anchor: flow-b-save -->
##### 3.7.3.2 Flow B: Manual Save, Auto-Save, and Snapshot Coordination
- Flow B maps to Journey 3 Save Document, contrasting auto-save triggers with explicit Cmd/Ctrl+S checkpoints.
- It reveals how InteractionEngine first flushes pending events, then records `document.saved` only when meaningful deltas exist.
- SnapshotManager offloads compression to background isolates yet still confirms readiness via NavigatorService.
- SecurityGateway validates target file paths and permissions before disk writes commence.
- TelemetryService captures save durations, fsync timings, and dedup decisions for performance analytics.
- NavigatorService updates status bars and window titles once the save marker materializes.
- The diagram also shows how BackgroundWorkerPool is avoided for local saves but remains available to mirror snapshots to optional cloud storage.
- Idle threshold logic ensures auto-save timers pause while manual saves execute, preventing double flushing.

~~~plantuml
@startuml
actor User as Creator
participant DesktopShell
participant InteractionEngine
participant EventStoreService
participant SnapshotManager
participant SecurityGateway
participant NavigatorService
participant TelemetryService

group Auto-save idle detection
InteractionEngine -> EventStoreService: pendingEvents?
EventStoreService --> InteractionEngine: count>0
InteractionEngine -> EventStoreService: flushAutoSave()
EventStoreService -> TelemetryService: log(metric="autosave.flush")
TelemetryService --> EventStoreService: ack
end

Creator -> DesktopShell: Cmd/Ctrl+S
DesktopShell -> InteractionEngine: requestManualSave()
InteractionEngine -> EventStoreService: ensureAllEventsCommitted()
EventStoreService --> InteractionEngine: currentSequence
InteractionEngine -> EventStoreService: compareWithLastManualSave()
EventStoreService --> InteractionEngine: deltaExists?

alt No new events since last save
InteractionEngine -> DesktopShell: showStatus("No changes to save")
InteractionEngine -> TelemetryService: log(metric="save.skipped")
else New events detected
InteractionEngine -> SecurityGateway: validateFilePath(currentDocument)
SecurityGateway --> InteractionEngine: pathApproved
InteractionEngine -> EventStoreService: record(document.saved)
EventStoreService --> InteractionEngine: saveSequence
InteractionEngine -> SnapshotManager: triggerSnapshotOnSave(sequence)
end

group Snapshot creation in background
SnapshotManager -> SnapshotManager: deepCopyDocument()
SnapshotManager -> TelemetryService: log(metric="snapshot.start")
activate SnapshotManager
SnapshotManager -> SnapshotManager: compressJSON(gzip)
SnapshotManager -> EventStoreService: persistSnapshotBlob()
EventStoreService --> SnapshotManager: stored
SnapshotManager -> TelemetryService: log(metric="snapshot.duration")
SnapshotManager -> NavigatorService: notifySnapshotReady(sequence)
deactivate SnapshotManager
NavigatorService -> DesktopShell: updateStatus("Saved")
end

group UI feedback and dedup markers
DesktopShell -> NavigatorService: removeDirtyIndicator()
NavigatorService --> DesktopShell: indicatorCleared
DesktopShell -> TelemetryService: log(metric="save.duration")
TelemetryService --> DesktopShell: ack
end

note over EventStoreService
Auto-save continues to persist events after a 200ms idle window,
but manual saves pause the timer until persistence completes.
end note

note right of SnapshotManager
Compression runs in an isolate to honor NFR-PERF-006,
with memory checks performed before allocating large buffers.
end note
@enduml
~~~

<!-- anchor: flow-c-artboard-load -->
##### 3.7.3.3 Flow C: Multi-Artboard Document Load and Navigator Activation
- Flow C aligns with Journey 10, showing how NavigatorService auto-opens when a multi-artboard document loads.
- The SecurityGateway validates file access, ensuring sandbox compliance on macOS and Windows.
- SyncAPI provides optional remote metadata when collaboration or cloud backups are active; otherwise EventStoreService reads the local SQLite store.
- ReplayService restores the latest snapshot and replays trailing events to satisfy the <100 ms load target for 10 K events.
- NavigatorService instantiates per-artboard windows with viewport and selection state restored from SettingsService.
- RenderingPipeline paints each window independently, respecting per-artboard state isolation.
- TelemetryService logs load duration, snapshot compression ratio, and viewport restoration success codes.
- The flow illustrates how document tabs appear inside NavigatorService even if the user opened multiple files beforehand.

~~~plantuml
@startuml
actor User as Designer
participant DesktopShell
participant SecurityGateway
participant SyncAPI
participant EventStoreService
participant ReplayService
participant SettingsService
participant NavigatorService
participant RenderingPipeline
participant TelemetryService

Designer -> DesktopShell: Cmd/Ctrl+O
DesktopShell -> SecurityGateway: requestFileAccess()
SecurityGateway --> DesktopShell: fileHandleGranted
DesktopShell -> EventStoreService: openSQLite(fileHandle)
EventStoreService --> DesktopShell: metadataSummary

alt Collaboration-enabled document
DesktopShell -> SyncAPI: query documentSummary(documentId)
SyncAPI --> DesktopShell: artboards + snapshotMetadata
else Local-only document
DesktopShell -> EventStoreService: readLocalMetadata()
EventStoreService --> DesktopShell: artboards + snapshotSequence
end

DesktopShell -> ReplayService: loadSnapshot(sequence)
ReplayService -> EventStoreService: fetchSnapshotBlob(sequence)
EventStoreService --> ReplayService: snapshotBlob
ReplayService -> ReplayService: deserializeDocument()
ReplayService -> EventStoreService: fetchEvents(sequence+1..end)
EventStoreService --> ReplayService: eventStream
ReplayService -> ReplayService: applyEvents()
ReplayService -> TelemetryService: log(metric="replay.rate")
ReplayService --> DesktopShell: hydratedDocument

DesktopShell -> NavigatorService: initializeTabs(document, artboards)
NavigatorService -> SettingsService: fetchViewportState(artboardIds)
SettingsService --> NavigatorService: zoomPanMap
NavigatorService -> RenderingPipeline: openArtboardWindows(zoomPan)
RenderingPipeline --> NavigatorService: windowsReady
NavigatorService -> DesktopShell: showNavigatorWindow()
DesktopShell -> TelemetryService: log(metric="document.load.time")
TelemetryService --> DesktopShell: ack

group Artboard window activation
Designer -> NavigatorService: Click artboard thumbnail
NavigatorService -> RenderingPipeline: openWindowFor(artboard, viewportState)
RenderingPipeline -> EventStoreService: requestArtboardObjects(artboardId)
EventStoreService --> RenderingPipeline: layer + object data
RenderingPipeline -> SettingsService: applyAnchorVisibility(documentPref)
SettingsService --> RenderingPipeline: visibilityMode
RenderingPipeline --> Designer: Rendered artboard window with restored selection
end

note over NavigatorService
Navigator auto-opens for any document with multiple artboards,
and maintains document tabs when several files are active simultaneously.
end note

note over TelemetryService
Load time, replay throughput, and viewport restoration fidelity
are captured for NFR-PERF-001 and NFR-PERF-002 tracking.
end note
@enduml
~~~

<!-- anchor: flow-d-direct-selection -->
##### 3.7.3.4 Flow D: Direct Selection Drag with Collaboration Broadcast
- Flow D mirrors Journey 2 Direct Selection, adding CollaborationGateway streaming to highlight distributed editing.
- ToolingFramework switches to direct selection mode, exposing anchors per FR-024 before any drag begins.
- InteractionEngine records drag start, sampled positions, and drag end events, ensuring `path.anchor.moved` payloads include sampledPath arrays when configured.
- EventStoreService persists each event, then CollaborationGateway distributes OT-transformed versions to remote peers.
- RenderingPipeline provides live screen-space snapping feedback when Shift is pressed, enforcing FR-028 rules.
- BackgroundWorkerPool flushes sampled positions to ensure large drags do not block the UI thread.
- TelemetryService tracks drag duration, sampling overhead, and OT conflict counts for performance dashboards.
- Remote InteractionEngines merge the broadcast events, keeping multi-artboard selection isolation intact.

~~~plantuml
@startuml
actor User as Lead
participant DesktopShell
participant ToolingFramework
participant InteractionEngine
participant RenderingPipeline
participant EventStoreService
participant BackgroundWorkerPool
participant CollaborationGateway
participant TelemetryService

Lead -> DesktopShell: Select Direct Selection Tool
DesktopShell -> ToolingFramework: activateTool("directSelection")
ToolingFramework -> InteractionEngine: registerPointerHandlers(mode="anchors")
InteractionEngine -> RenderingPipeline: showAnchors(mode=document.anchorVisibilityMode)
RenderingPipeline --> InteractionEngine: overlayReady

group Drag initiation
Lead -> DesktopShell: PointerDown(anchor)
DesktopShell -> ToolingFramework: dispatchPointerDown
ToolingFramework -> InteractionEngine: beginAnchorDrag(anchorId)
InteractionEngine -> EventStoreService: record(path.anchor.moved start)
EventStoreService --> InteractionEngine: eventSequence
InteractionEngine -> CollaborationGateway: submitEvent(startPayload)
CollaborationGateway --> InteractionEngine: otAck(sequence)
InteractionEngine -> TelemetryService: log(metric="drag.start")
end

loop Sampled movement every samplingInterval
Lead -> DesktopShell: Drag pointer
DesktopShell -> ToolingFramework: pointerMove(sample)
ToolingFramework -> InteractionEngine: updateAnchor(sample)
InteractionEngine -> RenderingPipeline: updateAnchorPreview(sample)
RenderingPipeline --> InteractionEngine: previewFrame
InteractionEngine -> BackgroundWorkerPool: enqueueSampleSerialization(sample)
BackgroundWorkerPool --> InteractionEngine: sampleSerialized
InteractionEngine -> EventStoreService: record(path.anchor.moved sample)
EventStoreService --> InteractionEngine: sampleSequence
InteractionEngine -> CollaborationGateway: submitEvent(samplePayload)
CollaborationGateway -> CollaborationGateway: applyOTTransform()
CollaborationGateway --> InteractionEngine: broadcastAck
InteractionEngine -> TelemetryService: log(metric="sampling.interval")
end

group Modifier snapping
Lead -> DesktopShell: Hold Shift
DesktopShell -> ToolingFramework: modifierUpdate(shift=true)
ToolingFramework -> InteractionEngine: enforceScreenSpaceSnap(step=10px)
InteractionEngine -> RenderingPipeline: drawSnapGuide()
RenderingPipeline --> InteractionEngine: snapGuideActive
end

group Drag completion
Lead -> DesktopShell: PointerUp
DesktopShell -> ToolingFramework: dispatchPointerUp
ToolingFramework -> InteractionEngine: endAnchorDrag()
InteractionEngine -> EventStoreService: record(path.anchor.moved end)
EventStoreService --> InteractionEngine: finalSequence
InteractionEngine -> CollaborationGateway: submitEvent(endPayload)
CollaborationGateway --> InteractionEngine: otAck
InteractionEngine -> TelemetryService: log(metric="drag.duration")
InteractionEngine -> BackgroundWorkerPool: flushSampleQueue(anchorId)
BackgroundWorkerPool --> InteractionEngine: flushed
end

group Remote propagation
CollaborationGateway -> EventStoreService: appendRemoteEvent(transformed)
EventStoreService --> CollaborationGateway: storedForAnalytics
CollaborationGateway -> TelemetryService: log(metric="ot.conflict",value=0|n)
CollaborationGateway -> DesktopShell: broadcast(selection.sync)
DesktopShell -> RenderingPipeline: applyRemoteSelectionHighlights()
end

note over InteractionEngine
Selection state remains per artboard; remote events targeting other artboards
are ignored by this window but still persist in the event log.
end note

note over TelemetryService
Drag metrics, OT conflicts, and snapping usage feed analytics
that validate FR-028 and FR-050 adoption.
end note
@enduml
~~~

<!-- anchor: dtos -->
#### 3.7.4 Data Transfer Objects

<!-- anchor: dto-create-artboard -->
##### 3.7.4.1 GraphQL Mutation: `createArtboard`
- Request field `documentId: UUID!` identifies the parent document stored in EventStoreService.
- `name: String!` enforces the ≤100 character constraint from the foundation.
- `preset: ArtboardPresetEnum` allows `custom`, `iphone14pro`, `desktophd`, `a4portrait`, or `instagramsquare`, aligning with FR-031 templates.
- `bounds: RectangleInput!` carries `x`, `y`, `width`, `height` doubles, validated for the 100–100 000 px range.
- `backgroundColor: RGBAInput!` stores 8-bit channels encoded as floats 0–1 or hex strings, matching Document metadata rules.
- `viewportState: ViewportInput` optionally persists zoom and pan offsets if the user cloned an artboard.
- `selectionState: SelectionInput` is omitted on create, but schema reserves it to support future duplication flows.
- `zOrder: Int` allows explicit placement; when undefined, SyncAPI inserts at the end.
- `clientRequestId: UUID` lets InteractionEngine correlate responses with optimistic UI state.
- `featureFlags: [String!]` echoes the flags the client considered, aiding server-side auditing.
- Response returns `artboard { id, name, bounds, backgroundColor, preset, zOrder }` so NavigatorService can hydrate UI immediately.
- `operationId: ID!` mirrors the `operation.started` event stored in EventStoreService for undo tracking.
- `thumbnailStatus { state, lastUpdatedAt }` informs whether BackgroundWorkerPool already rendered a preview.
- `warnings: [Warning!]` lists soft validation issues such as near-limit bounds, each with `code`, `message`, and `remediation`.
- `snapshotSequence: Int!` confirms the document sequence when the mutation completed, ensuring DesktopShell can detect drift.

<!-- anchor: dto-document-summary -->
##### 3.7.4.2 GraphQL Query: `documentSummary`
- Request takes `id: UUID!`, `includeArtboards: Boolean`, `includeSnapshots: Boolean`, and optional `artboardLimit`.
- The DTO returns `document { id, name, author, fileFormatVersion, metadata { anchorVisibilityMode, samplingPreset } }`.
- `artboards` is a paginated connection with edges containing `artboard { id, name, bounds, backgroundColor, zOrder, thumbnailRef, viewportState, selectionStateDigest }`.
- Each edge includes `cursor` tokens so NavigatorService can page efficiently.
- `snapshotSequence` and `eventCount` integers help ReplayService decide whether to use cached checkpoints.
- `collaborationStatus { active, participants, otBaselineSequence }` fuels presence indicators.
- `performanceHints { recommendedSnapshotThreshold, recommendedSamplingInterval }` guides SettingsService when remote policies dictate overrides.
- `health { sqliteIntegrity, pendingMigrations, diskUsageBytes }` surfaces Document health diagnostics inline.
- `featureFlags` echoes flag states so Presentation can log deterministic evaluations.
- `lastManualSaveAt` plus `lastAutoSaveAt` timestamps inform status bar badges.

<!-- anchor: dto-event-broadcast -->
##### 3.7.4.3 WebSocket Payload: `event.broadcast`
- Envelope fields: `type="event.broadcast"`, `protocolVersion`, `documentId`, `artboardId`, `sequence`, and `serverTimestamp`.
- `operationId` references the undo grouping so remote clients can align with InteractionEngine boundaries.
- `event` object mirrors EventBase with `eventId`, `eventType`, `userId`, and `eventData`.
- `eventData` for `path.anchor.moved` carries `pathId`, `anchorIndex`, `newPosition {x,y}`, `oldPosition`, `sampledPath[]`, and `gridSnapEnabled`.
- Payload includes `otMetadata { transformed, sourceSequence, priorSequence }` for Operational Transform debugging.
- `cursorHint { screenX, screenY, tool }` enables remote cursor rendering per FR-009 visual feedback requirements.
- `selectionDelta { addedIds[], removedIds[] }` optionally shares selection adjustments.
- `latencyMs` reflects measured RTT when the gateway sent the frame, helping DesktopShell tune smoothing filters.
- `flags { highFidelitySampling, anchorVisibilityMode }` ensures remote clients honor the same visualization context.
- `integrityHash` is the SHA-256 digest of the serialized event, protecting against tampering in transit.

<!-- anchor: dto-export-job -->
##### 3.7.4.4 REST DTO: `/exports` Job Submission and Status
- POST request body includes `documentId`, `artboardScope` array, `format` (`svg`, `pdf`, `json`), and `precisionHint` (e.g., "double" vs "float").
- `includeHistory: Boolean` toggles whether to append metadata describing snapshot sequence numbers inside exported files.
- `colorProfile: String` lets the user select profiles such as `sRGB` or `DisplayP3`.
- `compression: { type: "gzip"|"none", level: Int }` configures archive output.
- `retryPolicy: { maxRetries, backoffMs }` ensures BackgroundWorkerPool honors user expectations for flaky exports.
- Response returns `jobId`, `status="queued"`, `createdAt`, and `estimatedReadyAt`.
- Status polling (`GET /exports/{jobId}`) returns `status`, `progressPercent`, `warnings[]`, and `artifactUrl` when complete.
- `warnings` entries include `code`, `message`, and optionally `affectedObjectIds` (e.g., unsupported SVG filters).
- `artifactUrl` is a signed HTTPS link with `expiresAt` metadata to respect retention policies.
- `checksumSha256` ensures the user verifies downloads before trusting the export in other tools.

<!-- anchor: dto-telemetry-settings -->
##### 3.7.4.5 Telemetry and Settings DTOs
- `perf.sample` POST body fields: `documentId`, `artboardId?`, `fps`, `frameTimeMs`, `eventReplayRate`, `samplingIntervalMs`, `snapshotDurationMs`, `cursorLatencyUs`, and `platform`.
- Optional `flagsActive[]` array correlates performance spikes with feature experiments.
- `telemetryOptIn: Boolean` rides along to prove consent for each batch per compliance guidance.
- Response is `202 Accepted` with `correlationId` used later when crash dumps cite the same editing session.
- `settingsProfile` GraphQL mutation accepts `samplingIntervalMs`, `gridSnapScreenPx`, `undoDepth`, `anchorVisibilityMode`, `telemetryEnabled`, and `nudgePreset`.
- Each field returns `effectiveValue`, `source` (user, policy, default), and `updatedAt`.
- `settingsProfile` response also includes `pendingAdminOverrides` so DesktopShell can warn users about forced changes.
- `configurationBundle` DTOs include `version`, `snapshotThreshold`, `thumbnailIntervalSeconds`, and `maxConcurrentArtboardWindows`.
- These DTOs ensure SettingsService can broadcast consistent behavior across macOS and Windows installations without diverging from the foundation contracts.


<!-- anchor: dto-presence -->
##### 3.7.4.6 GraphQL Subscription: `documentPresence`
- Client supplies `documentId: UUID!` and optional `artboardFilter` to limit presence noise.
- `cursorSamplingMs: Int` hints at how frequently DesktopShell will emit local cursor frames, letting the server enforce quotas.
- Subscription payload includes `user { id, displayName, avatarUrl }` for overlay labels.
- `activity` union distinguishes `editing`, `reviewing`, `idling`, and `offline` states derived from CollaborationGateway timers.
- `selectedArtboardIds[]` communicates which artboards each collaborator has open, helping NavigatorService highlight shared contexts.
- `selectionBounds` summarizes bounding boxes for remote selections without leaking full geometry.
- `cursor { screenX, screenY, tool, pressure? }` mirrors UI cues for co-editors, with optional stylus data when available.
- `latencyMs` tracks per-user round-trip estimates so OT logic can adjust transformation windows.
- `lastEventSequence` indicates which event number the collaborator most recently applied, aiding resynchronization.
- `undoDepthRemaining` exposes how many operations remain in each collaborator's stack, aiding support diagnostics.
- Presence snapshots include `featureFlags[]` so differences in behavior can be correlated during debugging.
- Heartbeat frames include `idleReason` such as `systemIdle`, `networkDrop`, or `manualPause`.
- `deviceInfo { platform, appVersion }` ensures cross-platform parity checks per NFR-PORT.
- The server sends `presence.removed` messages when clients disconnect, prompting DesktopShell to fade cursors gracefully.
- Subscription also emits `documentClosed` events so NavigatorService can prompt the remaining user to save or take ownership.
- Error payloads follow GraphQL spec but include `retryAfterMs` hints when throttling occurs.
- Payloads always carry `protocolVersion` to permit schema evolution without breaking older clients.
- `capabilities { textTool, booleanOps }` flags ensure remote cursors only advertise features actually enabled by feature flags.
- `securityContext { role, authProvider }` travels with each presence entry so UI badges can differentiate viewers from editors.
- Every presence payload includes `timestamp` for ordering plus `signature` generated by SecurityGateway to deter spoofing.

