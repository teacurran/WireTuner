import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/domain/document/selection.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/models/geometry/rectangle.dart';
import 'package:wiretuner/domain/models/path.dart';
import 'package:wiretuner/domain/models/shape.dart';
import 'package:wiretuner/infrastructure/event_sourcing/snapshot_serializer.dart';

/// Tests for multi-artboard snapshot serialization and migration.
///
/// This test suite validates:
/// - Multi-artboard document serialization round-trips
/// - Legacy v1 snapshot migration to v2 (artboards)
/// - Per-artboard state isolation (layers, selection, viewport)
/// - Artboard bounds and metadata preservation
/// - Schema version handling
///
/// Related: I4.T1, ADR-0005
void main() {
  group('Multi-Artboard Snapshot Serialization', () {
    late SnapshotSerializer serializer;

    setUp(() {
      serializer = SnapshotSerializer(enableCompression: true);
    });

    test('Round-trip preserves empty artboard', () {
      // Arrange: Create document with single empty artboard
      final artboard = Artboard(
        id: 'artboard-1',
        name: 'Empty Artboard',
        bounds: const Rectangle(x: 0, y: 0, width: 800, height: 600),
        backgroundColor: '#FFFFFF',
      );

      final doc = Document(
        id: 'doc-1',
        title: 'Single Artboard Doc',
        schemaVersion: kDocumentSchemaVersion,
        artboards: [artboard],
      );

      // Act
      final bytes = serializer.serialize(doc);
      final deserialized = serializer.deserialize(bytes);

      // Assert
      expect(deserialized.id, equals('doc-1'));
      expect(deserialized.artboards.length, equals(1));
      expect(deserialized.artboards[0].id, equals('artboard-1'));
      expect(deserialized.artboards[0].name, equals('Empty Artboard'));
      expect(deserialized.artboards[0].bounds.width, equals(800));
      expect(deserialized.artboards[0].bounds.height, equals(600));
      expect(deserialized.artboards[0].backgroundColor, equals('#FFFFFF'));
      expect(deserialized, equals(doc));
    });

    test('Round-trip preserves multiple artboards with ordering', () {
      // Arrange: Create document with 3 artboards
      final artboards = [
        Artboard(
          id: 'mobile',
          name: 'iPhone 14',
          bounds: const Rectangle(x: 0, y: 0, width: 390, height: 844),
          backgroundColor: '#FFFFFF',
          preset: 'iPhone14',
        ),
        Artboard(
          id: 'tablet',
          name: 'iPad Pro',
          bounds: const Rectangle(x: 500, y: 0, width: 1024, height: 1366),
          backgroundColor: '#F5F5F5',
          preset: 'iPadPro11',
        ),
        Artboard(
          id: 'desktop',
          name: 'Desktop 1920x1080',
          bounds: const Rectangle(x: 1600, y: 0, width: 1920, height: 1080),
          backgroundColor: '#E0E0E0',
        ),
      ];

      final doc = Document(
        id: 'doc-2',
        title: 'Responsive Design',
        artboards: artboards,
      );

      // Act
      final bytes = serializer.serialize(doc);
      final deserialized = serializer.deserialize(bytes);

      // Assert: Document metadata preserved
      expect(deserialized.id, equals('doc-2'));
      expect(deserialized.title, equals('Responsive Design'));
      expect(deserialized.artboards.length, equals(3));

      // Assert: Artboard ordering preserved
      expect(deserialized.artboards[0].id, equals('mobile'));
      expect(deserialized.artboards[1].id, equals('tablet'));
      expect(deserialized.artboards[2].id, equals('desktop'));

      // Assert: Artboard metadata preserved
      expect(deserialized.artboards[0].name, equals('iPhone 14'));
      expect(deserialized.artboards[0].preset, equals('iPhone14'));
      expect(deserialized.artboards[0].bounds.width, equals(390));

      expect(deserialized.artboards[1].name, equals('iPad Pro'));
      expect(deserialized.artboards[1].preset, equals('iPadPro11'));
      expect(deserialized.artboards[1].backgroundColor, equals('#F5F5F5'));

      expect(deserialized.artboards[2].bounds.x, equals(1600));
      expect(deserialized.artboards[2].bounds.width, equals(1920));

      // Assert: Deep equality
      expect(deserialized, equals(doc));
    });

    test('Round-trip preserves per-artboard layers', () {
      // Arrange: Create artboards with different layer stacks
      final path1 = Path.line(
        start: const Point(x: 0, y: 0),
        end: const Point(x: 100, y: 100),
      );

      final shape1 = Shape.rectangle(
        center: const Point(x: 50, y: 50),
        width: 100,
        height: 60,
      );

      final artboard1 = Artboard(
        id: 'artboard-1',
        name: 'Artboard with Layers',
        bounds: const Rectangle(x: 0, y: 0, width: 800, height: 600),
        layers: [
          Layer(
            id: 'layer-1',
            name: 'Background',
            objects: [
              VectorObject.path(id: 'path-1', path: path1),
            ],
          ),
          Layer(
            id: 'layer-2',
            name: 'Foreground',
            visible: false,
            objects: [
              VectorObject.shape(id: 'shape-1', shape: shape1),
            ],
          ),
        ],
      );

      final artboard2 = Artboard(
        id: 'artboard-2',
        name: 'Empty Artboard',
        bounds: const Rectangle(x: 900, y: 0, width: 800, height: 600),
      );

      final doc = Document(
        id: 'doc-3',
        artboards: [artboard1, artboard2],
      );

      // Act
      final bytes = serializer.serialize(doc);
      final deserialized = serializer.deserialize(bytes);

      // Assert: Artboard 1 layers preserved
      expect(deserialized.artboards[0].layers.length, equals(2));
      expect(deserialized.artboards[0].layers[0].id, equals('layer-1'));
      expect(deserialized.artboards[0].layers[0].name, equals('Background'));
      expect(deserialized.artboards[0].layers[0].objects.length, equals(1));
      expect(deserialized.artboards[0].layers[1].id, equals('layer-2'));
      expect(deserialized.artboards[0].layers[1].visible, isFalse);

      // Assert: Artboard 2 has no layers
      expect(deserialized.artboards[1].layers, isEmpty);

      expect(deserialized, equals(doc));
    });

    test('Round-trip preserves per-artboard selection state', () {
      // Arrange: Create artboards with different selections
      final path1 = Path.line(
        start: const Point(x: 0, y: 0),
        end: const Point(x: 100, y: 100),
      );

      final layer = Layer(
        id: 'layer-1',
        objects: [
          VectorObject.path(id: 'path-1', path: path1),
          VectorObject.path(id: 'path-2', path: path1),
          VectorObject.path(id: 'path-3', path: path1),
        ],
      );

      final artboard1 = Artboard(
        id: 'artboard-1',
        bounds: const Rectangle(x: 0, y: 0, width: 800, height: 600),
        layers: [layer],
        selection: const Selection(
          objectIds: {'path-1', 'path-2'},
          anchorIndices: {'path-1': {0, 1}},
        ),
      );

      final artboard2 = Artboard(
        id: 'artboard-2',
        bounds: const Rectangle(x: 900, y: 0, width: 800, height: 600),
        layers: [layer],
        selection: const Selection(
          objectIds: {'path-3'},
        ),
      );

      final doc = Document(
        id: 'doc-4',
        artboards: [artboard1, artboard2],
      );

      // Act
      final bytes = serializer.serialize(doc);
      final deserialized = serializer.deserialize(bytes);

      // Assert: Artboard 1 selection preserved
      expect(deserialized.artboards[0].selection.objectIds,
          equals({'path-1', 'path-2'}));
      expect(deserialized.artboards[0].selection.anchorIndices['path-1'],
          equals({0, 1}));

      // Assert: Artboard 2 selection preserved (different)
      expect(deserialized.artboards[1].selection.objectIds, equals({'path-3'}));
      expect(
          deserialized.artboards[1].selection.anchorIndices, equals(<String, Set<int>>{}));

      // Assert: Selection state is isolated
      expect(deserialized.artboards[0].selection.contains('path-1'), isTrue);
      expect(deserialized.artboards[1].selection.contains('path-1'), isFalse);

      expect(deserialized, equals(doc));
    });

    test('Round-trip preserves per-artboard viewport state', () {
      // Arrange: Create artboards with different viewports
      final artboard1 = Artboard(
        id: 'artboard-1',
        bounds: const Rectangle(x: 0, y: 0, width: 800, height: 600),
        viewport: const Viewport(
          pan: Point(x: 100, y: 200),
          zoom: 1.5,
          canvasSize: Size(width: 1920, height: 1080),
        ),
      );

      final artboard2 = Artboard(
        id: 'artboard-2',
        bounds: const Rectangle(x: 900, y: 0, width: 800, height: 600),
        viewport: const Viewport(
          pan: Point(x: -50, y: -100),
          zoom: 0.75,
          canvasSize: Size(width: 1024, height: 768),
        ),
      );

      final doc = Document(
        id: 'doc-5',
        artboards: [artboard1, artboard2],
      );

      // Act
      final bytes = serializer.serialize(doc);
      final deserialized = serializer.deserialize(bytes);

      // Assert: Artboard 1 viewport preserved
      expect(deserialized.artboards[0].viewport.pan, equals(const Point(x: 100, y: 200)));
      expect(deserialized.artboards[0].viewport.zoom, equals(1.5));
      expect(deserialized.artboards[0].viewport.canvasSize.width, equals(1920));

      // Assert: Artboard 2 viewport preserved (different)
      expect(deserialized.artboards[1].viewport.pan, equals(const Point(x: -50, y: -100)));
      expect(deserialized.artboards[1].viewport.zoom, equals(0.75));
      expect(deserialized.artboards[1].viewport.canvasSize.width, equals(1024));

      expect(deserialized, equals(doc));
    });

    test('Schema version preserved in multi-artboard documents', () {
      // Arrange
      final doc = Document(
        id: 'doc-6',
        schemaVersion: kDocumentSchemaVersion,
        artboards: [
          Artboard(
            id: 'artboard-1',
            bounds: const Rectangle(x: 0, y: 0, width: 800, height: 600),
          ),
        ],
      );

      // Act
      final bytes = serializer.serialize(doc);
      final deserialized = serializer.deserialize(bytes);

      // Assert
      expect(deserialized.schemaVersion, equals(kDocumentSchemaVersion));
      expect(deserialized.schemaVersion, equals(2)); // v2.0.0
      expect(deserialized, equals(doc));
    });

    test('Artboard bounds are preserved with precision', () {
      // Arrange: Test floating-point precision
      final artboard = Artboard(
        id: 'artboard-1',
        bounds: const Rectangle(x: 123.456, y: 789.012, width: 390.5, height: 844.25),
      );

      final doc = Document(
        id: 'doc-7',
        artboards: [artboard],
      );

      // Act
      final bytes = serializer.serialize(doc);
      final deserialized = serializer.deserialize(bytes);

      // Assert: Floating-point precision preserved
      expect(deserialized.artboards[0].bounds.x, equals(123.456));
      expect(deserialized.artboards[0].bounds.y, equals(789.012));
      expect(deserialized.artboards[0].bounds.width, equals(390.5));
      expect(deserialized.artboards[0].bounds.height, equals(844.25));

      expect(deserialized, equals(doc));
    });

    test('Empty artboard list is preserved', () {
      // Arrange: Document with no artboards
      const doc = Document(
        id: 'doc-8',
        title: 'Empty Document',
        artboards: [],
      );

      // Act
      final bytes = serializer.serialize(doc);
      final deserialized = serializer.deserialize(bytes);

      // Assert
      expect(deserialized.artboards, isEmpty);
      expect(deserialized.isEmpty, isTrue);
      expect(deserialized, equals(doc));
    });

    test('Artboard query helpers work after deserialization', () {
      // Arrange
      final path = Path.line(
        start: const Point(x: 0, y: 0),
        end: const Point(x: 100, y: 100),
      );

      final artboard1 = Artboard(
        id: 'artboard-1',
        bounds: const Rectangle(x: 0, y: 0, width: 800, height: 600),
        layers: [
          Layer(
            id: 'layer-1',
            objects: [
              VectorObject.path(id: 'path-1', path: path),
            ],
          ),
        ],
      );

      final artboard2 = Artboard(
        id: 'artboard-2',
        bounds: const Rectangle(x: 900, y: 0, width: 800, height: 600),
        layers: [
          Layer(
            id: 'layer-2',
            objects: [
              VectorObject.path(id: 'path-2', path: path),
            ],
          ),
        ],
      );

      final doc = Document(
        id: 'doc-9',
        artboards: [artboard1, artboard2],
      );

      // Act
      final bytes = serializer.serialize(doc);
      final deserialized = serializer.deserialize(bytes);

      // Assert: Artboard queries work
      expect(deserialized.getArtboardById('artboard-1'), isNotNull);
      expect(deserialized.getArtboardById('artboard-2'), isNotNull);
      expect(deserialized.getArtboardById('nonexistent'), isNull);

      // Assert: Object queries work across artboards
      expect(deserialized.getObjectById('path-1'), isNotNull);
      expect(deserialized.getObjectById('path-2'), isNotNull);
      expect(deserialized.getAllObjects().length, equals(2));

      // Assert: Artboard containment queries work
      expect(deserialized.getArtboardContainingObject('path-1')?.id,
          equals('artboard-1'));
      expect(deserialized.getArtboardContainingObject('path-2')?.id,
          equals('artboard-2'));

      expect(deserialized, equals(doc));
    });

    test('Serialization is deterministic for multi-artboard documents', () {
      // Arrange
      final path = Path.line(
        start: const Point(x: 0, y: 0),
        end: const Point(x: 100, y: 100),
      );

      final doc = Document(
        id: 'doc-10',
        artboards: [
          Artboard(
            id: 'artboard-1',
            bounds: const Rectangle(x: 0, y: 0, width: 800, height: 600),
            layers: [
              Layer(
                id: 'layer-1',
                objects: [VectorObject.path(id: 'path-1', path: path)],
              ),
            ],
          ),
          Artboard(
            id: 'artboard-2',
            bounds: const Rectangle(x: 900, y: 0, width: 800, height: 600),
          ),
        ],
      );

      // Act: Serialize multiple times
      final bytes1 = serializer.serialize(doc);
      final bytes2 = serializer.serialize(doc);
      final bytes3 = serializer.serialize(doc);

      // Assert: All serializations produce identical bytes
      expect(bytes1, equals(bytes2));
      expect(bytes2, equals(bytes3));

      // Assert: Deserialization produces identical documents
      final doc1 = serializer.deserialize(bytes1);
      final doc2 = serializer.deserialize(bytes2);
      final doc3 = serializer.deserialize(bytes3);

      expect(doc1, equals(doc2));
      expect(doc2, equals(doc3));
      expect(doc1, equals(doc));
    });
  });

  group('Legacy Snapshot Migration (v1 → v2)', () {
    late SnapshotSerializer serializer;

    setUp(() {
      serializer = SnapshotSerializer(enableCompression: false);
    });

    test('Migrates legacy v1 snapshot with layers at document root', () {
      // Arrange: Create legacy v1 JSON structure
      final legacyJson = {
        'id': 'legacy-doc-1',
        'title': 'Legacy Document',
        'schemaVersion': 1,
        'layers': [
          {
            'id': 'layer-1',
            'name': 'Background',
            'visible': true,
            'locked': false,
            'objects': [],
          }
        ],
        'selection': {
          'objectIds': [],
          'anchorIndices': {},
        },
        'viewport': {
          'pan': {'x': 0, 'y': 0},
          'zoom': 1.0,
          'canvasSize': {'width': 800, 'height': 600},
        },
      };

      // Serialize legacy JSON to bytes
      final legacyBytes = serializer.serializeToJson(legacyJson);

      // Act: Deserialize should auto-migrate
      final deserialized = serializer.deserialize(legacyBytes);

      // Assert: Migrated to v2 with default artboard
      expect(deserialized.schemaVersion, equals(2));
      expect(deserialized.artboards.length, equals(1));
      expect(deserialized.artboards[0].id,
          equals('default-artboard-legacy-doc-1'));
      expect(deserialized.artboards[0].name, equals('Artboard 1'));

      // Assert: Layers moved to artboard
      expect(deserialized.artboards[0].layers.length, equals(1));
      expect(deserialized.artboards[0].layers[0].id, equals('layer-1'));
      expect(deserialized.artboards[0].layers[0].name, equals('Background'));

      // Assert: Selection moved to artboard
      expect(deserialized.artboards[0].selection.objectIds, isEmpty);

      // Assert: Viewport moved to artboard
      expect(deserialized.artboards[0].viewport.zoom, equals(1.0));
    });

    test('Migrates legacy v1 snapshot with selection state', () {
      // Arrange: Legacy v1 with selection
      final legacyJson = {
        'id': 'legacy-doc-2',
        'schemaVersion': 1,
        'layers': [
          {
            'id': 'layer-1',
            'objects': [],
          }
        ],
        'selection': {
          'objectIds': ['path-1', 'path-2'],
          'anchorIndices': {
            'path-1': [0, 1]
          },
        },
        'viewport': {
          'pan': {'x': 100, 'y': 200},
          'zoom': 1.5,
          'canvasSize': {'width': 1920, 'height': 1080},
        },
      };

      final legacyBytes = serializer.serializeToJson(legacyJson);

      // Act
      final deserialized = serializer.deserialize(legacyBytes);

      // Assert: Selection preserved in default artboard
      expect(deserialized.artboards[0].selection.objectIds,
          containsAll(['path-1', 'path-2']));
      expect(deserialized.artboards[0].selection.anchorIndices.containsKey('path-1'),
          isTrue);

      // Assert: Viewport preserved in default artboard
      expect(deserialized.artboards[0].viewport.pan.x, equals(100));
      expect(deserialized.artboards[0].viewport.pan.y, equals(200));
      expect(deserialized.artboards[0].viewport.zoom, equals(1.5));
    });

    test('Handles empty legacy document migration', () {
      // Arrange: Empty legacy v1 document
      final legacyJson = {
        'id': 'empty-legacy',
        'title': 'Empty',
        'schemaVersion': 1,
        'layers': [],
        'selection': {
          'objectIds': [],
          'anchorIndices': {},
        },
        'viewport': {
          'pan': {'x': 0, 'y': 0},
          'zoom': 1.0,
          'canvasSize': {'width': 800, 'height': 600},
        },
      };

      final legacyBytes = serializer.serializeToJson(legacyJson);

      // Act
      final deserialized = serializer.deserialize(legacyBytes);

      // Assert: Default artboard created even for empty document
      expect(deserialized.artboards.length, equals(1));
      expect(deserialized.artboards[0].layers, isEmpty);
      expect(deserialized.artboards[0].selection.isEmpty, isTrue);
    });

    test('Does not migrate v2 snapshots', () {
      // Arrange: Valid v2 snapshot
      final v2Doc = Document(
        id: 'v2-doc',
        schemaVersion: 2,
        artboards: [
          Artboard(
            id: 'artboard-1',
            bounds: const Rectangle(x: 0, y: 0, width: 800, height: 600),
          ),
        ],
      );

      // Act: Serialize and deserialize v2 document
      final bytes = serializer.serialize(v2Doc);
      final deserialized = serializer.deserialize(bytes);

      // Assert: No migration occurred
      expect(deserialized.schemaVersion, equals(2));
      expect(deserialized.artboards.length, equals(1));
      expect(deserialized.artboards[0].id, equals('artboard-1'));

      // Assert: No default artboard added
      expect(deserialized.artboards[0].id,
          isNot(equals('default-artboard-v2-doc')));

      expect(deserialized, equals(v2Doc));
    });
  });
}
