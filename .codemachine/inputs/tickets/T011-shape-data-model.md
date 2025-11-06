# T011: Shape Data Model

## Status
- **Phase**: 2 - Vector Data Model
- **Priority**: Critical
- **Estimated Effort**: 1 day
- **Dependencies**: T009

## Overview
Create shape primitives (Rectangle, Ellipse, Polygon, Star) with conversion to paths.

## Objectives
- Define base Shape class
- Implement Rectangle, Ellipse, Polygon, Star shapes
- Convert shapes to paths for rendering and editing
- Support shape-specific properties

## Implementation

### Base Shape (lib/models/vector/shape.dart)
```dart
abstract class Shape {
  String get id;
  Rect get bounds;
  Transform2D get transform;
  PathStyle get style;

  VectorPath toPath();
}

class RectangleShape implements Shape {
  final String id;
  final Rect bounds;
  final double cornerRadius;
  final Transform2D transform;
  final PathStyle style;

  const RectangleShape({
    required this.id,
    required this.bounds,
    this.cornerRadius = 0,
    this.transform = const Transform2D(),
    required this.style,
  });

  @override
  VectorPath toPath() {
    // Generate path with 4 corners (8 if rounded)
  }
}

class EllipseShape implements Shape {
  final String id;
  final Rect bounds;
  final Transform2D transform;
  final PathStyle style;

  @override
  VectorPath toPath() {
    // Generate ellipse as bezier approximation
  }
}

class PolygonShape implements Shape {
  final String id;
  final Rect bounds;
  final int sides;
  final Transform2D transform;
  final PathStyle style;

  @override
  VectorPath toPath() {
    // Generate regular polygon
  }
}

class StarShape implements Shape {
  final String id;
  final Rect bounds;
  final int points;
  final double innerRadius; // 0-1, ratio of inner to outer radius
  final Transform2D transform;
  final PathStyle style;

  @override
  VectorPath toPath() {
    // Generate star shape
  }
}
```

## Success Criteria

### Automated Verification
- [ ] All shape types can be created
- [ ] Shapes convert to paths correctly
- [ ] Polygon with 4 sides creates square
- [ ] Star with 5 points creates pentagram

### Manual Verification
- [ ] Shapes render correctly
- [ ] Transformed shapes render correctly

## References
- Dissipate polygon: `/Users/tea/dev/github/dissipate/lib/widget/polygon_painter.dart:5-49`
