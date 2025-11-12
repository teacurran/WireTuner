# App Shell - Window Lifecycle Management

This module implements window lifecycle management for WireTuner's multi-window application architecture.

## Overview

The app shell provides:
- **Window Management**: Central registry for all windows (Navigator, artboard, inspector)
- **Lifecycle Hooks**: Open, close, focus, blur events
- **State Persistence**: Per-artboard viewport state across sessions
- **Close Confirmation**: Navigator-level prompts per FR-040
- **Platform Integration**: Hooks for macOS/Windows file browser thumbnails

## Architecture

```
┌──────────────────┐
│  WindowManager   │  Central registry & lifecycle coordinator
└────────┬─────────┘
         │
         ├─────────────────────────────────────┐
         │                                     │
┌────────▼────────┐              ┌─────────────▼──────────┐
│ NavigatorRoot   │              │   ArtboardWindow       │
│  (root window)  │              │  (editing window)      │
└────────┬────────┘              └─────────────┬──────────┘
         │                                     │
         │ Wraps                               │ Wraps
         ▼                                     ▼
┌──────────────────┐              ┌─────────────────────────┐
│ NavigatorWindow  │              │   WireTunerCanvas       │
│ (grid UI)        │              │   (rendering)           │
└──────────────────┘              └─────────────────────────┘
```

## Core Components

### WindowManager

Central coordinator that tracks all open windows and manages lifecycle events.

**Responsibilities**:
- Register/unregister windows
- Track focus state
- Persist viewport state
- Handle close confirmations
- Emit lifecycle events

**Usage**:
```dart
final manager = WindowManager(
  onPersistViewportState: (docId, artId, viewport) async {
    await repo.saveViewportState(
      documentId: docId,
      artboardId: artId,
      viewport: viewport,
    );
  },
  onConfirmClose: (docId) async {
    return await showNavigatorCloseConfirmation(
      context,
      documentName,
      artboardCount,
    );
  },
);

// Provide to widget tree
Provider.value(
  value: manager,
  child: MaterialApp(...),
)
```

### WindowDescriptor

Immutable snapshot of a window's metadata.

**Fields**:
- `windowId`: Unique identifier (e.g., `art-doc1-art2`)
- `type`: WindowType (navigator, artboard, inspector)
- `documentId`: Parent document
- `artboardId`: Associated artboard (null for Navigator)
- `lastViewportState`: ViewportSnapshot for restoration
- `isDirty`: Has unsaved changes
- `createdAt`, `lastFocusTime`: Timestamps

### NavigatorRoot

Root window wrapper that integrates NavigatorWindow with WindowManager.

**Features**:
- Auto-registers on mount
- Shows close confirmation dialog
- Closes all artboard windows on confirm
- Unregisters on unmount

**Usage**:
```dart
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => NavigatorRoot(
      documentId: 'doc123',
      documentName: 'website-design.wiretuner',
    ),
  ),
);
```

### ArtboardWindow

Artboard editing window wrapper.

**Features**:
- Auto-registers on mount
- Restores initial viewport state
- Tracks viewport changes and persists on blur
- Silent close (no confirmation)
- Keyboard shortcuts (Cmd+W to close)

**Usage**:
```dart
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => ArtboardWindow(
      documentId: 'doc123',
      artboardId: 'art456',
      documentName: 'website-design.wiretuner',
      artboardName: 'Homepage 1920x1080',
      initialViewportState: await repo.loadViewportState(
        documentId: 'doc123',
        artboardId: 'art456',
      ),
    ),
  ),
);
```

### WindowStateRepository

Persistence layer for viewport state using SharedPreferences.

**Operations**:
- `saveViewportState()`: Persist viewport on blur/close
- `loadViewportState()`: Restore viewport on open
- `clearDocumentState()`: Remove all state for a document

**Storage Keys**:
- Viewport: `window_viewport_{documentId}_{artboardId}`
- Focus order: `window_focus_order`

**Usage**:
```dart
final repo = WindowStateRepository();

// Save
await repo.saveViewportState(
  documentId: 'doc1',
  artboardId: 'art1',
  viewport: ViewportSnapshot(panOffset: Offset(100, 50), zoom: 1.5),
);

// Load
final viewport = await repo.loadViewportState(
  documentId: 'doc1',
  artboardId: 'art1',
);
```

## Lifecycle Events

WindowManager emits events for:
- `opened`: Window registered
- `focused`: Window gained focus
- `blurred`: Window lost focus
- `closed`: Window unregistered

**Listen to events**:
```dart
manager.events.listen((event) {
  print('${event.type}: ${event.descriptor.windowId}');

  if (event.type == WindowLifecycleEventType.closed) {
    // Update UI, clean up resources, etc.
  }
});
```

## Journey Mappings

### Journey 10: Open Document with Multiple Artboards
- Navigator auto-opens when multi-artboard doc loads
- Clicking thumbnail calls `WindowManager.openArtboardWindow()`
- Each artboard gets independent window with isolated state

### Journey 12: Manage Multiple Open Documents
- Navigator tabs managed by NavigatorWindow
- Each document has separate WindowManager entries
- Closing Navigator prompts: "Close all artboards for [doc]?"

### Journey 15: Per-Artboard Viewport State Persistence
- `ArtboardWindow` tracks viewport changes via `ViewportController.addListener()`
- On blur/close: `WindowManager.updateWindow()` + `onPersistViewportState()`
- On reopen: `WindowStateRepository.loadViewportState()` → `initialViewportState`

### Journey 16: Per-Artboard Selection Isolation
- Each `ArtboardWindow` has its own `ViewportController` instance
- Selection state lives in document model, scoped by artboardId
- Switching windows preserves selection per artboard

### Journey 18: Artboard Window Lifecycle
- Artboard close: `WindowManager.requestCloseArtboard()` → silent, no prompt
- Navigator close: `WindowManager.requestCloseNavigator()` → shows confirmation
- Confirmation shows artboard count from `getArtboardWindowsForDocument()`
- On confirm: `WindowManager.closeDocument()` unregisters all windows

## Testing

Run tests with:
```bash
cd packages/app
flutter test test/window_manager_test.dart
```

Tests cover:
- Window registration and unregistration
- Focus/blur events and viewport persistence
- Close confirmation logic
- Multi-document scenarios
- Journey 15/18 workflows

## Integration Example

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Create window state repository
  final windowRepo = WindowStateRepository();

  // Create window manager
  final windowManager = WindowManager(
    onPersistViewportState: (docId, artId, viewport) async {
      await windowRepo.saveViewportState(
        documentId: docId,
        artboardId: artId,
        viewport: viewport,
      );
    },
    onConfirmClose: (docId) async {
      // Show dialog in app context
      final navigatorKey = GlobalKey<NavigatorState>();
      final context = navigatorKey.currentContext!;
      final manager = context.read<WindowManager>();
      final artboardCount = manager.getArtboardWindowsForDocument(docId).length;

      return await showNavigatorCloseConfirmation(
        context,
        docId, // Use document name from provider
        artboardCount,
      );
    },
  );

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: windowManager),
        Provider.value(value: windowRepo),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => _openDocument(context),
            child: Text('Open Document'),
          ),
        ),
      ),
    );
  }

  void _openDocument(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NavigatorRoot(
          documentId: 'doc1',
          documentName: 'example.wiretuner',
        ),
      ),
    );
  }
}
```

## Related Files

- `window_manager.dart`: Core window lifecycle coordinator
- `window_descriptor.dart`: Window metadata model
- `navigator_root.dart`: Navigator window wrapper
- `artboard_window.dart`: Artboard editing window wrapper
- `window_state_repository.dart`: Persistence layer
- `../test/window_manager_test.dart`: Comprehensive tests

## FR/Journey References

- **FR-040**: Artboard Window Lifecycle
- **FR-047**: macOS Platform Integration (QuickLook)
- **FR-048**: Windows Platform Integration (Explorer)
- **Journey 10**: Open Document with Multiple Artboards
- **Journey 12**: Manage Multiple Open Documents
- **Journey 15**: Per-Artboard Viewport State Persistence
- **Journey 16**: Per-Artboard Selection Isolation
- **Journey 18**: Artboard Window Lifecycle
