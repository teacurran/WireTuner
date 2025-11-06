# T021: Pen Tool - Create Anchor Points

## Status
- **Phase**: 5 - Pen Tool
- **Priority**: Critical
- **Estimated Effort**: 1 day
- **Dependencies**: T020

## Overview
Implement pen tool basics: clicking to create anchor points and start paths.

## Objectives
- Click to create new anchor point
- Start new path on first click
- Add points to current path
- Close path on click at start point

## Implementation
```dart
class PenTool extends Tool {
  VectorPath? _currentPath;

  @override
  void onTapDown(TapDownDetails details, ViewportTransform viewport) {
    final docPos = viewport.screenToDocument(details.localPosition);

    if (_currentPath == null) {
      _startNewPath(docPos);
    } else {
      if (_shouldClosePath(docPos)) {
        _closePath();
      } else {
        _addAnchorPoint(docPos);
      }
    }

    _recordEvent(EventType.pathAnchorAdded, docPos);
  }
}
```

## Success Criteria
- [ ] Click creates anchor point
- [ ] Path continues from last point
- [ ] Can close path by clicking start
- [ ] Events recorded correctly

## References
- Dissipate pen tool: `/Users/tea/dev/github/dissipate/lib/screens/whiteboard.dart:213-229`
