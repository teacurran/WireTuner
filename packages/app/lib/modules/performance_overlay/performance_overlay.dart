/// Enhanced performance overlay with telemetry integration.
///
/// This module provides a draggable/dockable performance overlay that displays
/// real-time performance metrics including FPS, frame time, snapshot duration,
/// and event replay rate with telemetry opt-out awareness.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wiretuner/infrastructure/telemetry/telemetry_config.dart';
import 'package:wiretuner/presentation/canvas/render_pipeline.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';

import 'overlay_state.dart' as perf_overlay;

/// Performance overlay with draggable/dockable UI.
///
/// This widget wraps a child (typically canvas) and provides an overlay
/// displaying performance metrics with drag-to-dock functionality.
class WireTunerPerformanceOverlay extends StatelessWidget {
  const WireTunerPerformanceOverlay({
    required this.child,
    required this.overlayState,
    required this.onOverlayStateChanged,
    this.metrics,
    this.viewportController,
    this.telemetryConfig,
    super.key,
  });

  /// The child widget to overlay (typically the canvas).
  final Widget child;

  /// Current overlay state (position, visibility, docking).
  final perf_overlay.PerformanceOverlayState overlayState;

  /// Callback when overlay state changes.
  final ValueChanged<perf_overlay.PerformanceOverlayState> onOverlayStateChanged;

  /// Current render metrics to display.
  final RenderMetrics? metrics;

  /// Viewport controller for displaying viewport state.
  final ViewportController? viewportController;

  /// Telemetry configuration for opt-out awareness.
  final TelemetryConfig? telemetryConfig;

  @override
  Widget build(BuildContext context) {
    if (!overlayState.isVisible) {
      return child;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            child,
            _DraggablePerformancePanel(
              overlayState: overlayState,
              onOverlayStateChanged: onOverlayStateChanged,
              canvasSize: constraints.biggest,
              metrics: metrics,
              viewportController: viewportController,
              telemetryConfig: telemetryConfig,
            ),
          ],
        );
      },
    );
  }
}

/// Stateful wrapper for PerformanceOverlay with keyboard toggle.
///
/// This widget manages overlay state and responds to keyboard shortcuts
/// (Cmd/Ctrl+Shift+P) and provides state persistence callbacks.
class PerformanceOverlayWrapper extends StatefulWidget {
  const PerformanceOverlayWrapper({
    required this.child,
    required this.initialState,
    required this.onStateChanged,
    this.metrics,
    this.viewportController,
    this.telemetryConfig,
    super.key,
  });

  final Widget child;
  final perf_overlay.PerformanceOverlayState initialState;
  final ValueChanged<perf_overlay.PerformanceOverlayState> onStateChanged;
  final RenderMetrics? metrics;
  final ViewportController? viewportController;
  final TelemetryConfig? telemetryConfig;

  @override
  State<PerformanceOverlayWrapper> createState() =>
      _PerformanceOverlayWrapperState();
}

class _PerformanceOverlayWrapperState extends State<PerformanceOverlayWrapper> {
  late perf_overlay.PerformanceOverlayState _overlayState;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _overlayState = widget.initialState;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _updateOverlayState(perf_overlay.PerformanceOverlayState newState) {
    setState(() {
      _overlayState = newState;
    });
    widget.onStateChanged(newState);
  }

  void _toggleOverlay() {
    _updateOverlayState(
      _overlayState.copyWith(isVisible: !_overlayState.isVisible),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          // Check for Cmd+Shift+P (macOS) or Ctrl+Shift+P (Windows/Linux)
          final isModifierPressed = event.logicalKey == LogicalKeyboardKey.keyP;
          final hasShift = HardwareKeyboard.instance.isShiftPressed;
          final hasControl = HardwareKeyboard.instance.isControlPressed ||
              HardwareKeyboard.instance.isMetaPressed;

          if (isModifierPressed && hasShift && hasControl) {
            _toggleOverlay();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: WireTunerPerformanceOverlay(
        overlayState: _overlayState,
        onOverlayStateChanged: _updateOverlayState,
        metrics: widget.metrics,
        viewportController: widget.viewportController,
        telemetryConfig: widget.telemetryConfig,
        child: widget.child,
      ),
    );
  }
}

/// Draggable performance panel with docking zones.
class _DraggablePerformancePanel extends StatefulWidget {
  const _DraggablePerformancePanel({
    required this.overlayState,
    required this.onOverlayStateChanged,
    required this.canvasSize,
    this.metrics,
    this.viewportController,
    this.telemetryConfig,
  });

  final perf_overlay.PerformanceOverlayState overlayState;
  final ValueChanged<perf_overlay.PerformanceOverlayState> onOverlayStateChanged;
  final Size canvasSize;
  final RenderMetrics? metrics;
  final ViewportController? viewportController;
  final TelemetryConfig? telemetryConfig;

  @override
  State<_DraggablePerformancePanel> createState() =>
      _DraggablePerformancePanelState();
}

class _DraggablePerformancePanelState
    extends State<_DraggablePerformancePanel> {
  final GlobalKey _panelKey = GlobalKey();
  perf_overlay.DockLocation? _hoveredDockZone;
  Offset? _dragStartPosition;

  @override
  Widget build(BuildContext context) {
    final overlaySize = _getPanelSize();
    final position =
        widget.overlayState.calculatePosition(widget.canvasSize, overlaySize);

    return Stack(
      children: [
        // Dock zone indicators (visible during drag)
        if (_dragStartPosition != null) ..._buildDockZoneIndicators(),

        // Performance panel
        Positioned(
          left: position.dx,
          top: position.dy,
          child: GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: _PerformancePanel(
              key: _panelKey,
              metrics: widget.metrics,
              viewportController: widget.viewportController,
              telemetryConfig: widget.telemetryConfig,
              isDragging: _dragStartPosition != null,
            ),
          ),
        ),
      ],
    );
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _dragStartPosition = details.globalPosition;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final overlaySize = _getPanelSize();
    final newPosition = Offset(
      widget.overlayState.position.dx + details.delta.dx,
      widget.overlayState.position.dy + details.delta.dy,
    );

    // Detect dock zones
    final hoveredZone = _detectDockZone(details.globalPosition, overlaySize);

    setState(() {
      _hoveredDockZone = hoveredZone;
    });

    // Update floating position
    widget.onOverlayStateChanged(
      widget.overlayState.copyWith(
        position: newPosition,
        dockLocation: perf_overlay.DockLocation.floating,
      ),
    );
  }

  void _onPanEnd(DragEndDetails details) {
    perf_overlay.DockLocation finalDockLocation = perf_overlay.DockLocation.floating;

    // Snap to dock zone if hovering
    if (_hoveredDockZone != null) {
      finalDockLocation = _hoveredDockZone!;
    }

    setState(() {
      _dragStartPosition = null;
      _hoveredDockZone = null;
    });

    widget.onOverlayStateChanged(
      widget.overlayState.copyWith(dockLocation: finalDockLocation),
    );
  }

  /// Detects which dock zone the cursor is in.
  perf_overlay.DockLocation? _detectDockZone(Offset globalPosition, Size overlaySize) {
    const dockZoneSize = 80.0;

    // Top-left zone
    if (globalPosition.dx < dockZoneSize &&
        globalPosition.dy < dockZoneSize) {
      return perf_overlay.DockLocation.topLeft;
    }

    // Top-right zone
    if (globalPosition.dx > widget.canvasSize.width - dockZoneSize &&
        globalPosition.dy < dockZoneSize) {
      return perf_overlay.DockLocation.topRight;
    }

    // Bottom-left zone
    if (globalPosition.dx < dockZoneSize &&
        globalPosition.dy > widget.canvasSize.height - dockZoneSize) {
      return perf_overlay.DockLocation.bottomLeft;
    }

    // Bottom-right zone
    if (globalPosition.dx > widget.canvasSize.width - dockZoneSize &&
        globalPosition.dy > widget.canvasSize.height - dockZoneSize) {
      return perf_overlay.DockLocation.bottomRight;
    }

    return null;
  }

  /// Builds dock zone visual indicators.
  List<Widget> _buildDockZoneIndicators() {
    const dockZoneSize = 80.0;
    final zones = [
      (perf_overlay.DockLocation.topLeft, Alignment.topLeft),
      (perf_overlay.DockLocation.topRight, Alignment.topRight),
      (perf_overlay.DockLocation.bottomLeft, Alignment.bottomLeft),
      (perf_overlay.DockLocation.bottomRight, Alignment.bottomRight),
    ];

    return zones.map((zoneData) {
      final location = zoneData.$1;
      final alignment = zoneData.$2;
      final isHovered = _hoveredDockZone == location;

      return Align(
        alignment: alignment,
        child: Container(
          width: dockZoneSize,
          height: dockZoneSize,
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isHovered
                ? Colors.blue.withOpacity(0.3)
                : Colors.white.withOpacity(0.1),
            border: Border.all(
              color: isHovered ? Colors.blue : Colors.white.withOpacity(0.3),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }).toList();
  }

  /// Gets the panel size from GlobalKey.
  Size _getPanelSize() {
    final renderBox =
        _panelKey.currentContext?.findRenderObject() as RenderBox?;
    return renderBox?.size ?? const Size(280, 400);
  }
}

/// The visual panel displaying performance metrics.
class _PerformancePanel extends StatelessWidget {
  const _PerformancePanel({
    super.key,
    this.metrics,
    this.viewportController,
    this.telemetryConfig,
    this.isDragging = false,
  });

  final RenderMetrics? metrics;
  final ViewportController? viewportController;
  final TelemetryConfig? telemetryConfig;
  final bool isDragging;

  @override
  Widget build(BuildContext context) {
    final telemetryEnabled = telemetryConfig?.enabled ?? false;

    return Container(
      width: 280,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(isDragging ? 0.85 : 0.75),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDragging
              ? Colors.blue.withOpacity(0.5)
              : Colors.white.withOpacity(0.2),
          width: isDragging ? 2 : 1,
        ),
        boxShadow: isDragging
            ? [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          fontFamily: 'IBM Plex Mono',
          fontSize: 12,
          color: Colors.white,
          height: 1.4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle + Title
            Row(
              children: [
                Icon(
                  Icons.drag_indicator,
                  color: Colors.white.withOpacity(0.5),
                  size: 16,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Performance Monitor',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 8),

            // Telemetry status badge
            if (!telemetryEnabled)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red.withOpacity(0.5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.block, color: Colors.red, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Telemetry Disabled',
                      style: TextStyle(color: Colors.red, fontSize: 11),
                    ),
                  ],
                ),
              ),

            // Render metrics
            if (metrics != null) ...[
              _MetricRow(
                label: 'FPS',
                value: metrics!.fps.toStringAsFixed(1),
                color: _getFPSColor(metrics!.fps),
              ),
              _MetricRow(
                label: 'Frame Time',
                value: '${metrics!.frameTimeMs.toStringAsFixed(2)}ms',
                color: _getFrameTimeColor(metrics!.frameTimeMs),
              ),
              _MetricRow(
                label: 'Objects Rendered',
                value: metrics!.objectsRendered.toString(),
              ),
              _MetricRow(
                label: 'Objects Culled',
                value: metrics!.objectsCulled.toString(),
                color: Colors.grey,
              ),
              _MetricRow(
                label: 'Cache Size',
                value: metrics!.cacheSize.toString(),
              ),
              const SizedBox(height: 4),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 8),

              // Snapshot metrics
              _MetricRow(
                label: 'Snapshot Duration',
                value: metrics!.snapshotDurationMs != null
                    ? '${metrics!.snapshotDurationMs!.toStringAsFixed(2)}ms'
                    : 'N/A',
                color: _getSnapshotDurationColor(metrics!.snapshotDurationMs),
              ),

              // Replay metrics
              _MetricRow(
                label: 'Event Replay Rate',
                value: metrics!.replayRateEventsPerSec != null
                    ? '${metrics!.replayRateEventsPerSec!.toStringAsFixed(0)} events/s'
                    : 'N/A',
                color: _getReplayRateColor(metrics!.replayRateEventsPerSec),
              ),
              const SizedBox(height: 4),
            ] else ...[
              const Text('No metrics available',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 4),
            ],

            // Viewport state
            if (viewportController != null) ...[
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 8),
              _MetricRow(
                label: 'Zoom',
                value:
                    '${(viewportController!.zoomLevel * 100).toStringAsFixed(0)}%',
              ),
              _MetricRow(
                label: 'Pan',
                value:
                    '(${viewportController!.panOffset.dx.toStringAsFixed(0)}, '
                    '${viewportController!.panOffset.dy.toStringAsFixed(0)})',
              ),
            ],

            // Help text
            const SizedBox(height: 8),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 8),
            Text(
              'Toggle: ${_getModifierKey()}+Shift+P',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 10,
              ),
            ),
            const Text(
              'Drag to reposition or dock',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Returns the appropriate modifier key label for the platform.
  String _getModifierKey() {
    if (ui.PlatformDispatcher.instance.defaultRouteName.contains('macos')) {
      return 'Cmd';
    }
    return 'Ctrl';
  }

  /// Returns color based on FPS (green > 50, yellow > 30, red < 30).
  Color _getFPSColor(double fps) {
    if (fps >= 50) return Colors.green;
    if (fps >= 30) return Colors.yellow;
    return Colors.red;
  }

  /// Returns color based on frame time (green < 16ms, yellow < 33ms, red > 33ms).
  Color _getFrameTimeColor(double frameTimeMs) {
    if (frameTimeMs <= 16) return Colors.green; // 60 FPS
    if (frameTimeMs <= 33) return Colors.yellow; // 30 FPS
    return Colors.red; // < 30 FPS
  }

  /// Returns color based on snapshot duration (green ≤500ms, amber >500ms, red >1000ms).
  Color? _getSnapshotDurationColor(double? durationMs) {
    if (durationMs == null) return null;
    if (durationMs <= 500) return Colors.green;
    if (durationMs <= 1000) return Colors.amber;
    return Colors.red;
  }

  /// Returns color based on replay rate (green ≥5000, yellow ≥4000, red <4000).
  Color? _getReplayRateColor(double? eventsPerSec) {
    if (eventsPerSec == null) return null;
    if (eventsPerSec >= 5000) return Colors.green;
    if (eventsPerSec >= 4000) return Colors.yellow;
    return Colors.red;
  }
}

/// A single metric row in the performance panel.
class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: color ?? Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
