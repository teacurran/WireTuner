<!-- anchor: logging-strategy-event-core -->
# Logging & Metrics Strategy - Event Core

**Document Version**: 1.0
**Last Updated**: 2024-11-08
**Implementation**: Task I1.T8
**Status**: Implemented

## Overview

This document specifies the logging and metrics strategy for the `event_core` package, which implements structured logging with the `logger` package and performance counters for monitoring event system health.

## Objectives

1. **Debug Support**: Enable developers and users to diagnose issues via log files attached to bug reports
2. **Performance Monitoring**: Track critical metrics (event write latency, replay duration, snapshot operations)
3. **Error Tracking**: Capture unrecoverable failures and recoverable issues with context
4. **Production Monitoring**: Maintain lightweight metrics in release builds for operational insights

## Log Levels

The event core uses standard log levels from the `logger` package:

| Level | Usage | Examples |
|-------|-------|----------|
| **ERROR** | Unrecoverable failures | File I/O errors, corrupted data, database failures |
| **WARNING** | Recoverable issues | Slow event writes (> 50ms), dropped frames, large snapshots (> 100MB) |
| **INFO** | Key lifecycle events | Document loaded/saved, replay completed, snapshot created |
| **DEBUG** | Detailed flow | Event recorded, tool state changes, sampler decisions |
| **TRACE** | Verbose output | Every rendered frame, geometry calculations (disabled in release) |

## Configuration

### Diagnostics Config

The `EventCoreDiagnosticsConfig` class controls logging and metrics behavior:

```dart
import 'package:logger/logger.dart';
import 'package:event_core/event_core.dart';

// Debug configuration (development)
final debugConfig = EventCoreDiagnosticsConfig.debug();
// - logLevel: Level.debug
// - enableMetrics: true
// - enableDetailedLogging: true

// Release configuration (production)
final releaseConfig = EventCoreDiagnosticsConfig.release();
// - logLevel: Level.info
// - enableMetrics: true
// - enableDetailedLogging: false

// Silent configuration (unit tests)
final silentConfig = EventCoreDiagnosticsConfig.silent();
// - logLevel: Level.nothing
// - enableMetrics: false
// - enableDetailedLogging: false
```

### Logger Setup

The `event_core` package does NOT configure the logger directly (platform-agnostic design). Instead, the embedding Flutter application provides a configured `Logger` instance:

```dart
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

Future<Logger> createProductionLogger() async {
  final appSupportDir = await getApplicationSupportDirectory();
  final logFile = File('${appSupportDir.path}/wiretuner.log');

  return Logger(
    level: Level.info, // Release: Level.info, Debug: Level.debug
    printer: PrettyPrinter(
      methodCount: 2,         // Stack trace depth
      errorMethodCount: 8,    // Stack trace for errors
      lineLength: 120,
      colors: true,           // ANSI colors (terminal only)
      printEmojis: true,
      printTime: true,
    ),
    output: MultiOutput([
      ConsoleOutput(),        // Stdout during development
      FileOutput(file: logFile), // Persistent log file
    ]),
  );
}
```

## Log File Location

Log files are stored in platform-specific application support directories:

- **macOS**: `~/Library/Application Support/WireTuner/wiretuner.log`
- **Windows**: `%APPDATA%\WireTuner\wiretuner.log`

## Log Rotation Policy

To prevent unbounded disk usage, applications should implement log rotation:

- **Max file size**: 10 MB per log file
- **Retention**: Keep last 5 log files (`wiretuner.log`, `wiretuner.1.log`, ..., `wiretuner.4.log`)
- **Rotation trigger**: On application start, check file size and rotate if > 10 MB

### Example Rotation Logic

```dart
import 'dart:io';

Future<void> rotateLogsIfNeeded(String logFilePath) async {
  final logFile = File(logFilePath);
  if (!await logFile.exists()) return;

  final stat = await logFile.stat();
  if (stat.size < 10 * 1024 * 1024) return; // < 10 MB, no rotation needed

  // Rotate: wiretuner.3.log → wiretuner.4.log, wiretuner.2.log → wiretuner.3.log, etc.
  for (var i = 4; i >= 1; i--) {
    final oldFile = File('$logFilePath${i == 1 ? '' : '.$i'}');
    if (await oldFile.exists()) {
      if (i == 4) {
        await oldFile.delete(); // Delete oldest log
      } else {
        await oldFile.rename('$logFilePath.${i + 1}');
      }
    }
  }

  // Rename current log to .1.log
  await logFile.rename('$logFilePath.1.log');
}
```

## Performance Metrics

### Tracked Metrics

The `StructuredMetricsSink` tracks the following operations:

| Metric | Target | Warning Threshold | Description |
|--------|--------|-------------------|-------------|
| **Event Write Latency** | < 10ms | > 50ms | Time to persist event to SQLite |
| **Replay Duration** | < 500ms | > 500ms | Time to replay events from snapshot |
| **Snapshot Creation** | - | - | Time + size of snapshot serialization |
| **Snapshot Load** | < 1000ms | > 1000ms | Time to load snapshot from storage |

### Metric Emission

Metrics are emitted via the configured `Logger` instance:

- **Event write > 50ms**: `WARN` level
- **Replay duration**: Always `INFO` level (important lifecycle event)
- **Replay > 500ms**: `WARN` level
- **Snapshot > 100MB**: `WARN` level (potential memory issue)

### Aggregated Metrics

Metrics are aggregated in-memory and flushed periodically or on application shutdown:

```dart
final metricsSink = StructuredMetricsSink(
  logger: logger,
  config: EventCoreDiagnosticsConfig.release(),
);

// ... record events ...

await metricsSink.flush(); // Emit aggregated stats

// Output example:
// [INFO] Event metrics: total=1500, sampled=800, avgWriteTime=6.2ms
// [INFO] Replay metrics: count=5, avgDuration=320.5ms
// [INFO] Snapshot metrics: created=2, loaded=3
```

## Integration Example

### Event Recorder with Logging

```dart
import 'package:event_core/event_core.dart';
import 'package:logger/logger.dart';

final logger = await createProductionLogger();
final config = EventCoreDiagnosticsConfig.release();
final metricsSink = StructuredMetricsSink(logger: logger, config: config);

final recorder = DefaultEventRecorder(
  sampler: sampler,
  dispatcher: dispatcher,
  storeGateway: storeGateway,
  metricsSink: metricsSink,
  logger: logger,
  config: config,
);

// All operations now emit structured logs
await recorder.recordEvent({'eventType': 'CreatePathEvent'});
// [DEBUG] Recording event: CreatePathEvent
// [WARN] Slow event write: CreatePathEvent took 65ms (sampled: false)

recorder.pause();
// [INFO] Event recording paused

recorder.resume();
// [INFO] Event recording resumed
```

### Event Replayer with Logging

```dart
final replayer = DefaultEventReplayer(
  storeGateway: storeGateway,
  dispatcher: dispatcher,
  snapshotManager: snapshotManager,
  metricsSink: metricsSink,
  logger: logger,
  config: config,
);

await replayer.replay(fromSequence: 0, toSequence: 100);
// [INFO] Starting replay: fromSequence=0, toSequence=100
// [INFO] Replay completed: 100 events [0 → 100] in 350ms
```

## Performance Overhead

- **Logging overhead**: < 0.5% of operation time (logger buffers asynchronously)
- **Metrics overhead**: < 1% of operation time (`Stopwatch` measurements are lightweight)
- **Safe for release builds**: Metrics stay enabled; detailed logging disabled

## Cross-References

- **Architecture**: `.codemachine/artifacts/architecture/05_Operational_Architecture.md` (logging-strategy, monitoring-metrics)
- **Performance Targets**: `.codemachine/artifacts/architecture/02_Component_Design.md` (Decision 1 & 6)
- **CI Integration**: Task `I1.T7` CI scripts capture log artifacts for debugging
- **Verification**: Section 6 of `.codemachine/artifacts/plan/03_Verification_and_Glossary.md`

## Future Work

- **Metrics Export**: Add option to export metrics to external monitoring systems (Prometheus, CloudWatch)
- **Flame Graphs**: Integrate with Dart DevTools for performance profiling
- **Log Filtering**: Add dynamic log level adjustment via debug UI
- **Crash Reporting**: Integrate with Sentry/Firebase Crashlytics for automated error tracking

---

**Note**: This strategy applies to `packages/event_core` only. Other packages (vector_engine, app_shell) should adopt similar patterns with package-specific metrics.
