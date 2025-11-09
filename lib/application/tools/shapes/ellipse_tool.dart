import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:wiretuner/application/tools/shapes/shape_base.dart';
import 'package:wiretuner/domain/events/event_base.dart';

/// Tool for creating ellipse shapes.
///
/// Creates ellipses through drag interaction:
/// - Default: Corner-to-corner drag (defines bounding box)
/// - Shift: Constrain to circle
/// - Option/Alt: Draw from center
/// - Shift+Option: Circle from center
///
/// ## Usage
///
/// ```dart
/// final ellipseTool = EllipseTool(
///   document: document,
///   viewportController: viewportController,
///   eventRecorder: eventRecorder,
/// );
///
/// toolManager.registerTool(ellipseTool);
/// toolManager.activateTool('ellipse');
/// ```
///
/// Related: T026 (Ellipse Tool), I4.T1
class EllipseTool extends ShapeToolBase {
  /// Creates an ellipse tool instance.
  ///
  /// Requires [document], [viewportController], and [eventRecorder] for
  /// event sourcing and coordinate conversion.
  EllipseTool({
    required super.document,
    required super.viewportController,
    required super.eventRecorder,
  });

  @override
  String get toolId => 'ellipse';

  @override
  String get shapeTypeName => 'ellipse';

  @override
  void renderShapePreview(
    ui.Canvas canvas,
    Rect boundingBox,
    bool isShiftPressed,
    bool isAltPressed,
  ) {
    // Fill preview with semi-transparent green
    final fillPaint = Paint()
      ..color = Colors.green.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawOval(boundingBox, fillPaint);

    // Stroke preview with solid green
    final strokePaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawOval(boundingBox, strokePaint);

    // Optional: Draw constraint labels for visual feedback
    if (isShiftPressed || isAltPressed) {
      _drawConstraintLabels(canvas, boundingBox, isShiftPressed, isAltPressed);
    }
  }

  @override
  Map<String, double> createShapeParameters(Rect boundingBox) => {
        'centerX': boundingBox.center.dx,
        'centerY': boundingBox.center.dy,
        'width': boundingBox.width,
        'height': boundingBox.height,
        // Note: Ellipse doesn't have cornerRadius parameter
      };

  @override
  ShapeType getShapeType() => ShapeType.ellipse;

  /// Draws constraint labels to provide visual feedback during drag.
  void _drawConstraintLabels(
    ui.Canvas canvas,
    Rect boundingBox,
    bool isShiftPressed,
    bool isAltPressed,
  ) {
    final labels = <String>[];
    if (isShiftPressed) labels.add('Circle');
    if (isAltPressed) labels.add('From Center');

    if (labels.isEmpty) return;

    final labelText = labels.join(' + ');
    final textSpan = TextSpan(
      text: labelText,
      style: const TextStyle(
        color: Colors.green,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    // Draw label above the ellipse
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
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    canvas.drawRect(backgroundRect, backgroundPaint);

    // Draw text
    textPainter.paint(canvas, labelOffset);
  }
}
