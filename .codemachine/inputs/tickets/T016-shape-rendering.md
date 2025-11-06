# T016: Shape Rendering

## Status
- **Phase**: 3 - Rendering Engine
- **Priority**: High
- **Estimated Effort**: 0.5 days
- **Dependencies**: T015

## Overview
Render shape primitives (rectangles, ellipses, polygons, stars).

## Objectives
- Render all shape types
- Convert shapes to paths for rendering
- Apply transformations correctly

## Implementation
```dart
void _renderShape(Canvas canvas, Shape shape) {
  final path = shape.toPath();
  _renderPath(canvas, path);
}
```

## Success Criteria
- [ ] All shape types render correctly
- [ ] Transformed shapes render correctly
- [ ] Shapes can be edited as paths

## References
- T011: Shape Data Model
