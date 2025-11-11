import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:logger/logger.dart';
import 'package:wiretuner/domain/document/document.dart';

/// Serializes and deserializes document snapshots to/from binary format.
///
/// This serializer converts document objects to JSON, optionally compresses them
/// using gzip, and stores them as binary data suitable for SQLite BLOB columns.
///
/// **Design Rationale** (from ADR-003):
/// - JSON encoding for human-readable debugging
/// - gzip compression for 10:1 compression ratio on typical documents
/// - Automatic compression detection via magic bytes
/// - Consistent with event storage format (JSON + gzip)
///
/// **Platform Compatibility**: This serializer uses dart:io for gzip compression,
/// which is only available on desktop and server platforms (macOS, Windows, Linux).
/// It will NOT work in Flutter web builds.
///
/// **Performance Note**: Serialization is synchronous and may take 50-100ms
/// for large documents (10MB+ JSON). For Milestone 0.1 target documents
/// (< 1MB), this is acceptable. If performance becomes an issue, consider
/// async serialization or chunking.
class SnapshotSerializer {
  SnapshotSerializer({this.enableCompression = true});
  final Logger _logger = Logger();
  final bool enableCompression;

  /// Serializes a document to uncompressed JSON bytes (UTF-8).
  ///
  /// This method is useful for calculating telemetry metrics like compression ratio.
  /// Returns the uncompressed byte representation of the document.
  ///
  /// Example:
  /// ```dart
  /// final serializer = SnapshotSerializer(enableCompression: true);
  /// final uncompressedBytes = serializer.serializeToJson(document);
  /// final uncompressedSize = uncompressedBytes.length;
  /// ```
  Uint8List serializeToJson(dynamic document) {
    try {
      // Step 1: Document → JSON Map
      final jsonMap = _toJson(document);

      // Step 2: JSON Map → String
      final jsonString = jsonEncode(jsonMap);

      // Step 3: String → UTF-8 bytes
      final bytes = utf8.encode(jsonString);

      return Uint8List.fromList(bytes);
    } catch (e, stackTrace) {
      _logger.e('Failed to serialize document to JSON',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Serializes a document to binary format (JSON + optional gzip).
  ///
  /// The serialization process:
  /// 1. Convert document to JSON via toJson()
  /// 2. Encode JSON to UTF-8 string
  /// 3. If compression enabled, gzip the bytes
  /// 4. Return Uint8List
  ///
  /// Returns compressed binary snapshot suitable for storage in SQLite BLOB.
  ///
  /// Example:
  /// ```dart
  /// final serializer = SnapshotSerializer(enableCompression: true);
  /// final bytes = serializer.serialize(document);
  /// // Store bytes in SQLite BLOB column
  /// ```
  Uint8List serialize(dynamic document) {
    try {
      // Extract document ID for logging (handle both Map and object with id property)
      final docId = _getDocumentId(document);
      _logger.d('Serializing document: $docId');

      // Step 1: Document → JSON Map
      final jsonMap = _toJson(document);

      // Step 2: JSON Map → String
      final jsonString = jsonEncode(jsonMap);

      // Step 3: String → UTF-8 bytes
      final bytes = utf8.encode(jsonString);

      // Step 4: Compress if enabled
      if (enableCompression) {
        final compressed = gzip.encode(bytes);
        _logger.d(
          'Serialized document $docId: '
          '${bytes.length} bytes → ${compressed.length} bytes '
          '(${((1 - compressed.length / bytes.length) * 100).toStringAsFixed(1)}% reduction)',
        );
        return Uint8List.fromList(compressed);
      } else {
        _logger.d(
            'Serialized document $docId: ${bytes.length} bytes (uncompressed)');
        return Uint8List.fromList(bytes);
      }
    } catch (e, stackTrace) {
      _logger.e('Failed to serialize document',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Deserializes binary snapshot back to Document.
  ///
  /// The deserialization process:
  /// 1. Detect if data is compressed (gzip magic bytes: 0x1f, 0x8b)
  /// 2. Decompress if needed
  /// 3. Decode UTF-8 bytes to string
  /// 4. Parse JSON string to Map
  /// 5. Migrate legacy schema if needed (v1 → v2)
  /// 6. Hydrate Document via fromJson()
  ///
  /// This method returns a typed [Document] instance by using the Document's
  /// fromJson factory. The Document model handles schema versioning and
  /// migrations internally.
  ///
  /// **Legacy Schema Migration (v1 → v2)**:
  /// If the snapshot contains schema version 1 or has 'layers' at document root:
  /// - Creates a default artboard with id 'default-artboard-{documentId}'
  /// - Moves layers/selection/viewport into the default artboard
  /// - Updates schemaVersion to 2
  /// - Removes deprecated fields from document root
  ///
  /// Throws [FormatException] if data is corrupted or invalid.
  ///
  /// Example:
  /// ```dart
  /// final serializer = SnapshotSerializer(enableCompression: true);
  /// final document = serializer.deserialize(bytes);
  /// assert(document is Document);
  /// ```
  Document deserialize(Uint8List bytes) {
    try {
      _logger.d('Deserializing snapshot (${bytes.length} bytes)');

      // Step 1: Detect compression (gzip magic bytes)
      final isCompressed =
          bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;

      // Step 2: Decompress if needed
      List<int> decompressed;
      if (isCompressed) {
        decompressed = gzip.decode(bytes);
        _logger.d(
            'Decompressed: ${bytes.length} bytes → ${decompressed.length} bytes');
      } else {
        decompressed = bytes;
      }

      // Step 3: UTF-8 bytes → String
      final jsonString = utf8.decode(decompressed);

      // Step 4: String → JSON Map
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;

      // Step 5: Migrate legacy v1 schema if needed
      final migratedJson = _migrateLegacySchema(jsonMap);

      // Step 6: Hydrate Document from JSON
      final document = Document.fromJson(migratedJson);
      _logger.d('Deserialized document: ${document.id}');
      return document;
    } on FormatException catch (e) {
      _logger.e(
        'Failed to deserialize snapshot: Invalid JSON format',
        error: e,
      );
      throw FormatException(
        'Snapshot deserialization failed: Invalid JSON format. '
        'Data may be corrupted or not a valid snapshot. '
        'Original error: ${e.message}',
      );
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to deserialize snapshot',
        error: e,
        stackTrace: stackTrace,
      );
      throw Exception(
        'Snapshot deserialization failed: $e. '
        'This may indicate a schema version mismatch or corrupted data.',
      );
    }
  }

  /// Migrates legacy schema v1 snapshots to v2 (multi-artboard).
  ///
  /// Detects v1 snapshots by:
  /// - schemaVersion == 1 OR
  /// - 'layers' field exists at document root AND no 'artboards' field (v1 structure)
  ///
  /// Migration process:
  /// 1. Extract layers, selection, viewport from document root
  /// 2. Create default artboard with those fields
  /// 3. Remove deprecated fields from document
  /// 4. Update schemaVersion to 2
  Map<String, dynamic> _migrateLegacySchema(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'] as int? ?? 1;
    final hasLegacyLayers = json.containsKey('layers');
    final hasArtboards = json.containsKey('artboards');

    // Check if migration is needed
    // V2 documents have artboards OR schemaVersion == 2 without legacy layers
    if (hasArtboards || (schemaVersion == 2 && !hasLegacyLayers)) {
      // Already v2 schema, no migration needed
      return json;
    }

    // Migrate v1 documents: schemaVersion == 1 OR has layers without artboards
    if (schemaVersion == 1 || (hasLegacyLayers && !hasArtboards)) {
      _logger.i(
        'Migrating legacy v1 snapshot to v2 for document: ${json['id']}',
      );

      // Extract legacy fields
      final layers = json['layers'] as List? ?? [];

      // Handle selection with proper type casting for anchorIndices
      final legacySelection = json['selection'] as Map<String, dynamic>?;
      final selection = legacySelection != null
          ? <String, dynamic>{
              'objectIds': legacySelection['objectIds'] ?? <dynamic>[],
              'anchorIndices': (legacySelection['anchorIndices'] as Map? ?? <dynamic, dynamic>{})
                  .map<String, dynamic>((key, value) =>
                      MapEntry(key.toString(), value)),
            }
          : <String, dynamic>{'objectIds': <dynamic>[], 'anchorIndices': <String, dynamic>{}};

      final viewport = json['viewport'] as Map<String, dynamic>? ?? <String, dynamic>{
            'pan': <String, dynamic>{'x': 0, 'y': 0},
            'zoom': 1.0,
            'canvasSize': <String, dynamic>{'width': 800, 'height': 600},
          };
      final documentId = json['id'] as String;

      // Create default artboard with legacy state
      final defaultArtboard = {
        'id': 'default-artboard-$documentId',
        'name': 'Artboard 1',
        'bounds': {'x': 0, 'y': 0, 'width': 800, 'height': 600},
        'backgroundColor': '#FFFFFF',
        'preset': null,
        'layers': layers,
        'selection': selection,
        'viewport': viewport,
      };

      // Build migrated document
      final migratedJson = Map<String, dynamic>.from(json);
      migratedJson['schemaVersion'] = 2;
      migratedJson['artboards'] = [defaultArtboard];

      // Remove deprecated v1 fields
      migratedJson.remove('layers');
      migratedJson.remove('selection');
      migratedJson.remove('viewport');

      _logger.i('Successfully migrated v1 → v2 snapshot for ${json['id']}');
      return migratedJson;
    }

    // Unknown schema version
    throw Exception(
      'Unsupported schema version: $schemaVersion. '
      'This snapshot may be from a newer version of WireTuner.',
    );
  }

  /// Helper to extract document ID for logging.
  String _getDocumentId(dynamic document) {
    if (document is Map) {
      return document['id']?.toString() ?? 'unknown';
    }
    try {
      // Try to access id property via reflection (works for freezed classes)
      return (document as dynamic).id?.toString() ?? 'unknown';
    } catch (_) {
      return 'unknown';
    }
  }

  /// Helper to convert document to JSON map.
  Map<String, dynamic> _toJson(dynamic document) {
    if (document is Map<String, dynamic>) {
      return document;
    }
    // Assume document has toJson() method (standard for freezed classes)
    if (document is Document) {
      return document.toJson();
    }
    // Fallback for other types (should not happen in normal use)
    // ignore: avoid_dynamic_calls
    return (document as dynamic).toJson() as Map<String, dynamic>;
  }
}
