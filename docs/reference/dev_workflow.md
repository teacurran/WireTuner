<!-- anchor: dev-workflow -->
# Developer Workflow Guide

This document provides a comprehensive guide to setting up your development environment, using the provided tooling, and following best practices for contributing to WireTuner.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Development Commands](#development-commands)
4. [Editor Integration](#editor-integration)
5. [Atomic Write Expectations](#atomic-write-expectations)
6. [Diagram Development](#diagram-development)
7. [Testing Strategy](#testing-strategy)
8. [CI/CD Integration](#cicd-integration)
9. [Verification](#verification)
10. [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before you begin, ensure you have the following tools installed:

### Required

- **Flutter SDK** (>=3.5.0): [Installation Guide](https://flutter.dev/docs/get-started/install)
- **Dart SDK** (included with Flutter)
- **Git**: [Installation Guide](https://git-scm.com/downloads)
- **Just**: Command runner for development shortcuts
  - macOS: `brew install just`
  - Windows: `scoop install just` or `choco install just`
  - Linux: `cargo install just` or download from [releases](https://github.com/casey/just/releases)

### Optional but Recommended

- **Melos**: Multi-package workspace management (installed via `just setup`)
  - Manual install: `dart pub global activate melos`
- **PlantUML**: For rendering component, state, and other UML diagrams
  - macOS: `brew install plantuml`
  - Windows: Download `plantuml.jar` from [PlantUML website](https://plantuml.com/download)
  - Linux: `apt-get install plantuml` or download JAR
- **Mermaid CLI**: For rendering sequence, ERD, and timeline diagrams
  - All platforms: `npm install -g @mermaid-js/mermaid-cli`
- **lcov**: For code coverage visualization
  - macOS: `brew install lcov`
  - Linux: `apt-get install lcov`

---

## Initial Setup

After cloning the repository, run the initial setup command:

```bash
just setup
```

This command will:
1. Install Flutter dependencies (`flutter pub get`)
2. Activate melos globally
3. Bootstrap the melos workspace (links all packages)

### Verify Installation

Check that all prerequisites are properly installed:

```bash
just doctor
```

This will display the versions of all required tools and warn about any missing optional dependencies.

---

## Development Commands

WireTuner uses `just` to provide cross-platform development shortcuts that mirror CI workflows. All commands work identically on macOS, Linux, and Windows (with Git Bash or WSL).

### Common Commands

| Command | Description | CI Equivalent |
|---------|-------------|---------------|
| `just setup` | Install all dependencies and bootstrap workspace | N/A |
| `just lint` | Run linting checks across all packages | `tools/lint.sh` |
| `just test` | Run all unit tests | `tools/test.sh` |
| `just format` | Auto-format all Dart code | `melos run format` |
| `just diagrams` | Validate and render all diagrams | `scripts/ci/diagram_check.sh` |
| `just ci` | Run complete CI check suite locally | `scripts/ci/run_checks.sh` |
| `just clean` | Remove build artifacts and dependencies | `melos clean` |
| `just doctor` | Verify development environment setup | N/A |

### Package-Specific Commands

Work with individual packages:

```bash
# Test a specific package
just test-package event_core

# Analyze a specific package
just analyze-package vector_engine
```

### Test Variants

Run specific test suites:

```bash
# Widget tests only
just test-widgets

# Integration tests only
just test-integration

# Generate coverage report
just coverage
```

### Diagram Commands

```bash
# Validate and render all diagrams
just diagrams

# Render a specific diagram
just render-diagram docs/diagrams/component_architecture.puml
```

---

## Editor Integration

### Visual Studio Code

WireTuner includes pre-configured VS Code tasks and launch configurations.

#### Launch Configurations (`.vscode/launch.json`)

Available debug configurations:
- **WireTuner (Debug)**: Launch app in debug mode
- **WireTuner (Profile)**: Launch app in profile mode for performance analysis
- **WireTuner (Release)**: Launch app in release mode
- **Event Core - Unit Tests**: Run event_core package tests
- **Vector Engine - Unit Tests**: Run vector_engine package tests
- **Tool Framework - Unit Tests**: Run tool_framework package tests
- **IO Services - Unit Tests**: Run io_services package tests
- **All Tests (Current File)**: Run tests in currently open file

**Usage**: Press `F5` or select configuration from Run and Debug panel.

#### Tasks (`.vscode/tasks.json`)

Run tasks via `Cmd/Ctrl+Shift+P` → "Tasks: Run Task":

- **Setup: Install Dependencies** - Initial project setup
- **Lint: Run All Checks** - Execute linting (default test task)
- **Test: Run All Tests** - Execute all tests (default test task)
- **Test: Widget Tests Only** - Widget tests only
- **Test: Integration Tests Only** - Integration tests only
- **Test: Coverage Report** - Generate coverage report
- **Format: Format Code** - Auto-format code
- **Diagrams: Validate and Render** - Process all diagrams
- **CI: Run Full CI Checks** - Local CI simulation (default build task)
- **Clean: Remove Build Artifacts** - Clean workspace
- **Doctor: Check Environment** - Verify setup

**Quick Access**:
- Run Build Task: `Cmd/Ctrl+Shift+B` (runs "CI: Run Full CI Checks")
- Run Test Task: `Cmd/Ctrl+Shift+T` (runs "Test: Run All Tests")

### IntelliJ IDEA / Android Studio

Pre-configured run configurations are available in `.idea/runConfigurations/`:

- **Run All Tests**: Execute full test suite
- **Run Lint**: Execute linting checks
- **Run Full CI Checks**: Local CI simulation
- **Validate Diagrams**: Process and validate diagrams

**Usage**:
1. Run configurations appear automatically in the run configurations dropdown (top-right toolbar)
2. Select desired configuration and click Run/Debug button
3. Or use `Ctrl+R` / `Ctrl+D` shortcuts

**Note**: IntelliJ configurations invoke `just` commands under the hood, ensuring consistency with VS Code and CLI workflows.

---

## Atomic Write Expectations

Per [Plan Directive #2](../../.codemachine/artifacts/plan/01_Plan_Overview_and_Setup.md#directives-process), all code modifications must follow the **single atomic write** principle:

### Requirements

1. **Mental Blueprint First**: Before editing any file, construct the complete desired state in your mental model
2. **Single Write Operation**: Stage entire file content in memory, then write via single atomic operation (using `>` redirection or equivalent)
3. **No Incremental Edits**: Avoid partial edits that would violate sampling/undo requirements
4. **Editor Integration**: Configure your editor to save entire buffers atomically

### Why This Matters

- Ensures consistent state for autonomous agents
- Prevents partial file updates during concurrent operations
- Maintains clean diffs and version control history
- Supports reliable rollback and undo operations

### Implementation Tips

- **VS Code**: Files are saved atomically by default
- **IntelliJ**: Files are saved atomically by default
- **CLI Editors**: Use temp files and `mv` for atomic operations
- **Scripts**: Always redirect complete output: `cat content > file` (not `echo line >> file` incrementally)

---

## Diagram Development

WireTuner uses two diagramming formats:

### PlantUML

Used for: Component diagrams, state machines, class diagrams

**File Location**: `docs/diagrams/*.puml`

**Rendering**:
```bash
# Validate and render all diagrams
just diagrams

# Render specific diagram
just render-diagram docs/diagrams/component_architecture.puml
```

**Preview**:
- **VS Code**: Install "PlantUML" extension for live preview
- **IntelliJ**: Built-in PlantUML support (enable in preferences)

**Syntax Reference**: [PlantUML Guide](https://plantuml.com/guide)

### Mermaid

Used for: Sequence diagrams, ERDs, timelines

**File Location**: `docs/diagrams/*.mmd`

**Rendering**:
```bash
# Validate all Mermaid diagrams (included in `just diagrams`)
mmdc -i docs/diagrams/sequence_event_flow.mmd -o docs/diagrams/sequence_event_flow.png
```

**Preview**:
- **VS Code**: Install "Mermaid Preview" extension
- **IntelliJ**: Install "Mermaid" plugin
- **Online**: [Mermaid Live Editor](https://mermaid.live)

**Syntax Reference**: [Mermaid Documentation](https://mermaid.js.org/)

### Diagram Validation in CI

All diagrams are validated and rendered in CI via `scripts/ci/diagram_check.sh`. Local runs via `just diagrams` ensure your diagrams will pass CI before pushing.

---

## Testing Strategy

WireTuner follows a comprehensive testing approach:

### Test Types

1. **Unit Tests** (`test/unit/`, `packages/*/test/`)
   - Test individual functions, classes, and services
   - Fast execution, no external dependencies
   - **Target Coverage**: 80%+

2. **Widget Tests** (`test/widget/`)
   - Test Flutter UI components in isolation
   - Verify canvas rendering, tool interactions, UI state

3. **Integration Tests** (`test/integration/`)
   - End-to-end workflows (save/load, import/export)
   - Multi-component interactions
   - File I/O and persistence validation

### Running Tests

```bash
# All tests
just test

# Specific test suite
just test-widgets
just test-integration

# Package-specific tests
just test-package event_core

# With coverage
just coverage
```

### Test Organization

```
test/
├── unit/           # Unit tests mirroring package structure
├── widget/         # Flutter widget tests for UI components
└── integration/    # End-to-end workflow tests
```

### Writing Tests

Follow Dart test conventions:
- Use `test()` for unit tests
- Use `testWidgets()` for widget tests
- Use `integration_test` package for integration tests
- Group related tests with `group()`
- Use descriptive test names explaining expected behavior

**Example**:
```dart
group('EventStore', () {
  test('should persist events to SQLite', () {
    // Arrange
    final store = EventStore();
    final event = DrawEvent(...);

    // Act
    store.append(event);

    // Assert
    expect(store.length, equals(1));
  });
});
```

---

## CI/CD Integration

### Local CI Simulation

Before pushing, always run the full CI suite locally:

```bash
just ci
```

This executes the same checks that run in GitHub Actions:
1. Lint checks (`flutter analyze`)
2. Format validation (`dart format --output=none --set-exit-if-changed`)
3. Unit tests (`flutter test`)
4. Widget tests
5. Integration tests
6. Diagram validation and rendering
7. SQLite smoke checks

### GitHub Actions Workflow

CI runs automatically on:
- Push to any branch
- Pull requests to `main`

**Workflow File**: `.github/workflows/ci.yml`

**Status Badges**: Available in root `README.md`

### Pre-Push Checklist

✅ Run `just ci` successfully
✅ All tests passing
✅ No lint warnings
✅ Code formatted (`just format`)
✅ Diagrams render without errors
✅ Commit messages follow conventions

---

## Verification

After initial setup, verify everything works:

```bash
# 1. Check environment
just doctor

# 2. Run lint checks
just lint

# 3. Run tests
just test

# 4. Validate diagrams
just diagrams

# 5. Run full CI suite
just ci
```

**Expected Outcome**: All commands should complete successfully with no errors.

---

## Troubleshooting

### Common Issues

#### `just: command not found`

**Solution**: Install just:
- macOS: `brew install just`
- Windows: `scoop install just` or `choco install just`

#### `melos: command not found`

**Solution**: Run `just setup` or manually install:
```bash
dart pub global activate melos
export PATH="$PATH":"$HOME/.pub-cache/bin"  # Add to ~/.bashrc or ~/.zshrc
```

#### PlantUML diagrams not rendering

**Solution**: Install PlantUML:
- macOS: `brew install plantuml`
- Verify: `plantuml -version`

#### Mermaid diagrams not rendering

**Solution**: Install Mermaid CLI:
```bash
npm install -g @mermaid-js/mermaid-cli
mmdc --version  # Verify installation
```

#### Tests failing on Windows

**Issue**: Path separators or shell incompatibilities

**Solution**:
- Use Git Bash or WSL for consistent shell environment
- Ensure `bash` is available in PATH
- Check that file paths use forward slashes in test assertions

#### VS Code tasks not running

**Solution**:
- Ensure `just` is in your PATH
- Reload VS Code window: `Cmd/Ctrl+Shift+P` → "Developer: Reload Window"
- Check Output panel for error details

### Getting Help

If you encounter issues not covered here:

1. Check existing [GitHub Issues](https://github.com/wiretuner/wiretuner-app/issues)
2. Review [Architecture Documentation](../reference/)
3. Consult [ADR (Architectural Decision Records)](../adr/)
4. Open a new issue with:
   - Output of `just doctor`
   - Full error message
   - Steps to reproduce

---

## Additional Resources

- [Plan Overview](../../.codemachine/artifacts/plan/01_Plan_Overview_and_Setup.md)
- [Architecture Overview](../architecture/02_Architecture_Overview.md)
- [Event Schema Reference](../reference/event_schema.md)
- [File Format Specification](../../api/file_format_spec.md)
- [ADRs (Architectural Decision Records)](../adr/)

---

**Last Updated**: 2025-11-08
**Maintained By**: WireTuner Development Team
