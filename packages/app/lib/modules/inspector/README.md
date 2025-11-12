# Inspector Module

The Inspector module provides property editing UI for selected objects in the WireTuner canvas. It displays organized property groups (Transform, Fill, Stroke, Effects) and integrates with the domain layer through a command abstraction.

## Architecture

```
inspector/
├── state/
│   ├── inspector_provider.dart    # State management (ChangeNotifier)
│   └── inspector_service.dart     # Command dispatch abstraction
├── widgets/
│   └── property_groups/
│       ├── transform_property_group.dart  # Position, size, rotation
│       ├── fill_property_group.dart       # Fill color, opacity
│       └── stroke_property_group.dart     # Stroke properties
└── inspector_panel.dart           # Main panel widget
```

## Key Features

### Multi-State Support

- **No Selection**: Displays placeholder message
- **Single Selection**: All properties editable
- **Multi-Selection**: Shared properties editable, mixed values shown as "—"

### Property Groups

#### Transform
- X, Y position (px)
- Width, Height (px)
- Rotation (degrees)
- Aspect ratio lock toggle
- Keyboard shortcuts: Arrow keys ±1, Shift+arrow ±10

#### Fill
- Color picker with preset colors
- Opacity slider (0-100%)
- Eyedropper tool placeholder (future)

#### Stroke
- Color picker
- Width (px)
- Cap style (butt, round, square)
- Join style (miter, round, bevel)
- Add/Remove stroke button

#### Effects
- Placeholder for future shadow/blur effects

### Staged Changes

- Edits are staged locally until "Apply" is clicked
- "Reset" button reverts to last committed state
- Changes dispatch through `InspectorService` abstraction layer

## Usage

### Basic Setup

```dart
import 'package:app/modules/inspector/inspector_panel.dart';
import 'package:app/modules/inspector/state/inspector_provider.dart';
import 'package:app/modules/inspector/state/inspector_service.dart';

// Create service
final inspectorService = InspectorService(
  telemetryCallback: (metric, data) => telemetry.record(metric, data),
);

// Listen to commands
inspectorService.commandStream.listen((event) {
  // Wire to InteractionEngine/EventStore
  eventStore.dispatch(event.command, event.data);
});

// Provide to widget tree
MultiProvider(
  providers: [
    ChangeNotifierProvider(
      create: (_) => InspectorProvider(
        commandDispatcher: inspectorService.dispatch,
      ),
    ),
    Provider.value(value: inspectorService),
  ],
  child: InspectorPanel(),
)
```

### Updating Selection

```dart
final inspector = context.read<InspectorProvider>();

// Single selection
inspector.updateSelection(
  ['object1'],
  [
    ObjectProperties(
      objectId: 'object1',
      objectType: 'Rectangle',
      x: 100,
      y: 200,
      width: 150,
      height: 100,
      fillColor: Colors.blue,
    ),
  ],
);

// Multi-selection
inspector.updateSelection(
  ['object1', 'object2'],
  [props1, props2],
);

// Clear selection
inspector.updateSelection([], []);
```

### Property Updates

```dart
// Stage transform changes
inspector.updateTransform(x: 250, y: 350);

// Stage fill changes
inspector.updateFill(color: Colors.red, opacity: 0.8);

// Stage stroke changes
inspector.updateStroke(color: Colors.black, width: 2.0);

// Commit all staged changes
inspector.applyChanges();

// Or discard staged changes
inspector.resetChanges();
```

## Integration Points

### InteractionEngine

The Inspector integrates with the InteractionEngine for:
- Selection updates (from canvas to Inspector)
- Property commands (from Inspector to domain model)
- Undo/redo boundaries

### EventStore

Property changes are dispatched as commands to the EventStore:
- `updateObjectProperties`: Modify object properties
- Replay support for undo/redo
- Conflict resolution for collaborative edits

### TelemetryService

The Inspector emits telemetry events:
- `inspector.command`: Command dispatch events
- Property edit metrics (future)

## Accessibility

All interactive elements include:
- Semantic labels (`aria-label` equivalents)
- Keyboard navigation support
- Focus indicators
- Screen reader announcements for mixed values
- High contrast mode support (via theme tokens)

## Testing

See `test/inspector/`:
- `inspector_provider_test.dart`: State management tests
- Property staging and commit tests
- Multi-selection mixed value computation tests

## Design Tokens

The Inspector uses the following tokens (from `docs/ui/tokens.md`):
- `surface.raised`: Panel background (#141920)
- `spacing.spacing8`: Field group spacing (8px)
- `spacing.spacing16`: Section padding (16px)
- `mono_md`: IBM Plex Mono for numeric fields

## Future Enhancements

- [ ] Gradient fill editor with draggable stops
- [ ] Shadow/blur effect controls
- [ ] Eyedropper tool for color picking
- [ ] Transform matrix direct editing
- [ ] Blend mode preview thumbnails
- [ ] Custom metadata panel
- [ ] History of recent color/stroke presets

## Related

- Layer Tree: `packages/app/lib/modules/layers/`
- Navigator: `packages/app/lib/modules/navigator/`
- FR-045: Inspector panel requirements
- Section 6.2: Component architecture specs
