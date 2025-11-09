# History Panel

The History Panel provides a visual timeline of document operations with thumbnails, search, and interactive scrubbing capabilities.

## Overview

The history panel displays all completed operations in chronological order, allowing users to:
- View past and future operations in a unified timeline
- Navigate to any point in history by clicking
- Search/filter operations by label
- Preview document state with thumbnails
- Scrub through history with playback controls

## Architecture

### Components

1. **HistoryPanel** (`lib/presentation/history/history_panel.dart`)
   - Main panel widget with operation list
   - Search/filter UI
   - Lazy loading ListView
   - Empty state handling

2. **HistoryScrubber** (`lib/presentation/history/history_scrubber.dart`)
   - Timeline slider for scrubbing
   - Playback controls (play/pause, step forward/backward)
   - Speed control (0.5×, 1.0×, 2.0×, 5.0×)
   - Current position indicator

3. **HistoryViewModel** (`lib/presentation/history/history_view_model.dart`)
   - Combines undo/redo stacks into unified timeline
   - Handles search filtering
   - Provides current position tracking

4. **ThumbnailGenerator** (`lib/presentation/history/thumbnail_generator.dart`)
   - Offscreen rendering using `ui.PictureRecorder`
   - LRU caching (default 50 thumbnails)
   - Automatic fit-to-viewport scaling

### Integration

The history panel integrates with:
- **UndoProvider** (app_shell): Provides undo/redo stacks and navigation
- **DocumentProvider**: Supplies current document state for thumbnails
- **UndoNavigator** (event_core): Handles scrubbing and time-travel

## Usage

### Basic Setup

The history panel is automatically included in the `EditorShell`:

```dart
// Already integrated in lib/presentation/shell/editor_shell.dart
return Scaffold(
  body: Column(
    children: [
      Expanded(
        child: Row(
          children: [
            const ToolToolbar(),      // Left: tools
            Expanded(child: canvas),  // Center: canvas
            const HistoryPanel(),     // Right: history
          ],
        ),
      ),
      const HistoryScrubber(),        // Bottom: scrubber
    ],
  ),
);
```

### Searching Operations

Users can filter operations by typing in the search field:

```
┌─────────────────────────────┐
│ History              [🔍]   │
├─────────────────────────────┤
│ [Search: "move"]            │
│ ► [thumb] Move Objects      │ ← Matches
│ [thumb] Move Anchor         │ ← Matches
└─────────────────────────────┘
```

### Scrubbing

Click any operation in the list or drag the scrubber slider to navigate:

```dart
// Handled internally by HistoryPanel
onTap: () => undoProvider.handleScrubToGroup(entry.group)

// Throttled to 60 FPS (16.7ms) for smooth scrubbing
```

### Playback

Use the scrubber controls for automated playback:

1. **Step Backward** (◄): `undoProvider.handleUndo()`
2. **Play/Pause** (▶/⏸): Automated forward stepping
3. **Step Forward** (►): `undoProvider.handleRedo()`
4. **Speed Control** (⚡): Adjust playback rate

## Performance

### Targets

- **Lazy Loading**: ListView.builder renders only visible items
- **Thumbnail Caching**: LRU cache (50 items) prevents redundant rendering
- **Scrubbing**: Throttled to 60 FPS (16.7ms) to meet 5k events/sec target
- **Search**: Debounced at 300ms (not yet implemented, immediate for now)

### Thumbnail Generation

Thumbnails are rendered offscreen using Flutter's `dart:ui`:

```dart
final recorder = ui.PictureRecorder();
final canvas = Canvas(recorder);

// Render document using DocumentPainter
final painter = DocumentPainter(paths: document.paths, ...);
painter.paint(canvas, Size(120, 80));

// Convert to image
final picture = recorder.endRecording();
final image = await picture.toImage(120, 80);
```

Thumbnails are:
- **120×80 pixels** (configurable)
- **Cached by groupId** (LRU eviction)
- **Rendered asynchronously** (FutureBuilder)
- **Invalidated** when document changes

## Testing

Widget tests verify:

1. **Empty State**: Shows "No History" when timeline is empty
2. **Search UI**: Search field renders in header
3. **Footer Stats**: Displays operation count
4. **Scrubber Visibility**: Hidden when history is empty

Run tests:

```bash
flutter test test/widget/history_panel_test.dart
```

## Future Enhancements

1. **Search Debouncing**: Add 300ms debounce to search input
2. **Keyboard Navigation**: Arrow keys to step through timeline
3. **Thumbnail Background Rendering**: Move to isolate for heavy documents
4. **Virtual Scrolling**: Optimize for 1000+ operation timelines
5. **Diff Visualization**: Show changed objects between operations
6. **Timeline Grouping**: Collapse related operations (e.g., drag sessions)

## Related Documentation

- [Undo Labels](../reference/undo_labels.md): Operation labeling guidelines
- [Event Replay](../api/event_replay_navigation.md): Navigator performance targets
- [ADR-001](../adr/ADR-001-hybrid-state-history.md): Event sampling rationale
- [Task I4.T4](../../docs/plan/iteration_4.md): Implementation task details

## API Reference

### HistoryPanel

```dart
class HistoryPanel extends StatefulWidget {
  const HistoryPanel({
    this.width = 250.0,  // Fixed panel width
    super.key,
  });
}
```

### HistoryScrubber

```dart
class HistoryScrubber extends StatefulWidget {
  const HistoryScrubber({super.key});
}
```

### ThumbnailGenerator

```dart
class ThumbnailGenerator {
  ThumbnailGenerator({
    int cacheSize = 50,
    this.thumbnailWidth = 120,
    this.thumbnailHeight = 80,
  });

  Future<ui.Image?> generate({
    required String groupId,
    required Document document,
    Color backgroundColor = Colors.white,
  });

  void invalidateCache();
  void invalidate(String groupId);
}
```

### HistoryViewModel

```dart
class HistoryViewModel {
  HistoryViewModel({
    required List<OperationGroup> undoStack,
    required List<OperationGroup> redoStack,
    String? searchQuery,
  });

  List<HistoryEntry> get timeline;
  int get currentIndex;
  bool get isEmpty;
  int get totalOperations;
}
```
