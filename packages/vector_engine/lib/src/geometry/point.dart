import 'package:freezed_annotation/freezed_annotation.dart';
import 'dart:math' as math;

part 'point.freezed.dart';
part 'point.g.dart';

/// An immutable 2D point in world coordinates.
///
/// Points represent positions in the infinite canvas coordinate system,
/// with the origin (0, 0) at the top-left. All coordinates are in world-space
/// units (typically pixels at 100% zoom).
///
/// Points support basic vector arithmetic operations and can be serialized
/// to/from JSON for snapshot persistence.
@freezed
class Point with _$Point {
  const Point._();

  /// Creates a point at the given coordinates.
  ///
  /// ```dart
  /// final p = Point(x: 100, y: 200);
  /// ```
  const factory Point({
    required double x,
    required double y,
  }) = _Point;

  /// Creates a point at the origin (0, 0).
  factory Point.zero() => const Point(x: 0, y: 0);

  /// Deserializes a point from JSON.
  factory Point.fromJson(Map<String, dynamic> json) => _$PointFromJson(json);

  /// Returns the distance from this point to another point.
  ///
  /// Uses the Euclidean distance formula: √((x₂-x₁)² + (y₂-y₁)²)
  double distanceTo(Point other) {
    final dx = other.x - x;
    final dy = other.y - y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Returns the squared distance to another point.
  ///
  /// This is more efficient than [distanceTo] when you only need to compare
  /// distances (avoids the square root calculation).
  double distanceSquaredTo(Point other) {
    final dx = other.x - x;
    final dy = other.y - y;
    return dx * dx + dy * dy;
  }

  /// Returns the magnitude (length) of this point when treated as a vector.
  double get magnitude => math.sqrt(x * x + y * y);

  /// Returns the squared magnitude of this point as a vector.
  double get magnitudeSquared => x * x + y * y;

  /// Returns a normalized version of this point (unit vector in same direction).
  ///
  /// Returns [Point.zero] if the magnitude is zero.
  Point normalize() {
    final mag = magnitude;
    if (mag == 0) return Point.zero();
    return Point(x: x / mag, y: y / mag);
  }

  /// Returns the dot product with another point (treated as vectors).
  double dot(Point other) => x * other.x + y * other.y;

  /// Returns the cross product z-component with another point (2D).
  ///
  /// For 2D vectors, the cross product is a scalar: x₁y₂ - y₁x₂
  double cross(Point other) => x * other.y - y * other.x;

  /// Returns the angle of this point in radians (when treated as a vector from origin).
  ///
  /// Returns values in the range [-π, π].
  double get angle => math.atan2(y, x);

  /// Returns the angle to another point in radians.
  double angleTo(Point other) => (other - this).angle;

  /// Adds another point (vector addition).
  Point operator +(Point other) => Point(x: x + other.x, y: y + other.y);

  /// Subtracts another point (vector subtraction).
  Point operator -(Point other) => Point(x: x - other.x, y: y - other.y);

  /// Multiplies by a scalar.
  Point operator *(double scalar) => Point(x: x * scalar, y: y * scalar);

  /// Divides by a scalar.
  Point operator /(double scalar) => Point(x: x / scalar, y: y / scalar);

  /// Returns the negation of this point.
  Point operator -() => Point(x: -x, y: -y);

  /// Linearly interpolates between this point and another.
  ///
  /// When [t] is 0, returns this point. When [t] is 1, returns [other].
  /// Values outside [0, 1] perform extrapolation.
  Point lerp(Point other, double t) {
    return Point(
      x: x + (other.x - x) * t,
      y: y + (other.y - y) * t,
    );
  }

  /// Returns a point rotated around the origin by the given angle in radians.
  Point rotate(double angleRadians) {
    final cos = math.cos(angleRadians);
    final sin = math.sin(angleRadians);
    return Point(
      x: x * cos - y * sin,
      y: x * sin + y * cos,
    );
  }

  /// Returns a point rotated around a center point by the given angle.
  Point rotateAround(Point center, double angleRadians) {
    return (this - center).rotate(angleRadians) + center;
  }

  /// Returns a human-readable string representation.
  @override
  String toString() => 'Point(x: $x, y: $y)';
}
