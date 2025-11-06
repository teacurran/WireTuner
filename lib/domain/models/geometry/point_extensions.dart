import 'dart:math';

import 'package:wiretuner/domain/events/event_base.dart';

/// Extension methods providing geometric operations on [Point].
///
/// Adds vector arithmetic and distance calculations to the existing Point class.
/// All operations preserve immutability by returning new Point instances.
extension PointGeometry on Point {
  /// Calculates the Euclidean distance to another point.
  ///
  /// Uses the formula: sqrt((x2-x1)^2 + (y2-y1)^2)
  ///
  /// Example:
  /// ```dart
  /// final p1 = Point(x: 0, y: 0);
  /// final p2 = Point(x: 3, y: 4);
  /// print(p1.distanceTo(p2)); // 5.0
  /// ```
  double distanceTo(Point other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return sqrt(dx * dx + dy * dy);
  }

  /// Adds two points using vector addition.
  ///
  /// Returns a new Point with coordinates (x1 + x2, y1 + y2).
  ///
  /// Example:
  /// ```dart
  /// final p1 = Point(x: 1, y: 2);
  /// final p2 = Point(x: 3, y: 4);
  /// final result = p1 + p2; // Point(x: 4, y: 6)
  /// ```
  Point operator +(Point other) {
    return Point(x: x + other.x, y: y + other.y);
  }

  /// Subtracts two points using vector subtraction.
  ///
  /// Returns a new Point with coordinates (x1 - x2, y1 - y2).
  ///
  /// Example:
  /// ```dart
  /// final p1 = Point(x: 5, y: 7);
  /// final p2 = Point(x: 2, y: 3);
  /// final result = p1 - p2; // Point(x: 3, y: 4)
  /// ```
  Point operator -(Point other) {
    return Point(x: x - other.x, y: y - other.y);
  }

  /// Multiplies point by a scalar value.
  ///
  /// Returns a new Point with coordinates (x * scalar, y * scalar).
  ///
  /// Example:
  /// ```dart
  /// final p = Point(x: 2, y: 3);
  /// final scaled = p * 2.5; // Point(x: 5, y: 7.5)
  /// ```
  Point operator *(double scalar) {
    return Point(x: x * scalar, y: y * scalar);
  }

  /// Divides point by a scalar value.
  ///
  /// Returns a new Point with coordinates (x / scalar, y / scalar).
  ///
  /// Example:
  /// ```dart
  /// final p = Point(x: 10, y: 20);
  /// final divided = p / 2; // Point(x: 5, y: 10)
  /// ```
  Point operator /(double scalar) {
    return Point(x: x / scalar, y: y / scalar);
  }

  /// Returns the negation of this point.
  ///
  /// Returns a new Point with coordinates (-x, -y).
  ///
  /// Example:
  /// ```dart
  /// final p = Point(x: 3, y: -4);
  /// final negated = -p; // Point(x: -3, y: 4)
  /// ```
  Point operator -() {
    return Point(x: -x, y: -y);
  }

  /// Calculates the magnitude (length) of this point as a vector.
  ///
  /// Uses the formula: sqrt(x^2 + y^2)
  ///
  /// Example:
  /// ```dart
  /// final p = Point(x: 3, y: 4);
  /// print(p.magnitude); // 5.0
  /// ```
  double get magnitude => sqrt(x * x + y * y);

  /// Returns a normalized version of this point (unit vector).
  ///
  /// If the magnitude is zero, returns the original point.
  ///
  /// Example:
  /// ```dart
  /// final p = Point(x: 3, y: 4);
  /// final normalized = p.normalized; // Point(x: 0.6, y: 0.8)
  /// ```
  Point get normalized {
    final mag = magnitude;
    if (mag == 0) return this;
    return Point(x: x / mag, y: y / mag);
  }

  /// Calculates the dot product with another point.
  ///
  /// Formula: x1 * x2 + y1 * y2
  ///
  /// Example:
  /// ```dart
  /// final p1 = Point(x: 2, y: 3);
  /// final p2 = Point(x: 4, y: 5);
  /// print(p1.dot(p2)); // 23.0 (2*4 + 3*5)
  /// ```
  double dot(Point other) {
    return x * other.x + y * other.y;
  }

  /// Calculates the cross product magnitude with another point (2D).
  ///
  /// In 2D, this returns the z-component of the 3D cross product.
  /// Formula: x1 * y2 - y1 * x2
  ///
  /// Example:
  /// ```dart
  /// final p1 = Point(x: 2, y: 3);
  /// final p2 = Point(x: 4, y: 5);
  /// print(p1.cross(p2)); // -2.0 (2*5 - 3*4)
  /// ```
  double cross(Point other) {
    return x * other.y - y * other.x;
  }
}
