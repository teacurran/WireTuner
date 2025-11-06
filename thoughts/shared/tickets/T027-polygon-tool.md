# T027: Polygon Tool

## Status
- **Phase**: 6 - Shape Tools
- **Priority**: Critical (Milestone 0.1)
- **Estimated Effort**: 1 day
- **Dependencies**: T026

## Overview
Implement polygon tool with configurable number of sides (3-12).

## Objectives
- Drag to create polygon
- UI slider for number of sides
- Preview shows current sides count

## Implementation
```dart
class PolygonTool extends Tool {
  int sides = 6; // Default hexagon

  @override
  Widget buildToolOptions() {
    return Slider(
      value: sides.toDouble(),
      min: 3,
      max: 12,
      divisions: 9,
      label: '$sides sides',
      onChanged: (value) => sides = value.toInt(),
    );
  }
}
```

## Success Criteria
- [ ] Creates polygons with 3-12 sides
- [ ] Slider updates sides in real-time

## References
- Dissipate polygon: `/Users/tea/dev/github/dissipate/lib/widget/polygon_painter.dart`
