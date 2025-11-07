import 'package:flutter/material.dart';
import 'package:wiretuner/domain/document/document.dart' as domain;
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_state.dart';

/// Binds viewport gesture handling to the widget tree.
///
/// ViewportBinding provides a declarative way to integrate viewport
/// transformations with Flutter's gesture system. It:
///
/// - Creates and manages ViewportState lifecycle
/// - Wraps children with gesture detectors
/// - Provides viewport state via InheritedWidget pattern
/// - Handles canvas sizing and coordinate conversion
///
/// ## Usage
///
/// ```dart
/// ViewportBinding(
///   controller: viewportController,
///   onViewportChanged: (viewport) {
///     // Update document
///     setState(() {
///       document = document.copyWith(viewport: viewport);
///     });
///   },
///   child: CustomPaint(
///     painter: DocumentPainter(
///       paths: paths,
///       viewportController: viewportController,
///     ),
///   ),
/// )
/// ```
///
/// ## Gesture Handling
///
/// The binding sets up:
/// - Pan gestures for dragging the canvas
/// - Scale gestures for pinch-to-zoom (on touch devices)
/// - Scroll wheel for zoom (on desktop)
///
/// All gestures are routed through ViewportState for consistent
/// coordinate handling and telemetry.
class ViewportBinding extends StatefulWidget {
  /// The viewport controller managing transformations.
  final ViewportController controller;

  /// Callback invoked when viewport state changes.
  ///
  /// Should update the document model with the new viewport.
  final ValueChanged<domain.Viewport>? onViewportChanged;

  /// Callback for telemetry data during interactions.
  ///
  /// Receives performance metrics like FPS and pan deltas.
  final ValueChanged<ViewportTelemetry>? onTelemetry;

  /// Whether to enable debug visualizations.
  ///
  /// When true, shows FPS counter and pan delta overlays.
  final bool debugMode;

  /// The child widget to wrap with gesture handling.
  ///
  /// Typically a CustomPaint with DocumentPainter.
  final Widget child;

  const ViewportBinding({
    super.key,
    required this.controller,
    required this.child,
    this.onViewportChanged,
    this.onTelemetry,
    this.debugMode = false,
  });

  @override
  State<ViewportBinding> createState() => _ViewportBindingState();

  // ignore: public_member_api_docs

  /// Retrieves the ViewportState from the widget tree.
  ///
  /// Returns null if no ViewportBinding is found in the tree.
  /// Use this to access viewport state from descendant widgets.
  static ViewportState? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_InheritedViewportState>()
        ?.state;
  }

  /// Retrieves the ViewportState from the widget tree.
  ///
  /// Throws if no ViewportBinding is found in the tree.
  /// Use this when you know a ViewportBinding must exist.
  static ViewportState of(BuildContext context) {
    final state = maybeOf(context);
    assert(state != null, 'No ViewportBinding found in context');
    return state!;
  }
}

class _ViewportBindingState extends State<ViewportBinding> {
  late ViewportState _state;

  @override
  void initState() {
    super.initState();
    _state = ViewportState(
      controller: widget.controller,
      onViewportChanged: widget.onViewportChanged,
      onTelemetry: _handleTelemetry,
    );
  }

  @override
  void didUpdateWidget(ViewportBinding oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If controller changed, recreate state
    if (widget.controller != oldWidget.controller) {
      _state.dispose();
      _state = ViewportState(
        controller: widget.controller,
        onViewportChanged: widget.onViewportChanged,
        onTelemetry: _handleTelemetry,
      );
    }
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  void _handleTelemetry(ViewportTelemetry telemetry) {
    // Forward to external callback
    widget.onTelemetry?.call(telemetry);

    // Log to debug console if debug mode enabled
    if (widget.debugMode) {
      debugPrint(telemetry.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return _InheritedViewportState(
      state: _state,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Update canvas size when layout changes
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _state.updateCanvasSize(constraints.biggest);
          });

          return Listener(
            // Handle scroll wheel zoom
            onPointerSignal: _state.onPointerSignal,
            child: GestureDetector(
              // Use scale gestures which handle both pan and pinch zoom
              // Note: GestureDetector does not support both onPan* and onScale*
              // simultaneously. Scale is a superset of pan.
              onScaleStart: (details) {
                // Convert ScaleStartDetails to pan-like handling
                _state.onPanStart(DragStartDetails(
                  globalPosition: details.focalPoint,
                ));
              },
              onScaleUpdate: (details) {
                // Handle both pan and zoom through scale gesture
                if (details.scale != 1.0) {
                  // Zoom gesture
                  _state.onScaleUpdate(details);
                } else if (details.focalPointDelta != Offset.zero) {
                  // Pan gesture (scale == 1.0 means no zoom, just pan)
                  _state.onPanUpdate(DragUpdateDetails(
                    globalPosition: details.focalPoint,
                    delta: details.focalPointDelta,
                  ));
                }
              },
              onScaleEnd: (details) {
                // End both pan and zoom
                _state.onPanEnd(DragEndDetails(
                  velocity: details.velocity,
                ));
              },
              // Use eager gesture recognition for responsive pan
              behavior: HitTestBehavior.opaque,
              child: Stack(
                children: [
                  // Main canvas content
                  widget.child,
                  // Debug overlay
                  if (widget.debugMode) _buildDebugOverlay(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Builds debug overlay showing FPS and viewport state.
  Widget _buildDebugOverlay() {
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) {
        return Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'FPS: ${_state.lastFps.toStringAsFixed(1)}',
                  style: TextStyle(
                    color: _getFpsColor(_state.lastFps),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Zoom: ${(widget.controller.zoomLevel * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  'Pan: (${widget.controller.panOffset.dx.toStringAsFixed(0)}, '
                  '${widget.controller.panOffset.dy.toStringAsFixed(0)})',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
                if (_state.isPanning)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'PANNING',
                      style: TextStyle(
                        color: Colors.yellow,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Returns color for FPS display based on performance.
  Color _getFpsColor(double fps) {
    if (fps >= 55) return Colors.green; // Good performance
    if (fps >= 30) return Colors.yellow; // Acceptable
    if (fps > 0) return Colors.red; // Poor performance
    return Colors.white; // No data
  }
}

/// InheritedWidget that provides ViewportState down the widget tree.
class _InheritedViewportState extends InheritedWidget {
  final ViewportState state;

  const _InheritedViewportState({
    required this.state,
    required super.child,
  });

  @override
  bool updateShouldNotify(_InheritedViewportState oldWidget) {
    return state != oldWidget.state;
  }
}
