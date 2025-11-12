import 'package:flutter/material.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';

/// A widget that displays the current zoom level and provides zoom controls.
///
/// The ZoomIndicator subscribes to [ViewportController] changes and displays
/// the current zoom level as a percentage. It also provides interactive
/// controls for preset zoom levels and fit-to-screen functionality.
///
/// ## Features
///
/// - Real-time zoom level display (e.g., "100%", "200%", "50%")
/// - Preset zoom levels (25%, 50%, 100%, 200%, 400%)
/// - Fit to screen button
/// - Reset to 100% button
/// - Compact design suitable for status bars
///
/// ## Usage
///
/// ```dart
/// // In status bar
/// Row(
///   children: [
///     ZoomIndicator(
///       controller: viewportController,
///       onFitToScreen: () {
///         // Implement fit to screen logic
///       },
///     ),
///   ],
/// )
/// ```
class ZoomIndicator extends StatelessWidget {
  /// Creates a zoom indicator widget.
  const ZoomIndicator({
    super.key,
    required this.controller,
    this.onFitToScreen,
    this.showPresets = true,
    this.compact = false,
  });

  /// The viewport controller to monitor.
  final ViewportController controller;

  /// Callback for fit-to-screen action.
  ///
  /// If null, the fit-to-screen button is not shown.
  final VoidCallback? onFitToScreen;

  /// Whether to show preset zoom level buttons.
  final bool showPresets;

  /// Whether to use compact layout (icon only, no percentage text).
  final bool compact;

  /// Preset zoom levels available in the dropdown.
  static const List<double> presetZoomLevels = [
    0.25, // 25%
    0.5, // 50%
    1.0, // 100%
    2.0, // 200%
    4.0, // 400%
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final zoomPercent = (controller.zoomLevel * 100).round();

        if (compact) {
          return _buildCompactIndicator(context, zoomPercent);
        } else {
          return _buildFullIndicator(context, zoomPercent);
        }
      },
    );
  }

  /// Builds the compact indicator with just an icon and percentage.
  Widget _buildCompactIndicator(BuildContext context, int zoomPercent) {
    return PopupMenuButton<double>(
      tooltip: 'Zoom level: $zoomPercent%',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.zoom_in,
              size: 16,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
            const SizedBox(width: 6),
            Text(
              '$zoomPercent%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
      itemBuilder: (context) => _buildZoomMenuItems(context),
    );
  }

  /// Builds the full indicator with controls.
  Widget _buildFullIndicator(BuildContext context, int zoomPercent) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodySmall?.color ?? Colors.black;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Zoom out button
          IconButton(
            icon: const Icon(Icons.remove, size: 16),
            iconSize: 16,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'Zoom out',
            onPressed: _canZoomOut ? _zoomOut : null,
          ),

          const SizedBox(width: 4),

          // Zoom percentage with dropdown
          PopupMenuButton<double>(
            tooltip: 'Select zoom level',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: textColor.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$zoomPercent%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 16,
                    color: textColor,
                  ),
                ],
              ),
            ),
            itemBuilder: (context) => _buildZoomMenuItems(context),
          ),

          const SizedBox(width: 4),

          // Zoom in button
          IconButton(
            icon: const Icon(Icons.add, size: 16),
            iconSize: 16,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'Zoom in',
            onPressed: _canZoomIn ? _zoomIn : null,
          ),

          // Fit to screen button (if callback provided)
          if (onFitToScreen != null) ...[
            const SizedBox(width: 4),
            const VerticalDivider(width: 1, thickness: 1),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.fit_screen, size: 16),
              iconSize: 16,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: 'Fit to screen',
              onPressed: onFitToScreen,
            ),
          ],

          // Reset button
          if (controller.zoomLevel != 1.0) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.refresh, size: 16),
              iconSize: 16,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: 'Reset to 100%',
              onPressed: () => controller.setZoom(1.0),
            ),
          ],
        ],
      ),
    );
  }

  /// Builds the zoom level menu items.
  List<PopupMenuEntry<double>> _buildZoomMenuItems(BuildContext context) {
    final items = <PopupMenuEntry<double>>[];

    // Add preset zoom levels
    for (final zoom in presetZoomLevels) {
      final percent = (zoom * 100).round();
      final isCurrent = (controller.zoomLevel - zoom).abs() < 0.01;

      items.add(
        PopupMenuItem<double>(
          value: zoom,
          onTap: () => controller.setZoom(zoom),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                child: isCurrent
                    ? const Icon(Icons.check, size: 16)
                    : null,
              ),
              Text('$percent%'),
            ],
          ),
        ),
      );
    }

    // Add divider before fit to screen
    if (onFitToScreen != null) {
      items.add(const PopupMenuDivider());
      items.add(
        PopupMenuItem<double>(
          value: -1, // Special value for fit to screen
          onTap: onFitToScreen,
          child: const Row(
            children: [
              SizedBox(width: 20),
              Icon(Icons.fit_screen, size: 16),
              SizedBox(width: 8),
              Text('Fit to screen'),
            ],
          ),
        ),
      );
    }

    return items;
  }

  /// Whether zoom out is available.
  bool get _canZoomOut => controller.zoomLevel > ViewportController.minZoom;

  /// Whether zoom in is available.
  bool get _canZoomIn => controller.zoomLevel < ViewportController.maxZoom;

  /// Zooms out by 10%.
  void _zoomOut() {
    final newZoom = (controller.zoomLevel * 0.9).clamp(
      ViewportController.minZoom,
      ViewportController.maxZoom,
    );
    controller.setZoom(newZoom);
  }

  /// Zooms in by 10%.
  void _zoomIn() {
    final newZoom = (controller.zoomLevel * 1.1).clamp(
      ViewportController.minZoom,
      ViewportController.maxZoom,
    );
    controller.setZoom(newZoom);
  }
}
