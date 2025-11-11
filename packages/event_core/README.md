# event_core

Event sourcing core infrastructure for WireTuner.

## Overview

This package provides the fundamental event sourcing components including event recording, replay, and snapshot management with built-in structured logging and performance metrics.

## Status

**Iteration I1**: Core interfaces implemented with logging/metrics instrumentation (I1.T8 complete). Full event persistence and replay logic planned for future iterations.

## Features

- **Event Recorder**: Event capture with 50ms sampling for continuous actions (I1.T3)
- **Event Replayer**: Document state reconstruction from event logs (I1.T6)
- **Snapshot Manager**: Periodic state snapshots (every 1000 events, I1.T7)
- **Structured Logging**: Configurable logging with `logger` package (I1.T8)
- **Performance Metrics**: Event write latency, replay duration, snapshot metrics (I1.T8)
- **Event Log Management**: Persistence and retrieval operations (I1.T4)

## Architecture

The event sourcing architecture enables:
- Infinite undo/redo through event history navigation
- Complete audit trail for debugging and analysis
- Future collaboration support (events are distributable)
- Crash recovery via snapshots + event replay
- Time-travel debugging
- **Performance monitoring** via structured metrics
- **Debug support** via detailed logging

## Usage

### Basic Setup

```dart
import 'package:event_core/event_core.dart';
import 'package:logger/logger.dart';

// Create logger and diagnostics config
final logger = Logger(level: Level.info);
final config = EventCoreDiagnosticsConfig.release();

// Create metrics sink
final metricsSink = StructuredMetricsSink(
  logger: logger,
  config: config,
);

// Create event recorder
final recorder = DefaultEventRecorder(
  sampler: StubEventSampler(),
  dispatcher: StubEventDispatcher(),
  storeGateway: StubEventStoreGateway(),
  metricsSink: metricsSink,
  logger: logger,
  config: config,
);

// Record events
await recorder.recordEvent({
  'eventType': 'CreatePathEvent',
  'timestamp': DateTime.now().millisecondsSinceEpoch,
});
```

### Logging Configuration

```dart
// Debug configuration (development)
final debugConfig = EventCoreDiagnosticsConfig.debug();

// Release configuration (production)
final releaseConfig = EventCoreDiagnosticsConfig.release();

// Silent configuration (unit tests)
final silentConfig = EventCoreDiagnosticsConfig.silent();
```

### Performance Metrics

```dart
// Use PerformanceCounters for custom timing
final counters = PerformanceCounters();

final (result, durationMs) = await counters.measure('custom_op', () async {
  return await performExpensiveOperation();
});

print('Operation took ${durationMs}ms');
```

## Documentation

- **Logging Strategy**: See [`docs/specs/logging_strategy.md`](../../docs/specs/logging_strategy.md) for:
  - Log levels and usage guidelines
  - Configuration examples
  - Log file location and rotation policy
  - Performance metrics tracked
  - CI integration for log artifacts
- **Architecture**: See [`.codemachine/artifacts/architecture/05_Operational_Architecture.md`](../../.codemachine/artifacts/architecture/05_Operational_Architecture.md)
- **Performance Targets**: Decision 1 & 6 in architecture documents

## Development

This package is part of the WireTuner melos workspace. See the root README for workspace commands.

### Running Tests

```bash
# Run all tests
dart test

# Run specific test suite
dart test test/unit/diagnostics_test.dart
```

### Test Coverage

- Unit tests for all core interfaces (event_core_interfaces_test.dart)
- Diagnostics and metrics tests (diagnostics_test.dart)
- Coverage target: ≥80% for event_core package
