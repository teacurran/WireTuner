# WireTuner

A professional event-sourced vector drawing application for macOS and Windows built with Flutter.

## Overview

WireTuner is a desktop vector drawing application designed with an event-sourcing architecture at its core. Every user interaction is recorded as an immutable event, enabling powerful features like unlimited undo/redo, time-travel debugging, and comprehensive document history.

### Key Features (Planned)

- **Event-Sourced Architecture**: All user interactions recorded with 50ms sampling rate
- **Professional Vector Tools**: Pen tool (straight/Bezier), selection tools, shape creation
- **Direct Manipulation**: Drag objects, anchor points, and Bezier control points
- **SQLite Persistence**: Self-contained .wiretuner file format (SQLite database)
- **Import/Export**: Adobe Illustrator import, SVG/PDF export
- **High Performance**: 60 FPS rendering targeting 10,000+ objects

## Prerequisites

- **Flutter**: 3.16.0 or higher
- **Dart**: 3.2.0 or higher
- **macOS**: 10.15 (Catalina) or higher (for macOS builds)
- **Windows**: Windows 10 1809 or higher (for Windows builds)

## Getting Started

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
- `docs/testing/`: Testing strategy and coverage reports

For comprehensive architecture documentation, see `.codemachine/artifacts/architecture/`.

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

**Diagram Validation:**
```bash
# Validate PlantUML syntax
plantuml -checkonly docs/diagrams/component_overview.puml

# Regenerate PNG/SVG outputs
bash tools/scripts/render_diagram.sh docs/diagrams/component_overview.puml svg
bash tools/scripts/render_diagram.sh docs/diagrams/component_overview.puml png
```

## Project Status

**Current Phase**: Infrastructure Setup (Iteration 1)

This is an active development project. The current iteration focuses on establishing the project foundation, SQLite integration, and event sourcing infrastructure.

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

All pull requests are automatically validated via GitHub Actions CI:
- Analyzer checks (warnings treated as errors)
- Code formatting verification
- Full test suite execution
- Platform-specific builds (macOS and Windows)

Reference: `.github/workflows/ci.yml`

## Contact

[Contact information to be added]
