import '../geometry/bounds.dart';
import '../geometry/point.dart';
import '../geometry/path.dart';
import '../geometry/shape.dart';
import 'bvh.dart';
import 'geometry_utils.dart';

/// Result of a hit test query.
///
/// Contains the ID of the hit object and optional anchor information
/// if an anchor point was specifically hit.
class HitTestResult {
  /// The ID of the object that was hit.
  final String objectId;

  /// The index of the hit anchor point, if any.
  ///
  /// Null if the hit was on the object itself (path/shape) rather than
  /// a specific anchor point.
  final int? anchorIndex;

  /// The distance from the query point to the hit.
  ///
  /// Useful for sorting results by proximity.
  final double distance;

  /// The type of hit.
  final HitType hitType;

  const HitTestResult({
    required this.objectId,
    this.anchorIndex,
    required this.distance,
    required this.hitType,
  });

  /// Returns true if this result represents an anchor hit.
  bool get isAnchorHit => anchorIndex != null;

  /// Returns true if this result represents an object hit (path or shape).
  bool get isObjectHit => !isAnchorHit;

  @override
  String toString() => 'HitTestResult('
      'objectId: $objectId, '
      'anchorIndex: $anchorIndex, '
      'distance: ${distance.toStringAsFixed(2)}, '
      'type: $hitType'
      ')';
}

/// The type of hit detected.
enum HitType {
  /// Hit on an anchor point.
  anchor,

  /// Hit on a path stroke.
  pathStroke,

  /// Hit inside a filled path.
  pathFill,

  /// Hit on a shape.
  shape,
}

/// Configuration for hit testing behavior.
class HitTestConfig {
  /// Tolerance in world units for stroke hit testing.
  ///
  /// Objects within this distance of the query point are considered hits.
  final double strokeTolerance;

  /// Tolerance in world units for anchor point hit testing.
  ///
  /// Anchor points within this distance are considered hits.
  final double anchorTolerance;

  /// Number of subdivisions for Bezier curve approximation.
  ///
  /// Higher values increase accuracy but decrease performance.
  final int bezierSamples;

  /// Whether to test anchor points.
  final bool testAnchors;

  /// Whether to test path strokes.
  final bool testStrokes;

  /// Whether to test path fills (point-in-path).
  final bool testFills;

  const HitTestConfig({
    this.strokeTolerance = 5.0,
    this.anchorTolerance = 8.0,
    this.bezierSamples = 20,
    this.testAnchors = true,
    this.testStrokes = true,
    this.testFills = true,
  });

  /// Creates a config scaled by a zoom factor.
  ///
  /// This adjusts tolerances to maintain consistent screen-space hit areas
  /// across zoom levels. For example, at 200% zoom, tolerances are halved
  /// so they represent the same screen-space size.
  HitTestConfig scaledByZoom(double zoom) {
    return HitTestConfig(
      strokeTolerance: strokeTolerance / zoom,
      anchorTolerance: anchorTolerance / zoom,
      bezierSamples: bezierSamples,
      testAnchors: testAnchors,
      testStrokes: testStrokes,
      testFills: testFills,
    );
  }
}

/// An object that can be hit tested.
///
/// Wraps either a Path or Shape with an ID for identification.
class HitTestable {
  /// The unique ID of this object.
  final String id;

  /// The path, if this is a path object.
  final Path? path;

  /// The shape, if this is a shape object.
  final Shape? shape;

  HitTestable.path({
    required this.id,
    required Path this.path,
  }) : shape = null;

  HitTestable.shape({
    required this.id,
    required Shape this.shape,
  }) : path = null;

  /// Returns the bounds of this object.
  Bounds getBounds() {
    if (path != null) {
      return path!.bounds();
    } else if (shape != null) {
      return shape!.toPath().bounds();
    } else {
      return Bounds.zero();
    }
  }

  /// Returns the path representation of this object.
  ///
  /// For shapes, converts to path first.
  Path getPath() {
    if (path != null) {
      return path!;
    } else if (shape != null) {
      return shape!.toPath();
    } else {
      return Path.empty();
    }
  }
}

/// A stateless hit testing service for vector objects.
///
/// This service provides methods for finding which objects, paths, or anchor
/// points are at a given location. It uses a BVH (Bounding Volume Hierarchy)
/// for efficient spatial queries.
///
/// ## Usage
///
/// ```dart
/// final hitTester = HitTester.build(objects);
///
/// final hits = hitTester.hitTest(
///   point: Point(x: 100, y: 100),
///   config: HitTestConfig(),
/// );
///
/// if (hits.isNotEmpty) {
///   print('Hit object: ${hits.first.objectId}');
/// }
/// ```
///
/// ## Performance
///
/// The BVH acceleration structure provides O(log n) average-case performance
/// for point queries, making it suitable for interactive hit testing even
/// with thousands of objects.
///
/// ## Zoom Scaling
///
/// Hit testing tolerances are specified in world-space units. To maintain
/// consistent screen-space hit areas across zoom levels, use [HitTestConfig.scaledByZoom]:
///
/// ```dart
/// final config = HitTestConfig().scaledByZoom(viewportZoom);
/// ```
class HitTester {
  /// The BVH acceleration structure.
  final BVH<HitTestable> _bvh;

  /// The objects being tested.
  final List<HitTestable> _objects;

  HitTester._({
    required BVH<HitTestable> bvh,
    required List<HitTestable> objects,
  })  : _bvh = bvh,
        _objects = objects;

  /// Builds a hit tester from a list of objects.
  ///
  /// This constructs the BVH acceleration structure, which has O(n log n) complexity.
  factory HitTester.build(List<HitTestable> objects) {
    final entries = objects.map((obj) {
      return BVHEntry<HitTestable>(
        id: obj.id,
        bounds: obj.getBounds(),
        data: obj,
      );
    }).toList();

    final bvh = BVH.build(entries);

    return HitTester._(
      bvh: bvh,
      objects: objects,
    );
  }

  /// Creates an empty hit tester.
  factory HitTester.empty() => HitTester.build([]);

  /// Performs a hit test at the given point.
  ///
  /// Returns a list of hits sorted by distance (nearest first).
  /// The list may contain multiple results:
  /// - Anchor hits (if anchors are tested and within tolerance)
  /// - Stroke hits (if strokes are tested and within tolerance)
  /// - Fill hits (if fills are tested and point is inside closed path)
  ///
  /// Priority order (nearest to farthest):
  /// 1. Anchor points (if within anchorTolerance)
  /// 2. Path strokes (if within strokeTolerance)
  /// 3. Shape objects (if within strokeTolerance or inside)
  /// 4. Path fills (if inside closed path)
  List<HitTestResult> hitTest({
    required Point point,
    HitTestConfig config = const HitTestConfig(),
  }) {
    final results = <HitTestResult>[];

    // Use BVH to find candidate objects
    // Use the larger tolerance to ensure we don't miss anything
    final queryTolerance = config.anchorTolerance > config.strokeTolerance
        ? config.anchorTolerance
        : config.strokeTolerance;

    final candidates = _bvh.query(point, tolerance: queryTolerance);

    // Test each candidate
    for (final candidate in candidates) {
      final obj = candidate.data;
      final path = obj.getPath();

      // Test anchors first (highest priority)
      if (config.testAnchors && path.isNotEmpty) {
        for (int i = 0; i < path.anchors.length; i++) {
          final anchor = path.anchors[i];
          final distance = point.distanceTo(anchor.position);

          if (distance <= config.anchorTolerance) {
            results.add(HitTestResult(
              objectId: obj.id,
              anchorIndex: i,
              distance: distance,
              hitType: HitType.anchor,
            ));
          }
        }
      }

      // Test path stroke
      if (config.testStrokes && path.isNotEmpty) {
        final distance = distanceToPath(
          point,
          path,
          bezierSamples: config.bezierSamples,
        );

        if (distance <= config.strokeTolerance) {
          results.add(HitTestResult(
            objectId: obj.id,
            anchorIndex: null,
            distance: distance,
            hitType: obj.shape != null ? HitType.shape : HitType.pathStroke,
          ));
        }
      }

      // Test path fill (if closed)
      if (config.testFills && path.closed && path.anchors.length >= 3) {
        if (isPointInPath(point, path)) {
          // For fill hits, use a large distance to deprioritize vs stroke hits
          // Use distance to nearest stroke as the distance metric
          final strokeDistance = distanceToPath(
            point,
            path,
            bezierSamples: config.bezierSamples,
          );

          results.add(HitTestResult(
            objectId: obj.id,
            anchorIndex: null,
            distance: strokeDistance,
            hitType: HitType.pathFill,
          ));
        }
      }
    }

    // Sort by distance (nearest first)
    results.sort((a, b) => a.distance.compareTo(b.distance));

    return results;
  }

  /// Finds the topmost (nearest) object at the given point.
  ///
  /// Returns null if no object is hit.
  ///
  /// This is a convenience method that returns only the nearest hit.
  HitTestResult? hitTestNearest({
    required Point point,
    HitTestConfig config = const HitTestConfig(),
  }) {
    final hits = hitTest(point: point, config: config);
    return hits.isEmpty ? null : hits.first;
  }

  /// Finds all objects within the given rectangular bounds.
  ///
  /// Useful for rectangle selection tools.
  ///
  /// Note: This uses bounding box intersection, not precise geometric intersection.
  /// Objects whose bounds intersect the query bounds are returned.
  List<String> hitTestBounds(Bounds bounds) {
    final candidates = _bvh.queryBounds(bounds);
    return candidates.map((entry) => entry.id).toList();
  }

  /// Returns statistics about the underlying BVH structure.
  ///
  /// Useful for debugging and performance profiling.
  BVHStats getStats() => _bvh.getStats();

  /// Returns the number of objects in this hit tester.
  int get objectCount => _objects.length;
}
