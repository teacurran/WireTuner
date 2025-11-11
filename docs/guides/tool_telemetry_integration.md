# Tool Telemetry Integration Guide

**Date:** 2025-11-09
**Task:** I3.T9
**Related Documents:** [Undo Label Reference](../reference/undo_labels.md) | [Event Schema](../reference/event_schema.md)

---

## Overview

This guide explains how to integrate the `ToolTelemetry` system into existing and new tools in WireTuner. The telemetry system provides:

1. **Undo Group Tracking**: Atomic multi-event operations
2. **Human-Readable Labels**: UI-friendly operation names
3. **Usage Metrics**: Tool activation and operation counts
4. **Flush Coordination**: Ensures sampled events are persisted

## Prerequisites

Before integrating telemetry, ensure you have:
- A tool that implements `ITool` interface
- Access to `EventRecorder` for event emission
- Understanding of undo group boundaries (pointer down → move → up)

## Integration Steps

### Step 1: Add Dependency

Add `tool_framework` to your dependencies:

```yaml
# pubspec.yaml
dependencies:
  tool_framework:
    path: packages/tool_framework
```

### Step 2: Inject ToolTelemetry

Modify your tool constructor to accept a `ToolTelemetry` instance:

```dart
class MyTool implements ITool {
  MyTool({
    required Document document,
    required ViewportController viewportController,
    required dynamic eventRecorder,
    required ToolTelemetry telemetry, // Add this
  })  : _viewportController = viewportController,
        _eventRecorder = eventRecorder,
        _telemetry = telemetry; // Add this

  final ToolTelemetry _telemetry;
  String? _activeGroupId; // Track active group ID

  // ... rest of tool implementation
}
```

### Step 3: Start Undo Group on Pointer Down

```dart
@override
bool onPointerDown(PointerDownEvent event) {
  final worldPos = _viewportController.screenToWorld(event.localPosition);

  // Start undo group
  _activeGroupId = _telemetry.startUndoGroup(
    toolId: toolId, // e.g., 'pen', 'selection', 'rectangle'
    label: 'Your Operation Label', // e.g., 'Create Path', 'Move Objects'
  );

  // Emit StartGroupEvent
  _eventRecorder.recordEvent(StartGroupEvent(
    eventId: _uuid.v4(),
    timestamp: DateTime.now().millisecondsSinceEpoch,
    groupId: _activeGroupId!,
    description: 'Your Operation Label',
  ));

  // ... tool-specific pointer down logic ...

  return true;
}
```

### Step 4: Record Samples on Pointer Move

```dart
@override
bool onPointerMove(PointerMoveEvent event) {
  if (_activeGroupId == null) return false;

  final worldPos = _viewportController.screenToWorld(event.localPosition);

  // Record telemetry sample
  _telemetry.recordSample(
    toolId: toolId,
    eventType: 'YourEventType', // e.g., 'AddAnchorEvent', 'MoveObjectEvent'
  );

  // Emit your actual event (sampled)
  _eventRecorder.recordEvent(YourEvent(
    // ... event fields ...
  ));

  return true;
}
```

### Step 5: End Undo Group on Pointer Up

```dart
@override
bool onPointerUp(PointerUpEvent event) {
  if (_activeGroupId == null) return false;

  // Emit EndGroupEvent
  _eventRecorder.recordEvent(EndGroupEvent(
    eventId: _uuid.v4(),
    timestamp: DateTime.now().millisecondsSinceEpoch,
    groupId: _activeGroupId!,
  ));

  // End telemetry group
  _telemetry.endUndoGroup(
    toolId: toolId,
    groupId: _activeGroupId!,
    label: 'Your Operation Label', // Same as startUndoGroup
  );

  // Flush event recorder (ensures events are persisted)
  _eventRecorder.flush();

  // Clear active group
  _activeGroupId = null;

  return true;
}
```

### Step 6: Record Activation in ToolManager

The `ToolManager` should record tool activations:

```dart
// In tool_manager.dart
bool activateTool(String toolId) {
  // ... existing activation logic ...

  _telemetry?.recordActivation(toolId);

  // ... rest of activation ...
}
```

### Step 7: Flush on Deactivation

Ensure telemetry is flushed when tools are deactivated:

```dart
// In tool_manager.dart
void _deactivateCurrentTool() {
  if (_activeTool == null) return;

  // Flush event recorder (already exists)
  _eventRecorder?.flush();

  // Flush telemetry
  _telemetry?.flush();

  // ... rest of deactivation ...
}
```

## Complete Example: Rectangle Tool

Here's a complete example for a shape tool:

```dart
import 'package:tool_framework/tool_framework.dart';
import 'package:uuid/uuid.dart';

class RectangleTool implements ITool {
  RectangleTool({
    required Document document,
    required ViewportController viewportController,
    required dynamic eventRecorder,
    required ToolTelemetry telemetry,
  })  : _viewportController = viewportController,
        _eventRecorder = eventRecorder,
        _telemetry = telemetry;

  final ViewportController _viewportController;
  final dynamic _eventRecorder;
  final ToolTelemetry _telemetry;
  final Uuid _uuid = const Uuid();

  String? _activeGroupId;
  Point? _dragStart;

  @override
  String get toolId => 'rectangle';

  @override
  MouseCursor get cursor => SystemMouseCursors.precise;

  @override
  bool onPointerDown(PointerDownEvent event) {
    final worldPos = _viewportController.screenToWorld(event.localPosition);
    _dragStart = worldPos;

    // Start undo group
    _activeGroupId = _telemetry.startUndoGroup(
      toolId: 'rectangle',
      label: 'Create Rectangle',
    );

    // Emit StartGroupEvent
    _eventRecorder.recordEvent(StartGroupEvent(
      eventId: _uuid.v4(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
      groupId: _activeGroupId!,
      description: 'Create Rectangle',
    ));

    return true;
  }

  @override
  bool onPointerMove(PointerMoveEvent event) {
    if (_activeGroupId == null || _dragStart == null) return false;

    // Record sample (for preview updates)
    _telemetry.recordSample(
      toolId: 'rectangle',
      eventType: 'CreateShapeEvent',
    );

    // Update preview (no event emission during drag)
    // Actual shape creation happens on pointer up

    return true;
  }

  @override
  bool onPointerUp(PointerUpEvent event) {
    if (_activeGroupId == null || _dragStart == null) return false;

    final worldPos = _viewportController.screenToWorld(event.localPosition);

    // Calculate rectangle bounds
    final x = min(_dragStart!.x, worldPos.x);
    final y = min(_dragStart!.y, worldPos.y);
    final width = (worldPos.x - _dragStart!.x).abs();
    final height = (worldPos.y - _dragStart!.y).abs();

    // Emit CreateShapeEvent
    _eventRecorder.recordEvent(CreateShapeEvent(
      eventId: _uuid.v4(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
      shapeId: 'shape_${_uuid.v4()}',
      shapeType: 'rectangle',
      parameters: {
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      },
    ));

    // Emit EndGroupEvent
    _eventRecorder.recordEvent(EndGroupEvent(
      eventId: _uuid.v4(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
      groupId: _activeGroupId!,
    ));

    // End telemetry group
    _telemetry.endUndoGroup(
      toolId: 'rectangle',
      groupId: _activeGroupId!,
      label: 'Create Rectangle',
    );

    // Flush event recorder
    _eventRecorder.flush();

    // Clear state
    _activeGroupId = null;
    _dragStart = null;

    return true;
  }

  @override
  bool onKeyPress(KeyEvent event) => false;

  @override
  void onActivate() {
    // Reset state on activation
    _activeGroupId = null;
    _dragStart = null;
  }

  @override
  void onDeactivate() {
    // Clean up if deactivated mid-drag
    if (_activeGroupId != null) {
      _eventRecorder.recordEvent(EndGroupEvent(
        eventId: _uuid.v4(),
        timestamp: DateTime.now().millisecondsSinceEpoch,
        groupId: _activeGroupId!,
      ));

      _telemetry.endUndoGroup(
        toolId: 'rectangle',
        groupId: _activeGroupId!,
        label: 'Create Rectangle',
      );

      _activeGroupId = null;
    }
    _dragStart = null;
  }

  @override
  void renderOverlay(Canvas canvas, Size size) {
    // Render preview rectangle during drag
    // ... preview rendering logic ...
  }
}
```

## UI Integration: Undo Menu

To display undo labels in the UI:

```dart
// In menu_bar.dart or similar
class EditMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final telemetry = context.watch<ToolTelemetry>();
    final toolManager = context.watch<ToolManager>();

    final activeToolId = toolManager.activeToolId;
    final lastLabel = activeToolId != null
        ? telemetry.getLastCompletedLabel(activeToolId)
        : null;

    return MenuBar(
      children: [
        SubmenuButton(
          menuChildren: [
            MenuItemButton(
              leadingIcon: Icon(Icons.undo),
              child: Text(lastLabel != null ? 'Undo $lastLabel' : 'Undo'),
              shortcut: SingleActivator(LogicalKeyboardKey.keyZ, meta: true),
              onPressed: lastLabel != null ? () => undo() : null,
            ),
            MenuItemButton(
              leadingIcon: Icon(Icons.redo),
              child: Text('Redo'),
              shortcut: SingleActivator(
                LogicalKeyboardKey.keyZ,
                meta: true,
                shift: true,
              ),
              onPressed: () => redo(),
            ),
          ],
          child: Text('Edit'),
        ),
      ],
    );
  }

  void undo() {
    // Trigger undo via EventNavigator
  }

  void redo() {
    // Trigger redo via EventNavigator
  }
}
```

## Label Naming Conventions

Follow these conventions when choosing operation labels:

| Tool | Operation | Label |
|------|-----------|-------|
| Pen | Complete path creation | "Create Path" |
| Selection | Move objects | "Move Objects" |
| Selection | Select objects | "Select Objects" |
| Direct Selection | Move anchor | "Move Anchor" |
| Direct Selection | Adjust handle | "Adjust Handle" |
| Rectangle | Create rectangle | "Create Rectangle" |
| Ellipse | Create ellipse | "Create Ellipse" |
| Polygon | Create polygon | "Create Polygon" |
| Star | Create star | "Create Star" |

See [Undo Label Reference](../reference/undo_labels.md) for complete label specifications.

## Testing

When writing tests for tools with telemetry integration:

```dart
test('tool records telemetry for operation', () {
  final telemetry = ToolTelemetry(
    logger: Logger(),
    config: EventCoreDiagnosticsConfig.debug(),
  );

  final tool = MyTool(
    document: document,
    viewportController: viewportController,
    eventRecorder: eventRecorder,
    telemetry: telemetry,
  );

  // Simulate pointer down
  tool.onPointerDown(PointerDownEvent(/* ... */));

  // Verify group started
  final metrics = telemetry.getMetrics();
  expect(metrics['activeUndoGroups']['my_tool'], isNotEmpty);

  // Simulate pointer up
  tool.onPointerUp(PointerUpEvent(/* ... */));

  // Verify group ended and label stored
  expect(telemetry.getLastCompletedLabel('my_tool'), equals('My Operation'));
});
```

## Troubleshooting

### Common Issues

**1. StateError: "Tool already has active undo group"**

**Cause:** `startUndoGroup` called twice without `endUndoGroup` in between.

**Solution:** Ensure `endUndoGroup` is called on pointer up, escape key, or deactivation.

```dart
@override
void onDeactivate() {
  if (_activeGroupId != null) {
    _telemetry.endUndoGroup(
      toolId: toolId,
      groupId: _activeGroupId!,
      label: 'Your Label',
    );
    _activeGroupId = null;
  }
}
```

**2. Warning: "Sample recorded but no active undo group"**

**Cause:** `recordSample` called outside of an active undo group.

**Solution:** Only call `recordSample` between `startUndoGroup` and `endUndoGroup`:

```dart
@override
bool onPointerMove(PointerMoveEvent event) {
  if (_activeGroupId == null) return false; // Guard clause

  _telemetry.recordSample(
    toolId: toolId,
    eventType: 'YourEvent',
  );

  return true;
}
```

**3. Warning: "Excessive sampled events (> 100)"**

**Cause:** Undo group has more than 100 sampled events.

**Solution:** This usually indicates a very long drag operation. No action needed, but consider if the operation should be split into multiple groups.

**4. Undo label not appearing in UI**

**Cause:** UI not watching `ToolTelemetry` or label not set correctly.

**Solution:** Ensure `context.watch<ToolTelemetry>()` is used and labels match exactly between `startUndoGroup` and `endUndoGroup`.

## Performance Considerations

### Telemetry Overhead

- **startUndoGroup**: ~0.01ms (UUID generation + map insertion)
- **recordSample**: ~0.001ms (counter increment)
- **endUndoGroup**: ~0.01ms (map operations + notifyListeners)

**Total overhead per operation**: < 0.1ms (negligible compared to event recording)

### Flush Frequency

- **Recommendation**: Flush on pointer up and tool deactivation
- **Avoid**: Flushing on every sample (too frequent)
- **Acceptable**: Flushing on timer (e.g., every 5 seconds)

## Migration Checklist

For migrating existing tools to use telemetry:

- [ ] Add `ToolTelemetry` dependency to tool constructor
- [ ] Identify undo group boundaries (pointer down/up or key press)
- [ ] Add `startUndoGroup` call at operation start
- [ ] Add `recordSample` calls during operation
- [ ] Add `endUndoGroup` call at operation end
- [ ] Add `endUndoGroup` call in `onDeactivate` (cleanup)
- [ ] Add `recordActivation` call in `ToolManager.activateTool`
- [ ] Add `flush` call in `ToolManager.deactivateCurrentTool`
- [ ] Update tests to verify telemetry tracking
- [ ] Update UI to display undo labels

---

**Author:** WireTuner Architecture Team
**Last Updated:** 2025-11-09
**Related Tasks:** I3.T9 (Tool Telemetry)
