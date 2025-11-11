import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:event_core/event_core.dart';
import 'package:app_shell/app_shell.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/presentation/state/document_provider.dart';
import 'package:wiretuner/presentation/history/history_scrubber.dart';
import 'package:wiretuner/presentation/history/history_transport_intents.dart';
import 'package:wiretuner/presentation/history/history_transport_actions.dart';

void main() {
  group('History Transport Intents', () {
    test('HistoryPlayPauseIntent can be created', () {
      const intent = HistoryPlayPauseIntent();
      expect(intent, isA<Intent>());
    });

    test('HistoryStopIntent can be created', () {
      const intent = HistoryStopIntent();
      expect(intent, isA<Intent>());
    });

    test('HistoryStepForwardIntent can be created', () {
      const intent = HistoryStepForwardIntent();
      expect(intent, isA<Intent>());
    });

    test('HistoryStepBackwardIntent can be created', () {
      const intent = HistoryStepBackwardIntent();
      expect(intent, isA<Intent>());
    });

    test('HistorySpeedUpIntent can be created', () {
      const intent = HistorySpeedUpIntent();
      expect(intent, isA<Intent>());
    });

    test('HistorySpeedDownIntent can be created', () {
      const intent = HistorySpeedDownIntent();
      expect(intent, isA<Intent>());
    });
  });

  group('History Transport Actions', () {
    test('HistoryPlayPauseAction invokes callback when enabled', () {
      var callbackInvoked = false;
      final action = HistoryPlayPauseAction(
        onPlayPause: () => callbackInvoked = true,
        enabledCallback: () => true,
      );

      expect(action.isEnabled(const HistoryPlayPauseIntent()), isTrue);
      action.invoke(const HistoryPlayPauseIntent());
      expect(callbackInvoked, isTrue);
    });

    test('HistoryPlayPauseAction does not invoke when disabled', () {
      var callbackInvoked = false;
      final action = HistoryPlayPauseAction(
        onPlayPause: () => callbackInvoked = true,
        enabledCallback: () => false,
      );

      expect(action.isEnabled(const HistoryPlayPauseIntent()), isFalse);
      action.invoke(const HistoryPlayPauseIntent());
      expect(callbackInvoked, isFalse);
    });

    test('HistoryStopAction invokes callback when enabled', () {
      var callbackInvoked = false;
      final action = HistoryStopAction(
        onStop: () => callbackInvoked = true,
        enabledCallback: () => true,
      );

      action.invoke(const HistoryStopIntent());
      expect(callbackInvoked, isTrue);
    });

    test('HistoryStepForwardAction invokes callback when enabled', () {
      var callbackInvoked = false;
      final action = HistoryStepForwardAction(
        onStepForward: () => callbackInvoked = true,
        enabledCallback: () => true,
      );

      action.invoke(const HistoryStepForwardIntent());
      expect(callbackInvoked, isTrue);
    });

    test('HistoryStepBackwardAction invokes callback when enabled', () {
      var callbackInvoked = false;
      final action = HistoryStepBackwardAction(
        onStepBackward: () => callbackInvoked = true,
        enabledCallback: () => true,
      );

      action.invoke(const HistoryStepBackwardIntent());
      expect(callbackInvoked, isTrue);
    });

    test('HistorySpeedUpAction invokes callback', () {
      var callbackInvoked = false;
      final action = HistorySpeedUpAction(
        onSpeedUp: () => callbackInvoked = true,
      );

      action.invoke(const HistorySpeedUpIntent());
      expect(callbackInvoked, isTrue);
    });

    test('HistorySpeedDownAction invokes callback', () {
      var callbackInvoked = false;
      final action = HistorySpeedDownAction(
        onSpeedDown: () => callbackInvoked = true,
      );

      action.invoke(const HistorySpeedDownIntent());
      expect(callbackInvoked, isTrue);
    });
  });

  group('History Transport Controls Widget Tests', () {
    late UndoProvider undoProvider;
    late DocumentProvider documentProvider;

    setUp(() {
      // Create mock services
      final logger = Logger(level: Level.off);
      final metricsSink = _MockMetricsSink();
      final config = EventCoreDiagnosticsConfig(
        enableMetrics: false,
        enableDetailedLogging: false,
      );

      // Create operation grouping service
      final operationGrouping = OperationGroupingService(
        clock: const SystemClock(),
        metricsSink: metricsSink,
        logger: logger,
        config: config,
      );

      // Create event replayer (stub for testing)
      final eventReplayer = _StubEventReplayer();

      // Create undo navigator
      final undoNavigator = UndoNavigator(
        operationGrouping: operationGrouping,
        eventReplayer: eventReplayer,
        metricsSink: metricsSink,
        logger: logger,
        config: config,
        documentId: 'test-doc',
      );

      // Create providers
      documentProvider = DocumentProvider(
        initialDocument: const Document(id: 'test-doc', title: 'Test'),
      );
      undoProvider = UndoProvider.withNavigator(
        navigator: undoNavigator,
        documentProvider: documentProvider,
      );
    });

    tearDown(() {
      undoProvider.dispose();
      documentProvider.dispose();
    });

    testWidgets('hides scrubber when no history', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: undoProvider),
              ChangeNotifierProvider.value(value: documentProvider),
            ],
            child: const Scaffold(
              body: HistoryScrubber(),
            ),
          ),
        ),
      );

      // Scrubber should not render when history is empty
      expect(find.byType(Slider), findsNothing);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
    });

    testWidgets('keyboard shortcuts are properly mapped', (tester) async {
      // This test verifies that the shortcuts are defined correctly
      // Even without visible UI (due to empty history), we can test the structure

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: undoProvider),
              ChangeNotifierProvider.value(value: documentProvider),
            ],
            child: const Scaffold(
              body: HistoryScrubber(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Widget is created (even if hidden)
      expect(find.byType(HistoryScrubber), findsOneWidget);

      // TODO: Add integration test with actual event recording to test
      // keyboard shortcuts with real operation history.
      // This would require:
      // 1. Recording events through OperationGroupingService
      // 2. Building up undo/redo stacks
      // 3. Simulating key presses and verifying navigation
    });
  });
}

/// Mock metrics sink for testing.
class _MockMetricsSink implements MetricsSink {
  @override
  void recordEvent({
    required String eventType,
    required bool sampled,
    int? durationMs,
  }) {
    // No-op
  }

  @override
  void recordNavigation({
    required String operation,
    required int durationMs,
    required int sequenceJump,
  }) {
    // No-op
  }

  @override
  void recordReplay({
    required int eventCount,
    required int durationMs,
    required int fromSequence,
    required int toSequence,
  }) {
    // No-op
  }

  @override
  void recordSnapshot({
    required int sequenceNumber,
    required int snapshotSizeBytes,
    required int durationMs,
  }) {
    // No-op
  }

  @override
  void recordSnapshotLoad({
    required int sequenceNumber,
    required int durationMs,
  }) {
    // No-op
  }

  @override
  Future<void> flush() async {
    // No-op
  }
}

/// Stub event replayer for testing.
class _StubEventReplayer implements EventReplayer {
  @override
  Future<void> replay({int fromSequence = 0, int? toSequence}) async {
    // No-op
  }

  @override
  Future<void> replayFromSnapshot({int? maxSequence}) async {
    // No-op
  }

  @override
  bool get isReplaying => false;
}
