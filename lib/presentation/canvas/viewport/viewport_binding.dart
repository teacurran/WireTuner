import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wiretuner/domain/document/document.dart' as domain;
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_state.dart';

// ============================================================================
// Keyboard Intents
// ============================================================================

/// Intent to zoom in on the viewport.
class ZoomInIntent extends Intent {
  /// Creates a zoom in intent.
  const ZoomInIntent();
}

/// Intent to zoom out on the viewport.
class ZoomOutIntent extends Intent {
  /// Creates a zoom out intent.
  const ZoomOutIntent();
}

/// Intent to reset the viewport to default zoom and pan.
class ResetViewportIntent extends Intent {
  /// Creates a reset viewport intent.
  const ResetViewportIntent();
}

/// Intent to activate pan mode (hold space bar).
class ActivatePanModeIntent extends Intent {
  /// Creates an activate pan mode intent.
  const ActivatePanModeIntent();
}

/// Intent to deactivate pan mode (release space bar).
class DeactivatePanModeIntent extends Intent {
  /// Creates a deactivate pan mode intent.
  const DeactivatePanModeIntent();
}

// ============================================================================
// Keyboard Actions
// ============================================================================

/// Action to zoom in on the viewport.
class ZoomInAction extends Action<ZoomInIntent> {
  /// Creates a zoom in action.
  ZoomInAction(this.controller);

  /// The viewport controller to zoom.
  final ViewportController controller;

  /// Zoom factor for keyboard zoom (10% per keystroke).
  static const double zoomFactor = 1.1;

  @override
  void invoke(ZoomInIntent intent) {
    // Get the center of the viewport as focal point
    // Note: We don't have canvas size here, so we zoom around current pan point
    // This is acceptable for keyboard zoom as it provides predictable behavior
    final currentPan = controller.panOffset;
    controller.zoom(zoomFactor, focalPoint: currentPan);
  }
}

/// Action to zoom out on the viewport.
class ZoomOutAction extends Action<ZoomOutIntent> {
  /// Creates a zoom out action.
  ZoomOutAction(this.controller);

  /// The viewport controller to zoom.
  final ViewportController controller;

  /// Zoom factor for keyboard zoom (10% per keystroke).
  static const double zoomFactor = 0.9;

  @override
  void invoke(ZoomOutIntent intent) {
    // Get the center of the viewport as focal point
    final currentPan = controller.panOffset;
    controller.zoom(zoomFactor, focalPoint: currentPan);
  }
}

/// Action to reset the viewport to default state.
class ResetViewportAction extends Action<ResetViewportIntent> {
  /// Creates a reset viewport action.
  ResetViewportAction(this.state);

  /// The viewport state to reset.
  final ViewportState state;

  @override
  void invoke(ResetViewportIntent intent) {
    state.reset();
  }
}

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

  const ViewportBinding({
    super.key,
    required this.controller,
    required this.child,
    this.onViewportChanged,
    this.onTelemetry,
    this.debugMode = false,
  });
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

  @override
  State<ViewportBinding> createState() => _ViewportBindingState();

  // ignore: public_member_api_docs

  /// Retrieves the ViewportState from the widget tree.
  ///
  /// Returns null if no ViewportBinding is found in the tree.
  /// Use this to access viewport state from descendant widgets.
  static ViewportState? maybeOf(BuildContext context) => context
        .dependOnInheritedWidgetOfExactType<_InheritedViewportState>()
        ?.state;

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
  late FocusNode _focusNode;

  /// Whether pan mode is active (space bar held down).
  bool _isPanModeActive = false;

  /// Cursor to display when pan mode is active.
  SystemMouseCursor _panModeCursor = SystemMouseCursors.grab;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
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
    _focusNode.dispose();
    _state.dispose();
    super.dispose();
  }

  /// Activates pan mode when space bar is pressed.
  void _activatePanMode() {
    setState(() {
      _isPanModeActive = true;
      _panModeCursor = SystemMouseCursors.grab;
    });
  }

  /// Deactivates pan mode when space bar is released.
  void _deactivatePanMode() {
    setState(() {
      _isPanModeActive = false;
    });
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
  Widget build(BuildContext context) => _InheritedViewportState(
      state: _state,
      child: RawKeyboardListener(
        focusNode: _focusNode,
        onKey: _handleRawKeyEvent,
        child: Shortcuts(
          shortcuts: <ShortcutActivator, Intent>{
            // Zoom shortcuts
            const SingleActivator(LogicalKeyboardKey.equal, shift: true):
                const ZoomInIntent(), // Shift+= (plus key)
            const SingleActivator(LogicalKeyboardKey.add):
                const ZoomInIntent(), // Numpad +
            const SingleActivator(LogicalKeyboardKey.minus):
                const ZoomOutIntent(), // Minus key
            const SingleActivator(LogicalKeyboardKey.numpadSubtract):
                const ZoomOutIntent(), // Numpad -
            // Reset viewport
            const SingleActivator(LogicalKeyboardKey.digit0, meta: true):
                const ResetViewportIntent(), // Cmd+0 on Mac
            const SingleActivator(LogicalKeyboardKey.digit0, control: true):
                const ResetViewportIntent(), // Ctrl+0 on Windows/Linux
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              ZoomInIntent: ZoomInAction(widget.controller),
              ZoomOutIntent: ZoomOutAction(widget.controller),
              ResetViewportIntent: ResetViewportAction(_state),
            },
            child: Focus(
              focusNode: FocusNode(),
              autofocus: true,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Update canvas size when layout changes
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _state.updateCanvasSize(constraints.biggest);
                  });

                  return MouseRegion(
                    cursor: _isPanModeActive
                        ? _panModeCursor
                        : SystemMouseCursors.basic,
                    child: Listener(
                      // Handle scroll wheel zoom
                      onPointerSignal: _state.onPointerSignal,
                      child: GestureDetector(
                        // Use scale gestures which handle both pan and pinch zoom
                        // Note: GestureDetector does not support both onPan* and onScale*
                        // simultaneously. Scale is a superset of pan.
                        onScaleStart: (details) {
                          // Update cursor when pan mode is active and dragging
                          if (_isPanModeActive) {
                            setState(() {
                              _panModeCursor = SystemMouseCursors.grabbing;
                            });
                          }
                          // Convert ScaleStartDetails to pan-like handling
                          _state.onPanStart(DragStartDetails(
                            globalPosition: details.focalPoint,
                          ),);
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
                            ),);
                          }
                        },
                        onScaleEnd: (details) {
                          // Reset cursor when pan mode is active and drag ends
                          if (_isPanModeActive) {
                            setState(() {
                              _panModeCursor = SystemMouseCursors.grab;
                            });
                          }
                          // End both pan and zoom
                          _state.onPanEnd(DragEndDetails(
                            velocity: details.velocity,
                          ),);
                        },
                        // Use eager gesture recognition for responsive pan
                        behavior: HitTestBehavior.opaque,
                        child: Stack(
                          children: [
                            // Main canvas content
                            widget.child,
                            // Debug overlay
                            if (widget.debugMode) _buildDebugOverlay(),
                            // Pan mode indicator
                            if (_isPanModeActive && widget.debugMode)
                              _buildPanModeIndicator(),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

  /// Handles raw keyboard events for space bar pan mode.
  ///
  /// Space bar press/release is handled via RawKeyboardListener instead of
  /// Shortcuts/Actions because we need to track key down/up state for the
  /// pan mode toggle behavior.
  void _handleRawKeyEvent(RawKeyEvent event) {
    // Only handle space bar for pan mode
    if (event.logicalKey == LogicalKeyboardKey.space) {
      if (event is RawKeyDownEvent && !event.repeat) {
        _activatePanMode();
      } else if (event is RawKeyUpEvent) {
        _deactivatePanMode();
      }
    }
  }

  /// Builds debug overlay showing FPS and viewport state.
  Widget _buildDebugOverlay() => ListenableBuilder(
      listenable: _state,
      builder: (context, _) => Positioned(
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
        ),
    );

  /// Returns color for FPS display based on performance.
  Color _getFpsColor(double fps) {
    if (fps >= 55) return Colors.green; // Good performance
    if (fps >= 30) return Colors.yellow; // Acceptable
    if (fps > 0) return Colors.red; // Poor performance
    return Colors.white; // No data
  }

  /// Builds pan mode indicator shown when space bar is held.
  Widget _buildPanModeIndicator() => Positioned(
        bottom: 8,
        left: 8,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.pan_tool,
                color: Colors.white,
                size: 16,
              ),
              SizedBox(width: 6),
              Text(
                'PAN MODE (Space)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      );
}

/// InheritedWidget that provides ViewportState down the widget tree.
class _InheritedViewportState extends InheritedWidget {

  const _InheritedViewportState({
    required this.state,
    required super.child,
  });
  final ViewportState state;

  @override
  bool updateShouldNotify(_InheritedViewportState oldWidget) => state != oldWidget.state;
}
