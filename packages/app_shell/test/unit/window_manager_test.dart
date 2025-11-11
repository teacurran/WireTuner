import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:event_core/event_core.dart';
import 'package:wiretuner/domain/document/document.dart';

import 'package:app_shell/src/window/window_manager.dart';

/// Tests for multi-window coordination and lifecycle management.
///
/// Validates window registry, lifecycle hooks, resource isolation,
/// and cleanup guarantees per Task I4.T7 acceptance criteria.
///
/// **Test Coverage:**
/// - Opening multiple windows creates isolated undo stacks
/// - Closing a window releases resources (no leaks)
/// - Same document in multiple windows has independent state
/// - Lifecycle hooks fire correctly
/// - Tests simulate 3 windows per acceptance criteria

/// Fake metrics sink for testing.
class FakeMetricsSink implements MetricsSink {
  final List<Map<String, dynamic>> recordedEvents = [];

  @override
  void recordEvent({
    required String eventType,
    required bool sampled,
    int? durationMs,
  }) {
    recordedEvents.add({
      'eventType': eventType,
      'sampled': sampled,
      'durationMs': durationMs,
    });
  }

  @override
  void recordReplay({
    required int eventCount,
    required int fromSequence,
    required int toSequence,
    required int durationMs,
  }) {}

  @override
  void recordSnapshot({
    required int sequenceNumber,
    required int snapshotSizeBytes,
    required int durationMs,
  }) {}

  @override
  void recordSnapshotLoad({
    required int sequenceNumber,
    required int durationMs,
  }) {}

  @override
  Future<void> flush() async {}

  void reset() {
    recordedEvents.clear();
  }
}

/// Fake operation grouping service for testing.
class FakeOperationGrouping extends Observable
    implements OperationGroupingService {
  final List<OperationGroup> _completedGroups = [];

  OperationGroup? get lastCompletedGroup =>
      _completedGroups.isEmpty ? null : _completedGroups.last;

  List<OperationGroup> get completedGroups => List.unmodifiable(_completedGroups);

  int get currentOperationEventCount => 0;

  bool get isOperationActive => false;

  int get idleThresholdMs => 500;

  bool get hasActiveGroup => false;

  @override
  void beginOperation(String label) {}

  @override
  void endOperation() {}

  @override
  void recordEvent(int eventSequence) {}

  @override
  void onEventRecorded(EventMetadata metadata) {}

  @override
  String startUndoGroup({required String label, String? toolId}) => 'group-id';

  @override
  void endUndoGroup({required String groupId, required String label}) {}

  @override
  void cancelOperation() {}

  @override
  void forceBoundary({String? label, required String reason}) {}

  void simulateCompletedOperation(OperationGroup group) {
    _completedGroups.add(group);
    notifyListeners();
  }
}

/// Fake event replayer for testing.
class FakeEventReplayer implements EventReplayer {
  final List<int?> replayedSequences = [];

  @override
  bool get isReplaying => false;

  @override
  Future<void> replay({
    int fromSequence = 0,
    int? toSequence,
  }) async {
    replayedSequences.add(toSequence);
  }

  @override
  Future<void> replayFromSnapshot({
    int? maxSequence,
  }) async {
    replayedSequences.add(maxSequence);
  }

  void reset() {
    replayedSequences.clear();
  }
}

/// Fake clock for deterministic testing.
class FakeClock implements Clock {
  FakeClock(this._currentTime);

  int _currentTime;

  @override
  int now() => _currentTime;

  void advance(int ms) {
    _currentTime += ms;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WindowManager', () {
    late WindowManager windowManager;
    late Logger logger;
    late FakeOperationGrouping operationGrouping;
    late FakeEventReplayer eventReplayer;
    late EventCoreDiagnosticsConfig diagnosticsConfig;

    setUp(() {
      logger = Logger(
        level: Level.info,
      );

      diagnosticsConfig = EventCoreDiagnosticsConfig.debug();

      windowManager = WindowManager(
        logger: logger,
        diagnosticsConfig: diagnosticsConfig,
      );

      operationGrouping = FakeOperationGrouping();
      eventReplayer = FakeEventReplayer();
    });

    tearDown(() async {
      await windowManager.dispose();
    });

    group('Window Lifecycle', () {
      test('opening window creates isolated scope', () async {
        final windowScope = await windowManager.openWindow(
          documentId: 'doc-1',
          operationGrouping: operationGrouping,
          eventReplayer: eventReplayer,
        );

        expect(windowScope.windowId, isNotEmpty);
        expect(windowScope.documentId, equals('doc-1'));
        expect(windowScope.documentProvider, isNotNull);
        expect(windowScope.undoProvider, isNotNull);
        expect(windowScope.undoNavigator, isNotNull);
        expect(windowScope.metricsSink, isNotNull);
        expect(windowScope.logger, isNotNull);

        expect(windowManager.windowCount, equals(1));
        expect(windowManager.hasOpenWindows, isTrue);
      });

      test('closing window releases resources', () async {
        final windowScope = await windowManager.openWindow(
          documentId: 'doc-1',
          operationGrouping: operationGrouping,
          eventReplayer: eventReplayer,
        );

        final windowId = windowScope.windowId;

        expect(windowManager.windowCount, equals(1));

        final closed = await windowManager.closeWindow(windowId);

        expect(closed, isTrue);
        expect(windowManager.windowCount, equals(0));
        expect(windowManager.hasOpenWindows, isFalse);
        expect(windowManager.getWindow(windowId), isNull);
      });

      test('closing non-existent window returns false', () async {
        final closed = await windowManager.closeWindow('non-existent');

        expect(closed, isFalse);
        expect(windowManager.windowCount, equals(0));
      });

      test('closing window multiple times is idempotent', () async {
        final windowScope = await windowManager.openWindow(
          documentId: 'doc-1',
          operationGrouping: operationGrouping,
          eventReplayer: eventReplayer,
        );

        final windowId = windowScope.windowId;

        final closed1 = await windowManager.closeWindow(windowId);
        final closed2 = await windowManager.closeWindow(windowId);

        expect(closed1, isTrue);
        expect(closed2, isFalse);
        expect(windowManager.windowCount, equals(0));
      });
    });

    group('Multi-Window Isolation (3 Windows)', () {
      test('opening 3 windows creates isolated undo stacks', () async {
        // Open 3 windows for different documents
        final window1 = await windowManager.openWindow(
          documentId: 'doc-1',
          operationGrouping: operationGrouping,
          eventReplayer: eventReplayer,
        );

        final window2 = await windowManager.openWindow(
          documentId: 'doc-2',
          operationGrouping: operationGrouping,
          eventReplayer: eventReplayer,
        );

        final window3 = await windowManager.openWindow(
          documentId: 'doc-3',
          operationGrouping: operationGrouping,
          eventReplayer: eventReplayer,
        );

        expect(windowManager.windowCount, equals(3));

        // Verify each window has isolated undo navigator
        expect(window1.undoNavigator, isNot(equals(window2.undoNavigator)));
        expect(window2.undoNavigator, isNot(equals(window3.undoNavigator)));
        expect(window1.undoNavigator, isNot(equals(window3.undoNavigator)));

        // Verify each window has isolated document provider
        expect(window1.documentProvider, isNot(equals(window2.documentProvider)));
        expect(window2.documentProvider, isNot(equals(window3.documentProvider)));
        expect(window1.documentProvider, isNot(equals(window3.documentProvider)));

        // Verify window IDs are unique
        expect(window1.windowId, isNot(equals(window2.windowId)));
        expect(window2.windowId, isNot(equals(window3.windowId)));
        expect(window1.windowId, isNot(equals(window3.windowId)));
      });

      test('undo in one window does not affect other windows', () async {
        // Create separate operation grouping services per window
        // (In production, each document would have its own service)
        final operationGrouping1 = FakeOperationGrouping();
        final operationGrouping2 = FakeOperationGrouping();
        final operationGrouping3 = FakeOperationGrouping();

        // Open 3 windows with isolated operation grouping
        final window1 = await windowManager.openWindow(
          documentId: 'doc-1',
          operationGrouping: operationGrouping1,
          eventReplayer: eventReplayer,
        );

        final window2 = await windowManager.openWindow(
          documentId: 'doc-2',
          operationGrouping: operationGrouping2,
          eventReplayer: eventReplayer,
        );

        final window3 = await windowManager.openWindow(
          documentId: 'doc-3',
          operationGrouping: operationGrouping3,
          eventReplayer: eventReplayer,
        );

        // Simulate operation in window 1 only
        operationGrouping1.simulateCompletedOperation(
          OperationGroup(
            groupId: 'group-1',
            label: 'Create Path',
            startSequence: 1,
            endSequence: 10,
            startTimestamp: DateTime.now().millisecondsSinceEpoch,
            endTimestamp: DateTime.now().millisecondsSinceEpoch,
            eventCount: 10,
          ),
        );

        // Wait for listener notification
        await Future<void>.delayed(Duration.zero);

        // Verify only window 1 has undo available
        // (Other windows don't receive operations from window 1)
        expect(window1.undoNavigator.canUndo, isTrue);
        expect(window2.undoNavigator.canUndo, isFalse);
        expect(window3.undoNavigator.canUndo, isFalse);

        // Perform undo in window 1
        await window1.undoProvider.handleUndo();

        // Verify undo stacks are independent
        expect(window1.undoNavigator.canUndo, isFalse);
        expect(window1.undoNavigator.canRedo, isTrue);
        expect(window2.undoNavigator.canRedo, isFalse);
        expect(window3.undoNavigator.canRedo, isFalse);
      });

      test('closing one window does not affect other windows', () async {
        // Open 3 windows
        final window1 = await windowManager.openWindow(
          documentId: 'doc-1',
          operationGrouping: operationGrouping,
          eventReplayer: eventReplayer,
        );

        final window2 = await windowManager.openWindow(
          documentId: 'doc-2',
          operationGrouping: operationGrouping,
          eventReplayer: eventReplayer,
        );

        final window3 = await windowManager.openWindow(
          documentId: 'doc-3',
          operationGrouping: operationGrouping,
          eventReplayer: eventReplayer,
        );

        expect(windowManager.windowCount, equals(3));

        // Close window 2
        await windowManager.closeWindow(window2.windowId);

        // Verify window count
        expect(windowManager.windowCount, equals(2));

        // Verify remaining windows are accessible
        expect(windowManager.getWindow(window1.windowId), isNotNull);
        expect(windowManager.getWindow(window2.windowId), isNull);
        expect(windowManager.getWindow(window3.windowId), isNotNull);

        // Verify remaining windows still functional
        expect(window1.documentProvider, isNotNull);
        expect(window3.documentProvider, isNotNull);
      });

      test('closing all windows triggers cleanup hooks', () async {
        // Open 3 windows
        await windowManager.openWindow(
          documentId: 'doc-1',
          operationGrouping: operationGrouping,
          eventReplayer: eventReplayer,
        );

        await windowManager.openWindow(
          documentId: 'doc-2',
          operationGrouping: operationGrouping,
          eventReplayer: eventReplayer,
        );

        await windowManager.openWindow(
          documentId: 'doc-3',
          operationGrouping: operationGrouping,
          eventReplayer: eventReplayer,
        );

        expect(windowManager.windowCount, equals(3));

        // Close all windows
        await windowManager.closeAllWindows();

        expect(windowManager.windowCount, equals(0));
        expect(windowManager.hasOpenWindows, isFalse);
      });
    });

    group('Same Document in Multiple Windows', () {
      test('same document in 2 windows has isolated undo stacks', () async {
        const documentId = 'doc-shared';

        // Open same document in 2 windows
        final window1 = await windowManager.openWindow(
          documentId: documentId,
          operationGrouping: operationGrouping,
          eventReplayer: eventReplayer,
        );

        final window2 = await windowManager.openWindow(
          documentId: documentId,
          operationGrouping: operationGrouping,
          eventReplayer: eventReplayer,
        );

        expect(windowManager.windowCount, equals(2));

        // Verify both windows reference same document
        expect(window1.documentId, equals(documentId));
        expect(window2.documentId, equals(documentId));

        // Verify undo navigators are isolated
        expect(window1.undoNavigator, isNot(equals(window2.undoNavigator)));

        // Verify document providers are isolated
        expect(window1.documentProvider, isNot(equals(window2.documentProvider)));
      });

      test('getWindowsForDocument returns all windows for document', () async {
        const documentId = 'doc-shared';

        // Open same document in 3 windows
        final window1 = await windowManager.openWindow(
          documentId: documentId,
          operationGrouping: operationGrouping,
          eventReplayer: eventReplayer,
        );

        final window2 = await windowManager.openWindow(
          documentId: documentId,
          operationGrouping: operationGrouping,
          eventReplayer: eventReplayer,
        );

        final window3 = await windowManager.openWindow(
          documentId: 'doc-other',
          operationGrouping: operationGrouping,
          eventReplayer: eventReplayer,
        );

        final windowsForShared = windowManager.getWindowsForDocument(documentId);

        expect(windowsForShared.length, equals(2));
        expect(windowsForShared, contains(window1.windowId));
        expect(windowsForShared, contains(window2.windowId));
        expect(windowsForShared, isNot(contains(window3.windowId)));
      });
    });

    group('Lifecycle Hooks', () {
      test('onWindowCreated hook fires when window opens', () async {
        final createdWindows = <(WindowId, DocumentId)>[];

        windowManager.onWindowCreated((windowId, documentId) {
          createdWindows.add((windowId, documentId));
        });

        final window1 = await windowManager.openWindow(
          documentId: 'doc-1',
          operationGrouping: operationGrouping,
          eventReplayer: eventReplayer,
        );

        final window2 = await windowManager.openWindow(
          documentId: 'doc-2',
          operationGrouping: operationGrouping,
          eventReplayer: eventReplayer,
        );

        expect(createdWindows.length, equals(2));
        expect(createdWindows[0], equals((window1.windowId, 'doc-1')));
        expect(createdWindows[1], equals((window2.windowId, 'doc-2')));
      });

      test('onWindowClosed hook fires when window closes', () async {
        final closedWindows = <(WindowId, DocumentId)>[];

        windowManager.onWindowClosed((windowId, documentId) {
          closedWindows.add((windowId, documentId));
        });

        final window1 = await windowManager.openWindow(
          documentId: 'doc-1',
          operationGrouping: operationGrouping,
          eventReplayer: eventReplayer,
        );

        await windowManager.closeWindow(window1.windowId);

        expect(closedWindows.length, equals(1));
        expect(closedWindows[0], equals((window1.windowId, 'doc-1')));
      });

      test('onAllWindowsClosed hook fires when last window closes', () async {
        var allWindowsClosedCount = 0;

        windowManager.onAllWindowsClosed(() {
          allWindowsClosedCount++;
        });

        final window1 = await windowManager.openWindow(
          documentId: 'doc-1',
          operationGrouping: operationGrouping,
          eventReplayer: eventReplayer,
        );

        final window2 = await windowManager.openWindow(
          documentId: 'doc-2',
          operationGrouping: operationGrouping,
          eventReplayer: eventReplayer,
        );

        // Close first window - should not trigger hook
        await windowManager.closeWindow(window1.windowId);
        expect(allWindowsClosedCount, equals(0));

        // Close second window - should trigger hook
        await windowManager.closeWindow(window2.windowId);
        expect(allWindowsClosedCount, equals(1));
      });

      test('multiple hooks can be registered', () async {
        var hook1Fired = false;
        var hook2Fired = false;

        windowManager.onWindowCreated((windowId, documentId) {
          hook1Fired = true;
        });

        windowManager.onWindowCreated((windowId, documentId) {
          hook2Fired = true;
        });

        await windowManager.openWindow(
          documentId: 'doc-1',
          operationGrouping: operationGrouping,
          eventReplayer: eventReplayer,
        );

        expect(hook1Fired, isTrue);
        expect(hook2Fired, isTrue);
      });

      test('hook exceptions do not prevent other hooks from running', () async {
        var hook1Fired = false;
        var hook2Fired = false;

        windowManager.onWindowCreated((windowId, documentId) {
          hook1Fired = true;
          throw Exception('Hook 1 error');
        });

        windowManager.onWindowCreated((windowId, documentId) {
          hook2Fired = true;
        });

        await windowManager.openWindow(
          documentId: 'doc-1',
          operationGrouping: operationGrouping,
          eventReplayer: eventReplayer,
        );

        expect(hook1Fired, isTrue);
        expect(hook2Fired, isTrue);
      });
    });

    group('Resource Cleanup', () {
      test('disposing window manager closes all windows', () async {
        await windowManager.openWindow(
          documentId: 'doc-1',
          operationGrouping: operationGrouping,
          eventReplayer: eventReplayer,
        );

        await windowManager.openWindow(
          documentId: 'doc-2',
          operationGrouping: operationGrouping,
          eventReplayer: eventReplayer,
        );

        expect(windowManager.windowCount, equals(2));

        await windowManager.dispose();

        expect(windowManager.windowCount, equals(0));
      });

      test('closing window disposes providers', () async {
        final windowScope = await windowManager.openWindow(
          documentId: 'doc-1',
          operationGrouping: operationGrouping,
          eventReplayer: eventReplayer,
        );

        final windowId = windowScope.windowId;

        await windowManager.closeWindow(windowId);

        // Verify window was removed and resources freed
        expect(windowManager.getWindow(windowId), isNull);
        expect(windowManager.windowCount, equals(0));
      });
    });

    group('Edge Cases', () {
      test('opening window with initial document', () async {
        final initialDoc = const Document(
          id: 'doc-1',
          title: 'Test Document',
        );

        final windowScope = await windowManager.openWindow(
          documentId: 'doc-1',
          operationGrouping: operationGrouping,
          eventReplayer: eventReplayer,
          initialDocument: initialDoc,
        );

        expect(windowScope.documentProvider.document, equals(initialDoc));
      });

      test('closeAllWindows with no open windows is no-op', () async {
        expect(windowManager.windowCount, equals(0));

        await windowManager.closeAllWindows();

        expect(windowManager.windowCount, equals(0));
      });

      test('window IDs are unique across creation cycles', () async {
        final window1 = await windowManager.openWindow(
          documentId: 'doc-1',
          operationGrouping: operationGrouping,
          eventReplayer: eventReplayer,
        );

        await windowManager.closeWindow(window1.windowId);

        final window2 = await windowManager.openWindow(
          documentId: 'doc-1',
          operationGrouping: operationGrouping,
          eventReplayer: eventReplayer,
        );

        expect(window1.windowId, isNot(equals(window2.windowId)));
      });
    });
  });
}
