import '../geometry/bounds.dart';
import '../geometry/point.dart';

/// A bounding volume hierarchy (BVH) for accelerating spatial queries.
///
/// BVH is a tree data structure that organizes objects by their bounding boxes,
/// allowing efficient culling during hit testing and other spatial queries.
///
/// ## Algorithm
///
/// This implementation uses a top-down construction approach:
/// 1. Split objects into two groups based on their centroids along the longest axis
/// 2. Recursively build child nodes
/// 3. Stop when a leaf contains few enough objects (maxLeafSize)
///
/// ## Performance
///
/// - Construction: O(n log n) where n is the number of objects
/// - Query: O(log n) average case for point queries
/// - Space: O(n) for the tree structure
///
/// ## Usage
///
/// ```dart
/// final entries = objects.map((obj) => BVHEntry(
///   id: obj.id,
///   bounds: obj.bounds(),
///   data: obj,
/// )).toList();
///
/// final bvh = BVH.build(entries);
///
/// final hits = bvh.query(queryPoint, tolerance: 5.0);
/// ```
class BVH<T> {
  /// The root node of the BVH tree.
  final BVHNode<T> root;

  /// Maximum number of entries in a leaf node before splitting.
  static const int maxLeafSize = 8;

  /// Creates a BVH with the given root node.
  const BVH._(this.root);

  /// Builds a BVH from a list of entries.
  ///
  /// If [entries] is empty, creates a BVH with an empty leaf node.
  factory BVH.build(List<BVHEntry<T>> entries) {
    if (entries.isEmpty) {
      return BVH._(BVHLeaf<T>(
        bounds: Bounds.zero(),
        entries: const [],
      ));
    }

    final root = _buildNode(entries);
    return BVH._(root);
  }

  /// Recursively builds a BVH node from a list of entries.
  static BVHNode<T> _buildNode<T>(List<BVHEntry<T>> entries) {
    // Compute bounds of all entries
    Bounds totalBounds = entries.first.bounds;
    for (int i = 1; i < entries.length; i++) {
      totalBounds = totalBounds.union(entries[i].bounds);
    }

    // Base case: create leaf if few enough entries
    if (entries.length <= maxLeafSize) {
      return BVHLeaf<T>(
        bounds: totalBounds,
        entries: entries,
      );
    }

    // Choose split axis (longest dimension)
    final useX = totalBounds.width >= totalBounds.height;

    // Sort entries by centroid along chosen axis
    entries.sort((a, b) {
      final aC = useX ? a.bounds.center.x : a.bounds.center.y;
      final bC = useX ? b.bounds.center.x : b.bounds.center.y;
      return aC.compareTo(bC);
    });

    // Split at median
    final mid = entries.length ~/ 2;
    final leftEntries = entries.sublist(0, mid);
    final rightEntries = entries.sublist(mid);

    // Recursively build children
    final leftChild = _buildNode(leftEntries);
    final rightChild = _buildNode(rightEntries);

    return BVHBranch<T>(
      bounds: totalBounds,
      left: leftChild,
      right: rightChild,
    );
  }

  /// Queries the BVH for entries whose bounds are within [tolerance] of [point].
  ///
  /// Returns a list of entries sorted by distance to the query point (nearest first).
  ///
  /// The [tolerance] parameter expands the query region. A tolerance of 5.0
  /// means we'll find all objects within 5 units of the point.
  List<BVHEntry<T>> query(Point point, {double tolerance = 5.0}) {
    final results = <BVHEntry<T>>[];
    _queryNode(root, point, tolerance, results);

    // Sort by distance to point
    results.sort((a, b) {
      final distA = a.bounds.distanceToPoint(point).abs();
      final distB = b.bounds.distanceToPoint(point).abs();
      return distA.compareTo(distB);
    });

    return results;
  }

  /// Recursively queries a node and its children.
  void _queryNode(
    BVHNode<T> node,
    Point point,
    double tolerance,
    List<BVHEntry<T>> results,
  ) {
    // Expand query bounds by tolerance
    final queryBounds = Bounds.fromCenter(
      center: point,
      width: tolerance * 2,
      height: tolerance * 2,
    );

    // Early exit if node bounds don't intersect query
    if (!node.bounds.intersects(queryBounds)) {
      // Also check if point is close enough to the bounds
      final distance = node.bounds.distanceToPoint(point);
      if (distance > tolerance) {
        return;
      }
    }

    if (node is BVHLeaf<T>) {
      // Leaf node: check each entry
      for (final entry in node.entries) {
        final distance = entry.bounds.distanceToPoint(point);
        if (distance <= tolerance) {
          results.add(entry);
        }
      }
    } else if (node is BVHBranch<T>) {
      // Branch node: recurse into children
      _queryNode(node.left, point, tolerance, results);
      _queryNode(node.right, point, tolerance, results);
    }
  }

  /// Queries all entries that intersect the given bounds.
  ///
  /// Useful for rectangle selection and viewport culling.
  List<BVHEntry<T>> queryBounds(Bounds queryBounds) {
    final results = <BVHEntry<T>>[];
    _queryBoundsNode(root, queryBounds, results);
    return results;
  }

  /// Recursively queries entries that intersect bounds.
  void _queryBoundsNode(
    BVHNode<T> node,
    Bounds queryBounds,
    List<BVHEntry<T>> results,
  ) {
    // Early exit if node bounds don't intersect query
    if (!node.bounds.intersects(queryBounds)) {
      return;
    }

    if (node is BVHLeaf<T>) {
      // Leaf node: check each entry
      for (final entry in node.entries) {
        if (entry.bounds.intersects(queryBounds)) {
          results.add(entry);
        }
      }
    } else if (node is BVHBranch<T>) {
      // Branch node: recurse into children
      _queryBoundsNode(node.left, queryBounds, results);
      _queryBoundsNode(node.right, queryBounds, results);
    }
  }

  /// Returns statistics about the BVH structure.
  ///
  /// Useful for debugging and profiling.
  BVHStats getStats() {
    int leafCount = 0;
    int branchCount = 0;
    int totalEntries = 0;
    int maxDepth = 0;

    void traverse(BVHNode<T> node, int depth) {
      maxDepth = maxDepth > depth ? maxDepth : depth;

      if (node is BVHLeaf<T>) {
        leafCount++;
        totalEntries += node.entries.length;
      } else if (node is BVHBranch<T>) {
        branchCount++;
        traverse(node.left, depth + 1);
        traverse(node.right, depth + 1);
      }
    }

    traverse(root, 0);

    return BVHStats(
      leafCount: leafCount,
      branchCount: branchCount,
      totalEntries: totalEntries,
      maxDepth: maxDepth,
      averageLeafSize: leafCount > 0 ? totalEntries / leafCount : 0,
    );
  }
}

/// Base class for BVH tree nodes.
sealed class BVHNode<T> {
  /// The bounding box encompassing all entries in this subtree.
  Bounds get bounds;
}

/// A leaf node containing actual entries.
class BVHLeaf<T> implements BVHNode<T> {
  @override
  final Bounds bounds;

  /// The entries stored in this leaf.
  final List<BVHEntry<T>> entries;

  const BVHLeaf({
    required this.bounds,
    required this.entries,
  });
}

/// A branch node with two children.
class BVHBranch<T> implements BVHNode<T> {
  @override
  final Bounds bounds;

  /// The left child node.
  final BVHNode<T> left;

  /// The right child node.
  final BVHNode<T> right;

  const BVHBranch({
    required this.bounds,
    required this.left,
    required this.right,
  });
}

/// An entry in the BVH containing an object and its bounding box.
class BVHEntry<T> {
  /// Unique identifier for this entry.
  final String id;

  /// The bounding box of this entry.
  final Bounds bounds;

  /// The user data associated with this entry.
  final T data;

  const BVHEntry({
    required this.id,
    required this.bounds,
    required this.data,
  });
}

/// Statistics about a BVH structure.
class BVHStats {
  /// Number of leaf nodes in the tree.
  final int leafCount;

  /// Number of branch nodes in the tree.
  final int branchCount;

  /// Total number of entries across all leaves.
  final int totalEntries;

  /// Maximum depth of the tree.
  final int maxDepth;

  /// Average number of entries per leaf.
  final double averageLeafSize;

  const BVHStats({
    required this.leafCount,
    required this.branchCount,
    required this.totalEntries,
    required this.maxDepth,
    required this.averageLeafSize,
  });

  @override
  String toString() => 'BVHStats('
      'leaves: $leafCount, '
      'branches: $branchCount, '
      'entries: $totalEntries, '
      'maxDepth: $maxDepth, '
      'avgLeafSize: ${averageLeafSize.toStringAsFixed(1)}'
      ')';
}
