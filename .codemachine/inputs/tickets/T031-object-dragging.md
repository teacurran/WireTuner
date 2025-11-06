# T031: Object Dragging

## Status
- **Phase**: 7 - Direct Manipulation
- **Priority**: High
- **Estimated Effort**: 1 day
- **Dependencies**: T019

## Overview
Enable dragging entire objects (shapes, paths) to move them.

## Objectives
- Drag selected objects
- Move all anchor points together
- Apply transform to object
- Record transform event

## Implementation
```dart
class SelectionTool extends Tool {
  @override
  void onDragUpdate(DragUpdateDetails details, ViewportTransform viewport) {
    final delta = viewport.screenToDocument(details.delta);

    for (final objId in _selectedObjects) {
      final obj = _document.getObject(objId);
      final newTransform = obj.transform.withTranslation(delta);
      _updateObjectTransform(objId, newTransform);
    }
  }
}
```

## Success Criteria
- [ ] Can drag selected objects
- [ ] Multiple objects move together
- [ ] Transform recorded correctly

## References
- T019: Selection Tool
