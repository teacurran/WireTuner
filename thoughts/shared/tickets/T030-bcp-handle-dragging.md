# T030: BCP Handle Dragging

## Status
- **Phase**: 7 - Direct Manipulation
- **Priority**: Critical (Milestone 0.1)
- **Estimated Effort**: 1.5 days
- **Dependencies**: T029

## Overview
Enable dragging BCP handles to adjust curve shape.

## Objectives
- Show BCP handles for selected anchors
- Drag handles to adjust curves
- Support symmetric, smooth, and corner point types
- Record BCP adjustments

## Implementation
```dart
void _renderBCPHandles(Canvas canvas, AnchorPoint anchor) {
  if (anchor.controlPoint1 != null) {
    // Draw line from anchor to CP1
    canvas.drawLine(anchor.position, anchor.controlPoint1!, _bcpLinePaint);
    // Draw CP1 handle circle
    canvas.drawCircle(anchor.controlPoint1!, 4.0, _bcpHandlePaint);
  }

  if (anchor.controlPoint2 != null) {
    canvas.drawLine(anchor.position, anchor.controlPoint2!, _bcpLinePaint);
    canvas.drawCircle(anchor.controlPoint2!, 4.0, _bcpHandlePaint);
  }
}

bool _hitTestBCP(Offset position, AnchorPoint anchor, double threshold) {
  if (anchor.controlPoint1 != null &&
      (position - anchor.controlPoint1!).distance < threshold) {
    return true; // Hit CP1
  }
  if (anchor.controlPoint2 != null &&
      (position - anchor.controlPoint2!).distance < threshold) {
    return true; // Hit CP2
  }
  return false;
}
```

## Success Criteria
- [ ] BCP handles visible for selected anchors
- [ ] Can drag handles to adjust curves
- [ ] Symmetric points maintain symmetry
- [ ] Smooth points maintain colinearity
- [ ] Corner points allow independent adjustment

## References
- Dissipate BCPs: `/Users/tea/dev/github/dissipate/lib/screens/whiteboard.dart:263-288`
