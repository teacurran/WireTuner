import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Abstract interface that all tools must implement.
///
/// Tools are interactive components that handle user input (pointer events and keyboard events)
/// and render tool-specific overlays on the canvas. Each tool represents a distinct editing mode
/// (e.g., pen, selection, rectangle) and follows a well-defined lifecycle.
///
/// ## Lifecycle
///
/// Tools go through the following lifecycle:
/// 1. **Construction**: Tool instance is created (but not active)
/// 2. **Activation**: [onActivate] is called when tool becomes the active tool
/// 3. **Event Handling**: [onPointerDown], [onPointerMove], [onPointerUp], [onKeyPress] handle user input
/// 4. **Rendering**: [renderOverlay] is called during paint to draw tool-specific UI
/// 5. **Deactivation**: [onDeactivate] is called when tool is deactivated
///
/// ## Event Handling
///
/// Event handlers return `true` if they handled the event, `false` otherwise.
/// This allows for event propagation and fallback handling.
///
/// ## Cursor Management
///
/// Each tool defines its own cursor via the [cursor] getter. The [CursorService]
/// automatically updates the mouse cursor when the active tool changes or when
/// the tool programmatically changes its cursor.
///
/// ## Overlay Rendering
///
/// Tools can draw custom UI on top of the canvas (guides, handles, previews) via
/// [renderOverlay]. This method is called during the paint phase and receives
/// the canvas and size for rendering.
///
/// ## Example Implementation
///
/// ```dart
/// class PenTool implements ITool {
///   @override
///   String get toolId => 'pen';
///
///   @override
///   MouseCursor get cursor => SystemMouseCursors.precise;
///
///   PathState _state = PathState.idle;
///
///   @override
///   void onActivate() {
///     _state = PathState.idle;
///   }
///
///   @override
///   void onDeactivate() {
///     _state = PathState.idle;
///   }
///
///   @override
///   bool onPointerDown(PointerDownEvent event) {
///     // Handle click to add anchor point
///     return true;
///   }
///
///   @override
///   bool onPointerMove(PointerMoveEvent event) {
///     // Handle drag to adjust handles
///     return false;
///   }
///
///   @override
///   bool onPointerUp(PointerUpEvent event) {
///     // Finalize anchor placement
///     return true;
///   }
///
///   @override
///   bool onKeyPress(KeyEvent event) {
///     if (event.logicalKey == LogicalKeyboardKey.enter) {
///       // Finish path
///       return true;
///     }
///     return false;
///   }
///
///   @override
///   void renderOverlay(Canvas canvas, Size size) {
///     // Draw anchor previews, guides, etc.
///   }
/// }
/// ```
///
/// Related: T018 (Tool Framework), Flow 1 (Pen Tool workflow)
abstract class ITool {
  /// Unique identifier for this tool (e.g., 'pen', 'selection', 'rectangle').
  ///
  /// This ID is used for tool registration, keyboard shortcuts, and telemetry.
  String get toolId;

  /// The mouse cursor to display when this tool is active.
  ///
  /// The cursor can be changed dynamically during tool operation (e.g., hovering
  /// over a handle might show a different cursor). Tools should notify the
  /// [CursorService] when the cursor changes.
  ///
  /// Common cursors:
  /// - [SystemMouseCursors.precise]: For precise drawing (pen tool)
  /// - [SystemMouseCursors.click]: For selection
  /// - [SystemMouseCursors.move]: For dragging
  /// - [SystemMouseCursors.resizeUp], etc.: For resize handles
  MouseCursor get cursor;

  /// Called when this tool becomes the active tool.
  ///
  /// Use this to:
  /// - Initialize tool state
  /// - Reset state machines
  /// - Subscribe to necessary services
  /// - Set up any tool-specific configuration
  ///
  /// **Important**: This is called AFTER the previous tool's [onDeactivate].
  ///
  /// Example:
  /// ```dart
  /// @override
  /// void onActivate() {
  ///   _state = PathState.idle;
  ///   _currentPath = null;
  ///   _logger.i('Pen tool activated');
  /// }
  /// ```
  void onActivate();

  /// Called when this tool is deactivated (another tool is being activated).
  ///
  /// Use this to:
  /// - Clean up tool state
  /// - Flush buffered events to [EventRecorder]
  /// - Cancel ongoing operations gracefully
  /// - Unsubscribe from services
  ///
  /// **Important**: This is called BEFORE the next tool's [onActivate].
  ///
  /// Example:
  /// ```dart
  /// @override
  /// void onDeactivate() {
  ///   if (_currentPath != null) {
  ///     _eventRecorder.flush(); // Persist pending events
  ///   }
  ///   _state = PathState.idle;
  ///   _logger.i('Pen tool deactivated');
  /// }
  /// ```
  void onDeactivate();

  /// Handles pointer down events (mouse button pressed or touch began).
  ///
  /// This is typically where tools begin interactions like:
  /// - Starting a drag operation
  /// - Adding an anchor point
  /// - Selecting an object
  /// - Beginning a shape creation
  ///
  /// Returns `true` if the event was handled, `false` otherwise.
  ///
  /// **Coordinate Conversion**: The event position is in screen space.
  /// Use [ViewportController.screenToWorld] to convert to world coordinates.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// bool onPointerDown(PointerDownEvent event) {
  ///   final worldPos = _viewportController.screenToWorld(event.localPosition);
  ///   _eventRecorder.recordEvent(CreatePathEvent(
  ///     eventId: _uuid.v4(),
  ///     timestamp: DateTime.now().millisecondsSinceEpoch,
  ///     pathId: _currentPathId,
  ///     startAnchor: worldPos,
  ///   ));
  ///   return true;
  /// }
  /// ```
  bool onPointerDown(PointerDownEvent event);

  /// Handles pointer move events (mouse moved or touch dragged).
  ///
  /// This is typically where tools handle:
  /// - Dragging objects or handles
  /// - Updating previews
  /// - Hover effects
  ///
  /// Returns `true` if the event was handled, `false` otherwise.
  ///
  /// **Performance Note**: This can be called very frequently (60+ times per second).
  /// Ensure this method is efficient and delegates heavy work to the [EventSampler].
  ///
  /// Example:
  /// ```dart
  /// @override
  /// bool onPointerMove(PointerMoveEvent event) {
  ///   if (_draggingHandle) {
  ///     final worldPos = _viewportController.screenToWorld(event.localPosition);
  ///     _eventRecorder.recordEvent(ModifyAnchorEvent(...)); // Will be sampled
  ///     return true;
  ///   }
  ///   return false;
  /// }
  /// ```
  bool onPointerMove(PointerMoveEvent event);

  /// Handles pointer up events (mouse button released or touch ended).
  ///
  /// This is typically where tools:
  /// - Finalize drag operations
  /// - Complete shape creation
  /// - Flush buffered events
  ///
  /// Returns `true` if the event was handled, `false` otherwise.
  ///
  /// **Important**: Call [EventRecorder.flush] to ensure final events are persisted.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// bool onPointerUp(PointerUpEvent event) {
  ///   if (_draggingHandle) {
  ///     _eventRecorder.flush(); // Persist final position
  ///     _draggingHandle = false;
  ///     return true;
  ///   }
  ///   return false;
  /// }
  /// ```
  bool onPointerUp(PointerUpEvent event);

  /// Handles keyboard events.
  ///
  /// This is typically where tools handle:
  /// - Modifier keys (Shift, Ctrl, Alt)
  /// - Tool-specific shortcuts (Enter to finish path, Escape to cancel)
  /// - Numeric input for parametric shapes
  ///
  /// Returns `true` if the event was handled, `false` otherwise.
  ///
  /// **Note**: Global shortcuts (like Ctrl+Z for undo) are handled by the
  /// ToolManager and won't reach individual tools.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// bool onKeyPress(KeyEvent event) {
  ///   if (event.logicalKey == LogicalKeyboardKey.enter) {
  ///     _finishPath();
  ///     return true;
  ///   }
  ///   if (event.logicalKey == LogicalKeyboardKey.escape) {
  ///     _cancelPath();
  ///     return true;
  ///   }
  ///   return false;
  /// }
  /// ```
  bool onKeyPress(KeyEvent event);

  /// Renders tool-specific overlay UI on top of the canvas.
  ///
  /// This method is called during the paint phase and should draw:
  /// - Guides and snap lines
  /// - Control handles
  /// - Preview shapes
  /// - Tool-specific cursors or indicators
  ///
  /// **Performance**: This is called every frame. Keep rendering efficient.
  ///
  /// **Coordinate Systems**:
  /// - Use [ViewportController.worldToScreen] to convert world coordinates to screen
  /// - The canvas is already transformed according to the viewport
  ///
  /// Example:
  /// ```dart
  /// @override
  /// void renderOverlay(Canvas canvas, Size size) {
  ///   if (_currentPath != null) {
  ///     final paint = Paint()
  ///       ..color = Colors.blue
  ///       ..style = PaintingStyle.stroke
  ///       ..strokeWidth = 2.0;
  ///
  ///     // Draw path preview
  ///     canvas.drawPath(_currentPath!, paint);
  ///
  ///     // Draw anchor handles
  ///     for (final anchor in _anchors) {
  ///       final screenPos = _viewportController.worldToScreen(anchor);
  ///       canvas.drawCircle(screenPos, 4.0, paint);
  ///     }
  ///   }
  /// }
  /// ```
  void renderOverlay(Canvas canvas, Size size);
}
