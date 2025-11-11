import 'dart:math' show cos, sin;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/models/geometry/point_extensions.dart';
import 'package:wiretuner/domain/models/path.dart' as domain;
import 'package:wiretuner/domain/models/segment.dart';
import 'package:wiretuner/domain/models/shape.dart';
import 'package:wiretuner/presentation/canvas/paint_styles.dart';
import 'package:wiretuner/presentation/canvas/render_pipeline.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';

/// CustomPainter that renders vector paths from the document model.
///
/// DocumentPainter is the core rendering component that converts domain
/// [Path] objects into rendered graphics on the canvas. It integrates with
/// the [ViewportController] to apply pan/zoom transformations.
///
/// ## Rendering Pipeline
///
/// 1. Accept list of domain paths and viewport controller
/// 2. Apply viewport transformation to canvas
/// 3. For each path:
///    - Convert domain path to dart:ui Path
///    - Render with placeholder stroke style
/// 4. Use [shouldRepaint] to optimize redraws
///
/// ## Performance Optimization
///
/// - Wrap in [RepaintBoundary] to isolate repaints
/// - [shouldRepaint] checks path list and viewport changes
/// - Future: Implement dirty-region tracking for partial updates
/// - Future: Cull paths outside viewport bounds
///
/// ## Usage
///
/// ```dart
/// CustomPaint(
///   painter: DocumentPainter(
///     paths: document.paths,
///     viewportController: viewportController,
///   ),
/// )
/// ```
///
/// Typically wrapped in:
/// ```dart
/// RepaintBoundary(
///   child: CustomPaint(
///     painter: DocumentPainter(...),
///   ),
/// )
/// ```
class DocumentPainter extends CustomPainter {
  /// Creates a document painter with the specified paths and viewport.
  ///
  /// The [paths] list should contain the paths to render.
  /// The [shapes] map should contain shape objects by ID.
  /// The [viewportController] provides the pan/zoom transformation state.
  /// The [strokeWidth] and [strokeColor] are placeholder style properties.
  /// The [renderPipeline] is an optional advanced rendering pipeline; if not
  /// provided, the painter uses the legacy direct rendering approach.
  DocumentPainter({
    required this.paths,
    required this.shapes,
    required this.viewportController,
    this.strokeWidth = 1.0,
    this.strokeColor = Colors.black,
    this.renderPipeline,
  }) : super(repaint: viewportController);

  /// The list of paths to render.
  ///
  /// These are domain [Path] objects that will be converted to
  /// dart:ui paths for rendering.
  final List<domain.Path> paths;

  /// The map of shapes to render by ID.
  final Map<String, Shape> shapes;

  /// The viewport controller providing transformation state.
  ///
  /// The painter uses the controller's transformation matrix to
  /// render paths in the correct screen position and scale.
  final ViewportController viewportController;

  /// Optional stroke width in world coordinates.
  ///
  /// Defaults to 1.0. This value is in world space, so it will be
  /// scaled by the viewport zoom when rendered.
  final double strokeWidth;

  /// Optional stroke color.
  ///
  /// Defaults to black. This is a placeholder style; future iterations
  /// will integrate with a proper style system.
  final Color strokeColor;

  /// Optional render pipeline for advanced rendering features.
  ///
  /// When provided, this pipeline is used for rendering with support for
  /// caching, culling, and performance optimizations. If null, falls back
  /// to the legacy direct rendering approach.
  final RenderPipeline? renderPipeline;

  @override
  void paint(Canvas canvas, Size size) {
    // Use render pipeline if available
    if (renderPipeline != null) {
      _paintWithPipeline(canvas, size);
    } else {
      _paintLegacy(canvas, size);
    }
  }

  /// Renders using the advanced render pipeline.
  void _paintWithPipeline(Canvas canvas, Size size) {
    // Convert paths to renderable objects with default style
    final defaultStyle = PaintStyle.stroke(
      color: strokeColor,
      strokeWidth: strokeWidth,
    );

    final renderablePaths = <RenderablePath>[];
    for (var i = 0; i < paths.length; i++) {
      renderablePaths.add(
        RenderablePath(
          id: 'path-$i',
          path: paths[i],
          style: defaultStyle,
        ),
      );
    }

    // Render via pipeline
    renderPipeline!.render(
      canvas: canvas,
      size: size,
      viewportController: viewportController,
      paths: renderablePaths,
    );
  }

  /// Legacy rendering approach (backward compatibility).
  void _paintLegacy(Canvas canvas, Size size) {
    // Apply viewport transformation
    canvas.save();
    canvas.transform(viewportController.worldToScreenMatrix.storage);

    // Create paint for path strokes
    final paint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Render each path
    for (final domainPath in paths) {
      final uiPath = _convertDomainPathToUiPath(domainPath);
      canvas.drawPath(uiPath, paint);
    }

    // Render each shape
    for (final shape in shapes.values) {
      final uiPath = _convertShapeToUiPath(shape);
      canvas.drawPath(uiPath, paint);
    }

    canvas.restore();
  }

  /// Converts a parametric Shape to a dart:ui Path for rendering.
  ui.Path _convertShapeToUiPath(Shape shape) {
    final path = ui.Path();

    switch (shape.kind) {
      case ShapeKind.rectangle:
        final rect = Rect.fromCenter(
          center: Offset(shape.center.x, shape.center.y),
          width: shape.width!,
          height: shape.height!,
        );
        if (shape.cornerRadius > 0) {
          path.addRRect(RRect.fromRectAndRadius(
            rect,
            Radius.circular(shape.cornerRadius),
          ));
        } else {
          path.addRect(rect);
        }
        break;

      case ShapeKind.ellipse:
        final rect = Rect.fromCenter(
          center: Offset(shape.center.x, shape.center.y),
          width: shape.width!,
          height: shape.height!,
        );
        path.addOval(rect);
        break;

      case ShapeKind.polygon:
        _addPolygonToPath(path, shape.center, shape.radius!, shape.sides);
        break;

      case ShapeKind.star:
        _addStarToPath(
            path, shape.center, shape.radius!, shape.innerRadius!, shape.sides);
        break;
    }

    return path;
  }

  /// Adds a polygon to the given path.
  void _addPolygonToPath(ui.Path path, Point center, double radius, int sides) {
    if (sides < 3) return;

    final angleStep = 2 * 3.141592653589793 / sides;
    final startAngle = -3.141592653589793 / 2; // Start at top

    // Move to first vertex
    final firstX = center.x + radius * cos(startAngle);
    final firstY = center.y + radius * sin(startAngle);
    path.moveTo(firstX, firstY);

    // Draw lines to remaining vertices
    for (var i = 1; i < sides; i++) {
      final angle = startAngle + angleStep * i;
      final x = center.x + radius * cos(angle);
      final y = center.y + radius * sin(angle);
      path.lineTo(x, y);
    }

    path.close();
  }

  /// Adds a star to the given path.
  void _addStarToPath(
    ui.Path path,
    Point center,
    double outerRadius,
    double innerRadius,
    int pointCount,
  ) {
    if (pointCount < 2) return;

    final angleStep = 3.141592653589793 / pointCount; // π / pointCount
    final startAngle = -3.141592653589793 / 2; // Start at top

    // Move to first outer vertex
    final firstX = center.x + outerRadius * cos(startAngle);
    final firstY = center.y + outerRadius * sin(startAngle);
    path.moveTo(firstX, firstY);

    // Alternate between outer and inner vertices
    for (var i = 0; i < pointCount * 2; i++) {
      final angle = startAngle + angleStep * (i + 1);
      final radius = (i % 2 == 0) ? innerRadius : outerRadius;
      final x = center.x + radius * cos(angle);
      final y = center.y + radius * sin(angle);
      path.lineTo(x, y);
    }

    path.close();
  }

  @override
  bool shouldRepaint(covariant DocumentPainter oldDelegate) {
    // Repaint if paths reference changed
    if (paths != oldDelegate.paths) return true;

    // Repaint if shapes reference changed
    if (shapes != oldDelegate.shapes) return true;

    // Repaint if viewport controller changed
    // The controller is also passed to super(repaint:) which handles
    // repaints when the controller notifies listeners
    if (viewportController != oldDelegate.viewportController) return true;

    // Repaint if style properties changed
    if (strokeWidth != oldDelegate.strokeWidth) return true;
    if (strokeColor != oldDelegate.strokeColor) return true;

    return false;
  }

  /// Converts a domain Path to a dart:ui Path for rendering.
  ///
  /// This method walks through the path's anchors and segments,
  /// converting them to Canvas path commands:
  /// - First anchor: moveTo
  /// - Line segments: lineTo
  /// - Bezier segments: cubicTo with control points from handles
  /// - Closed paths: close() after last segment
  ///
  /// **Coordinate Space**: The returned path is in world coordinates.
  /// The viewport transformation (already applied to canvas) will convert
  /// it to screen coordinates during rendering.
  ui.Path _convertDomainPathToUiPath(domain.Path domainPath) {
    final path = ui.Path();

    if (domainPath.anchors.isEmpty) {
      return path;
    }

    // Move to first anchor
    final firstAnchor = domainPath.anchors.first;
    path.moveTo(firstAnchor.position.x, firstAnchor.position.y);

    // Draw explicit segments
    for (final segment in domainPath.segments) {
      _addSegmentToPath(path, segment, domainPath);
    }

    // For closed paths, add implicit closing segment
    if (domainPath.closed && domainPath.anchors.length > 1) {
      final lastAnchor = domainPath.anchors.last;
      final firstAnchor = domainPath.anchors.first;

      // Check if closing segment should be a curve
      final hasHandles =
          lastAnchor.handleOut != null || firstAnchor.handleIn != null;

      if (hasHandles) {
        // Compute control points for closing Bezier segment
        final cp1 = lastAnchor.handleOut != null
            ? lastAnchor.position + lastAnchor.handleOut!
            : lastAnchor.position;

        final cp2 = firstAnchor.handleIn != null
            ? firstAnchor.position + firstAnchor.handleIn!
            : firstAnchor.position;

        path.cubicTo(
          cp1.x,
          cp1.y,
          cp2.x,
          cp2.y,
          firstAnchor.position.x,
          firstAnchor.position.y,
        );
      }

      // Close the path
      path.close();
    }

    return path;
  }

  /// Adds a segment to the ui.Path.
  ///
  /// This method switches on the segment type and generates the appropriate
  /// Canvas path command:
  /// - LINE: lineTo(end position)
  /// - BEZIER: cubicTo(cp1, cp2, end position) using anchor handles
  void _addSegmentToPath(
    ui.Path path,
    Segment segment,
    domain.Path domainPath,
  ) {
    final startAnchor = domainPath.anchors[segment.startAnchorIndex];
    final endAnchor = domainPath.anchors[segment.endAnchorIndex];

    switch (segment.segmentType) {
      case SegmentType.line:
        // Straight line to end anchor
        path.lineTo(endAnchor.position.x, endAnchor.position.y);
        break;

      case SegmentType.bezier:
        // Cubic Bezier curve with control points from handles
        //
        // Control point 1: Start anchor's handleOut (relative to start position)
        // Control point 2: End anchor's handleIn (relative to end position)
        //
        // If a handle is null, default to the anchor position (degenerate curve)
        final cp1 = startAnchor.handleOut != null
            ? startAnchor.position + startAnchor.handleOut!
            : startAnchor.position;

        final cp2 = endAnchor.handleIn != null
            ? endAnchor.position + endAnchor.handleIn!
            : endAnchor.position;

        path.cubicTo(
          cp1.x,
          cp1.y,
          cp2.x,
          cp2.y,
          endAnchor.position.x,
          endAnchor.position.y,
        );
        break;

      case SegmentType.arc:
        // Arc segments not yet implemented in domain model
        // For now, fall back to straight line
        path.lineTo(endAnchor.position.x, endAnchor.position.y);
        break;
    }
  }
}
