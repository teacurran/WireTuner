# T015: Path Rendering with Bezier Curves

## Status
- **Phase**: 3 - Rendering Engine
- **Priority**: Critical
- **Estimated Effort**: 1 day
- **Dependencies**: T013

## Overview
Implement rendering of vector paths with bezier curves, strokes, and fills.

## Objectives
- Render paths using Flutter Path API
- Draw bezier curves correctly
- Apply stroke and fill styles
- Show anchor points and BCPs in edit mode

## Implementation
```dart
void _renderPath(Canvas canvas, VectorPath path) {
  final flutterPath = path.toFlutterPath();

  // Fill
  if (path.style.fillColor != null) {
    final fillPaint = Paint()
      ..color = path.style.fillColor!
      ..style = PaintingStyle.fill;
    canvas.drawPath(flutterPath, fillPaint);
  }

  // Stroke
  final strokePaint = Paint()
    ..color = path.style.strokeColor
    ..strokeWidth = path.style.strokeWidth
    ..style = PaintingStyle.stroke;
  canvas.drawPath(flutterPath, strokePaint);

  // Render anchor points (if in edit mode)
  if (editMode) {
    for (final anchor in path.anchors) {
      _renderAnchorPoint(canvas, anchor);
    }
  }
}
```

## Success Criteria
- [ ] Paths render with correct stroke/fill
- [ ] Bezier curves are smooth
- [ ] Anchor points visible in edit mode
- [ ] BCPs visible when anchor selected

## References
- Dissipate rendering: `/Users/tea/dev/github/dissipate/lib/screens/whiteboard.dart:335-383`
