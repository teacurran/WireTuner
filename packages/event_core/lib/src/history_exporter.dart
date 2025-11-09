/// History export/import service for debugging and reproduction workflows.
///
/// This module provides JSON-based export/import of event log subsections
/// with accompanying snapshots for debugging, crash reproduction, and
/// development workflows. Exported data includes full event schema validation
/// and snapshot serialization metadata.
///
/// **Design:**
/// - Exports bounded event ranges with nearest snapshot
/// - Validates against canonical event schema during import
/// - Integrates with EventReplayer for state reconstruction
/// - Flags as dev-only feature with security warnings
///
/// **Export Format:**
/// ```json
/// {
///   "metadata": {
///     "documentId": "uuid",
///     "exportVersion": 1,
///     "exportedAt": "2023-11-07T00:00:00.000000Z",
///     "eventRange": {"start": 5000, "end": 5500},
///     "eventCount": 500,
///     "snapshotSequence": 5000
///   },
///   "snapshot": {
///     "eventSequence": 5000,
///     "compression": "gzip",
///     "uncompressedSize": 102400,
///     "data": "base64-encoded-blob..."
///   },
///   "events": [
///     { /* full event JSON per event_schema.md */ }
///   ]
/// }
/// ```
///
/// **Security Warnings:**
/// - Exported files bypass encryption and may contain sensitive data
/// - Do NOT share exported history files externally
/// - Use only for local debugging and reproduction workflows
/// - Mark exported files with .debug.json extension for visibility
///
/// **Integration:**
/// - Depends on EventStoreGateway for event/snapshot retrieval
/// - Uses SnapshotSerializer for binary snapshot handling
/// - Consumed by justfile CLI command for export/import operations
///
/// **References:**
/// - Task I4.T10: History export/import stubs
/// - docs/reference/event_schema.md: Canonical event schema
/// - packages/event_core/lib/src/snapshot_serializer.dart: Snapshot format
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:logger/logger.dart';

import 'event_store_gateway.dart';
import 'snapshot_serializer.dart';
import 'event_replayer.dart';
import 'metrics_sink.dart';
import 'diagnostics_config.dart';

/// History export/import service for debugging workflows.
///
/// Provides JSON-based export/import of event log subsections with
/// accompanying snapshots for crash reproduction and debugging.
///
/// **Usage:**
/// ```dart
/// final exporter = HistoryExporter(
///   eventStore: eventStore,
///   snapshotSerializer: snapshotSerializer,
///   eventReplayer: eventReplayer,
///   logger: logger,
///   config: EventCoreDiagnosticsConfig.debug(),
/// );
///
/// // Export a range of events
/// final exportData = await exporter.exportRange(
///   documentId: 'doc-123',
///   startSequence: 5000,
///   endSequence: 5500,
/// );
///
/// // Save to file (in your application code)
/// final jsonString = jsonEncode(exportData);
/// await File('debug_history.json').writeAsString(jsonString);
///
/// // Import from JSON
/// final importedData = jsonDecode(jsonString) as Map<String, dynamic>;
/// await exporter.importFromJson(
///   importData: importedData,
///   documentId: 'doc-123',
/// );
/// ```
///
/// **Threading:** All methods must be called from UI isolate.
class HistoryExporter {
  /// Creates a history exporter.
  ///
  /// [eventStore]: Event store gateway for event/snapshot retrieval
  /// [snapshotSerializer]: Serializer for snapshot binary format
  /// [eventReplayer]: Replayer for state reconstruction during import
  /// [metricsSink]: Optional metrics sink for telemetry
  /// [logger]: Logger instance
  /// [config]: Diagnostics configuration
  HistoryExporter({
    required EventStoreGateway eventStore,
    required SnapshotSerializer snapshotSerializer,
    required EventReplayer eventReplayer,
    required Logger logger,
    required EventCoreDiagnosticsConfig config,
    MetricsSink? metricsSink,
  })  : _eventStore = eventStore,
        _snapshotSerializer = snapshotSerializer,
        _eventReplayer = eventReplayer,
        _metricsSink = metricsSink,
        _logger = logger,
        _config = config;

  final EventStoreGateway _eventStore;
  final SnapshotSerializer _snapshotSerializer;
  final EventReplayer _eventReplayer;
  final MetricsSink? _metricsSink;
  final Logger _logger;
  final EventCoreDiagnosticsConfig _config;

  /// Export format version for schema evolution.
  static const int kExportVersion = 1;

  /// Maximum event count per export to prevent memory exhaustion.
  static const int kMaxExportEvents = 10000;

  /// Exports a subsection of the event log with nearest snapshot.
  ///
  /// Creates a JSON-serializable export containing:
  /// - Metadata (document ID, event range, export timestamp)
  /// - Snapshot at or before startSequence (base64-encoded)
  /// - Events from startSequence to endSequence (inclusive)
  ///
  /// [documentId]: Document identifier
  /// [startSequence]: Starting event sequence (inclusive)
  /// [endSequence]: Ending event sequence (inclusive)
  ///
  /// Returns a Map<String, dynamic> ready for JSON encoding.
  ///
  /// Throws [ArgumentError] if:
  /// - startSequence > endSequence
  /// - Event range exceeds kMaxExportEvents
  /// - startSequence < 0
  ///
  /// Throws [StateError] if no events found in range.
  Future<Map<String, dynamic>> exportRange({
    required String documentId,
    required int startSequence,
    required int endSequence,
  }) async {
    // Validation
    if (startSequence < 0) {
      throw ArgumentError('startSequence must be >= 0: $startSequence');
    }
    if (startSequence > endSequence) {
      throw ArgumentError(
        'startSequence ($startSequence) must be <= endSequence ($endSequence)',
      );
    }

    final eventCount = endSequence - startSequence + 1;
    if (eventCount > kMaxExportEvents) {
      throw ArgumentError(
        'Event range ($eventCount events) exceeds maximum ($kMaxExportEvents). '
        'Use smaller ranges to prevent memory exhaustion.',
      );
    }

    _logger.i(
      '[$documentId] Exporting history range: $startSequence-$endSequence '
      '($eventCount events)',
    );

    final startTime = DateTime.now();

    // Step 1: Retrieve events in range
    final events = await _eventStore.getEvents(
      fromSequence: startSequence,
      toSequence: endSequence,
    );

    if (events.isEmpty) {
      throw StateError(
        'No events found in range $startSequence-$endSequence for document $documentId',
      );
    }

    _logger.d(
      '[$documentId] Retrieved ${events.length} events from store',
    );

    // Step 2: Find nearest snapshot at or before startSequence
    // Note: This is a simplified approach. In production, you'd query
    // the snapshots table directly. For now, we rely on the replayer's
    // internal snapshot lookup.
    Map<String, dynamic>? snapshotData;
    int? snapshotSequence;

    try {
      // Use replayer to find nearest snapshot
      // This is a simplified approach - in production you'd query snapshots table
      final nearestSnapshot = await _findNearestSnapshot(
        documentId: documentId,
        maxSequence: startSequence,
      );

      if (nearestSnapshot != null) {
        snapshotData = nearestSnapshot['data'] as Map<String, dynamic>?;
        snapshotSequence = nearestSnapshot['sequence'] as int?;
        _logger.d(
          '[$documentId] Found snapshot at sequence $snapshotSequence',
        );
      } else {
        _logger.w(
          '[$documentId] No snapshot found before sequence $startSequence. '
          'Import will replay from event 0.',
        );
      }
    } catch (e, stackTrace) {
      _logger.e(
        '[$documentId] Failed to retrieve snapshot',
        error: e,
        stackTrace: stackTrace,
      );
      // Continue without snapshot - import will replay from beginning
    }

    // Step 3: Build export JSON
    final exportData = {
      'metadata': {
        'documentId': documentId,
        'exportVersion': kExportVersion,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'eventRange': {
          'start': startSequence,
          'end': endSequence,
        },
        'eventCount': events.length,
        'snapshotSequence': snapshotSequence,
      },
      'snapshot': snapshotData != null && snapshotSequence != null
          ? {
              'eventSequence': snapshotSequence,
              'data': snapshotData,
            }
          : null,
      'events': events,
    };

    final durationMs = DateTime.now().difference(startTime).inMilliseconds;

    _logger.i(
      '[$documentId] Export completed in ${durationMs}ms: '
      '${events.length} events, '
      'snapshot: ${snapshotSequence ?? "none"}',
    );

    // Record metrics
    if (_config.enableMetrics && _metricsSink != null) {
      _metricsSink!.recordEvent(
        eventType: 'HistoryExport',
        sampled: false,
        durationMs: durationMs,
      );
    }

    return exportData;
  }

  /// Imports a JSON export and reconstructs state via event replay.
  ///
  /// Validates the imported data against the event schema and uses
  /// EventReplayer to reconstruct document state.
  ///
  /// [importData]: JSON export data (from exportRange)
  /// [documentId]: Target document ID for import
  /// [validateSchema]: If true, validates events against schema (default: true)
  ///
  /// Returns the final event sequence number after import.
  ///
  /// Throws [FormatException] if:
  /// - Export version is unsupported
  /// - Required metadata fields are missing
  /// - Event schema validation fails
  ///
  /// Throws [StateError] if replay fails.
  Future<int> importFromJson({
    required Map<String, dynamic> importData,
    required String documentId,
    bool validateSchema = true,
  }) async {
    _logger.i('[$documentId] Importing history from JSON export');

    final startTime = DateTime.now();

    // Step 1: Validate metadata
    final metadata = importData['metadata'] as Map<String, dynamic>?;
    if (metadata == null) {
      throw const FormatException('Missing required field: metadata');
    }

    final exportVersion = metadata['exportVersion'] as int?;
    if (exportVersion == null) {
      throw const FormatException('Missing required field: metadata.exportVersion');
    }
    if (exportVersion > kExportVersion) {
      throw FormatException(
        'Unsupported export version: $exportVersion (current: $kExportVersion). '
        'Update your HistoryExporter implementation.',
      );
    }

    final eventRange = metadata['eventRange'] as Map<String, dynamic>?;
    if (eventRange == null) {
      throw const FormatException('Missing required field: metadata.eventRange');
    }

    final startSequence = eventRange['start'] as int?;
    final endSequence = eventRange['end'] as int?;
    if (startSequence == null || endSequence == null) {
      throw const FormatException(
        'Missing required fields: metadata.eventRange.{start,end}',
      );
    }

    final eventCount = metadata['eventCount'] as int?;
    if (eventCount == null) {
      throw const FormatException('Missing required field: metadata.eventCount');
    }

    _logger.d(
      '[$documentId] Import metadata: '
      'version=$exportVersion, '
      'range=$startSequence-$endSequence, '
      'count=$eventCount',
    );

    // Step 2: Extract and validate events
    final events = importData['events'] as List<dynamic>?;
    if (events == null) {
      throw const FormatException('Missing required field: events');
    }

    if (events.length != eventCount) {
      throw FormatException(
        'Event count mismatch: metadata claims $eventCount, '
        'but events array contains ${events.length}',
      );
    }

    // Step 3: Validate event schema (if enabled)
    if (validateSchema) {
      _logger.d('[$documentId] Validating ${events.length} events against schema');
      _validateEventSchema(events, documentId);
    }

    // Step 4: Extract snapshot (if present)
    final snapshotMap = importData['snapshot'] as Map<String, dynamic>?;
    if (snapshotMap != null) {
      final snapshotSequence = snapshotMap['eventSequence'] as int?;
      _logger.d(
        '[$documentId] Found snapshot at sequence $snapshotSequence',
      );
    } else {
      _logger.w(
        '[$documentId] No snapshot in import data. '
        'Will replay from beginning (may be slow).',
      );
    }

    // Step 5: Persist events to store
    // Note: This is a simplified approach. In production, you'd want to:
    // - Check for duplicate events
    // - Handle transaction rollback on failure
    // - Update snapshot store if snapshot is included
    _logger.d('[$documentId] Persisting ${events.length} events to store');

    for (final event in events) {
      final eventMap = event as Map<String, dynamic>;
      await _eventStore.persistEvent(eventMap);
    }

    // Step 6: Replay to reconstruct state
    _logger.d('[$documentId] Replaying events to reconstruct state');

    try {
      await _eventReplayer.replayFromSnapshot(maxSequence: endSequence);
    } catch (e, stackTrace) {
      _logger.e(
        '[$documentId] Replay failed during import',
        error: e,
        stackTrace: stackTrace,
      );
      throw StateError('Failed to replay events during import: $e');
    }

    final durationMs = DateTime.now().difference(startTime).inMilliseconds;

    _logger.i(
      '[$documentId] Import completed in ${durationMs}ms: '
      '${events.length} events replayed, '
      'final sequence: $endSequence',
    );

    // Record metrics
    if (_config.enableMetrics && _metricsSink != null) {
      _metricsSink!.recordEvent(
        eventType: 'HistoryImport',
        sampled: false,
        durationMs: durationMs,
      );
    }

    return endSequence;
  }

  /// Finds the nearest snapshot at or before the given sequence.
  ///
  /// This is a simplified helper. In production, you'd query the
  /// snapshots table directly instead of relying on the replayer.
  ///
  /// Returns a map with 'sequence' and 'data' keys, or null if no snapshot found.
  Future<Map<String, dynamic>?> _findNearestSnapshot({
    required String documentId,
    required int maxSequence,
  }) async {
    // TODO(I4.T10): Implement actual snapshot store query
    // For now, return null to indicate no snapshot available
    // Production implementation would query:
    // SELECT event_sequence, snapshot_data FROM snapshots
    // WHERE document_id = ? AND event_sequence <= ?
    // ORDER BY event_sequence DESC
    // LIMIT 1
    return null;
  }

  /// Validates events against the canonical event schema.
  ///
  /// Checks that all required envelope fields are present and valid.
  /// Per event_schema.md, every event must have:
  /// - eventId (valid UUIDv4)
  /// - timestamp (positive integer)
  /// - eventType (non-empty string)
  /// - eventSequence (non-negative integer)
  /// - documentId (valid UUIDv4)
  ///
  /// Throws [FormatException] if validation fails.
  void _validateEventSchema(List<dynamic> events, String documentId) {
    for (var i = 0; i < events.length; i++) {
      final event = events[i];
      if (event is! Map<String, dynamic>) {
        throw FormatException(
          'Event at index $i is not a valid JSON object',
        );
      }

      // Validate required envelope fields
      final eventId = event['eventId'];
      if (eventId == null || eventId is! String || !_isValidUuid(eventId)) {
        throw FormatException(
          'Event at index $i: invalid or missing eventId (must be UUIDv4)',
        );
      }

      final timestamp = event['timestamp'];
      if (timestamp == null || timestamp is! int || timestamp < 0) {
        throw FormatException(
          'Event at index $i: invalid or missing timestamp '
          '(must be positive integer)',
        );
      }

      final eventType = event['eventType'];
      if (eventType == null || eventType is! String || eventType.isEmpty) {
        throw FormatException(
          'Event at index $i: invalid or missing eventType '
          '(must be non-empty string)',
        );
      }

      final eventSequence = event['eventSequence'];
      if (eventSequence == null ||
          eventSequence is! int ||
          eventSequence < 0) {
        throw FormatException(
          'Event at index $i: invalid or missing eventSequence '
          '(must be non-negative integer)',
        );
      }

      final eventDocumentId = event['documentId'];
      if (eventDocumentId == null ||
          eventDocumentId is! String ||
          !_isValidUuid(eventDocumentId)) {
        throw FormatException(
          'Event at index $i: invalid or missing documentId (must be UUIDv4)',
        );
      }

      // Optional: Validate sampling interval if present
      final samplingIntervalMs = event['samplingIntervalMs'];
      if (samplingIntervalMs != null) {
        if (samplingIntervalMs is! int || samplingIntervalMs != 50) {
          _logger.w(
            'Event at index $i: samplingIntervalMs is $samplingIntervalMs '
            '(expected 50ms per Decision 5)',
          );
        }
      }
    }

    _logger.d('[$documentId] Schema validation passed for ${events.length} events');
  }

  /// Validates UUIDv4 format (simplified check).
  ///
  /// Checks for basic UUID format: 8-4-4-4-12 hex characters.
  /// Does not validate version/variant bits for simplicity.
  bool _isValidUuid(String uuid) {
    final uuidPattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return uuidPattern.hasMatch(uuid);
  }
}
