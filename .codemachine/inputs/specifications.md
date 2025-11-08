# WireTuner Implementation Tickets Index

## Overview
This document indexes all implementation tickets for WireTuner, a vector drawing application built with Flutter for desktop (macOS/Windows) with event-sourced architecture.

# IMPORTANT - ARCHITECTURE - decision in this section override any write up in an individual ticket.

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

# Tickets

**Total Tickets**: 39
**Milestone 0.1 Goal**: Working pen tool, shape creation (rect, ellipse, polygon, star), anchor/BCP manipulation, save/load

---

## Phase 0: Foundation & Setup (3 tickets)

| Ticket | Title | Priority | Effort | Dependencies |
|--------|-------|----------|--------|--------------|
| T001 | Flutter Project Setup | Critical | 0.5d | None |
| T002 | SQLite Integration | Critical | 1d | T001 |
| T003 | Event Sourcing Architecture Design | Critical | 0.5d | T002 |

**Phase Goal**: Project initialized, database integrated, architecture documented

---

## Phase 1: Core Event System (5 tickets)

| Ticket | Title | Priority | Effort | Dependencies |
|--------|-------|----------|--------|--------------|
| T004 | Event Model | Critical | 1d | T003 |
| T005 | Event Recorder with Sampling | Critical | 1d | T004 |
| T006 | Event Log Persistence | Critical | 0.5d | T002, T004 |
| T007 | Snapshot System | High | 1d | T006 |
| T008 | Event Replay Engine | Critical | 1.5d | T007 |

**Phase Goal**: Complete event sourcing system with recording, persistence, snapshots, and replay

---

## Phase 2: Vector Data Model (4 tickets)

| Ticket | Title | Priority | Effort | Dependencies |
|--------|-------|----------|--------|--------------|
| T009 | Core Geometry Primitives | Critical | 0.5d | None |
| T010 | Path Data Model | Critical | 1d | T009 |
| T011 | Shape Data Model | Critical | 1d | T009 |
| T012 | Document Model | Critical | 1d | T010, T011 |

**Phase Goal**: Complete data models for paths, shapes, and documents

---

## Phase 3: Rendering Engine (5 tickets)

| Ticket | Title | Priority | Effort | Dependencies |
|--------|-------|----------|--------|--------------|
| T013 | Canvas System with CustomPainter | Critical | 1d | T012 |
| T014 | Viewport Transform (Pan/Zoom) | Critical | 1d | T013 |
| T015 | Path Rendering with Bezier | Critical | 1d | T013 |
| T016 | Shape Rendering | High | 0.5d | T015 |
| T017 | Selection Visualization | High | 1d | T015 |

**Phase Goal**: Working canvas that renders all objects with pan/zoom

---

## Phase 4: Tool System Architecture (3 tickets)

| Ticket | Title | Priority | Effort | Dependencies |
|--------|-------|----------|--------|--------------|
| T018 | Tool Framework | Critical | 1d | T014 |
| T019 | Selection Tool | Critical | 1d | T018 |
| T020 | Direct Selection Tool | Critical | 1d | T019 |

**Phase Goal**: Tool system with object and anchor selection

---

## Phase 5: Pen Tool (4 tickets)

| Ticket | Title | Priority | Effort | Dependencies |
|--------|-------|----------|--------|--------------|
| T021 | Pen Tool - Create Anchor Points | Critical | 1d | T020 |
| T022 | Pen Tool - Straight Segments | High | 0.5d | T021 |
| T023 | Pen Tool - Bezier Curves | Critical | 1.5d | T022 |
| T024 | Pen Tool - Adjust BCPs | Medium | 1d | T023 |

**Phase Goal**: Fully functional pen tool with straight and curved segments

---

## Phase 6: Shape Tools (4 tickets)

| Ticket | Title | Priority | Effort | Dependencies |
|--------|-------|----------|--------|--------------|
| T025 | Rectangle Tool | Critical | 1d | T018 |
| T026 | Ellipse Tool | Critical | 0.5d | T025 |
| T027 | Polygon Tool | Critical | 1d | T026 |
| T028 | Star Tool | Critical | 1d | T027 |

**Phase Goal**: All basic shape creation tools working

---

## Phase 7: Direct Manipulation (4 tickets)

| Ticket | Title | Priority | Effort | Dependencies |
|--------|-------|----------|--------|--------------|
| T029 | Anchor Point Dragging | Critical | 1.5d | T020 |
| T030 | BCP Handle Dragging | Critical | 1.5d | T029 |
| T031 | Object Dragging | High | 1d | T019 |
| T032 | Multi-Selection Support | High | 0.5d | T031 |

**Phase Goal**: Full editing capability - drag points, handles, and objects

---

## Phase 8: File Operations (3 tickets)

| Ticket | Title | Priority | Effort | Dependencies |
|--------|-------|----------|--------|--------------|
| T033 | Save Document | Critical | 1d | T008 |
| T034 | Load Document | Critical | 1d | T033 |
| T035 | File Format Versioning | High | 0.5d | T034 |

**Phase Goal**: Save/load documents with version compatibility

---

## Phase 9: Import/Export (4 tickets)

| Ticket | Title | Priority | Effort | Dependencies |
|--------|-------|----------|--------|--------------|
| T036 | SVG Export | Critical | 2d | T034 |
| T037 | PDF Export | Critical | 2d | T036 |
| T038 | AI Import | Critical | 3d | T034 |
| T039 | SVG Import | High | 2d | T038 |

**Phase Goal**: Import AI files, export to SVG/PDF

---

## Milestone 0.1 Critical Path

To achieve Milestone 0.1 (working vector editor with save/load), complete these tickets in order:

### Foundation (4.5 days)
1. T001 → T002 → T003 → T004 → T005 → T006 → T007 → T008

### Data & Rendering (5 days)
2. T009 → T010 → T011 → T012 → T013 → T014 → T015 → T016 → T017

### Tools & Interaction (9 days)
3. T018 → T019 → T020
4. T021 → T022 → T023
5. T025 → T026 → T027 → T028
6. T029 → T030

### Persistence (2.5 days)
7. T033 → T034 → T035

**Total Critical Path**: ~21 days of focused development

---

## Implementation Notes

### Key Architectural Decisions
- **Event Sourcing**: All interactions recorded at 50ms sampling rate
- **Flutter CustomPainter**: Canvas rendering approach
- **SQLite**: Native file format with .wiretuner extension
- **Immutable Data**: All data models use immutable patterns
- **Snapshots**: Periodic snapshots every 1000 events

### Testing Strategy
- Unit tests for all data models and services
- Widget tests for tools and canvas
- Integration tests for save/load
- Manual testing for UI/UX

### References
- **Product Vision**: `/Users/tea/dev/github/wiretuner/thoughts/shared/research/2025-11-05-product-vision.md`
- **Architecture Design**: `/Users/tea/dev/github/wiretuner/thoughts/shared/tickets/T003-event-sourcing-architecture-design.md`
- **Dissipate Prototype**: `/Users/tea/dev/github/dissipate` (reference only, no code reuse)

---

## Quick Start

To begin implementation:

1. **Week 1**: Complete Phase 0-1 (Foundation + Event System)
   - Start with T001, work sequentially through T008
   - This establishes the architectural foundation

2. **Week 2**: Complete Phase 2-3 (Data Models + Rendering)
   - T009 through T017
   - First visual results!

3. **Week 3-4**: Complete Phase 4-7 (Tools + Interaction)
   - T018 through T032
   - Milestone 0.1 feature complete!

4. **Week 5**: Complete Phase 8-9 (File I/O + Import/Export)
   - T033 through T039
   - Production ready!

---

## Ticket Status Legend

- **Priority**:
  - Critical: Required for Milestone 0.1
  - High: Important but not blocking
  - Medium: Nice to have

- **Effort**:
  - d = days of focused development
  - Estimates assume single developer

---

*Last Updated: 2025-11-05*
*Total Estimated Effort: ~42 days*
