# T032: Multi-Selection Support

## Status
- **Phase**: 7 - Direct Manipulation
- **Priority**: High
- **Estimated Effort**: 0.5 days
- **Dependencies**: T031

## Overview
Support selecting multiple objects and manipulating them together.

## Objectives
- Shift-click to add/remove from selection
- Marquee selection selects multiple objects
- All selected objects move/transform together
- Show combined bounding box

## Implementation
```dart
void _toggleSelection(String objectId) {
  if (_selectedObjects.contains(objectId)) {
    _selectedObjects.remove(objectId);
  } else {
    _selectedObjects.add(objectId);
  }
  notifyListeners();
}

Rect _getCombinedBounds(Set<String> objectIds) {
  Rect? bounds;
  for (final id in objectIds) {
    final objBounds = _getObjectBounds(id);
    bounds = bounds == null ? objBounds : bounds.expandToInclude(objBounds);
  }
  return bounds ?? Rect.zero;
}
```

## Success Criteria
- [ ] Can select multiple objects
- [ ] All selected objects move together
- [ ] Combined bounding box shown

## References
- T019: Selection Tool
