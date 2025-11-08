# Import Compatibility Specification

**Version:** 0.1.0
**Status:** Implemented
**Last Updated:** 2025-11-08

## Overview

WireTuner supports importing vector graphics from external formats (SVG and Adobe Illustrator) into its event-based document model. This document specifies the supported features, limitations, and compatibility matrix for Milestone 0.1.

## Architecture

### Event-Based Import

Unlike traditional vector editors that directly construct document objects from imported files, WireTuner converts external formats into **event streams** that are replayed to reconstruct the document. This approach:

- ✅ Maintains event sourcing architecture consistency
- ✅ Enables undo/redo for imported content
- ✅ Provides audit trail of import operations
- ✅ Allows import replay and migration across schema versions

**Import Flow:**
```
SVG/AI File → Parser → Event Stream → Event Replay → Document
```

## SVG Import Compatibility

### Supported SVG Version

- **SVG 1.1** (W3C Recommendation)
- Basic SVG 2.0 features that align with SVG 1.1

### Supported Path Commands

| Command | Type | Support | Notes |
|---------|------|---------|-------|
| `M` / `m` | MoveTo | ✅ Full | Absolute and relative |
| `L` / `l` | LineTo | ✅ Full | Absolute and relative |
| `H` / `h` | Horizontal LineTo | ✅ Full | Absolute and relative |
| `V` / `v` | Vertical LineTo | ✅ Full | Absolute and relative |
| `C` / `c` | Cubic Bezier | ✅ Full | Absolute and relative, handles converted to WireTuner format |
| `S` / `s` | Smooth Cubic Bezier | ✅ Full | Automatic reflection of control point |
| `Q` / `q` | Quadratic Bezier | ✅ Converted | Converted to cubic Bezier internally |
| `T` / `t` | Smooth Quadratic Bezier | ✅ Converted | Converted to cubic Bezier internally |
| `A` / `a` | Elliptical Arc | ❌ Not Supported | Future enhancement (Milestone 0.2) |
| `Z` / `z` | ClosePath | ✅ Full | Marks path as closed |

### Supported Shape Elements

| Element | Support | Conversion | Notes |
|---------|---------|------------|-------|
| `<path>` | ✅ Full | Events | Direct conversion to path events |
| `<rect>` | ✅ Full | Path | Converted to 4-point closed path |
| `<circle>` | ✅ Full | Path | Converted to ellipse approximation (4 Bezier curves) |
| `<ellipse>` | ✅ Full | Path | Approximated with 4 cubic Bezier curves |
| `<line>` | ✅ Full | Path | Converted to 2-point open path |
| `<polyline>` | ✅ Full | Path | Converted to multi-point open path |
| `<polygon>` | ✅ Full | Path | Converted to multi-point closed path |

**Note on Rounded Rectangles:** `<rect>` elements with `rx`/`ry` corner radius attributes are currently converted to sharp rectangles. Rounded corner support is planned for Milestone 0.2.

### Supported Structural Elements

| Element | Support | Behavior | Notes |
|---------|---------|----------|-------|
| `<g>` | ✅ Partial | Flattened | Groups are flattened to single layer in Milestone 0.1 |
| `<defs>` | ✅ Ignored | Skipped | Definition section skipped safely |
| `<metadata>` | ✅ Ignored | Skipped | Metadata preserved in SVG export but not imported |
| `<title>` | ✅ Ignored | Skipped | Future enhancement for document title |
| `<desc>` | ✅ Ignored | Skipped | Future enhancement for descriptions |
| `<symbol>` | ❌ Not Supported | Skipped | Instance/symbol system not in 0.1 |
| `<use>` | ❌ Not Supported | Skipped | Instance references not supported |

### Supported Style Attributes

| Attribute | Support | Notes |
|-----------|---------|-------|
| `stroke` | ✅ Full | Color value preserved (hex, named colors) |
| `stroke-width` | ✅ Full | Numeric value preserved |
| `fill` | ✅ Full | Color value preserved, `none` respected |
| `opacity` | ✅ Full | Opacity value (0.0-1.0) preserved |
| `stroke-linecap` | ❌ Not Supported | Future enhancement |
| `stroke-linejoin` | ❌ Not Supported | Future enhancement |
| `stroke-dasharray` | ❌ Not Supported | Future enhancement |
| `fill-rule` | ❌ Not Supported | Future enhancement |

**Note:** Style attributes are extracted from element attributes only. CSS styles in `<style>` blocks or external stylesheets are not supported in Milestone 0.1.

### Unsupported Features

The following SVG features are **not supported** in Milestone 0.1. Importing files containing these features will:
- Log warnings to console
- Skip the unsupported elements
- Continue importing supported content (no crash)

| Feature Category | Elements/Attributes | Status |
|------------------|---------------------|--------|
| **Gradients** | `<linearGradient>`, `<radialGradient>`, `fill="url(#...)"` | Logged, skipped |
| **Patterns** | `<pattern>`, `fill="url(#...)"` | Logged, skipped |
| **Filters** | `<filter>`, `<feGaussianBlur>`, etc. | Logged, skipped |
| **Clipping/Masking** | `<clipPath>`, `<mask>`, `clip-path`, `mask` | Logged, skipped |
| **Text** | `<text>`, `<tspan>`, `<textPath>` | Logged, skipped |
| **Images** | `<image>` | Logged, skipped |
| **Animations** | `<animate>`, `<animateTransform>`, etc. | Logged, skipped |
| **Transforms** | `transform="..."` attribute | Logged, skipped (future: Milestone 0.2) |

## Adobe Illustrator (.ai) Import Compatibility

### Architecture

Adobe Illustrator files (.ai) are PDF-based with proprietary extensions:
- **PDF Layer:** Contains geometric primitives (paths, curves)
- **AI Private Data:** Contains Illustrator-specific features (effects, live paint, symbols)

**Milestone 0.1 Strategy:** Parse PDF layer only, ignore AI private data.

### Supported AI Features

| Feature | Support | Notes |
|---------|---------|-------|
| **Basic Paths** | ⚠️ Placeholder | PDF parsing library needed for production |
| **Straight Lines** | ⚠️ Placeholder | PDF `l` operator support planned |
| **Bezier Curves** | ⚠️ Placeholder | PDF `c` operator support planned |
| **Rectangles** | ⚠️ Placeholder | PDF `re` operator support planned |

**Milestone 0.1 Status:** AI import service is implemented as a **placeholder** that demonstrates the architecture but does not perform actual PDF parsing. The `pdf` package (^3.10.0) in dependencies is for PDF *generation*, not parsing.

**Future Implementation:** A production AI importer requires adding a PDF parsing library (e.g., `pdf_renderer`, `pdfium_bindings`) in a future milestone.

### Unsupported AI Features

| Feature Category | Status |
|------------------|--------|
| **Effects** (drop shadow, glow, etc.) | Not supported |
| **Live Paint** | Not supported |
| **Symbols** | Not supported |
| **Gradients/Patterns** | Not supported |
| **Text** | Not supported |
| **Artboards** (multi-page) | Only first page imported |
| **Illustrator Private Data** | Ignored |

### Coordinate System Conversion

**PDF Coordinate System:**
- Origin: Bottom-left corner
- Y-axis: Increases upward

**WireTuner Coordinate System:**
- Origin: Top-left corner
- Y-axis: Increases downward

**Conversion:** `y_wiretuner = pageHeight - y_pdf`

## Security Constraints

### File Size Limits

- **Maximum File Size:** 10 MB (10,485,760 bytes)
- **Rationale:** Prevent DoS attacks via huge files, out-of-memory errors
- **Behavior:** Files exceeding limit are rejected with `ImportException`

### Path Data Limits

- **Maximum Path Data Length:** 100,000 characters per `<path>` element
- **Rationale:** Prevent billion laughs pattern, excessive memory allocation
- **Behavior:** Paths exceeding limit are rejected with `ImportException`

### XML External Entities (XXE)

- **Protection:** XML parser does not support DTD/external entities
- **Library:** `xml` package (^6.5.0) does not enable XXE by default
- **Status:** XXE attacks prevented

### Coordinate Validation

- **Finite Numbers:** All coordinate values must be finite (not NaN, not Infinity)
- **Range:** Coordinates within ±1,000,000 pixels
- **Behavior:** Invalid coordinates rejected with `ImportException`

## Import API

### SVG Import

```dart
import 'package:wiretuner/infrastructure/import_export/svg_importer.dart';
import 'package:wiretuner/domain/events/event_base.dart';

final importer = SvgImporter();

// From file
final events = await importer.importFromFile('/path/to/drawing.svg');

// From string
final svgContent = '<svg>...</svg>';
final events = await importer.importFromString(svgContent);

// Replay events
for (final event in events) {
  eventDispatcher.dispatch(event);
}
```

### AI Import

```dart
import 'package:wiretuner/infrastructure/import_export/ai_importer.dart';

final importer = AiImporter();

// From file (Milestone 0.1: placeholder implementation)
final events = await importer.importFromFile('/path/to/drawing.ai');

// Note: Returns demonstration events in 0.1, not actual AI file content
```

### Exception Handling

```dart
import 'package:wiretuner/infrastructure/import_export/import_validator.dart';

try {
  final events = await importer.importFromFile(filePath);
  print('Import successful: ${events.length} events');
} on ImportException catch (e) {
  print('Import failed: ${e.message}');
  // Handle validation errors, malformed files, unsupported formats
}
```

## Testing Strategy

### Unit Tests

- Path command parsing (all supported commands)
- Shape element conversion
- Coordinate validation
- Security constraint enforcement
- Error handling for malformed input

### Integration Tests

Located in `integration_test/import_roundtrip_test.dart`:

- ✅ SVG path import (line segments)
- ✅ SVG path import (Bezier curves)
- ✅ SVG shape import (rect, circle, ellipse, line, polygon, polyline)
- ✅ SVG groups and multiple elements
- ✅ Security constraints (file size, path data length, malformed XML)
- ✅ Unsupported features (graceful handling, no crash)
- ✅ AI import placeholder (no crash, valid event structure)

### Golden File Tests

Located in `test/fixtures/golden/`:

- `simple_path.svg` - Basic closed path with line segments
- `bezier_path.svg` - Path with cubic Bezier curves
- `shapes.svg` - Rectangle, circle, and ellipse elements

**Note:** Full round-trip tests (import → replay → export → compare) require event replay infrastructure. Milestone 0.1 tests verify event generation correctness. Future milestones will add document reconstruction validation.

## Compatibility Matrix

### Import Format Support

| Format | Extension | Milestone 0.1 | Future |
|--------|-----------|---------------|--------|
| SVG 1.1 | `.svg` | ✅ Full | Enhanced (transforms, gradients) |
| Adobe Illustrator | `.ai` | ⚠️ Placeholder | Full PDF parsing |
| PDF | `.pdf` | ❌ Not Supported | Possible in 0.3+ |
| EPS | `.eps` | ❌ Not Supported | Possible in 0.4+ |
| DXF (CAD) | `.dxf` | ❌ Not Supported | Possible in 0.5+ |

### SVG Export Compatibility

For round-trip compatibility, refer to `lib/infrastructure/export/svg_exporter.dart`:

- ✅ Paths exported as SVG `<path>` elements
- ✅ Shapes converted to paths for export
- ✅ Layers exported as SVG `<g>` groups
- ✅ Basic stroke styling (color, width)
- ❌ Fill colors not exported in 0.1
- ❌ Gradients/filters not exported in 0.1

## Known Limitations

### Milestone 0.1

1. **No Transform Support:** SVG `transform` attributes are ignored. Imported objects retain their original coordinates without rotation, scaling, or skewing.

2. **Flattened Groups:** SVG `<g>` groups are flattened to a single layer. Nested layer hierarchy is not preserved.

3. **Rounded Rectangles:** `<rect>` elements with `rx`/`ry` are converted to sharp rectangles.

4. **Quadratic Bezier Approximation:** Quadratic Bezier curves (`Q`, `T` commands) are converted to cubic Bezier, which may have minor precision differences.

5. **No Style Inheritance:** Only styles on the element itself are imported. Inherited styles from parent `<g>` elements are not supported.

6. **AI Import Placeholder:** AI file import is a placeholder implementation. Production use requires adding a PDF parsing library.

7. **Single Page Only:** For multi-page AI files, only the first page is imported.

### Future Enhancements (Milestone 0.2+)

- ✅ Transform attribute support (rotate, scale, translate, skew)
- ✅ Nested layer preservation
- ✅ Rounded rectangle corners
- ✅ Gradient import (linear and radial)
- ✅ Text import (convert to paths or editable text objects)
- ✅ Full AI/PDF parsing with effects support
- ✅ Clipping path support
- ✅ Arc command support
- ✅ Pattern fills

## Best Practices

### For Users

1. **Simplify Before Import:** For best results, flatten transforms and convert text to paths in the source editor before exporting to SVG.

2. **Use SVG 1.1:** Ensure exported SVG files use SVG 1.1 format for maximum compatibility.

3. **Avoid Advanced Features:** Gradients, filters, and effects will be lost during import. Use solid colors for Milestone 0.1.

4. **Check File Size:** Keep imported files under 10 MB. For large illustrations, split into multiple files.

5. **Validate Before Import:** Use an SVG validator to ensure well-formed XML before importing.

### For Developers

1. **Extend Import Events:** When adding new event types, update both importers to generate them.

2. **Test Round-Trip:** Add golden file tests for any new supported features.

3. **Log Warnings:** Use `logger.w()` for unsupported features, never throw exceptions.

4. **Validate All Inputs:** Use `ImportValidator` for all numeric and string inputs from external files.

5. **Document Limitations:** Update this spec when adding or removing support for features.

## References

### Standards

- [SVG 1.1 W3C Recommendation](https://www.w3.org/TR/SVG11/)
- [SVG Path Syntax](https://www.w3.org/TR/SVG11/paths.html)
- [PDF Reference (Adobe)](https://www.adobe.com/devnet/pdf/pdf_reference.html)

### Related Documentation

- `docs/specs/event_payload.md` - Event schema specification
- `lib/infrastructure/export/svg_exporter.dart` - SVG export implementation
- `lib/domain/models/path.dart` - Path model structure
- `lib/domain/models/anchor_point.dart` - Anchor and handle math

### Implementation Files

- `lib/infrastructure/import_export/svg_importer.dart` - SVG import service
- `lib/infrastructure/import_export/ai_importer.dart` - AI import service
- `lib/infrastructure/import_export/import_validator.dart` - Shared validation
- `integration_test/import_roundtrip_test.dart` - Integration tests

---

**Document Version History:**

- **0.1.0** (2025-11-08): Initial version for Milestone 0.1 release
  - SVG 1.1 path and shape import
  - AI import placeholder
  - Security constraints
  - Integration tests
