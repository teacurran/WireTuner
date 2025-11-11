<!-- anchor: qa-crash-recovery-playbook -->
# WireTuner Crash Recovery QA Playbook

**Version:** 1.0
**Iteration:** I4.T9
**Last Updated:** 2025-11-09
**Status:** Active

---

## Overview

This QA playbook validates the crash recovery mechanism delivered in Iteration 4, Task 9 (I4.T9). It ensures that WireTuner can recover from abrupt termination (crashes, force-quits, system failures) without data loss and within performance targets.

**Reference Documentation:**
- [Snapshot Strategy](../reference/snapshot_strategy.md)
- [Operational Architecture: Reliability](.codemachine/artifacts/architecture/05_Operational_Architecture.md#reliability-fault-tolerance)
- [Decision 1: Event Sourcing Architecture](.codemachine/artifacts/decisions/001_event_sourcing.md)
- [Verification Strategy](.codemachine/artifacts/plan/03_Verification_and_Glossary.md#verification-and-integration-strategy)

---

## Table of Contents

- [Automated Test Verification](#automated-test-verification)
- [Manual QA Procedures](#manual-qa-procedures)
  - [macOS Testing](#macos-testing)
  - [Windows Testing](#windows-testing)
- [Performance Benchmarks](#performance-benchmarks)
- [Recovery Scenarios Matrix](#recovery-scenarios-matrix)
- [Telemetry Validation](#telemetry-validation)
- [Known Issues & Limitations](#known-issues--limitations)

---

## Automated Test Verification

### Prerequisites

- Flutter SDK installed and configured
- Development environment set up per I1 infrastructure
- All dependencies installed (`flutter pub get`)
- Temporary file system access for test database files

### Test Execution

Run the crash recovery integration test:

```bash
# Run crash recovery test suite
flutter test test/integration/test/integration/crash_recovery_test.dart

# Run with verbose output to see metrics
flutter test test/integration/test/integration/crash_recovery_test.dart --verbose
```

### Expected Results

| Test Case | Expected Outcome | Pass Criteria |
|-----------|------------------|---------------|
| Mid-operation crash | State fully recovered | Recovery time < 100 ms, zero data loss |
| Corrupted snapshot | Fallback to previous snapshot | Graceful degradation, warnings logged |
| Large event backlog | Fast recovery via snapshot | Recovery < 100 ms despite 50+ events |
| WAL data loss prevention | All events recovered | Zero events lost after crash |

**Acceptance Criteria:**
- ✅ All 4 test cases pass
- ✅ Recovery time < 100 ms for typical documents (per Decision 1)
- ✅ Zero data loss in all scenarios
- ✅ Corrupted snapshot fallback mechanism validated
- ✅ Metrics printed and documented

---

## Manual QA Procedures

### macOS Testing

**Test Environment:**
- macOS 13+ (Ventura or later)
- Physical device (MacBook Pro/Air) or VM
- Sufficient disk space (~500 MB free)
- User with admin privileges (for force-quit)

#### Test Case M1: Force-Quit During Drawing

**Objective:** Verify recovery from forced application termination mid-operation.

**Steps:**
1. Launch WireTuner application
2. Create a new document
3. Use pen tool to draw 2-3 paths with multiple anchors
4. While drawing the 3rd path (before finishing):
   - Press **Cmd+Option+Esc** (Force Quit dialog)
   - Select WireTuner and click "Force Quit"
   - Or: Run `killall -9 wiretuner` from Terminal
5. Wait 2-3 seconds
6. Relaunch WireTuner
7. Open the document from step 2

**Expected:**
- Document opens without errors
- First 2 completed paths are present and intact
- Incomplete 3rd path is discarded (expected behavior)
- No corruption warnings in logs
- Load time < 100 ms (check console logs for metrics)

**Verification:**
- Compare canvas visually before/after force-quit
- Check application logs for recovery messages
- Verify undo history is intact for recovered objects

**Platform-Specific:**
- **macOS:** Force Quit via Cmd+Option+Esc or Activity Monitor

**Pass/Fail:** ⬜

---

#### Test Case M2: System Crash Simulation (Power Loss)

**Objective:** Simulate abrupt system shutdown (power loss, kernel panic).

**Steps:**
1. Launch WireTuner
2. Create a document with 10+ paths
3. Save document to disk (File → Save)
4. Continue editing: add 5 more paths without manual save
5. Simulate crash:
   - **Method 1:** Run `sudo shutdown -h now` (requires password)
   - **Method 2:** Hold power button for 5 seconds (physical device only)
   - **Method 3:** Use VM snapshot/restore feature
6. Restart system
7. Launch WireTuner
8. Open the document from step 2

**Expected:**
- All 15 paths recovered (10 saved + 5 auto-saved via event log)
- No manual "Save" required for event persistence
- Document integrity validated (no missing objects)
- Load time < 100 ms

**Metrics to Capture:**
- Number of events in database after recovery
- Snapshot sequence number used for recovery
- Time from app launch to document rendered

**Platform-Specific:**
- **macOS:** Use `sudo shutdown -h now` or hold power button

**Pass/Fail:** ⬜

---

#### Test Case M3: Corrupted Database Recovery

**Objective:** Verify graceful handling of corrupted snapshot or event data.

**Setup:**
1. Locate a test document's `.wiretuner` file (SQLite database)
2. Use SQLite CLI or hex editor to corrupt snapshot data:
   ```bash
   # Backup first
   cp test_document.wiretuner test_document.backup

   # Corrupt snapshot table (replace bytes in BLOB)
   sqlite3 test_document.wiretuner "UPDATE snapshots SET snapshot_data = X'DEADBEEF' WHERE snapshot_id = (SELECT MAX(snapshot_id) FROM snapshots);"
   ```

**Steps:**
1. Launch WireTuner
2. Attempt to open the corrupted document
3. Observe application behavior

**Expected:**
- Warning dialog: "Document partially corrupted, attempting recovery"
- Application falls back to previous valid snapshot
- Document loads successfully (may be missing recent edits)
- Logs show corruption detection and fallback strategy
- No application crash

**Verification:**
- Check logs for "Snapshot at sequence X corrupted" warnings
- Verify application remains stable after recovery
- Confirm at least some document content is recovered

**Platform-Specific:**
- **macOS:** Use `sqlite3` CLI tool (pre-installed)

**Pass/Fail:** ⬜

---

#### Test Case M4: Rapid Crash-Relaunch Cycles

**Objective:** Stress-test recovery mechanism with repeated crashes.

**Steps:**
1. Launch WireTuner
2. Create a document
3. Draw 1-2 paths
4. Force-quit application (Cmd+Option+Esc)
5. Immediately relaunch
6. Verify document state
7. **Repeat steps 3-6 five times** (5 crash-relaunch cycles)

**Expected:**
- Each relaunch successfully recovers previous state
- No cumulative corruption or data drift
- Performance remains stable across cycles
- Event log grows correctly (no duplicate/missing events)

**Metrics:**
- Recovery time should remain consistent (< 100 ms each time)
- Database file size should grow linearly (no bloat)

**Platform-Specific:**
- **macOS:** Use Activity Monitor or `killall` for consistent termination

**Pass/Fail:** ⬜

---

#### Test Case M5: Large Document Recovery (Stress Test)

**Objective:** Verify recovery performance with large event histories.

**Setup:**
1. Create a document with 100+ objects (paths, shapes)
2. Perform 500+ operations (draw, select, move, undo)
3. Verify snapshot was created (check logs or database)

**Steps:**
1. With large document open, force-quit application
2. Relaunch WireTuner
3. Open the large document

**Expected:**
- Document opens successfully
- Load time < 200 ms (relaxed target for large docs)
- All objects rendered correctly
- No memory issues or performance degradation

**Verification:**
- Check database stats:
  ```bash
  sqlite3 document.wiretuner "SELECT COUNT(*) FROM events;"
  sqlite3 document.wiretuner "SELECT COUNT(*) FROM snapshots;"
  ```
- Confirm snapshot optimization is working (shouldn't replay all events)

**Platform-Specific:**
- **macOS:** Use Activity Monitor to monitor memory usage

**Pass/Fail:** ⬜

---

### Windows Testing

**Test Environment:**
- Windows 10/11
- Physical device or VM
- Administrator privileges (for Task Manager force-quit)
- NTFS file system

**Key Differences from macOS:**
- Use **Task Manager** (Ctrl+Shift+Esc) instead of Force Quit dialog
- Right-click WireTuner → "End Task" for force termination
- Use `taskkill /F /IM wiretuner.exe` for command-line termination
- SQLite behavior identical (platform-agnostic)

#### Test Case W1-W5: Repeat M1-M5 on Windows

Execute test cases M1 through M5 on Windows platform with the following adjustments:

**Key Substitutions:**
- Replace **Cmd+Option+Esc** with **Ctrl+Shift+Esc** (Task Manager)
- Replace `killall -9 wiretuner` with `taskkill /F /IM wiretuner.exe`
- Replace `sudo shutdown -h now` with `shutdown /s /t 0` (requires admin)
- SQLite CLI: Install from [sqlite.org/download.html](https://sqlite.org/download.html)

**Expected Behavior:**
- All test cases should produce identical results to macOS
- Recovery metrics should be within ±20% of macOS benchmarks
- File system behavior (NTFS vs APFS) should not affect recovery

**Pass/Fail:** ⬜ (for each test case W1-W5)

---

## Performance Benchmarks

### Recovery Performance Targets (Decision 1)

| Metric | Target | Measurement Method | Acceptance |
|--------|--------|-------------------|------------|
| Cold start recovery | < 100 ms | Stopwatch: DB open → document rendered | 90th percentile < 100 ms |
| Snapshot load time | < 50 ms | EventReplayer instrumentation | Average < 50 ms |
| Event replay rate | > 1000 events/sec | Benchmark: replay 1000 events, measure time | > 1000 events/sec |
| Database integrity check | < 10 ms | SQLite `PRAGMA integrity_check` | Always < 10 ms |
| Corrupted snapshot fallback | < 150 ms | Measure with corrupted snapshot | Fallback complete < 150 ms |

### Benchmark Execution

Run performance benchmarks:

```bash
# Run crash recovery test and capture metrics
flutter test test/integration/test/integration/crash_recovery_test.dart --verbose | tee recovery_metrics.log

# Parse metrics from output
grep "Recovery Time" recovery_metrics.log
grep "Performance" recovery_metrics.log
```

**Expected Output:**
```
=== Crash Recovery Metrics ===
Recovery Time: 45 ms
Events Recovered: 50
Snapshot Used: Yes (at sequence 10)
State Integrity: PASS
==============================
```

**Results Storage:**
- Metrics logged to `test/performance/results/crash_recovery_metrics.json`
- Baseline: Established in I4.T9 (this task)
- Regression tracking: Compare against baseline in future iterations

---

## Recovery Scenarios Matrix

### Crash Scenario Coverage (Decision 1 Requirements)

| Scenario | Automated Test | Manual Test | Data Loss | Performance | Status |
|----------|---------------|-------------|-----------|-------------|--------|
| Mid-operation crash | ✅ M1 | ✅ M1 | Zero | < 100 ms | ⬜ |
| System power loss | ❌ N/A | ✅ M2 | Zero (WAL) | < 100 ms | ⬜ |
| Corrupted snapshot | ✅ M2 | ✅ M3 | Minimal | < 150 ms | ⬜ |
| Corrupted event log | ✅ M2 | ✅ M3 | Graceful skip | < 150 ms | ⬜ |
| Large event backlog | ✅ M3 | ✅ M5 | Zero | < 100 ms | ⬜ |
| Rapid crash cycles | ❌ N/A | ✅ M4 | Zero | Stable | ⬜ |
| Disk full during save | ❌ Future | ✅ Manual | Error shown | N/A | ⬜ |
| Network drive disconnect | ❌ Future | ✅ Manual | Error shown | N/A | ⬜ |

**Legend:**
- ✅ Covered by test
- ❌ Not covered (manual or future work)
- ⬜ Pending validation

---

## Telemetry Validation

### Expected Telemetry Ranges

**Recovery Metrics (from I4.T9):**
- Cold start recovery time: 20-80 ms (typical)
- 90th percentile: < 100 ms (hard limit per Decision 1)
- 99th percentile: < 150 ms (acceptable outlier)

**Snapshot Metrics:**
- Snapshot load time: 10-40 ms (typical medium document)
- Large document (2000+ objects): 30-70 ms
- Compression ratio: 5:1 to 15:1 (gzip)

**Event Replay:**
- Replay rate: 1000-5000 events/sec (depending on event complexity)
- Delta events after snapshot: 0-1000 events (typical)
- Full replay (no snapshot): 5000+ events in < 500 ms

**Database Stats:**
- WAL file size: 0-32 KB (auto-checkpointed)
- Database file growth: ~1 KB per 100 events
- Snapshot frequency: Every 1000 events (adaptive, see snapshot_strategy.md)

### Telemetry Collection

Enable telemetry in test runs:

```bash
# Run with detailed logging
export WIRETUNER_LOG_LEVEL=DEBUG
flutter test test/integration/test/integration/crash_recovery_test.dart --verbose

# Check console output for metrics sections
# Example:
# === Crash Recovery Metrics ===
# Recovery Time: 45 ms
# Events Recovered: 50
# Snapshot Used: Yes (at sequence 10)
# State Integrity: PASS
# ==============================
```

**Validation:**
- All metrics must fall within documented ranges
- Recovery time must be < 100 ms for 90% of cases
- No data loss in any scenario
- Document any deviations in known issues section

---

## Known Issues & Limitations

### Current Limitations (as of I4.T9)

1. **Disk Full Scenarios:** Not fully tested
   - If disk is full during event write, error may not surface until next operation
   - Mitigation: SQLite WAL mode provides partial protection
   - Future: Add explicit disk space checks (I5+)

2. **Network Drive Support:** Limited testing
   - SQLite on network drives (SMB, NFS) may have locking issues
   - Recommendation: Store documents on local disk
   - Future: Add warning for network paths (I5+)

3. **Concurrent Access:** Not supported
   - Opening same document in multiple instances may cause corruption
   - Mitigation: Use file locking (not yet implemented)
   - Future: Add multi-instance detection (I5+)

4. **Very Large Documents (10,000+ objects):** Performance degradation
   - Recovery time may exceed 100 ms for extremely large documents
   - Mitigation: Adaptive snapshot cadence reduces impact
   - Target: Maintain < 200 ms even for large docs

### Regression Risks

**Monitor for:**
- Recovery time increases (regression in snapshot optimization)
- Data loss in edge cases (WAL disabled, disk errors)
- Corrupted snapshot handling (fallback logic broken)
- Memory leaks during repeated crash-recovery cycles

**Prevention:**
- Run crash recovery tests in CI before each release
- Compare metrics against baseline from I4.T9
- Alert if 90th percentile recovery time exceeds 100 ms

---

## Sign-Off

### QA Execution Log

| Platform | Tester | Date | Automated | Manual | Pass/Fail | Notes |
|----------|--------|------|-----------|--------|-----------|-------|
| macOS 14 | _____  | ____ | ⬜ | ⬜ | ⬜ | |
| Windows 11 | _____ | ____ | ⬜ | ⬜ | ⬜ | |

### Release Criteria

- [ ] All automated tests pass (4/4 test cases)
- [ ] macOS manual QA checklist 100% complete (5/5 test cases)
- [ ] Windows manual QA checklist 100% complete (5/5 test cases)
- [ ] Recovery scenarios matrix 100% validated
- [ ] Performance benchmarks within target ranges
- [ ] Telemetry validated and documented
- [ ] Known issues documented and triaged
- [ ] Decision 1 references verified in documentation

**QA Lead Approval:** ___________________ Date: __________

**Release Manager Approval:** ___________________ Date: __________

---

## Troubleshooting Guide

### Issue: Recovery time exceeds 100 ms

**Possible Causes:**
1. No snapshot exists (replaying all events)
2. Large number of delta events since snapshot
3. Slow disk I/O (HDD vs SSD)

**Diagnosis:**
```bash
# Check snapshot status
sqlite3 document.wiretuner "SELECT event_sequence, created_at FROM snapshots ORDER BY event_sequence DESC LIMIT 1;"

# Check total events
sqlite3 document.wiretuner "SELECT MAX(event_sequence) FROM events WHERE document_id='your-doc-id';"

# Calculate delta
# If (max_event_sequence - snapshot_sequence) > 1000, snapshot is stale
```

**Resolution:**
- Trigger manual snapshot creation (future feature)
- Reduce snapshot interval (see `snapshot_strategy.md`)
- Verify adaptive cadence is enabled

---

### Issue: Data loss after crash

**Possible Causes:**
1. WAL mode disabled (should never happen)
2. File system corruption (rare)
3. Explicit transaction rollback (bug)

**Diagnosis:**
```bash
# Check WAL mode
sqlite3 document.wiretuner "PRAGMA journal_mode;"
# Expected output: wal

# Check database integrity
sqlite3 document.wiretuner "PRAGMA integrity_check;"
# Expected output: ok
```

**Resolution:**
- If WAL disabled: File a bug (P0 severity)
- If integrity check fails: Restore from backup or previous snapshot
- Check application logs for error messages

---

### Issue: Corrupted snapshot fallback fails

**Possible Causes:**
1. All snapshots corrupted (extremely rare)
2. Fallback logic bug
3. Database table corruption

**Diagnosis:**
```bash
# List all snapshots
sqlite3 document.wiretuner "SELECT snapshot_id, event_sequence, compression FROM snapshots ORDER BY event_sequence;"

# Try to load each snapshot manually (use test script)
# Check logs for specific error messages
```

**Resolution:**
- If all snapshots corrupted: Full replay from events (slow but safe)
- If database corrupted: Use SQLite `.recover` command
- Report bug with reproduction steps

---

**Document Version:** 1.0
**Iteration:** I4.T9
**Maintainer:** WireTuner QA Team
**Next Review:** I5.T1 (Multi-Window Coordination Testing)
