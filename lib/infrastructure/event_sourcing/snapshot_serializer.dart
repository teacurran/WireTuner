/// Snapshot serialization for Document objects.
///
/// Converts Document objects to/from binary format using JSON encoding with
/// optional gzip compression. This serializer is used by SnapshotManager to
/// store document snapshots in SQLite BLOBs.
///
/// **Platform Compatibility**: This serializer uses dart:io for gzip compression,
/// which is only available on desktop and server platforms (macOS, Windows, Linux).
/// It will NOT work in Flutter web builds.
///
/// **Performance Note**: Serialization is synchronous and may take 50-100ms
/// for large documents (10MB+ JSON). For Milestone 0.1 target documents
/// (< 1MB), this is acceptable. If performance becomes an issue, consider
/// async serialization or chunking.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:logger/logger.dart';

/// Serializes and deserializes Document snapshots to/from binary format.
///
/// Serialization pipeline:
/// Document → JSON Map → JSON String → UTF-8 bytes → gzip (optional) → Uint8List
///
/// Deserialization pipeline:
/// Uint8List → detect compression → decompress (optional) → UTF-8 String → JSON Map → Document
///
/// Example usage:
/// ```dart
/// final serializer = SnapshotSerializer<Document>(
///   fromJson: Document.fromJson,
///   enableCompression: true,
/// );
/// final document = Document(id: 'doc-1', title: 'My Document');
///
/// // Serialize
/// final bytes = serializer.serialize(document);
///
/// // Deserialize
/// final restored = serializer.deserialize(bytes);
/// ```
class SnapshotSerializer<T> {
  final Logger _logger = Logger();
  final bool enableCompression;
  final T Function(Map<String, dynamic> json) fromJson;

  /// Creates a new SnapshotSerializer.
  ///
  /// [fromJson] - Factory function to construct T from JSON map.
  /// [enableCompression] - Whether to apply gzip compression (default: true).
  /// Compression typically achieves 10:1 ratio for JSON documents with
  /// repeated structure. Disable for testing or debugging.
  SnapshotSerializer({
    required this.fromJson,
    this.enableCompression = true,
  });

  /// Serializes a Document to binary format (JSON + optional gzip).
  ///
  /// The serialization process:
  /// 1. Convert Document to JSON via toJson()
  /// 2. Encode JSON to UTF-8 string
  /// 3. If compression enabled, gzip the bytes
  /// 4. Return Uint8List
  ///
  /// Returns compressed binary snapshot suitable for storage in SQLite BLOB.
  ///
  /// Throws [Exception] if serialization fails (e.g., invalid Document state).
  Uint8List serialize(dynamic document) {
    try {
      // Extract document ID for logging (assumes document has id field)
      final documentId = _extractDocumentId(document);
      _logger.d('Serializing document: $documentId');

      // Step 1: Document → JSON Map
      final jsonMap = document.toJson() as Map<String, dynamic>;

      // Step 2: JSON Map → String
      final jsonString = jsonEncode(jsonMap);

      // Step 3: String → UTF-8 bytes
      final bytes = utf8.encode(jsonString);

      // Step 4: Compress if enabled
      if (enableCompression) {
        final compressed = gzip.encode(bytes);
        _logger.d(
          'Serialized document $documentId: '
          '${bytes.length} bytes → ${compressed.length} bytes '
          '(${((1 - compressed.length / bytes.length) * 100).toStringAsFixed(1)}% reduction)',
        );
        return Uint8List.fromList(compressed);
      } else {
        _logger.d(
          'Serialized document $documentId: ${bytes.length} bytes (uncompressed)',
        );
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
  /// 5. Construct Document via fromJson()
  ///
  /// The deserializer automatically detects compressed vs uncompressed data
  /// by checking for gzip magic bytes, allowing transparent handling of both
  /// formats.
  ///
  /// Throws [FormatException] if data is corrupted or invalid JSON.
  /// Throws [Exception] if decompression fails or Document construction fails.
  T deserialize(Uint8List bytes) {
    try {
      _logger.d('Deserializing snapshot (${bytes.length} bytes)');

      // Step 1: Detect compression (gzip magic bytes: 0x1f, 0x8b)
      final isCompressed =
          bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;

      // Step 2: Decompress if needed
      List<int> decompressed;
      if (isCompressed) {
        decompressed = gzip.decode(bytes);
        _logger.d(
          'Decompressed: ${bytes.length} bytes → ${decompressed.length} bytes',
        );
      } else {
        decompressed = bytes;
      }

      // Step 3: UTF-8 bytes → String
      final jsonString = utf8.decode(decompressed);

      // Step 4: String → JSON Map
      final jsonMap = jsonDecode(jsonString);
      if (jsonMap is! Map<String, dynamic>) {
        throw FormatException(
          'Snapshot deserialization failed: Expected JSON object, got ${jsonMap.runtimeType}',
        );
      }

      // Step 5: JSON Map → Document (using provided fromJson factory)
      final document = fromJson(jsonMap);

      final documentId = jsonMap['id'] ?? 'unknown';
      _logger.d('Deserialized document: $documentId');

      return document;
    } on FormatException catch (e) {
      _logger.e('Failed to deserialize snapshot: Invalid format', error: e);
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

  /// Extracts document ID for logging purposes.
  String _extractDocumentId(dynamic document) {
    try {
      // Try to access id field via reflection/duck typing
      return document.toJson()['id']?.toString() ?? 'unknown';
    } catch (e) {
      return 'unknown';
    }
  }
}
