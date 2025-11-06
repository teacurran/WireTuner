# T020: Direct Selection Tool

## Status
- **Phase**: 4 - Tool System
- **Priority**: Critical
- **Estimated Effort**: 1 day
- **Dependencies**: T019

## Overview
Implement direct selection tool for selecting and manipulating anchor points and BCPs.

## Objectives
- Click to select individual anchor points
- Show BCPs for selected anchors
- Select multiple anchors with marquee
- Prepare for anchor/BCP dragging (implemented in T029-T030)

## Implementation
```dart
class DirectSelectionTool extends Tool {
  Set<AnchorPointRef> selectedAnchors = {};

  @override
  void onTapDown(TapDownDetails details, ViewportTransform viewport) {
    final docPos = viewport.screenToDocument(details.localPosition);
    final hitAnchor = _hitTestAnchor(docPos, threshold: 5.0 / viewport.scale);

    if (hitAnchor != null) {
      _selectAnchor(hitAnchor);
    }
  }
}

class AnchorPointRef {
  final String objectId;
  final int anchorIndex;
}
```

## Success Criteria
- [ ] Can select anchor points
- [ ] BCPs visible for selected anchors
- [ ] Multiple anchor selection works

## References
- Dissipate point selection: `/Users/tea/dev/github/dissipate/lib/screens/whiteboard.dart:231-252`
