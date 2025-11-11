# Quality Gates

**Version:** 1.0
**Last Updated:** 2025-11-10
**Owner:** DevOps Team
**Task Reference:** I1.T6

## Overview

This document describes WireTuner's baseline CI quality gates that enforce code quality, testing standards, and formatting consistency across the monorepo. All quality gates must pass before code can be merged to `main` or `develop` branches.

Quality gates are enforced automatically via GitHub Actions CI pipeline and can be run locally using the quality gate script.

## Quality Gate Summary

| Gate | Tool/Command | Threshold | Blocking | FR/NFR References |
|------|--------------|-----------|----------|-------------------|
| **Code Formatting** | `dart format` | Zero violations | Yes | NFR-PERF-006 |
| **Static Analysis** | `melos run analyze` | Zero issues (infos/warnings/errors) | Yes | FR-026, NFR-PERF-006 |
| **Unit Tests** | `melos run test` | 100% passing | Yes | FR-026 |
| **Coverage Thresholds** | `flutter test --coverage` | 80% domain/infra, 70% UI | Info only (future) | NFR-PERF-006 |

## Gate Descriptions

### Gate 1: Code Formatting

**Purpose:** Ensures consistent code style across the entire codebase.

**Tool:** `dart format`

**Command:**
```bash
dart format --set-exit-if-changed lib/ test/
```

**Pass Criteria:**
- Zero formatting violations in `lib/` and `test/` directories
- All files conform to Dart style guide

**Fail Behavior:**
- Exit code 1 if any file requires formatting changes
- CI pipeline blocks merge

**Remediation:**
```bash
# Auto-fix formatting issues
dart format lib/ test/

# Or use melos for workspace-wide formatting
melos run format
```

**References:**
- NFR-PERF-006: Zero UI blocking (clean code standards)

---

### Gate 2: Static Analysis (Lint)

**Purpose:** Enforces type safety, code quality rules, and catches potential bugs via static analysis.

**Tool:** `melos run analyze`

**Configuration:** `analysis_options.yaml` with strict linting rules

**Command:**
```bash
melos run analyze
```

**Pass Criteria:**
- Zero analyzer issues (infos, warnings, errors)
- All packages in workspace pass analysis
- Enforces `--fatal-infos --fatal-warnings` flags

**Key Lint Rules:**
- Type safety: `avoid_dynamic_calls`, `unnecessary_null_checks`
- Immutability: `prefer_const_constructors`, `prefer_final_fields`
- Resource cleanup: `cancel_subscriptions`, `close_sinks`
- Documentation: `public_member_api_docs`

**Fail Behavior:**
- Exit code 1 if any package has analyzer issues
- CI pipeline blocks merge

**Remediation:**
```bash
# Run analyzer with full output
melos run analyze

# Fix issues per package
cd packages/core && flutter analyze
```

**References:**
- FR-026: Snapshot backgrounding (requires clean async code)
- NFR-PERF-006: Zero UI blocking (enforces performance patterns)

---

### Gate 3: Unit Tests

**Purpose:** Ensures all unit and widget tests pass before merging code.

**Tool:** `melos run test`

**Command:**
```bash
melos run test
```

**Pass Criteria:**
- 100% of tests passing across all packages
- Zero test failures or errors
- Tests run in isolation without flakiness

**Fail Behavior:**
- Exit code 1 if any test fails
- CI pipeline blocks merge

**Remediation:**
```bash
# Run tests with full output
melos run test

# Run tests for specific package
melos run test --scope=core

# Run single test file
flutter test test/domain/models/document_test.dart
```

**Test Categories:**
- Unit tests: Business logic, models, utilities
- Widget tests: UI components, interactions
- Integration tests: Cross-layer workflows (not covered by this gate)

**References:**
- FR-026: Snapshot backgrounding (tests verify async behavior)

---

### Gate 4: Coverage Thresholds

**Purpose:** Ensures adequate test coverage for domain logic and UI components.

**Tool:** `flutter test --coverage` + lcov parser

**Thresholds:**
- **Domain/Infrastructure packages:** ≥80% coverage
- **UI packages (app, app_shell):** ≥70% coverage

**Command:**
```bash
# Generate coverage report
melos run test --coverage

# Parse lcov.info for threshold validation
# (Future: automated parsing via quality_gate.sh)
```

**Pass Criteria (Future):**
- Domain packages (`core`, `infrastructure`) ≥ 80% line coverage
- UI packages (`app`, `app_shell`) ≥ 70% line coverage

**Current Status:**
- **Informational only** - threshold enforcement not yet implemented
- Coverage data collected but not blocking

**Future Implementation:**
- Parse `coverage/lcov.info` per package
- Fail gate if any package below threshold
- Generate HTML coverage reports

**References:**
- NFR-PERF-006: Zero UI blocking (tested performance patterns)

---

## Running Quality Gates

### Local Execution

Run all quality gates locally before committing:

```bash
# Run complete quality gate suite
./scripts/devtools/quality_gate.sh

# Skip coverage validation (faster for quick checks)
./scripts/devtools/quality_gate.sh --skip-coverage
```

**Expected Output:**
```
╔═══════════════════════════════════════════╗
║   WireTuner Quality Gate Enforcer         ║
║   Baseline CI Quality Gates (I1.T6)      ║
╚═══════════════════════════════════════════╝

ℹ INFO: Project: WireTuner
ℹ INFO: Quality gates enforce FR-026, NFR-PERF-006 requirements

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Gate 1/4: Code Formatting
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ SUCCESS: Code formatting is correct

...

✓ SUCCESS: All quality gates passed! ✓
```

### CI Pipeline Execution

Quality gates run automatically in GitHub Actions CI:

**Workflow:** `.github/workflows/ci.yml`

**Job:** `quality-gates`

**Matrix:** macOS + Windows

**Trigger:**
- Push to `main`, `develop`, `codemachine/**` branches
- Pull requests targeting `main` or `develop`

**Job Dependencies:**
```
quality-gates (runs in parallel)
     ↓
build (requires quality-gates + lint + test)
     ↓
ci-summary (checks all jobs)
```

**Badge:**

[![CI](https://github.com/teacurran/WireTuner/actions/workflows/ci.yml/badge.svg)](https://github.com/teacurran/WireTuner/actions/workflows/ci.yml)

---

## Troubleshooting

### Gate 1: Formatting Failures

**Symptom:** `dart format` exits with code 1

**Diagnosis:**
```bash
# See which files need formatting
dart format --set-exit-if-changed lib/ test/
```

**Resolution:**
```bash
# Auto-fix all formatting issues
dart format lib/ test/
```

---

### Gate 2: Analyzer Failures

**Symptom:** `melos run analyze` reports infos/warnings/errors

**Diagnosis:**
```bash
# Run analyzer with full output
melos run analyze

# Check specific package
cd packages/core && flutter analyze
```

**Common Issues:**
- Missing documentation comments → Add `///` doc comments to public APIs
- Dynamic type usage → Add explicit type annotations
- Unused imports → Remove or comment out unused imports
- Missing `const` constructors → Add `const` where applicable

**Resolution:**
```bash
# Fix issues manually based on analyzer output
# Re-run analyzer to verify fixes
melos run analyze
```

---

### Gate 3: Test Failures

**Symptom:** Tests fail or error during execution

**Diagnosis:**
```bash
# Run tests with verbose output
melos run test

# Run specific test file
flutter test test/domain/models/document_test.dart --verbose
```

**Common Issues:**
- Missing test setup → Add `setUp()` / `tearDown()` methods
- Flaky async tests → Use `await`, `expectLater`, `pumpAndSettle()`
- Mock configuration → Verify mock behaviors and expectations

**Resolution:**
- Fix failing tests based on error messages
- Run tests locally until all pass
- Re-run CI pipeline

---

### Gate 4: Coverage Threshold Failures (Future)

**Symptom:** Package coverage below threshold (once enforced)

**Diagnosis:**
```bash
# Generate coverage report
flutter test --coverage

# View coverage HTML report
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

**Resolution:**
- Add missing unit tests for uncovered code
- Focus on domain logic and critical paths
- Aim for 80% domain/infrastructure, 70% UI

---

## Quality Gate Configuration

### CI Workflow Configuration

**File:** `.github/workflows/ci.yml`

**Quality Gates Job:**
```yaml
quality-gates:
  name: Quality Gates
  runs-on: ${{ matrix.os }}
  strategy:
    fail-fast: false
    matrix:
      os: [macos-latest, windows-latest]
      flutter-version: ['3.16.0']
  steps:
    - name: Run quality gate script
      run: bash scripts/devtools/quality_gate.sh --skip-coverage
      shell: bash
```

### Local Script Configuration

**File:** `scripts/devtools/quality_gate.sh`

**Options:**
- `--skip-coverage`: Skip coverage threshold validation
- `--help`: Show usage information

**Exit Codes:**
- `0`: All gates passed
- `1`: One or more gates failed

---

## FR/NFR Traceability

Quality gates enforce the following functional and non-functional requirements:

### Functional Requirements (FR)

| FR ID | Description | Gate Enforcement |
|-------|-------------|------------------|
| FR-026 | Snapshot backgrounding | Static analysis enforces async patterns; tests verify snapshot logic |

### Non-Functional Requirements (NFR)

| NFR ID | Description | Gate Enforcement |
|--------|-------------|------------------|
| NFR-PERF-006 | Zero UI blocking | Static analysis enforces non-blocking patterns; formatting ensures clean code; coverage validates performance-critical paths |

---

## PR Checklist

Before submitting a pull request, ensure:

- [ ] All quality gates pass locally (`./scripts/devtools/quality_gate.sh`)
- [ ] CI pipeline shows green checkmarks for all jobs
- [ ] No new analyzer warnings or infos introduced
- [ ] All tests pass (100% passing rate)
- [ ] Code is properly formatted (`dart format lib/ test/`)
- [ ] Documentation updated if public APIs changed
- [ ] PR description links relevant FR/NFR IDs (e.g., "Implements FR-026")

---

## Future Enhancements

### Planned Improvements (Post-I1)

1. **Coverage Threshold Enforcement**
   - Implement lcov.info parser in `quality_gate.sh`
   - Block merges if packages below 80%/70% thresholds
   - Generate HTML coverage reports in CI artifacts

2. **Golden Test Validation**
   - Add golden test comparison gate
   - Require UX lead approval for UI drifts
   - Store baseline golden images in repository

3. **Performance Regression Gates**
   - Nightly performance test suite
   - Trend analysis with ±5% tolerance
   - Block releases on regression

4. **PlantUML/Diagram Regeneration**
   - Auto-regenerate diagrams on source changes
   - Validate diagram outputs match sources
   - Fail gate if diagrams out of sync

5. **ADR Compliance Checks**
   - Lint rules enforcing ADR decisions
   - Directory ownership validation
   - Architectural boundary enforcement

---

## References

### Internal Documentation
- [CI Workflow](.github/workflows/ci.yml)
- [Quality Gate Script](../scripts/devtools/quality_gate.sh)
- [CI Scripts README](../scripts/ci/README.md)
- [Verification Strategy](../../.codemachine/artifacts/architecture/03_Verification_and_Glossary.md)

### Task Context
- **Task ID:** I1.T6
- **Iteration:** I1 (Monorepo Workspace Setup)
- **Dependencies:** I1.T1 (Melos workspace configuration)

### FR/NFR References
- FR-026: Snapshot backgrounding
- NFR-PERF-006: Zero UI blocking

### External Resources
- [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- [Flutter Testing Documentation](https://docs.flutter.dev/testing)
- [Melos Documentation](https://melos.invertase.dev/)

---

## Revision History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | 2025-11-10 | Initial quality gates documentation (I1.T6) | DevOps Team |
