# WireTuner Documentation

This directory contains comprehensive documentation for the WireTuner vector graphics editor, including architecture diagrams, ADRs (Architecture Decision Records), and supporting technical documentation.

## Table of Contents

- [Architecture Diagrams](#architecture-diagrams)
- [Architecture Decision Records (ADRs)](#architecture-decision-records-adrs)
- [Rendering Diagrams](#rendering-diagrams)

---

## Architecture Diagrams

WireTuner follows the [C4 model](https://c4model.com/) for architecture documentation, providing multiple levels of abstraction from system context down to component details.

### System Context Diagram (C4 Level 1)

**Location:** [`diagrams/system_context.puml`](diagrams/system_context.puml) | [PNG](diagrams/system_context.png) | [SVG](diagrams/system_context.svg)

The system context diagram situates WireTuner Desktop Application within its ecosystem of designers, reviewers, OS services, collaboration infrastructure, feature flag services, telemetry, and conversion workers. It shows the Clean Architecture client as the central system boundary and illustrates how WireTuner interacts with:

- **Primary Users:** Professional Designers, Design Leads, QA Engineers, Support Engineers
- **Cloud Services:** Collaboration Gateway, Sync API, Telemetry Service, Feature Flag Platform
- **Platform Integrations:** macOS QuickLook, Windows Explorer extensions
- **External Systems:** Identity Providers, Redis Cluster, Object Storage, Conversion Workers

**Key Highlights:**
- TLS 1.3 encrypted communication for all cloud services
- OAuth 2.0/OIDC authentication with JWT token management
- Event sourcing architecture with SQLite event store (ADR-003)
- Real-time collaboration via WebSocket and Operational Transform

---

### Container Diagram (C4 Level 2)

**Location:** [`diagrams/deployment.puml`](diagrams/deployment.puml) | [PNG](diagrams/deployment.png) | [SVG](diagrams/deployment.svg)

The container diagram decomposes WireTuner into deployable/run-time units, showing the internal structure and technology choices for each container:

**Desktop Runtime:**
- **WireTuner Desktop Application** (Flutter 3.x): Clean Architecture layers orchestrating all desktop functionality
- **Embedded Event Store** (SQLite 3.x WAL): Append-only event log with periodic snapshots
- **BackgroundWorkerPool** (Flutter isolates + Rust resvg): Non-blocking background processing
- **Platform Extensions:** QuickLook (macOS), Explorer Handler (Windows)

**Cloud Services:**
- **Collaboration Gateway** (Dart Frog WebSocket): OT sequencing and presence
- **Sync API** (Dart Frog GraphQL/REST): Metadata and snapshot synchronization
- **Telemetry Collector** (Prometheus/OpenTelemetry): Metrics and trace aggregation
- **Feature Flag Service** (LaunchDarkly/Flagsmith): Configuration rollouts
- **Data Stores:** Redis Cluster (Pub/Sub), PostgreSQL 14+ (metadata), S3 (artifacts)
- **Conversion Workers** (Rust resvg): SVG→PDF background conversion
- **Observability Stack** (Grafana/Loki/CloudWatch): Dashboards and alerts

**Key Highlights:**
- Clean separation of desktop runtime and cloud services
- Background job processing via Redis Streams
- Feature flag-driven rollouts with emergency kill switches
- Comprehensive observability with OpenTelemetry correlation IDs

---

### Component Diagram (C4 Level 3)

**Location:** [`diagrams/component_overview.puml`](diagrams/component_overview.puml) | [PNG](diagrams/component_overview.png) | [SVG](diagrams/component_overview.svg)

The component diagram dissects the WireTuner Desktop Application into its internal modules, organized by Clean Architecture layers:

**Component Boundaries:**
1. **UI Shell & Window Manager:** Main Window, Toolbar, Tool Panel, Canvas Widget, Dialogs
2. **Rendering Pipeline:** Vector Painter (CustomPainter), Curve Tessellator
3. **Tool Framework:** Tool Manager, ITool interface implementations (Pen, Selection, Direct Selection, Shape tools)
4. **Event Recorder & Replayer:** Event Recorder (50ms sampling), Snapshot Manager (1000-event snapshots), Event Navigator (undo/redo)
5. **Vector Engine:** Immutable domain models (Document, Path, Shape, Anchor), Geometry Services
6. **Persistence Services:** SQLite Repository, Event Store, Schema Manager
7. **Import/Export Services:** SVG/AI import, SVG/PDF export adapters

**Key Highlights:**
- Strict adherence to Clean Architecture boundaries
- Event sourcing with 50ms sampling rate (ADR-003)
- Immutable Freezed domain models (ADR-004)
- Provider-based state management
- 60 FPS rendering target with GPU acceleration

---

## Architecture Decision Records (ADRs)

ADRs document significant architectural decisions made during the development of WireTuner. Each ADR captures the context, decision, consequences, and alternatives considered.

### Available ADRs

- **[ADR-003: Event Sourcing Architecture](adr/003-event-sourcing-architecture.md)**
  - Complete event sourcing with SQLite append-only log
  - 50ms sampling rate for high-frequency input
  - Periodic snapshots every 1000 events
  - Immutable domain models with Freezed
  - Enables unlimited undo/redo, crash recovery, and future collaboration

---

## Rendering Diagrams

All PlantUML diagrams can be rendered to PNG or SVG using the provided rendering script.

### Prerequisites

Ensure PlantUML is installed on your system:

```bash
# macOS (via Homebrew)
brew install plantuml

# Ubuntu/Debian
sudo apt-get install plantuml

# Or download the JAR directly from plantuml.com
```

### Rendering Commands

Use the `render_diagram.sh` script to generate PNG and SVG outputs:

```bash
# Render a specific diagram to PNG
./tools/scripts/render_diagram.sh docs/diagrams/system_context.puml png

# Render a specific diagram to SVG
./tools/scripts/render_diagram.sh docs/diagrams/deployment.puml svg

# Render all diagrams (both PNG and SVG)
for diagram in docs/diagrams/*.puml; do
  ./tools/scripts/render_diagram.sh "$diagram" png
  ./tools/scripts/render_diagram.sh "$diagram" svg
done
```

### CI Integration

Diagram validation and rendering is automated in the CI/CD pipeline. Pull requests will fail if:
- PlantUML source files fail to compile
- Rendered PNG/SVG outputs are missing or out of sync with source files
- Required anchor comments are missing

---

## Additional Documentation

- **Architecture Blueprint:** [`.codemachine/artifacts/architecture/02_System_Structure_and_Data.md`](../.codemachine/artifacts/architecture/02_System_Structure_and_Data.md) - Comprehensive system structure documentation
- **Plan Overview:** [`.codemachine/artifacts/plan/01_Plan_Overview_and_Setup.md`](../.codemachine/artifacts/plan/01_Plan_Overview_and_Setup.md) - Core architecture and technology stack
- **Iteration Plans:** [`.codemachine/artifacts/plan/`](../.codemachine/artifacts/plan/) - Detailed iteration breakdowns

---

## Contributing to Documentation

When updating architecture diagrams:

1. Edit the `.puml` source files in `docs/diagrams/`
2. Ensure anchor comments are present for cross-referencing (e.g., `/' anchor: system-context '/`)
3. Update version metadata blocks with current date and version number
4. Render both PNG and SVG outputs using `render_diagram.sh`
5. Update this README if adding new diagrams or significant content
6. Reference relevant ADRs in diagram legends
7. Verify diagrams compile in CI before merging

For questions or clarifications, consult the architecture team or refer to the comprehensive blueprint in `.codemachine/artifacts/architecture/`.
