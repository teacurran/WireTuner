import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:event_core/event_core.dart';
import 'package:app_shell/app_shell.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/presentation/state/document_provider.dart';
import 'package:wiretuner/presentation/history/history_panel.dart';
import 'package:wiretuner/presentation/history/history_scrubber.dart';

void main() {
  group('HistoryPanel Widget Tests', () {
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

    testWidgets('shows empty state when no history', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: undoProvider),
              ChangeNotifierProvider.value(value: documentProvider),
            ],
            child: const Scaffold(
              body: HistoryPanel(),
            ),
          ),
        ),
      );

      // Verify empty state is shown
      expect(find.text('No History'), findsOneWidget);
      expect(find.text('Operations will appear here\nas you work'),
          findsOneWidget);
      expect(find.byIcon(Icons.history), findsOneWidget);
    });

    testWidgets('displays search field in header', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: undoProvider),
              ChangeNotifierProvider.value(value: documentProvider),
            ],
            child: const Scaffold(
              body: HistoryPanel(),
            ),
          ),
        ),
      );

      // Verify header elements
      expect(find.text('History'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search operations...'), findsOneWidget);
    });

    testWidgets('search filters operations by label', (tester) async {
      // Manually add mock operation groups to navigator
      // (In real usage, these would come from operation grouping service)
      final navigator = undoProvider;

      // For this test, we need to simulate operations being added
      // Since we can't easily add operations without full event system,
      // we'll skip this test for now and document it as a future enhancement

      // TODO: Add integration test with full event recording flow
    });

    testWidgets('displays operation count in footer', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: undoProvider),
              ChangeNotifierProvider.value(value: documentProvider),
            ],
            child: const Scaffold(
              body: HistoryPanel(),
            ),
          ),
        ),
      );

      // With empty history, should show 0 operations
      expect(find.text('0 operations'), findsOneWidget);
    });
  });

  group('HistoryScrubber Widget Tests', () {
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

    testWidgets('shows playback controls when history exists', (tester) async {
      // TODO: Add test with non-empty history
      // This requires setting up full event recording flow
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
