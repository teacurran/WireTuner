# SVG Export Reference

**Version:** Tier-2 (Iteration 5)
**Status:** Active
**Last Updated:** 2025-11-09

---

## Overview

The SVG export feature converts WireTuner documents to industry-standard SVG 1.1 format. This enables interoperability with other vector graphics applications and web browsers.

### Key Features

- **Vector Path Export**: Converts WireTuner paths to SVG path elements with full Bezier curve support
- **Shape Conversion**: Automatically converts shapes (rectangles, ellipses) to SVG paths
- **Layer Organization**: Exports layers as SVG group elements with proper hierarchy
- **Metadata Embedding**: Includes document title and creator information in RDF format
- **Coordinate Precision**: Maintains 2 decimal place precision (0.01 pixel accuracy)
- **XML Well-formedness**: Generates valid, parseable SVG 1.1 XML

### Tier-2 Capabilities

The current implementation (Iteration 5) includes infrastructure for:

- **Gradient Support**: Linear and radial gradient definitions (API ready, full integration pending)
- **Clipping Masks**: Clip path definitions and references (API ready, full integration pending)
- **Transform Attributes**: Matrix transforms for object positioning (API ready)
- **Style Properties**: Stroke, fill, opacity, and line styles (API ready)
- **Compound Paths**: Multiple segments with mixed line and Bezier curves

---

## Usage

### Basic Export

```dart
import 'package:wiretuner/infrastructure/export/svg_exporter.dart';

final exporter = SvgExporter();
await exporter.exportToFile(document, '/path/to/output.svg');
```

### Programmatic SVG Generation

```dart
// Generate SVG string without writing to file
final svgContent = exporter.generateSvg(document);
print(svgContent);
```

---

## Architecture

### Components

```
┌─────────────────────────────────────────────────┐
│              SvgExporter                        │
│  - Document orchestration                       │
│  - Bounds calculation                           │
│  - Path conversion (pathToSvgPathData)         │
└───────────────────┬─────────────────────────────┘
                    │ uses
                    ▼
┌─────────────────────────────────────────────────┐
│              SvgWriter                          │
│  - XML generation                               │
│  - Element writing (header, paths, groups)     │
│  - Gradient/clipPath definitions               │
│  - XML escaping                                 │
└─────────────────────────────────────────────────┘
```

### File Locations

- **Exporter**: `lib/infrastructure/export/svg_exporter.dart`
- **Writer**: `lib/infrastructure/export/svg_writer.dart`
- **Unit Tests**: `test/unit/svg_exporter_test.dart`
- **Integration Tests**: `test/integration/svg_export_test.dart`

---

## Path Conversion

### Coordinate System

WireTuner uses screen coordinates (y increases downward), which matches SVG's default coordinate system. No transformation is needed during export.

### Handle Coordinates

Anchor handles are stored as **relative offsets** from the anchor position. The exporter converts these to absolute coordinates for SVG:

```dart
// Internal representation
final anchor = AnchorPoint(
  position: Point(x: 100, y: 100),
  handleOut: Point(x: 20, y: 0),  // Relative offset
);

// SVG output
// Control point = anchor.position + anchor.handleOut = (120, 100)
// Output: "M 100.00 100.00 C 120.00 100.00, ..."
```

### Segment Types

| WireTuner Segment | SVG Command | Example |
|-------------------|-------------|---------|
| Line | `L x y` | `L 100.00 100.00` |
| Bezier Curve | `C x1 y1, x2 y2, x y` | `C 50.00 0.00, 50.00 100.00, 100.00 100.00` |
| Closed Path | `Z` | `M 0 0 L 100 0 L 100 100 Z` |

---

## Supported Features

### Paths

- ✅ Line segments
- ✅ Cubic Bezier curves
- ✅ Closed paths (Z command)
- ✅ Compound paths (multiple segments)
- ✅ Empty paths (gracefully skipped)

### Shapes

- ✅ Rectangles (converted to paths)
- ✅ Ellipses (converted to paths)
- ✅ Automatic path conversion via `Shape.toPath()`

### Layers

- ✅ Layer groups (`<g>` elements)
- ✅ Layer IDs preserved
- ✅ Visibility handling (invisible layers skipped)
- ✅ Nested layer hierarchy

### Metadata

- ✅ Document title (Dublin Core `dc:title`)
- ✅ Creator attribution (Dublin Core `dc:creator`)
- ✅ Format identification (`dc:format`)
- ✅ RDF namespace compliance

### Advanced Features (API Ready)

- 🔧 Linear gradients (`writeLinearGradient`)
- 🔧 Radial gradients (`writeRadialGradient`)
- 🔧 Clipping paths (`startClipPath`, `endClipPath`)
- 🔧 Transform matrices (`transform` attribute)
- 🔧 Stroke styles (width, cap, join, dash arrays)
- 🔧 Fill and stroke opacity

**Legend:** ✅ Fully implemented | 🔧 API ready, full integration pending

---

## Known Limitations

### Current Tier-2 Limitations

1. **No Style Export (Current Limitation)**
   - All paths currently export with default styles:
     - Stroke: black (`stroke="black"`)
     - Stroke width: 1px (`stroke-width="1"`)
     - Fill: none (`fill="none"`)
   - Reason: VectorObject does not yet store style properties (fill color, stroke color, opacity, etc.)
   - Workaround: Edit SVG manually or apply styles in external editor
   - Roadmap: Style system planned for Iteration 3
   - **Infrastructure Status**: ✅ API ready in SvgWriter (opacity, strokeOpacity, fillOpacity parameters)

2. **No Gradient Export (Current Limitation)**
   - Infrastructure exists (`SvgWriter.writeLinearGradient`, `writeRadialGradient`, `startDefs`, `endDefs`)
   - VectorObject does not yet store gradient definitions (linear/radial gradient stops, colors, positions)
   - Roadmap: Full gradient support in future iterations when domain model includes gradient data
   - **Infrastructure Status**: ✅ API ready and tested in SvgWriter

3. **No Clipping Mask Export (Current Limitation)**
   - Infrastructure exists (`SvgWriter.startClipPath`, `endClipPath`, `clipPath` parameter on paths)
   - Clipping relationships not yet stored in document model (no parent-child clipping relationships)
   - Roadmap: Clipping mask support in future iterations when domain model includes clipping data
   - **Infrastructure Status**: ✅ API ready and tested in SvgWriter

4. **No Filter Effects**
   - Drop shadows, blurs, and other SVG filters are not supported
   - Reason: Filter system not yet designed
   - Roadmap: Planned for advanced rendering iterations

5. **No Blend Modes**
   - All objects use normal blending (`mix-blend-mode: normal`)
   - SVG supports multiply, screen, overlay, etc., but WireTuner does not track blend modes
   - Roadmap: Planned for advanced rendering iterations

6. **No Text Export**
   - Text elements are not yet implemented in WireTuner
   - Text-to-path conversion will be supported when text features are added
   - Roadmap: Text system planned for future iterations

7. **No Pattern Fills**
   - Pattern fills (repeating images/paths) are not supported
   - Roadmap: Planned for advanced styling iterations

8. **Limited Transform Export**
   - Object transforms (rotation, scale, skew) are not yet stored
   - Infrastructure exists (`transform` attribute parameter)
   - Roadmap: Transform system planned for future iterations

### Performance Characteristics

| Metric | Specification | Actual |
|--------|---------------|--------|
| Export Speed | < 5 seconds for 5000 objects | ✅ Passes |
| File Size | ~150 bytes per simple path | ✅ Efficient |
| Memory Usage | Linear with object count | ✅ Scalable |
| Coordinate Precision | 2 decimal places | ✅ 0.01px accuracy |

---

## Validation

### W3C Validation

To validate exported SVG files with the W3C validator:

1. **Install the validator:**
   ```bash
   npm install -g vnu-jar
   ```

2. **Export an SVG file from WireTuner**

3. **Run validation:**
   ```bash
   vnu --svg output.svg
   ```

4. **Expected result:** No errors, valid SVG 1.1 output

### Manual Testing Checklist

- [ ] SVG opens correctly in web browsers (Chrome, Firefox, Safari)
- [ ] SVG opens correctly in vector editors (Inkscape, Adobe Illustrator, Figma)
- [ ] Paths render with correct geometry
- [ ] Layers are organized correctly
- [ ] Metadata is visible in document properties
- [ ] File size is reasonable (< 1MB for typical documents)
- [ ] No XML parsing errors

---

## Examples

### Example 1: Simple Line Export

**Input:**
```dart
final path = Path.line(
  start: Point(x: 10, y: 20),
  end: Point(x: 110, y: 70),
);
```

**Output SVG:**
```xml
<path id="path-1" d="M 10.00 20.00 L 110.00 70.00" stroke="black" stroke-width="1" fill="none"/>
```

### Example 2: Bezier Curve Export

**Input:**
```dart
final path = Path(
  anchors: [
    AnchorPoint(
      position: Point(x: 0, y: 0),
      handleOut: Point(x: 50, y: 0),
    ),
    AnchorPoint(
      position: Point(x: 100, y: 100),
      handleIn: Point(x: -50, y: 0),
    ),
  ],
  segments: [Segment.bezier(startIndex: 0, endIndex: 1)],
);
```

**Output SVG:**
```xml
<path id="path-2" d="M 0.00 0.00 C 50.00 0.00, 50.00 100.00, 100.00 100.00" stroke="black" stroke-width="1" fill="none"/>
```

### Example 3: Closed Path (Triangle)

**Input:**
```dart
final path = Path.fromAnchors(
  anchors: [
    AnchorPoint.corner(Point(x: 0, y: 0)),
    AnchorPoint.corner(Point(x: 100, y: 0)),
    AnchorPoint.corner(Point(x: 50, y: 86.6)),
  ],
  closed: true,
);
```

**Output SVG:**
```xml
<path id="path-3" d="M 0.00 0.00 L 100.00 0.00 L 50.00 86.60 Z" stroke="black" stroke-width="1" fill="none"/>
```

### Example 4: Complete Document

**Input:**
```dart
final document = Document(
  id: 'doc-1',
  title: 'My Drawing',
  layers: [
    Layer(
      id: 'layer-1',
      name: 'Background',
      objects: [
        VectorObject.path(
          id: 'path-1',
          path: Path.line(start: Point(x: 0, y: 0), end: Point(x: 100, y: 100)),
        ),
      ],
    ),
  ],
);
```

**Output SVG:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" version="1.1" viewBox="0.00 0.00 100.00 100.00" width="100.00" height="100.00">
  <metadata>
    <rdf:RDF
      xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
      xmlns:dc="http://purl.org/dc/elements/1.1/">
      <rdf:Description rdf:about="">
        <dc:title>My Drawing</dc:title>
        <dc:creator>WireTuner 0.1</dc:creator>
        <dc:format>image/svg+xml</dc:format>
      </rdf:Description>
    </rdf:RDF>
  </metadata>
  <g id="layer-1" opacity="1">
    <path id="path-1" d="M 0.00 0.00 L 100.00 100.00" stroke="black" stroke-width="1" fill="none"/>
  </g>
</svg>
```

---

## API Reference

### SvgExporter

#### `exportToFile(document, filePath)`

Exports a document to an SVG file.

**Parameters:**
- `document` (Document): The document to export
- `filePath` (String): Absolute path to the output SVG file

**Returns:** `Future<void>`

**Throws:**
- `FileSystemException` if file cannot be written
- `Exception` for other export errors

**Example:**
```dart
final exporter = SvgExporter();
await exporter.exportToFile(document, '/Users/name/Desktop/drawing.svg');
```

#### `generateSvg(document)`

Generates SVG XML content from a document without writing to a file.

**Parameters:**
- `document` (Document): The document to export

**Returns:** `String` - The complete SVG document as an XML string

**Example:**
```dart
final svgContent = exporter.generateSvg(document);
print(svgContent);
```

#### `pathToSvgPathData(path)`

Converts a WireTuner Path to SVG path data string.

**Parameters:**
- `path` (Path): The path to convert

**Returns:** `String` - SVG path data (d attribute value)

**Example:**
```dart
final path = Path.line(start: Point(x: 0, y: 0), end: Point(x: 100, y: 100));
final svgData = exporter.pathToSvgPathData(path);
// Result: "M 0.00 0.00 L 100.00 100.00"
```

### SvgWriter

#### `writeHeader(viewBox)`

Writes the XML declaration and SVG root element.

#### `writeMetadata(title)`

Writes RDF metadata section with document information.

#### `startGroup(id, opacity)`

Starts a group element (SVG `<g>` tag).

#### `endGroup()`

Ends the current group element.

#### `writePath({id, pathData, ...})`

Writes a path element with styling.

**Optional Parameters:**
- `opacity` (double): Opacity value (0.0 to 1.0)
- `strokeOpacity` (double): Stroke-specific opacity
- `fillOpacity` (double): Fill-specific opacity
- `strokeDasharray` (String): Dash pattern
- `strokeLinecap` (String): Line cap style
- `strokeLinejoin` (String): Line join style
- `transform` (String): SVG transform attribute
- `clipPath` (String): Reference to a clip path

#### `startDefs()`

Starts a defs section for reusable resources.

#### `endDefs()`

Ends the defs section.

#### `writeLinearGradient({...})`

Writes a linear gradient definition.

#### `writeRadialGradient({...})`

Writes a radial gradient definition.

#### `startClipPath(id)`

Starts a clipPath definition.

#### `endClipPath()`

Ends a clipPath definition.

#### `writeFooter()`

Writes the closing SVG root element tag.

---

## Testing

### Unit Tests

Run unit tests:
```bash
flutter test test/unit/svg_exporter_test.dart
```

**Coverage:**
- Path data conversion (line, Bezier, closed paths)
- Document structure generation
- Metadata embedding
- XML escaping
- Layer visibility handling
- Bounds calculation
- Performance benchmarks (5000 objects < 5 seconds)

### Integration Tests

Run integration tests:
```bash
flutter test test/integration/svg_export_test.dart
```

**Coverage:**
- File I/O operations
- XML well-formedness validation
- Multi-layer document export
- Coordinate precision verification
- Large document performance
- W3C validation readiness

---

## Future Enhancements

### Iteration 6+

- [ ] Full style export (stroke, fill, opacity)
- [ ] Gradient export (linear and radial)
- [ ] Clipping mask export
- [ ] Transform matrix export (rotation, scale, skew)
- [ ] Pattern fill support
- [ ] Filter effects (drop shadows, blurs)
- [ ] Blend mode export
- [ ] Text export (when text features are implemented)
- [ ] SVG animation export
- [ ] Compression (SVGZ format)

---

## Troubleshooting

### Issue: SVG file is too large

**Solution:** Check for unnecessary precision or duplicate objects. Consider:
- Reducing coordinate precision (currently 2 decimals)
- Simplifying paths with fewer anchors
- Merging redundant layers

### Issue: Paths render incorrectly in external editors

**Possible Causes:**
- Handle coordinate conversion errors
- Incorrect segment types
- ViewBox mismatch

**Debugging Steps:**
1. Validate SVG with W3C validator
2. Inspect path data in XML
3. Compare bounds calculation with actual geometry
4. Check for unclosed paths or invalid indices

### Issue: Invisible layers appear in export

**Solution:** This is a bug. Invisible layers should be skipped. File an issue with:
- Document structure
- Layer visibility settings
- Exported SVG content

---

## References

- [SVG 1.1 Specification](https://www.w3.org/TR/SVG11/)
- [SVG Path Commands](https://developer.mozilla.org/en-US/docs/Web/SVG/Tutorial/Paths)
- [W3C Validator](https://validator.w3.org/)
- [Dublin Core Metadata](https://www.dublincore.org/specifications/dublin-core/dcmi-terms/)

---

**Maintained by:** WireTuner Development Team
**Last Review:** Iteration 5 (2025-11-09)
