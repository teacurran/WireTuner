# ADR-0005: Multi-Artboard Architecture and Per-Artboard State Isolation

**Status:** Accepted
**Date:** 2025-11-11
**Related:** FR-029–FR-045, I4.T1, ADR-003 (Event Sourcing)
**Version:** 2.0.0

---

## Context

WireTuner initially supported single-artboard documents where layers, selection, and viewport state existed at the document level. As we move toward supporting responsive design workflows, icon grids, device templates, and multi-window editing, we need to support multiple independent artboards within a single document, each with isolated state.

### Requirements

**FR-029 (Navigator Auto-Open):**
Documents containing multiple artboards must automatically spawn a Navigator window on open, displaying artboard thumbnails and enabling quick switching between artboards.

**FR-033 (Viewport Persistence):**
Each artboard must persist its own viewport state (pan, zoom, pivot) independently, allowing users to switch between artboard windows without losing their view context.

**FR-034–FR-045 (Multi-Artboard Operations):**
- Artboards must support creation, deletion, renaming, resizing
- Each artboard maintains its own layer stack
- Selection state is scoped per artboard
- Artboard presets (iPhone 14, A4, 1080p, etc.) for quick creation
- Spatial arrangement on infinite canvas
- Independent rendering and export per artboard

### Constraints

1. **Backward Compatibility:** Existing v1 documents (single artboard, layers at document root) must migrate seamlessly without data loss
2. **Event Sourcing Integrity:** Multi-artboard structure must preserve event replay determinism and snapshot consistency
3. **Performance:** Navigator panel must efficiently thumbnail and enumerate artboards (target: <100ms for 50 artboards)
4. **State Isolation:** Per-artboard selection and viewport must never leak across artboards, even when multiple windows are open
5. **SQLite Schema:** Must leverage existing `artboards` and `layers` tables from v2 schema without breaking changes

---

## Decision

We will introduce a **multi-artboard document architecture** where:

### 1. Domain Model Changes

**New Artboard Aggregate:**
```dart
@freezed
class Artboard with _$Artboard {
  const factory Artboard({
    required String id,
    @Default('Artboard') String name,
    @RectangleConverter() required Rectangle bounds,  // Position on infinite canvas
    @Default('#FFFFFF') String backgroundColor,
    String? preset,  // e.g., "iPhone14", "A4"
    @Default([]) List<Layer> layers,  // Per-artboard layer stack
    @Default(Selection()) Selection selection,  // Per-artboard selection
    @Default(Viewport()) Viewport viewport,  // Per-artboard pan/zoom
  }) = _Artboard;
}
```

**Refactored Document:**
```dart
@freezed
class Document with _$Document {
  const factory Document({
    required String id,
    @Default('Untitled') String title,
    @Default(kDocumentSchemaVersion) int schemaVersion,  // Now 2
    @Default([]) List<Artboard> artboards,  // NEW: List of artboards
    // Deprecated legacy fields for migration:
    @Deprecated(...) List<Layer>? layers,
    @Deprecated(...) Selection? selection,
    @Deprecated(...) Viewport? viewport,
  }) = _Document;
}
```

### 2. Schema Version Bump

- **Document Schema Version:** `kDocumentSchemaVersion = 2`
- **Database Schema Version:** `targetSchemaVersion = 3` (SQLite migrations)

### 3. Migration Strategy

**Database Migration (v2 → v3):**
- Add `artboard_count` column to `documents` table
- Create default artboard for documents without artboards
- Populate artboard count for Navigator performance
- No changes to existing `artboards`/`layers` tables (already exist from v2)

**Snapshot Migration (v1 → v2):**
Handled lazily in `SnapshotSerializer.deserialize()`:
1. Detect legacy snapshots: `schemaVersion == 1` OR `layers` field at document root
2. Create default artboard: `'default-artboard-{documentId}'`
3. Move legacy `layers`, `selection`, `viewport` into default artboard
4. Update `schemaVersion` to 2
5. Remove deprecated fields from document root

**Event Migration:**
- Existing events table already has `artboard_id` column (added in v2)
- New events MUST include `artboard_id` for artboard-scoped operations
- Document-level events (CreateDocumentEvent, etc.) have NULL `artboard_id`

### 4. State Isolation Guarantees

**Selection State:**
- Each artboard maintains `Selection(objectIds, anchorIndices)`
- Selecting objects in Artboard A does NOT affect Artboard B selection
- Document-wide operations (copy/paste across artboards) use `Document.getSelectedObjects()`

**Viewport State:**
- Each artboard stores `Viewport(pan, zoom, canvasSize)`
- Opening Artboard window restores last saved viewport
- Viewport changes emit `ViewportPanEvent`/`ViewportZoomEvent` with `artboard_id`

**Layer Stack:**
- Each artboard owns its `List<Layer>`
- Layer operations (CreateLayerEvent, ReorderLayerEvent) carry `artboard_id`
- Layer enumeration is always scoped to specific artboard

### 5. Event Sourcing Integration

**Event Schema Extensions:**
- All artboard-scoped events require `artboard_id` field (already in schema)
- Event replay filters by `artboard_id` for artboard-specific operations
- Snapshot serialization includes full artboard list with nested state

**Snapshot Structure (v2):**
```json
{
  "id": "doc-123",
  "title": "Responsive Design",
  "schemaVersion": 2,
  "artboards": [
    {
      "id": "artboard-mobile",
      "name": "iPhone 14",
      "bounds": {"x": 0, "y": 0, "width": 390, "height": 844},
      "backgroundColor": "#FFFFFF",
      "preset": "iPhone14",
      "layers": [...],
      "selection": {...},
      "viewport": {...}
    },
    {
      "id": "artboard-desktop",
      "name": "Desktop 1920x1080",
      "bounds": {"x": 500, "y": 0, "width": 1920, "height": 1080},
      ...
    }
  ]
}
```

### 6. Query API Changes

**New Methods:**
- `Document.getArtboardById(artboardId)` → `Artboard?`
- `Document.getArtboardContainingObject(objectId)` → `Artboard?`
- `Document.objectsAtPoint(point, artboardId)` → `List<VectorObject>`
- `Document.getSelectedObjectsForArtboard(artboardId)` → `List<VectorObject>`

**Deprecated (backward compatible):**
- `Document.layers` → Use `artboard.layers` instead
- `Document.selection` → Use `artboard.selection` instead
- `Document.viewport` → Use `artboard.viewport` instead

---

## Consequences

### Positive

1. **Multi-Canvas Workflows:** Enables responsive design, icon grids, device templates
2. **State Isolation:** No accidental cross-artboard selection/viewport pollution
3. **Window-Per-Artboard:** Each artboard can open in dedicated window with independent state
4. **Backward Compatible:** Legacy v1 documents auto-migrate to default artboard
5. **Performance:** Navigator can efficiently query `artboard_count` and thumbnail 50+ artboards
6. **Event Replay:** Artboard-scoped events enable targeted replay for thumbnails

### Negative

1. **API Complexity:** Document query methods now require `artboardId` parameter
2. **Migration Overhead:** Snapshot deserialization must handle two schema versions
3. **Storage Growth:** Multi-artboard documents store redundant viewport/selection per artboard
4. **Breaking Changes:** Deprecated `Document.layers` will be removed in v3.0.0

### Risks

1. **Migration Bugs:** Legacy snapshots might fail to migrate if schema is malformed
   - **Mitigation:** Extensive migration tests covering edge cases (empty documents, corrupted JSON)
2. **Event Validation:** Events missing `artboard_id` might corrupt state
   - **Mitigation:** EventStoreServiceAdapter validates artboard_id presence for scoped events
3. **Performance:** Large artboard counts (100+) might slow Navigator
   - **Mitigation:** Lazy thumbnail generation, virtualized lists, artboard_count index

---

## Alternatives Considered

### 1. Flat Layer Model with Artboard Tags

**Approach:** Keep `Document.layers` flat, add `artboardId` tag to each Layer.

**Rejected Because:**
- No clear state isolation (selection/viewport would still be document-level)
- Layer enumeration requires filtering entire layer list
- Breaks conceptual model of artboard as aggregate root

### 2. Separate Documents Per Artboard

**Approach:** Each artboard is a separate `.wt` file with its own event log.

**Rejected Because:**
- Breaks multi-artboard export workflows (PDF with multiple pages)
- Navigator panel would require managing multiple file handles
- Copy/paste across artboards requires cross-document coordination
- Violates "single source of truth" principle for related designs

### 3. Hybrid: Documents Reference External Artboards

**Approach:** Document stores artboard IDs, artboards stored in separate SQLite tables.

**Rejected Because:**
- Snapshot serialization becomes complex (require joins)
- Event replay requires coordinating multiple data sources
- Complicates backup/sync (need to track artboard dependencies)

---

## Implementation Notes

### Code Generation

**Freezed:** Regenerate `document.freezed.dart` after adding Artboard class:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

**JSON Serialization:** Added `RectangleConverter` for artboard bounds field.

### Migration Testing

Required test coverage:
1. ✅ Empty v1 document → default artboard created
2. ✅ V1 document with layers → layers moved to default artboard
3. ✅ V1 document with selection → selection scoped to default artboard
4. ✅ V1 document with viewport → viewport scoped to default artboard
5. ✅ V2 document with multiple artboards → no migration
6. ✅ Round-trip serialization preserves artboard order
7. ✅ Snapshot compression works with multi-artboard documents

### Performance Benchmarks

Target SLAs:
- Navigator thumbnail generation: <100ms for 50 artboards
- Artboard enumeration: <10ms for 100 artboards
- Snapshot serialization: <200ms for 10 artboards with 1000 objects total
- Event replay per artboard: <500ms for 1000 events

---

## References

- **Architecture Document:** `.codemachine/artifacts/architecture/02_System_Structure_and_Data.md#appendix-data-ownership`
- **Iteration Plan:** `.codemachine/artifacts/plan/02_Iteration_I4.md#task-i4-t1`
- **Event Catalog:** `docs/reference/event_catalog.md#artboard-events`
- **Migration Code:** `lib/infrastructure/persistence/migrations.dart#_migrateToV3`
- **Snapshot Serializer:** `lib/infrastructure/event_sourcing/snapshot_serializer.dart#_migrateLegacySchema`

---

**Decision Made By:** WireTuner Architecture Team
**Approved Date:** 2025-11-11
**Next Review:** After I4 completion (Multi-Artboard MVP)
