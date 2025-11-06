# T034: Load Document from SQLite File

## Status
- **Phase**: 8 - File Operations
- **Priority**: Critical (Milestone 0.1)
- **Estimated Effort**: 1 day
- **Dependencies**: T033

## Overview
Implement load functionality to open existing .wiretuner files.

## Objectives
- Open database file
- Load latest snapshot
- Replay events since snapshot
- Restore document state
- Handle file version compatibility

## Implementation
```dart
class DocumentService {
  Future<Document> loadDocument(String filePath) async {
    // 1. Open database
    await _db.openDocument(filePath);

    // 2. Check schema version compatibility
    final schemaVersion = await _db.getSchemaVersion();
    if (schemaVersion > DatabaseService.currentSchemaVersion) {
      throw IncompatibleVersionException(
        'This file was created with a newer version of WireTuner'
      );
    }

    // 3. Replay to current sequence
    final state = await _replayEngine.replayToSequence(int.maxValue);

    // 4. Load metadata
    final name = await _db.getMetadata('document_name');
    state.metadata = state.metadata.copyWith(name: name);

    return state.toDocument();
  }
}
```

## Success Criteria
- [ ] Can open saved .wiretuner files
- [ ] Document state fully restored
- [ ] All objects render correctly
- [ ] Event history preserved
- [ ] Rejects files from newer app versions

## References
- T008: Replay Engine
- T033: Save Document
