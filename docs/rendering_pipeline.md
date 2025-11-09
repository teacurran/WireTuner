# Rendering Pipeline

This document describes the WireTuner rendering pipeline architecture, features, and usage.

## Overview

The WireTuner rendering pipeline is a high-performance system for rendering vector graphics with support for:

- **Path and Shape Rendering**: Stroke, fill, and combined styles
- **GPU-Friendly Caching**: Optimized geometry caching with smart invalidation
- **Performance Optimizations**: Viewport culling, LOD, and dirty region tracking
- **Debug Tooling**: Real-time performance monitoring overlay

## Architecture

### Components

1. **PaintStyles** (`lib/presentation/canvas/paint_styles.dart`)
   - Defines visual styles for rendering (stroke, fill, gradients)
   - Converts styles to Flutter Paint objects
   - Placeholder API for future gradient support

2. **RenderPipeline** (`lib/presentation/canvas/render_pipeline.dart`)
   - Orchestrates the rendering process
   - Applies performance optimizations (caching, culling, LOD)
   - Collects performance metrics

3. **PathRenderer** (`lib/presentation/canvas/painter/path_renderer.dart`)
   - Converts domain geometry to `dart:ui` Path objects
   - Caches converted paths with smart invalidation

4. **DocumentPainter** (`lib/presentation/canvas/painter/document_painter.dart`)
   - CustomPainter that renders the document
   - Integrates with RenderPipeline for optimized rendering
   - Falls back to legacy rendering if pipeline disabled

5. **PerformanceOverlay** (`lib/presentation/canvas/overlays/performance_overlay.dart`)
   - Real-time performance monitoring UI
   - Keyboard-toggled overlay (Cmd/Ctrl+Shift+P)
   - Displays FPS, frame time, render stats, viewport state

## Usage

### Basic Rendering

```dart
// Create canvas with default rendering
WireTunerCanvas(
  paths: document.paths,
  shapes: document.shapes,
  selection: selection,
  viewportController: viewportController,
)
```

### Enable Performance Overlay

```dart
// Show performance overlay (toggle with Cmd/Ctrl+Shift+P)
WireTunerCanvas(
  paths: document.paths,
  shapes: document.shapes,
  selection: selection,
  viewportController: viewportController,
  showPerformanceOverlay: true,
)
```

### Advanced Pipeline Configuration

```dart
// Custom render pipeline with optimizations
final pipeline = RenderPipeline(
  pathRenderer: pathRenderer,
  config: RenderPipelineConfig(
    enablePathCaching: true,
    enableViewportCulling: true,
    enableGPUCaching: false, // Future: I3+
    cullMargin: 100.0,
    lodThreshold: 0.25,
    minObjectScreenSize: 2.0,
  ),
);

// Use in DocumentPainter
DocumentPainter(
  paths: paths,
  viewportController: viewportController,
  renderPipeline: pipeline,
)
```

### Custom Paint Styles

```dart
// Stroke style
const strokeStyle = PaintStyle.stroke(
  color: Colors.black,
  strokeWidth: 2.0,
  cap: StrokeCap.round,
  join: StrokeJoin.round,
);

// Fill style
const fillStyle = PaintStyle.fill(
  color: Colors.blue,
  opacity: 0.5,
);

// Stroke and fill
const bothStyle = PaintStyle.strokeAndFill(
  strokeColor: Colors.black,
  fillColor: Colors.white,
  strokeWidth: 1.5,
);

// Render with pipeline
final renderablePath = RenderablePath(
  id: 'path-123',
  path: domainPath,
  style: strokeStyle,
);

pipeline.render(
  canvas: canvas,
  size: size,
  viewportController: viewportController,
  paths: [renderablePath],
);
```

## Performance Optimizations

### 1. Path Caching

Converted `dart:ui` Path objects are cached and reused across frames:

```dart
final config = RenderPipelineConfig(
  enablePathCaching: true, // Default: enabled
);
```

**Invalidation Strategy:**
- Automatic invalidation when geometry changes (via hash)
- Automatic invalidation on significant zoom changes (>10% by default)
- Manual invalidation via `pipeline.invalidateObject(id)`

### 2. Viewport Culling (Future: I3)

Objects outside the visible viewport are not rendered:

```dart
final config = RenderPipelineConfig(
  enableViewportCulling: true,
  cullMargin: 100.0, // Render 100px outside viewport
);
```

### 3. Level of Detail (Future: I3)

Rendering quality adapts based on zoom level:

```dart
final config = RenderPipelineConfig(
  lodThreshold: 0.25, // Zoom < 25% triggers LOD
  minObjectScreenSize: 2.0, // Skip objects < 2px
);
```

When zoomed out below threshold:
- Objects smaller than `minObjectScreenSize` are skipped
- Bezier tessellation quality is reduced
- Stroke details are omitted

### 4. GPU Caching (Future: I3)

Complex object groups are rasterized and cached:

```dart
final config = RenderPipelineConfig(
  enableGPUCaching: true, // Future implementation
);
```

## Performance Monitoring

### Performance Overlay

Toggle the performance overlay with **Cmd+Shift+P** (macOS) or **Ctrl+Shift+P** (Windows/Linux).

The overlay displays:

| Metric | Description |
|--------|-------------|
| **FPS** | Frames per second (color-coded: green >50, yellow >30, red <30) |
| **Frame Time** | Milliseconds per frame (green <16ms, yellow <33ms, red >33ms) |
| **Objects Rendered** | Number of objects actually drawn |
| **Objects Culled** | Number of objects skipped (viewport/LOD) |
| **Cache Size** | Number of cached path objects |
| **Zoom** | Current viewport zoom percentage |
| **Pan** | Current viewport pan offset |

### Programmatic Metrics

Access metrics from the render pipeline:

```dart
final metrics = pipeline.lastMetrics;
print('FPS: ${metrics.fps.toStringAsFixed(1)}');
print('Frame time: ${metrics.frameTimeMs}ms');
print('Rendered: ${metrics.objectsRendered}');
print('Culled: ${metrics.objectsCulled}');
```

## Gradient Support (Future: I3+)

Gradients are currently placeholders. Future implementation:

```dart
// Linear gradient (TODO: I3)
final gradient = LinearGradientStyle(
  colors: [Colors.red, Colors.blue],
  stops: [0.0, 1.0],
);

final style = PaintStyle.fill(gradient: gradient);
```

## Testing

Comprehensive test coverage in `test/widget/render_pipeline_test.dart`:

- PaintStyle creation and conversion
- RenderPipeline configuration
- Path/shape rendering
- Metrics collection
- Cache invalidation
- Style variations (stroke, fill, stroke-and-fill)

Run tests:

```bash
flutter test test/widget/render_pipeline_test.dart
```

## Parity with Design Tools

The rendering pipeline is designed to achieve parity with industry-standard vector design tools:

| Feature | Status | Notes |
|---------|--------|-------|
| **Stroke rendering** | ✅ Implemented | Cap/join styles, width scaling |
| **Fill rendering** | ✅ Implemented | Solid colors with opacity |
| **Stroke + Fill** | ✅ Implemented | Both applied in correct order |
| **Linear gradients** | ⏳ Placeholder | API defined, implementation pending |
| **Radial gradients** | ⏳ Placeholder | API defined, implementation pending |
| **Pattern fills** | ❌ Future | Post-I3 enhancement |
| **Shadow effects** | ❌ Future | Post-I3 enhancement |
| **Blend modes** | ❌ Future | Post-I3 enhancement |

## Best Practices

1. **Enable Caching**: Always keep `enablePathCaching: true` for production
2. **Monitor Performance**: Use overlay during development to identify bottlenecks
3. **Invalidate Sparingly**: Only call `invalidateObject()` when geometry actually changes
4. **Use Viewport Culling**: Enable for large documents (>100 objects)
5. **Test at Scale**: Verify performance with realistic document sizes

## Troubleshooting

### Poor Performance

1. Check performance overlay metrics (Cmd/Ctrl+Shift+P)
2. Verify caching is enabled
3. Enable viewport culling for large documents
4. Check for excessive invalidation (cache size dropping)

### Visual Artifacts

1. Disable caching temporarily to isolate issue
2. Check zoom invalidation threshold
3. Verify viewport transform calculations

### Missing Features

- **Gradients**: Currently placeholders; use solid colors
- **Effects**: Not yet implemented; use Flutter's Paint properties where possible

## Future Enhancements (Post-I2)

- **I3**: Viewport culling, LOD, GPU caching
- **I4**: Gradient rendering (linear, radial)
- **I5**: Pattern fills, texture mapping
- **I6**: Advanced effects (shadows, glows, blend modes)

## References

- Architecture: `.codemachine/artifacts/architecture/02_Architecture_Overview.md`
- Performance Spec: `.codemachine/artifacts/architecture/05_Operational_Architecture.md`
- Task Spec: `.codemachine/artifacts/plan/02_Iteration_I2.md` (Task I2.T6)
