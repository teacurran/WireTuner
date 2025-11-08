import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:wiretuner/application/tools/framework/tool_interface.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/events/object_events.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';

/// State machine for shape tools.
enum ShapeState {
  /// Idle state - no shape being created.
  idle,

  /// Dragging state - actively dragging to define shape dimensions.
  dragging,
}

/// Abstract base class for shape creation tools (rectangle, ellipse, etc.).
///
/// Provides common drag-based shape creation logic with modifier key support:
/// - Shift: Constrain aspect ratio (square/circle)
/// - Option/Alt: Draw from center instead of corner-to-corner
///
/// ## Interaction Flow
///
/// 1. Pointer down: Record start position, enter dragging state
/// 2. Pointer move: Update current position, render preview
/// 3. Pointer up: Emit CreateShapeEvent if drag exceeds minimum distance
///
/// ## Event Emission
///
/// - Single CreateShapeEvent on pointer up (no intermediate events)
/// - Event includes shape type, parameters map, and optional style
///
/// ## Subclass Responsibilities
///
/// Subclasses must implement:
/// - [shapeTypeName]: Human-readable name ('rectangle', 'ellipse')
/// - [renderShapePreview]: Draw shape preview during drag
/// - [createShapeParameters]: Convert bounding box to parameter map
/// - [getShapeType]: Return appropriate ShapeType enum value
abstract class ShapeToolBase implements ITool {
  final Document _document;
  final ViewportController _viewportController;
  final dynamic _eventRecorder;
  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();

  /// Current state of the tool.
  ShapeState _state = ShapeState.idle;

  /// Position where drag started (world coordinates).
  Point? _dragStartPos;

  /// Current drag position (world coordinates).
  Point? _currentDragPos;

  /// Minimum drag distance to create a shape (in world units).
  /// Prevents accidental tiny shapes from jittery input.
  static const double _minDragDistance = 5.0;

  ShapeToolBase({
    required Document document,
    required ViewportController viewportController,
    required dynamic eventRecorder,
  })  : _document = document,
        _viewportController = viewportController,
        _eventRecorder = eventRecorder;

  // Abstract methods that subclasses must implement

  /// Human-readable name of this shape type (e.g., 'rectangle', 'ellipse').
  String get shapeTypeName;

  /// Renders the shape preview during drag operation.
  ///
  /// Parameters:
  /// - [canvas]: Canvas to draw on
  /// - [boundingBox]: Bounding rectangle defining shape dimensions
  /// - [isShiftPressed]: Whether Shift key is pressed (aspect constraint)
  /// - [isAltPressed]: Whether Alt/Option key is pressed (center draw)
  void renderShapePreview(
    ui.Canvas canvas,
    Rect boundingBox,
    bool isShiftPressed,
    bool isAltPressed,
  );

  /// Creates the parameter map for CreateShapeEvent.
  ///
  /// Converts the bounding box to shape-specific parameters.
  /// For example, rectangle might return:
  /// ```dart
  /// {
  ///   'centerX': boundingBox.center.dx,
  ///   'centerY': boundingBox.center.dy,
  ///   'width': boundingBox.width,
  ///   'height': boundingBox.height,
  ///   'cornerRadius': 0.0,
  /// }
  /// ```
  Map<String, double> createShapeParameters(Rect boundingBox);

  /// Returns the ShapeType enum value for this shape.
  ShapeType getShapeType();

  // ITool implementation

  @override
  MouseCursor get cursor => SystemMouseCursors.precise;

  @override
  void onActivate() {
    _logger.i('$shapeTypeName tool activated');
    _state = ShapeState.idle;
    _dragStartPos = null;
    _currentDragPos = null;
  }

  @override
  void onDeactivate() {
    _logger.i('$shapeTypeName tool deactivated');
    _state = ShapeState.idle;
    _dragStartPos = null;
    _currentDragPos = null;
  }

  @override
  bool onPointerDown(PointerDownEvent event) {
    final worldPos = _viewportController.screenToWorld(event.localPosition);
    _dragStartPos = worldPos;
    _currentDragPos = worldPos;
    _state = ShapeState.dragging;
    _logger.d('Started $shapeTypeName drag at $worldPos');
    return true;
  }

  @override
  bool onPointerMove(PointerMoveEvent event) {
    if (_state != ShapeState.dragging) return false;

    final worldPos = _viewportController.screenToWorld(event.localPosition);
    _currentDragPos = worldPos;
    return true;
  }

  @override
  bool onPointerUp(PointerUpEvent event) {
    if (_state != ShapeState.dragging || _dragStartPos == null) return false;

    final worldPos = _viewportController.screenToWorld(event.localPosition);
    _currentDragPos = worldPos;

    // Check minimum drag distance
    final dragDistance = _calculateDistance(_dragStartPos!, _currentDragPos!);
    if (dragDistance < _minDragDistance) {
      _logger.d(
        'Drag distance ($dragDistance) below threshold - ignoring',
      );
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

    // Emit CreateShapeEvent
    _createShape(boundingBox);

    _resetState();
    return true;
  }

  @override
  bool onKeyPress(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      if (_state == ShapeState.dragging) {
        _logger.d('Escape pressed - canceling $shapeTypeName creation');
        _resetState();
        return true;
      }
    }
    return false;
  }

  @override
  void renderOverlay(ui.Canvas canvas, ui.Size size) {
    if (_state != ShapeState.dragging ||
        _dragStartPos == null ||
        _currentDragPos == null) {
      return;
    }

    final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
    final isAltPressed = HardwareKeyboard.instance.isAltPressed;

    final boundingBox = _calculateBoundingBox(
      _dragStartPos!,
      _currentDragPos!,
      isShiftPressed,
      isAltPressed,
    );

    renderShapePreview(canvas, boundingBox, isShiftPressed, isAltPressed);
  }

  // Private helper methods

  /// Creates and records a CreateShapeEvent.
  void _createShape(Rect boundingBox) {
    final shapeId = 'shape_${_uuid.v4()}';
    final now = DateTime.now().millisecondsSinceEpoch;
    final parameters = createShapeParameters(boundingBox);

    final event = CreateShapeEvent(
      eventId: _uuid.v4(),
      timestamp: now,
      shapeId: shapeId,
      shapeType: getShapeType(),
      parameters: parameters,
      strokeColor: '#000000',
      strokeWidth: 2.0,
    );

    _eventRecorder.recordEvent(event);
    _logger.i(
      '$shapeTypeName created: shapeId=$shapeId, params=$parameters',
    );
  }

  /// Calculates the bounding box for the shape based on drag positions.
  ///
  /// Handles:
  /// - Corner-to-corner (default)
  /// - From center (Alt key)
  /// - Aspect ratio constraint (Shift key)
  /// - Drag direction normalization (user can drag in any direction)
  Rect _calculateBoundingBox(
    Point start,
    Point end,
    bool constrainAspect,
    bool drawFromCenter,
  ) {
    double left, right, top, bottom;

    if (drawFromCenter) {
      // Draw from center (Option/Alt key)
      final deltaX = (end.x - start.x).abs();
      final deltaY = (end.y - start.y).abs();

      double halfWidth = deltaX;
      double halfHeight = deltaY;

      if (constrainAspect) {
        // Square/circle from center
        final maxHalf = max(halfWidth, halfHeight);
        halfWidth = maxHalf;
        halfHeight = maxHalf;
      }

      left = start.x - halfWidth;
      right = start.x + halfWidth;
      top = start.y - halfHeight;
      bottom = start.y + halfHeight;
    } else {
      // Corner-to-corner (default)
      left = min(start.x, end.x);
      right = max(start.x, end.x);
      top = min(start.y, end.y);
      bottom = max(start.y, end.y);

      if (constrainAspect) {
        // Square/circle - expand from drag start corner
        final width = right - left;
        final height = bottom - top;
        final size = max(width, height);

        // Expand in the direction of drag
        if (end.x >= start.x) {
          right = left + size;
        } else {
          left = right - size;
        }

        if (end.y >= start.y) {
          bottom = top + size;
        } else {
          top = bottom - size;
        }
      }
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// Calculates Euclidean distance between two points.
  double _calculateDistance(Point p1, Point p2) {
    final dx = p2.x - p1.x;
    final dy = p2.y - p1.y;
    return sqrt(dx * dx + dy * dy);
  }

  /// Resets tool state to idle.
  void _resetState() {
    _state = ShapeState.idle;
    _dragStartPos = null;
    _currentDragPos = null;
  }
}
