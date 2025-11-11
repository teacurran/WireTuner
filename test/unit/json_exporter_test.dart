import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/domain/document/selection.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/models/geometry/rectangle.dart';
import 'package:wiretuner/domain/models/path.dart';
import 'package:wiretuner/infrastructure/export/json_exporter.dart';

void main() {
  group('JsonExporter - generateJson', () {
    late JsonExporter exporter;

    setUp(() {
      exporter = JsonExporter();
    });

    test('Exports document with required metadata fields', () {
      final document = Document(
        id: 'doc-1',
        title: 'Test Document',
        artboards: [
          Artboard(
            id: 'artboard-1',
            name: 'Main',
            bounds: const Rectangle(x: 0, y: 0, width: 800, height: 600),
            layers: const [],
          ),
        ],
      );

      final jsonContent = exporter.generateJson(document);
      final data = jsonDecode(jsonContent) as Map<String, dynamic>;

      expect(data, containsPair('fileFormatVersion', '2.0.0'));
      expect(data, contains('exportedAt'));
      expect(data, contains('exportedBy'));
      expect(data, contains('document'));
      expect(data['exportedBy'], startsWith('WireTuner'));
    });

    test('Exports document with ISO 8601 timestamp', () {
      final document = Document(
        id: 'doc-2',
        title: 'Timestamp Test',
        artboards: const [],
      );

      final jsonContent = exporter.generateJson(document);
      final data = jsonDecode(jsonContent) as Map<String, dynamic>;

      final timestamp = data['exportedAt'] as String;
      expect(timestamp, matches(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}'));
      expect(DateTime.parse(timestamp).isUtc, isTrue);
    });

    test('Exports document payload with schema version', () {
      final document = Document(
        id: 'doc-3',
        title: 'Schema Test',
        schemaVersion: 2,
        artboards: const [],
      );

      final jsonContent = exporter.generateJson(document);
      final data = jsonDecode(jsonContent) as Map<String, dynamic>;

      final documentData = data['document'] as Map<String, dynamic>;
      expect(documentData['id'], 'doc-3');
      expect(documentData['title'], 'Schema Test');
      expect(documentData['schemaVersion'], 2);
    });

    test('Exports multi-artboard document', () {
      final document = Document(
        id: 'doc-4',
        title: 'Multi-Artboard',
        artboards: [
          Artboard(
            id: 'artboard-mobile',
            name: 'Mobile',
            bounds: const Rectangle(x: 0, y: 0, width: 390, height: 844),
            layers: const [],
          ),
          Artboard(
            id: 'artboard-desktop',
            name: 'Desktop',
            bounds: const Rectangle(x: 1000, y: 0, width: 1920, height: 1080),
            layers: const [],
          ),
        ],
      );

      final jsonContent = exporter.generateJson(document);
      final data = jsonDecode(jsonContent) as Map<String, dynamic>;
      final documentData = data['document'] as Map<String, dynamic>;
      final artboards = documentData['artboards'] as List;

      expect(artboards.length, 2);
      expect(artboards[0]['id'], 'artboard-mobile');
      expect(artboards[1]['id'], 'artboard-desktop');
    });

    test('Filters artboards when artboardIds specified', () {
      final document = Document(
        id: 'doc-5',
        title: 'Filter Test',
        artboards: [
          Artboard(
            id: 'artboard-1',
            name: 'First',
            bounds: const Rectangle(x: 0, y: 0, width: 800, height: 600),
          ),
          Artboard(
            id: 'artboard-2',
            name: 'Second',
            bounds: const Rectangle(x: 1000, y: 0, width: 800, height: 600),
          ),
          Artboard(
            id: 'artboard-3',
            name: 'Third',
            bounds: const Rectangle(x: 2000, y: 0, width: 800, height: 600),
          ),
        ],
      );

      final jsonContent = exporter.generateJson(
        document,
        artboardIds: ['artboard-1', 'artboard-3'],
      );
      final data = jsonDecode(jsonContent) as Map<String, dynamic>;
      final documentData = data['document'] as Map<String, dynamic>;
      final artboards = documentData['artboards'] as List;

      expect(artboards.length, 2);
      expect(artboards[0]['id'], 'artboard-1');
      expect(artboards[1]['id'], 'artboard-3');
    });

    test('Pretty prints JSON by default', () {
      final document = Document(
        id: 'doc-6',
        title: 'Pretty Print',
        artboards: const [],
      );

      final jsonContent = exporter.generateJson(document, prettyPrint: true);

      expect(jsonContent, contains('\n'));
      expect(jsonContent, contains('  '));
    });

    test('Minifies JSON when prettyPrint is false', () {
      final document = Document(
        id: 'doc-7',
        title: 'Minified',
        artboards: const [],
      );

      final jsonContent = exporter.generateJson(document, prettyPrint: false);

      // Minified JSON should have no newlines except at end
      expect(jsonContent.split('\n').length, lessThan(5));
    });

    test('Preserves artboard viewport state', () {
      final document = Document(
        id: 'doc-8',
        title: 'Viewport Test',
        artboards: [
          Artboard(
            id: 'artboard-1',
            name: 'Main',
            bounds: const Rectangle(x: 0, y: 0, width: 800, height: 600),
            viewport: const Viewport(
              pan: Point(x: 100, y: 200),
              zoom: 2.0,
              canvasSize: Size(width: 1920, height: 1080),
            ),
          ),
        ],
      );

      final jsonContent = exporter.generateJson(document);
      final data = jsonDecode(jsonContent) as Map<String, dynamic>;
      final documentData = data['document'] as Map<String, dynamic>;
      final artboards = documentData['artboards'] as List;
      final viewport = artboards[0]['viewport'] as Map<String, dynamic>;

      expect(viewport['zoom'], 2.0);
      expect(viewport['pan']['x'], 100);
      expect(viewport['pan']['y'], 200);
    });

    test('Preserves artboard selection state', () {
      final document = Document(
        id: 'doc-9',
        title: 'Selection Test',
        artboards: [
          Artboard(
            id: 'artboard-1',
            name: 'Main',
            bounds: const Rectangle(x: 0, y: 0, width: 800, height: 600),
            selection: const Selection(objectIds: {'path-1', 'path-2'}),
          ),
        ],
      );

      final jsonContent = exporter.generateJson(document);
      final data = jsonDecode(jsonContent) as Map<String, dynamic>;
      final documentData = data['document'] as Map<String, dynamic>;
      final artboards = documentData['artboards'] as List;
      final selection = artboards[0]['selection'] as Map<String, dynamic>;

      expect(selection['objectIds'], isA<List>());
      expect(selection['objectIds'], containsAll(['path-1', 'path-2']));
    });
  });

  group('JsonExporter - validateImport', () {
    test('Validates compatible JSON export', () {
      final jsonContent = jsonEncode({
        'fileFormatVersion': '2.0.0',
        'exportedAt': DateTime.now().toIso8601String(),
        'exportedBy': 'WireTuner v0.1.0',
        'document': {
          'id': 'doc-1',
          'title': 'Test',
          'schemaVersion': 2,
          'artboards': [],
        },
      });

      final result = JsonExporter.validateImport(jsonContent);

      expect(result.isCompatible, isTrue);
      expect(result.error, isNull);
    });

    test('Rejects JSON with missing fileFormatVersion', () {
      final jsonContent = jsonEncode({
        'exportedAt': DateTime.now().toIso8601String(),
        'document': {},
      });

      final result = JsonExporter.validateImport(jsonContent);

      expect(result.isCompatible, isFalse);
      expect(result.error, contains('Missing fileFormatVersion'));
    });

    test('Rejects JSON with invalid version format', () {
      final jsonContent = jsonEncode({
        'fileFormatVersion': 'invalid',
        'document': {},
      });

      final result = JsonExporter.validateImport(jsonContent);

      expect(result.isCompatible, isFalse);
      expect(result.error, contains('Invalid version format'));
    });

    test('Rejects JSON with future major version', () {
      final jsonContent = jsonEncode({
        'fileFormatVersion': '99.0.0',
        'exportedAt': DateTime.now().toIso8601String(),
        'document': {},
      });

      final result = JsonExporter.validateImport(jsonContent);

      expect(result.isCompatible, isFalse);
      expect(result.error, contains('too new'));
    });

    test('Warns about older major version', () {
      final jsonContent = jsonEncode({
        'fileFormatVersion': '1.0.0',
        'exportedAt': DateTime.now().toIso8601String(),
        'document': {},
      });

      final result = JsonExporter.validateImport(jsonContent);

      expect(result.isCompatible, isTrue);
      expect(result.warnings, isNotEmpty);
      expect(result.warnings.first, contains('older than current'));
    });

    test('Rejects JSON with missing document payload', () {
      final jsonContent = jsonEncode({
        'fileFormatVersion': '2.0.0',
        'exportedAt': DateTime.now().toIso8601String(),
      });

      final result = JsonExporter.validateImport(jsonContent);

      expect(result.isCompatible, isFalse);
      expect(result.error, contains('Missing document payload'));
    });

    test('Handles malformed JSON gracefully', () {
      const jsonContent = 'not valid json';

      final result = JsonExporter.validateImport(jsonContent);

      expect(result.isCompatible, isFalse);
      expect(result.error, contains('Failed to parse JSON'));
    });
  });

  group('JsonExporter - exportToFile', () {
    late JsonExporter exporter;
    late Directory tempDir;

    setUp(() {
      exporter = JsonExporter();
      tempDir = Directory.systemTemp.createTempSync('wiretuner_json_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('Exports document to file', () async {
      final document = Document(
        id: 'doc-file',
        title: 'File Export Test',
        artboards: [
          Artboard(
            id: 'artboard-1',
            name: 'Main',
            bounds: const Rectangle(x: 0, y: 0, width: 800, height: 600),
          ),
        ],
      );

      final filePath = '${tempDir.path}/test_export.json';
      await exporter.exportToFile(document, filePath);

      // Verify file exists
      final file = File(filePath);
      expect(file.existsSync(), isTrue);

      // Verify file content
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      expect(data['fileFormatVersion'], '2.0.0');
      expect(data['document']['id'], 'doc-file');
    });

    test('Overwrites existing file', () async {
      final filePath = '${tempDir.path}/overwrite_test.json';

      // Create initial file
      await File(filePath).writeAsString('old content');

      final document = Document(
        id: 'doc-new',
        title: 'New Document',
        artboards: const [],
      );

      await exporter.exportToFile(document, filePath);

      // Verify new content
      final content = await File(filePath).readAsString();
      expect(content, isNot(contains('old content')));
      expect(content, contains('doc-new'));
    });

    test('Throws exception for invalid file path', () async {
      final document = Document(
        id: 'doc-invalid',
        title: 'Invalid Path Test',
        artboards: const [],
      );

      final invalidPath = '/nonexistent_directory_xyz/test.json';

      await expectLater(
        exporter.exportToFile(document, invalidPath),
        throwsA(isA<PathNotFoundException>()),
      );
    });

    test('Exports file with UTF-8 encoding', () async {
      final document = Document(
        id: 'doc-utf8',
        title: 'UTF-8 Test: 日本語 中文 한글',
        artboards: const [],
      );

      final filePath = '${tempDir.path}/utf8_test.json';
      await exporter.exportToFile(document, filePath);

      final content = await File(filePath).readAsString();
      expect(content, contains('UTF-8 Test: 日本語 中文 한글'));
    });
  });

  group('JsonExporter - Round-trip tests', () {
    late JsonExporter exporter;
    late Directory tempDir;

    setUp(() {
      exporter = JsonExporter();
      tempDir = Directory.systemTemp.createTempSync('wiretuner_roundtrip_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('Round-trips empty document', () async {
      final original = Document(
        id: 'doc-roundtrip-1',
        title: 'Empty Document',
        artboards: const [],
      );

      final filePath = '${tempDir.path}/roundtrip_empty.json';
      await exporter.exportToFile(original, filePath);

      final result = await exporter.importFromFile(filePath);
      final imported = result.document;

      expect(imported.id, original.id);
      expect(imported.title, original.title);
      expect(imported.schemaVersion, original.schemaVersion);
      expect(imported.artboards.length, original.artboards.length);
    });

    test('Round-trips document with multiple artboards', () async {
      final original = Document(
        id: 'doc-roundtrip-2',
        title: 'Multi-Artboard Document',
        artboards: [
          Artboard(
            id: 'artboard-1',
            name: 'Mobile',
            bounds: const Rectangle(x: 0, y: 0, width: 390, height: 844),
            backgroundColor: '#FFFFFF',
            preset: 'iPhone14',
          ),
          Artboard(
            id: 'artboard-2',
            name: 'Desktop',
            bounds: const Rectangle(x: 1000, y: 0, width: 1920, height: 1080),
            backgroundColor: '#F5F5F5',
            preset: '1080p',
          ),
        ],
      );

      final filePath = '${tempDir.path}/roundtrip_multi.json';
      await exporter.exportToFile(original, filePath);

      final result = await exporter.importFromFile(filePath);
      final imported = result.document;

      expect(imported.artboards.length, 2);
      expect(imported.artboards[0].id, 'artboard-1');
      expect(imported.artboards[0].name, 'Mobile');
      expect(imported.artboards[0].preset, 'iPhone14');
      expect(imported.artboards[1].id, 'artboard-2');
      expect(imported.artboards[1].name, 'Desktop');
      expect(imported.artboards[1].preset, '1080p');
    });

    test('Round-trips artboard viewport state', () async {
      final original = Document(
        id: 'doc-roundtrip-3',
        title: 'Viewport Test',
        artboards: [
          Artboard(
            id: 'artboard-1',
            name: 'Main',
            bounds: const Rectangle(x: 0, y: 0, width: 800, height: 600),
            viewport: const Viewport(
              pan: Point(x: 150, y: 250),
              zoom: 1.5,
              canvasSize: Size(width: 1920, height: 1080),
            ),
          ),
        ],
      );

      final filePath = '${tempDir.path}/roundtrip_viewport.json';
      await exporter.exportToFile(original, filePath);

      final result = await exporter.importFromFile(filePath);
      final imported = result.document;

      final viewport = imported.artboards[0].viewport;
      expect(viewport.pan.x, 150);
      expect(viewport.pan.y, 250);
      expect(viewport.zoom, 1.5);
      expect(viewport.canvasSize.width, 1920);
      expect(viewport.canvasSize.height, 1080);
    });

    test('Round-trips artboard selection state', () async {
      final original = Document(
        id: 'doc-roundtrip-4',
        title: 'Selection Test',
        artboards: [
          Artboard(
            id: 'artboard-1',
            name: 'Main',
            bounds: const Rectangle(x: 0, y: 0, width: 800, height: 600),
            selection: const Selection(
              objectIds: {'path-1', 'path-2', 'shape-1'},
              anchorIndices: {
                'path-1': {0, 2},
              },
            ),
          ),
        ],
      );

      final filePath = '${tempDir.path}/roundtrip_selection.json';
      await exporter.exportToFile(original, filePath);

      final result = await exporter.importFromFile(filePath);
      final imported = result.document;

      final selection = imported.artboards[0].selection;
      expect(selection.objectIds, containsAll(['path-1', 'path-2', 'shape-1']));
      expect(selection.anchorIndices['path-1'], containsAll([0, 2]));
    });

    test('Round-trips document with layers and objects', () async {
      final original = Document(
        id: 'doc-roundtrip-5',
        title: 'Content Test',
        artboards: [
          Artboard(
            id: 'artboard-1',
            name: 'Main',
            bounds: const Rectangle(x: 0, y: 0, width: 800, height: 600),
            layers: [
              Layer(
                id: 'layer-1',
                name: 'Background',
                visible: true,
                locked: false,
                objects: [
                  VectorObject.path(
                    id: 'path-1',
                    path: Path.line(
                      start: const Point(x: 0, y: 0),
                      end: const Point(x: 100, y: 100),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      final filePath = '${tempDir.path}/roundtrip_content.json';
      await exporter.exportToFile(original, filePath);

      final result = await exporter.importFromFile(filePath);
      final imported = result.document;

      final artboard = imported.artboards[0];
      expect(artboard.layers.length, 1);
      expect(artboard.layers[0].name, 'Background');
      expect(artboard.layers[0].objects.length, 1);
      expect(artboard.layers[0].objects[0].id, 'path-1');
    });

    test('Preserves exact structure for identical export/import', () async {
      final original = Document(
        id: 'doc-exact',
        title: 'Exact Match',
        schemaVersion: 2,
        artboards: [
          Artboard(
            id: 'artboard-1',
            name: 'Main',
            bounds: const Rectangle(x: 10, y: 20, width: 800, height: 600),
            backgroundColor: '#FFFFFF',
            preset: 'Custom',
            layers: const [],
          ),
        ],
      );

      final filePath = '${tempDir.path}/exact_match.json';
      await exporter.exportToFile(original, filePath);

      final result = await exporter.importFromFile(filePath);
      final imported = result.document;

      // Compare JSON serializations
      final originalJson = jsonEncode(original.toJson());
      final importedJson = jsonEncode(imported.toJson());

      expect(importedJson, originalJson);
    });
  });

  group('JsonExporter - Schema validation', () {
    late JsonExporter exporter;

    setUp(() {
      exporter = JsonExporter();
    });

    test('Rejects document with invalid schema version', () async {
      final document = Document(
        id: 'doc-invalid',
        title: 'Invalid Schema',
        schemaVersion: 999,
        artboards: const [],
      );

      final tempDir = Directory.systemTemp.createTempSync('wiretuner_test_');
      final filePath = '${tempDir.path}/invalid_schema.json';

      try {
        await expectLater(
          exporter.exportToFile(document, filePath),
          throwsA(isA<ArgumentError>()),
        );
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('Accepts document with current schema version', () async {
      final document = Document(
        id: 'doc-valid',
        title: 'Valid Schema',
        schemaVersion: kDocumentSchemaVersion,
        artboards: const [],
      );

      final tempDir = Directory.systemTemp.createTempSync('wiretuner_test_');
      final filePath = '${tempDir.path}/valid_schema.json';

      try {
        await exporter.exportToFile(document, filePath);
        final file = File(filePath);
        expect(file.existsSync(), isTrue);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
