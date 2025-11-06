# T024: Pen Tool - Adjust BCPs After Placement

## Status
- **Phase**: 5 - Pen Tool
- **Priority**: Medium
- **Estimated Effort**: 1 day
- **Dependencies**: T023

## Overview
Allow adjusting BCPs of the last placed anchor point before placing next point.

## Objectives
- Alt-click last anchor to adjust BCPs
- Drag to reposition control handles
- Break symmetry if needed
- Continue path after adjustment

## Implementation
```dart
bool _isAdjustingLastAnchor = false;

@override
void onTapDown(TapDownDetails details, ViewportTransform viewport) {
  if (details.modifiers.alt && _currentPath != null) {
    final lastAnchor = _currentPath!.anchors.last;
    if (_hitTest(details.localPosition, lastAnchor.position)) {
      _isAdjustingLastAnchor = true;
      return;
    }
  }

  // Normal anchor placement logic...
}
```

## Success Criteria
- [ ] Can adjust last anchor's BCPs
- [ ] Alt-drag breaks symmetry
- [ ] Can continue path after adjustment

## References
- T023: Bezier Curves
