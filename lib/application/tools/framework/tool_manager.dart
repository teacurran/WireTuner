import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:wiretuner/infrastructure/event_sourcing/event_recorder.dart';
import 'cursor_service.dart';
import 'tool_interface.dart';
import 'tool_registry.dart';
import 'dart:ui';

/// Manages the lifecycle and state of all tools in the application.
///
/// The [ToolManager] is responsible for:
/// - Registering and unregistering tools
/// - Activating/deactivating tools (ensuring only one is active at a time)
/// - Routing input events (pointer and keyboard) to the active tool
/// - Managing cursor state via [CursorService]
/// - Coordinating with [EventRecorder] for pause/flush operations
///
/// ## Architecture
///
/// The ToolManager acts as a centralized orchestrator in the tool system:
///
/// ```
/// UI Layer (Canvas Widget)
///       ↓ (pointer/keyboard events)
/// ToolManager
///       ↓ (routes to active tool)
/// Active ITool (e.g., PenTool)
///       ↓ (generates events)
/// EventRecorder
/// ```
///
/// ## Lifecycle
///
/// Tools go through the following lifecycle managed by ToolManager:
/// 1. **Registration**: Tool is added to the manager via [registerTool]
/// 2. **Activation**: Tool is made active via [activateTool]
///    - Previous tool's [onDeactivate] is called
///    - New tool's [onActivate] is called
///    - Cursor is updated via [CursorService]
/// 3. **Event Handling**: Events are routed to the active tool
/// 4. **Deactivation**: Tool is deactivated when another tool is activated
/// 5. **Unregistration**: Tool is removed via [unregisterTool]
///
/// ## Event Routing
///
/// The manager routes events using a priority system:
/// 1. Active tool handlers (onPointerDown, onKeyPress, etc.)
/// 2. Global shortcuts (handled by manager if tool returns false)
/// 3. Fallback behavior (e.g., default canvas panning)
///
/// ## Usage
///
/// ```dart
/// final toolManager = ToolManager(
///   cursorService: cursorService,
///   eventRecorder: eventRecorder,
/// );
///
/// // Register tools
/// toolManager.registerTool(penTool);
/// toolManager.registerTool(selectionTool);
///
/// // Activate a tool
/// toolManager.activateTool('pen');
///
/// // Route events from canvas widget
/// Listener(
///   onPointerDown: toolManager.handlePointerDown,
///   onPointerMove: toolManager.handlePointerMove,
///   onPointerUp: toolManager.handlePointerUp,
///   child: Canvas(...),
/// )
/// ```
///
/// ## Provider Integration
///
/// The ToolManager should be exposed via Provider at the app shell level:
///
/// ```dart
/// ChangeNotifierProvider(
///   create: (_) => ToolManager(...),
///   child: EditorShell(),
/// )
/// ```
///
/// Related: T018 (Tool Framework), Component Diagram (Tool System)
class ToolManager extends ChangeNotifier {
  /// Creates a tool manager with required services.
  ///
  /// The [cursorService] is required for cursor management.
  /// The [eventRecorder] is optional but recommended for proper event coordination.
  /// In production, this should be an [EventRecorder] instance. In tests, it can
  /// be a mock object with pause/resume/flush methods.
  ToolManager({
    required CursorService cursorService,
    dynamic eventRecorder,
  })  : _cursorService = cursorService,
        _eventRecorder = eventRecorder {
    _logger.i('ToolManager initialized');
  }

  /// Map of registered tools by toolId.
  final Map<String, ITool> _tools = {};

  /// The currently active tool, or null if no tool is active.
  ITool? _activeTool;

  /// Service for managing cursor state.
  final CursorService _cursorService;

  /// Event recorder for coordinating pause/flush during tool switches.
  /// Can be null if event recording is not needed (e.g., in tests).
  final dynamic _eventRecorder;

  /// Logger for debugging tool lifecycle and events.
  final Logger _logger = Logger();

  /// Returns the currently active tool, or null if no tool is active.
  ITool? get activeTool => _activeTool;

  /// Returns the ID of the currently active tool, or null if no tool is active.
  String? get activeToolId => _activeTool?.toolId;

  /// Returns an unmodifiable view of all registered tools.
  Map<String, ITool> get registeredTools => Map.unmodifiable(_tools);

  /// Registers a tool with the manager.
  ///
  /// The tool is identified by its [ITool.toolId]. If a tool with the same
  /// ID is already registered, it will be replaced.
  ///
  /// **Note**: Registering a tool does not activate it. Call [activateTool]
  /// to make it the active tool.
  ///
  /// Example:
  /// ```dart
  /// final penTool = PenTool();
  /// toolManager.registerTool(penTool);
  /// ```
  void registerTool(ITool tool) {
    final toolId = tool.toolId;

    if (_tools.containsKey(toolId)) {
      _logger.w('Tool "$toolId" is already registered, replacing');
    }

    _tools[toolId] = tool;
    _logger.i('Tool registered: $toolId');
    notifyListeners();
  }

  /// Unregisters a tool from the manager.
  ///
  /// If the tool is currently active, it will be deactivated first.
  ///
  /// Example:
  /// ```dart
  /// toolManager.unregisterTool('pen');
  /// ```
  void unregisterTool(String toolId) {
    if (!_tools.containsKey(toolId)) {
      _logger.w('Cannot unregister tool "$toolId": not registered');
      return;
    }

    // Deactivate if currently active
    if (_activeTool?.toolId == toolId) {
      _deactivateCurrentTool();
    }

    _tools.remove(toolId);
    _logger.i('Tool unregistered: $toolId');
    notifyListeners();
  }

  /// Activates a tool by its ID.
  ///
  /// This method:
  /// 1. Validates the tool exists
  /// 2. Deactivates the currently active tool (if any)
  /// 3. Flushes pending events to EventRecorder
  /// 4. Activates the new tool
  /// 5. Updates the cursor via CursorService
  ///
  /// If the requested tool is already active, this is a no-op.
  ///
  /// Returns `true` if activation succeeded, `false` otherwise.
  ///
  /// Example:
  /// ```dart
  /// // Activate pen tool
  /// final success = toolManager.activateTool('pen');
  /// if (!success) {
  ///   print('Failed to activate pen tool');
  /// }
  /// ```
  bool activateTool(String toolId) {
    // Validate tool exists
    if (!_tools.containsKey(toolId)) {
      _logger.e('Cannot activate tool "$toolId": not registered');
      return false;
    }

    // No-op if already active
    if (_activeTool?.toolId == toolId) {
      _logger.d('Tool "$toolId" is already active');
      return true;
    }

    final newTool = _tools[toolId]!;

    // Deactivate current tool
    if (_activeTool != null) {
      _deactivateCurrentTool();
    }

    // Activate new tool
    _activeTool = newTool;
    _activeTool!.onActivate();
    _cursorService.setCursor(_activeTool!.cursor);

    _logger.i('Tool activated: $toolId');
    notifyListeners();

    return true;
  }

  /// Deactivates the currently active tool.
  ///
  /// This is typically called internally when switching tools, but can be
  /// called explicitly to return to a "no tool active" state.
  void deactivateCurrentTool() {
    if (_activeTool == null) {
      _logger.d('No active tool to deactivate');
      return;
    }

    _deactivateCurrentTool();
    notifyListeners();
  }

  /// Internal helper to deactivate the current tool.
  ///
  /// This method:
  /// 1. Flushes pending events to EventRecorder
  /// 2. Calls the tool's onDeactivate
  /// 3. Resets the cursor to default
  /// 4. Clears the active tool reference
  void _deactivateCurrentTool() {
    if (_activeTool == null) return;

    final toolId = _activeTool!.toolId;

    // Flush any buffered events before deactivation
    _eventRecorder?.flush();

    // Deactivate tool
    _activeTool!.onDeactivate();
    _activeTool = null;

    // Reset cursor to default
    _cursorService.reset();

    _logger.i('Tool deactivated: $toolId');
  }

  /// Routes a pointer down event to the active tool.
  ///
  /// Returns `true` if the event was handled by the tool, `false` otherwise.
  ///
  /// If no tool is active, returns `false` to allow fallback handling.
  ///
  /// Example:
  /// ```dart
  /// Listener(
  ///   onPointerDown: (event) {
  ///     final handled = toolManager.handlePointerDown(event);
  ///     if (!handled) {
  ///       // Fallback: start canvas pan
  ///     }
  ///   },
  /// )
  /// ```
  bool handlePointerDown(PointerDownEvent event) {
    if (_activeTool == null) {
      _logger.d('No active tool, pointer down event ignored');
      return false;
    }

    final handled = _activeTool!.onPointerDown(event);
    _logger.d('Pointer down handled by ${_activeTool!.toolId}: $handled');
    return handled;
  }

  /// Routes a pointer move event to the active tool.
  ///
  /// Returns `true` if the event was handled by the tool, `false` otherwise.
  ///
  /// **Performance Note**: This can be called 60+ times per second.
  /// Tools should ensure their onPointerMove handlers are efficient.
  bool handlePointerMove(PointerMoveEvent event) {
    if (_activeTool == null) {
      return false;
    }

    final handled = _activeTool!.onPointerMove(event);

    // Notify listeners to trigger overlay repaint during drag
    if (handled) {
      notifyListeners();
    }

    return handled;
  }

  /// Routes a pointer up event to the active tool.
  ///
  /// Returns `true` if the event was handled by the tool, `false` otherwise.
  bool handlePointerUp(PointerUpEvent event) {
    if (_activeTool == null) {
      _logger.d('No active tool, pointer up event ignored');
      return false;
    }

    final handled = _activeTool!.onPointerUp(event);
    _logger.d('Pointer up handled by ${_activeTool!.toolId}: $handled');

    // Flush events after pointer up to ensure final state is persisted
    _eventRecorder?.flush();

    return handled;
  }

  /// Routes a keyboard event to the active tool.
  ///
  /// Returns `true` if the event was handled by the tool, `false` otherwise.
  ///
  /// Global shortcuts (e.g., Ctrl+Z for undo) should be handled by the
  /// manager before routing to tools. If a tool returns `false`, the
  /// manager can handle the event as a global shortcut.
  ///
  /// Example:
  /// ```dart
  /// Focus(
  ///   onKey: (node, event) {
  ///     final handled = toolManager.handleKeyPress(event);
  ///     if (!handled) {
  ///       // Handle global shortcuts
  ///       if (event.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyZ) {
  ///         // Undo
  ///         return KeyEventResult.handled;
  ///       }
  ///     }
  ///     return handled ? KeyEventResult.handled : KeyEventResult.ignored;
  ///   },
  /// )
  /// ```
  bool handleKeyPress(KeyEvent event) {
    if (_activeTool == null) {
      _logger.d('No active tool, keyboard event ignored');
      return false;
    }

    final handled = _activeTool!.onKeyPress(event);
    _logger.d('Key press handled by ${_activeTool!.toolId}: $handled');
    return handled;
  }

  /// Handles global hotkey shortcuts for tool activation.
  ///
  /// This method should be called by the application shell to handle
  /// tool-switching shortcuts (e.g., 'P' for pen tool, 'V' for selection).
  ///
  /// Returns `true` if the hotkey was handled, `false` otherwise.
  ///
  /// **Implementation Status**: PLACEHOLDER
  /// This is a placeholder for future hotkey mapping implementation.
  /// The actual mapping will be integrated in a future iteration with
  /// the [ToolRegistry] shortcuts.
  ///
  /// **Planned Implementation**:
  /// 1. Query [ToolRegistry] for tool definitions with shortcuts
  /// 2. Match the key event against registered shortcuts
  /// 3. Activate the matching tool via [activateTool]
  /// 4. Handle modifier keys (Shift for temporary tool switch)
  ///
  /// Example (future):
  /// ```dart
  /// Focus(
  ///   onKey: (node, event) {
  ///     // Try global tool hotkeys first
  ///     if (toolManager.handleToolHotkey(event)) {
  ///       return KeyEventResult.handled;
  ///     }
  ///
  ///     // Then try active tool's key handler
  ///     if (toolManager.handleKeyPress(event)) {
  ///       return KeyEventResult.handled;
  ///     }
  ///
  ///     return KeyEventResult.ignored;
  ///   },
  /// )
  /// ```
  ///
  /// Related: [ToolRegistry.getDefinitionByShortcut], Section 2 (Tool System)
  bool handleToolHotkey(KeyEvent event) {
    // Only handle key down events for tool switching
    if (event is! KeyDownEvent) {
      return false;
    }

    // Skip if modifier keys are pressed (Ctrl, Alt, Meta)
    // Tool shortcuts are single-key only (e.g., 'P', 'V', 'A')
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isAltPressed ||
        HardwareKeyboard.instance.isMetaPressed) {
      return false;
    }

    // Extract character from logical key
    // LogicalKeyboardKey provides keyLabel for printable characters
    final keyLabel = event.logicalKey.keyLabel;
    if (keyLabel.isEmpty || keyLabel.length > 1) {
      // Not a single character key
      return false;
    }

    // Try to find tool definition by shortcut
    try {
      final registry = ToolRegistry.instance;
      final definition = registry.getDefinitionByShortcut(keyLabel)!;

      // Activate the tool
      final success = activateTool(definition.toolId);
      if (success) {
        _logger.i(
            'Tool hotkey activated: ${definition.toolId} (shortcut: $keyLabel)');
        return true;
      } else {
        _logger.w(
            'Failed to activate tool via hotkey: ${definition.toolId} (shortcut: $keyLabel)');
        return false;
      }
    } on StateError {
      // No tool found for this shortcut
      _logger.d('No tool registered for shortcut: $keyLabel');
      return false;
    }
  }

  /// Renders the active tool's overlay.
  ///
  /// This method should be called from a CustomPainter during the paint phase.
  ///
  /// Example:
  /// ```dart
  /// class CanvasOverlayPainter extends CustomPainter {
  ///   final ToolManager toolManager;
  ///
  ///   CanvasOverlayPainter(this.toolManager);
  ///
  ///   @override
  ///   void paint(Canvas canvas, Size size) {
  ///     toolManager.renderOverlay(canvas, size);
  ///   }
  ///
  ///   @override
  ///   bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
  /// }
  /// ```
  void renderOverlay(Canvas canvas, Size size) {
    if (_activeTool == null) {
      return;
    }

    _activeTool!.renderOverlay(canvas, size);
  }

  /// Pauses event recording.
  ///
  /// This is typically called during event replay or undo operations to
  /// prevent circular event creation. The manager delegates this to the
  /// EventRecorder.
  ///
  /// **Important**: Always pair with [resumeRecording] to avoid losing events.
  ///
  /// Example:
  /// ```dart
  /// toolManager.pauseRecording();
  /// try {
  ///   await eventReplayer.replay(events);
  /// } finally {
  ///   toolManager.resumeRecording();
  /// }
  /// ```
  void pauseRecording() {
    _eventRecorder?.pause();
    _logger.i('Event recording paused via ToolManager');
  }

  /// Resumes event recording after a [pauseRecording] call.
  void resumeRecording() {
    _eventRecorder?.resume();
    _logger.i('Event recording resumed via ToolManager');
  }

  /// Updates the cursor for the active tool.
  ///
  /// This allows tools to dynamically change their cursor during operation
  /// (e.g., hovering over a handle shows a move cursor).
  ///
  /// If no tool is active, this has no effect.
  ///
  /// Example:
  /// ```dart
  /// // Inside a tool's onPointerMove handler
  /// if (hoveringOverHandle) {
  ///   toolManager.updateCursor(SystemMouseCursors.move);
  /// }
  /// ```
  void updateCursor(MouseCursor cursor) {
    _cursorService.setCursor(cursor);
  }

  @override
  void dispose() {
    // Deactivate current tool on disposal
    if (_activeTool != null) {
      _deactivateCurrentTool();
    }

    _logger.i('ToolManager disposed');
    super.dispose();
  }

  @override
  String toString() =>
      'ToolManager(activeTool: ${_activeTool?.toolId ?? "none"}, registeredTools: ${_tools.length})';
}
