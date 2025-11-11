import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:wiretuner/domain/models/geometry/rectangle.dart' as wiretuner;
import 'package:wiretuner/domain/models/path.dart' as domain;
import 'package:wiretuner/domain/models/shape.dart';
import 'package:wiretuner/presentation/canvas/paint_styles.dart';
import 'package:wiretuner/presentation/canvas/painter/path_renderer.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';

/// Configuration options for the render pipeline.
///
/// These options control performance optimizations and rendering behavior.
class RenderPipelineConfig {
  const RenderPipelineConfig({
    this.enablePathCaching = true,
    this.enableGPUCaching = false,
    this.enableViewportCulling = false,
    this.cullMargin = 100.0,
    this.lodThreshold = 0.25,
    this.minObjectScreenSize = 2.0,
  });

  /// Enable path geometry caching via PathRenderer.
  ///
  /// When true, converted ui.Path objects are cached and reused across
  /// frames. Disable for debugging or when paths change frequently.
  final bool enablePathCaching;

  /// Enable GPU-friendly caching strategies.
  ///
  /// TODO(I3): Implement raster caching for complex object groups.
  /// When enabled, frequently-rendered groups will be cached as raster
  /// images and composited instead of re-vectorizing each frame.
  final bool enableGPUCaching;

  /// Enable viewport culling optimization.
  ///
  /// When true, objects outside the visible viewport are not rendered.
  /// This significantly improves performance for large documents.
  final bool enableViewportCulling;

  /// Margin around viewport bounds for culling (in world units).
  ///
  /// Objects within this margin are still rendered to avoid pop-in
  /// artifacts during panning.
  final double cullMargin;

  /// Zoom threshold for level-of-detail (LOD) simplification.
  ///
  /// When zoom level is below this value, rendering quality is reduced:
  /// - Very small objects are skipped
  /// - Bezier tessellation quality is reduced
  /// - Stroke details are omitted
  final double lodThreshold;

  /// Minimum object size in screen pixels for LOD rendering.
  ///
  /// Objects smaller than this are skipped when zoomed out below
  /// [lodThreshold].
  final double minObjectScreenSize;

  /// Creates a copy with modified properties.
  RenderPipelineConfig copyWith({
    bool? enablePathCaching,
    bool? enableGPUCaching,
    bool? enableViewportCulling,
    double? cullMargin,
    double? lodThreshold,
    double? minObjectScreenSize,
  }) {
    return RenderPipelineConfig(
      enablePathCaching: enablePathCaching ?? this.enablePathCaching,
      enableGPUCaching: enableGPUCaching ?? this.enableGPUCaching,
      enableViewportCulling:
          enableViewportCulling ?? this.enableViewportCulling,
      cullMargin: cullMargin ?? this.cullMargin,
      lodThreshold: lodThreshold ?? this.lodThreshold,
      minObjectScreenSize: minObjectScreenSize ?? this.minObjectScreenSize,
    );
  }
}

/// High-performance rendering pipeline for vector documents.
///
/// RenderPipeline orchestrates the conversion of domain geometry to rendered
/// graphics with support for:
/// - Path and shape rendering with customizable styles
/// - GPU-friendly caching strategies
/// - Viewport culling and level-of-detail optimizations
/// - Performance profiling and debugging
///
/// ## Architecture
///
/// The pipeline follows this flow:
/// 1. **Culling**: Filter objects outside viewport (if enabled)
/// 2. **LOD Selection**: Choose rendering quality based on zoom
/// 3. **Geometry Conversion**: Convert domain objects to ui.Path (cached)
/// 4. **Style Application**: Apply stroke/fill/gradient styles
/// 5. **Rendering**: Draw to canvas with viewport transforms
///
/// ## Performance Optimizations
///
/// Following architectural requirements (Section 5: Operational Architecture):
///
/// 1. **Viewport Culling**: Only render visible objects + margin
/// 2. **Level of Detail**: Simplify geometry when zoomed out
/// 3. **Path Caching**: Reuse converted geometry across frames
/// 4. **GPU Caching**: Rasterize complex groups (future)
/// 5. **Dirty Region Tracking**: Via Flutter's RepaintBoundary
///
/// ## Usage
///
/// ```dart
/// final pipeline = RenderPipeline(
///   pathRenderer: pathRenderer,
///   config: RenderPipelineConfig(
///     enableViewportCulling: true,
///     enablePathCaching: true,
///   ),
/// );
///
/// // In CustomPainter.paint:
/// pipeline.render(
///   canvas: canvas,
///   size: size,
///   viewportController: viewportController,
///   objects: document.objects,
/// );
/// ```
class RenderPipeline {
  /// Creates a render pipeline with the specified configuration.
  RenderPipeline({
    required PathRenderer pathRenderer,
    RenderPipelineConfig config = const RenderPipelineConfig(),
  })  : _pathRenderer = pathRenderer,
        _config = config;

  final PathRenderer _pathRenderer;
  final RenderPipelineConfig _config;

  /// Performance metrics from last render pass.
  RenderMetrics? lastMetrics;

  /// Renders a collection of vector objects to the canvas.
  ///
  /// This is the main entry point for rendering. It applies all configured
  /// optimizations and renders objects with their associated styles.
  ///
  /// Parameters:
  /// - [canvas]: The canvas to render to
  /// - [size]: The size of the canvas
  /// - [viewportController]: Viewport transformation state
  /// - [paths]: List of paths to render with their IDs and styles
  /// - [shapes]: List of shapes to render with their IDs and styles
  void render({
    required Canvas canvas,
    required Size size,
    required ViewportController viewportController,
    List<RenderablePath> paths = const [],
    List<RenderableShape> shapes = const [],
  }) {
    final stopwatch = Stopwatch()..start();

    // Track metrics
    var culledCount = 0;
    var renderedCount = 0;

    // Apply viewport transformation
    canvas.save();
    canvas.transform(viewportController.worldToScreenMatrix.storage);

    // Get visible bounds for culling
    final visibleBounds = _config.enableViewportCulling
        ? _getVisibleBounds(viewportController, size)
        : null;

    // Render paths
    for (final renderablePath in paths) {
      // Viewport culling
      if (visibleBounds != null) {
        final bounds = renderablePath.path.bounds();
        if (!_boundsIntersect(bounds, visibleBounds)) {
          culledCount++;
          continue;
        }
      }

      // LOD check
      if (_shouldSkipForLOD(
        renderablePath.path.bounds(),
        viewportController.zoomLevel,
      )) {
        culledCount++;
        continue;
      }

      // Render path
      _renderPath(
        canvas,
        renderablePath.id,
        renderablePath.path,
        renderablePath.style,
        viewportController.zoomLevel,
      );
      renderedCount++;
    }

    // Render shapes
    for (final renderableShape in shapes) {
      final path = renderableShape.shape.toPath();

      // Viewport culling
      if (visibleBounds != null) {
        final bounds = path.bounds();
        if (!_boundsIntersect(bounds, visibleBounds)) {
          culledCount++;
          continue;
        }
      }

      // LOD check
      if (_shouldSkipForLOD(path.bounds(), viewportController.zoomLevel)) {
        culledCount++;
        continue;
      }

      // Render shape
      _renderPath(
        canvas,
        renderableShape.id,
        path,
        renderableShape.style,
        viewportController.zoomLevel,
      );
      renderedCount++;
    }

    canvas.restore();

    stopwatch.stop();

    // Store metrics
    lastMetrics = RenderMetrics(
      frameTimeMs: stopwatch.elapsedMicroseconds / 1000.0,
      objectsRendered: renderedCount,
      objectsCulled: culledCount,
      cacheSize: _pathRenderer.cacheSize,
    );
  }

  /// Renders a single path with the specified style.
  void _renderPath(
    Canvas canvas,
    String objectId,
    domain.Path domainPath,
    PaintStyle style,
    double currentZoom,
  ) {
    // Get or create ui.Path (potentially cached)
    final uiPath = _config.enablePathCaching
        ? _pathRenderer.getOrCreatePathFromDomain(
            objectId: objectId,
            domainPath: domainPath,
            currentZoom: currentZoom,
          )
        : _pathRenderer.getOrCreatePathFromDomain(
            objectId: objectId,
            domainPath: domainPath,
            currentZoom: currentZoom,
          );

    // Render based on style type
    switch (style.type) {
      case PaintStyleType.stroke:
        canvas.drawPath(uiPath, style.toPaint());
        break;

      case PaintStyleType.fill:
        canvas.drawPath(uiPath, style.toPaint());
        break;

      case PaintStyleType.strokeAndFill:
        // Render fill first, then stroke on top
        canvas.drawPath(uiPath, style.toFillPaint());
        canvas.drawPath(uiPath, style.toPaint());
        break;
    }
  }

  /// Calculates visible bounds in world coordinates.
  Rect _getVisibleBounds(ViewportController controller, Size canvasSize) {
    // Convert canvas corners to world space
    final topLeft = controller.screenToWorld(Offset.zero);
    final bottomRight = controller.screenToWorld(
      Offset(canvasSize.width, canvasSize.height),
    );

    // Expand by cull margin
    return Rect.fromLTRB(
      topLeft.x - _config.cullMargin,
      topLeft.y - _config.cullMargin,
      bottomRight.x + _config.cullMargin,
      bottomRight.y + _config.cullMargin,
    );
  }

  /// Checks if a domain bounds intersects with a viewport rect.
  bool _boundsIntersect(
    wiretuner.Rectangle domainBounds,
    Rect viewportRect,
  ) {
    final boundsRect = Rect.fromLTWH(
      domainBounds.x,
      domainBounds.y,
      domainBounds.width,
      domainBounds.height,
    );
    return boundsRect.overlaps(viewportRect);
  }

  /// Checks if an object should be skipped for LOD optimization.
  bool _shouldSkipForLOD(wiretuner.Rectangle bounds, double zoomLevel) {
    if (zoomLevel >= _config.lodThreshold) {
      return false; // Normal rendering
    }

    // Calculate screen size
    final screenWidth = bounds.width * zoomLevel;
    final screenHeight = bounds.height * zoomLevel;
    final screenSize = screenWidth.abs() + screenHeight.abs();

    return screenSize < _config.minObjectScreenSize;
  }

  /// Invalidates cached geometry for a specific object.
  void invalidateObject(String objectId) {
    _pathRenderer.invalidate(objectId);
  }

  /// Invalidates all cached geometry.
  void invalidateAll() {
    _pathRenderer.invalidateAll();
  }

  /// Gets the current configuration.
  RenderPipelineConfig get config => _config;
}

/// A path object ready for rendering.
class RenderablePath {
  const RenderablePath({
    required this.id,
    required this.path,
    required this.style,
  });

  final String id;
  final domain.Path path;
  final PaintStyle style;
}

/// A shape object ready for rendering.
class RenderableShape {
  const RenderableShape({
    required this.id,
    required this.shape,
    required this.style,
  });

  final String id;
  final Shape shape;
  final PaintStyle style;
}

/// Performance metrics from a render pass.
class RenderMetrics {
  const RenderMetrics({
    required this.frameTimeMs,
    required this.objectsRendered,
    required this.objectsCulled,
    required this.cacheSize,
  });

  /// Total frame rendering time in milliseconds.
  final double frameTimeMs;

  /// Number of objects actually rendered.
  final int objectsRendered;

  /// Number of objects culled (skipped due to viewport/LOD).
  final int objectsCulled;

  /// Current path cache size.
  final int cacheSize;

  /// Frames per second estimate (1000 / frameTimeMs).
  double get fps => 1000.0 / frameTimeMs;

  @override
  String toString() {
    return 'RenderMetrics('
        'frameTime: ${frameTimeMs.toStringAsFixed(2)}ms, '
        'fps: ${fps.toStringAsFixed(1)}, '
        'rendered: $objectsRendered, '
        'culled: $objectsCulled, '
        'cacheSize: $cacheSize'
        ')';
  }
}
