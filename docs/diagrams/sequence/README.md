# WireTuner Sequence Diagrams

This directory contains PlantUML sequence diagrams documenting the core interaction flows in WireTuner.

## Diagrams

### 1. Pen Tool Path Creation (`pen_flow.puml`)
Documents the complete pen tool interaction flow from tool activation through path creation with event sourcing.

**Key Features:**
- Tool activation and pointer handler registration
- 200ms anchor sampling loop
- Grid snapping with Shift modifier (FR-028)
- Event persistence and undo boundary detection (ADR-0004)
- Telemetry tracking (NFR-PERF-004)

**Related Specifications:**
- Architecture Blueprint Section 3.7.3.1 (Flow A)
- ADR-001 (Hybrid State + History)
- ADR-0004 (Undo Depth Configuration)
- FR-025 (Tool activation and sampling)

### 2. Direct Selection Drag (`direct_selection_flow.puml`)
Shows anchor manipulation with real-time collaboration broadcast.

**Key Features:**
- Direct selection tool activation with anchor visibility (FR-024)
- Sampled drag movement with background serialization
- Screen-space snapping (FR-028)
- Operational Transform (OT) for collaboration (FR-050)
- Remote event propagation

**Related Specifications:**
- Architecture Blueprint Section 3.7.3.4 (Flow D)
- FR-024 (Anchor visibility)
- FR-050 (Collaboration)

### 3. Save and Snapshot Coordination (`save_snapshot_flow.puml`)
Documents manual save (Cmd/Ctrl+S), auto-save, and snapshot creation flows.

**Key Features:**
- Auto-save idle detection (200ms threshold)
- Save deduplication (FR-014)
- Background snapshot compression (NFR-PERF-006)
- Security validation via SecurityGateway
- UI feedback and status indicators

**Related Specifications:**
- Architecture Blueprint Section 3.7.3.2 (Flow B)
- Architecture Blueprint Appendix B.3 (Save + Snapshot + Export)
- ADR-001 (Snapshot strategy)
- FR-014 (Save deduplication)

### 4. SVG/AI Import Flow (`import_flow.puml`)
Documents the complete import workflow from file selection through event recording.

**Key Features:**
- File selection and security validation
- Feature flag gating for AI import
- Background worker processing (NFR-PERF-006)
- Progress feedback via WebSocket
- Event recording for full undo support

**Related Specifications:**
- Architecture Blueprint Section 3.7.1 (API Style - Import hooks)
- Architecture Blueprint Section 3.5 (Component Diagram)
- FR-041 (Import format support)

## Rendering Diagrams

These diagrams use PlantUML syntax and can be rendered using:

### Online
- [PlantUML Web Server](http://www.plantuml.com/plantuml/uml/)

### Local (VS Code)
1. Install the PlantUML extension
2. Open any `.puml` file
3. Press `Alt+D` to preview

### Command Line
```bash
# Install PlantUML
brew install plantuml  # macOS
apt-get install plantuml  # Ubuntu

# Render diagrams
plantuml docs/diagrams/sequence/*.puml

# Generate PNG output
plantuml -tpng docs/diagrams/sequence/*.puml
```

## Diagram Conventions

All diagrams follow these conventions:

1. **Header Comments**: Each file starts with a comment block describing purpose, related specs, and date
2. **Participant Grouping**: Participants organized into logical boxes (UI Layer, Event Pipeline, Persistence Layer, etc.)
3. **FR/ADR References**: Inline notes reference specific functional requirements and architectural decisions
4. **Color Coding**: Consistent box colors across diagrams:
   - `#FFFDE7` - UI Layer (yellow tint)
   - `#FCE4EC` - Event Pipeline (pink tint)
   - `#E3F2FD` - Persistence Layer (blue tint)
   - `#E8F5E9` - Collaboration Layer (green tint)
   - `#F3E5F5` - External Systems (purple tint)

## Related Documentation

- [Architecture Blueprint - Behavior and Communication](../../.codemachine/artifacts/architecture/03_Behavior_and_Communication.md)
- [Architecture Blueprint - System Structure](../../.codemachine/artifacts/architecture/02_System_Structure_and_Data.md)
- [ADR-001 - Hybrid State + History](../../adr/ADR-001-hybrid-state-history.md)
- [ADR-0004 - Undo Depth Configuration](../../adr/ADR-0004-undo-depth.md)

## Maintenance

These diagrams should be updated when:
- New interaction flows are added
- Service interactions change significantly
- FR/NFR requirements are modified
- ADRs affecting these flows are created/updated

For questions or updates, refer to the Architecture Team.
