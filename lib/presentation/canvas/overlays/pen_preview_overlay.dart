import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';

/// Visual constants for pen tool preview overlay rendering.
class PenPreviewConstants {
  /// Color for handle lines and control points during Bezier creation.
  static const Color handleColor = Color(0xFF2196F3); // Blue

  /// Color for path preview line (rubber-band from last anchor to cursor).
  static const Color previewLineColor = Color(0xFF4CAF50); // Green

  /// Color for anchor point fill.
  static const Color anchorFillColor = Color(0xFFFFFFFF); // White

  /// Color for anchor point stroke.
  static const Color anchorStrokeColor = Color(0xFF000000); // Black

  /// Color for last anchor indicator.
  static const Color lastAnchorColor = Color(0xFF1976D2); // Dark blue

  /// Radius of anchor point circles in screen pixels.
  static const double anchorRadius = 5.0;

  /// Radius of handle control point circles in screen pixels.
  static const double handleRadius = 3.0;

  /// Radius of preview anchor circle in screen pixels.
  static const double previewAnchorRadius = 4.0;

  /// Stroke width for lines in screen pixels.
  static const double strokeWidth = 1.0;
}

/// State data for pen tool preview rendering.
///
/// This class encapsulates all the state needed to render the pen tool's
/// visual preview overlay, including handle positions, hover state, and
/// the current phase of path creation.
class PenPreviewState {
  /// Creates a pen preview state.
  const PenPreviewState({
    this.lastAnchorPosition,
    this.hoverPosition,
    this.dragStartPosition,
    this.currentDragPosition,
    this.isDragging = false,
    this.isAdjustingHandles = false,
    this.isAltPressed = false,
  });

  /// Position of the last anchor placed (world coordinates).
  final Point? lastAnchorPosition;

  /// Current hover position for preview rendering (world coordinates).
  final Point? hoverPosition;

  /// Position where drag started (world coordinates).
  /// Used as anchor position for Bezier curve creation.
  final Point? dragStartPosition;

  /// Current drag position during pointer move (world coordinates).
  /// Used to calculate handle direction and magnitude.
  final Point? currentDragPosition;

  /// Whether the user is currently dragging (after pointer down).
  final bool isDragging;

  /// Whether the user is adjusting handles on the last anchor.
  final bool isAdjustingHandles;

  /// Whether Alt key is pressed (for corner/independent handles).
  final bool isAltPressed;

  /// Creates an empty state (no preview).
  static const PenPreviewState empty = PenPreviewState();
}

/// Custom painter that renders pen tool preview overlay.
///
/// PenPreviewOverlayPainter draws visual feedback during path creation:
/// - Preview line from last anchor to cursor (rubber-band)
/// - Handle preview during Bezier anchor drag gesture
/// - Handle adjustment preview when modifying existing anchor
/// - Anchor point indicators
///
/// ## Design Rationale
///
/// The pen preview overlay is a separate CustomPainter to:
/// - Enable independent repainting (preview changes don't repaint document)
/// - Isolate pen tool UI from document rendering logic
/// - Allow easy testing of preview behavior
///
/// ## Performance
///
/// - Only repaints when pen tool state or viewport changes
/// - Transforms applied once per frame via ViewportController
/// - Uses world coordinates for all positions
///
/// ## Usage
///
/// ```dart
/// CustomPaint(
///   painter: PenPreviewOverlayPainter(
///     state: penPreviewState,
///     viewportController: viewportController,
///   ),
/// )
/// ```
class PenPreviewOverlayPainter extends CustomPainter {
  /// Creates a pen preview overlay painter.
  PenPreviewOverlayPainter({
    required this.state,
    required this.viewportController,
  }) : super(repaint: viewportController);

  /// The current pen tool preview state.
  final PenPreviewState state;

  /// Viewport controller providing transformation state.
  final ViewportController viewportController;

  @override
  void paint(Canvas canvas, ui.Size size) {
    final zoomLevel = viewportController.zoomLevel;

    // If dragging (either creating anchor or adjusting handles), render handle preview
    if (state.isDragging &&
        state.dragStartPosition != null &&
        state.currentDragPosition != null) {
      if (state.isAdjustingHandles) {
        _renderHandleAdjustmentPreview(canvas, zoomLevel);
      } else {
        _renderHandlePreview(canvas, zoomLevel);
      }
    }
    // Otherwise, render normal path preview
    else if (state.hoverPosition != null && state.lastAnchorPosition != null) {
      _renderPathPreview(canvas, zoomLevel);
    }
  }

  /// Renders handle preview during drag gesture (for new anchor creation).
  void _renderHandlePreview(Canvas canvas, double zoomLevel) {
    final anchorPos = state.dragStartPosition!;
    final dragPos = state.currentDragPosition!;

    // Paint for handle lines
    final handlePaint = ui.Paint()
      ..color = PenPreviewConstants.handleColor
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = PenPreviewConstants.strokeWidth / zoomLevel
      ..strokeCap = ui.StrokeCap.round;

    // Paint for handle control points
    final handlePointPaint = ui.Paint()
      ..color = PenPreviewConstants.handleColor
      ..style = ui.PaintingStyle.fill;

    // Paint for anchor point
    final anchorPaint = ui.Paint()
      ..color = PenPreviewConstants.anchorFillColor
      ..style = ui.PaintingStyle.fill;

    final anchorStrokePaint = ui.Paint()
      ..color = PenPreviewConstants.anchorStrokeColor
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = PenPreviewConstants.strokeWidth / zoomLevel;

    final anchorOffset = ui.Offset(anchorPos.x, anchorPos.y);
    final dragOffset = ui.Offset(dragPos.x, dragPos.y);

    // Draw handleOut line from anchor to drag position
    canvas.drawLine(anchorOffset, dragOffset, handlePaint);

    // Draw handleOut control point
    canvas.drawCircle(
      dragOffset,
      PenPreviewConstants.handleRadius / zoomLevel,
      handlePointPaint,
    );

    // If Alt not pressed (smooth anchor mode), draw mirrored handleIn
    if (!state.isAltPressed) {
      // Calculate mirrored position: anchor - (drag - anchor) = anchor - handleOut
      final mirrorX = anchorPos.x - (dragPos.x - anchorPos.x);
      final mirrorY = anchorPos.y - (dragPos.y - anchorPos.y);
      final mirrorOffset = ui.Offset(mirrorX, mirrorY);

      // Draw handleIn line
      canvas.drawLine(anchorOffset, mirrorOffset, handlePaint);

      // Draw handleIn control point
      canvas.drawCircle(
        mirrorOffset,
        PenPreviewConstants.handleRadius / zoomLevel,
        handlePointPaint,
      );
    }

    // Draw anchor point (on top of handles)
    canvas.drawCircle(
      anchorOffset,
      PenPreviewConstants.anchorRadius / zoomLevel,
      anchorPaint,
    );
    canvas.drawCircle(
      anchorOffset,
      PenPreviewConstants.anchorRadius / zoomLevel,
      anchorStrokePaint,
    );
  }

  /// Renders handle adjustment preview (when adjusting existing anchor handles).
  ///
  /// Similar to _renderHandlePreview, but uses lastAnchorPosition as the
  /// anchor base instead of dragStartPosition, since the user is adjusting
  /// handles on an already-placed anchor.
  void _renderHandleAdjustmentPreview(Canvas canvas, double zoomLevel) {
    if (state.lastAnchorPosition == null) {
      return;
    }

    final anchorPos = state.lastAnchorPosition!;
    final dragPos = state.currentDragPosition!;

    // Paint for handle lines
    final handlePaint = ui.Paint()
      ..color = PenPreviewConstants.handleColor
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = PenPreviewConstants.strokeWidth / zoomLevel
      ..strokeCap = ui.StrokeCap.round;

    // Paint for handle control points
    final handlePointPaint = ui.Paint()
      ..color = PenPreviewConstants.handleColor
      ..style = ui.PaintingStyle.fill;

    // Paint for anchor point
    final anchorPaint = ui.Paint()
      ..color = PenPreviewConstants.anchorFillColor
      ..style = ui.PaintingStyle.fill;

    final anchorStrokePaint = ui.Paint()
      ..color = PenPreviewConstants.anchorStrokeColor
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = PenPreviewConstants.strokeWidth / zoomLevel;

    final anchorOffset = ui.Offset(anchorPos.x, anchorPos.y);
    final dragOffset = ui.Offset(dragPos.x, dragPos.y);

    // Draw handleOut line from anchor to drag position
    canvas.drawLine(anchorOffset, dragOffset, handlePaint);

    // Draw handleOut control point
    canvas.drawCircle(
      dragOffset,
      PenPreviewConstants.handleRadius / zoomLevel,
      handlePointPaint,
    );

    // If Alt not pressed (smooth anchor mode), draw mirrored handleIn
    if (!state.isAltPressed) {
      // Calculate mirrored position: anchor - (drag - anchor) = anchor - handleOut
      final mirrorX = anchorPos.x - (dragPos.x - anchorPos.x);
      final mirrorY = anchorPos.y - (dragPos.y - anchorPos.y);
      final mirrorOffset = ui.Offset(mirrorX, mirrorY);

      // Draw handleIn line
      canvas.drawLine(anchorOffset, mirrorOffset, handlePaint);

      // Draw handleIn control point
      canvas.drawCircle(
        mirrorOffset,
        PenPreviewConstants.handleRadius / zoomLevel,
        handlePointPaint,
      );
    }

    // Draw anchor point (on top of handles)
    canvas.drawCircle(
      anchorOffset,
      PenPreviewConstants.anchorRadius / zoomLevel,
      anchorPaint,
    );
    canvas.drawCircle(
      anchorOffset,
      PenPreviewConstants.anchorRadius / zoomLevel,
      anchorStrokePaint,
    );
  }

  /// Renders path preview line (when not dragging).
  void _renderPathPreview(Canvas canvas, double zoomLevel) {
    final lastAnchor = state.lastAnchorPosition!;
    final hover = state.hoverPosition!;

    // Draw preview line from last anchor to hover position
    final previewPaint = ui.Paint()
      ..color = PenPreviewConstants.previewLineColor
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = PenPreviewConstants.strokeWidth / zoomLevel
      ..strokeCap = ui.StrokeCap.round;

    final lastOffset = ui.Offset(lastAnchor.x, lastAnchor.y);
    final hoverOffset = ui.Offset(hover.x, hover.y);

    canvas.drawLine(lastOffset, hoverOffset, previewPaint);

    // Draw anchor preview circle at hover position
    final anchorPaint = ui.Paint()
      ..color = PenPreviewConstants.previewLineColor
      ..style = ui.PaintingStyle.fill;

    canvas.drawCircle(
      hoverOffset,
      PenPreviewConstants.previewAnchorRadius / zoomLevel,
      anchorPaint,
    );

    // Draw anchor circle at last anchor position
    final lastAnchorPaint = ui.Paint()
      ..color = PenPreviewConstants.lastAnchorColor
      ..style = ui.PaintingStyle.fill;

    canvas.drawCircle(
      lastOffset,
      PenPreviewConstants.previewAnchorRadius / zoomLevel,
      lastAnchorPaint,
    );
  }

  @override
  bool shouldRepaint(PenPreviewOverlayPainter oldDelegate) {
    // Repaint if any preview state has changed
    return state != oldDelegate.state;
  }
}
