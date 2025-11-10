import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:wiretuner/domain/document/selection.dart';
import 'package:wiretuner/domain/events/event_base.dart' as event_base;
import 'package:wiretuner/domain/models/anchor_point.dart';
import 'package:wiretuner/domain/models/geometry/point_extensions.dart';
import 'package:wiretuner/domain/models/geometry/rectangle.dart' as geom;
import 'package:wiretuner/domain/models/path.dart' as domain;
import 'package:wiretuner/domain/models/shape.dart';
import 'package:wiretuner/presentation/canvas/painter/path_renderer.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';

/// Visual constants for selection overlay rendering.
class SelectionOverlayConstants {
  /// Size of anchor point circles in screen pixels.
  static const double anchorSize = 6.0;

  /// Size of Bezier control point (BCP) handle circles in screen pixels.
  static const double handleSize = 4.0;

  /// Color for selected anchors and handles.
  static const Color selectedColor = Color(0xFF2196F3); // Blue

  /// Color for hovered anchors and handles.
  static const Color hoverColor = Color(0xFFFF9800); // Orange

  /// Color for selection bounding box.
  static const Color boundingBoxColor = Color(0xFF2196F3); // Blue

  /// Stroke width for bounding box in screen pixels.
  static const double boundingBoxStrokeWidth = 1.0;

  /// Color for BCP handle lines.
  static const Color bcpLineColor = Color(0xFF9E9E9E); // Gray

  /// Stroke width for BCP handle lines in screen pixels.
  static const double bcpLineStrokeWidth = 1.0;

  /// Dash pattern for bounding box (alternating line and gap lengths).
  static const List<double> dashPattern = [4.0, 4.0];
}

/// Custom painter that renders selection decorations over the canvas.
///
/// SelectionOverlayPainter draws visual feedback for selected objects:
/// - Bounding boxes around selected objects
/// - Anchor point circles at each vertex
/// - Bezier control point (BCP) handles with connecting lines
/// - Color-coded states (selected, hover)
///
/// ## Design Rationale
///
/// The selection overlay is a separate CustomPainter from DocumentPainter to:
/// - Enable independent repainting (selection changes don't repaint document)
/// - Isolate selection UI from document rendering logic
/// - Allow easy addition of selection-specific features (handles, highlights)
///
/// ## Performance
///
/// - Uses PathRenderer's cache for geometry conversion
/// - Only repaints when selection or viewport changes
/// - Transforms applied once per frame via ViewportController
///
/// ## Usage
///
/// ```dart
/// CustomPaint(
///   painter: SelectionOverlayPainter(
///     selection: selection,
///     paths: document.paths,
///     shapes: document.shapes,
///     viewportController: viewportController,
///     pathRenderer: pathRenderer,
///     hoveredAnchor: HoveredAnchor(objectId: 'path-1', anchorIndex: 2),
///   ),
/// )
/// ```
class SelectionOverlayPainter extends CustomPainter {
  /// Creates a selection overlay painter.
  SelectionOverlayPainter({
    required this.selection,
    required this.paths,
    required this.shapes,
    required this.viewportController,
    required this.pathRenderer,
    this.hoveredAnchor,
  }) : super(repaint: viewportController);

  /// The current selection state.
  final Selection selection;

  /// Map of path objects by ID.
  final Map<String, domain.Path> paths;

  /// Map of shape objects by ID.
  final Map<String, Shape> shapes;

  /// Viewport controller providing transformation state.
  final ViewportController viewportController;

  /// Path renderer for converting domain geometry to ui.Path.
  final PathRenderer pathRenderer;

  /// Currently hovered anchor point (if any).
  final HoveredAnchor? hoveredAnchor;

  @override
  void paint(Canvas canvas, Size size) {
    if (selection.isEmpty) {
      return; // Nothing to render
    }

    // Apply viewport transformation
    canvas.save();
    canvas.transform(viewportController.worldToScreenMatrix.storage);

    // Render unified bounding box if multiple objects selected
    if (selection.selectedCount > 1) {
      _paintUnifiedBoundingBox(canvas);
    } else {
      // Render each selected object (single selection)
      for (final objectId in selection.objectIds) {
        final path = paths[objectId];
        final shape = shapes[objectId];

        if (path != null) {
          _paintPathSelection(canvas, objectId, path);
        } else if (shape != null) {
          _paintShapeSelection(canvas, objectId, shape);
        }
      }
    }

    canvas.restore();
  }

  /// Paints selection decorations for a path object.
  void _paintPathSelection(Canvas canvas, String objectId, domain.Path path) {
    if (path.anchors.isEmpty) {
      return;
    }

    // Draw bounding box
    _drawBoundingBox(canvas, path.bounds());

    // Draw anchor points and handles
    final selectedAnchors = selection.getSelectedAnchors(objectId);
    for (int i = 0; i < path.anchors.length; i++) {
      final anchor = path.anchors[i];
      final isSelected = selectedAnchors.contains(i);
      final isHovered = hoveredAnchor?.objectId == objectId &&
          hoveredAnchor?.anchorIndex == i;

      _drawAnchor(
        canvas,
        anchor,
        isSelected: isSelected,
        isHovered: isHovered,
        component: hoveredAnchor?.component,
      );
    }
  }

  /// Paints selection decorations for a shape object.
  void _paintShapeSelection(Canvas canvas, String objectId, Shape shape) {
    // Convert shape to path for bounds and anchor rendering
    final path = shape.toPath();

    if (path.anchors.isEmpty) {
      return;
    }

    // Draw bounding box
    _drawBoundingBox(canvas, path.bounds());

    // Draw anchor points and handles
    final selectedAnchors = selection.getSelectedAnchors(objectId);
    for (int i = 0; i < path.anchors.length; i++) {
      final anchor = path.anchors[i];
      final isSelected = selectedAnchors.contains(i);
      final isHovered = hoveredAnchor?.objectId == objectId &&
          hoveredAnchor?.anchorIndex == i;

      _drawAnchor(
        canvas,
        anchor,
        isSelected: isSelected,
        isHovered: isHovered,
        component: hoveredAnchor?.component,
      );
    }
  }

  /// Paints a unified bounding box that encompasses all selected objects.
  ///
  /// This method computes the union of all selected object bounds and draws
  /// a single bounding box around them. Used for multi-selection visualization.
  void _paintUnifiedBoundingBox(Canvas canvas) {
    // Collect bounds of all selected objects
    final selectedBounds = <geom.Rectangle>[];

    for (final objectId in selection.objectIds) {
      final path = paths[objectId];
      final shape = shapes[objectId];

      if (path != null && path.anchors.isNotEmpty) {
        selectedBounds.add(path.bounds());
      } else if (shape != null) {
        final shapePath = shape.toPath();
        if (shapePath.anchors.isNotEmpty) {
          selectedBounds.add(shapePath.bounds());
        }
      }
    }

    if (selectedBounds.isEmpty) {
      return;
    }

    // Compute union of all bounds
    final unifiedBounds = _computeUnionBounds(selectedBounds);

    // Draw unified bounding box
    _drawBoundingBox(canvas, unifiedBounds);
  }

  /// Computes the union of multiple rectangles.
  ///
  /// Returns a rectangle that encompasses all input rectangles.
  geom.Rectangle _computeUnionBounds(List<geom.Rectangle> bounds) {
    if (bounds.isEmpty) {
      return const geom.Rectangle(x: 0, y: 0, width: 0, height: 0);
    }

    double minX = bounds.first.x;
    double minY = bounds.first.y;
    double maxX = bounds.first.x + bounds.first.width;
    double maxY = bounds.first.y + bounds.first.height;

    for (final rect in bounds.skip(1)) {
      minX = minX < rect.x ? minX : rect.x;
      minY = minY < rect.y ? minY : rect.y;
      final rectMaxX = rect.x + rect.width;
      final rectMaxY = rect.y + rect.height;
      maxX = maxX > rectMaxX ? maxX : rectMaxX;
      maxY = maxY > rectMaxY ? maxY : rectMaxY;
    }

    return geom.Rectangle(
      x: minX,
      y: minY,
      width: maxX - minX,
      height: maxY - minY,
    );
  }

  /// Draws a dashed bounding box around the object.
  void _drawBoundingBox(Canvas canvas, geom.Rectangle bounds) {
    final paint = Paint()
      ..color = SelectionOverlayConstants.boundingBoxColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = SelectionOverlayConstants.boundingBoxStrokeWidth /
          viewportController.zoomLevel; // Convert to world space

    final rect = Rect.fromLTWH(
      bounds.x,
      bounds.y,
      bounds.width,
      bounds.height,
    );

    // Draw dashed rectangle
    _drawDashedRect(canvas, rect, paint);
  }

  /// Draws a dashed rectangle.
  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    final path = ui.Path();

    // Top edge
    _addDashedLine(
      path,
      Offset(rect.left, rect.top),
      Offset(rect.right, rect.top),
    );

    // Right edge
    _addDashedLine(
      path,
      Offset(rect.right, rect.top),
      Offset(rect.right, rect.bottom),
    );

    // Bottom edge
    _addDashedLine(
      path,
      Offset(rect.right, rect.bottom),
      Offset(rect.left, rect.bottom),
    );

    // Left edge
    _addDashedLine(
      path,
      Offset(rect.left, rect.bottom),
      Offset(rect.left, rect.top),
    );

    canvas.drawPath(path, paint);
  }

  /// Adds a dashed line to a path.
  void _addDashedLine(ui.Path path, Offset start, Offset end) {
    final worldSpaceDash = SelectionOverlayConstants.dashPattern
        .map((d) => d / viewportController.zoomLevel)
        .toList();

    final dashLength = worldSpaceDash[0];
    final gapLength = worldSpaceDash[1];
    final totalLength = (end - start).distance;

    double currentDistance = 0;
    bool isDash = true;

    path.moveTo(start.dx, start.dy);

    while (currentDistance < totalLength) {
      final segmentLength = isDash ? dashLength : gapLength;
      final nextDistance =
          (currentDistance + segmentLength).clamp(0.0, totalLength);

      final t = nextDistance / totalLength;
      final nextPoint = Offset.lerp(start, end, t)!;

      if (isDash) {
        path.lineTo(nextPoint.dx, nextPoint.dy);
      } else {
        path.moveTo(nextPoint.dx, nextPoint.dy);
      }

      currentDistance = nextDistance;
      isDash = !isDash;
    }
  }

  /// Draws an anchor point with its handles.
  void _drawAnchor(
    Canvas canvas,
    AnchorPoint anchor, {
    required bool isSelected,
    required bool isHovered,
    AnchorComponent? component,
  }) {
    // Draw handleIn line and circle
    if (anchor.handleIn != null) {
      final handleInPos = anchor.position + anchor.handleIn!;
      final isHandleInHovered =
          isHovered && component == AnchorComponent.handleIn;

      _drawBCPLine(canvas, anchor.position, handleInPos);
      _drawHandle(
        canvas,
        handleInPos,
        isSelected: isSelected,
        isHovered: isHandleInHovered,
      );
    }

    // Draw handleOut line and circle
    if (anchor.handleOut != null) {
      final handleOutPos = anchor.position + anchor.handleOut!;
      final isHandleOutHovered =
          isHovered && component == AnchorComponent.handleOut;

      _drawBCPLine(canvas, anchor.position, handleOutPos);
      _drawHandle(
        canvas,
        handleOutPos,
        isSelected: isSelected,
        isHovered: isHandleOutHovered,
      );
    }

    // Draw anchor point circle
    final isAnchorHovered =
        isHovered && (component == AnchorComponent.anchor || component == null);
    _drawAnchorPoint(
      canvas,
      anchor.position,
      isSelected: isSelected,
      isHovered: isAnchorHovered,
    );
  }

  /// Draws a line connecting an anchor to its BCP handle.
  void _drawBCPLine(
    Canvas canvas,
    event_base.Point anchorPos,
    event_base.Point handlePos,
  ) {
    final paint = Paint()
      ..color = SelectionOverlayConstants.bcpLineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = SelectionOverlayConstants.bcpLineStrokeWidth /
          viewportController.zoomLevel; // Convert to world space

    canvas.drawLine(
      Offset(anchorPos.x, anchorPos.y),
      Offset(handlePos.x, handlePos.y),
      paint,
    );
  }

  /// Draws a BCP handle circle.
  void _drawHandle(
    Canvas canvas,
    event_base.Point position, {
    required bool isSelected,
    required bool isHovered,
  }) {
    final color = isHovered
        ? SelectionOverlayConstants.hoverColor
        : SelectionOverlayConstants.selectedColor;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Convert handle size from screen to world space
    final worldRadius = SelectionOverlayConstants.handleSize /
        (2 * viewportController.zoomLevel);

    canvas.drawCircle(
      Offset(position.x, position.y),
      worldRadius,
      paint,
    );
  }

  /// Draws an anchor point circle.
  void _drawAnchorPoint(
    Canvas canvas,
    event_base.Point position, {
    required bool isSelected,
    required bool isHovered,
  }) {
    final color = isHovered
        ? SelectionOverlayConstants.hoverColor
        : SelectionOverlayConstants.selectedColor;

    // Draw filled circle
    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 / viewportController.zoomLevel;

    // Convert anchor size from screen to world space
    final worldRadius = SelectionOverlayConstants.anchorSize /
        (2 * viewportController.zoomLevel);

    canvas.drawCircle(
      Offset(position.x, position.y),
      worldRadius,
      fillPaint,
    );

    canvas.drawCircle(
      Offset(position.x, position.y),
      worldRadius,
      strokePaint,
    );
  }

  @override
  bool shouldRepaint(covariant SelectionOverlayPainter oldDelegate) {
    // Repaint if selection changed
    if (selection != oldDelegate.selection) return true;

    // Repaint if viewport changed (handled by repaint: viewportController)
    if (viewportController != oldDelegate.viewportController) return true;

    // Repaint if paths changed
    if (paths != oldDelegate.paths) return true;

    // Repaint if shapes changed
    if (shapes != oldDelegate.shapes) return true;

    // Repaint if hover state changed
    if (hoveredAnchor != oldDelegate.hoveredAnchor) return true;

    return false;
  }
}

/// Represents a hovered anchor point or handle component.
class HoveredAnchor {
  const HoveredAnchor({
    required this.objectId,
    required this.anchorIndex,
    this.component,
  });

  /// The object ID containing the anchor.
  final String objectId;

  /// The index of the anchor point.
  final int anchorIndex;

  /// The specific component being hovered (anchor, handleIn, or handleOut).
  final AnchorComponent? component;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HoveredAnchor &&
        other.objectId == objectId &&
        other.anchorIndex == anchorIndex &&
        other.component == component;
  }

  @override
  int get hashCode => Object.hash(objectId, anchorIndex, component);
}

/// Component of an anchor point for hit-testing.
enum AnchorComponent {
  /// The anchor point itself.
  anchor,

  /// The incoming handle (handleIn).
  handleIn,

  /// The outgoing handle (handleOut).
  handleOut,
}
