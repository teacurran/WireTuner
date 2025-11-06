# T014: Viewport Transform (Pan/Zoom)

## Status
- **Phase**: 3 - Rendering Engine
- **Priority**: Critical
- **Estimated Effort**: 1 day
- **Dependencies**: T013

## Overview
Implement pan and zoom functionality for the canvas viewport.

## Objectives
- Capture pan gestures (drag to move canvas)
- Capture zoom gestures (pinch or scroll to zoom)
- Maintain viewport state (offset, scale)
- Convert screen coordinates to document coordinates

## Implementation (lib/models/viewport/viewport_transform.dart)
```dart
class ViewportTransform {
  final Offset offset;
  final double scale;

  const ViewportTransform({
    this.offset = Offset.zero,
    this.scale = 1.0,
  });

  Offset screenToDocument(Offset screenPos) {
    return (screenPos - offset) / scale;
  }

  Offset documentToScreen(Offset docPos) {
    return docPos * scale + offset;
  }

  ViewportTransform withPan(Offset delta) {
    return ViewportTransform(
      offset: offset + delta,
      scale: scale,
    );
  }

  ViewportTransform withZoom(double delta, Offset focalPoint) {
    final newScale = (scale * delta).clamp(0.1, 10.0);
    final newOffset = focalPoint - (focalPoint - offset) * (newScale / scale);
    return ViewportTransform(offset: newOffset, scale: newScale);
  }
}
```

## GestureDetector Integration
```dart
GestureDetector(
  onScaleStart: _handleScaleStart,
  onScaleUpdate: _handleScaleUpdate,
  onScaleEnd: _handleScaleEnd,
  child: CanvasWidget(/* ... */),
)
```

## Success Criteria
- [ ] Can pan canvas by dragging
- [ ] Can zoom with pinch gesture
- [ ] Zoom centers on focal point
- [ ] Coordinate conversion works correctly

## References
- Dissipate viewport: `/Users/tea/dev/github/dissipate/lib/screens/whiteboard.dart:78-176`
