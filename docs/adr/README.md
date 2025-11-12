# Architecture Decision Records (ADRs)

This directory contains Architecture Decision Records (ADRs) documenting significant architectural decisions made during WireTuner's development.

## What are ADRs?

Architecture Decision Records capture important architectural decisions, their context, rationale, and consequences. They provide:

- **Historical Context**: Why decisions were made at the time
- **Traceability**: Links to requirements, tasks, and implementation
- **Knowledge Transfer**: Onboard new team members with decision history
- **Change Management**: Track architectural evolution over time

## ADR Index

### Persistence & Event Sourcing

| ADR | Title | Status | Date | Summary |
|-----|-------|--------|------|---------|
| [ADR-001](ADR-001-hybrid-state-history.md) | Hybrid State + History Approach | Accepted | 2025-11-08 | Combines periodic snapshots with append-only event log for fast loading and complete history preservation |
| [003](003-event-sourcing-architecture.md) | Event Sourcing Architecture Design | Accepted | 2025-11-06 | Complete event sourcing with 50ms sampling, JSON encoding, and immutable domain models |
| [ADR-0001](ADR-0001-event-storage.md) | Event Storage Implementation | Accepted | 2025-11-10 | SQLite-based event storage with WAL mode, 50ms sampling, and per-event transactions |
| [ADR-0003](ADR-0003-snapshot-policy.md) | Snapshot Policy | Accepted | 2025-11-10 | Multi-trigger snapshot policy (500 events, 10-minute timer, manual save) with gzip compression |

### Multi-User & Collaboration

| ADR | Title | Status | Date | Summary |
|-----|-------|--------|------|---------|
| [ADR-002](ADR-002-multi-window.md) | Multi-Window Document Editing | Accepted | 2025-11-08 | Independent window state with pooled SQLite connections and isolated undo stacks |
| [ADR-0002](ADR-0002-ot-strategy.md) | Operational Transform Strategy | Accepted | 2025-11-10 | OT-based conflict resolution for future collaborative editing with 10-editor concurrency limit |

### User Experience & Configuration

| ADR | Title | Status | Date | Summary |
|-----|-------|--------|------|---------|
| [ADR-0004](ADR-0004-undo-depth.md) | Undo Depth Configuration | Accepted | 2025-11-10 | Configurable undo depth (default 100, extended 500, unlimited) with memory thresholds and warnings |

### File Format & Versioning

| ADR | Title | Status | Date | Summary |
|-----|-------|--------|------|---------|
| [004](004-file-format-versioning.md) | File Format Versioning | Accepted | 2025-11-10 | Semantic versioning with automatic sequential migrations and transaction safety |

## ADR Lifecycle

### Status Values

- **Proposed**: Under review, not yet accepted
- **Accepted**: Approved and implemented (or being implemented)
- **Deprecated**: No longer recommended, kept for historical reference
- **Superseded by ADR-XXX**: Replaced by specific newer ADR

### Creating a New ADR

See [CONTRIBUTING.md](../../CONTRIBUTING.md#architecture-decision-records-adrs) for detailed workflow.

**Quick Start**:

1. Copy the template:
   ```bash
   cp docs/adr/template.md docs/adr/ADR-00XX-descriptive-name.md
   ```

2. Fill in all required sections (see template for structure)

3. Ensure traceability:
   - Reference FR/NFR IDs from specifications
   - Link to task IDs from iteration plans
   - Cross-reference related ADRs

4. Submit for review (2 approvals required for architectural decisions)

## ADR Naming Convention

- **Zero-padded prefix**: `ADR-0001`, `ADR-0002`, etc.
- **Descriptive suffix**: Short, hyphenated description (`event-storage`, `ot-strategy`)
- **Legacy format**: Some early ADRs use `003-*` format (will be standardized in future)

## References

- **Template**: [template.md](template.md) - Standard ADR structure
- **Contributing Guide**: [CONTRIBUTING.md](../../CONTRIBUTING.md) - Full ADR workflow
- **Architecture Blueprint**: `.codemachine/artifacts/architecture/` - High-level architecture
- **Specifications**: `.codemachine/inputs/specifications.md` - Requirements and constraints

## Questions?

If you have questions about existing ADRs or the ADR process, please:

1. Check the [Contributing Guide](../../CONTRIBUTING.md) for workflow details
2. Review related ADRs linked in the References section
3. Open a GitHub Discussion for clarification
4. Contact the Architecture Team lead

---

**Last Updated**: 2025-11-10
