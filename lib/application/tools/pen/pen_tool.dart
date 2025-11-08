import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:wiretuner/application/tools/framework/tool_interface.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/events/path_events.dart';
import 'package:wiretuner/domain/events/group_events.dart';
import 'package:wiretuner/infrastructure/event_sourcing/event_recorder.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';
import 'dart:ui' as ui;

/// State machine for pen tool.
enum PathState {
  /// Idle state - no path being created.
  idle,

  /// Creating path state - actively placing anchors.
  creatingPath,
}

/// Tool for creating vector paths with anchors and segments.
///
/// The Pen Tool (T021-T024) provides the following capabilities:
/// - Click to place anchor points (straight line segments)
/// - Drag to create Bezier curve segments with handles
/// - Alt/Option key to toggle between smooth and corner anchors
/// - Shift+Click to constrain angles to 45° increments
/// - Enter or double-click to finish path
/// - Escape to cancel path creation
/// - Visual preview of next segment and handles
///
/// ## Interaction Flow
///
/// ### Path Creation
/// 1. First click: Start path, emit StartGroupEvent + CreatePathEvent
/// 2. Subsequent interactions:
///    - Click (pointer down → up quickly): Add straight line anchor (AddAnchorEvent with anchorType: line)
///    - Drag (pointer down → move → up): Add Bezier anchor with handles (AddAnchorEvent with anchorType: bezier, handleIn, handleOut)
/// 3. Enter/double-click: Finish path, emit FinishPathEvent + EndGroupEvent
/// 4. Escape: Cancel path, emit EndGroupEvent
///
/// ### Bezier Curve Creation (I3.T6)
/// - Pointer down: Track drag start position
/// - Pointer move: Update handle preview, set dragging flag
/// - Pointer up:
///   - If drag distance < 5px: Emit straight line anchor
///   - If drag distance >= 5px: Emit Bezier anchor with handles
///   - handleOut = relative offset from anchor to drag end
///   - handleIn = -handleOut (smooth anchor) or null (corner anchor with Alt key)
///
/// ### Undo Grouping
/// - Entire path creation (all clicks/drags) is one undo group
/// - Marked by StartGroupEvent at start, EndGroupEvent at finish
/// - Undo removes entire path atomically
///
/// ## Event Emission
///
/// The tool emits the following events:
/// - StartGroupEvent: Begin path creation group
/// - CreatePathEvent: First anchor placed
/// - AddAnchorEvent: Subsequent anchors added (line or bezier)
/// - FinishPathEvent: Path completed
/// - EndGroupEvent: End path creation group
///
/// ## Important: Pointer Event Flow
///
/// **Breaking Change in I3.T6:** Anchor creation now happens on `onPointerUp`,
/// not `onPointerDown`. This enables drag-to-curve gesture detection.
///
/// In real Flutter applications, pointer events always follow the sequence:
/// onPointerDown → [onPointerMove...] → onPointerUp
///
/// Tests must simulate complete pointer gestures including onPointerUp to
/// properly test anchor creation.
///
/// ## Usage
///
/// ```dart
/// final penTool = PenTool(
///   document: document,
///   viewportController: viewportController,
///   eventRecorder: eventRecorder,
/// );
///
/// toolManager.registerTool(penTool);
/// toolManager.activateTool('pen');
/// ```
class PenTool implements ITool {
  final Document _document;
  final ViewportController _viewportController;
  final dynamic _eventRecorder;
  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();

  /// Current state of the pen tool.
  PathState _state = PathState.idle;

  /// ID of the path currently being created (null when idle).
  String? _currentPathId;

  /// ID of the current undo group (null when idle).
  String? _currentGroupId;

  /// Hover position for preview rendering (world coordinates).
  Point? _hoverPosition;

  /// Position of the last anchor placed (world coordinates).
  Point? _lastAnchorPosition;

  /// Timestamp of last click for double-click detection.
  int? _lastClickTime;

  /// Position of last click for double-click detection (world coordinates).
  Point? _lastClickPosition;

  /// Double-click time threshold in milliseconds.
  static const int _doubleClickTimeThreshold = 500;

  /// Double-click distance threshold in world units.
  static const double _doubleClickDistanceThreshold = 10.0;

  /// Minimum drag distance to trigger Bezier curve creation (in world units).
  /// Drags shorter than this are treated as clicks (straight line anchors).
  static const double _minDragDistance = 5.0;

  /// Tracks whether user is currently dragging (after pointer down).
  bool _isDragging = false;

  /// Position where drag started (world coordinates).
  /// This becomes the anchor position for Bezier curve creation.
  Point? _dragStartPosition;

  /// Current drag position during pointer move (world coordinates).
  /// Used to calculate handle direction and magnitude.
  Point? _currentDragPosition;

  PenTool({
    required Document document,
    required ViewportController viewportController,
    required dynamic eventRecorder,
  })  : _document = document,
        _viewportController = viewportController,
        _eventRecorder = eventRecorder {
    _logger.i('PenTool initialized');
  }

  @override
  String get toolId => 'pen';

  @override
  MouseCursor get cursor => SystemMouseCursors.precise;

  @override
  void onActivate() {
    _logger.i('Pen tool activated');
    _resetState();
  }

  @override
  void onDeactivate() {
    _logger.i('Pen tool deactivated');

    // If we're in the middle of creating a path, finish it gracefully
    if (_state == PathState.creatingPath) {
      _logger.w('Pen tool deactivated mid-path creation - finishing path');
      _finishPath(closed: false);
    }

    // Clear drag state
    _isDragging = false;
    _dragStartPosition = null;
    _currentDragPosition = null;

    _resetState();
  }

  @override
  bool onPointerDown(PointerDownEvent event) {
    final worldPos = _viewportController.screenToWorld(event.localPosition);
    final now = DateTime.now().millisecondsSinceEpoch;

    // Check for double-click
    if (_isDoubleClick(worldPos, now)) {
      _logger.d('Double-click detected - finishing path');
      if (_state == PathState.creatingPath) {
        _finishPath(closed: false);
        return true;
      }
    }

    // Handle based on current state
    if (_state == PathState.idle) {
      // First click - start new path
      _startPath(worldPos);
      _updateClickTracking(worldPos, now);
      return true;
    } else if (_state == PathState.creatingPath) {
      // Track drag start for potential Bezier curve creation
      // But don't emit event yet - wait to see if user drags or just clicks
      _dragStartPosition = worldPos;
      _currentDragPosition = worldPos;
      _isDragging = false; // Will become true if pointer moves
      _updateClickTracking(worldPos, now);
      return true;
    }

    return false;
  }

  @override
  bool onPointerMove(PointerMoveEvent event) {
    final worldPos = _viewportController.screenToWorld(event.localPosition);
    _hoverPosition = worldPos;

    // If drag start is tracked (pointer is down), this is a drag gesture
    if (_dragStartPosition != null) {
      _isDragging = true;
      _currentDragPosition = worldPos;
      // No event emission during drag - just update preview state
    }

    // No active handling, just update preview
    return false;
  }

  @override
  bool onPointerUp(PointerUpEvent event) {
    // If no drag tracking, this pointer up is not related to our tool
    if (_dragStartPosition == null) {
      return false;
    }

    final worldPos = _viewportController.screenToWorld(event.localPosition);

    // Calculate drag distance to determine if this was a click or drag
    final dragDistance = _calculateDistance(
      _dragStartPosition!,
      _currentDragPosition ?? _dragStartPosition!,
    );

    // If drag distance is below threshold, treat as click (straight line anchor)
    if (dragDistance < _minDragDistance) {
      _logger.d('Short drag ($dragDistance < $_minDragDistance) - treating as click');
      _addStraightLineAnchor(_dragStartPosition!, event);
    } else {
      // Actual drag - create Bezier anchor with handles
      _logger.d('Drag detected (distance: $dragDistance) - creating Bezier anchor');
      _addBezierAnchor(
        anchorPosition: _dragStartPosition!,
        dragEndPosition: _currentDragPosition ?? _dragStartPosition!,
        event: event,
      );
    }

    // Clear drag state
    _isDragging = false;
    _dragStartPosition = null;
    _currentDragPosition = null;

    return true;
  }

  @override
  bool onKeyPress(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_state == PathState.creatingPath) {
          _logger.d('Enter pressed - finishing path');
          _finishPath(closed: false);
          return true;
        }
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        if (_state == PathState.creatingPath) {
          _logger.d('Escape pressed - canceling path');
          _cancelPath();
          return true;
        }
      }
    }

    return false;
  }

  @override
  void renderOverlay(Canvas canvas, ui.Size size) {
    if (_state != PathState.creatingPath) {
      return;
    }

    final zoomLevel = _viewportController.zoomLevel;

    // If dragging, render handle preview
    if (_isDragging && _dragStartPosition != null && _currentDragPosition != null) {
      _renderHandlePreview(canvas, zoomLevel);
    }
    // Otherwise, render normal path preview
    else if (_hoverPosition != null && _lastAnchorPosition != null) {
      _renderPathPreview(canvas, zoomLevel);
    }
  }

  /// Renders handle preview during drag gesture.
  void _renderHandlePreview(Canvas canvas, double zoomLevel) {
    final anchorPos = _dragStartPosition!;
    final dragPos = _currentDragPosition!;

    // Paint for handle lines
    final handlePaint = ui.Paint()
      ..color = const ui.Color(0xFF2196F3) // Blue for handles
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.0 / zoomLevel
      ..strokeCap = ui.StrokeCap.round;

    // Paint for handle control points
    final handlePointPaint = ui.Paint()
      ..color = const ui.Color(0xFF2196F3)
      ..style = ui.PaintingStyle.fill;

    // Paint for anchor point
    final anchorPaint = ui.Paint()
      ..color = const ui.Color(0xFFFFFFFF) // White
      ..style = ui.PaintingStyle.fill;

    final anchorStrokePaint = ui.Paint()
      ..color = const ui.Color(0xFF000000) // Black stroke
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.0 / zoomLevel;

    final anchorOffset = ui.Offset(anchorPos.x, anchorPos.y);
    final dragOffset = ui.Offset(dragPos.x, dragPos.y);

    // Draw handleOut line from anchor to drag position
    canvas.drawLine(anchorOffset, dragOffset, handlePaint);

    // Draw handleOut control point
    canvas.drawCircle(dragOffset, 3.0 / zoomLevel, handlePointPaint);

    // If Alt not pressed (smooth anchor mode), draw mirrored handleIn
    if (!HardwareKeyboard.instance.isAltPressed) {
      // Calculate mirrored position: anchor - (drag - anchor) = anchor - handleOut
      final mirrorX = anchorPos.x - (dragPos.x - anchorPos.x);
      final mirrorY = anchorPos.y - (dragPos.y - anchorPos.y);
      final mirrorOffset = ui.Offset(mirrorX, mirrorY);

      // Draw handleIn line
      canvas.drawLine(anchorOffset, mirrorOffset, handlePaint);

      // Draw handleIn control point
      canvas.drawCircle(mirrorOffset, 3.0 / zoomLevel, handlePointPaint);
    }

    // Draw anchor point (on top of handles)
    canvas.drawCircle(anchorOffset, 5.0 / zoomLevel, anchorPaint);
    canvas.drawCircle(anchorOffset, 5.0 / zoomLevel, anchorStrokePaint);
  }

  /// Renders path preview line (when not dragging).
  void _renderPathPreview(Canvas canvas, double zoomLevel) {
    // Draw preview line from last anchor to hover position
    final previewPaint = ui.Paint()
      ..color = const ui.Color(0xFF4CAF50) // Green for path preview
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.0 / zoomLevel
      ..strokeCap = ui.StrokeCap.round;

    final lastOffset = ui.Offset(
      _lastAnchorPosition!.x,
      _lastAnchorPosition!.y,
    );
    final hoverOffset = ui.Offset(
      _hoverPosition!.x,
      _hoverPosition!.y,
    );

    canvas.drawLine(lastOffset, hoverOffset, previewPaint);

    // Draw anchor preview circle at hover position
    final anchorPaint = ui.Paint()
      ..color = const ui.Color(0xFF4CAF50)
      ..style = ui.PaintingStyle.fill;

    canvas.drawCircle(hoverOffset, 4.0 / zoomLevel, anchorPaint);

    // Draw anchor circle at last anchor position
    final lastAnchorPaint = ui.Paint()
      ..color = const ui.Color(0xFF1976D2)
      ..style = ui.PaintingStyle.fill;

    canvas.drawCircle(lastOffset, 4.0 / zoomLevel, lastAnchorPaint);
  }

  // ========== Private Methods ==========

  /// Resets tool state to idle.
  void _resetState() {
    _state = PathState.idle;
    _currentPathId = null;
    _currentGroupId = null;
    _hoverPosition = null;
    _lastAnchorPosition = null;
    _lastClickTime = null;
    _lastClickPosition = null;
    _isDragging = false;
    _dragStartPosition = null;
    _currentDragPosition = null;
  }

  /// Starts a new path with the first anchor.
  void _startPath(Point startAnchor) {
    _logger.d('Starting new path at $startAnchor');

    final pathId = 'path_${_uuid.v4()}';
    final groupId = 'pen-tool-${_uuid.v4()}';
    final now = DateTime.now().millisecondsSinceEpoch;

    // Emit StartGroupEvent
    _eventRecorder.recordEvent(StartGroupEvent(
      eventId: _uuid.v4(),
      timestamp: now,
      groupId: groupId,
      description: 'Create path',
    ));

    // Emit CreatePathEvent
    _eventRecorder.recordEvent(CreatePathEvent(
      eventId: _uuid.v4(),
      timestamp: now,
      pathId: pathId,
      startAnchor: startAnchor,
      strokeColor: '#000000',
      strokeWidth: 2.0,
    ));

    // Update state
    _state = PathState.creatingPath;
    _currentPathId = pathId;
    _currentGroupId = groupId;
    _lastAnchorPosition = startAnchor;

    _logger.i('Path created: pathId=$pathId, groupId=$groupId');
  }

  /// Adds a straight line anchor to the current path.
  void _addStraightLineAnchor(Point position, PointerEvent event) {
    if (_currentPathId == null) {
      _logger.e('Cannot add anchor: no active path');
      return;
    }

    // Apply angle constraint if Shift is pressed
    Point anchorPosition = position;
    if (HardwareKeyboard.instance.isShiftPressed && _lastAnchorPosition != null) {
      anchorPosition = _constrainToAngle(_lastAnchorPosition!, position);
      _logger.d('Shift pressed - constrained angle: $anchorPosition');
    }

    final now = DateTime.now().millisecondsSinceEpoch;

    // Emit AddAnchorEvent for straight line
    _eventRecorder.recordEvent(AddAnchorEvent(
      eventId: _uuid.v4(),
      timestamp: now,
      pathId: _currentPathId!,
      position: anchorPosition,
      anchorType: AnchorType.line,
    ));

    _lastAnchorPosition = anchorPosition;

    _logger.d('Straight line anchor added: position=$anchorPosition');
  }

  /// Adds a Bezier anchor with handles to the current path.
  void _addBezierAnchor({
    required Point anchorPosition,
    required Point dragEndPosition,
    required PointerEvent event,
  }) {
    if (_currentPathId == null) {
      _logger.e('Cannot add Bezier anchor: no active path');
      return;
    }

    // Calculate handleOut as relative offset from anchor to drag end
    final handleOut = Point(
      x: dragEndPosition.x - anchorPosition.x,
      y: dragEndPosition.y - anchorPosition.y,
    );

    // Check Alt key to determine anchor type
    final isAltPressed = HardwareKeyboard.instance.isAltPressed;

    // For smooth anchor: handleIn is mirrored (-handleOut)
    // For corner anchor: no handleIn (independent handles)
    final Point? handleIn = isAltPressed
        ? null
        : Point(x: -handleOut.x, y: -handleOut.y);

    final anchorType = isAltPressed ? AnchorType.bezier : AnchorType.bezier;

    final now = DateTime.now().millisecondsSinceEpoch;

    // Emit AddAnchorEvent with handles
    _eventRecorder.recordEvent(AddAnchorEvent(
      eventId: _uuid.v4(),
      timestamp: now,
      pathId: _currentPathId!,
      position: anchorPosition,
      anchorType: anchorType,
      handleIn: handleIn,
      handleOut: handleOut,
    ));

    _lastAnchorPosition = anchorPosition;

    _logger.d(
      'Bezier anchor added: position=$anchorPosition, '
      'handleOut=$handleOut, handleIn=$handleIn, '
      'isAlt=$isAltPressed',
    );
  }

  /// Finishes the current path.
  void _finishPath({required bool closed}) {
    if (_currentPathId == null || _currentGroupId == null) {
      _logger.e('Cannot finish path: no active path');
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;

    // Emit FinishPathEvent
    _eventRecorder.recordEvent(FinishPathEvent(
      eventId: _uuid.v4(),
      timestamp: now,
      pathId: _currentPathId!,
      closed: closed,
    ));

    // Emit EndGroupEvent
    _eventRecorder.recordEvent(EndGroupEvent(
      eventId: _uuid.v4(),
      timestamp: now,
      groupId: _currentGroupId!,
    ));

    // Flush events to ensure they're persisted
    _eventRecorder.flush();

    _logger.i('Path finished: pathId=$_currentPathId, closed=$closed');

    // Reset state
    _resetState();
  }

  /// Cancels the current path creation.
  void _cancelPath() {
    if (_currentGroupId == null) {
      _logger.e('Cannot cancel path: no active group');
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;

    // Emit EndGroupEvent to close the undo group
    // (No FinishPathEvent = incomplete path, will be ignored by event handlers)
    _eventRecorder.recordEvent(EndGroupEvent(
      eventId: _uuid.v4(),
      timestamp: now,
      groupId: _currentGroupId!,
    ));

    _logger.i('Path canceled: groupId=$_currentGroupId');

    // Reset state
    _resetState();
  }

  /// Constrains a position to the nearest 45° angle from a reference point.
  Point _constrainToAngle(Point from, Point to) {
    final dx = to.x - from.x;
    final dy = to.y - from.y;

    // Calculate angle and distance
    final angle = math.atan2(dy, dx);
    final distance = math.sqrt(dx * dx + dy * dy);

    // Snap to nearest 45° (pi/4 radians)
    final increment = math.pi / 4;
    final snappedAngle = (angle / increment).round() * increment;

    // Calculate constrained position
    final constrainedX = from.x + math.cos(snappedAngle) * distance;
    final constrainedY = from.y + math.sin(snappedAngle) * distance;

    return Point(x: constrainedX, y: constrainedY);
  }

  /// Checks if the current click is a double-click.
  bool _isDoubleClick(Point worldPos, int timestamp) {
    if (_lastClickTime == null || _lastClickPosition == null) {
      return false;
    }

    final timeDelta = timestamp - _lastClickTime!;
    final distance = _calculateDistance(_lastClickPosition!, worldPos);

    return timeDelta <= _doubleClickTimeThreshold &&
        distance <= _doubleClickDistanceThreshold;
  }

  /// Calculates Euclidean distance between two points.
  double _calculateDistance(Point p1, Point p2) {
    final dx = p2.x - p1.x;
    final dy = p2.y - p1.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Updates click tracking for double-click detection.
  void _updateClickTracking(Point worldPos, int timestamp) {
    _lastClickTime = timestamp;
    _lastClickPosition = worldPos;
  }
}
