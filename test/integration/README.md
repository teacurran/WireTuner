# WireTuner Integration Test Strategy

**Version:** 1.0
**Last Updated:** 2025-11-11
**Owner:** QA Team
**Task Reference:** I5.T4

## 1. Overview

This document describes WireTuner's integration testing strategy, including test orchestration, execution environments, and guidelines for writing new integration tests. Integration tests validate end-to-end workflows spanning multiple components, services, and persistence layers.

### 1.1 Purpose

- **Cross-Component Validation:** Verify interactions between domain, application, and infrastructure layers
- **Workflow Coverage:** Test complete user workflows (pen→save→reload, collaboration sessions, import/export)
- **Contract Testing:** Validate GraphQL/WebSocket APIs and backend integrations
- **Regression Prevention:** Catch integration-level regressions that unit tests miss

### 1.2 Scope

Integration tests cover:
- **Event Sourcing Workflows:** Event persistence, replay, snapshot restore
- **Document Lifecycle:** Save/load, version migration, crash recovery
- **Tool Workflows:** End-to-end pen, selection, and direct selection flows
- **Navigator Integration:** Multi-artboard discovery, thumbnail refresh
- **Import/Export Pipelines:** SVG/PDF/AI round-trip validation
- **Platform Integration:** SQLite integrity, file system operations

**Out of Scope:**
- Unit-level logic (covered by `flutter test` unit tests)
- UI widget interactions in isolation (covered by widget tests)
- Performance benchmarking (covered by [perf_benchmarks.md](../../docs/qa/perf_benchmarks.md))

### 1.3 Test Levels

| Level | Description | Tooling | Execution Time |
|-------|-------------|---------|----------------|
| **Unit Tests** | Single class/function validation | `flutter test` | <5 seconds |
| **Widget Tests** | UI component interactions | `flutter test` (with `WidgetTester`) | <30 seconds |
| **Integration Tests** | Multi-component workflows (this doc) | `flutter drive` or `flutter test` (with `IntegrationTestWidgetsFlutterBinding`) | 1-5 minutes |
| **E2E Tests** | Full system + backend (future) | `flutter drive` + real backend | 5-15 minutes |

---

## 2. Test Suite Inventory

### 2.1 Existing Integration Tests

All integration test files located in `test/integration/`:

| Test Suite | File | Status | Requirements Covered | Notes |
|------------|------|--------|---------------------|-------|
| Event Replay | `event_replay_test.dart` | PENDING | NFR-PERF-001, NFR-PERF-002, NFR-ACC-004 | Event → canvas replay validation, checksum validation |
| Save/Load | `save_load_test.dart` | PENDING | FR-014, FR-026, FR-033, NFR-REL-004 | Save/load round-trip with version migration |
| Pen Flow | `pen_flow_test.dart` | PENDING | FR-001..013, FR-028 | End-to-end pen tool workflow with snapping |
| Selection Flow | `selection_flow_test.dart` | PENDING | FR-001..013, FR-050 | End-to-end selection + arrow nudging workflow |
| Crash Recovery | `crash_recovery_test.dart` | PENDING | NFR-REL-001 | SQLite recovery after simulated crash |
| Navigator Auto-Open | `navigator_autoopen_test.dart` | PENDING | FR-029, FR-039 | Multi-artboard navigator behavior |
| Export Flows | `export_flow_test.dart` | PENDING | FR-041 | Per-artboard SVG/PDF export validation |

### 2.2 Planned Integration Tests (I6+)

| Test Suite | File | Requirements Covered | Priority | Target Iteration |
|------------|------|---------------------|----------|------------------|
| Collaboration Session | `collaboration_session_test.dart` | Collaboration requirements (I4) | High | I6 |
| Import AI Files | `import_ai_test.dart` | FR-021 | Medium | I6 |
| SQLite Migration | `sqlite_migration_test.dart` | NFR-REL-004 | High | I6 |
| Viewport Persistence | `viewport_persistence_test.dart` | FR-033 | Low | I7 |
| Thumbnail Batch Regen | `thumbnail_batch_test.dart` | FR-039, NFR-PERF-007 | Medium | I6 |

---

## 3. Running Integration Tests

### 3.1 Prerequisites

**System Requirements:**
- macOS 12+ or Windows 10+
- Flutter 3.16.0+
- Dart SDK 3.2.0+
- Melos 3.0.0+

**Setup:**
```bash
# Install dependencies
melos bootstrap

# Ensure test databases exist (auto-created on first run)
mkdir -p test/fixtures/databases

# Verify Flutter installation
flutter doctor -v
```

### 3.2 Local Execution

**Run All Integration Tests:**
```bash
# Using melos (recommended)
melos run test:integration

# Using flutter directly
flutter test test/integration/
```

**Run Specific Test Suite:**
```bash
# Run event replay tests only
flutter test test/integration/event_replay_test.dart

# With verbose output
flutter test test/integration/event_replay_test.dart --verbose

# With coverage
flutter test test/integration/event_replay_test.dart --coverage
```

**Run with Specific Platform:**
```bash
# macOS
flutter test test/integration/ --platform=macos

# Windows
flutter test test/integration/ --platform=windows
```

**Debug Integration Tests:**
```bash
# Run in debug mode with DevTools
flutter test test/integration/pen_flow_test.dart --start-paused

# Attach to running test
flutter attach
```

### 3.3 CI Execution

**Workflow:** `.github/workflows/ci.yml`

**Job:** `integration-tests` (to be added in I5.T6)

**Configuration:**
```yaml
integration-tests:
  name: Integration Tests
  runs-on: ${{ matrix.os }}
  strategy:
    fail-fast: false
    matrix:
      os: [macos-latest, windows-latest]
      flutter-version: ['3.16.0']
  steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup Flutter
      uses: subosito/flutter-action@v2
      with:
        flutter-version: ${{ matrix.flutter-version }}
        channel: 'stable'

    - name: Install dependencies
      run: melos bootstrap

    - name: Run integration tests
      run: melos run test:integration

    - name: Upload coverage
      uses: codecov/codecov-action@v3
      with:
        files: coverage/lcov.info
        flags: integration-tests

    - name: Upload test results
      uses: actions/upload-artifact@v3
      if: always()
      with:
        name: integration-test-results-${{ matrix.os }}
        path: test/integration/results/
```

**Trigger Conditions:**
- Push to `main`, `develop`, `codemachine/**` branches
- Pull requests targeting `main` or `develop`
- Manual workflow dispatch

**Failure Handling:**
- Integration test failures block PR merges
- Flaky test detection: Re-run failed tests up to 2 times
- Persistent failures require investigation within 24 hours

---

## 4. Writing Integration Tests

### 4.1 Test Structure Template

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wiretuner/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Feature Name Integration Tests', () {
    setUp(() async {
      // Setup test environment
      // - Initialize test database
      // - Load fixture data
      // - Mock external services if needed
    });

    tearDown(() async {
      // Cleanup test environment
      // - Clear test database
      // - Reset global state
      // - Close file handles
    });

    testWidgets('Test Case Description', (WidgetTester tester) async {
      // ARRANGE: Setup test data and state
      final testDocument = await createTestDocument(eventCount: 1000);

      // ACT: Execute workflow
      app.main();
      await tester.pumpAndSettle();

      // Open document
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // ASSERT: Verify expected outcome
      expect(find.text('Document Loaded'), findsOneWidget);
      expect(testDocument.isLoaded, isTrue);

      // Verify telemetry (if applicable)
      final metrics = await getTelemetryMetrics();
      expect(metrics['document.load.ms'], lessThan(100));
    });
  });
}
```

### 4.2 Best Practices

**DO:**
- ✅ Use descriptive test names: `testWidgets('should restore viewport after document reload', ...)`
- ✅ Isolate tests: Each test should be runnable independently
- ✅ Clean up: Always reset state in `tearDown()`
- ✅ Use fixtures: Load test data from `test/fixtures/` directory
- ✅ Mock external dependencies: Network calls, file system (when appropriate)
- ✅ Assert expected state: Verify both UI state and domain state
- ✅ Test error paths: Validate error handling and recovery
- ✅ Document assumptions: Add comments explaining complex setup

**DON'T:**
- ❌ Test implementation details: Focus on behavior, not internal methods
- ❌ Share mutable state: Between tests (causes flakiness)
- ❌ Use hardcoded delays: Use `pumpAndSettle()` or `pump(Duration(...))`
- ❌ Skip tearDown: Always clean up resources
- ❌ Test too much: Keep tests focused on a single workflow
- ❌ Ignore flakiness: Fix or skip flaky tests with `skip: 'Flaky - see issue #123'`

### 4.3 Test Data Management

**Fixture Data Location:** `test/fixtures/`

**Structure:**
```
test/fixtures/
├── databases/
│   ├── empty.db             # Empty SQLite database
│   ├── 1k_events.db         # 1K events for performance testing
│   ├── 10k_events.db        # 10K events for stress testing
│   └── multi_artboard.db    # Multi-artboard document
├── documents/
│   ├── simple.wiretuner     # Simple document (100 events)
│   ├── complex.wiretuner    # Complex document (10K events)
│   └── v1_legacy.wiretuner  # Legacy format for migration tests
├── import/
│   ├── test_vector.svg      # SVG import test
│   ├── test_document.ai     # AI import test
│   └── test_export.pdf      # PDF import test
└── export/
    └── golden/              # Golden files for export validation
        ├── artboard_1.svg
        └── artboard_2.pdf
```

**Creating Fixtures:**
```bash
# Generate test database with N events
dart test/fixtures/generators/generate_event_db.dart --events=1000 --output=test/fixtures/databases/1k_events.db

# Generate test document
dart test/fixtures/generators/generate_document.dart --events=10000 --artboards=5 --output=test/fixtures/documents/complex.wiretuner
```

**Loading Fixtures in Tests:**
```dart
import 'package:path/path.dart' as path;

Future<Database> loadFixtureDatabase(String name) async {
  final fixturePath = path.join('test', 'fixtures', 'databases', name);
  final tempPath = await createTempCopy(fixturePath); // Copy to temp location
  return await openDatabase(tempPath);
}

// Usage
final db = await loadFixtureDatabase('1k_events.db');
```

### 4.4 Mocking External Dependencies

**Mocking Backend Services:**
```dart
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([TelemetryService, CollaborationGateway])
void main() {
  late MockTelemetryService mockTelemetry;

  setUp(() {
    mockTelemetry = MockTelemetryService();
    // Inject mock into service locator
    getIt.registerSingleton<TelemetryService>(mockTelemetry);
  });

  testWidgets('should record telemetry on document load', (tester) async {
    // ... test logic ...

    // Verify telemetry was called
    verify(mockTelemetry.recordMetric(
      name: 'document.load.ms',
      value: any,
      tags: any,
    )).called(1);
  });
}
```

**Mocking File System:**
```dart
import 'package:file/memory.dart';

void main() {
  late MemoryFileSystem fileSystem;

  setUp(() {
    fileSystem = MemoryFileSystem();
    // Inject into service
    getIt.registerSingleton<FileSystem>(fileSystem);
  });

  testWidgets('should save document to file system', (tester) async {
    // Create mock file
    final file = fileSystem.file('/tmp/test.wiretuner');

    // ... save document ...

    // Verify file exists
    expect(await file.exists(), isTrue);
  });
}
```

### 4.5 Debugging Failed Tests

**Capture Screenshots:**
```dart
testWidgets('should render canvas correctly', (tester) async {
  await tester.pumpWidget(MyApp());

  // Take screenshot on failure
  try {
    expect(find.text('Canvas'), findsOneWidget);
  } catch (e) {
    await tester.takeScreenshot('failure_screenshot.png');
    rethrow;
  }
});
```

**Log Test Artifacts:**
```dart
tearDown(() async {
  // Export logs on failure
  if (testFailed) {
    await exportLogs('test/integration/results/logs.txt');
    await exportDatabase('test/integration/results/test.db');
  }
});
```

**Enable Verbose Logging:**
```bash
# Run with verbose logs
flutter test test/integration/event_replay_test.dart --verbose

# Enable Flutter DevTools
flutter test test/integration/event_replay_test.dart --start-paused
# Then attach DevTools and inspect state
```

---

## 5. Test Orchestration

### 5.1 Melos Commands

**Configuration:** `melos.yaml`

```yaml
scripts:
  test:integration:
    run: flutter test test/integration/
    description: Run all integration tests
    packageFilters:
      scope: 'app'

  test:integration:event-replay:
    run: flutter test test/integration/event_replay_test.dart
    description: Run event replay integration tests
    packageFilters:
      scope: 'app'

  test:integration:save-load:
    run: flutter test test/integration/save_load_test.dart
    description: Run save/load integration tests
    packageFilters:
      scope: 'app'

  test:integration:pen-flow:
    run: flutter test test/integration/pen_flow_test.dart
    description: Run pen flow integration tests
    packageFilters:
      scope: 'app'

  test:integration:selection-flow:
    run: flutter test test/integration/selection_flow_test.dart
    description: Run selection flow integration tests
    packageFilters:
      scope: 'app'

  test:integration:crash-recovery:
    run: flutter test test/integration/crash_recovery_test.dart --platform=${{ platform }}
    description: Run crash recovery integration tests (platform-specific)
    packageFilters:
      scope: 'app'

  test:integration:coverage:
    run: flutter test test/integration/ --coverage && genhtml coverage/lcov.info -o coverage/html
    description: Run integration tests with coverage report
    packageFilters:
      scope: 'app'
```

**Usage:**
```bash
# Run all integration tests
melos run test:integration

# Run specific suite
melos run test:integration:event-replay

# Run with coverage
melos run test:integration:coverage

# Open coverage report
open coverage/html/index.html
```

### 5.2 Parallel Execution

Integration tests can be executed in parallel for faster CI runs:

```yaml
# .github/workflows/ci.yml
jobs:
  integration-tests:
    strategy:
      matrix:
        suite:
          - event-replay
          - save-load
          - pen-flow
          - selection-flow
          - crash-recovery
    steps:
      - name: Run ${{ matrix.suite }} tests
        run: melos run test:integration:${{ matrix.suite }}
```

**Benefits:**
- Faster feedback (5 parallel jobs vs 1 sequential)
- Early failure detection (fail-fast on first failure)

**Considerations:**
- Ensure test isolation (no shared state between suites)
- Monitor resource usage (parallel execution may stress CI runners)

### 5.3 Test Result Reporting

**JUnit XML Output:**
```bash
# Generate JUnit XML for CI integration
flutter test test/integration/ --reporter=json > test-results.json

# Convert to JUnit XML
dart scripts/test/convert_to_junit.dart test-results.json > test-results.xml
```

**Upload to CI Dashboard:**
```yaml
- name: Publish test results
  uses: dorny/test-reporter@v1
  if: always()
  with:
    name: Integration Tests
    path: test-results.xml
    reporter: java-junit
```

---

## 6. Coverage Expectations

### 6.1 Coverage Thresholds

Integration tests are expected to contribute to overall coverage targets:

| Package | Target Coverage | Integration Contribution |
|---------|-----------------|--------------------------|
| `core` (domain) | ≥80% | ~30% (cross-component workflows) |
| `infrastructure` | ≥80% | ~50% (persistence, event store) |
| `app` | ≥70% | ~40% (UI workflows) |

### 6.2 Measuring Coverage

**Generate Coverage Report:**
```bash
# Run tests with coverage
melos run test:integration:coverage

# View HTML report
open coverage/html/index.html

# View terminal summary
lcov --summary coverage/lcov.info
```

**Coverage Gaps:**
If integration tests do not meet expected coverage contribution:
1. Identify uncovered code paths via coverage report
2. Assess if uncovered code is testable via integration tests
3. Add new test cases or extend existing tests
4. If not integration-testable, ensure unit test coverage exists

### 6.3 Coverage in CI

**Quality Gate Integration:**
Integration test coverage is combined with unit test coverage for quality gate evaluation:

```bash
# CI script: scripts/ci/check_coverage.sh
flutter test --coverage # Run all tests (unit + integration)
lcov --summary coverage/lcov.info

# Fail if coverage below threshold
dart scripts/ci/validate_coverage.dart \
  --coverage-file=coverage/lcov.info \
  --threshold-domain=80 \
  --threshold-infra=80 \
  --threshold-ui=70
```

---

## 7. Troubleshooting

### 7.1 Common Issues

**Issue: Tests timeout**

**Symptom:**
```
Test timed out after 30 seconds
```

**Diagnosis:**
- Long-running async operations not completing
- Missing `await` on async calls
- Deadlock in event loop

**Resolution:**
```dart
// Increase timeout
testWidgets('long running test', (tester) async {
  // ...
}, timeout: Timeout(Duration(seconds: 60)));

// Ensure all async operations awaited
await tester.pumpAndSettle();
```

---

**Issue: Flaky test failures**

**Symptom:**
Test passes locally but fails intermittently in CI

**Diagnosis:**
- Timing issues (race conditions)
- Platform differences (macOS vs Windows)
- Shared mutable state between tests

**Resolution:**
```dart
// Use pumpAndSettle instead of hardcoded delays
await tester.pumpAndSettle(); // Good
await Future.delayed(Duration(milliseconds: 500)); // Bad

// Reset state in tearDown
tearDown(() async {
  await resetGlobalState();
  await closeAllDatabases();
});

// Skip flaky test temporarily
testWidgets('flaky test', (tester) async {
  // ...
}, skip: 'Flaky on Windows - see issue #456');
```

---

**Issue: Database locked errors**

**Symptom:**
```
SqliteException: database is locked
```

**Diagnosis:**
- Database not properly closed in previous test
- Multiple connections to same database

**Resolution:**
```dart
tearDown(() async {
  // Ensure database closed
  await database?.close();
  await deleteTestDatabase();
});

// Use unique database per test
final testDbPath = 'test_${DateTime.now().millisecondsSinceEpoch}.db';
```

---

**Issue: File not found errors**

**Symptom:**
```
FileSystemException: Cannot open file, path = 'test/fixtures/...'
```

**Diagnosis:**
- Fixture file missing
- Incorrect path (relative vs absolute)

**Resolution:**
```dart
import 'package:path/path.dart' as path;

// Use absolute path
final fixturePath = path.join(
  Directory.current.path,
  'test',
  'fixtures',
  'databases',
  '1k_events.db',
);

// Verify file exists before loading
if (!await File(fixturePath).exists()) {
  throw Exception('Fixture file not found: $fixturePath');
}
```

---

### 7.2 CI-Specific Issues

**Issue: Tests pass locally but fail in CI**

**Diagnosis:**
- Platform differences (macOS vs Linux vs Windows)
- Missing dependencies in CI environment
- Different Flutter/Dart versions

**Resolution:**
```yaml
# Ensure same Flutter version locally and CI
flutter --version # Check local version

# CI workflow
- name: Setup Flutter
  uses: subosito/flutter-action@v2
  with:
    flutter-version: '3.16.0' # Pin version
    channel: 'stable'
```

**Issue: Out of memory errors in CI**

**Diagnosis:**
- Running too many tests in parallel
- Memory leaks in tests

**Resolution:**
```yaml
# Reduce parallelism
strategy:
  max-parallel: 2 # Limit concurrent jobs

# Split test suites into smaller batches
- name: Run integration tests (batch 1)
  run: flutter test test/integration/event_replay_test.dart test/integration/save_load_test.dart
```

---

## 8. Future Enhancements

### 8.1 Planned Improvements (I6+)

| Enhancement | Description | Priority | Target Iteration |
|-------------|-------------|----------|------------------|
| **E2E Backend Integration** | Test against real backend services (GraphQL, WebSocket) | High | I6 |
| **Contract Testing** | Validate API contracts using Pact or similar | Medium | I7 |
| **Visual Regression Testing** | Golden file comparison for UI consistency | Medium | I6 |
| **Load Testing** | Stress test with 100K+ events, 1000+ artboards | Low | I7 |
| **Cross-Platform Testing** | Add Linux, iOS, Android to CI matrix | Medium | I8 |
| **Chaos Engineering** | Inject faults (network latency, disk errors) | Low | I8 |

### 8.2 Tooling Improvements

| Tool | Purpose | Status |
|------|---------|--------|
| `flutter_gherkin` | BDD-style integration tests | PLANNED (I7) |
| `golden_toolkit` | Golden file management | PLANNED (I6) |
| `integration_test` package | Enhanced integration test capabilities | IN USE |
| `mockito` | Mocking external dependencies | IN USE |

---

## 9. References

### 9.1 Internal Documentation

- [Verification Matrix](../../docs/qa/verification_matrix.md) - FR/NFR → test mapping
- [Quality Gates](../../docs/qa/quality_gates.md) - Baseline CI quality gates
- [Performance Benchmarks](../../docs/qa/perf_benchmarks.md) - Benchmark suite specifications

### 9.2 Architecture Documents

- [03_Verification_and_Glossary.md](../../.codemachine/artifacts/architecture/03_Verification_and_Glossary.md) - Testing levels, validation strategy
- [02_System_Structure_and_Data.md](../../.codemachine/artifacts/architecture/02_System_Structure_and_Data.md) - Component structure, data contracts

### 9.3 External Resources

- [Flutter Integration Testing Guide](https://docs.flutter.dev/testing/integration-tests)
- [Flutter Driver Documentation](https://api.flutter.dev/flutter/flutter_driver/flutter_driver-library.html)
- [Mockito Documentation](https://pub.dev/packages/mockito)

### 9.4 Task Context

- **Task ID:** I5.T4
- **Iteration:** I5 (Import/Export Pipelines & Release Readiness)
- **Dependencies:** I1.T6 (Quality Gates), I3.T6 (Telemetry Policy)

---

## 10. Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-11-11 | Claude (CodeImplementer) | Initial integration test strategy for I5.T4 |
