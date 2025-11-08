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
      _logger.e('Failed to serialize document to JSON', error: e, stackTrace: stackTrace);
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
        _logger.d('Serialized document $docId: ${bytes.length} bytes (uncompressed)');
        return Uint8List.fromList(bytes);
      }
    } catch (e, stackTrace) {
      _logger.e('Failed to serialize document', error: e, stackTrace: stackTrace);
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
  /// 5. Hydrate Document via fromJson()
  ///
  /// This method returns a typed [Document] instance by using the Document's
  /// fromJson factory. The Document model handles schema versioning and
  /// migrations internally.
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
      final isCompressed = bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;

      // Step 2: Decompress if needed
      List<int> decompressed;
      if (isCompressed) {
        decompressed = gzip.decode(bytes);
        _logger.d('Decompressed: ${bytes.length} bytes → ${decompressed.length} bytes');
      } else {
        decompressed = bytes;
      }

      // Step 3: UTF-8 bytes → String
      final jsonString = utf8.decode(decompressed);

      // Step 4: String → JSON Map
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;

      // Step 5: Hydrate Document from JSON
      final document = Document.fromJson(jsonMap);
      _logger.d('Deserialized document: ${document.id}');
      return document;
    } on FormatException catch (e) {
      _logger.e('Failed to deserialize snapshot: Invalid JSON format', error: e);
      throw FormatException(
        'Snapshot deserialization failed: Invalid JSON format. '
        'Data may be corrupted or not a valid snapshot. '
        'Original error: ${e.message}',
      );
    } catch (e, stackTrace) {
      _logger.e('Failed to deserialize snapshot', error: e, stackTrace: stackTrace);
      throw Exception(
        'Snapshot deserialization failed: $e. '
        'This may indicate a schema version mismatch or corrupted data.',
      );
    }
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
    return (document as dynamic).toJson() as Map<String, dynamic>;
  }
}
