# Application Services

Application-level services that orchestrate domain logic and infrastructure operations for WireTuner.

## Overview

This directory contains high-level services that coordinate between the UI layer (presentation), domain models, and infrastructure packages (io_services, event_core). These services provide a clean API for the UI while encapsulating complex workflows.

## Services

### DocumentService

Document lifecycle orchestrator that manages save, load, and close operations.

**Responsibilities:**
- Coordinates between DocumentProvider (UI state) and SaveService (persistence)
- Manages dirty state tracking by bridging sequence numbers from event gateway
- Provides high-level save/saveAs methods with integrated dialog handling
- Ensures snapshots are created before saves when policy requires
- Handles error propagation with user-friendly messages

**Architecture:**
```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
│              (UI components, buttons, menus)                 │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                  DocumentService                             │
│  - saveDocument(context)                                     │
│  - saveDocumentAs(context)                                   │
│  - hasUnsavedChanges()                                       │
│  - closeDocument()                                           │
└──┬───────────────┬─────────────┬──────────────┬─────────────┘
   │               │             │              │
   │ reads state   │ delegates   │ queries      │ notifies
   │               │ save ops    │ sequence     │ policy
   ▼               ▼             ▼              ▼
┌──────────┐  ┌──────────┐  ┌─────────────┐  ┌──────────────┐
│Document  │  │  Save    │  │Event Store  │  │ Snapshot     │
│Provider  │  │ Service  │  │  Gateway    │  │  Manager     │
└──────────┘  └──────────┘  └─────────────┘  └──────────────┘
```

**Usage:**

```dart
import 'package:wiretuner/application/services/document_service.dart';

// Initialize with dependencies
final documentService = DocumentService(
  documentProvider: documentProvider,
  saveService: saveService,
  eventGateway: eventGateway,
  snapshotManager: snapshotManager,
  logger: logger,
);

// Save document (uses current path or prompts for Save As)
final result = await documentService.saveDocument(context: context);

if (result is SaveSuccess) {
  print('Saved to: ${result.filePath}');
} else if (result is SaveFailure) {
  // Error dialog already shown to user
  print('Save failed: ${result.technicalDetails}');
}

// Save As (always prompts for new path)
final saveAsResult = await documentService.saveDocumentAs(context: context);

// Check dirty state
final hasChanges = await documentService.hasUnsavedChanges();
if (hasChanges) {
  // Show unsaved changes dialog
}

// Close document (releases resources)
await documentService.closeDocument();
```

**Key Features:**

1. **Automatic Save As Detection**: If `saveDocument()` is called on a new document (no file path), automatically redirects to Save As workflow

2. **Dialog Integration**: Integrates with `SaveDialogs` from `app_shell` package to show:
   - Progress indicators during save
   - Success notifications (non-blocking snackbar)
   - Error dialogs with actionable messages
   - File picker for Save As

3. **Dirty State Tracking**: Compares current event sequence with last persisted sequence to determine if document has unsaved changes

4. **Snapshot Coordination**: Ensures snapshots are created before save when `SnapshotManager` policy requires it (e.g., every 1000 events)

5. **Error Handling**: Catches exceptions during save and converts them to user-friendly error messages while logging technical details

**Integration with Other Services:**

- **DocumentProvider** (`presentation/state/document_provider.dart`): Provides current document state via `toJson()` and tracks document metadata (id, title)

- **SaveService** (`packages/io_services/lib/src/save_service.dart`): Handles all filesystem operations, database transactions, and connection management

- **EventStoreGateway** (`packages/event_core/src/event_store_gateway.dart`): Provides current sequence number via `getLatestSequenceNumber()`

- **SnapshotManager** (`packages/event_core/src/snapshot_manager.dart`): Determines snapshot policy and records event activity

- **SaveDialogs** (`packages/app_shell/lib/src/ui/save_dialogs.dart`): UI helper for showing save-related dialogs and file pickers

**Testing:**

See `test/integration/document_service_integration_test.dart` for comprehensive integration tests covering:
- Save workflow with file creation
- Dirty state detection
- Snapshot creation triggers
- Concurrent save prevention
- Resource cleanup

**Acceptance Criteria (from I9.T1):**

✅ `saveDocument()` creates SQLite file with events, snapshots, metadata
✅ Save As prompts for file path (via `SaveDialogs.showSaveAsDialog`)
✅ Save uses current file path or prompts if new document
✅ `format_version` field set (e.g., "1.0")
✅ Integration test creates document, saves, verifies file exists

---

### UndoService

*(Implemented in I4)*

Undo/redo navigation service that provides operation-based history navigation.

See `undo_service.dart` for details.

---

### DocumentEventApplier

*(Implemented in I2)*

Applies events to the document model and updates DocumentProvider state.

See `document_event_applier.dart` for details.

---

## Architecture Guidelines

### Dependency Injection

All services should be instantiated at app startup with explicit dependency injection:

```dart
// In main.dart or app bootstrap
final documentService = DocumentService(
  documentProvider: documentProvider,
  saveService: saveService,
  eventGateway: eventGateway,
  snapshotManager: snapshotManager,
  logger: logger,
);
```

### BuildContext Handling

Services that show dialogs require `BuildContext`:

```dart
// ✅ Good: Pass context from widget
onPressed: () async {
  await documentService.saveDocument(context: context);
}

// ❌ Bad: Store context in service
// Services should be stateless and context-agnostic
```

### Error Handling Pattern

Services should:
1. Catch exceptions
2. Log technical details
3. Return structured result types (`SaveResult`, `LoadResult`)
4. Show user-friendly error dialogs

```dart
try {
  final result = await saveService.save(...);
  if (result is SaveFailure) {
    await showErrorDialog(context, result.userMessage);
  }
} catch (e, stackTrace) {
  logger.e('Save failed', error: e, stackTrace: stackTrace);
  // Show generic error to user
}
```

### Testing Strategy

- **Unit tests**: Test individual service methods with mocked dependencies
- **Integration tests**: Test full workflows with real database connections
- **Widget tests**: Test UI integration with services using `testWidgets()`

---

## Dependencies

Services in this directory depend on:

- **Domain Layer**: `lib/domain/` (Document, Layer, etc.)
- **Presentation Layer**: `lib/presentation/state/` (DocumentProvider)
- **Infrastructure Packages**: `io_services`, `event_core`, `app_shell`
- **Flutter SDK**: For `BuildContext` and widgets

## References

- **Architecture Blueprint**: `.codemachine/artifacts/architecture/`
- **Task Specifications**: `.codemachine/artifacts/plan/02_Iteration_I9.md`
- **io_services README**: `packages/io_services/README.md`
- **event_core README**: `packages/event_core/README.md`
