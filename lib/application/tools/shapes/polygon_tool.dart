import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:wiretuner/application/tools/shapes/shape_base.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/models/shape.dart' as shape_model;
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';

/// Tool for creating regular polygon shapes.
///
/// Creates polygons through drag interaction:
/// - Default: Corner-to-corner drag defines bounding box, converted to center + radius
/// - Option/Alt: Draw from center (drag distance = radius)
/// - Shift: No effect (polygons are inherently symmetric)
///
/// ## Polygon Parameters
///
/// - **Sides**: Number of sides (default: 5, minimum: 3)
/// - **Radius**: Distance from center to vertices
/// - **Rotation**: Angle in radians (default: 0, pointing straight up)
///
/// ## Usage
///
/// ```dart
/// final polygonTool = PolygonTool(
///   document: document,
///   viewportController: viewportController,
///   eventRecorder: eventRecorder,
/// );
///
/// toolManager.registerTool(polygonTool);
/// toolManager.activateTool('polygon');
/// ```
///
/// Related: T027 (Polygon Tool), I4.T2
class PolygonTool extends ShapeToolBase {
  /// Number of sides for the polygon (minimum 3).
  ///
  /// Future enhancement: Make this configurable via property panel.
  /// For MVP, use fixed value of 5 (pentagon).
  static const int _defaultSideCount = 5;
  int _sideCount = _defaultSideCount;

  PolygonTool({
    required Document document,
    required ViewportController viewportController,
    required dynamic eventRecorder,
  }) : super(
          document: document,
          viewportController: viewportController,
          eventRecorder: eventRecorder,
        );

  @override
  String get toolId => 'polygon';

  @override
  String get shapeTypeName => 'polygon';

  @override
  void renderShapePreview(
    ui.Canvas canvas,
    Rect boundingBox,
    bool isShiftPressed,
    bool isAltPressed,
  ) {
    // Convert bounding box to polygon parameters
    final center = Point(
      x: boundingBox.center.dx,
      y: boundingBox.center.dy,
    );
    final radiusX = boundingBox.width / 2;
    final radiusY = boundingBox.height / 2;
    final radius = max(radiusX, radiusY);

    // Create temporary shape for preview
    final previewShape = shape_model.Shape.polygon(
      center: center,
      radius: radius,
      sides: _sideCount,
      rotation: 0.0,
    );

    // Convert to path for rendering
    final path = previewShape.toPath();

    // Build Flutter Path from our domain Path
    final flutterPath = ui.Path();
    if (path.anchors.isNotEmpty) {
      final firstAnchor = path.anchors.first;
      flutterPath.moveTo(firstAnchor.position.x, firstAnchor.position.y);

      for (int i = 1; i < path.anchors.length; i++) {
        final anchor = path.anchors[i];
        flutterPath.lineTo(anchor.position.x, anchor.position.y);
      }

      // Close the path
      if (path.closed) {
        flutterPath.close();
      }
    }

    // Fill preview with semi-transparent blue
    final fillPaint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawPath(flutterPath, fillPaint);

    // Stroke preview with solid blue
    final strokePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(flutterPath, strokePaint);

    // Optional: Draw center point for visual feedback
    final centerPaint = Paint()
      ..color = Colors.blue.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(center.x, center.y),
      3.0,
      centerPaint,
    );

    // Optional: Draw constraint labels for visual feedback
    if (isAltPressed) {
      _drawConstraintLabels(canvas, boundingBox, isAltPressed);
    }
  }

  @override
  Map<String, double> createShapeParameters(Rect boundingBox) {
    // Convert bounding box to polygon parameters
    final center = boundingBox.center;
    final radiusX = boundingBox.width / 2;
    final radiusY = boundingBox.height / 2;
    final radius = max(radiusX, radiusY);

    return {
      'centerX': center.dx,
      'centerY': center.dy,
      'radius': radius,
      'sides': max(_sideCount, 3).toDouble(), // Enforce minimum
      'rotation': 0.0,
    };
  }

  @override
  ShapeType getShapeType() => ShapeType.polygon;

  /// Draws constraint labels to provide visual feedback during drag.
  void _drawConstraintLabels(
    ui.Canvas canvas,
    Rect boundingBox,
    bool isAltPressed,
  ) {
    final labels = <String>[];
    if (isAltPressed) labels.add('From Center');
    labels.add('${_sideCount} sides');

    if (labels.isEmpty) return;

    final labelText = labels.join(' • ');
    final textSpan = TextSpan(
      text: labelText,
      style: const TextStyle(
        color: Colors.blue,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    // Draw label above the polygon
    final labelOffset = Offset(
      boundingBox.center.dx - textPainter.width / 2,
      boundingBox.top - 20,
    );

    // Draw background
    final backgroundRect = Rect.fromLTWH(
      labelOffset.dx - 4,
      labelOffset.dy - 2,
      textPainter.width + 8,
      textPainter.height + 4,
    );
    final backgroundPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.fill;
    canvas.drawRect(backgroundRect, backgroundPaint);

    // Draw text
    textPainter.paint(canvas, labelOffset);
  }
}
