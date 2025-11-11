# Performance Overlay & Telemetry UI

This module implements the performance overlay with telemetry instrumentation as specified in **Task I3.T6**.

## Overview

The performance overlay provides real-time performance monitoring with:
- **Draggable/Dockable UI**: Users can drag the overlay to reposition or snap it to screen corners
- **Performance Metrics**: FPS, frame time, snapshot duration, event replay rate
- **Telemetry Integration**: Opt-out aware metrics collection and upload
- **State Persistence**: Overlay position and preferences saved across sessions

## Architecture

### Core Components

#### 1. Performance Overlay (`performance_overlay.dart`)

The main UI widget with draggable/dockable functionality:

```dart
PerformanceOverlay(
  overlayState: overlayState,
  onOverlayStateChanged: (state) => saveState(state),
  metrics: renderMetrics,
  viewportController: viewportController,
  telemetryConfig: telemetryConfig,
  child: canvas,
)
```

**Features:**
- Drag-to-reposition with visual dock zone indicators
- Snap-to-corner docking (top-left, top-right, bottom-left, bottom-right)
- Color-coded metrics (green/yellow/red thresholds)
- Telemetry status badge when opted out
- Keyboard toggle: `Cmd/Ctrl+Shift+P`

#### 2. Overlay State (`overlay_state.dart`)

State management for position, visibility, and docking:

```dart
const overlayState = OverlayState(
  isVisible: true,
  dockLocation: DockLocation.topRight,
  position: Offset(16, 16),
);
```

**Dock Locations:**
- `topLeft`, `topRight`, `bottomLeft`, `bottomRight`: Docked positions
- `floating`: Free-floating at specified position

#### 3. State Persistence (`overlay_preferences.dart`)

Persistent storage via `SharedPreferences`:

```dart
final prefs = OverlayPreferences(sharedPreferences);

// Load saved state
final state = prefs.loadState();

// Save state
await prefs.saveState(state);

// Reset to defaults
await prefs.resetToDefaults();
```

#### 4. Telemetry Integration (`telemetry_integration.dart`)

Instrumentation hooks for snapshot and replay metrics:

```dart
// Snapshot telemetry callback
final snapshotManager = SnapshotManager(
  snapshotStore: store,
  onSnapshotCreated: createSnapshotTelemetryCallback(telemetryService),
);

// Replay metrics tracker
final replayTracker = createReplayMetricsTracker(telemetryService);
replayTracker.recordEvent(); // Track event replay
```

#### 5. Settings UI (`telemetry_section.dart`)

Telemetry configuration panel:

```dart
TelemetrySettingsSection(
  telemetryConfig: config,
  onConfigChanged: () => saveConfig(config),
)
```

**Features:**
- Enable/disable telemetry toggle
- Enable/disable upload toggle (dependent on telemetry enabled)
- Sampling rate and retention period display
- Audit trail viewer (opt-in/opt-out history)
- Privacy notice

## Metrics

### Extended RenderMetrics

The `RenderMetrics` class has been extended with snapshot and replay metrics:

```dart
const metrics = RenderMetrics(
  frameTimeMs: 16.7,                      // Frame render time
  objectsRendered: 150,                   // Objects rendered this frame
  objectsCulled: 50,                      // Objects culled (not visible)
  cacheSize: 200,                         // Path cache size
  snapshotDurationMs: 450.0,              // Snapshot creation time
  replayRateEventsPerSec: 5500.0,         // Event replay throughput
);
```

### Metric Thresholds (per UI/UX Architecture Section 1.7)

| Metric | Green | Amber | Red |
|--------|-------|-------|-----|
| **Frame Time** | ≤16ms | 17-33ms | >33ms |
| **FPS** | ≥50 | 30-49 | <30 |
| **Snapshot Duration** | ≤500ms | 501-1000ms | >1000ms |
| **Replay Rate** | ≥5000 events/s | 4000-4999 events/s | <4000 events/s |

### Telemetry Service Methods

New methods added to `TelemetryService`:

```dart
// Record snapshot metric
telemetryService.recordSnapshotMetric(
  durationMs: 450,
  compressionRatio: 10.0,
  documentId: 'doc-123',
);

// Record replay metric
telemetryService.recordReplayMetric(
  eventsPerSec: 5500.0,
  queueDepth: 42,
);
```

Both methods:
- Honor `TelemetryConfig.enabled` (opt-out enforcement)
- Log structured telemetry events
- Warn when thresholds are exceeded (per NFRs)
- Export to OTLP when configured

## Usage

### Basic Setup

```dart
class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late TelemetryConfig _telemetryConfig;
  late TelemetryService _telemetryService;
  late OverlayPreferences _overlayPrefs;
  late OverlayState _overlayState;

  @override
  void initState() {
    super.initState();

    // Initialize telemetry
    _telemetryConfig = TelemetryConfig.debug();
    _telemetryService = TelemetryService(config: _telemetryConfig);

    // Load overlay state
    _overlayPrefs = OverlayPreferences(sharedPreferences);
    _overlayState = _overlayPrefs.loadState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: PerformanceOverlayWrapper(
          initialState: _overlayState,
          onStateChanged: (state) async {
            await _overlayPrefs.saveState(state);
          },
          metrics: renderPipeline.lastMetrics,
          viewportController: viewportController,
          telemetryConfig: _telemetryConfig,
          child: WireTunerCanvas(...),
        ),
      ),
    );
  }
}
```

### Snapshot Instrumentation

```dart
final snapshotManager = SnapshotManager(
  snapshotStore: snapshotStore,
  snapshotFrequency: 1000,
  onSnapshotCreated: createSnapshotTelemetryCallback(telemetryService),
);

// Snapshots will automatically emit telemetry
await snapshotManager.createSnapshot(
  documentId: 'doc-123',
  eventSequence: 1000,
  document: currentDocument,
);
```

### Replay Instrumentation

```dart
final replayTracker = createReplayMetricsTracker(telemetryService);

// In your replay loop:
for (final event in events) {
  await dispatcher.dispatch(event);
  replayTracker.recordEvent();
}
```

### Settings Integration

```dart
class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: ListView(
        children: [
          TelemetrySettingsSection(
            telemetryConfig: telemetryConfig,
            onConfigChanged: () async {
              await telemetryPrefs.saveConfig(telemetryConfig.toJson());
            },
          ),
          // Other settings sections...
        ],
      ),
    );
  }
}
```

## Testing

Comprehensive tests cover:

### Unit Tests
- `overlay_state.dart`: State serialization, position calculation, equality
- `overlay_preferences.dart`: Save/load, persistence, error handling
- `telemetry_integration.dart`: Callback forwarding, opt-out enforcement

### Widget Tests
- `performance_overlay.dart`: Visibility, drag behavior, metric display
- `telemetry_section.dart`: Toggle interaction, audit trail, visual feedback

### Integration Tests
- End-to-end telemetry flow (snapshot + replay)
- Opt-out enforcement across all components
- State persistence across restarts

Run tests:
```bash
flutter test packages/app/test/performance_overlay_test.dart
flutter test packages/app/test/telemetry_integration_test.dart
flutter test packages/app/test/telemetry_settings_test.dart
```

## NFR Compliance

### Performance (Section 3.6)
- ✅ Overlay renders in separate layer (no layout thrash)
- ✅ Metrics throttled to avoid excessive updates
- ✅ Frame budget: <1ms overhead per frame

### Telemetry (Section 3.6 & 4.7)
- ✅ Opt-out enforcement: No metrics collected when `enabled=false`
- ✅ Buffers cleared immediately on opt-out
- ✅ Structured JSON logs conform to shared schema
- ✅ Metric IDs match catalog: `performance.snapshot.ms`, `performance.event.replay.rate`
- ✅ Alert thresholds: snapshot >500ms, replay <5000 events/sec

### Observability (Section 3.6)
- ✅ FPS overlay uses stacked bars with gradient fill (per Section 1.7)
- ✅ Plex Mono font for numeric labels
- ✅ Color thresholds match spec (green/amber/red)
- ✅ Telemetry status visible in UI
- ✅ Audit trail for compliance verification

## Acceptance Criteria

- [x] **Overlay draggable/dockable**: Drag handle, visual dock zones, snap-to-corner
- [x] **Metrics cross-reference telemetry IDs**: Uses `MetricsCatalog` constants
- [x] **Opt-out disables emission**: `TelemetryGuard` enforces opt-out before collection
- [x] **Tests ensure state persistence**: Save/load round-trip tests, error handling

## Future Enhancements

- [ ] Customizable metric display (show/hide specific metrics)
- [ ] Export overlay metrics to CSV/JSON
- [ ] Heatmap visualization for event sampling (per Section 1.7)
- [ ] Undo/redo queue inspector integration (per Section 1.7)
- [ ] GPU resource fallback notifications (per Section 4.7)

## References

- **Architecture**: `.codemachine/artifacts/architecture/04_Operational_Architecture.md` (Section 3.6)
- **UI/UX Spec**: `.codemachine/artifacts/architecture/06_UI_UX_Architecture.md` (Sections 1.7, 4.7)
- **Task Spec**: `.codemachine/artifacts/plan/02_Iteration_I3.md` (Task 3.6)
- **Dependencies**: Task `I2.T6` (Telemetry opt-out enforcement)
