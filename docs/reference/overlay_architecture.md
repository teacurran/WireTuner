# Overlay Architecture

## Overview

The overlay system provides deterministic z-index management for coordinating selection boxes, pen previews, snapping guides, and future shape guides in the WireTuner canvas.

## Architecture

The overlay system is built on three core components:

### 1. OverlayRegistry

A `ChangeNotifier` that manages overlay registration and ordering:

```dart
final registry = OverlayRegistry();

// Register selection overlay (document-derived)
registry.register(CanvasOverlayEntry.painter(
  id: 'selection',
  zIndex: OverlayZIndex.selection,
  painter: SelectionOverlayPainter(...),
));

// Register pen preview (tool-state)
registry.register(CanvasOverlayEntry.painter(
  id: 'pen-preview',
  zIndex: OverlayZIndex.penPreview,
  painter: PenPreviewOverlayPainter(...),
));

// Register tool hints (widget overlay)
registry.register(CanvasOverlayEntry.widget(
  id: 'tool-hints',
  zIndex: OverlayZIndex.toolHints,
  widget: ToolHintsOverlay(...),
));
```

**Key Features:**
- Deterministic z-index based ordering
- Support for CustomPainter and Widget overlays
- Automatic listener notifications on changes
- Overlay replacement by ID

### 2. OverlayLayer Widget

Renders all registered overlays in sorted z-index order:

```dart
Stack(
  children: [
    CustomPaint(painter: DocumentPainter(...)),
    OverlayLayer(registry: registry), // All overlays in order
  ],
)
```

**Key Features:**
- Automatic rebuilding when registry changes
- Separate rendering of painters and widgets
- Hit-test management (IgnorePointer for translucent overlays)
- Viewport-independent positioning

### 3. Z-Index Tiers

The system uses three deterministic tiers (100-399):

#### Tier 1: Document-Derived (100-199)

Visual feedback tied to document state:
- `OverlayZIndex.selection` (110): Selection boxes and handles
- `OverlayZIndex.bounds` (120): Object bounds and alignment guides

#### Tier 2: Tool-State Painters (200-299)

Dynamic previews from active tools:
- `OverlayZIndex.penPreview` (210): Pen tool rubber-band and handles
- `OverlayZIndex.shapePreview` (220): Shape creation guides
- `OverlayZIndex.snapping` (230): Snapping indicators
- `OverlayZIndex.activeTool` (240): Tool-specific overlays from `ToolManager.renderOverlay`

#### Tier 3: Widget Overlays (300-399)

Positioned widgets for UI elements:
- `OverlayZIndex.toolHints` (310): Tool hints and modifier key feedback
- `OverlayZIndex.performance` (320): Performance HUD

## Usage Patterns

### Painter-Based Overlays

Use for high-performance canvas drawing:

```dart
registry.register(CanvasOverlayEntry.painter(
  id: 'selection',
  zIndex: OverlayZIndex.selection,
  painter: SelectionOverlayPainter(
    selection: selection,
    paths: paths,
    viewportController: viewportController,
    pathRenderer: pathRenderer,
  ),
  hitTestBehavior: HitTestBehavior.translucent, // Pass events through
));
```

**When to use:**
- Selection boxes and handles
- Path previews and guides
- Snapping indicators
- Any frequently-repainting graphics

### Widget-Based Overlays

Use for positioned UI elements:

```dart
registry.register(CanvasOverlayEntry.widget(
  id: 'tool-hints',
  zIndex: OverlayZIndex.toolHints,
  widget: ToolHintsOverlay(hints: currentHints),
));
```

**When to use:**
- Text-heavy overlays (hints, labels)
- Interactive UI elements
- HUD components
- Elements that need Flutter layout

### Dynamic Painter Overlays

Use for tool-provided painters that change frequently:

```dart
registry.register(CanvasOverlayEntry.painterBuilder(
  id: 'active-tool',
  zIndex: OverlayZIndex.activeTool,
  builder: () => toolManager.getActiveToolPainter(),
));
```

## Hit-Test Management

The system supports three hit-test behaviors:

### Translucent (Default)

Overlays wrapped in `IgnorePointer` - events pass through to underlying canvas:

```dart
CanvasOverlayEntry.painter(
  id: 'selection',
  zIndex: OverlayZIndex.selection,
  painter: selectionPainter,
  hitTestBehavior: HitTestBehavior.translucent, // Default
)
```

Use for: Selection boxes, guides, previews

### Opaque

Overlays block events from layers below:

```dart
CanvasOverlayEntry.widget(
  id: 'modal-dialog',
  zIndex: 350,
  widget: ModalDialog(...),
  hitTestBehavior: HitTestBehavior.opaque,
)
```

Use for: Modal dialogs, interactive widgets

### DeferToChild

Only overlay's child widgets receive events:

```dart
CanvasOverlayEntry.widget(
  id: 'toolbar',
  zIndex: 340,
  widget: FloatingToolbar(...),
  hitTestBehavior: HitTestBehavior.deferToChild,
)
```

Use for: Toolbars with buttons, complex interactive widgets

## Integration with Canvas

The overlay system is integrated into `WireTunerCanvas`:

```dart
class _WireTunerCanvasState extends State<WireTunerCanvas> {
  late final OverlayRegistry _overlayRegistry;

  @override
  void build(BuildContext context) {
    _registerOverlays(); // Register overlays based on current state

    return Stack(
      children: [
        CustomPaint(painter: DocumentPainter(...)),
        OverlayLayer(registry: _overlayRegistry),
      ],
    );
  }

  void _registerOverlays() {
    // Selection overlay
    if (widget.selection.isNotEmpty) {
      _overlayRegistry.register(CanvasOverlayEntry.painter(
        id: 'selection',
        zIndex: OverlayZIndex.selection,
        painter: SelectionOverlayPainter(...),
      ));
    } else {
      _overlayRegistry.unregister('selection');
    }

    // Add more overlay registrations as needed...
  }
}
```

## Testing

The overlay system includes comprehensive tests in `test/widget/overlay_layer_test.dart`:

### Registry Tests

```dart
test('sorts overlays by z-index ascending', () {
  registry.register(CanvasOverlayEntry.painter(id: 'c', zIndex: 300, ...));
  registry.register(CanvasOverlayEntry.painter(id: 'a', zIndex: 100, ...));
  registry.register(CanvasOverlayEntry.painter(id: 'b', zIndex: 200, ...));

  final sorted = registry.getSortedOverlays();

  expect(sorted[0].id, equals('a')); // z-index 100
  expect(sorted[1].id, equals('b')); // z-index 200
  expect(sorted[2].id, equals('c')); // z-index 300
});
```

### Widget Tests

```dart
testWidgets('renders overlays in z-index order', (tester) async {
  final registry = OverlayRegistry();

  registry.register(CanvasOverlayEntry.painter(id: 'high', zIndex: 300, ...));
  registry.register(CanvasOverlayEntry.painter(id: 'low', zIndex: 100, ...));
  registry.register(CanvasOverlayEntry.painter(id: 'mid', zIndex: 200, ...));

  await tester.pumpWidget(OverlayLayer(registry: registry));

  // Verify Stack children are in correct order
  final stack = tester.widget<Stack>(...);
  expect(stack.children[0].id, equals('low'));   // Lowest z-index renders first
  expect(stack.children[1].id, equals('mid'));
  expect(stack.children[2].id, equals('high'));  // Highest z-index renders last
});
```

### Hit-Test Tests

```dart
testWidgets('uses IgnorePointer for translucent overlays', (tester) async {
  registry.register(CanvasOverlayEntry.painter(
    id: 'translucent',
    zIndex: 100,
    painter: testPainter,
    hitTestBehavior: HitTestBehavior.translucent,
  ));

  await tester.pumpWidget(OverlayLayer(registry: registry));

  expect(find.byType(IgnorePointer), findsOneWidget);
});
```

## Performance Considerations

### Overlay Rebuilds

The registry notifies listeners on changes, triggering OverlayLayer rebuilds:

```dart
// This triggers a rebuild
registry.register(entry);

// This also triggers a rebuild
registry.unregister('id');
```

**Best Practice:** Register overlays in `build()` method - the registry deduplicates by ID, so re-registering with the same ID only triggers a rebuild if the painter/widget instance changes.

### Painter Repaints

Individual painters control their own repaint logic:

```dart
class SelectionOverlayPainter extends CustomPainter {
  SelectionOverlayPainter({
    required this.viewportController,
  }) : super(repaint: viewportController); // Repaint on viewport changes

  @override
  bool shouldRepaint(SelectionOverlayPainter oldDelegate) {
    return selection != oldDelegate.selection ||
           hoveredAnchor != oldDelegate.hoveredAnchor;
  }
}
```

**Best Practice:** Use granular shouldRepaint checks and pass Listenables to the `repaint` parameter for automatic repaints.

### Widget Overlays

Widget overlays use Flutter's normal rebuild logic:

```dart
registry.register(CanvasOverlayEntry.widget(
  id: 'tool-hints',
  zIndex: OverlayZIndex.toolHints,
  widget: ListenableBuilder(
    listenable: cursorManager,
    builder: (context, _) => ToolHintsOverlay(hints: cursorManager.hints),
  ),
));
```

**Best Practice:** Wrap widgets in `ListenableBuilder` or use Provider for fine-grained rebuilds.

## Future Extensions

The overlay system is designed for future enhancements:

### Snapping Guides (I4+)

```dart
registry.register(CanvasOverlayEntry.painter(
  id: 'snapping',
  zIndex: OverlayZIndex.snapping,
  painter: SnappingGuidePainter(
    activeGuides: snappingService.activeGuides,
    viewportController: viewportController,
  ),
));
```

### Shape Creation Guides (I4+)

```dart
registry.register(CanvasOverlayEntry.painter(
  id: 'shape-preview',
  zIndex: OverlayZIndex.shapePreview,
  painter: ShapePreviewPainter(
    previewState: shapeToolState,
    viewportController: viewportController,
  ),
));
```

### Animated Overlays (I5+)

```dart
registry.register(CanvasOverlayEntry.widget(
  id: 'animation-overlay',
  zIndex: 330,
  widget: AnimatedBuilder(
    animation: animationController,
    builder: (context, child) => CustomOverlay(...),
  ),
));
```

## Related Documentation

- [Tool Framework](./tool_framework.md)
- [Cursor Manager](./cursor_manager.md)
- [Canvas Architecture](../architecture/03_System_Structure_and_Data.md)
- [Rendering Pipeline](./rendering_pipeline.md)

## Task References

- **Task ID:** I3.T8
- **Dependencies:** I3.T3 (Selection Tool), I3.T5 (Cursor Manager), I3.T7 (Tool Hints)
- **Deliverables:** ✅ Overlay registry, ✅ Deterministic stacking, ✅ Tests, ✅ Documentation
