import 'dart:math' show cos, max, pi, sin;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:wiretuner/application/tools/shapes/shape_base.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/models/shape.dart' as shape_model;

/// Tool for creating regular polygon shapes.
///
/// Creates polygons through drag interaction:
/// - Default: Corner-to-corner drag defines bounding box, converted to center + radius
/// - Option/Alt: Draw from center (drag distance = radius)
/// - Shift: No effect (polygons are inherently symmetric)
///
/// ## Polygon Parameters
///
/// - **Sides**: Number of sides (default: 6, minimum: 3, maximum: 20)
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
  PolygonTool({
    required super.document,
    required super.viewportController,
    required super.eventRecorder,
  });

  /// Number of sides for the polygon (minimum 3, maximum 20).
  ///
  /// Can be configured via [setSideCount] method.
  /// Default: 6 (hexagon).
  static const int _defaultSideCount = 6;
  int _sideCount = _defaultSideCount;

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
    // The polygon should fit exactly in the bounding box
    final center = Point(
      x: boundingBox.center.dx,
      y: boundingBox.center.dy,
    );

    // Calculate scaling factors for width and height
    final scaleX = boundingBox.width / 2;
    final scaleY = boundingBox.height / 2;

    // Create the polygon path manually with proper scaling
    final flutterPath = ui.Path();

    // Generate polygon points
    for (int i = 0; i < _sideCount; i++) {
      // Calculate angle (start from top, go clockwise)
      final angle = -pi / 2 + (2 * pi * i / _sideCount);

      // Calculate point position with non-uniform scaling
      final x = center.x + cos(angle) * scaleX;
      final y = center.y + sin(angle) * scaleY;

      if (i == 0) {
        flutterPath.moveTo(x, y);
      } else {
        flutterPath.lineTo(x, y);
      }
    }

    flutterPath.close();

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
    // Store the actual bounding box parameters
    // We'll create the shape at origin and use transform to position and scale it
    return {
      'centerX': 0.0, // Shape at origin
      'centerY': 0.0,
      'radius': 1.0, // Unit radius
      'sides': max(_sideCount, 3).toDouble(), // Enforce minimum
      'rotation': 0.0,
      // Store bounding box for transform calculation
      'boundingLeft': boundingBox.left,
      'boundingTop': boundingBox.top,
      'boundingWidth': boundingBox.width,
      'boundingHeight': boundingBox.height,
    };
  }

  @override
  ShapeType getShapeType() => ShapeType.polygon;

  /// Sets the number of sides for the polygon.
  ///
  /// The side count must be between 3 and 20 (inclusive).
  /// Values outside this range will be clamped.
  ///
  /// This method allows configuring the polygon before dragging.
  /// In the future, this will be integrated with the property panel UI.
  void setSideCount(int count) {
    _sideCount = count.clamp(3, 20);
  }

  /// Gets the current number of sides.
  int get sideCount => _sideCount;

  /// Draws constraint labels to provide visual feedback during drag.
  void _drawConstraintLabels(
    ui.Canvas canvas,
    Rect boundingBox,
    bool isAltPressed,
  ) {
    final labels = <String>[];
    if (isAltPressed) labels.add('From Center');
    labels.add('$_sideCount sides');

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
