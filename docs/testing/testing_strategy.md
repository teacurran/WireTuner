<!-- anchor: testing-strategy -->
# WireTuner Testing Strategy

**Document Version:** 1.0
**Last Updated:** 2025-11-10
**Iteration:** I9
**Related Architecture:** [Verification and Integration Strategy](../../.codemachine/artifacts/plan/03_Verification_and_Glossary.md#verification-and-integration-strategy)
**Related Workflows:** [Developer Workflow](../reference/dev_workflow.md)

---

## Table of Contents

1. [Overview](#overview)
2. [Testing Philosophy](#testing-philosophy)
3. [Coverage Targets](#coverage-targets)
4. [Test Types](#test-types)
   - [Unit Tests](#unit-tests)
   - [Widget Tests](#widget-tests)
   - [Integration Tests](#integration-tests)
   - [Performance Tests](#performance-tests)
5. [Visual Regression Testing](#visual-regression-testing)
6. [Manual Testing](#manual-testing)
7. [CI/CD Integration](#cicd-integration)
8. [Best Practices](#best-practices)
9. [Common Pitfalls](#common-pitfalls)
10. [References](#references)

---

## Overview

WireTuner employs a comprehensive multi-layered testing strategy to ensure reliability, performance, and correctness across all platforms (macOS, Windows, Linux). Our testing pyramid emphasizes:

- **Strong unit test coverage** for domain logic and infrastructure (≥80%)
- **Thorough widget testing** with visual regression detection
- **Critical path integration testing** for end-to-end workflows
- **Performance benchmarking** to maintain 60 FPS and sub-2-second load times
- **Manual QA** for platform parity and UX validation

All tests are automated via CI/CD pipelines that run on every pull request, with coverage gates enforcing quality standards before merge.

---

## Testing Philosophy

### Testing Pyramid

```
         /\
        /  \  Manual QA (Platform Parity, UX)
       /____\
      /      \  Integration Tests (Critical Workflows)
     /________\
    /          \  Widget Tests (UI Components, Interactions)
   /____________\
  /              \  Unit Tests (Domain Logic, Infrastructure)
 /________________\
```

**Principles:**
1. **Fast Feedback:** Unit tests run in milliseconds; integration tests complete in seconds
2. **Deterministic:** Tests produce consistent results across environments
3. **Isolated:** Each test is independent; failures don't cascade
4. **Maintainable:** Tests are readable, well-documented, and follow DRY principles
5. **Coverage-Driven:** Code without tests is considered incomplete

### Quality Gates

Before merging any PR, the following must pass:

- ✅ All test suites (unit, widget, integration) green
- ✅ `flutter analyze` with zero issues
- ✅ ≥80% coverage for `lib/domain` and `lib/infrastructure`
- ✅ Performance benchmarks within acceptable thresholds
- ✅ Golden file diffs reviewed and approved (if applicable)
- ✅ Manual QA checklist completed for UI changes

---

## Coverage Targets

### Mandatory Coverage Thresholds

| Package/Directory           | Minimum Coverage | Enforcement |
|-----------------------------|------------------|-------------|
| `lib/domain/**`             | **80%**          | CI gate     |
| `lib/infrastructure/**`     | **80%**          | CI gate     |
| `lib/presentation/widgets/**` | **70%**        | Advisory    |
| `lib/presentation/tools/**` | **75%**          | Advisory    |

**Verification:**
```bash
# Generate coverage report locally
just coverage

# View HTML report
open coverage/html/index.html
```

**CI Enforcement:**
The CI pipeline runs `just coverage` and fails the build if coverage drops below thresholds for gated packages. See `.github/workflows/ci.yml` for implementation details.

---

## Test Types

### Unit Tests

**Purpose:** Validate individual classes, functions, and methods in isolation.

**Scope:**
- Domain logic (geometry calculations, event processing, tool behavior)
- Infrastructure components (persistence, serialization, export/import helpers)
- Pure functions and stateless utilities

**Location:** `test/unit/`

**Examples:**
- `test/unit/pen_tool_test.dart` – Tests pen tool state machine and path construction
- `test/unit/document_snapshot_test.dart` – Tests event sourcing logic (replay, snapshots)
- `test/unit/event_schema_validation_test.dart` – Validates event schema and serialization

**Guidelines:**

1. **Test Naming:** Use descriptive names that explain the scenario
   ```dart
   test('pen tool creates straight line when clicking two points', () { ... });
   ```

2. **Arrange-Act-Assert Pattern:**
   ```dart
   test('selection tool selects object under cursor', () {
     // Arrange
     final document = Document.empty();
     final rect = Rectangle(position: Point(10, 10), size: Size(50, 50));
     document.addObject(rect);

     // Act
     final selected = SelectionTool.selectAt(Point(20, 20), document);

     // Assert
     expect(selected, equals(rect));
   });
   ```

3. **Mock External Dependencies:** Use `mockito` or test doubles for file I/O, network, platform channels
   ```dart
   final mockFileSystem = MockFileSystem();
   when(mockFileSystem.readAsString(any)).thenReturn('{"version": "1.0"}');
   ```

4. **Test Edge Cases:**
   - Null/empty inputs
   - Boundary conditions (zero, negative, max values)
   - Invalid states

**Running Unit Tests:**
```bash
# All unit tests
just test

# Specific file
flutter test test/unit/pen_tool_test.dart

# With coverage
just coverage
```

---

### Widget Tests

**Purpose:** Test Flutter widgets in isolation, verifying UI rendering, user interactions, and state management.

**Scope:**
- Canvas rendering and overlays
- Tool panels and property inspectors
- History panel, menus, dialogs
- Gesture handling (tap, drag, zoom)

**Location:** `test/widget/`

**Examples:**
- `test/widget/pen_tool_straight_test.dart` – Tests pen tool UI interactions
- `test/widget/document_painter_test.dart` – Validates canvas paint operations
- `test/widget/history_panel_test.dart` – Tests undo/redo UI

**Guidelines:**

1. **Pump Widgets with Necessary Providers:**
   ```dart
   testWidgets('canvas renders rectangle', (tester) async {
     await tester.pumpWidget(
       ProviderScope(
         child: MaterialApp(
           home: CanvasWidget(document: testDocument),
         ),
       ),
     );

     // Verify rendering
     expect(find.byType(CustomPaint), findsOneWidget);
   });
   ```

2. **Test User Interactions:**
   ```dart
   testWidgets('pen tool creates path on canvas tap', (tester) async {
     await tester.pumpWidget(testApp);

     // Tap canvas to add points
     await tester.tapAt(Offset(100, 100));
     await tester.pump();
     await tester.tapAt(Offset(200, 200));
     await tester.pump();

     // Verify path created
     final path = document.objects.whereType<Path>().single;
     expect(path.points.length, equals(2));
   });
   ```

3. **Use Golden Files for Visual Regression:** See [Visual Regression Testing](#visual-regression-testing)

4. **Test Accessibility:**
   ```dart
   expect(tester, meetsGuideline(textContrastGuideline));
   expect(tester, meetsGuideline(labeledTapTargetGuideline));
   ```

**Running Widget Tests:**
```bash
# All widget tests
just test-widgets

# Update golden files after intentional UI changes
flutter test --update-goldens

# Specific widget test
flutter test test/widget/pen_tool_straight_test.dart
```

---

### Integration Tests

**Purpose:** Validate end-to-end workflows and inter-component interactions.

**Scope:**
- Complete user workflows (create → edit → save → load)
- Tool switching and mode transitions
- Event replay and document recovery
- Cross-layer interactions (presentation → domain → infrastructure)

**Location:** `test/integration/`

**Critical Scenarios:**

1. **Save/Load Round-Trip** (`test/integration/test/integration/save_load_roundtrip_test.dart`)
   - Create document with various objects
   - Save to `.wiretuner` file
   - Load from disk
   - Verify all objects restored correctly

2. **Pen Tool Workflow** (`test/integration/test/integration/tool_pen_selection_test.dart`)
   - Activate pen tool
   - Draw multiple paths
   - Switch to selection tool
   - Modify paths
   - Verify undo/redo works across tools

3. **Undo/Redo** (covered in `test/integration/test/integration/tool_pen_selection_test.dart` and `test/integration/document_service_integration_test.dart`)
   - Perform series of operations (create, delete, transform)
   - Undo each operation
   - Redo operations
   - Verify document state matches at each step

4. **Crash Recovery** (`test/integration/test/integration/crash_recovery_test.dart`)
   - Simulate app crash mid-transaction
   - Restart app
   - Verify document recovered from event log

5. **Export/Import** (`test/integration/svg_importer_integration_test.dart`, `test/integration/svg_export_test.dart`, `test/integration/pdf_export_test.dart`)
   - Export document to SVG/PDF
   - Validate output structure
   - Import SVG from Adobe Illustrator
   - Verify fidelity

**Guidelines:**

1. **Test Real User Paths:**
   ```dart
   testWidgets('complete drawing workflow', (tester) async {
     await tester.pumpWidget(WireTunerApp());

     // Create new document
     await tester.tap(find.byIcon(Icons.add));
     await tester.pumpAndSettle();

     // Draw rectangle
     await tester.tap(find.byTooltip('Rectangle Tool'));
     await tester.dragFrom(Offset(50, 50), Offset(100, 100));
     await tester.pumpAndSettle();

     // Save document
     await tester.tap(find.byIcon(Icons.save));
     await tester.pumpAndSettle();

     // Verify saved
     expect(find.text('Document saved'), findsOneWidget);
   });
   ```

2. **Use Real Services (with test doubles for external I/O):**
   - Real event sourcing repository (in-memory SQLite)
   - Real rendering pipeline
   - Mock file system for save/load

3. **Assert on Business Outcomes, Not Implementation:**
   ```dart
   // Good: Tests observable outcome
   expect(document.objects.length, equals(3));

   // Bad: Tests internal state
   expect(documentController.isDirty, isTrue);
   ```

**Running Integration Tests:**
```bash
# All integration tests
just test-integration

# Run in headless mode (CI)
flutter test integration_test/

# Specific integration test
flutter test test/integration/test/integration/save_load_roundtrip_test.dart
```

---

### Performance Tests

**Purpose:** Ensure rendering, replay, and I/O operations meet performance targets.

**Scope:**
- Frame rendering times (60 FPS target)
- Document load times (<2 seconds)
- Event replay throughput
- Memory usage under load

**Location:** `test/performance/`

**Primary Benchmark:** `test/performance/rendering_benchmark_test.dart`

**Performance Targets:**

| Metric                     | Target          | Alert Threshold |
|----------------------------|-----------------|-----------------|
| Frame Time (Paint)         | <16.67ms (60 FPS) | >33ms (30 FPS) |
| Document Load (500 objects) | <500ms          | >2000ms         |
| Event Replay (10k events)  | <500ms          | >1000ms         |
| Event Write Latency        | <10ms           | >50ms           |
| Memory Usage (Document)    | <500 MB         | >1 GB           |

**Example Benchmark:**
```dart
test('canvas renders 1000 objects at 60 FPS', () async {
  // Generate stress-test document
  final document = _generateLargeDocument(objectCount: 1000);

  // Warm up rendering cache
  await tester.pumpWidget(CanvasWidget(document: document));
  await tester.pump();

  // Measure paint time
  final stopwatch = Stopwatch()..start();
  await tester.pump();
  stopwatch.stop();

  expect(stopwatch.elapsedMilliseconds, lessThan(17),
         reason: 'Frame should render in <16.67ms for 60 FPS');
});
```

**Running Performance Tests:**
```bash
# All performance benchmarks
flutter test test/performance/

# Generate performance report
flutter test test/performance/rendering_benchmark_test.dart --reporter json > perf_results.json
```

**Monitoring in Development:**
- Enable performance overlay: `Debug → Show Performance Overlay`
- Monitor FPS graph during complex operations
- Check memory profiler for leaks

**CI Integration:**
Performance benchmarks run on workflow dispatch (not every PR) and store results as artifacts for regression tracking. Significant regressions require investigation before release.

---

## Visual Regression Testing

**Purpose:** Detect unintended UI changes by comparing rendered widgets to golden master images.

**Location:** `test/widget/goldens/`

**Workflow:**

1. **Create Golden Test:**
   ```dart
   testWidgets('pen tool overlay renders correctly', (tester) async {
     await tester.pumpWidget(testApp);
     await tester.tap(find.byTooltip('Pen Tool'));
     await tester.pump();

     await expectLater(
       find.byType(CanvasWidget),
       matchesGoldenFile('goldens/pen_tool_overlay.png'),
     );
   });
   ```

2. **Generate Initial Golden Files:**
   ```bash
   flutter test --update-goldens
   ```

3. **Review Generated Images:**
   Inspect `test/widget/goldens/*.png` files to ensure they represent correct UI state.

4. **Run Golden Tests:**
   ```bash
   flutter test test/widget/  # Fails if rendered output differs from golden
   ```

5. **Update Goldens After Intentional Changes:**
   ```bash
   flutter test --update-goldens
   git add test/widget/goldens/
   git commit -m "Update golden files for new button design"
   ```

**Best Practices:**
- Keep golden files small (test individual widgets, not full screens)
- Name files descriptively (`pen_tool_overlay.png`, not `test1.png`)
- Review diffs carefully in PRs (use image diff tools)
- Platform-specific goldens if rendering differs (rare with Flutter)

---

## Manual Testing

**Purpose:** Validate UX, platform parity, and scenarios difficult to automate.

**When Required:**
- Platform-specific features (macOS/Windows file dialogs, window management)
- Complex gestures (multi-touch, pen pressure)
- Visual polish and animation smoothness
- Accessibility with screen readers
- Release candidate validation

**Checklists:**

- **Platform Parity:** [docs/qa/platform_parity_checklist.md](../qa/platform_parity_checklist.md)
- **History/Undo/Redo:** [docs/qa/history_checklist.md](../qa/history_checklist.md)
- **Crash Recovery:** [docs/qa/recovery_playbook.md](../qa/recovery_playbook.md)
- **Release Sign-Off:** [docs/qa/release_checklist.md](../qa/release_checklist.md)

**Process:**
1. Run automated test suite first (`just ci`)
2. Execute relevant manual checklist(s)
3. Document any issues in GitHub Issues
4. Sign off in PR or release tracking issue

---

## CI/CD Integration

**GitHub Actions Workflows:**

- **PR Validation** (`.github/workflows/ci.yml`):
  - Runs on every push to PR branches
  - Matrix: macOS + Windows
  - Steps:
    1. `flutter analyze` (lint/static analysis)
    2. `just test` (unit tests)
    3. `just test-widgets` (widget tests, golden comparisons)
    4. `just test-integration` (integration tests)
    5. `just coverage` (coverage report + gate enforcement)
    6. `just diagrams` (PlantUML/Mermaid validation)
  - **Merge Blocked** if any step fails or coverage <80% for gated packages

- **Nightly Integration Tests** (optional, workflow dispatch):
  - Runs full integration suite including slow tests
  - Executes performance benchmarks
  - Stores JSON/CSV results as artifacts

- **Release Build** (`.github/workflows/release.yml`):
  - Triggered on version tags
  - Runs full test suite + security audit
  - Builds macOS DMG and Windows EXE
  - Halts on critical dependency vulnerabilities

**Local Pre-PR Validation:**
```bash
# Run complete CI suite locally
just ci

# Equivalent to:
# - flutter analyze
# - dart format --set-exit-if-changed .
# - just test
# - just test-widgets
# - just test-integration
# - just coverage
```

**Coverage Gate Implementation:**
CI parses `coverage/lcov.info` and calculates per-directory coverage. If `lib/domain/` or `lib/infrastructure/` fall below 80%, the build fails with a clear error message.

---

## Best Practices

### Test Organization

- **Group related tests:**
  ```dart
  group('PenTool', () {
    group('straight line mode', () {
      test('creates line on two clicks', () { ... });
      test('cancels on escape key', () { ... });
    });

    group('bezier mode', () {
      test('creates curve with control points', () { ... });
    });
  });
  ```

- **Use `setUp` and `tearDown` for common initialization:**
  ```dart
  group('Document persistence', () {
    late TemporaryDirectory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('wiretuner_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('saves document to disk', () { ... });
  });
  ```

### Test Data Management

- **Use builders/factories for test objects:**
  ```dart
  Document createTestDocument({int objectCount = 10}) {
    final doc = Document.empty();
    for (int i = 0; i < objectCount; i++) {
      doc.addObject(Rectangle(
        position: Point(i * 10, i * 10),
        size: Size(50, 50),
      ));
    }
    return doc;
  }
  ```

- **Keep fixtures minimal and focused**
- **Avoid brittle assertions on exact values** (use matchers like `closeTo`, `inInclusiveRange`)

### Flaky Test Prevention

- **Avoid timing dependencies:**
  ```dart
  // Bad: Assumes animation completes in 500ms
  await Future.delayed(Duration(milliseconds: 500));

  // Good: Wait for specific condition
  await tester.pumpAndSettle();
  ```

- **Stub randomness and time:**
  ```dart
  final mockClock = Clock.fixed(DateTime(2025, 1, 1));
  withClock(mockClock, () {
    // Test with deterministic time
  });
  ```

- **Isolate tests from external state** (filesystem, network, platform APIs)

### Error Messages

- **Use descriptive `reason` parameters:**
  ```dart
  expect(result, isNotNull, reason: 'Parser should return object for valid SVG');
  ```

- **Add context to failures:**
  ```dart
  fail('Expected event log to contain PathCreated, but found: ${events.map((e) => e.runtimeType)}');
  ```

---

## Common Pitfalls

### 1. Testing Implementation Instead of Behavior
**Problem:**
```dart
// Tests internal state, breaks on refactoring
expect(controller.selectedObjectId, equals('obj-123'));
```

**Solution:**
```dart
// Tests observable behavior
expect(find.byKey(Key('selected-obj-123')), findsOneWidget);
expect(document.getSelectedObjects(), contains(obj123));
```

### 2. Overmocking
**Problem:**
```dart
// Mocks everything, test becomes meaningless
final mockDocument = MockDocument();
final mockRenderer = MockRenderer();
final mockEventBus = MockEventBus();
when(mockDocument.objects).thenReturn([]);
// ... 50 lines of mock setup
```

**Solution:**
- Use real objects when possible
- Mock only at architectural boundaries (filesystem, network, platform)
- Prefer test doubles over mocks for value objects

### 3. Brittle Golden Tests
**Problem:**
- Golden files change on every minor Flutter update
- Tests fail on different platforms/screen densities

**Solution:**
- Test individual widgets, not entire screens
- Use platform-agnostic rendering (avoid native widgets in golden tests)
- Accept minor pixel differences (use `matchesGoldenFile` tolerance if needed)

### 4. Slow Integration Tests
**Problem:**
- Integration test suite takes 10+ minutes
- Developers skip running tests locally

**Solution:**
- Keep integration tests focused on critical paths
- Use in-memory databases (SQLite `:memory:`)
- Mock external services (cloud sync, analytics)
- Reserve exhaustive tests for nightly runs

### 5. Ignoring Flaky Tests
**Problem:**
- "Just rerun the CI, it'll pass eventually"
- Flakiness masks real issues

**Solution:**
- Investigate and fix flaky tests immediately
- Use `@Retry(3)` annotation only as temporary mitigation
- Add logging to diagnose intermittent failures

---

## References

### Internal Documentation
- [Developer Workflow](../reference/dev_workflow.md) – Setup, commands, troubleshooting
- [Architecture: Verification Strategy](../../.codemachine/artifacts/plan/03_Verification_and_Glossary.md#verification-and-integration-strategy) – Testing philosophy and requirements
- [Platform Parity Checklist](../qa/platform_parity_checklist.md) – Manual QA procedures
- [History QA Checklist](../qa/history_qa_checklist.md) – Undo/redo validation
- [Recovery QA Playbook](../qa/recovery_qa_playbook.md) – Crash recovery testing

### External Resources
- [Flutter Testing Guide](https://docs.flutter.dev/testing/overview)
- [Effective Dart: Testing](https://dart.dev/guides/language/effective-dart/testing)
- [Golden File Testing](https://github.com/flutter/flutter/wiki/Writing-a-golden-file-test-for-package:flutter)
- [Integration Testing in Flutter](https://docs.flutter.dev/cookbook/testing/integration/introduction)

---

**Document Maintenance:**
This document should be updated when:
- New test types are introduced (e.g., fuzz testing, accessibility automation)
- Coverage targets change
- Performance benchmarks are revised
- CI/CD workflows are modified
- Significant testing patterns emerge from practice

For questions or improvements, contact the development team or open a GitHub issue.
