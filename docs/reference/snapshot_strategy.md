# Snapshot Strategy Reference

## Overview

WireTuner's event sourcing system creates periodic snapshots of document state to enable fast loading without replaying entire event histories. The snapshot system uses an **adaptive cadence** that automatically adjusts snapshot frequency based on editing activity patterns.

## Adaptive Snapshot Cadence

### How It Works

The snapshot manager monitors editing activity in real-time and classifies it into three categories:

1. **Burst Mode**: High-frequency editing (≥20 events/second by default)
   - **Behavior**: Creates snapshots more frequently (every 500 events by default)
   - **Rationale**: Dense editing generates large event histories quickly; more frequent snapshots prevent slow replays

2. **Idle Mode**: Low-frequency editing (≤2 events/second by default)
   - **Behavior**: Creates snapshots less frequently (every 2000 events by default)
   - **Rationale**: Sparse editing means event history grows slowly; reduce snapshot overhead

3. **Normal Mode**: Moderate editing (between idle and burst thresholds)
   - **Behavior**: Uses base interval (1000 events by default)
   - **Rationale**: Balanced approach for typical editing workflows

### Activity Tracking Window

The system maintains a **rolling 60-second window** (configurable) of event timestamps to calculate the current editing rate (events/second). This approach:

- **Responds quickly** to changes in editing patterns (within ~10 seconds)
- **Avoids noise** from momentary spikes or pauses
- **Uses minimal memory** (stores only timestamps, not full events)

### Performance Characteristics

| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| Snapshot creation time | < 100ms | Warn at 80ms |
| Memory per snapshot | ~10 KB - 1 MB (compressed) | - |
| Queue depth (pending snapshots) | 0-2 | Warn at >3 |

## Configuration

### Environment Variables

All configuration is optional and falls back to sensible defaults. Set environment variables to override:

```bash
# Base event count between snapshots (default: 1000)
export WIRETUNER_SNAPSHOT_BASE_INTERVAL=1000

# Multiplier during burst editing (default: 0.5 → snapshots every 500 events)
export WIRETUNER_SNAPSHOT_BURST_MULTIPLIER=0.5

# Multiplier during idle periods (default: 2.0 → snapshots every 2000 events)
export WIRETUNER_SNAPSHOT_IDLE_MULTIPLIER=2.0

# Activity tracking window in seconds (default: 60)
export WIRETUNER_SNAPSHOT_WINDOW_SECONDS=60

# Events/sec threshold for burst classification (default: 20.0)
export WIRETUNER_SNAPSHOT_BURST_THRESHOLD=20.0

# Events/sec threshold for idle classification (default: 2.0)
export WIRETUNER_SNAPSHOT_IDLE_THRESHOLD=2.0
```

### Tuning Guidelines

#### Reducing Snapshot Overhead

If snapshots are consuming too much storage or CPU:

1. **Increase base interval**: Fewer snapshots overall
   ```bash
   export WIRETUNER_SNAPSHOT_BASE_INTERVAL=2000
   ```

2. **Increase idle multiplier**: Even fewer snapshots during low activity
   ```bash
   export WIRETUNER_SNAPSHOT_IDLE_MULTIPLIER=3.0
   ```

3. **Tighten burst threshold**: Require higher rates to trigger burst mode
   ```bash
   export WIRETUNER_SNAPSHOT_BURST_THRESHOLD=50.0
   ```

#### Improving Load Performance

If document loading is too slow (event replay takes >500ms):

1. **Decrease base interval**: More frequent snapshots
   ```bash
   export WIRETUNER_SNAPSHOT_BASE_INTERVAL=500
   ```

2. **Decrease burst multiplier**: Aggressive snapshotting during dense editing
   ```bash
   export WIRETUNER_SNAPSHOT_BURST_MULTIPLIER=0.25
   ```

3. **Widen burst threshold**: Easier to trigger burst mode
   ```bash
   export WIRETUNER_SNAPSHOT_BURST_THRESHOLD=10.0
   ```

#### Adjusting Responsiveness

If the system is too slow to detect activity changes:

1. **Shorten window**: Faster adaptation to pattern changes
   ```bash
   export WIRETUNER_SNAPSHOT_WINDOW_SECONDS=30
   ```

   **Trade-off**: More sensitive to momentary spikes

If the system is too jumpy (thrashing between modes):

1. **Lengthen window**: More stable classification
   ```bash
   export WIRETUNER_SNAPSHOT_WINDOW_SECONDS=120
   ```

   **Trade-off**: Slower to adapt to genuine pattern changes

## Instrumentation & Monitoring

### Log Messages

The snapshot manager emits structured logs at various levels:

#### INFO: Activity Transitions

```
Activity changed: normal → burst (25.3 events/sec, new interval: 500)
```

**When**: Editing pattern classification changes
**Action**: Informational only; confirms adaptive logic is working

#### INFO: Snapshot Creation

```
Creating snapshot at sequence 1000
```

**When**: Snapshot creation begins
**Action**: Normal operation

#### DEBUG: Backlog Status (requires `enableDetailedLogging: true`)

```
[OK] Snapshot queue: 1 pending, 450/1000 events since last, activity: normal (10.2 events/sec)
```

**When**: Snapshot is created
**Action**: Detailed instrumentation for debugging

#### WARN: Queue Backlog

```
Snapshot queue backlog detected: 5 pending
```

**When**: More than 3 snapshots are queued/in-progress
**Action**: Investigate why snapshot creation is slow (disk I/O, serialization overhead)

#### WARN: Performance Threshold

```
Snapshot creation approaching threshold: 85ms (target: <100ms)
```

**When**: Snapshot creation takes >80ms
**Action**: Consider optimizing serialization or reducing document complexity

### Metrics

The system reports metrics via `MetricsSink`:

| Metric | Type | Description |
|--------|------|-------------|
| `recordSnapshot()` | Counter + Timer | Snapshot sequence, size, duration |
| `recordSnapshotLoad()` | Timer | Snapshot load duration |

Integrate with your metrics backend (Prometheus, StatsD, etc.) via a custom `MetricsSink` implementation.

### Programmatic Access

For custom diagnostics or UI overlays:

```dart
final manager = DefaultSnapshotManager(...);

// Get current backlog status
final status = manager.getBacklogStatus(currentSequence);
print(status.toLogString());

// Inspect tuning configuration
print(manager.tuningConfig.baseInterval);

// Access activity window directly (testing/diagnostics)
print(manager.activityWindow.eventsPerSecond);
```

## Algorithm Details

### Rate Calculation

Given a rolling window of event timestamps `[t₁, t₂, ..., tₙ]` and current time `now`:

1. **Prune old events**: Remove timestamps older than `now - windowDuration`
2. **Calculate effective window**: `effectiveWindow = now - oldest_timestamp`
3. **Compute rate**: `eventsPerSecond = eventCount / effectiveWindow`

**Edge case**: If `effectiveWindow < 100ms`, treat as instantaneous burst (`rate = events / 0.1`)

### Interval Adjustment

Given current `eventsPerSecond` rate:

```dart
if (rate >= burstThreshold) {
  effectiveInterval = baseInterval * burstMultiplier;
} else if (rate <= idleThreshold) {
  effectiveInterval = baseInterval * idleMultiplier;
} else {
  effectiveInterval = baseInterval;
}
```

**Snapshot decision**: `shouldSnapshot = (sequenceNumber % effectiveInterval == 0)`

### Backlog Detection

Queue depth = `pending_snapshots_count`

| Queue Depth | Status | Interpretation |
|-------------|--------|----------------|
| 0-2 | OK | Normal operation |
| 3+ | Falling behind | Snapshot creation slower than event production |

**Action on backlog**: Log warning, continue operation (snapshots will catch up)

## Design Rationale

### Why Adaptive Cadence?

**Problem**: Fixed 1000-event interval works poorly across diverse workflows:
- **Burst editing** (e.g., batch operations, imports): Generates 10,000+ events quickly → long replay times
- **Idle periods** (e.g., reading, thinking): Sparse events → wasted snapshot overhead

**Solution**: Adjust interval based on actual editing patterns:
- **Burst mode**: Prevent runaway event histories
- **Idle mode**: Minimize overhead during low activity

### Why Rolling Window (vs. Exponential Moving Average)?

| Approach | Pros | Cons |
|----------|------|------|
| Rolling window | Simple, deterministic, no decay tuning | Slightly more memory |
| Exponential moving average | Constant memory | Requires decay constant tuning, less intuitive |

**Verdict**: Rolling window wins for simplicity and predictability.

### Why 1000 Events Default?

Empirical testing shows:
- **100 events**: Too frequent, ~10 snapshots/minute during active editing
- **1000 events**: ~5-10 minutes of editing, balanced overhead
- **10,000 events**: Too infrequent, replay times approach 1 minute

**Reference**: See [Decision 6: Snapshot Every 1000 Events](../../.codemachine/artifacts/architecture/06_Rationale_and_Future.md#decision-6-snapshot-every-1000-events)

## Troubleshooting

### Symptoms: Slow Document Loading

**Possible Causes**:
1. Too few snapshots (long event history replay)
2. Snapshots are stale (last snapshot far from current sequence)

**Diagnosis**:
```bash
# Check average replay duration from logs
grep "recordReplay" wiretuner.log | awk '{sum+=$NF; count++} END {print sum/count}'
```

**Fixes**:
- Decrease `WIRETUNER_SNAPSHOT_BASE_INTERVAL`
- Ensure snapshots are created regularly (check for backlog warnings)

### Symptoms: High Disk Usage

**Possible Causes**:
1. Too many snapshots
2. Snapshots not pruned (old snapshots retained indefinitely)

**Diagnosis**:
```bash
# Count snapshot files (if using file-based storage)
ls -lh snapshots/ | wc -l

# Check snapshot sizes
du -sh snapshots/
```

**Fixes**:
- Increase `WIRETUNER_SNAPSHOT_BASE_INTERVAL`
- Verify pruning logic runs (check `pruneSnapshotsBeforeSequence` calls)
- Enable compression (already default in serializer)

### Symptoms: Snapshot Queue Backlog

**Possible Causes**:
1. Slow disk I/O (network drive, HDD vs SSD)
2. CPU-intensive serialization (large documents)
3. Burst editing overwhelming snapshot creation

**Diagnosis**:
```bash
# Check snapshot creation duration from logs
grep "Snapshot creation approaching threshold" wiretuner.log
```

**Fixes**:
- Optimize snapshot serializer (reduce document size, faster compression)
- Increase `WIRETUNER_SNAPSHOT_BURST_MULTIPLIER` to reduce burst-mode snapshot frequency
- Profile serialization code for bottlenecks

## References

- **Architecture Decision**: [06_Rationale_and_Future.md](../../.codemachine/artifacts/architecture/06_Rationale_and_Future.md#decision-6-snapshot-every-1000-events)
- **Performance Targets**: [05_Operational_Architecture.md](../../.codemachine/artifacts/architecture/05_Operational_Architecture.md#event-system-performance)
- **Implementation**: `packages/event_core/lib/src/snapshot_manager.dart`
- **Tests**: `packages/event_core/test/snapshot_manager_tuning_test.dart`

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-11-09 | Initial adaptive snapshot cadence implementation (Task I4.T6) |
