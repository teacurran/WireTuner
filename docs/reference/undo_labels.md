# Undo Label Reference

**Version:** 1.0
**Date:** 2025-11-09
**Status:** Active
**Related Documents:** [Event Schema Reference](./event_schema.md) | [Tool Framework Architecture](../../.codemachine/artifacts/architecture/02_Iteration_I3.md)

---

## Overview

This document provides the authoritative reference for human-readable undo/redo labels in WireTuner. These labels power the user interface for undo/redo menus, history panels, and keyboard shortcut hints.

**Purpose:**
- Define consistent naming conventions for tool operations
- Map tool operations to user-facing labels
- Provide integration guidance for UI surfaces (menus, panels, tooltips)

**Key Design Principles:**
1. **Human-Readable**: Labels use plain English (e.g., "Move Rectangle" not "MoveObjectEvent")
2. **Consistent**: Similar operations across tools use parallel naming (e.g., "Create Path", "Create Rectangle")
3. **Concise**: Labels are 1-3 words maximum
4. **Action-Oriented**: Start with verbs ("Move", "Create", "Delete", "Modify")

---

## Table of Contents

- [Label Format](#label-format)
- [Tool Operation Labels](#tool-operation-labels)
  - [Pen Tool Labels](#pen-tool-labels)
  - [Selection Tool Labels](#selection-tool-labels)
  - [Direct Selection Tool Labels](#direct-selection-tool-labels)
  - [Shape Tool Labels](#shape-tool-labels)
- [UI Integration](#ui-integration)
- [Implementation Guidance](#implementation-guidance)
- [Testing](#testing)

---

## Label Format

### Naming Convention

All undo labels follow this format:

```
<Verb> <Object> [Detail]
```

**Components:**
- **Verb**: Action performed (Create, Move, Delete, Modify, Add, Finish)
- **Object**: Target entity (Path, Rectangle, Anchor, Handle, Selection)
- **Detail** (optional): Additional context (e.g., "Move Rectangle 5px")

### Examples

| Operation | Label | Format |
|-----------|-------|--------|
| Creating a new path | "Create Path" | Verb + Object |
| Moving a rectangle | "Move Rectangle" | Verb + Object |
| Adding an anchor to path | "Add Anchor" | Verb + Object |
| Modifying handle position | "Adjust Handle" | Verb + Object |
| Deleting selected objects | "Delete Selection" | Verb + Object |

---

## Tool Operation Labels

### Pen Tool Labels

The pen tool creates vector paths with anchors and Bezier curves.

| Operation | Label | Description | Group Lifecycle |
|-----------|-------|-------------|-----------------|
| Path creation (complete) | "Create Path" | Entire path creation from first anchor to finish/close | StartGroupEvent → [anchors...] → EndGroupEvent |
| Path cancellation | _(no label)_ | Canceled paths do not emit labels (no FinishPathEvent) | StartGroupEvent → EndGroupEvent (no completion) |

**Implementation Note:**
The pen tool uses a single undo group for the entire path creation workflow. The label "Create Path" is emitted when the path is finished (Enter key, double-click, or click on first anchor). If the path is canceled (Escape key), no label is stored since the operation was incomplete.

**Example:**
```dart
// In pen_tool.dart
final groupId = telemetry.startUndoGroup(
  toolId: 'pen',
  label: 'Create Path',
);

// ... path creation logic ...

telemetry.endUndoGroup(
  toolId: 'pen',
  groupId: groupId,
  label: 'Create Path',
);
```

### Selection Tool Labels

The selection tool selects and moves objects on the canvas.

| Operation | Label | Description | Group Lifecycle |
|-----------|-------|-------------|-----------------|
| Selecting objects | "Select Objects" | Single-click or marquee selection | Single event (no group) |
| Moving selected objects | "Move Objects" | Drag operation moving one or more objects | StartGroupEvent → [samples...] → EndGroupEvent |
| Deselecting all | "Deselect All" | Clear selection | Single event (no group) |

**Implementation Note:**
Movement operations are sampled at 50ms intervals and grouped atomically. The label uses plural "Objects" to cover both single and multi-object moves.

**Example:**
```dart
// In selection_tool.dart (on pointer down)
final groupId = telemetry.startUndoGroup(
  toolId: 'selection',
  label: 'Move Objects',
);

// During drag (sampled)
telemetry.recordSample(
  toolId: 'selection',
  eventType: 'MoveObjectEvent',
);

// On pointer up
telemetry.endUndoGroup(
  toolId: 'selection',
  groupId: groupId,
  label: 'Move Objects',
);
```

### Direct Selection Tool Labels

The direct selection tool manipulates individual anchors and handles within paths.

| Operation | Label | Description | Group Lifecycle |
|-----------|-------|-------------|-----------------|
| Moving anchor position | "Move Anchor" | Drag operation moving a single anchor | StartGroupEvent → [samples...] → EndGroupEvent |
| Adjusting handle position | "Adjust Handle" | Drag operation modifying Bezier control point | StartGroupEvent → [samples...] → EndGroupEvent |
| Converting anchor type | "Convert Anchor" | Alt+click to toggle smooth/corner anchor | Single event (no group) |

**Implementation Note:**
Anchor and handle drags are sampled and grouped. Anchor type conversions are discrete single events.

**Example:**
```dart
// In direct_selection_tool.dart (handle drag)
final groupId = telemetry.startUndoGroup(
  toolId: 'direct_selection',
  label: 'Adjust Handle',
);

// During drag
telemetry.recordSample(
  toolId: 'direct_selection',
  eventType: 'ModifyAnchorEvent',
);

// On pointer up
telemetry.endUndoGroup(
  toolId: 'direct_selection',
  groupId: groupId,
  label: 'Adjust Handle',
);
```

### Shape Tool Labels

Shape tools create parametric shapes (rectangles, ellipses, polygons, stars).

| Tool | Operation | Label | Description | Group Lifecycle |
|------|-----------|-------|-------------|-----------------|
| Rectangle | Shape creation | "Create Rectangle" | Drag operation creating rectangle | StartGroupEvent → [samples...] → EndGroupEvent |
| Ellipse | Shape creation | "Create Ellipse" | Drag operation creating ellipse | StartGroupEvent → [samples...] → EndGroupEvent |
| Polygon | Shape creation | "Create Polygon" | Drag operation creating polygon | StartGroupEvent → [samples...] → EndGroupEvent |
| Star | Shape creation | "Create Star" | Drag operation creating star | StartGroupEvent → [samples...] → EndGroupEvent |

**Implementation Note:**
Shape creation is a single drag operation from pointer down to pointer up. The preview is rendered during the drag, but the shape is only committed on pointer up.

**Example:**
```dart
// In rectangle_tool.dart
final groupId = telemetry.startUndoGroup(
  toolId: 'rectangle',
  label: 'Create Rectangle',
);

// During drag (samples for preview)
telemetry.recordSample(
  toolId: 'rectangle',
  eventType: 'CreateShapeEvent', // or preview events
);

// On pointer up (final shape)
telemetry.endUndoGroup(
  toolId: 'rectangle',
  groupId: groupId,
  label: 'Create Rectangle',
);
```

---

## UI Integration

### Provider Integration (Decision 7)

Undo labels are exposed via Provider for reactive UI binding.

**Setup:**
```dart
// In app shell (main.dart or shell widget)
ChangeNotifierProvider(
  create: (_) => ToolTelemetry(
    logger: logger,
    config: EventCoreDiagnosticsConfig.debug(),
  ),
  child: EditorShell(),
)
```

**Consumption:**
```dart
// In menu or history panel widget
class UndoMenuItem extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final telemetry = context.watch<ToolTelemetry>();
    final activeTool = context.watch<ToolManager>().activeToolId;

    final label = activeTool != null
        ? telemetry.getLastCompletedLabel(activeTool)
        : null;

    return MenuItem(
      label: label != null ? 'Undo $label' : 'Undo',
      shortcut: 'Cmd+Z',
      onPressed: () => undoController.undo(),
      enabled: label != null,
    );
  }
}
```

### Menu Labels

**Edit Menu:**
- **Undo**: "Undo \<label\>" (e.g., "Undo Create Path")
- **Redo**: "Redo \<label\>" (e.g., "Redo Move Objects")
- When no operation available: "Undo" / "Redo" (disabled)

**Keyboard Shortcut Hints:**
- macOS: "Cmd+Z" (undo), "Cmd+Shift+Z" (redo)
- Windows/Linux: "Ctrl+Z" (undo), "Ctrl+Shift+Z" (redo)

### History Panel

The history panel displays a chronological list of operations:

```
┌─────────────────────────────┐
│ History                     │
├─────────────────────────────┤
│ ► Create Rectangle          │ ← Current position
│   Move Objects              │
│   Adjust Handle             │
│   Create Path               │
│   Move Anchor               │
└─────────────────────────────┘
```

**Implementation:**
- Current position marked with "►" indicator
- Clicking an entry triggers undo/redo to that position
- Labels fetched from `ToolTelemetry.allLastCompletedLabels`

---

## Implementation Guidance

### For Tool Developers

When implementing a new tool, follow this pattern:

**1. Identify Undo Boundaries**

Determine which operations should be atomic:
- Discrete actions (select, delete): Single events, no group
- Sampled operations (drag, move): Grouped with StartGroupEvent/EndGroupEvent

**2. Choose Label**

Select a human-readable label following the naming convention:
- Verb: Create, Move, Delete, Modify, Add, Adjust
- Object: Path, Anchor, Handle, Rectangle, etc.

**3. Integrate Telemetry**

```dart
// On operation start
final groupId = telemetry.startUndoGroup(
  toolId: 'your_tool',
  label: 'Your Label',
);

// During sampled events
telemetry.recordSample(
  toolId: 'your_tool',
  eventType: 'YourEventType',
);

// On operation complete
telemetry.endUndoGroup(
  toolId: 'your_tool',
  groupId: groupId,
  label: 'Your Label',
);
```

**4. Test Label Display**

Verify labels appear correctly in:
- Edit → Undo/Redo menu items
- History panel entries
- Keyboard shortcut tooltips

### For UI Developers

**Accessing Labels:**
```dart
// Single label (for menu)
final label = telemetry.getLastCompletedLabel(toolId);

// All labels (for history panel)
final allLabels = telemetry.allLastCompletedLabels;
```

**Reactivity:**
```dart
// Use context.watch for automatic UI updates
final telemetry = context.watch<ToolTelemetry>();
```

**Null Handling:**
- Labels are `null` if no operations completed
- Display fallback text: "Undo" / "Redo" when label is null
- Disable menu items when label is null

---

## Testing

### Unit Tests

**Test Coverage:**
1. **Label Registration**: Verify labels are stored on endUndoGroup
2. **Label Retrieval**: Verify getLastCompletedLabel returns correct value
3. **Label Persistence**: Verify labels survive flush() calls
4. **Multi-Tool Isolation**: Verify labels per tool don't interfere

**Example Test:**
```dart
test('endUndoGroup stores last completed label', () {
  final telemetry = ToolTelemetry(
    logger: Logger(),
    config: EventCoreDiagnosticsConfig.debug(),
  );

  final groupId = telemetry.startUndoGroup(
    toolId: 'pen',
    label: 'Create Path',
  );

  telemetry.endUndoGroup(
    toolId: 'pen',
    groupId: groupId,
    label: 'Create Path',
  );

  expect(telemetry.getLastCompletedLabel('pen'), equals('Create Path'));
});
```

### Integration Tests

**Test Coverage:**
1. **Menu Label Update**: Verify menu items update when operations complete
2. **History Panel Sync**: Verify history panel reflects undo/redo navigation
3. **Provider Reactivity**: Verify UI rebuilds on notifyListeners

**Example Test:**
```dart
testWidgets('undo menu displays last operation label', (tester) async {
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => ToolTelemetry(...),
      child: MaterialApp(home: EditorShell()),
    ),
  );

  // Perform operation
  final telemetry = tester.read<ToolTelemetry>();
  final groupId = telemetry.startUndoGroup(
    toolId: 'pen',
    label: 'Create Path',
  );
  telemetry.endUndoGroup(
    toolId: 'pen',
    groupId: groupId,
    label: 'Create Path',
  );

  await tester.pump(); // Rebuild

  // Verify menu label
  expect(find.text('Undo Create Path'), findsOneWidget);
});
```

---

## Future Enhancements

### Contextual Labels

In future iterations, labels may include contextual details:
- "Move Rectangle 5px" (distance)
- "Create Path (5 anchors)" (count)
- "Delete 3 Objects" (quantity)

This requires event payload analysis and templating support.

### Localization

Labels will be localized in future releases:
```dart
final label = Localization.of(context).undoLabel(
  operation: 'create_path',
);
```

### Batch Operations

Future support for grouping multiple discrete actions:
- "Delete 3 Objects" (batch delete)
- "Align 5 Objects" (batch alignment)

---

**Document Maintainer:** WireTuner Architecture Team
**Last Updated:** 2025-11-09
**Next Review:** After completion of I3.T9 (Tool Telemetry Implementation)
