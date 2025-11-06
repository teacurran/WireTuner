# System Architecture Blueprint: WireTuner

**Version:** 1.0
**Date:** 2025-11-05

---

<!-- anchor: cross-cutting-concerns -->
### 3.8. Cross-Cutting Concerns

<!-- anchor: authentication-authorization -->
#### Authentication & Authorization

**Status: Not Applicable for Milestone 0.1**

WireTuner is a single-user desktop application with no authentication requirements in the initial release. All files are stored locally, with access control delegated to the operating system's file permissions.

**Future Considerations (Post-0.1):**
- **Cloud Sync**: If cloud storage integration is added, OAuth 2.0 / OpenID Connect for user authentication
- **Collaboration**: User identity for multi-user editing, JWT tokens for session management
- **File-Level Access**: Encrypted .wiretuner files with password protection
- **License Verification**: Software license validation for commercial releases

**Current Security Posture:**
- Files stored in user's home directory with OS-level permissions
- No network communication, no authentication surface
- Malicious .wiretuner files could execute code only if SQLite has vulnerabilities (mitigated by using well-tested library)

---

<!-- anchor: logging-monitoring -->
#### Logging & Monitoring

<!-- anchor: logging-strategy -->
##### Logging Strategy

**Objectives:**
1. Debug issues reported by users (attach log files to bug reports)
2. Performance monitoring (frame times, event replay duration)
3. Error tracking (crashes, failed file operations)

**Log Levels:**
- **ERROR**: Unrecoverable failures (file I/O errors, corrupted data)
- **WARN**: Recoverable issues (skipped events during replay, missing fonts)
- **INFO**: Key lifecycle events (document loaded, export completed)
- **DEBUG**: Detailed flow (event recorded, tool state changes)
- **TRACE**: Verbose output (every rendered frame, geometry calculations) - disabled in release

**Implementation:**
```dart
// Use 'logger' package
import 'package:logger/logger.dart';

final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2, // Stack trace depth
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    printTime: true,
  ),
  output: MultiOutput([
    ConsoleOutput(), // Stdout during development
    FileOutput(file: File('$appSupportDir/wiretuner.log')), // Persistent log
  ]),
  level: Level.debug, // Release: Level.info
);
```

**Log Rotation:**
- Max log file size: 10 MB
- Keep last 5 log files (wiretuner.log, wiretuner.1.log, ..., wiretuner.4.log)
- Rotate on application start if size exceeded

**Log Location:**
- **macOS**: `~/Library/Application Support/WireTuner/wiretuner.log`
- **Windows**: `%APPDATA%\WireTuner\wiretuner.log`

<!-- anchor: monitoring-metrics -->
##### Performance Monitoring

**Key Metrics:**
1. **Frame Time**: Measure time from `onPaint` call to completion
   - **Target**: < 16.67ms (60 FPS)
   - **Alert**: Log warning if > 33ms (dropped frame)

2. **Event Replay Duration**: Time to load document from snapshot + events
   - **Target**: < 500ms for typical documents
   - **Log**: INFO level on every document load

3. **Event Write Latency**: Time to persist event to SQLite
   - **Target**: < 10ms
   - **Alert**: WARN if > 50ms (disk slow)

4. **Memory Usage**: Track Document object size, event log size
   - **Target**: < 500 MB for in-memory document
   - **Alert**: WARN if > 1 GB (potential leak)

**Implementation:**
```dart
class PerformanceMonitor {
  static final _frameTimesBuffer = <Duration>[];

  static void recordFrameTime(Duration frameTime) {
    _frameTimesBuffer.add(frameTime);
    if (_frameTimesBuffer.length > 60) _frameTimesBuffer.removeAt(0); // Keep last 60 frames

    if (frameTime.inMilliseconds > 33) {
      logger.w('Dropped frame: ${frameTime.inMilliseconds}ms');
    }
  }

  static double get averageFPS {
    if (_frameTimesBuffer.isEmpty) return 0;
    final avgMs = _frameTimesBuffer.map((d) => d.inMilliseconds).reduce((a, b) => a + b) / _frameTimesBuffer.length;
    return 1000 / avgMs;
  }
}
```

**Monitoring UI (Development Mode):**
- Overlay showing FPS, frame time graph, memory usage
- Enable via `Debug → Show Performance Overlay` menu

---

<!-- anchor: security-considerations -->
#### Security Considerations

<!-- anchor: security-threat-model -->
##### Threat Model

**Assets:**
1. User's vector artwork (intellectual property)
2. Application integrity (prevent malicious code execution)
3. User's system resources (prevent DoS via malformed files)

**Threats:**
1. **Malicious .wiretuner Files**: Crafted SQLite database exploiting parser vulnerabilities
2. **Malicious .ai/.svg Imports**: XML/PDF exploits during parsing
3. **File Exfiltration**: Malware reading user's documents (OS-level threat)
4. **Supply Chain**: Compromised Flutter/Dart dependencies

<!-- anchor: security-input-validation -->
##### Input Validation & Sanitization

**SQLite Event Payloads:**
- **Risk**: JSON injection, malicious code in event payloads
- **Mitigation**:
  - Use parameterized queries (prepared statements) for all SQLite operations
  - Validate JSON schema before deserialization
  - Enforce maximum event payload size (100 KB per event)
  - Sanitize string fields (document title, layer names) to prevent XSS-like issues in future web export

**File Import Validation:**
- **SVG/AI Import**:
  - Limit file size (< 100 MB)
  - Parse XML with safe parser (no external entity resolution to prevent XXE attacks)
  - Validate SVG structure against expected schema
  - Sanitize `<script>` tags, `javascript:` URLs, `data:` URIs

- **.wiretuner File Validation**:
  - Check SQLite file integrity (`PRAGMA integrity_check`)
  - Verify format_version compatibility
  - Limit event log size (< 1 million events per document)

**Geometry Calculations:**
- **Risk**: Floating-point edge cases (NaN, Infinity) causing crashes or hangs
- **Mitigation**:
  - Validate all coordinate inputs (`assert(x.isFinite)`)
  - Clamp extreme values (coordinates > ±1e6 rejected)
  - Handle division by zero in geometry functions

<!-- anchor: security-data-protection -->
##### Data Protection

**File Encryption (Future Enhancement):**
- Not implemented in Milestone 0.1
- Future: AES-256 encryption of .wiretuner SQLite databases with user-provided password
- Key derivation: PBKDF2 with 100,000 iterations

**Temporary Files:**
- Export operations may create temp files (e.g., during PDF generation)
- **Mitigation**: Use OS-provided temp directory with restricted permissions, delete files immediately after export

**Clipboard Data:**
- Copy/paste operations expose vector data to system clipboard
- **Risk**: Other applications can read clipboard
- **Mitigation**: Clear clipboard on application exit (optional user preference)

<!-- anchor: security-dependencies -->
##### Dependency Security

**Strategy:**
1. **Pin Versions**: Lock dependency versions in `pubspec.lock`
2. **Audit**: Run `flutter pub outdated` monthly, review changelogs before upgrading
3. **Vulnerability Scanning**: Use GitHub Dependabot / `pub audit` (when available)
4. **Minimal Dependencies**: Prefer Dart-native packages over FFI bindings (smaller attack surface)

**Critical Dependencies:**
- `sqflite_common_ffi`: SQLite binding (well-tested, used by thousands of apps)
- `pdf`: PDF generation (pure Dart, no native code)
- `xml`: XML parsing (safe parser, no external entity resolution)

<!-- anchor: security-code-practices -->
##### Secure Coding Practices

1. **Null Safety**: Dart 3.0+ null safety enforced (`sound null safety`)
2. **Immutability**: Prevents unintended state mutations, reduces concurrency bugs
3. **Type Safety**: Strong typing catches errors at compile time
4. **Code Review**: All commits reviewed before merge (single developer: self-review checklist)
5. **Static Analysis**: Dart analyzer with strict rules (`analysis_options.yaml`)

**Example Analysis Rules:**
```yaml
linter:
  rules:
    - avoid_dynamic_calls
    - avoid_returning_null_for_void
    - avoid_slow_async_io
    - cancel_subscriptions
    - close_sinks
    - no_adjacent_strings_in_list
    - prefer_const_constructors
    - unnecessary_null_checks
```

---

<!-- anchor: scalability-performance -->
#### Scalability & Performance

<!-- anchor: scalability-document-size -->
##### Scalability Targets

**Document Complexity:**
- **Target**: Support documents with 10,000+ objects without degradation
- **Performance**: Maintain 60 FPS pan/zoom at 5,000 objects
- **Memory**: < 500 MB RAM for typical documents (1,000 objects)

**Event Log Size:**
- **Target**: Gracefully handle 100,000+ events (several hours of work)
- **Snapshot Frequency**: Every 1,000 events (balance replay speed vs. storage)
- **Replay Performance**: Load document in < 2 seconds even with 100,000 events (via snapshots)

**File Size:**
- **Typical**: 1-10 MB for moderate documents (1,000 objects, 10,000 events)
- **Large**: 50-100 MB for complex documents (10,000 objects, 100,000 events)
- **Maximum**: Gracefully handle files up to 500 MB (warn user if approaching limit)

<!-- anchor: performance-rendering -->
##### Rendering Performance Optimizations

**1. Viewport Culling:**
```dart
// Only render objects within visible viewport + margin
List<VectorObject> getVisibleObjects(Viewport viewport) {
  final visibleBounds = viewport.visibleBounds.inflate(100); // 100px margin
  return document.getAllObjects().where((obj) {
    return obj.bounds().intersects(visibleBounds);
  }).toList();
}
```

**2. Level of Detail (LOD):**
- When zoomed out (zoom < 0.25), simplify paths:
  - Skip rendering very small objects (< 2px on screen)
  - Reduce Bezier tessellation quality
  - Omit stroke details

**3. Dirty Region Tracking:**
- Track which objects changed since last frame
- Only repaint dirty regions (Flutter's `RepaintBoundary` optimization)

**4. Path Caching:**
- Cache tessellated Path objects (converted to screen coordinates)
- Invalidate cache on zoom/pan or object modification

**5. Offscreen Rendering:**
- For complex groups, render to cached raster image when not being edited
- Fall back to vector rendering when user selects the object

<!-- anchor: performance-event-system -->
##### Event System Performance

**1. Event Sampling:**
- 50ms sampling reduces drag operations from 200+ events to ~40 events/2 seconds
- Trade-off: Slightly less smooth replay, but acceptable for workflow reconstruction

**2. Snapshot Strategy:**
- **Frequency**: Every 1,000 events
- **Compression**: Gzip snapshots to reduce storage (typical 10:1 compression)
- **Selective Snapshotting**: Only snapshot when document has changed significantly

**3. Batch Event Writes:**
- Buffer events during rapid interactions (e.g., drag)
- Write to SQLite in batches every 100ms to reduce transaction overhead

**4. Lazy Event Replay:**
- When navigating to specific event sequence (undo/redo), find nearest snapshot
- Only replay events between snapshot and target, not from beginning

<!-- anchor: performance-memory -->
##### Memory Management

**1. Immutable Data Sharing:**
- Dart's copy-on-write for lists and maps
- Unchanged sub-trees shared between document versions

**2. Event Pruning (Future):**
- Optionally "compact" event history: remove intermediate sampled events for completed actions
- Example: 40 MoveAnchor events for a drag → single MoveAnchor event with final position
- Trade-off: Lose fine-grained replay, but reduce file size

**3. Snapshot Garbage Collection:**
- Keep only last N snapshots (default: 10)
- Delete old snapshots to limit file size growth

---

<!-- anchor: reliability-availability -->
#### Reliability & Availability

<!-- anchor: reliability-fault-tolerance -->
##### Fault Tolerance

**Crash Recovery:**
- **Automatic Saving**: Events persisted to SQLite immediately (no manual save required for event log)
- **Recovery Flow**: On restart after crash, load last valid document state from snapshot + events
- **Corrupted Files**: If .wiretuner file corrupted, attempt to load last valid snapshot (skip corrupted events)

**Undo/Redo Safety:**
- Immutable event log ensures undo/redo never corrupts document
- No "redo stack" to manage (navigate forward in event history)

**File Format Resilience:**
- SQLite's ACID properties ensure atomic writes (no partial events)
- `PRAGMA journal_mode=WAL` (Write-Ahead Logging) prevents corruption during crashes

<!-- anchor: reliability-data-integrity -->
##### Data Integrity

**Event Log Integrity:**
- **Checksums**: SQLite's internal page checksums detect corruption
- **Validation**: On document load, verify event sequence numbers are contiguous
- **Error Handling**: If gap detected, warn user and skip to next valid event

**Snapshot Integrity:**
- **Versioning**: Each snapshot tagged with format version
- **Validation**: Deserialize snapshot, check for null fields, validate object IDs

**Export Integrity:**
- **SVG Validation**: Validate generated SVG against SVG 1.1 schema before writing
- **PDF Validation**: Check PDF structure integrity (valid xref table, trailer)

<!-- anchor: reliability-testing -->
##### Reliability Testing Strategy

**1. Crash Simulation:**
- Unit tests that kill process mid-transaction, verify recovery on restart
- Corrupt SQLite file, verify graceful degradation

**2. Stress Testing:**
- Create documents with 50,000 objects, measure performance
- Replay 500,000 events, measure time and memory usage

**3. Fuzz Testing:**
- Generate malformed .wiretuner files (invalid JSON, out-of-order events)
- Verify app doesn't crash, shows appropriate error messages

**4. Platform-Specific Testing:**
- Test on low-end hardware (2014 MacBook Air, budget Windows laptop)
- Verify performance targets met on minimum spec

---

<!-- anchor: deployment-view -->
### 3.9. Deployment View

<!-- anchor: deployment-target-env -->
#### Target Environment

**Desktop Platforms:**
- **macOS**: 10.15 (Catalina) or later (Intel + Apple Silicon)
- **Windows**: Windows 10 version 1809 or later (x64)

**No Server Components**: Fully offline desktop application, no cloud services

<!-- anchor: deployment-strategy -->
#### Deployment Strategy

<!-- anchor: deployment-build-process -->
##### Build Process

**macOS:**
```bash
# Release build
flutter build macos --release

# Output: build/macos/Build/Products/Release/WireTuner.app

# Packaging (DMG creation)
# - Use create-dmg or appdmg tools
# - Sign app bundle with Developer ID certificate (for notarization)
# - Notarize with Apple (required for macOS 10.15+)

# Sign
codesign --deep --force --verify --verbose --sign "Developer ID Application: [Name]" \
  build/macos/Build/Products/Release/WireTuner.app

# Notarize
xcrun notarytool submit WireTuner.dmg --wait --apple-id [email] --password [app-specific-password]

# Staple ticket
xcrun stapler staple WireTuner.dmg
```

**Windows:**
```bash
# Release build
flutter build windows --release

# Output: build\windows\runner\Release\

# Packaging (Installer creation)
# Option 1: MSIX (Windows Store / sideloading)
flutter pub run msix:create

# Option 2: Inno Setup (traditional .exe installer)
# - Create Inno Setup script (.iss)
# - Sign executable with code signing certificate
# - Build installer

# Sign
signtool sign /f certificate.pfx /p password /tr http://timestamp.digicert.com \
  /td sha256 /fd sha256 build\windows\runner\Release\wiretuner.exe
```

<!-- anchor: deployment-distribution -->
##### Distribution Channels

**Phase 1 (Milestone 0.1 - Internal Testing):**
- Direct download links (GitHub Releases)
- No app store distribution

**Phase 2 (Post-0.1 - Public Beta):**
- Website download page (wiretuner.com/download)
- GitHub Releases for open-source distribution

**Phase 3 (Future - Production):**
- macOS: Distribute via .dmg file (notarized), potentially Mac App Store
- Windows: Distribute via .exe installer (signed), potentially Microsoft Store

<!-- anchor: deployment-ci-cd -->
##### CI/CD Pipeline (GitHub Actions)

**Workflow Overview:**
```yaml
# .github/workflows/build.yml
name: Build & Test

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test --coverage
      - uses: codecov/codecov-action@v3

  build-macos:
    runs-on: macos-latest
    needs: test
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter build macos --release
      - name: Create DMG
        run: |
          # DMG creation script
      - uses: actions/upload-artifact@v3
        with:
          name: WireTuner-macOS.dmg
          path: build/macos/*.dmg

  build-windows:
    runs-on: windows-latest
    needs: test
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter build windows --release
      - name: Create Installer
        run: |
          # Inno Setup script
      - uses: actions/upload-artifact@v3
        with:
          name: WireTuner-Windows-Setup.exe
          path: build/windows/*.exe
```

<!-- anchor: deployment-updates -->
##### Application Updates

**Milestone 0.1**: No auto-update mechanism (manual download)

**Future**: Implement update checker
- On startup, check GitHub Releases API for newer version
- Show notification if update available
- Download installer, prompt user to quit and install

---

<!-- anchor: deployment-diagram -->
#### Deployment Diagram

~~~plantuml
@startuml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Deployment.puml

title Deployment Diagram - WireTuner Desktop Application

' User's Device (macOS)
Deployment_Node(mac_device, "MacBook Pro", "macOS 14 Sonoma") {
  Deployment_Node(mac_os, "Operating System", "macOS") {
    Container(wiretuner_mac_app, "WireTuner.app", "Flutter macOS App", "Native macOS application bundle")

    Deployment_Node(app_support, "Application Support", "~/Library/Application Support/WireTuner") {
      ContainerDb(user_documents_mac, ".wiretuner Files", "SQLite Databases", "User's vector documents")
      Container(log_files_mac, "Logs", "wiretuner.log", "Application logs")
    }
  }
}

' User's Device (Windows)
Deployment_Node(win_device, "Windows PC", "Windows 11") {
  Deployment_Node(win_os, "Operating System", "Windows") {
    Container(wiretuner_win_app, "wiretuner.exe", "Flutter Windows App", "Native Windows application")

    Deployment_Node(appdata, "AppData", "%APPDATA%\\WireTuner") {
      ContainerDb(user_documents_win, ".wiretuner Files", "SQLite Databases", "User's vector documents")
      Container(log_files_win, "Logs", "wiretuner.log", "Application logs")
    }
  }
}

' External File System (shared)
Deployment_Node(external_storage, "External Storage", "USB Drive / Cloud Sync") {
  ContainerDb(shared_documents, ".wiretuner Files", "Portable SQLite", "Documents shared between devices")
  Container(exported_files, "Exports", "SVG/PDF Files", "Exported vector graphics")
}

' GitHub (Distribution)
Deployment_Node(github, "GitHub", "Cloud") {
  Container(releases, "Releases", "GitHub Releases", "Signed installers (.dmg, .exe)")
  Container(source_code, "Source Code", "Git Repository", "Open-source codebase")
}

' Developer CI/CD
Deployment_Node(ci_cd, "GitHub Actions", "CI/CD Cloud") {
  Container(build_mac, "macOS Builder", "GitHub Runner", "Builds macOS .dmg")
  Container(build_win, "Windows Builder", "GitHub Runner", "Builds Windows .exe")
  Container(test_runner, "Test Runner", "Ubuntu", "Runs unit/widget tests")
}

' Relationships
Rel(wiretuner_mac_app, user_documents_mac, "Reads/Writes", "File I/O")
Rel(wiretuner_mac_app, log_files_mac, "Writes", "Logging")
Rel(wiretuner_win_app, user_documents_win, "Reads/Writes", "File I/O")
Rel(wiretuner_win_app, log_files_win, "Writes", "Logging")

Rel(wiretuner_mac_app, shared_documents, "Imports/Exports", "File I/O")
Rel(wiretuner_win_app, shared_documents, "Imports/Exports", "File I/O")
Rel(wiretuner_mac_app, exported_files, "Exports to", "SVG/PDF")
Rel(wiretuner_win_app, exported_files, "Exports to", "SVG/PDF")

Rel(build_mac, releases, "Uploads builds to", "HTTPS")
Rel(build_win, releases, "Uploads builds to", "HTTPS")
Rel(test_runner, source_code, "Pulls code from", "Git")

Rel(mac_device, releases, "Downloads installer from", "HTTPS (manual)")
Rel(win_device, releases, "Downloads installer from", "HTTPS (manual)")

SHOW_LEGEND()

@enduml
~~~

---

<!-- anchor: deployment-system-requirements -->
#### System Requirements

**Minimum Requirements:**
- **macOS**: 10.15 (Catalina), 4 GB RAM, 200 MB disk space
- **Windows**: Windows 10 (1809), 4 GB RAM, 200 MB disk space
- **Display**: 1280×720 resolution minimum

**Recommended Requirements:**
- **macOS**: 11.0 (Big Sur) or later, 8 GB RAM, SSD
- **Windows**: Windows 11, 8 GB RAM, SSD
- **Display**: 1920×1080 or higher
- **Input**: Mouse or trackpad (pen tablet supported)

**Performance Expectations:**
- Smooth 60 FPS editing on documents with < 5,000 objects
- Document load time < 2 seconds for typical files
- Export to SVG/PDF < 5 seconds for complex documents
