import 'package:freezed_annotation/freezed_annotation.dart';
import 'point.dart';
import 'dart:math' as math;

part 'bounds.freezed.dart';
part 'bounds.g.dart';

/// An immutable axis-aligned bounding box (AABB) in 2D space.
///
/// Bounds represent rectangular regions defined by minimum and maximum
/// coordinates. They are used for hit testing, viewport culling, and
/// geometric calculations.
///
/// ## Example
///
/// ```dart
/// final bounds = Bounds.fromLTRB(
///   left: 50,
///   top: 50,
///   right: 250,
///   bottom: 150,
/// );
/// print(bounds.width);   // 200
/// print(bounds.height);  // 100
/// print(bounds.center);  // Point(x: 150, y: 100)
/// ```
@freezed
class Bounds with _$Bounds {
  const Bounds._();

  /// Creates bounds from minimum and maximum points.
  ///
  /// [min] is the top-left corner, [max] is the bottom-right corner.
  const factory Bounds({
    required Point min,
    required Point max,
  }) = _Bounds;

  /// Creates bounds from left, top, right, and bottom coordinates.
  factory Bounds.fromLTRB({
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) {
    return Bounds(
      min: Point(x: left, y: top),
      max: Point(x: right, y: bottom),
    );
  }

  /// Creates bounds from center point and size.
  factory Bounds.fromCenter({
    required Point center,
    required double width,
    required double height,
  }) {
    final halfWidth = width / 2;
    final halfHeight = height / 2;
    return Bounds(
      min: Point(x: center.x - halfWidth, y: center.y - halfHeight),
      max: Point(x: center.x + halfWidth, y: center.y + halfHeight),
    );
  }

  /// Creates bounds from a list of points.
  ///
  /// Returns null if the list is empty.
  factory Bounds.fromPoints(List<Point> points) {
    if (points.isEmpty) {
      throw ArgumentError('Cannot create bounds from empty point list');
    }

    double minX = points.first.x;
    double minY = points.first.y;
    double maxX = points.first.x;
    double maxY = points.first.y;

    for (final point in points.skip(1)) {
      minX = math.min(minX, point.x);
      minY = math.min(minY, point.y);
      maxX = math.max(maxX, point.x);
      maxY = math.max(maxY, point.y);
    }

    return Bounds(
      min: Point(x: minX, y: minY),
      max: Point(x: maxX, y: maxY),
    );
  }

  /// Creates an empty bounds at the origin.
  factory Bounds.zero() => Bounds(
        min: Point.zero(),
        max: Point.zero(),
      );

  /// Deserializes bounds from JSON.
  factory Bounds.fromJson(Map<String, dynamic> json) => _$BoundsFromJson(json);

  /// The left edge x-coordinate.
  double get left => min.x;

  /// The top edge y-coordinate.
  double get top => min.y;

  /// The right edge x-coordinate.
  double get right => max.x;

  /// The bottom edge y-coordinate.
  double get bottom => max.y;

  /// The width of the bounds.
  double get width => max.x - min.x;

  /// The height of the bounds.
  double get height => max.y - min.y;

  /// The center point of the bounds.
  Point get center => Point(
        x: (min.x + max.x) / 2,
        y: (min.y + max.y) / 2,
      );

  /// The top-left corner point.
  Point get topLeft => min;

  /// The top-right corner point.
  Point get topRight => Point(x: max.x, y: min.y);

  /// The bottom-left corner point.
  Point get bottomLeft => Point(x: min.x, y: max.y);

  /// The bottom-right corner point.
  Point get bottomRight => max;

  /// The area of the bounds.
  double get area => width * height;

  /// Returns true if the bounds have zero area.
  bool get isEmpty => width == 0 || height == 0;

  /// Returns true if the bounds have non-zero area.
  bool get isNotEmpty => !isEmpty;

  /// Returns true if this bounds contains the given point.
  bool containsPoint(Point point) {
    return point.x >= min.x &&
        point.x <= max.x &&
        point.y >= min.y &&
        point.y <= max.y;
  }

  /// Returns true if this bounds fully contains another bounds.
  bool containsBounds(Bounds other) {
    return other.min.x >= min.x &&
        other.max.x <= max.x &&
        other.min.y >= min.y &&
        other.max.y <= max.y;
  }

  /// Returns true if this bounds intersects another bounds.
  bool intersects(Bounds other) {
    return !(other.min.x > max.x ||
        other.max.x < min.x ||
        other.min.y > max.y ||
        other.max.y < min.y);
  }

  /// Returns the intersection of this bounds with another bounds.
  ///
  /// Returns null if the bounds don't intersect.
  Bounds? intersection(Bounds other) {
    if (!intersects(other)) return null;

    return Bounds(
      min: Point(
        x: math.max(min.x, other.min.x),
        y: math.max(min.y, other.min.y),
      ),
      max: Point(
        x: math.min(max.x, other.max.x),
        y: math.min(max.y, other.max.y),
      ),
    );
  }

  /// Returns the union of this bounds with another bounds.
  ///
  /// The union is the smallest bounds that contains both bounds.
  Bounds union(Bounds other) {
    return Bounds(
      min: Point(
        x: math.min(min.x, other.min.x),
        y: math.min(min.y, other.min.y),
      ),
      max: Point(
        x: math.max(max.x, other.max.x),
        y: math.max(max.y, other.max.y),
      ),
    );
  }

  /// Expands the bounds by the given amount in all directions.
  Bounds expand(double amount) {
    return Bounds(
      min: Point(x: min.x - amount, y: min.y - amount),
      max: Point(x: max.x + amount, y: max.y + amount),
    );
  }

  /// Expands the bounds to include the given point.
  Bounds expandToInclude(Point point) {
    return Bounds(
      min: Point(
        x: math.min(min.x, point.x),
        y: math.min(min.y, point.y),
      ),
      max: Point(
        x: math.max(max.x, point.x),
        y: math.max(max.y, point.y),
      ),
    );
  }

  /// Expands the bounds to include another bounds.
  Bounds expandToIncludeBounds(Bounds other) {
    return union(other);
  }

  /// Translates the bounds by the given offset.
  Bounds translate(Point offset) {
    return Bounds(
      min: min + offset,
      max: max + offset,
    );
  }

  /// Scales the bounds by the given factors around the origin.
  Bounds scale(double sx, double sy) {
    return Bounds(
      min: Point(x: min.x * sx, y: min.y * sy),
      max: Point(x: max.x * sx, y: max.y * sy),
    );
  }

  /// Scales the bounds uniformly by the given factor around the origin.
  Bounds uniformScale(double scale) => this.scale(scale, scale);

  /// Returns the distance from a point to the nearest edge of the bounds.
  ///
  /// Returns 0 if the point is inside the bounds.
  /// Returns negative value if point is inside (distance to nearest edge).
  double distanceToPoint(Point point) {
    if (containsPoint(point)) {
      // Point is inside, return negative distance to nearest edge
      final dx = math.min(point.x - min.x, max.x - point.x);
      final dy = math.min(point.y - min.y, max.y - point.y);
      return -math.min(dx, dy);
    }

    // Point is outside, calculate distance to nearest edge
    final dx = math.max(0.0, math.max(min.x - point.x, point.x - max.x));
    final dy = math.max(0.0, math.max(min.y - point.y, point.y - max.y));
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Returns the four corner points in clockwise order starting from top-left.
  List<Point> get corners => [topLeft, topRight, bottomRight, bottomLeft];

  @override
  String toString() =>
      'Bounds(left: $left, top: $top, right: $right, bottom: $bottom)';
}
