/// Tests for SnapshotSerializer.
///
/// **Setup Required**: Before running tests, generate code:
/// ```
/// flutter pub run build_runner build --delete-conflicting-outputs
/// ```

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/infrastructure/event_sourcing/snapshot_serializer.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'snapshot_serializer_test.freezed.dart';
part 'snapshot_serializer_test.g.dart';

/// Placeholder Document class for testing SnapshotSerializer.
/// This will be replaced by the real Document model in Iteration 3 (I3.T6).
@freezed
class Document with _$Document {
  const factory Document({
    required String id,
    required String title,
    @Default([]) List<String> layers,
    @Default(0) int version,
    DateTime? createdAt,
    DateTime? modifiedAt,
  }) = _Document;

  factory Document.fromJson(Map<String, dynamic> json) =>
      _$DocumentFromJson(json);
}

void main() {
  late SnapshotSerializer<Document> serializer;

  setUp(() {
    serializer = SnapshotSerializer<Document>(
      fromJson: Document.fromJson,
      enableCompression: true,
    );
  });

  group('SnapshotSerializer - Basic Serialization', () {
    test('serialize produces Uint8List', () {
      final document = Document(id: 'doc-1', title: 'Test');
      final bytes = serializer.serialize(document);

      expect(bytes, isA<Uint8List>());
      expect(bytes.length, greaterThan(0));
    });

    test('round-trip preserves document', () {
      final original = Document(
        id: 'doc-123',
        title: 'Test Document',
        layers: ['layer-1', 'layer-2'],
        version: 1,
        createdAt: DateTime(2025, 1, 1),
      );

      final bytes = serializer.serialize(original);
      final deserialized = serializer.deserialize(bytes);

      expect(deserialized, equals(original));
    });

    test('round-trip preserves all fields', () {
      final original = Document(
        id: 'doc-456',
        title: 'Complex Document',
        layers: ['layer-1', 'layer-2', 'layer-3'],
        version: 42,
        createdAt: DateTime(2025, 1, 1, 10, 30),
        modifiedAt: DateTime(2025, 1, 2, 14, 45),
      );

      final bytes = serializer.serialize(original);
      final deserialized = serializer.deserialize(bytes);

      expect(deserialized.id, equals(original.id));
      expect(deserialized.title, equals(original.title));
      expect(deserialized.layers, equals(original.layers));
      expect(deserialized.version, equals(original.version));
      expect(deserialized.createdAt, equals(original.createdAt));
      expect(deserialized.modifiedAt, equals(original.modifiedAt));
    });
  });

  group('SnapshotSerializer - Compression', () {
    test('compression reduces size significantly', () {
      final document = Document(
        id: 'doc-large',
        title: 'Large Document',
        layers: List.generate(100, (i) => 'layer-$i'),
        version: 1,
      );

      final uncompressedSerializer = SnapshotSerializer<Document>(
        fromJson: Document.fromJson,
        enableCompression: false,
      );
      final compressedSerializer = SnapshotSerializer<Document>(
        fromJson: Document.fromJson,
        enableCompression: true,
      );

      final uncompressedBytes = uncompressedSerializer.serialize(document);
      final compressedBytes = compressedSerializer.serialize(document);

      expect(compressedBytes.length, lessThan(uncompressedBytes.length));

      final compressionRatio = uncompressedBytes.length / compressedBytes.length;
      expect(compressionRatio, greaterThan(2.0));

      // ignore: avoid_print
      print('Compression: ${uncompressedBytes.length} → ${compressedBytes.length} '
          '(${compressionRatio.toStringAsFixed(2)}:1)');
    });

    test('compression ratio ~10:1 for realistic documents', () {
      // Create document with 1000 layers (realistic large document)
      final document = Document(
        id: 'doc-very-large',
        title: 'Very Large Document with Many Layers',
        layers: List.generate(1000, (i) => 'layer-$i-with-some-content'),
        version: 100,
      );

      final uncompressedSerializer = SnapshotSerializer<Document>(
        fromJson: Document.fromJson,
        enableCompression: false,
      );
      final compressedSerializer = SnapshotSerializer<Document>(
        fromJson: Document.fromJson,
        enableCompression: true,
      );

      final uncompressedBytes = uncompressedSerializer.serialize(document);
      final compressedBytes = compressedSerializer.serialize(document);

      final compressionRatio = uncompressedBytes.length / compressedBytes.length;

      // Verify significant compression (at least 5:1, aiming for 10:1)
      expect(compressionRatio, greaterThan(5.0));

      // ignore: avoid_print
      print(
          'Large document compression: ${uncompressedBytes.length} → ${compressedBytes.length} '
          '(${compressionRatio.toStringAsFixed(2)}:1)');
    });

    test('deserialize handles both compressed and uncompressed', () {
      final document = Document(id: 'doc-1', title: 'Test');

      final compressedBytes = SnapshotSerializer<Document>(
        fromJson: Document.fromJson,
        enableCompression: true,
      ).serialize(document);
      final uncompressedBytes = SnapshotSerializer<Document>(
        fromJson: Document.fromJson,
        enableCompression: false,
      ).serialize(document);

      // Both should deserialize successfully
      final fromCompressed = serializer.deserialize(compressedBytes);
      final fromUncompressed = serializer.deserialize(uncompressedBytes);

      expect(fromCompressed, equals(document));
      expect(fromUncompressed, equals(document));
    });
  });

  group('SnapshotSerializer - Edge Cases', () {
    test('empty document serializes correctly', () {
      final document = Document(id: '', title: '', layers: [], version: 0);

      final bytes = serializer.serialize(document);
      final deserialized = serializer.deserialize(bytes);

      expect(deserialized, equals(document));
    });

    test('null optional fields preserved', () {
      final document = Document(
        id: 'doc-1',
        title: 'Test',
        createdAt: null,
        modifiedAt: null,
      );

      final bytes = serializer.serialize(document);
      final deserialized = serializer.deserialize(bytes);

      expect(deserialized.createdAt, isNull);
      expect(deserialized.modifiedAt, isNull);
    });

    test('special characters in strings preserved', () {
      final document = Document(
        id: 'doc-1',
        title: 'Test "Document" with \'quotes\' and\nnewlines\t\tand émoji 🎨',
        layers: ['layer-1', 'layer "2"', "layer '3'"],
      );

      final bytes = serializer.serialize(document);
      final deserialized = serializer.deserialize(bytes);

      expect(deserialized.title, equals(document.title));
      expect(deserialized.layers, equals(document.layers));
    });
  });

  group('SnapshotSerializer - Error Handling', () {
    test('deserialize throws on invalid data', () {
      final invalidBytes = Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF]);

      expect(
        () => serializer.deserialize(invalidBytes),
        throwsA(isA<Exception>()),
      );
    });

    test('deserialize throws on corrupted gzip data', () {
      // gzip magic bytes but corrupted payload
      final corruptedBytes = Uint8List.fromList([0x1f, 0x8b, 0xFF, 0xFF]);

      expect(
        () => serializer.deserialize(corruptedBytes),
        throwsA(isA<Exception>()),
      );
    });

    test('deserialize throws on malformed JSON', () {
      // Valid UTF-8 but invalid JSON
      final invalidJson = '{"id": "doc-1", broken json}';
      final bytes = Uint8List.fromList(invalidJson.codeUnits);

      expect(
        () => serializer.deserialize(bytes),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
