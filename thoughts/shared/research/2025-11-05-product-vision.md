# WireTuner Product Vision

## Overview
WireTuner is a vector drawing application for desktop and web, positioning itself as an alternative to Adobe Illustrator and Affinity Designer, while bringing back beloved features from classic tools like Adobe Flash and Macromedia Freehand.

## Platform Targets
- **Desktop**: [TBD - which platforms]
- **Web**: Online version
- **Mobile**: [TBD - scope to be determined]

## Key Differentiators
- Combines modern vector drawing capabilities with classic workflow features
- Features inspired by Adobe Flash (animation timeline, symbols, tweening?)
- Features inspired by Macromedia Freehand (innovative path editing, multi-page documents?)

## Technical Stack

### Framework & Platforms
- **Primary Framework**: Flutter
- **Initial Target Platforms**:
  - macOS Desktop
  - Windows Desktop
- **Future Considerations**:
  - Tablet (interface redesign needed)
  - Mobile (stripped down interface)
  - Web (TBD)

### Data Architecture
- **Native File Format**: SQLite database file (.wiretuner or similar extension)
- **Data Model**: Event-sourced architecture
  - Record ALL user interactions with sampled fidelity (50-100ms sampling)
  - Mouse movements, timings, selections, drags, anchor point manipulations
  - Bezier control point (BCP) handle adjustments
  - Full replay capability
- **Database Structure**: Event log + periodic snapshots
  - Append-only event log for all interactions
  - Periodic snapshots for fast document loading
  - Rebuild state from last snapshot + subsequent events
- **Versioning Strategy**: Database schema must be forward-compatible
  - Every future version must read older file formats
  - Migration strategy needed for schema evolution
- **Collaboration Support** (future):
  - Multi-user events in same database
  - Conflict resolution for out-of-sync edits
  - Operational Transform or CRDT approach needed

### Rendering
- **Approach**: Flutter CustomPainter with Canvas API
- **Optimization**: Can migrate to OpenGL/Vulkan if performance requires

### Import/Export Formats
- **SVG** (Scalable Vector Graphics): Import & Export
- **AI** (Adobe Illustrator): Import & Export
- **EPS** (Encapsulated PostScript): Import & Export
- **PDF** (Portable Document Format): Import & Export

**Priority for MVP**:
- **Export**: SVG and PDF (most critical)
- **Import**: AI/Adobe Illustrator (most critical)
- **Later**: EPS support

**Import Strategy**: Single "ImportEvent" that captures the entire imported document as one atomic action. This preserves the imported state without fabricating individual creation events.

**Export Strategy**: Materialize current document state from event stream and export to target format.

## Core Feature Areas

### Milestone 0.1 - MVP: Basic Vector Editing
**Goal**: Functional vector path editing with full event recording

**Features**:
- **Pen Tool**: Click to create anchor points, create bezier curves
- **Shape Tools**: Create and size basic shapes (rectangle, ellipse, polygon, star)
- **Direct Selection**: Click and drag anchor points
- **Bezier Control**: Click and drag BCPs (Bezier Control Points / handles)
- **File Operations**: Save to .wiretuner SQLite file, load and replay

**Terminology Note**:
- Anchor points = the points on the path
- BCPs (Bezier Control Points) / handles = the control points that define curve tangents

## Development Priorities
[To be determined]

---

## Architectural Learnings from Dissipate Prototype

The dissipate prototype (`/Users/tea/dev/github/dissipate`) provides valuable architectural insights:

### What Worked Well:
1. **Data Model**: Simple Point/BezierCurve classes with bidirectional references
   - Points maintain references to connected curves
   - Automatic curve updates when points move
2. **State Management**: ValueNotifier pattern for tool/UI state
3. **Canvas Transform**: Clean separation of logical vs screen coordinates
4. **Gesture Handling**: Conditional logic prevents pan/drag conflicts
5. **Animated Selection**: Dashed rectangle with animation provides good UX

### Key Patterns to Adopt:
- Custom data models (not tied to Flutter's Path class)
- GestureDetector for all input handling
- Canvas save/restore for transform stack
- Platform-aware keyboard shortcuts infrastructure

### Gaps to Address in WireTuner:
- Add event sourcing (dissipate has no undo/history)
- Add file persistence (dissipate is memory-only)
- Add shape tools (dissipate only has pen tool fully implemented)
- Add styling system (color, stroke width, fill)
- Add proper undo/redo system

---

## Discussion Notes

### Session 2025-11-05
- Initial concept: Desktop + online vector drawing app
- Inspiration: Illustrator, Affinity Designer, Flash, Freehand
- Analyzed dissipate prototype for architectural patterns
