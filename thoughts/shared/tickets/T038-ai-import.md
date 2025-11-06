# T038: Adobe Illustrator (AI) Import

## Status
- **Phase**: 9 - Import/Export
- **Priority**: Critical (MVP)
- **Estimated Effort**: 3 days
- **Dependencies**: T034

## Overview
Import Adobe Illustrator files (.ai format).

## Objectives
- Parse AI files (PDF-based format)
- Extract vector paths and shapes
- Convert to WireTuner objects
- Create ImportEvent with all objects

## Implementation Strategy

AI files come in two formats:
1. **Legacy AI** (PostScript-based) - complex, may skip for MVP
2. **PDF-compatible AI** (AI 9+) - These are PDFs with AI metadata

**Approach**: Use PDF parsing to read PDF-compatible AI files.

```dart
import 'package:pdf/pdf.dart';

class AIImporter {
  Future<Document> importAI(String filePath) async {
    // 1. Parse as PDF
    final pdfDoc = await _parsePDFFile(filePath);

    // 2. Extract vector content from PDF
    final objects = await _extractVectorObjects(pdfDoc);

    // 3. Create new document with imported objects
    final document = Document.empty();
    final layer = document.layers.first.copyWith(objects: objects);

    // 4. Record import event
    final importEvent = Event(
      sequence: 1,
      userId: 'system',
      type: EventType.objectImported,
      data: {
        'source': filePath,
        'format': 'ai',
        'objectIds': objects.map((o) => o.id).toList(),
      },
    );

    return document;
  }
}
```

## Success Criteria
- [ ] Can import AI files created in Illustrator
- [ ] Paths import correctly
- [ ] Basic shapes preserved
- [ ] Colors/strokes imported
- [ ] ImportEvent recorded

## Notes
- May need to use native code for robust AI parsing
- Consider using librsvg or similar for complex cases
- Start with simple AI files for MVP

## References
- AI File Format: https://www.adobe.com/devnet/illustrator.html
