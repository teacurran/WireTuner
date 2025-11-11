/// Unit tests for ManualSaveUseCase with deduplication logic.
///
/// Verifies:
/// - Manual save flushes pending auto-save first
/// - Deduplication prevents redundant document.saved events
/// - Snapshot triggering during manual saves
/// - Integration with SaveService
/// - Error handling and status reporting
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:event_core/event_core.dart';
import 'package:io_services/io_services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wiretuner/application/interaction/auto_save_manager.dart';
import 'package:wiretuner/application/interaction/manual_save_use_case.dart';

void main() {
  group('ManualSaveUseCase', () {
    late StubAutoSaveManager autoSaveManager;
    late StubSaveService saveService;
    late StubEventStoreGateway eventGateway;
    late StubSnapshotManager snapshotManager;
    late ManualSaveUseCase manualSaveUseCase;

    setUp(() {
      autoSaveManager = StubAutoSaveManager();
      saveService = StubSaveService();
      eventGateway = StubEventStoreGateway();
      snapshotManager = StubSnapshotManager();

      manualSaveUseCase = ManualSaveUseCase(
        autoSaveManager: autoSaveManager,
        saveService: saveService,
        eventGateway: eventGateway,
        snapshotManager: snapshotManager,
        documentId: 'test-doc',
        logger: Logger(level: Level.off),
      );
    });

    group('Deduplication', () {
      test('skips save when no changes since last manual save', () async {
        // Setup: Last manual save at sequence 10
        autoSaveManager.setLastManualSaveSequence(10);
        autoSaveManager.setFlushSequence(10);

        final result = await manualSaveUseCase.execute(
          documentState: {'test': 'data'},
          title: 'Test Document',
        );

        // Should skip save
        expect(result, isA<ManualSaveSkipped>());
        expect((result as ManualSaveSkipped).message, 'No changes to save');

        // Should not call SaveService
        expect(saveService.saveCallCount, 0);

        // Should not persist document.saved event
        expect(eventGateway.persistedEvents, isEmpty);
      });

      test('saves when changes exist since last manual save', () async {
        // Setup: Last manual save at sequence 10, current at 15
        autoSaveManager.setLastManualSaveSequence(10);
        autoSaveManager.setFlushSequence(15);

        saveService.setFilePath('/path/to/document.wiretuner');

        final result = await manualSaveUseCase.execute(
          documentState: {'test': 'data'},
          title: 'Test Document',
        );

        // Should save successfully
        expect(result, isA<ManualSaveSuccess>());
        expect((result as ManualSaveSuccess).sequenceNumber, 16);

        // Should call SaveService
        expect(saveService.saveCallCount, 1);

        // Should persist document.saved event
        expect(eventGateway.persistedEvents, hasLength(1));
        expect(eventGateway.persistedEvents.first['eventType'], 'document.saved');
      });

      test('saves on first manual save (never saved before)', () async {
        // Setup: Never manually saved (-1 marker)
        autoSaveManager.setLastManualSaveSequence(-1);
        autoSaveManager.setFlushSequence(5);

        saveService.setFilePath('/path/to/document.wiretuner');

        final result = await manualSaveUseCase.execute(
          documentState: {'test': 'data'},
          title: 'Test Document',
        );

        // Should save successfully
        expect(result, isA<ManualSaveSuccess>());

        // Should call SaveService
        expect(saveService.saveCallCount, 1);
      });
    });

    group('Auto-Save Coordination', () {
      test('flushes pending auto-save before checking changes', () async {
        autoSaveManager.setLastManualSaveSequence(10);
        autoSaveManager.setFlushSequence(15);

        saveService.setFilePath('/path/to/document.wiretuner');

        await manualSaveUseCase.execute(
          documentState: {'test': 'data'},
          title: 'Test Document',
        );

        // Should have flushed auto-save
        expect(autoSaveManager.flushCallCount, 1);
      });

      test('uses sequence from flush for deduplication check', () async {
        // Setup: Manual save at 10, but flush returns 10 (no new events)
        autoSaveManager.setLastManualSaveSequence(10);
        autoSaveManager.setFlushSequence(10);

        final result = await manualSaveUseCase.execute(
          documentState: {'test': 'data'},
          title: 'Test Document',
        );

        // Should skip (flush revealed no new events)
        expect(result, isA<ManualSaveSkipped>());
      });
    });

    group('Event Recording', () {
      test('records document.saved event with correct metadata', () async {
        autoSaveManager.setLastManualSaveSequence(10);
        autoSaveManager.setFlushSequence(15);

        saveService.setFilePath('/path/to/document.wiretuner');

        await manualSaveUseCase.execute(
          documentState: {'test': 'data'},
          title: 'Test Document',
        );

        final savedEvent = eventGateway.persistedEvents.first;

        expect(savedEvent['eventType'], 'document.saved');
        expect(savedEvent['sequenceNumber'], 16); // flush + 1
        expect(savedEvent['filePath'], '/path/to/document.wiretuner');
        expect(savedEvent['eventCount'], 16);
        expect(savedEvent['savedAt'], isNotNull);
      });

      test('updates auto-save manager with manual save sequence', () async {
        autoSaveManager.setLastManualSaveSequence(10);
        autoSaveManager.setFlushSequence(15);

        saveService.setFilePath('/path/to/document.wiretuner');

        await manualSaveUseCase.execute(
          documentState: {'test': 'data'},
          title: 'Test Document',
        );

        // Should record manual save at new sequence
        expect(autoSaveManager.recordedManualSaveSequence, 16);
      });
    });

    group('SaveService Integration', () {
      test('delegates to SaveService with correct parameters', () async {
        autoSaveManager.setLastManualSaveSequence(10);
        autoSaveManager.setFlushSequence(15);

        saveService.setFilePath('/path/to/document.wiretuner');

        final documentState = {'test': 'data'};
        await manualSaveUseCase.execute(
          documentState: documentState,
          title: 'Test Document',
        );

        expect(saveService.lastSaveParams, isNotNull);
        expect(saveService.lastSaveParams!['documentId'], 'test-doc');
        expect(saveService.lastSaveParams!['currentSequence'], 16);
        expect(saveService.lastSaveParams!['documentState'], documentState);
        expect(saveService.lastSaveParams!['title'], 'Test Document');
      });

      test('includes snapshot creation flag in result', () async {
        autoSaveManager.setLastManualSaveSequence(10);
        autoSaveManager.setFlushSequence(15);

        saveService.setFilePath('/path/to/document.wiretuner');
        saveService.setSnapshotCreated(true);

        final result = await manualSaveUseCase.execute(
          documentState: {'test': 'data'},
          title: 'Test Document',
        );

        expect(result, isA<ManualSaveSuccess>());
        expect((result as ManualSaveSuccess).snapshotCreated, isTrue);
      });
    });

    group('Error Handling', () {
      test('returns failure when SaveService fails', () async {
        autoSaveManager.setLastManualSaveSequence(10);
        autoSaveManager.setFlushSequence(15);

        saveService.setFailure(
          errorType: SaveErrorType.diskFull,
          userMessage: 'Disk full',
          technicalDetails: 'Insufficient space',
        );

        final result = await manualSaveUseCase.execute(
          documentState: {'test': 'data'},
          title: 'Test Document',
        );

        expect(result, isA<ManualSaveFailure>());
        expect((result as ManualSaveFailure).message, 'Disk full');
        expect(result.technicalDetails, 'Insufficient space');
      });

      test('handles unexpected exceptions', () async {
        autoSaveManager.setLastManualSaveSequence(10);
        autoSaveManager.setFlushSequence(15);

        eventGateway.setShouldFail(true);

        final result = await manualSaveUseCase.execute(
          documentState: {'test': 'data'},
          title: 'Test Document',
        );

        expect(result, isA<ManualSaveFailure>());
        expect((result as ManualSaveFailure).message, 'Failed to save document');
      });
    });
  });
}

/// Stub AutoSaveManager for testing.
class StubAutoSaveManager extends AutoSaveManager {
  StubAutoSaveManager()
      : super(
          eventGateway: StubEventStoreGateway(),
          documentId: 'stub-doc',
        );

  int _lastManualSaveSequence = -1;
  int _flushSequence = 0;
  int flushCallCount = 0;
  int? recordedManualSaveSequence;

  void setLastManualSaveSequence(int sequence) {
    _lastManualSaveSequence = sequence;
  }

  void setFlushSequence(int sequence) {
    _flushSequence = sequence;
  }

  @override
  Future<int> flushPendingAutoSave() async {
    flushCallCount++;
    return _flushSequence;
  }

  @override
  bool hasChangesSinceLastManualSave(int currentSequence) {
    if (_lastManualSaveSequence == -1) {
      return currentSequence >= 0;
    }
    return currentSequence > _lastManualSaveSequence;
  }

  @override
  void recordManualSave(int sequenceNumber) {
    recordedManualSaveSequence = sequenceNumber;
  }

  @override
  int get lastManualSaveSequence => _lastManualSaveSequence;
}

/// Stub SaveService for testing.
class StubSaveService extends SaveService {
  StubSaveService()
      : super(
          connectionFactory: StubConnectionFactory(),
          snapshotManager: StubSnapshotManager(),
          eventStoreGateway: StubEventStoreGateway(),
          operationGrouping: StubOperationGrouping(),
          logger: Logger(level: Level.off),
        );

  int saveCallCount = 0;
  Map<String, dynamic>? lastSaveParams;
  String? _filePath;
  bool _snapshotCreated = false;
  SaveFailure? _failure;

  void setFilePath(String path) {
    _filePath = path;
  }

  void setSnapshotCreated(bool created) {
    _snapshotCreated = created;
  }

  void setFailure({
    required SaveErrorType errorType,
    required String userMessage,
    required String technicalDetails,
  }) {
    _failure = SaveFailure(
      errorType: errorType,
      userMessage: userMessage,
      technicalDetails: technicalDetails,
    );
  }

  @override
  Future<SaveResult> save({
    required String documentId,
    required int currentSequence,
    required Map<String, dynamic> documentState,
    String title = 'Untitled',
  }) async {
    saveCallCount++;
    lastSaveParams = {
      'documentId': documentId,
      'currentSequence': currentSequence,
      'documentState': documentState,
      'title': title,
    };

    if (_failure != null) {
      return _failure!;
    }

    return SaveSuccess(
      filePath: _filePath ?? '/default/path.wiretuner',
      sequenceNumber: currentSequence,
      durationMs: 10,
      snapshotCreated: _snapshotCreated,
    );
  }

  @override
  String? getCurrentFilePath(String documentId) {
    return _filePath;
  }
}

/// Stub EventStoreGateway for testing.
class StubEventStoreGateway implements EventStoreGateway {
  final List<Map<String, dynamic>> persistedEvents = [];
  bool _shouldFail = false;

  void setShouldFail(bool shouldFail) {
    _shouldFail = shouldFail;
  }

  @override
  Future<void> persistEvent(Map<String, dynamic> eventData) async {
    if (_shouldFail) {
      throw Exception('Simulated failure');
    }
    persistedEvents.add(eventData);
  }

  @override
  Future<int> getLatestSequenceNumber() async => 0;

  @override
  Future<void> persistEventBatch(List<Map<String, dynamic>> events) async {}

  @override
  Future<List<Map<String, dynamic>>> getEvents({
    required int fromSequence,
    int? toSequence,
  }) async =>
      [];

  @override
  Future<void> pruneEventsBeforeSequence(int sequenceNumber) async {}
}

/// Stub SnapshotManager for testing.
class StubSnapshotManager implements SnapshotManager {
  @override
  Future<void> createSnapshot({
    required Map<String, dynamic> documentState,
    required int sequenceNumber,
    String? documentId,
  }) async {}

  @override
  bool shouldCreateSnapshot(int sequenceNumber, {bool forceTimeCheck = false}) => false;

  @override
  Future<SnapshotData?> loadSnapshot({int? maxSequence, String? documentId}) async => null;

  @override
  Future<void> pruneSnapshotsBeforeSequence(int sequenceNumber, {String? documentId}) async {}

  @override
  int get snapshotInterval => 100;
}

/// Stub ConnectionFactory for testing.
class StubConnectionFactory implements ConnectionFactory {
  @override
  Future<Database> openConnection({
    required String documentId,
    required DatabaseConfig config,
    bool runMigrations = true,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> closeConnection(String documentId) async {}

  @override
  Future<void> closeAll() async {}

  @override
  int get activeConnectionCount => 0;

  @override
  Database getConnection(String documentId) {
    throw UnimplementedError();
  }

  @override
  bool hasConnection(String documentId) => false;

  @override
  Future<void> initialize() async {}

  @override
  bool get isInitialized => true;
}

/// Stub OperationGrouping for testing.
class StubOperationGrouping extends OperationGroupingService {
  StubOperationGrouping()
      : super(
          clock: const SystemClock(),
          metricsSink: const StubMetricsSink(),
          logger: Logger(level: Level.off),
          config: const EventCoreDiagnosticsConfig(),
        );
}
