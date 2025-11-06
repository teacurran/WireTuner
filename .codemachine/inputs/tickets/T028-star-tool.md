# T028: Star Tool

## Status
- **Phase**: 6 - Shape Tools
- **Priority**: Critical (Milestone 0.1)
- **Estimated Effort**: 1 day
- **Dependencies**: T027

## Overview
Implement star tool with configurable points and inner radius.

## Objectives
- Drag to create star
- UI for number of points (3-12)
- UI slider for inner radius ratio (0.2-0.8)

## Implementation
```dart
class StarShape {
  final int points;
  final double innerRadiusRatio; // 0.0-1.0

  VectorPath toPath() {
    // Generate alternating outer/inner points
  }
}
```

## Success Criteria
- [ ] Creates stars with variable points
- [ ] Inner radius adjusts shape
- [ ] Looks like traditional star shapes

## References
- T011: Shape Data Model
