# Viewport System

The viewport system provides comprehensive canvas transformation, navigation, and interaction features for WireTuner's vector editing interface.

## Overview

This module implements:

- **Viewport transformations** (pan, zoom, reset)
- **Per-artboard state persistence**
- **Screen-space grid snapping**
- **Intelligent keyboard nudging**
- **Zoom indicator UI widget**

## Architecture

The viewport system follows a layered architecture:

```
┌─────────────────────────────────────────┐
│  UI Layer (ZoomIndicator)               │
│  - Status bar widgets                   │
│  - User controls                        │
└─────────────────────────────────────────┘
           │
┌─────────────────────────────────────────┐
│  Service Layer                          │
│  - GridSnapper                          │
│  - NudgeService                         │
└─────────────────────────────────────────┘
           │
┌─────────────────────────────────────────┐
│  Controller Layer                       │
│  - ViewportController                   │
│  - ViewportState                        │
│  - ViewportBinding                      │
└─────────────────────────────────────────┘
           │
┌─────────────────────────────────────────┐
│  Domain Layer                           │
│  - Viewport (immutable model)           │
│  - Point, Size                          │
└─────────────────────────────────────────┘
```

## Components

### ViewportController

Core transformation controller managing zoom and pan operations.

**Features:**
- Coordinate transformations (world ↔ screen)
- Per-artboard state management
- Fit-to-screen functionality
- Zoom constraints (5% - 800%)

**Usage:**
```dart
final controller = ViewportController();

// Pan the viewport
controller.pan(Offset(100, 50));

// Zoom with focal point
controller.zoom(1.2, focalPoint: Offset(400, 300));

// Save/restore per-artboard state
controller.saveArtboardState('artboard-1');
controller.restoreArtboardState('artboard-1');

// Fit content to screen
controller.fitToScreen(
  contentBounds,
  canvasSize,
  padding: 50.0,
);

// Convert coordinates
final screenPoint = controller.worldToScreen(worldPoint);
final worldPoint = controller.screenToWorld(screenOffset);
```

**Per-Artboard State:**
- Each artboard can have its own zoom level and pan position
- State is automatically saved and restored when switching artboards
- Use `saveArtboardState(id)` before switching
- Use `restoreArtboardState(id)` when switching back

### GridSnapper

Screen-space grid snapping service.

**Key Design Decision:**
Grid snapping operates in **screen space**, not world space. This ensures:
- Uniform grid appearance at all zoom levels
- Consistent snapping behavior
- Predictable user experience

**Usage:**
```dart
final snapper = GridSnapper(
  config: GridSnapConfig(
    enabled: true,
    gridSize: 10.0,  // pixels in screen space
    snapThreshold: 5.0,
  ),
);

// Snap a point
final snappedPoint = snapper.snapPointToGrid(
  worldPoint,
  viewportController,
);

// Snap a distance
final snappedDistance = snapper.snapDistanceToGrid(
  worldDistance,
  viewportController,
);

// Check if point would snap
if (snapper.wouldSnap(point, controller)) {
  // Show snap indicator
}

// Generate grid lines for rendering
final grid = snapper.generateGridLines(canvasSize, controller);
for (final x in grid.verticalLines) {
  canvas.drawLine(/* ... */);
}
```

**Configuration Options:**
- `enabled`: Toggle snapping on/off
- `gridSize`: Grid spacing in screen pixels
- `showGrid`: Whether to render the grid
- `snapThreshold`: Maximum distance to snap (pixels)

### NudgeService

Intelligent keyboard nudging with overshoot detection and toast notifications.

**Features:**
- Screen-space nudge distances (1px, 10px with Shift)
- Cumulative tracking for undo grouping (200ms window)
- Overshoot detection for artboard boundaries
- Toast notifications for user feedback

**Usage:**
```dart
final nudgeService = NudgeService(
  controller: viewportController,
  onToast: (message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  },
);

// Handle arrow key press
final result = nudgeService.nudge(
  direction: NudgeDirection.right,
  largeNudge: event.isShiftPressed,
  contentBounds: selectionBounds,
  artboardBounds: currentArtboard.bounds,
);

// Apply delta to selection
applyTransform(result.delta);

// Check undo grouping
if (nudgeService.isGroupingActive) {
  // Within 200ms window - group with previous nudge
}
```

**Undo Grouping:**
- Nudges within 200ms are batched into a single undo operation
- Matches InteractionEngine's grouping threshold
- Use `cumulativeDelta` to track total movement
- Use `isGroupingActive` to check if grouping window is open

**Overshoot Detection:**
- Triggers when content exceeds artboard bounds by > threshold (default 50 units)
- Provides helpful toast messages
- Includes overshoot distance in message

### ZoomIndicator

Status bar widget showing zoom level with interactive controls.

**Features:**
- Real-time zoom percentage display
- Preset zoom levels (25%, 50%, 100%, 200%, 400%)
- Zoom in/out buttons
- Fit-to-screen button
- Reset to 100% button
- Compact mode for space-constrained layouts

**Usage:**
```dart
// Full indicator with controls
ZoomIndicator(
  controller: viewportController,
  onFitToScreen: () {
    controller.fitToScreen(
      artboardBounds,
      canvasSize,
    );
  },
)

// Compact mode (icon + percentage only)
ZoomIndicator(
  controller: viewportController,
  compact: true,
)
```

### ViewportBinding

Widget that binds viewport gestures to the widget tree.

**Features:**
- Pan gestures (drag with space bar)
- Pinch-to-zoom (touch devices)
- Scroll wheel zoom
- Keyboard shortcuts (Cmd/Ctrl+0 to reset, +/- to zoom)
- Debug overlay (FPS, zoom level, pan offset)

**Usage:**
```dart
ViewportBinding(
  controller: viewportController,
  onViewportChanged: (viewport) {
    // Sync to document model
    document = document.copyWith(viewport: viewport);
  },
  debugMode: true,  // Show FPS overlay
  child: CustomPaint(
    painter: DocumentPainter(
      viewportController: viewportController,
    ),
  ),
)
```

## Coordinate Systems

### World Space
- Document coordinates
- Infinite canvas
- Artboard coordinates are in world space
- Vector object positions are in world space

### Screen Space
- Viewport widget pixel coordinates
- Canvas rendering coordinates
- Grid snapping operates in screen space
- Nudge distances specified in screen space

### Conversion
```dart
// World → Screen
final screenOffset = controller.worldToScreen(worldPoint);
final screenDistance = controller.worldDistanceToScreen(worldDistance);

// Screen → World
final worldPoint = controller.screenToWorld(screenOffset);
final worldDistance = controller.screenDistanceToWorld(screenDistance);
```

## Integration

### With InteractionEngine

The viewport services are designed to integrate with InteractionEngine:

1. **NudgeService** calculates deltas but doesn't mutate state
2. Return `NudgeResult` containing world-space delta
3. Caller creates `TransformCommand` with delta
4. Dispatch command through InteractionEngine
5. InteractionEngine handles undo grouping and event recording

```dart
// In tool implementation
final result = nudgeService.nudge(
  direction: direction,
  largeNudge: isShiftPressed,
  contentBounds: selection.bounds,
  artboardBounds: artboard.bounds,
);

// Create and dispatch command
final command = TransformCommand(
  objectIds: selection.objectIds,
  delta: result.delta,
);

interactionEngine.dispatch(command);
```

### With TelemetryService

Viewport operations emit telemetry events:

```dart
ViewportState(
  controller: controller,
  onTelemetry: (telemetry) {
    telemetryService.recordEvent(
      'viewport_interaction',
      data: {
        'type': telemetry.eventType,
        'zoom': telemetry.zoomLevel,
        'fps': telemetry.fps,
      },
    );
  },
);
```

## Testing

Comprehensive test coverage includes:

- **ViewportController Tests** (`viewport_controller_test.dart`):
  - Basic transformations
  - Coordinate conversions
  - Per-artboard state management
  - Fit-to-screen calculations
  - Zoom with focal point

- **GridSnapper Tests** (`grid_snapper_test.dart`):
  - Screen-space snapping at various zoom levels
  - Distance snapping
  - Snap detection (wouldSnap)
  - Grid line generation
  - Edge cases (extreme zoom, negative coords)

- **NudgeService Tests** (`nudge_service_test.dart`):
  - Screen-space nudge distance calculations
  - Cumulative tracking and undo grouping
  - Overshoot detection for all edges
  - Toast notification triggering
  - Edge cases (zero bounds, extreme zoom)

**Run Tests:**
```bash
flutter test test/unit/presentation/viewport/
```

## Performance Considerations

### ViewportController
- Matrix caching: Transformation matrices are cached and only recomputed on zoom/pan changes
- Efficient notifications: Only notifies listeners when state actually changes
- No unnecessary allocations: Reuses cached matrices

### GridSnapper
- Screen-space calculations: Avoids complex world-space transformations
- Minimal allocations: Uses simple arithmetic, no temporary objects
- Early returns: Disabled snapping returns immediately

### NudgeService
- Timer-based reset: Cumulative tracking resets automatically after grouping window
- Lightweight delta calculation: Simple arithmetic operations
- Optional overshoot detection: Skip bounds checking when not needed

## Architectural Alignment

This implementation aligns with the architecture documents:

**FR-012**: Viewport state management
- ✓ Per-artboard viewport state persistence
- ✓ Zoom, pan, and fit-to-screen controls
- ✓ Coordinate transformation utilities

**FR-013**: Screen-space grid snapping
- ✓ Grid defined in screen space for consistency
- ✓ Configurable grid size and snap threshold
- ✓ Visual grid rendering support

**FR-028**: Intelligent nudging
- ✓ Arrow key nudging with Shift modifier
- ✓ Screen-space nudge distances (1px, 10px)
- ✓ Conversion to world-space for commands

**FR-050**: User feedback
- ✓ Toast notifications for overshoot
- ✓ Helpful hints about boundary violations
- ✓ Overshoot distance included in messages

**Section 7.11**: Viewport architecture
- ✓ ViewportController manages transformations
- ✓ ViewportState bridges gestures to domain
- ✓ Per-artboard state stored in controller
- ✓ Telemetry integration for performance monitoring

## Future Enhancements

Potential improvements for future iterations:

1. **Zoom Animations**: Smooth zoom transitions
2. **Pan Inertia**: Momentum-based panning after gesture release
3. **Snap Preview**: Visual indicators showing snap targets
4. **Custom Grid Patterns**: Isometric, hexagonal, etc.
5. **Ruler Guides**: User-defined snap guides
6. **Viewport History**: Undo/redo for viewport changes
7. **Mini-map**: Overview navigator for large documents
8. **Touch Gestures**: Two-finger pan, pinch zoom optimization

## References

- Architecture: `.codemachine/artifacts/architecture/06_UI_UX_Architecture.md`
- Data Model: `.codemachine/artifacts/architecture/02_System_Structure_and_Data.md`
- Interaction Flows: `.codemachine/artifacts/architecture/03_Behavior_and_Communication.md`
- Implementation Plan: `.codemachine/artifacts/plan/02_Iteration_I3.md`
