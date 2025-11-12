import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/domain/models/path.dart' as domain;
import 'package:wiretuner/presentation/canvas/painter/document_painter.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';

/// Generates thumbnail images of document state for history panel.
///
/// Uses offscreen rendering with `ui.PictureRecorder` to create cached
/// thumbnail images without affecting main canvas rendering. Thumbnails
/// are memoized by operation group ID to avoid redundant rendering.
///
/// **Performance:**
/// - Target size: 120x80 pixels
/// - Offscreen rendering using `ui.PictureRecorder`
/// - Asynchronous image conversion via `toImage()`
/// - LRU cache with configurable size (default 50 thumbnails)
///
/// **Integration:**
/// ```dart
/// final generator = ThumbnailGenerator(
///   cacheSize: 50,
/// );
///
/// final imageBytes = await generator.generate(
///   groupId: 'group_123',
///   document: currentDocument,
/// );
/// ```
///
/// Related: Task I4.T4 (History Panel UI), Performance target 5k events/sec
class ThumbnailGenerator {
  /// Creates a thumbnail generator.
  ///
  /// [cacheSize]: Maximum number of thumbnails to cache (LRU)
  /// [thumbnailWidth]: Width of generated thumbnails in pixels
  /// [thumbnailHeight]: Height of generated thumbnails in pixels
  ThumbnailGenerator({
    int cacheSize = 50,
    this.thumbnailWidth = 120,
    this.thumbnailHeight = 80,
  }) : _cache = _LRUCache<String, ui.Image>(maxSize: cacheSize);

  final _LRUCache<String, ui.Image> _cache;

  /// Width of generated thumbnails.
  final int thumbnailWidth;

  /// Height of generated thumbnails.
  final int thumbnailHeight;

  /// Generates a thumbnail image for a document state.
  ///
  /// Returns cached image if available, otherwise renders off-screen.
  ///
  /// [groupId]: Unique identifier for caching (e.g., OperationGroup.groupId)
  /// [document]: Document snapshot to render
  /// [backgroundColor]: Optional background color (default: white)
  ///
  /// Returns `ui.Image` that can be drawn with `Canvas.drawImage()` or
  /// converted to bytes via `toByteData()`.
  Future<ui.Image?> generate({
    required String groupId,
    required Document document,
    Color backgroundColor = Colors.white,
  }) async {
    // Check cache first
    final cached = _cache.get(groupId);
    if (cached != null) {
      return cached;
    }

    // Render off-screen
    final image = await _renderOffscreen(
      document: document,
      backgroundColor: backgroundColor,
    );

    if (image != null) {
      _cache.put(groupId, image);
    }

    return image;
  }

  /// Renders document to an off-screen image.
  Future<ui.Image?> _renderOffscreen({
    required Document document,
    required Color backgroundColor,
  }) async {
    // Create picture recorder for off-screen rendering
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Fill background
    canvas.drawRect(
      Rect.fromLTWH(
          0, 0, thumbnailWidth.toDouble(), thumbnailHeight.toDouble()),
      Paint()..color = backgroundColor,
    );

    // Create temporary viewport controller for thumbnail view
    // Scale to fit document bounds within thumbnail size
    final viewportController = ViewportController(
      initialZoom: _calculateFitZoom(document),
      initialPan: _calculateCenterPan(document),
    );

    try {
      // Extract all paths from all layers in all artboards
      final allPaths = <domain.Path>[];
      for (final artboard in document.artboards) {
        for (final layer in artboard.layers) {
          for (final obj in layer.objects) {
            obj.when(
              path: (id, path, _) => allPaths.add(path),
              shape: (id, shape, _) {
                // Skip shapes for now or convert to path if needed
              },
            );
          }
        }
      }

      // Render document using DocumentPainter
      final painter = DocumentPainter(
        paths: allPaths,
        shapes: const {}, // No shapes in thumbnails for now
        viewportController: viewportController,
        strokeWidth: 1.0, // Thinner strokes for thumbnails
        strokeColor: Colors.black87,
        renderPipeline: null, // Skip pipeline for thumbnails
      );

      // Paint to off-screen canvas
      painter.paint(
        canvas,
        ui.Size(thumbnailWidth.toDouble(), thumbnailHeight.toDouble()),
      );

      // Convert picture to image
      final picture = recorder.endRecording();
      final image = await picture.toImage(thumbnailWidth, thumbnailHeight);

      return image;
    } catch (e) {
      debugPrint('[ThumbnailGenerator] Failed to render: $e');
      return null;
    } finally {
      viewportController.dispose();
    }
  }

  /// Calculates zoom level to fit document bounds in thumbnail.
  double _calculateFitZoom(Document document) {
    // Extract all paths from all layers in all artboards
    final allPaths = <domain.Path>[];
    for (final artboard in document.artboards) {
      for (final layer in artboard.layers) {
        for (final obj in layer.objects) {
          obj.when(
            path: (id, path, _) => allPaths.add(path),
            shape: (id, shape, _) {
              // Skip shapes for now
            },
          );
        }
      }
    }

    if (allPaths.isEmpty) {
      return 1.0;
    }

    // Calculate document bounding box
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final path in allPaths) {
      for (final anchor in path.anchors) {
        minX = minX < anchor.position.x ? minX : anchor.position.x;
        minY = minY < anchor.position.y ? minY : anchor.position.y;
        maxX = maxX > anchor.position.x ? maxX : anchor.position.x;
        maxY = maxY > anchor.position.y ? maxY : anchor.position.y;
      }
    }

    if (!minX.isFinite || !minY.isFinite || !maxX.isFinite || !maxY.isFinite) {
      return 1.0;
    }

    final docWidth = maxX - minX;
    final docHeight = maxY - minY;

    if (docWidth <= 0 || docHeight <= 0) {
      return 1.0;
    }

    // Add 10% padding
    final padding = 1.1;
    final scaleX = thumbnailWidth / (docWidth * padding);
    final scaleY = thumbnailHeight / (docHeight * padding);

    return scaleX < scaleY ? scaleX : scaleY;
  }

  /// Calculates pan offset to center document in thumbnail.
  Offset _calculateCenterPan(Document document) {
    // Extract all paths from all layers in all artboards
    final allPaths = <domain.Path>[];
    for (final artboard in document.artboards) {
      for (final layer in artboard.layers) {
        for (final obj in layer.objects) {
          obj.when(
            path: (id, path, _) => allPaths.add(path),
            shape: (id, shape, _) {
              // Skip shapes for now
            },
          );
        }
      }
    }

    if (allPaths.isEmpty) {
      return Offset.zero;
    }

    // Calculate document centroid
    double sumX = 0;
    double sumY = 0;
    int count = 0;

    for (final path in allPaths) {
      for (final anchor in path.anchors) {
        sumX += anchor.position.x;
        sumY += anchor.position.y;
        count++;
      }
    }

    if (count == 0) {
      return Offset.zero;
    }

    final centerX = sumX / count;
    final centerY = sumY / count;

    // Pan to center document in thumbnail
    return Offset(
      thumbnailWidth / 2 - centerX,
      thumbnailHeight / 2 - centerY,
    );
  }

  /// Invalidates all cached thumbnails.
  void invalidateCache() {
    _cache.clear();
  }

  /// Invalidates a specific thumbnail by group ID.
  void invalidate(String groupId) {
    _cache.remove(groupId);
  }

  /// Disposes resources.
  void dispose() {
    _cache.clear();
  }
}

/// Simple LRU cache implementation.
class _LRUCache<K, V> {
  _LRUCache({required this.maxSize});

  final int maxSize;
  final Map<K, V> _cache = {};
  final List<K> _accessOrder = [];

  V? get(K key) {
    final value = _cache[key];
    if (value != null) {
      // Move to end (most recently used)
      _accessOrder.remove(key);
      _accessOrder.add(key);
    }
    return value;
  }

  void put(K key, V value) {
    // Remove if exists (will re-add at end)
    if (_cache.containsKey(key)) {
      _accessOrder.remove(key);
    } else if (_cache.length >= maxSize) {
      // Evict least recently used
      final evictKey = _accessOrder.removeAt(0);
      _cache.remove(evictKey);
    }

    _cache[key] = value;
    _accessOrder.add(key);
  }

  void remove(K key) {
    _cache.remove(key);
    _accessOrder.remove(key);
  }

  void clear() {
    _cache.clear();
    _accessOrder.clear();
  }
}
