# T041: Anchor Point Hit Testing

## Status
- **Phase**: 10 - Anchor Point Visualization
- **Priority**: Critical (Milestone 0.1)
- **Estimated Effort**: 0.5 days
- **Dependencies**: T040

## Overview
Enable clicking and selecting anchor points via transparent fill areas. Implement hit testing to detect when user clicks near an anchor point. Hit testing only active when anchor points are visible (View → Show Anchor Points enabled).

## Objectives
- Detect clicks on anchor points with appropriate hit radius
- Return anchor metadata for selection/manipulation
- Support multi-selection with Shift key modifier
- Prioritize anchor hits over path/object selection

## Hit Testing Specifications

### Hit Test Radius
- **Radius**: 8px screen space (slightly larger than visual size)
- **Rationale**: Makes anchors easier to click, especially at high zoom levels
- **Visual size**: 5-7px, hit size: 8px = ~1-3px clickable margin

### Return Data
When anchor hit detected, return:
```dart
class AnchorHit {
  final String pathId;           // ID of path containing anchor
  final int anchorIndex;         // Index of anchor in path.anchors list
  final AnchorType anchorType;   // Smooth, corner, or tangent
  final Point position;          // World coordinates of anchor
  final AnchorVisualType visualType; // For rendering feedback
}
```

### Priority Rules
1. **Closest anchor within radius wins** (if multiple anchors overlap)
2. **Anchor hits override path hits** (clicking near anchor selects anchor, not path)
3. **Shift + click adds to selection** (multi-select)
4. **Click outside deselects all** (unless Shift held)

## Implementation

### Add Hit Testing Method

Create `anchor_hit_testing.dart` utility:

```dart
import 'dart:math' show sqrt;
import 'package:wiretuner/domain/models/path.dart' as domain;
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';

/// Result of anchor point hit test.
class AnchorHit {
  const AnchorHit({
    required this.pathId,
    required this.anchorIndex,
    required this.anchorType,
    required this.position,
    required this.visualType,
  });

  final String pathId;
  final int anchorIndex;
  final AnchorType anchorType;
  final Point position;
  final AnchorVisualType visualType;
}

/// Hit test radius in screen pixels.
const double kAnchorHitRadius = 8.0;

/// Performs hit testing for anchor points.
class AnchorHitTester {
  /// Tests if a screen position hits any anchor in the given paths.
  ///
  /// Returns the closest anchor within hit radius, or null if no hit.
  static AnchorHit? hitTestAnchor({
    required Offset screenPosition,
    required Map<String, domain.Path> paths,
    required ViewportController viewportController,
  }) {
    AnchorHit? closestHit;
    double closestDistance = kAnchorHitRadius;

    // Check all paths
    for (final entry in paths.entries) {
      final pathId = entry.key;
      final path = entry.value;

      // Check all anchors in this path
      for (var i = 0; i < path.anchors.length; i++) {
        final anchor = path.anchors[i];

        // Convert anchor position to screen coordinates
        final anchorScreenPos = viewportController.worldToScreen(anchor.position);

        // Calculate distance
        final distance = _calculateDistance(screenPosition, anchorScreenPos);

        // Check if within hit radius and closer than previous hits
        if (distance < closestDistance) {
          closestDistance = distance;
          closestHit = AnchorHit(
            pathId: pathId,
            anchorIndex: i,
            anchorType: anchor.anchorType,
            position: anchor.position,
            visualType: _determineVisualType(anchor),
          );
        }
      }
    }

    return closestHit;
  }

  /// Calculates Euclidean distance between two screen positions.
  static double _calculateDistance(Offset p1, Offset p2) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    return sqrt(dx * dx + dy * dy);
  }

  /// Determines visual type from anchor configuration.
  static AnchorVisualType _determineVisualType(AnchorPoint anchor) {
    final hasHandleIn = anchor.handleIn != null;
    final hasHandleOut = anchor.handleOut != null;

    if (hasHandleIn && hasHandleOut) {
      return AnchorVisualType.smooth;
    } else if (!hasHandleIn && !hasHandleOut) {
      return AnchorVisualType.corner;
    } else {
      return AnchorVisualType.tangent;
    }
  }
}
```

### Integrate with Direct Selection Tool

Update `direct_selection_tool.dart`:

```dart
@override
bool onPointerDown(PointerDownEvent event) {
  final screenPos = event.localPosition;

  // Only hit test anchors if they're visible
  final showAnchorPoints = _viewSettings?.showAnchorPoints ?? true;

  if (showAnchorPoints) {
    // First, try to hit test anchors
    final anchorHit = AnchorHitTester.hitTestAnchor(
      screenPosition: screenPos,
      paths: _getPathsMap(),
      viewportController: _viewportController,
    );

    if (anchorHit != null) {
    // Anchor hit - update selection
    final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

    if (isShiftPressed) {
      // Multi-select: add to existing selection
      _addAnchorToSelection(anchorHit);
    } else {
      // Single select: replace selection
      _selectAnchor(anchorHit);
    }

    _logger.d('Anchor selected: path=${anchorHit.pathId}, index=${anchorHit.anchorIndex}');
    return true;
  }

      return true;
    }
  }

  // No anchor hit (or anchors hidden) - fall back to object selection
  return _handleObjectSelection(event);
}

void _selectAnchor(AnchorHit hit) {
  // Update document selection to include this anchor
  _documentProvider.updateSelection(
    Selection.anchor(
      pathId: hit.pathId,
      anchorIndex: hit.anchorIndex,
    ),
  );
}

void _addAnchorToSelection(AnchorHit hit) {
  // Add to existing selection
  final currentSelection = _documentProvider.document.selection;
  final updatedSelection = currentSelection.addAnchor(
    pathId: hit.pathId,
    anchorIndex: hit.anchorIndex,
  );
  _documentProvider.updateSelection(updatedSelection);
}
```

## Selection State Management

### Update Selection Model

Extend `Selection` class to support anchor selection:

```dart
class Selection {
  const Selection({
    this.selectedObjects = const {},
    this.selectedAnchors = const {}, // NEW
  });

  final Set<String> selectedObjects;
  final Map<String, Set<int>> selectedAnchors; // pathId -> anchor indices

  /// Creates selection with single anchor.
  factory Selection.anchor({
    required String pathId,
    required int anchorIndex,
  }) {
    return Selection(
      selectedAnchors: {
        pathId: {anchorIndex}
      },
    );
  }

  /// Adds anchor to existing selection.
  Selection addAnchor({
    required String pathId,
    required int anchorIndex,
  }) {
    final updatedAnchors = Map<String, Set<int>>.from(selectedAnchors);
    updatedAnchors.putIfAbsent(pathId, () => <int>{});
    updatedAnchors[pathId]!.add(anchorIndex);

    return Selection(
      selectedObjects: selectedObjects,
      selectedAnchors: updatedAnchors,
    );
  }

  bool get isNotEmpty => selectedObjects.isNotEmpty || selectedAnchors.isNotEmpty;
  bool get isEmpty => !isNotEmpty;
}
```

## Success Criteria
- [ ] Clicking on anchor (within 8px) selects it when anchors are visible
- [ ] Hit testing disabled when View → Show Anchor Points is off
- [ ] Closest anchor within radius is selected (if multiple overlapping)
- [ ] Shift + click adds anchor to selection
- [ ] Click outside deselects all anchors (unless Shift held)
- [ ] Anchor selection takes priority over path selection when visible
- [ ] Selection state includes anchor metadata (pathId, index)

## Testing
- [ ] Unit test: Hit test returns closest anchor within radius
- [ ] Unit test: Hit test returns null when no anchors within radius
- [ ] Unit test: Multi-select adds anchors without replacing
- [ ] Integration test: Click anchor, verify selection state updated
- [ ] Integration test: Shift+click multiple anchors, verify multi-select
- [ ] Manual test: Click near overlapping anchors, verify closest is selected

## References
- Selection overlay: `lib/presentation/canvas/overlays/selection_overlay.dart`
- Direct selection tool: `lib/application/tools/selection/direct_selection_tool.dart`
- Anchor dragging: `.codemachine/inputs/tickets/T029-anchor-dragging.md`
