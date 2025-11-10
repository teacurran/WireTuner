# T042: Anchor Point Visual Interaction

## Status
- **Phase**: 10 - Anchor Point Visualization
- **Priority**: High
- **Estimated Effort**: 1 day
- **Dependencies**: T041

## Overview
Provide visual feedback for anchor point interaction states: hover, selection, and dragging. Enhances user experience by making anchor point manipulation more intuitive.

## Objectives
- Show hover state when mouse over anchor
- Highlight selected anchors with outline
- Display drag preview during anchor movement
- Maintain visual consistency with anchor types

## Visual State Specifications

### Hover State
**Trigger**: Mouse cursor within 8px of anchor (hit test radius)

**Visual Changes**:
- Increase size by 30%
  - Smooth: 5px → 6.5px radius
  - Corner: 7x7px → 9x9px square
  - Tangent: 7px → 9px triangle sides
- Add outer glow (2px, 50% opacity)
  - Smooth: Red glow (#FF0000 @ 50%)
  - Corner: White glow (#FFFFFF @ 50%)
  - Tangent: Orange glow (#FF8800 @ 50%)
- Cursor changes to `SystemMouseCursors.click`

**Implementation**:
```dart
void _renderHoveredAnchor(Canvas canvas, Offset position, AnchorVisualType type) {
  // Draw glow
  final glowPaint = ui.Paint()
    ..color = _getGlowColor(type).withOpacity(0.5)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 2.0
    ..maskFilter = const ui.MaskFilter.blur(BlurStyle.normal, 2.0);

  // Draw enlarged shape
  _renderAnchor(canvas, position, type, sizeMultiplier: 1.3);
}
```

### Selected State
**Trigger**: Anchor included in `Selection.selectedAnchors`

**Visual Changes**:
- Keep original size and color
- Add blue outline (2px, 100% opacity)
  - Color: #2196F3 (Material blue)
- Draw on top of non-selected anchors (z-order)
- Maintain anchor type appearance (circle/square/triangle)

**Implementation**:
```dart
void _renderSelectedAnchor(Canvas canvas, Offset position, AnchorVisualType type) {
  // Draw normal anchor
  _renderAnchor(canvas, position, type);

  // Add blue outline
  final outlinePaint = ui.Paint()
    ..color = const Color(0xFF2196F3)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 2.0;

  // Draw outline shape matching anchor type
  _drawOutline(canvas, position, type, outlinePaint);
}
```

### Dragging State
**Trigger**: Mouse down on anchor + mouse move (anchor being dragged)

**Visual Changes**:
- Show live position at cursor location
- Original anchor shows at 50% opacity (ghost position)
- Dragging anchor shows at 100% opacity with blue outline
- Optional: Faded trail effect showing path from start to current position

**Implementation**:
```dart
class AnchorDragState {
  final AnchorHit anchor;
  final Point startPosition;
  final Point currentPosition;
  final List<Point> trailPositions; // Optional trail
}

void _renderDraggingAnchor(Canvas canvas, AnchorDragState dragState) {
  // Draw ghost at original position (50% opacity)
  final ghostPaint = ui.Paint()
    ..color = _getAnchorColor(dragState.anchor.visualType).withOpacity(0.5);
  _renderAnchor(canvas, dragState.startPosition, dragState.anchor.visualType);

  // Draw trail (optional, fading opacity)
  _renderTrail(canvas, dragState.trailPositions);

  // Draw live position with selection outline
  _renderSelectedAnchor(
    canvas,
    viewportController.worldToScreen(dragState.currentPosition),
    dragState.anchor.visualType,
  );
}
```

## State Management

### Hover State Tracking
```dart
class AnchorInteractionState {
  AnchorHit? hoveredAnchor;
  Set<String> selectedAnchorIds; // "pathId:anchorIndex" format
  AnchorDragState? dragState;
}
```

### Update AnchorPointOverlayPainter
```dart
class AnchorPointOverlayPainter extends CustomPainter {
  AnchorPointOverlayPainter({
    required this.paths,
    required this.viewportController,
    this.interactionState, // NEW
  }) : super(repaint: viewportController);

  final Map<String, domain.Path> paths;
  final ViewportController viewportController;
  final AnchorInteractionState? interactionState; // NEW

  @override
  void paint(Canvas canvas, ui.Size size) {
    // Render normal anchors first
    _renderAllAnchors(canvas);

    // Render selected anchors on top
    _renderSelectedAnchors(canvas);

    // Render hovered anchor on top of selected
    if (interactionState?.hoveredAnchor != null) {
      _renderHoveredAnchor(canvas, interactionState!.hoveredAnchor!);
    }

    // Render dragging anchor on top of everything
    if (interactionState?.dragState != null) {
      _renderDraggingAnchor(canvas, interactionState!.dragState!);
    }
  }
}
```

## Integration with Tools

### Hover Tracking in Direct Selection Tool
```dart
@override
bool onPointerHover(PointerHoverEvent event) {
  final screenPos = event.localPosition;

  // Hit test anchors
  final anchorHit = AnchorHitTester.hitTestAnchor(
    screenPosition: screenPos,
    paths: _getPathsMap(),
    viewportController: _viewportController,
  );

  if (anchorHit != _hoveredAnchor) {
    setState(() {
      _hoveredAnchor = anchorHit;
    });
    _updateOverlayState();
  }

  return anchorHit != null;
}

@override
MouseCursor get cursor {
  return _hoveredAnchor != null
      ? SystemMouseCursors.click
      : SystemMouseCursors.basic;
}
```

### Drag Tracking Integration
```dart
@override
bool onPointerMove(PointerMoveEvent event) {
  if (_dragState != null) {
    final worldPos = _viewportController.screenToWorld(event.localPosition);

    setState(() {
      _dragState = _dragState!.copyWith(
        currentPosition: worldPos,
        trailPositions: [..._dragState!.trailPositions, worldPos],
      );
    });

    _updateOverlayState();
    return true;
  }

  return false;
}
```

## Performance Considerations

### Hover Optimization
- Debounce hover state updates (16ms = 60 FPS)
- Only repaint overlay layer, not document layer
- Cache anchor screen positions between frames

### Drag Optimization
- Limit trail history to last 10 positions
- Sample trail positions at 50ms intervals
- Use `shouldRepaint` to skip unnecessary redraws

## Success Criteria
- [ ] Anchors increase size and show glow on hover
- [ ] Selected anchors show blue outline
- [ ] Dragging anchors show ghost at original position + live position
- [ ] Visual states stack correctly (drag > hover > selected > normal)
- [ ] No visual glitches or flicker during state transitions
- [ ] Cursor changes to pointer when hovering over anchor
- [ ] Performance maintains 60 FPS with 100+ anchors visible

## Testing
- [ ] Unit test: State transitions trigger correct visual rendering
- [ ] Widget test: Hover state renders enlarged anchor with glow
- [ ] Widget test: Selected state adds blue outline
- [ ] Integration test: Hover → select → drag sequence
- [ ] Manual test: Hover over multiple anchors, verify smooth transitions
- [ ] Manual test: Drag anchor, verify ghost and live positions render correctly

## References
- Pen preview overlay: `lib/presentation/canvas/overlays/pen_preview_overlay.dart`
- Selection overlay: `lib/presentation/canvas/overlays/selection_overlay.dart`
- T029 Anchor dragging: `.codemachine/inputs/tickets/T029-anchor-dragging.md`
- T030 BCP handle dragging: `.codemachine/inputs/tickets/T030-bcp-handle-dragging.md`
