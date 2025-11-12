# Layers Module

The Layers module provides a hierarchical layer tree UI for managing object z-order, visibility, and locking in WireTuner artboards. It supports virtualization for 100+ layers, inline rename, multi-select, and keyboard navigation.

## Architecture

```
layers/
├── state/
│   └── layer_tree_provider.dart   # State management (ChangeNotifier)
├── widgets/
│   └── layer_tree.dart            # Virtualized tree widget
└── README.md
```

## Key Features

### Hierarchical Tree

- Nested groups with expand/collapse
- Depth-based indentation
- Parent-child relationships
- Mask and clipping indicators

### Virtualization

- Efficient rendering for 100+ layers
- `ListView.builder` with fixed item extent (32px)
- Flattened list respects expansion state
- Lazy tree traversal

### Inline Editing

- Double-click to rename (respects lock state)
- Escape to cancel, Enter to commit
- Focus management for accessibility

### Visibility & Lock Toggles

- Per-layer visibility toggle (eye icon)
- Per-layer lock toggle (lock icon)
- Visual feedback (icon color/opacity)
- Locked layers prevent rename and editing

### Multi-Select

- Click to select single layer
- Cmd/Ctrl+Click to toggle selection
- Shift+Click for range selection
- Visual selection highlight

### Keyboard Navigation

- **Cmd/Ctrl+]**: Move layer forward
- **Cmd/Ctrl+Shift+]**: Move layer to front
- **Cmd/Ctrl+[**: Move layer backward
- **Cmd/Ctrl+Shift+[**: Move layer to back
- **Delete/Backspace**: Remove selected layers

### Search & Filter

- Case-insensitive layer name search
- Filter text updates flattened list
- Clear filter shows all layers

## Usage

### Basic Setup

```dart
import 'package:app/modules/layers/widgets/layer_tree.dart';
import 'package:app/modules/layers/state/layer_tree_provider.dart';

// Create provider with command dispatcher
final layerProvider = LayerTreeProvider(
  commandDispatcher: (cmd, data) {
    // Wire to domain layer
    eventStore.dispatch(cmd, data);
  },
);

// Provide to widget tree
ChangeNotifierProvider.value(
  value: layerProvider,
  child: LayerTree(),
)
```

### Loading Layers

```dart
final provider = context.read<LayerTreeProvider>();

// Load flat list
provider.loadLayers([
  LayerNode(
    layerId: 'layer1',
    name: 'Background',
    type: 'Rectangle',
    isVisible: true,
    isLocked: true,
  ),
  LayerNode(
    layerId: 'layer2',
    name: 'Logo',
    type: 'Path',
  ),
]);

// Load nested groups
provider.loadLayers([
  LayerNode(
    layerId: 'group1',
    name: 'Group 1',
    type: 'Group',
    isExpanded: true,
    children: [
      LayerNode(
        layerId: 'child1',
        name: 'Child Layer',
        type: 'Rectangle',
        depth: 1,
      ),
    ],
  ),
]);
```

### Layer Operations

```dart
// Rename
provider.renameLayer('layer1', 'New Name');

// Toggle visibility
provider.toggleVisibility('layer1');

// Toggle lock
provider.toggleLock('layer1');

// Toggle group expansion
provider.toggleExpansion('group1');

// Selection
provider.selectLayer('layer1');
provider.toggleLayerSelection('layer2'); // Multi-select
provider.selectRange('layer1', 'layer3'); // Range select
provider.clearSelection();

// Reorder
provider.moveLayerUp('layer1');
provider.moveLayerDown('layer1');
provider.moveLayerToFront('layer1');
provider.moveLayerToBack('layer1');

// Search
provider.setFilterText('logo');
```

### Adding/Removing Layers

```dart
// Add to root
provider.addLayer(
  LayerNode(layerId: 'new1', name: 'New Layer', type: 'Rectangle'),
);

// Add to group
provider.addLayer(
  LayerNode(layerId: 'new2', name: 'Child Layer', type: 'Rectangle'),
  parentId: 'group1',
);

// Remove
provider.removeLayer('layer1');
```

## Data Model

### LayerNode

Immutable layer node structure:

```dart
class LayerNode {
  final String layerId;
  final String name;
  final String type;          // 'Rectangle', 'Path', 'Group', 'Mask'
  final bool isVisible;
  final bool isLocked;
  final bool isSelected;
  final bool isMask;
  final bool isClipping;
  final List<LayerNode> children;
  final int depth;
  final bool isExpanded;
}
```

### FlattenedLayerNode

Virtualization-friendly flat structure:

```dart
class FlattenedLayerNode {
  final LayerNode node;
  final int flatIndex;
  final bool hasChildren;
  final bool isLastChild;
}
```

## Integration Points

### InteractionEngine

The Layer Tree integrates with InteractionEngine for:
- Selection sync (canvas ↔ layer tree)
- Layer reorder commands
- Visibility/lock state updates

### EventStore

Layer operations dispatch commands:
- `selectLayer`: Update selection
- `addLayer`: Create new layer
- `removeLayer`: Delete layer
- `renameLayer`: Rename layer
- `toggleLayerVisibility`: Show/hide layer
- `toggleLayerLock`: Lock/unlock layer
- `moveLayerUp/Down/ToFront/ToBack`: Reorder z-index

### TelemetryService

The Layer Tree emits telemetry (future):
- Layer count metrics
- Scroll performance (FPS)
- Interaction frequency

## Accessibility

All features include:
- Semantic labels for each layer row
- `aria-selected` for selected layers
- Button roles for visibility/lock toggles
- Keyboard navigation support
- Screen reader announcements for state changes

## Performance

### Virtualization

- Uses `ListView.builder` for lazy rendering
- Fixed item extent (32px) for optimal performance
- Flattened cache invalidation only on structure change
- Handles 100+ layers with 60fps scroll

### Optimization Tips

- Keep depth levels ≤ 5 for best UX
- Limit filter queries to debounced user input
- Batch selection updates where possible

## Testing

See `test/layers/`:
- `layer_tree_provider_test.dart`: State management tests
- Rename/lock toggle tests
- Virtualization tests (100+ layers)
- Multi-select and range select tests
- Filter search tests

## Design Tokens

The Layer Tree uses:
- `spacing.spacing6`: Dense row height (24px + 8px padding = 32px)
- `surface.raised`: Panel background (#141920)
- Icon sizing: 14-20px for visibility/lock/expand icons

## Future Enhancements

- [ ] Drag-and-drop reordering with drop indicators
- [ ] Context menu (right-click)
- [ ] Layer thumbnail previews
- [ ] Group color coding
- [ ] Bulk operations (lock all, show all)
- [ ] Layer styles/presets
- [ ] Smart grouping suggestions

## Related

- Inspector: `packages/app/lib/modules/inspector/`
- Navigator: `packages/app/lib/modules/navigator/`
- FR-045: Layer panel requirements
- Section 6.2: LayerTree component spec
