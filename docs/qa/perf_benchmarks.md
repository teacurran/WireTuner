# WireTuner Performance Benchmark Plan

**Version:** 1.0
**Last Updated:** 2025-11-11
**Owner:** Performance Working Group
**Task Reference:** I5.T4

## 1. Overview

This document defines WireTuner's performance benchmarking strategy, measurement methodology, KPI targets, and CI integration. It ensures all performance-related non-functional requirements (NFR-PERF-001..010) are continuously validated and monitored.

### 1.1 Purpose

- **Performance Validation:** Verify NFR-PERF requirements are met before releases
- **Regression Detection:** Identify performance degradation through baseline comparison
- **Trend Analysis:** Track performance metrics over time via telemetry dashboards
- **Release Blocking:** Prevent merges/releases that violate performance SLAs

### 1.2 Scope

This plan covers:
- **Load Time Benchmarks:** Document open and snapshot restore (NFR-PERF-001)
- **Replay Throughput Benchmarks:** Event replay rate (NFR-PERF-002)
- **Rendering Benchmarks:** FPS, frame time, GPU fallback (NFR-PERF-003, 008, 009)
- **Snapshot & Thumbnail Benchmarks:** Background task performance (NFR-PERF-004, 007)
- **Interaction Benchmarks:** Cursor latency (NFR-PERF-010)

### 1.3 Success Criteria

- All benchmark suites integrated into nightly CI by I5 end
- Performance regression dashboard operational with ±5% tolerance alerts
- Every NFR-PERF requirement mapped to at least one benchmark suite
- Benchmark failures block releases with documented escalation process

---

## 2. Benchmark Suites

### 2.1 Load Time Benchmark Suite

**Benchmark ID:** `BENCH-LOAD-001`

**Requirements Covered:** NFR-PERF-001

**Objective:** Validate document load time remains <100ms (p95) for documents with up to 10K events.

#### 2.1.1 Test Scenarios

| Scenario | Event Count | Artboards | Expected Load Time (p95) | Notes |
|----------|-------------|-----------|--------------------------|-------|
| Small Document | 100 | 1 | <10ms | Baseline case |
| Medium Document | 1,000 | 1 | <30ms | Typical user doc |
| Large Document | 10,000 | 1 | <100ms | NFR-PERF-001 target |
| Multi-Artboard | 10,000 | 10 | <150ms | Navigator overhead included |
| Worst-Case | 50,000 | 50 | <500ms | Stress test (informational) |

#### 2.1.2 Measurement Methodology

**Implementation:** `benchmark/load_time_bench.dart`

**Execution:**
```bash
# Local execution
flutter drive --driver=test_driver/benchmark_driver.dart \
              --target=benchmark/load_time_bench.dart \
              --profile

# Melos orchestration
melos run benchmark:load-time
```

**Metrics Collected:**
- `document.load.ms`: Total time from `DocumentService.open()` call to first paint
- `snapshot.load.ms`: Time to restore snapshot from SQLite
- `event.replay.count`: Number of events replayed after snapshot restore
- `event.replay.ms`: Time spent replaying delta events

**Data Collection:**
```dart
// Pseudo-code example
final stopwatch = Stopwatch()..start();
await documentService.open(documentPath);
await tester.pumpAndSettle(); // Wait for first paint
stopwatch.stop();

telemetryService.recordMetric(
  name: 'document.load.ms',
  value: stopwatch.elapsedMilliseconds,
  tags: {
    'event_count': eventCount,
    'artboard_count': artboardCount,
    'benchmark_id': 'BENCH-LOAD-001',
  },
);
```

**Baseline Management:**
- Baselines stored in `benchmark/baselines/load_time.json`
- Format: `{ "scenario": "large_document", "p50": 45, "p95": 90, "p99": 120 }`
- Updated quarterly or after major persistence architecture changes
- Updates require QA lead + architect approval

#### 2.1.3 CI Integration

**Workflow:** `.github/workflows/nightly-benchmarks.yml`

**Schedule:** Nightly at 02:00 UTC

**Platform Matrix:** macOS-latest, Windows-latest

**Failure Handling:**
- If p95 > 100ms: Mark build as FAILED, block release
- If p95 within 100-110ms: Mark build as WARNING, require manual review
- If p95 < 100ms: PASS

**Telemetry Export:**
- Results pushed to Prometheus endpoint: `POST /api/v1/metrics/benchmark`
- CloudWatch Logs: `benchmark/load-time` log group
- Grafana Dashboard: "WireTuner Performance - Load Time"

**Alert Threshold:**
- Prometheus alert: `document_load_ms_p95 > 100` for >5 consecutive runs

---

### 2.2 Event Replay Throughput Benchmark Suite

**Benchmark ID:** `BENCH-REPLAY-001`

**Requirements Covered:** NFR-PERF-002

**Objective:** Validate event replay throughput ≥5K events/sec (p95) during timeline scrubbing and document load.

#### 2.2.1 Test Scenarios

| Scenario | Event Count | Operation | Expected Throughput (p95) | Notes |
|----------|-------------|-----------|---------------------------|-------|
| Small Replay | 1,000 | Load from snapshot | ≥10K events/sec | Baseline |
| Medium Replay | 10,000 | Load from snapshot | ≥7K events/sec | Typical |
| Large Replay | 100,000 | Load from snapshot | ≥5K events/sec | NFR-PERF-002 target |
| Timeline Scrub | 10,000 | Scrub 0% → 100% | ≥5K events/sec | Interactive use case |
| Worst-Case | 500,000 | Load from snapshot | ≥3K events/sec | Stress test (informational) |

#### 2.2.2 Measurement Methodology

**Implementation:** `benchmark/replay_throughput_bench.dart`

**Execution:**
```bash
flutter drive --driver=test_driver/benchmark_driver.dart \
              --target=benchmark/replay_throughput_bench.dart \
              --profile

melos run benchmark:replay-throughput
```

**Metrics Collected:**
- `event.replay.rate`: Events replayed per second
- `event.replay.duration_ms`: Total replay duration
- `event.replay.count`: Total events replayed
- `event.replay.batch_size`: Batch size used by ReplayService

**Data Collection:**
```dart
final stopwatch = Stopwatch()..start();
await replayService.replayEvents(eventRange: EventRange(0, eventCount));
await tester.pumpAndSettle();
stopwatch.stop();

final throughput = (eventCount / stopwatch.elapsedMilliseconds) * 1000;

telemetryService.recordMetric(
  name: 'event.replay.rate',
  value: throughput,
  tags: {
    'event_count': eventCount,
    'operation': 'load_from_snapshot',
    'benchmark_id': 'BENCH-REPLAY-001',
  },
);
```

**Baseline Management:**
- Baselines: `benchmark/baselines/replay_throughput.json`
- Format: `{ "scenario": "large_replay", "p50": 6500, "p95": 5200, "p99": 4800 }`
- Updated after event sourcing or replay architecture changes

#### 2.2.3 CI Integration

**Workflow:** `.github/workflows/nightly-benchmarks.yml`

**Platform Matrix:** macOS-latest, Windows-latest

**Failure Handling:**
- If p95 < 5K events/sec: FAILED, block release
- If p95 within 4.5K-5K events/sec: WARNING, manual review
- If p95 ≥ 5K events/sec: PASS

**Telemetry Export:**
- Prometheus endpoint: `POST /api/v1/metrics/benchmark`
- CloudWatch Logs: `benchmark/replay-throughput`
- Grafana Dashboard: "WireTuner Performance - Replay Rate"

**Alert Threshold:**
- Prometheus alert: `event_replay_rate_p95 < 4000` for >3 consecutive runs

---

### 2.3 Rendering Benchmark Suite

**Benchmark ID:** `BENCH-RENDER-001`

**Requirements Covered:** NFR-PERF-008 (FPS ≥60), NFR-PERF-009 (frame time <16.67ms), NFR-PERF-003 (GPU fallback)

**Objective:** Validate rendering performance under stress (10K+ objects) and GPU fallback behavior.

#### 2.3.1 Test Scenarios

| Scenario | Object Count | Zoom Level | Expected FPS (p95) | Expected Frame Time (p95) | Notes |
|----------|--------------|------------|--------------------|-----------------------------|-------|
| Baseline | 100 | 100% | ≥60 FPS | <16ms | Simple scene |
| Medium Load | 1,000 | 100% | ≥60 FPS | <16ms | Typical canvas |
| High Load | 10,000 | 100% | ≥60 FPS | <16.67ms | NFR-PERF-008/009 target |
| Zoomed In | 10,000 | 400% | ≥60 FPS | <16.67ms | Anchor rendering overhead |
| GPU Fallback | 10,000 | 100% | ≥30 FPS | <33ms | CPU rendering fallback |

#### 2.3.2 Measurement Methodology

**Implementation:** `benchmark/render_pipeline_bench.dart`

**Execution:**
```bash
flutter drive --driver=test_driver/benchmark_driver.dart \
              --target=benchmark/render_pipeline_bench.dart \
              --profile

melos run benchmark:render-pipeline
```

**Metrics Collected:**
- `render.fps`: Frames per second during viewport updates
- `render.frame_time_ms`: Time per frame (ms)
- `render.object_count`: Number of objects in scene
- `render.fallback.duration_ms`: Time to detect and switch to CPU fallback (NFR-PERF-003)

**Data Collection:**
```dart
final frameTimings = <Duration>[];
final listener = SchedulerBinding.instance.addTimingsCallback((timings) {
  frameTimings.addAll(timings.map((t) => t.totalSpan));
});

// Render scene with 10K objects
await renderingPipeline.render(objects: testObjects);
await tester.pump(Duration(seconds: 5)); // Collect 5 seconds of frame data

SchedulerBinding.instance.removeTimingsCallback(listener);

final avgFrameTime = frameTimings.average;
final fps = 1000 / avgFrameTime.inMilliseconds;

telemetryService.recordMetric(
  name: 'render.fps',
  value: fps,
  tags: {
    'object_count': testObjects.length,
    'zoom_level': zoomLevel,
    'benchmark_id': 'BENCH-RENDER-001',
  },
);
```

**GPU Fallback Testing:**
```dart
// Simulate GPU stress to trigger fallback
await renderingPipeline.setGpuStress(enabled: true);

final stopwatch = Stopwatch()..start();
// Wait for fallback detection
await renderingPipeline.waitForFallback();
stopwatch.stop();

telemetryService.recordMetric(
  name: 'render.fallback.duration_ms',
  value: stopwatch.elapsedMilliseconds,
  tags: {'benchmark_id': 'BENCH-RENDER-001'},
);

// Verify no flicker (manual validation required)
```

**Baseline Management:**
- Baselines: `benchmark/baselines/render_pipeline.json`
- Format: `{ "scenario": "high_load", "fps_p50": 62, "fps_p95": 60, "frame_time_p95": 16.5 }`

#### 2.3.3 CI Integration

**Workflow:** `.github/workflows/nightly-benchmarks.yml`

**Platform Matrix:** macOS-latest, Windows-latest

**Failure Handling:**
- If FPS p95 < 60: FAILED, block release
- If frame time p95 > 16.67ms: FAILED, block release
- If GPU fallback >50ms: WARNING, manual review (NFR-PERF-003)

**Telemetry Export:**
- Prometheus endpoint: `POST /api/v1/metrics/benchmark`
- CloudWatch Logs: `benchmark/render-pipeline`
- Grafana Dashboard: "WireTuner Performance - Rendering"

**Alert Threshold:**
- Prometheus alert: `render_fps_p95 < 58` OR `render_frame_time_ms_p95 > 17`

---

### 2.4 Snapshot Generation Benchmark Suite

**Benchmark ID:** `BENCH-SNAPSHOT-001`

**Requirements Covered:** NFR-PERF-004 (snapshot duration <500ms)

**Objective:** Validate snapshot creation completes in <500ms (p95) for documents with up to 10K events.

#### 2.4.1 Test Scenarios

| Scenario | Event Count | Artboards | Expected Duration (p95) | Notes |
|----------|-------------|-----------|-------------------------|-------|
| Small Document | 1,000 | 1 | <50ms | Baseline |
| Medium Document | 5,000 | 1 | <200ms | Typical |
| Large Document | 10,000 | 1 | <500ms | NFR-PERF-004 target |
| Multi-Artboard | 10,000 | 10 | <600ms | Multiple artboard states |

#### 2.4.2 Measurement Methodology

**Implementation:** `benchmark/snapshot_generation_bench.dart`

**Execution:**
```bash
flutter drive --driver=test_driver/benchmark_driver.dart \
              --target=benchmark/snapshot_generation_bench.dart \
              --profile

melos run benchmark:snapshot-generation
```

**Metrics Collected:**
- `snapshot.duration_ms`: Total time to generate snapshot (NFR-PERF-004)
- `snapshot.size_bytes`: Snapshot size in bytes
- `snapshot.compression_ratio`: Compression efficiency
- `snapshot.event_count`: Number of events in document

**Data Collection:**
```dart
final stopwatch = Stopwatch()..start();
await snapshotManager.createSnapshot(documentId: docId);
await snapshotManager.waitForCompletion(); // Wait for isolate completion
stopwatch.stop();

telemetryService.recordMetric(
  name: 'snapshot.duration_ms',
  value: stopwatch.elapsedMilliseconds,
  tags: {
    'event_count': eventCount,
    'artboard_count': artboardCount,
    'benchmark_id': 'BENCH-SNAPSHOT-001',
  },
);
```

**Baseline Management:**
- Baselines: `benchmark/baselines/snapshot_generation.json`
- Format: `{ "scenario": "large_document", "p50": 350, "p95": 480, "p99": 520 }`

#### 2.4.3 CI Integration

**Workflow:** `.github/workflows/nightly-benchmarks.yml`

**Platform Matrix:** macOS-latest, Windows-latest

**Failure Handling:**
- If p95 > 500ms: FAILED, block release
- If p95 within 480-500ms: WARNING, manual review

**Telemetry Export:**
- Prometheus endpoint: `POST /api/v1/metrics/benchmark`
- CloudWatch Logs: `benchmark/snapshot-generation`
- Grafana Dashboard: "WireTuner Performance - Snapshots"

**Alert Threshold:**
- Prometheus alert: `snapshot_duration_ms_p95 > 500`

---

### 2.5 Thumbnail Regeneration Benchmark Suite

**Benchmark ID:** `BENCH-THUMB-001`

**Requirements Covered:** NFR-PERF-007 (thumbnail refresh <100ms), FR-039 (refresh triggers)

**Objective:** Validate thumbnail regeneration completes in <100ms (p95) for individual artboards and <1000ms for batch operations.

#### 2.5.1 Test Scenarios

| Scenario | Artboard Count | Trigger | Expected Duration (p95) | Notes |
|----------|----------------|---------|-------------------------|-------|
| Single Thumbnail | 1 | Idle timer | <100ms | NFR-PERF-007 target |
| Small Batch | 10 | Manual refresh | <500ms | Navigator context menu |
| Large Batch | 100 | Document open | <1000ms | Worst-case batch |

#### 2.5.2 Measurement Methodology

**Implementation:** `benchmark/thumbnail_regen_bench.dart`

**Execution:**
```bash
flutter drive --driver=test_driver/benchmark_driver.dart \
              --target=benchmark/thumbnail_regen_bench.dart \
              --profile

melos run benchmark:thumbnail-regen
```

**Metrics Collected:**
- `thumbnail.latency`: Time to generate single thumbnail (ms)
- `thumbnail.regen.count`: Number of thumbnails regenerated
- `thumbnail.batch_duration_ms`: Time for batch operation

**Data Collection:**
```dart
final stopwatch = Stopwatch()..start();
await navigatorService.refreshThumbnail(artboardId: artboardId);
await navigatorService.waitForThumbnail(artboardId);
stopwatch.stop();

telemetryService.recordMetric(
  name: 'thumbnail.latency',
  value: stopwatch.elapsedMilliseconds,
  tags: {
    'artboard_id': artboardId,
    'trigger': 'manual',
    'benchmark_id': 'BENCH-THUMB-001',
  },
);
```

**Baseline Management:**
- Baselines: `benchmark/baselines/thumbnail_regen.json`
- Format: `{ "scenario": "single_thumbnail", "p50": 60, "p95": 95, "p99": 110 }`

#### 2.5.3 CI Integration

**Workflow:** `.github/workflows/nightly-benchmarks.yml`

**Platform Matrix:** macOS-latest, Windows-latest

**Failure Handling:**
- If single thumbnail p95 > 100ms: FAILED, block release
- If batch p95 > 1000ms: WARNING, manual review

**Telemetry Export:**
- Prometheus endpoint: `POST /api/v1/metrics/benchmark`
- CloudWatch Logs: `benchmark/thumbnail-regen`
- Grafana Dashboard: "WireTuner Performance - Thumbnails"

**Alert Threshold:**
- Prometheus alert: `thumbnail_latency_p95 > 100`

---

### 2.6 Cursor Latency Benchmark Suite

**Benchmark ID:** `BENCH-CURSOR-001`

**Requirements Covered:** NFR-PERF-010 (cursor latency <16ms)

**Objective:** Validate cursor response latency remains <16ms (p95) during drawing operations.

#### 2.6.1 Test Scenarios

| Scenario | Object Count | Tool | Expected Latency (p95) | Notes |
|----------|--------------|------|------------------------|-------|
| Empty Canvas | 0 | Pen | <5ms | Baseline |
| Light Load | 100 | Pen | <10ms | Typical |
| Heavy Load | 10,000 | Pen | <16ms | NFR-PERF-010 target |

#### 2.6.2 Measurement Methodology

**Implementation:** `benchmark/cursor_latency_bench.dart`

**Execution:**
```bash
flutter drive --driver=test_driver/benchmark_driver.dart \
              --target=benchmark/cursor_latency_bench.dart \
              --profile

melos run benchmark:cursor-latency
```

**Metrics Collected:**
- `cursor.latency_us`: Time from input event to cursor update (microseconds)

**Data Collection:**
```dart
final latencies = <int>[];

for (var i = 0; i < 1000; i++) {
  final inputTimestamp = DateTime.now().microsecondsSinceEpoch;
  await tester.tapAt(Offset(i * 10, i * 10));
  final renderTimestamp = await cursorService.getLastRenderTimestamp();
  latencies.add(renderTimestamp - inputTimestamp);
}

final p95Latency = latencies.percentile(0.95);

telemetryService.recordMetric(
  name: 'cursor.latency_us',
  value: p95Latency,
  tags: {
    'object_count': objectCount,
    'tool': 'pen',
    'benchmark_id': 'BENCH-CURSOR-001',
  },
);
```

**Baseline Management:**
- Baselines: `benchmark/baselines/cursor_latency.json`
- Format: `{ "scenario": "heavy_load", "p50": 12000, "p95": 15000, "p99": 17000 }` (microseconds)

#### 2.6.3 CI Integration

**Workflow:** `.github/workflows/nightly-benchmarks.yml`

**Platform Matrix:** macOS-latest, Windows-latest

**Failure Handling:**
- If p95 > 16ms (16000μs): FAILED, block release

**Telemetry Export:**
- Prometheus endpoint: `POST /api/v1/metrics/benchmark`
- CloudWatch Logs: `benchmark/cursor-latency`
- Grafana Dashboard: "WireTuner Performance - Interaction"

**Alert Threshold:**
- Prometheus alert: `cursor_latency_us_p95 > 16000`

---

## 3. Baseline Management

### 3.1 Baseline Storage

**Location:** `benchmark/baselines/*.json`

**Format:**
```json
{
  "version": "1.0",
  "last_updated": "2025-11-11",
  "baseline_id": "BENCH-LOAD-001",
  "scenarios": [
    {
      "name": "large_document",
      "event_count": 10000,
      "artboard_count": 1,
      "metrics": {
        "document.load.ms": {
          "p50": 45,
          "p95": 90,
          "p99": 120
        }
      }
    }
  ]
}
```

### 3.2 Baseline Update Process

**When to Update:**
- Major architecture changes (event sourcing, rendering pipeline, persistence)
- Dependency upgrades (Flutter SDK, Dart, Skia)
- Quarterly review (scheduled baseline refresh)

**Update Procedure:**
1. Run benchmark suite 10 times on clean environment
2. Compute p50, p95, p99 across runs
3. Document justification in `benchmark/baselines/changelog.md`
4. Submit PR with baseline updates + justification
5. Require approvals: QA Lead + Architect + VP Engineering
6. Merge after sign-off

**Approval Template:**
```markdown
## Baseline Update Request

**Benchmark ID:** BENCH-LOAD-001
**Date:** 2025-11-11
**Requestor:** [Name]

**Justification:**
Major event sourcing refactor reduced replay overhead by 30%.

**Old Baseline (p95):** 90ms
**New Baseline (p95):** 63ms

**Evidence:**
- 10 benchmark runs: [link to CI artifacts]
- Performance dashboard: [link to Grafana]

**Approvals:**
- [ ] QA Lead: [Name]
- [ ] Architect: [Name]
- [ ] VP Engineering: [Name]
```

### 3.3 Regression Detection

**Tolerance:** ±5% from baseline p95

**Detection Logic:**
```python
# Pseudo-code
baseline_p95 = load_baseline(benchmark_id)
current_p95 = run_benchmark()

deviation_percent = ((current_p95 - baseline_p95) / baseline_p95) * 100

if deviation_percent > 5:
    mark_as_regression()
    block_release()
elif deviation_percent > 2:
    mark_as_warning()
    require_manual_review()
else:
    mark_as_pass()
```

**Escalation:**
- Regression >5%: Block release, require fix or baseline update
- Regression 2-5%: Manual review by Performance WG
- Improvement >10%: Verify not a measurement error, update baseline if valid

---

## 4. CI/CD Integration

### 4.1 Nightly Benchmark Workflow

**File:** `.github/workflows/nightly-benchmarks.yml` (to be created in I5.T6)

**Workflow Configuration:**
```yaml
name: Nightly Performance Benchmarks

on:
  schedule:
    - cron: '0 2 * * *' # 02:00 UTC daily
  workflow_dispatch: # Manual trigger

jobs:
  benchmark-suite:
    name: Run Benchmark Suite
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        os: [macos-latest, windows-latest]
        benchmark:
          - load-time
          - replay-throughput
          - render-pipeline
          - snapshot-generation
          - thumbnail-regen
          - cursor-latency
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
          channel: 'stable'

      - name: Install dependencies
        run: melos bootstrap

      - name: Run benchmark
        run: melos run benchmark:${{ matrix.benchmark }}

      - name: Upload results
        run: |
          # Push to Prometheus
          curl -X POST https://api.wiretuner.io/v1/metrics/benchmark \
            -H "Authorization: Bearer ${{ secrets.TELEMETRY_API_KEY }}" \
            -d @benchmark/results/${{ matrix.benchmark }}.json

      - name: Compare against baseline
        run: |
          dart scripts/benchmark/compare_baseline.dart \
            --benchmark=${{ matrix.benchmark }} \
            --results=benchmark/results/${{ matrix.benchmark }}.json \
            --baseline=benchmark/baselines/${{ matrix.benchmark }}.json

      - name: Upload artifacts
        uses: actions/upload-artifact@v3
        with:
          name: benchmark-results-${{ matrix.os }}-${{ matrix.benchmark }}
          path: benchmark/results/${{ matrix.benchmark }}.json

  benchmark-summary:
    name: Benchmark Summary
    needs: benchmark-suite
    runs-on: ubuntu-latest
    steps:
      - name: Download all results
        uses: actions/download-artifact@v3

      - name: Generate summary report
        run: dart scripts/benchmark/generate_summary.dart

      - name: Post to Slack
        if: failure()
        run: |
          curl -X POST ${{ secrets.SLACK_WEBHOOK_URL }} \
            -d '{"text": "⚠️ Nightly benchmarks failed! Check GitHub Actions for details."}'
```

### 4.2 Benchmark Melos Commands

**File:** `melos.yaml`

```yaml
scripts:
  benchmark:load-time:
    run: flutter drive --driver=test_driver/benchmark_driver.dart --target=benchmark/load_time_bench.dart --profile
    description: Run load time benchmark suite
    packageFilters:
      scope: 'app'

  benchmark:replay-throughput:
    run: flutter drive --driver=test_driver/benchmark_driver.dart --target=benchmark/replay_throughput_bench.dart --profile
    description: Run event replay throughput benchmark suite
    packageFilters:
      scope: 'app'

  benchmark:render-pipeline:
    run: flutter drive --driver=test_driver/benchmark_driver.dart --target=benchmark/render_pipeline_bench.dart --profile
    description: Run rendering pipeline benchmark suite
    packageFilters:
      scope: 'app'

  benchmark:snapshot-generation:
    run: flutter drive --driver=test_driver/benchmark_driver.dart --target=benchmark/snapshot_generation_bench.dart --profile
    description: Run snapshot generation benchmark suite
    packageFilters:
      scope: 'app'

  benchmark:thumbnail-regen:
    run: flutter drive --driver=test_driver/benchmark_driver.dart --target=benchmark/thumbnail_regen_bench.dart --profile
    description: Run thumbnail regeneration benchmark suite
    packageFilters:
      scope: 'app'

  benchmark:cursor-latency:
    run: flutter drive --driver=test_driver/benchmark_driver.dart --target=benchmark/cursor_latency_bench.dart --profile
    description: Run cursor latency benchmark suite
    packageFilters:
      scope: 'app'

  benchmark:all:
    run: melos run benchmark:load-time && melos run benchmark:replay-throughput && melos run benchmark:render-pipeline && melos run benchmark:snapshot-generation && melos run benchmark:thumbnail-regen && melos run benchmark:cursor-latency
    description: Run all benchmark suites sequentially
```

### 4.3 Local Execution

**Run All Benchmarks:**
```bash
melos run benchmark:all
```

**Run Specific Benchmark:**
```bash
melos run benchmark:load-time
```

**Compare Against Baseline:**
```bash
dart scripts/benchmark/compare_baseline.dart \
  --benchmark=load-time \
  --results=benchmark/results/load_time.json \
  --baseline=benchmark/baselines/load_time.json
```

**View Results:**
```bash
cat benchmark/results/load_time.json | jq
```

---

## 5. Telemetry Integration

### 5.1 Metric Catalog Mapping

All benchmark metrics align with telemetry metrics defined in [telemetry_policy.md](../telemetry_policy.md#41-performance-metrics).

| Benchmark Metric | Telemetry Catalog Name | Frequency | Collection Method |
|------------------|------------------------|-----------|-------------------|
| `document.load.ms` | `render.fps` → indirectly via load events | Per document open | OTLP export to Prometheus |
| `event.replay.rate` | `event.replay.rate` | Per replay operation | OTLP export to Prometheus |
| `render.fps` | `render.fps` | Per viewport update | OTLP export to Prometheus |
| `render.frame_time_ms` | `render.frame_time_ms` | Per viewport update | OTLP export to Prometheus |
| `snapshot.duration_ms` | `snapshot.duration_ms` | Per snapshot | OTLP export to Prometheus |
| `thumbnail.latency` | `thumbnail.latency` (custom metric) | Per thumbnail regen | OTLP export to Prometheus |
| `cursor.latency_us` | `cursor.latency_us` | Per interaction | OTLP export to Prometheus |

### 5.2 Dashboard Configuration

**Grafana Dashboards:**

1. **WireTuner Performance - Overview**
   - Panels: All p95 metrics, trend lines, baseline overlays
   - Alerts: Regression detection (>5% deviation)

2. **WireTuner Performance - Load Time**
   - Panels: `document.load.ms` (p50, p95, p99), event count correlation
   - Filters: Platform, artboard count, event count range

3. **WireTuner Performance - Replay Rate**
   - Panels: `event.replay.rate` (p50, p95, p99), throughput trends
   - Filters: Platform, operation type

4. **WireTuner Performance - Rendering**
   - Panels: `render.fps`, `render.frame_time_ms`, GPU fallback frequency
   - Filters: Platform, object count, zoom level

5. **WireTuner Performance - Snapshots**
   - Panels: `snapshot.duration_ms`, compression ratio, size trends
   - Filters: Platform, event count

6. **WireTuner Performance - Thumbnails**
   - Panels: `thumbnail.latency`, batch duration, regen count
   - Filters: Platform, artboard count, trigger type

**Dashboard URLs:**
- Production: `https://metrics.wiretuner.io/d/perf-overview`
- Staging: `https://staging-metrics.wiretuner.io/d/perf-overview`

### 5.3 Alert Configuration

**Prometheus Alerting Rules:**

```yaml
groups:
  - name: wiretuner_performance_alerts
    interval: 5m
    rules:
      - alert: DocumentLoadTimeRegression
        expr: document_load_ms_p95 > 100
        for: 15m
        labels:
          severity: critical
          component: persistence
        annotations:
          summary: "Document load time p95 exceeds 100ms"
          description: "Load time p95 is {{ $value }}ms (threshold: 100ms)"

      - alert: EventReplayRateRegression
        expr: event_replay_rate_p95 < 4000
        for: 15m
        labels:
          severity: critical
          component: replay
        annotations:
          summary: "Event replay rate p95 below 4K events/sec"
          description: "Replay rate p95 is {{ $value }} events/sec (threshold: 5K)"

      - alert: RenderingFPSRegression
        expr: render_fps_p95 < 58
        for: 15m
        labels:
          severity: critical
          component: rendering
        annotations:
          summary: "Rendering FPS p95 below 60"
          description: "FPS p95 is {{ $value }} (threshold: 60)"

      - alert: SnapshotDurationRegression
        expr: snapshot_duration_ms_p95 > 500
        for: 15m
        labels:
          severity: critical
          component: snapshot
        annotations:
          summary: "Snapshot duration p95 exceeds 500ms"
          description: "Snapshot duration p95 is {{ $value }}ms (threshold: 500ms)"
```

**Alert Notification Channels:**
- Slack: `#alerts-performance` channel
- Email: `performance-wg@wiretuner.io`
- PagerDuty: Critical alerts only (out-of-hours escalation)

---

## 6. Verification & Validation

### 6.1 Benchmark Suite Validation

Before marking benchmark suite as READY, validate:

- [ ] Benchmark runs successfully on macOS and Windows
- [ ] Results export to JSON format compatible with baseline comparison script
- [ ] Telemetry metrics pushed to Prometheus endpoint
- [ ] Baseline file exists in `benchmark/baselines/`
- [ ] Melos command registered in `melos.yaml`
- [ ] CI workflow includes benchmark in matrix
- [ ] Grafana dashboard panel created
- [ ] Prometheus alert configured
- [ ] Documentation updated (this file + [verification_matrix.md](verification_matrix.md))

### 6.2 Regression Detection Validation

Test regression detection logic:

```bash
# Artificially degrade performance
dart scripts/benchmark/inject_delay.dart --benchmark=load-time --delay-ms=50

# Run benchmark
melos run benchmark:load-time

# Compare against baseline (should detect regression)
dart scripts/benchmark/compare_baseline.dart \
  --benchmark=load-time \
  --results=benchmark/results/load_time.json \
  --baseline=benchmark/baselines/load_time.json

# Expected output: REGRESSION DETECTED (deviation >5%)
```

### 6.3 CI Integration Validation

Validate nightly workflow:

```bash
# Trigger workflow manually
gh workflow run nightly-benchmarks.yml

# Monitor execution
gh run list --workflow=nightly-benchmarks.yml

# Download results
gh run download <run-id>
```

---

## 7. Action Items & Ownership

### 7.1 Immediate Actions (I5.T6)

| Action | Owner | Target Date | Status |
|--------|-------|-------------|--------|
| Implement `BENCH-LOAD-001` (load time benchmark) | ReplayService Team | 2025-11-15 | PENDING |
| Implement `BENCH-REPLAY-001` (replay throughput) | ReplayService Team | 2025-11-15 | PENDING |
| Implement `BENCH-RENDER-001` (rendering pipeline) | RenderingPipeline Team | 2025-11-18 | PENDING |
| Implement `BENCH-SNAPSHOT-001` (snapshot generation) | SnapshotManager Team | 2025-11-18 | PENDING |
| Implement `BENCH-THUMB-001` (thumbnail regen) | NavigatorService Team | 2025-11-20 | PENDING |
| Implement `BENCH-CURSOR-001` (cursor latency) | InteractionEngine Team | 2025-11-20 | PENDING |
| Create `.github/workflows/nightly-benchmarks.yml` | DevOps Team | 2025-11-22 | PENDING |
| Configure Grafana dashboards | Observability Team | 2025-11-22 | PENDING |
| Configure Prometheus alerts | Observability Team | 2025-11-22 | PENDING |
| Write `compare_baseline.dart` script | Performance WG | 2025-11-20 | PENDING |

### 7.2 Follow-Up Actions (I6+)

| Action | Owner | Target Iteration |
|--------|-------|------------------|
| Baseline refresh (quarterly) | Performance WG | I7 (Q1 2026) |
| Add mobile platform benchmarks (iOS, Android) | Platform Team | I8 |
| Golden test integration (rendering parity) | RenderingPipeline Team | I6 |
| A/B testing framework for feature flags + performance | Performance WG | I7 |

---

## 8. References

### 8.1 Internal Documentation

- [Verification Matrix](verification_matrix.md) - FR/NFR → test mapping
- [Telemetry Policy](telemetry_policy.md) - Metrics catalog, opt-out enforcement
- [Quality Gates](quality_gates.md) - Baseline CI gates
- [Test Matrix CSV](test_matrix.csv) - Test suite inventory

### 8.2 Architecture Documents

- [03_Verification_and_Glossary.md](../../.codemachine/artifacts/architecture/03_Verification_and_Glossary.md) - Performance KPI definitions
- [04_Operational_Architecture.md](../../.codemachine/artifacts/architecture/04_Operational_Architecture.md) - Operational testing strategy

### 8.3 Task Context

- **Task ID:** I5.T4
- **Iteration:** I5 (Import/Export Pipelines & Release Readiness)
- **Dependencies:** I1.T6 (Quality Gates), I3.T6 (Telemetry Policy)

---

## 9. Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-11-11 | Claude (CodeImplementer) | Initial benchmark plan for I5.T4 |
