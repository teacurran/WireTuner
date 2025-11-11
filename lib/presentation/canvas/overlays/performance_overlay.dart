import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wiretuner/presentation/canvas/render_pipeline.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';

/// Performance profiling overlay for the canvas.
///
/// This overlay displays real-time performance metrics including:
/// - FPS (frames per second)
/// - Frame time in milliseconds
/// - Number of objects rendered vs. culled
/// - Cache statistics
/// - Viewport state (zoom, pan)
///
/// ## Keyboard Control
///
/// Toggle the overlay with the keyboard shortcut:
/// - **Cmd+Shift+P** (macOS)
/// - **Ctrl+Shift+P** (Windows/Linux)
///
/// ## Design Rationale
///
/// The performance overlay helps developers and designers:
/// - Identify rendering bottlenecks
/// - Verify optimization effectiveness
/// - Monitor real-time performance during interaction
/// - Debug viewport transformation issues
///
/// ## Usage
///
/// Wrap the canvas widget with PerformanceOverlay:
///
/// ```dart
/// PerformanceOverlay(
///   enabled: true,
///   metrics: renderPipeline.lastMetrics,
///   viewportController: viewportController,
///   child: WireTunerCanvas(...),
/// )
/// ```
///
/// Or use the stateful wrapper with keyboard toggle:
///
/// ```dart
/// PerformanceOverlayWrapper(
///   metrics: renderPipeline.lastMetrics,
///   viewportController: viewportController,
///   child: WireTunerCanvas(...),
/// )
/// ```
class PerformanceOverlay extends StatelessWidget {
  const PerformanceOverlay({
    required this.child,
    required this.enabled,
    this.metrics,
    this.viewportController,
    super.key,
  });

  /// The child widget to overlay (typically the canvas).
  final Widget child;

  /// Whether the overlay is visible.
  final bool enabled;

  /// Current render metrics to display.
  final RenderMetrics? metrics;

  /// Viewport controller for displaying viewport state.
  final ViewportController? viewportController;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }

    return Stack(
      children: [
        child,
        Positioned(
          top: 16,
          right: 16,
          child: _PerformancePanel(
            metrics: metrics,
            viewportController: viewportController,
          ),
        ),
      ],
    );
  }
}

/// Stateful wrapper for PerformanceOverlay with keyboard toggle.
///
/// This widget manages the overlay visibility state and responds to
/// keyboard shortcuts (Cmd/Ctrl+Shift+P).
class PerformanceOverlayWrapper extends StatefulWidget {
  const PerformanceOverlayWrapper({
    required this.child,
    this.metrics,
    this.viewportController,
    this.initiallyEnabled = false,
    super.key,
  });

  final Widget child;
  final RenderMetrics? metrics;
  final ViewportController? viewportController;
  final bool initiallyEnabled;

  @override
  State<PerformanceOverlayWrapper> createState() =>
      _PerformanceOverlayWrapperState();
}

class _PerformanceOverlayWrapperState extends State<PerformanceOverlayWrapper> {
  late bool _enabled;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _enabled = widget.initiallyEnabled;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _toggleOverlay() {
    setState(() {
      _enabled = !_enabled;
    });
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
      child: PerformanceOverlay(
        enabled: _enabled,
        metrics: widget.metrics,
        viewportController: widget.viewportController,
        child: widget.child,
      ),
    );
  }
}

/// The visual panel displaying performance metrics.
class _PerformancePanel extends StatelessWidget {
  const _PerformancePanel({
    this.metrics,
    this.viewportController,
  });

  final RenderMetrics? metrics;
  final ViewportController? viewportController;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: Colors.white,
          height: 1.4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            const Text(
              'Performance Monitor',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 8),

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
    if (frameTimeMs < 16) return Colors.green; // 60 FPS
    if (frameTimeMs < 33) return Colors.yellow; // 30 FPS
    return Colors.red; // < 30 FPS
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
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color ?? Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
