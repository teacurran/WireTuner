import 'dart:math' as math;

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/models/anchor_point.dart' as ap;
import 'package:wiretuner/domain/models/geometry/point_extensions.dart';
import 'package:wiretuner/domain/models/path.dart';
import 'package:wiretuner/domain/models/segment.dart';

part 'shape.freezed.dart';
part 'shape.g.dart';

/// Type of parametric shape.
///
/// Defines the geometric primitive that will be used to generate
/// the shape's path representation.
enum ShapeKind {
  /// Rectangle with optional corner radius.
  rectangle,

  /// Ellipse (or circle when width equals height).
  ellipse,

  /// Regular polygon with configurable number of sides.
  polygon,

  /// Star shape with inner and outer radii.
  star,
}

/// Represents an immutable parametric shape.
///
/// A shape is a geometric primitive (rectangle, ellipse, polygon, or star)
/// defined by a set of parameters rather than explicit anchor points.
/// The shape can be converted to a [Path] for rendering and editing.
///
/// ## Design Rationale
///
/// Shapes are stored in parametric form to enable intuitive editing.
/// For example:
/// - A rectangle can be resized by changing width/height
/// - A star can adjust point count without recreating all anchors
/// - An ellipse maintains its perfect circular nature
///
/// When rendering or performing geometric operations, shapes are converted
/// to paths using [toPath()].
///
/// ## Immutability & Freezed
///
/// This class uses Freezed for:
/// - Automatic immutability enforcement
/// - copyWith method generation
/// - Deep equality comparison
/// - JSON serialization support
///
/// ## Examples
///
/// Create a rectangle:
/// ```dart
/// final rect = Shape.rectangle(
///   center: Point(x: 50, y: 50),
///   width: 100,
///   height: 60,
/// );
/// ```
///
/// Create a star:
/// ```dart
/// final star = Shape.star(
///   center: Point(x: 100, y: 100),
///   outerRadius: 50,
///   innerRadius: 25,
///   pointCount: 5,
/// );
/// ```
///
/// Convert to path:
/// ```dart
/// final path = shape.toPath();
/// // Now can be rendered or edited as a path
/// ```
@freezed
class Shape with _$Shape {
  const factory Shape({
    /// The center point of the shape.
    required Point center,

    /// The type of shape.
    required ShapeKind kind,

    /// Width of the shape (for rectangle, ellipse).
    double? width,

    /// Height of the shape (for rectangle, ellipse).
    double? height,

    /// Corner radius for rectangles (0 = sharp corners).
    @Default(0) double cornerRadius,

    /// Radius for regular polygons and stars.
    double? radius,

    /// Inner radius for stars (distance from center to inner points).
    double? innerRadius,

    /// Number of sides for polygons, or points for stars.
    @Default(5) int sides,

    /// Rotation angle in radians.
    @Default(0) double rotation,
  }) = _Shape;

  /// Private constructor for accessing methods on Freezed class.
  const Shape._();

  /// Creates a Shape from JSON.
  factory Shape.fromJson(Map<String, dynamic> json) => _$ShapeFromJson(json);

  /// Creates a rectangle shape.
  ///
  /// Parameters:
  /// - [center]: The center point of the rectangle
  /// - [width]: The width of the rectangle
  /// - [height]: The height of the rectangle
  /// - [cornerRadius]: Optional corner radius (default 0)
  /// - [rotation]: Optional rotation in radians (default 0)
  ///
  /// Example:
  /// ```dart
  /// final rect = Shape.rectangle(
  ///   center: Point(x: 100, y: 100),
  ///   width: 200,
  ///   height: 150,
  ///   cornerRadius: 10,
  /// );
  /// ```
  factory Shape.rectangle({
    required Point center,
    required double width,
    required double height,
    double cornerRadius = 0,
    double rotation = 0,
  }) {
    assert(width > 0, 'Width must be positive');
    assert(height > 0, 'Height must be positive');
    assert(cornerRadius >= 0, 'Corner radius must be non-negative');
    assert(
      cornerRadius <= width / 2 && cornerRadius <= height / 2,
      'Corner radius must not exceed half of width or height',
    );

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
  ///
  /// Parameters:
  /// - [center]: The center point of the ellipse
  /// - [width]: The width (horizontal diameter) of the ellipse
  /// - [height]: The height (vertical diameter) of the ellipse
  /// - [rotation]: Optional rotation in radians (default 0)
  ///
  /// Example:
  /// ```dart
  /// final ellipse = Shape.ellipse(
  ///   center: Point(x: 100, y: 100),
  ///   width: 200,
  ///   height: 100,
  /// );
  /// ```
  factory Shape.ellipse({
    required Point center,
    required double width,
    required double height,
    double rotation = 0,
  }) {
    assert(width > 0, 'Width must be positive');
    assert(height > 0, 'Height must be positive');

    return Shape(
      center: center,
      kind: ShapeKind.ellipse,
      width: width,
      height: height,
      rotation: rotation,
    );
  }

  /// Creates a regular polygon shape.
  ///
  /// Parameters:
  /// - [center]: The center point of the polygon
  /// - [radius]: Distance from center to vertices
  /// - [sides]: Number of sides (minimum 3)
  /// - [rotation]: Optional rotation in radians (default 0)
  ///
  /// Example:
  /// ```dart
  /// final hexagon = Shape.polygon(
  ///   center: Point(x: 100, y: 100),
  ///   radius: 50,
  ///   sides: 6,
  /// );
  /// ```
  factory Shape.polygon({
    required Point center,
    required double radius,
    int sides = 5,
    double rotation = 0,
  }) {
    assert(radius > 0, 'Radius must be positive');
    assert(sides >= 3, 'Polygon must have at least 3 sides');

    return Shape(
      center: center,
      kind: ShapeKind.polygon,
      radius: radius,
      sides: sides,
      rotation: rotation,
    );
  }

  /// Creates a star shape.
  ///
  /// Parameters:
  /// - [center]: The center point of the star
  /// - [outerRadius]: Distance from center to outer points
  /// - [innerRadius]: Distance from center to inner points
  /// - [pointCount]: Number of star points (minimum 3)
  /// - [rotation]: Optional rotation in radians (default 0)
  ///
  /// Example:
  /// ```dart
  /// final star = Shape.star(
  ///   center: Point(x: 100, y: 100),
  ///   outerRadius: 60,
  ///   innerRadius: 30,
  ///   pointCount: 5,
  /// );
  /// ```
  factory Shape.star({
    required Point center,
    required double outerRadius,
    required double innerRadius,
    int pointCount = 5,
    double rotation = 0,
  }) {
    assert(outerRadius > 0, 'Outer radius must be positive');
    assert(innerRadius > 0, 'Inner radius must be positive');
    assert(
      innerRadius < outerRadius,
      'Inner radius must be less than outer radius',
    );
    assert(pointCount >= 3, 'Star must have at least 3 points');

    return Shape(
      center: center,
      kind: ShapeKind.star,
      radius: outerRadius,
      innerRadius: innerRadius,
      sides: pointCount,
      rotation: rotation,
    );
  }

  /// Converts this shape to a [Path] representation.
  ///
  /// The generated path is closed and consists of line segments connecting
  /// anchor points. For rectangles with corner radius and ellipses, the path
  /// uses Bezier curves to approximate rounded corners and circular arcs.
  ///
  /// Returns a [Path] that can be rendered or edited.
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

  /// Converts rectangle to path.
  Path _rectangleToPath() {
    final w = width!;
    final h = height!;
    final r = cornerRadius;

    // Calculate corner points relative to center
    final left = center.x - w / 2;
    final right = center.x + w / 2;
    final top = center.y - h / 2;
    final bottom = center.y + h / 2;

    if (r == 0) {
      // Sharp corners - simple rectangle
      final anchors = [
        ap.AnchorPoint.corner(_rotatePoint(Point(x: left, y: top))),
        ap.AnchorPoint.corner(_rotatePoint(Point(x: right, y: top))),
        ap.AnchorPoint.corner(_rotatePoint(Point(x: right, y: bottom))),
        ap.AnchorPoint.corner(_rotatePoint(Point(x: left, y: bottom))),
      ];

      return Path.fromAnchors(anchors: anchors, closed: true);
    } else {
      // Rounded corners using Bezier approximation
      // Create 4 corner arcs, each with smooth anchor points
      final anchors = <ap.AnchorPoint>[];
      final segments = <Segment>[];

      // Bezier control point distance for 90-degree arc approximation
      // Magic constant: 4/3 * tan(π/8) ≈ 0.5522847498
      const kappa = 0.5522847498;
      final handleDistance = r * kappa;

      // Top-right corner arc
      anchors.add(ap.AnchorPoint(
        position: _rotatePoint(Point(x: right - r, y: top)),
        handleOut: Point(x: handleDistance, y: 0),
        anchorType: ap.AnchorType.smooth,
      ));
      anchors.add(ap.AnchorPoint(
        position: _rotatePoint(Point(x: right, y: top + r)),
        handleIn: Point(x: 0, y: -handleDistance),
        anchorType: ap.AnchorType.smooth,
      ));

      // Bottom-right corner arc
      anchors.add(ap.AnchorPoint(
        position: _rotatePoint(Point(x: right, y: bottom - r)),
        handleOut: Point(x: 0, y: handleDistance),
        anchorType: ap.AnchorType.smooth,
      ));
      anchors.add(ap.AnchorPoint(
        position: _rotatePoint(Point(x: right - r, y: bottom)),
        handleIn: Point(x: handleDistance, y: 0),
        anchorType: ap.AnchorType.smooth,
      ));

      // Bottom-left corner arc
      anchors.add(ap.AnchorPoint(
        position: _rotatePoint(Point(x: left + r, y: bottom)),
        handleOut: Point(x: -handleDistance, y: 0),
        anchorType: ap.AnchorType.smooth,
      ));
      anchors.add(ap.AnchorPoint(
        position: _rotatePoint(Point(x: left, y: bottom - r)),
        handleIn: Point(x: 0, y: handleDistance),
        anchorType: ap.AnchorType.smooth,
      ));

      // Top-left corner arc
      anchors.add(ap.AnchorPoint(
        position: _rotatePoint(Point(x: left, y: top + r)),
        handleOut: Point(x: 0, y: -handleDistance),
        anchorType: ap.AnchorType.smooth,
      ));
      anchors.add(ap.AnchorPoint(
        position: _rotatePoint(Point(x: left + r, y: top)),
        handleIn: Point(x: -handleDistance, y: 0),
        anchorType: ap.AnchorType.smooth,
      ));

      // Create segments connecting anchors
      for (int i = 0; i < anchors.length; i++) {
        segments.add(Segment.bezier(
          startIndex: i,
          endIndex: (i + 1) % anchors.length,
        ));
      }

      return Path(anchors: anchors, segments: segments, closed: true);
    }
  }

  /// Converts ellipse to path using Bezier approximation.
  Path _ellipseToPath() {
    final w = width!;
    final h = height!;

    // Use 4 Bezier curves to approximate a circle/ellipse
    // Each curve handles a 90-degree arc
    const kappa = 0.5522847498; // 4/3 * tan(π/8)

    final rx = w / 2; // Horizontal radius
    final ry = h / 2; // Vertical radius
    final handleX = rx * kappa;
    final handleY = ry * kappa;

    final anchors = [
      // Right point (0°)
      ap.AnchorPoint(
        position: _rotatePoint(Point(x: center.x + rx, y: center.y)),
        handleIn: Point(x: 0, y: -handleY),
        handleOut: Point(x: 0, y: handleY),
        anchorType: ap.AnchorType.smooth,
      ),
      // Bottom point (90°)
      ap.AnchorPoint(
        position: _rotatePoint(Point(x: center.x, y: center.y + ry)),
        handleIn: Point(x: handleX, y: 0),
        handleOut: Point(x: -handleX, y: 0),
        anchorType: ap.AnchorType.smooth,
      ),
      // Left point (180°)
      ap.AnchorPoint(
        position: _rotatePoint(Point(x: center.x - rx, y: center.y)),
        handleIn: Point(x: 0, y: handleY),
        handleOut: Point(x: 0, y: -handleY),
        anchorType: ap.AnchorType.smooth,
      ),
      // Top point (270°)
      ap.AnchorPoint(
        position: _rotatePoint(Point(x: center.x, y: center.y - ry)),
        handleIn: Point(x: -handleX, y: 0),
        handleOut: Point(x: handleX, y: 0),
        anchorType: ap.AnchorType.smooth,
      ),
    ];

    final segments = [
      Segment.bezier(startIndex: 0, endIndex: 1),
      Segment.bezier(startIndex: 1, endIndex: 2),
      Segment.bezier(startIndex: 2, endIndex: 3),
      Segment.bezier(startIndex: 3, endIndex: 0),
    ];

    return Path(anchors: anchors, segments: segments, closed: true);
  }

  /// Converts regular polygon to path.
  Path _polygonToPath() {
    final r = radius!;
    final n = sides;

    final anchors = <ap.AnchorPoint>[];

    for (int i = 0; i < n; i++) {
      // Calculate angle for this vertex
      // Start from top (270° / -π/2) and go clockwise
      final angle = rotation - math.pi / 2 + (2 * math.pi * i / n);
      final x = center.x + r * math.cos(angle);
      final y = center.y + r * math.sin(angle);

      anchors.add(ap.AnchorPoint.corner(Point(x: x, y: y)));
    }

    return Path.fromAnchors(anchors: anchors, closed: true);
  }

  /// Converts star to path.
  Path _starToPath() {
    final outerR = radius!;
    final innerR = innerRadius!;
    final n = sides;

    final anchors = <ap.AnchorPoint>[];

    // Star has 2n vertices (alternating outer and inner points)
    for (int i = 0; i < 2 * n; i++) {
      final isOuter = i % 2 == 0;
      final r = isOuter ? outerR : innerR;

      // Calculate angle for this vertex
      // Start from top (270° / -π/2) and go clockwise
      final angle = rotation - math.pi / 2 + (math.pi * i / n);
      final x = center.x + r * math.cos(angle);
      final y = center.y + r * math.sin(angle);

      anchors.add(ap.AnchorPoint.corner(Point(x: x, y: y)));
    }

    return Path.fromAnchors(anchors: anchors, closed: true);
  }

  /// Rotates a point around the shape's center by the rotation angle.
  Point _rotatePoint(Point point) {
    if (rotation == 0) return point;

    // Translate to origin
    final translated = point - center;

    // Rotate
    final cos = math.cos(rotation);
    final sin = math.sin(rotation);
    final rotated = Point(
      x: translated.x * cos - translated.y * sin,
      y: translated.x * sin + translated.y * cos,
    );

    // Translate back
    return rotated + center;
  }
}
