import 'dart:math' show cos, max, min, sin, pi, sqrt;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:wiretuner/application/tools/shapes/shape_base.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/events/path_events.dart';
import 'package:wiretuner/domain/events/selection_events.dart';
import 'package:wiretuner/domain/events/group_events.dart';
import 'package:wiretuner/infrastructure/event_sourcing/event_recorder.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';

/// Tool for creating star-shaped paths.
///
/// Creates stars through drag interaction, generating a path with anchor points
/// that is indistinguishable from a star created manually with the pen tool.
///
/// ## Usage
///
/// ```dart
/// final starTool = StarTool(
///   document: document,
///   viewportController: viewportController,
///   eventRecorder: eventRecorder,
/// );
///
/// toolManager.registerTool(starTool);
/// toolManager.activateTool('star');
/// ```
class StarTool extends ShapeToolBase {
  /// Creates a new StarTool instance.
  StarTool({
    required Document document,
    required ViewportController viewportController,
    required EventRecorder eventRecorder,
  }) : _viewportController = viewportController,
       _eventRecorder = eventRecorder,
       super(
         document: document,
         viewportController: viewportController,
         eventRecorder: eventRecorder,
       );

  final ViewportController _viewportController;
  final Logger _logger = Logger();
  final _uuid = const Uuid();
  final EventRecorder _eventRecorder;

  /// Number of points for the star (minimum 3, maximum 20).
  static const int _defaultPointCount = 5;
  int _pointCount = _defaultPointCount;

  /// Inner radius as a ratio of outer radius (0.0 to 1.0).
  static const double _defaultInnerRadiusRatio = 0.38;
  double _innerRadiusRatio = _defaultInnerRadiusRatio;

  @override
  String get toolId => 'star';

  @override
  String get shapeTypeName => 'star';

  @override
  void renderShapePreview(
    ui.Canvas canvas,
    Rect boundingBox,
    bool isShiftPressed,
    bool isAltPressed,
  ) {
    final center = Offset(
      boundingBox.center.dx,
      boundingBox.center.dy,
    );

    // Calculate the actual radii based on bounding box
    final outerRadiusX = boundingBox.width / 2;
    final outerRadiusY = boundingBox.height / 2;
    final innerRadiusX = outerRadiusX * _innerRadiusRatio;
    final innerRadiusY = outerRadiusY * _innerRadiusRatio;

    // Create the star path
    final flutterPath = ui.Path();

    // Generate star points
    final totalPoints = _pointCount * 2; // Alternating outer and inner points
    for (int i = 0; i < totalPoints; i++) {
      final isOuter = i % 2 == 0;
      final radiusX = isOuter ? outerRadiusX : innerRadiusX;
      final radiusY = isOuter ? outerRadiusY : innerRadiusY;

      // Calculate angle (start from top, go clockwise)
      final angle = -pi / 2 + (2 * pi * i / totalPoints);

      // Calculate point position
      final x = center.dx + radiusX * cos(angle);
      final y = center.dy + radiusY * sin(angle);

      if (i == 0) {
        flutterPath.moveTo(x, y);
      } else {
        flutterPath.lineTo(x, y);
      }
    }

    flutterPath.close();

    // Fill preview with semi-transparent blue
    final fillPaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawPath(flutterPath, fillPaint);

    // Stroke preview with solid blue
    final strokePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(flutterPath, strokePaint);
  }

  // Override pointer handling to manage our own state and avoid base class shape creation

  ShapeState _state = ShapeState.idle;
  Point? _dragStartPos;
  Point? _currentDragPos;
  static const double _minDragDistance = 5.0;

  @override
  bool onPointerDown(PointerDownEvent event) {
    final worldPos = _viewportController.screenToWorld(event.localPosition);
    _dragStartPos = worldPos;
    _currentDragPos = worldPos;
    _state = ShapeState.dragging;
    _logger.d('Started star drag at $worldPos');
    return true;
  }

  @override
  bool onPointerMove(PointerMoveEvent event) {
    if (_state != ShapeState.dragging) return false;
    final worldPos = _viewportController.screenToWorld(event.localPosition);
    _currentDragPos = worldPos;
    return true;
  }

  /// Override onPointerUp to create ONLY a path, not a shape.
  /// We completely bypass the base class's shape creation logic.
  @override
  bool onPointerUp(PointerUpEvent event) {
    if (_state != ShapeState.dragging || _dragStartPos == null) {
      return false;
    }

    final worldPos = _viewportController.screenToWorld(event.localPosition);
    _currentDragPos = worldPos;

    // Check minimum drag distance
    final dx = _currentDragPos!.x - _dragStartPos!.x;
    final dy = _currentDragPos!.y - _dragStartPos!.y;
    final dragDistance = sqrt(dx * dx + dy * dy);

    if (dragDistance < _minDragDistance) {
      _logger.d('Drag distance ($dragDistance) below threshold - ignoring');
      _resetState();
      return true;
    }

    // Calculate bounding box with modifier key support
    final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
    final isAltPressed = HardwareKeyboard.instance.isAltPressed;
    final boundingBox = _calculateBoundingBox(
      _dragStartPos!,
      _currentDragPos!,
      isShiftPressed,
      isAltPressed,
    );

    // Create the star as a path (NOT a shape)
    _createStarPath(boundingBox);

    _resetState();
    return true;
  }

  void _resetState() {
    _state = ShapeState.idle;
    _dragStartPos = null;
    _currentDragPos = null;
  }

  Rect _calculateBoundingBox(
    Point start,
    Point end,
    bool constrainAspect,
    bool drawFromCenter,
  ) {
    double left, right, top, bottom;

    if (drawFromCenter) {
      final deltaX = (end.x - start.x).abs();
      final deltaY = (end.y - start.y).abs();

      if (constrainAspect) {
        final radius = max(deltaX, deltaY);
        left = start.x - radius;
        right = start.x + radius;
        top = start.y - radius;
        bottom = start.y + radius;
      } else {
        left = start.x - deltaX;
        right = start.x + deltaX;
        top = start.y - deltaY;
        bottom = start.y + deltaY;
      }
    } else {
      left = min(start.x, end.x);
      right = max(start.x, end.x);
      top = min(start.y, end.y);
      bottom = max(start.y, end.y);

      if (constrainAspect) {
        final size = max((right - left), (bottom - top));

        if (end.x > start.x) {
          right = left + size;
        } else {
          left = right - size;
        }

        if (end.y > start.y) {
          bottom = top + size;
        } else {
          top = bottom - size;
        }
      }
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// Override renderOverlay to use our own state instead of base class state
  @override
  void renderOverlay(ui.Canvas canvas, ui.Size size) {
    if (_state != ShapeState.dragging ||
        _dragStartPos == null ||
        _currentDragPos == null) {
      return;
    }

    final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
    final isAltPressed = HardwareKeyboard.instance.isAltPressed;

    // Calculate bounding box in world coordinates
    final boundingBox = _calculateBoundingBox(
      _dragStartPos!,
      _currentDragPos!,
      isShiftPressed,
      isAltPressed,
    );

    // Convert bounding box corners from world to screen coordinates
    final topLeft = _viewportController.worldToScreen(
      Point(x: boundingBox.left, y: boundingBox.top),
    );
    final bottomRight = _viewportController.worldToScreen(
      Point(x: boundingBox.right, y: boundingBox.bottom),
    );

    // Create screen-space bounding box
    final screenBoundingBox = Rect.fromPoints(topLeft, bottomRight);

    renderShapePreview(canvas, screenBoundingBox, isShiftPressed, isAltPressed);
  }

  /// Override createShapeParameters - not used since we handle everything in onPointerUp
  @override
  Map<String, double> createShapeParameters(Rect boundingBox) {
    // This should never be called since we override onPointerUp
    return {};
  }

  /// Creates a star as a path with individual anchors
  void _createStarPath(Rect boundingBox) {
    final pathId = 'path_${_uuid.v4()}';
    final groupId = 'group_${_uuid.v4()}';
    final now = DateTime.now().millisecondsSinceEpoch;

    // Calculate center and radii in world space
    final centerX = boundingBox.center.dx;
    final centerY = boundingBox.center.dy;
    final outerRadiusX = boundingBox.width / 2;
    final outerRadiusY = boundingBox.height / 2;
    final innerRadiusX = outerRadiusX * _innerRadiusRatio;
    final innerRadiusY = outerRadiusY * _innerRadiusRatio;

    // Generate star points
    final totalPoints = _pointCount * 2;
    final anchors = <Point>[];

    for (int i = 0; i < totalPoints; i++) {
      final isOuter = i % 2 == 0;
      final radiusX = isOuter ? outerRadiusX : innerRadiusX;
      final radiusY = isOuter ? outerRadiusY : innerRadiusY;

      // Calculate angle (start from top, go clockwise)
      final angle = -pi / 2 + (2 * pi * i / totalPoints);

      // Calculate point position in world space
      final x = centerX + radiusX * cos(angle);
      final y = centerY + radiusY * sin(angle);

      anchors.add(Point(x: x, y: y));
    }

    // Start group for the star creation
    _eventRecorder.recordEvent(
      StartGroupEvent(
        eventId: _uuid.v4(),
        timestamp: now,
        groupId: groupId,
        description: 'Create star',
      ),
    );

    // Create the path with the first anchor
    _eventRecorder.recordEvent(
      CreatePathEvent(
        eventId: _uuid.v4(),
        timestamp: now,
        pathId: pathId,
        startAnchor: anchors[0],
        strokeColor: '#000000',
        strokeWidth: 1.0,  // Thinner stroke
      ),
    );
    // Flush immediately to ensure CreatePathEvent is processed
    _eventRecorder.flush();

    // Add remaining anchors
    for (int i = 1; i < anchors.length; i++) {
      _eventRecorder.recordEvent(
        AddAnchorEvent(
          eventId: _uuid.v4(),
          timestamp: now,
          pathId: pathId,
          position: anchors[i],
          anchorType: AnchorType.line, // Star points are straight lines
        ),
      );
      // Flush after each anchor to ensure it's not lost in buffering
      _eventRecorder.flush();
    }

    // Close the path by connecting back to the first point
    _eventRecorder.recordEvent(
      FinishPathEvent(
        eventId: _uuid.v4(),
        timestamp: now,
        pathId: pathId,
        closed: true,
      ),
    );
    _eventRecorder.flush();

    // End the group
    _eventRecorder.recordEvent(
      EndGroupEvent(
        eventId: _uuid.v4(),
        timestamp: now,
        groupId: groupId,
      ),
    );
    _eventRecorder.flush();

    // Auto-select the newly created path
    _eventRecorder.recordEvent(
      SelectObjectsEvent(
        eventId: _uuid.v4(),
        timestamp: now,
        objectIds: [pathId],
        mode: SelectionMode.replace,
      ),
    );
    _eventRecorder.flush();

    _logger.i(
      'Star path created: pathId=$pathId with ${anchors.length} anchors',
    );
  }

  @override
  ShapeType getShapeType() => ShapeType.star;

  /// Sets the number of points for the star.
  void setPointCount(int count) {
    _pointCount = count.clamp(3, 20);
  }

  /// Gets the current number of points.
  int get pointCount => _pointCount;
}