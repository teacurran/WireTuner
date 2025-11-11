# Navigator Module

Multi-artboard document management UI for WireTuner.

## Features

- **Multi-Document Support**: Manage multiple open documents via tabs
- **Virtualized Grid**: Smooth performance with up to 1000 artboards
- **Live Thumbnails**: Auto-refreshing previews (10s interval + save trigger)
- **Multi-Select**: Cmd+Click, Shift+Click for batch operations
- **Context Menu**: Rename, duplicate, delete, refresh actions
- **Keyboard Shortcuts**: Arrow keys, Delete, Cmd+W
- **Responsive Layout**: Adapts grid columns to window width

## Architecture

### Component Hierarchy

```
NavigatorWindow
├── NavigatorTabs
│   └── _TabItem (per document)
└── ArtboardGrid
    └── ArtboardCard (virtualized)
        └── ArtboardContextMenu
```

### State Management

```
NavigatorProvider (ChangeNotifier)
├── Document tabs
├── Artboard cards
├── Selection state
├── Grid configuration
└── Viewport snapshots

NavigatorService
├── Action orchestration
├── Event emission
└── Telemetry tracking
```

## Usage

### Opening the Navigator

```dart
import 'package:app/modules/navigator/navigator.dart';

// Show Navigator window
showDialog(
  context: context,
  builder: (_) => NavigatorWindow(
    onClose: () => Navigator.of(context).pop(),
  ),
);
```

### Opening a Document

```dart
final provider = context.read<NavigatorProvider>();

provider.openDocument(DocumentTab(
  documentId: 'uuid',
  name: 'My Design.wire',
  path: '/path/to/file.wire',
  artboardIds: ['art1', 'art2', 'art3'],
));
```

### Handling Actions

```dart
final service = context.read<NavigatorService>();

service.actionStream.listen((event) {
  // Dispatch to EventStore
  eventStore.append(
    ArtboardEvent.fromAction(event),
  );
});
```

## Performance

### Virtualization

The grid uses `GridView.builder` to render only visible artboards:

```dart
GridView.builder(
  itemCount: 1000, // Total artboards
  itemBuilder: (context, index) {
    // Only builds visible cards
    return ArtboardCard(...);
  },
)
```

**Metrics**:
- 1000 artboards: ~20-40 cards rendered at once
- Memory: ~10-20 MB for visible cards
- Scroll FPS: 60 FPS on M1 Mac

### Thumbnail Management

Thumbnails use a hybrid refresh strategy:

1. **Timer-based**: 10-second periodic refresh for visible cards
2. **Event-based**: Immediate refresh on document save
3. **LRU Cache**: Limited cache size with automatic eviction

```dart
// Start auto-refresh
provider.startThumbnailRefresh(artboardId, () async {
  return await renderingPipeline.generateThumbnail(artboardId);
});

// Trigger immediate refresh (e.g., on save)
provider.refreshThumbnailNow(artboardId, generator);
```

## Testing

### Unit Tests

```bash
flutter test test/navigator/navigator_provider_test.dart
flutter test test/navigator/navigator_service_test.dart
```

**Coverage**:
- NavigatorProvider: Selection logic, tab management, viewport state
- NavigatorService: Action validation, event emission, telemetry

### Widget Tests

```bash
flutter test test/navigator/artboard_card_test.dart
flutter test test/navigator/artboard_grid_test.dart
```

**Coverage**:
- ArtboardCard: Rendering, editing, hover states
- ArtboardGrid: Virtualization, selection, responsive layout

### Integration Tests

```dart
testWidgets('handles 1000 artboards', (tester) async {
  final artboards = List.generate(1000, (i) => ArtboardCardState(...));

  await tester.pumpWidget(ArtboardGrid(artboards: artboards));

  // Verify virtualization
  expect(find.byType(ArtboardCard).evaluate().length, lessThan(50));

  // Verify scroll performance
  await tester.drag(find.byType(GridView), Offset(0, -1000));
  await tester.pumpAndSettle();

  expect(find.byType(ArtboardCard), findsWidgets);
});
```

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Click | Select artboard |
| Cmd/Ctrl+Click | Toggle selection |
| Shift+Click | Range selection |
| Delete/Backspace | Delete selected artboards |
| Cmd/Ctrl+W | Close active document tab |
| Arrow Keys | Navigate grid (future) |
| Enter | Rename selected artboard (future) |

## Context Menu Actions

| Action | Availability | Description |
|--------|-------------|-------------|
| Rename | Single selection | Inline text edit |
| Duplicate | Single/Multi | Clone artboard(s) |
| Delete | Single/Multi | Remove artboard(s) with confirmation |
| Refresh Thumbnail | Single | Force thumbnail regeneration |
| Fit to View | Single | Restore viewport from snapshot |
| Copy to Document | Disabled | Future feature |
| Export As | Disabled | Future feature |

## State Management Details

### NavigatorProvider

**Responsibilities**:
- Document tab lifecycle (open, close, switch)
- Artboard card state (metadata, thumbnails, visibility)
- Selection management (single, multi, range)
- Viewport snapshot persistence
- Thumbnail refresh scheduling

**Key Methods**:
```dart
void openDocument(DocumentTab tab)
void closeDocument(String documentId)
void selectArtboard(String artboardId)
void toggleArtboard(String artboardId)
void selectRange(String fromId, String toId)
void updateArtboard({...})
void saveViewportState(String artboardId, ViewportSnapshot snapshot)
```

### NavigatorService

**Responsibilities**:
- Action validation (name length, empty checks)
- Event emission to EventStore
- Telemetry tracking

**Key Methods**:
```dart
Future<String?> renameArtboard(String id, String name)
Future<String?> duplicateArtboards(List<String> ids)
Future<bool> deleteArtboards(List<String> ids, {confirmCallback})
void trackNavigatorOpenTime(Duration duration, int count)
void trackThumbnailLatency(String id, Duration duration)
```

## Integration Points

### EventStore

Navigator actions dispatch events via `NavigatorService.actionStream`:

```dart
service.actionStream.listen((event) {
  switch (event.action) {
    case ArtboardAction.rename:
      eventStore.append(ArtboardRenamed(
        artboardId: event.artboardIds.first,
        newName: event.metadata['newName'],
      ));
      break;
    // ... other actions
  }
});
```

### RenderingPipeline

Thumbnail generation integrates with the rendering pipeline:

```dart
provider.startThumbnailRefresh(artboardId, () async {
  return await renderingPipeline.renderArtboardThumbnail(
    artboardId: artboardId,
    width: 200,
    height: 200,
    quality: ThumbnailQuality.medium,
  );
});
```

### SettingsService

Viewport state persists via SettingsService:

```dart
// Save on tab switch
final snapshot = viewportController.createSnapshot(artboardId);
provider.saveViewportState(artboardId, snapshot);
settingsService.saveViewport(artboardId, snapshot);

// Restore on document load
final snapshot = await settingsService.loadViewport(artboardId);
if (snapshot != null) {
  viewportController.restoreSnapshot(snapshot);
}
```

### TelemetryService

Performance metrics track Navigator operations:

```dart
service.trackNavigatorOpenTime(loadDuration, artboardCount);
service.trackThumbnailLatency(artboardId, renderDuration);
service.trackVirtualizationMetrics(
  totalArtboards: 1000,
  visibleArtboards: 25,
  scrollFps: 60.0,
);
```

## Future Enhancements

- [ ] Drag-reorder artboards with drop indicators
- [ ] Artboard search/filter bar
- [ ] Grid zoom controls (thumbnail size adjustment)
- [ ] Copy artboards between documents
- [ ] Export queue integration
- [ ] Artboard grouping/folders
- [ ] Custom sort orders (name, date, size)
- [ ] Thumbnail quality settings
- [ ] Multi-window support via WindowManager
- [ ] Collaborative presence indicators

## Related Documentation

- **Architecture**: `.codemachine/artifacts/architecture/06_UI_UX_Architecture.md`
- **Flow C**: Multi-Artboard Document Load and Navigator Activation
- **Journey H**: Manage Artboards in Navigator
- **FR-029–FR-044**: Navigator functional requirements
- **Task I3.T3**: Navigator Window UI Mandate

## License

Part of WireTuner - proprietary software.
