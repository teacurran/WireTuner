# Cursor Manager & Tool Hints

This document describes the cursor management and tool hints system implemented for I3.T5.

## Overview

The cursor management system provides:

1. **Platform-specific cursor mappings** - macOS uses `precise` cursors, Windows uses `basic` cursors
2. **Context-aware cursor selection** - Cursors change based on hover state, modifiers, and tool modes
3. **Frame-budget compliance** - Updates complete within <1 frame (16.67ms at 60fps)
4. **Tool hints overlay** - Displays contextual hints (angle lock, snapping, etc.)

## Architecture

```
Tool → CursorManager → CursorService → MouseRegion
          ↓
    PlatformMapper
    ContextResolver
          ↓
    ToolHintsOverlay
```

## Components

### CursorManager

Platform-aware cursor manager that wraps `CursorService` with additional features:

- **Platform Mapping**: Translates `SystemMouseCursors.precise` to platform-appropriate cursors
- **Context Awareness**: Changes cursor based on hover state, dragging, etc.
- **Tool Tracking**: Tracks active tool ID for hints integration

**Usage:**

```dart
final cursorManager = CursorManager(
  cursorService: cursorService,
  platform: TargetPlatform.macOS, // Optional, defaults to current platform
);

// Set tool cursor
cursorManager.setToolCursor(
  toolId: 'pen',
  baseCursor: SystemMouseCursors.precise,
);

// Update context dynamically
cursorManager.updateContext(
  CursorContext(isHoveringHandle: true),
);
```

### CursorContext

Represents contextual information affecting cursor display:

```dart
const context = CursorContext(
  isHoveringHandle: true,
  isHoveringAnchor: false,
  isDragging: false,
  isAngleLocked: true,
  isSnapping: true,
);
```

### ToolHintsOverlay

Widget that displays contextual hints based on tool state:

```dart
ToolHintsOverlay(
  hints: [
    if (isAngleLocked) ToolHints.angleLock,
    if (isSnapping) ToolHints.snapping,
  ],
  position: ToolHintPosition.bottomRight,
)
```

### ContextualToolHints

Widget that automatically derives hints from `CursorManager`:

```dart
ContextualToolHints(
  cursorManager: cursorManager,
  toolHints: {
    'pen': [ToolHints.penDrawing],
    'selection': [ToolHints.selection],
  },
)
```

## Platform Parity Rules

Per Decision 6 and acceptance criteria:

| Platform | Precise Cursor | Other Cursors |
|----------|---------------|---------------|
| macOS    | `SystemMouseCursors.precise` | Platform-agnostic |
| Windows  | `SystemMouseCursors.basic` | Platform-agnostic |
| Linux    | `SystemMouseCursors.basic` | Platform-agnostic |

All other cursors (`click`, `move`, `grab`, etc.) are identical across platforms.

## Cursor Priority Order

When resolving the final cursor, the manager applies this priority:

1. **Dragging override**: Shows `move` cursor during drag
2. **Handle hover override**: Shows `move` cursor over handles
3. **Anchor hover override**: Shows platform-specific precise cursor
4. **Platform mapping**: Applies platform rules to base cursor
5. **Base cursor**: The tool's default cursor

## Frame Budget Compliance

Per acceptance criteria, cursor updates must complete within 1 frame (<16.67ms at 60fps).

Actual performance (from tests):
- **Single update**: <0.5ms
- **100 updates**: <60ms (avg 0.6ms each)

This is well within the 1-frame budget.

## Internationalization

Tool hints are designed for i18n:

```dart
const HintMessage(
  key: 'hint.snapping.enabled',  // i18n key for future lookup
  text: 'Snapping Enabled',       // Default English text
  icon: Icons.grid_on,
  color: Colors.green,
)
```

Future iterations can add localization by looking up `key` in translation resources.

## Testing

Comprehensive widget tests cover:

- ✅ Platform-specific cursor mapping (macOS, Windows, Linux)
- ✅ Context-aware cursor selection
- ✅ Context updates and notifications
- ✅ Reset behavior
- ✅ Frame budget compliance
- ✅ Integration with CursorService
- ✅ Tool state tracking
- ✅ Platform parity requirements

Run tests:

```bash
flutter test test/widget/cursor_manager_test.dart
```

## Integration Example

```dart
// In app initialization
final cursorService = CursorService();
final cursorManager = CursorManager(cursorService: cursorService);

// In viewport binding
MouseRegion(
  cursor: cursorService.currentCursor,
  child: Stack(
    children: [
      Canvas(...),
      SelectionOverlay(...),
      ContextualToolHints(
        cursorManager: cursorManager,
        toolHints: {
          'pen': [ToolHints.penDrawing],
          'direct_selection': [ToolHints.directSelection],
        },
      ),
    ],
  ),
)

// In tool activation
toolManager.activateTool('pen');
cursorManager.setToolCursor(
  toolId: 'pen',
  baseCursor: SystemMouseCursors.precise,
);

// During pointer move
if (hoveringOverHandle) {
  cursorManager.updateContext(
    CursorContext(isHoveringHandle: true),
  );
}
```

## Related

- **Task**: I3.T5
- **Dependencies**: I3.T3 (tool provider), I3.T4 (direct selection)
- **Files**:
  - `lib/application/tools/framework/cursor_manager.dart`
  - `lib/presentation/canvas/overlays/tool_hints.dart`
  - `test/widget/cursor_manager_test.dart`
