<!-- anchor: telemetry-thresholds -->
# WireTuner Telemetry Thresholds and Performance Targets

**Version:** 1.0
**Iteration:** I3.T10
**Last Updated:** 2025-11-09
**Status:** Active

---

## Overview

This document defines expected telemetry ranges, performance thresholds, and success metrics for the WireTuner tool framework and event sourcing system. These values serve as acceptance criteria for QA validation and regression detection.

**Related Documentation:**
- [QA Tooling Checklist](../qa/tooling_checklist.md)
- [Pen Tool Usage](./tools/pen_tool_usage.md)
- [Verification Strategy](../../.codemachine/artifacts/plan/03_Verification_and_Glossary.md#verification-and-integration-strategy)

---

## Table of Contents

- [Tool Framework Metrics](#tool-framework-metrics)
- [Event Sourcing Metrics](#event-sourcing-metrics)
- [Rendering Pipeline Metrics](#rendering-pipeline-metrics)
- [Memory and Storage Metrics](#memory-and-storage-metrics)
- [Platform-Specific Variations](#platform-specific-variations)
- [Measurement Methods](#measurement-methods)

---

## Tool Framework Metrics

### Tool Switching Latency

**Definition:** Time elapsed between tool activation request and UI ready state.

**Measurement Points:**
- Start: `ToolManager.activateTool()` called
- End: Previous tool deactivated, new tool activated, cursor updated

**Target Thresholds:**

| Percentile | Target (ms) | Hard Limit (ms) | Rationale |
|------------|-------------|-----------------|-----------|
| Average | 5-15 | 20 | Typical case, no heavy state |
| 90th | < 25 | 30 | I3 success indicator |
| 99th | < 40 | 50 | Acceptable outlier (GC, etc.) |
| Max | < 60 | 100 | Catastrophic failure threshold |

**Acceptance Criteria:**
- ✅ 90th percentile < 30 ms (per I3.T10 requirements)
- ✅ No visible lag to user (< 50 ms perceived as instant)
- ✅ Consistent across macOS and Windows (±10% variance)

**Regression Alert:** If average exceeds 20 ms or 90th exceeds 30 ms.

---

### Selection Accuracy

**Definition:** Percentage of hit-test operations that correctly identify the topmost object at a given screen coordinate.

**Test Suite:** `test/widget/selection_tool_test.dart` + automated hit-test suite

**Target Thresholds:**

| Metric | Target | Hard Limit | Test Coverage |
|--------|--------|------------|---------------|
| Point selection | ≥ 99.5% | ≥ 99.0% | 1000+ test cases |
| Marquee selection | ≥ 99.0% | ≥ 98.0% | 500+ test cases |
| Edge cases (overlapping) | ≥ 95.0% | ≥ 90.0% | 200+ test cases |

**Edge Cases:**
- Overlapping objects (z-order)
- Very small objects (< 5 px bounding box)
- Paths with sub-pixel stroke widths
- High zoom levels (> 10x)

**Acceptance:** ≥ 99% overall accuracy across test suite (per I3 success indicators).

---

### Event Sampling Rate

**Definition:** Frequency at which pointer events are captured and processed during active tool use.

**Configuration:**
- Default: 50 ms intervals (20 events/second)
- Justification: Balance between responsiveness and event volume

**Measured Rates:**

| Tool State | Expected Rate | Max Rate | Throttling |
|------------|---------------|----------|------------|
| Idle (no input) | 0 events/sec | 0 | Full throttle |
| Pen tool (drawing) | 10-20 events/sec | 20 | Yes (50 ms) |
| Selection (dragging) | 15-20 events/sec | 20 | Yes (50 ms) |
| Pen tool (Bezier drag) | 15-20 events/sec | 20 | Yes (50 ms) |
| Peak burst (tool switch) | ≤ 50 events/sec | 50 | Burst allowance |

**Rationale:**
- 20 Hz sufficient for smooth visual feedback (perceived as real-time)
- Prevents event flooding during rapid gestures
- Reduces database write pressure

**Acceptance:** No sustained bursts > 50 events/sec; average ≤ 20 events/sec during active use.

---

## Event Sourcing Metrics

### Event Volume per Operation

**Definition:** Number of events recorded for common user operations.

**Typical Event Counts:**

| Operation | Event Count | Breakdown | Notes |
|-----------|-------------|-----------|-------|
| Create straight path (3 anchors) | 5 | 1 Start + 1 Create + 1 Add + 1 Finish + 1 End | Minimal path |
| Create Bezier path (5 anchors) | 9 | 1 Start + 1 Create + 4 Add + 1 Finish + 1 End | Mixed line/curve |
| Select object | 1 | 1 SelectObjectsEvent | Single operation |
| Move object | 1-10 | 1+ MoveObjectEvent (batched) | Throttled during drag |
| Undo | 0 | Navigation only (no new events) | Replay to prev sequence |
| Tool switch | 0 | State change (no events) | Internal operation |

**Acceptance:**
- Pen tool paths: 3 + 2×(anchors-1) events (typical)
- No redundant or duplicate events
- Event payloads < 1 KB each (JSON)

---

### Event Replay Performance

**Definition:** Time to reconstruct document state from event history.

**Benchmark Scenarios:**

| Scenario | Event Count | Snapshot | Target Time (ms) | Hard Limit (ms) |
|----------|-------------|----------|------------------|-----------------|
| Small document | 100 | None | < 20 | 50 |
| Medium document | 1,000 | None | < 100 | 200 |
| Medium + snapshot | 1,000 | @ seq 500 | < 60 | 150 |
| Large document | 10,000 | @ seq 5000 | < 500 | 1000 |
| Undo navigation | 100 | Yes | < 50 | 100 |

**Test Suite:** `test/infrastructure/event_sourcing/event_replayer_integration_test.dart`

**Acceptance:**
- Replay 1,000 events in < 100 ms (I3.T10 requirement)
- Linear time complexity: O(n) where n = event count
- Snapshot usage reduces replay time by ≥ 50% (for delta > 500 events)

---

### Snapshot Efficiency

**Definition:** Compression ratio and serialization performance for document snapshots.

**Metrics:**

| Metric | Target | Hard Limit | Measurement |
|--------|--------|------------|-------------|
| Compression ratio | > 60% | > 50% | gzip compression |
| Serialization time | < 50 ms | < 100 ms | Per 1000 objects |
| Deserialization time | < 30 ms | < 80 ms | Per 1000 objects |
| Snapshot frequency | Every 1000 events | Configurable | Background task |

**Typical Snapshot Sizes:**

| Document Complexity | Uncompressed (KB) | Compressed (KB) | Ratio |
|---------------------|-------------------|-----------------|-------|
| Small (10 paths) | 50 | 15 | 70% |
| Medium (100 paths) | 500 | 150 | 70% |
| Large (1000 paths) | 5,000 | 1,500 | 70% |

**Acceptance:** Compression ratio ≥ 50% for JSON payloads (gzip).

---

## Rendering Pipeline Metrics

### Frame Time

**Definition:** Time to render one complete frame (document + overlays).

**Target: 60 FPS (16.67 ms/frame)**

**Measured Frame Times:**

| Scenario | Object Count | Target (ms) | Hard Limit (ms) | FPS |
|----------|--------------|-------------|-----------------|-----|
| Empty canvas | 0 | < 5 | 10 | 200+ |
| Simple paths | 10 | < 8 | 12 | 120+ |
| Complex scene | 100 | < 14 | 16.67 | 60+ |
| Stress test | 1,000 | < 40 | 50 | 25+ |
| Zoom/pan animation | Any | < 16 | 16.67 | 60 |

**Acceptance:**
- Maintain 60 FPS for typical workloads (< 100 objects)
- No frame drops during tool switching or undo/redo
- Overlay rendering < 2 ms additional overhead

**Test Suite:** `test/performance/render_stress_test.dart`

---

### Culling Efficiency

**Definition:** Percentage of objects culled (not rendered) due to viewport clipping.

**Metrics:**

| Viewport Coverage | Objects in Scene | Objects Rendered | Culled (%) | Target |
|-------------------|------------------|------------------|------------|--------|
| Full canvas (100%) | 100 | 100 | 0% | N/A |
| Half canvas (50%) | 100 | ~50 | ~50% | ≥ 40% |
| Zoomed in (10%) | 1,000 | ~100 | ~90% | ≥ 80% |

**Acceptance:**
- Culling reduces render calls proportional to viewport coverage
- Spatial indexing (planned I4) will improve efficiency

---

## Memory and Storage Metrics

### Memory Footprint

**Definition:** Heap memory usage during typical operations.

**Target Thresholds:**

| Component | Idle (MB) | Active (MB) | Peak (MB) | Hard Limit (MB) |
|-----------|-----------|-------------|-----------|-----------------|
| Event buffer | < 5 | < 10 | < 20 | 50 |
| Document state | < 10 | < 20 | < 50 | 100 |
| Rendering cache | < 20 | < 30 | < 60 | 150 |
| Overlay painter | < 2 | < 5 | < 10 | 20 |
| Total application | < 100 | < 150 | < 250 | 500 |

**Acceptance:**
- No memory leaks (heap stable after GC)
- Peak memory < 250 MB for typical workloads
- Memory scales linearly with document complexity

---

### Database Storage

**Definition:** SQLite database file size and growth rate.

**Metrics:**

| Content | Event Count | Size (KB) | Growth Rate |
|---------|-------------|-----------|-------------|
| Events only | 1,000 | ~500 | 0.5 KB/event |
| Events + snapshots | 1,000 + 1 snap | ~650 | +150 KB/snap |
| Large document | 10,000 | ~5,000 | Linear |

**Acceptance:**
- Event size ~500 bytes/event (average JSON payload)
- Snapshot size proportional to document complexity
- Database compression (vacuum) reduces size by ~20%

---

## Platform-Specific Variations

### Expected Performance Differences

**macOS vs. Windows:**

| Metric | macOS | Windows | Acceptable Variance |
|--------|-------|---------|---------------------|
| Tool switch latency | Baseline | ±5 ms | ±10% |
| Frame time | Baseline | ±2 ms | ±15% |
| Event replay | Baseline | ±10 ms | ±10% |
| Memory usage | Baseline | ±20 MB | ±20% |

**Factors:**
- macOS: Metal rendering (GPU-accelerated)
- Windows: DirectX/OpenGL rendering
- SQLite performance: Similar (both use FFI)
- Flutter framework: Cross-platform parity expected

**Acceptance:** No metric should differ by > 20% between platforms (per Decision 6 platform parity requirements).

---

## Measurement Methods

### Automated Instrumentation

**Code-Level Metrics:**

```dart
// Example: Measure tool switch latency
final stopwatch = Stopwatch()..start();
toolManager.activateTool('pen');
final latencyMs = stopwatch.elapsedMicroseconds / 1000;
metrics.recordToolSwitchLatency(latencyMs);
```

**Integration Test Metrics:**

```dart
// Capture metrics during test
final metrics = WorkflowMetrics();
// ... perform operations ...
metrics.validate(); // Asserts thresholds
```

### CI/CD Benchmarking

**GitHub Actions Workflow:**

```bash
# Run performance benchmarks
flutter test test/performance/ --reporter json > results.json

# Parse and validate thresholds
dart scripts/validate_metrics.dart results.json
```

**Regression Detection:**
- Compare against baseline from I3.T9
- Alert if any metric degrades by > 15%
- Store historical data for trend analysis

---

### Manual Profiling

**Tools:**
- Flutter DevTools (CPU profiler, memory profiler)
- macOS Instruments (Time Profiler, Allocations)
- Windows Performance Analyzer
- Chrome DevTools (for web builds)

**Procedure:**
1. Launch app with profiling enabled
2. Execute QA checklist test cases
3. Record metrics at each step
4. Export and analyze results
5. Compare against documented thresholds

---

## Telemetry Data Format

### Logged Metrics Example

```json
{
  "session_id": "test-session-001",
  "timestamp": "2025-11-09T10:00:00Z",
  "platform": "macos",
  "metrics": {
    "tool_switch_latency_ms": {
      "average": 12.34,
      "p90": 18.56,
      "p99": 28.90,
      "max": 35.12
    },
    "event_count": 15,
    "event_sampling_rate_ms": 50,
    "frame_time_ms": {
      "average": 8.23,
      "p90": 12.45,
      "max": 15.67
    },
    "memory_peak_mb": 128.5,
    "event_replay_time_ms": 45.2
  }
}
```

### Expected Ranges Summary

**Quick Reference Card:**

| Metric | Target | Hard Limit |
|--------|--------|------------|
| Tool switch (90th) | < 25 ms | < 30 ms |
| Selection accuracy | ≥ 99.5% | ≥ 99.0% |
| Event sampling | 20/sec | 50/sec |
| Frame time (60 FPS) | < 14 ms | < 16.67 ms |
| Event replay (1000) | < 100 ms | < 200 ms |
| Memory peak | < 200 MB | < 250 MB |

**Validation Command:**

```bash
# Run integration test with telemetry validation
flutter test test/integration/test/integration/tool_pen_selection_test.dart --verbose

# Check output for:
# === Workflow Telemetry Metrics ===
# Tool Switch Latency (avg): XX.XX ms  ← Must be < 20 ms
# Tool Switch Latency (max): XX.XX ms  ← Must be < 30 ms
# Total Events: XX                     ← Reasonable count
# Event Sampling Rate: 50 ms           ← Expected value
# ===================================
```

---

## Appendix: Metric Definitions

### Latency
Time between user action and system response.

### Throughput
Number of operations completed per unit time.

### Accuracy
Percentage of correct results in test suite.

### Efficiency
Resource usage relative to work performed (e.g., compression ratio).

### Percentile
Value below which a percentage of observations fall (e.g., 90th percentile = 90% of samples ≤ this value).

---

**Document Version:** 1.0
**Iteration:** I3.T10
**Maintainer:** WireTuner Performance Team
**Next Review:** I4.T1 (After Direct Selection Implementation)
