# WireTuner Implementation Tickets Index

## Overview
This document indexes all implementation tickets for WireTuner, a vector drawing application built with Flutter for desktop (macOS/Windows) with event-sourced architecture.

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
