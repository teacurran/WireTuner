# Tool Framework

The Tool Framework provides the foundation for all interactive tools in WireTuner. It defines a common interface, lifecycle management, cursor handling, and event routing for tools like Pen, Selection, Rectangle, etc.

## Architecture

The framework consists of three main components:

### 1. ITool Interface (`tool_interface.dart`)

The abstract interface that all tools must implement. It defines:

- **Lifecycle methods**: `onActivate()` and `onDeactivate()`
- **Event handlers**: `onPointerDown()`, `onPointerMove()`, `onPointerUp()`, `onKeyPress()`
- **Overlay rendering**: `renderOverlay()` for drawing tool-specific UI
- **Cursor management**: `cursor` getter for defining the tool's mouse cursor

### 2. ToolManager (`tool_manager.dart`)

The central orchestrator for all tools. It handles:

- **Tool registration**: Register/unregister tools dynamically
- **Activation**: Ensure only one tool is active at a time
- **Event routing**: Route input events to the active tool
- **Cursor updates**: Coordinate with CursorService
- **Event recorder integration**: Pause/flush events during tool transitions

### 3. CursorService (`cursor_service.dart`)

A dedicated service for managing mouse cursor state. It:

- Updates the cursor based on the active tool
- Ensures cursor changes propagate within <1 frame
- Notifies listeners when the cursor changes

## Usage

### Implementing a Tool

```dart
class MyTool implements ITool {
  @override
  String get toolId => 'my_tool';

  @override
  MouseCursor get cursor => SystemMouseCursors.precise;

  @override
  void onActivate() {
    // Initialize tool state
  }

  @override
  void onDeactivate() {
    // Clean up state, flush events
  }

  @override
  bool onPointerDown(PointerDownEvent event) {
    // Handle click
    return true; // Event was handled
  }

  @override
  bool onPointerMove(PointerMoveEvent event) {
    // Handle drag
    return false; // Event not handled
  }

  @override
  bool onPointerUp(PointerUpEvent event) {
    // Handle release
    return true;
  }

  @override
  bool onKeyPress(KeyEvent event) {
    // Handle keyboard shortcuts
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      // Finish operation
      return true;
    }
    return false;
  }

  @override
  void renderOverlay(Canvas canvas, Size size) {
    // Draw tool-specific UI (guides, handles, etc.)
  }
}
```

### Setting Up ToolManager

```dart
// Create services
final cursorService = CursorService();
final toolManager = ToolManager(
  cursorService: cursorService,
  eventRecorder: eventRecorder, // Optional
);

// Register tools
toolManager.registerTool(MyTool());
toolManager.registerTool(AnotherTool());

// Activate a tool
toolManager.activateTool('my_tool');

// Expose via Provider
ChangeNotifierProvider(
  create: (_) => toolManager,
  child: EditorShell(),
)
```

### Integrating with Canvas

```dart
class CanvasWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final toolManager = context.watch<ToolManager>();
    final cursorService = context.watch<CursorService>();

    return MouseRegion(
      cursor: cursorService.currentCursor,
      child: Listener(
        onPointerDown: toolManager.handlePointerDown,
        onPointerMove: toolManager.handlePointerMove,
        onPointerUp: toolManager.handlePointerUp,
        child: Focus(
          onKey: (node, event) {
            final handled = toolManager.handleKeyPress(event);
            return handled ? KeyEventResult.handled : KeyEventResult.ignored;
          },
          child: CustomPaint(
            painter: CanvasPainter(),
            foregroundPainter: ToolOverlayPainter(toolManager),
          ),
        ),
      ),
    );
  }
}
```

### Tool Overlay Rendering

```dart
class ToolOverlayPainter extends CustomPainter {
  final ToolManager toolManager;

  ToolOverlayPainter(this.toolManager) : super(repaint: toolManager);

  @override
  void paint(Canvas canvas, Size size) {
    toolManager.renderOverlay(canvas, size);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
```

## Tool Lifecycle

Tools follow this lifecycle:

1. **Construction**: Tool instance is created
2. **Registration**: Tool is registered with ToolManager
3. **Activation**: `onActivate()` is called
   - Previous tool's `onDeactivate()` is called first
   - Cursor is updated
4. **Event Handling**: Events are routed to the tool
5. **Deactivation**: `onDeactivate()` is called
   - EventRecorder is flushed
   - Cursor is reset
6. **Unregistration**: Tool is removed from ToolManager

## Best Practices

### Event Recording

Tools should generate events via EventRecorder:

```dart
@override
bool onPointerDown(PointerDownEvent event) {
  final worldPos = viewportController.screenToWorld(event.localPosition);

  eventRecorder.recordEvent(CreatePathEvent(
    eventId: uuid.v4(),
    timestamp: DateTime.now().millisecondsSinceEpoch,
    pathId: currentPathId,
    startAnchor: worldPos,
  ));

  return true;
}
```

Always flush on `onDeactivate()`:

```dart
@override
void onDeactivate() {
  eventRecorder.flush(); // Persist pending events
  currentPath = null;
}
```

### Coordinate Conversion

Always convert between screen and world coordinates:

```dart
// Screen to world (for event handling)
final worldPos = viewportController.screenToWorld(event.localPosition);

// World to screen (for overlay rendering)
final screenPos = viewportController.worldToScreen(anchorPoint);
```

### Performance

- `onPointerMove` can be called 60+ times per second - keep it efficient
- Use EventSampler to throttle high-frequency events
- Minimize allocations in render methods

### Cursor Management

Update cursor dynamically during tool operation:

```dart
@override
bool onPointerMove(PointerMoveEvent event) {
  if (hoveringOverHandle) {
    toolManager.updateCursor(SystemMouseCursors.move);
  } else {
    toolManager.updateCursor(cursor); // Reset to default
  }
  return false;
}
```

## Testing

Use `FakeTool` for testing ToolManager integration:

```dart
class FakeTool implements ITool {
  List<String> eventLog = [];

  @override
  void onActivate() => eventLog.add('activate');

  @override
  bool onPointerDown(PointerDownEvent event) {
    eventLog.add('pointerDown');
    return true;
  }

  // ... implement other methods
}
```

See `test/unit/tool_manager_test.dart` for comprehensive examples.

## Acceptance Criteria

The Tool Framework meets the following acceptance criteria from Task I3.T1:

- ✅ Tools register/unregister cleanly; only one active tool at a time
- ✅ Cursor updates propagate within <1 frame
- ✅ Test suite covers tool activation, hotkeys, and ensures overlays render via callbacks

## Related Documentation

- **Architecture**: `docs/01_Project_Overview_and_Scope.md`
- **Component Diagram**: `docs/03_System_Structure_and_Data.md` (Tool System)
- **Pen Tool Workflow**: `docs/04_Behavior_and_Communication.md` (Flow 1)
- **Event Model**: `lib/domain/events/path_events.dart`

## Future Enhancements

Planned improvements for future iterations:

- Tool keyboard shortcuts registry (Hotkey system)
- Tool state persistence (remember last active tool)
- Tool-specific settings panels
- Undo/redo integration hooks
- Multi-tool composition (e.g., Pen + Direct Selection)
