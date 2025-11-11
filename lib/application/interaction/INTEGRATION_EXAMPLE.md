# Integration Example: Auto-Save & Manual Save

This example demonstrates how to integrate the auto-save and manual save components into your application.

## Complete Integration Example

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:event_core/event_core.dart';
import 'package:io_services/io_services.dart';
import 'package:wiretuner/application/interaction/auto_save_manager.dart';
import 'package:wiretuner/application/interaction/manual_save_use_case.dart';
import 'package:wiretuner/presentation/widgets/save_status_indicator.dart';

/// Example document editor with auto-save and manual save.
class DocumentEditorWithAutoSave extends StatefulWidget {
  const DocumentEditorWithAutoSave({super.key});

  @override
  State<DocumentEditorWithAutoSave> createState() =>
      _DocumentEditorWithAutoSaveState();
}

class _DocumentEditorWithAutoSaveState
    extends State<DocumentEditorWithAutoSave> {
  late final AutoSaveManager _autoSaveManager;
  late final ManualSaveUseCase _manualSaveUseCase;
  late final SaveStatusController _statusController;

  // Dependencies (normally injected via DI)
  late final EventStoreGateway _eventGateway;
  late final SaveService _saveService;
  late final SnapshotManager _snapshotManager;

  String _documentId = 'doc-example';
  Map<String, dynamic> _documentState = {};

  @override
  void initState() {
    super.initState();

    // Initialize dependencies
    _eventGateway = context.read<EventStoreGateway>();
    _saveService = context.read<SaveService>();
    _snapshotManager = context.read<SnapshotManager>();

    // Initialize status controller
    _statusController = SaveStatusController();

    // Initialize auto-save manager
    _autoSaveManager = AutoSaveManager(
      eventGateway: _eventGateway,
      documentId: _documentId,
      idleThresholdMs: 200, // 200ms debounce
      onStatusUpdate: ({
        required status,
        required message,
        eventCount,
      }) {
        // Update UI status indicator
        if (status == AutoSaveStatus.saved) {
          _statusController.showAutoSaved(eventCount: eventCount);
        } else if (status == AutoSaveStatus.failed) {
          _statusController.showError(message);
        }
      },
    );

    // Initialize manual save use case
    _manualSaveUseCase = ManualSaveUseCase(
      autoSaveManager: _autoSaveManager,
      saveService: _saveService,
      eventGateway: _eventGateway,
      snapshotManager: _snapshotManager,
      documentId: _documentId,
      logger: Logger(),
    );
  }

  @override
  void dispose() {
    _autoSaveManager.dispose();
    super.dispose();
  }

  /// Called when user edits the document.
  void _onDocumentEdit(Map<String, dynamic> newState) {
    setState(() {
      _documentState = newState;
    });

    // Trigger auto-save timer
    _autoSaveManager.onEventRecorded();
  }

  /// Called when user presses Cmd/Ctrl+S.
  Future<void> _handleManualSave() async {
    final result = await _manualSaveUseCase.execute(
      documentState: _documentState,
      title: 'My Document',
    );

    if (result is ManualSaveSuccess) {
      // Success - show status and update window title
      _statusController.showSaved(
        snapshotCreated: result.snapshotCreated,
      );

      // Update window title to remove dirty indicator
      _updateWindowTitle(isDirty: false);
    } else if (result is ManualSaveSkipped) {
      // No changes - show informational message
      _statusController.showNoChanges();
    } else if (result is ManualSaveFailure) {
      // Error - show error dialog
      _showErrorDialog(result.message);
    }
  }

  void _updateWindowTitle({required bool isDirty}) {
    // Update window title with or without "*" indicator
    final title = isDirty ? '* My Document' : 'My Document';
    // Platform-specific window title update
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Editor'),
        actions: [
          // Save status indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SaveStatusIndicator(
              controller: _statusController,
            ),
          ),
        ],
      ),
      body: Shortcuts(
        shortcuts: {
          // Cmd/Ctrl+S for manual save
          LogicalKeySet(
            Platform.isMacOS
                ? LogicalKeyboardKey.meta
                : LogicalKeyboardKey.control,
            LogicalKeyboardKey.keyS,
          ): const SaveIntent(),
        },
        child: Actions(
          actions: {
            SaveIntent: CallbackAction<SaveIntent>(
              onInvoke: (_) {
                _handleManualSave();
                return null;
              },
            ),
          },
          child: Focus(
            autofocus: true,
            child: DocumentCanvas(
              documentState: _documentState,
              onEdit: _onDocumentEdit,
            ),
          ),
        ),
      ),
    );
  }
}

/// Intent for save shortcut.
class SaveIntent extends Intent {
  const SaveIntent();
}

/// Placeholder for document canvas.
class DocumentCanvas extends StatelessWidget {
  const DocumentCanvas({
    super.key,
    required this.documentState,
    required this.onEdit,
  });

  final Map<String, dynamic> documentState;
  final ValueChanged<Map<String, dynamic>> onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Document State: ${documentState.length} items'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Simulate edit
                final newState = Map<String, dynamic>.from(documentState);
                newState['edit_${DateTime.now().millisecondsSinceEpoch}'] =
                    'value';
                onEdit(newState);
              },
              child: const Text('Simulate Edit'),
            ),
          ],
        ),
      ),
    );
  }
}
```

## Step-by-Step Integration

### 1. Set Up Dependencies

Add required packages to `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.0.0
  logger: ^2.0.0
  event_core:
    path: packages/event_core
  io_services:
    path: packages/io_services
```

### 2. Initialize Auto-Save Manager

```dart
// In initState or dependency injection setup
final autoSaveManager = AutoSaveManager(
  eventGateway: eventStoreGateway,
  documentId: currentDocument.id,
  idleThresholdMs: 200,
  onStatusUpdate: ({
    required status,
    required message,
    eventCount,
  }) {
    // Handle status updates
    statusController.updateStatus(status, message);
  },
);
```

### 3. Wire Up Event Recording

```dart
// When an event is recorded
void recordEvent(EventBase event) {
  // Persist event via gateway
  await eventGateway.persistEvent(event.toJson());

  // Trigger auto-save timer
  autoSaveManager.onEventRecorded();

  // Update window title to show dirty state
  updateWindowTitle(isDirty: true);
}
```

### 4. Implement Manual Save Handler

```dart
// Create use case
final manualSaveUseCase = ManualSaveUseCase(
  autoSaveManager: autoSaveManager,
  saveService: saveService,
  eventGateway: eventGateway,
  snapshotManager: snapshotManager,
  documentId: currentDocument.id,
  logger: logger,
);

// Handle Cmd/Ctrl+S
Future<void> onSaveShortcut() async {
  final result = await manualSaveUseCase.execute(
    documentState: documentProvider.toJson(),
    title: currentDocument.title,
  );

  // Handle result...
}
```

### 5. Add Status Indicator to UI

```dart
// In your app bar or status bar
Row(
  children: [
    Text(document.title),
    const Spacer(),
    SaveStatusIndicator(
      controller: statusController,
    ),
  ],
)
```

### 6. Register Keyboard Shortcut

```dart
Shortcuts(
  shortcuts: {
    LogicalKeySet(
      Platform.isMacOS
          ? LogicalKeyboardKey.meta
          : LogicalKeyboardKey.control,
      LogicalKeyboardKey.keyS,
    ): const SaveIntent(),
  },
  child: Actions(
    actions: {
      SaveIntent: CallbackAction<SaveIntent>(
        onInvoke: (_) {
          onSaveShortcut();
          return null;
        },
      ),
    },
    child: yourWidget,
  ),
)
```

## Testing Integration

### Unit Test Example

```dart
void main() {
  testWidgets('manual save triggers after edits', (tester) async {
    // Setup
    final autoSaveManager = AutoSaveManager(/*...*/);
    final manualSaveUseCase = ManualSaveUseCase(/*...*/);

    await tester.pumpWidget(
      DocumentEditorWithAutoSave(
        autoSaveManager: autoSaveManager,
        manualSaveUseCase: manualSaveUseCase,
      ),
    );

    // Simulate edit
    await tester.tap(find.text('Simulate Edit'));
    await tester.pump();

    // Wait for auto-save debounce
    await tester.pump(const Duration(milliseconds: 250));

    // Verify auto-save status shown
    expect(find.text('Auto-saved'), findsOneWidget);

    // Trigger manual save
    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.pump();

    // Verify manual save status shown
    expect(find.text('Saved'), findsOneWidget);
  });
}
```

## Common Patterns

### Pattern 1: Dirty State Tracking

```dart
class DocumentDirtyTracker {
  bool _isDirty = false;

  void markDirty() {
    _isDirty = true;
    updateWindowTitle();
  }

  void markClean() {
    _isDirty = false;
    updateWindowTitle();
  }

  void updateWindowTitle() {
    final title = _isDirty ? '* ${document.title}' : document.title;
    windowTitleService.setTitle(title);
  }
}

// Usage
void onEventRecorded() {
  autoSaveManager.onEventRecorded();
  dirtyTracker.markDirty();
}

void onManualSaveSuccess() {
  dirtyTracker.markClean();
}
```

### Pattern 2: Debounced Status Updates

```dart
class DebouncedStatusController extends SaveStatusController {
  Timer? _clearTimer;

  @override
  void showAutoSaved({int? eventCount}) {
    super.showAutoSaved(eventCount: eventCount);

    // Auto-clear after 1 second
    _clearTimer?.cancel();
    _clearTimer = Timer(const Duration(seconds: 1), clear);
  }
}
```

### Pattern 3: Error Recovery

```dart
Future<void> handleManualSaveWithRetry() async {
  const maxRetries = 3;
  int attempt = 0;

  while (attempt < maxRetries) {
    final result = await manualSaveUseCase.execute(
      documentState: documentState,
      title: documentTitle,
    );

    if (result is ManualSaveSuccess) {
      return; // Success
    } else if (result is ManualSaveFailure) {
      attempt++;
      if (attempt >= maxRetries) {
        showErrorDialog(result.message);
        return;
      }
      // Wait before retry
      await Future.delayed(Duration(seconds: attempt));
    } else {
      return; // Skipped, no retry needed
    }
  }
}
```

## Troubleshooting Integration

### Issue: Auto-save not triggering

**Check:**
1. `onEventRecorded()` is being called after edits
2. Timer is not disposed prematurely
3. Event gateway is functioning

**Debug:**
```dart
autoSaveManager = AutoSaveManager(
  // ...
  onStatusUpdate: ({required status, required message, eventCount}) {
    print('Auto-save status: $status - $message');
  },
);
```

### Issue: Manual save always skips

**Check:**
1. Sequence numbers are incrementing
2. Auto-save flush is completing
3. Event recording is working

**Debug:**
```dart
final currentSeq = await eventGateway.getLatestSequenceNumber();
final lastManual = autoSaveManager.lastManualSaveSequence;
print('Current: $currentSeq, Last manual: $lastManual');
```

### Issue: Status indicator not showing

**Check:**
1. `SaveStatusController` is in widget tree
2. Callbacks are wired correctly
3. Widget is rebuilding

**Debug:**
```dart
statusController.addListener(() {
  print('Status changed: ${statusController.status}');
});
```

## Best Practices

1. **Always dispose:** Call `autoSaveManager.dispose()` in widget dispose
2. **Flush before close:** Flush auto-save before closing documents
3. **Handle errors:** Show user-friendly error messages for save failures
4. **Track dirty state:** Update window title to reflect unsaved changes
5. **Test debounce:** Verify 200ms threshold prevents excessive saves
6. **Monitor telemetry:** Track auto-save frequency and manual save patterns
