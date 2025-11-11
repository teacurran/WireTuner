import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Represents a paint style for rendering vector objects.
///
/// PaintStyle encapsulates all visual properties needed to render paths
/// and shapes, including stroke, fill, gradients, and effects.
///
/// ## Design Rationale
///
/// This module centralizes style definitions to:
/// - Separate visual styling from rendering logic
/// - Enable future gradient and effect implementations
/// - Provide clean API for style modifications
/// - Support caching of paint objects for performance
///
/// ## Usage
///
/// ```dart
/// // Create a stroke style
/// final strokeStyle = PaintStyle.stroke(
///   color: Colors.black,
///   width: 2.0,
///   cap: StrokeCap.round,
///   join: StrokeJoin.round,
/// );
///
/// // Create a fill style
/// final fillStyle = PaintStyle.fill(
///   color: Colors.blue.withOpacity(0.5),
/// );
///
/// // Apply to canvas
/// final paint = strokeStyle.toPaint();
/// canvas.drawPath(path, paint);
/// ```
///
/// ## Future Enhancements (I3+)
///
/// - Linear and radial gradients
/// - Pattern fills
/// - Shadow and glow effects
/// - Blend modes
class PaintStyle {
  /// Creates a paint style with the specified properties.
  const PaintStyle({
    required this.type,
    this.color = Colors.black,
    this.strokeWidth = 1.0,
    this.strokeCap = StrokeCap.round,
    this.strokeJoin = StrokeJoin.round,
    this.gradient,
    this.opacity = 1.0,
  });

  /// Creates a stroke-only paint style.
  const PaintStyle.stroke({
    Color color = Colors.black,
    double strokeWidth = 1.0,
    StrokeCap cap = StrokeCap.round,
    StrokeJoin join = StrokeJoin.round,
    double opacity = 1.0,
  }) : this(
          type: PaintStyleType.stroke,
          color: color,
          strokeWidth: strokeWidth,
          strokeCap: cap,
          strokeJoin: join,
          opacity: opacity,
        );

  /// Creates a fill-only paint style.
  const PaintStyle.fill({
    Color color = Colors.black,
    double opacity = 1.0,
  }) : this(
          type: PaintStyleType.fill,
          color: color,
          opacity: opacity,
        );

  /// Creates a stroke-and-fill paint style.
  const PaintStyle.strokeAndFill({
    Color strokeColor = Colors.black,
    Color fillColor = Colors.white,
    double strokeWidth = 1.0,
    StrokeCap cap = StrokeCap.round,
    StrokeJoin join = StrokeJoin.round,
    double opacity = 1.0,
  }) : this(
          type: PaintStyleType.strokeAndFill,
          color: strokeColor,
          strokeWidth: strokeWidth,
          strokeCap: cap,
          strokeJoin: join,
          opacity: opacity,
        );

  /// The type of paint style (stroke, fill, or both).
  final PaintStyleType type;

  /// The color to use for stroke or fill.
  ///
  /// For stroke-and-fill styles, this represents the stroke color.
  /// Fill color should be stored separately (future enhancement).
  final Color color;

  /// The width of strokes in world coordinates.
  ///
  /// This value will be scaled by the viewport zoom when rendered.
  final double strokeWidth;

  /// The cap style for stroke endpoints.
  final StrokeCap strokeCap;

  /// The join style for stroke corners.
  final StrokeJoin strokeJoin;

  /// Optional gradient definition.
  ///
  /// TODO(I3): Implement gradient support for linear and radial fills.
  /// When non-null, this gradient should override the solid color.
  /// Placeholder for future gradient implementation.
  final GradientStyle? gradient;

  /// Opacity of the entire style (0.0 = transparent, 1.0 = opaque).
  final double opacity;

  /// Converts this style to a Flutter Paint object for rendering.
  ///
  /// The returned Paint is configured with all properties from this style.
  /// For stroke-and-fill styles, this returns the stroke paint; call
  /// [toFillPaint] separately to get the fill paint.
  ui.Paint toPaint() {
    final paint = ui.Paint();

    // Apply color with opacity
    paint.color = color.withOpacity(color.opacity * opacity);

    // Configure stroke or fill
    switch (type) {
      case PaintStyleType.stroke:
      case PaintStyleType.strokeAndFill:
        paint.style = PaintingStyle.stroke;
        paint.strokeWidth = strokeWidth;
        paint.strokeCap = strokeCap;
        paint.strokeJoin = strokeJoin;
        break;
      case PaintStyleType.fill:
        paint.style = PaintingStyle.fill;
        break;
    }

    // TODO(I3): Apply gradient shader when gradient is non-null
    if (gradient != null) {
      // Placeholder for gradient implementation
      // paint.shader = gradient!.toShader(bounds);
    }

    return paint;
  }

  /// Returns a Paint configured for fill rendering.
  ///
  /// Only applicable for strokeAndFill styles. For other types, returns
  /// the same as [toPaint].
  ui.Paint toFillPaint({Color? fillColor}) {
    if (type != PaintStyleType.strokeAndFill) {
      return toPaint();
    }

    final paint = ui.Paint();
    paint.style = PaintingStyle.fill;
    paint.color = (fillColor ?? Colors.white).withOpacity(opacity);

    // TODO(I3): Apply fill gradient if specified
    if (gradient != null) {
      // paint.shader = gradient!.toShader(bounds);
    }

    return paint;
  }

  /// Creates a copy of this style with modified properties.
  PaintStyle copyWith({
    PaintStyleType? type,
    Color? color,
    double? strokeWidth,
    StrokeCap? strokeCap,
    StrokeJoin? strokeJoin,
    GradientStyle? gradient,
    double? opacity,
  }) {
    return PaintStyle(
      type: type ?? this.type,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      strokeCap: strokeCap ?? this.strokeCap,
      strokeJoin: strokeJoin ?? this.strokeJoin,
      gradient: gradient ?? this.gradient,
      opacity: opacity ?? this.opacity,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PaintStyle &&
        other.type == type &&
        other.color == color &&
        other.strokeWidth == strokeWidth &&
        other.strokeCap == strokeCap &&
        other.strokeJoin == strokeJoin &&
        other.gradient == gradient &&
        other.opacity == opacity;
  }

  @override
  int get hashCode => Object.hash(
        type,
        color,
        strokeWidth,
        strokeCap,
        strokeJoin,
        gradient,
        opacity,
      );
}

/// Type of paint style.
enum PaintStyleType {
  /// Stroke only (outline).
  stroke,

  /// Fill only (interior).
  fill,

  /// Both stroke and fill.
  strokeAndFill,
}

/// Gradient style definition.
///
/// TODO(I3): Implement full gradient support with linear, radial, and sweep types.
/// This is a placeholder interface to scaffold the API for future use.
///
/// ## Future Implementation
///
/// ```dart
/// // Linear gradient
/// final gradient = GradientStyle.linear(
///   start: Point(0, 0),
///   end: Point(100, 100),
///   colors: [Colors.red, Colors.blue],
///   stops: [0.0, 1.0],
/// );
///
/// // Radial gradient
/// final gradient = GradientStyle.radial(
///   center: Point(50, 50),
///   radius: 50,
///   colors: [Colors.white, Colors.black],
/// );
/// ```
abstract class GradientStyle {
  const GradientStyle();

  /// TODO(I3): Convert gradient to a Flutter Shader.
  ///
  /// The [bounds] parameter provides the bounding box of the object
  /// being rendered, which is needed for gradient coordinate mapping.
  ///
  /// Example implementation:
  /// ```dart
  /// ui.Shader toShader(Rect bounds) {
  ///   return ui.Gradient.linear(
  ///     Offset(bounds.left, bounds.top),
  ///     Offset(bounds.right, bounds.bottom),
  ///     colors,
  ///     stops,
  ///   );
  /// }
  /// ```
  ui.Shader? toShader(Rect bounds);
}

/// Linear gradient style (placeholder).
///
/// TODO(I3): Implement linear gradient with start/end points and color stops.
class LinearGradientStyle extends GradientStyle {
  const LinearGradientStyle({
    required this.colors,
    this.stops,
  });

  final List<Color> colors;
  final List<double>? stops;

  @override
  ui.Shader? toShader(Rect bounds) {
    // TODO(I3): Implement linear gradient shader creation
    // For now, return null to fall back to solid color
    return null;
  }
}

/// Radial gradient style (placeholder).
///
/// TODO(I3): Implement radial gradient with center, radius, and color stops.
class RadialGradientStyle extends GradientStyle {
  const RadialGradientStyle({
    required this.colors,
    this.stops,
  });

  final List<Color> colors;
  final List<double>? stops;

  @override
  ui.Shader? toShader(Rect bounds) {
    // TODO(I3): Implement radial gradient shader creation
    // For now, return null to fall back to solid color
    return null;
  }
}
