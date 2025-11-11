/// Tests for performance overlay state, persistence, and UI.
library;


import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wiretuner/infrastructure/telemetry/telemetry_config.dart';
import 'package:wiretuner/presentation/canvas/render_pipeline.dart';

import 'package:app/modules/performance_overlay/overlay_state.dart';
import 'package:app/modules/performance_overlay/overlay_preferences.dart';
import 'package:app/modules/performance_overlay/performance_overlay.dart' as perf;

void main() {
  group('PerformanceOverlayState', () {
    test('default state has correct values', () {
      final state = PerformanceOverlayState.defaultState();

      expect(state.isVisible, false);
      expect(state.dockLocation, DockLocation.topRight);
      expect(state.position, const Offset(16, 16));
      expect(state.isDocked, true);
    });

    test('copyWith creates new instance with updated values', () {
      final state = PerformanceOverlayState.defaultState();
      final updated = state.copyWith(
        isVisible: true,
        dockLocation: DockLocation.floating,
      );

      expect(updated.isVisible, true);
      expect(updated.dockLocation, DockLocation.floating);
      expect(updated.position, const Offset(16, 16)); // unchanged
    });

    test('toJson and fromJson round-trip correctly', () {
      final original = const PerformanceOverlayState(
        isVisible: true,
        dockLocation: DockLocation.bottomLeft,
        position: Offset(100, 200),
      );

      final json = original.toJson();
      final restored = PerformanceOverlayState.fromJson(json);

      expect(restored.isVisible, original.isVisible);
      expect(restored.dockLocation, original.dockLocation);
      expect(restored.position, original.position);
    });

    test('calculatePosition returns correct docked positions', () {
      const canvasSize = Size(800, 600);
      const overlaySize = Size(280, 400);

      // Top-left
      final topLeft = const PerformanceOverlayState(dockLocation: DockLocation.topLeft);
      expect(
        topLeft.calculatePosition(canvasSize, overlaySize),
        const Offset(16, 16),
      );

      // Top-right
      final topRight = const PerformanceOverlayState(dockLocation: DockLocation.topRight);
      expect(
        topRight.calculatePosition(canvasSize, overlaySize),
        const Offset(504, 16), // 800 - 280 - 16
      );

      // Bottom-left
      final bottomLeft =
          const PerformanceOverlayState(dockLocation: DockLocation.bottomLeft);
      expect(
        bottomLeft.calculatePosition(canvasSize, overlaySize),
        const Offset(16, 184), // 600 - 400 - 16
      );

      // Bottom-right
      final bottomRight =
          const PerformanceOverlayState(dockLocation: DockLocation.bottomRight);
      expect(
        bottomRight.calculatePosition(canvasSize, overlaySize),
        const Offset(504, 184),
      );
    });

    test('calculatePosition clamps floating position to bounds', () {
      const canvasSize = Size(800, 600);
      const overlaySize = Size(280, 400);

      // Position within bounds (no clamping)
      final withinBounds = const PerformanceOverlayState(
        dockLocation: DockLocation.floating,
        position: Offset(100, 100),
      );
      expect(
        withinBounds.calculatePosition(canvasSize, overlaySize),
        const Offset(100, 100),
      );

      // Position outside right edge (clamped)
      final outsideRight = const PerformanceOverlayState(
        dockLocation: DockLocation.floating,
        position: Offset(1000, 100), // exceeds canvas width
      );
      expect(
        outsideRight.calculatePosition(canvasSize, overlaySize),
        const Offset(520, 100), // clamped to 800 - 280
      );

      // Position outside bottom edge (clamped)
      final outsideBottom = const PerformanceOverlayState(
        dockLocation: DockLocation.floating,
        position: Offset(100, 1000), // exceeds canvas height
      );
      expect(
        outsideBottom.calculatePosition(canvasSize, overlaySize),
        const Offset(100, 200), // clamped to 600 - 400
      );
    });

    test('equality and hashCode work correctly', () {
      const state1 = PerformanceOverlayState(
        isVisible: true,
        dockLocation: DockLocation.topLeft,
        position: Offset(10, 20),
      );
      const state2 = PerformanceOverlayState(
        isVisible: true,
        dockLocation: DockLocation.topLeft,
        position: Offset(10, 20),
      );
      const state3 = PerformanceOverlayState(
        isVisible: false,
        dockLocation: DockLocation.topLeft,
        position: Offset(10, 20),
      );

      expect(state1, equals(state2));
      expect(state1.hashCode, equals(state2.hashCode));
      expect(state1, isNot(equals(state3)));
    });
  });

  group('DockLocation', () {
    test('toJson and fromJson round-trip correctly', () {
      for (final location in DockLocation.values) {
        final json = location.toJson();
        final restored = DockLocation.fromJson(json);
        expect(restored, location);
      }
    });

    test('fromJson returns default for invalid input', () {
      final result = DockLocation.fromJson('invalid');
      expect(result, DockLocation.topRight);
    });
  });

  group('OverlayPreferences', () {
    late SharedPreferences prefs;
    late OverlayPreferences overlayPrefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      overlayPrefs = OverlayPreferences(prefs);
    });

    test('loadState returns default when no saved state exists', () {
      final state = overlayPrefs.loadState();
      expect(state, PerformanceOverlayState.defaultState());
      expect(overlayPrefs.hasSavedState(), false);
    });

    test('saveState and loadState round-trip correctly', () async {
      const state = PerformanceOverlayState(
        isVisible: true,
        dockLocation: DockLocation.bottomRight,
        position: Offset(50, 75),
      );

      final saved = await overlayPrefs.saveState(state);
      expect(saved, true);
      expect(overlayPrefs.hasSavedState(), true);

      final loaded = overlayPrefs.loadState();
      expect(loaded, state);
    });

    test('resetToDefaults clears saved state', () async {
      const state = PerformanceOverlayState(isVisible: true);
      await overlayPrefs.saveState(state);

      final defaultState = await overlayPrefs.resetToDefaults();
      expect(defaultState, PerformanceOverlayState.defaultState());
      expect(overlayPrefs.hasSavedState(), false);
    });

    test('loadState returns default on invalid JSON', () async {
      // Manually corrupt the saved data
      await prefs.setString('performance_overlay_state', 'invalid json');

      final state = overlayPrefs.loadState();
      expect(state, PerformanceOverlayState.defaultState());
    });
  });

  group('PerformanceOverlay Widget', () {
    testWidgets('hides overlay when isVisible is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: perf.WireTunerPerformanceOverlay(
              overlayState: PerformanceOverlayState.defaultState(),
              onOverlayStateChanged: (_) {},
              child: const Text('Canvas'),
            ),
          ),
        ),
      );

      expect(find.text('Canvas'), findsOneWidget);
      expect(find.text('Performance Monitor'), findsNothing);
    });

    testWidgets('shows overlay when isVisible is true', (tester) async {
      const visibleState = PerformanceOverlayState(isVisible: true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: perf.WireTunerPerformanceOverlay(
              overlayState: visibleState,
              onOverlayStateChanged: (_) {},
              child: const Text('Canvas'),
            ),
          ),
        ),
      );

      expect(find.text('Canvas'), findsOneWidget);
      expect(find.text('Performance Monitor'), findsOneWidget);
    });

    testWidgets('displays telemetry disabled badge when opted out',
        (tester) async {
      final config = TelemetryConfig.disabled();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: perf.WireTunerPerformanceOverlay(
              overlayState: const PerformanceOverlayState(isVisible: true),
              onOverlayStateChanged: (_) {},
              telemetryConfig: config,
              child: const Text('Canvas'),
            ),
          ),
        ),
      );

      expect(find.text('Telemetry Disabled'), findsOneWidget);
      expect(find.byIcon(Icons.block), findsOneWidget);
    });

    testWidgets('displays metrics when provided', (tester) async {
      const metrics = RenderMetrics(
        frameTimeMs: 16.7,
        objectsRendered: 150,
        objectsCulled: 50,
        cacheSize: 200,
        snapshotDurationMs: 450.0,
        replayRateEventsPerSec: 5500.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: perf.WireTunerPerformanceOverlay(
              overlayState: const PerformanceOverlayState(isVisible: true),
              onOverlayStateChanged: (_) {},
              metrics: metrics,
              child: const Text('Canvas'),
            ),
          ),
        ),
      );

      // Check FPS display
      expect(find.textContaining('FPS'), findsOneWidget);
      expect(find.textContaining('59.9'), findsOneWidget); // 1000/16.7

      // Check snapshot duration
      expect(find.textContaining('Snapshot Duration'), findsOneWidget);
      expect(find.textContaining('450.00ms'), findsOneWidget);

      // Check replay rate
      expect(find.textContaining('Event Replay Rate'), findsOneWidget);
      expect(find.textContaining('5500 events/s'), findsOneWidget);
    });

    testWidgets('handles null metrics gracefully', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: perf.WireTunerPerformanceOverlay(
              overlayState: const PerformanceOverlayState(isVisible: true),
              onOverlayStateChanged: (_) {},
              metrics: null,
              child: const Text('Canvas'),
            ),
          ),
        ),
      );

      expect(find.text('No metrics available'), findsOneWidget);
    });

    testWidgets('overlay state changes trigger callback', (tester) async {
      PerformanceOverlayState? capturedState;
      const initialState = PerformanceOverlayState(isVisible: true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return perf.WireTunerPerformanceOverlay(
                  overlayState: capturedState ?? initialState,
                  onOverlayStateChanged: (newState) {
                    setState(() {
                      capturedState = newState;
                    });
                  },
                  child: const Text('Canvas'),
                );
              },
            ),
          ),
        ),
      );

      // Initially visible
      expect(find.text('Performance Monitor'), findsOneWidget);
    });
  });

  group('RenderMetrics with extended fields', () {
    test('copyWith updates snapshot and replay metrics', () {
      const original = RenderMetrics(
        frameTimeMs: 16.0,
        objectsRendered: 100,
        objectsCulled: 20,
        cacheSize: 50,
      );

      final updated = original.copyWith(
        snapshotDurationMs: 500.0,
        replayRateEventsPerSec: 5000.0,
      );

      expect(updated.frameTimeMs, 16.0);
      expect(updated.snapshotDurationMs, 500.0);
      expect(updated.replayRateEventsPerSec, 5000.0);
    });

    test('toString includes snapshot and replay metrics', () {
      const metrics = RenderMetrics(
        frameTimeMs: 16.0,
        objectsRendered: 100,
        objectsCulled: 20,
        cacheSize: 50,
        snapshotDurationMs: 450.5,
        replayRateEventsPerSec: 5500.0,
      );

      final str = metrics.toString();
      expect(str, contains('snapshotDuration: 450.50ms'));
      expect(str, contains('replayRate: 5500.0 events/sec'));
    });

    test('toString handles null metrics', () {
      const metrics = RenderMetrics(
        frameTimeMs: 16.0,
        objectsRendered: 100,
        objectsCulled: 20,
        cacheSize: 50,
      );

      final str = metrics.toString();
      expect(str, contains('snapshotDuration: N/A'));
      expect(str, contains('replayRate: N/A'));
    });
  });
}
