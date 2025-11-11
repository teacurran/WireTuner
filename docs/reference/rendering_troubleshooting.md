# Rendering Troubleshooting Guide

<!-- anchor: rendering-troubleshooting -->

**Version:** 1.0
**Date:** 2025-11-09
**Status:** Active
**Related Documents:** [Rendering Performance Benchmarks](../../dev/benchmarks/README.md) | [Vector Model Specification](vector_model.md) | [Performance Tests](../../test/performance/rendering_benchmark_test.dart)

---

## Overview

This guide provides diagnostic procedures and remediation steps for common rendering performance issues in WireTuner. It covers known problems, their symptoms, diagnostic commands, and escalation paths for issues requiring deeper investigation or future enhancements.

**Target Audience:** Developers, performance engineers, and QA teams investigating rendering bottlenecks or visual artifacts.

**Performance Targets:**

Following the architectural requirements (Section 5: Operational Architecture), WireTuner aims for these rendering performance goals:

| Metric | Target | Warning | Alert |
|--------|--------|---------|-------|
| Frame Time | < 16.67ms | > 20ms | > 33ms |
| FPS | > 60 | < 50 | < 30 |
| Memory Usage | < 100MB | > 200MB | > 500MB |

---

## Table of Contents

1. [Diagnostic Tools](#diagnostic-tools)
2. [Common Scenarios](#common-scenarios)
   - [Scenario 1: Frame Time Spikes / Dropped Frames](#scenario-1-frame-time-spikes--dropped-frames)
   - [Scenario 2: Low FPS on Large Documents](#scenario-2-low-fps-on-large-documents)
   - [Scenario 3: Path Cache Not Improving Performance](#scenario-3-path-cache-not-improving-performance)
   - [Scenario 4: Memory Leak or Unbounded Growth](#scenario-4-memory-leak-or-unbounded-growth)
   - [Scenario 5: Precision Loss / Z-Fighting Artifacts](#scenario-5-precision-loss--z-fighting-artifacts)
   - [Scenario 6: Poor Performance When Zoomed Out](#scenario-6-poor-performance-when-zoomed-out)
   - [Scenario 7: Cache Invalidation Thrashing](#scenario-7-cache-invalidation-thrashing)
3. [Advanced Diagnostics](#advanced-diagnostics)
4. [Escalation Paths](#escalation-paths)
5. [Future Optimizations](#future-optimizations)

---

## Diagnostic Tools

WireTuner provides several built-in tools for diagnosing rendering performance issues:

### 1. Performance Overlay (In-App)

**Purpose:** Real-time monitoring of rendering metrics during normal application use.

**Access:** Toggle with keyboard shortcut:
- **macOS:** Cmd+Shift+P
- **Windows/Linux:** Ctrl+Shift+P

**Metrics Displayed:**
- **FPS**: Frames per second (color-coded: green > 50, yellow > 30, red < 30)
- **Frame Time**: Milliseconds per frame (color-coded: green < 16ms, yellow < 33ms, red > 33ms)
- **Objects Rendered**: Number of vector objects actually drawn
- **Objects Culled**: Number of objects skipped due to viewport/LOD optimizations
- **Cache Size**: Number of entries in PathRenderer's geometry cache
- **Zoom**: Current viewport zoom level (percentage)
- **Pan**: Current viewport pan offset (x, y)

**Reference:** `lib/presentation/canvas/overlays/performance_overlay.dart`

**Usage Tips:**
- Enable the overlay before reproducing performance issues
- Take screenshots showing metric values when issues occur
- Note the zoom level and document complexity when capturing data

### 2. Benchmark Harness (Command Line)

**Purpose:** Automated performance testing across varying document complexities and viewport configurations.

**Location:** `dev/benchmarks/render_bench.dart`

**Basic Usage:**

```bash
# Run with default settings (500 objects, 30 iterations)
flutter test dev/benchmarks/render_bench.dart

# Run with large dataset (1000 objects)
flutter test dev/benchmarks/render_bench.dart --dart-define=DATASET=large

# Run with custom iterations and output
flutter test dev/benchmarks/render_bench.dart \
  --dart-define=DATASET=xlarge \
  --dart-define=ITERATIONS=60 \
  --dart-define=OUTPUT=my_results \
  --dart-define=FORMAT=both
```

**Dataset Sizes:**

| Dataset | Object Count | Use Case |
|---------|--------------|----------|
| `small` | 100 | Quick smoke test |
| `medium` | 500 | Standard benchmark |
| `large` | 1000 | Stress test |
| `xlarge` | 2500 | Extreme load test |

**Output Formats:**
- **JSON:** `results.json` - Detailed metrics with scenario metadata
- **CSV:** `results.csv` - Spreadsheet-friendly format for trend analysis

**Reference:** [Benchmark README](../../dev/benchmarks/README.md)

### 3. Rendering Benchmark Tests (Unit Level)

**Purpose:** Lower-latency diagnostics for specific rendering subsystems.

**Location:** `test/performance/rendering_benchmark_test.dart`

**Run Tests:**

```bash
# Run all rendering performance tests
flutter test test/performance/rendering_benchmark_test.dart

# Run specific test
flutter test test/performance/rendering_benchmark_test.dart --name "PathRenderer caching"
```

**Coverage:**
- Path generation performance
- `DocumentPainter` timing
- `PathRenderer` caching speedups
- Cache invalidation behavior
- Zoom-dependent cache persistence

**Usage Tips:**
- Use these tests when investigating cache hit rate issues
- Faster feedback loop than full benchmark harness
- Validate caching logic before running expensive benchmarks

### 4. Log Files

**Purpose:** Persistent diagnostic logs for post-mortem analysis.

**Log Locations:**

| Platform | Path |
|----------|------|
| macOS | `~/Library/Application Support/WireTuner/wiretuner.log` |
| Windows | `%APPDATA%\WireTuner\wiretuner.log` |

**Log Levels:**
- **ERROR**: Unrecoverable failures (file I/O errors, corrupted data)
- **WARN**: Recoverable issues (dropped frames, performance degradation)
- **INFO**: Key lifecycle events (document loaded, export completed)
- **DEBUG**: Detailed flow (event recorded, tool state changes)
- **TRACE**: Verbose output (geometry calculations) - disabled in release

**Log Rotation:**
- Max log file size: 10 MB
- Keeps last 5 log files (`wiretuner.log`, `wiretuner.1.log`, ..., `wiretuner.4.log`)

**Reference:** Architecture Section 5 - [Logging Strategy](.codemachine/artifacts/architecture/05_Operational_Architecture.md#logging-strategy)

---

## Common Scenarios

### Scenario 1: Frame Time Spikes / Dropped Frames

#### Symptom

Intermittent frame time spikes > 33ms (< 30 FPS) causing visible stuttering or jank during pan/zoom operations.

#### Possible Causes

1. **Cache invalidation during interaction:** Panning or zooming triggers cache invalidation, forcing re-tessellation of all paths
2. **Garbage collection pressure:** Large object allocations triggering GC pauses
3. **Synchronous I/O on UI thread:** Event persistence or snapshot creation blocking rendering
4. **Excessive re-rendering:** Widget tree rebuilding unnecessarily

#### Diagnostics

1. **Enable Performance Overlay** (Cmd/Ctrl+Shift+P) and monitor frame time during pan/zoom:
   - Note when spikes occur (start of pan? continuous during pan? after zoom?)
   - Check if "Cache Size" drops to zero during interaction (indicates cache thrashing)

2. **Check Logs** for warnings:
   ```bash
   # macOS
   grep "Dropped frame" ~/Library/Application\ Support/WireTuner/wiretuner.log

   # Windows
   findstr "Dropped frame" %APPDATA%\WireTuner\wiretuner.log
   ```

3. **Run Cache-Specific Tests:**
   ```bash
   flutter test test/performance/rendering_benchmark_test.dart --name "cache"
   ```

4. **Profile with Flutter DevTools:**
   - Run app in profile mode: `flutter run --profile`
   - Open DevTools: `flutter pub global run devtools`
   - Navigate to Performance tab and record during reproduction
   - Look for long synchronous operations or GC events

#### Remediation

**Short-term:**

1. **Disable Viewport Culling** if cache thrashing is observed:
   ```dart
   // In RenderPipeline initialization
   config: RenderPipelineConfig(
     enableViewportCulling: false, // Temporarily disable
     enablePathCaching: true,
   )
   ```

2. **Increase Cache Retention** during viewport changes:
   - Current implementation invalidates cache on zoom changes
   - Consider retaining cache entries when zoom delta is small (< 10%)

3. **Reduce Document Complexity** temporarily to isolate issue:
   - If spikes disappear with < 500 objects, issue is scale-related

**Long-term:**

1. **Implement Dirty Region Tracking** (Iteration 3+):
   - Use Flutter's `RepaintBoundary` to isolate static content
   - Only invalidate cache for modified objects

2. **Optimize Cache Invalidation Strategy**:
   - Implement zoom-aware cache keys (store multiple resolutions)
   - Use incremental invalidation instead of full cache clear

**Reference:** `lib/presentation/canvas/render_pipeline.dart:336` (`invalidateAll()`)

---

### Scenario 2: Low FPS on Large Documents

#### Symptom

Sustained FPS < 30 on documents with > 1000 objects, even without user interaction.

#### Possible Causes

1. **Viewport culling disabled:** Rendering all objects regardless of visibility
2. **LOD threshold too low:** Not skipping small objects when zoomed out
3. **Inefficient path tessellation:** Complex Bezier curves requiring excessive subdivisions
4. **No path caching:** Re-converting domain paths to `ui.Path` every frame

#### Diagnostics

1. **Enable Performance Overlay** and check metrics:
   - If "Objects Rendered" equals total document object count, culling is ineffective
   - If "Objects Culled" is zero, culling is disabled or not working

2. **Run Benchmark with Culling Variants:**
   ```bash
   flutter test dev/benchmarks/render_bench.dart --dart-define=DATASET=large
   ```
   - Compare "With culling (zoom 1.0)" vs "Baseline (zoom 1.0, no opts)" scenarios
   - Expected improvement: 20-80% reduction in rendered objects

3. **Check RenderPipeline Configuration:**
   ```dart
   // Verify these are enabled in production
   RenderPipelineConfig(
     enablePathCaching: true,
     enableViewportCulling: true,
     enableGPUCaching: false, // Not yet implemented
   )
   ```

4. **Analyze Benchmark Results:**
   ```bash
   # Check JSON output for red flags
   cat dev/benchmarks/results.json | grep -A 5 "objectsCulled"
   ```

#### Remediation

**Short-term:**

1. **Enable All Optimizations:**
   ```dart
   RenderPipelineConfig(
     enablePathCaching: true,
     enableViewportCulling: true,
     cullMargin: 100.0, // Adjust margin as needed
     lodThreshold: 0.25, // Simplify rendering below 25% zoom
     minObjectScreenSize: 2.0, // Skip objects < 2px when zoomed out
   )
   ```

2. **Increase LOD Thresholds** for very large documents:
   ```dart
   RenderPipelineConfig(
     lodThreshold: 0.5, // More aggressive LOD
     minObjectScreenSize: 5.0, // Skip smaller objects
   )
   ```

3. **Profile Path Complexity:**
   - Identify paths with > 20 anchors or excessive Bezier segments
   - Consider simplifying complex paths programmatically

**Long-term:**

1. **Implement GPU Raster Caching** (TODO - Iteration 3+):
   - Cache complex object groups as raster images
   - Fall back to vector rendering during editing
   - Reference: `RenderPipelineConfig.enableGPUCaching` (line 35)

2. **Add Spatial Indexing** (TODO - Iteration 4+):
   - Use Bounding Volume Hierarchy (BVH) or R-tree for culling
   - Reduce O(n) object iteration to O(log n) visibility queries

3. **Implement Background Tessellation**:
   - Move path conversion to isolate (background thread)
   - Queue converted paths for main thread rendering

**Reference:** `lib/presentation/canvas/render_pipeline.dart:83-109` (Architecture comments)

---

### Scenario 3: Path Cache Not Improving Performance

#### Symptom

Benchmark results show no performance difference between "With caching (zoom 1.0)" and "Baseline (zoom 1.0, no opts)" scenarios, or performance overlay shows cache size remains zero.

#### Possible Causes

1. **Cache disabled in configuration:** `enablePathCaching: false`
2. **Cache invalidation on every frame:** Paths changing or cache being cleared
3. **Cache key mismatch:** Object IDs changing between frames
4. **Warm-up pass populating cache:** All caches already populated, masking benefits

#### Diagnostics

1. **Verify Cache Configuration:**
   ```dart
   // Check RenderPipeline initialization
   print(pipeline.config.enablePathCaching); // Should be true
   ```

2. **Monitor Cache Size in Performance Overlay:**
   - Enable overlay (Cmd/Ctrl+Shift+P)
   - Cache size should grow as objects are rendered
   - If stuck at 0, cache is not being populated

3. **Run Cache-Specific Tests:**
   ```bash
   flutter test test/performance/rendering_benchmark_test.dart --name "PathRenderer caching"
   ```
   - Tests verify 2-5x speedup on subsequent renders
   - If tests pass but app shows no improvement, issue is in integration

4. **Check for Unexpected Invalidation:**
   - Add debug logging in `PathRenderer.invalidate()` and `invalidateAll()`
   - Look for log entries during normal rendering (shouldn't invalidate unless objects change)

#### Remediation

**Short-term:**

1. **Enable Path Caching:**
   ```dart
   RenderPipelineConfig(
     enablePathCaching: true,
   )
   ```

2. **Verify Object IDs are Stable:**
   - Object IDs must remain constant across frames
   - If using generated IDs, ensure they're based on persistent data (UUID from event)

3. **Reduce Cache Invalidation:**
   ```dart
   // Only invalidate specific objects that changed
   pipeline.invalidateObject(changedObjectId);

   // Avoid full cache clear unless absolutely necessary
   // pipeline.invalidateAll(); // Use sparingly
   ```

4. **Increase Benchmark Iterations:**
   ```bash
   # More iterations show clearer cache benefits
   flutter test dev/benchmarks/render_bench.dart --dart-define=ITERATIONS=60
   ```

**Long-term:**

1. **Implement Cache Metrics:**
   - Track cache hit rate in `PathRenderer`
   - Expose via `RenderMetrics.cacheHitRate`
   - Monitor in performance overlay

2. **Add Cache Size Limits:**
   - Implement LRU eviction when cache exceeds threshold (e.g., 1000 entries)
   - Prevent unbounded memory growth on very large documents

3. **Profile Cache Effectiveness:**
   - Log cache hits/misses in debug mode
   - Analyze which object types benefit most from caching

**Reference:** `lib/presentation/canvas/painter/path_renderer.dart`

---

### Scenario 4: Memory Leak or Unbounded Growth

#### Symptom

Memory usage continuously grows over time, eventually exceeding 500MB and causing performance degradation or out-of-memory crashes.

#### Possible Causes

1. **Unbounded path cache:** Cache never evicts entries, growing indefinitely
2. **Event log accumulation:** Old events not cleared after snapshot creation
3. **Leaked listeners or subscriptions:** Flutter widgets not disposing resources
4. **Retained snapshots:** Old snapshots not being deleted from SQLite

#### Diagnostics

1. **Monitor Memory in Performance Overlay:**
   - Note baseline memory usage with empty document
   - Open large document and observe memory growth
   - Pan/zoom repeatedly and check if memory keeps growing

2. **Run Benchmark with Memory Tracking:**
   ```bash
   flutter test dev/benchmarks/render_bench.dart --dart-define=DATASET=xlarge
   ```
   - Check "memoryUsedMB" in results
   - Compare across scenarios to isolate memory-hungry features

3. **Use Flutter DevTools Memory Profiler:**
   ```bash
   flutter run --profile
   # Open DevTools -> Memory tab
   # Take heap snapshot before and after loading large document
   # Compare snapshots to identify leaked objects
   ```

4. **Check Cache Size Growth:**
   - Enable performance overlay
   - Load progressively larger documents
   - If "Cache Size" grows beyond object count, cache may not be evicting

#### Remediation

**Short-term:**

1. **Manually Clear Cache Periodically:**
   ```dart
   // After major document changes
   pipeline.invalidateAll();
   ```

2. **Monitor Benchmark Memory Metrics:**
   - Fail CI builds if memory usage exceeds thresholds:
   ```bash
   # In CI script
   if (memoryUsedMB > 200) {
     echo "Memory usage too high: ${memoryUsedMB}MB"
     exit 1
   }
   ```

3. **Disable Caching Temporarily** to confirm cache is the issue:
   ```dart
   RenderPipelineConfig(
     enablePathCaching: false,
   )
   ```
   - If memory leak stops, cache eviction is needed

**Long-term:**

1. **Implement LRU Cache with Size Limit:**
   - Set maximum cache size (e.g., 1000 entries or 100MB)
   - Evict least-recently-used entries when limit is reached
   - Reference: Consider `package:collection` LinkedHashMap for LRU

2. **Add Snapshot Cleanup:**
   - Delete snapshots older than N events (e.g., keep only last 3 snapshots)
   - Implement in snapshot manager background task

3. **Audit Resource Disposal:**
   - Run static analysis for unclosed streams/subscriptions:
   ```bash
   flutter analyze | grep "close_sinks\|cancel_subscriptions"
   ```
   - Ensure all controllers/listeners are disposed in `dispose()` methods

4. **Add Memory Profiling to CI:**
   - Run memory leak tests as part of nightly CI
   - Alert team if memory usage trends upward

**Reference:** Architecture Section 5 - [Performance Monitoring](.codemachine/artifacts/architecture/05_Operational_Architecture.md#monitoring-metrics)

---

### Scenario 5: Precision Loss / Z-Fighting Artifacts

#### Symptom

Visual artifacts where objects flicker or incorrectly overlap, especially when zoomed in (> 200%) or with very large coordinate values (> 10,000 world units).

#### Possible Causes

1. **Floating-point precision limits:** Dart's `double` (64-bit IEEE 754) loses precision at large scales
2. **Viewport transformation errors:** Accumulated rounding errors during world-to-screen conversion
3. **Z-order rendering inconsistencies:** Objects with identical bounds rendered in non-deterministic order
4. **Bezier curve tessellation artifacts:** Subdivision errors at extreme zoom levels

#### Diagnostics

1. **Reproduce at Extreme Zoom Levels:**
   - Zoom in to 500% (5.0x) or higher
   - Pan to large coordinate values (x > 10,000, y > 10,000)
   - Check if artifacts appear

2. **Check Viewport Transformation Logic:**
   ```dart
   // In ViewportController
   print('World point: $worldPoint');
   print('Screen point: ${toScreen(worldPoint)}');
   print('Round-trip: ${toWorld(toScreen(worldPoint))}');
   // Should match worldPoint within epsilon (< 0.01)
   ```

3. **Verify Rendering Order Determinism:**
   - Load same document twice
   - Take screenshot each time
   - Compare pixel-by-pixel (should be identical)

4. **Test with Coordinate Extremes:**
   ```dart
   // Create test path with large coordinates
   final path = Path.line(
     Point(x: 100000, y: 100000),
     Point(x: 100100, y: 100100),
   );
   // Verify rendering is correct
   ```

#### Remediation

**Short-term:**

1. **Limit Zoom Range:**
   ```dart
   // In ViewportController
   static const double minZoom = 0.1;
   static const double maxZoom = 10.0; // Reduce from higher values
   ```

2. **Clamp Coordinate Values:**
   - Warn users if objects exceed safe coordinate range
   - Recommend keeping coordinates within -10,000 to +10,000

3. **Use Epsilon Comparisons:**
   ```dart
   // When comparing floating-point values
   const epsilon = 0.0001;
   if ((a - b).abs() < epsilon) {
     // Consider equal
   }
   ```

**Long-term:**

1. **Implement Fixed-Point Arithmetic** (Iteration 5+):
   - Use integer coordinates internally (e.g., 1/100th pixel precision)
   - Convert to floating-point only during rendering
   - Eliminates precision loss at large scales

2. **Add Z-Index Field to VectorObject:**
   - Explicitly control rendering order
   - Break ties deterministically (e.g., by object ID)

3. **Improve Bezier Tessellation:**
   - Use adaptive subdivision based on screen-space error
   - Increase subdivision depth when zoomed in

**Reference:** `lib/domain/models/geometry/point.dart`, `lib/presentation/canvas/viewport/viewport_controller.dart`

---

### Scenario 6: Poor Performance When Zoomed Out

#### Symptom

Frame time > 33ms (< 30 FPS) when zoomed out to < 10% (0.1x), even with viewport culling enabled.

#### Possible Causes

1. **LOD threshold too low:** Rendering tiny objects that are invisible at low zoom
2. **Cull margin too large:** Rendering objects far outside viewport
3. **Tessellation quality not scaling:** Using high-detail Bezier subdivision for tiny objects
4. **Hit-testing overhead:** Processing all objects even when not visible

#### Diagnostics

1. **Run LOD Stress Test:**
   ```bash
   flutter test dev/benchmarks/render_bench.dart --dart-define=DATASET=large
   ```
   - Check "Zoomed out (zoom 0.1, all opts)" scenario results
   - Expected: > 50% object culling due to LOD

2. **Enable Performance Overlay and Zoom Out:**
   - Zoom to 10% (0.1x)
   - Check "Objects Culled" metric
   - Should show significant culling (> 50% of objects)

3. **Verify LOD Configuration:**
   ```dart
   print(pipeline.config.lodThreshold); // Should be 0.25
   print(pipeline.config.minObjectScreenSize); // Should be 2.0
   ```

4. **Profile Object Iteration:**
   - If culling high but FPS still low, iteration overhead may be the issue
   - Consider spatial indexing for large documents

#### Remediation

**Short-term:**

1. **Increase LOD Thresholds:**
   ```dart
   RenderPipelineConfig(
     lodThreshold: 0.5, // More aggressive (skip below 50% zoom)
     minObjectScreenSize: 5.0, // Skip objects < 5px on screen
   )
   ```

2. **Reduce Cull Margin:**
   ```dart
   RenderPipelineConfig(
     cullMargin: 50.0, // Reduce from default 100.0
   )
   ```

3. **Disable Stroke Rendering at Low Zoom:**
   - Modify `_renderPath()` to skip stroke when zoomed out
   - Only render fills for overview

**Long-term:**

1. **Implement Adaptive Tessellation Quality:**
   - Reduce Bezier subdivision when zoomed out
   - Use coarser approximations for tiny objects
   - Reference: `PathRenderer` tessellation logic

2. **Add Spatial Indexing** (BVH or R-tree):
   - Reduce O(n) culling loop to O(log n)
   - Essential for documents with > 5000 objects

3. **Implement Object Simplification:**
   - Generate simplified versions of complex paths
   - Use simplified versions when screen size < threshold

**Reference:** `lib/presentation/canvas/render_pipeline.dart:321-333` (`_shouldSkipForLOD()`)

---

### Scenario 7: Cache Invalidation Thrashing

#### Symptom

Frequent cache invalidation causing repeated cache misses and poor performance, observable as cache size fluctuating in performance overlay.

#### Possible Causes

1. **Object modification triggering full cache clear:** Editing one object invalidates entire cache
2. **Viewport changes clearing cache:** Zoom/pan operations clearing cache unnecessarily
3. **Unnecessary object updates:** Objects marked as modified even when unchanged
4. **Event replay invalidating cache:** Loading document clears cache before replay completes

#### Diagnostics

1. **Monitor Cache Size During Editing:**
   - Enable performance overlay
   - Make small edit (move one object)
   - Watch "Cache Size" metric
   - Should only decrease by 1, not drop to zero

2. **Add Debug Logging:**
   ```dart
   // In PathRenderer.invalidate()
   logger.d('Invalidating cache for object: $objectId');

   // In PathRenderer.invalidateAll()
   logger.w('Clearing entire cache! Current size: $cacheSize');
   ```

3. **Check Invalidation Call Sites:**
   ```bash
   # Find all invalidateAll() calls
   grep -r "invalidateAll()" lib/
   ```

4. **Profile Cache Churn Rate:**
   - Measure cache invalidations per second
   - High churn (> 10/sec) indicates thrashing

#### Remediation

**Short-term:**

1. **Use Selective Invalidation:**
   ```dart
   // Instead of:
   pipeline.invalidateAll();

   // Use:
   pipeline.invalidateObject(modifiedObjectId);
   ```

2. **Batch Invalidations:**
   - Collect modified object IDs during event replay
   - Invalidate once after replay completes

3. **Defer Invalidation:**
   - Queue invalidations during rapid changes
   - Process queue after interaction ends

**Long-term:**

1. **Implement Dirty Tracking:**
   - Mark objects as dirty instead of immediate invalidation
   - Invalidate cache lazily during render
   - Only invalidate truly modified objects

2. **Add Cache Versioning:**
   - Track cache version per object
   - Increment version on modification
   - Compare versions during cache lookup

3. **Implement Incremental Cache Updates:**
   - Update cache entries in-place when possible
   - Avoid full re-tessellation for minor changes

**Reference:** `lib/presentation/canvas/render_pipeline.dart:336-343` (invalidation methods)

---

## Advanced Diagnostics

### Running CI Benchmarks Locally

To reproduce CI benchmark results on your local machine:

```bash
# Run benchmark script (same as CI)
bash scripts/ci/run_benchmarks.sh

# Or manually with specific parameters
flutter test dev/benchmarks/render_bench.dart \
  --dart-define=DATASET=medium \
  --dart-define=ITERATIONS=30 \
  --dart-define=FORMAT=both
```

### Comparing Benchmark Results Over Time

Track performance regressions by comparing benchmark output across commits:

```bash
# Run baseline benchmark
git checkout main
flutter test dev/benchmarks/render_bench.dart --dart-define=OUTPUT=baseline

# Run current branch benchmark
git checkout feature-branch
flutter test dev/benchmarks/render_bench.dart --dart-define=OUTPUT=feature

# Compare JSON results
diff baseline.json feature.json
```

### Custom Benchmark Scenarios

To add custom scenarios for specific performance testing:

1. Edit `dev/benchmarks/render_bench.dart`
2. Modify `BenchmarkRunner._createScenarios()`:

```dart
scenarios.add(
  BenchmarkScenario(
    name: 'Custom scenario: High Bezier density',
    objectCount: totalCount,
    pathCount: pathCount,
    shapeCount: shapeCount,
    zoomLevel: 1.0,
    enableCulling: true,
    enableCaching: true,
  ),
);
```

3. Adjust `SyntheticDocumentGenerator` to create specific patterns

**Reference:** `dev/benchmarks/render_bench.dart:337-404`

### Profiling with Flutter DevTools

For detailed performance profiling:

```bash
# Run in profile mode (optimized but with profiling enabled)
flutter run --profile

# Launch DevTools
flutter pub global activate devtools
flutter pub global run devtools

# In DevTools:
# 1. Navigate to Performance tab
# 2. Click "Record" button
# 3. Reproduce performance issue in app
# 4. Click "Stop" button
# 5. Analyze frame timeline and CPU profiler
```

Look for:
- Long synchronous operations (> 16ms blocks)
- Garbage collection pauses (GC events)
- Excessive widget rebuilds (`build()` calls)
- Shader compilation stalls (first frame after launch)

---

## Escalation Paths

When standard troubleshooting doesn't resolve an issue, escalate through these paths:

### Internal Escalation (Current Iteration)

1. **Document the Issue:**
   - Symptoms observed
   - Steps to reproduce
   - Diagnostics already performed
   - Relevant log excerpts or screenshots

2. **Create GitHub Issue:**
   - Use template: "Rendering Performance Issue"
   - Attach benchmark results (JSON/CSV)
   - Include performance overlay screenshots
   - Link to log files

3. **Assign to Performance Team:**
   - Tag with `performance`, `rendering` labels
   - Set priority based on severity:
     - **P0 (Critical):** Rendering completely broken, app unusable
     - **P1 (High):** FPS < 30 on typical documents (< 500 objects)
     - **P2 (Medium):** FPS 30-60 on typical documents
     - **P3 (Low):** Performance issues only on extreme documents (> 2500 objects)

### Future Iteration Escalation

Some performance issues require architectural changes planned for future iterations:

| Issue Type | Planned Iteration | Reference |
|------------|-------------------|-----------|
| GPU/Raster Caching | Iteration 3 (I3) | `RenderPipelineConfig.enableGPUCaching` TODO |
| Spatial Indexing (BVH) | Iteration 4 (I4) | Architecture Section 5 - Future Enhancements |
| Multi-threaded Tessellation | Iteration 5 (I5) | TBD |
| WebGL/Skia GPU Backend | Iteration 6+ (I6+) | TBD |

**Process:**
1. Document issue as technical debt
2. Add to future iteration backlog
3. Provide workaround if available
4. Monitor issue frequency to prioritize scheduling

### External Escalation (Flutter/Dart)

If root cause is in Flutter or Dart SDK:

1. **Verify Flutter Version:**
   ```bash
   flutter --version
   flutter doctor -v
   ```

2. **Search Flutter GitHub Issues:**
   - Search for similar rendering performance issues
   - Check if issue is fixed in newer Flutter versions

3. **File Upstream Bug:**
   - Use Flutter issue template
   - Provide minimal reproduction case
   - Include Flutter Doctor output and stack traces
   - Link to WireTuner issue for context

---

## Future Optimizations

The following optimizations are planned for future iterations but not yet implemented. Current troubleshooting should consider these as potential long-term solutions:

### GPU/Raster Caching (Iteration 3 - I3)

**Status:** Planned (TODO in code)

**Description:** Cache complex object groups as raster images for faster compositing.

**Benefits:**
- 5-10x speedup for static, complex groups
- Reduced CPU load during panning/zooming
- Better battery life on laptops

**Implementation Notes:**
- Use Flutter's `Picture.toImage()` for rasterization
- Store cached images in GPU texture memory
- Invalidate on object modification or style change
- Fall back to vector rendering during editing

**Reference:** `lib/presentation/canvas/render_pipeline.dart:33-35`

```dart
/// Enable GPU-friendly caching strategies.
///
/// TODO(I3): Implement raster caching for complex object groups.
final bool enableGPUCaching;
```

### Spatial Indexing with BVH (Iteration 4 - I4)

**Status:** Planned

**Description:** Replace O(n) culling loop with O(log n) Bounding Volume Hierarchy (BVH) queries.

**Benefits:**
- Essential for documents with > 5000 objects
- 10-100x faster culling on large documents
- Enables real-time hit-testing for complex scenes

**Implementation Notes:**
- Build BVH during document load or background task
- Rebuild incrementally on object modification
- Use Axis-Aligned Bounding Box (AABB) nodes
- Consider R-tree for 2D spatial queries

**Alternative:** R-tree (better for 2D, more complex implementation)

### Multi-threaded Path Tessellation (Iteration 5 - I5)

**Status:** Exploration

**Description:** Move Bezier curve tessellation to background isolate (Dart thread).

**Benefits:**
- Offload CPU work from UI thread
- Better utilization of multi-core CPUs
- Smoother 60 FPS rendering on complex documents

**Challenges:**
- Serialization overhead for Path objects between isolates
- Synchronization complexity
- Cache coordination across threads

**Implementation Notes:**
- Use Dart Isolate API
- Queue paths for background conversion
- Return `ui.Path` objects to main thread
- Maintain cache consistency between isolates

### Adaptive Tessellation Quality (Iteration 3 - I3)

**Status:** Planned

**Description:** Dynamically adjust Bezier subdivision quality based on zoom level and object screen size.

**Benefits:**
- Fewer vertices when zoomed out (LOD optimization)
- Smoother curves when zoomed in (quality)
- Balances performance and visual quality

**Implementation Strategy:**
- Calculate screen-space error tolerance
- Use flatness test for adaptive subdivision
- Store quality level in cache key (zoom-dependent caching)

---

## Related Documentation

- **[Rendering Performance Benchmarks](../../dev/benchmarks/README.md):** Benchmark harness usage, dataset sizes, output formats, and red flag thresholds
- **[Vector Model Specification](vector_model.md):** Domain model structures, coordinate systems, and geometric operations
- **[Performance Tests](../../test/performance/rendering_benchmark_test.dart):** Lower-latency diagnostic tests for cache validation
- **[Operational Architecture](../../.codemachine/artifacts/architecture/05_Operational_Architecture.md):** Performance monitoring strategy, logging, and targets
- **[Event Schema Reference](event_schema.md):** Event sampling rates and replay performance targets

---

**Document Maintainer:** Performance Engineering Team
**Last Updated:** 2025-11-09
**Next Review:** After completion of I3.T1 (GPU Caching Implementation)
