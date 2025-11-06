# T019: Selection Tool

## Status
- **Phase**: 4 - Tool System
- **Priority**: Critical
- **Estimated Effort**: 1 day
- **Dependencies**: T018

## Overview
Implement selection tool for clicking objects and marquee selection.

## Objectives
- Click to select objects
- Shift-click to add/remove from selection
- Drag for marquee (rectangular) selection
- Hit testing for objects

## Implementation
```dart
class SelectionTool extends Tool {
  @override
  void onTapDown(TapDownDetails details, ViewportTransform viewport) {
    final docPos = viewport.screenToDocument(details.localPosition);
    final hitObject = _hitTest(docPos);

    if (hitObject != null) {
      if (details.modifiers.shift) {
        _toggleSelection(hitObject);
      } else {
        _selectSingle(hitObject);
      }
    } else {
      _startMarqueeSelection(docPos);
    }
  }
}
```

## Success Criteria
- [ ] Can select objects by clicking
- [ ] Shift-click adds to selection
- [ ] Marquee selection works
- [ ] Hit testing is accurate

## References
- Dissipate selection: `/Users/tea/dev/github/dissipate/lib/screens/whiteboard.dart:231-252`
