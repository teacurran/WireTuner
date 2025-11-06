# T017: Selection Visualization

## Status
- **Phase**: 3 - Rendering Engine
- **Priority**: High
- **Estimated Effort**: 1 day
- **Dependencies**: T015

## Overview
Render selection indicators (bounding boxes, handles, marquee selection).

## Objectives
- Show bounding box around selected objects
- Render transform handles (corners, edges)
- Animated dashed marquee for area selection
- Selected anchor points highlighted

## Implementation
```dart
void _renderSelection(Canvas canvas, Set<String> selectedIds) {
  for (final id in selectedIds) {
    final obj = document.getObject(id);
    if (obj != null) {
      _renderBoundingBox(canvas, obj);
      _renderTransformHandles(canvas, obj);
    }
  }
}

void _renderBoundingBox(Canvas canvas, VectorObject obj) {
  final bounds = _getObjectBounds(obj);
  final paint = Paint()
    ..color = Colors.blue
    ..strokeWidth = 1.0 / viewport.scale
    ..style = PaintingStyle.stroke;
  canvas.drawRect(bounds, paint);
}
```

## Success Criteria
- [ ] Selected objects show blue bounding box
- [ ] Transform handles appear on selection
- [ ] Marquee selection animates correctly

## References
- Dissipate selection: `/Users/tea/dev/github/dissipate/lib/screens/whiteboard.dart:393-425`
