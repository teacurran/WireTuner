# WireTuner Development Commands
# Cross-platform shortcuts mirroring CI workflows

# Default recipe - show available commands
default:
    @just --list

# Initial project setup - install dependencies
setup:
    @echo "Installing Flutter dependencies..."
    @flutter pub get
    @echo "Installing melos..."
    @dart pub global activate melos
    @echo "Bootstrapping melos workspace..."
    @melos bootstrap
    @echo "Setup complete! Run 'just --list' to see available commands."

# Run all lint checks
lint:
    @bash tools/lint.sh

# Run all tests
test:
    @bash tools/test.sh

# Format code
format:
    @echo "Formatting code..."
    @melos run format

# Validate and render all diagrams
diagrams:
    @bash scripts/ci/diagram_check.sh

# Run full CI checks locally
ci:
    @bash scripts/ci/run_checks.sh

# Clean build artifacts and dependencies
clean:
    @echo "Cleaning build artifacts..."
    @melos clean
    @flutter clean

# Rebuild after clean
rebuild: clean setup

# Run a specific package's tests (usage: just test-package event_core)
test-package PACKAGE:
    @echo "Running tests for {{PACKAGE}}..."
    @cd packages/{{PACKAGE}} && flutter test

# Analyze a specific package (usage: just analyze-package event_core)
analyze-package PACKAGE:
    @echo "Analyzing {{PACKAGE}}..."
    @cd packages/{{PACKAGE}} && flutter analyze

# Render a specific PlantUML diagram (usage: just render-diagram docs/diagrams/component_architecture.puml)
render-diagram PATH:
    @bash tools/scripts/render_diagram.sh {{PATH}}

# Run widget tests
test-widgets:
    @echo "Running widget tests..."
    @melos run test:widget

# Run integration tests
test-integration:
    @echo "Running integration tests..."
    @melos run test:integration

# Check code coverage
coverage:
    @echo "Generating coverage report..."
    @melos run test:coverage

# Verify all prerequisites are installed
doctor:
    @echo "Checking development environment..."
    @echo "\n=== Flutter ==="
    @flutter --version
    @echo "\n=== Melos ==="
    @melos --version || echo "❌ melos not found - run 'just setup'"
    @echo "\n=== PlantUML ==="
    @plantuml -version || echo "⚠️  PlantUML not found - see docs/reference/dev_workflow.md"
    @echo "\n=== Mermaid CLI ==="
    @mmdc --version || echo "⚠️  Mermaid CLI not found - see docs/reference/dev_workflow.md"
    @echo "\n=== Git ==="
    @git --version
