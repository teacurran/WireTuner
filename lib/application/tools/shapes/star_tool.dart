import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:wiretuner/application/tools/shapes/shape_base.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/models/shape.dart' as shape_model;

/// Tool for creating star shapes.
///
/// Creates stars through drag interaction:
/// - Default: Corner-to-corner drag defines bounding box, converted to center + outer radius
/// - Option/Alt: Draw from center (drag distance = outer radius)
/// - Shift: No effect (stars are inherently symmetric)
///
/// ## Star Parameters
///
/// - **Point Count**: Number of star points (default: 5, minimum: 3)
/// - **Outer Radius**: Distance from center to outer points
/// - **Inner Radius**: Distance from center to inner points (default: 0.5 × outer radius)
/// - **Rotation**: Angle in radians (default: 0, pointing straight up)
///
/// ## Usage
///
/// ```dart
/// final starTool = StarTool(
///   document: document,
///   viewportController: viewportController,
///   eventRecorder: eventRecorder,
/// );
///
/// toolManager.registerTool(starTool);
/// toolManager.activateTool('star');
/// ```
///
/// Related: T028 (Star Tool), I4.T2
class StarTool extends ShapeToolBase {
  /// Creates a new StarTool instance.
  ///
  /// Requires [document] for shape storage, [viewportController] for coordinate
  /// conversion, and [eventRecorder] for event sourcing.
  StarTool({
    required super.document,
    required super.viewportController,
    required super.eventRecorder,
  });
  final Logger _logger = Logger();

  /// Number of points for the star (minimum 3, maximum 20).
  ///
  /// Can be configured via [setPointCount] method.
  /// Default: 5 (classic 5-point star).
  static const int _defaultPointCount = 5;
  int _pointCount = _defaultPointCount;

  /// Inner radius as a ratio of outer radius (0.0 to 1.0).
  ///
  /// Future enhancement: Make this adjustable via property panel.
  /// For MVP, use fixed value of 0.5 (pleasing star shape).
  static const double _defaultInnerRadiusRatio = 0.5;
  final double _innerRadiusRatio = _defaultInnerRadiusRatio;

  @override
  String get toolId => 'star';

  @override
  String get shapeTypeName => 'star';

  @override
  void renderShapePreview(
    ui.Canvas canvas,
    Rect boundingBox,
    bool isShiftPressed,
    bool isAltPressed,
  ) {
    // Convert bounding box to star parameters
    final center = Point(
      x: boundingBox.center.dx,
      y: boundingBox.center.dy,
    );
    final radiusX = boundingBox.width / 2;
    final radiusY = boundingBox.height / 2;
    final outerRadius = max(radiusX, radiusY);
    final innerRadius = outerRadius * _innerRadiusRatio;

    // Validate inner radius
    if (innerRadius >= outerRadius || innerRadius <= 0) {
      _logger.w('Invalid star parameters: innerRadius=$innerRadius, outerRadius=$outerRadius');
      return;
    }

    // Create temporary shape for preview
    final previewShape = shape_model.Shape.star(
      center: center,
      outerRadius: outerRadius,
      innerRadius: innerRadius,
      pointCount: _pointCount,
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
      ..color = Colors.blue.withValues(alpha: 0.3)
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
      ..color = Colors.blue.withValues(alpha: 0.5)
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
    // Convert bounding box to star parameters
    final center = boundingBox.center;
    final radiusX = boundingBox.width / 2;
    final radiusY = boundingBox.height / 2;
    final outerRadius = max(radiusX, radiusY);
    final innerRadius = outerRadius * _innerRadiusRatio;

    // Validate inner radius before creating parameters
    if (innerRadius >= outerRadius) {
      _logger.w(
        'Invalid star: innerRadius ($innerRadius) >= outerRadius ($outerRadius)',
      );
      // Use a safe default - ensure inner radius is less than outer
      final safeInnerRadius = outerRadius * 0.5;
      return {
        'centerX': center.dx,
        'centerY': center.dy,
        'radius': outerRadius, // "radius" field = outer radius
        'innerRadius': safeInnerRadius,
        'sides': max(_pointCount, 3).toDouble(), // Enforce minimum
        'rotation': 0.0,
      };
    }

    if (innerRadius <= 0) {
      _logger.w('Invalid star: innerRadius ($innerRadius) <= 0');
      // Use a safe minimum
      final safeInnerRadius = max(outerRadius * 0.1, 0.01);
      return {
        'centerX': center.dx,
        'centerY': center.dy,
        'radius': outerRadius,
        'innerRadius': safeInnerRadius,
        'sides': max(_pointCount, 3).toDouble(),
        'rotation': 0.0,
      };
    }

    return {
      'centerX': center.dx,
      'centerY': center.dy,
      'radius': outerRadius, // "radius" field = outer radius
      'innerRadius': innerRadius,
      'sides': max(_pointCount, 3).toDouble(), // Enforce minimum, convert to double
      'rotation': 0.0,
    };
  }

  @override
  ShapeType getShapeType() => ShapeType.star;

  /// Sets the number of points for the star.
  ///
  /// The point count must be between 3 and 20 (inclusive).
  /// Values outside this range will be clamped.
  ///
  /// This method allows configuring the star before dragging.
  /// In the future, this will be integrated with the property panel UI.
  void setPointCount(int count) {
    _pointCount = count.clamp(3, 20);
  }

  /// Gets the current number of points.
  int get pointCount => _pointCount;

  /// Draws constraint labels to provide visual feedback during drag.
  void _drawConstraintLabels(
    ui.Canvas canvas,
    Rect boundingBox,
    bool isAltPressed,
  ) {
    final labels = <String>[];
    if (isAltPressed) labels.add('From Center');
    labels.add('$_pointCount points');

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

    // Draw label above the star
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
