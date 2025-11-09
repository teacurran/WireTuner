import 'package:flutter/material.dart';
import 'package:wiretuner/domain/document/selection.dart';
import 'package:wiretuner/domain/models/path.dart' as domain;
import 'package:wiretuner/domain/models/shape.dart';
import 'package:wiretuner/infrastructure/telemetry/telemetry_service.dart';
import 'package:wiretuner/presentation/canvas/overlay_layer.dart';
import 'package:wiretuner/presentation/canvas/overlay_registry.dart';
import 'package:wiretuner/presentation/canvas/overlays/performance_overlay.dart';
import 'package:wiretuner/presentation/canvas/overlays/selection_overlay.dart';
import 'package:wiretuner/presentation/canvas/painter/document_painter.dart';
import 'package:wiretuner/presentation/canvas/painter/path_renderer.dart';
import 'package:wiretuner/presentation/canvas/render_pipeline.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_state.dart';

/// Main canvas widget for rendering vector documents with selection overlays.
///
/// WireTunerCanvas is the primary rendering component that orchestrates:
/// - Document rendering via [DocumentPainter]
/// - Overlay rendering via [OverlayLayer] and [OverlayRegistry]
/// - Viewport transformations and gestures via [ViewportController]
/// - Performance telemetry via [TelemetryService]
///
/// ## Architecture (Section 2: Rendering & Graphics)
///
/// The canvas uses a layered rendering architecture with Flutter's CustomPainter:
/// - **Base layer**: Document paths rendered with world-space transformations
/// - **Overlay layer**: Managed overlays in deterministic z-index order
///   - Document-derived (selection, bounds)
///   - Tool-state painters (pen preview, snapping guides)
///   - Widget overlays (tool hints, performance HUD)
/// - **Gesture layer**: Pan/zoom interaction handling
/// - **Telemetry layer**: Performance monitoring (FPS, frame times)
///
/// This structure aligns with the architectural requirements for:
/// - Direct Canvas control via dart:ui for 60 FPS rendering
/// - Matrix4 transformations for viewport pan/zoom
/// - RepaintBoundary optimization for dirty-region tracking
/// - Independent layer repaints (document vs. overlay)
/// - Deterministic overlay stacking with z-index management
///
/// ## Performance Optimizations
///
/// 1. **RepaintBoundary**: Isolates canvas repaints from parent widget tree
/// 2. **Layer Separation**: Document and overlay painters repaint independently
/// 3. **Path Caching**: PathRenderer caches converted geometry
/// 4. **Viewport Culling**: Future support via painter extensibility
/// 5. **Telemetry Monitoring**: Captures frame times for debugging
///
/// ## Gesture Handling
///
/// - **Pan**: Drag with primary pointer to move viewport
/// - **Zoom**: Scroll wheel or pinch gesture to zoom in/out
/// - **Zoom Constraints**: Clamped to [0.05, 8.0] range (5%-800%)
/// - **Focal Point**: Zoom pivots around pointer/gesture center
///
/// ## Usage
///
/// ```dart
/// WireTunerCanvas(
///   paths: document.paths,
///   shapes: document.shapes,
///   selection: document.selection,
///   viewportController: viewportController,
///   telemetryService: telemetryService,
/// )
/// ```
///
/// ## Testing
///
/// Widget tests verify:
/// - Canvas builds without exceptions at 60 FPS
/// - Zoom clamping works correctly
/// - Selection overlay renders handles for mock anchors
/// - Telemetry captures frame time data
///
/// See: test/widget/canvas_smoke_test.dart
class WireTunerCanvas extends StatefulWidget {
  /// Creates a WireTuner canvas widget.
  ///
  /// All parameters are required except [telemetryService], [hoveredAnchor],
  /// and [enableRenderPipeline].
  ///
  /// The [paths] list contains document path objects to render.
  /// The [shapes] map contains shape objects by ID.
  /// The [selection] defines which objects/anchors are currently selected.
  /// The [viewportController] manages pan/zoom transformations.
  /// The [telemetryService] is optional and enables performance monitoring.
  /// The [hoveredAnchor] indicates the currently hovered anchor (if any).
  /// The [enableRenderPipeline] enables advanced rendering optimizations (default: true).
  ///
  /// The performance overlay can be toggled at runtime using Cmd+Shift+P (macOS)
  /// or Ctrl+Shift+P (Windows/Linux).
  const WireTunerCanvas({
    required this.paths,
    required this.shapes,
    required this.selection,
    required this.viewportController,
    this.telemetryService,
    this.hoveredAnchor,
    this.enableRenderPipeline = true,
    super.key,
  });

  /// List of paths to render in the document.
  final List<domain.Path> paths;

  /// Map of shape objects by ID.
  final Map<String, Shape> shapes;

  /// Current selection state.
  final Selection selection;

  /// Viewport controller for pan/zoom transformations.
  final ViewportController viewportController;

  /// Optional telemetry service for performance monitoring.
  final TelemetryService? telemetryService;

  /// Currently hovered anchor point (if any).
  final HoveredAnchor? hoveredAnchor;

  /// Enable advanced render pipeline with optimizations.
  final bool enableRenderPipeline;

  @override
  State<WireTunerCanvas> createState() => _WireTunerCanvasState();
}

class _WireTunerCanvasState extends State<WireTunerCanvas> {
  /// Path renderer for caching converted geometry.
  late final PathRenderer _pathRenderer;

  /// Render pipeline for advanced rendering.
  late final RenderPipeline? _renderPipeline;

  /// Viewport state manager for gesture handling.
  late final ViewportState _viewportState;

  /// Overlay registry for managing overlay z-index and rendering order.
  late final OverlayRegistry _overlayRegistry;

  /// Stopwatch for measuring frame build times.
  final Stopwatch _frameStopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();

    // Initialize path renderer
    _pathRenderer = PathRenderer();

    // Initialize render pipeline if enabled
    _renderPipeline = widget.enableRenderPipeline
        ? RenderPipeline(
            pathRenderer: _pathRenderer,
            config: const RenderPipelineConfig(
              enablePathCaching: true,
              enableViewportCulling: false, // Enable in I3
              enableGPUCaching: false, // Enable in I3
            ),
          )
        : null;

    // Initialize viewport state with telemetry callback
    _viewportState = ViewportState(
      controller: widget.viewportController,
      onTelemetry: _onTelemetry,
    );

    // Initialize overlay registry
    _overlayRegistry = OverlayRegistry();

    // Listen to viewport controller for frame time measurement
    widget.viewportController.addListener(_onViewportChanged);
  }

  @override
  void dispose() {
    widget.viewportController.removeListener(_onViewportChanged);
    _viewportState.dispose();
    super.dispose();
  }

  /// Handles telemetry callback from viewport state.
  void _onTelemetry(ViewportTelemetry telemetry) {
    widget.telemetryService?.recordViewportMetric(telemetry);
  }

  /// Handles viewport changes to measure frame times.
  void _onViewportChanged() {
    // Start measuring frame build time
    _frameStopwatch.reset();
    _frameStopwatch.start();

    // Let setState trigger rebuild, which will stop the stopwatch in build()
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Stop frame build timer if it's running
    if (_frameStopwatch.isRunning) {
      _frameStopwatch.stop();

      // Log frame time if telemetry is enabled
      if (widget.telemetryService != null) {
        final frameTimeMs = _frameStopwatch.elapsedMicroseconds / 1000.0;
        debugPrint(
            '[Canvas] Frame build time: ${frameTimeMs.toStringAsFixed(2)}ms');
      }
    }

    // Convert paths list to map for selection overlay painter
    final pathsMap = <String, domain.Path>{};
    for (var i = 0; i < widget.paths.length; i++) {
      // Generate temporary IDs for mock data
      // In production, paths should have persistent IDs
      pathsMap['path-$i'] = widget.paths[i];
    }

    // Register overlays in the registry with deterministic z-index
    _registerOverlays(pathsMap);

    final canvasWidget = RepaintBoundary(
      child: Listener(
        // Handle scroll events for zoom
        onPointerSignal: _viewportState.onPointerSignal,
        child: GestureDetector(
          // Handle pan gestures for viewport movement
          onPanStart: _viewportState.onPanStart,
          onPanUpdate: _viewportState.onPanUpdate,
          onPanEnd: _viewportState.onPanEnd,
          // Background behavior for gesture detection
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              // Bottom layer: Document content
              CustomPaint(
                painter: DocumentPainter(
                  paths: widget.paths,
                  viewportController: widget.viewportController,
                  strokeWidth: 2.0,
                  strokeColor: Colors.black87,
                  renderPipeline: _renderPipeline,
                ),
                // Fill available space
                size: Size.infinite,
              ),
              // Overlay layer: All overlays in z-index order
              OverlayLayer(registry: _overlayRegistry),
            ],
          ),
        ),
      ),
    );

    // Always wrap with performance overlay wrapper (keyboard toggle available)
    return PerformanceOverlayWrapper(
      metrics: _renderPipeline?.lastMetrics,
      viewportController: widget.viewportController,
      child: canvasWidget,
    );
  }

  /// Registers overlays in the registry based on current widget state.
  ///
  /// This method is called on each build to ensure overlays reflect the
  /// current document and tool state. The registry handles deduplication
  /// via overlay IDs, so re-registering with the same ID updates the entry.
  void _registerOverlays(Map<String, domain.Path> pathsMap) {
    // Register selection overlay (document-derived, z-index 110)
    if (widget.selection.isNotEmpty) {
      _overlayRegistry.register(
        CanvasOverlayEntry.painter(
          id: 'selection',
          zIndex: OverlayZIndex.selection,
          painter: SelectionOverlayPainter(
            selection: widget.selection,
            paths: pathsMap,
            shapes: widget.shapes,
            viewportController: widget.viewportController,
            pathRenderer: _pathRenderer,
            hoveredAnchor: widget.hoveredAnchor,
          ),
          hitTestBehavior: HitTestBehavior.translucent,
        ),
      );
    } else {
      // Unregister if no selection
      _overlayRegistry.unregister('selection');
    }

    // TODO(I3.T8+): Register pen preview overlay when pen tool is active
    // TODO(I3.T8+): Register snapping guide overlay when snapping is enabled
    // TODO(I3.T8+): Register tool hints widget overlay
    // TODO(I3.T8+): Register active tool overlay from ToolManager.renderOverlay
  }
}
