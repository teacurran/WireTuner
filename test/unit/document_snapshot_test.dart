import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/domain/document/selection.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/models/anchor_point.dart' as ap;
import 'package:wiretuner/domain/models/path.dart';
import 'package:wiretuner/domain/models/segment.dart';
import 'package:wiretuner/domain/models/shape.dart';
import 'package:wiretuner/infrastructure/event_sourcing/snapshot_serializer.dart';

void main() {
  group('Document Snapshot Serialization', () {
    late SnapshotSerializer serializer;

    setUp(() {
      serializer = SnapshotSerializer(enableCompression: true);
    });

    test('Round-trip serialization preserves empty document', () {
      // Arrange
      const original = Document(
        id: 'doc-1',
        title: 'Empty Document',
      );

      // Act
      final bytes = serializer.serialize(original);
      final deserialized = serializer.deserialize(bytes);

      // Assert
      expect(deserialized, equals(original));
      expect(deserialized.id, equals('doc-1'));
      expect(deserialized.title, equals('Empty Document'));
      expect(deserialized.layers, isEmpty);
      expect(deserialized.selection.isEmpty, isTrue);
    });

    test('Round-trip preserves document with layers and objects', () {
      // Arrange: Create a document with multiple layers and objects
      final path1 = Path.line(
        start: const Point(x: 0, y: 0),
        end: const Point(x: 100, y: 100),
      );

      final shape1 = Shape.rectangle(
        center: const Point(x: 50, y: 50),
        width: 100,
        height: 60,
      );

      final layer1 = Layer(
        id: 'layer-1',
        name: 'Background',
        visible: true,
        locked: false,
        objects: [
          VectorObject.path(id: 'path-1', path: path1),
          VectorObject.shape(id: 'shape-1', shape: shape1),
        ],
      );

      const layer2 = Layer(
        id: 'layer-2',
        name: 'Foreground',
        visible: false,
        locked: true,
        objects: [],
      );

      final original = Document(
        id: 'doc-2',
        title: 'Complex Document',
        layers: [layer1, layer2],
      );

      // Act
      final bytes = serializer.serialize(original);
      final deserialized = serializer.deserialize(bytes);

      // Assert: Document properties preserved
      expect(deserialized.id, equals(original.id));
      expect(deserialized.title, equals(original.title));
      expect(deserialized.schemaVersion, equals(original.schemaVersion));

      // Assert: Layer count and ordering preserved
      expect(deserialized.layers.length, equals(2));
      expect(deserialized.layers[0].id, equals('layer-1'));
      expect(deserialized.layers[1].id, equals('layer-2'));

      // Assert: Layer properties preserved
      expect(deserialized.layers[0].name, equals('Background'));
      expect(deserialized.layers[0].visible, isTrue);
      expect(deserialized.layers[0].locked, isFalse);
      expect(deserialized.layers[1].visible, isFalse);
      expect(deserialized.layers[1].locked, isTrue);

      // Assert: Object count and IDs preserved
      expect(deserialized.layers[0].objects.length, equals(2));
      expect(deserialized.layers[0].objects[0].id, equals('path-1'));
      expect(deserialized.layers[0].objects[1].id, equals('shape-1'));

      // Assert: Deep equality
      expect(deserialized, equals(original));
    });

    test('Round-trip preserves selection state', () {
      // Arrange: Document with selection
      final path1 = Path.line(
        start: const Point(x: 0, y: 0),
        end: const Point(x: 100, y: 100),
      );

      final layer1 = Layer(
        id: 'layer-1',
        objects: [
          VectorObject.path(id: 'path-1', path: path1),
          VectorObject.path(id: 'path-2', path: path1),
        ],
      );

      const selection = Selection(
        objectIds: {'path-1', 'path-2'},
        anchorIndices: {
          'path-1': {0, 1},
        },
      );

      final original = Document(
        id: 'doc-3',
        layers: [layer1],
        selection: selection,
      );

      // Act
      final bytes = serializer.serialize(original);
      final deserialized = serializer.deserialize(bytes);

      // Assert: Selection state preserved
      expect(deserialized.selection.objectIds, equals(selection.objectIds));
      expect(
        deserialized.selection.anchorIndices,
        equals(selection.anchorIndices),
      );
      expect(deserialized.selection.contains('path-1'), isTrue);
      expect(deserialized.selection.contains('path-2'), isTrue);
      expect(
        deserialized.selection.getSelectedAnchors('path-1'),
        equals({0, 1}),
      );
      expect(deserialized, equals(original));
    });

    test('Round-trip preserves viewport state', () {
      // Arrange: Document with custom viewport
      const viewport = Viewport(
        pan: Point(x: 100, y: 200),
        zoom: 1.5,
        canvasSize: Size(width: 1920, height: 1080),
      );

      const original = Document(
        id: 'doc-4',
        viewport: viewport,
      );

      // Act
      final bytes = serializer.serialize(original);
      final deserialized = serializer.deserialize(bytes);

      // Assert: Viewport preserved
      expect(deserialized.viewport.pan, equals(viewport.pan));
      expect(deserialized.viewport.zoom, equals(viewport.zoom));
      expect(deserialized.viewport.canvasSize, equals(viewport.canvasSize));
      expect(deserialized, equals(original));
    });

    test('Round-trip preserves complex path geometry', () {
      // Arrange: Path with bezier curves
      final anchors = [
        const ap.AnchorPoint(
          position: Point(x: 0, y: 0),
          handleOut: Point(x: 50, y: 0),
          anchorType: ap.AnchorType.smooth,
        ),
        const ap.AnchorPoint(
          position: Point(x: 100, y: 100),
          handleIn: Point(x: -50, y: 0),
          handleOut: Point(x: 50, y: 0),
          anchorType: ap.AnchorType.symmetric,
        ),
        const ap.AnchorPoint(
          position: Point(x: 200, y: 0),
          handleIn: Point(x: -50, y: 0),
          anchorType: ap.AnchorType.corner,
        ),
      ];

      final segments = [
        Segment.bezier(startIndex: 0, endIndex: 1),
        Segment.bezier(startIndex: 1, endIndex: 2),
      ];

      final path = Path(
        anchors: anchors,
        segments: segments,
        closed: true,
      );

      final layer = Layer(
        id: 'layer-1',
        objects: [VectorObject.path(id: 'path-1', path: path)],
      );

      final original = Document(
        id: 'doc-5',
        layers: [layer],
      );

      // Act
      final bytes = serializer.serialize(original);
      final deserialized = serializer.deserialize(bytes);

      // Assert: Path geometry preserved
      final deserializedPath =
          (deserialized.layers[0].objects[0] as PathObject).path;
      expect(deserializedPath.anchors.length, equals(3));
      expect(deserializedPath.segments.length, equals(2));
      expect(deserializedPath.closed, isTrue);

      // Assert: Anchor properties preserved
      expect(deserializedPath.anchors[0].position,
          equals(const Point(x: 0, y: 0)));
      expect(deserializedPath.anchors[0].handleOut,
          equals(const Point(x: 50, y: 0)));
      expect(
          deserializedPath.anchors[0].anchorType, equals(ap.AnchorType.smooth));

      expect(deserializedPath.anchors[1].handleIn,
          equals(const Point(x: -50, y: 0)));
      expect(deserializedPath.anchors[1].handleOut,
          equals(const Point(x: 50, y: 0)));
      expect(deserializedPath.anchors[1].anchorType,
          equals(ap.AnchorType.symmetric));

      // Assert: Segment properties preserved
      expect(
          deserializedPath.segments[0].segmentType, equals(SegmentType.bezier));
      expect(deserializedPath.segments[0].startAnchorIndex, equals(0));
      expect(deserializedPath.segments[0].endAnchorIndex, equals(1));

      expect(deserialized, equals(original));
    });

    test('Round-trip preserves parametric shapes', () {
      // Arrange: Document with various shape types
      final shapes = [
        Shape.rectangle(
          center: const Point(x: 50, y: 50),
          width: 100,
          height: 60,
          cornerRadius: 10,
        ),
        Shape.ellipse(
          center: const Point(x: 150, y: 150),
          width: 80,
          height: 120,
        ),
        Shape.polygon(
          center: const Point(x: 250, y: 250),
          radius: 50,
          sides: 6,
        ),
        Shape.star(
          center: const Point(x: 350, y: 350),
          outerRadius: 60,
          innerRadius: 30,
          pointCount: 5,
        ),
      ];

      final layer = Layer(
        id: 'layer-1',
        objects: shapes
            .asMap()
            .entries
            .map(
              (e) => VectorObject.shape(
                id: 'shape-${e.key}',
                shape: e.value,
              ),
            )
            .toList(),
      );

      final original = Document(
        id: 'doc-6',
        layers: [layer],
      );

      // Act
      final bytes = serializer.serialize(original);
      final deserialized = serializer.deserialize(bytes);

      // Assert: All shapes preserved
      expect(deserialized.layers[0].objects.length, equals(4));

      final deserializedShapes = deserialized.layers[0].objects
          .map((obj) => (obj as ShapeObject).shape)
          .toList();

      // Assert: Rectangle
      expect(deserializedShapes[0].kind, equals(ShapeKind.rectangle));
      expect(deserializedShapes[0].width, equals(100));
      expect(deserializedShapes[0].height, equals(60));
      expect(deserializedShapes[0].cornerRadius, equals(10));

      // Assert: Ellipse
      expect(deserializedShapes[1].kind, equals(ShapeKind.ellipse));
      expect(deserializedShapes[1].width, equals(80));
      expect(deserializedShapes[1].height, equals(120));

      // Assert: Polygon
      expect(deserializedShapes[2].kind, equals(ShapeKind.polygon));
      expect(deserializedShapes[2].radius, equals(50));
      expect(deserializedShapes[2].sides, equals(6));

      // Assert: Star
      expect(deserializedShapes[3].kind, equals(ShapeKind.star));
      expect(deserializedShapes[3].radius, equals(60));
      expect(deserializedShapes[3].innerRadius, equals(30));
      expect(deserializedShapes[3].sides, equals(5));

      expect(deserialized, equals(original));
    });

    test('Serialization handles version field', () {
      // Arrange
      const original = Document(
        id: 'doc-7',
        title: 'Versioned Document',
        schemaVersion: kDocumentSchemaVersion,
      );

      // Act
      final bytes = serializer.serialize(original);
      final deserialized = serializer.deserialize(bytes);

      // Assert: Version preserved
      expect(deserialized.schemaVersion, equals(kDocumentSchemaVersion));
      expect(deserialized.schemaVersion, equals(1)); // Current version
      expect(deserialized, equals(original));
    });

    test('Serialization is deterministic', () {
      // Arrange: Create document with multiple objects
      final path = Path.line(
        start: const Point(x: 0, y: 0),
        end: const Point(x: 100, y: 100),
      );

      final layer = Layer(
        id: 'layer-1',
        objects: [
          VectorObject.path(id: 'path-1', path: path),
          VectorObject.path(id: 'path-2', path: path),
          VectorObject.path(id: 'path-3', path: path),
        ],
      );

      final document = Document(
        id: 'doc-8',
        layers: [layer],
        selection: const Selection(objectIds: {'path-1', 'path-2'}),
      );

      // Act: Serialize multiple times
      final bytes1 = serializer.serialize(document);
      final bytes2 = serializer.serialize(document);
      final bytes3 = serializer.serialize(document);

      // Assert: All serializations produce identical bytes
      expect(bytes1, equals(bytes2));
      expect(bytes2, equals(bytes3));

      // Assert: Deserialization produces identical documents
      final doc1 = serializer.deserialize(bytes1);
      final doc2 = serializer.deserialize(bytes2);
      final doc3 = serializer.deserialize(bytes3);

      expect(doc1, equals(doc2));
      expect(doc2, equals(doc3));
      expect(doc1, equals(document));
    });

    test('Serialization with compression reduces size', () {
      // Arrange: Create a large document
      final paths = List.generate(
        100,
        (i) => VectorObject.path(
          id: 'path-$i',
          path: Path.line(
            start: Point(x: i.toDouble(), y: 0),
            end: Point(x: i.toDouble() + 100, y: 100),
          ),
        ),
      );

      final layer = Layer(id: 'layer-1', objects: paths);
      final document = Document(id: 'doc-9', layers: [layer]);

      // Act
      final serializerWithCompression =
          SnapshotSerializer(enableCompression: true);
      final serializerWithoutCompression =
          SnapshotSerializer(enableCompression: false);

      final compressedBytes = serializerWithCompression.serialize(document);
      final uncompressedBytes =
          serializerWithoutCompression.serialize(document);

      // Assert: Compression reduces size significantly
      expect(compressedBytes.length, lessThan(uncompressedBytes.length));

      // Assert: Both deserialize to the same document
      final fromCompressed =
          serializerWithCompression.deserialize(compressedBytes);
      final fromUncompressed =
          serializerWithoutCompression.deserialize(uncompressedBytes);

      expect(fromCompressed, equals(fromUncompressed));
      expect(fromCompressed, equals(document));
    });

    test('Query helpers work after deserialization', () {
      // Arrange: Document with multiple objects
      final path1 = Path.line(
        start: const Point(x: 0, y: 0),
        end: const Point(x: 100, y: 100),
      );

      final layer1 = Layer(
        id: 'layer-1',
        objects: [
          VectorObject.path(id: 'path-1', path: path1),
          VectorObject.path(id: 'path-2', path: path1),
        ],
      );

      final layer2 = Layer(
        id: 'layer-2',
        objects: [
          VectorObject.path(id: 'path-3', path: path1),
        ],
      );

      final original = Document(
        id: 'doc-10',
        layers: [layer1, layer2],
        selection: const Selection(objectIds: {'path-1', 'path-3'}),
      );

      // Act
      final bytes = serializer.serialize(original);
      final deserialized = serializer.deserialize(bytes);

      // Assert: Query helpers work
      expect(deserialized.getAllObjects().length, equals(3));
      expect(deserialized.getObjectById('path-1'), isNotNull);
      expect(deserialized.getObjectById('path-2'), isNotNull);
      expect(deserialized.getObjectById('path-3'), isNotNull);
      expect(deserialized.getObjectById('nonexistent'), isNull);

      expect(deserialized.getSelectedObjects().length, equals(2));
      expect(deserialized.getSelectedObjects().map((o) => o.id),
          containsAll(['path-1', 'path-3']));

      expect(deserialized.getLayerContainingObject('path-1')?.id,
          equals('layer-1'));
      expect(deserialized.getLayerContainingObject('path-3')?.id,
          equals('layer-2'));
      expect(deserialized.getLayerContainingObject('nonexistent'), isNull);
    });
  });
}
