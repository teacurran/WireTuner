import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:wiretuner/application/tools/shapes/shape_base.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';

/// Tool for creating rectangle shapes.
///
/// Creates rectangles through drag interaction:
/// - Default: Corner-to-corner drag
/// - Shift: Constrain to square
/// - Option/Alt: Draw from center
/// - Shift+Option: Square from center
///
/// ## Usage
///
/// ```dart
/// final rectangleTool = RectangleTool(
///   document: document,
///   viewportController: viewportController,
///   eventRecorder: eventRecorder,
/// );
///
/// toolManager.registerTool(rectangleTool);
/// toolManager.activateTool('rectangle');
/// ```
///
/// Related: T025 (Rectangle Tool), I4.T1
class RectangleTool extends ShapeToolBase {
  RectangleTool({
    required Document document,
    required ViewportController viewportController,
    required dynamic eventRecorder,
  }) : super(
          document: document,
          viewportController: viewportController,
          eventRecorder: eventRecorder,
        );

  @override
  String get toolId => 'rectangle';

  @override
  String get shapeTypeName => 'rectangle';

  @override
  void renderShapePreview(
    ui.Canvas canvas,
    Rect boundingBox,
    bool isShiftPressed,
    bool isAltPressed,
  ) {
    // Fill preview with semi-transparent blue
    final fillPaint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawRect(boundingBox, fillPaint);

    // Stroke preview with solid blue
    final strokePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(boundingBox, strokePaint);

    // Optional: Draw constraint labels for visual feedback
    if (isShiftPressed || isAltPressed) {
      _drawConstraintLabels(canvas, boundingBox, isShiftPressed, isAltPressed);
    }
  }

  @override
  Map<String, double> createShapeParameters(Rect boundingBox) {
    return {
      'centerX': boundingBox.center.dx,
      'centerY': boundingBox.center.dy,
      'width': boundingBox.width,
      'height': boundingBox.height,
      'cornerRadius': 0.0, // No rounded corners for basic rectangle tool
    };
  }

  @override
  ShapeType getShapeType() => ShapeType.rectangle;

  /// Draws constraint labels to provide visual feedback during drag.
  void _drawConstraintLabels(
    ui.Canvas canvas,
    Rect boundingBox,
    bool isShiftPressed,
    bool isAltPressed,
  ) {
    final labels = <String>[];
    if (isShiftPressed) labels.add('Square');
    if (isAltPressed) labels.add('From Center');

    if (labels.isEmpty) return;

    final labelText = labels.join(' + ');
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

    // Draw label above the rectangle
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
