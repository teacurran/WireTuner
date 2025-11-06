# System Architecture Blueprint: WireTuner

**Version:** 1.0
**Date:** 2025-11-05

---

<!-- anchor: design-rationale -->
## 4. Design Rationale & Trade-offs

<!-- anchor: key-decisions -->
### 4.1. Key Decisions Summary

This section consolidates the most critical architectural decisions and their justifications.

<!-- anchor: decision-event-sourcing -->
#### Decision 1: Event Sourcing Architecture

**Choice**: Implement full event sourcing with 50ms sampling for user interactions

**Rationale:**
1. **Infinite Undo/Redo**: Natural consequence of event history navigation
2. **Audit Trail**: Complete workflow reconstruction for debugging and analysis
3. **Future Collaboration**: Events are inherently distributable for multi-user editing
4. **State Recovery**: Robust crash recovery via snapshots + events
5. **Time Travel Debugging**: Inspect document state at any point in history

**Trade-offs:**
- **Complexity**: More complex than traditional CRUD (requires event handlers, replay engine, snapshots)
- **Storage Overhead**: Event log grows unbounded (mitigated by snapshots, optional compaction)
- **Initial Learning Curve**: Developers unfamiliar with event sourcing need time to adapt

**Alternatives Considered:**
- **Command Pattern with Undo Stack**: Simpler but doesn't provide audit trail or collaboration foundation
- **Full Event Sourcing (no sampling)**: Too many events for high-frequency input (drag = 200+ events/second)
- **No Undo/Redo**: Unacceptable for professional vector editor

**Verdict**: Benefits outweigh costs. Event sourcing is the right foundation for WireTuner's long-term vision.

---

<!-- anchor: decision-flutter -->
#### Decision 2: Flutter Desktop Framework

**Choice**: Use Flutter for cross-platform desktop development

**Rationale:**
1. **Single Codebase**: Maintain one codebase for macOS and Windows (future: Linux)
2. **Performance**: CustomPainter provides direct canvas access, capable of 60 FPS rendering
3. **Modern UI**: Declarative widget-based UI, hot reload for rapid iteration
4. **Ecosystem**: Strong package ecosystem (SQLite, PDF, XML, file I/O)
5. **Proven Success**: Rive (vector animation tool) demonstrates Flutter's suitability

**Trade-offs:**
- **Binary Size**: Flutter apps are larger than native apps (~40-60 MB vs. ~5-10 MB)
- **Platform Integration**: Some platform-specific features require plugins or FFI
- **Maturity**: Flutter desktop is newer than mobile (but stable as of Flutter 3.0+)

**Alternatives Considered:**
- **Electron + Web Canvas**: Rejected due to larger memory footprint and slower rendering
- **Native (Swift/Cocoa + C++/Win32)**: Rejected due to code duplication and maintenance burden
- **Qt/C++**: Rejected due to less modern development experience and licensing complexity

**Verdict**: Flutter provides the best balance of performance, developer productivity, and cross-platform reach.

---

<!-- anchor: decision-sqlite -->
#### Decision 3: SQLite for Event Storage & File Format

**Choice**: Use SQLite as the native .wiretuner file format

**Rationale:**
1. **Embedded**: No separate database server, zero configuration
2. **ACID Guarantees**: Ensures event log integrity even during crashes
3. **Portable**: .wiretuner files are standard SQLite databases, readable with any SQLite tool
4. **Performance**: More than adequate for 50ms sampling rate (20 events/second max)
5. **Battle-Tested**: SQLite is the most deployed database engine globally

**Trade-offs:**
- **Not Text-Based**: Unlike JSON/XML, binary format (but SQLite's ubiquity mitigates this)
- **Single-User**: SQLite not designed for concurrent access (acceptable for desktop app)
- **File Size**: Potentially larger than custom binary format (mitigated by snapshot compression)

**Alternatives Considered:**
- **JSON File + Append-Only Log**: Simpler but no ACID guarantees, harder to query
- **Custom Binary Format**: More compact but requires custom serialization, less tooling
- **PostgreSQL**: Overkill, requires server, not portable

**Verdict**: SQLite is the ideal choice for a local-first desktop application.

---

<!-- anchor: decision-immutability -->
#### Decision 4: Immutable Data Patterns

**Choice**: All domain models (Document, Path, Shape, etc.) are immutable

**Rationale:**
1. **Predictable State**: Every event produces a new document version, no hidden mutations
2. **Thread-Safe**: Immutable objects safe to share across isolates (future: background rendering)
3. **Simplified Testing**: Pure functions easier to test, no setup/teardown of mutable state
4. **Event Sourcing Synergy**: Natural fit for event sourcing (each event = state transition)

**Trade-offs:**
- **Memory Overhead**: Copying objects on every change (mitigated by structural sharing)
- **Performance**: Slightly slower than in-place mutation (but negligible for document-level objects)
- **Boilerplate**: `copyWith()` methods on every class (mitigated by Freezed code generation)

**Alternatives Considered:**
- **Mutable Models**: Simpler, faster, but harder to reason about and test
- **Copy-on-Write Structures**: Custom implementation complex, Dart's built-in sharing sufficient

**Verdict**: Immutability is a cornerstone of robust, maintainable architecture.

---

<!-- anchor: decision-50ms-sampling -->
#### Decision 5: 50ms Event Sampling Rate

**Choice**: Sample high-frequency user input (mouse drag) at 50ms intervals

**Rationale:**
1. **Reduce Event Volume**: 2-second drag = 40 events instead of 200+ (at 100 Hz mouse input)
2. **Smooth Replay**: 20 events/second sufficient for visually smooth playback
3. **Storage Efficiency**: Smaller event logs, faster replay
4. **Performance**: Less strain on SQLite write throughput

**Trade-offs:**
- **Fidelity Loss**: Not capturing every mouse position (acceptable for workflow reconstruction)
- **Non-Deterministic**: Two users dragging identically may produce slightly different event sequences
- **Replay Smoothness**: Interpolation may be needed for buttery-smooth replay (future enhancement)

**Alternatives Considered:**
- **No Sampling (Full Fidelity)**: Too many events, storage bloat, replay performance issues
- **100ms Sampling**: Noticeably choppy replay (10 events/second)
- **Adaptive Sampling**: Complex, e.g., sample faster during rapid movement (over-engineering for 0.1)

**Verdict**: 50ms is the sweet spot for balancing fidelity, storage, and performance.

---

<!-- anchor: decision-snapshot-frequency -->
#### Decision 6: Snapshot Every 1000 Events

**Choice**: Create document snapshots every 1000 events

**Rationale:**
1. **Replay Performance**: Avoid replaying entire history (10,000 events = ~1 minute)
2. **Fast Document Loading**: Load snapshot + recent events (~50-100ms)
3. **Reasonable Overhead**: 1000 events ≈ 5-10 minutes of active editing

**Trade-offs:**
- **Storage**: Each snapshot ~10 KB - 1 MB (compressed)
- **Snapshot Overhead**: Serialization time (~10-20ms per snapshot)

**Alternatives Considered:**
- **Time-Based Snapshots** (every 5 minutes): Unpredictable number of events, less deterministic
- **Snapshot Every 100 Events**: Too frequent, wasted storage
- **Snapshot Every 10,000 Events**: Too infrequent, slow document loading

**Verdict**: 1000 events is empirically balanced (may tune based on real-world usage).

---

<!-- anchor: decision-provider-state-mgmt -->
#### Decision 7: Provider for State Management

**Choice**: Use Flutter Provider package for UI state management

**Rationale:**
1. **Simplicity**: Adequate for single-user desktop app, minimal boilerplate
2. **Flutter-Native**: Official recommendation, excellent documentation
3. **Sufficient**: Event sourcing handles time-travel, Provider handles UI reactivity

**Trade-offs:**
- **Not as Powerful**: BLoC or Riverpod offer more features (but not needed for 0.1)
- **Manual notifyListeners**: Developer must remember to call (mitigated by linting rules)

**Alternatives Considered:**
- **BLoC**: More powerful but heavier boilerplate, overkill for desktop app
- **Riverpod**: Modern, but Provider sufficient for current needs
- **GetX**: Too magical, hides complexity

**Verdict**: Provider is the right level of abstraction for WireTuner's needs.

---

<!-- anchor: alternatives-considered -->
### 4.2. Alternatives Considered

<!-- anchor: alt-architecture-styles -->
#### Architecture Styles

| Alternative | Why Considered | Why Rejected |
|-------------|----------------|--------------|
| **Microservices** | Modularity, independent scaling | Overkill for single-user desktop app, deployment complexity |
| **Full CQRS** | Separate read/write models | Over-engineering, event sourcing provides sufficient separation |
| **Traditional MVC** | Simplicity, familiarity | No natural undo/redo support, would need custom undo system |
| **Plugin-Based Architecture** | Extensibility | Deferred to post-0.1, adds complexity without immediate value |

<!-- anchor: alt-frameworks -->
#### Frameworks & Languages

| Alternative | Why Considered | Why Rejected |
|-------------|----------------|--------------|
| **Electron** | Web tech familiarity, cross-platform | Larger memory footprint, slower rendering vs. Flutter |
| **Qt/C++** | Native performance, cross-platform | Older dev experience, licensing (LGPL/Commercial), slower iteration |
| **Native (Swift + C++)** | Best platform integration | Code duplication for macOS/Windows, higher maintenance burden |
| **Tauri (Rust + Web)** | Lightweight alternative to Electron | Rust learning curve, less mature ecosystem for desktop |

<!-- anchor: alt-databases -->
#### Data Storage

| Alternative | Why Considered | Why Rejected |
|-------------|----------------|--------------|
| **JSON File + Append Log** | Human-readable, simple | No ACID, hard to query, no crash protection |
| **Custom Binary Format** | Compact, fast | Reinventing the wheel, no tooling, high development cost |
| **PostgreSQL** | Powerful querying | Requires server, not portable, overkill for single-user |
| **LevelDB/RocksDB** | Fast key-value store | No SQL, harder to query event history |

<!-- anchor: alt-rendering -->
#### Rendering Approaches

| Alternative | Why Considered | Why Rejected |
|-------------|----------------|--------------|
| **WebGL/OpenGL** | GPU acceleration | Complexity, Flutter CustomPainter sufficient for vector graphics |
| **Skia Direct API** | Lower-level control | Unnecessary, CustomPainter built on Skia already |
| **HTML5 Canvas (Electron)** | Web compatibility | Slower than native canvas, Electron rejected |

---

<!-- anchor: known-risks -->
### 4.3. Known Risks & Mitigation

<!-- anchor: risk-performance -->
#### Risk 1: Rendering Performance with Large Documents

**Risk**: Rendering 10,000+ objects at 60 FPS may be challenging

**Likelihood**: Medium (depends on object complexity and user hardware)

**Impact**: High (poor UX, user frustration)

**Mitigation:**
1. **Viewport Culling**: Only render visible objects (implemented in Phase 3)
2. **Level of Detail**: Simplify rendering when zoomed out
3. **Caching**: Cache rendered paths when not actively editing
4. **Profiling**: Continuous performance testing during development
5. **Progressive Rendering**: Render high-priority objects first, low-priority later (future)

**Contingency**: If targets not met, implement more aggressive optimizations (e.g., WebGL rendering, object instancing).

---

<!-- anchor: risk-file-size -->
#### Risk 2: Event Log File Size Bloat

**Risk**: Documents with long editing sessions may produce very large .wiretuner files (100 MB+)

**Likelihood**: Medium (power users, complex projects)

**Impact**: Medium (slow loading, file sharing difficult)

**Mitigation:**
1. **Snapshots**: Reduce replay time (already planned)
2. **Event Compaction**: Optional "compress history" feature to remove intermediate sampled events (future)
3. **Snapshot Compression**: Gzip snapshots (10:1 compression typical)
4. **User Education**: Warn users when file size exceeds threshold, offer compaction

**Contingency**: Implement binary event encoding (Protocol Buffers) if JSON proves too verbose.

---

<!-- anchor: risk-flutter-desktop-maturity -->
#### Risk 3: Flutter Desktop Maturity Issues

**Risk**: Flutter desktop has platform-specific bugs or missing features

**Likelihood**: Low-Medium (Flutter 3.0+ is stable, but edge cases exist)

**Impact**: Medium-High (blocking issues, workarounds needed)

**Mitigation:**
1. **Early Testing**: Test on both macOS and Windows early in development
2. **Plugin Fallbacks**: Use platform channels for critical features if plugins fail
3. **Community Engagement**: Active in Flutter desktop community, report bugs upstream
4. **Contingency Plan**: If critical blocker, consider Qt/C++ rewrite (extreme case)

**Current Status**: Flutter desktop is production-ready as of 3.0+, major apps (e.g., Google Photos, Ubuntu installer) use it.

---

<!-- anchor: risk-import-export-complexity -->
#### Risk 4: AI/SVG Import Complexity

**Risk**: Adobe Illustrator and SVG files are complex, full support may be difficult

**Likelihood**: High (both formats have extensive feature sets)

**Impact**: Medium (partial import support may frustrate users)

**Mitigation:**
1. **Phased Support**: Import basic shapes and paths first, defer advanced features (gradients, masks, etc.)
2. **Clear Limitations**: Document which features are supported
3. **Error Reporting**: Show warnings for unsupported elements during import
4. **Reference Libraries**: Use existing parsers (pdf package for AI, xml for SVG) rather than custom

**Contingency**: Clearly communicate limitations, focus on 80% use case (basic vector shapes and paths).

---

<!-- anchor: risk-single-developer -->
#### Risk 5: Single Developer Bottleneck

**Risk**: One person responsible for all development, testing, documentation

**Likelihood**: Guaranteed

**Impact**: High (slower progress, no peer review, knowledge silos)

**Mitigation:**
1. **Comprehensive Documentation**: Architecture docs, code comments, ticket descriptions
2. **Test Coverage**: 80%+ unit test coverage to catch regressions
3. **Self-Review Checklist**: Formal checklist before merging code
4. **Community Involvement**: Open-source project, invite contributors for code review
5. **Time Management**: Realistic estimates, avoid burnout, sustainable pace

**Contingency**: If blocked, seek community help via GitHub issues, Flutter forums, Discord.

---

<!-- anchor: future-considerations -->
## 5. Future Considerations

<!-- anchor: potential-evolution -->
### 5.1. Potential Evolution

<!-- anchor: evolution-collaboration -->
#### Collaborative Editing (Post-Milestone 1.0)

**Vision**: Multiple users editing the same document simultaneously

**Architectural Fit**: Event sourcing is inherently collaboration-friendly
- **Events are Messages**: Each user's events broadcast to others via WebSocket/WebRTC
- **Conflict Resolution**: Operational Transform (OT) or CRDT to merge concurrent edits
- **User Identity**: Add `user_id` field to events (already in schema)

**Required Changes:**
1. **Sync Service**: WebSocket server for event distribution
2. **Conflict Resolution**: OT/CRDT algorithms for path edits
3. **User Presence**: Real-time cursor positions, selection highlights
4. **Authentication**: User accounts, session management

**Timeline**: 6-12 months post-0.1

---

<!-- anchor: evolution-cloud-sync -->
#### Cloud Storage & Sync (Post-Milestone 0.2)

**Vision**: Save .wiretuner files to cloud, sync across devices

**Architectural Fit**: SQLite files are self-contained, easy to sync
- **Conflict Resolution**: File-level locking or event-based merge (if collaborative editing implemented)
- **Storage Backend**: AWS S3, Dropbox API, Google Drive API

**Required Changes:**
1. **Cloud Provider Integration**: OAuth, file upload/download APIs
2. **Sync Logic**: Detect local vs. remote changes, merge or prompt user
3. **Offline Support**: Queue events while offline, sync when reconnected

**Timeline**: 3-6 months post-0.1

---

<!-- anchor: evolution-plugins -->
#### Plugin System (Post-Milestone 1.0)

**Vision**: Third-party developers extend WireTuner with custom tools, importers, exporters

**Architectural Fit**: Tool system already abstracted (`ITool` interface)
- **Plugin API**: Expose tool registration, event system, rendering hooks
- **Sandboxing**: Run plugins in isolates or separate processes (security)
- **Package Manager**: Install plugins via UI (like VS Code extensions)

**Required Changes:**
1. **Plugin API Definition**: Public Dart API for tool/importer/exporter development
2. **Plugin Loader**: Dynamically load plugins from user directory
3. **Security**: Sandbox plugins, permission system
4. **Marketplace**: Plugin discovery and installation UI

**Timeline**: 12+ months post-0.1

---

<!-- anchor: evolution-advanced-features -->
#### Advanced Vector Editing Features (Ongoing)

**Post-0.1 Feature Roadmap:**

**Phase 10: Text Editing (v0.2)**
- Text tool, font rendering, text-on-path
- **Complexity**: High (text layout engines are complex)
- **Timeline**: 3-4 weeks

**Phase 11: Layer Management (v0.3)**
- Layer panel, layer visibility/locking, layer groups
- **Complexity**: Medium (UI-heavy)
- **Timeline**: 2-3 weeks

**Phase 12: Boolean Path Operations (v0.4)**
- Union, Intersect, Subtract, Exclude for paths
- **Complexity**: Very High (computational geometry algorithms)
- **Timeline**: 4-6 weeks

**Phase 13: Gradients & Effects (v0.5)**
- Linear/radial gradients, drop shadows, blur
- **Complexity**: Medium (rendering complexity)
- **Timeline**: 2-3 weeks

**Phase 14: Artboard & Export Presets (v0.6)**
- Multiple artboards per document, export presets for web/print
- **Complexity**: Medium
- **Timeline**: 2 weeks

---

<!-- anchor: evolution-platforms -->
#### Platform Expansion (Long-Term)

**Flutter Web (v1.5+)**
- Deploy WireTuner as web app (PWA)
- **Trade-offs**: Slower rendering, limited file system access
- **Use Case**: Lightweight editing, demos, education

**Flutter Mobile (v2.0+)**
- iOS/Android version with touch-optimized UI
- **Trade-offs**: Smaller screens, different interaction patterns
- **Use Case**: Sketching, on-the-go edits, sync with desktop

**Linux Desktop (v0.8)**
- Relatively easy addition to macOS/Windows support
- **Timeline**: 1-2 weeks (mostly testing)

---

<!-- anchor: deeper-dive-areas -->
### 5.2. Areas for Deeper Dive

The following areas require more detailed design before implementation:

<!-- anchor: deep-dive-geometry -->
#### 1. Geometry Engine Details

**Current**: High-level interfaces defined (hit testing, bounds calculation, Bezier math)

**Needs Design:**
- **Bezier Curve Algorithms**: De Casteljau, curve subdivision, arc-length parameterization
- **Intersection Detection**: Path-path, path-rect for selection
- **Boolean Operations**: Weiler-Atherton algorithm for path unions/intersections
- **Tessellation**: Converting Bezier curves to line segments for rendering

**Resources:**
- Primer on Bezier Curves (https://pomax.github.io/bezierinfo/)
- Computational Geometry: Algorithms and Applications (book)

---

<!-- anchor: deep-dive-undo-redo-ui -->
#### 2. Undo/Redo UI/UX Design

**Current**: Event navigation enables undo/redo programmatically

**Needs Design:**
- **Undo Grouping**: Should 40 MoveAnchor events from a drag be one undo action or 40?
- **UI Feedback**: Show action names in Edit > Undo menu ("Undo Move Anchor")
- **History Panel**: Visual timeline of actions (like Photoshop history panel)
- **Branch Management**: If user undoes and then takes new action, what happens to "redo" branch?

**Approach:**
- **Undo Groups**: Group events by tool action (e.g., all events between tool activate/deactivate)
- **Action Naming**: Derive human-readable names from event sequences ("Move Object", "Create Rectangle")

---

<!-- anchor: deep-dive-selection -->
#### 3. Selection Model & Multi-Selection

**Current**: `Selection` class with object IDs and anchor indices

**Needs Design:**
- **Selection Modes**: Click to select, Shift+Click to add, Cmd+Click to toggle
- **Marquee Selection**: Drag rectangle to select multiple objects
- **Lasso Selection**: Freeform selection path
- **Selection Groups**: Temporary groups for transformation (without creating group object)

**Approach:**
- **Hit Priority**: Anchors > paths > shapes (innermost first)
- **Marquee**: Objects fully inside or intersecting marquee?

---

<!-- anchor: deep-dive-accessibility -->
#### 4. Accessibility Support

**Current**: No specific accessibility considerations

**Needs Design:**
- **Keyboard Navigation**: Tab through objects, arrow keys to adjust properties
- **Screen Reader**: Announce tool changes, selected objects, document structure
- **High Contrast Mode**: Respect OS settings, ensure visibility
- **Alternative Input**: Voice control, eye tracking (very long-term)

**Resources:**
- Flutter Accessibility Guide (https://docs.flutter.dev/development/accessibility-and-localization/accessibility)

---

<!-- anchor: deep-dive-performance-profiling -->
#### 5. Performance Profiling & Optimization Strategy

**Current**: High-level targets (60 FPS, < 2s document load)

**Needs Design:**
- **Profiling Tools**: DevTools, custom performance overlay
- **Bottleneck Identification**: Where are the slow paths? (Rendering? Event replay? Hit testing?)
- **Optimization Techniques**: Batching, caching, spatial indexing (R-tree), level-of-detail
- **Benchmarking**: Standardized test documents for performance regression detection

**Approach:**
- **Continuous Profiling**: Run benchmarks on every PR
- **Performance Budget**: Set maximum frame time, alert if exceeded

---

<!-- anchor: deep-dive-localization -->
#### 6. Internationalization & Localization (i18n/l10n)

**Current**: English-only UI

**Needs Design:**
- **Localization Framework**: Use Flutter's `intl` package, ARB files
- **Languages**: Priority languages (English, Spanish, Chinese, Japanese, German, French)
- **Date/Time Formats**: Respect user's locale settings
- **RTL Support**: Right-to-left languages (Arabic, Hebrew)

**Timeline**: Post-0.1, prioritize based on user demand

---

<!-- anchor: glossary -->
## 6. Glossary

| Term | Definition |
|------|------------|
| **Anchor Point** | A point on a path that defines segment endpoints. May have Bezier control point handles. |
| **BCP** | Bezier Control Point - handles on anchors that define curve shape |
| **C4 Model** | Context, Containers, Components, Code - hierarchical architecture diagram system |
| **CRDT** | Conflict-free Replicated Data Type - data structure for eventual consistency in distributed systems |
| **Custom Painter** | Flutter API for low-level canvas rendering (extends `CustomPainter` class) |
| **Event Sourcing** | Architectural pattern where state changes are captured as immutable events |
| **Immutable** | Object that cannot be modified after creation; changes produce new copies |
| **LOD** | Level of Detail - rendering optimization that simplifies objects based on view distance |
| **OT** | Operational Transform - algorithm for resolving concurrent edits in collaborative systems |
| **Provider** | Flutter state management package based on `InheritedWidget` |
| **Sampling** | Recording events at fixed intervals (50ms) rather than every input change |
| **Segment** | Part of a path between two anchor points (line, Bezier curve, or arc) |
| **Snapshot** | Serialized document state at a specific point in event history |
| **SQLite** | Embedded relational database engine, used for .wiretuner file format |
| **Tessellation** | Converting curves to line segments for rendering |
| **Vector Object** | Generic term for paths, shapes, or other drawable objects in the document |
| **Viewport** | The visible portion of the canvas (affected by pan/zoom) |
| **.wiretuner** | Native file format (SQLite database containing events and snapshots) |

---

<!-- anchor: acronyms -->
### Acronyms

| Acronym | Full Form |
|---------|-----------|
| **ACID** | Atomicity, Consistency, Isolation, Durability (database transaction properties) |
| **AI** | Adobe Illustrator (file format, not Artificial Intelligence in this context) |
| **API** | Application Programming Interface |
| **BCP** | Bezier Control Point |
| **BLOB** | Binary Large Object (database data type) |
| **CI/CD** | Continuous Integration / Continuous Deployment |
| **CRDT** | Conflict-free Replicated Data Type |
| **CRUD** | Create, Read, Update, Delete (traditional data operations) |
| **DMG** | Disk Image (macOS installer format) |
| **ERD** | Entity-Relationship Diagram |
| **FFI** | Foreign Function Interface (calling native code from Dart) |
| **FPS** | Frames Per Second |
| **I/O** | Input/Output |
| **JSON** | JavaScript Object Notation |
| **LOD** | Level of Detail |
| **NFR** | Non-Functional Requirement |
| **OT** | Operational Transform |
| **PDF** | Portable Document Format |
| **SQLite** | Structured Query Language (Lite) - embedded database |
| **SVG** | Scalable Vector Graphics |
| **UI/UX** | User Interface / User Experience |
| **WAL** | Write-Ahead Logging (SQLite journaling mode) |
| **XML** | Extensible Markup Language |

---

**End of System Architecture Blueprint**

*This document provides a comprehensive architectural foundation for WireTuner. All designs are subject to refinement based on implementation learnings and user feedback.*
