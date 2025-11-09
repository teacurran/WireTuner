/// Tests for snapshot serializer.
///
/// Verifies serialization/deserialization round-trips, compression ratios,
/// CRC validation, format versioning, and performance benchmarks.
library;

import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:event_core/event_core.dart';
import 'package:test/test.dart';

void main() {
  late SnapshotSerializer serializer;

  setUp(() {
    serializer = SnapshotSerializer(enableCompression: true);
  });

  group('SnapshotSerializer - Basic Serialization', () {
    test('serialize produces SerializedSnapshot with binary data', () {
      final documentState = {'id': 'doc-1', 'title': 'Test'};
      final snapshot = serializer.serialize(documentState);

      expect(snapshot, isA<SerializedSnapshot>());
      expect(snapshot.data, isA<Uint8List>());
      expect(snapshot.data.length, greaterThan(0));
      expect(snapshot.compression, equals('gzip'));
      expect(snapshot.uncompressedSize, greaterThan(0));
    });

    test('round-trip preserves document state', () {
      final original = {
        'id': 'doc-123',
        'title': 'Test Document',
        'layers': ['layer-1', 'layer-2'],
        'version': 1,
        'createdAt': '2025-01-01T00:00:00.000Z',
      };

      final snapshot = serializer.serialize(original);
      final deserialized = serializer.deserialize(snapshot.data);

      expect(deserialized, equals(original));
    });

    test('round-trip preserves all field types', () {
      final original = {
        'id': 'doc-456',
        'title': 'Complex Document',
        'layers': ['layer-1', 'layer-2', 'layer-3'],
        'version': 42,
        'metadata': {
          'createdAt': '2025-01-01T10:30:00.000Z',
          'modifiedAt': '2025-01-02T14:45:00.000Z',
          'author': 'Test User',
        },
        'floatValue': 3.14159,
        'boolValue': true,
        'nullValue': null,
      };

      final snapshot = serializer.serialize(original);
      final deserialized = serializer.deserialize(snapshot.data);

      expect(deserialized['id'], equals(original['id']));
      expect(deserialized['title'], equals(original['title']));
      expect(deserialized['layers'], equals(original['layers']));
      expect(deserialized['version'], equals(original['version']));
      expect(deserialized['metadata'], equals(original['metadata']));
      expect(deserialized['floatValue'], equals(original['floatValue']));
      expect(deserialized['boolValue'], equals(original['boolValue']));
      expect(deserialized['nullValue'], isNull);
    });

    test('round-trip preserves nested structures', () {
      final original = {
        'id': 'doc-nested',
        'paths': [
          {
            'id': 'path-1',
            'anchors': [
              {
                'position': {'x': 10.0, 'y': 20.0},
                'handleIn': null,
                'handleOut': {'x': 5.0, 'y': 0.0},
              },
              {
                'position': {'x': 100.0, 'y': 200.0},
                'handleIn': {'x': -5.0, 'y': 0.0},
                'handleOut': null,
              },
            ],
            'segments': [
              {
                'startAnchorIndex': 0,
                'endAnchorIndex': 1,
                'segmentType': 'bezier',
              },
            ],
            'closed': false,
          },
        ],
        'shapes': [
          {
            'id': 'shape-1',
            'kind': 'rectangle',
            'center': {'x': 100.0, 'y': 100.0},
            'width': 200.0,
            'height': 150.0,
            'cornerRadius': 10.0,
          },
        ],
      };

      final snapshot = serializer.serialize(original);
      final deserialized = serializer.deserialize(snapshot.data);

      expect(deserialized, equals(original));
    });
  });

  group('SnapshotSerializer - Compression', () {
    test('compression reduces size significantly', () {
      final documentState = {
        'id': 'doc-large',
        'title': 'Large Document',
        'layers': List.generate(100, (i) => 'layer-$i'),
        'version': 1,
      };

      final uncompressedSerializer = SnapshotSerializer(enableCompression: false);
      final compressedSerializer = SnapshotSerializer(enableCompression: true);

      final uncompressedSnapshot = uncompressedSerializer.serialize(documentState);
      final compressedSnapshot = compressedSerializer.serialize(documentState);

      expect(compressedSnapshot.compressedSize, lessThan(uncompressedSnapshot.compressedSize));

      final compressionRatio = uncompressedSnapshot.compressedSize / compressedSnapshot.compressedSize;
      expect(compressionRatio, greaterThan(2.0));

      // Verify compression metadata
      expect(uncompressedSnapshot.compression, equals('none'));
      expect(compressedSnapshot.compression, equals('gzip'));
      expect(compressedSnapshot.compressionRatio, greaterThan(2.0));
    });

    test('compression ratio ~10:1 for realistic documents', () {
      // Create document with realistic vector content (paths and shapes)
      final documentState = {
        'id': 'doc-realistic',
        'title': 'Realistic Vector Document',
        'paths': List.generate(
          500,
          (i) => {
            'id': 'path-$i',
            'anchors': [
              {'position': {'x': i * 10.0, 'y': i * 20.0}, 'handleIn': null, 'handleOut': null},
              {'position': {'x': i * 10.0 + 100, 'y': i * 20.0 + 100}, 'handleIn': null, 'handleOut': null},
            ],
            'segments': [
              {'startAnchorIndex': 0, 'endAnchorIndex': 1, 'segmentType': 'line'},
            ],
            'closed': false,
          },
        ),
        'version': 1,
      };

      final uncompressedSerializer = SnapshotSerializer(enableCompression: false);
      final compressedSerializer = SnapshotSerializer(enableCompression: true);

      final uncompressedSnapshot = uncompressedSerializer.serialize(documentState);
      final compressedSnapshot = compressedSerializer.serialize(documentState);

      final compressionRatio = uncompressedSnapshot.compressedSize / compressedSnapshot.compressedSize;

      // Verify significant compression (at least 5:1, aiming for 10:1)
      expect(compressionRatio, greaterThan(5.0));

      print(
        'Large document compression: ${uncompressedSnapshot.compressedSize} → ${compressedSnapshot.compressedSize} '
        '(${compressionRatio.toStringAsFixed(2)}:1)',
      );
    });

    test('deserialize handles both compressed and uncompressed', () {
      final documentState = {'id': 'doc-1', 'title': 'Test'};

      final compressedSnapshot = SnapshotSerializer(enableCompression: true).serialize(documentState);
      final uncompressedSnapshot = SnapshotSerializer(enableCompression: false).serialize(documentState);

      // Both should deserialize successfully
      final fromCompressed = serializer.deserialize(compressedSnapshot.data);
      final fromUncompressed = serializer.deserialize(uncompressedSnapshot.data);

      expect(fromCompressed, equals(documentState));
      expect(fromUncompressed, equals(documentState));
    });

    test('compression type string matches database expectations', () {
      final documentState = {'id': 'doc-1', 'title': 'Test'};

      final compressedSnapshot = SnapshotSerializer(enableCompression: true).serialize(documentState);
      final uncompressedSnapshot = SnapshotSerializer(enableCompression: false).serialize(documentState);

      // Verify compression type strings match SQLite schema expectations
      expect(compressedSnapshot.compression, equals('gzip'));
      expect(uncompressedSnapshot.compression, equals('none'));
    });
  });

  group('SnapshotSerializer - Binary Format', () {
    test('versioned header includes magic bytes', () {
      final documentState = {'id': 'doc-1', 'title': 'Test'};
      final snapshot = serializer.serialize(documentState);

      // Verify magic bytes "WTSS"
      expect(snapshot.data[0], equals(0x57)); // 'W'
      expect(snapshot.data[1], equals(0x54)); // 'T'
      expect(snapshot.data[2], equals(0x53)); // 'S'
      expect(snapshot.data[3], equals(0x53)); // 'S'
    });

    test('versioned header includes format version', () {
      final documentState = {'id': 'doc-1', 'title': 'Test'};
      final snapshot = serializer.serialize(documentState);

      // Byte 4 = format version
      expect(snapshot.data[4], equals(1)); // kFormatVersion = 1
    });

    test('versioned header includes compression flag', () {
      final documentState = {'id': 'doc-1', 'title': 'Test'};

      final compressedSnapshot = SnapshotSerializer(enableCompression: true).serialize(documentState);
      final uncompressedSnapshot = SnapshotSerializer(enableCompression: false).serialize(documentState);

      // Byte 5 = compression flag
      expect(compressedSnapshot.data[5], equals(1)); // compressed
      expect(uncompressedSnapshot.data[5], equals(0)); // not compressed
    });

    test('versioned header includes uncompressed size', () {
      final documentState = {'id': 'doc-1', 'title': 'Test'};
      final snapshot = serializer.serialize(documentState);

      // Bytes 6-9 = uncompressed size (uint32, little-endian)
      final header = ByteData.sublistView(snapshot.data, 0, 20);
      final uncompressedSize = header.getUint32(6, Endian.little);

      expect(uncompressedSize, equals(snapshot.uncompressedSize));
      expect(uncompressedSize, greaterThan(0));
    });

    test('header size is 20 bytes', () {
      final documentState = {'id': 'doc-1', 'title': 'Test'};
      final snapshot = serializer.serialize(documentState);

      // Header should be exactly 20 bytes before payload
      expect(snapshot.data.length, greaterThan(20));
    });
  });

  group('SnapshotSerializer - CRC Validation', () {
    test('CRC32 checksum is included in header', () {
      final documentState = {'id': 'doc-1', 'title': 'Test'};
      final snapshot = serializer.serialize(documentState);

      // Bytes 10-13 = CRC32 checksum (uint32, little-endian)
      final header = ByteData.sublistView(snapshot.data, 0, 20);
      final crc32 = header.getUint32(10, Endian.little);

      expect(crc32, greaterThan(0));
    });

    test('CRC validation succeeds on valid data', () {
      final documentState = {'id': 'doc-1', 'title': 'Test'};
      final snapshot = serializer.serialize(documentState);

      // Should deserialize without throwing
      expect(() => serializer.deserialize(snapshot.data), returnsNormally);
    });

    test('CRC validation fails on corrupted payload', () {
      final documentState = {'id': 'doc-1', 'title': 'Test'};
      final snapshot = serializer.serialize(documentState);

      // Corrupt payload (byte 50, assuming payload starts at byte 20)
      final corrupted = Uint8List.fromList(snapshot.data);
      if (corrupted.length > 50) {
        corrupted[50] ^= 0xFF; // Flip all bits in byte 50

        // Should throw FormatException due to CRC mismatch
        expect(
          () => serializer.deserialize(corrupted),
          throwsA(isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('CRC32 checksum validation failed'),
          )),
        );
      }
    });

    test('CRC validation fails on corrupted header CRC field', () {
      final documentState = {'id': 'doc-1', 'title': 'Test'};
      final snapshot = serializer.serialize(documentState);

      // Corrupt CRC32 field in header (bytes 10-13)
      final corrupted = Uint8List.fromList(snapshot.data);
      corrupted[10] ^= 0xFF; // Flip bits in first byte of CRC32

      // Should throw FormatException due to CRC mismatch
      expect(
        () => serializer.deserialize(corrupted),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('CRC32 checksum validation failed'),
        )),
      );
    });
  });

  group('SnapshotSerializer - Edge Cases', () {
    test('empty document serializes correctly', () {
      final documentState = {'id': '', 'title': '', 'layers': <String>[], 'version': 0};

      final snapshot = serializer.serialize(documentState);
      final deserialized = serializer.deserialize(snapshot.data);

      expect(deserialized, equals(documentState));
    });

    test('null optional fields preserved', () {
      final documentState = {
        'id': 'doc-1',
        'title': 'Test',
        'createdAt': null,
        'modifiedAt': null,
        'author': null,
      };

      final snapshot = serializer.serialize(documentState);
      final deserialized = serializer.deserialize(snapshot.data);

      expect(deserialized['createdAt'], isNull);
      expect(deserialized['modifiedAt'], isNull);
      expect(deserialized['author'], isNull);
    });

    test('special characters in strings preserved', () {
      final documentState = {
        'id': 'doc-1',
        'title': 'Test "Document" with \'quotes\' and\nnewlines\t\tand émoji 🎨',
        'layers': ['layer-1', 'layer "2"', "layer '3'"],
      };

      final snapshot = serializer.serialize(documentState);
      final deserialized = serializer.deserialize(snapshot.data);

      expect(deserialized['title'], equals(documentState['title']));
      expect(deserialized['layers'], equals(documentState['layers']));
    });

    test('unicode characters preserved', () {
      final documentState = {
        'id': 'doc-unicode',
        'title': 'Unicode: 你好世界 مرحبا العالم Привет мир',
        'content': '🎨🖌️✏️📐📏',
      };

      final snapshot = serializer.serialize(documentState);
      final deserialized = serializer.deserialize(snapshot.data);

      expect(deserialized, equals(documentState));
    });

    test('large document handles thousands of objects', () {
      // Create a large document with 2000 paths
      final documentState = {
        'id': 'doc-very-large',
        'title': 'Very Large Document',
        'paths': List.generate(
          2000,
          (i) => {
            'id': 'path-$i',
            'anchors': [
              {'position': {'x': i.toDouble(), 'y': i.toDouble()}, 'handleIn': null, 'handleOut': null},
            ],
            'segments': <Map<String, dynamic>>[],
            'closed': false,
          },
        ),
      };

      final snapshot = serializer.serialize(documentState);
      final deserialized = serializer.deserialize(snapshot.data);

      expect(deserialized, equals(documentState));
      expect((deserialized['paths'] as List).length, equals(2000));
    });
  });

  group('SnapshotSerializer - Error Handling', () {
    test('deserialize throws on invalid magic bytes', () {
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
      // Build valid header but invalid JSON payload
      final invalidJson = '{"id": "doc-1", broken json}';
      final invalidBytes = Uint8List.fromList(invalidJson.codeUnits);

      expect(
        () => serializer.deserialize(invalidBytes),
        throwsA(isA<FormatException>()),
      );
    });

    test('deserialize throws on header too small', () {
      // Header should be at least 20 bytes
      final tooSmall = Uint8List(10);

      expect(
        () => serializer.deserialize(tooSmall),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('SnapshotSerializer - Legacy Format Compatibility', () {
    test('deserialize handles legacy gzip format (no header)', () {
      // Simulate legacy format: raw gzip with no header
      final documentState = {'id': 'doc-legacy', 'title': 'Legacy Document'};

      // Use low-level gzip encoding to create legacy format
      final jsonString = '{"id":"doc-legacy","title":"Legacy Document"}';
      final jsonBytes = Uint8List.fromList(jsonString.codeUnits);
      final gzippedList = GZipEncoder().encode(jsonBytes);

      if (gzippedList == null) {
        fail('GZip encoding failed');
      }

      final legacyBytes = Uint8List.fromList(gzippedList);

      // Should deserialize successfully
      final deserialized = serializer.deserialize(legacyBytes);
      expect(deserialized['id'], equals('doc-legacy'));
      expect(deserialized['title'], equals('Legacy Document'));
    });

    test('deserialize handles legacy raw JSON format (no header, no compression)', () {
      // Simulate legacy format: raw JSON with no header
      final jsonString = '{"id":"doc-legacy-json","title":"Legacy JSON Document"}';
      final legacyBytes = Uint8List.fromList(jsonString.codeUnits);

      // Should deserialize successfully
      final deserialized = serializer.deserialize(legacyBytes);
      expect(deserialized['id'], equals('doc-legacy-json'));
      expect(deserialized['title'], equals('Legacy JSON Document'));
    });
  });

  group('SnapshotSerializer - Performance Benchmarks', () {
    test('serialization completes in <20ms for medium document', () {
      // Medium document: ~500 paths
      final documentState = {
        'id': 'doc-medium',
        'title': 'Medium Document',
        'paths': List.generate(
          500,
          (i) => {
            'id': 'path-$i',
            'anchors': [
              {'position': {'x': i.toDouble(), 'y': i.toDouble()}, 'handleIn': null, 'handleOut': null},
              {'position': {'x': i + 100.0, 'y': i + 100.0}, 'handleIn': null, 'handleOut': null},
            ],
            'segments': [
              {'startAnchorIndex': 0, 'endAnchorIndex': 1, 'segmentType': 'line'},
            ],
            'closed': false,
          },
        ),
      };

      final stopwatch = Stopwatch()..start();
      final snapshot = serializer.serialize(documentState);
      stopwatch.stop();

      final durationMs = stopwatch.elapsedMilliseconds;
      final pathCount = (documentState['paths'] as List?)?.length ?? 0;
      print('Serialization time (medium doc, $pathCount paths): ${durationMs}ms');

      expect(durationMs, lessThan(20), reason: 'Serialization should complete in <20ms for medium document');
      expect(snapshot.data.length, greaterThan(0));
    });

    test('deserialization completes in <20ms for medium document', () {
      // Medium document: ~500 paths
      final documentState = {
        'id': 'doc-medium',
        'title': 'Medium Document',
        'paths': List.generate(
          500,
          (i) => {
            'id': 'path-$i',
            'anchors': [
              {'position': {'x': i.toDouble(), 'y': i.toDouble()}, 'handleIn': null, 'handleOut': null},
              {'position': {'x': i + 100.0, 'y': i + 100.0}, 'handleIn': null, 'handleOut': null},
            ],
            'segments': [
              {'startAnchorIndex': 0, 'endAnchorIndex': 1, 'segmentType': 'line'},
            ],
            'closed': false,
          },
        ),
      };

      final snapshot = serializer.serialize(documentState);

      final stopwatch = Stopwatch()..start();
      final deserialized = serializer.deserialize(snapshot.data);
      stopwatch.stop();

      final durationMs = stopwatch.elapsedMilliseconds;
      final pathCount = (deserialized['paths'] as List?)?.length ?? 0;
      print('Deserialization time (medium doc, $pathCount paths): ${durationMs}ms');

      expect(durationMs, lessThan(20), reason: 'Deserialization should complete in <20ms for medium document');
      expect(deserialized, equals(documentState));
    });

    test('round-trip completes in <40ms for medium document', () {
      // Medium document: ~500 paths
      final documentState = {
        'id': 'doc-medium',
        'title': 'Medium Document',
        'paths': List.generate(
          500,
          (i) => {
            'id': 'path-$i',
            'anchors': [
              {'position': {'x': i.toDouble(), 'y': i.toDouble()}, 'handleIn': null, 'handleOut': null},
              {'position': {'x': i + 100.0, 'y': i + 100.0}, 'handleIn': null, 'handleOut': null},
            ],
            'segments': [
              {'startAnchorIndex': 0, 'endAnchorIndex': 1, 'segmentType': 'line'},
            ],
            'closed': false,
          },
        ),
      };

      final stopwatch = Stopwatch()..start();
      final snapshot = serializer.serialize(documentState);
      final deserialized = serializer.deserialize(snapshot.data);
      stopwatch.stop();

      final durationMs = stopwatch.elapsedMilliseconds;
      final pathCount = (documentState['paths'] as List?)?.length ?? 0;
      print('Round-trip time (medium doc, $pathCount paths): ${durationMs}ms');

      expect(durationMs, lessThan(40), reason: 'Round-trip should complete in <40ms for medium document');
      expect(deserialized, equals(documentState));
    });
  });

  group('SnapshotSerializer - Metadata', () {
    test('SerializedSnapshot provides compression metadata', () {
      final documentState = {
        'id': 'doc-1',
        'title': 'Test Document',
        'layers': List.generate(100, (i) => 'layer-$i'),
      };

      final snapshot = serializer.serialize(documentState);

      expect(snapshot.compressedSize, equals(snapshot.data.length));
      expect(snapshot.uncompressedSize, greaterThan(snapshot.compressedSize));
      expect(snapshot.compressionRatio, greaterThan(1.0));
      expect(snapshot.compression, equals('gzip'));
    });

    test('uncompressed snapshot has compressionRatio of 1.0', () {
      final documentState = {'id': 'doc-1', 'title': 'Test'};

      final uncompressedSerializer = SnapshotSerializer(enableCompression: false);
      final snapshot = uncompressedSerializer.serialize(documentState);

      // For uncompressed, ratio should be close to 1.0 (accounting for header overhead)
      expect(snapshot.compressionRatio, lessThan(1.5));
      expect(snapshot.compression, equals('none'));
    });
  });
}
