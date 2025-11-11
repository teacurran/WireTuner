# Integration Guide: Performance Overlay & Telemetry

This guide shows how to integrate the performance overlay and telemetry instrumentation into your application.

## Quick Start

### 1. Add Dependencies to pubspec.yaml

```yaml
dependencies:
  shared_preferences: ^2.2.2
  # Other existing dependencies...
```

### 2. Initialize Services

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wiretuner/infrastructure/telemetry/telemetry_config.dart';
import 'package:wiretuner/infrastructure/telemetry/telemetry_service.dart';
import 'package:wiretuner_app/modules/performance_overlay/overlay_preferences.dart';
import 'package:wiretuner_app/modules/performance_overlay/overlay_state.dart';
import 'package:wiretuner_app/modules/performance_overlay/telemetry_integration.dart';

class AppServices {
  late final SharedPreferences sharedPreferences;
  late final TelemetryConfig telemetryConfig;
  late final TelemetryService telemetryService;
  late final OverlayPreferences overlayPreferences;
  late final TelemetryPreferences telemetryPreferences;

  Future<void> initialize() async {
    // Initialize SharedPreferences
    sharedPreferences = await SharedPreferences.getInstance();

    // Initialize telemetry preferences
    telemetryPreferences = TelemetryPreferences(sharedPreferences);
    final savedConfig = telemetryPreferences.loadConfig();

    // Initialize telemetry config (load from prefs or use debug defaults)
    telemetryConfig = savedConfig != null
        ? TelemetryConfig.fromJson(savedConfig)
        : TelemetryConfig.debug();

    // Initialize telemetry service
    telemetryService = TelemetryService(
      config: telemetryConfig,
      verbose: false,
    );

    // Initialize overlay preferences
    overlayPreferences = OverlayPreferences(sharedPreferences);
  }

  Future<void> dispose() async {
    telemetryService.dispose();
  }
}
```

### 3. Wire Into Main App

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  final services = AppServices();
  await services.initialize();

  runApp(MyApp(services: services));
}

class MyApp extends StatelessWidget {
  const MyApp({required this.services, super.key});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MainScreen(services: services),
    );
  }
}
```

### 4. Add Overlay to Canvas

```dart
class MainScreen extends StatefulWidget {
  const MainScreen({required this.services, super.key});

  final AppServices services;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late OverlayState _overlayState;

  @override
  void initState() {
    super.initState();
    _overlayState = widget.services.overlayPreferences.loadState();
  }

  Future<void> _onOverlayStateChanged(OverlayState newState) async {
    setState(() {
      _overlayState = newState;
    });
    await widget.services.overlayPreferences.saveState(newState);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PerformanceOverlayWrapper(
        initialState: _overlayState,
        onStateChanged: _onOverlayStateChanged,
        metrics: renderPipeline.lastMetrics, // Your RenderPipeline instance
        viewportController: viewportController, // Your ViewportController
        telemetryConfig: widget.services.telemetryConfig,
        child: WireTunerCanvas(
          // Your canvas implementation
        ),
      ),
    );
  }
}
```

### 5. Add Settings Page

```dart
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.services, super.key});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          TelemetrySettingsSection(
            telemetryConfig: services.telemetryConfig,
            onConfigChanged: () async {
              await services.telemetryPreferences
                  .saveConfig(services.telemetryConfig.toJson());
            },
          ),
          // Other settings sections...
        ],
      ),
    );
  }
}
```

## Instrumentation Integration

### Snapshot Telemetry

When creating your `SnapshotManager`, add the telemetry callback:

```dart
import 'package:wiretuner_app/modules/performance_overlay/telemetry_integration.dart';

final snapshotManager = SnapshotManager(
  snapshotStore: snapshotStore,
  snapshotFrequency: 1000,
  onSnapshotCreated: createSnapshotTelemetryCallback(
    services.telemetryService,
  ),
);

// Snapshots will now automatically emit telemetry
await snapshotManager.createSnapshot(
  documentId: documentId,
  eventSequence: eventCount,
  document: currentDocument,
);
```

### Replay Telemetry

When replaying events, track throughput:

```dart
import 'package:wiretuner_app/modules/performance_overlay/telemetry_integration.dart';

class EventReplayService {
  EventReplayService({required TelemetryService telemetryService})
      : _replayTracker = createReplayMetricsTracker(telemetryService);

  final ReplayMetricsTracker _replayTracker;

  Future<void> replay(List<Event> events) async {
    for (final event in events) {
      await _dispatcher.dispatch(event);
      _replayTracker.recordEvent(); // Track each event replayed
    }
  }
}
```

### Updating Metrics in Real-Time

To update the overlay with snapshot/replay metrics, extend your metrics source:

```dart
class MetricsAggregator {
  RenderMetrics? _currentMetrics;
  double? _lastSnapshotDuration;
  double? _lastReplayRate;

  // Called by RenderPipeline
  void updateRenderMetrics(RenderMetrics metrics) {
    _currentMetrics = metrics.copyWith(
      snapshotDurationMs: _lastSnapshotDuration,
      replayRateEventsPerSec: _lastReplayRate,
    );
    notifyListeners(); // If using ChangeNotifier
  }

  // Called by snapshot telemetry callback
  void updateSnapshotDuration(double durationMs) {
    _lastSnapshotDuration = durationMs;
    if (_currentMetrics != null) {
      _currentMetrics = _currentMetrics!.copyWith(
        snapshotDurationMs: durationMs,
      );
      notifyListeners();
    }
  }

  // Called by replay tracker
  void updateReplayRate(double eventsPerSec) {
    _lastReplayRate = eventsPerSec;
    if (_currentMetrics != null) {
      _currentMetrics = _currentMetrics!.copyWith(
        replayRateEventsPerSec: eventsPerSec,
      );
      notifyListeners();
    }
  }

  RenderMetrics? get currentMetrics => _currentMetrics;
}
```

## Advanced Configuration

### Custom Dock Zone Size

Modify dock zone detection sensitivity:

```dart
// In _DraggablePerformancePanelState._detectDockZone():
const dockZoneSize = 100.0; // Increase from default 80.0 for easier docking
```

### Custom Telemetry Sampling

```dart
final telemetryConfig = TelemetryConfig.production(
  enabled: true,
  collectorEndpoint: 'https://telemetry.example.com',
  samplingRate: 0.1, // 10% sampling in production
);
```

### Custom Overlay Initial State

```dart
final customState = OverlayState(
  isVisible: true, // Start visible
  dockLocation: DockLocation.bottomLeft, // Custom dock location
  position: Offset(20, 20), // Custom position when floating
);
```

### Telemetry Callback Composition

If you need to perform additional actions when metrics are recorded:

```dart
final composedCallback = ({
  required String documentId,
  required int eventSequence,
  required int uncompressedSize,
  required int compressedSize,
  required double compressionRatio,
  required int durationMs,
}) {
  // Forward to telemetry service
  telemetryService.recordSnapshotMetric(
    durationMs: durationMs,
    compressionRatio: compressionRatio,
    documentId: documentId,
  );

  // Custom logic (e.g., update UI, log to console)
  print('Snapshot created: ${durationMs}ms, ${compressionRatio}x compression');
  metricsAggregator.updateSnapshotDuration(durationMs.toDouble());
};
```

## Testing Your Integration

### Manual Testing Checklist

1. **Overlay Visibility**
   - [ ] Press `Cmd/Ctrl+Shift+P` to toggle overlay
   - [ ] Overlay appears in top-right by default
   - [ ] Metrics display FPS, frame time, and object counts

2. **Drag and Dock**
   - [ ] Click and drag overlay to move it
   - [ ] Drag near corners to see dock zone indicators
   - [ ] Release near corner to snap-dock overlay
   - [ ] Drag to center and release to keep floating

3. **Telemetry Settings**
   - [ ] Open settings page
   - [ ] Toggle telemetry on/off
   - [ ] Verify overlay shows "Telemetry Disabled" badge when off
   - [ ] Expand audit trail to see state change history

4. **State Persistence**
   - [ ] Position overlay in custom location
   - [ ] Restart app
   - [ ] Verify overlay returns to same position

5. **Metrics Display**
   - [ ] Verify FPS is green when >50, yellow when 30-50, red when <30
   - [ ] Verify frame time is green when <16ms, yellow when <33ms, red when >33ms
   - [ ] Trigger snapshot creation, verify duration appears in overlay
   - [ ] Start event replay, verify replay rate appears in overlay

### Automated Testing

Add integration tests:

```dart
testWidgets('overlay persists state across restarts', (tester) async {
  final services = AppServices();
  await services.initialize();

  // Initial state
  await tester.pumpWidget(MyApp(services: services));
  await tester.pumpAndSettle();

  // Change overlay position (simulate drag)
  // ... drag gestures ...

  // Verify state persisted
  final savedState = services.overlayPreferences.loadState();
  expect(savedState.position, expectedPosition);
});
```

## Troubleshooting

### Overlay Not Visible
- Check that `overlayState.isVisible` is `true`
- Verify overlay is not positioned off-screen
- Check z-index/Stack ordering

### Metrics Not Updating
- Ensure `RenderPipeline.lastMetrics` is being updated each frame
- Verify metrics object is passed to `PerformanceOverlayWrapper`
- Check that widget is rebuilding when metrics change

### Telemetry Not Recording
- Verify `TelemetryConfig.enabled` is `true`
- Check that callbacks are wired correctly
- Enable verbose logging: `TelemetryService(verbose: true)`
- Inspect console for structured log output

### State Not Persisting
- Ensure `SharedPreferences` is initialized before loading state
- Verify `onStateChanged` callback is wired to save method
- Check SharedPreferences permissions on platform

### Drag Not Working
- Verify `GestureDetector` is receiving events
- Check for conflicting gesture recognizers in parent widgets
- Ensure overlay has sufficient size for hit testing

## Performance Tips

1. **Throttle Metrics Updates**: Update overlay at 60fps max, not every frame
2. **Use RepaintBoundary**: Wrap overlay to isolate repaints
3. **Lazy Load Settings**: Only load telemetry preferences when settings page opens
4. **Batch Replay Tracking**: Use `recordEvents(count)` instead of individual `recordEvent()` calls
5. **Disable Verbose Logging**: Set `verbose: false` in production builds

## Further Reading

- Module README: `packages/app/lib/modules/performance_overlay/README.md`
- Architecture Docs: `.codemachine/artifacts/architecture/04_Operational_Architecture.md`
- UI/UX Spec: `.codemachine/artifacts/architecture/06_UI_UX_Architecture.md`
- Telemetry Opt-Out Tests: `test/infrastructure/telemetry/telemetry_opt_out_test.dart`
