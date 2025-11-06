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

  factory Document.fromJson(Map<String, dynamic> json) => _$DocumentFromJson(json);
}

void main() {
  late SnapshotSerializer serializer;

  setUp(() {
    serializer = SnapshotSerializer(enableCompression: true);
  });

  group('SnapshotSerializer - Basic Serialization', () {
    test('serialize produces Uint8List', () {
      final document = const Document(id: 'doc-1', title: 'Test');
      final bytes = serializer.serialize(document);

      expect(bytes, isA<Uint8List>());
      expect(bytes.length, greaterThan(0));
    });

    test('round-trip preserves document', () {
      final original = Document(
        id: 'doc-123',
        title: 'Test Document',
        layers: const ['layer-1', 'layer-2'],
        version: 1,
        createdAt: DateTime(2025, 1, 1),
      );

      final bytes = serializer.serialize(original);
      final jsonMap = serializer.deserialize(bytes) as Map<String, dynamic>;
      final deserialized = Document.fromJson(jsonMap);

      expect(deserialized, equals(original));
    });

    test('round-trip preserves all fields', () {
      final original = Document(
        id: 'doc-456',
        title: 'Complex Document',
        layers: const ['layer-1', 'layer-2', 'layer-3'],
        version: 42,
        createdAt: DateTime(2025, 1, 1, 10, 30),
        modifiedAt: DateTime(2025, 1, 2, 14, 45),
      );

      final bytes = serializer.serialize(original);
      final jsonMap = serializer.deserialize(bytes) as Map<String, dynamic>;
      final deserialized = Document.fromJson(jsonMap);

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

      final uncompressedSerializer = SnapshotSerializer(enableCompression: false);
      final compressedSerializer = SnapshotSerializer(enableCompression: true);

      final uncompressedBytes = uncompressedSerializer.serialize(document);
      final compressedBytes = compressedSerializer.serialize(document);

      expect(compressedBytes.length, lessThan(uncompressedBytes.length));

      final compressionRatio = uncompressedBytes.length / compressedBytes.length;
      expect(compressionRatio, greaterThan(2.0));

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

      final uncompressedSerializer = SnapshotSerializer(enableCompression: false);
      final compressedSerializer = SnapshotSerializer(enableCompression: true);

      final uncompressedBytes = uncompressedSerializer.serialize(document);
      final compressedBytes = compressedSerializer.serialize(document);

      final compressionRatio = uncompressedBytes.length / compressedBytes.length;

      // Verify significant compression (at least 5:1, aiming for 10:1)
      expect(compressionRatio, greaterThan(5.0));

      print('Large document compression: ${uncompressedBytes.length} → ${compressedBytes.length} '
            '(${compressionRatio.toStringAsFixed(2)}:1)');
    });

    test('deserialize handles both compressed and uncompressed', () {
      const document = Document(id: 'doc-1', title: 'Test');

      final compressedBytes = SnapshotSerializer(enableCompression: true).serialize(document);
      final uncompressedBytes = SnapshotSerializer(enableCompression: false).serialize(document);

      // Both should deserialize successfully
      final fromCompressedMap = serializer.deserialize(compressedBytes) as Map<String, dynamic>;
      final fromUncompressedMap = serializer.deserialize(uncompressedBytes) as Map<String, dynamic>;
      final fromCompressed = Document.fromJson(fromCompressedMap);
      final fromUncompressed = Document.fromJson(fromUncompressedMap);

      expect(fromCompressed, equals(document));
      expect(fromUncompressed, equals(document));
    });
  });

  group('SnapshotSerializer - Edge Cases', () {
    test('empty document serializes correctly', () {
      const document = Document(id: '', title: '', layers: [], version: 0);

      final bytes = serializer.serialize(document);
      final jsonMap = serializer.deserialize(bytes) as Map<String, dynamic>;
      final deserialized = Document.fromJson(jsonMap);

      expect(deserialized, equals(document));
    });

    test('null optional fields preserved', () {
      const document = Document(
        id: 'doc-1',
        title: 'Test',
        createdAt: null,
        modifiedAt: null,
      );

      final bytes = serializer.serialize(document);
      final jsonMap = serializer.deserialize(bytes) as Map<String, dynamic>;
      final deserialized = Document.fromJson(jsonMap);

      expect(deserialized.createdAt, isNull);
      expect(deserialized.modifiedAt, isNull);
    });

    test('special characters in strings preserved', () {
      const document = Document(
        id: 'doc-1',
        title: 'Test "Document" with \'quotes\' and\nnewlines\t\tand émoji 🎨',
        layers: ['layer-1', 'layer "2"', "layer '3'"],
      );

      final bytes = serializer.serialize(document);
      final jsonMap = serializer.deserialize(bytes) as Map<String, dynamic>;
      final deserialized = Document.fromJson(jsonMap);

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
      const invalidJson = '{"id": "doc-1", broken json}';
      final bytes = Uint8List.fromList(invalidJson.codeUnits);

      expect(
        () => serializer.deserialize(bytes),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
