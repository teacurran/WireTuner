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

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/wiretuner.git
cd wiretuner
```

### 2. Install Dependencies

```bash
flutter pub get
```

For SQLite desktop support, you may need to run:

```bash
flutter pub run sqflite_common_ffi:setup
```

### 3. Verify Installation

Run the analyzer to check for any issues:

```bash
flutter analyze
```

### 4. Run the Application

For macOS:

```bash
flutter run -d macos
```

For Windows:

```bash
flutter run -d windows
```

## Project Structure

WireTuner follows a layered architecture with clear separation of concerns:

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

## Project Status

**Current Phase**: Infrastructure Setup (Iteration 1)

This is an active development project. The current iteration focuses on establishing the project foundation, SQLite integration, and event sourcing infrastructure.

## License

[License information to be added]

## Contributing

This is currently a solo development project. Contribution guidelines will be added once the core architecture is stable.

## Contact

[Contact information to be added]
