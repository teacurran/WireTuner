# Auto-Save & Manual Save Implementation

This module implements the auto-save and manual save strategy defined in Section 7.12 of the WireTuner architecture specification.

## Overview

The implementation provides:

- **Continuous Auto-Save**: Automatic persistence of events after 200ms idle time
- **Manual Save Checkpoints**: User-initiated saves with `document.saved` event markers
- **Deduplication**: Prevents redundant saves when no changes exist
- **Status Feedback**: UI-friendly status indicators for save operations

## Architecture

### Components

```
┌─────────────────────────────────────────────────────────┐
│                    User Interface                       │
│  (Cmd/Ctrl+S, Status Indicator, Window Title)           │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│              ManualSaveUseCase                          │
│  • Coordinates manual saves                             │
│  • Enforces deduplication                               │
│  • Records document.saved events                        │
└─────────────────────────────────────────────────────────┘
                            │
              ┌─────────────┴─────────────┐
              ▼                           ▼
┌───────────────────────┐   ┌──────────────────────────┐
│  AutoSaveManager      │   │     SaveService          │
│  • 200ms debounce     │   │  • SQLite persistence    │
│  • Dedup detection    │   │  • Snapshot creation     │
│  • Status callbacks   │   │  • Metadata updates      │
└───────────────────────┘   └──────────────────────────┘
              │                           │
              └─────────────┬─────────────┘
                            ▼
              ┌──────────────────────────┐
              │   EventStoreGateway      │
              │  • Event persistence     │
              │  • Sequence tracking     │
              └──────────────────────────┘
```

### Key Classes

#### `AutoSaveManager`
**Location:** `lib/application/interaction/auto_save_manager.dart`

Manages automatic persistence with debounce logic.

**Responsibilities:**
- Triggers auto-save after 200ms idle time
- Resets timer on every event (debounce behavior)
- Tracks last auto-saved sequence for deduplication
- Provides status callbacks for UI feedback
- Coordinates with manual saves via flush mechanism

**Key Methods:**
- `onEventRecorded()`: Triggers auto-save timer
- `flushPendingAutoSave()`: Forces immediate save (used before manual saves)
- `hasChangesSinceLastManualSave(sequence)`: Deduplication check
- `recordManualSave(sequence)`: Updates manual save marker

#### `ManualSaveUseCase`
**Location:** `lib/application/interaction/manual_save_use_case.dart`

Orchestrates manual save workflow with deduplication.

**Workflow:**
1. Flush pending auto-save to ensure all events persisted
2. Compare current sequence with last manual save sequence
3. Skip if no changes (deduplication)
4. Record `document.saved` event if changes exist
5. Delegate to `SaveService` for persistence
6. Trigger snapshot creation if threshold reached
7. Update UI with status

**Returns:**
- `ManualSaveSuccess`: Save completed with new checkpoint
- `ManualSaveSkipped`: No changes detected (deduplication)
- `ManualSaveFailure`: Error occurred during save

#### `SaveStatusIndicator`
**Location:** `lib/presentation/widgets/save_status_indicator.dart`

UI widget for displaying save status messages.

**Features:**
- Auto-save: Subtle gray indicator, 1 second duration
- Manual save: Prominent green indicator, 2 seconds duration
- No changes: Blue info indicator, 2 seconds duration
- Errors: Red error indicator, persistent until dismissed
- WCAG-compliant colors and contrast ratios

## Usage

### Setting Up Auto-Save

```dart
// 1. Create AutoSaveManager
final autoSaveManager = AutoSaveManager(
  eventGateway: eventStoreGateway,
  documentId: document.id,
  idleThresholdMs: 200,
  onStatusUpdate: ({required status, required message, eventCount}) {
    statusController.show(status, message);
  },
);

// 2. Wire event recording
eventRecorder.onEventRecorded = () {
  autoSaveManager.onEventRecorded();
};
```

### Implementing Manual Save

```dart
// 1. Create ManualSaveUseCase
final manualSaveUseCase = ManualSaveUseCase(
  autoSaveManager: autoSaveManager,
  saveService: saveService,
  eventGateway: eventGateway,
  snapshotManager: snapshotManager,
  documentId: document.id,
  logger: logger,
);

// 2. Handle Cmd/Ctrl+S
Future<void> handleSaveShortcut() async {
  final result = await manualSaveUseCase.execute(
    documentState: documentProvider.toJson(),
    title: document.title,
  );

  if (result is ManualSaveSuccess) {
    statusIndicator.showSaved(
      snapshotCreated: result.snapshotCreated,
    );
    windowTitle.removeDirtyIndicator();
  } else if (result is ManualSaveSkipped) {
    statusIndicator.showNoChanges();
  } else if (result is ManualSaveFailure) {
    showErrorDialog(result.message);
  }
}
```

### Adding Status Indicator to UI

```dart
// Add to your widget tree
Widget build(BuildContext context) {
  return Scaffold(
    body: Column(
      children: [
        // Status bar with save indicator
        Row(
          children: [
            Text(document.title),
            Spacer(),
            SaveStatusIndicator(controller: statusController),
          ],
        ),
        // Rest of UI...
      ],
    ),
  );
}
```

## Event Flow

### Auto-Save Flow

```
User edits object
  ↓
EventRecorder.recordEvent()
  ↓
AutoSaveManager.onEventRecorded()
  ↓
[200ms idle period]
  ↓
AutoSaveManager._performAutoSave()
  ↓
EventStoreGateway (already persisted by recordEvent)
  ↓
Status callback → UI shows "Auto-saved" (1 second)
```

### Manual Save Flow (With Changes)

```
User presses Cmd/Ctrl+S
  ↓
ManualSaveUseCase.execute()
  ↓
AutoSaveManager.flushPendingAutoSave()
  ↓
Check hasChangesSinceLastManualSave()
  ↓ [changes exist]
Record document.saved event
  ↓
SaveService.save()
  ├── Update metadata
  ├── Create snapshot (if threshold)
  └── WAL checkpoint
  ↓
AutoSaveManager.recordManualSave()
  ↓
UI shows "Saved" (2 seconds)
Window title removes "*" indicator
```

### Manual Save Flow (No Changes - Deduplication)

```
User presses Cmd/Ctrl+S
  ↓
ManualSaveUseCase.execute()
  ↓
AutoSaveManager.flushPendingAutoSave()
  ↓
Check hasChangesSinceLastManualSave()
  ↓ [no changes]
Return ManualSaveSkipped
  ↓
UI shows "No changes to save" (2 seconds)
```

## Configuration

### Auto-Save Timing

Default: 200ms idle threshold

```dart
final autoSaveManager = AutoSaveManager(
  // ...
  idleThresholdMs: 200, // Adjust if needed
);
```

### Status Display Duration

Defined in `SaveStatusController`:

```dart
showAutoSaved()   // 1 second
showSaved()       // 2 seconds
showNoChanges()   // 2 seconds
showError()       // Persistent
```

## Testing

### Unit Tests

**Auto-Save Manager:** `test/unit/auto_save_manager_test.dart`
- Debounce behavior (200ms threshold)
- Deduplication logic
- Manual save coordination
- Status callbacks
- Timer management

**Manual Save Use Case:** `test/unit/manual_save_use_case_test.dart`
- Deduplication scenarios
- Auto-save flushing
- Event recording
- SaveService integration
- Error handling

### Running Tests

```bash
# Run auto-save tests
flutter test test/unit/auto_save_manager_test.dart

# Run manual save tests
flutter test test/unit/manual_save_use_case_test.dart

# Run all interaction tests
flutter test test/unit/
```

## Benefits

### For Users

- **Data Safety**: Auto-save prevents data loss from crashes
- **Workflow Control**: Manual saves mark intentional checkpoints
- **Clear Feedback**: Status indicators show save state
- **Performance**: Debounce prevents excessive saves during rapid editing

### For Collaboration

- **Replay Milestones**: Manual saves create version markers in event stream
- **Operational Transform**: `document.saved` events help coordinate multi-user edits
- **Telemetry**: Save patterns reveal user workflow insights

### For Debugging

- **Deterministic Replay**: Manual save markers provide known-good states
- **Crash Recovery**: Auto-save ensures recent work is always persisted
- **Audit Trail**: Event log shows all save operations with timestamps

## Troubleshooting

### Auto-Save Not Triggering

**Symptom:** No "Auto-saved" status appears after edits

**Causes:**
1. `onEventRecorded()` not being called
2. Timer disposed prematurely
3. No pending changes detected

**Debug:**
```dart
// Add logging
autoSaveManager.logger.level = Level.debug;

// Check active state
print('Is active: ${autoSaveManager.isActive}');
print('Has pending: ${autoSaveManager._hasPendingChanges}');
```

### Manual Save Always Skipping

**Symptom:** "No changes to save" appears even after edits

**Causes:**
1. Auto-save already persisted events
2. Manual save sequence not updating
3. Event recording not incrementing sequence

**Debug:**
```dart
// Check sequences
final current = await eventGateway.getLatestSequenceNumber();
final lastManual = autoSaveManager.lastManualSaveSequence;
print('Current: $current, Last manual: $lastManual');
```

### Status Indicator Not Showing

**Symptom:** Status messages don't appear in UI

**Causes:**
1. Status callback not wired up
2. Widget not rebuilding
3. Controller not in widget tree

**Debug:**
```dart
// Verify callback
autoSaveManager = AutoSaveManager(
  // ...
  onStatusUpdate: ({required status, required message, eventCount}) {
    print('Status: $status, Message: $message');
  },
);
```

## Performance Considerations

### Debounce Threshold

200ms provides good balance between:
- **Responsiveness**: Short enough users don't notice
- **Efficiency**: Long enough to batch rapid edits
- **UX**: Avoids distracting status flashes

### Memory Usage

- Timer: Single `Timer` instance per manager (~100 bytes)
- Callbacks: Minimal closure overhead
- State: 3 integers (sequence tracking)

**Total per document:** < 1KB

### Event Overhead

- Auto-save: No additional events (just flush)
- Manual save: Single `document.saved` event (~200 bytes)

**Network Impact:** Minimal (local-first architecture)

## Future Enhancements

### Potential Improvements

1. **Cloud Sync Integration**
   - Auto-save triggers background sync
   - Conflict resolution on manual save
   - Status shows sync state

2. **Snapshot Optimization**
   - Auto-save triggers incremental snapshots
   - Manual save creates full snapshots
   - LRU cache for recent snapshots

3. **Telemetry**
   - Auto-save frequency metrics
   - Manual save patterns
   - Deduplication hit rate

4. **Accessibility**
   - Screen reader announcements
   - Keyboard focus management
   - High contrast themes

## References

- **Architecture Spec:** Section 7.12 (Auto-Save & Manual Save Strategy)
- **Sequence Diagrams:** Flow B (Manual Save, Auto-Save, Snapshot Coordination)
- **Event Schema:** `document.saved` event definition
- **ADRs:** ADR-001 (Event Sourcing), ADR-003 (SQLite Storage)
