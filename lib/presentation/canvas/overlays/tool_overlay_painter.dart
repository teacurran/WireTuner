import 'package:flutter/material.dart';
import 'package:wiretuner/application/tools/framework/tool_manager.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';

/// Custom painter that delegates to the active tool's renderOverlay method.
///
/// This painter acts as a bridge between the Flutter CustomPaint system and
/// the tool's rendering logic. It calls the active tool's renderOverlay method
/// with the canvas and size, allowing tools to draw their preview overlays
/// (e.g., pen handles, shape previews, etc.).
class ToolOverlayPainter extends CustomPainter {
  /// Creates a tool overlay painter.
  ToolOverlayPainter({
    required this.toolManager,
    required this.viewportController,
  }) : super(repaint: toolManager);

  /// Tool manager that provides the active tool.
  final ToolManager toolManager;

  /// Viewport controller for coordinate transformations.
  final ViewportController viewportController;

  @override
  void paint(Canvas canvas, Size size) {
    // Delegate to the active tool's renderOverlay method
    if (toolManager.activeTool != null) {
      // Apply viewport transformation to convert world coordinates to screen
      canvas.save();
      canvas.transform(viewportController.worldToScreenMatrix.storage);

      toolManager.renderOverlay(canvas, size);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ToolOverlayPainter oldDelegate) {
    // Repaint when tool manager or viewport changes
    return oldDelegate.toolManager != toolManager ||
        oldDelegate.viewportController != viewportController;
  }
}
