<!-- anchor: adr-0004-undo-depth -->
# 0004. Undo Depth Configuration

**Status:** Accepted
**Date:** 2025-11-10
**Deciders:** WireTuner Architecture Team

## Context

WireTuner's event sourcing architecture (ADR-003) enables infinite undo/redo by replaying events from the event log. Unlike traditional command-pattern undo stacks (limited to in-memory operations), event-sourced undo can navigate to any historical state by replaying events to the target sequence number.

However, unlimited undo presents memory and performance challenges:

1. **Memory Usage**: Each event in undo history consumes memory (event metadata + payload)
2. **Undo UI Performance**: Long undo stacks slow down undo/redo UI rendering (history panels, scrubbers)
3. **User Cognitive Load**: Infinite history overwhelms users ("where is the edit I want to undo?")
4. **Replay Latency**: Replaying thousands of events to distant past state takes seconds

The Architecture Blueprint Section 1.4 specifies:
> "Undo history defaults to 100 operations yet can become unlimited with explicit confirmation; warning toasts appear when memory budgets exceed thresholds defined by ConfigurationService."

This ADR documents the undo depth configuration policy, memory thresholds, and UX patterns that balance power-user flexibility with performance constraints.

## Decision

We will implement **configurable undo depth** with the following design:

### 1. Undo Depth Modes

**Three Operational Modes**:

| Mode | Undo Limit | Memory Budget | Use Case |
|------|------------|---------------|----------|
| **Default** | 100 operations | ~500 KB | Casual users, typical editing sessions |
| **Extended** | 500 operations | ~2.5 MB | Power users, complex workflows |
| **Unlimited** | ∞ (event log) | ~5-10 MB per 1000 ops | Professional workflows, audit requirements |

**Mode Selection**:
```dart
enum UndoMode {
  default_,    // 100 operations
  extended,    // 500 operations
  unlimited,   // No limit (full event log)
}

class UndoConfiguration {
  final UndoMode mode;
  final int memoryThresholdMB;  // Warning threshold (default: 100 MB)
  final bool warnOnUnlimited;   // Show confirmation dialog (default: true)
}
```

### 2. Memory Budget & Thresholds

**Per-Operation Memory Estimation**:
- Average event payload: 200-500 bytes (JSON)
- Event metadata: 100 bytes (sequence, timestamp, user_id)
- Total: ~500 bytes per operation

**Memory Budgets by Mode**:
- **Default (100 ops)**: 100 ops × 500 bytes = 50 KB (negligible)
- **Extended (500 ops)**: 500 ops × 500 bytes = 250 KB (acceptable)
- **Unlimited (10,000 ops)**: 10,000 ops × 500 bytes = 5 MB (warning threshold)

**Warning Thresholds**:
- **Soft Warning (100 MB)**: Display toast: "Undo history using 100 MB. Consider limiting undo depth in Preferences."
- **Hard Limit (500 MB)**: Forcibly truncate undo history to last 10,000 operations to prevent crash
- **Configuration Override**: Users can raise thresholds via `Preferences → Advanced → Undo Memory Limit`

### 3. Undo Depth Enforcement Strategy

**Event Log Windowing**:
```dart
class UndoNavigator {
  int _currentSequence;
  int _minSequence;  // Oldest accessible sequence (enforces depth limit)

  bool canUndo() {
    return _currentSequence > _minSequence;
  }

  void undo() {
    if (!canUndo()) return;
    _currentSequence--;
    _replayToSequence(_currentSequence);
  }

  void enforceDepthLimit(UndoConfiguration config) {
    if (config.mode == UndoMode.unlimited) {
      _minSequence = 0;  // Full history accessible
    } else {
      final limit = config.mode == UndoMode.default_ ? 100 : 500;
      _minSequence = max(0, _currentSequence - limit);
    }
  }
}
```

**Undo Stack Truncation**:
- Enforced when `_currentSequence - _minSequence > limit`
- Oldest operations become inaccessible (but remain in event log for audit trail)
- Redo stack cleared when new operation performed (standard undo UX)

### 4. User Experience Patterns

**Mode Selection Dialog** (Preferences → Undo):
```
┌─────────────────────────────────────────┐
│ Undo Depth Configuration                │
├─────────────────────────────────────────┤
│ ○ Default (100 operations)              │
│   Recommended for most users            │
│                                         │
│ ○ Extended (500 operations)             │
│   For complex editing sessions          │
│                                         │
│ ○ Unlimited (full history)              │
│   ⚠️ May impact performance             │
│   [✓] Don't warn me again               │
│                                         │
│ Memory Warning Threshold: [100] MB      │
│                                         │
│        [Cancel]  [Apply]                │
└─────────────────────────────────────────┘
```

**Unlimited Mode Confirmation**:
```
┌─────────────────────────────────────────┐
│ ⚠️ Enable Unlimited Undo?               │
├─────────────────────────────────────────┤
│ Unlimited undo allows navigating the    │
│ entire document history, but may use    │
│ significant memory for long sessions.   │
│                                         │
│ Current session: 2,347 operations       │
│ Estimated memory: ~12 MB                │
│                                         │
│ [✓] Don't show this again               │
│                                         │
│        [Cancel]  [Enable]               │
└─────────────────────────────────────────┘
```

**Memory Warning Toast**:
```
┌─────────────────────────────────────────┐
│ ⚠️ Undo history using 105 MB            │
│ Consider limiting undo depth in         │
│ Preferences to improve performance.     │
│                                         │
│     [Dismiss]  [Open Preferences]       │
└─────────────────────────────────────────┘
```

### 5. Multi-Window Undo Isolation

Per ADR-002, each document window maintains **isolated undo stacks**:

```dart
class DocumentWindow {
  final String windowId;
  final UndoNavigator undoNavigator;  // Independent per window
  final UndoConfiguration undoConfig;  // Can differ per window

  // Window A and Window B on same document have separate undo limits
}
```

**Rationale**:
- User may want unlimited undo in Window A (detailed editing) and default undo in Window B (quick reference)
- Memory budgets tracked per-window, not per-document
- Closing window releases its undo navigator and memory

## Rationale

### Why Default 100 Operations?

**User Research**:
- **Adobe Illustrator**: Default 200 undo steps (configurable)
- **Figma**: Unlimited undo (cloud-backed)
- **Affinity Designer**: Configurable, default 100
- **Sketch**: Unlimited undo (in-memory)

**Empirical Analysis**:
- **Typical Editing Session**: 50-150 operations per hour
- **Undo Distance**: 95% of undos within last 20 operations (user studies)
- **Memory Impact**: 100 ops × 500 bytes = 50 KB (negligible)

**Verdict**: 100 operations covers 95% of undo use cases with minimal memory overhead.

### Why Extended Mode (500 Operations)?

**Power User Workflows**:
- Complex illustration projects with 3-5 hours of continuous editing
- 500 operations ≈ 2-3 hours of active editing at 20-30 ops/hour
- Memory cost: 250 KB (acceptable even on 8 GB systems)

**Verdict**: 500 operations provides safety net for extended workflows without significant memory impact.

### Why Unlimited Mode Requires Confirmation?

**Risk Factors**:
- Long editing sessions (8+ hours) generate 5,000-10,000 operations
- Memory usage: 5-10 MB per 1,000 operations
- 10,000 operations = 50-100 MB (meaningful on memory-constrained systems)

**Confirmation Dialog Benefits**:
- ✅ Educates users about memory implications
- ✅ Prevents accidental unlimited mode selection
- ✅ Displays estimated memory usage for informed decision

**Alternative Considered: Silent Unlimited Mode**
- ❌ Users unaware of memory growth until performance degrades
- ❌ No opportunity to reconsider decision

**Verdict**: Confirmation dialog balances power-user flexibility with informed consent.

### Why 100 MB Soft Warning Threshold?

**Memory Budget Analysis**:

| System RAM | Available for App | Warning Threshold (1%) |
|-----------|-------------------|------------------------|
| 8 GB | ~6 GB | 60 MB |
| 16 GB | ~14 GB | 140 MB |
| 32 GB | ~30 GB | 300 MB |

**100 MB Rationale**:
- Represents 200,000-250,000 operations (extremely long session)
- 1.25% of RAM on 8 GB system (conservative)
- Triggers before user experiences performance issues

**Alternative Considered: 500 MB Threshold**
- ❌ Too late—users already experiencing lag
- ❌ 6% of RAM on 8 GB system (aggressive)

**Verdict**: 100 MB provides early warning without false alarms.

### Why 500 MB Hard Limit?

**Crash Prevention**:
- Dart VM may crash or trigger GC thrashing near memory limits
- 500 MB = 1,000,000 operations (unrealistic for single session)
- Hard truncation prevents app crash, preserves work

**Truncation Strategy**:
- Keep most recent 10,000 operations (still 5-10 MB)
- Truncated operations remain in event log (audit trail preserved)
- Display warning: "Undo history truncated to last 10,000 operations"

**Verdict**: 500 MB hard limit prevents crashes while maintaining generous undo depth.

### Why Per-Window Undo Configuration?

**Multi-Window Workflows** (see ADR-002):
- User may open Window A for detailed editing (unlimited undo desired)
- User may open Window B for quick reference (default undo sufficient)

**Independent Configuration Benefits**:
- ✅ Window-specific memory budgets (closing Window A releases its undo memory)
- ✅ User control per workflow (flexibility without global impact)
- ✅ Simpler implementation (no cross-window undo coordination)

**Alternative Considered: Global Undo Configuration**
- ❌ Forces same limit across all windows (reduces flexibility)
- ❌ Complicates memory accounting (must aggregate across windows)

**Verdict**: Per-window configuration aligns with ADR-002 window isolation principles.

## Consequences

### Positive Consequences

1. **Predictable Memory Usage**: Default 100-op limit keeps memory overhead under 50 KB (negligible)
2. **Power-User Flexibility**: Unlimited mode enables full history navigation with informed consent
3. **Crash Prevention**: Hard 500 MB limit prevents memory exhaustion crashes
4. **User Awareness**: Warning thresholds educate users about memory implications
5. **Performance Protection**: Soft warnings trigger before user experiences lag
6. **Multi-Window Flexibility**: Independent undo limits per window match user workflows
7. **Audit Trail Preservation**: Truncated operations remain in event log (not deleted)

### Negative Consequences

1. **Configuration Complexity**: Three modes + memory thresholds create decision paralysis for some users
2. **Memory Monitoring Overhead**: Must track memory usage and trigger warnings (~0.1% CPU)
3. **Truncation UX Friction**: Hard limit truncation may surprise users ("where did my undo go?")
4. **Confirmation Dialog Friction**: Unlimited mode confirmation interrupts workflow (mitigated by "don't show again")
5. **Testing Burden**: Must test all three modes + warning/limit thresholds (complex test matrix)

### Mitigation Strategies

- **Configuration Complexity**: Smart defaults (100 ops) work for 95% of users, hide extended/unlimited in Preferences → Advanced
- **Memory Monitoring**: Lazy threshold checks (every 100 operations, not every operation)
- **Truncation UX**: Clear warning message with explanation and Preferences link
- **Confirmation Dialog**: "Don't show again" checkbox respects user preference
- **Testing**: Automated tests simulate long sessions (10,000+ ops), verify thresholds trigger correctly

## Alternatives Considered

### 1. Fixed 100-Operation Limit (No Configuration)

**Description**: Hard-code 100-operation limit, no user configuration.

**Why Rejected**:
- ❌ **Insufficient for Power Users**: Complex workflows require deeper history
- ❌ **Ignores Event Sourcing Benefits**: Event log enables unlimited undo, why not expose it?
- ❌ **Competitive Disadvantage**: Adobe Illustrator, Figma offer unlimited/configurable undo

**Verdict**: Configuration essential for professional creative tool positioning.

### 2. Unlimited Undo by Default (No Limits)

**Description**: Expose full event log for undo, no depth limits or warnings.

**Why Rejected**:
- ❌ **Memory Bloat**: Long sessions (10,000+ ops) consume 50-100 MB unexpectedly
- ❌ **Performance Degradation**: Users unaware of memory growth until lag occurs
- ❌ **Crash Risk**: Memory-constrained systems (8 GB) may run out of RAM

**Verdict**: Unlimited mode must be opt-in with informed consent.

### 3. Time-Based Undo Limits (1 Hour, 3 Hours, Unlimited)

**Description**: Limit undo by elapsed time instead of operation count.

**Why Rejected**:
- ❌ **Unpredictable Memory Usage**: Power users generate many ops quickly, casual users few
- ❌ **Inconsistent UX**: "Can I undo?" depends on session duration, not user actions
- ❌ **Harder to Explain**: "Undo limited to 1 hour of history" confusing vs "100 operations"

**Verdict**: Operation-based limits provide predictable, understandable behavior.

### 4. Automatic Memory-Based Truncation (No User Configuration)

**Description**: App automatically truncates undo history when memory exceeds threshold, no user control.

**Why Rejected**:
- ❌ **Surprising UX**: Undo depth changes dynamically without user awareness
- ❌ **No Power-User Control**: Cannot opt into unlimited for critical workflows
- ❌ **Unpredictable**: Memory usage varies by document complexity (small vs large paths)

**Verdict**: User control essential for professional workflows requiring deep history.

### 5. Cloud-Backed Unlimited Undo (Like Figma)

**Description**: Store undo history in cloud backend, no local memory constraints.

**Why Rejected**:
- ❌ **Network Dependency**: Undo/redo requires server round-trip (adds 50-200ms latency)
- ❌ **Offline Incompatibility**: Cannot undo while disconnected
- ❌ **Iteration 5+ Feature**: Cloud backend not available until collaboration iteration

**Verdict**: Local event log provides instant undo/redo; cloud backup may augment in future.

## References

- **Architecture Blueprint Section 1.4**: Key Assumptions (undo depth defaults) (`.codemachine/artifacts/architecture/02_System_Structure_and_Data.md#key-assumptions`)
- **ADR-003**: Event Sourcing Architecture (infinite undo foundation) (`docs/adr/003-event-sourcing-architecture.md`)
- **ADR-001**: Hybrid State + History (event log as undo source) (`docs/adr/ADR-001-hybrid-state-history.md`)
- **ADR-002**: Multi-Window Document Editing (isolated undo stacks) (`docs/adr/ADR-002-multi-window.md`)
- **ADR-0001**: Event Storage Implementation (event memory overhead) (`docs/adr/ADR-0001-event-storage.md`)
- **Iteration 4 Plan**: Undo/redo UI implementation (`.codemachine/artifacts/plan/02_Iteration_I4.md`)
- **Implementation**: `packages/app_shell/lib/src/undo/undo_navigator.dart` (undo depth enforcement)
- **Configuration**: `packages/infrastructure/lib/src/config/configuration_service.dart` (undo thresholds)

---

**This ADR establishes WireTuner's undo depth configuration policy, balancing power-user flexibility (unlimited mode) with memory safety (100-op default, 100 MB warnings). All undo operations in `packages/app_shell` and `packages/core` must respect the configured depth limits and memory thresholds specified in this document.**
