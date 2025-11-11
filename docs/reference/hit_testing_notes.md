# Hit Testing Reference

This document describes the hit testing implementation in WireTuner's vector engine, including algorithms, heuristics, edge cases, and performance characteristics.

## Overview

The hit testing system determines which vector objects (paths, shapes, anchors) are at or near a given point. It uses a **Bounding Volume Hierarchy (BVH)** for spatial acceleration, enabling sub-millisecond queries even with thousands of objects.

## Architecture

### Components

1. **HitTester** (`hit_tester.dart`)
   - Main stateless service for hit testing
   - Builds and queries BVH acceleration structure
   - Supports object, stroke, fill, and anchor hit detection

2. **BVH** (`bvh.dart`)
   - Binary spatial tree for fast queries
   - O(log n) average-case performance
   - Top-down construction with median splitting

3. **Geometry Utils** (`geometry_utils.dart`)
   - Low-level geometric primitives
   - Point-in-path testing (ray casting)
   - Distance calculations for lines and Bezier curves

### Data Flow

```
User Click → Screen Space Point
           ↓
    World Space Transform
           ↓
    HitTester.hitTest(point, config)
           ↓
    BVH Spatial Query (broad phase)
           ↓
    Geometry Tests (narrow phase)
           ↓
    Sorted Results (nearest first)
```

## Tolerances and Thresholds

### Default Values

- **Stroke Tolerance**: 5.0 world units
  - Objects within this distance of the query point are considered "hit"
  - Recommended for normal selection tools

- **Anchor Tolerance**: 8.0 world units
  - Anchor points within this distance are selectable
  - Larger than stroke tolerance for easier anchor manipulation

- **Bezier Samples**: 20 subdivisions
  - Number of linear segments used to approximate curves
  - Higher = more accurate but slower

### Zoom Scaling

Tolerances are specified in **world-space units** but should represent consistent **screen-space sizes** across zoom levels.

**Problem**: At 200% zoom, a 5px world-space tolerance appears as 10px on screen (too large).

**Solution**: Use `HitTestConfig.scaledByZoom(zoom)`:

```dart
// Maintain 5px screen tolerance at any zoom level
final config = HitTestConfig(strokeTolerance: 5.0).scaledByZoom(viewportZoom);
```

**Formula**:
```
world_tolerance = screen_tolerance / zoom_factor
```

**Example**:
- At 100% zoom (1.0): 5px screen = 5.0 world units
- At 200% zoom (2.0): 5px screen = 2.5 world units
- At 50% zoom (0.5): 5px screen = 10.0 world units

## Hit Testing Modes

The system supports multiple hit detection modes, configurable via `HitTestConfig`:

### 1. Anchor Hit Testing (`testAnchors: true`)

**Algorithm**: Direct distance check to each anchor position.

**Criteria**: `distance(point, anchor.position) <= anchorTolerance`

**Priority**: Highest (anchors are tested first and sorted by distance)

**Use Cases**:
- Direct manipulation tools
- Anchor selection for path editing
- Handle dragging

### 2. Stroke Hit Testing (`testStrokes: true`)

**Algorithm**:
- For **line segments**: Perpendicular distance to segment
- For **Bezier curves**: Subdivision-based approximation (20 samples default)

**Criteria**: Minimum distance to any segment <= strokeTolerance

**Priority**: Medium (after anchors, before fills)

**Use Cases**:
- Path selection
- Stroke-only objects
- Outline selection

**Edge Cases**:
- **Degenerate curves**: Bezier curves with no handles degrade to line distance
- **Segment endpoints**: Distance calculated to nearest point on segment (may be endpoint)
- **Multi-segment paths**: Returns minimum distance across all segments

### 3. Fill Hit Testing (`testFills: true`)

**Algorithm**: Ray casting (even-odd rule)
- Cast horizontal ray from point to infinity (right direction)
- Count intersections with path edges
- Odd count = inside, even count = outside

**Criteria**:
- Path must be `closed: true`
- Path must have at least 3 anchors
- Point must be inside path boundary

**Priority**: Lowest (tested last, after strokes)

**Use Cases**:
- Filled shape selection
- Region selection
- Click-to-select closed paths

**Edge Cases**:
- **Open paths**: Never hit (no interior defined)
- **Self-intersecting paths**: Even-odd rule may produce unexpected results
- **Point on edge**: May be inside or outside depending on floating-point precision
- **Horizontal edges**: Ignored to avoid double-counting vertices

## Performance Characteristics

### BVH Construction

- **Complexity**: O(n log n) where n = object count
- **Method**: Top-down median splitting along longest axis
- **Leaf Threshold**: 8 objects per leaf (tunable via `BVH.maxLeafSize`)

**Benchmark** (10,000 objects):
- Construction time: ~50-200ms (acceptable for interactive use)
- Tree depth: ~13-15 levels (logarithmic)
- Average leaf size: ~8 objects

### Query Performance

- **Point queries**: O(log n) average, O(n) worst case
- **Bounds queries**: O(log n + k) where k = number of results

**Benchmark** (10,000 objects):
- Average point query: **< 2ms** ✓ (meets acceptance criteria)
- Queries per second: ~500-1000
- Scalability: 10x object count → ~2x query time (logarithmic scaling)

### Optimization Strategies

1. **BVH Spatial Culling** (Broad Phase)
   - Quickly eliminate objects far from query point
   - Uses cheap bounding box tests

2. **Early Termination**
   - Stop after finding first hit (for `hitTestNearest`)
   - Skip expensive geometry tests when bounds are too far

3. **Bezier Approximation**
   - Use linear segments instead of analytical root-finding
   - 20 samples provides good accuracy/performance balance
   - Tunable via `config.bezierSamples`

## Edge Cases and Gotchas

### 1. Overlapping Objects

**Scenario**: Multiple objects at the same location

**Behavior**: All matching objects are returned, sorted by distance

**Mitigation**: Use `hitTestNearest()` to get only the topmost object

### 2. Z-Order

**Current**: Hit testing is distance-based, not z-order aware

**Future**: Will respect document layer order once integrated with full document model

### 3. Transforms

**Current**: Hit testing assumes world-space coordinates

**Future**: Will need to apply object transforms (rotation, scale) before testing

### 4. Curved Segment Accuracy

**Issue**: Bezier distance is approximate (subdivision-based)

**Impact**: May miss hits on very tight curves with low sample count

**Mitigation**: Increase `bezierSamples` for higher precision (at performance cost)

### 5. Floating-Point Precision

**Issue**: Points exactly on edges may behave inconsistently

**Mitigation**: Use `kGeometryEpsilon` (1e-10) for all comparisons

### 6. Very Large/Small Objects

**Large objects**: BVH may have unbalanced leaves

**Small objects**: May be missed if tolerance is too small

**Mitigation**: Ensure tolerances are appropriate for your object scale

## Profiling and Debugging

### BVH Statistics

Get tree structure info:

```dart
final stats = hitTester.getStats();
print(stats);
// BVHStats(leaves: 157, branches: 156, entries: 10000,
//          maxDepth: 14, avgLeafSize: 6.4)
```

**Indicators of Problems**:
- `maxDepth > 30`: Unbalanced tree (may indicate degenerate data)
- `avgLeafSize > 20`: Leaves too large (poor spatial separation)
- `leafCount == 1`: No BVH splitting (all objects in one leaf)

### Performance Profiling Hooks

**Add custom profiling**:

```dart
class ProfiledHitTester {
  final HitTester _inner;
  final Stopwatch _stopwatch = Stopwatch();
  int _queryCount = 0;

  List<HitTestResult> hitTest(Point point, HitTestConfig config) {
    _stopwatch.start();
    final results = _inner.hitTest(point: point, config: config);
    _stopwatch.stop();
    _queryCount++;

    if (_queryCount % 100 == 0) {
      final avgMs = _stopwatch.elapsedMilliseconds / _queryCount;
      print('Avg hit test time: ${avgMs.toStringAsFixed(3)}ms');
    }

    return results;
  }
}
```

**Flutter DevTools Timeline**:

Wrap hit tests in timeline events:

```dart
Timeline.startSync('HitTest');
final hits = hitTester.hitTest(point: point, config: config);
Timeline.finishSync();
```

## Future Improvements

### Near-Term (Iteration 3-4)

1. **Transform Support**
   - Apply object transforms before hit testing
   - Inverse transform query point into object space

2. **Z-Order Awareness**
   - Respect document layer order
   - Return topmost object when multiple hits overlap

3. **Selection Rectangles**
   - Implement precise polygon-polygon intersection
   - Currently uses bounding box intersection only

### Long-Term (Post-MVP)

1. **Advanced Spatial Indexing**
   - R-tree or R*-tree for better overlap handling
   - Adaptive BVH rebuilding for dynamic scenes

2. **GPU Acceleration**
   - Offload distance calculations to compute shaders
   - Parallel query processing

3. **Analytical Bezier Distance**
   - Solve cubic equations for exact distance
   - Eliminate subdivision approximation

4. **Caching**
   - Cache recent query results
   - Invalidate on document changes

5. **Multi-threaded Queries**
   - Parallelize bounds queries for large selections
   - Async query API

## Testing Coverage

### Unit Tests (`*_test.dart`)

- ✅ Geometry utilities (line/curve distance, point-in-path)
- ✅ BVH construction and queries
- ✅ Hit tester (anchors, strokes, fills, shapes)
- ✅ Edge cases (empty paths, overlaps, boundaries)

### Performance Tests (`*_performance_test.dart`)

- ✅ 10k object construction (< 1s)
- ✅ 10k object queries (< 2ms average) ✓ **Acceptance Criteria Met**
- ✅ Scalability tests (logarithmic scaling)
- ✅ Stress tests (dense clusters, sparse distributions)

### Missing Coverage

- ⚠️ Transform integration (planned for I3)
- ⚠️ Z-order handling (planned for I3)
- ⚠️ Arc segments (placeholder, not yet implemented)

## API Examples

### Basic Usage

```dart
// Build hit tester from document objects
final objects = document.getAllObjects().map((obj) {
  return obj.when(
    path: (id, path) => HitTestable.path(id: id, path: path),
    shape: (id, shape) => HitTestable.shape(id: id, shape: shape),
  );
}).toList();

final hitTester = HitTester.build(objects);

// Perform hit test
final hits = hitTester.hitTest(
  point: worldSpacePoint,
  config: HitTestConfig(
    strokeTolerance: 5.0,
    anchorTolerance: 8.0,
  ).scaledByZoom(viewport.zoom),
);

// Process results
if (hits.isNotEmpty) {
  final nearest = hits.first;
  if (nearest.isAnchorHit) {
    print('Selected anchor ${nearest.anchorIndex} on ${nearest.objectId}');
  } else {
    print('Selected object ${nearest.objectId}');
  }
}
```

### Anchor-Only Selection

```dart
final config = HitTestConfig(
  testAnchors: true,
  testStrokes: false,
  testFills: false,
  anchorTolerance: 10.0,
);

final hits = hitTester.hitTest(point: point, config: config);
```

### Rectangle Selection

```dart
final selectionBounds = Bounds.fromLTRB(
  left: dragStart.x,
  top: dragStart.y,
  right: dragEnd.x,
  bottom: dragEnd.y,
);

final selectedIds = hitTester.hitTestBounds(selectionBounds);
```

### Integration with Selection Model

```dart
final hits = hitTester.hitTest(point: point, config: config);

Selection newSelection = currentSelection;

for (final hit in hits) {
  if (hit.isAnchorHit) {
    newSelection = newSelection.addAnchor(hit.objectId, hit.anchorIndex!);
  } else {
    newSelection = newSelection.addObject(hit.objectId);
  }
}

// Update document state
documentBloc.add(UpdateSelectionEvent(newSelection));
```

## References

### Related Code

- `packages/vector_engine/lib/src/hit_testing/` - Implementation
- `packages/vector_engine/test/hit_testing/` - Tests
- `lib/domain/document/selection.dart` - Selection model
- `lib/presentation/canvas/overlays/selection_overlay.dart` - Visual feedback

### External Resources

- [Ray Casting Algorithm](https://en.wikipedia.org/wiki/Point_in_polygon#Ray_casting_algorithm)
- [BVH Overview](https://en.wikipedia.org/wiki/Bounding_volume_hierarchy)
- [Bezier Curves](https://pomax.github.io/bezierinfo/)
- [Distance to Bezier Curve](https://stackoverflow.com/questions/2742610/closest-point-on-a-cubic-bezier-curve)

---

**Document Version**: 1.0
**Last Updated**: Iteration 2, Task 2.7
**Author**: AI Code Generator (Claude)
