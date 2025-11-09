# Adobe Illustrator Import Feature Matrix (Tier-2)

**Version:** 1.0
**Date:** 2025-11-09
**Status:** Active
**Document Type:** Feature Coverage Specification

---

<!-- anchor: ai-import-matrix -->

## Overview

This document defines WireTuner's support matrix for importing Adobe Illustrator (.ai) files, categorizing features into three tiers based on implementation priority and technical feasibility. The matrix guides both users (what to expect) and developers (what to implement).

**Key Design Decisions:**
- **Tier-1 (Core Paths):** Fully supported basic geometry critical for vector editing workflows
- **Tier-2 (Advanced Geometry):** Partial support with automatic conversion to Tier-1 equivalents
- **Tier-3 (Illustrator-Specific):** Unsupported proprietary features; warnings logged but import continues

**Related Documents:**
- [Import Compatibility Specification](../specs/import_compatibility.md) - SVG and AI import overview
- [Vector Model Specification](vector_model.md) - Target event/object model
- [Event Schema Reference](event_schema.md) - Event payload requirements
- [File Format Specification](../../api/file_format_spec.md) - .wiretuner compatibility
- [Architecture Decision 5](../../.codemachine/artifacts/architecture/06_Rationale_and_Future.md#decision-50ms-sampling) - Sampling strategy

---

## Table of Contents

1. [Feature Tier Definitions](#feature-tier-definitions)
2. [Tier-1: Core Path Geometry (Full Support)](#tier-1-core-path-geometry)
3. [Tier-2: Advanced Geometry (Partial Support)](#tier-2-advanced-geometry)
4. [Tier-3: Unsupported Features](#tier-3-unsupported-features)
5. [Stroke and Fill Support](#stroke-and-fill-support)
6. [Coordinate System Conversion](#coordinate-system-conversion)
7. [Warning and Error Handling](#warning-and-error-handling)
8. [Testing Strategy](#testing-strategy)
9. [Implementation Roadmap](#implementation-roadmap)
10. [Cross-References](#cross-references)

---

## Feature Tier Definitions

### Tier Classification

| Tier | Support Level | Behavior | Import Outcome |
|------|--------------|----------|----------------|
| **Tier-1** | ✅ Full Support | Direct conversion to WireTuner events | Identical visual output, no warnings |
| **Tier-2** | ⚠️ Partial Support | Conversion with approximation/fallback | Visual approximation, informational warnings |
| **Tier-3** | ❌ Not Supported | Feature skipped, warning logged | Feature ignored, document imports successfully |

### Warning Levels

| Level | Symbol | Usage | User Action Required |
|-------|--------|-------|---------------------|
| **Info** | ℹ️ | Tier-2 conversions, non-critical degradation | Optional: Review imported result |
| **Warning** | ⚠️ | Tier-3 feature detected, visual fidelity loss | Recommended: Adjust in WireTuner |
| **Error** | ❌ | Malformed file, security violation | Required: Fix source file or contact support |

---

## Tier-1: Core Path Geometry

Tier-1 features map directly to WireTuner's event model with full fidelity.

### PDF Graphics Operators (Full Support)

| PDF Operator | Syntax | Description | WireTuner Event Mapping | Notes |
|-------------|--------|-------------|------------------------|-------|
| **moveto** | `x y m` | Begin new subpath | `CreatePathEvent(startAnchor: Point(x, y))` | Starts new path, generates UUID |
| **lineto** | `x y l` | Add line segment | `AddAnchorEvent(position: Point(x, y), anchorType: line)` | Straight line connection |
| **curveto** | `x1 y1 x2 y2 x3 y3 c` | Cubic Bezier curve | `AddAnchorEvent(position: Point(x3, y3), anchorType: bezier, handleIn: ..., handleOut: ...)` | Converts absolute control points to relative handles |
| **closepath** | `h` | Close current subpath | `FinishPathEvent(pathId: ..., closed: true)` | Implicit segment from last to first anchor |
| **stroke** | `S` | Stroke path | Event metadata (`strokeColor`, `strokeWidth`) | Rendering operator, does not modify geometry |
| **fill** | `f` | Fill path | Event metadata (`fillColor`) | Rendering operator, does not modify geometry |

### Control Point Conversion

**PDF Format:** Absolute coordinates for control points
**WireTuner Format:** Relative offsets from anchor position

```dart
// PDF: c x1 y1 x2 y2 x3 y3
final cp1Absolute = Point(x: x1, y: flipY(y1));
final cp2Absolute = Point(x: x2, y: flipY(y2));
final endPoint = Point(x: x3, y: flipY(y3));

// Convert to relative handles
final handleOut = Point(
  x: cp1Absolute.x - currentPoint.x,
  y: cp1Absolute.y - currentPoint.y,
);
final handleIn = Point(
  x: cp2Absolute.x - endPoint.x,
  y: cp2Absolute.y - endPoint.y,
);

// Emit events
ModifyAnchorEvent(..., handleOut: handleOut);
AddAnchorEvent(..., handleIn: handleIn, anchorType: bezier);
```

### Rectangle Operator

| PDF Operator | Syntax | Description | Event Mapping | Notes |
|-------------|--------|-------------|---------------|-------|
| **rectangle** | `x y w h re` | Axis-aligned rectangle | `CreateShapeEvent(shapeType: rectangle, parameters: {x, y, width, height})` | Prefer shape event over 4-anchor path for editability |

**Decision:** Rectangles emit `CreateShapeEvent` instead of path events to preserve parametric editability (width/height adjustable).

---

## Tier-2: Advanced Geometry

Tier-2 features are converted to Tier-1 equivalents with best-effort approximation.

### Bezier Curve Variants

| PDF Operator | Syntax | Description | Conversion Strategy | Warning Level |
|-------------|--------|-------------|---------------------|---------------|
| **v** | `x2 y2 x3 y3 v` | Bezier with control point 1 = current point | Set `handleOut` to zero vector, use `x2 y2` for `handleIn` | ℹ️ Info |
| **y** | `x1 y1 x3 y3 y` | Bezier with control point 2 = end point | Use `x1 y1` for `handleOut`, set `handleIn` to zero vector | ℹ️ Info |

**Rationale:** These operators are syntactic shortcuts for common Bezier patterns; conversion is lossless.

### Gradients (Tier-2 Partial)

| Feature | AI Representation | WireTuner Conversion | Warning Level |
|---------|------------------|---------------------|---------------|
| **Linear Gradient** | `/sh` operator + gradient dictionary | Convert to solid fill using gradient's first color stop | ⚠️ Warning |
| **Radial Gradient** | `/sh` operator + gradient dictionary | Convert to solid fill using gradient's first color stop | ⚠️ Warning |
| **Mesh Gradient** | `/Sh` operator (Type 7 shading) | Convert to solid fill using average color | ⚠️ Warning |

**Warning Message Example:**
```
⚠️ Gradient detected in object 'path_abc123'
   Converted to solid fill (#FF5733).
   Original gradient: linear (2 stops)
   Future enhancement: Gradient support planned for Milestone 0.3
```

### Stroke Attributes (Tier-2 Partial)

| Attribute | PDF Operator | Support Level | Conversion | Warning |
|-----------|-------------|---------------|------------|---------|
| **Stroke Width** | `w` | ✅ Full | Direct mapping to `strokeWidth` | None |
| **Line Cap** | `J` | ❌ Not Supported | Default to butt cap | ⚠️ Warning |
| **Line Join** | `j` | ❌ Not Supported | Default to miter join | ⚠️ Warning |
| **Dash Pattern** | `d` | ❌ Not Supported | Render as solid stroke | ⚠️ Warning |
| **Miter Limit** | `M` | ❌ Not Supported | Ignore | ℹ️ Info |

---

## Tier-3: Unsupported Features

Tier-3 features are logged and skipped during import.

### Illustrator Private Data

| Feature Category | Illustrator Format | Detection Method | Behavior |
|------------------|-------------------|------------------|----------|
| **Live Paint Groups** | AI private stream | `/AIPDFPrivateData1` marker | Skip, log warning |
| **Symbols & Instances** | AI private stream | `/AISymbolSet` marker | Skip, log warning |
| **Effects & Filters** | AI private stream | `/AIEffect` dictionary | Skip, log warning |
| **Artboards** | AI private stream + PDF pages | Parse only first page | Log info |
| **Compound Paths** | AI private stream | `/AICompoundPath` | Flatten to individual paths, log warning |
| **Clipping Masks** | AI private stream | `/AIClipGroup` | Render clipped objects without mask, log warning |

**Warning Message Example:**
```
⚠️ Unsupported feature: Live Paint Group (2 objects)
   Location: Page 1, layer "Background"
   Impact: Objects imported as separate paths without live paint behavior
   Recommendation: Convert to regular paths in Illustrator before exporting
```

### Text and Typography

| Feature | Support | Behavior | Warning |
|---------|---------|----------|---------|
| **Point Text** | ❌ | Skip text objects entirely | ⚠️ Warning: "Text not supported, convert to outlines" |
| **Area Text** | ❌ | Skip | ⚠️ Warning |
| **Text on Path** | ❌ | Skip | ⚠️ Warning |
| **Font Embedding** | ❌ | Ignore | ℹ️ Info |

**Recommended Workflow:** Users should convert text to outlines in Illustrator (`Type > Create Outlines`) before exporting.

### Complex Fills and Effects

| Feature | Tier | Behavior | Warning Level |
|---------|------|----------|---------------|
| **Pattern Fills** | Tier-3 | Convert to solid fill (#CCCCCC placeholder) | ⚠️ Warning |
| **Drop Shadows** | Tier-3 | Skip effect, import base object only | ⚠️ Warning |
| **Gaussian Blur** | Tier-3 | Skip | ⚠️ Warning |
| **Blend Modes** | Tier-3 | Default to normal blending | ℹ️ Info |
| **Opacity Masks** | Tier-3 | Apply flat opacity value (average), skip mask | ⚠️ Warning |

---

## Stroke and Fill Support

### Color Formats

| AI Color Space | PDF Representation | WireTuner Conversion | Support |
|----------------|-------------------|---------------------|---------|
| **RGB** | `/DeviceRGB` + `rg` operator | Direct hex conversion (`#RRGGBB`) | ✅ Full |
| **CMYK** | `/DeviceCMYK` + `k` operator | Convert to RGB via standard formula | ✅ Full (with ℹ️ info) |
| **Grayscale** | `/DeviceGray` + `g` operator | Convert to RGB (`#RRGGBB` where R=G=B) | ✅ Full |
| **Spot Colors** | `/Separation` | Convert to fallback RGB | ⚠️ Warning |
| **LAB** | `/Lab` | Convert to RGB via LAB→RGB transform | ⚠️ Warning |

**CMYK to RGB Conversion:**
```dart
// Standard ICC profile conversion (simplified)
R = 255 * (1 - C) * (1 - K)
G = 255 * (1 - M) * (1 - K)
B = 255 * (1 - Y) * (1 - K)
```

**Warning for Spot Colors:**
```
ℹ️ Spot color "PANTONE 185 C" converted to RGB (#E03C31)
   Note: Printed output may differ from screen appearance
```

### Opacity and Transparency

| Feature | PDF Operator | Support | Conversion |
|---------|-------------|---------|------------|
| **Object Opacity** | `/ca` (non-stroke), `/CA` (stroke) | ✅ Full | Direct mapping to `opacity` field (0.0-1.0) |
| **Blend Modes** | `/BM` | ❌ Tier-3 | Default to `normal`, log warning |

---

## Coordinate System Conversion

### PDF vs. WireTuner Coordinates

| Aspect | PDF | WireTuner | Conversion |
|--------|-----|-----------|------------|
| **Origin** | Bottom-left | Top-left | `y_wt = pageHeight - y_pdf` |
| **Y-Axis Direction** | Upward (+y) | Downward (+y) | Flip required |
| **Units** | Points (1/72 inch) | Pixels (typically 1:1 at 100% zoom) | Direct mapping |
| **Coordinate Range** | Arbitrary | ±1,000,000 pixels (security limit) | Validate via `ImportValidator.validateCoordinate()` |

### Transform Matrix Handling

**PDF CTM (Current Transformation Matrix):** `[a b c d e f]`

**Milestone 0.1 Strategy:** Apply transform to coordinates during import, do not preserve as separate transform object.

```dart
// Apply CTM to point
final transformedX = a * x + c * y + e;
final transformedY = b * x + d * y + f;
final flippedY = pageHeight - transformedY;

return Point(x: transformedX, y: flippedY);
```

**Future Enhancement (Milestone 0.3):** Preserve transformations as `TransformEvent` for non-destructive editing.

---

## Warning and Error Handling

### Warning Collection

Importers MUST collect warnings during parsing and return them in a structured format:

```dart
class ImportWarning {
  final String severity; // "info" | "warning" | "error"
  final String featureType; // "gradient", "text", "effect", etc.
  final String message; // User-friendly description
  final String? objectId; // Optional object identifier
  final int? pageNumber; // Optional page number (for multi-page AI files)
}

class ImportResult {
  final List<EventBase> events;
  final List<ImportWarning> warnings;
  final ImportMetadata metadata;
}
```

### Warning Display (UX Guidance)

**Dialog Example (Mock):**
```
Import Completed with Warnings

Successfully imported 47 objects with 3 warnings:

⚠️ 2 gradients converted to solid fills
   Objects: "Background Shape", "Button Fill"

⚠️ 1 text object skipped
   Object: "Logo Text"
   Recommendation: Convert text to outlines in Illustrator

ℹ️ 1 CMYK color converted to RGB
   Color: CMYK(0.2, 0.8, 0.0, 0.1) → RGB(#CC33E6)

[View Details] [Dismiss]
```

### Error Handling (Security & Corruption)

| Error Type | Trigger | Behavior | User Message |
|------------|---------|----------|--------------|
| **File Size Exceeded** | File > 10 MB | Reject import, throw `ImportException` | "File too large (15 MB). Maximum: 10 MB." |
| **Invalid PDF Structure** | PDF parse error | Reject import | "Corrupted or invalid AI file" |
| **Malformed Operators** | Invalid operator syntax | Skip operator, log warning, continue | "Malformed path operator at byte offset 12345" |
| **Coordinate Out of Range** | Value > ±1M pixels | Reject import | "Invalid coordinates detected (security constraint)" |

---

## Testing Strategy

### Unit Tests

**Location:** `packages/io_services/test/importers/ai_importer_test.dart`

#### Test Categories

1. **Tier-1 Operator Parsing**
   ```dart
   test('parses moveto operator', () {
     final events = parseOperators([
       PDFOperator(name: 'm', operands: [100.0, 200.0]),
     ]);
     expect(events, hasLength(1));
     expect(events.first, isA<CreatePathEvent>());
     expect((events.first as CreatePathEvent).startAnchor, Point(x: 100, y: pageHeight - 200));
   });
   ```

2. **Tier-2 Gradient Conversion**
   ```dart
   test('converts linear gradient to solid fill', () {
     final events = parseGradient(linearGradientDict);
     final pathEvent = events.whereType<CreatePathEvent>().first;
     expect(pathEvent.fillColor, '#FF5733'); // First color stop
   });
   ```

3. **Tier-3 Feature Warnings**
   ```dart
   test('logs warning for text objects', () {
     final result = importAIFile('fixtures/with_text.ai');
     expect(result.warnings, contains(
       predicate<ImportWarning>((w) =>
         w.featureType == 'text' &&
         w.severity == 'warning'
       ),
     ));
   });
   ```

4. **Coordinate System Conversion**
   ```dart
   test('flips Y coordinates correctly', () {
     final pageHeight = 792.0; // Letter size 11" * 72 DPI
     final pdfY = 692.0; // Near top in PDF space
     final wtY = flipY(pdfY, pageHeight);
     expect(wtY, 100.0); // Near top in WireTuner space
   });
   ```

### Integration Tests (Fixtures)

**Location:** `packages/io_services/test/fixtures/ai/`

#### Test Fixtures

| Fixture File | Content | Validation |
|-------------|---------|------------|
| `simple_rect.ai` | Single rectangle (PDF `re` operator) | 1 `CreateShapeEvent`, no warnings |
| `bezier_curves.ai` | Path with cubic Bezier curves | Multiple `AddAnchorEvent` with `anchorType: bezier`, handles verified |
| `with_gradient.ai` | Object with linear gradient | `fillColor` is solid, 1 gradient warning |
| `with_text.ai` | Text object + path | Text skipped, 1 warning, path imported |
| `multi_page.ai` | 3-page AI file | Only first page imported, info message |
| `cmyk_colors.ai` | CMYK stroke/fill | RGB conversion verified, info warning |

#### Assertion Examples

```dart
test('simple_rect.ai generates shape event', () async {
  final result = await aiImporter.importFromFile('test/fixtures/ai/simple_rect.ai');

  expect(result.events, hasLength(1));
  expect(result.events.first, isA<CreateShapeEvent>());

  final shapeEvent = result.events.first as CreateShapeEvent;
  expect(shapeEvent.shapeType, ShapeType.rectangle);
  expect(shapeEvent.parameters['width'], closeTo(200.0, 0.1));
  expect(shapeEvent.parameters['height'], closeTo(150.0, 0.1));

  expect(result.warnings, isEmpty);
});

test('with_gradient.ai logs gradient warning', () async {
  final result = await aiImporter.importFromFile('test/fixtures/ai/with_gradient.ai');

  expect(result.warnings, hasLength(1));
  expect(result.warnings.first.featureType, 'gradient');
  expect(result.warnings.first.severity, 'warning');
  expect(result.warnings.first.message, contains('converted to solid fill'));
});
```

---

## Implementation Roadmap

### Milestone 0.1 (Current)

- ✅ Tier-1 basic path operators (`m`, `l`, `c`, `h`, `re`)
- ✅ Tier-1 stroke/fill (RGB colors, opacity)
- ✅ Coordinate system conversion (PDF → WireTuner)
- ✅ Security validation (file size, coordinate bounds)
- ⚠️ Tier-2 gradients (convert to solid fill with warnings)
- ⚠️ Tier-2 CMYK colors (convert to RGB with info)
- ❌ Tier-3 text (skip with warnings)
- ❌ Tier-3 effects/filters (skip with warnings)

### Milestone 0.2 (Planned)

- ⬜ Tier-2 pattern fills (convert to solid)
- ⬜ Tier-2 compound paths (flatten to individual paths)
- ⬜ Tier-2 clipping masks (apply mask, import clipped result)
- ⬜ Improved gradient approximation (multi-stop gradients → multiple objects)

### Milestone 0.3 (Future)

- ⬜ Tier-1 gradient support (preserve gradient as first-class feature)
- ⬜ Tier-1 transform preservation (non-destructive transforms)
- ⬜ Tier-2 text-to-path conversion (automatic outlining)
- ⬜ Multi-page AI file support (import all artboards as layers)

---

## Cross-References

### Decision Documents

- [Architecture Decision 5](../../.codemachine/artifacts/architecture/06_Rationale_and_Future.md#decision-50ms-sampling) - Sampling rate (applies to imported path complexity)
- [Import Compatibility Specification](../specs/import_compatibility.md#adobe-illustrator-ai-import-compatibility) - High-level AI import strategy

### Technical Specifications

- [Vector Model Specification](vector_model.md#geometry-primitives) - Anchor point handle semantics (relative offsets)
- [Event Schema Reference](event_schema.md#event-type-examples) - Event payload validation rules
- [File Format Specification](../../api/file_format_spec.md#sqlite-schema-specification) - Target event storage format

### Implementation Files

- **AI Importer Service:** `packages/io_services/lib/src/importers/ai_importer.dart` - Main importer logic
- **Shared Validation:** `lib/infrastructure/import_export/import_validator.dart` - Security constraints
- **Path Event Definitions:** `lib/domain/events/path_events.dart` - Event constructors
- **Shape Event Definitions:** `lib/domain/events/object_events.dart` - Shape event constructors

### External Standards

- [PDF Reference 1.7](https://www.adobe.com/devnet/pdf/pdf_reference.html) - PDF graphics operators
- [Adobe Illustrator File Format](https://www.adobe.com/devnet/illustrator/sdk.html) - AI private data structure (limited public documentation)
- [ICC Color Profiles](https://www.color.org/icc_specs2.xalter) - CMYK → RGB conversion

---

## Document Maintenance

**Maintainer:** WireTuner Backend Team
**Review Cycle:** After each tier expansion or upon user feedback
**Next Review:** After completion of I5.T4 (AI Import Implementation)
**Feedback:** Submit issues to [WireTuner GitHub Repository](https://github.com/wiretuner/wiretuner/issues) with label `import:ai`

**Version History:**

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-11-09 | Initial feature matrix with Tier-1/2/3 classification, gradient conversion strategy, warning taxonomy |

---

**End of AI Import Feature Matrix**

*This document guides both development priorities and user expectations for Adobe Illustrator import fidelity.*
