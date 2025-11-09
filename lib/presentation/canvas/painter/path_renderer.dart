import 'dart:ui' as ui;

import 'package:wiretuner/domain/models/geometry/point_extensions.dart';
import 'package:wiretuner/domain/models/path.dart' as domain;
import 'package:wiretuner/domain/models/segment.dart';
import 'package:wiretuner/domain/models/shape.dart';

/// Cached data for a rendered path.
///
/// Contains the converted ui.Path along with metadata used for cache
/// invalidation decisions.
class _CachedPathData {
  _CachedPathData({
    required this.path,
    required this.zoomLevel,
    required this.domainHash,
  });

  /// The converted dart:ui Path ready for rendering.
  final ui.Path path;

  /// The zoom level at which this path was cached.
  ///
  /// Used to detect when zoom changes significantly enough to warrant
  /// regeneration (e.g., for LOD optimizations).
  final double zoomLevel;

  /// Hash of the domain object's geometry.
  ///
  /// Used to detect when the underlying domain object has changed
  /// and the cache needs invalidation.
  final int domainHash;
}

/// Service responsible for converting domain paths and shapes to ui.Path.
///
/// PathRenderer provides efficient conversion of domain geometry to Flutter's
/// rendering primitives with built-in caching to meet performance requirements.
///
/// ## Performance Strategy
///
/// - **Caching**: Converts paths once and caches by object ID
/// - **Invalidation**: Tracks domain hash and zoom level for smart invalidation
/// - **Shared Logic**: Both document painter and overlays use this service
///
/// ## Cache Invalidation
///
/// A cached path is invalidated when:
/// - The domain object's geometry changes (detected via hash)
/// - The viewport zoom changes beyond threshold (10% by default)
/// - Explicit invalidation is requested
///
/// ## Usage
///
/// ```dart
/// final renderer = PathRenderer();
///
/// // Get or create a ui.Path for a domain path
/// final uiPath = renderer.getOrCreatePathFromDomain(
///   objectId: 'path-123',
///   domainPath: path,
///   currentZoom: 1.0,
/// );
///
/// // Get or create a ui.Path from a shape (converts to path first)
/// final shapePath = renderer.getOrCreatePathFromShape(
///   objectId: 'shape-456',
///   shape: rectangle,
///   currentZoom: 1.0,
/// );
///
/// // Invalidate when object changes
/// renderer.invalidate('path-123');
///
/// // Clear all caches
/// renderer.invalidateAll();
/// ```
///
/// ## Coordinate Space
///
/// The returned ui.Path is in **world coordinates**. The viewport
/// transformation should be applied to the canvas before rendering.
class PathRenderer {
  /// Creates a PathRenderer with optional configuration.
  ///
  /// The [zoomInvalidationThreshold] controls how sensitive the cache is
  /// to zoom changes. Lower values mean more frequent regeneration but
  /// better quality at different zoom levels.
  PathRenderer({
    this.zoomInvalidationThreshold = 0.1,
  });

  /// Cache of converted paths indexed by object ID.
  final Map<String, _CachedPathData> _cache = {};

  /// Threshold for zoom-based cache invalidation.
  ///
  /// If the zoom level changes by more than this ratio, the cache is
  /// invalidated. Default is 0.1 (10% change).
  final double zoomInvalidationThreshold;

  /// Gets or creates a ui.Path from a domain Path.
  ///
  /// Returns a cached path if available and valid, otherwise converts
  /// the domain path to a ui.Path and caches it.
  ///
  /// Parameters:
  /// - [objectId]: Unique identifier for caching
  /// - [domainPath]: The domain path to convert
  /// - [currentZoom]: Current viewport zoom level for invalidation tracking
  ui.Path getOrCreatePathFromDomain({
    required String objectId,
    required domain.Path domainPath,
    required double currentZoom,
  }) {
    final domainHash = domainPath.hashCode;
    final cached = _cache[objectId];

    // Check if cache is valid
    if (cached != null && _isCacheValid(cached, domainHash, currentZoom)) {
      return cached.path;
    }

    // Convert and cache
    final uiPath = _convertDomainPathToUiPath(domainPath);
    _cache[objectId] = _CachedPathData(
      path: uiPath,
      zoomLevel: currentZoom,
      domainHash: domainHash,
    );

    return uiPath;
  }

  /// Gets or creates a ui.Path from a Shape.
  ///
  /// Converts the shape to a domain path first, then converts to ui.Path.
  /// The result is cached like domain paths.
  ///
  /// Parameters:
  /// - [objectId]: Unique identifier for caching
  /// - [shape]: The shape to convert
  /// - [currentZoom]: Current viewport zoom level for invalidation tracking
  ui.Path getOrCreatePathFromShape({
    required String objectId,
    required Shape shape,
    required double currentZoom,
  }) {
    final domainHash = shape.hashCode;
    final cached = _cache[objectId];

    // Check if cache is valid
    if (cached != null && _isCacheValid(cached, domainHash, currentZoom)) {
      return cached.path;
    }

    // Convert shape to path, then to ui.Path
    final domainPath = shape.toPath();
    final uiPath = _convertDomainPathToUiPath(domainPath);
    _cache[objectId] = _CachedPathData(
      path: uiPath,
      zoomLevel: currentZoom,
      domainHash: domainHash,
    );

    return uiPath;
  }

  /// Invalidates the cached path for a specific object.
  ///
  /// Call this when you know an object has changed and needs to be
  /// regenerated on the next render.
  void invalidate(String objectId) {
    _cache.remove(objectId);
  }

  /// Invalidates all cached paths.
  ///
  /// Call this when performing bulk operations or when the entire
  /// document changes.
  void invalidateAll() {
    _cache.clear();
  }

  /// Returns the number of cached paths.
  ///
  /// Useful for debugging and monitoring cache performance.
  int get cacheSize => _cache.length;

  /// Checks if a cached path is still valid.
  bool _isCacheValid(
    _CachedPathData cached,
    int currentDomainHash,
    double currentZoom,
  ) {
    // Check if domain object changed
    if (cached.domainHash != currentDomainHash) {
      return false;
    }

    // Check if zoom changed significantly
    final zoomRatio = (currentZoom - cached.zoomLevel).abs() / cached.zoomLevel;
    if (zoomRatio > zoomInvalidationThreshold) {
      return false;
    }

    return true;
  }

  /// Converts a domain Path to a dart:ui Path for rendering.
  ///
  /// This method walks through the path's anchors and segments,
  /// converting them to Canvas path commands:
  /// - First anchor: moveTo
  /// - Line segments: lineTo
  /// - Bezier segments: cubicTo with control points from handles
  /// - Closed paths: close() after last segment
  ///
  /// **Coordinate Space**: The returned path is in world coordinates.
  /// The viewport transformation (already applied to canvas) will convert
  /// it to screen coordinates during rendering.
  ///
  /// This is factored out from DocumentPainter to enable reuse by overlays
  /// and other rendering components.
  ui.Path _convertDomainPathToUiPath(domain.Path domainPath) {
    final path = ui.Path();

    if (domainPath.anchors.isEmpty) {
      return path;
    }

    // Move to first anchor
    final firstAnchor = domainPath.anchors.first;
    path.moveTo(firstAnchor.position.x, firstAnchor.position.y);

    // Draw explicit segments
    for (final segment in domainPath.segments) {
      _addSegmentToPath(path, segment, domainPath);
    }

    // For closed paths, add implicit closing segment
    if (domainPath.closed && domainPath.anchors.length > 1) {
      final lastAnchor = domainPath.anchors.last;
      final firstAnchor = domainPath.anchors.first;

      // Check if closing segment should be a curve
      final hasHandles =
          lastAnchor.handleOut != null || firstAnchor.handleIn != null;

      if (hasHandles) {
        // Compute control points for closing Bezier segment
        final cp1 = lastAnchor.handleOut != null
            ? lastAnchor.position + lastAnchor.handleOut!
            : lastAnchor.position;

        final cp2 = firstAnchor.handleIn != null
            ? firstAnchor.position + firstAnchor.handleIn!
            : firstAnchor.position;

        path.cubicTo(
          cp1.x,
          cp1.y,
          cp2.x,
          cp2.y,
          firstAnchor.position.x,
          firstAnchor.position.y,
        );
      }

      // Close the path
      path.close();
    }

    return path;
  }

  /// Adds a segment to the ui.Path.
  ///
  /// This method switches on the segment type and generates the appropriate
  /// Canvas path command:
  /// - LINE: lineTo(end position)
  /// - BEZIER: cubicTo(cp1, cp2, end position) using anchor handles
  void _addSegmentToPath(
    ui.Path path,
    Segment segment,
    domain.Path domainPath,
  ) {
    final startAnchor = domainPath.anchors[segment.startAnchorIndex];
    final endAnchor = domainPath.anchors[segment.endAnchorIndex];

    switch (segment.segmentType) {
      case SegmentType.line:
        // Straight line to end anchor
        path.lineTo(endAnchor.position.x, endAnchor.position.y);
        break;

      case SegmentType.bezier:
        // Cubic Bezier curve with control points from handles
        //
        // Control point 1: Start anchor's handleOut (relative to start position)
        // Control point 2: End anchor's handleIn (relative to end position)
        //
        // If a handle is null, default to the anchor position (degenerate curve)
        final cp1 = startAnchor.handleOut != null
            ? startAnchor.position + startAnchor.handleOut!
            : startAnchor.position;

        final cp2 = endAnchor.handleIn != null
            ? endAnchor.position + endAnchor.handleIn!
            : endAnchor.position;

        path.cubicTo(
          cp1.x,
          cp1.y,
          cp2.x,
          cp2.y,
          endAnchor.position.x,
          endAnchor.position.y,
        );
        break;

      case SegmentType.arc:
        // Arc segments not yet implemented in domain model
        // For now, fall back to straight line
        path.lineTo(endAnchor.position.x, endAnchor.position.y);
        break;
    }
  }
}
