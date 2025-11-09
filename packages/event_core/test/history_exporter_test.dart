/// Tests for history export/import service.
///
/// Verifies export range validation, JSON schema compliance, import
/// reconstruction, and integration with snapshot serialization.
library;

import 'package:event_core/event_core.dart';
import 'package:logger/logger.dart';
import 'package:test/test.dart';

void main() {
  late HistoryExporter exporter;
  late MockEventStore mockEventStore;
  late MockEventReplayer mockEventReplayer;
  late SnapshotSerializer snapshotSerializer;
  late Logger logger;
  late EventCoreDiagnosticsConfig config;

  setUp(() {
    mockEventStore = MockEventStore();
    mockEventReplayer = MockEventReplayer();
    snapshotSerializer = SnapshotSerializer(enableCompression: true);
    logger = Logger(level: Level.off); // Suppress logs during tests
    config = EventCoreDiagnosticsConfig.debug();

    exporter = HistoryExporter(
      eventStore: mockEventStore,
      snapshotSerializer: snapshotSerializer,
      eventReplayer: mockEventReplayer,
      logger: logger,
      config: config,
    );
  });

  group('HistoryExporter - Export Range Validation', () {
    test('exportRange rejects negative startSequence', () async {
      expect(
        () => exporter.exportRange(
          documentId: 'doc-1',
          startSequence: -1,
          endSequence: 100,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('exportRange rejects startSequence > endSequence', () async {
      expect(
        () => exporter.exportRange(
          documentId: 'doc-1',
          startSequence: 100,
          endSequence: 50,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('exportRange rejects ranges exceeding max event count', () async {
      expect(
        () => exporter.exportRange(
          documentId: 'doc-1',
          startSequence: 0,
          endSequence: HistoryExporter.kMaxExportEvents + 1,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('exportRange throws StateError when no events found', () async {
      // Mock empty event store
      mockEventStore.mockEvents = [];

      expect(
        () => exporter.exportRange(
          documentId: 'doc-1',
          startSequence: 5000,
          endSequence: 5100,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('exportRange accepts valid range at boundary', () async {
      // Create exactly max events
      final events = _generateMockEvents(
        count: HistoryExporter.kMaxExportEvents,
        startSequence: 0,
        documentId: 'doc-1',
      );
      mockEventStore.mockEvents = events;

      final result = await exporter.exportRange(
        documentId: 'doc-1',
        startSequence: 0,
        endSequence: HistoryExporter.kMaxExportEvents - 1,
      );

      expect(result, isA<Map<String, dynamic>>());
      expect(result['events'], hasLength(HistoryExporter.kMaxExportEvents));
    });
  });

  group('HistoryExporter - Export Format', () {
    test('exportRange produces valid JSON structure', () async {
      final events = _generateMockEvents(
        count: 100,
        startSequence: 5000,
        documentId: 'doc-1',
      );
      mockEventStore.mockEvents = events;

      final result = await exporter.exportRange(
        documentId: 'doc-1',
        startSequence: 5000,
        endSequence: 5099,
      );

      // Validate top-level structure
      expect(result, containsPair('metadata', isA<Map<String, dynamic>>()));
      expect(result, containsPair('events', isA<List>()));

      // Validate metadata fields
      final metadata = result['metadata'] as Map<String, dynamic>;
      expect(metadata, containsPair('documentId', 'doc-1'));
      expect(metadata, containsPair('exportVersion', HistoryExporter.kExportVersion));
      expect(metadata, containsPair('exportedAt', isA<String>()));
      expect(metadata, containsPair('eventRange', isA<Map<String, dynamic>>()));
      expect(metadata, containsPair('eventCount', 100));

      // Validate event range
      final eventRange = metadata['eventRange'] as Map<String, dynamic>;
      expect(eventRange, containsPair('start', 5000));
      expect(eventRange, containsPair('end', 5099));

      // Validate events array
      final exportedEvents = result['events'] as List;
      expect(exportedEvents, hasLength(100));
    });

    test('exportRange includes RFC3339 timestamp in metadata', () async {
      final events = _generateMockEvents(
        count: 10,
        startSequence: 0,
        documentId: 'doc-1',
      );
      mockEventStore.mockEvents = events;

      final result = await exporter.exportRange(
        documentId: 'doc-1',
        startSequence: 0,
        endSequence: 9,
      );

      final metadata = result['metadata'] as Map<String, dynamic>;
      final exportedAt = metadata['exportedAt'] as String;

      // Validate RFC3339 format (simplified check)
      expect(exportedAt, matches(RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}')));
    });

    test('exportRange handles snapshot absence gracefully', () async {
      final events = _generateMockEvents(
        count: 50,
        startSequence: 0,
        documentId: 'doc-1',
      );
      mockEventStore.mockEvents = events;

      final result = await exporter.exportRange(
        documentId: 'doc-1',
        startSequence: 0,
        endSequence: 49,
      );

      // Snapshot should be null when not available
      expect(result['snapshot'], isNull);
      expect(
        result['metadata'],
        containsPair('snapshotSequence', isNull),
      );
    });
  });

  group('HistoryExporter - Import Validation', () {
    test('importFromJson rejects missing metadata', () async {
      final importData = <String, dynamic>{
        'events': [],
      };

      expect(
        () => exporter.importFromJson(
          importData: importData,
          documentId: 'doc-1',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('importFromJson rejects unsupported export version', () async {
      final importData = {
        'metadata': {
          'documentId': 'doc-1',
          'exportVersion': 999,
          'eventRange': {'start': 0, 'end': 10},
          'eventCount': 10,
        },
        'events': [],
      };

      expect(
        () => exporter.importFromJson(
          importData: importData,
          documentId: 'doc-1',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('importFromJson rejects event count mismatch', () async {
      final events = _generateMockEvents(count: 5, startSequence: 0, documentId: 'doc-1');

      final importData = {
        'metadata': {
          'documentId': 'doc-1',
          'exportVersion': 1,
          'eventRange': {'start': 0, 'end': 4},
          'eventCount': 10, // Mismatch: claims 10 but array has 5
        },
        'events': events,
      };

      expect(
        () => exporter.importFromJson(
          importData: importData,
          documentId: 'doc-1',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('importFromJson validates event schema by default', () async {
      final invalidEvent = {
        'eventId': 'not-a-uuid', // Invalid UUID
        'timestamp': 1699305600000,
        'eventType': 'CreatePathEvent',
        'eventSequence': 0,
        'documentId': '550e8400-e29b-41d4-a716-446655440000',
      };

      final importData = {
        'metadata': {
          'documentId': 'doc-1',
          'exportVersion': 1,
          'eventRange': {'start': 0, 'end': 0},
          'eventCount': 1,
        },
        'events': [invalidEvent],
      };

      expect(
        () => exporter.importFromJson(
          importData: importData,
          documentId: 'doc-1',
          validateSchema: true,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('importFromJson skips schema validation when disabled', () async {
      final invalidEvent = {
        'eventId': 'not-a-uuid',
        'timestamp': 1699305600000,
        'eventType': 'CreatePathEvent',
        'eventSequence': 0,
        'documentId': '550e8400-e29b-41d4-a716-446655440000',
      };

      final importData = {
        'metadata': {
          'documentId': 'doc-1',
          'exportVersion': 1,
          'eventRange': {'start': 0, 'end': 0},
          'eventCount': 1,
        },
        'events': [invalidEvent],
      };

      mockEventReplayer.mockSuccess = true;

      // Should not throw when validation is disabled
      final result = await exporter.importFromJson(
        importData: importData,
        documentId: 'doc-1',
        validateSchema: false,
      );

      expect(result, equals(0));
    });
  });

  group('HistoryExporter - Schema Validation', () {
    test('validates eventId is valid UUIDv4', () async {
      final invalidEvents = [
        {
          'eventId': 'not-a-uuid',
          'timestamp': 1699305600000,
          'eventType': 'CreatePathEvent',
          'eventSequence': 0,
          'documentId': '550e8400-e29b-41d4-a716-446655440000',
        },
      ];

      final importData = _buildImportData(invalidEvents);

      expect(
        () => exporter.importFromJson(
          importData: importData,
          documentId: 'doc-1',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('validates timestamp is positive integer', () async {
      final invalidEvents = [
        {
          'eventId': '550e8400-e29b-41d4-a716-446655440000',
          'timestamp': -1, // Invalid negative timestamp
          'eventType': 'CreatePathEvent',
          'eventSequence': 0,
          'documentId': '550e8400-e29b-41d4-a716-446655440001',
        },
      ];

      final importData = _buildImportData(invalidEvents);

      expect(
        () => exporter.importFromJson(
          importData: importData,
          documentId: 'doc-1',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('validates eventType is non-empty string', () async {
      final invalidEvents = [
        {
          'eventId': '550e8400-e29b-41d4-a716-446655440000',
          'timestamp': 1699305600000,
          'eventType': '', // Invalid empty string
          'eventSequence': 0,
          'documentId': '550e8400-e29b-41d4-a716-446655440001',
        },
      ];

      final importData = _buildImportData(invalidEvents);

      expect(
        () => exporter.importFromJson(
          importData: importData,
          documentId: 'doc-1',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('validates eventSequence is non-negative integer', () async {
      final invalidEvents = [
        {
          'eventId': '550e8400-e29b-41d4-a716-446655440000',
          'timestamp': 1699305600000,
          'eventType': 'CreatePathEvent',
          'eventSequence': -1, // Invalid negative sequence
          'documentId': '550e8400-e29b-41d4-a716-446655440001',
        },
      ];

      final importData = _buildImportData(invalidEvents);

      expect(
        () => exporter.importFromJson(
          importData: importData,
          documentId: 'doc-1',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('validates documentId is valid UUIDv4', () async {
      final invalidEvents = [
        {
          'eventId': '550e8400-e29b-41d4-a716-446655440000',
          'timestamp': 1699305600000,
          'eventType': 'CreatePathEvent',
          'eventSequence': 0,
          'documentId': 'invalid-doc-id', // Invalid UUID
        },
      ];

      final importData = _buildImportData(invalidEvents);

      expect(
        () => exporter.importFromJson(
          importData: importData,
          documentId: 'doc-1',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('accepts valid event schema', () async {
      final validEvents = _generateMockEvents(
        count: 10,
        startSequence: 0,
        documentId: 'doc-1',
      );

      final importData = _buildImportData(validEvents);
      mockEventReplayer.mockSuccess = true;

      // Should not throw
      final result = await exporter.importFromJson(
        importData: importData,
        documentId: 'doc-1',
      );

      expect(result, equals(9)); // endSequence
    });
  });

  group('HistoryExporter - Round-trip Integration', () {
    test('export and import round-trip preserves events', () async {
      final originalEvents = _generateMockEvents(
        count: 50,
        startSequence: 100,
        documentId: 'doc-roundtrip',
      );
      mockEventStore.mockEvents = originalEvents;

      // Export
      final exportData = await exporter.exportRange(
        documentId: 'doc-roundtrip',
        startSequence: 100,
        endSequence: 149,
      );

      // Verify export structure
      expect(exportData['events'], hasLength(50));
      expect(
        (exportData['metadata'] as Map)['eventCount'],
        equals(50),
      );

      // Import
      mockEventReplayer.mockSuccess = true;

      final finalSequence = await exporter.importFromJson(
        importData: exportData,
        documentId: 'doc-roundtrip',
      );

      expect(finalSequence, equals(149));

      // Verify all events were persisted
      expect(mockEventStore.persistedEvents, hasLength(50));

      // Verify event data integrity
      for (var i = 0; i < 50; i++) {
        final original = originalEvents[i];
        final persisted = mockEventStore.persistedEvents[i];
        expect(persisted['eventId'], equals(original['eventId']));
        expect(persisted['eventSequence'], equals(original['eventSequence']));
        expect(persisted['eventType'], equals(original['eventType']));
      }
    });

    test('import triggers event replay', () async {
      final events = _generateMockEvents(
        count: 10,
        startSequence: 0,
        documentId: 'doc-1',
      );

      final importData = _buildImportData(events);
      mockEventReplayer.mockSuccess = true;

      await exporter.importFromJson(
        importData: importData,
        documentId: 'doc-1',
      );

      // Verify replayer was called
      expect(mockEventReplayer.replayCallCount, equals(1));
      expect(mockEventReplayer.lastMaxSequence, equals(9));
    });

    test('import throws StateError when replay fails', () async {
      final events = _generateMockEvents(
        count: 5,
        startSequence: 0,
        documentId: 'doc-1',
      );

      final importData = _buildImportData(events);
      mockEventReplayer.mockSuccess = false; // Simulate replay failure

      expect(
        () => exporter.importFromJson(
          importData: importData,
          documentId: 'doc-1',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}

// ============================================================================
// Mock Implementations
// ============================================================================

class MockEventStore implements EventStoreGateway {
  List<Map<String, dynamic>> mockEvents = [];
  List<Map<String, dynamic>> persistedEvents = [];

  @override
  Future<List<Map<String, dynamic>>> getEvents({
    required int fromSequence,
    int? toSequence,
  }) async {
    return mockEvents
        .where((e) {
          final seq = e['eventSequence'] as int;
          return seq >= fromSequence &&
              (toSequence == null || seq <= toSequence);
        })
        .toList();
  }

  @override
  Future<void> persistEvent(Map<String, dynamic> eventData) async {
    persistedEvents.add(eventData);
  }

  @override
  Future<void> persistEventBatch(List<Map<String, dynamic>> events) async {
    persistedEvents.addAll(events);
  }

  @override
  Future<int> getLatestSequenceNumber() async {
    if (mockEvents.isEmpty) return 0;
    return mockEvents.map((e) => e['eventSequence'] as int).reduce((a, b) => a > b ? a : b);
  }

  @override
  Future<void> pruneEventsBeforeSequence(int sequenceNumber) async {
    mockEvents.removeWhere((e) => (e['eventSequence'] as int) < sequenceNumber);
  }
}

class MockEventReplayer implements EventReplayer {
  bool mockSuccess = true;
  int replayCallCount = 0;
  int? lastMaxSequence;
  bool _isReplaying = false;

  @override
  Future<void> replayFromSnapshot({int? maxSequence}) async {
    _isReplaying = true;
    replayCallCount++;
    lastMaxSequence = maxSequence;

    if (!mockSuccess) {
      _isReplaying = false;
      throw Exception('Simulated replay failure');
    }

    _isReplaying = false;
  }

  @override
  Future<void> replay({int fromSequence = 0, int? toSequence}) async {
    _isReplaying = true;

    if (!mockSuccess) {
      _isReplaying = false;
      throw Exception('Simulated replay failure');
    }

    _isReplaying = false;
  }

  @override
  bool get isReplaying => _isReplaying;
}

// ============================================================================
// Test Utilities
// ============================================================================

/// Generates mock events with valid schema.
List<Map<String, dynamic>> _generateMockEvents({
  required int count,
  required int startSequence,
  required String documentId,
}) {
  final events = <Map<String, dynamic>>[];

  // Ensure documentId is a valid UUID
  final uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );
  final validDocId = uuidPattern.hasMatch(documentId)
      ? documentId
      : '550e8400-e29b-41d4-a716-${documentId.hashCode.abs().toRadixString(16).padLeft(12, '0').substring(0, 12)}';

  for (var i = 0; i < count; i++) {
    final sequence = startSequence + i;
    events.add({
      'eventId': _generateMockUuid(sequence),
      'timestamp': 1699305600000 + (i * 50),
      'eventType': 'AddAnchorEvent',
      'eventSequence': sequence,
      'documentId': validDocId,
      'pathId': 'path-001',
      'position': {'x': 100.0 + i, 'y': 200.0 + i},
      'samplingIntervalMs': 50,
    });
  }

  return events;
}

/// Generates a deterministic mock UUID for testing.
String _generateMockUuid(int sequence) {
  final hex = sequence.toRadixString(16).padLeft(12, '0');
  return '550e8400-e29b-41d4-a716-$hex';
}

/// Builds valid import data structure from events.
Map<String, dynamic> _buildImportData(List<Map<String, dynamic>> events) {
  final startSequence = events.isEmpty ? 0 : events.first['eventSequence'] as int;
  final endSequence = events.isEmpty ? 0 : events.last['eventSequence'] as int;

  // Extract documentId from first event if available, otherwise use valid UUID
  final documentId = events.isEmpty
      ? '550e8400-e29b-41d4-a716-000000000001'
      : events.first['documentId'] as String;

  return {
    'metadata': {
      'documentId': documentId,
      'exportVersion': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'eventRange': {
        'start': startSequence,
        'end': endSequence,
      },
      'eventCount': events.length,
      'snapshotSequence': null,
    },
    'snapshot': null,
    'events': events,
  };
}
