import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:wiretuner/domain/events/event_base.dart' as event_base;
import 'package:wiretuner/domain/models/geometry/point_extensions.dart';
import 'package:wiretuner/domain/models/geometry/rectangle.dart' as geom;
import 'package:wiretuner/domain/models/path.dart' as domain;
import 'package:wiretuner/domain/models/shape.dart';
import 'package:wiretuner/presentation/canvas/overlays/selection_overlay.dart';
import 'package:wiretuner/presentation/canvas/painter/path_renderer.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';

/// Result of a hit test operation.
class HitTestResult {
  /// The ID of the object that was hit (if any).
  final String? objectId;

  /// The index of the anchor point that was hit (if any).
  final int? anchorIndex;

  /// The specific component that was hit (anchor, handleIn, handleOut).
  final AnchorComponent? component;

  /// Distance from the hit test point to the hit object (in world space).
  final double distance;

  const HitTestResult({
    this.objectId,
    this.anchorIndex,
    this.component,
    required this.distance,
  });

  /// Returns true if this result represents a hit.
  bool get isHit => objectId != null;

  /// Returns true if this is an anchor hit (not just an object).
  bool get isAnchorHit => anchorIndex != null;

  /// Creates a result representing no hit.
  factory HitTestResult.miss() => const HitTestResult(
        distance: double.infinity,
      );

  @override
  String toString() => 'HitTestResult(objectId: $objectId, '
      'anchorIndex: $anchorIndex, component: $component, distance: $distance)';
}

/// Service for performing hit-testing on canvas objects.
///
/// CanvasHitTester provides efficient hit-testing for:
/// - Object selection (clicking on paths/shapes)
/// - Anchor point selection (clicking on vertices)
/// - Handle selection (clicking on Bezier control points)
///
/// ## Hit-Testing Strategy
///
/// Uses a two-phase approach:
/// 1. **Coarse phase**: Bounding box checks to quickly eliminate most objects
/// 2. **Fine phase**: Precise distance calculations for candidates
///
/// ## Performance
///
/// - Early rejection via AABB tests (O(1) per object)
/// - Spatial queries in world space (avoids repeated transformations)
/// - Returns results sorted by distance (nearest first)
///
/// ## Usage
///
/// ```dart
/// final hitTester = CanvasHitTester(
///   viewportController: viewportController,
///   pathRenderer: pathRenderer,
/// );
///
/// // Hit test for objects
/// final objectHit = hitTester.hitTestObjects(
///   screenPoint: mousePosition,
///   paths: document.paths,
///   shapes: document.shapes,
/// );
///
/// // Hit test for anchors within an object
/// final anchorHit = hitTester.hitTestAnchors(
///   screenPoint: mousePosition,
///   objectId: 'path-123',
///   path: path,
/// );
/// ```
class CanvasHitTester {
  /// Viewport controller for coordinate transformations.
  final ViewportController viewportController;

  /// Path renderer for accessing cached geometry.
  final PathRenderer pathRenderer;

  /// Hit test threshold in screen pixels.
  ///
  /// Objects/anchors within this distance are considered "hit".
  final double hitThresholdScreenPx;

  /// Creates a hit tester with the specified configuration.
  ///
  /// The [hitThresholdScreenPx] controls how close the cursor must be
  /// to an object/anchor to register a hit. Default is 8px, which provides
  /// good balance between precision and usability.
  CanvasHitTester({
    required this.viewportController,
    required this.pathRenderer,
    this.hitThresholdScreenPx = 8.0,
  });

  /// Hit tests objects at the specified screen point.
  ///
  /// Returns the nearest hit object, or a miss result if nothing was hit.
  ///
  /// Parameters:
  /// - [screenPoint]: The point to test in screen coordinates
  /// - [paths]: Map of path objects by ID
  /// - [shapes]: Map of shape objects by ID
  HitTestResult hitTestObjects({
    required Offset screenPoint,
    required Map<String, domain.Path> paths,
    required Map<String, Shape> shapes,
  }) {
    final worldPoint = viewportController.screenToWorld(screenPoint);
    final worldThreshold =
        viewportController.screenDistanceToWorld(hitThresholdScreenPx);

    HitTestResult? bestResult;

    // Test paths
    for (final entry in paths.entries) {
      final objectId = entry.key;
      final path = entry.value;

      final result = _hitTestPath(
        worldPoint: worldPoint,
        worldThreshold: worldThreshold,
        objectId: objectId,
        path: path,
      );

      if (result.isHit &&
          (bestResult == null || result.distance < bestResult.distance)) {
        bestResult = result;
      }
    }

    // Test shapes
    for (final entry in shapes.entries) {
      final objectId = entry.key;
      final shape = entry.value;

      final result = _hitTestShape(
        worldPoint: worldPoint,
        worldThreshold: worldThreshold,
        objectId: objectId,
        shape: shape,
      );

      if (result.isHit &&
          (bestResult == null || result.distance < bestResult.distance)) {
        bestResult = result;
      }
    }

    return bestResult ?? HitTestResult.miss();
  }

  /// Hit tests anchors within a specific object.
  ///
  /// Returns the nearest hit anchor/handle, or a miss result if nothing was hit.
  ///
  /// This is more precise than object hit-testing and is used for direct
  /// manipulation of anchor points.
  ///
  /// Parameters:
  /// - [screenPoint]: The point to test in screen coordinates
  /// - [objectId]: The ID of the object containing the anchors
  /// - [path]: The path object (if testing a path)
  /// - [shape]: The shape object (if testing a shape)
  HitTestResult hitTestAnchors({
    required Offset screenPoint,
    required String objectId,
    domain.Path? path,
    Shape? shape,
  }) {
    assert(path != null || shape != null, 'Must provide either path or shape');

    final worldPoint = viewportController.screenToWorld(screenPoint);
    final worldThreshold =
        viewportController.screenDistanceToWorld(hitThresholdScreenPx);

    // Convert shape to path if needed
    final domainPath = path ?? shape!.toPath();

    HitTestResult? bestResult;

    // Test each anchor and its handles
    for (int i = 0; i < domainPath.anchors.length; i++) {
      final anchor = domainPath.anchors[i];

      // Test handleIn
      if (anchor.handleIn != null) {
        final handlePos = anchor.position + anchor.handleIn!;
        final distance = worldPoint.distanceTo(handlePos);

        if (distance <= worldThreshold) {
          final result = HitTestResult(
            objectId: objectId,
            anchorIndex: i,
            component: AnchorComponent.handleIn,
            distance: distance,
          );

          if (bestResult == null || result.distance < bestResult.distance) {
            bestResult = result;
          }
        }
      }

      // Test handleOut
      if (anchor.handleOut != null) {
        final handlePos = anchor.position + anchor.handleOut!;
        final distance = worldPoint.distanceTo(handlePos);

        if (distance <= worldThreshold) {
          final result = HitTestResult(
            objectId: objectId,
            anchorIndex: i,
            component: AnchorComponent.handleOut,
            distance: distance,
          );

          if (bestResult == null || result.distance < bestResult.distance) {
            bestResult = result;
          }
        }
      }

      // Test anchor point itself
      final distance = worldPoint.distanceTo(anchor.position);

      if (distance <= worldThreshold) {
        final result = HitTestResult(
          objectId: objectId,
          anchorIndex: i,
          component: AnchorComponent.anchor,
          distance: distance,
        );

        if (bestResult == null || result.distance < bestResult.distance) {
          bestResult = result;
        }
      }
    }

    return bestResult ?? HitTestResult.miss();
  }

  /// Hit tests a path object.
  HitTestResult _hitTestPath({
    required event_base.Point worldPoint,
    required double worldThreshold,
    required String objectId,
    required domain.Path path,
  }) {
    // Phase 1: Coarse bounding box check
    final bounds = path.bounds();
    if (!_boundsContainsPoint(bounds, worldPoint, worldThreshold)) {
      return HitTestResult.miss();
    }

    // Phase 2: Fine path containment check
    final uiPath = pathRenderer.getOrCreatePathFromDomain(
      objectId: objectId,
      domainPath: path,
      currentZoom: viewportController.zoomLevel,
    );

    // Check if point is inside path
    if (uiPath.contains(Offset(worldPoint.x, worldPoint.y))) {
      return HitTestResult(
        objectId: objectId,
        distance: 0.0, // Inside path
      );
    }

    // Check if point is near path stroke
    // For now, we use a simple distance-to-anchors heuristic
    // Future: implement proper distance-to-curve calculation
    double minDistance = double.infinity;

    for (final anchor in path.anchors) {
      final distance = worldPoint.distanceTo(anchor.position);
      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    if (minDistance <= worldThreshold) {
      return HitTestResult(
        objectId: objectId,
        distance: minDistance,
      );
    }

    return HitTestResult.miss();
  }

  /// Hit tests a shape object.
  HitTestResult _hitTestShape({
    required event_base.Point worldPoint,
    required double worldThreshold,
    required String objectId,
    required Shape shape,
  }) {
    // Convert shape to path for hit-testing
    final path = shape.toPath();

    return _hitTestPath(
      worldPoint: worldPoint,
      worldThreshold: worldThreshold,
      objectId: objectId,
      path: path,
    );
  }

  /// Checks if a bounding box contains or is near a point.
  bool _boundsContainsPoint(
    geom.Rectangle bounds,
    event_base.Point point,
    double threshold,
  ) {
    // Expand bounds by threshold
    final expandedLeft = bounds.x - threshold;
    final expandedTop = bounds.y - threshold;
    final expandedRight = bounds.x + bounds.width + threshold;
    final expandedBottom = bounds.y + bounds.height + threshold;

    return point.x >= expandedLeft &&
        point.x <= expandedRight &&
        point.y >= expandedTop &&
        point.y <= expandedBottom;
  }
}
