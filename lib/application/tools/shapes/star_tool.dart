import 'dart:math' show cos, max, min, pi, sin, sqrt;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
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
  /// Using 0.38 for a more pronounced star shape that works at all sizes.
  static const double _defaultInnerRadiusRatio = 0.38;
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
    // The star should fit exactly in the bounding box
    // We'll create a star with radius 1 and then scale it to fit
    final center = Point(
      x: boundingBox.center.dx,
      y: boundingBox.center.dy,
    );

    // Calculate scaling factors for width and height
    final scaleX = boundingBox.width / 2;
    final scaleY = boundingBox.height / 2;

    // Create star points scaled to fit the bounding box exactly
    final outerRadius = 1.0; // Unit circle
    final innerRadius = outerRadius * _innerRadiusRatio;

    // Create the star path manually with proper scaling
    final flutterPath = ui.Path();

    // Generate star points
    final totalPoints = _pointCount * 2; // Alternating outer and inner points
    for (int i = 0; i < totalPoints; i++) {
      final isOuter = i % 2 == 0;
      final r = isOuter ? outerRadius : innerRadius;

      // Calculate angle (start from top, go clockwise)
      final angle = -pi / 2 + (2 * pi * i / totalPoints);

      // Calculate point position with non-uniform scaling
      final x = center.x + r * cos(angle) * scaleX;
      final y = center.y + r * sin(angle) * scaleY;

      if (i == 0) {
        flutterPath.moveTo(x, y);
      } else {
        flutterPath.lineTo(x, y);
      }
    }

    flutterPath.close();

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
    // Inner radius is typically 38% of outer radius for classic star appearance
    final unitInnerRadius = 0.38;

    // Store the actual bounding box parameters
    // We'll create the shape at origin and use transform to position and scale it
    return {
      'centerX': 0.0, // Shape at origin
      'centerY': 0.0,
      'outerRadius': 1.0, // Unit radius, will be scaled by transform
      'innerRadius': unitInnerRadius,
      'points': max(_pointCount, 3).toDouble(), // Must be 'points' not 'sides'
      'rotation': 0.0,
      // Store bounding box for transform calculation
      'boundingLeft': boundingBox.left,
      'boundingTop': boundingBox.top,
      'boundingWidth': boundingBox.width,
      'boundingHeight': boundingBox.height,
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

  /// Calculates dynamic inner radius ratio based on star size.
  ///
  /// Smaller stars need smaller inner radius for sharper points,
  /// while larger stars can have larger inner radius for better proportions.
  double _calculateDynamicInnerRadiusRatio(double outerRadius) {
    // For very small stars (< 20px), use smaller ratio for sharper points
    if (outerRadius < 20) {
      return 0.3;
    }
    // For small to medium stars (20-50px), gradually increase ratio
    if (outerRadius < 50) {
      return 0.3 + (outerRadius - 20) * 0.01; // 0.3 to 0.6
    }
    // For medium to large stars (50-100px), use moderate ratio
    if (outerRadius < 100) {
      return 0.4 + (outerRadius - 50) * 0.002; // 0.4 to 0.5
    }
    // For large stars (>= 100px), use consistent ratio
    return 0.5;
  }
}
