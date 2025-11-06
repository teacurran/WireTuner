# WireTuner Project Plan

**Version:** 1.0
**Generated:** 2025-11-05
**Total Iterations:** 9
**Estimated Duration:** ~42 days (21 days for Milestone 0.1)

---

## Overview

This directory contains a comprehensive, structured project plan for WireTuner, a professional vector drawing application built with Flutter for desktop platforms (macOS/Windows). The plan is organized to support both human readers and autonomous software development agents working in parallel where possible.

**Key Features:**
- Event-sourced architecture with 50ms sampling
- Flutter CustomPainter rendering at 60 FPS
- SQLite-based .wiretuner file format
- Complete toolset: Pen, Selection, Direct Selection, Rectangle, Ellipse, Polygon, Star
- Full editing workflow: drag objects/anchors/handles, undo/redo, save/load
- Import/Export: AI, SVG, PDF

---

## File Structure

### Core Planning Documents

1. **`01_Plan_Overview_and_Setup.md`** (21 KB)
   - Project overview, goals, requirements summary
   - Core architecture (Event-Sourced Layered Architecture)
   - Technology stack (Flutter, Dart, SQLite, Provider)
   - Key components and data model overview
   - Complete directory structure
   - Planned architectural artifacts (diagrams, schemas)

2. **`02_Iteration_I1.md` through `02_Iteration_I9.md`** (11-15 KB each)
   - **I1: Foundation & Setup** (6 tasks, 4-5 days)
   - **I2: Core Event System** (9 tasks, 7-8 days)
   - **I3: Vector Data Model** (7 tasks, 5-6 days)
   - **I4: Rendering Engine** (6 tasks, 5-6 days)
   - **I5: Tool System Architecture** (6 tasks, 4-5 days)
   - **I6: Pen Tool** (5 tasks, 4-5 days)
   - **I7: Shape Tools** (5 tasks, 4-5 days)
   - **I8: Direct Manipulation** (5 tasks, 5-6 days)
   - **I9: File Operations & Import/Export** (8 tasks, 7-9 days)

3. **`03_Verification_and_Glossary.md`** (18 KB)
   - Testing strategy (unit, widget, integration, performance, manual)
   - CI/CD pipeline definition (GitHub Actions)
   - Code quality gates (linting, coverage, review)
   - Artifact validation (diagrams, schemas, file formats)
   - Comprehensive glossary (terms, acronyms, project-specific terminology)

4. **`plan_manifest.json`** (26 KB)
   - Machine-readable index of all plan sections
   - Maps anchor keys to file locations
   - Enables surgical content retrieval by agents
   - 133 location entries

---

## How to Use This Plan

### For Human Developers

**Getting Started:**
1. Read `01_Plan_Overview_and_Setup.md` first for context
2. Review the directory structure (Section 3) to understand code organization
3. Study iteration overviews to grasp the development sequence

**During Implementation:**
1. Work through iterations sequentially (I1 → I2 → ... → I9)
2. Within each iteration, identify parallelizable tasks (marked in task descriptions)
3. Refer to acceptance criteria for task completion validation
4. Cross-reference architecture blueprint (in `thoughts/shared/research/`) for design details

**Task Execution:**
- Each task specifies:
  - **Agent Type Hint:** Suggested role (BackendAgent, FrontendAgent, DatabaseAgent, etc.)
  - **Inputs:** Required context (architecture sections, previous tasks)
  - **Input Files:** Specific file dependencies
  - **Target Files:** Files to create/modify
  - **Deliverables:** Expected outputs
  - **Acceptance Criteria:** Specific, verifiable completion conditions
  - **Dependencies:** Task IDs that must complete first
  - **Parallelizable:** Yes/No flag

**Milestone 0.1 Critical Path:**
- Foundation & Setup (I1): 4-5 days
- Core Event System (I2): 7-8 days
- Vector Data Model (I3): 5-6 days
- Rendering Engine (I4): 5-6 days
- Tool System (I5): 4-5 days
- Pen Tool (I6): 4-5 days
- Shape Tools (I7): 4-5 days (can partially overlap with I6)
- Direct Manipulation (I8): 5-6 days
- File Operations (I9): 7-9 days

**Total:** ~42 days (optimized to ~21 days with parallel work)

---

### For Autonomous Agents

**Using the Manifest:**
1. Load `plan_manifest.json` to index all plan sections
2. Query by `key` to locate specific content
3. Open `file` and seek to `start_anchor` to extract content
4. Use `description` for semantic search/matching

**Example Query:**
```json
{
  "key": "task-i3-t6",
  "file": "02_Iteration_I3.md",
  "start_anchor": "<!-- anchor: task-i3-t6 -->",
  "description": "Task I3.T6: Implement Document model as root aggregate"
}
```

**Agent Workflow:**
1. Identify assigned task (e.g., "I3.T6")
2. Query manifest for task key (`task-i3-t6`)
3. Read task details from `02_Iteration_I3.md` at anchor
4. Load input files specified in task
5. Execute task following acceptance criteria
6. Generate target files
7. Run tests to verify acceptance criteria
8. Mark task complete

**Parallelization:**
- Check `Parallelizable: Yes` flag in task metadata
- Launch multiple agents for independent tasks
- Respect `Dependencies` field (wait for prerequisite tasks)

---

## Plan Statistics

### Iterations
- **Total Iterations:** 9
- **Total Tasks:** 57
- **Estimated Duration:** ~42 days sequential, ~21 days with parallel work

### Tasks by Iteration
- I1: 6 tasks (Foundation & Setup)
- I2: 9 tasks (Core Event System)
- I3: 7 tasks (Vector Data Model)
- I4: 6 tasks (Rendering Engine)
- I5: 6 tasks (Tool System Architecture)
- I6: 5 tasks (Pen Tool)
- I7: 5 tasks (Shape Tools)
- I8: 5 tasks (Direct Manipulation)
- I9: 8 tasks (File Operations & Import/Export)

### Artifacts to Generate
- **PlantUML Diagrams:** 5
  - Component Diagram (I1.T2)
  - Event Sourcing Sequence Diagrams (I1.T3)
  - Database ERD (I3.T7)
  - Domain Model Class Diagram (I3.T7)
  - Tool State Machine Diagrams (I6.T5)
- **Architecture Decision Records (ADRs):** 2
  - Event Sourcing Architecture (I1.T6)
  - File Format Versioning (I9.T3)
- **API Documentation:** 1
  - Internal API Contracts (referenced throughout)
- **Testing Strategy:** 1
  - Comprehensive Testing Document (I9.T8)

---

## Key Architectural Decisions

### 1. Event Sourcing with 50ms Sampling
All user interactions captured as immutable events at 50ms intervals. Benefits: infinite undo/redo, audit trail, collaboration foundation.

### 2. Flutter Desktop Framework
Single codebase for macOS/Windows, CustomPainter for 60 FPS rendering.

### 3. SQLite as Native File Format
.wiretuner files are SQLite databases with ACID guarantees.

### 4. Immutable Domain Models
All data structures are immutable. Changes create new copies with structural sharing.

### 5. Snapshot Every 1000 Events
Periodic snapshots enable fast document loading (< 2 seconds) without replaying entire history.

---

## Success Criteria (Milestone 0.1)

**Functional Requirements:**
- [ ] Pen tool creates paths with straight segments and Bezier curves
- [ ] Shape tools create rectangle, ellipse, polygon, star
- [ ] Selection tool selects and moves objects
- [ ] Direct selection tool selects and moves anchor points and BCP handles
- [ ] Undo/redo works for all operations (Cmd/Ctrl+Z)
- [ ] Save/load .wiretuner documents with event replay
- [ ] Export to SVG and PDF
- [ ] Import Adobe Illustrator (.ai) files

**Non-Functional Requirements:**
- [ ] Rendering: 60 FPS with 1,000 objects
- [ ] Document load: < 2 seconds for 10,000 events
- [ ] Test coverage: 80%+ for domain and infrastructure layers
- [ ] Cross-platform: Runs on macOS 10.15+ and Windows 10 1809+

---

## Iteration Dependencies

```
I1 (Foundation) → I2 (Event System)
                → I3 (Data Model)

I2 + I3 → I4 (Rendering)

I4 → I5 (Tool System)

I5 → I6 (Pen Tool)
   → I7 (Shape Tools)
   → I8 (Direct Manipulation)

I2 + I3 → I9 (File Ops & Import/Export)
```

**Critical Path:** I1 → I2 → I3 → I4 → I5 → I6 → I8 → I9

**Parallelizable Paths:**
- I3 can partially overlap with I2 (after event models defined)
- I7 can partially overlap with I6 (both depend on I5)
- I9 can start after I2+I3 complete (file operations independent of rendering)

---

## Next Steps

1. **Validate Plan:** Review with technical stakeholders, gather feedback
2. **Set Up Development Environment:** Complete I1 tasks (project setup, database integration)
3. **Begin Implementation:** Start I2 (Core Event System)
4. **Iterate:** Work through I3-I9, testing incrementally
5. **Integrate Continuously:** Run CI/CD pipeline on every commit
6. **Review Milestone 0.1:** After I9 completion, validate all success criteria met

---

## Maintenance

**Updating the Plan:**
1. Edit relevant markdown files
2. If adding new sections, insert anchor comments: `<!-- anchor: kebab-case-key -->`
3. Update `plan_manifest.json` with new location entries
4. Increment version number in all files
5. Commit changes with descriptive message

**Feedback:**
Report issues or suggest improvements via the project repository.

---

## References

- **Architecture Blueprint:** `.codemachine/artifacts/architecture/` (comprehensive system design)
- **Product Vision:** `thoughts/shared/research/2025-11-05-product-vision.md`
- **Ticket Index:** `thoughts/shared/tickets/README.md` (39 detailed tickets)
- **Dissipate Prototype:** `../dissipate/` (reference implementation, no code reuse)

---

**Generated by:** Claude Sonnet 4.5
**Last Updated:** 2025-11-05

*This plan provides a roadmap for building WireTuner from scratch to Milestone 0.1 in ~21 days with focused, parallel development.*
