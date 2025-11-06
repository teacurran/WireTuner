# T022: Pen Tool - Straight Segments

## Status
- **Phase**: 5 - Pen Tool
- **Priority**: High
- **Estimated Effort**: 0.5 days
- **Dependencies**: T021

## Overview
Connect anchor points with straight line segments (no BCPs).

## Objectives
- Create straight segments between consecutive points
- Render preview line while creating
- Finalize segment on next click

## Implementation
```dart
void _addAnchorPoint(Offset position) {
  final newAnchor = AnchorPoint(
    id: Uuid().v4(),
    position: position,
    type: PointType.corner, // Straight = corner points, no BCPs
  );

  _currentPath = _currentPath!.withAnchorAdded(newAnchor);
}
```

## Success Criteria
- [ ] Straight segments connect points
- [ ] Preview line shows before clicking
- [ ] Renders correctly

## References
- T021: Pen Tool Basics
