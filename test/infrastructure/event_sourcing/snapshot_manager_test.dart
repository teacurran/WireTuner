import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/infrastructure/event_sourcing/snapshot_manager.dart';
import 'package:wiretuner/infrastructure/persistence/snapshot_store.dart';

/// Manual mock of SnapshotStore for testing.
class MockSnapshotStore implements SnapshotStore {
  final List<InsertCall> insertCalls = [];
  bool shouldThrowOnInsert = false;
  String? errorMessage;
  int nextSnapshotId = 1;

  @override
  Future<int> insertSnapshot({
    required String documentId,
    required int eventSequence,
    required Uint8List snapshotData,
    required String compression,
  }) async {
    insertCalls.add(
      InsertCall(documentId, eventSequence, snapshotData, compression),
    );

    if (shouldThrowOnInsert) {
      throw StateError(errorMessage ?? 'Mock error');
    }

    return nextSnapshotId++;
  }

  // Other methods not needed for testing
  @override
  Future<Map<String, dynamic>?> getLatestSnapshot(
    String documentId,
    int maxSequence,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<int> deleteOldSnapshots(String documentId,
      {int keepCount = 10}) async {
    throw UnimplementedError();
  }

  bool wasCalledWith(String documentId, int eventSequence) => insertCalls.any(
        (call) =>
            call.documentId == documentId &&
            call.eventSequence == eventSequence,
      );

  int get callCount => insertCalls.length;

  void reset() {
    insertCalls.clear();
    shouldThrowOnInsert = false;
    errorMessage = null;
    nextSnapshotId = 1;
  }
}

class InsertCall {
  InsertCall(
    this.documentId,
    this.eventSequence,
    this.snapshotData,
    this.compression,
  );
  final String documentId;
  final int eventSequence;
  final Uint8List snapshotData;
  final String compression;
}

void main() {
  late MockSnapshotStore mockSnapshotStore;
  late SnapshotManager manager;

  setUp(() {
    mockSnapshotStore = MockSnapshotStore();
    manager = SnapshotManager(
      snapshotStore: mockSnapshotStore,
      snapshotFrequency: 1000,
      enableCompression: true,
    );
  });

  group('SnapshotManager - shouldSnapshot()', () {
    test('returns true for exact multiples of frequency', () {
      expect(manager.shouldSnapshot(1000), isTrue);
      expect(manager.shouldSnapshot(2000), isTrue);
      expect(manager.shouldSnapshot(3000), isTrue);
      expect(manager.shouldSnapshot(10000), isTrue);
    });

    test('returns false for non-multiples of frequency', () {
      expect(manager.shouldSnapshot(1), isFalse);
      expect(manager.shouldSnapshot(999), isFalse);
      expect(manager.shouldSnapshot(1001), isFalse);
      expect(manager.shouldSnapshot(1500), isFalse);
    });

    test('returns false for zero and negative values', () {
      expect(manager.shouldSnapshot(0), isFalse);
      expect(manager.shouldSnapshot(-1), isFalse);
      expect(manager.shouldSnapshot(-1000), isFalse);
    });

    test('respects custom snapshot frequency', () {
      final customManager = SnapshotManager(
        snapshotStore: mockSnapshotStore,
        snapshotFrequency: 500,
      );

      expect(customManager.shouldSnapshot(500), isTrue);
      expect(customManager.shouldSnapshot(1000), isTrue);
      expect(customManager.shouldSnapshot(1500), isTrue);

      expect(customManager.shouldSnapshot(499), isFalse);
      expect(customManager.shouldSnapshot(501), isFalse);
    });
  });

  group('SnapshotManager - createSnapshot()', () {
    test('serializes document and persists to SnapshotStore', () async {
      final document = {'id': 'doc-1', 'title': 'Test Document'};

      await manager.createSnapshot(
        documentId: 'doc-1',
        eventSequence: 1000,
        document: document,
      );

      expect(mockSnapshotStore.callCount, equals(1));
      expect(mockSnapshotStore.wasCalledWith('doc-1', 1000), isTrue);
    });

    test('compressed snapshots are smaller than uncompressed', () async {
      // Create document with repetitive data (compresses well)
      final document = {
        'id': 'doc-large',
        'title': 'Large Document',
        'layers': List.generate(100, (i) => 'layer-$i'),
      };

      final mockStoreCompressed = MockSnapshotStore();
      final compressedManager = SnapshotManager(
        snapshotStore: mockStoreCompressed,
        enableCompression: true,
      );

      final mockStoreUncompressed = MockSnapshotStore();
      final uncompressedManager = SnapshotManager(
        snapshotStore: mockStoreUncompressed,
        enableCompression: false,
      );

      await compressedManager.createSnapshot(
        documentId: 'doc-1',
        eventSequence: 1000,
        document: document,
      );

      await uncompressedManager.createSnapshot(
        documentId: 'doc-2',
        eventSequence: 1000,
        document: document,
      );

      final compressedSize =
          mockStoreCompressed.insertCalls[0].snapshotData.length;
      final uncompressedSize =
          mockStoreUncompressed.insertCalls[0].snapshotData.length;

      expect(compressedSize, lessThan(uncompressedSize));
      final compressionRatio = uncompressedSize / compressedSize;
      expect(compressionRatio, greaterThan(2.0)); // At least 2:1 compression
    });

    test('stores compression method correctly', () async {
      final document = {'id': 'doc-1', 'title': 'Test'};

      await manager.createSnapshot(
        documentId: 'doc-1',
        eventSequence: 1000,
        document: document,
      );

      final call = mockSnapshotStore.insertCalls.first;
      expect(call.compression, equals('gzip'));
    });

    test('stores "none" compression method when compression disabled',
        () async {
      final mockStoreUncompressed = MockSnapshotStore();
      final uncompressedManager = SnapshotManager(
        snapshotStore: mockStoreUncompressed,
        enableCompression: false,
      );

      final document = {'id': 'doc-1', 'title': 'Test'};

      await uncompressedManager.createSnapshot(
        documentId: 'doc-1',
        eventSequence: 1000,
        document: document,
      );

      final call = mockStoreUncompressed.insertCalls.first;
      expect(call.compression, equals('none'));
    });

    test('handles SnapshotStore errors gracefully', () async {
      mockSnapshotStore.shouldThrowOnInsert = true;
      mockSnapshotStore.errorMessage = 'Database error';

      final document = {'id': 'doc-1', 'title': 'Test'};

      expect(
        () => manager.createSnapshot(
          documentId: 'doc-1',
          eventSequence: 1000,
          document: document,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('snapshot data is not empty', () async {
      final document = {'id': 'doc-1', 'title': 'Test Document'};

      await manager.createSnapshot(
        documentId: 'doc-1',
        eventSequence: 1000,
        document: document,
      );

      final call = mockSnapshotStore.insertCalls.first;
      expect(call.snapshotData.length, greaterThan(0));
    });
  });

  group('SnapshotManager - Integration Scenarios', () {
    test('workflow: check shouldSnapshot, then create snapshot', () async {
      final document = {'id': 'doc-1', 'title': 'Test'};
      const eventCount = 1000;

      if (manager.shouldSnapshot(eventCount)) {
        await manager.createSnapshot(
          documentId: 'doc-1',
          eventSequence: eventCount,
          document: document,
        );
      }

      expect(mockSnapshotStore.callCount, equals(1));
      expect(mockSnapshotStore.wasCalledWith('doc-1', 1000), isTrue);
    });

    test('multiple snapshots at different sequences', () async {
      final document = {'id': 'doc-1', 'title': 'Test'};

      for (final seq in [1000, 2000, 3000]) {
        if (manager.shouldSnapshot(seq)) {
          await manager.createSnapshot(
            documentId: 'doc-1',
            eventSequence: seq,
            document: document,
          );
        }
      }

      expect(mockSnapshotStore.callCount, equals(3));
      expect(mockSnapshotStore.wasCalledWith('doc-1', 1000), isTrue);
      expect(mockSnapshotStore.wasCalledWith('doc-1', 2000), isTrue);
      expect(mockSnapshotStore.wasCalledWith('doc-1', 3000), isTrue);
    });

    test('no snapshots created for non-multiple event counts', () async {
      final document = {'id': 'doc-1', 'title': 'Test'};

      for (final seq in [1, 500, 999, 1001, 1500]) {
        if (manager.shouldSnapshot(seq)) {
          await manager.createSnapshot(
            documentId: 'doc-1',
            eventSequence: seq,
            document: document,
          );
        }
      }

      expect(mockSnapshotStore.callCount, equals(0));
    });

    test('snapshot creation with large document', () async {
      final largeDocument = {
        'id': 'doc-large',
        'title': 'Large Document',
        'layers': List.generate(
          1000,
          (i) => {
            'id': 'layer-$i',
            'name': 'Layer $i',
            'shapes': List.generate(
              10,
              (j) => {
                'id': 'shape-$i-$j',
                'type': 'rectangle',
                'x': i * 10,
                'y': j * 10,
              },
            ),
          },
        ),
      };

      await manager.createSnapshot(
        documentId: 'doc-large',
        eventSequence: 1000,
        document: largeDocument,
      );

      expect(mockSnapshotStore.callCount, equals(1));
      expect(mockSnapshotStore.wasCalledWith('doc-large', 1000), isTrue);

      final call = mockSnapshotStore.insertCalls.first;
      expect(call.snapshotData.length, greaterThan(0));
    });

    test('multiple documents can have independent snapshots', () async {
      final doc1 = {'id': 'doc-1', 'title': 'Document 1'};
      final doc2 = {'id': 'doc-2', 'title': 'Document 2'};
      final doc3 = {'id': 'doc-3', 'title': 'Document 3'};

      await manager.createSnapshot(
        documentId: 'doc-1',
        eventSequence: 1000,
        document: doc1,
      );

      await manager.createSnapshot(
        documentId: 'doc-2',
        eventSequence: 2000,
        document: doc2,
      );

      await manager.createSnapshot(
        documentId: 'doc-3',
        eventSequence: 3000,
        document: doc3,
      );

      expect(mockSnapshotStore.callCount, equals(3));
      expect(mockSnapshotStore.wasCalledWith('doc-1', 1000), isTrue);
      expect(mockSnapshotStore.wasCalledWith('doc-2', 2000), isTrue);
      expect(mockSnapshotStore.wasCalledWith('doc-3', 3000), isTrue);
    });
  });
}
