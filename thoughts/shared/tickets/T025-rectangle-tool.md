# T025: Rectangle Tool

## Status
- **Phase**: 6 - Shape Tools
- **Priority**: Critical (Milestone 0.1)
- **Estimated Effort**: 1 day
- **Dependencies**: T018

## Overview
Implement rectangle tool: click-drag to create rectangles.

## Objectives
- Click-drag to define bounds
- Show preview while dragging
- Create RectangleShape on release
- Record creation event

## Implementation
```dart
class RectangleTool extends Tool {
  Offset? _startPos;

  @override
  void onDragStart(DragStartDetails details, ViewportTransform viewport) {
    _startPos = viewport.screenToDocument(details.localPosition);
  }

  @override
  void onDragUpdate(DragUpdateDetails details, ViewportTransform viewport) {
    final currentPos = viewport.screenToDocument(details.localPosition);
    _previewBounds = Rect.fromPoints(_startPos!, currentPos);
  }

  @override
  void onDragEnd(DragEndDetails details, ViewportTransform viewport) {
    final shape = RectangleShape(
      id: Uuid().v4(),
      bounds: _previewBounds!,
      style: _currentStyle,
    );
    _addShape(shape);
    _recordEvent(EventType.objectShapeCreated, shape);
  }
}
```

## Success Criteria
- [ ] Drag creates rectangle
- [ ] Preview shows while dragging
- [ ] Can create squares (hold Shift)
- [ ] Event recorded

## References
- T011: Shape Data Model
