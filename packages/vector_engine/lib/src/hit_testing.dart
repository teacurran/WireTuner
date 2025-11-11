/// Hit testing for selection and manipulation of vector graphics.
///
/// This module provides hit testing functionality to determine
/// which objects, anchor points, or control points are under the cursor.
///
/// ## Features
///
/// - **Point-in-path testing**: Determine if a point is inside a closed path
/// - **Stroke hit testing**: Find objects near a point with configurable tolerance
/// - **Anchor point detection**: Hit test individual anchor points
/// - **BVH acceleration**: Fast spatial queries using bounding volume hierarchy
/// - **Zoom-aware tolerances**: Maintain consistent hit areas across zoom levels
///
/// ## Usage
///
/// ```dart
/// // Build a hit tester from your objects
/// final hitTester = HitTester.build(objects);
///
/// // Perform a hit test
/// final hits = hitTester.hitTest(
///   point: Point(x: 100, y: 100),
///   config: HitTestConfig(
///     strokeTolerance: 5.0,
///     anchorTolerance: 8.0,
///   ),
/// );
///
/// // Process results
/// for (final hit in hits) {
///   if (hit.isAnchorHit) {
///     print('Hit anchor ${hit.anchorIndex} on ${hit.objectId}');
///   } else {
///     print('Hit object ${hit.objectId}');
///   }
/// }
/// ```
///
/// ## Performance
///
/// The BVH acceleration structure provides O(log n) average-case performance
/// for point queries, making it suitable for interactive hit testing with
/// thousands of objects.
library;

export 'hit_testing/hit_tester.dart';
export 'hit_testing/bvh.dart';
export 'hit_testing/geometry_utils.dart';
