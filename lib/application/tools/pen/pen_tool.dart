import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:wiretuner/application/tools/framework/tool_interface.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/events/path_events.dart';
import 'package:wiretuner/domain/events/group_events.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';
import 'package:wiretuner/presentation/canvas/overlays/pen_preview_overlay.dart';
import 'dart:ui' as ui;

/// State machine for pen tool.
enum PathState {
  /// Idle state - no path being created.
  idle,

  /// Creating path state - actively placing anchors.
  creatingPath,

  /// Adjusting handles state - adjusting Bezier control points of last anchor.
  adjustingHandles,
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
/// ## Rendering Architecture
///
/// The pen tool separates state management from rendering:
/// - State management happens in this class (PenTool)
/// - Visual preview rendering is delegated to [PenPreviewOverlayPainter]
/// - The [previewState] getter exposes preview data to the UI layer
///
/// ### Overlay Integration
///
/// For UI applications, use [PenPreviewOverlayPainter] in a CustomPaint widget:
///
/// ```dart
/// CustomPaint(
///   painter: PenPreviewOverlayPainter(
///     state: penTool.previewState,
///     viewportController: viewportController,
///   ),
/// )
/// ```
///
/// The [renderOverlay] method is kept for backward compatibility and direct
/// canvas access, but delegates to the same painter implementation.
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
  /// Creates a new PenTool instance.
  ///
  /// The tool requires a [document] for path creation, a [viewportController]
  /// for coordinate transformations, and an [eventRecorder] for event emission.
  PenTool({
    required Document document,
    required ViewportController viewportController,
    required dynamic eventRecorder,
  })  : _viewportController = viewportController,
        _eventRecorder = eventRecorder {
    _logger.i('PenTool initialized');
  }
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

  /// Position of the first anchor (start of path, world coordinates).
  /// Used to detect clicks on start anchor for closing paths.
  Point? _firstAnchorPosition;

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

  /// Counter to track the number of anchors added to the current path.
  /// Used for calculating anchor indices in ModifyAnchorEvent.
  /// First anchor (from CreatePathEvent) has index 0, subsequent anchors increment.
  int _anchorCount = 0;

  @override
  String get toolId => 'pen';

  @override
  MouseCursor get cursor => SystemMouseCursors.precise;

  /// Exposes the current preview state for the overlay renderer.
  ///
  /// This getter creates a [PenPreviewState] snapshot that the overlay
  /// painter can use to render visual feedback during path creation.
  PenPreviewState get previewState => PenPreviewState(
        lastAnchorPosition: _lastAnchorPosition,
        hoverPosition: _hoverPosition,
        dragStartPosition: _dragStartPosition,
        currentDragPosition: _currentDragPosition,
        isDragging: _isDragging,
        isAdjustingHandles: _state == PathState.adjustingHandles,
        isAltPressed: HardwareKeyboard.instance.isAltPressed,
      );

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

    // Handle based on current state
    if (_state == PathState.idle) {
      // First click - start new path
      _startPath(worldPos);
      _updateClickTracking(worldPos, now);
      return true;
    } else if (_state == PathState.creatingPath) {
      // Check if click is on first anchor (close path)
      // This must be checked FIRST to enable path closing
      if (_isClickOnFirstAnchor(worldPos)) {
        _logger.d('Click on first anchor - closing path');
        _finishPath(closed: true);
        return true;
      }

      // Check if click is on last anchor (enable handle adjustment)
      // This must be checked BEFORE double-click detection, because clicking
      // on the last anchor would otherwise be detected as a double-click
      if (_isClickOnLastAnchor(worldPos)) {
        _logger.d('Click on last anchor - entering handle adjustment mode');
        _state = PathState.adjustingHandles;
        _dragStartPosition = worldPos;
        _currentDragPosition = worldPos;
        _isDragging = false; // Will become true if pointer moves
        _updateClickTracking(worldPos, now);
        return true;
      }

      // Check for double-click (to finish path)
      if (_isDoubleClick(worldPos, now)) {
        _logger.d('Double-click detected - finishing path');
        _finishPath(closed: false);
        return true;
      }

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

    // Handle adjustment completion (adjusting handles on last anchor)
    if (_state == PathState.adjustingHandles) {
      _commitHandleAdjustment(event);
      _state = PathState.creatingPath; // Return to path creation
      _isDragging = false;
      _dragStartPosition = null;
      _currentDragPosition = null;
      return true;
    }

    // Calculate drag distance to determine if this was a click or drag
    final dragDistance = _calculateDistance(
      _dragStartPosition!,
      _currentDragPosition ?? _dragStartPosition!,
    );

    // If drag distance is below threshold, treat as click (straight line anchor)
    if (dragDistance < _minDragDistance) {
      _logger.d(
          'Short drag ($dragDistance < $_minDragDistance) - treating as click');
      _addStraightLineAnchor(_dragStartPosition!, event);
    } else {
      // Actual drag - create Bezier anchor with handles
      _logger.d(
          'Drag detected (distance: $dragDistance) - creating Bezier anchor');
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
    // Note: The recommended approach is to use PenPreviewOverlayPainter
    // in the UI layer via CustomPaint, consuming the previewState getter.
    // This inline rendering is kept for backward compatibility and
    // for cases where direct canvas access is needed.

    if (_state != PathState.creatingPath &&
        _state != PathState.adjustingHandles) {
      return;
    }

    // Delegate to the overlay painter for consistent rendering
    final painter = PenPreviewOverlayPainter(
      state: previewState,
      viewportController: _viewportController,
    );
    painter.paint(canvas, size);
  }

  // ========== Private Methods ==========

  /// Resets tool state to idle.
  void _resetState() {
    _state = PathState.idle;
    _currentPathId = null;
    _currentGroupId = null;
    _hoverPosition = null;
    _lastAnchorPosition = null;
    _firstAnchorPosition = null;
    _lastClickTime = null;
    _lastClickPosition = null;
    _isDragging = false;
    _dragStartPosition = null;
    _currentDragPosition = null;
    _anchorCount = 0;
  }

  /// Starts a new path with the first anchor.
  void _startPath(Point startAnchor) {
    _logger.d('Starting new path at $startAnchor');

    final pathId = 'path_${_uuid.v4()}';
    final groupId = 'pen-tool-${_uuid.v4()}';
    final now = DateTime.now().millisecondsSinceEpoch;

    // Emit StartGroupEvent
    _eventRecorder.recordEvent(
      StartGroupEvent(
        eventId: _uuid.v4(),
        timestamp: now,
        groupId: groupId,
        description: 'Create path',
      ),
    );

    // Emit CreatePathEvent
    _eventRecorder.recordEvent(
      CreatePathEvent(
        eventId: _uuid.v4(),
        timestamp: now,
        pathId: pathId,
        startAnchor: startAnchor,
        strokeColor: '#000000',
        strokeWidth: 2.0,
      ),
    );

    // Update state
    _state = PathState.creatingPath;
    _currentPathId = pathId;
    _currentGroupId = groupId;
    _lastAnchorPosition = startAnchor;
    _firstAnchorPosition = startAnchor;
    _anchorCount = 1; // First anchor (index 0)

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
    if (HardwareKeyboard.instance.isShiftPressed &&
        _lastAnchorPosition != null) {
      anchorPosition = _constrainToAngle(_lastAnchorPosition!, position);
      _logger.d('Shift pressed - constrained angle: $anchorPosition');
    }

    final now = DateTime.now().millisecondsSinceEpoch;

    // Emit AddAnchorEvent for straight line
    _eventRecorder.recordEvent(
      AddAnchorEvent(
        eventId: _uuid.v4(),
        timestamp: now,
        pathId: _currentPathId!,
        position: anchorPosition,
        anchorType: AnchorType.line,
      ),
    );

    _lastAnchorPosition = anchorPosition;
    _anchorCount++;

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

    // Apply angle constraint if Shift is pressed
    Point constrainedDragEnd = dragEndPosition;
    if (HardwareKeyboard.instance.isShiftPressed) {
      constrainedDragEnd = _constrainToAngle(anchorPosition, dragEndPosition);
      _logger
          .d('Shift pressed - constrained handle angle: $constrainedDragEnd');
    }

    // Calculate handleOut as relative offset from anchor to constrained drag end
    final handleOut = Point(
      x: constrainedDragEnd.x - anchorPosition.x,
      y: constrainedDragEnd.y - anchorPosition.y,
    );

    // Check Alt key to determine anchor type
    final isAltPressed = HardwareKeyboard.instance.isAltPressed;

    // For smooth anchor: handleIn is mirrored (-handleOut)
    // For corner anchor: no handleIn (independent handles)
    final Point? handleIn =
        isAltPressed ? null : Point(x: -handleOut.x, y: -handleOut.y);

    final anchorType = isAltPressed ? AnchorType.bezier : AnchorType.bezier;

    final now = DateTime.now().millisecondsSinceEpoch;

    // Emit AddAnchorEvent with handles
    _eventRecorder.recordEvent(
      AddAnchorEvent(
        eventId: _uuid.v4(),
        timestamp: now,
        pathId: _currentPathId!,
        position: anchorPosition,
        anchorType: anchorType,
        handleIn: handleIn,
        handleOut: handleOut,
      ),
    );

    _lastAnchorPosition = anchorPosition;
    _anchorCount++;

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
    _eventRecorder.recordEvent(
      FinishPathEvent(
        eventId: _uuid.v4(),
        timestamp: now,
        pathId: _currentPathId!,
        closed: closed,
      ),
    );

    // Emit EndGroupEvent
    _eventRecorder.recordEvent(
      EndGroupEvent(
        eventId: _uuid.v4(),
        timestamp: now,
        groupId: _currentGroupId!,
      ),
    );

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
    _eventRecorder.recordEvent(
      EndGroupEvent(
        eventId: _uuid.v4(),
        timestamp: now,
        groupId: _currentGroupId!,
      ),
    );

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
    const increment = math.pi / 4;
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

  /// Checks if the current click is on the first anchor position.
  ///
  /// This is used to close the path when the user clicks on the first anchor.
  ///
  /// Returns true if:
  /// - A first anchor position exists
  /// - Path has at least 3 anchors (need minimum anchors for a closed shape)
  /// - The distance between worldPos and first anchor is within threshold
  ///
  /// Uses the same distance threshold as double-click detection (10.0 world units).
  bool _isClickOnFirstAnchor(Point worldPos) {
    if (_firstAnchorPosition == null || _anchorCount < 3) {
      return false;
    }

    final distance = _calculateDistance(worldPos, _firstAnchorPosition!);
    return distance < _doubleClickDistanceThreshold;
  }

  /// Checks if the current click is on the last anchor position.
  ///
  /// This is used to enter handle adjustment mode when the user clicks
  /// on the last anchor during path creation.
  ///
  /// Returns true if:
  /// - A last anchor position exists
  /// - The distance between worldPos and last anchor is within threshold
  ///
  /// Uses the same distance threshold as double-click detection (10.0 world units).
  bool _isClickOnLastAnchor(Point worldPos) {
    if (_lastAnchorPosition == null) {
      return false;
    }

    final distance = _calculateDistance(worldPos, _lastAnchorPosition!);
    return distance < _doubleClickDistanceThreshold;
  }

  /// Commits handle adjustment for the last anchor.
  ///
  /// This method is called when the user finishes adjusting handles
  /// by releasing the pointer after dragging from the last anchor.
  ///
  /// Behavior:
  /// - Calculates handleOut from drag end position
  /// - If Shift pressed: constrains handle angle to 45° increments
  /// - If Alt pressed: independent handles (handleIn = null)
  /// - If Alt not pressed: symmetric handles (handleIn = -handleOut)
  /// - Emits ModifyAnchorEvent with updated handles
  ///
  /// Note: ModifyAnchorEvent uses AnchorType from event_base.dart (line/bezier),
  /// not the more detailed AnchorType from anchor_point.dart (corner/smooth/symmetric).
  /// The anchorType field is optional and set to null since we're modifying a bezier anchor.
  void _commitHandleAdjustment(PointerEvent event) {
    if (_currentPathId == null || _lastAnchorPosition == null) {
      _logger.e('Cannot commit handle adjustment: no active path or anchor');
      return;
    }

    // Calculate drag end position
    final dragEndPosition = _currentDragPosition ?? _dragStartPosition!;

    // Apply angle constraint if Shift is pressed
    Point constrainedDragEnd = dragEndPosition;
    if (HardwareKeyboard.instance.isShiftPressed) {
      constrainedDragEnd =
          _constrainToAngle(_lastAnchorPosition!, dragEndPosition);
      _logger.d('Shift pressed - constrained handle angle during adjustment');
    }

    // Calculate handleOut from constrained drag end position
    final handleOut = Point(
      x: constrainedDragEnd.x - _lastAnchorPosition!.x,
      y: constrainedDragEnd.y - _lastAnchorPosition!.y,
    );

    // Check Alt key to determine handle behavior
    final isAltPressed = HardwareKeyboard.instance.isAltPressed;

    // For symmetric handles: handleIn is mirrored (-handleOut)
    // For independent handles (Alt pressed): no handleIn
    final Point? handleIn =
        isAltPressed ? null : Point(x: -handleOut.x, y: -handleOut.y);

    final now = DateTime.now().millisecondsSinceEpoch;

    // Emit ModifyAnchorEvent to record handle adjustment
    // anchorType is null since we're only modifying handles, not changing anchor type
    _eventRecorder.recordEvent(
      ModifyAnchorEvent(
        eventId: _uuid.v4(),
        timestamp: now,
        pathId: _currentPathId!,
        anchorIndex: _anchorCount - 1, // Last anchor (0-based index)
        handleOut: handleOut,
        handleIn: handleIn,
      ),
    );

    _logger.d(
      'Handle adjustment committed: anchorIndex=${_anchorCount - 1}, '
      'handleOut=$handleOut, handleIn=$handleIn, '
      'isAlt=$isAltPressed',
    );
  }
}
