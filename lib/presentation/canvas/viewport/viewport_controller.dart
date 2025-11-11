import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:wiretuner/domain/events/event_base.dart' as event_base;

/// Controls viewport transformations for the canvas, including pan and zoom.
///
/// The ViewportController manages the coordinate transformation between:
/// - **World space**: The coordinate system of the document (infinite canvas)
/// - **Screen space**: The coordinate system of the viewport widget (pixels)
///
/// ## Coordinate Transformation
///
/// The transformation is composed of:
/// 1. Scale (zoom): Magnifies or reduces the world
/// 2. Translate (pan): Positions the world within the viewport
///
/// Matrix composition: `screen = translate(pan) * scale(zoom) * world`
///
/// ## Zoom Constraints
///
/// Zoom is clamped to the range [0.05, 8.0]:
/// - Minimum (0.05): 5% scale, zoomed way out
/// - Maximum (8.0): 800% scale, zoomed way in
///
/// ## Usage
///
/// ```dart
/// final controller = ViewportController();
///
/// // Pan the viewport
/// controller.pan(Offset(100, 50));
///
/// // Zoom with focal point (e.g., mouse position)
/// controller.zoom(1.2, focalPoint: Offset(400, 300));
///
/// // Convert between coordinate spaces
/// final screenPoint = controller.worldToScreen(Point(x: 100, y: 100));
/// final worldPoint = controller.screenToWorld(Offset(400, 300));
/// ```
///
/// The controller extends [ChangeNotifier] to support reactive UI updates.
/// Widgets should listen to changes and rebuild when transformations change.
class ViewportController extends ChangeNotifier {
  /// Creates a viewport controller with optional initial state.
  ///
  /// [initialPan] defaults to zero offset (world origin at screen origin).
  /// [initialZoom] defaults to 1.0 (100% scale) and is clamped to valid range.
  ViewportController({
    Offset initialPan = Offset.zero,
    double initialZoom = 1.0,
  })  : _panOffset = initialPan,
        _zoom = initialZoom.clamp(minZoom, maxZoom),
        _worldToScreenMatrix = Matrix4.identity(),
        _screenToWorldMatrix = Matrix4.identity() {
    _updateMatrices();
  }

  /// Minimum allowed zoom level (5%).
  static const double minZoom = 0.05;

  /// Maximum allowed zoom level (800%).
  static const double maxZoom = 8.0;

  /// Current pan offset in screen pixels.
  Offset _panOffset;

  /// Current zoom level (1.0 = 100%).
  double _zoom;

  /// Cached world-to-screen transformation matrix.
  ///
  /// Recomputed when [_zoom] or [_panOffset] changes.
  Matrix4 _worldToScreenMatrix;

  /// Cached screen-to-world transformation matrix.
  ///
  /// Recomputed when [_zoom] or [_panOffset] changes.
  /// This is the inverse of [_worldToScreenMatrix].
  Matrix4 _screenToWorldMatrix;

  /// The current pan offset in screen pixels.
  Offset get panOffset => _panOffset;

  /// The current zoom level (1.0 = 100%).
  double get zoomLevel => _zoom;

  /// Returns the world-to-screen transformation matrix.
  ///
  /// This matrix converts world coordinates to screen coordinates:
  /// `screenPoint = worldToScreenMatrix * worldPoint`
  ///
  /// The matrix is cached and recomputed only when zoom or pan changes.
  Matrix4 get worldToScreenMatrix => _worldToScreenMatrix.clone();

  /// Returns the screen-to-world transformation matrix.
  ///
  /// This matrix converts screen coordinates to world coordinates:
  /// `worldPoint = screenToWorldMatrix * screenPoint`
  ///
  /// This is the inverse of [worldToScreenMatrix].
  Matrix4 get screenToWorldMatrix => _screenToWorldMatrix.clone();

  /// Pans the viewport by the specified delta in screen pixels.
  ///
  /// Positive deltas move the world right/down in screen space.
  /// This is typically called in response to drag gestures.
  ///
  /// Example:
  /// ```dart
  /// // Pan right by 50 pixels, down by 30 pixels
  /// controller.pan(Offset(50, 30));
  /// ```
  void pan(Offset delta) {
    _panOffset += delta;
    _updateMatrices();
    notifyListeners();
  }

  /// Updates the pan offset to an absolute value.
  ///
  /// This directly sets the pan offset rather than adding to it.
  ///
  /// Example:
  /// ```dart
  /// controller.setPan(Offset(100, 200));
  /// ```
  void setPan(Offset offset) {
    _panOffset = offset;
    _updateMatrices();
    notifyListeners();
  }

  /// Zooms the viewport by the specified factor around a focal point.
  ///
  /// The [factor] is multiplicative (e.g., 1.2 = zoom in by 20%, 0.8 = zoom out by 20%).
  /// The [focalPoint] is in screen coordinates (e.g., mouse position).
  ///
  /// The zoom pivots around the focal point, meaning the world position under
  /// the focal point remains stationary in screen space.
  ///
  /// Example:
  /// ```dart
  /// // Zoom in by 20% around mouse position
  /// controller.zoom(1.2, focalPoint: mousePosition);
  ///
  /// // Zoom out by 20% around viewport center
  /// controller.zoom(0.8, focalPoint: viewportCenter);
  /// ```
  void zoom(double factor, {required Offset focalPoint}) {
    // Convert focal point to world space before zoom
    final worldFocalPoint = screenToWorld(focalPoint);

    // Update zoom with clamping
    final newZoom = (_zoom * factor).clamp(minZoom, maxZoom);

    // If zoom would be clamped to the same value, skip update
    if (newZoom == _zoom) return;

    _zoom = newZoom;

    // After zoom, recompute where the focal point is in screen space
    _updateMatrices();
    final newScreenFocalPoint = worldToScreen(worldFocalPoint);

    // Adjust pan to keep the focal point stationary
    final panCorrection = focalPoint - newScreenFocalPoint;
    _panOffset += panCorrection;

    _updateMatrices();
    notifyListeners();
  }

  /// Sets the zoom level to an absolute value.
  ///
  /// The zoom is clamped to the valid range [minZoom, maxZoom].
  /// The viewport is zoomed around the center (no focal point adjustment).
  ///
  /// Example:
  /// ```dart
  /// controller.setZoom(1.0); // Reset to 100%
  /// controller.setZoom(2.0); // Zoom to 200%
  /// ```
  void setZoom(double newZoom) {
    final clampedZoom = newZoom.clamp(minZoom, maxZoom);
    if (clampedZoom == _zoom) return;

    _zoom = clampedZoom;
    _updateMatrices();
    notifyListeners();
  }

  /// Converts a world coordinate point to screen coordinates.
  ///
  /// The [worldPoint] uses the domain [Point] type from event_base.
  /// Returns an [Offset] in screen pixel coordinates.
  ///
  /// Example:
  /// ```dart
  /// final screenPos = controller.worldToScreen(Point(x: 100, y: 50));
  /// // Use screenPos.dx and screenPos.dy for screen rendering
  /// ```
  Offset worldToScreen(event_base.Point worldPoint) {
    // Apply transformation: scale then translate
    final x = worldPoint.x * _zoom + _panOffset.dx;
    final y = worldPoint.y * _zoom + _panOffset.dy;
    return Offset(x, y);
  }

  /// Converts a screen coordinate offset to world coordinates.
  ///
  /// The [screenOffset] is in screen pixel coordinates.
  /// Returns a domain [Point] in world space.
  ///
  /// Example:
  /// ```dart
  /// final worldPos = controller.screenToWorld(mousePosition);
  /// // Use worldPos.x and worldPos.y for domain logic
  /// ```
  event_base.Point screenToWorld(Offset screenOffset) {
    // Reverse transformation: subtract translation then divide by scale
    final x = (screenOffset.dx - _panOffset.dx) / _zoom;
    final y = (screenOffset.dy - _panOffset.dy) / _zoom;
    return event_base.Point(x: x, y: y);
  }

  /// Converts a screen distance (e.g., from gesture delta) to world distance.
  ///
  /// This is useful for converting drag distances or sizes from screen to world space.
  /// Unlike [screenToWorld], this only applies the scale transformation (no translation).
  ///
  /// Example:
  /// ```dart
  /// final worldDistance = controller.screenDistanceToWorld(50.0);
  /// // If zoom is 2.0, worldDistance will be 25.0
  /// ```
  double screenDistanceToWorld(double screenDistance) => screenDistance / _zoom;

  /// Converts a world distance to screen distance.
  ///
  /// This is useful for converting world-space sizes to screen pixels.
  /// Unlike [worldToScreen], this only applies the scale transformation (no translation).
  ///
  /// Example:
  /// ```dart
  /// final screenDistance = controller.worldDistanceToScreen(100.0);
  /// // If zoom is 2.0, screenDistance will be 200.0
  /// ```
  double worldDistanceToScreen(double worldDistance) => worldDistance * _zoom;

  /// Resets the viewport to default state.
  ///
  /// Pan is set to zero and zoom is set to 1.0 (100%).
  void reset() {
    _panOffset = Offset.zero;
    _zoom = 1.0;
    _updateMatrices();
    notifyListeners();
  }

  /// Recomputes the transformation matrices based on current pan and zoom.
  ///
  /// The world-to-screen matrix is composed as:
  /// 1. Scale by zoom factor
  /// 2. Translate by pan offset
  ///
  /// The screen-to-world matrix is the inverse of world-to-screen.
  void _updateMatrices() {
    // Build world-to-screen transform: translate(pan) * scale(zoom)
    _worldToScreenMatrix = Matrix4.identity()
      ..translate(_panOffset.dx, _panOffset.dy)
      ..scale(_zoom, _zoom);

    // Build screen-to-world transform: inverse of world-to-screen
    _screenToWorldMatrix = Matrix4.identity()
      ..scale(1.0 / _zoom, 1.0 / _zoom)
      ..translate(-_panOffset.dx / _zoom, -_panOffset.dy / _zoom);
  }

  @override
  String toString() =>
      'ViewportController(pan: $_panOffset, zoom: ${_zoom.toStringAsFixed(2)})';
}
