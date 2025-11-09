# CI Scripts Documentation

This directory contains scripts for running continuous integration checks both locally and in GitHub Actions.

## Overview

The CI pipeline validates code quality, tests, diagrams, and builds across macOS and Windows platforms. All checks can be run locally using the provided scripts.

## Scripts

### `run_checks.sh` - Main CI Orchestrator

Runs all CI checks in sequence, mirroring what happens in GitHub Actions.

**Usage:**
```bash
# Run all checks
./scripts/ci/run_checks.sh

# Skip specific checks
./scripts/ci/run_checks.sh --skip-diagrams
./scripts/ci/run_checks.sh --skip-test
./scripts/ci/run_checks.sh --skip-lint
./scripts/ci/run_checks.sh --skip-format

# Show help
./scripts/ci/run_checks.sh --help
```

**What it checks:**
1. **Flutter Analyze** - Linting and static analysis
2. **Format Check** - Code formatting validation
3. **Tests** - Full test suite execution
4. **Diagrams** - PlantUML and Mermaid syntax validation
5. **SQLite Smoke Tests** - Basic persistence checks (if available)

**Exit codes:**
- `0` - All checks passed
- `1` - One or more checks failed

---

### `diagram_check.sh` - Diagram Validation

Validates PlantUML (`.puml`) and Mermaid (`.mmd`) diagram syntax.

**Usage:**
```bash
# Validate diagrams in default directory (docs/diagrams)
./scripts/ci/diagram_check.sh

# Validate diagrams in custom directory
./scripts/ci/diagram_check.sh path/to/diagrams
```

**Requirements:**
- **PlantUML**: Install via `brew install plantuml` (macOS) or download `plantuml.jar`
- **Mermaid CLI**: Install via `npm install -g @mermaid-js/mermaid-cli`

**Exit codes:**
- `0` - All diagrams valid
- `1` - Validation failures detected
- `2` - Required tools not found

---

## Local Setup

### Prerequisites

1. **Flutter SDK** (3.16.0+)
   ```bash
   flutter --version
   ```

2. **PlantUML** (for diagram validation)
   ```bash
   # macOS
   brew install plantuml

   # Alternative: Download plantuml.jar
   # https://plantuml.com/download
   ```

3. **Mermaid CLI** (for diagram validation)
   ```bash
   npm install -g @mermaid-js/mermaid-cli
   ```

4. **Java** (for PlantUML, if using .jar)
   ```bash
   # macOS
   brew install openjdk@17
   ```

### Running Checks Locally

**Quick validation before commit:**
```bash
# Run all CI checks
./scripts/ci/run_checks.sh
```

**Individual checks:**
```bash
# Just linting
bash tools/lint.sh

# Just tests
bash tools/test.sh

# Just diagrams
./scripts/ci/diagram_check.sh

# Just formatting
dart format --set-exit-if-changed lib/ test/
```

**Fix formatting issues:**
```bash
dart format lib/ test/
```

---

## GitHub Actions CI Pipeline

The CI pipeline is defined in `.github/workflows/ci.yml` and runs automatically on:
- Pushes to `main`, `develop`, or `codemachine/**` branches
- Pull requests to `main` or `develop`

### Pipeline Jobs

#### 1. **Lint & Analyze** (Parallel)
- Runs on: macOS + Windows matrix
- Checks: `flutter analyze`, `dart format`
- Caching: Flutter SDK, pub dependencies

#### 2. **Tests** (Parallel)
- Runs on: macOS + Windows matrix
- Checks: `flutter test`, SQLite smoke tests
- Caching: Flutter SDK, pub dependencies

#### 3. **Diagram Validation** (Parallel)
- Runs on: macOS only
- Checks: PlantUML syntax, Mermaid syntax
- Caching: PlantUML JAR, npm packages

#### 4. **Build Verification** (Sequential, after lint & test)
- Runs on: macOS + Windows matrix
- Checks: Debug builds for each platform
- Caching: Flutter SDK, pub dependencies

#### 5. **CI Summary** (Final)
- Runs on: Ubuntu
- Reports: Overall pipeline status

### Workflow Features

- **Parallel Execution**: Lint, test, and diagram jobs run concurrently
- **Platform Matrix**: macOS and Windows validation
- **Caching**: Flutter SDK, pub cache, PlantUML, npm packages
- **Fail-Fast Disabled**: All matrix combinations run even if one fails
- **Concurrency Control**: Cancel in-progress runs for same PR

---

## Caching Strategy

### Local Development
No explicit caching needed - Flutter manages its own cache.

### GitHub Actions
- **Flutter SDK**: Cached by `subosito/flutter-action@v2`
- **Pub Dependencies**: Cached via `actions/cache@v3` keyed on `pubspec.lock`
- **PlantUML JAR**: Cached to avoid repeated downloads
- **npm packages**: Cached for Mermaid CLI

---

## Troubleshooting

### Diagram validation fails locally but not in CI
**Cause**: Missing PlantUML or Mermaid CLI
**Fix**: Install required tools (see Prerequisites)

### Tests pass locally but fail in CI
**Cause**: Platform-specific differences or missing dependencies
**Fix**: Check CI logs for specific error, ensure code is platform-agnostic

### Formatting check fails
**Cause**: Code not formatted according to Dart standards
**Fix**: Run `dart format lib/ test/` to auto-format

### Cache issues in CI
**Cause**: Stale cache or corrupted dependencies
**Fix**: Clear cache by changing `key` in workflow or manually delete in GitHub Actions settings

### SQLite smoke tests fail
**Cause**: SQLite not properly initialized or tests not tagged
**Fix**: Ensure `sqflite_common_ffi` is initialized in tests, or tag tests with `@Tags(['smoke'])`

---

## Development Workflow

### Before Committing
```bash
# Run all checks
./scripts/ci/run_checks.sh

# Or run individual checks
bash tools/lint.sh
bash tools/test.sh
dart format lib/ test/
```

### Fixing Issues
```bash
# Fix formatting
dart format lib/ test/

# Fix linting issues (manual)
# Review output from: bash tools/lint.sh

# Run specific tests
flutter test test/path/to/test_file.dart
```

### Adding New Diagrams
1. Create `.puml` or `.mmd` file in `docs/diagrams/`
2. Validate syntax: `./scripts/ci/diagram_check.sh`
3. Render for preview:
   - PlantUML: `bash tools/scripts/render_diagram.sh docs/diagrams/your_diagram.puml`
   - Mermaid: `mmdc -i docs/diagrams/your_diagram.mmd -o output.svg`

---

## CI Badge

Add this badge to your README to show CI status:

```markdown
[![CI](https://github.com/YOUR_USERNAME/WireTuner/actions/workflows/ci.yml/badge.svg)](https://github.com/YOUR_USERNAME/WireTuner/actions/workflows/ci.yml)
```

Replace `YOUR_USERNAME` with the actual GitHub username or organization.

---

## Platform-Specific Notes

### macOS
- All tools available via Homebrew
- Native support for all diagram renderers
- Recommended for local diagram validation

### Windows
- PlantUML works via Java + JAR or WSL
- Mermaid CLI works via npm (requires Node.js)
- Use Git Bash or PowerShell for scripts

### CI (GitHub Actions)
- macOS runners: Full tooling support
- Windows runners: Limited diagram validation (PlantUML only via Java)
- Diagram validation runs exclusively on macOS in CI

---

## Exit Codes Reference

All scripts follow standard Unix exit codes:

| Code | Meaning |
|------|---------|
| 0    | Success - all checks passed |
| 1    | Failure - one or more checks failed |
| 2    | Error - missing tools or invalid usage |

---

## Additional Resources

- [Flutter CI/CD Best Practices](https://docs.flutter.dev/deployment/cd)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [PlantUML Documentation](https://plantuml.com/)
- [Mermaid Documentation](https://mermaid.js.org/)
- [Dart Code Style](https://dart.dev/guides/language/effective-dart/style)

---

## Maintenance

### Updating Flutter Version
1. Update `flutter-version` in `.github/workflows/ci.yml`
2. Update local Flutter: `flutter upgrade`
3. Test locally: `./scripts/ci/run_checks.sh`

### Updating Dependencies
1. Update `pubspec.yaml`
2. Run `flutter pub get`
3. Update lockfile cache key if needed
4. Test locally before pushing

### Adding New Checks
1. Add script in `scripts/ci/`
2. Update `run_checks.sh` to include new check
3. Add corresponding job in `.github/workflows/ci.yml`
4. Update this README
