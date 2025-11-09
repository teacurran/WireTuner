import 'package:freezed_annotation/freezed_annotation.dart';
import 'dart:math' as math;
import 'point.dart';
import 'anchor.dart';
import 'path.dart';

part 'shape.freezed.dart';
part 'shape.g.dart';

/// Defines the type of parametric shape.
enum ShapeKind {
  /// Rectangle with optional rounded corners.
  rectangle,

  /// Ellipse (or circle when width equals height).
  ellipse,

  /// Regular polygon with configurable number of sides.
  polygon,

  /// Star shape with inner and outer radii.
  star,
}

/// An immutable parametric shape defined by geometric parameters.
///
/// Shapes are stored in parametric form to enable intuitive editing:
/// - Rectangle width/height can be resized without recreating all anchors
/// - Star point count can be adjusted dynamically
/// - Ellipses maintain perfect circular symmetry
///
/// Call [toPath] to generate the explicit Path representation for rendering
/// or geometric operations.
///
/// ## Invariants
///
/// 1. **Positive Dimensions**: width, height, radius, innerRadius must be positive
/// 2. **Corner Radius Bounds**: For rectangles, cornerRadius ≤ min(width/2, height/2)
/// 3. **Star Radii Ordering**: For stars, innerRadius < outerRadius
/// 4. **Minimum Sides**: Polygons and stars require sides ≥ 3
///
/// ## Example
///
/// ```dart
/// final rect = Shape.rectangle(
///   center: Point(x: 100, y: 100),
///   width: 200,
///   height: 150,
///   cornerRadius: 10,
/// );
///
/// // Convert to path for rendering
/// final path = rect.toPath();
/// ```
@freezed
class Shape with _$Shape {
  const Shape._();

  /// Creates a shape with the given properties.
  ///
  /// Use the factory constructors ([rectangle], [ellipse], [polygon], [star])
  /// for type-safe shape creation with appropriate defaults.
  const factory Shape({
    required Point center,
    required ShapeKind kind,
    double? width,
    double? height,
    @Default(0.0) double cornerRadius,
    double? radius,
    double? innerRadius,
    @Default(5) int sides,
    @Default(0.0) double rotation,
  }) = _Shape;

  /// Creates a rectangle shape.
  factory Shape.rectangle({
    required Point center,
    required double width,
    required double height,
    double cornerRadius = 0.0,
    double rotation = 0.0,
  }) {
    return Shape(
      center: center,
      kind: ShapeKind.rectangle,
      width: width,
      height: height,
      cornerRadius: cornerRadius,
      rotation: rotation,
    );
  }

  /// Creates an ellipse shape.
  factory Shape.ellipse({
    required Point center,
    required double width,
    required double height,
    double rotation = 0.0,
  }) {
    return Shape(
      center: center,
      kind: ShapeKind.ellipse,
      width: width,
      height: height,
      rotation: rotation,
    );
  }

  /// Creates a circle shape.
  factory Shape.circle({
    required Point center,
    required double radius,
  }) {
    return Shape(
      center: center,
      kind: ShapeKind.ellipse,
      width: radius * 2,
      height: radius * 2,
    );
  }

  /// Creates a regular polygon shape.
  factory Shape.polygon({
    required Point center,
    required double radius,
    int sides = 5,
    double rotation = 0.0,
  }) {
    return Shape(
      center: center,
      kind: ShapeKind.polygon,
      radius: radius,
      sides: sides,
      rotation: rotation,
    );
  }

  /// Creates a star shape.
  factory Shape.star({
    required Point center,
    required double outerRadius,
    required double innerRadius,
    int pointCount = 5,
    double rotation = 0.0,
  }) {
    return Shape(
      center: center,
      kind: ShapeKind.star,
      radius: outerRadius,
      innerRadius: innerRadius,
      sides: pointCount,
      rotation: rotation,
    );
  }

  /// Deserializes a shape from JSON.
  factory Shape.fromJson(Map<String, dynamic> json) => _$ShapeFromJson(json);

  /// Converts this parametric shape to an explicit Path.
  ///
  /// The generated path is closed and composed of anchors and segments
  /// that approximate the shape's geometry.
  Path toPath() {
    switch (kind) {
      case ShapeKind.rectangle:
        return _rectangleToPath();
      case ShapeKind.ellipse:
        return _ellipseToPath();
      case ShapeKind.polygon:
        return _polygonToPath();
      case ShapeKind.star:
        return _starToPath();
    }
  }

  // ========== Rectangle to Path ==========

  Path _rectangleToPath() {
    final w = width!;
    final h = height!;
    final r = cornerRadius.clamp(0.0, math.min(w / 2, h / 2)).toDouble();

    // If no corner radius, create simple rectangle
    if (r == 0.0) {
      return _simpleRectanglePath(w, h);
    }

    // Create rounded rectangle with Bezier curves
    return _roundedRectanglePath(w, h, r);
  }

  Path _simpleRectanglePath(double w, double h) {
    final halfW = w / 2;
    final halfH = h / 2;

    // Create corner points in local space
    final corners = [
      Point(x: -halfW, y: -halfH), // Top-left
      Point(x: halfW, y: -halfH), // Top-right
      Point(x: halfW, y: halfH), // Bottom-right
      Point(x: -halfW, y: halfH), // Bottom-left
    ];

    // Transform to world space (rotate + translate)
    final anchors = corners
        .map((p) => AnchorPoint.corner(
              position: p.rotate(rotation) + center,
            ))
        .toList();

    return Path.fromAnchors(anchors: anchors, closed: true);
  }

  Path _roundedRectanglePath(double w, double h, double r) {
    final halfW = w / 2;
    final halfH = h / 2;

    // Bezier control point offset for circular arc approximation
    // Magic constant: 4/3 * tan(π/8) ≈ 0.5522847498
    final kappa = 0.5522847498;
    final handleOffset = r * kappa;

    // Create anchors for each corner (4 corners × 2 anchors = 8 total)
    // Each corner has two anchors with handles for smooth curves

    final anchors = <AnchorPoint>[];

    // Top edge (left to right)
    anchors.add(AnchorPoint(
      position: Point(x: -halfW + r, y: -halfH),
      handleIn: Point(x: -handleOffset, y: 0),
      anchorType: AnchorType.symmetric,
    ));
    anchors.add(AnchorPoint(
      position: Point(x: halfW - r, y: -halfH),
      handleOut: Point(x: handleOffset, y: 0),
      anchorType: AnchorType.symmetric,
    ));

    // Top-right corner
    anchors.add(AnchorPoint(
      position: Point(x: halfW, y: -halfH + r),
      handleIn: Point(x: 0, y: -handleOffset),
      anchorType: AnchorType.symmetric,
    ));

    // Right edge (top to bottom)
    anchors.add(AnchorPoint(
      position: Point(x: halfW, y: halfH - r),
      handleOut: Point(x: 0, y: handleOffset),
      anchorType: AnchorType.symmetric,
    ));

    // Bottom-right corner
    anchors.add(AnchorPoint(
      position: Point(x: halfW - r, y: halfH),
      handleIn: Point(x: handleOffset, y: 0),
      anchorType: AnchorType.symmetric,
    ));

    // Bottom edge (right to left)
    anchors.add(AnchorPoint(
      position: Point(x: -halfW + r, y: halfH),
      handleOut: Point(x: -handleOffset, y: 0),
      anchorType: AnchorType.symmetric,
    ));

    // Bottom-left corner
    anchors.add(AnchorPoint(
      position: Point(x: -halfW, y: halfH - r),
      handleIn: Point(x: 0, y: handleOffset),
      anchorType: AnchorType.symmetric,
    ));

    // Left edge (bottom to top)
    anchors.add(AnchorPoint(
      position: Point(x: -halfW, y: -halfH + r),
      handleOut: Point(x: 0, y: -handleOffset),
      anchorType: AnchorType.symmetric,
    ));

    // Transform to world space
    final transformedAnchors = anchors
        .map((a) => a.copyWith(
              position: a.position.rotate(rotation) + center,
              handleIn: a.handleIn?.rotate(rotation),
              handleOut: a.handleOut?.rotate(rotation),
            ))
        .toList();

    return Path.fromAnchors(anchors: transformedAnchors, closed: true);
  }

  // ========== Ellipse to Path ==========

  Path _ellipseToPath() {
    final w = width!;
    final h = height!;
    final rx = w / 2;
    final ry = h / 2;

    // Bezier control point offset for circular arc approximation
    final kappa = 0.5522847498;
    final handleX = rx * kappa;
    final handleY = ry * kappa;

    // Create 4 anchors for the ellipse (at cardinal points)
    final anchors = [
      // Right (0°)
      AnchorPoint(
        position: Point(x: rx, y: 0),
        handleIn: Point(x: 0, y: -handleY),
        handleOut: Point(x: 0, y: handleY),
        anchorType: AnchorType.smooth,
      ),
      // Bottom (90°)
      AnchorPoint(
        position: Point(x: 0, y: ry),
        handleIn: Point(x: handleX, y: 0),
        handleOut: Point(x: -handleX, y: 0),
        anchorType: AnchorType.smooth,
      ),
      // Left (180°)
      AnchorPoint(
        position: Point(x: -rx, y: 0),
        handleIn: Point(x: 0, y: handleY),
        handleOut: Point(x: 0, y: -handleY),
        anchorType: AnchorType.smooth,
      ),
      // Top (270°)
      AnchorPoint(
        position: Point(x: 0, y: -ry),
        handleIn: Point(x: -handleX, y: 0),
        handleOut: Point(x: handleX, y: 0),
        anchorType: AnchorType.smooth,
      ),
    ];

    // Transform to world space
    final transformedAnchors = anchors
        .map((a) => a.copyWith(
              position: a.position.rotate(rotation) + center,
              handleIn: a.handleIn?.rotate(rotation),
              handleOut: a.handleOut?.rotate(rotation),
            ))
        .toList();

    return Path.fromAnchors(anchors: transformedAnchors, closed: true);
  }

  // ========== Polygon to Path ==========

  Path _polygonToPath() {
    final r = radius!;
    final n = sides;

    if (n < 3) {
      throw ArgumentError('Polygon must have at least 3 sides');
    }

    final anchors = <AnchorPoint>[];
    final angleStep = 2 * math.pi / n;

    for (int i = 0; i < n; i++) {
      final angle = rotation - math.pi / 2 + i * angleStep;
      final x = r * math.cos(angle);
      final y = r * math.sin(angle);

      anchors.add(AnchorPoint.corner(
        position: Point(x: x, y: y) + center,
      ));
    }

    return Path.fromAnchors(anchors: anchors, closed: true);
  }

  // ========== Star to Path ==========

  Path _starToPath() {
    final outerR = radius!;
    final innerR = innerRadius!;
    final n = sides; // Number of points

    if (n < 3) {
      throw ArgumentError('Star must have at least 3 points');
    }

    if (innerR >= outerR) {
      throw ArgumentError('Inner radius must be less than outer radius');
    }

    final anchors = <AnchorPoint>[];
    final angleStep = math.pi / n; // Half the angle between points

    for (int i = 0; i < n * 2; i++) {
      final angle = rotation - math.pi / 2 + i * angleStep;
      final r = i.isEven ? outerR : innerR;
      final x = r * math.cos(angle);
      final y = r * math.sin(angle);

      anchors.add(AnchorPoint.corner(
        position: Point(x: x, y: y) + center,
      ));
    }

    return Path.fromAnchors(anchors: anchors, closed: true);
  }
}
