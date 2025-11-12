import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:wiretuner/application/tools/framework/tool_interface.dart';
import 'package:wiretuner/application/tools/direct_selection/snapping_service.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/events/selection_events.dart' as events;
import 'package:wiretuner/domain/events/object_events.dart';
import 'package:wiretuner/domain/events/group_events.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';
import 'marquee_controller.dart';
import 'object_drag_controller.dart';
import 'dart:ui' as ui;

/// Tool for selecting and manipulating vector objects.
///
/// The Selection Tool (T019) provides the following capabilities:
/// - Click to select individual objects
/// - Shift+Click to add/remove from selection
/// - Cmd/Ctrl+Click to toggle selection
/// - Marquee rectangle drag for area selection
/// - Drag selected objects to move them
/// - Respects viewport transformations
///
/// ## Interaction Modes
///
/// ### Click Selection
/// - Click on object: Replace selection with clicked object
/// - Click on empty area: Clear selection
/// - Shift+Click on object: Add to selection
/// - Cmd/Ctrl+Click on object: Toggle selection
///
/// ### Marquee Selection
/// - Click and drag on empty area: Show marquee rectangle
/// - Objects within marquee bounds are selected on mouse up
/// - Shift+Marquee: Add marquee objects to selection
/// - Cmd/Ctrl+Marquee: Toggle marquee objects
///
/// ### Object Movement
/// - Drag selected object: Move all selected objects
/// - Drag delta is accumulated and emitted as MoveObjectEvent
/// - Final delta is flushed on mouse up
///
/// ## Event Emission
///
/// The tool emits the following events:
/// - SelectObjectsEvent: When objects are selected
/// - DeselectObjectsEvent: When objects are deselected
/// - ClearSelectionEvent: When selection is cleared
/// - MoveObjectEvent: When objects are moved
///
/// ## Usage
///
/// ```dart
/// final selectionTool = SelectionTool(
///   document: document,
///   viewportController: viewportController,
///   eventRecorder: eventRecorder,
/// );
///
/// toolManager.registerTool(selectionTool);
/// toolManager.activateTool('selection');
/// ```
class SelectionTool implements ITool {
  /// Creates a new selection tool.
  ///
  /// [document] is the document to operate on.
  /// [viewportController] manages the canvas viewport transformations.
  /// [eventRecorder] records user interactions as events.
  /// [snappingService] provides optional grid snapping functionality.
  SelectionTool({
    required Document document,
    required ViewportController viewportController,
    required dynamic eventRecorder,
    SnappingService? snappingService,
  })  : _document = document,
        _viewportController = viewportController,
        _eventRecorder = eventRecorder,
        _snappingService = snappingService ??
            SnappingService(gridSnapEnabled: false, angleSnapEnabled: false),
        _objectDragController =
            ObjectDragController(snappingService: snappingService) {
    _logger.i('SelectionTool initialized');
  }
  final Document _document;
  final ViewportController _viewportController;
  final dynamic _eventRecorder;
  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();

  /// Gets the active artboard ID. For now, always uses the first artboard.
  /// In future iterations, this will be determined by the focused window.
  String? get _activeArtboardId =>
      _document.artboards.isNotEmpty ? _document.artboards.first.id : null;

  /// Gets the active artboard. Returns null if no artboards exist.
  Artboard? get _activeArtboard =>
      _document.artboards.isNotEmpty ? _document.artboards.first : null;

  /// Snapping service for grid snapping during object drags.
  final SnappingService _snappingService;

  /// Controller for object drag operations.
  final ObjectDragController _objectDragController;

  /// Controller for marquee selection rectangle.
  MarqueeController? _marqueeController;

  /// State tracking for drag operations.
  _DragState? _dragState;

  /// Current cursor based on hover state.
  MouseCursor _currentCursor = SystemMouseCursors.click;

  /// Whether snapping is currently enabled (toggled by Shift key).
  bool _snappingEnabled = false;

  @override
  String get toolId => 'selection';

  @override
  MouseCursor get cursor => _currentCursor;

  @override
  void onActivate() {
    _logger.i('Selection tool activated');
    _currentCursor = SystemMouseCursors.click;
    _dragState = null;
    _marqueeController = null;
  }

  @override
  void onDeactivate() {
    _logger.i('Selection tool deactivated');
    // Flush any pending events
    if (_dragState != null) {
      _flushDragEvent();
    }
    _dragState = null;
    _marqueeController = null;
  }

  @override
  bool onPointerDown(PointerDownEvent event) {
    final worldPos = _viewportController.screenToWorld(event.localPosition);

    // Check for modifier keys
    final isShiftPressed = event.buttons & kPrimaryButton != 0 &&
        HardwareKeyboard.instance.isShiftPressed;
    final isCmdPressed = event.buttons & kPrimaryButton != 0 &&
        (HardwareKeyboard.instance.isMetaPressed ||
            HardwareKeyboard.instance.isControlPressed);

    // Hit test for objects at click point
    final artboardId = _activeArtboardId;
    if (artboardId == null) return false;

    final hitObjects = _document.objectsAtPoint(worldPos, artboardId);
    final artboard = _activeArtboard;

    if (hitObjects.isNotEmpty && artboard != null) {
      // Clicked on an object
      final clickedObjectId = hitObjects.first.id;
      final isAlreadySelected = artboard.selection.contains(clickedObjectId);

      // Track whether we should start a drag
      bool shouldStartDrag = false;

      // Handle selection based on modifiers
      if (isShiftPressed) {
        // Shift: Add to selection
        _recordSelectionEvent([clickedObjectId], events.SelectionMode.add);
        shouldStartDrag = true; // Will be selected after event
      } else if (isCmdPressed) {
        // Cmd/Ctrl: Toggle selection
        _recordSelectionEvent([clickedObjectId], events.SelectionMode.toggle);
        // Don't start drag on toggle - unclear if object will be selected or deselected
        shouldStartDrag = false;
      } else if (!isAlreadySelected) {
        // No modifier and not selected: Replace selection
        _recordSelectionEvent([clickedObjectId], events.SelectionMode.replace);
        shouldStartDrag = true; // Will be selected after event
      } else {
        // Already selected and no modifiers: Start drag
        shouldStartDrag = true;
      }

      // Start drag operation
      if (shouldStartDrag) {
        // Pass the object IDs that will be dragged
        // If the object was already selected, use current selection
        // Otherwise, use just the clicked object
        final dragObjectIds =
            isAlreadySelected && !isShiftPressed && !isCmdPressed
                ? artboard.selection.objectIds.toList()
                : [clickedObjectId];
        _startDrag(event.localPosition, worldPos, dragObjectIds);
      }

      return true;
    } else {
      // Clicked on empty area
      if (!isShiftPressed && !isCmdPressed) {
        // Clear selection if no modifiers
        _recordClearSelectionEvent();
      }

      // Start marquee selection
      _startMarquee(event.localPosition, worldPos);
      return true;
    }
  }

  @override
  bool onPointerMove(PointerMoveEvent event) {
    final worldPos = _viewportController.screenToWorld(event.localPosition);

    if (_dragState != null) {
      // Update drag operation
      _updateDrag(event.localPosition, worldPos);
      return true;
    } else if (_marqueeController != null) {
      // Update marquee rectangle
      _marqueeController!.updateEnd(event.localPosition, worldPos);
      return true;
    }

    // Hover handling (for cursor updates)
    final artboardId = _activeArtboardId;
    if (artboardId != null) {
      final hitObjects = _document.objectsAtPoint(worldPos, artboardId);
      if (hitObjects.isNotEmpty) {
        _currentCursor = SystemMouseCursors.click;
      } else {
        _currentCursor = SystemMouseCursors.basic;
      }
    }

    return false;
  }

  @override
  bool onPointerUp(PointerUpEvent event) {
    if (_dragState != null) {
      // Finish drag operation
      _finishDrag();
      return true;
    } else if (_marqueeController != null) {
      // Finish marquee selection
      _finishMarquee();
      return true;
    }

    return false;
  }

  @override
  bool onKeyPress(KeyEvent event) {
    // Shift key enables snapping
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.shift) {
      _snappingEnabled = true;
      _snappingService.setSnapEnabled(true);
      return false; // Allow other handlers to process
    }

    // Escape key cancels current operation
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      if (_dragState != null) {
        _cancelDrag();
        return true;
      } else if (_marqueeController != null) {
        _cancelMarquee();
        return true;
      }
    }

    return false;
  }

  /// Handles key release events.
  ///
  /// Returns true if the event was handled, false otherwise.
  bool onKeyRelease(KeyEvent event) {
    // Shift key disables snapping
    if (event is KeyUpEvent && event.logicalKey == LogicalKeyboardKey.shift) {
      _snappingEnabled = false;
      _snappingService.setSnapEnabled(false);
      return false; // Allow other handlers to process
    }

    return false;
  }

  @override
  void renderOverlay(ui.Canvas canvas, ui.Size size) {
    // Render marquee rectangle if active
    if (_marqueeController != null) {
      _marqueeController!.render(canvas, _viewportController);
    }
  }

  /// Starts a drag operation for moving selected objects.
  void _startDrag(Offset screenPos, Point worldPos, List<String> objectIds) {
    // Generate group ID for undo grouping
    final groupId = 'drag-${_uuid.v4()}';

    // Emit StartGroupEvent for undo grouping
    final startGroupEvent = StartGroupEvent(
      eventId: _uuid.v4(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
      groupId: groupId,
      description:
          'Move ${objectIds.length} object${objectIds.length > 1 ? 's' : ''}',
    );
    _eventRecorder.recordEvent(startGroupEvent);

    _dragState = _DragState(
      startScreenPos: screenPos,
      startWorldPos: worldPos,
      currentWorldPos: worldPos,
      selectedObjectIds: objectIds,
      groupId: groupId,
    );
    _currentCursor = SystemMouseCursors.move;
    _logger.d(
        'Started drag operation for ${_dragState!.selectedObjectIds.length} objects (groupId: $groupId)');
  }

  /// Updates the drag operation with new position.
  void _updateDrag(Offset screenPos, Point worldPos) {
    if (_dragState == null) return;

    // Update current position
    _dragState = _dragState!.copyWith(
      currentScreenPos: screenPos,
      currentWorldPos: worldPos,
    );

    // Calculate cumulative delta from start position (not previous frame)
    // This ensures deterministic event replay
    final cumulativeDelta = _objectDragController.calculateSnappedDelta(
      startWorldPos: _dragState!.startWorldPos,
      currentWorldPos: worldPos,
      snapEnabled: _snappingEnabled,
    );

    // Only emit event if delta is non-zero
    if (cumulativeDelta.x != 0 || cumulativeDelta.y != 0) {
      _recordMoveEvent(_dragState!.selectedObjectIds, cumulativeDelta);
    }
  }

  /// Finishes the drag operation and flushes events.
  void _finishDrag() {
    if (_dragState == null) return;

    _logger.d('Finished drag operation');
    _flushDragEvent();

    // Emit EndGroupEvent for undo grouping
    final endGroupEvent = EndGroupEvent(
      eventId: _uuid.v4(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
      groupId: _dragState!.groupId,
    );
    _eventRecorder.recordEvent(endGroupEvent);

    _dragState = null;
    _currentCursor = SystemMouseCursors.click;
  }

  /// Cancels the drag operation without flushing events.
  void _cancelDrag() {
    _logger.d('Cancelled drag operation');
    _dragState = null;
    _currentCursor = SystemMouseCursors.click;
  }

  /// Flushes the drag event to ensure final state is persisted.
  void _flushDragEvent() {
    _eventRecorder.flush();
  }

  /// Starts a marquee selection operation.
  void _startMarquee(Offset screenPos, Point worldPos) {
    _marqueeController = MarqueeController(
      startScreenPos: screenPos,
      startWorldPos: worldPos,
    );
    _logger.d('Started marquee selection');
  }

  /// Finishes the marquee selection and selects objects within bounds.
  void _finishMarquee() {
    if (_marqueeController == null) return;

    final marqueeBounds = _marqueeController!.worldBounds;
    final artboardId = _activeArtboardId;
    if (marqueeBounds != null && artboardId != null) {
      // Find objects within marquee bounds
      final selectedObjects = _document.objectsInBounds(marqueeBounds, artboardId);
      final selectedIds = selectedObjects.map((obj) => obj.id).toList();

      if (selectedIds.isNotEmpty) {
        // Determine selection mode based on modifiers
        final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
        final isCmdPressed = HardwareKeyboard.instance.isMetaPressed ||
            HardwareKeyboard.instance.isControlPressed;

        final mode = isCmdPressed
            ? events.SelectionMode.toggle
            : (isShiftPressed
                ? events.SelectionMode.add
                : events.SelectionMode.replace);

        _recordSelectionEvent(selectedIds, mode);
      }
    }

    _logger.d('Finished marquee selection');
    _marqueeController = null;
  }

  /// Cancels the marquee selection.
  void _cancelMarquee() {
    _logger.d('Cancelled marquee selection');
    _marqueeController = null;
  }

  /// Records a selection event.
  void _recordSelectionEvent(
      List<String> objectIds, events.SelectionMode mode) {
    final event = events.SelectObjectsEvent(
      eventId: _uuid.v4(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
      objectIds: objectIds,
      mode: mode,
    );
    _eventRecorder.recordEvent(event);
    _logger.d(
        'Recorded SelectObjectsEvent: mode=$mode, count=${objectIds.length}');
  }

  /// Records a clear selection event.
  void _recordClearSelectionEvent() {
    final event = events.ClearSelectionEvent(
      eventId: _uuid.v4(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    _eventRecorder.recordEvent(event);
    _logger.d('Recorded ClearSelectionEvent');
  }

  /// Records a move object event.
  void _recordMoveEvent(List<String> objectIds, Point delta) {
    final event = MoveObjectEvent(
      eventId: _uuid.v4(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
      objectIds: objectIds,
      delta: delta,
    );
    _eventRecorder.recordEvent(event);
  }
}

/// Internal state for drag operations.
class _DragState {
  _DragState({
    required this.startScreenPos,
    required this.startWorldPos,
    this.currentScreenPos,
    required this.currentWorldPos,
    required this.selectedObjectIds,
    required this.groupId,
  });
  final Offset startScreenPos;
  final Point startWorldPos;
  final Offset? currentScreenPos;
  final Point currentWorldPos;
  final List<String> selectedObjectIds;
  final String groupId;

  _DragState copyWith({
    Offset? currentScreenPos,
    Point? currentWorldPos,
  }) =>
      _DragState(
        startScreenPos: startScreenPos,
        startWorldPos: startWorldPos,
        currentScreenPos: currentScreenPos ?? this.currentScreenPos,
        currentWorldPos: currentWorldPos ?? this.currentWorldPos,
        selectedObjectIds: selectedObjectIds,
        groupId: groupId,
      );
}
