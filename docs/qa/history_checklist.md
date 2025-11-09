<!-- anchor: qa-history-checklist -->
# WireTuner History & Undo/Redo QA Checklist

**Version:** 1.0
**Iteration:** I4.T11
**Last Updated:** 2025-11-09
**Status:** Active

---

## Overview

This QA checklist validates the undo/redo navigation system, history panel, operation grouping, and timeline playback features delivered in Iteration 4. It covers both automated test verification and manual testing procedures to ensure platform parity between macOS and Windows.

**Reference Documentation:**
- [Undo Timeline Diagram](../diagrams/undo_timeline.mmd)
- [History Panel Usage](../reference/history_panel_usage.md)
- [Undo Label Reference](../reference/undo_labels.md)
- [History Debug Workflow](../reference/history_debug.md)
- [Crash Recovery Playbook](./recovery_playbook.md)
- [Verification Strategy](.codemachine/artifacts/plan/03_Verification_and_Glossary.md#verification-and-integration-strategy)

---

## Table of Contents

- [Automated Test Verification](#automated-test-verification)
- [Manual QA Procedures](#manual-qa-procedures)
  - [macOS Testing](#macos-testing)
  - [Windows Testing](#windows-testing)
- [Performance Benchmarks](#performance-benchmarks)
- [Platform Parity Matrix](#platform-parity-matrix)
- [Telemetry Validation](#telemetry-validation)
- [History Panel Testing](#history-panel-testing)
- [Troubleshooting Common Issues](#troubleshooting-common-issues)
- [Known Issues & Limitations](#known-issues--limitations)

---

## Automated Test Verification

### Prerequisites

- Flutter SDK installed and configured
- Development environment set up per I1 infrastructure
- All dependencies installed (`flutter pub get`)
- Iteration 4 tasks I4.T1-I4.T10 completed

### Test Execution

Run all automated tests for undo/redo and history functionality:

```bash
# Operation grouping tests
flutter test test/unit/operation_grouping_test.dart

# Undo navigator tests
flutter test test/unit/undo_navigator_test.dart

# History panel widget tests
flutter test test/widget/history_panel_test.dart

# Integration test for undo/redo workflows
flutter test test/integration/test/integration/undo_redo_navigation_test.dart

# History export/import tests
flutter test test/integration/test/integration/history_export_test.dart

# All tests
flutter test
```

### Expected Results

| Test Suite | Expected Outcome | Pass Criteria |
|------------|------------------|---------------|
| `operation_grouping_test.dart` | All tests pass | 100% pass rate, 200ms idle threshold validated |
| `undo_navigator_test.dart` | All tests pass | 100% pass rate, time-travel logic correct |
| `history_panel_test.dart` | All tests pass | UI updates reactively, scrubbing works |
| `undo_redo_navigation_test.dart` | All tests pass | Undo/redo latency <80ms, branch invalidation works |
| `history_export_test.dart` | All tests pass | Export/import round-trip preserves state |

**Acceptance Criteria:**
- ✅ All tests pass in headless CI environment
- ✅ No flaky tests (3 consecutive runs with same result)
- ✅ Test execution time < 5 minutes for full suite
- ✅ Code coverage ≥80% for `operation_grouping`, `undo_navigator`, `history_exporter`
- ✅ Undo latency <80ms (90th percentile)
- ✅ History scrubbing ≥5,000 events/sec

---

## Manual QA Procedures

### macOS Testing

**Test Environment:**
- macOS 13+ (Ventura or later)
- Physical device (MacBook Pro/Air) or VM
- External mouse + trackpad for gesture testing
- Keyboard with full modifier key support

#### Test Case M1: Basic Undo/Redo - Single Operation

**Objective:** Verify single-step undo and redo with keyboard shortcuts.

**Steps:**
1. Launch WireTuner application
2. Create a new document
3. Use pen tool (`P`) to create a complete path (3 anchors)
4. Press `Cmd+Z` to undo
5. Verify path is removed
6. Press `Cmd+Shift+Z` to redo
7. Verify path is restored exactly as created

**Expected:**
- Undo removes entire path atomically (all anchors together)
- Edit menu shows "Undo Create Path" before undo
- Edit menu shows "Redo Create Path" after undo
- Redo restores path with same position, handles, and style
- Undo/redo completes in <80ms (no visible lag)

**Platform-Specific:**
- **macOS:** Use `Cmd+Z` (undo), `Cmd+Shift+Z` (redo)

**Pass/Fail:** ⬜

---

#### Test Case M2: Operation Grouping - Sampled Events

**Objective:** Verify that sampled drag operations are grouped as single undo action.

**Steps:**
1. Activate selection tool (`V`)
2. Create a rectangle using rectangle tool
3. Select the rectangle
4. Drag rectangle ~200 pixels (2+ seconds of movement)
5. Release pointer
6. Press `Cmd+Z` (undo)
7. Verify rectangle returns to original position

**Expected:**
- Entire drag operation (40+ sampled MoveObjectEvents) grouped as one undo
- Single Cmd+Z undoes entire move, not individual samples
- Edit menu shows "Undo Move Objects"
- Rectangle jumps atomically to start position (no intermediate frames)
- 200ms idle threshold detected after pointer release

**Platform-Specific:**
- **macOS:** Smooth drag with trackpad or mouse

**Pass/Fail:** ⬜

---

#### Test Case M3: Redo Branch Invalidation

**Objective:** Verify redo history is cleared when new action taken after undo.

**Steps:**
1. Create two paths (Path A, Path B)
2. Press `Cmd+Z` to undo Path B creation
3. Verify Path B is removed
4. Verify Edit menu shows "Redo Create Path"
5. Create a new path (Path C) instead of redoing
6. Verify Edit menu no longer shows "Redo" option (disabled/grayed)
7. Press `Cmd+Z` to undo Path C
8. Press `Cmd+Shift+Z` to redo
9. Verify Path C is restored (NOT Path B)

**Expected:**
- Redo branch is invalidated after creating Path C
- Old redo history (Path B) is permanently cleared
- New redo history (Path C) replaces old branch
- Database pruned: events for Path B removed from event store
- Log message: "Redo branch invalidated"

**Platform-Specific:**
- **macOS:** Cmd+Z/Cmd+Shift+Z shortcuts

**Pass/Fail:** ⬜

---

#### Test Case M4: Multi-Operation Undo/Redo

**Objective:** Verify navigating through multiple undo/redo steps.

**Steps:**
1. Perform 5 operations:
   - Create Path A
   - Create Path B
   - Move Path A
   - Delete Path B
   - Create Path C
2. Press `Cmd+Z` five times (undo all)
3. Verify canvas is empty after 5 undos
4. Press `Cmd+Shift+Z` five times (redo all)
5. Verify all operations restored in correct order

**Expected:**
- Each Cmd+Z undoes one operation (not one event)
- Edit menu updates with correct operation labels
- Canvas state matches expected after each undo/redo
- All 5 operations restored exactly after redo
- No state drift or corruption

**Platform-Specific:**
- **macOS:** Cmd+Z/Cmd+Shift+Z keyboard shortcuts

**Pass/Fail:** ⬜

---

#### Test Case M5: Undo Performance - Snapshot Optimization

**Objective:** Verify undo latency meets <80ms target using snapshots.

**Steps:**
1. Create a document with 100+ objects
2. Perform operations until event sequence reaches ~2500
3. Verify snapshot exists at sequence 2000 (check logs or database)
4. Press `Cmd+Z` to undo last operation
5. Measure undo latency (check console logs for metrics)
6. Repeat undo 10 times, observe average latency

**Expected:**
- Undo uses snapshot at sequence 2000 (not replay from 0)
- Undo latency: <80ms (90th percentile)
- Typical latency: 20-50ms
- Log message: "Found snapshot at seq=2000"
- No visible lag or frame drops during undo

**Measurement:**
- Check console logs for "Undo latency" metrics
- Or use performance overlay (Cmd+Shift+P) to monitor frame time

**Platform-Specific:**
- **macOS:** Monitor Activity Monitor for CPU spikes

**Pass/Fail:** ⬜

---

#### Test Case M6: Undo at Document Boundaries

**Objective:** Verify undo/redo behavior at start/end of history.

**Steps:**
1. Create a new empty document
2. Create one path
3. Press `Cmd+Z` to undo (back to empty)
4. Press `Cmd+Z` again (attempt undo past beginning)
5. Verify no error, Edit menu shows "Undo" disabled
6. Press `Cmd+Shift+Z` to redo
7. Press `Cmd+Shift+Z` again (attempt redo past end)
8. Verify no error, Edit menu shows "Redo" disabled

**Expected:**
- Undo at beginning of history does nothing (graceful)
- Redo at end of history does nothing (graceful)
- Menu items disabled when at boundaries
- No crashes or error dialogs
- Log messages: "Already at beginning/end of history"

**Platform-Specific:**
- **macOS:** Cmd+Z/Cmd+Shift+Z shortcuts

**Pass/Fail:** ⬜

---

#### Test Case M7: History Panel Navigation

**Objective:** Verify history panel displays operations and allows scrubbing.

**Steps:**
1. Open history panel (View → History Panel or shortcut)
2. Create 5 operations (paths, moves, etc.)
3. Verify history panel lists all 5 operations with labels
4. Click on operation #2 in history panel
5. Verify document state jumps to after operation #2
6. Verify canvas shows only first 2 operations
7. Verify current position indicator (►) at operation #2

**Expected:**
- History panel updates reactively as operations complete
- Operation labels match Edit menu labels (e.g., "Create Path")
- Clicking entry triggers undo/redo navigation to that position
- Current position marked clearly (► or highlight)
- Scrubbing performance: 5,000 events/sec (smooth)

**Platform-Specific:**
- **macOS:** History panel UI rendering

**Pass/Fail:** ⬜

---

#### Test Case M8: History Timeline Playback

**Objective:** Verify timeline scrubber for interactive history navigation.

**Steps:**
1. Create 10+ operations
2. Open history panel with timeline scrubber
3. Drag scrubber to middle of timeline
4. Verify document state updates in real-time
5. Drag scrubber rapidly back and forth
6. Verify no lag, stuttering, or crashes
7. Release scrubber at specific operation
8. Verify document state matches selected point

**Expected:**
- Real-time preview during scrubbing (if implemented)
- Smooth playback: 5,000 events/sec scrubbing rate
- No visible lag or frame drops
- Final state matches selected timeline position
- Telemetry: "History scrubbing performance" logged

**Platform-Specific:**
- **macOS:** Trackpad or mouse dragging

**Pass/Fail:** ⬜

---

#### Test Case M9: Undo with Crash Recovery

**Objective:** Verify undo history survives crash and recovery.

**Steps:**
1. Create 5 operations
2. Undo 2 operations (back to operation #3)
3. Force-quit application (Cmd+Option+Esc or `killall wiretuner`)
4. Relaunch WireTuner
5. Open the same document
6. Verify undo position preserved (at operation #3)
7. Press `Cmd+Z` to undo further
8. Verify undo continues from correct position

**Expected:**
- Undo position persisted in database/navigator state
- No loss of undo history after crash
- Redo branch preserved if applicable
- Recovery time <100ms per crash recovery requirements
- See [Crash Recovery Playbook](./recovery_playbook.md) for details

**Platform-Specific:**
- **macOS:** Force-quit via Activity Monitor

**Pass/Fail:** ⬜

---

#### Test Case M10: Undo Label Accuracy

**Objective:** Verify undo labels match operation types per specification.

**Steps:**
1. Perform each operation type:
   - Pen tool: Create path → "Create Path"
   - Selection tool: Move objects → "Move Objects"
   - Direct selection: Move anchor → "Move Anchor"
   - Direct selection: Adjust handle → "Adjust Handle"
   - Rectangle tool: Create rectangle → "Create Rectangle"
2. For each operation, press `Cmd+Z` and check Edit menu label

**Expected:**
- Edit menu shows "Undo <Label>" format
- Labels match [Undo Label Reference](../reference/undo_labels.md)
- No generic labels like "Undo Action" or "Undo Event"
- All tools integrate correctly with operation grouping

**Platform-Specific:**
- **macOS:** Edit menu rendering

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
| Cmd (⌘) | Ctrl | Undo, Redo |
| Cmd+Shift+Z | Ctrl+Y or Ctrl+Shift+Z | Redo |
| Option (⌥) | Alt | (Context: tool modifiers) |
| Shift (⇧) | Shift | (Context: tool modifiers) |

#### Test Case W1-W10: Repeat M1-M10 on Windows

Execute test cases M1 through M10 on Windows platform with the following adjustments:

**Key Substitutions:**
- Replace `Cmd+Z` with `Ctrl+Z` (undo)
- Replace `Cmd+Shift+Z` with `Ctrl+Y` or `Ctrl+Shift+Z` (redo)
- History panel shortcuts: Verify Windows-specific bindings
- Force-quit: Use Task Manager (Ctrl+Shift+Esc) → End Task

**Expected Behavior:**
- All test cases should produce identical results to macOS
- Performance metrics should be within ±10% of macOS benchmarks
- UI feedback (menus, panels, tooltips) should match macOS appearance
- Redo shortcut: Both `Ctrl+Y` and `Ctrl+Shift+Z` should work

**Pass/Fail:** ⬜ (for each test case W1-W10)

---

## Performance Benchmarks

### Undo/Redo Performance Targets (Iteration 4 KPIs)

| Metric | Target | Measurement Method | Acceptance |
|--------|--------|-------------------|------------|
| Undo latency | < 80 ms | Instrumented timer in UndoNavigator | 90th percentile < 80 ms |
| Redo latency | < 80 ms | Instrumented timer in UndoNavigator | 90th percentile < 80 ms |
| Operation grouping idle threshold | 200 ms | OperationGroupingService config | Exactly 200 ms |
| History scrubbing rate | ≥ 5,000 events/sec | Benchmark harness | Sustained playback |
| Snapshot retrieval | < 50 ms | SnapshotStore query time | Average < 50 ms |
| Event replay rate | ≥ 1,000 events/sec | EventReplayer benchmark | Replay throughput |

### Benchmark Execution

Run performance benchmarks:

```bash
# Undo/redo navigation benchmarks
flutter test test/performance/undo_navigation_benchmark.dart

# History scrubbing stress test
flutter test test/performance/history_scrubbing_benchmark.dart

# Operation grouping timing validation
flutter test test/performance/operation_grouping_benchmark.dart
```

**Results Storage:**
- Benchmark outputs saved to `test/performance/results/`
- JSON format for regression tracking
- Compare against baseline from I4.T1-I4.T8

---

## Platform Parity Matrix

### Undo/Redo Feature Parity Checklist

| Feature | macOS | Windows | Notes |
|---------|-------|---------|-------|
| Undo shortcut (Cmd/Ctrl+Z) | ⬜ | ⬜ | Keyboard event handling |
| Redo shortcut (Cmd+Shift+Z) | ⬜ | ⬜ | macOS: Cmd+Shift+Z |
| Redo shortcut (Ctrl+Y) | N/A | ⬜ | Windows: Ctrl+Y also works |
| Edit menu "Undo <Label>" | ⬜ | ⬜ | Dynamic label updates |
| Edit menu "Redo <Label>" | ⬜ | ⬜ | Dynamic label updates |
| Operation grouping (200ms) | ⬜ | ⬜ | Idle threshold detection |
| Undo latency < 80ms | ⬜ | ⬜ | Snapshot optimization |
| Redo latency < 80ms | ⬜ | ⬜ | Forward navigation |
| Redo branch invalidation | ⬜ | ⬜ | Clear on new action |
| History panel display | ⬜ | ⬜ | Operation list with labels |
| History panel scrubbing | ⬜ | ⬜ | Click to navigate |
| Timeline scrubber | ⬜ | ⬜ | Drag to scrub (if implemented) |
| Undo at boundaries | ⬜ | ⬜ | Graceful no-op |
| Multi-window isolated stacks | ⬜ | ⬜ | Per-window undo state |
| Crash recovery preservation | ⬜ | ⬜ | Position survives restart |

**Acceptance:** All checkboxes must be marked ✅ for both platforms before release.

---

## Telemetry Validation

### Expected Telemetry Ranges (from I4 Metrics)

**Undo/Redo Performance:**
- Average latency: 20-50 ms (typical)
- 90th percentile: < 80 ms (hard limit per I4 KPIs)
- 99th percentile: < 120 ms (acceptable outlier)
- Snapshot hit rate: > 95% (most undos use snapshot)

**Operation Grouping:**
- Idle threshold: 200 ms (exact, not approximate)
- Group completion latency: < 5 ms
- Average events per group: 1-40 (depends on operation)
- Single-event operations: ~30% of total

**History Scrubbing:**
- Scrubbing rate: 5,000-10,000 events/sec (interactive)
- Background replay: 1,000-5,000 events/sec (preview)
- Frame time during scrub: < 16 ms (60 FPS maintained)

**Event Store:**
- Redo branch pruning: < 10 ms (DELETE query)
- Event count after prune: Reduced by invalidated count
- Snapshot retrieval: 5-20 ms (typical)

### Telemetry Collection

Enable telemetry in test runs:

```bash
# Run integration test with telemetry
flutter test test/integration/test/integration/undo_redo_navigation_test.dart --verbose

# Check console output for metrics
# Example:
# === Undo/Redo Navigation Metrics ===
# Undo Latency (avg): 35.2 ms
# Undo Latency (p90): 67.4 ms
# Redo Latency (avg): 28.1 ms
# Snapshot Hit Rate: 97.3%
# Operation Group Count: 45
# Redo Branch Invalidations: 3
# ===================================
```

**Validation:**
- All metrics must fall within documented ranges
- No performance regressions vs. I4.T1 baseline
- Document any deviations in known issues section

---

## History Panel Testing

### History Panel UI Checklist

| Feature | Test Procedure | Pass/Fail |
|---------|---------------|-----------|
| Panel opens via menu | View → History Panel | ⬜ |
| Panel shows operation list | Verify all operations visible | ⬜ |
| Current position indicator | Verify ► marker or highlight | ⬜ |
| Operation labels correct | Match [Undo Label Reference](../reference/undo_labels.md) | ⬜ |
| Click to navigate | Click entry, verify state change | ⬜ |
| Scroll performance | Smooth scrolling with 100+ operations | ⬜ |
| Real-time updates | Panel updates when new operation completes | ⬜ |
| Redo branch grayed out | Invalidated operations shown differently | ⬜ |
| Keyboard navigation | Arrow keys navigate history (if implemented) | ⬜ |
| Tooltips/context menus | Right-click shows options (future) | ⬜ |

### Timeline Scrubber Checklist (If Implemented)

| Feature | Test Procedure | Pass/Fail |
|---------|---------------|-----------|
| Scrubber visible | Timeline bar shown below operation list | ⬜ |
| Drag to scrub | Drag handle updates document state | ⬜ |
| Smooth playback | No stuttering at 5,000 events/sec | ⬜ |
| Position indicator | Handle syncs with current operation | ⬜ |
| Keyboard shortcuts | Left/Right arrows step through timeline | ⬜ |
| Playback controls | Play/pause for auto-scrubbing (future) | ⬜ |

---

## Troubleshooting Common Issues

### Issue: Undo latency exceeds 80ms

**Symptoms:**
- Visible lag when pressing Cmd+Z
- Frame drops during undo
- Console shows "Undo latency: 150ms" or higher

**Possible Causes:**
1. No snapshot exists (replaying from event 0)
2. Large number of delta events since snapshot (>1,000)
3. Complex event replay (e.g., heavy geometry calculations)
4. Slow disk I/O (HDD vs SSD)

**Diagnosis:**
```bash
# Check snapshot status
sqlite3 document.wiretuner "SELECT MAX(event_sequence) FROM snapshots;"
# Compare to current sequence
sqlite3 document.wiretuner "SELECT MAX(event_sequence) FROM events WHERE document_id='your-doc-id';"
```

**Resolution:**
- Verify adaptive snapshot cadence is working (every 1,000 events)
- Check snapshot compression is enabled (gzip)
- Run on SSD if possible
- See [Snapshot Strategy](../reference/snapshot_strategy.md)

---

### Issue: Redo history lost unexpectedly

**Symptoms:**
- User expects redo to be available but menu is disabled
- Redo history cleared without obvious new action

**Possible Causes:**
1. User took new action after undo (expected behavior)
2. Event recorded automatically (e.g., auto-save, telemetry)
3. Multi-window race condition (one window invalidated other)

**Diagnosis:**
- Check console logs for "Redo branch invalidated" messages
- Verify new events were recorded after undo position
- Check event sequence for unexpected events

**Resolution:**
- Educate user: Redo is cleared when new action taken (expected)
- If unintended: Check for background event recording (bug)
- Multi-window: Verify isolated undo stacks per Decision 2

---

### Issue: History panel not updating

**Symptoms:**
- History panel shows stale operation list
- New operations not appearing in panel
- Current position indicator not moving

**Possible Causes:**
1. Provider not notifying listeners
2. Widget not watching ToolTelemetry provider
3. Operation grouping not completing (200ms idle threshold not reached)

**Diagnosis:**
```dart
// Check provider setup
final telemetry = context.watch<ToolTelemetry>();
// Should rebuild widget on notifyListeners()
```

**Resolution:**
- Verify `context.watch<ToolTelemetry>()` used (not `read`)
- Check `notifyListeners()` called in OperationGroupingService
- Verify 200ms idle period after operation

---

### Issue: Timeline playback jitter

**Symptoms:**
- Stuttering during timeline scrubbing
- Frame drops when dragging scrubber
- Playback rate below 5,000 events/sec

**Possible Causes:**
1. Event replay inefficiency (complex events)
2. Rendering overhead (too many redraws)
3. Background tasks interfering
4. Insufficient CPU/memory

**Diagnosis:**
- Enable performance overlay (Cmd+Shift+P)
- Monitor frame time during scrubbing
- Run benchmark: `flutter test test/performance/history_scrubbing_benchmark.dart`

**Resolution:**
- Optimize event replay (batch updates, viewport culling)
- Reduce render frequency during scrub (throttle paints)
- Close other windows/applications
- See [Rendering Troubleshooting Guide](../reference/rendering_troubleshooting.md)

---

### Issue: Operation labels incorrect or missing

**Symptoms:**
- Edit menu shows "Undo" instead of "Undo Create Path"
- History panel shows blank labels
- Labels don't match operation type

**Possible Causes:**
1. Tool not calling `endUndoGroup()` with label
2. ToolTelemetry integration missing
3. Label string mismatch vs. specification

**Diagnosis:**
```bash
# Check telemetry logs
grep "endUndoGroup" console_output.log
# Should show label parameter
```

**Resolution:**
- Verify tool calls `telemetry.endUndoGroup(toolId, groupId, label)`
- Check label against [Undo Label Reference](../reference/undo_labels.md)
- Add missing telemetry integration to tool

---

## Known Issues & Limitations

### Current Limitations (as of I4.T11)

1. **Timeline Scrubber UI:** Partially implemented
   - Basic history panel works (operation list)
   - Advanced timeline scrubber with drag preview may be placeholder
   - Mitigation: Click operations in list to navigate

2. **Multi-Window Undo Coordination:** Basic isolation only
   - Each window has isolated undo stack (correct)
   - Cross-window undo synchronization not yet implemented
   - Deferred to future iteration

3. **Undo Label Localization:** Not implemented
   - All labels in English only
   - Future: i18n support for labels
   - See [Undo Label Reference](../reference/undo_labels.md#future-enhancements)

4. **Large Document Undo Performance:** Degradation possible
   - Undo latency may exceed 80ms for documents with 10,000+ objects
   - Snapshot optimization reduces impact but not eliminates
   - Target: Maintain < 120ms even for very large docs

5. **History Export/Import:** Dev-only feature
   - CLI tool experimental status
   - See [History Debug Workflow](../reference/history_debug.md)
   - Not intended for end-user workflows

### Regression Risks

**Monitor for:**
- Undo latency increases (regression in snapshot optimization)
- Operation grouping threshold drift (must remain 200ms)
- Redo branch invalidation failures (stale redo history)
- History panel memory leaks (large operation lists)

**Prevention:**
- Run undo/redo benchmarks in CI before each release
- Compare metrics against baseline from I4.T1-I4.T8
- Alert if 90th percentile undo latency exceeds 80ms
- Alert if snapshot hit rate drops below 95%

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
- [ ] History panel functional and tested
- [ ] Known issues documented and triaged
- [ ] Documentation anchors updated (`plan_manifest.json`)

**QA Lead Approval:** ___________________ Date: __________

**Release Manager Approval:** ___________________ Date: __________

---

**Document Version:** 1.0
**Iteration:** I4.T11
**Maintainer:** WireTuner QA Team
**Next Review:** I5.T1 (Import/Export Feature Integration)
