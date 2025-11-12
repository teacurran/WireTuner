# Specification Review & Recommendations: WireTuner Vector Drawing Application

**Date:** 2025-11-10
**Status:** Awaiting Specification Enhancement

### **1.0 Executive Summary**

This document is an automated analysis of the provided project specifications. It has identified critical decision points that require explicit definition before architectural design can proceed.

**Required Action:** The user is required to review the assertions below and **update the original specification document** to resolve the ambiguities. This updated document will serve as the canonical source for subsequent development phases.

### **2.0 Synthesized Project Vision**

*Based on the provided data, the core project objective is to engineer a system that:*

Delivers a professional desktop vector drawing application with complete event-sourced interaction history, enabling precise vector artwork creation while capturing the entire creative process for replay, analysis, and collaboration. The system differentiates through comprehensive event sourcing that records all user interactions, supporting rich history visualization beyond traditional undo/redo.

### **3.0 Critical Assertions & Required Clarifications**

---

#### **Assertion 1: Event Sourcing Storage Strategy & Performance Trade-offs**

*   **Observation:** The specification implements a hybrid model (final state + event log) but lacks explicit guidance on event retention policies, database growth management, and performance degradation thresholds for large event stores.
*   **Architectural Impact:** This directly affects long-term application viability, user experience degradation over time, and disk space requirements.
    *   **Path A (Unbounded Event Log):** Store all events indefinitely. Enables complete history replay but requires aggressive snapshot strategies and may degrade performance after 500K+ events.
    *   **Path B (Windowed Event Log):** Retain events for fixed time period (e.g., 90 days) or event count (e.g., 100K events), with archival export. Predictable performance but loses deep history.
    *   **Path C (Tiered Retention):** Keep all critical events (anchors, objects) indefinitely, but prune high-frequency sampling events (mouse movements) after threshold period. Balances history completeness with storage efficiency.
*   **Default Assumption & Required Action:** The architecture assumes **Path A (Unbounded)** with user-managed file sizes and configurable snapshot frequency (500 events default). **The specification must be updated** to define explicit event retention policies, expected file size growth patterns (e.g., "typical 1-hour session = 5K events = 2MB file"), and performance degradation thresholds that trigger user warnings or automatic archival suggestions.

---

#### **Assertion 2: Multiplayer Collaboration Conflict Resolution Algorithm**

*   **Observation:** Section 7.9 recommends WebSockets + GraphQL with Operational Transform (OT) or CRDT for conflict resolution but does not specify which algorithm is required or provide decision criteria.
*   **Architectural Impact:** This is a foundational choice affecting real-time collaboration accuracy, server complexity, and client-side state management.
    *   **Path A (Operational Transform):** Deterministic, well-understood for vector editing. Requires centralized server to sequence operations. Complex transformation functions for path editing (anchor position changes, handle adjustments). Best for low-latency, small team collaboration (2-10 users).
    *   **Path B (CRDT - Conflict-free Replicated Data Types):** Eventually consistent, decentralized. Simpler conflict resolution but may produce unexpected intermediate states during concurrent edits. Better for asynchronous collaboration or larger teams (10+ users).
    *   **Path C (Last-Write-Wins with Timestamps):** Simplest implementation. Server-authoritative timestamps determine conflict winners. Acceptable for low-conflict scenarios but may lose user edits during simultaneous modifications.
*   **Default Assumption & Required Action:** The system will architect for **Path A (Operational Transform)** given the real-time, precision-critical nature of vector path editing and target use case of small design teams. **The specification must be updated** to explicitly mandate OT as the conflict resolution strategy, define maximum supported concurrent editors per document (recommend: 5-10), and specify acceptable conflict resolution latency (recommend: <200ms for transform + broadcast).

---

#### **Assertion 3: Cross-Platform File Format Byte Ordering & Portability**

*   **Observation:** The specification mandates SQLite for .wiretuner files with "byte-identical across platforms" (NFR-PORT-002) but does not address potential endianness issues in custom binary data structures or floating-point representation differences.
*   **Architectural Impact:** Failure to enforce strict serialization standards will cause file corruption when transferring documents between macOS (Intel/ARM) and Windows (x86/x64) systems.
    *   **Path A (Pure JSON Serialization):** Store all document state and events as JSON text in SQLite BLOB columns. Guaranteed platform-portable but 30-50% larger file sizes and slower parse times.
    *   **Path B (Canonical Binary Format):** Define explicit byte order (little-endian), IEEE 754 double precision for all coordinates, and protocol buffer or similar schema for binary serialization. Compact and fast but requires rigorous cross-platform testing.
    *   **Path C (SQLite Native Types Only):** Restrict all stored data to SQLite's native types (INTEGER, REAL, TEXT). Avoids custom serialization entirely. Requires denormalized schema (e.g., separate tables for anchor points) but maximizes portability.
*   **Default Assumption & Required Action:** The architecture assumes **Path A (Pure JSON)** given Flutter's strong JSON serialization support and Freezed integration. File size increase is acceptable trade-off for guaranteed portability. **The specification must be updated** to mandate JSON-only serialization for all event payloads and snapshot state, specify compression strategy (gzip for snapshots >1MB), and define cross-platform validation test suite (macOS-created files must load identically on Windows and vice versa).

---

#### **Assertion 4: Snapshot Background Execution Thread Safety & State Consistency**

*   **Observation:** Section 7.7 mandates background snapshot creation using Flutter's `compute()` isolate but does not address potential race conditions when document state changes during snapshot serialization.
*   **Architectural Impact:** Concurrent mutations during snapshot generation can produce corrupted snapshots or inconsistent event sequences, compromising document integrity.
    *   **Path A (Copy-on-Write Snapshot):** Deep clone document state before passing to background isolate. Guarantees consistency but requires 2x memory (original + clone) during snapshot operation. May cause memory pressure on large documents (10K+ objects).
    *   **Path B (Read Lock During Snapshot):** Acquire read lock on document state, pause event recording during serialization (typically 50-200ms). Guarantees consistency with minimal memory overhead but introduces brief UI freeze.
    *   **Path C (Sequence Number Validation):** Pass current sequence number to isolate. If document sequence advances during snapshot, discard result and retry. Eventually consistent but may require multiple attempts under heavy editing load.
*   **Default Assumption & Required Action:** The system will implement **Path A (Copy-on-Write)** with memory pressure monitoring. If available RAM < 500MB during snapshot attempt, defer to next opportunity or prompt user to close other documents. **The specification must be updated** to define snapshot thread safety guarantees, specify memory requirements for background execution (recommend: 2x current document size + 200MB headroom), and document retry/fallback behavior if snapshot creation fails.

---

#### **Assertion 5: AI File Import Feature Completeness vs. Implementation Cost**

*   **Observation:** FR-021 scopes AI import to "PDF-compatible AI 9.0+ with Tier 1 features" but the specification's unlimited resources assumption (v3.5 changelog) suggests all features ship with MVP, creating tension with the "easiest and most common" import philosophy.
*   **Architectural Impact:** Expanding AI import beyond Tier 1 (basic paths/shapes) to Tier 2 (gradients, masks, compound paths) significantly increases parser complexity and edge case handling.
    *   **Tier 1 Only (Conservative):** Parse basic vector primitives (paths, rectangles, ellipses, fills, strokes). Implementation: 3-5 days. Covers 60-70% of simple AI file import use cases. Clear limitations documented.
    *   **Tier 1 + Tier 2 (Comprehensive):** Add gradient parsing, clipping mask support, compound path handling. Implementation: 10-15 days including edge case testing. Covers 85-90% of AI file imports. Higher risk of partial import failures.
    *   **Full AI Specification (Aspirational):** Attempt to parse all AI features including blend modes, live effects, symbols. Implementation: 30-60 days with high failure risk. Unrealistic given AI's proprietary format complexity.
*   **Default Assumption & Required Action:** Given the specification's "unlimited resources" scope and Tier 2 features explicitly marked as "INCLUDED in MVP" (Section 9.2, Ambiguity 4 Resolution), the system will implement **Tier 1 + Tier 2 (Comprehensive)**. **The specification must be updated** to clearly define the boundary between "supported with high fidelity" (Tier 1+2) and "best-effort import with degradation warnings" (Tier 3+). Recommend adding explicit acceptance criteria: "AI import must successfully parse and render 85%+ of test corpus (20 representative AI files from Illustrator CS6-CC 2024) with warnings for unsupported features."

---

#### **Assertion 6: History Replay Timeline Scrubber Performance Model**

*   **Observation:** The specification includes History Replay UI as in-scope for MVP (Section 5.2, v3.5 changelog) with "5K events/second replay rate" target (NFR-PERF-002) but does not define rendering strategy for timeline scrubbing with 100K+ event documents.
*   **Architectural Impact:** Naive event-by-event replay during scrubbing will cause catastrophic performance degradation. Real-time scrubbing requires intelligent caching and interpolation strategies.
    *   **Path A (Snapshot Checkpoints):** Pre-generate snapshots every 1,000 events during document load. Scrubbing seeks to nearest checkpoint then replays forward. Memory overhead: ~50-100MB for 100K event document. Scrub latency: <50ms.
    *   **Path B (Keyframe + Interpolation):** Identify "keyframe" events (object creation, major transformations) and interpolate intermediate states during scrubbing. Requires event type classification and interpolation logic. Minimal memory overhead but complex implementation.
    *   **Path C (Lazy Evaluation):** Only replay events when user pauses scrubbing or plays at <2x speed. During fast scrubbing (10x+), show wireframe approximations or skip intermediate frames. Simplest implementation but degraded UX during high-speed replay.
*   **Default Assumption & Required Action:** The architecture will implement **Path A (Snapshot Checkpoints)** with lazy snapshot generation (created on first timeline scrub, not at document load). This balances performance with memory efficiency. **The specification must be updated** to define history replay performance targets for large documents: "Timeline scrubbing with 100K events must maintain 30fps UI responsiveness" and "Replay from arbitrary timeline position must start within 100ms (snapshot seek + incremental replay)."

---

#### **Assertion 7: Arrow Key Nudging Precision Threshold & Zoom Automation**

*   **Observation:** FR-050 defines intelligent zoom suggestion when user overshoots target (3+ direction reversals) but does not specify the precision threshold where nudging becomes impractical or auto-zoom should be mandatory rather than suggested.
*   **Architectural Impact:** At extreme zoom levels (0.01x - viewing entire artboard) or pixel-perfect precision work (400%+ zoom), 1px screen-space nudging may be insufficient or excessive.
    *   **Path A (Fixed Screen-Space Nudging):** Always nudge 1px screen space regardless of zoom. Simple, consistent behavior. At 0.1x zoom, 1px screen = 10px world (coarse). At 800% zoom, 1px screen = 0.125px world (sub-pixel precision).
    *   **Path B (Adaptive Nudging):** Adjust nudge distance based on current zoom level. At <50% zoom, nudge 2px screen. At >400% zoom, nudge 0.5px screen. More intuitive but adds complexity and user confusion about "how far will this move."
    *   **Path C (Mandatory Zoom Gates):** Disable arrow key nudging below 25% zoom (force marquee selection) and above 800% zoom (force direct manipulation). Nudging only available in "reasonable precision" range.
*   **Default Assumption & Required Action:** The system will implement **Path A (Fixed Screen-Space)** as specified, with intelligent zoom suggestions remaining advisory (toast notification, not blocking). This maintains predictable behavior across all zoom levels. **The specification must be updated** to define zoom level boundaries where nudging is recommended vs. discouraged, and specify fallback interaction model for extreme zoom levels (e.g., "Below 10% zoom, arrow keys pan viewport instead of nudging objects").

---

### **4.0 Next Steps**

Upon the user's update of the original specification document, the development process will be unblocked and can proceed to the architectural design phase.
