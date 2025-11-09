/// Geometry utilities for hit testing calculations.
///
/// This module provides low-level geometric primitives used by the hit testing
/// system, including point-in-path tests, distance calculations, and curve
/// intersection helpers.
library;

import 'dart:math' as math;
import '../geometry/point.dart';
import '../geometry/segment.dart';
import '../geometry/anchor.dart';
import '../geometry/path.dart';
import '../geometry.dart';

/// Computes the minimum distance from a point to a line segment.
///
/// Returns the perpendicular distance if the point projects onto the segment,
/// or the distance to the nearest endpoint otherwise.
///
/// Algorithm:
/// 1. Project point onto infinite line through segment
/// 2. Clamp projection parameter t to [0, 1] to stay on segment
/// 3. Compute distance to clamped point
double distanceToLineSegment(Point point, Point segmentStart, Point segmentEnd) {
  final segmentVector = segmentEnd - segmentStart;
  final pointVector = point - segmentStart;

  final segmentLengthSquared = segmentVector.magnitudeSquared;

  // Handle degenerate case (segment is a point)
  if (segmentLengthSquared < kGeometryEpsilon) {
    return point.distanceTo(segmentStart);
  }

  // Project point onto line: t = dot(AP, AB) / |AB|²
  double t = pointVector.dot(segmentVector) / segmentLengthSquared;

  // Clamp t to [0, 1] to stay on segment
  t = t.clamp(0.0, 1.0);

  // Compute closest point on segment
  final closestPoint = segmentStart + segmentVector * t;

  return point.distanceTo(closestPoint);
}

/// Computes the minimum distance from a point to a cubic Bezier curve.
///
/// Uses a subdivision-based approximation with the specified number of samples.
/// This is more efficient than analytical root-finding for interactive hit testing.
///
/// Parameters:
/// - [point]: The query point
/// - [p0]: Curve start point
/// - [p1]: First control point
/// - [p2]: Second control point
/// - [p3]: Curve end point
/// - [samples]: Number of subdivisions (default: 20 for good accuracy/performance balance)
double distanceToBezierCurve(
  Point point,
  Point p0,
  Point p1,
  Point p2,
  Point p3, {
  int samples = 20,
}) {
  double minDistance = double.infinity;
  Point? previousPoint;

  for (int i = 0; i <= samples; i++) {
    final t = i / samples;
    final curvePoint = _evaluateCubicBezier(t, p0, p1, p2, p3);

    if (previousPoint != null) {
      // Check distance to this linear segment approximation
      final distance = distanceToLineSegment(point, previousPoint, curvePoint);
      minDistance = math.min(minDistance, distance);
    }

    previousPoint = curvePoint;
  }

  return minDistance;
}

/// Evaluates a cubic Bezier curve at parameter t ∈ [0, 1].
Point _evaluateCubicBezier(double t, Point p0, Point p1, Point p2, Point p3) {
  final t2 = t * t;
  final t3 = t2 * t;
  final mt = 1.0 - t;
  final mt2 = mt * mt;
  final mt3 = mt2 * mt;

  return Point(
    x: mt3 * p0.x + 3 * mt2 * t * p1.x + 3 * mt * t2 * p2.x + t3 * p3.x,
    y: mt3 * p0.y + 3 * mt2 * t * p1.y + 3 * mt * t2 * p2.y + t3 * p3.y,
  );
}

/// Computes the minimum distance from a point to a segment.
///
/// Dispatches to the appropriate distance calculation based on segment type.
double distanceToSegment(
  Point point,
  Segment segment,
  AnchorPoint startAnchor,
  AnchorPoint endAnchor, {
  int bezierSamples = 20,
}) {
  switch (segment.segmentType) {
    case SegmentType.line:
      return distanceToLineSegment(
        point,
        startAnchor.position,
        endAnchor.position,
      );

    case SegmentType.bezier:
      final p0 = startAnchor.position;
      final p3 = endAnchor.position;
      final p1 = startAnchor.handleOutAbsolute ?? p0;
      final p2 = endAnchor.handleInAbsolute ?? p3;

      // Degenerate case: no handles means it's effectively a line
      if (p1 == p0 && p2 == p3) {
        return distanceToLineSegment(point, p0, p3);
      }

      return distanceToBezierCurve(point, p0, p1, p2, p3, samples: bezierSamples);

    case SegmentType.arc:
      // TODO: Implement arc distance calculation when arcs are supported
      throw UnimplementedError('Arc segments not yet supported');
  }
}

/// Computes the minimum distance from a point to a path.
///
/// Returns the minimum distance to any segment in the path.
double distanceToPath(Point point, Path path, {int bezierSamples = 20}) {
  if (path.isEmpty) {
    return double.infinity;
  }

  if (path.anchors.length == 1) {
    return point.distanceTo(path.anchors.first.position);
  }

  double minDistance = double.infinity;

  // Check all segments
  final allSegments = path.allSegments;
  for (final segment in allSegments) {
    if (segment.startAnchorIndex < path.anchors.length &&
        segment.endAnchorIndex < path.anchors.length) {
      final distance = distanceToSegment(
        point,
        segment,
        path.anchors[segment.startAnchorIndex],
        path.anchors[segment.endAnchorIndex],
        bezierSamples: bezierSamples,
      );
      minDistance = math.min(minDistance, distance);
    }
  }

  return minDistance;
}

/// Tests if a point is inside a closed path using the ray casting algorithm.
///
/// This implements the even-odd rule (also known as the parity rule):
/// - Cast a ray from the point to infinity (we use horizontal ray to the right)
/// - Count how many times the ray crosses path edges
/// - If count is odd, point is inside; if even, point is outside
///
/// Note: Only works for closed paths. Returns false for open paths.
///
/// Algorithm details:
/// - We cast a horizontal ray from [point] extending to positive infinity
/// - For each segment, we check if the ray intersects it
/// - Edge cases are handled carefully to avoid double-counting shared vertices
bool isPointInPath(Point point, Path path) {
  // Only closed paths have an "inside"
  if (!path.closed || path.anchors.length < 3) {
    return false;
  }

  int intersectionCount = 0;
  final allSegments = path.allSegments;

  for (final segment in allSegments) {
    if (segment.startAnchorIndex >= path.anchors.length ||
        segment.endAnchorIndex >= path.anchors.length) {
      continue;
    }

    final startAnchor = path.anchors[segment.startAnchorIndex];
    final endAnchor = path.anchors[segment.endAnchorIndex];

    // Count ray intersections based on segment type
    switch (segment.segmentType) {
      case SegmentType.line:
        if (_rayIntersectsLineSegment(point, startAnchor.position, endAnchor.position)) {
          intersectionCount++;
        }
        break;

      case SegmentType.bezier:
        final p0 = startAnchor.position;
        final p3 = endAnchor.position;
        final p1 = startAnchor.handleOutAbsolute ?? p0;
        final p2 = endAnchor.handleInAbsolute ?? p3;

        // Degenerate case
        if (p1 == p0 && p2 == p3) {
          if (_rayIntersectsLineSegment(point, p0, p3)) {
            intersectionCount++;
          }
        } else {
          // Approximate Bezier with subdivisions
          intersectionCount += _countBezierRayIntersections(point, p0, p1, p2, p3);
        }
        break;

      case SegmentType.arc:
        // TODO: Implement when arcs are supported
        throw UnimplementedError('Arc segments not yet supported');
    }
  }

  // Odd number of intersections means inside
  return intersectionCount.isOdd;
}

/// Tests if a horizontal ray from [point] to the right intersects a line segment.
///
/// Edge cases:
/// - If segment is horizontal and contains point, count as no intersection
/// - If ray passes through a vertex, only count if it's the lower vertex
///   (this prevents double-counting at shared vertices)
bool _rayIntersectsLineSegment(Point point, Point start, Point end) {
  final px = point.x;
  final py = point.y;

  final x1 = start.x;
  final y1 = start.y;
  final x2 = end.x;
  final y2 = end.y;

  // Check if segment is entirely above or below the ray
  if ((y1 < py && y2 < py) || (y1 > py && y2 > py)) {
    return false;
  }

  // Check if segment is entirely to the left of the point
  if (x1 < px && x2 < px) {
    return false;
  }

  // Handle horizontal segments specially
  if ((y1 - y2).abs() < kGeometryEpsilon) {
    return false;
  }

  // Compute intersection point x-coordinate using line equation
  // x = x1 + (py - y1) * (x2 - x1) / (y2 - y1)
  final t = (py - y1) / (y2 - y1);
  final intersectionX = x1 + t * (x2 - x1);

  // Ray extends to the right, so intersection must be at or right of point
  if (intersectionX < px - kGeometryEpsilon) {
    return false;
  }

  // To avoid double-counting vertices, only count if we're not at the upper vertex
  // Check if we're exactly at a vertex
  if ((py - y1).abs() < kGeometryEpsilon) {
    // At start vertex - only count if end is below
    return y2 > y1;
  }
  if ((py - y2).abs() < kGeometryEpsilon) {
    // At end vertex - only count if start is below
    return y1 > y2;
  }

  return true;
}

/// Counts how many times a horizontal ray from [point] intersects a Bezier curve.
///
/// Uses subdivision to approximate the curve as a polyline.
int _countBezierRayIntersections(Point point, Point p0, Point p1, Point p2, Point p3) {
  const int subdivisions = 20;
  int count = 0;
  Point? previousPoint;

  for (int i = 0; i <= subdivisions; i++) {
    final t = i / subdivisions;
    final curvePoint = _evaluateCubicBezier(t, p0, p1, p2, p3);

    if (previousPoint != null) {
      if (_rayIntersectsLineSegment(point, previousPoint, curvePoint)) {
        count++;
      }
    }

    previousPoint = curvePoint;
  }

  return count;
}
