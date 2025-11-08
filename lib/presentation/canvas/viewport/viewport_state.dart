import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:wiretuner/domain/document/document.dart' as domain;
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';

/// Manages viewport gesture state and coordinates between UI gestures and
/// domain model updates.
///
/// ViewportState bridges the gap between:
/// - Flutter gesture system (screen coordinates, Offset)
/// - ViewportController (presentation logic)
/// - Domain Viewport model (world coordinates, Point)
///
/// ## Responsibilities
///
/// 1. **Gesture State Management**:
///    - Tracks pan gesture state (start position, accumulated delta)
///    - Manages zoom focal point and inertia
///    - Handles gesture recognition and conflict resolution
///
/// 2. **Coordinate Conversion**:
///    - Converts between Flutter Offset and domain Point
///    - Syncs ViewportController state with domain Viewport
///    - Maintains consistency during gestures
///
/// 3. **Performance Tracking**:
///    - Records FPS metrics during interactions
///    - Tracks pan delta for telemetry
///    - Provides callbacks for performance monitoring
///
/// ## Usage
///
/// ```dart
/// final state = ViewportState(
///   controller: viewportController,
///   onViewportChanged: (viewport) {
///     // Update document with new viewport
///     document = document.copyWith(viewport: viewport);
///   },
/// );
///
/// // In GestureDetector
/// onPanStart: state.onPanStart,
/// onPanUpdate: state.onPanUpdate,
/// onPanEnd: state.onPanEnd,
/// ```
class ViewportState extends ChangeNotifier {

  /// Creates a viewport state manager.
  ///
  /// The [controller] is required and manages the actual transformations.
  /// The [onViewportChanged] callback is optional but recommended to sync
  /// state back to the document model.
  /// The [onTelemetry] callback is optional and used for performance monitoring.
  ViewportState({
    required this.controller,
    this.onViewportChanged,
    this.onTelemetry,
    Size canvasSize = const Size(800, 600),
  }) : _canvasSize = canvasSize {
    // Listen to controller changes to notify our listeners
    controller.addListener(_onControllerChanged);
  }
  /// The viewport controller managing transformations.
  final ViewportController controller;

  /// Callback invoked when viewport state changes.
  ///
  /// This callback receives the new domain Viewport object that should
  /// be persisted to the document model. The callback is responsible for
  /// updating the document via copyWith.
  final ValueChanged<domain.Viewport>? onViewportChanged;

  /// Callback invoked with telemetry data during interactions.
  ///
  /// Provides performance metrics including FPS, pan deltas, and zoom factors.
  /// Only called when debug mode is enabled or telemetry is active.
  final ValueChanged<ViewportTelemetry>? onTelemetry;

  /// Current canvas size in screen pixels.
  ///
  /// This is updated whenever the canvas widget is laid out and is used
  /// to convert between screen and world coordinates when syncing with
  /// the domain model.
  Size _canvasSize;

  /// Whether a pan gesture is currently active.
  bool _isPanning = false;

  /// Start time of the current gesture for FPS calculation.
  DateTime? _gestureStartTime;

  /// Number of gesture updates received for FPS calculation.
  int _gestureUpdateCount = 0;

  /// Last recorded FPS value for telemetry.
  double _lastFps = 0.0;

  /// Accumulated pan delta during the current gesture.
  Offset _accumulatedPanDelta = Offset.zero;

  /// Gets the current canvas size.
  Size get canvasSize => _canvasSize;

  /// Gets whether a pan gesture is active.
  bool get isPanning => _isPanning;

  /// Gets the last recorded FPS value.
  double get lastFps => _lastFps;

  /// Updates the canvas size when the widget is resized.
  ///
  /// This should be called from the canvas widget's layout callback
  /// to keep coordinate transformations accurate.
  void updateCanvasSize(Size size) {
    if (_canvasSize != size) {
      _canvasSize = size;
      _syncWithDomain();
      notifyListeners();
    }
  }

  /// Syncs the controller state with a domain Viewport object.
  ///
  /// This is typically called when loading a document or after undo/redo
  /// operations to ensure the UI controller matches the persisted state.
  ///
  /// Note: The domain Viewport uses centered coordinates (pan is relative
  /// to canvas center), while the controller uses absolute screen coordinates.
  /// This method handles the conversion.
  void syncFromDomain(domain.Viewport viewport) {
    // Update canvas size
    _canvasSize = Size(viewport.canvasSize.width, viewport.canvasSize.height);

    // Convert domain pan (world coordinates centered on canvas) to
    // controller pan (screen offset from origin)
    //
    // Domain: screen = (world - pan) * zoom + canvasSize/2
    // Controller: screen = world * zoom + panOffset
    //
    // Therefore: panOffset = canvasSize/2 - pan * zoom
    final domainPanOffset = Offset(
      _canvasSize.width / 2 - viewport.pan.x * viewport.zoom,
      _canvasSize.height / 2 - viewport.pan.y * viewport.zoom,
    );

    controller.setPan(domainPanOffset);
    controller.setZoom(viewport.zoom);
  }

  /// Converts the current controller state to a domain Viewport object.
  ///
  /// This is used to generate viewport updates for the document model.
  /// The conversion handles the coordinate system difference between
  /// the controller and domain model.
  domain.Viewport toDomainViewport() {
    // Convert controller pan (screen offset) back to domain pan (world coords)
    //
    // Controller: screen = world * zoom + panOffset
    // Domain: screen = (world - pan) * zoom + canvasSize/2
    //
    // Solving for domain pan:
    // panOffset = canvasSize/2 - pan * zoom
    // pan = (canvasSize/2 - panOffset) / zoom
    final domainPan = Point(
      x: (_canvasSize.width / 2 - controller.panOffset.dx) /
          controller.zoomLevel,
      y: (_canvasSize.height / 2 - controller.panOffset.dy) /
          controller.zoomLevel,
    );

    return domain.Viewport(
      pan: domainPan,
      zoom: controller.zoomLevel,
      canvasSize: domain.Size(
        width: _canvasSize.width,
        height: _canvasSize.height,
      ),
    );
  }

  /// Handles the start of a pan gesture.
  ///
  /// This should be connected to GestureDetector.onPanStart.
  void onPanStart(DragStartDetails details) {
    _isPanning = true;
    _gestureStartTime = DateTime.now();
    _gestureUpdateCount = 0;
    _accumulatedPanDelta = Offset.zero;
    notifyListeners();
  }

  /// Handles pan gesture updates.
  ///
  /// This should be connected to GestureDetector.onPanUpdate.
  /// Updates the viewport controller and emits telemetry.
  void onPanUpdate(DragUpdateDetails details) {
    if (!_isPanning) return;

    // Update viewport
    controller.pan(details.delta);
    _accumulatedPanDelta += details.delta;

    // Track gesture updates for FPS calculation
    _gestureUpdateCount++;
    _updateFps();

    // Emit telemetry if callback is registered
    _emitTelemetry(
      eventType: 'pan',
      panDelta: details.delta,
    );

    notifyListeners();
  }

  /// Handles the end of a pan gesture.
  ///
  /// This should be connected to GestureDetector.onPanEnd.
  /// Finalizes the gesture and syncs state with the domain model.
  void onPanEnd(DragEndDetails details) {
    _isPanning = false;

    // Emit final telemetry
    _emitTelemetry(
      eventType: 'pan_end',
      panDelta: _accumulatedPanDelta,
      velocity: details.velocity.pixelsPerSecond,
    );

    // Sync with domain model
    _syncWithDomain();

    // Reset gesture tracking
    _gestureStartTime = null;
    _gestureUpdateCount = 0;
    _accumulatedPanDelta = Offset.zero;

    notifyListeners();
  }

  /// Handles scale gesture start (for pinch zoom).
  ///
  /// This should be connected to GestureDetector.onScaleStart.
  void onScaleStart(ScaleStartDetails details) {
    _gestureStartTime = DateTime.now();
    _gestureUpdateCount = 0;
    notifyListeners();
  }

  /// Handles scale gesture updates (for pinch zoom).
  ///
  /// This should be connected to GestureDetector.onScaleUpdate.
  /// Updates zoom around the focal point and emits telemetry.
  void onScaleUpdate(ScaleUpdateDetails details) {
    // Only process if scale changed (ignore pure pan)
    if (details.scale == 1.0) return;

    // Update zoom around focal point
    controller.zoom(
      details.scale,
      focalPoint: details.focalPoint,
    );

    // Track gesture updates for FPS calculation
    _gestureUpdateCount++;
    _updateFps();

    // Emit telemetry
    _emitTelemetry(
      eventType: 'zoom',
      zoomFactor: details.scale,
      focalPoint: details.focalPoint,
    );

    notifyListeners();
  }

  /// Handles the end of a scale gesture.
  ///
  /// This should be connected to GestureDetector.onScaleEnd.
  void onScaleEnd(ScaleEndDetails details) {
    // Emit final telemetry
    _emitTelemetry(
      eventType: 'zoom_end',
      zoomFactor: controller.zoomLevel,
    );

    // Sync with domain model
    _syncWithDomain();

    // Reset gesture tracking
    _gestureStartTime = null;
    _gestureUpdateCount = 0;

    notifyListeners();
  }

  /// Handles scroll events for zoom.
  ///
  /// This should be connected to a Listener widget's onPointerSignal.
  /// Implements zoom via scroll wheel with the pointer position as focal point.
  void onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      // Calculate zoom factor from scroll delta
      // Negative delta = scroll up = zoom in
      // Positive delta = scroll down = zoom out
      final delta = event.scrollDelta.dy;
      final zoomFactor = delta < 0 ? 1.1 : 0.9;

      // Zoom around pointer position
      controller.zoom(
        zoomFactor,
        focalPoint: event.position,
      );

      // Emit telemetry
      _emitTelemetry(
        eventType: 'scroll_zoom',
        zoomFactor: zoomFactor,
        focalPoint: event.position,
      );

      // Sync with domain immediately for scroll events
      _syncWithDomain();

      notifyListeners();
    }
  }

  /// Resets the viewport to default state.
  ///
  /// Centers the viewport at origin with 100% zoom.
  void reset() {
    controller.reset();
    _syncWithDomain();
    notifyListeners();
  }

  /// Updates FPS calculation based on gesture timing.
  void _updateFps() {
    if (_gestureStartTime == null || _gestureUpdateCount == 0) {
      _lastFps = 0.0;
      return;
    }

    final elapsed = DateTime.now().difference(_gestureStartTime!);
    if (elapsed.inMilliseconds > 0) {
      _lastFps = _gestureUpdateCount * 1000 / elapsed.inMilliseconds;
    }
  }

  /// Emits telemetry data if callback is registered.
  void _emitTelemetry({
    required String eventType,
    Offset? panDelta,
    double? zoomFactor,
    Offset? focalPoint,
    Offset? velocity,
  }) {
    if (onTelemetry == null) return;

    onTelemetry!(ViewportTelemetry(
      timestamp: DateTime.now(),
      eventType: eventType,
      fps: _lastFps,
      panOffset: controller.panOffset,
      panDelta: panDelta,
      zoomLevel: controller.zoomLevel,
      zoomFactor: zoomFactor,
      focalPoint: focalPoint,
      velocity: velocity,
    ),);
  }

  /// Syncs the current controller state back to the domain model.
  void _syncWithDomain() {
    if (onViewportChanged != null) {
      onViewportChanged!(toDomainViewport());
    }
  }

  /// Handles controller changes from external sources.
  void _onControllerChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    controller.removeListener(_onControllerChanged);
    super.dispose();
  }
}

/// Telemetry data captured during viewport interactions.
///
/// Used for performance monitoring and debugging. Contains metrics
/// like FPS, pan deltas, zoom factors, and gesture timing.
///
/// See also:
/// - [TelemetryService] for collecting and analyzing telemetry data
/// - [ViewportState.onTelemetry] for receiving telemetry callbacks
class ViewportTelemetry {

  /// Creates a telemetry data record.
  const ViewportTelemetry({
    required this.timestamp,
    required this.eventType,
    required this.fps,
    required this.panOffset,
    this.panDelta,
    required this.zoomLevel,
    this.zoomFactor,
    this.focalPoint,
    this.velocity,
  });
  /// Timestamp when the telemetry was recorded.
  final DateTime timestamp;

  /// Type of event (pan, zoom, scroll_zoom, pan_end, zoom_end).
  final String eventType;

  /// Current frames per second.
  final double fps;

  /// Current pan offset in screen pixels.
  final Offset panOffset;

  /// Delta for this pan update (null for zoom events).
  final Offset? panDelta;

  /// Current zoom level.
  final double zoomLevel;

  /// Zoom factor for this update (null for pan events).
  final double? zoomFactor;

  /// Focal point for zoom in screen coordinates (null for pan events).
  final Offset? focalPoint;

  /// Gesture velocity in pixels per second (null except for pan_end).
  final Offset? velocity;

  @override
  String toString() {
    final buffer = StringBuffer('ViewportTelemetry(');
    buffer.write('type: $eventType, ');
    buffer.write('fps: ${fps.toStringAsFixed(1)}, ');
    buffer.write('zoom: ${zoomLevel.toStringAsFixed(2)}');

    if (panDelta != null) {
      buffer.write(', panDelta: (${panDelta!.dx.toStringAsFixed(1)}, '
          '${panDelta!.dy.toStringAsFixed(1)})');
    }

    if (zoomFactor != null) {
      buffer.write(', zoomFactor: ${zoomFactor!.toStringAsFixed(2)}');
    }

    if (velocity != null) {
      buffer.write(', velocity: ${velocity!.distance.toStringAsFixed(1)} px/s');
    }

    buffer.write(')');
    return buffer.toString();
  }
}
