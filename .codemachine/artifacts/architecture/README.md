# WireTuner System Architecture Blueprint

**Version:** 1.0
**Generated:** 2025-11-05
**Project:** WireTuner Vector Drawing Application

---

## Overview

This directory contains a comprehensive System Architecture Blueprint for WireTuner, a professional vector drawing application built with Flutter for desktop platforms (macOS/Windows). The architecture employs event sourcing to enable advanced features like infinite undo/redo, workflow replay, and future collaborative editing.

The blueprint is organized as a structured set of interconnected documents, indexed by `architecture_manifest.json` for surgical content retrieval by downstream agents or tools.

---

## Document Structure

The architecture is split across 6 thematically balanced markdown files:

### **01_Context_and_Drivers.md** (9.4 KB)
**Purpose:** Establishes the "Why" and "What" of the project

**Contents:**
- Introduction & Goals (vision, objectives, scope, assumptions)
- Architectural Drivers (functional requirements, NFRs, constraints)

**Key Sections:**
- Project vision for event-sourced vector editing
- Performance targets (60 FPS, 10,000+ objects)
- Constraints (Flutter, SQLite, single developer, 21-day timeline)

---

### **02_Architecture_Overview.md** (8.8 KB)
**Purpose:** Defines the high-level architectural approach and technology stack

**Contents:**
- Architectural Style (Event-Sourced Layered Architecture)
- Technology Stack Summary (Flutter, Dart, SQLite, Provider)

**Key Sections:**
- Event sourcing rationale (undo/redo, audit trail, collaboration foundation)
- Layered architecture structure (Presentation → Application → Domain → Infrastructure)
- Technology selection justifications (Flutter vs Electron, SQLite vs PostgreSQL, etc.)

---

### **03_System_Structure_and_Data.md** (22 KB)
**Purpose:** Provides static structural views of the system

**Contents:**
- C4 Context Diagram (Level 1) - System boundary and external actors
- C4 Container Diagram (Level 2) - Major subsystems (UI, Event Core, Vector Engine, Persistence)
- C4 Component Diagrams (Level 3) - Internal components of Vector Engine, Event Sourcing Core, Tool System
- Data Model & ERD - SQLite schema (events, snapshots, metadata) and in-memory domain model (Document, Path, Shape)

**Key Diagrams:**
- 4 PlantUML diagrams (Context, Container, 3 Component views)
- 2 ERD diagrams (SQLite persistent data, in-memory domain objects)

---

### **04_Behavior_and_Communication.md** (18 KB)
**Purpose:** Illustrates dynamic behavior and communication patterns

**Contents:**
- API Design & Communication (event-driven, request/response, pub/sub patterns)
- Key Interaction Flows with 5 sequence diagrams:
  1. Creating a path with the Pen Tool
  2. Loading a document (event replay from snapshot)
  3. Undo operation (event navigation)
  4. Dragging an anchor point (50ms sampling)
  5. Exporting to SVG
- Internal API Contracts (EventRecorder, EventReplayer, ITool, Document)

**Key Diagrams:**
- 5 PlantUML sequence diagrams showing critical workflows

---

### **05_Operational_Architecture.md** (21 KB)
**Purpose:** Covers operational concerns and deployment

**Contents:**
- Cross-Cutting Concerns:
  - Logging & Monitoring (log levels, rotation, performance metrics)
  - Security (threat model, input validation, dependency security)
  - Scalability & Performance (viewport culling, LOD, event sampling)
  - Reliability & Availability (crash recovery, data integrity, ACID guarantees)
- Deployment View:
  - Build process (macOS .dmg, Windows .exe)
  - Distribution channels (GitHub Releases, future app stores)
  - CI/CD pipeline (GitHub Actions)
  - System requirements (minimum/recommended specs)

**Key Diagrams:**
- 1 PlantUML deployment diagram showing desktop environments and CI/CD

---

### **06_Rationale_and_Future.md** (25 KB)
**Purpose:** Explains design decisions, trade-offs, and future directions

**Contents:**
- Design Rationale & Trade-offs:
  - 7 key decisions (event sourcing, Flutter, SQLite, immutability, 50ms sampling, snapshots, Provider)
  - Alternatives considered (Microservices, Electron, Qt, PostgreSQL, WebGL)
  - Known risks & mitigation (performance, file size, Flutter maturity, AI/SVG complexity, single developer)
- Future Considerations:
  - Potential evolution (collaborative editing, cloud sync, plugins, advanced features)
  - Platform expansion (web, mobile, Linux)
  - Areas needing deeper design (geometry engine, undo/redo UI, selection model, accessibility)
- Glossary & Acronyms

---

## Architecture Manifest

**File:** `architecture_manifest.json` (29 KB)

The manifest is the "address book" for the entire blueprint. It contains **134 location entries**, each specifying:
- `key`: Unique identifier (kebab-case)
- `file`: Which markdown file contains the content
- `start_anchor`: HTML comment anchor marking the section start
- `description`: One-sentence summary of the section

**Usage:**
Downstream agents can query the manifest to locate specific architectural knowledge without reading all files. For example:

```json
{
  "key": "decision-event-sourcing",
  "file": "06_Rationale_and_Future.md",
  "start_anchor": "<!-- anchor: decision-event-sourcing -->",
  "description": "Event sourcing architecture decision rationale"
}
```

---

## Key Architectural Decisions

### 1. **Event Sourcing with 50ms Sampling**
All user interactions are captured as immutable events at 50ms intervals, stored in SQLite. Benefits: infinite undo/redo, audit trail, collaboration foundation. Trade-off: complexity vs. traditional CRUD.

### 2. **Flutter Desktop Framework**
Single codebase for macOS/Windows, CustomPainter for 60 FPS rendering. Trade-off: larger binaries vs. code duplication in native development.

### 3. **SQLite as Native File Format**
.wiretuner files are SQLite databases with ACID guarantees. Trade-off: binary format vs. human-readable JSON/XML, but ubiquity of SQLite tooling mitigates.

### 4. **Immutable Domain Models**
All data structures (Document, Path, Shape) are immutable. Benefits: predictable state, thread-safe, testable. Trade-off: memory overhead (mitigated by structural sharing).

### 5. **Snapshot Every 1000 Events**
Periodic snapshots enable fast document loading without replaying entire history. Trade-off: storage overhead (~10 KB - 1 MB per snapshot, gzipped).

---

## Diagrams Summary

**Total Diagrams:** 12 PlantUML diagrams

| Type | Count | Purpose |
|------|-------|---------|
| C4 Context | 1 | System boundary, external actors |
| C4 Container | 1 | Major subsystems and data flow |
| C4 Component | 3 | Internal structure of Vector Engine, Event Core, Tool System |
| ERD | 2 | SQLite schema + in-memory domain model |
| Sequence | 5 | Critical workflows (pen tool, load, undo, drag, export) |
| Deployment | 1 | Desktop environments, CI/CD |

All diagrams use PlantUML syntax and can be rendered with PlantUML tools or online renderers (e.g., https://www.plantuml.com/plantuml/).

---

## Technology Stack at a Glance

| Layer | Technology | Justification |
|-------|-----------|---------------|
| **Framework** | Flutter 3.16+ | Cross-platform, 60 FPS CustomPainter, mature ecosystem |
| **Language** | Dart 3.2+ | Null-safe, strong typing, Flutter requirement |
| **Database** | SQLite (sqflite_common_ffi) | Embedded, ACID, portable, battle-tested |
| **State Mgmt** | Provider 6.0+ | Lightweight, sufficient for desktop app |
| **Event Sourcing** | Custom | Purpose-built for desktop needs, full control |
| **Rendering** | CustomPainter (dart:ui) | Direct canvas access, Skia backend |
| **Import/Export** | xml, pdf packages | SVG, PDF, AI file support |
| **Testing** | test, flutter_test | Unit, widget, integration tests |
| **CI/CD** | GitHub Actions | Automated builds for macOS, Windows |

---

## Milestone 0.1 Scope

**Timeline:** ~21 days (4 weeks)
**Developer:** Single developer (8 hours/day)

**Deliverables:**
1. Event sourcing system (recorder, replayer, snapshots)
2. Vector data models (Path, Shape, Document)
3. Canvas rendering (CustomPainter, 60 FPS)
4. Tools: Pen, Selection, Direct Selection, Rectangle, Ellipse, Polygon, Star
5. Direct manipulation (drag objects, anchors, BCPs)
6. Save/load .wiretuner files
7. SVG/PDF export, AI/SVG import

**Out of Scope for 0.1:**
- Real-time collaboration
- Cloud sync
- Text editing
- Layer management
- Boolean path operations
- Gradients/effects
- Mobile/web platforms

---

## How to Use This Blueprint

### For Developers
1. **Start with 01_Context_and_Drivers.md** to understand project vision and constraints
2. **Read 02_Architecture_Overview.md** for high-level architecture and tech stack
3. **Study 03_System_Structure_and_Data.md** for component structure and data models
4. **Review 04_Behavior_and_Communication.md** for workflow sequences
5. **Consult 05_Operational_Architecture.md** for operational concerns
6. **Reference 06_Rationale_and_Future.md** for decision justifications

### For Agents/Tools
1. **Load architecture_manifest.json** to index all sections
2. **Query by key** to locate specific architectural knowledge
3. **Read from anchor** in the specified file to extract content
4. **Example query:** "decision-event-sourcing" → Read from `<!-- anchor: decision-event-sourcing -->` in `06_Rationale_and_Future.md`

### For Stakeholders
- **Executive Summary:** Read sections 1.1, 1.2, 3.1 (vision, objectives, architectural style)
- **Technology Choices:** Read section 3.2 (technology stack)
- **Risks:** Read section 4.3 (known risks and mitigation)
- **Roadmap:** Read section 5.1 (future evolution)

---

## Next Steps

1. **Validate Architecture:** Review with technical stakeholders, gather feedback
2. **Prototype Critical Paths:** Build spike solutions for event sourcing, rendering, and tool system
3. **Begin Implementation:** Start with Phase 0-1 (Foundation & Event System) per ticket index
4. **Iterate:** Refine architecture based on implementation learnings

---

## Maintenance

**Updating the Blueprint:**
1. Edit relevant markdown files
2. If adding new sections, insert anchor comments: `<!-- anchor: kebab-case-key -->`
3. Update `architecture_manifest.json` with new location entries
4. Increment version number in all files

**Feedback:**
Report issues or suggest improvements via the project repository.

---

**Generated by:** Claude Sonnet 4.5
**Last Updated:** 2025-11-05
