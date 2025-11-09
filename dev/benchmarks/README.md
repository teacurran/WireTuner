# WireTuner Rendering Performance Benchmarks

This directory contains automated performance benchmarks for the WireTuner rendering pipeline. The benchmark harness measures frame time, FPS, memory usage, and cache performance across varying document complexities and viewport configurations.

## Overview

The rendering benchmark suite (`render_bench.dart`) tests the performance of:
- **RenderPipeline**: High-performance vector rendering with culling and LOD optimizations
- **PathRenderer**: Geometry caching and conversion from domain to UI primitives
- **ViewportController**: Pan/zoom transformations at various scales

## Quick Start

Run the benchmark with default settings (500 objects, 30 iterations):

```bash
flutter test dev/benchmarks/render_bench.dart
```

This will generate `dev/benchmarks/results.json` and `dev/benchmarks/results.csv` containing detailed metrics for all scenarios.

## Usage

### Basic Usage

```bash
# Run with medium dataset (500 objects)
flutter test dev/benchmarks/render_bench.dart

# Run with large dataset (1000 objects) and 60 iterations
flutter test dev/benchmarks/render_bench.dart --dart-define=DATASET=large --dart-define=ITERATIONS=60

# Output with custom path
flutter test dev/benchmarks/render_bench.dart --dart-define=OUTPUT=my_results
```

### Command Line Options

Configuration is passed via `--dart-define` flags:

| Dart Define | Values | Default | Description |
|-------------|--------|---------|-------------|
| `DATASET` | `small`, `medium`, `large`, `xlarge` | `medium` | Dataset size (object count) |
| `ITERATIONS` | Integer | `30` | Number of render passes per scenario |
| `OUTPUT` | Path | `dev/benchmarks/results` | Output file path (extensions auto-added) |
| `FORMAT` | `json`, `csv`, `both` | `json` | Output format |

### Dataset Sizes

| Dataset | Object Count | Typical Use Case |
|---------|--------------|------------------|
| `small` | 100 | Quick smoke test |
| `medium` | 500 | Standard benchmark |
| `large` | 1000 | Stress test |
| `xlarge` | 2500 | Extreme load test |

Each dataset consists of ~70% paths and ~30% shapes (rectangles, ellipses, polygons, stars).

## Benchmark Scenarios

The harness runs the following scenarios for each dataset:

1. **Baseline (zoom 1.0, no opts)**: Rendering without optimizations (reference)
2. **With caching (zoom 1.0)**: PathRenderer caching enabled
3. **With culling (zoom 1.0)**: Viewport culling enabled
4. **All optimizations (zoom 1.0)**: Both caching and culling enabled
5. **Zoomed out (zoom 0.1, all opts)**: LOD stress test at low zoom
6. **Zoomed in (zoom 2.0, all opts)**: High-detail rendering at 2x zoom

## Output Format

### JSON Output

The JSON output includes:
- Timestamp and configuration metadata
- Per-scenario results with detailed metrics

Example:

```json
{
  "benchmark": "WireTuner Rendering Performance",
  "timestamp": "2025-01-15T10:30:00.000Z",
  "configuration": {
    "dataset": "medium",
    "objectCount": 500,
    "iterations": 30
  },
  "results": [
    {
      "scenario": {
        "name": "All optimizations (zoom 1.0)",
        "objectCount": 500,
        "zoomLevel": 1.0,
        "enableCulling": true,
        "enableCaching": true
      },
      "frameTimeMs": 8.32,
      "fps": 120.2,
      "objectsRendered": 487,
      "objectsCulled": 13,
      "cacheSize": 350,
      "memoryUsedMB": 12.5
    }
  ]
}
```

### CSV Output

The CSV output is optimized for spreadsheet analysis:

```csv
Scenario,ObjectCount,ZoomLevel,Culling,Caching,FrameTimeMs,FPS,ObjectsRendered,ObjectsCulled,CacheSize,MemoryMB
All optimizations (zoom 1.0),500,1.0,true,true,8.32,120.2,487,13,350,12.50
```

## Metrics Explanation

### Frame Time (ms)
Total time to render one frame, measured in milliseconds. Lower is better.
- **Target**: < 16.67ms (60 FPS)
- **Alert**: > 33ms (dropped frame, < 30 FPS)

### FPS (Frames Per Second)
Calculated as `1000 / frameTimeMs`. Higher is better.
- **Excellent**: > 60 FPS
- **Good**: 30-60 FPS
- **Poor**: < 30 FPS

### Objects Rendered
Number of vector objects actually drawn to the canvas. Fewer means better culling.

### Objects Culled
Number of objects skipped due to:
- Viewport culling (outside visible area)
- LOD optimization (too small when zoomed out)

### Cache Size
Number of entries in PathRenderer's geometry cache. Higher = more memory, but faster rendering.

### Memory Used (MB)
Resident Set Size (RSS) growth during the benchmark. Approximate memory footprint.

## Interpreting Results

### Performance Targets

Based on the architectural requirements (Section 5: Operational Architecture):

| Metric | Target | Warning | Alert |
|--------|--------|---------|-------|
| Frame Time | < 16.67ms | > 20ms | > 33ms |
| FPS | > 60 | < 50 | < 30 |
| Memory | < 100MB | > 200MB | > 500MB |

### Optimization Impact

Expected performance improvements:
- **Path Caching**: 2-5x faster on subsequent frames
- **Viewport Culling**: 20-80% reduction in rendered objects (varies by zoom/pan)
- **LOD at zoom 0.1**: 50-90% object culling for small objects

### Red Flags

Watch for these warning signs:
- Frame time > 16.67ms on medium dataset with all optimizations
- Cache size growing unbounded (potential memory leak)
- Memory usage > 100MB for medium dataset
- No performance difference between cached/uncached scenarios (caching not working)

## Running in CI

### Manual Trigger

The benchmark is designed for manual CI execution (not automatic on every commit):

```bash
# Locally
bash scripts/ci/run_benchmarks.sh

# GitHub Actions (manual workflow dispatch)
gh workflow run benchmarks.yml
```

### CI Script

The CI script (`scripts/ci/run_benchmarks.sh`) handles:
- Environment setup and dependency installation
- Running the benchmark with standard parameters
- Storing results as CI artifacts
- Failing the build if critical thresholds are exceeded (optional)

See `scripts/ci/run_benchmarks.sh` for configuration.

## Headless Execution

The benchmark runs headless (no window/display required) using `ui.PictureRecorder`. This works on:
- macOS (Intel and Apple Silicon)
- Windows (x64)
- Linux (CI runners)

No Flutter application shell is needed—the benchmark runs as a pure Dart script.

## Troubleshooting

### Benchmark fails to run

**Problem**: `Error: Cannot run benchmark or dart:ui not available`

**Solution**: Ensure you're in the project root and dependencies are installed:

```bash
cd /path/to/wiretuner
flutter pub get
flutter test dev/benchmarks/render_bench.dart
```

Note: Use `flutter test` (not `dart run`) since the benchmark requires Flutter's rendering infrastructure.

### Memory metrics show 0.0 MB

**Problem**: `ProcessInfo.currentRss` unavailable on platform.

**Solution**: This is expected on some platforms. Other metrics (frame time, FPS) remain valid.

### Results show no performance difference

**Problem**: Caching or culling appears to have no effect.

**Possible causes**:
1. Warm-up pass successfully populated all caches
2. Dataset too small to show meaningful differences
3. Bug in optimization implementation

**Solution**: Try larger datasets (`--dataset xlarge`) or inspect `RenderPipeline` logs.

## Extending the Benchmarks

### Adding Custom Scenarios

Edit `BenchmarkRunner._createScenarios()` in `render_bench.dart`:

```dart
scenarios.add(
  BenchmarkScenario(
    name: 'Custom scenario',
    objectCount: totalCount,
    pathCount: pathCount,
    shapeCount: shapeCount,
    zoomLevel: 0.5,  // Your zoom level
    enableCulling: true,
    enableCaching: true,
  ),
);
```

### Custom Dataset Generators

Modify `SyntheticDocumentGenerator` to create specific patterns:
- All rectangles
- Concentric circles
- Grid layouts
- Real-world document structures

### Integration with Real Documents

To benchmark real documents instead of synthetic ones:

1. Load a `.wiretuner` document using the document loader
2. Extract paths and shapes
3. Pass to `BenchmarkRunner._runScenario()` directly

## Related Documentation

- **Architecture**: `.codemachine/artifacts/architecture/05_Operational_Architecture.md`
- **Rendering Pipeline**: `lib/presentation/canvas/render_pipeline.dart`
- **Performance Tests**: `test/performance/rendering_benchmark_test.dart`
- **Metrics Sink**: `packages/event_core/lib/src/metrics_sink.dart`

## Maintenance

**Owner**: DevOps / Performance Team
**Iteration**: I2 (Task I2.T9)
**Dependencies**: I2.T6 (RenderPipeline), I2.T8 (ViewportController)

For questions or improvements, see the project's contribution guidelines.
