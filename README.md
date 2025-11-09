# WireTuner

[![CI](https://github.com/YOUR_USERNAME/WireTuner/actions/workflows/ci.yml/badge.svg)](https://github.com/YOUR_USERNAME/WireTuner/actions/workflows/ci.yml)

A professional event-sourced vector drawing application for macOS and Windows built with Flutter.

## Overview

WireTuner is a desktop vector drawing application designed with an event-sourcing architecture at its core. Every user interaction is recorded as an immutable event, enabling powerful features like unlimited undo/redo, time-travel debugging, and comprehensive document history.

### Key Features

- **Event-Sourced Architecture**: All user interactions recorded with 50ms sampling rate
- **Professional Vector Tools**: ✅ Pen tool with Bezier curves, ✅ Selection tool, shape creation (planned)
- **Tool Framework**: Sub-30ms tool switching, keyboard shortcuts (V, P, A), modifier-driven workflows
- **Direct Manipulation**: ✅ Object selection and movement, anchor/handle manipulation (I4)
- **SQLite Persistence**: Self-contained .wiretuner file format (SQLite database)
- **Import/Export**: Adobe Illustrator import (planned), SVG/PDF export (planned)
- **High Performance**: 60 FPS rendering targeting 10,000+ objects
- **Performance Monitoring**: Real-time FPS and render metrics overlay (toggle with Cmd/Ctrl+Shift+P)

## Prerequisites

- **Flutter**: 3.16.0 or higher
- **Dart**: 3.2.0 or higher
- **macOS**: 10.15 (Catalina) or higher (for macOS builds)
- **Windows**: Windows 10 1809 or higher (for Windows builds)

## Getting Started

### Quick Start with Just

WireTuner provides a streamlined developer experience using `just` for common commands. See the [Developer Workflow Guide](docs/reference/dev_workflow.md) for complete setup instructions.

**Prerequisites**: Install [just](https://github.com/casey/just) command runner:
- macOS: `brew install just`
- Windows: `scoop install just` or `choco install just`

**Initial Setup**:
```bash
# Clone the repository
git clone https://github.com/yourusername/wiretuner.git
cd wiretuner

# Install all dependencies and bootstrap workspace
just setup

# Verify your environment
just doctor
```

**Common Commands**:
```bash
just lint      # Run linting checks
just test      # Run all tests
just diagrams  # Validate and render diagrams
just ci        # Run complete CI suite locally
just --list    # Show all available commands
```

**Editor Integration**: Pre-configured launch and task configurations available for:
- **VS Code**: `.vscode/launch.json` and `.vscode/tasks.json`
- **IntelliJ IDEA**: `.idea/runConfigurations/`

See [Developer Workflow Guide](docs/reference/dev_workflow.md) for editor setup and advanced usage.

### Manual Setup (Alternative)

If you prefer not to use `just`, you can run commands manually:

### 1. Verify Flutter Installation

Before starting, ensure your Flutter environment is correctly configured:

```bash
flutter doctor
```

All checks should pass. If you see any issues, follow the Flutter installation guide at https://docs.flutter.dev/get-started/install.

### 2. Clone the Repository

```bash
git clone https://github.com/yourusername/wiretuner.git
cd wiretuner
```

### 3. Install Dependencies

```bash
flutter pub get
dart pub global activate melos
melos bootstrap
```

**Note**: SQLite desktop support is automatically configured when the application starts. No additional setup command is required.

### 4. Verify Installation

Run the analyzer to check for any issues:

```bash
flutter analyze
```

Run tests to ensure everything is working:

```bash
flutter test
```

### 5. Run the Application

For macOS:

```bash
flutter run -d macos
```

For Windows:

```bash
flutter run -d windows
```

## Workspace Structure (Iteration I1+)

WireTuner uses a **melos-managed monorepo** to organize code into reusable packages. The workspace enables independent development, testing, and versioning of core components.

### Package Overview

```
packages/
├── app_shell/         # Flutter UI shell and window management
├── event_core/        # Event sourcing infrastructure (recorder, replayer, snapshots)
└── vector_engine/     # Vector graphics engine (models, geometry, hit testing)
```

### Workspace Commands

The workspace uses [melos](https://melos.invertase.dev/) for package orchestration. Key commands:

```bash
# Bootstrap the workspace (run once after clone, or after adding packages)
melos bootstrap

# Run static analysis across all packages
melos run analyze

# Run all tests across all packages
melos run test

# Format all Dart files
melos run format

# Check formatting without modifying files
melos run format:check

# Clean all packages
melos run clean

# Run pub get in all packages
melos run get
```

For detailed workspace architecture, see [.codemachine/artifacts/plan/01_Plan_Overview_and_Setup.md#directory-structure](.codemachine/artifacts/plan/01_Plan_Overview_and_Setup.md#directory-structure).

## Legacy Single-Package Structure

The original single-package structure is being migrated to the workspace model:

```
lib/
├── presentation/       # UI Layer (widgets, pages, providers)
├── application/        # Application Layer (tools, use cases, services)
├── domain/            # Domain Layer (models, events, business logic)
├── infrastructure/    # Infrastructure Layer (persistence, event sourcing)
└── utils/             # Shared utilities
```

### Architecture Layers

- **Presentation Layer**: Flutter widgets, UI state management with Provider
- **Application Layer**: Tool implementations, application services, use cases
- **Domain Layer**: Core business logic, immutable models, event definitions
- **Infrastructure Layer**: Event sourcing implementation, SQLite persistence, import/export

## Technology Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Framework | Flutter 3.16+ | Cross-platform desktop UI |
| Language | Dart 3.2+ | Application code |
| State Management | Provider | UI state reactivity |
| Persistence | SQLite (sqflite_common_ffi) | Event store and snapshots |
| Vector Math | vector_math | Geometric calculations |
| Logging | logger | Application diagnostics |
| Code Generation | freezed + build_runner | Immutable model generation |

## Development

### Code Quality

The project enforces strict linting rules configured in `analysis_options.yaml`:

- Type safety enforcement (`avoid_dynamic_calls`, `unnecessary_null_checks`)
- Const constructors and immutability preferences
- Resource cleanup (`cancel_subscriptions`, `close_sinks`)
- Documentation requirements (`public_member_api_docs`)

### Running Tests

```bash
# Unit and widget tests
flutter test

# Integration tests
flutter test integration_test

# Test coverage
flutter test --coverage
```

### Code Generation

For freezed models (when implemented):

```bash
flutter pub run build_runner build
```

### Linting

```bash
flutter analyze
```

### Formatting

```bash
flutter format lib/ test/
```

## Event Sourcing Architecture

WireTuner uses event sourcing as its core architectural pattern:

1. **Event Log**: All user interactions stored as immutable events in SQLite
2. **Snapshots**: Periodic snapshots (every 1000 events) for fast document loading
3. **Replay**: Document state reconstructed by replaying events from last snapshot
4. **Sampling**: Continuous actions (e.g., dragging) sampled at 50ms intervals

### File Format

WireTuner documents use the `.wiretuner` extension, which are standard SQLite database files containing:

- `events` table: Append-only event log
- `snapshots` table: Periodic document state snapshots
- `metadata` table: Document properties (title, version, timestamps)

## Documentation

Detailed documentation is available in the `docs/` directory:

- `docs/diagrams/`: Architecture diagrams (PlantUML)
- `docs/api/`: API documentation and contracts
- `docs/adr/`: Architectural Decision Records
- `docs/reference/`: Reference documentation
  - **[Tooling Overview](docs/reference/tooling_overview.md)**: Complete guide to WireTuner's tool framework, keyboard shortcuts, and visual feedback system (see [I3 plan](.codemachine/artifacts/plan/02_Iteration_I3.md#iteration-3-plan))
  - **[Pen Tool Usage](docs/reference/tools/pen_tool_usage.md)**: Comprehensive reference for pen tool interactions, Bezier curves, modifiers, and event emission
  - **[Developer Workflow Guide](docs/reference/dev_workflow.md)**: Complete guide to development tooling, editor setup, testing, mock events, and CI integration
  - **[Rendering Troubleshooting Guide](docs/reference/rendering_troubleshooting.md)**: Diagnostic procedures for rendering performance issues, including known problems (precision loss, z-fighting, performance dips), diagnostic commands (benchmark harness, performance overlay), and remediation steps with escalation paths
  - **[Overlay Architecture](docs/reference/overlay_architecture.md)**: Z-index management system for coordinating selection boxes, pen previews, snapping guides, and tool overlays with deterministic stacking order
  - [Event Schema Reference](docs/reference/event_schema.md): Universal event metadata, sampling rules, snapshot policy, and collaboration fields
  - [Vector Model Specification](docs/reference/vector_model.md): Immutable domain model structures (Document, Layer, Path, Shape, Segment, Anchor, Style, Transform, Selection, Viewport) with invariants, copyWith patterns, and JSON serialization examples
- `docs/specs/`: Technical specifications
  - [Event Payload Specification](docs/specs/event_payload.md): Per-event field definitions and JSON Schema
  - [Event Lifecycle](docs/specs/event_lifecycle.md): Complete event flow from creation through replay
- `docs/qa/`: Quality assurance and testing
  - **[Tooling QA Checklist](docs/qa/tooling_checklist.md)**: Manual QA procedures, platform parity matrix, performance benchmarks, and telemetry validation for tool framework
- `docs/testing/`: Testing strategy and coverage reports

For comprehensive architecture documentation, see `.codemachine/artifacts/architecture/`.

### Architectural Decision Records

Key architectural decisions are documented in `docs/adr/` following the ADR template format:

| # | Title | Status | Summary |
|---|-------|--------|---------|
| [001](docs/adr/ADR-001-hybrid-state-history.md) | Hybrid State + History Approach | Accepted | Documents the dual persistence strategy combining periodic snapshots (every 1000 events) with append-only event logs, enabling <200ms document loading while preserving complete history for infinite undo/redo and audit trails. |
| [002](docs/adr/ADR-002-multi-window.md) | Multi-Window Document Editing | Accepted | Establishes isolated window state (independent undo stacks, canvas state, metrics) with shared event store via SQLite connection pooling and WAL mode concurrency, supporting professional multi-document workflows. |
| [003](docs/adr/003-event-sourcing-architecture.md) | Event Sourcing Architecture Design | Accepted | Defines the complete event sourcing foundation with 50ms sampling rate, JSON event encoding, periodic snapshots (every 1000 events), and immutable domain models, providing unlimited undo/redo and future collaboration capabilities. |

### Architecture Diagrams

The system architecture is documented through interactive diagrams that illustrate the key components, their responsibilities, and relationships:

**Component Overview Diagram** ([PlantUML source](docs/diagrams/component_overview.puml) | [PNG](docs/diagrams/component_overview.png) | [SVG](docs/diagrams/component_overview.svg))

This C4 component diagram captures the seven major architectural boundaries of WireTuner:

1. **UI Shell & Window Manager** - Flutter widgets, application chrome, menu, window lifecycle
2. **Rendering Pipeline** - CustomPainter for 60 FPS rendering, viewport transforms
3. **Tool Framework** - ITool interface, state machines for selection/pen/shape tools
4. **Event Recorder & Replayer** - 50ms sampler, SQLite event store, snapshot manager, undo navigator
5. **Vector Engine** - Immutable data models: paths, shapes, anchors, styles, geometry utilities
6. **Persistence Services** - SQLite event store, snapshot manager, file versioning
7. **Import/Export Services** - AI/SVG import, SVG/PDF export modules

The diagram includes metadata (version, date, references) and a comprehensive legend mapping components to architectural decisions (1-7) detailed in [Section 2 Core Architecture](.codemachine/artifacts/plan/01_Plan_Overview_and_Setup.md#core-architecture).

**Event Flow Sequence Diagram** ([Mermaid source](docs/diagrams/event_flow_sequence.mmd) | [PNG](docs/diagrams/event_flow_sequence.png) | [SVG](docs/diagrams/event_flow_sequence.svg))

This sequence diagram illustrates the complete event sourcing lifecycle, showing the flow from user input through event recording, sampling, persistence, snapshot management, and replay:

- **Pointer Input → Sampler → Event Recorder**: 50ms sampling for high-frequency inputs (drag operations)
- **Event Recorder → SQLite → Snapshot Manager**: Event persistence with snapshot creation every 500 events
- **Snapshot Manager → Event Replayer → Provider**: Document reconstruction and UI notification

The diagram includes Decision 1 KPIs and logging touchpoints:
- Document load time: <100ms (final state only)
- History replay: 5K events/second playback rate
- Snapshot creation: <25ms latency, every 500 events
- Replay section latency: <100ms

**Data and Snapshot ERD** ([Mermaid source](docs/diagrams/data_snapshot_erd.mmd) | [PNG](docs/diagrams/data_snapshot_erd.png) | [SVG](docs/diagrams/data_snapshot_erd.svg) | [Documentation](docs/diagrams/data_snapshot_erd.md))

This Entity-Relationship Diagram documents the persistent SQLite schema for WireTuner's event-sourced architecture:

- **metadata** table: Document-level properties (title, version, timestamps)
- **events** table: Append-only event log with 50ms sampling (Decision 5)
- **snapshots** table: Periodic document state captures every 1000 events (Decision 6)

The diagram shows table relationships, foreign key constraints, and includes annotations for:
- Snapshot cadence and compression methods (gzip)
- Performance indexes (`idx_events_document_sequence`, `idx_snapshots_document`)
- Future cache tables (rendered paths, spatial index, thumbnails)

See [Data and Snapshot ERD Documentation](docs/diagrams/data_snapshot_erd.md) for complete schema rationale, validation checklist, and architectural decision references.

**Undo/Redo Timeline** ([Mermaid source](docs/diagrams/undo_timeline.mmd) | [PNG](docs/diagrams/undo_timeline.png) | [SVG](docs/diagrams/undo_timeline.svg))

This sequence diagram illustrates the complete undo/redo navigation lifecycle in WireTuner:

- **Operation Grouping**: 200ms idle threshold detection for atomic undo boundaries (Decision 7)
- **Undo Navigation**: Time-travel to previous operation using nearest snapshot
- **Redo Navigation**: Forward navigation through operation history
- **Branch Invalidation**: Automatic clearing of redo history when new actions occur after undo

The diagram shows the interaction between:
- Operation Grouping Service with 200ms idle threshold
- Undo Navigator for time-travel operations
- Snapshot Store for efficient replay (snapshots every 1,000 events)
- Event Store for complete operation history

Includes Iteration 4 KPIs:
- Undo latency: <80ms (snapshot optimization)
- History scrubbing: 5,000 events/sec playback rate
- Multi-window coordination with isolated undo stacks

See [Undo Label Reference](docs/reference/undo_labels.md) for operation naming conventions and UI integration.

**Tool Framework State Machine** ([PlantUML source](docs/diagrams/tool_framework_state_machine.puml) | [PNG](docs/diagrams/tool_framework_state_machine.png) | [SVG](docs/diagrams/tool_framework_state_machine.svg))

This state machine diagram documents the complete behavior of WireTuner's three foundational tools:

- **Selection Tool**: Object selection via click or marquee, drag-to-move with 50ms sampled events
- **Direct Selection Tool**: Anchor point and Bezier control point manipulation
- **Pen Tool**: Path creation with straight line and Bezier curve segments

The diagram includes:
- State transitions with guard conditions (drag distance thresholds, hover detection)
- Event emissions with undo grouping markers (StartGroupEvent, EndGroupEvent)
- 50ms sampling annotations for high-frequency drag operations (Decision 5)
- Modifier key behaviors (Shift for angle constraint, Alt for independent handles)
- Complete event sequences with eventId, timestamp, and eventType specifications

See [Event Schema Reference](docs/reference/event_schema.md) for detailed event payload specifications.

**Diagram Validation:**
```bash
# Component Overview (PlantUML)
plantuml -checkonly docs/diagrams/component_overview.puml
bash tools/scripts/render_diagram.sh docs/diagrams/component_overview.puml svg
bash tools/scripts/render_diagram.sh docs/diagrams/component_overview.puml png

# Tool Framework State Machine (PlantUML)
plantuml -checkonly docs/diagrams/tool_framework_state_machine.puml
bash tools/scripts/render_diagram.sh docs/diagrams/tool_framework_state_machine.puml svg
bash tools/scripts/render_diagram.sh docs/diagrams/tool_framework_state_machine.puml png

# Event Flow Sequence (Mermaid)
# Requires: npm install -g @mermaid-js/mermaid-cli
mmdc -i docs/diagrams/event_flow_sequence.mmd -o docs/diagrams/event_flow_sequence.svg
mmdc -i docs/diagrams/event_flow_sequence.mmd -o docs/diagrams/event_flow_sequence.png

# Data and Snapshot ERD (Mermaid)
mmdc -i docs/diagrams/data_snapshot_erd.mmd -o docs/diagrams/data_snapshot_erd.svg
mmdc -i docs/diagrams/data_snapshot_erd.mmd -o docs/diagrams/data_snapshot_erd.png

# Undo/Redo Timeline (Mermaid)
mmdc -i docs/diagrams/undo_timeline.mmd -o docs/diagrams/undo_timeline.svg
mmdc -i docs/diagrams/undo_timeline.mmd -o docs/diagrams/undo_timeline.png
```

## Project Status

**Current Phase**: Tool Framework & Vector Tooling (Iteration 3 Complete)

This is an active development project. Iteration 3 delivered a robust tool framework with selection and pen tool implementations, overlay feedback system, and comprehensive testing infrastructure. See the [I3 Plan](.codemachine/artifacts/plan/02_Iteration_I3.md#iteration-3-plan) for details.

**Recently Completed (I3):**
- ✅ Tool framework with sub-30ms switching
- ✅ Selection tool (click, marquee, multi-select)
- ✅ Pen tool with Bezier curves and handle manipulation
- ✅ Overlay layer system for visual feedback
- ✅ Cross-platform QA (macOS + Windows parity)

**Next Up (I4):**
- Direct selection tool for anchor manipulation
- Shape tools (rectangle, ellipse, polygon, star)
- Undo/redo orchestration with grouped events

## License

[License information to be added]

## Contributing

### Setup Checklist for Contributors

Before starting development, ensure your environment meets all requirements:

1. **Verify Flutter Environment**
   ```bash
   flutter doctor
   ```
   All checks must pass (✓). Address any issues before proceeding.

2. **Install Project Dependencies**
   ```bash
   flutter pub get
   ```

3. **Run Code Generation** (if working with models)
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. **Verify Code Quality**
   ```bash
   flutter analyze
   dart format --set-exit-if-changed lib/ test/
   flutter test
   ```
   All commands must succeed without errors or warnings.

5. **Test Platform Builds**
   - macOS: `flutter build macos --debug`
   - Windows: `flutter build windows --debug`

### Development Workflow

1. **Before Committing**:
   - Run `flutter analyze` - must pass with zero issues
   - Run `flutter test` - all tests must pass
   - Run `dart format lib/ test/` - format all code
   - Verify your changes build on target platform

2. **Code Style**:
   - Follow strict linting rules in `analysis_options.yaml`
   - Use `logger` package for logging, NOT `print()` statements
   - All public APIs must have documentation comments
   - Prefer immutable data structures (const, final)

3. **Commit Messages**:
   - Follow conventional commits format: `type(scope): description`
   - Types: feat, fix, docs, refactor, test, chore
   - Example: `feat(persistence): add event snapshot compression`

### Continuous Integration

All pull requests are automatically validated via GitHub Actions CI with parallel jobs:

**Automated Checks:**
- **Lint & Analyze** - `flutter analyze` with warnings as errors (macOS + Windows)
- **Format Check** - `dart format` validation (macOS + Windows)
- **Tests** - Full test suite + SQLite smoke tests (macOS + Windows)
- **Diagram Validation** - PlantUML and Mermaid syntax checks (macOS)
- **Build Verification** - Debug builds for both platforms

**Run Locally:**
```bash
# Run all CI checks locally
./scripts/ci/run_checks.sh

# Run individual checks
bash tools/lint.sh          # Linting
bash tools/test.sh          # Tests
./scripts/ci/diagram_check.sh  # Diagrams
dart format lib/ test/      # Fix formatting
```

**Documentation:**
- CI Scripts: `scripts/ci/README.md`
- Workflow Definition: `.github/workflows/ci.yml`

The CI pipeline uses aggressive caching for Flutter SDK and pub dependencies to minimize build times.

## Contact

[Contact information to be added]
