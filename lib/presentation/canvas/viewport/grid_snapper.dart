import 'dart:ui';

import 'package:wiretuner/domain/events/event_base.dart' as event_base;
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';

/// Configuration for grid snapping behavior.
///
/// Controls how the grid snapping system behaves, including grid size,
/// enabled state, and visual properties.
class GridSnapConfig {
  /// Creates a grid snap configuration.
  const GridSnapConfig({
    this.enabled = true,
    this.gridSize = 10.0,
    this.showGrid = true,
    this.snapThreshold = 5.0,
  });

  /// Whether grid snapping is enabled.
  ///
  /// When false, [GridSnapper.snapPointToGrid] returns the original point.
  final bool enabled;

  /// The grid size in screen pixels.
  ///
  /// This represents the spacing between grid lines. The grid is always
  /// defined in screen space, so it appears uniform regardless of zoom level.
  final double gridSize;

  /// Whether to show the grid visually.
  ///
  /// When true, the grid should be rendered on the canvas.
  final bool showGrid;

  /// The snap threshold in screen pixels.
  ///
  /// Points within this distance from a grid line will snap to it.
  /// Must be less than or equal to gridSize / 2 for predictable behavior.
  final double snapThreshold;

  /// Creates a copy of this configuration with some fields replaced.
  GridSnapConfig copyWith({
    bool? enabled,
    double? gridSize,
    bool? showGrid,
    double? snapThreshold,
  }) =>
      GridSnapConfig(
        enabled: enabled ?? this.enabled,
        gridSize: gridSize ?? this.gridSize,
        showGrid: showGrid ?? this.showGrid,
        snapThreshold: snapThreshold ?? this.snapThreshold,
      );

  @override
  String toString() => 'GridSnapConfig('
      'enabled: $enabled, '
      'gridSize: $gridSize, '
      'showGrid: $showGrid, '
      'snapThreshold: $snapThreshold)';
}

/// Service that provides screen-space grid snapping functionality.
///
/// The GridSnapper implements grid snapping in screen space, ensuring that
/// the grid appears uniform and consistent regardless of the viewport zoom level.
/// This is mandated by FR-028 and Section 7.11 of the architecture.
///
/// ## Screen-Space vs World-Space Snapping
///
/// **Screen-space snapping** (implemented here):
/// - Grid lines are spaced uniformly in pixels on screen
/// - Grid appears consistent at all zoom levels
/// - Snapping behavior feels natural to the user
/// - Grid size is independent of document scale
///
/// **World-space snapping** (NOT used):
/// - Grid lines would be spaced in world coordinates
/// - Grid would appear larger/smaller when zooming
/// - Snapping would feel inconsistent at different zooms
///
/// ## Algorithm
///
/// 1. Convert world point to screen coordinates
/// 2. Snap screen coordinates to nearest grid intersection
/// 3. Convert snapped screen coordinates back to world
///
/// This ensures the snapping is perceived as uniform by the user.
///
/// ## Usage
///
/// ```dart
/// final snapper = GridSnapper(
///   config: GridSnapConfig(gridSize: 10.0, enabled: true),
/// );
///
/// // Snap a world point to grid
/// final snappedPoint = snapper.snapPointToGrid(
///   worldPoint,
///   viewportController,
/// );
///
/// // Snap a distance
/// final snappedDistance = snapper.snapDistanceToGrid(
///   worldDistance,
///   viewportController,
/// );
/// ```
class GridSnapper {
  /// Creates a grid snapper with the given configuration.
  GridSnapper({
    this.config = const GridSnapConfig(),
  });

  /// Current grid configuration.
  GridSnapConfig config;

  /// Snaps a world-space point to the nearest grid intersection.
  ///
  /// This method performs screen-space snapping by:
  /// 1. Converting the world point to screen coordinates
  /// 2. Snapping screen coordinates to grid
  /// 3. Converting back to world coordinates
  ///
  /// If snapping is disabled, returns the original point.
  ///
  /// The [worldPoint] is the point to snap, in world coordinates.
  /// The [controller] provides the coordinate transformation.
  ///
  /// Returns the snapped point in world coordinates.
  ///
  /// Example:
  /// ```dart
  /// final snapped = snapper.snapPointToGrid(
  ///   Point(x: 105.3, y: 203.7),
  ///   viewportController,
  /// );
  /// // If gridSize is 10px and zoom is 1.0, snapped might be Point(x: 110, y: 200)
  /// ```
  event_base.Point snapPointToGrid(
    event_base.Point worldPoint,
    ViewportController controller,
  ) {
    // If snapping is disabled, return original point
    if (!config.enabled) {
      return worldPoint;
    }

    // Convert world point to screen coordinates
    final screenOffset = controller.worldToScreen(worldPoint);

    // Snap screen coordinates to grid
    final snappedScreen = _snapScreenOffset(screenOffset);

    // Convert back to world coordinates
    return controller.screenToWorld(snappedScreen);
  }

  /// Snaps a world-space distance to the nearest grid increment.
  ///
  /// This is useful for snapping sizes or deltas rather than absolute positions.
  /// The snapping is performed in screen space to maintain consistency.
  ///
  /// If snapping is disabled, returns the original distance.
  ///
  /// The [worldDistance] is the distance to snap, in world units.
  /// The [controller] provides the coordinate transformation.
  ///
  /// Returns the snapped distance in world units.
  ///
  /// Example:
  /// ```dart
  /// final snappedSize = snapper.snapDistanceToGrid(
  ///   103.7,
  ///   viewportController,
  /// );
  /// // If gridSize is 10px and zoom is 1.0, result might be 100.0
  /// ```
  double snapDistanceToGrid(
    double worldDistance,
    ViewportController controller,
  ) {
    // If snapping is disabled, return original distance
    if (!config.enabled) {
      return worldDistance;
    }

    // Convert world distance to screen distance
    final screenDistance = controller.worldDistanceToScreen(worldDistance);

    // Snap to grid in screen space
    final snappedScreen = _snapToGrid(screenDistance);

    // Convert back to world distance
    return controller.screenDistanceToWorld(snappedScreen);
  }

  /// Checks if a world-space point would snap to the grid.
  ///
  /// Returns true if the point is within the snap threshold of a grid line.
  /// This can be used to provide visual feedback before actually snapping.
  ///
  /// Example:
  /// ```dart
  /// if (snapper.wouldSnap(point, controller)) {
  ///   // Show snap indicator
  /// }
  /// ```
  bool wouldSnap(
    event_base.Point worldPoint,
    ViewportController controller,
  ) {
    if (!config.enabled) {
      return false;
    }

    final screenOffset = controller.worldToScreen(worldPoint);
    final snappedScreen = _snapScreenOffset(screenOffset);

    // Calculate distance between original and snapped positions
    final dx = (screenOffset.dx - snappedScreen.dx).abs();
    final dy = (screenOffset.dy - snappedScreen.dy).abs();

    // Check if within snap threshold
    return dx <= config.snapThreshold || dy <= config.snapThreshold;
  }

  /// Calculates the nearest grid line position for a given screen coordinate.
  ///
  /// Returns the screen-space coordinate of the nearest grid line.
  double _snapToGrid(double value) {
    final gridSize = config.gridSize;
    if (gridSize <= 0) return value;

    // Round to nearest grid increment
    return (value / gridSize).round() * gridSize;
  }

  /// Snaps a screen-space offset to the nearest grid intersection.
  ///
  /// This is an internal helper that performs the actual snapping in screen space.
  Offset _snapScreenOffset(Offset offset) => Offset(
        _snapToGrid(offset.dx),
        _snapToGrid(offset.dy),
      );

  /// Generates grid line positions for rendering.
  ///
  /// Returns a list of screen-space coordinates where grid lines should
  /// be drawn. This is useful for rendering the grid overlay.
  ///
  /// The [canvasSize] specifies the visible screen area.
  /// The [controller] provides the viewport transformation.
  ///
  /// Returns a record with:
  /// - verticalLines: X coordinates for vertical lines
  /// - horizontalLines: Y coordinates for horizontal lines
  ///
  /// Example:
  /// ```dart
  /// final grid = snapper.generateGridLines(canvasSize, controller);
  /// for (final x in grid.verticalLines) {
  ///   canvas.drawLine(
  ///     Offset(x, 0),
  ///     Offset(x, canvasSize.height),
  ///     gridPaint,
  ///   );
  /// }
  /// ```
  ({List<double> verticalLines, List<double> horizontalLines}) generateGridLines(
    Size canvasSize,
    ViewportController controller,
  ) {
    if (!config.showGrid || config.gridSize <= 0) {
      return (verticalLines: [], horizontalLines: []);
    }

    final gridSize = config.gridSize;
    final verticalLines = <double>[];
    final horizontalLines = <double>[];

    // Generate vertical grid lines (X positions)
    // Start from first grid line visible on left, continue until right edge
    final startX = (0.0 / gridSize).floor() * gridSize;
    for (var x = startX; x <= canvasSize.width; x += gridSize) {
      if (x >= 0) {
        verticalLines.add(x);
      }
    }

    // Generate horizontal grid lines (Y positions)
    // Start from first grid line visible on top, continue until bottom edge
    final startY = (0.0 / gridSize).floor() * gridSize;
    for (var y = startY; y <= canvasSize.height; y += gridSize) {
      if (y >= 0) {
        horizontalLines.add(y);
      }
    }

    return (verticalLines: verticalLines, horizontalLines: horizontalLines);
  }

  /// Calculates the grid offset for rendering.
  ///
  /// Returns the screen-space offset where the grid origin (0, 0) appears.
  /// This is useful for rendering grid patterns that need to align with
  /// the viewport transformation.
  Offset getGridOriginOffset(ViewportController controller) {
    const worldOrigin = event_base.Point(x: 0, y: 0);
    final screenOrigin = controller.worldToScreen(worldOrigin);
    return Offset(
      screenOrigin.dx % config.gridSize,
      screenOrigin.dy % config.gridSize,
    );
  }
}
