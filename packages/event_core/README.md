# event_core

Event sourcing core infrastructure for WireTuner.

## Overview

This package provides the fundamental event sourcing components including event recording, replay, and snapshot management.

## Status

**Iteration I1**: Placeholder package created. Implementation planned for future iterations.

## Planned Features

- **Event Recorder**: Event capture with 50ms sampling for continuous actions
- **Event Replayer**: Document state reconstruction from event logs
- **Snapshot Service**: Periodic state snapshots (every 1000 events)
- **Event Log Management**: Persistence and retrieval operations

## Architecture

The event sourcing architecture enables:
- Infinite undo/redo through event history navigation
- Complete audit trail for debugging and analysis
- Future collaboration support (events are distributable)
- Crash recovery via snapshots + event replay
- Time-travel debugging

## Usage

```dart
import 'package:event_core/event_core.dart';

const recorder = EventRecorder();
const replayer = EventReplayer();
const snapshots = SnapshotService();
```

## Development

This package is part of the WireTuner melos workspace. See the root README for workspace commands.
