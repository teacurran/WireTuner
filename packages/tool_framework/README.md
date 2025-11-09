# Tool Framework Package

Tool telemetry and undo boundary annotation system for WireTuner.

## Overview

This package provides telemetry tracking and undo grouping support for tools in the WireTuner application. It ensures that:

1. Tool operations flush pending sampled events correctly
2. Human-readable labels are emitted for undo/redo UI
3. Tool usage metrics are tracked and aggregated
4. Metrics are exported via logger following the MetricsSink pattern

## Features

- **Undo Group Lifecycle Tracking**: Start, sample, and end undo groups with validation
- **Human-Readable Labels**: Register operation labels for UI surfaces (menus, history panels)
- **Tool Usage Metrics**: Track activation counts, operation counts, and sample events
- **Flush Contract**: Compatible with MetricsSink pattern from event_core
- **Provider Integration**: Extends ChangeNotifier for reactive UI binding (Decision 7)

## Usage

### Basic Setup

```dart
import 'package:tool_framework/tool_framework.dart';
import 'package:logger/logger.dart';
import 'package:event_core/src/diagnostics_config.dart';

final telemetry = ToolTelemetry(
  logger: Logger(level: Level.debug),
  config: EventCoreDiagnosticsConfig.debug(),
);
```

### Tracking an Undo Group

```dart
// Start an undo group (on pointer down)
final groupId = telemetry.startUndoGroup(
  toolId: 'pen',
  label: 'Create Path',
);

// Record sampled events (during pointer move)
telemetry.recordSample(
  toolId: 'pen',
  eventType: 'AddAnchorEvent',
);

// End the undo group (on pointer up)
telemetry.endUndoGroup(
  toolId: 'pen',
  groupId: groupId,
  label: 'Create Path',
);

// Flush metrics periodically
await telemetry.flush();
```

### Recording Tool Activation

```dart
telemetry.recordActivation('pen');
```

### Accessing Undo Labels for UI

```dart
// Get last completed label for a tool
final label = telemetry.getLastCompletedLabel('pen');
// Returns: "Create Path"

// Get all labels (for history panels)
final allLabels = telemetry.allLastCompletedLabels;
// Returns: {'pen': 'Create Path', 'selection': 'Move Objects', ...}
```

### Provider Integration

```dart
// In app shell
ChangeNotifierProvider(
  create: (_) => ToolTelemetry(
    logger: logger,
    config: config,
  ),
  child: EditorShell(),
)

// In menu widget
class UndoMenuItem extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final telemetry = context.watch<ToolTelemetry>();
    final activeTool = context.watch<ToolManager>().activeToolId;

    final label = activeTool != null
        ? telemetry.getLastCompletedLabel(activeTool)
        : null;

    return MenuItem(
      label: label != null ? 'Undo $label' : 'Undo',
      shortcut: 'Cmd+Z',
      onPressed: () => undoController.undo(),
      enabled: label != null,
    );
  }
}
```

## Architecture

The telemetry system integrates with:

- **Event sourcing**: Via event recorder flush operations
- **Metrics infrastructure**: MetricsSink pattern from I1.T8
- **Undo/redo system**: StartGroupEvent/EndGroupEvent metadata
- **UI layer**: Provider-based label propagation per Decision 7

## API Reference

### `ToolTelemetry`

Main class for tracking tool telemetry and undo boundaries.

#### Methods

- `startUndoGroup({required String toolId, required String label})`: Starts a new undo group
- `recordSample({required String toolId, required String eventType})`: Records a sampled event
- `endUndoGroup({required String toolId, required String groupId, required String label})`: Ends an undo group
- `recordActivation(String toolId)`: Records a tool activation
- `flush()`: Flushes buffered metrics to logger
- `getLastCompletedLabel(String toolId)`: Returns last completed operation label
- `getMetrics()`: Returns current aggregated metrics

## Testing

Run tests with:

```bash
flutter test
```

The test suite covers:
- Undo group lifecycle (start, sample, end)
- Sample recording and aggregation
- Activation tracking
- Label management and persistence
- Flush behavior and metric reset
- ChangeNotifier integration
- Edge cases (excessive samples, dispose with active groups)

## Documentation

See also:
- [Event Schema Reference](../../docs/reference/event_schema.md)
- [Undo Label Reference](../../docs/reference/undo_labels.md)
- [Task I3.T9 Specification](.codemachine/artifacts/plan/02_Iteration_I3.md)

## License

Part of the WireTuner project.
