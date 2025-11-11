# Export Functionality - Usage Examples

This document provides practical examples of using the new SVG and JSON export functionality implemented in I5.T1.

---

## Table of Contents

1. [Per-Artboard SVG Export](#per-artboard-svg-export)
2. [JSON Archival Export](#json-archival-export)
3. [Using the Export Dialog](#using-the-export-dialog)
4. [Programmatic Export](#programmatic-export)
5. [Import and Validation](#import-and-validation)

---

## Per-Artboard SVG Export

### Export a Single Artboard

```dart
import 'package:wiretuner/infrastructure/export/svg_exporter.dart';
import 'package:wiretuner/domain/document/document.dart';

Future<void> exportArtboard() async {
  final document = /* your document */;
  final artboard = document.getArtboardById('artboard-mobile');

  final exporter = SvgExporter();
  await exporter.exportArtboardToFile(
    artboard!,
    '/Users/name/Desktop/mobile_view.svg',
    documentTitle: document.title,
  );
}
```

### Export All Artboards (Separate Files)

```dart
Future<void> exportAllArtboards(Document document, String basePath) async {
  final exporter = SvgExporter();

  for (final artboard in document.artboards) {
    final fileName = '${basePath}/${artboard.name.toLowerCase()}.svg';
    await exporter.exportArtboardToFile(
      artboard,
      fileName,
      documentTitle: document.title,
    );
  }
}
```

### Generate SVG String (No File)

```dart
String generateArtboardSvg(Artboard artboard) {
  final exporter = SvgExporter();
  return exporter.generateSvgForArtboard(artboard);
}
```

---

## JSON Archival Export

### Export Full Document

```dart
import 'package:wiretuner/infrastructure/export/json_exporter.dart';

Future<void> exportDocumentToJson() async {
  final document = /* your document */;
  final exporter = JsonExporter();

  await exporter.exportToFile(
    document,
    '/Users/name/Documents/my_design.json',
    prettyPrint: true, // Human-readable
  );
}
```

### Export Specific Artboards Only

```dart
Future<void> exportSelectedArtboards(
  Document document,
  List<String> artboardIds,
) async {
  final exporter = JsonExporter();

  await exporter.exportToFile(
    document,
    '/Users/name/Documents/selected_artboards.json',
    artboardIds: artboardIds,
    prettyPrint: true,
  );
}
```

### Minified Export (Version Control)

```dart
Future<void> exportMinified(Document document) async {
  final exporter = JsonExporter();

  await exporter.exportToFile(
    document,
    '/Users/name/repo/design.json',
    prettyPrint: false, // Smaller file size
  );
}
```

### Generate JSON String

```dart
String generateDocumentJson(Document document) {
  final exporter = JsonExporter();
  return exporter.generateJson(document, prettyPrint: true);
}
```

---

## Using the Export Dialog

### Show Export Dialog from UI

```dart
import 'package:flutter/material.dart';
import 'package:wiretuner/modules/export/export_dialog.dart';

Future<void> showExportDialog(
  BuildContext context,
  Document document,
  String currentArtboardId,
) async {
  final result = await showDialog<ExportResult>(
    context: context,
    builder: (context) => ExportDialog(
      document: document,
      currentArtboardId: currentArtboardId,
    ),
  );

  if (result != null) {
    // Export successful
    print('Exported ${result.format.name} to:');
    for (final path in result.filePaths) {
      print('  - $path');
    }
  }
}
```

### Menu Integration

```dart
MenuBar(
  children: [
    SubmenuButton(
      menuChildren: [
        MenuItemButton(
          child: const Text('Export...'),
          onPressed: () => showExportDialog(
            context,
            documentProvider.document,
            navigatorProvider.currentArtboardId,
          ),
        ),
      ],
      child: const Text('File'),
    ),
  ],
)
```

---

## Programmatic Export

### Export Workflow for Build Systems

```dart
import 'dart:io';
import 'package:wiretuner/infrastructure/export/json_exporter.dart';
import 'package:wiretuner/infrastructure/export/svg_exporter.dart';

Future<void> buildExportPipeline(String inputJsonPath) async {
  // 1. Load document from JSON
  final jsonExporter = JsonExporter();
  final importResult = await jsonExporter.importFromFile(inputJsonPath);

  if (importResult.warnings.isNotEmpty) {
    print('Warnings: ${importResult.warnings}');
  }

  final document = importResult.document;

  // 2. Export all artboards to SVG
  final svgExporter = SvgExporter();
  final outputDir = Directory('build/exports');
  await outputDir.create(recursive: true);

  for (final artboard in document.artboards) {
    final svgPath = '${outputDir.path}/${artboard.id}.svg';
    await svgExporter.exportArtboardToFile(
      artboard,
      svgPath,
      documentTitle: document.title,
    );
    print('✓ Exported: ${artboard.name} → $svgPath');
  }

  // 3. Create minified JSON backup
  final backupPath = '${outputDir.path}/backup.json';
  await jsonExporter.exportToFile(
    document,
    backupPath,
    prettyPrint: false,
  );

  print('✓ Build complete: ${document.artboards.length} artboards exported');
}
```

### Automated Testing Export

```dart
Future<void> exportForVisualRegression(Document document) async {
  final svgExporter = SvgExporter();
  final testDir = Directory('test/fixtures/visual_regression');
  await testDir.create(recursive: true);

  for (final artboard in document.artboards) {
    final path = '${testDir.path}/${artboard.id}_${DateTime.now().millisecondsSinceEpoch}.svg';
    await svgExporter.exportArtboardToFile(artboard, path);
  }
}
```

---

## Import and Validation

### Validate Before Import

```dart
Future<Document?> safeImportJson(String filePath) async {
  // Read file content
  final file = File(filePath);
  final jsonContent = await file.readAsString();

  // Validate compatibility
  final validation = JsonExporter.validateImport(jsonContent);

  if (!validation.isCompatible) {
    print('❌ Import failed: ${validation.error}');
    return null;
  }

  if (validation.warnings.isNotEmpty) {
    print('⚠️ Warnings:');
    for (final warning in validation.warnings) {
      print('  - $warning');
    }
  }

  // Import document
  final exporter = JsonExporter();
  final result = await exporter.importFromFile(filePath);

  return result.document;
}
```

### Round-Trip Validation

```dart
Future<bool> validateRoundTrip(Document original) async {
  final exporter = JsonExporter();
  final tempFile = File('${Directory.systemTemp.path}/roundtrip_test.json');

  // Export
  await exporter.exportToFile(original, tempFile.path);

  // Import
  final result = await exporter.importFromFile(tempFile.path);
  final imported = result.document;

  // Compare
  final originalJson = jsonEncode(original.toJson());
  final importedJson = jsonEncode(imported.toJson());

  final isIdentical = originalJson == importedJson;

  // Cleanup
  await tempFile.delete();

  if (!isIdentical) {
    print('❌ Round-trip validation failed');
    print('Original artboards: ${original.artboards.length}');
    print('Imported artboards: ${imported.artboards.length}');
  }

  return isIdentical;
}
```

### Migration from Old Format

```dart
Future<Document> migrateOldDocument(String oldJsonPath) async {
  final exporter = JsonExporter();

  // Import (handles v1 to v2 migration automatically)
  final result = await exporter.importFromFile(oldJsonPath);

  if (result.warnings.isNotEmpty) {
    print('Migration warnings:');
    for (final warning in result.warnings) {
      print('  - $warning');
    }
  }

  // Re-export with current version
  final newPath = oldJsonPath.replaceAll('.json', '_migrated.json');
  await exporter.exportToFile(result.document, newPath);

  print('✓ Migrated to $newPath');
  return result.document;
}
```

---

## Advanced Usage

### Custom Export Metadata

```dart
Map<String, dynamic> createExportWithMetadata(Document document) {
  final exporter = JsonExporter();
  final baseExport = jsonDecode(exporter.generateJson(document));

  // Add custom metadata
  return {
    ...baseExport,
    'customMetadata': {
      'exportedBy': 'My App v1.2.3',
      'purpose': 'Client review',
      'reviewer': 'john@example.com',
      'tags': ['responsive', 'mobile-first', 'prototype'],
    },
  };
}
```

### Batch Export with Progress

```dart
Future<void> batchExport(
  List<Document> documents,
  String outputDir,
  void Function(int current, int total) onProgress,
) async {
  final svgExporter = SvgExporter();

  for (var i = 0; i < documents.length; i++) {
    final doc = documents[i];

    for (final artboard in doc.artboards) {
      final path = '$outputDir/${doc.id}_${artboard.id}.svg';
      await svgExporter.exportArtboardToFile(artboard, path);
    }

    onProgress(i + 1, documents.length);
  }
}
```

### Export with Compression

```dart
import 'dart:io';
import 'package:archive/archive.dart';

Future<void> exportCompressed(Document document, String zipPath) async {
  final tempDir = Directory.systemTemp.createTempSync('wiretuner_export_');

  try {
    // Export all formats to temp directory
    final jsonExporter = JsonExporter();
    final svgExporter = SvgExporter();

    await jsonExporter.exportToFile(
      document,
      '${tempDir.path}/document.json',
    );

    for (final artboard in document.artboards) {
      await svgExporter.exportArtboardToFile(
        artboard,
        '${tempDir.path}/${artboard.name}.svg',
      );
    }

    // Create zip archive
    final archive = Archive();
    for (final file in tempDir.listSync()) {
      if (file is File) {
        final bytes = await file.readAsBytes();
        archive.addFile(ArchiveFile(
          file.path.split('/').last,
          bytes.length,
          bytes,
        ));
      }
    }

    // Write zip file
    final zipBytes = ZipEncoder().encode(archive);
    await File(zipPath).writeAsBytes(zipBytes!);

  } finally {
    await tempDir.delete(recursive: true);
  }
}
```

---

## Error Handling

### Comprehensive Error Handling

```dart
Future<ExportResult?> safeExport(
  Document document,
  String filePath,
  ExportFormat format,
) async {
  try {
    switch (format) {
      case ExportFormat.svg:
        final exporter = SvgExporter();
        // Export logic...
        return ExportResult(format: format, filePaths: [filePath]);

      case ExportFormat.json:
        final exporter = JsonExporter();
        await exporter.exportToFile(document, filePath);
        return ExportResult(format: format, filePaths: [filePath]);

      default:
        throw UnimplementedError('Format $format not supported');
    }
  } on FileSystemException catch (e) {
    print('❌ File system error: ${e.message}');
    print('   Path: ${e.path}');
    return null;
  } on ArgumentError catch (e) {
    print('❌ Invalid argument: ${e.message}');
    return null;
  } catch (e, stackTrace) {
    print('❌ Unexpected error: $e');
    print('Stack trace: $stackTrace');
    return null;
  }
}
```

---

## Performance Optimization

### Parallel Export

```dart
Future<void> parallelExport(Document document, String outputDir) async {
  final svgExporter = SvgExporter();

  // Export all artboards in parallel
  await Future.wait(
    document.artboards.map((artboard) async {
      final path = '$outputDir/${artboard.id}.svg';
      return svgExporter.exportArtboardToFile(artboard, path);
    }),
  );
}
```

### Memory-Efficient Large Document Export

```dart
Future<void> exportLargeDocument(Document document, String outputDir) async {
  final svgExporter = SvgExporter();

  // Export one artboard at a time to avoid memory pressure
  for (final artboard in document.artboards) {
    final path = '$outputDir/${artboard.id}.svg';
    await svgExporter.exportArtboardToFile(artboard, path);

    // Give GC a chance to run
    await Future.delayed(const Duration(milliseconds: 10));
  }
}
```

---

## Testing Utilities

### Mock Export for Tests

```dart
class MockExporter {
  final List<String> exportedPaths = [];

  Future<void> mockExport(Document document, String path) async {
    exportedPaths.add(path);
    // Simulate export delay
    await Future.delayed(const Duration(milliseconds: 10));
  }

  bool wasExported(String path) => exportedPaths.contains(path);

  void reset() => exportedPaths.clear();
}
```

### Verification Helpers

```dart
Future<bool> verifySvgOutput(String svgPath) async {
  final content = await File(svgPath).readAsString();

  return content.startsWith('<?xml version="1.0"') &&
         content.contains('<svg') &&
         content.contains('xmlns="http://www.w3.org/2000/svg"') &&
         content.endsWith('</svg>');
}

Future<bool> verifyJsonOutput(String jsonPath) async {
  final content = await File(jsonPath).readAsString();
  final data = jsonDecode(content);

  return data['fileFormatVersion'] != null &&
         data['exportedAt'] != null &&
         data['document'] != null;
}
```

---

## Integration Examples

### With Navigator Module

```dart
class NavigatorExportIntegration {
  final NavigatorService navigator;
  final SvgExporter svgExporter;

  NavigatorExportIntegration(this.navigator, this.svgExporter);

  Future<void> exportCurrentArtboard(String outputPath) async {
    final currentArtboard = navigator.getCurrentArtboard();
    if (currentArtboard != null) {
      await svgExporter.exportArtboardToFile(
        currentArtboard,
        outputPath,
      );
    }
  }

  Future<void> exportVisibleArtboards(String outputDir) async {
    final visibleArtboards = navigator.getVisibleArtboards();

    for (final artboard in visibleArtboards) {
      final path = '$outputDir/${artboard.id}.svg';
      await svgExporter.exportArtboardToFile(artboard, path);
    }
  }
}
```

### With History Module

```dart
class HistoryExportIntegration {
  Future<void> exportHistoricalState(
    HistoryService history,
    int eventIndex,
    String outputPath,
  ) async {
    // Replay to specific event
    final document = await history.replayToEvent(eventIndex);

    // Export that state
    final exporter = JsonExporter();
    await exporter.exportToFile(document, outputPath);
  }
}
```

---

## Best Practices

1. **Always validate before import**
   ```dart
   final validation = JsonExporter.validateImport(content);
   if (!validation.isCompatible) {
     // Handle error
   }
   ```

2. **Use pretty print for human-readable exports**
   ```dart
   await exporter.exportToFile(doc, path, prettyPrint: true);
   ```

3. **Include document title in artboard exports**
   ```dart
   await exporter.exportArtboardToFile(
     artboard,
     path,
     documentTitle: document.title,
   );
   ```

4. **Handle warnings from imports**
   ```dart
   final result = await exporter.importFromFile(path);
   if (result.warnings.isNotEmpty) {
     // Log or display warnings
   }
   ```

5. **Use try-catch for file operations**
   ```dart
   try {
     await exporter.exportToFile(doc, path);
   } on FileSystemException catch (e) {
     // Handle file errors
   }
   ```

---

## Conclusion

The new export functionality provides flexible, robust options for exporting WireTuner documents. Use these examples as a starting point for integrating export capabilities into your application or workflow.

For questions or issues, refer to:
- Implementation: `lib/infrastructure/export/`
- Tests: `test/unit/*_exporter_test.dart`
- Architecture: `.codemachine/outputs/I5_T1_Export_Implementation_Summary.md`
