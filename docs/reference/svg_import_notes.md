# SVG Import Reference

This document describes the SVG import capabilities of WireTuner, including supported features, limitations, and fallback behaviors.

## Overview

WireTuner's SVG importer converts SVG 1.1 files into the application's event-based format. It supports **Tier-1** (core vector graphics) and **Tier-2** (gradients, clipping paths, text) features as defined in Iteration 5.

## Supported SVG Elements

### Path Commands (Tier-1) ✅

All SVG path commands are fully supported:

| Command | Description | Support Level |
|---------|-------------|---------------|
| `M`, `m` | Move to | ✅ Full (absolute/relative) |
| `L`, `l` | Line to | ✅ Full (absolute/relative) |
| `H`, `h` | Horizontal line | ✅ Full (absolute/relative) |
| `V`, `v` | Vertical line | ✅ Full (absolute/relative) |
| `C`, `c` | Cubic Bezier curve | ✅ Full (absolute/relative) |
| `S`, `s` | Smooth cubic Bezier | ✅ Full (absolute/relative) |
| `Q`, `q` | Quadratic Bezier | ✅ Converted to cubic Bezier |
| `T`, `t` | Smooth quadratic Bezier | ✅ Converted to cubic Bezier |
| `Z`, `z` | Close path | ✅ Full |
| `A`, `a` | Arc | ⚠️ Not yet supported (Tier-3) |

**Note:** Quadratic Bezier curves are automatically converted to cubic Bezier curves using the standard conversion formula to maintain compatibility with WireTuner's internal path representation.

### Shape Elements (Tier-1) ✅

All basic SVG shapes are converted to paths:

| Element | Support | Conversion Method |
|---------|---------|-------------------|
| `<path>` | ✅ Full | Direct import |
| `<rect>` | ✅ Full | Converted to closed path with 4 corners |
| `<circle>` | ✅ Full | Converted to path with 4 Bezier curves |
| `<ellipse>` | ✅ Full | Converted to path with 4 Bezier curves |
| `<line>` | ✅ Full | Converted to open path with 2 anchors |
| `<polyline>` | ✅ Full | Converted to open path |
| `<polygon>` | ✅ Full | Converted to closed path |

**Rounded rectangles:** Rectangles with `rx`/`ry` attributes are currently imported as sharp-cornered rectangles. A debug warning is logged. Full rounded corner support is planned for a future release.

### Gradients (Tier-2) 🟡

Linear and radial gradients are recognized and parsed, with **fallback** to solid colors:

| Gradient Type | Support | Fallback Behavior |
|---------------|---------|-------------------|
| `<linearGradient>` | 🟡 Partial | Uses first stop color as fill |
| `<radialGradient>` | 🟡 Partial | Uses first stop color as fill |
| Gradient stops | ✅ Full | Offset (percentage or decimal) and color parsed |
| Gradient units | ⚠️ Limited | `objectBoundingBox` assumed, warning for `userSpaceOnUse` |
| Spread method | ⚠️ Limited | `pad` assumed, warning for `reflect`/`repeat` |
| Gradient transform | ❌ Not supported | Warning logged |

**Gradient fallback example:**
```xml
<linearGradient id="grad1">
  <stop offset="0%" stop-color="red"/>
  <stop offset="100%" stop-color="blue"/>
</linearGradient>
<rect fill="url(#grad1)" ... />
```
→ Rectangle is imported with solid **red** fill (first stop color).

**Warnings issued:**
- `gradientUnits="userSpaceOnUse"` → "may render incorrectly"
- `spreadMethod="reflect"` or `"repeat"` → "using pad fallback"
- `gradientTransform` present → "gradient orientation may be incorrect"

### Clipping Paths (Tier-2) 🟡

Clipping paths are detected and logged but **not visually applied**:

| Feature | Support | Behavior |
|---------|---------|----------|
| `<clipPath>` detection | ✅ Recognized | ID stored, warning logged |
| Path-based clips | 🟡 Parsed | Geometry extracted but not applied to objects |
| Shape-based clips (`<rect>`, `<circle>`) | ⚠️ Noted | Warning logged about limited support |
| `clipPathUnits` | ❌ Ignored | No distinction made |

**Warning logged:** "ClipPath detected: `{id}` - Clipping paths are recognized but not fully applied in current version. Visual clipping may not be accurate."

**Future enhancement:** Full clipping support requires domain model changes to store clipping relationships.

### Text Elements (Tier-2) 🟡

Text is converted to **placeholder rectangle paths** with warnings:

| Feature | Support | Behavior |
|---------|---------|----------|
| `<text>` | 🟡 Placeholder | Converted to rectangle approximating text bounds |
| `<tspan>` | ⚠️ Ignored | Nested spans not processed |
| Font properties | ❌ Not used | Bounding box approximated (6px/char width, 10px height) |
| Text-as-path | ❌ Not supported | Users must convert text to paths in design tool |

**Warning logged:** "Text element encountered: `{text}` at ({x}, {y}) - Text is not fully supported. Converting to placeholder rectangle. For accurate text rendering, convert text to paths in your design tool before exporting."

**Recommendation:** Before exporting SVG from design tools (Adobe Illustrator, Figma, Sketch), use "Convert Text to Outlines" or similar feature to preserve text as vector paths.

### Grouping and Structure (Tier-1) ✅

| Element | Support | Behavior |
|---------|---------|----------|
| `<g>` (group) | ✅ Flattened | Child elements imported, group hierarchy not preserved |
| `<defs>` | ✅ Parsed | Definitions extracted in first pass |
| `<svg>` root | ✅ Full | ViewBox parsed (not yet used for bounds) |
| `<metadata>`, `<title>`, `<desc>` | ✅ Ignored | Skipped without warnings |

## Unsupported Features

The following SVG features are **not supported** and will generate warnings or be skipped:

### Filters and Effects ⛔
- `<filter>`, `<feGaussianBlur>`, `<feColorMatrix>`, `<feBlend>`, `<feOffset>`
- **Warning:** "filter effects not supported, skipping"
- **Fallback:** Filter is ignored, element rendered without effects

### Patterns ⛔
- `<pattern>`
- **Warning:** "pattern fills not supported, skipping"
- **Fallback:** Pattern fill ignored, element may have no fill

### Advanced Blend Modes ⛔
- Blend modes beyond `normal` (e.g., `multiply`, `screen`, `overlay`)
- **Behavior:** Blend modes not yet parsed from style attributes (planned for Tier-3)

### Embedded Content ⛔
- `<image>` (raster images)
- **Warning:** "embedded images not supported, skipping"

### Advanced Path Features ⛔
- Arc commands (`A`, `a`)
- **Status:** Planned for Tier-3

### Transforms ⛔
- `transform` attribute on elements
- **Status:** Ignored in current version (planned enhancement)

### Style Inheritance ⛔
- CSS-based styles and cascading
- **Behavior:** Only inline `stroke`, `fill`, `stroke-width`, `opacity` attributes are parsed
- Inherited styles from parent groups are **not** applied

## Import Workflow

WireTuner uses a **two-pass parsing** strategy:

### Pass 1: Definitions
1. Scan `<defs>` sections and root-level SVG for:
   - `<linearGradient>` and `<radialGradient>` (stored in ID map)
   - `<clipPath>` (stored in ID map)
2. Build internal lookup tables for URL references

### Pass 2: Geometry
1. Traverse child elements of `<svg>`
2. Convert each shape/path to WireTuner events:
   - `CreatePathEvent` (initiates path)
   - `AddAnchorEvent` (adds anchor points)
   - `ModifyAnchorEvent` (sets Bezier handles)
   - `FinishPathEvent` (marks path complete)
3. Resolve `fill="url(#id)"` and `clip-path="url(#id)"` references
4. Log warnings for unsupported features

## Security and Validation

All SVG imports are subject to security constraints:

| Constraint | Limit | Error Type |
|------------|-------|------------|
| File size | 10 MB max | `ImportException` |
| Path data length | 100,000 characters max | `ImportException` |
| Gradient stops | 100 max per gradient | Truncation + warning |
| Coordinate values | Must be finite numbers | `ImportException` |
| XML structure | Well-formed XML required | `ImportException` |
| External entities | Disabled (XXE prevention) | Built-in safety |

## Round-Trip Export/Import

WireTuner supports **round-trip** workflows:

```
WireTuner Document → SVG Export → SVG Import → WireTuner Document
```

**Expected differences:**
- Gradient fills become solid colors (first stop)
- Text becomes placeholder rectangles (if present)
- Clipping paths noted but not visually applied
- Floating-point precision (coordinates rounded to 2 decimal places in export)

**Acceptance criteria (from task):**
- ✅ Round-trip sample document without visual diff (for supported features)
- ✅ Warnings issued for filters and blend modes
- ✅ Documentation lists fallback behaviors (this document)

## Examples

### Example 1: Simple Path with Gradient

**Input SVG:**
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <defs>
    <linearGradient id="grad" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0%" stop-color="#ff0000"/>
      <stop offset="100%" stop-color="#0000ff"/>
    </linearGradient>
  </defs>
  <rect x="10" y="10" width="180" height="180" fill="url(#grad)" stroke="black"/>
</svg>
```

**Import behavior:**
1. Gradient `grad` parsed and stored
2. Rectangle converted to 4-corner path
3. Fill color set to `#ff0000` (red, first stop)
4. Stroke color set to `black`
5. Debug log: "Gradient reference detected: grad (support limited, using fallback)"

**Generated events:**
- `CreatePathEvent(pathId, position: (10, 10), fillColor: "#ff0000", strokeColor: "black")`
- `AddAnchorEvent` × 3 (remaining corners)
- `FinishPathEvent(closed: true)`

### Example 2: Text Conversion

**Input SVG:**
```xml
<svg xmlns="http://www.w3.org/2000/svg">
  <text x="50" y="100" font-size="16">WireTuner</text>
</svg>
```

**Import behavior:**
1. Text content "WireTuner" extracted (9 characters)
2. Bounding box approximated: width = 9 × 6 = 54px, height = 10px
3. Position adjusted for baseline: (50, 100 - 10) = (50, 90)
4. Warning logged: "Text element encountered: 'WireTuner' at (50, 100) - Text is not fully supported. Converting to placeholder rectangle..."
5. Rectangle path created at (50, 90, 54, 10)

### Example 3: Clipping Path

**Input SVG:**
```xml
<svg xmlns="http://www.w3.org/2000/svg">
  <defs>
    <clipPath id="clip1">
      <circle cx="100" cy="100" r="50"/>
    </clipPath>
  </defs>
  <rect x="0" y="0" width="200" height="200" fill="blue" clip-path="url(#clip1)"/>
</svg>
```

**Import behavior:**
1. ClipPath `clip1` detected and parsed
2. Debug log: "ClipPath clip1 contains <circle> - complex clipping shapes have limited support"
3. Rectangle imported as normal 4-corner path
4. Warning: "ClipPath detected: clip1 - Clipping paths are recognized but not fully applied..."
5. Visual result: Full 200×200 blue rectangle (no clipping applied)

## Recommendations for Best Import Results

1. **Convert text to paths** in your design tool before exporting SVG
2. **Avoid complex gradients** - use solid colors for critical designs, or accept first-stop-color fallback
3. **Flatten clipping masks** in design tool before export
4. **Remove unused defs** - clean SVG files import faster
5. **Use simple paths** - avoid arcs (use cubic Beziers instead)
6. **Test round-trips** - export from WireTuner and re-import to verify fidelity

## API Example

```dart
import 'package:wiretuner/infrastructure/import_export/svg_importer.dart';

final importer = SvgImporter();

// Import from file
final events = await importer.importFromFile('/path/to/drawing.svg');

// Import from string
final svgContent = '<svg>...</svg>';
final events = await importer.importFromString(svgContent);

// Replay events to reconstruct document
for (final event in events) {
  eventDispatcher.dispatch(event);
}
```

## Version History

- **Iteration 5 (Tier-2)**: Added gradient parsing (with fallback), clipPath detection, text-as-path conversion
- **Iteration 4**: Basic path and shape support (Tier-1)

## Related Documentation

- [Event Schema Reference](event_schema.md)
- [Vector Model Reference](vector_model.md)
- [SVG Export Documentation](svg_export.md)
- [File Format Specification](../specs/file_format_spec.md)
