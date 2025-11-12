# Import Warning Catalog

**Version:** 1.0
**Date:** 2025-11-11
**Status:** Active
**Document Type:** Reference Catalog

---

## Overview

This catalog documents all warnings that may be emitted during file import operations (AI, SVG, PDF). Each warning includes:

- **Warning Code**: Unique identifier for the warning type
- **Severity**: `info`, `warning`, or `error`
- **Feature Type**: Category of the unsupported or converted feature
- **Message Template**: User-facing description
- **Recommendation**: Suggested user action
- **Related Tier**: Tier-1/2/3 classification from AI Import Matrix

This catalog ensures consistent warning messages across import pipelines and helps users understand import fidelity limitations.

**Related Documents:**
- [AI Import Feature Matrix](ai_import_matrix.md) - Tier-1/2/3 feature classification
- [SVG Import Specification](../specs/import_compatibility.md#svg-import) - SVG import warnings
- [FR-021 Import Requirements](../../.codemachine/artifacts/plan/requirements.md) - Functional requirements

---

## Table of Contents

1. [Warning Severity Levels](#warning-severity-levels)
2. [AI Import Warnings](#ai-import-warnings)
   - [Tier-1 Warnings (Info)](#tier-1-warnings-info)
   - [Tier-2 Warnings (Conversion)](#tier-2-warnings-conversion)
   - [Tier-3 Warnings (Unsupported)](#tier-3-warnings-unsupported)
3. [SVG Import Warnings](#svg-import-warnings)
4. [Error Warnings (Security & Validation)](#error-warnings-security--validation)
5. [Usage Guidelines](#usage-guidelines)

---

## Warning Severity Levels

| Severity | Symbol | Usage | User Action Required | Display Priority |
|----------|--------|-------|----------------------|------------------|
| **info** | ℹ️ | Tier-2 conversions, non-critical degradation, informational notices | Optional: Review imported result | Low |
| **warning** | ⚠️ | Tier-3 feature detected, visual fidelity loss, feature skipped | Recommended: Adjust in WireTuner or re-export from source | Medium |
| **error** | ❌ | Malformed file, security violation, import failure | Required: Fix source file or contact support | High |

**Display Guidelines:**
- **Errors**: Block import and show immediately in dialog
- **Warnings**: Show summary count in dialog, detailed list in expandable section
- **Info**: Show count only, full details in collapsible "Import Notes" section

---

## AI Import Warnings

### Tier-1 Warnings (Info)

These warnings indicate successful conversions that may have minor visual differences.

#### `ai-private-data`

**Severity:** `info`
**Feature Type:** `ai-private-data`
**Tier:** Tier-3

**Message Template:**
```
AI import uses PDF layer only. Illustrator-specific features (effects, live paint,
symbols, etc.) are not supported in this version.
```

**Context:**
Adobe Illustrator files contain proprietary data streams beyond the PDF layer. This warning is shown for all AI imports to set user expectations.

**Recommendation:**
None required. This is informational only. Users should export critical effects as outlined paths before importing.

**Emitted:** Once per import operation

---

#### `bezier-variant-v`

**Severity:** `info`
**Feature Type:** `bezier-variant-v`
**Tier:** Tier-2

**Message Template:**
```
Bezier variant "v" operator converted to standard curve
```

**Context:**
PDF operator `v` (Bezier with control point 1 = current point) was converted to standard cubic Bezier with zero `handleOut` vector. Conversion is mathematically lossless.

**Recommendation:**
None required. Visual output is identical.

**Emitted:** Once per `v` operator encountered

**Related:** ai_import_matrix.md#tier-2-bezier-variants

---

#### `bezier-variant-y`

**Severity:** `info`
**Feature Type:** `bezier-variant-y`
**Tier:** Tier-2

**Message Template:**
```
Bezier variant "y" operator converted to standard curve
```

**Context:**
PDF operator `y` (Bezier with control point 2 = end point) was converted to standard cubic Bezier with zero `handleIn` vector. Conversion is mathematically lossless.

**Recommendation:**
None required. Visual output is identical.

**Emitted:** Once per `y` operator encountered

**Related:** ai_import_matrix.md#tier-2-bezier-variants

---

#### `cmyk-color`

**Severity:** `info`
**Feature Type:** `cmyk-color`
**Tier:** Tier-2

**Message Template:**
```
CMYK color CMYK({c}, {m}, {y}, {k}) converted to RGB {rgbHex}
```

**Example:**
```
CMYK color CMYK(0.2, 0.8, 0.0, 0.1) converted to RGB #CC33E6
```

**Context:**
CMYK colors were converted to RGB using standard ICC profile transformation. Screen appearance may differ from printed output.

**Recommendation:**
Review color accuracy for print-critical designs. Use RGB export from Illustrator if screen fidelity is required.

**Emitted:** Once per CMYK color definition

**Related:** ai_import_matrix.md#color-formats

---

#### `unsupported-operator`

**Severity:** `info`
**Feature Type:** `unsupported-operator`
**Tier:** Tier-3

**Message Template:**
```
Unsupported PDF operator: {operator}
```

**Example:**
```
Unsupported PDF operator: Tj (text rendering)
```

**Context:**
PDF operator was recognized but not implemented (e.g., text rendering operators `Tj`, `TJ`, advanced graphics state operators).

**Recommendation:**
If visual output is incomplete, convert unsupported features to outlines/paths in Illustrator before exporting.

**Emitted:** Once per unique unsupported operator

---

### Tier-2 Warnings (Conversion)

These warnings indicate feature conversions with potential visual differences.

#### `gradient-linear`

**Severity:** `warning`
**Feature Type:** `gradient-linear`
**Tier:** Tier-2

**Message Template:**
```
Linear gradient converted to solid fill ({firstStopColor}). Original gradient: {stopCount} stops.
```

**Example:**
```
Linear gradient converted to solid fill (#FF5733). Original gradient: 3 stops.
```

**Context:**
Linear gradients are not supported in WireTuner v0.1. Gradient was replaced with solid fill using the first color stop.

**Recommendation:**
Manually recreate gradient in WireTuner using multiple overlapping shapes with opacity. Gradient support is planned for Milestone 0.3.

**Emitted:** Once per gradient object

**Related:** ai_import_matrix.md#tier-2-gradients

---

#### `gradient-radial`

**Severity:** `warning`
**Feature Type:** `gradient-radial`
**Tier:** Tier-2

**Message Template:**
```
Radial gradient converted to solid fill ({firstStopColor}). Original gradient: {stopCount} stops.
```

**Example:**
```
Radial gradient converted to solid fill (#3366FF). Original gradient: 2 stops.
```

**Context:**
Radial gradients are not supported. Gradient was replaced with solid fill using the first color stop.

**Recommendation:**
Recreate gradient manually or wait for Milestone 0.3 gradient support.

**Emitted:** Once per gradient object

---

#### `pattern-fill`

**Severity:** `warning`
**Feature Type:** `pattern-fill`
**Tier:** Tier-3

**Message Template:**
```
Pattern fill converted to solid fill (#CCCCCC). Patterns are not supported.
```

**Context:**
PDF pattern fills are not supported. Replaced with neutral gray placeholder.

**Recommendation:**
Recreate pattern manually in WireTuner or export flattened artwork from Illustrator.

**Emitted:** Once per pattern fill

---

### Tier-3 Warnings (Unsupported)

These warnings indicate features that are completely skipped.

#### `text-skipped`

**Severity:** `warning`
**Feature Type:** `text`
**Tier:** Tier-3

**Message Template:**
```
Text object "{textContent}" skipped. Text is not supported. Convert text to outlines
in Illustrator before exporting.
```

**Example:**
```
Text object "Logo Text" skipped. Text is not supported. Convert text to outlines
in Illustrator before exporting.
```

**Context:**
Text objects (PDF operators `Tj`, `TJ`, `Td`) are not parsed. Font embedding and text rendering are out of scope for Milestone 0.1.

**Recommendation:**
**Required:** In Illustrator, select text and choose `Type > Create Outlines` to convert to vector paths, then re-export.

**Emitted:** Once per text object

**Related:** ai_import_matrix.md#text-and-typography

---

#### `effect-drop-shadow`

**Severity:** `warning`
**Feature Type:** `effect`
**Tier:** Tier-3

**Message Template:**
```
Drop shadow effect skipped on object {objectId}. Effects are not supported.
```

**Context:**
Illustrator effects (stored in AI private data) are not parsed. Only base object geometry is imported.

**Recommendation:**
Flatten effects in Illustrator (`Object > Expand Appearance`) before exporting.

**Emitted:** Once per effect instance

---

#### `effect-blur`

**Severity:** `warning`
**Feature Type:** `effect`
**Tier:** Tier-3

**Message Template:**
```
Gaussian blur effect skipped on object {objectId}. Effects are not supported.
```

**Context:**
Blur effects are not supported.

**Recommendation:**
Flatten effects or rasterize blurred objects before exporting.

**Emitted:** Once per blur effect

---

#### `blend-mode`

**Severity:** `warning`
**Feature Type:** `blend-mode`
**Tier:** Tier-3

**Message Template:**
```
Blend mode "{blendMode}" on object {objectId} converted to normal blending.
```

**Example:**
```
Blend mode "multiply" on object path_abc123 converted to normal blending.
```

**Context:**
Blend modes (PDF `/BM` operator) other than `normal` are not supported.

**Recommendation:**
Flatten transparency in Illustrator (`Object > Flatten Transparency`) if blend mode is critical.

**Emitted:** Once per non-normal blend mode

---

#### `clipping-mask`

**Severity:** `warning`
**Feature Type:** `clipping-mask`
**Tier:** Tier-3

**Message Template:**
```
Clipping mask on object {objectId} ignored. Clipped objects imported without mask.
```

**Context:**
Clipping masks are not supported. Clipped objects are imported in full.

**Recommendation:**
Flatten clipping masks in Illustrator (`Object > Clipping Mask > Release`, then manually delete unwanted areas).

**Emitted:** Once per clipping mask

---

#### `symbol-instance`

**Severity:** `warning`
**Feature Type:** `symbol`
**Tier:** Tier-3

**Message Template:**
```
Symbol instance "{symbolName}" skipped. Symbols are not supported.
```

**Context:**
Illustrator symbol instances are stored in AI private data and not parsed.

**Recommendation:**
Expand symbols in Illustrator (`Object > Expand Symbol`) before exporting.

**Emitted:** Once per symbol instance

---

#### `live-paint-group`

**Severity:** `warning`
**Feature Type:** `live-paint`
**Tier:** Tier-3

**Message Template:**
```
Live Paint Group ({objectCount} objects) converted to individual paths. Live paint
behavior not preserved.
```

**Example:**
```
Live Paint Group (5 objects) converted to individual paths. Live paint behavior
not preserved.
```

**Context:**
Live Paint groups are proprietary AI features not stored in PDF layer.

**Recommendation:**
Expand Live Paint groups in Illustrator (`Object > Expand`) before exporting.

**Emitted:** Once per Live Paint group

---

#### `compound-path`

**Severity:** `warning`
**Feature Type:** `compound-path`
**Tier:** Tier-3

**Message Template:**
```
Compound path flattened to {pathCount} individual paths. Compound path relationships
not preserved.
```

**Example:**
```
Compound path flattened to 3 individual paths. Compound path relationships not preserved.
```

**Context:**
Compound paths (holes, boolean operations) are flattened during import.

**Recommendation:**
If compound path structure is critical, manually recreate using WireTuner's boolean operations (planned for Milestone 0.2).

**Emitted:** Once per compound path

---

## Error Warnings (Security & Validation)

### `file-size-exceeded`

**Severity:** `error`
**Feature Type:** `validation`
**Tier:** N/A

**Message Template:**
```
File size ({sizeBytes} bytes) exceeds maximum ({maxSizeBytes} bytes). Maximum
supported file size is {maxSizeMB} MB.
```

**Example:**
```
File size (15728640 bytes) exceeds maximum (10485760 bytes). Maximum supported
file size is 10 MB.
```

**Context:**
Security constraint to prevent memory exhaustion attacks.

**Recommendation:**
**Required:** Reduce file complexity, remove unused layers, or split into multiple files.

**Action:** Import is blocked. User must fix source file.

**Related:** FR-021 security requirements

---

### `invalid-pdf-structure`

**Severity:** `error`
**Feature Type:** `validation`
**Tier:** N/A

**Message Template:**
```
Invalid AI file: not a valid PDF structure. File may be corrupted.
```

**Context:**
File does not start with PDF header `%PDF-` or has corrupted structure.

**Recommendation:**
**Required:** Verify file integrity, re-export from Illustrator, or try opening in Illustrator to repair.

**Action:** Import is blocked.

---

### `coordinate-out-of-range`

**Severity:** `error`
**Feature Type:** `validation`
**Tier:** N/A

**Message Template:**
```
Invalid {coordinateName}: {value}. Coordinate values must be within ±{maxCoordinate} range.
```

**Example:**
```
Invalid x coordinate: 2000000.5. Coordinate values must be within ±1000000 range.
```

**Context:**
Security constraint to prevent coordinate overflow attacks.

**Recommendation:**
**Required:** Fix malformed coordinates in source file or contact support.

**Action:** Import is blocked.

---

### `malformed-operator`

**Severity:** `warning`
**Feature Type:** `malformed-operator`
**Tier:** N/A

**Message Template:**
```
{operatorName} operator requires {requiredOperands} operands, found {foundOperands}.
Operator skipped.
```

**Example:**
```
curveto operator requires 6 operands, found 4. Operator skipped.
```

**Context:**
PDF operator has incorrect number of operands. Likely indicates corrupted content stream or malformed export.

**Recommendation:**
Review imported result for missing geometry. Re-export from Illustrator if critical paths are missing.

**Action:** Operator is skipped, import continues.

---

### `malformed-path`

**Severity:** `warning`
**Feature Type:** `malformed-path`
**Tier:** N/A

**Message Template:**
```
{operatorName} operator without preceding moveto. Path construction error.
```

**Example:**
```
lineto operator without preceding moveto. Path construction error.
```

**Context:**
Path operator (lineto, curveto) appears without a preceding moveto to establish starting point.

**Recommendation:**
Review imported paths. Re-export if paths are incomplete.

**Action:** Operator is skipped, import continues.

---

### `operator-error`

**Severity:** `warning`
**Feature Type:** `operator-error`
**Tier:** N/A

**Message Template:**
```
Error processing operator "{operator}": {errorMessage}
```

**Example:**
```
Error processing operator "c": NumberFormatException: Invalid double
```

**Context:**
Unexpected error during operator processing. Likely indicates malformed operand values.

**Recommendation:**
Review imported result. Contact support if issue persists with valid AI files.

**Action:** Operator is skipped, import continues.

---

## SVG Import Warnings

### `svg-transform-approximation`

**Severity:** `info`
**Feature Type:** `svg-transform`
**Tier:** Tier-2

**Message Template:**
```
SVG transform matrix on element {elementId} approximated. Non-uniform scaling may
have slight rounding differences.
```

**Context:**
SVG transform matrices are applied to coordinates during import. Floating-point rounding may introduce sub-pixel differences.

**Recommendation:**
None required unless precision-critical.

**Emitted:** Once per transformed element

---

### `svg-filter-skipped`

**Severity:** `warning`
**Feature Type:** `svg-filter`
**Tier:** Tier-3

**Message Template:**
```
SVG filter "{filterId}" skipped. Filters are not supported.
```

**Example:**
```
SVG filter "blur-effect-1" skipped. Filters are not supported.
```

**Context:**
SVG filter effects (`<filter>`, `<feGaussianBlur>`, etc.) are not parsed.

**Recommendation:**
Rasterize filtered elements before exporting to SVG.

**Emitted:** Once per filter

---

## Usage Guidelines

### For Developers

**Emitting Warnings:**
```dart
_addWarning(
  severity: 'warning',
  featureType: 'gradient-linear',
  message: 'Linear gradient converted to solid fill (#FF5733). Original gradient: 3 stops.',
  objectId: 'path_abc123',  // Optional
  pageNumber: 1,            // Optional (for multi-page AI)
);
```

**Warning Collection:**
Warnings are accumulated in `AIImportResult.warnings` and returned to the caller for display in UI.

### For UI Developers

**Display Priority:**
1. Show error count prominently (red badge)
2. Show warning count (amber badge)
3. Show info count in collapsible section

**Example Dialog:**
```
Import Completed with Warnings

Successfully imported 47 objects with 3 warnings:

⚠️ 2 gradients converted to solid fills
   Objects: "Background Shape", "Button Fill"
   Recommendation: Recreate gradients manually or wait for v0.3

⚠️ 1 text object skipped
   Object: "Logo Text"
   Recommendation: Convert text to outlines in Illustrator

[Show Details] [Dismiss]
```

### For Documentation

**Linking to Warnings:**
Use feature type as anchor:
```markdown
See [gradient-linear warning](import_warning_catalog.md#gradient-linear) for details.
```

---

## Document Maintenance

**Maintainer:** WireTuner Backend Team
**Review Cycle:** After each import feature expansion
**Next Review:** After I5.T3 (AI Import) completion
**Feedback:** Submit issues to [WireTuner GitHub](https://github.com/wiretuner/wiretuner/issues) with label `import:warnings`

**Version History:**

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-11-11 | Initial catalog with AI import warnings, SVG warnings, error codes |

---

**End of Import Warning Catalog**

*This catalog ensures consistent, actionable feedback during file import operations.*
