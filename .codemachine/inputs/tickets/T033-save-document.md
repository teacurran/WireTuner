# T033: Save Document to SQLite File

## Status
- **Phase**: 8 - File Operations
- **Priority**: Critical (Milestone 0.1)
- **Estimated Effort**: 1 day
- **Dependencies**: T008

## Overview
Implement save functionality to persist document to .wiretuner file.

## Objectives
- Save current document state
- Create snapshot at save time
- Flush all pending events
- Update file metadata
- Handle "Save" vs "Save As"

## Implementation
```dart
class DocumentService {
  Future<void> saveDocument(String filePath) async {
    // 1. Flush any pending events
    await _eventRecorder.flush();

    // 2. Create snapshot of current state
    final currentSequence = _eventRecorder.currentSequence;
    await _snapshotService.createSnapshot(currentSequence, _documentState);

    // 3. Update metadata
    await _db.setMetadata('document_name', _documentState.metadata.name);
    await _db.setMetadata('modified_at', DateTime.now().toIso8601String());

    // 4. Ensure file is written to disk
    await _db.close();
    await _db.openDocument(filePath);
  }

  Future<void> saveAsDocument(String newFilePath) async {
    // Copy current database to new location
    // Then call saveDocument
  }
}
```

## Success Criteria
- [ ] Document saves successfully
- [ ] File can be reopened
- [ ] All events preserved
- [ ] Snapshot created at save time
- [ ] "Save As" creates new file

## References
- T002: Database Service
- T007: Snapshot System
