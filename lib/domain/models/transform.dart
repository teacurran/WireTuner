import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/models/geometry/rectangle.dart';

/// Represents an immutable 2D affine transformation.
///
/// This class wraps a [Matrix4] from the vector_math package to provide
/// affine transformations (translate, rotate, scale) for 2D vector graphics.
///
/// Transformations can be composed using the [compose] method, which applies
/// matrix multiplication. Note that transformation order matters:
/// translate-then-scale produces different results than scale-then-translate.
///
/// Example:
/// ```dart
/// // Create a transform that translates by (10, 20)
/// final t1 = Transform.translate(10, 20);
///
/// // Create a transform that scales by 2x
/// final t2 = Transform.scale(2, 2);
///
/// // Compose: first translate, then scale
/// final combined = t1.compose(t2);
/// final point = Point(x: 5, y: 5);
/// final transformed = combined.transformPoint(point);
/// // Result: (20, 30) - point moved to (15, 25), then scaled to (30, 50)
/// ```
@immutable
class Transform {

  /// Creates a transform from a Matrix4.
  ///
  /// The matrix is cloned to ensure immutability.
  Transform(Matrix4 matrix) : matrix = matrix.clone();

  /// Creates an identity transform (no transformation).
  ///
  /// An identity transform leaves all points unchanged.
  ///
  /// Example:
  /// ```dart
  /// final t = Transform.identity();
  /// final p = Point(x: 5, y: 10);
  /// final result = t.transformPoint(p);
  /// // result: Point(x: 5, y: 10) - unchanged
  /// ```
  factory Transform.identity() => Transform(Matrix4.identity());

  /// Creates a translation transform.
  ///
  /// Moves points by the specified offset ([dx], [dy]).
  ///
  /// Example:
  /// ```dart
  /// final t = Transform.translate(10, 20);
  /// final p = Point(x: 5, y: 5);
  /// final result = t.transformPoint(p);
  /// // result: Point(x: 15, y: 25)
  /// ```
  factory Transform.translate(double dx, double dy) => Transform(Matrix4.identity()..translate(dx, dy));

  /// Creates a rotation transform.
  ///
  /// Rotates points around the origin by the specified angle in radians.
  /// Positive angles rotate counter-clockwise.
  ///
  /// Example:
  /// ```dart
  /// final t = Transform.rotate(math.pi / 2); // 90 degrees
  /// final p = Point(x: 1, y: 0);
  /// final result = t.transformPoint(p);
  /// // result: Point(x: 0, y: 1) approximately
  /// ```
  factory Transform.rotate(double angleInRadians) => Transform(Matrix4.identity()..rotateZ(angleInRadians));

  /// Creates a rotation transform around a specific point.
  ///
  /// Rotates points around the specified center point.
  ///
  /// Example:
  /// ```dart
  /// final t = Transform.rotateAround(
  ///   angle: math.pi / 2,
  ///   center: Point(x: 5, y: 5),
  /// );
  /// ```
  factory Transform.rotateAround({
    required double angle,
    required Point center,
  }) {
    final matrix = Matrix4.identity()
      ..translate(center.x, center.y)
      ..rotateZ(angle)
      ..translate(-center.x, -center.y);
    return Transform(matrix);
  }

  /// Creates a scale transform.
  ///
  /// Scales points by the specified factors ([sx], [sy]) around the origin.
  ///
  /// Example:
  /// ```dart
  /// final t = Transform.scale(2, 3);
  /// final p = Point(x: 5, y: 10);
  /// final result = t.transformPoint(p);
  /// // result: Point(x: 10, y: 30)
  /// ```
  factory Transform.scale(double sx, double sy) => Transform(Matrix4.identity()..scale(sx, sy));

  /// Creates a uniform scale transform.
  ///
  /// Scales points equally in both x and y directions.
  ///
  /// Example:
  /// ```dart
  /// final t = Transform.uniformScale(2);
  /// final p = Point(x: 3, y: 4);
  /// final result = t.transformPoint(p);
  /// // result: Point(x: 6, y: 8)
  /// ```
  factory Transform.uniformScale(double scale) => Transform.scale(scale, scale);

  /// Creates a scale transform around a specific point.
  ///
  /// Scales points around the specified center point.
  ///
  /// Example:
  /// ```dart
  /// final t = Transform.scaleAround(
  ///   sx: 2,
  ///   sy: 2,
  ///   center: Point(x: 10, y: 10),
  /// );
  /// ```
  factory Transform.scaleAround({
    required double sx,
    required double sy,
    required Point center,
  }) {
    final matrix = Matrix4.identity()
      ..translate(center.x, center.y)
      ..scale(sx, sy)
      ..translate(-center.x, -center.y);
    return Transform(matrix);
  }

  /// Creates a skew transform.
  ///
  /// Skews points by the specified angles in radians.
  ///
  /// Example:
  /// ```dart
  /// final t = Transform.skew(math.pi / 6, 0); // Skew 30° horizontally
  /// ```
  factory Transform.skew(double angleX, double angleY) {
    final matrix = Matrix4.identity();
    matrix[1] = math.tan(angleX); // Skew X
    matrix[4] = math.tan(angleY); // Skew Y
    return Transform(matrix);
  }
  /// The underlying transformation matrix.
  final Matrix4 matrix;

  /// Composes this transform with another transform.
  ///
  /// Returns a new transform that represents applying this transform
  /// followed by the [other] transform. This is done through matrix
  /// multiplication: result = other.matrix * this.matrix
  ///
  /// **Important**: Order matters! `t1.compose(t2)` applies t1 first, then t2.
  ///
  /// Example:
  /// ```dart
  /// final t1 = Transform.translate(10, 0);
  /// final t2 = Transform.scale(2, 1);
  /// final combined = t1.compose(t2);
  /// final p = Point(x: 5, y: 0);
  /// final result = combined.transformPoint(p);
  /// // First translate: (5, 0) -> (15, 0)
  /// // Then scale: (15, 0) -> (30, 0)
  /// ```
  Transform compose(Transform other) {
    final result = other.matrix.clone()..multiply(matrix);
    return Transform(result);
  }

  /// Transforms a point by this transform.
  ///
  /// Applies the affine transformation to the point and returns a new point.
  ///
  /// Example:
  /// ```dart
  /// final t = Transform.translate(10, 20);
  /// final p = Point(x: 5, y: 5);
  /// final result = t.transformPoint(p);
  /// // result: Point(x: 15, y: 25)
  /// ```
  Point transformPoint(Point point) {
    final vector = Vector3(point.x, point.y, 0.0);
    final transformed = matrix.transform3(vector);
    return Point(x: transformed.x, y: transformed.y);
  }

  /// Transforms a rectangle by this transform.
  ///
  /// Transforms all four corners of the rectangle and returns the
  /// bounding box of the transformed corners.
  ///
  /// **Note**: For non-uniform transforms (like rotation), the resulting
  /// rectangle will be axis-aligned and may be larger than the rotated
  /// rectangle.
  ///
  /// Example:
  /// ```dart
  /// final t = Transform.translate(10, 20);
  /// final r = Rectangle(x: 0, y: 0, width: 10, height: 10);
  /// final result = t.transformRectangle(r);
  /// // result: Rectangle(x: 10, y: 20, width: 10, height: 10)
  /// ```
  Rectangle transformRectangle(Rectangle rect) {
    // Transform all four corners
    final topLeft = transformPoint(rect.topLeft);
    final topRight = transformPoint(rect.topRight);
    final bottomLeft = transformPoint(rect.bottomLeft);
    final bottomRight = transformPoint(rect.bottomRight);

    // Find bounding box of transformed corners
    final minX = [topLeft.x, topRight.x, bottomLeft.x, bottomRight.x]
        .reduce(math.min);
    final maxX = [topLeft.x, topRight.x, bottomLeft.x, bottomRight.x]
        .reduce(math.max);
    final minY = [topLeft.y, topRight.y, bottomLeft.y, bottomRight.y]
        .reduce(math.min);
    final maxY = [topLeft.y, topRight.y, bottomLeft.y, bottomRight.y]
        .reduce(math.max);

    return Rectangle.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Returns the inverse of this transform.
  ///
  /// The inverse transform "undoes" this transform. Applying a transform
  /// followed by its inverse returns the original point.
  ///
  /// Returns null if the transform is not invertible (e.g., scale of 0).
  ///
  /// Example:
  /// ```dart
  /// final t = Transform.translate(10, 20);
  /// final inverse = t.invert()!;
  /// final p = Point(x: 5, y: 5);
  /// final transformed = t.transformPoint(p);
  /// final original = inverse.transformPoint(transformed);
  /// // original == p
  /// ```
  Transform? invert() {
    try {
      final inverted = Matrix4.inverted(matrix);
      return Transform(inverted);
    } catch (e) {
      return null; // Not invertible
    }
  }

  /// Whether this transform is the identity transform.
  bool get isIdentity => matrix.isIdentity();

  /// Extracts the translation component of this transform.
  ///
  /// Returns the (dx, dy) translation as a Point.
  Point get translation => Point(x: matrix.getTranslation().x, y: matrix.getTranslation().y);

  /// Extracts the rotation angle (in radians) from this transform.
  ///
  /// This assumes the transform only contains rotation (no skew).
  /// For complex transforms, this may not be accurate.
  double get rotation => math.atan2(matrix.entry(1, 0), matrix.entry(0, 0));

  /// Extracts the scale factors from this transform.
  ///
  /// Returns (scaleX, scaleY) as a Point.
  /// For complex transforms with rotation/skew, this approximates the scale.
  Point get scale {
    final sx = math.sqrt(
      matrix.entry(0, 0) * matrix.entry(0, 0) +
          matrix.entry(1, 0) * matrix.entry(1, 0),
    );
    final sy = math.sqrt(
      matrix.entry(0, 1) * matrix.entry(0, 1) +
          matrix.entry(1, 1) * matrix.entry(1, 1),
    );
    return Point(x: sx, y: sy);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Transform) return false;

    // Compare all 16 matrix elements
    for (var i = 0; i < 16; i++) {
      if (matrix[i] != other.matrix[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    // Hash the relevant transformation components
    return Object.hash(
      matrix[0],
      matrix[1],
      matrix[4],
      matrix[5],
      matrix[12],
      matrix[13],
    );
  }

  @override
  String toString() => 'Transform(matrix: ${matrix.storage})';
}
