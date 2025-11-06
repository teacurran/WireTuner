# System Architecture Blueprint: WireTuner

**Version:** 1.0
**Date:** 2025-11-05

---

<!-- anchor: proposed-architecture -->
## 3. Proposed Architecture

<!-- anchor: architectural-style -->
### 3.1. Architectural Style

**Primary Style: Event-Sourced Layered Architecture**

WireTuner employs a hybrid architectural approach combining **Event Sourcing** with a **Layered Architecture** pattern, tailored for desktop application requirements.

<!-- anchor: style-event-sourcing -->
#### Event Sourcing Foundation

**Definition**: All state changes are captured as immutable events stored in an append-only log. The current application state is derived by replaying events from the log.

**Rationale for WireTuner:**
1. **Infinite Undo/Redo**: Natural consequence of event history - navigate forward/backward through events
2. **Audit Trail**: Complete record of user actions enables debugging and workflow analysis
3. **Future Collaboration**: Events are inherently distributable, enabling multi-user editing in future versions
4. **State Recovery**: Snapshots + events provide robust crash recovery
5. **Temporal Queries**: Ability to inspect document state at any point in history

**Key Design Decision**: Sample user interactions at 50ms intervals rather than capturing every mouse movement event. This balances fidelity with storage/replay performance.

<!-- anchor: style-layered -->
#### Layered Architecture Structure

WireTuner organizes code into distinct layers with clear dependencies:

```
┌─────────────────────────────────────────┐
│     Presentation Layer (UI/Widgets)     │  ← Flutter widgets, tools, canvas
├─────────────────────────────────────────┤
│    Application Layer (Use Cases)        │  ← Event handlers, tool controllers
├─────────────────────────────────────────┤
│    Domain Layer (Models & Logic)        │  ← Path, Shape, Document models
├─────────────────────────────────────────┤
│  Infrastructure Layer (Persistence)      │  ← SQLite, file I/O, event store
└─────────────────────────────────────────┘
```

**Rationale:**
- **Separation of Concerns**: Each layer has distinct responsibility
- **Testability**: Domain logic independent of UI framework
- **Maintainability**: Changes to UI don't affect business logic
- **Flutter Compatibility**: Maps well to Flutter's widget-based architecture

<!-- anchor: style-alternatives -->
#### Alternatives Considered

**Microservices Architecture**
- **Rejected**: Overkill for single-user desktop app, adds deployment complexity
- **Future**: Could extract services (rendering, import/export) if needed

**CQRS (Command Query Responsibility Segregation)**
- **Partially Adopted**: Event sourcing naturally separates commands (events) from queries (state reconstruction)
- **Not Full CQRS**: Read models are derived on-the-fly rather than maintained separately for simplicity

**Traditional MVC/MVVM**
- **Rejected**: Doesn't naturally support undo/redo or history tracking
- **Insufficient**: Would require custom undo system, duplicating effort

---

<!-- anchor: technology-stack -->
### 3.2. Technology Stack Summary

<!-- anchor: stack-overview -->
#### Core Platform

| Layer | Technology | Version | Justification |
|-------|-----------|---------|---------------|
| **Framework** | Flutter | 3.16+ | Cross-platform desktop, mature CustomPainter API, strong ecosystem |
| **Language** | Dart | 3.2+ | Required by Flutter, null-safe, good performance |
| **Desktop Targets** | macOS, Windows | - | Primary platforms for professional vector editing |

<!-- anchor: stack-persistence -->
#### Data & Persistence

| Component | Technology | Package/Library | Justification |
|-----------|-----------|-----------------|---------------|
| **Event Store** | SQLite | `sqflite_common_ffi` | Embedded database, ACID compliance, zero-config, portable files |
| **Schema** | SQL DDL | - | Direct SQL for event log, snapshot, document tables |
| **File Format** | .wiretuner (SQLite) | - | Self-contained file format, readable with standard SQLite tools |

<!-- anchor: stack-rendering -->
#### Rendering & Graphics

| Component | Technology | Flutter API | Justification |
|-----------|-----------|-------------|---------------|
| **Canvas** | CustomPainter | `dart:ui` Canvas | Direct control over rendering, 60 FPS capable |
| **Paths** | Path/Bezier | `dart:ui` Path | Native Bezier curve support, efficient rendering |
| **Transforms** | Matrix4 | `vector_math` | Viewport pan/zoom transformations |
| **Hit Testing** | Manual | Custom geometry | Precise selection detection for vector objects |

<!-- anchor: stack-state-management -->
#### State Management

| Component | Technology | Package | Justification |
|-----------|-----------|---------|---------------|
| **App State** | Provider | `provider` 6.0+ | Lightweight, sufficient for single-user desktop app |
| **Event Sourcing** | Custom | - | Purpose-built event recorder, replayer, snapshot manager |
| **Immutability** | Freezed (optional) | `freezed` | Code generation for immutable models with copy constructors |

<!-- anchor: stack-import-export -->
#### Import/Export

| Format | Technology | Package | Purpose |
|--------|-----------|---------|---------|
| **SVG Export** | SVG 1.1 | `xml` | Industry-standard vector format |
| **PDF Export** | PDF 1.7 | `pdf` | Print-ready output |
| **AI Import** | Adobe Illustrator | Custom parser + `pdf` | Legacy file support (AI files are PDF-based) |
| **SVG Import** | SVG 1.1 | `xml` + custom parser | Web vector import |

<!-- anchor: stack-development -->
#### Development & Testing

| Purpose | Technology | Package | Justification |
|---------|-----------|---------|---------------|
| **Unit Tests** | Dart test | `test` | Core logic verification |
| **Widget Tests** | Flutter test | `flutter_test` | UI component testing |
| **Integration Tests** | Flutter integration | `integration_test` | End-to-end workflow testing |
| **Code Coverage** | lcov | - | Track test coverage (target 80%+) |
| **Linting** | Dart analyzer | `analysis_options.yaml` | Code quality enforcement |

<!-- anchor: stack-build-deployment -->
#### Build & Deployment

| Platform | Tooling | Artifacts | Notes |
|----------|---------|-----------|-------|
| **macOS** | `flutter build macos` | .app bundle, .dmg | Notarized for distribution |
| **Windows** | `flutter build windows` | .exe installer | MSIX or Inno Setup installer |
| **CI/CD** | GitHub Actions | - | Automated builds, tests on push |

<!-- anchor: stack-rationale -->
#### Technology Selection Rationale

**Why Flutter for Desktop Vector Editor?**
- **CustomPainter Performance**: Proven 60 FPS rendering capability for complex graphics
- **Cross-Platform**: Single codebase for macOS/Windows reduces maintenance burden
- **Native Compilation**: Dart compiles to native machine code, no runtime overhead
- **Mature Ecosystem**: Strong package ecosystem (PDF, XML, file I/O)
- **Reference Success**: Apps like Rive demonstrate Flutter's suitability for vector editing

**Why SQLite for Event Storage?**
- **ACID Guarantees**: Ensures event log integrity even during crashes
- **Embeddable**: No separate database server, zero configuration
- **Portable Format**: .wiretuner files are standard SQLite databases, tooling available
- **Performance**: Adequate for 50ms sampling rate (20 events/second max)
- **Proven**: SQLite is the most deployed database engine globally

**Why Custom Event Sourcing vs. Library?**
- **Flutter-Specific**: Most event sourcing frameworks target backend systems (Kafka, EventStore)
- **Simplicity**: Custom implementation avoids over-engineering for single-user desktop needs
- **Control**: Full control over event schema, sampling rate, snapshot strategy
- **Learning**: Purpose-built system easier to understand and maintain for single developer

**Why Provider for State Management?**
- **Simplicity**: Adequate for single-user desktop app without complex state needs
- **Flutter-Native**: Official Flutter recommendation, good documentation
- **Lightweight**: Minimal boilerplate compared to BLoC, Redux
- **Sufficient**: Event sourcing handles time-travel, Provider handles UI reactivity

**Rejected Alternatives:**
- **Electron**: Rejected in favor of Flutter for better performance and smaller binary size
- **Native (Swift/C++)**: Rejected due to code duplication for macOS/Windows
- **Web Canvas**: Rejected for desktop-first focus, though Flutter web could be future target
- **PostgreSQL/MongoDB**: Rejected as overkill for single-user local files
