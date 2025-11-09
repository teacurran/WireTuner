# Specification Review & Recommendations: WireTuner Vector Drawing Application

**Date:** 2025-11-08
**Status:** Awaiting Specification Enhancement

### **1.0 Executive Summary**

This document is an automated analysis of the provided project specifications. It has identified critical decision points that require explicit definition before architectural design can proceed.

**Required Action:** The user is required to review the assertions below and **update the original specification document** to resolve the ambiguities. This updated document will serve as the canonical source for subsequent development phases.

### **2.0 Synthesized Project Vision**

*Based on the provided data, the core project objective is to engineer a system that:*

WireTuner is a desktop vector drawing application built with Flutter targeting macOS and Windows platforms. It employs event-sourced architecture for history replay visualization, supports Adobe Illustrator file import at Tier 2 fidelity, and provides professional-grade vector editing tools including pen, shape creation, and anchor point manipulation with persistent document storage.

### **3.0 Critical Assertions & Required Clarifications**

---

#### **Assertion 1: Event Sampling Strategy vs. Tool-Specific Event Types**

*   **Observation:** The architecture document specifies a blanket 50ms sampling rate for all user interactions (T005: Event Recorder with Sampling), but different tools have fundamentally different interaction patterns that may require distinct event modeling strategies.
*   **Architectural Impact:** This decision affects event log size, replay fidelity, and the complexity of the event recorder system.
    *   **Path A (Universal Sampling):** Apply 50ms sampling uniformly across all tools. Simple to implement but may oversample discrete actions (pen tool clicks) while undersampling continuous gestures (complex bezier curve adjustments).
    *   **Path B (Tool-Aware Event Types):** Define discrete event types for tools with atomic actions (pen tool anchor creation = single event) and sampling-based events for continuous operations (drag operations sampled at 50ms). Increases event model complexity but optimizes storage and replay accuracy.
    *   **Path C (Adaptive Sampling):** Implement variable sampling rates based on detected user action velocity or tool type (10ms for high-velocity drags, 100ms for slow movements). Maximizes replay fidelity but adds significant complexity to the event recorder.
*   **Default Assumption & Required Action:** The system will be architected assuming **Path A (Universal Sampling)** to minimize initial complexity. However, **the specification must explicitly define** whether the 50ms sampling applies to all tool interactions uniformly, or if certain tools (pen tool click-to-place anchor) should generate atomic events instead of time-sampled streams.

---

#### **Assertion 2: Snapshot Trigger Strategy & Replay Performance Guarantees**

*   **Observation:** The architecture decision specifies "snapshots every 500 events" for history replay performance, but the specification does not define whether this is a fixed interval, time-based, or dynamic strategy, nor does it specify replay performance requirements beyond "target 5K events/second playback rate."
*   **Architectural Impact:** Snapshot placement directly impacts memory consumption, replay startup time, and the granularity of seekable positions in the history timeline.
    *   **Strategy A (Fixed Event Count):** Create snapshot every 500 events regardless of document complexity. Simple and predictable, but may over-snapshot for simple documents or under-snapshot for complex scenes.
    *   **Strategy B (Document State Size Threshold):** Trigger snapshots when serialized document state exceeds a size threshold (e.g., 1MB). Optimizes for memory efficiency but makes replay seek positions unpredictable.
    *   **Strategy C (Hybrid Time + Event Count):** Snapshot every 500 events OR every 30 seconds of recorded time, whichever comes first. Balances replay performance with storage efficiency.
*   **Default Assumption & Required Action:** The architecture will implement **Strategy A (Fixed Event Count)** at 500 events to maintain deterministic behavior. **The specification must be updated** to explicitly define: (1) Whether the 500-event interval is a hard requirement or a baseline target, (2) Maximum acceptable replay startup time for seeking to arbitrary positions, and (3) Whether snapshots should be pruned/compacted on document save or retained indefinitely.

---

#### **Assertion 3: Multi-Window State Synchronization & Menu Bar Coordination**

*   **Observation:** The architecture decision mandates MDI with multiple windows, stating "Application menu bar coordinates across all windows," but the specification does not define the synchronization model for shared application state (recent files, preferences, clipboard) or whether the menu bar is per-window or global.
*   **Architectural Impact:** This variable determines the complexity of inter-window communication, shared state management, and platform-specific native integration.
    *   **Path A (Fully Isolated Windows):** Each window is entirely independent with no shared state except file system access. Simple to implement but provides poor UX (no shared clipboard, no synchronized preferences changes).
    *   **Path B (Shared Application State with Event Bus):** Implement a singleton application controller that coordinates shared state (preferences, clipboard, recent files) across all document windows via an event bus. Moderate complexity, industry-standard approach.
    *   **Path C (macOS Application Delegate / Windows Single-Instance Pattern):** Use platform-native application lifecycle patterns for state coordination. Optimal UX but requires platform-specific code paths and increases testing complexity.
*   **Default Assumption & Required Action:** The system will assume **Path B (Shared Application State with Event Bus)** to balance cross-platform consistency with UX quality. **The specification must explicitly define**: (1) Whether clipboard operations (copy/paste) work across document windows, (2) Whether preference changes apply immediately to all open windows, (3) Whether the "Recent Files" menu is globally synchronized, and (4) The expected behavior when closing the last document window (application quits vs. remains running with no windows).

---

#### **Assertion 4: Collaboration Foundation - UUID Collision Handling & Clock Synchronization**

*   **Observation:** The architecture decision specifies UUID-based event IDs and RFC3339 timestamps with microsecond precision for future collaboration support, but does not address UUID collision detection or client clock skew scenarios.
*   **Architectural Impact:** This decision affects data integrity guarantees and the viability of the deferred collaboration feature.
    *   **Path A (Trust UUID Uniqueness):** Assume UUIDv4 collisions are statistically impossible and omit collision detection. Simple but introduces non-zero data corruption risk in distributed scenarios.
    *   **Path B (Deterministic Event IDs with Hybrid Clock):** Use a combination of client ID + Lamport timestamp or Hybrid Logical Clock (HLC) instead of pure UUIDs. Guarantees uniqueness but requires additional infrastructure for clock synchronization.
    *   **Path C (UUID with Validation Layer):** Use UUIDv4 but implement validation during event persistence to detect and reject duplicate IDs. Adds minimal overhead while maintaining simplicity.
*   **Default Assumption & Required Action:** The system will implement **Path C (UUID with Validation Layer)** to provide collision detection without overengineering for v0.1. **The specification must be updated** to define: (1) Whether event IDs must be globally unique across all documents/users or only within a single document session, (2) The acceptable tolerance for timestamp drift between collaborating clients (e.g., ±5 seconds), and (3) Whether client-side or server-side timestamp authority is assumed for future collaboration.

---

#### **Assertion 5: File Format Versioning - Migration Path for Breaking Changes**

*   **Observation:** The architecture decision specifies semantic versioning with N-2 backward compatibility and "Save As" degradation warnings, but does not define the migration strategy when a major version introduces schema-breaking changes that cannot be gracefully degraded.
*   **Architectural Impact:** This determines whether users can always open old files (with potential data loss warnings) or if some version migrations require explicit conversion tools.
    *   **Path A (Always Readable with Data Loss):** Guarantee that any file can always be opened, but unsupported features are silently dropped or converted to nearest equivalents with warnings logged. User-friendly but risks unintentional data loss.
    *   **Path B (Explicit Migration Required):** When a file format change is non-degradable (e.g., fundamental coordinate system change), require users to run a one-time migration tool or open-and-resave in an intermediate version. Safest for data integrity but poorest UX.
    *   **Path C (Dual-Format Support Windows):** Major versions support reading old formats natively but write only the new format. Provide a 2-version overlap window where both formats are writable, then drop write support for old format. Balances safety and UX.
*   **Default Assumption & Required Action:** The system will implement **Path C (Dual-Format Support Windows)** to provide safe migration paths without requiring external tools. **The specification must explicitly define**: (1) The support lifecycle for old formats (e.g., "v3.x drops read support for v1.x after 2 years"), (2) Whether opening an old-format file triggers an automatic upgrade prompt or requires explicit "Save As" to new format, and (3) The validation/testing requirements for each version migration path.

---

#### **Assertion 6: Adobe Illustrator Import - Boolean Operations & Compound Path Interpretation**

*   **Observation:** The Tier 2 import specification includes "compound paths and boolean operations" as supported features, but does not define whether these are imported as live/editable operations or flattened/baked geometric results.
*   **Architectural Impact:** This decision determines the complexity of the path geometry engine and whether WireTuner needs to implement a full boolean operations stack in v0.1.
    *   **Path A (Flatten on Import):** Convert all compound paths and boolean operations to simple path geometry during import. Simple to implement (7-day estimate is achievable) but users lose editability of boolean operations.
    *   **Path B (Preserve as Metadata):** Import boolean operations as tagged path groups with original operation metadata stored but not executable. Allows future implementation of live boolean editing without overcommitting in v0.1.
    *   **Path C (Full Boolean Engine):** Implement a complete constructive solid geometry (CSG) engine to preserve live, editable boolean operations. High-fidelity but adds 5-7 days to the 7-day import estimate.
*   **Default Assumption & Required Action:** The system will implement **Path A (Flatten on Import)** to respect the 7-day development timeline for Tier 2 import. **The specification must be updated** to explicitly state: (1) Whether compound paths are flattened or preserved with operation history, (2) The expected behavior when re-exporting a flattened boolean operation to AI format, and (3) Whether the import dialog warnings should explicitly call out "boolean operations will be flattened" as a Tier 3 limitation.

---

#### **Assertion 7: Undo/Redo Granularity - Cross-Tool Operation Boundaries**

*   **Observation:** The architecture decision specifies operation-based undo with 200ms idle detection, but does not address scenarios where users rapidly switch between tools within the same 200ms window (e.g., draw with pen tool, immediately switch to selection tool and drag).
*   **Architectural Impact:** This affects the user's mental model of undo granularity and the implementation complexity of the operation boundary detection system.
    *   **Path A (Tool Switch = Operation Boundary):** Any tool change explicitly marks an operation boundary regardless of idle time. Predictable but may fragment logical operations (e.g., drawing a path then immediately adjusting it feels like one action).
    *   **Path B (Idle Time Only):** Trust the 200ms idle detection exclusively; tool switches do not force boundaries. Simpler implementation but may create unexpectedly large undo operations if users work quickly across tools.
    *   **Path C (Hybrid with Tool-Specific Markers):** Use 200ms idle as the primary boundary, but allow tools to explicitly emit operation markers when completing a logical action (e.g., pen tool closing a path, shape tool releasing mouse button). Most sophisticated but adds per-tool complexity.
*   **Default Assumption & Required Action:** The system will implement **Path C (Hybrid with Tool-Specific Markers)** to optimize for user intent rather than pure timing. **The specification must explicitly define**: (1) Whether rapid tool switching (< 200ms) should group actions into a single undo or separate them, (2) The expected undo behavior when switching from pen tool mid-path-creation to selection tool, and (3) Whether the undo stack should display tool names in operation descriptions (e.g., "Undo: Pen Tool - Create Path").

---

### **4.0 Next Steps**

Upon the user's update of the original specification document, the development process will be unblocked and can proceed to the architectural design phase.

The recommended workflow is:

1. **Review each assertion** in Section 3.0 and select the preferred path for each ambiguity.
2. **Update the architecture decisions document** to explicitly address each assertion with selected paths and rationale.
3. **Revise affected ticket estimates** in the implementation index if any decisions significantly alter complexity (e.g., choosing Path C for boolean operations would extend T038 from 3d to ~5d).
4. **Signal completion** by updating the specification status to "Architecture Finalized" to trigger the next phase of detailed technical design.
