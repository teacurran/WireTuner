import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:wiretuner/domain/events/event_base.dart';

/// Represents an immutable 2D rectangle defined by position and size.
///
/// A rectangle is uniquely defined by its top-left corner ([x], [y]) and
/// its dimensions ([width], [height]). All values are in the document's
/// coordinate space (typically pixels).
///
/// This class is immutable and provides various geometric operations
/// such as intersection, union, and point containment testing.
///
/// Example:
/// ```dart
/// final rect = Rectangle(x: 10, y: 20, width: 100, height: 50);
/// print(rect.right); // 110
/// print(rect.bottom); // 70
/// print(rect.containsPoint(Point(x: 50, y: 40))); // true
/// ```
@immutable
class Rectangle {
  /// The x-coordinate of the rectangle's top-left corner.
  final double x;

  /// The y-coordinate of the rectangle's top-left corner.
  final double y;

  /// The width of the rectangle.
  final double width;

  /// The height of the rectangle.
  final double height;

  /// Creates a rectangle with the specified position and size.
  ///
  /// All parameters are required and must be finite numbers.
  const Rectangle({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// Creates a rectangle from left, top, right, bottom coordinates.
  ///
  /// Example:
  /// ```dart
  /// final rect = Rectangle.fromLTRB(10, 20, 110, 70);
  /// // Same as Rectangle(x: 10, y: 20, width: 100, height: 50)
  /// ```
  factory Rectangle.fromLTRB(
    double left,
    double top,
    double right,
    double bottom,
  ) {
    return Rectangle(
      x: left,
      y: top,
      width: right - left,
      height: bottom - top,
    );
  }

  /// Creates a rectangle from a center point and size.
  ///
  /// Example:
  /// ```dart
  /// final rect = Rectangle.fromCenter(
  ///   center: Point(x: 50, y: 50),
  ///   width: 40,
  ///   height: 30,
  /// );
  /// // Creates rectangle with bounds (30, 35, 70, 65)
  /// ```
  factory Rectangle.fromCenter({
    required Point center,
    required double width,
    required double height,
  }) {
    return Rectangle(
      x: center.x - width / 2,
      y: center.y - height / 2,
      width: width,
      height: height,
    );
  }

  /// Creates a rectangle from two corner points.
  ///
  /// The points can be any two opposite corners.
  ///
  /// Example:
  /// ```dart
  /// final rect = Rectangle.fromPoints(
  ///   Point(x: 10, y: 20),
  ///   Point(x: 110, y: 70),
  /// );
  /// ```
  factory Rectangle.fromPoints(Point p1, Point p2) {
    final left = math.min(p1.x, p2.x);
    final top = math.min(p1.y, p2.y);
    final right = math.max(p1.x, p2.x);
    final bottom = math.max(p1.y, p2.y);
    return Rectangle.fromLTRB(left, top, right, bottom);
  }

  /// The x-coordinate of the left edge (same as [x]).
  double get left => x;

  /// The y-coordinate of the top edge (same as [y]).
  double get top => y;

  /// The x-coordinate of the right edge.
  double get right => x + width;

  /// The y-coordinate of the bottom edge.
  double get bottom => y + height;

  /// The center point of the rectangle.
  Point get center => Point(x: x + width / 2, y: y + height / 2);

  /// The top-left corner point.
  Point get topLeft => Point(x: left, y: top);

  /// The top-right corner point.
  Point get topRight => Point(x: right, y: top);

  /// The bottom-left corner point.
  Point get bottomLeft => Point(x: left, y: bottom);

  /// The bottom-right corner point.
  Point get bottomRight => Point(x: right, y: bottom);

  /// The size of the rectangle as a point (width, height).
  Point get size => Point(x: width, y: height);

  /// Whether this rectangle has a non-zero area.
  bool get hasArea => width > 0 && height > 0;

  /// Whether this rectangle is empty (zero or negative area).
  bool get isEmpty => width <= 0 || height <= 0;

  /// Tests whether a point is inside this rectangle.
  ///
  /// Points on the edge are considered inside.
  ///
  /// Example:
  /// ```dart
  /// final rect = Rectangle(x: 0, y: 0, width: 10, height: 10);
  /// print(rect.containsPoint(Point(x: 5, y: 5))); // true
  /// print(rect.containsPoint(Point(x: 15, y: 5))); // false
  /// print(rect.containsPoint(Point(x: 10, y: 10))); // true (on edge)
  /// ```
  bool containsPoint(Point point) {
    return point.x >= left &&
        point.x <= right &&
        point.y >= top &&
        point.y <= bottom;
  }

  /// Tests whether another rectangle is completely inside this rectangle.
  ///
  /// Example:
  /// ```dart
  /// final outer = Rectangle(x: 0, y: 0, width: 100, height: 100);
  /// final inner = Rectangle(x: 10, y: 10, width: 20, height: 20);
  /// print(outer.containsRectangle(inner)); // true
  /// ```
  bool containsRectangle(Rectangle other) {
    return other.left >= left &&
        other.right <= right &&
        other.top >= top &&
        other.bottom <= bottom;
  }

  /// Returns the intersection of this rectangle with another.
  ///
  /// If the rectangles don't overlap, returns null.
  ///
  /// Example:
  /// ```dart
  /// final r1 = Rectangle(x: 0, y: 0, width: 10, height: 10);
  /// final r2 = Rectangle(x: 5, y: 5, width: 10, height: 10);
  /// final result = r1.intersection(r2);
  /// // result: Rectangle(x: 5, y: 5, width: 5, height: 5)
  /// ```
  Rectangle? intersection(Rectangle other) {
    final newLeft = math.max(left, other.left);
    final newTop = math.max(top, other.top);
    final newRight = math.min(right, other.right);
    final newBottom = math.min(bottom, other.bottom);

    // Check if there's no intersection
    if (newLeft >= newRight || newTop >= newBottom) {
      return null;
    }

    return Rectangle.fromLTRB(newLeft, newTop, newRight, newBottom);
  }

  /// Returns the smallest rectangle that contains both this and another rectangle.
  ///
  /// Example:
  /// ```dart
  /// final r1 = Rectangle(x: 0, y: 0, width: 10, height: 10);
  /// final r2 = Rectangle(x: 5, y: 5, width: 10, height: 10);
  /// final result = r1.union(r2);
  /// // result: Rectangle(x: 0, y: 0, width: 15, height: 15)
  /// ```
  Rectangle union(Rectangle other) {
    final newLeft = math.min(left, other.left);
    final newTop = math.min(top, other.top);
    final newRight = math.max(right, other.right);
    final newBottom = math.max(bottom, other.bottom);

    return Rectangle.fromLTRB(newLeft, newTop, newRight, newBottom);
  }

  /// Tests whether this rectangle overlaps with another.
  ///
  /// Touching edges are not considered overlapping.
  ///
  /// Example:
  /// ```dart
  /// final r1 = Rectangle(x: 0, y: 0, width: 10, height: 10);
  /// final r2 = Rectangle(x: 5, y: 5, width: 10, height: 10);
  /// print(r1.overlaps(r2)); // true
  /// ```
  bool overlaps(Rectangle other) {
    return left < other.right &&
        right > other.left &&
        top < other.bottom &&
        bottom > other.top;
  }

  /// Returns a new rectangle expanded by the specified amount.
  ///
  /// A positive delta expands the rectangle, negative shrinks it.
  /// The expansion is applied equally on all sides.
  ///
  /// Example:
  /// ```dart
  /// final rect = Rectangle(x: 10, y: 10, width: 20, height: 20);
  /// final expanded = rect.inflate(5);
  /// // result: Rectangle(x: 5, y: 5, width: 30, height: 30)
  /// final shrunk = rect.inflate(-5);
  /// // result: Rectangle(x: 15, y: 15, width: 10, height: 10)
  /// ```
  Rectangle inflate(double delta) {
    return Rectangle(
      x: x - delta,
      y: y - delta,
      width: width + delta * 2,
      height: height + delta * 2,
    );
  }

  /// Returns a new rectangle expanded by different amounts on each axis.
  ///
  /// Example:
  /// ```dart
  /// final rect = Rectangle(x: 10, y: 10, width: 20, height: 20);
  /// final expanded = rect.inflateXY(5, 3);
  /// // result: Rectangle(x: 5, y: 7, width: 30, height: 26)
  /// ```
  Rectangle inflateXY(double dx, double dy) {
    return Rectangle(
      x: x - dx,
      y: y - dy,
      width: width + dx * 2,
      height: height + dy * 2,
    );
  }

  /// Returns a new rectangle with the specified offsets applied.
  ///
  /// Example:
  /// ```dart
  /// final rect = Rectangle(x: 10, y: 10, width: 20, height: 20);
  /// final shifted = rect.translate(5, 3);
  /// // result: Rectangle(x: 15, y: 13, width: 20, height: 20)
  /// ```
  Rectangle translate(double dx, double dy) {
    return Rectangle(
      x: x + dx,
      y: y + dy,
      width: width,
      height: height,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Rectangle &&
        other.x == x &&
        other.y == y &&
        other.width == width &&
        other.height == height;
  }

  @override
  int get hashCode => Object.hash(x, y, width, height);

  @override
  String toString() => 'Rectangle(x: $x, y: $y, width: $width, height: $height)';
}
