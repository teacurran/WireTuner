# Event Replay and Navigation API

This document provides usage examples and API documentation for the Event Replay and Navigation components of WireTuner's event sourcing architecture.

## Table of Contents

1. [Overview](#overview)
2. [EventReplayer API](#eventreplayer-api)
3. [EventNavigator API](#eventnavigator-api)
4. [Usage Examples](#usage-examples)
5. [Performance Considerations](#performance-considerations)
6. [Error Handling](#error-handling)

---

## Overview

The Event Replay and Navigation system provides:

- **Event Replay**: Reconstruct document state from event sequences with snapshot optimization
- **Corruption Handling**: Gracefully skip corrupt events while logging warnings
- **Undo/Redo**: Navigate through document history with LRU caching
- **Performance**: < 200ms document load for 5k events, < 100ms undo/redo operations

### Key Components

- `EventReplayer`: Core replay engine that reconstructs state from events
- `EventNavigator`: Undo/redo controller with LRU caching for fast navigation
- `ReplayResult`: Container for replay state with error information

---

## EventReplayer API

### Class: `EventReplayer`

Reconstructs document state from event sequences using snapshot optimization.

#### Constructor

```dart
EventReplayer({
  required EventStore eventStore,
  required SnapshotStore snapshotStore,
  required EventDispatcher dispatcher,
  bool enableCompression = true,
})
```

**Parameters:**
- `eventStore`: Store for querying event sequences
- `snapshotStore`: Store for loading document snapshots
- `dispatcher`: Dispatcher for applying events to state
- `enableCompression`: Enable gzip compression for snapshot deserialization (default: true)

### Methods

#### replayToSequence()

Reconstructs document state to a specific sequence number with corruption handling.

```dart
Future<ReplayResult> replayToSequence({
  required String documentId,
  required int targetSequence,
  bool continueOnError = true,
})
```

**Parameters:**
- `documentId`: The document to replay
- `targetSequence`: Sequence number to reconstruct state at
- `continueOnError`: If true, skip corrupt events; if false, throw on first error (default: true)

**Returns:** `ReplayResult` containing state, skipped sequences, and warnings

**Example:**

```dart
// Navigate to specific sequence
final result = await replayer.replayToSequence(
  documentId: 'doc123',
  targetSequence: 5000,
);

if (result.hasIssues) {
  print('Skipped ${result.skippedSequences.length} corrupt events');
  for (final warning in result.warnings) {
    print('Warning: $warning');
  }
}

final document = result.state;
```

#### replayFromSnapshot() *(Legacy)*

Reconstructs document state from nearest snapshot + subsequent events.

```dart
Future<dynamic> replayFromSnapshot({
  required String documentId,
  required int maxSequence,
})
```

**Note:** This method is maintained for backward compatibility. Use `replayToSequence()` for new code as it provides better error handling.

#### replay() *(Legacy)*

Reconstructs document state from events in the specified range without snapshots.

```dart
Future<dynamic> replay({
  required String documentId,
  int fromSequence = 0,
  int? toSequence,
})
```

**Note:** This method replays from scratch without snapshot optimization. Use `replayToSequence()` for better performance.

---

## EventNavigator API

### Class: `EventNavigator`

Manages document state navigation for undo/redo operations with LRU caching.

#### Constructor

```dart
EventNavigator({
  required String documentId,
  required EventReplayer replayer,
  required EventStore eventStore,
  int? initialSequence,
})
```

**Parameters:**
- `documentId`: The document to navigate
- `replayer`: EventReplayer for reconstructing states
- `eventStore`: EventStore for querying max sequence number
- `initialSequence`: Optional starting sequence (defaults to latest)

### Properties

- `int currentSequence`: Current sequence number the navigator is positioned at
- `int maxSequence`: Maximum sequence number available in the document

### Methods

#### initialize()

Initializes the navigator by loading the latest state.

```dart
Future<ReplayResult> initialize()
```

**Returns:** `ReplayResult` with the initial document state

**Example:**

```dart
final navigator = EventNavigator(
  documentId: 'doc123',
  replayer: eventReplayer,
  eventStore: eventStore,
);

final result = await navigator.initialize();
if (result.hasIssues) {
  showWarnings(result.warnings);
}
```

#### canUndo()

Checks if undo operation is possible.

```dart
Future<bool> canUndo()
```

**Returns:** `true` if undo is possible (currentSequence > 0), `false` otherwise

#### canRedo()

Checks if redo operation is possible.

```dart
Future<bool> canRedo()
```

**Returns:** `true` if redo is possible (currentSequence < maxSequence), `false` otherwise

#### undo()

Performs an undo operation (navigate to previous sequence).

```dart
Future<ReplayResult> undo()
```

**Returns:** `ReplayResult` with state at previous sequence

**Throws:** `StateError` if undo is not possible

**Example:**

```dart
if (await navigator.canUndo()) {
  final result = await navigator.undo();
  updateDocumentState(result.state);
}
```

#### redo()

Performs a redo operation (navigate to next sequence).

```dart
Future<ReplayResult> redo()
```

**Returns:** `ReplayResult` with state at next sequence

**Throws:** `StateError` if redo is not possible

**Example:**

```dart
if (await navigator.canRedo()) {
  final result = await navigator.redo();
  updateDocumentState(result.state);
}
```

#### navigateToSequence()

Navigates to an arbitrary sequence number.

```dart
Future<ReplayResult> navigateToSequence(int targetSequence)
```

**Parameters:**
- `targetSequence`: Sequence number to navigate to (must be >= 0 and <= maxSequence)

**Returns:** `ReplayResult` with state at target sequence

**Throws:** `ArgumentError` if target sequence is invalid

**Example:**

```dart
// Navigate to specific point in history
final result = await navigator.navigateToSequence(5000);
if (result.hasIssues) {
  print('Encountered ${result.skippedSequences.length} corrupt events');
}
updateDocumentState(result.state);
```

#### clearCache()

Clears the state cache.

```dart
void clearCache()
```

Useful for testing or when memory needs to be reclaimed.

#### getCacheStats()

Returns cache statistics for debugging.

```dart
Map<String, dynamic> getCacheStats()
```

**Returns:** Map containing:
- `size`: Current number of cached entries
- `capacity`: Maximum cache size (10)
- `sequences`: List of cached sequence numbers
- `currentSequence`: Current sequence number
- `maxSequence`: Maximum sequence number

---

## Usage Examples

### Basic Document Loading

```dart
// Create dependencies
final db = await DatabaseProvider.openDatabase('mydoc.wiretuner');
final eventStore = EventStore(db);
final snapshotStore = SnapshotStore(db);
final registry = EventHandlerRegistry();
// ... register handlers ...
final dispatcher = EventDispatcher(registry);

// Create replayer
final replayer = EventReplayer(
  eventStore: eventStore,
  snapshotStore: snapshotStore,
  dispatcher: dispatcher,
);

// Load document at latest state
final maxSeq = await eventStore.getMaxSequence('doc123');
final result = await replayer.replayToSequence(
  documentId: 'doc123',
  targetSequence: maxSeq,
);

if (result.hasIssues) {
  for (final warning in result.warnings) {
    showWarning(warning);
  }
}

final document = result.state;
```

### Undo/Redo Implementation

```dart
// Create navigator
final navigator = EventNavigator(
  documentId: 'doc123',
  replayer: replayer,
  eventStore: eventStore,
);

// Initialize
await navigator.initialize();

// Wire up keyboard shortcuts
KeyboardShortcut.register(
  key: LogicalKeyboardKey.keyZ,
  modifiers: [LogicalKeyboardKey.meta],
  onPressed: () async {
    if (await navigator.canUndo()) {
      final result = await navigator.undo();
      updateDocumentState(result.state);
      print('Undid to sequence ${navigator.currentSequence}');
    }
  },
);

KeyboardShortcut.register(
  key: LogicalKeyboardKey.keyZ,
  modifiers: [LogicalKeyboardKey.meta, LogicalKeyboardKey.shift],
  onPressed: () async {
    if (await navigator.canRedo()) {
      final result = await navigator.redo();
      updateDocumentState(result.state);
      print('Redid to sequence ${navigator.currentSequence}');
    }
  },
);
```

### Time Travel Slider

```dart
// Build sequence slider UI
Slider(
  value: navigator.currentSequence.toDouble(),
  min: 0,
  max: navigator.maxSequence.toDouble(),
  divisions: navigator.maxSequence > 0 ? navigator.maxSequence : null,
  label: 'Sequence ${navigator.currentSequence}',
  onChanged: (value) async {
    final targetSeq = value.toInt();
    final result = await navigator.navigateToSequence(targetSeq);
    updateDocumentState(result.state);
  },
)
```

### Handling Corrupted Events

```dart
// Replay with error handling
final result = await replayer.replayToSequence(
  documentId: 'doc123',
  targetSequence: 10000,
  continueOnError: true, // Skip corrupt events
);

if (result.hasIssues) {
  // Show warning dialog
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Document Recovery'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Some events could not be replayed:'),
          SizedBox(height: 8),
          ...result.warnings.map((w) => Text('• $w')),
          SizedBox(height: 8),
          Text('Skipped sequences: ${result.skippedSequences.join(", ")}'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('OK'),
        ),
      ],
    ),
  );
}

// Continue with recovered state
final document = result.state;
```

---

## Performance Considerations

### Snapshot Strategy

- Snapshots are created every 1000 events automatically (via `SnapshotManager`)
- Loading with snapshots: typically replays < 1000 events
- Without snapshots: replays all events from sequence 0

**Recommendation:** Ensure snapshots are being created periodically for optimal performance.

### Cache Behavior

The `EventNavigator` maintains an LRU cache of 10 recently visited states:

- **Cache Hit:** < 1ms (simple map lookup + clone)
- **Cache Miss:** 50-200ms (snapshot load + event replay)

**Best Practices:**
- Repeated undo/redo within same range benefits from cache
- Cache is automatically evicted (LRU) when capacity is reached
- Use `clearCache()` to manually free memory if needed

### Performance Targets

| Operation | Target Latency | Typical Latency |
|-----------|---------------|-----------------|
| Document Load (with snapshot) | < 200ms | 50-150ms |
| Undo/Redo (cache hit) | < 100ms | < 10ms |
| Undo/Redo (cache miss) | < 100ms | 50-100ms |
| Navigate to arbitrary sequence | < 200ms | 100-200ms |
| Full replay (no snapshots) | < 1000ms | 500-800ms |

**Note:** Performance measured on CI runner with 5000-event documents.

---

## Error Handling

### ReplayResult Structure

All replay operations return a `ReplayResult` object:

```dart
class ReplayResult {
  /// The reconstructed document state
  final dynamic state;

  /// Event sequences that were skipped due to corruption
  final List<int> skippedSequences;

  /// Warnings generated during replay
  final List<String> warnings;

  /// Whether the replay encountered any issues
  bool get hasIssues => skippedSequences.isNotEmpty || warnings.isNotEmpty;
}
```

### Common Error Scenarios

#### Corrupted Event

```dart
final result = await replayer.replayToSequence(
  documentId: 'doc123',
  targetSequence: 5000,
);

if (result.hasIssues) {
  // Some events were corrupted
  logger.warning('Skipped ${result.skippedSequences.length} events');

  // Check which sequences were affected
  for (final seq in result.skippedSequences) {
    logger.warning('Event at sequence $seq could not be applied');
  }
}
```

#### Corrupted Snapshot

When a snapshot is corrupted, the replayer automatically:
1. Attempts to find the previous snapshot
2. Falls back to full replay if no previous snapshot exists
3. Logs warnings in `ReplayResult.warnings`

```dart
final result = await replayer.replayToSequence(
  documentId: 'doc123',
  targetSequence: 5000,
);

if (result.warnings.any((w) => w.contains('Snapshot'))) {
  logger.error('Snapshot corruption detected - document recovered via fallback');
}
```

#### Navigator Errors

```dart
// Attempting undo when at sequence 0
try {
  await navigator.undo();
} on StateError catch (e) {
  print('Cannot undo: $e');
}

// Attempting redo when at latest sequence
try {
  await navigator.redo();
} on StateError catch (e) {
  print('Cannot redo: $e');
}

// Invalid target sequence
try {
  await navigator.navigateToSequence(-1);
} on ArgumentError catch (e) {
  print('Invalid sequence: $e');
}
```

---

## Testing

The replay and navigation system includes comprehensive test coverage:

- **Unit Tests:** `test/infrastructure/event_sourcing/event_replayer_corruption_test.dart`
- **Unit Tests:** `test/infrastructure/event_sourcing/event_navigator_test.dart`
- **Performance Benchmarks:** `test/infrastructure/event_sourcing/event_replay_performance_test.dart`

Run tests:

```bash
# Run all event sourcing tests
flutter test test/infrastructure/event_sourcing/

# Run specific test suite
flutter test test/infrastructure/event_sourcing/event_navigator_test.dart

# Run performance benchmarks
flutter test test/infrastructure/event_sourcing/event_replay_performance_test.dart
```

---

## Architecture References

- [ADR 003: Event Sourcing Architecture Design](../adr/003-event-sourcing-architecture.md)
- [Event Lifecycle Flow](../specs/event_lifecycle.md)
- [Event Sourcing Sequences Diagram](../diagrams/event_sourcing_sequences.puml)

---

## API Stability

**Current Status:** ✅ Stable (Iteration I1)

**Breaking Changes Policy:**
- The `replayToSequence()` and `EventNavigator` APIs are stable
- Legacy methods (`replay()`, `replayFromSnapshot()`) are maintained for backward compatibility
- Future enhancements will be additive (new methods/parameters)

**Deprecation Timeline:**
- `replay()` and `replayFromSnapshot()` will be deprecated in Iteration I3
- Full removal planned for Iteration I5

---

## Support

For questions or issues:
- File bug reports at: [GitHub Issues](https://github.com/wiretuner/wiretuner/issues)
- Reference Task ID: `I1.T7` (Event Replay Engine and Undo/Redo Navigator)
