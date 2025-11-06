# Architecture Decisions: WireTuner Vector Drawing Application

**Date:** 2025-11-06
**Status:** Approved
**Version:** 1.0

## Document Purpose

This document captures the architectural decisions made in response to the critical assertions identified in the specification review. These decisions will guide the implementation of WireTuner v0.1 and establish the foundation for future development.

---

## Decision 1: Event Sourcing & Document State Management

### Context
The specification initially suggested event sourcing for document reconstruction, but clarification revealed that the primary use case is **history replay visualization**, not document state reconstruction.

### Decision
**Hybrid State Management with Separate History Log**

- **Document State:** Always save and load the complete final state of the document for fast opening
- **History Log:** Maintain separate event log for replay/visualization purposes only
- **Event Sampling:** 50ms sampling for user interactions (mouse movements, drags) stored as optional history data
- **Snapshots:** Use conservative snapshot strategy (every 500 events) for history replay performance
- **Critical Path:** Document opening uses final state only - history replay is a separate, optional feature

### Rationale
This approach ensures:
- Fast document loading (always reads final state, not event replay)
- Rich history for visualization/replay when needed
- Separation of concerns between document persistence and history tracking
- History data is additive and never blocks core functionality

### Performance Targets
- Document load time: <100ms for final state, regardless of history size
- History replay: Target 5K events/second playback rate
- Snapshots every 500 events ensure replay sections stay under 100ms

---

## Decision 2: Multi-Document Architecture

### Decision
**MDI - Multiple Windows**

Each document opens in a separate window within a single application instance.

### Implementation Details
- Native window lifecycle management per platform
- Each document has isolated state and event store
- Standard window management (minimize, maximize, close per document)
- Application menu bar coordinates across all windows

### Rationale
- Provides native desktop application feel
- Allows users to organize documents across multiple monitors
- Consistent with professional creative applications (Adobe suite, Sketch)
- Better fits professional workflows than SDI or tabs

---

## Decision 3: Collaborative Editing Foundation

### Decision
**Build Collaboration-Ready Foundation (Defer Implementation)**

Implement the foundational architecture to enable future collaborative editing without committing to full implementation in v0.1.

### Implementation Details
- Use UUID-based event IDs instead of local sequences
- Include timestamp infrastructure (RFC3339 format with microsecond precision)
- Design event schema to support eventual operational transformation
- No networking, sync logic, or conflict resolution in v0.1
- Single-user functionality only for initial release

### Timeline
- Foundation work: v0.1 (adds 3-5 days to initial implementation)
- Networking and sync: Post-v0.1 (future milestone)
- Full collaborative editing: TBD based on user demand

### Rationale
- Avoids costly architectural refactoring when collaboration is added
- Minimal overhead for v0.1 (UUID generation is negligible)
- Keeps door open for competitive feature without committing resources prematurely

---

## Decision 4: File Format Versioning

### Decision
**Semantic Versioning with Graceful Degradation**

Implement Major.Minor.Patch versioning for file format with backward compatibility guarantees.

### Implementation Details
- File format starts at version 1.0.0
- Each file embeds its format version in header
- Application supports reading N-2 major versions (e.g., v3.x can read v1.x and v2.x)
- "Save As" option to export in backward-compatible format with feature degradation warnings
- Migration testing required for each minor/major version bump

### Version Compatibility Matrix
| App Version | Can Read | Can Write | Notes |
|-------------|----------|-----------|-------|
| 1.x | 1.x | 1.x | Initial format |
| 2.x | 1.x, 2.x | 2.x, 1.x (degraded) | Warns on feature loss when saving to 1.x |
| 3.x | 1.x, 2.x, 3.x | 3.x, 2.x (degraded) | Drops 1.x write support |

### Rationale
- Balances user flexibility with maintainability
- Prevents vendor lock-in scenarios
- Supports workflows where teams use different versions
- Industry standard approach (Office, Sketch, Figma use similar strategies)

---

## Decision 5: Adobe Illustrator (AI) Import Fidelity

### Decision
**Tier 2: Extended Vector Features**

Support geometric primitives plus common vector features, with explicit unsupported feature warnings.

### Supported Features (Tier 2)
**Tier 1 (Geometric Primitives):**
- Paths and bezier curves
- Basic shapes (rectangles, ellipses, polygons)
- Fill colors and stroke colors
- Stroke widths and basic stroke styles
- Layer hierarchy and naming
- Object transformations (translate, rotate, scale)

**Tier 2 (Extended Vector Features):**
- Gradient fills (linear and radial)
- Advanced stroke styles (dashed, dotted, caps, joins)
- Compound paths and boolean operations
- Clipping masks
- Opacity/transparency
- Basic text (as converted paths)

### Explicitly NOT Supported (Tier 3 - Future)
- Blend modes (multiply, screen, overlay, etc.)
- Live effects (drop shadows, glows, blurs)
- Symbols and symbol instances
- Brushes (art, pattern, scatter)
- Advanced typography (text flow, on-path text with editability)
- Appearance panel stacking

### Implementation Timeline
- Tier 1: 3 days (MVP)
- Tier 2: Additional 4 days (total 7 days)
- Tier 3: Deferred to post-v0.1 milestones based on user feedback

### User Experience
- Import dialog shows feature compatibility report
- Unsupported features are logged with warnings
- Complex objects may be simplified or flattened
- Users can preview import before committing

### Rationale
- Covers 85% of common use cases (validated by Illustrator usage patterns)
- Achievable within reasonable development timeline (7 days)
- Provides clear upgrade path to Tier 3
- Sets realistic user expectations via explicit warnings

---

## Decision 6: Platform Parity Strategy

### Decision
**Strict Parity Across Platforms (v0.1)**

Maintain identical core functionality across macOS and Windows for initial release.

### Implementation Details
- All drawing tools work identically on both platforms
- File formats are 100% interchangeable
- Keyboard shortcuts follow platform conventions (Cmd vs Ctrl) but map to same functions
- UI uses Flutter Material/Cupertino widgets that adapt to platform
- No platform-specific features in v0.1 (Touch Bar, Windows Ink, etc.)

### Testing Requirements
- Parallel testing matrix for both platforms
- Automated tests run on both macOS and Windows CI runners
- Manual QA checklist validated on both platforms before each release

### Future Platform Enhancements (Post-v0.1)
Potential platform-specific features for future consideration:
- **macOS:** Touch Bar support, QuickLook previews, Continuity integration
- **Windows:** Windows Ink integration, Taskbar thumbnail previews, Jump Lists

### Rationale
- Ensures consistent user experience across platforms
- Simplifies initial development and testing
- Avoids fragmenting user base with platform-specific features
- Allows platform enhancements to be added strategically based on user feedback

---

## Decision 7: Undo/Redo Granularity

### Decision
**Operation-Based Undo with Automatic Boundary Detection**

Group related events into logical operations, with one undo action reversing an entire operation.

### Implementation Details
- **Idle Time Threshold:** 200ms of no user input marks end of operation
- **Operation Grouping:** All events within an operation are treated as single undoable unit
- **Examples:**
  - Dragging object for 2 seconds = 1 undo (not 40 separate undos)
  - Typing text continuously = groups by 200ms pauses
  - Applying multiple property changes = 1 undo if within 200ms
- **Operation Markers:** Tools can explicitly emit operation boundaries when idle detection is insufficient
- **Undo Stack:** Limit to 100 operations (configurable in preferences)
- **Redo Stack:** Cleared when new operation occurs after undo

### Edge Cases
| Scenario | Behavior |
|----------|----------|
| Undo during in-progress operation | Complete current operation first, then undo previous |
| Redo after document modification | Redo stack is cleared |
| Undo while history is replaying | Replay pauses, undo applies, replay can continue |
| Multiple rapid operations | Each distinct action (separated by 200ms idle) is separate undo |

### User Experience
- Undo/Redo commands show operation description in status bar
  - "Undo: Move Rectangle"
  - "Redo: Apply Gradient Fill"
- Keyboard shortcuts: Cmd+Z / Ctrl+Z (undo), Cmd+Shift+Z / Ctrl+Y (redo)
- History panel shows operation list with thumbnails

### Rationale
- Matches user mental model (entire action = 1 undo)
- 200ms threshold aligns with human perception of continuous action
- Prevents frustration of undoing through dozens of micro-samples
- Industry standard approach (Adobe, Figma, Sketch use similar strategies)

---

## Summary of Architectural Choices

| Decision Area | Choice | Development Impact | v0.1 Timeline |
|---------------|--------|-------------------|---------------|
| Event Sourcing | Hybrid (state + history) | Medium | +2 days (dual persistence) |
| Multi-Document | MDI - Multiple Windows | Medium | +3 days (window lifecycle) |
| Collaboration | Foundation only | Low | +3-5 days (UUID/timestamps) |
| File Versioning | Semantic with degradation | Medium | +2 days (version handling) |
| AI Import | Tier 2 (Extended features) | High | +7 days (parser + render) |
| Platform Parity | Strict parity | High | +4 days (dual platform testing) |
| Undo/Redo | Operation-based grouping | Low | +1 day (boundary detection) |

**Total Additional Development Time from Decisions:** ~22 days (on top of base implementation)

---

## Next Steps

1. **Specification Update:** Update the original specification document to incorporate these decisions
2. **Technical Design:** Proceed to detailed architectural design phase
3. **Implementation Planning:** Break down into sprint-sized tasks with dependencies
4. **Risk Assessment:** Identify potential blockers for each decision area
5. **Prototype Validation:** Consider building small proofs-of-concept for high-risk areas (Tier 2 AI import, operation-based undo)

---

## Document History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | 2025-11-06 | Initial architecture decisions captured | System/User collaboration |

---

## Approval

These decisions have been reviewed and approved by the project stakeholder and serve as the canonical architectural foundation for WireTuner v0.1 development.
