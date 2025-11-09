<!-- anchor: qa-tooling-checklist -->
# WireTuner Tooling QA Checklist

**Version:** 1.0
**Iteration:** I3.T10
**Last Updated:** 2025-11-09
**Status:** Active

---

## Overview

This QA checklist validates the tool framework, selection tool, and pen tool implementations delivered in Iteration 3. It covers both automated test verification and manual testing procedures to ensure platform parity between macOS and Windows.

**Reference Documentation:**
- [Pen Tool Usage](../reference/tools/pen_tool_usage.md)
- [Verification Strategy](.codemachine/artifacts/plan/03_Verification_and_Glossary.md#verification-and-integration-strategy)
- [Decision 6: Platform Parity](.codemachine/artifacts/decisions/006_platform_parity.md)

---

## Table of Contents

- [Automated Test Verification](#automated-test-verification)
- [Manual QA Procedures](#manual-qa-procedures)
  - [macOS Testing](#macos-testing)
  - [Windows Testing](#windows-testing)
- [Performance Benchmarks](#performance-benchmarks)
- [Platform Parity Matrix](#platform-parity-matrix)
- [Telemetry Validation](#telemetry-validation)
- [Known Issues & Limitations](#known-issues--limitations)

---

## Automated Test Verification

### Prerequisites

- Flutter SDK installed and configured
- Development environment set up per I1 infrastructure
- All dependencies installed (`flutter pub get`)

### Test Execution

Run all automated tests in headless mode:

```bash
# Unit tests for tools
flutter test test/unit/tools/

# Widget tests for pen + selection tools
flutter test test/widget/pen_tool_bezier_test.dart
flutter test test/widget/selection_tool_test.dart

# Integration test for pen + selection interplay
flutter test test/integration/test/integration/tool_pen_selection_test.dart

# All tests
flutter test
```

### Expected Results

| Test Suite | Expected Outcome | Pass Criteria |
|------------|------------------|---------------|
| `pen_tool_bezier_test.dart` | All tests pass | 100% pass rate, coverage ≥80% |
| `selection_tool_test.dart` | All tests pass | 100% pass rate, coverage ≥80% |
| `tool_pen_selection_test.dart` | All tests pass | 100% pass rate, tool switch <30ms |
| Integration replay tests | Deterministic replay | Identical results across 3+ runs |

**Acceptance Criteria:**
- ✅ All tests pass in headless CI environment
- ✅ No flaky tests (3 consecutive runs with same result)
- ✅ Test execution time < 5 minutes for full suite
- ✅ Code coverage ≥80% for `tool_framework`, `pen_tool`, `selection_tool`

---

## Manual QA Procedures

### macOS Testing

**Test Environment:**
- macOS 13+ (Ventura or later)
- Physical device (MacBook Pro/Air) or VM
- External mouse + trackpad for gesture testing
- Keyboard with full modifier key support

#### Test Case M1: Pen Tool - Basic Path Creation

**Objective:** Verify pen tool creates straight-line paths with click interactions.

**Steps:**
1. Launch WireTuner application
2. Press `P` to activate pen tool (or click pen tool icon)
3. Click at point A (100, 100)
4. Click at point B (200, 100)
5. Click at point C (200, 200)
6. Press `Enter` to finish path

**Expected:**
- Path preview shows dashed line from last anchor to cursor
- Final path has 3 anchors connected by straight segments
- Path remains selected after creation
- Undo (`Cmd+Z`) removes entire path atomically

**Platform-Specific:**
- **macOS:** Use `Cmd+Z` for undo
- **macOS:** Cursor changes to crosshair when pen tool active

**Pass/Fail:** ⬜

---

#### Test Case M2: Pen Tool - Bezier Curves with Handles

**Objective:** Verify drag-to-create Bezier anchors with symmetrical handles.

**Steps:**
1. Activate pen tool (`P`)
2. Click at point A (100, 100) — first anchor
3. Click-drag from point B (200, 100) to (250, 80) — drag distance ≥5 units
4. Release mouse
5. Press `Enter` to finish

**Expected:**
- Second anchor has visible handles extending from anchor point
- Handles are symmetrical (handleIn = -handleOut)
- Curve segment smoothly connects A to B
- Drag distance < 5 units creates straight line (threshold behavior)

**Pass/Fail:** ⬜

---

#### Test Case M3: Pen Tool - Shift Angle Constraint

**Objective:** Verify Shift key constrains handle angles to 45° increments.

**Steps:**
1. Activate pen tool
2. Click first anchor at (100, 100)
3. **Hold Shift** key
4. Click-drag from (200, 100) to arbitrary position (e.g., 230, 120)
5. Release mouse (keep Shift held)
6. Observe handle angle
7. Release Shift

**Expected:**
- Handle snaps to nearest 45° angle (0°, 45°, 90°, 135°, etc.)
- Visual feedback shows constrained angle during drag
- Magnitude (length) preserved, only direction constrained
- Releasing Shift returns to free-angle mode for next anchor

**Platform-Specific:**
- **macOS:** Shift key must be left or right Shift (both work)

**Pass/Fail:** ⬜

---

#### Test Case M4: Pen Tool - Alt Independent Handles

**Objective:** Verify Alt/Option key creates corner anchors with independent handles.

**Steps:**
1. Activate pen tool
2. Click first anchor
3. **Hold Alt/Option** key (macOS: Option key)
4. Click-drag to create second anchor
5. Release mouse
6. Observe handle configuration

**Expected:**
- Only `handleOut` created (outgoing handle)
- `handleIn` is null (no incoming constraint)
- Creates corner/cusp anchor type
- Allows sharp direction changes in path

**Platform-Specific:**
- **macOS:** Use Option key (⌥)
- Key label may show "Alt" or "Option" depending on keyboard

**Pass/Fail:** ⬜

---

#### Test Case M5: Selection Tool - Click Selection

**Objective:** Verify single-click selection of vector objects.

**Steps:**
1. Create a path using pen tool
2. Press `V` to activate selection tool (or click selection icon)
3. Click on the path
4. Verify selection state
5. Click on empty canvas area
6. Verify selection clears

**Expected:**
- Clicked path shows selection outline/handles
- Only one object selected (unless Shift held)
- Clicking empty area clears selection
- Selection persists across tool switches

**Pass/Fail:** ⬜

---

#### Test Case M6: Selection Tool - Marquee Selection

**Objective:** Verify drag-to-create marquee rectangle selection.

**Steps:**
1. Create 3 paths in different positions
2. Activate selection tool
3. Click in empty area and drag to create marquee
4. Drag marquee to cover 2 of the 3 paths
5. Release mouse
6. Verify selection

**Expected:**
- Dashed marquee rectangle appears during drag
- All objects within marquee bounds are selected
- Objects partially intersecting marquee are included
- Selection replaces previous selection (unless Shift held)

**Pass/Fail:** ⬜

---

#### Test Case M7: Selection Tool - Shift Multi-Select

**Objective:** Verify Shift-click adds/removes objects from selection.

**Steps:**
1. Create 3 paths
2. Click path A (selects A)
3. **Hold Shift**, click path B (A + B selected)
4. **Hold Shift**, click path C (A + B + C selected)
5. **Hold Shift**, click path B again (A + C selected, B deselected)

**Expected:**
- Shift-click toggles object selection state
- Multiple objects can be selected simultaneously
- Selection handles shown for all selected objects
- Move operations affect all selected objects

**Platform-Specific:**
- **macOS:** Use Shift key (⇧)

**Pass/Fail:** ⬜

---

#### Test Case M8: Tool Switching Performance

**Objective:** Verify tool switch latency < 30 ms (I3 success indicator).

**Steps:**
1. Open browser DevTools or performance monitor
2. Activate pen tool (`P`)
3. Immediately activate selection tool (`V`)
4. Measure time between keypress and UI update
5. Repeat 10 times and calculate average

**Expected:**
- Tool switch completes in < 30 ms (average)
- No visible lag or frame drops
- Cursor updates immediately
- Previous tool state cleaned up properly

**Measurement:**
- Use browser performance timeline
- Or check console logs if telemetry enabled
- Acceptance: 90th percentile < 30 ms

**Pass/Fail:** ⬜

---

#### Test Case M9: Undo/Redo with Tool Interactions

**Objective:** Verify undo/redo correctly navigates event history across tools.

**Steps:**
1. Activate pen tool, create path A (3 anchors), finish
2. Activate selection tool, select path A
3. Press `Cmd+Z` (undo)
4. Verify path A removed
5. Press `Cmd+Shift+Z` (redo)
6. Verify path A restored

**Expected:**
- Undo removes entire path (grouped event)
- Redo restores path exactly as created
- Selection state preserved during undo/redo
- Tool state remains consistent

**Platform-Specific:**
- **macOS:** `Cmd+Z` (undo), `Cmd+Shift+Z` (redo)

**Pass/Fail:** ⬜

---

#### Test Case M10: Escape Key Cancellation

**Objective:** Verify Escape key cancels in-progress operations.

**Steps:**
1. Activate pen tool
2. Click 2 anchors (start path)
3. Press `Escape` key
4. Verify path discarded
5. Activate selection tool
6. Start marquee drag
7. Press `Escape` during drag
8. Verify marquee cancelled

**Expected:**
- Escape cancels pen tool path creation (no events recorded)
- Escape cancels selection marquee (no selection change)
- Tool returns to idle state
- No partial/incomplete objects left in document

**Pass/Fail:** ⬜

---

### Windows Testing

**Test Environment:**
- Windows 10/11
- Physical device or VM
- Mouse with scroll wheel
- Keyboard with Ctrl, Alt, Shift keys

**Modifier Key Mapping:**

| macOS Key | Windows Key | Function |
|-----------|-------------|----------|
| Cmd (⌘) | Ctrl | Undo, shortcuts |
| Option (⌥) | Alt | Independent handles |
| Shift (⇧) | Shift | Angle constraint, multi-select |

#### Test Case W1-W10: Repeat M1-M10 on Windows

Execute test cases M1 through M10 on Windows platform with the following adjustments:

**Key Substitutions:**
- Replace `Cmd+Z` with `Ctrl+Z` (undo)
- Replace `Cmd+Shift+Z` with `Ctrl+Y` or `Ctrl+Shift+Z` (redo)
- Replace `Option` with `Alt` for independent handles
- Shift and Escape keys identical to macOS

**Expected Behavior:**
- All test cases should produce identical results to macOS
- Performance metrics should be within ±10% of macOS benchmarks
- UI feedback (cursors, overlays) should match macOS appearance

**Pass/Fail:** ⬜ (for each test case W1-W10)

---

## Performance Benchmarks

### Tool Framework Performance Targets

| Metric | Target | Measurement Method | Acceptance |
|--------|--------|-------------------|------------|
| Tool switch latency | < 30 ms | Instrumented timer in ToolManager | 90th percentile < 30 ms |
| Selection accuracy | ≥ 99% | Hit-test suite (automated) | 99%+ pass rate |
| Event sampling rate | 50 ms | Pointer event throttle | Max 20 events/sec |
| Frame time (rendering) | < 16.67 ms | RenderPipeline metrics | 60 FPS maintained |
| Undo navigation | < 100 ms | EventReplayer benchmark | Replay 1000 events < 100 ms |

### Benchmark Execution

Run performance benchmarks:

```bash
# Tool framework benchmarks
flutter test test/performance/tool_switching_benchmark.dart

# Render pipeline stress test
flutter test test/performance/render_stress_test.dart
```

**Results Storage:**
- Benchmark outputs saved to `test/performance/results/`
- JSON format for regression tracking
- Compare against baseline from I3.T9

---

## Platform Parity Matrix

### Feature Parity Checklist (Decision 6)

| Feature | macOS | Windows | Notes |
|---------|-------|---------|-------|
| Pen tool activation | ⬜ | ⬜ | Keyboard shortcut `P` |
| Click to create line anchors | ⬜ | ⬜ | Threshold: 5 world units |
| Drag to create Bezier anchors | ⬜ | ⬜ | Symmetrical handles by default |
| Shift angle constraint | ⬜ | ⬜ | 45° increments |
| Alt independent handles | ⬜ | ⬜ | macOS: Option, Windows: Alt |
| Enter to finish path | ⬜ | ⬜ | Keyboard event handling |
| Double-click to finish | ⬜ | ⬜ | 500 ms threshold |
| Close path (click first anchor) | ⬜ | ⬜ | 10 unit proximity |
| Escape to cancel | ⬜ | ⬜ | Discard in-progress path |
| Selection tool activation | ⬜ | ⬜ | Keyboard shortcut `V` |
| Click selection | ⬜ | ⬜ | Single object |
| Marquee selection | ⬜ | ⬜ | Drag rectangle |
| Shift multi-select | ⬜ | ⬜ | Toggle selection |
| Object move (drag) | ⬜ | ⬜ | Delta events |
| Undo (Cmd/Ctrl+Z) | ⬜ | ⬜ | Event navigation |
| Redo (Cmd+Shift+Z / Ctrl+Y) | ⬜ | ⬜ | Forward navigation |
| Tool switch latency | ⬜ | ⬜ | < 30 ms target |
| Cursor feedback | ⬜ | ⬜ | Crosshair (pen), arrow (selection) |
| Preview overlay | ⬜ | ⬜ | Dashed lines, handles |

**Acceptance:** All checkboxes must be marked ✅ for both platforms before release.

---

## Telemetry Validation

### Expected Telemetry Ranges (from I3.T9 Metrics)

**Tool Switching:**
- Average latency: 5-15 ms (typical)
- 90th percentile: < 30 ms (hard limit)
- 99th percentile: < 50 ms (acceptable outlier)

**Event Volume:**
- Typical path (10 anchors): 13 events (1 start + 1 create + 9 add + 1 finish + 1 end)
- Events/second during active drawing: 10-20 (throttled)
- Peak event burst: ≤ 50 events/sec (during rapid tool switching)

**Frame Time:**
- Idle: < 5 ms/frame
- Active drawing (pen tool): < 10 ms/frame
- Complex selection (100+ objects): < 16 ms/frame (60 FPS)

**Memory:**
- Event buffer size: < 10 MB (for 1000 events)
- Snapshot compression ratio: > 50% (gzip)
- Overlay painter allocations: < 1 MB/frame

### Telemetry Collection

Enable telemetry in test runs:

```bash
# Run integration test with telemetry
flutter test test/integration/test/integration/tool_pen_selection_test.dart --verbose

# Check console output for metrics
# Example:
# === Workflow Telemetry Metrics ===
# Tool Switch Latency (avg): 12.34 ms
# Tool Switch Latency (max): 28.56 ms
# Total Events: 15
# Event Sampling Rate: 50 ms
# ===================================
```

**Validation:**
- All metrics must fall within documented ranges
- No performance regressions vs. I3.T9 baseline
- Document any deviations in known issues section

---

## Known Issues & Limitations

### Current Limitations (as of I3.T10)

1. **Direct Selection Tool:** Not yet implemented (planned for I4)
   - Cannot select individual anchors for manipulation
   - Workaround: Use pen tool handle adjustment mode

2. **Multi-Layer Selection:** Limited support
   - Selection works within single layer
   - Cross-layer selection deferred to I4

3. **Touch Input:** Not fully tested
   - Tablet/stylus input may have gesture conflicts
   - Trackpad gestures may interfere with marquee

4. **High-DPI Displays:** Scaling issues
   - Handle sizes may appear too small on Retina/4K displays
   - Mitigation: Viewport zoom compensates

### Regression Risks

**Monitor for:**
- Tool switch performance degradation (watch for memory leaks)
- Event replay non-determinism (check for timestamp dependencies)
- Selection accuracy on complex paths (hit-test edge cases)
- Undo/redo state corruption (verify event sequence integrity)

---

## Sign-Off

### QA Execution Log

| Platform | Tester | Date | Automated | Manual | Pass/Fail | Notes |
|----------|--------|------|-----------|--------|-----------|-------|
| macOS 14 | _____  | ____ | ⬜ | ⬜ | ⬜ | |
| Windows 11 | _____ | ____ | ⬜ | ⬜ | ⬜ | |

### Release Criteria

- [ ] All automated tests pass headless (CI green)
- [ ] macOS manual QA checklist 100% complete
- [ ] Windows manual QA checklist 100% complete
- [ ] Platform parity matrix 100% ✅
- [ ] Performance benchmarks within target ranges
- [ ] Telemetry validated and documented
- [ ] Known issues documented and triaged
- [ ] Manifest anchors updated (`plan_manifest.json`)

**QA Lead Approval:** ___________________ Date: __________

**Release Manager Approval:** ___________________ Date: __________

---

**Document Version:** 1.0
**Iteration:** I3.T10
**Maintainer:** WireTuner QA Team
**Next Review:** I4.T1 (Direct Selection Implementation)
