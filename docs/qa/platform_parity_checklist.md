<!-- anchor: qa-platform-parity -->
# WireTuner Platform Parity QA Checklist

**Version:** 1.0
**Iteration:** I5.T8
**Last Updated:** 2025-11-09
**Status:** Active

---

## Overview

This QA checklist ensures platform parity between macOS and Windows for WireTuner's cross-platform desktop application. It validates that keyboard shortcuts, window chrome, file dialogs, and export functionality behave identically across platforms per Decision 2 (Flutter Desktop Framework) and Decision 6 (Snapshot Every 1000 Events).

**Reference Documentation:**
- [Flutter Desktop Framework Decision](.codemachine/artifacts/architecture/06_Rationale_and_Future.md#decision-flutter)
- [Platform Parity Decision](.codemachine/artifacts/architecture/06_Rationale_and_Future.md#decision-snapshot-frequency)
- [History Panel Usage Guide](../reference/history_panel_usage.md)
- [Verification Strategy](.codemachine/artifacts/plan/03_Verification_and_Glossary.md#verification-and-integration-strategy)

**Scope:**
- Keyboard shortcuts (Cmd vs. Ctrl, Option vs. Alt)
- Window chrome and native UI integration
- File pickers (Open, Save, Export)
- Export functionality (SVG, PDF)
- Undo/Redo behavior across platforms

---

## Table of Contents

- [Automated Test Verification](#automated-test-verification)
- [Manual QA Procedures](#manual-qa-procedures)
  - [macOS Testing](#macos-testing)
  - [Windows Testing](#windows-testing)
- [Platform Parity Matrix](#platform-parity-matrix)
- [File Dialog Parity](#file-dialog-parity)
- [Export Format Parity](#export-format-parity)
- [Performance Benchmarks](#performance-benchmarks)
- [Known Platform Differences](#known-platform-differences)
- [Sign-Off Template](#sign-off-template)

---

## Automated Test Verification

### Prerequisites

- Flutter SDK 3.0+ installed and configured
- Development environment set up per I1 infrastructure
- All dependencies installed (`flutter pub get`)
- Platform-specific tools:
  - **macOS:** Xcode Command Line Tools
  - **Windows:** Visual Studio 2019+ Build Tools

### Test Execution

Run platform parity automated tests:

```bash
# Run platform parity integration tests (auto-detects OS)
flutter test test/integration/platform_parity_test.dart

# Run with platform tag filter (macOS only)
flutter test test/integration/platform_parity_test.dart --tags macos

# Run with platform tag filter (Windows only)
flutter test test/integration/platform_parity_test.dart --tags windows

# Run all integration tests (includes parity checks)
flutter test test/integration/
```

### Expected Results

| Test Suite | Expected Outcome | Pass Criteria |
|------------|------------------|---------------|
| `platform_parity_test.dart` | All tests pass | 100% pass rate on both platforms |
| Keyboard shortcut tests | Platform-specific modifiers work | Cmd (macOS) / Ctrl (Windows) equivalent |
| File dialog tests | Native dialogs appear | Platform-appropriate UI shown |
| SVG export parity | Byte-identical output | MD5 hash match across platforms |
| PDF export parity | Byte-identical output | MD5 hash match across platforms |
| Save/load parity | Round-trip deterministic | File loads identically on both platforms |

**Acceptance Criteria:**
- ✅ All automated tests pass on macOS (CI runner: `macos-latest`)
- ✅ All automated tests pass on Windows (CI runner: `windows-latest`)
- ✅ No platform-conditional skips unless explicitly documented
- ✅ Export outputs are byte-identical (excluding platform metadata)
- ✅ Test execution time < 10 minutes per platform

---

## Manual QA Procedures

### macOS Testing

**Test Environment:**
- macOS 10.15 (Catalina) or later
- Physical device (MacBook Pro/Air) or VM
- Standard Apple keyboard (with Cmd/Option keys)
- External mouse or trackpad

---

#### Test Case M1: Keyboard Shortcuts - File Operations

**Objective:** Verify macOS-specific keyboard shortcuts for file operations.

**Steps:**
1. Launch WireTuner application
2. Test the following shortcuts:

| Action | Shortcut | Expected Behavior |
|--------|----------|-------------------|
| New Document | `Cmd+N` | Creates new blank document |
| Open Document | `Cmd+O` | Shows native macOS file picker |
| Save Document | `Cmd+S` | Saves document (or shows Save dialog if new) |
| Save As | `Cmd+Shift+S` | Shows native Save dialog |
| Export SVG | `Cmd+E` (or menu) | Shows export dialog, filters to .svg |
| Export PDF | (Menu only) | Shows export dialog, filters to .pdf |
| Quit Application | `Cmd+Q` | Quits with unsaved changes prompt |

**Expected:**
- All shortcuts work without conflicts
- Native macOS file dialogs appear (with Finder-style UI)
- File type filters show correct extensions

**Platform-Specific:**
- **macOS:** Cmd key (⌘) used for all shortcuts
- **macOS:** File dialogs show in native macOS style (dark/light mode aware)

**Pass/Fail:** ⬜

---

#### Test Case M2: Keyboard Shortcuts - Undo/Redo/History

**Objective:** Verify undo/redo shortcuts and history panel integration.

**Reference:** [History Panel Usage - Keyboard Shortcuts](../reference/history_panel_usage.md#keyboard-shortcuts)

**Steps:**
1. Create a simple path using pen tool
2. Test undo: Press `Cmd+Z`
3. Verify path is removed
4. Test redo: Press `Cmd+Shift+Z`
5. Verify path is restored
6. Test history panel: Press `Cmd+Shift+H`
7. Verify history panel opens/closes

**Expected:**
- `Cmd+Z` undoes last operation
- `Cmd+Shift+Z` redoes last undone operation
- `Cmd+Shift+H` toggles history panel
- History panel shows correct operation labels
- Shortcuts work regardless of panel visibility

**Platform-Specific:**
- **macOS:** Use `Cmd+Z` / `Cmd+Shift+Z` (NOT `Cmd+Y`)
- **macOS:** Keyboard shortcuts shown in menus with ⌘ symbol

**Pass/Fail:** ⬜

---

#### Test Case M3: Window Chrome and Native Integration

**Objective:** Verify macOS window chrome and native OS integration.

**Steps:**
1. Launch WireTuner
2. Observe window title bar (traffic lights: red/yellow/green)
3. Test red button (close)
4. Test yellow button (minimize)
5. Test green button (maximize/fullscreen)
6. Test dragging window by title bar
7. Verify menu bar integration (WireTuner menu appears in macOS menu bar)
8. Test native macOS menu shortcuts (Cmd+H to hide, etc.)

**Expected:**
- Standard macOS traffic light buttons (top-left)
- Close button prompts to save if unsaved changes
- Minimize collapses to Dock
- Green button enters fullscreen (not just maximize)
- Application menu appears in system menu bar (not in-window)
- Menu shortcuts work (Cmd+H hides, Cmd+M minimizes)

**Platform-Specific:**
- **macOS:** Traffic light buttons (not X/minimize/maximize)
- **macOS:** Fullscreen uses native macOS fullscreen (separate space)
- **macOS:** Menu bar is system-wide (not per-window)

**Pass/Fail:** ⬜

---

#### Test Case M4: File Picker - Open Document

**Objective:** Verify native macOS file picker for opening documents.

**Steps:**
1. Press `Cmd+O` (or File → Open)
2. Observe file picker dialog
3. Verify UI elements:
   - Sidebar with Favorites/Locations
   - File type filter dropdown
   - Preview pane (if available)
   - Search bar
4. Navigate to test directory
5. Filter to `.wiretuner` files
6. Select a test document
7. Click "Open"
8. Verify document loads

**Expected:**
- Native macOS file picker (NSOpenPanel)
- Sidebar shows Favorites, iCloud, Recent, etc.
- File filter shows ".wiretuner" or "All Documents"
- Preview pane shows file info (if macOS supports)
- Search works within current directory
- Dialog respects macOS dark/light mode

**Platform-Specific:**
- **macOS:** Dialog uses NSOpenPanel (system API)
- **macOS:** Follows macOS HIG for file selection

**Pass/Fail:** ⬜

---

#### Test Case M5: File Picker - Save Document

**Objective:** Verify native macOS save dialog.

**Steps:**
1. Create a new document
2. Press `Cmd+S` (or File → Save)
3. Observe save dialog
4. Verify UI elements:
   - Filename text field
   - Location dropdown/browser
   - File format dropdown (if applicable)
   - "Cancel" and "Save" buttons
5. Navigate to test directory
6. Enter filename: `parity_test_macos`
7. Verify file extension appended: `.wiretuner`
8. Click "Save"
9. Verify file created on disk

**Expected:**
- Native macOS save dialog (NSSavePanel)
- Default filename is "Untitled.wiretuner"
- Can navigate directories via dropdown or sheet expansion
- File extension automatically appended
- Dialog shows warning if file exists (overwrite prompt)

**Platform-Specific:**
- **macOS:** Save dialog is a sheet attached to window
- **macOS:** Expand/collapse sheet shows Finder-like browser

**Pass/Fail:** ⬜

---

#### Test Case M6: SVG Export - File Dialog and Output

**Objective:** Verify SVG export uses native dialog and produces valid output.

**Reference:** [SVG Export Test](../../test/integration/svg_export_test.dart)

**Steps:**
1. Create a document with paths and shapes
2. Select File → Export → SVG (or equivalent)
3. Observe export dialog
4. Verify file type filter shows "SVG (*.svg)"
5. Enter filename: `export_test_macos.svg`
6. Click "Export"
7. Verify file created
8. Open exported SVG in:
   - Safari (drag file into browser)
   - Preview.app
   - Adobe Illustrator (if available)
9. Verify rendering matches WireTuner canvas

**Expected:**
- Native macOS save dialog for export
- File extension defaults to `.svg`
- Exported SVG is valid XML
- SVG opens without errors in macOS apps
- Visual rendering matches source document
- File size is reasonable (not bloated)

**Platform-Specific:**
- **macOS:** Export dialog uses NSSavePanel
- **macOS:** Default location is user's Documents folder

**Pass/Fail:** ⬜

---

#### Test Case M7: PDF Export - File Dialog and Output

**Objective:** Verify PDF export uses native dialog and produces valid output.

**Reference:** [PDF Export Test](../../test/integration/pdf_export_test.dart)

**Steps:**
1. Create a document with paths and shapes
2. Select File → Export → PDF (or equivalent)
3. Observe export dialog
4. Verify file type filter shows "PDF (*.pdf)"
5. Enter filename: `export_test_macos.pdf`
6. Click "Export"
7. Verify file created
8. Open exported PDF in:
   - Preview.app (double-click)
   - Adobe Acrobat Reader (if available)
9. Verify rendering matches WireTuner canvas
10. Run `pdfinfo export_test_macos.pdf` (if poppler installed)

**Expected:**
- Native macOS save dialog for export
- File extension defaults to `.pdf`
- Exported PDF is valid (no corruption warnings)
- PDF opens without errors in Preview.app
- Visual rendering matches source document
- PDF metadata includes title, creator ("WireTuner")

**Platform-Specific:**
- **macOS:** Export dialog uses NSSavePanel
- **macOS:** PDF opens in Preview.app by default

**Pass/Fail:** ⬜

---

#### Test Case M8: Application Menu Integration

**Objective:** Verify application menu integrates with macOS menu bar.

**Steps:**
1. Launch WireTuner
2. Observe macOS menu bar (top of screen)
3. Verify menu structure:
   - **WireTuner** (app menu): About, Preferences, Quit
   - **File**: New, Open, Save, Save As, Export, Close
   - **Edit**: Undo, Redo, Cut, Copy, Paste
   - **View**: History Panel, Zoom In/Out
   - **Window**: Minimize, Zoom, Bring All to Front
   - **Help**: WireTuner Help
4. Test keyboard shortcuts shown in menus
5. Verify shortcuts use Cmd symbol (⌘)

**Expected:**
- All menus appear in system menu bar (not in window)
- Menu items show keyboard shortcuts with ⌘ symbol
- Standard macOS app menu items present (About, Preferences, Quit)
- Window menu follows macOS conventions
- Help menu integrates with macOS Help system

**Platform-Specific:**
- **macOS:** Application menu is system-wide
- **macOS:** "WireTuner" menu (app name) is first menu
- **macOS:** Preferences in app menu (not Edit menu)

**Pass/Fail:** ⬜

---

### Windows Testing

**Test Environment:**
- Windows 10 version 1809 or later (x64)
- Physical device or VM
- Standard Windows keyboard (with Ctrl/Alt keys)
- Mouse with scroll wheel

**Modifier Key Mapping:**

| macOS Key | Windows Key | Function |
|-----------|-------------|----------|
| Cmd (⌘) | Ctrl | File operations, undo, shortcuts |
| Option (⌥) | Alt | Menu access, tool modifiers |
| Shift (⇧) | Shift | Identical on both platforms |

---

#### Test Case W1: Keyboard Shortcuts - File Operations

**Objective:** Verify Windows-specific keyboard shortcuts for file operations.

**Steps:**
1. Launch WireTuner application
2. Test the following shortcuts:

| Action | Shortcut | Expected Behavior |
|--------|----------|-------------------|
| New Document | `Ctrl+N` | Creates new blank document |
| Open Document | `Ctrl+O` | Shows native Windows file picker |
| Save Document | `Ctrl+S` | Saves document (or shows Save dialog if new) |
| Save As | `Ctrl+Shift+S` | Shows native Save dialog |
| Export SVG | `Ctrl+E` (or menu) | Shows export dialog, filters to .svg |
| Export PDF | (Menu only) | Shows export dialog, filters to .pdf |
| Quit Application | `Alt+F4` | Quits with unsaved changes prompt |

**Expected:**
- All shortcuts work without conflicts
- Native Windows file dialogs appear
- File type filters show correct extensions
- `Alt+F4` quits application (standard Windows behavior)

**Platform-Specific:**
- **Windows:** Ctrl key used instead of Cmd
- **Windows:** `Alt+F4` quits (not `Ctrl+Q`)
- **Windows:** File dialogs follow Windows UI conventions

**Pass/Fail:** ⬜

---

#### Test Case W2: Keyboard Shortcuts - Undo/Redo/History

**Objective:** Verify undo/redo shortcuts on Windows.

**Reference:** [History Panel Usage - Keyboard Shortcuts](../reference/history_panel_usage.md#keyboard-shortcuts)

**Steps:**
1. Create a simple path using pen tool
2. Test undo: Press `Ctrl+Z`
3. Verify path is removed
4. Test redo: Press `Ctrl+Y` (or `Ctrl+Shift+Z`)
5. Verify path is restored
6. Test history panel: Press `Ctrl+Shift+H`
7. Verify history panel opens/closes

**Expected:**
- `Ctrl+Z` undoes last operation
- `Ctrl+Y` OR `Ctrl+Shift+Z` redoes (both should work)
- `Ctrl+Shift+H` toggles history panel
- History panel shows correct operation labels
- Shortcuts work regardless of panel visibility

**Platform-Specific:**
- **Windows:** Use `Ctrl+Z` / `Ctrl+Y` (standard Windows convention)
- **Windows:** `Ctrl+Shift+Z` also works for redo (Photoshop convention)
- **Windows:** Menu shows shortcuts with "Ctrl+" prefix

**Pass/Fail:** ⬜

---

#### Test Case W3: Window Chrome and Native Integration

**Objective:** Verify Windows window chrome and native OS integration.

**Steps:**
1. Launch WireTuner
2. Observe window title bar (minimize/maximize/close buttons)
3. Test X button (close)
4. Test minimize button (–)
5. Test maximize/restore button (□)
6. Test dragging window by title bar
7. Verify menu bar integration (in-window menu bar)
8. Test `Alt` key to access menus
9. Test snapping window to screen edges (Windows Snap)

**Expected:**
- Standard Windows title bar buttons (top-right)
- Close button (X) prompts to save if unsaved changes
- Minimize collapses to taskbar
- Maximize fills screen (NOT fullscreen mode)
- Menu bar appears in window (below title bar)
- Pressing `Alt` activates menu bar (underlined letters)
- Window supports Windows Snap (drag to edge to snap)

**Platform-Specific:**
- **Windows:** Title bar buttons on right (X, □, –)
- **Windows:** Menu bar is in-window (not system-wide)
- **Windows:** Alt key activates menu mnemonics

**Pass/Fail:** ⬜

---

#### Test Case W4: File Picker - Open Document

**Objective:** Verify native Windows file picker for opening documents.

**Steps:**
1. Press `Ctrl+O` (or File → Open)
2. Observe file picker dialog
3. Verify UI elements:
   - Sidebar with Quick Access/This PC/Network
   - File type filter dropdown
   - Search box (top-right)
   - View options (icons/list/details)
4. Navigate to test directory
5. Filter to `.wiretuner` files
6. Select a test document
7. Click "Open"
8. Verify document loads

**Expected:**
- Native Windows file picker (OpenFileDialog)
- Sidebar shows Quick Access, This PC, OneDrive, etc.
- File filter shows "WireTuner Files (*.wiretuner)" or "All Files (*.*)"
- Search works within current directory
- View options (icons, list, details) available
- Dialog respects Windows theme (dark/light)

**Platform-Specific:**
- **Windows:** Dialog uses Win32 OpenFileDialog API
- **Windows:** Follows Windows UI conventions (breadcrumb navigation)

**Pass/Fail:** ⬜

---

#### Test Case W5: File Picker - Save Document

**Objective:** Verify native Windows save dialog.

**Steps:**
1. Create a new document
2. Press `Ctrl+S` (or File → Save)
3. Observe save dialog
4. Verify UI elements:
   - Filename text field
   - Save location dropdown/breadcrumb
   - File format dropdown (if applicable)
   - "Cancel" and "Save" buttons
5. Navigate to test directory
6. Enter filename: `parity_test_windows`
7. Verify file extension appended: `.wiretuner`
8. Click "Save"
9. Verify file created on disk

**Expected:**
- Native Windows save dialog (SaveFileDialog)
- Default filename is "Untitled.wiretuner"
- Can navigate directories via breadcrumb or sidebar
- File extension automatically appended
- Dialog shows warning if file exists (overwrite prompt)

**Platform-Specific:**
- **Windows:** Save dialog is modal window (not sheet)
- **Windows:** Breadcrumb navigation at top of dialog

**Pass/Fail:** ⬜

---

#### Test Case W6: SVG Export - File Dialog and Output

**Objective:** Verify SVG export uses native dialog and produces valid output.

**Reference:** [SVG Export Test](../../test/integration/svg_export_test.dart)

**Steps:**
1. Create a document with paths and shapes
2. Select File → Export → SVG (or equivalent)
3. Observe export dialog
4. Verify file type filter shows "SVG (*.svg)"
5. Enter filename: `export_test_windows.svg`
6. Click "Export"
7. Verify file created
8. Open exported SVG in:
   - Microsoft Edge (drag file into browser)
   - Inkscape (if available)
   - Adobe Illustrator (if available)
9. Verify rendering matches WireTuner canvas

**Expected:**
- Native Windows save dialog for export
- File extension defaults to `.svg`
- Exported SVG is valid XML
- SVG opens without errors in Windows apps
- Visual rendering matches source document
- File size is reasonable (not bloated)

**Platform-Specific:**
- **Windows:** Export dialog uses SaveFileDialog
- **Windows:** Default location is user's Documents folder

**Pass/Fail:** ⬜

---

#### Test Case W7: PDF Export - File Dialog and Output

**Objective:** Verify PDF export uses native dialog and produces valid output.

**Reference:** [PDF Export Test](../../test/integration/pdf_export_test.dart)

**Steps:**
1. Create a document with paths and shapes
2. Select File → Export → PDF (or equivalent)
3. Observe export dialog
4. Verify file type filter shows "PDF (*.pdf)"
5. Enter filename: `export_test_windows.pdf`
6. Click "Export"
7. Verify file created
8. Open exported PDF in:
   - Microsoft Edge (default PDF viewer)
   - Adobe Acrobat Reader (if available)
9. Verify rendering matches WireTuner canvas
10. Run `pdfinfo export_test_windows.pdf` (if poppler installed via WSL)

**Expected:**
- Native Windows save dialog for export
- File extension defaults to `.pdf`
- Exported PDF is valid (no corruption warnings)
- PDF opens without errors in Edge/Acrobat
- Visual rendering matches source document
- PDF metadata includes title, creator ("WireTuner")

**Platform-Specific:**
- **Windows:** Export dialog uses SaveFileDialog
- **Windows:** PDF opens in default viewer (usually Edge)

**Pass/Fail:** ⬜

---

#### Test Case W8: Application Menu Integration

**Objective:** Verify application menu integrates with Windows window.

**Steps:**
1. Launch WireTuner
2. Observe menu bar (top of window, below title bar)
3. Verify menu structure:
   - **File**: New, Open, Save, Save As, Export, Exit
   - **Edit**: Undo, Redo, Cut, Copy, Paste, Preferences
   - **View**: History Panel, Zoom In/Out
   - **Window**: Minimize, Maximize
   - **Help**: About WireTuner, Help
4. Test keyboard shortcuts shown in menus
5. Verify shortcuts use Ctrl prefix
6. Press `Alt` key and verify menu mnemonics activate

**Expected:**
- Menu bar appears in window (below title bar)
- Menu items show keyboard shortcuts with "Ctrl+" prefix
- Alt key activates menu mnemonics (underlined letters)
- File menu has "Exit" (not "Quit")
- Edit menu has "Preferences" (not in app menu)
- Help menu has "About WireTuner"

**Platform-Specific:**
- **Windows:** Menu bar is in-window (not system-wide)
- **Windows:** Alt+F activates File menu, Alt+E activates Edit, etc.
- **Windows:** "Exit" instead of "Quit"
- **Windows:** Preferences in Edit menu (not separate app menu)

**Pass/Fail:** ⬜

---

## Platform Parity Matrix

### Keyboard Shortcuts Parity

| Feature | macOS Shortcut | Windows Shortcut | Parity Status |
|---------|----------------|------------------|---------------|
| **New Document** | `Cmd+N` | `Ctrl+N` | ⬜ |
| **Open Document** | `Cmd+O` | `Ctrl+O` | ⬜ |
| **Save Document** | `Cmd+S` | `Ctrl+S` | ⬜ |
| **Save As** | `Cmd+Shift+S` | `Ctrl+Shift+S` | ⬜ |
| **Export SVG** | `Cmd+E` | `Ctrl+E` | ⬜ |
| **Undo** | `Cmd+Z` | `Ctrl+Z` | ⬜ |
| **Redo** | `Cmd+Shift+Z` | `Ctrl+Y` OR `Ctrl+Shift+Z` | ⬜ |
| **History Panel** | `Cmd+Shift+H` | `Ctrl+Shift+H` | ⬜ |
| **Quit Application** | `Cmd+Q` | `Alt+F4` | ⬜ |
| **Cut** | `Cmd+X` | `Ctrl+X` | ⬜ |
| **Copy** | `Cmd+C` | `Ctrl+C` | ⬜ |
| **Paste** | `Cmd+V` | `Ctrl+V` | ⬜ |
| **Select All** | `Cmd+A` | `Ctrl+A` | ⬜ |

**Acceptance:** All shortcuts must map correctly and produce identical behavior across platforms.

---

### Window Chrome Parity

| Feature | macOS Behavior | Windows Behavior | Parity Status |
|---------|----------------|------------------|---------------|
| **Close Button** | Red traffic light (top-left) | X button (top-right) | ⬜ |
| **Minimize** | Yellow traffic light | – button (top-right) | ⬜ |
| **Maximize** | Green traffic light (fullscreen) | □ button (maximize, NOT fullscreen) | ⬜ |
| **Menu Location** | System menu bar (top of screen) | In-window menu bar | ⬜ |
| **Drag Window** | Drag title bar | Drag title bar | ⬜ |
| **Resize** | Drag edges/corners | Drag edges/corners | ⬜ |
| **Unsaved Changes** | Dot in red button | Asterisk (*) in title | ⬜ |

**Note:** Window chrome differences are platform-standard and expected. The "Parity Status" here means "behaves correctly per platform conventions."

---

### File Dialog Parity

| Feature | macOS | Windows | Parity Status |
|---------|-------|---------|---------------|
| **Open Dialog** | NSOpenPanel (native) | OpenFileDialog (native) | ⬜ |
| **Save Dialog** | NSSavePanel (native) | SaveFileDialog (native) | ⬜ |
| **File Type Filter** | Shows .wiretuner, .svg, .pdf | Shows .wiretuner, .svg, .pdf | ⬜ |
| **Default Location** | User Documents folder | User Documents folder | ⬜ |
| **File Extension Auto-Append** | Yes | Yes | ⬜ |
| **Overwrite Warning** | Native dialog | Native dialog | ⬜ |
| **Dark Mode Support** | Follows macOS appearance | Follows Windows theme | ⬜ |

**Acceptance:** Both platforms must use native dialogs with equivalent functionality.

---

## Export Format Parity

### SVG Export Byte-Identical Output

**Test Method:**
1. Create identical document on both platforms
2. Export to SVG using same filename
3. Compare file contents using MD5 hash or diff

**Expected:**
- SVG XML structure identical (order may vary for attributes)
- Coordinate precision identical (2 decimal places)
- Metadata may differ (platform, timestamp) - exclude from comparison
- Visual rendering identical when opened in browser

**Automated Verification:**
See `test/integration/platform_parity_test.dart` for byte-identical export tests.

**Pass/Fail:** ⬜

---

### PDF Export Byte-Identical Output

**Test Method:**
1. Create identical document on both platforms
2. Export to PDF using same filename
3. Compare file contents using MD5 hash (excluding metadata)

**Expected:**
- PDF structure identical (same page count, dimensions)
- Vector paths render identically
- Metadata may differ (creation date, OS version) - exclude from comparison
- Visual rendering identical when opened in viewer

**Automated Verification:**
See `test/integration/platform_parity_test.dart` for PDF parity tests.

**Pass/Fail:** ⬜

---

### Save/Load Round-Trip Parity

**Test Method:**
1. Create document on macOS, save as `parity_test.wiretuner`
2. Copy file to Windows machine
3. Open on Windows, verify document loads without errors
4. Make edit, save on Windows
5. Copy back to macOS, verify edit persisted

**Expected:**
- .wiretuner file format is 100% cross-platform compatible
- No corruption or data loss when transferring files
- Snapshots compress/decompress identically
- Event replay produces identical results

**Automated Verification:**
See `test/integration/save_load_roundtrip_test.dart`.

**Pass/Fail:** ⬜

---

## Performance Benchmarks

### Platform Parity Performance Targets

| Metric | macOS Target | Windows Target | Acceptable Variance |
|--------|--------------|----------------|---------------------|
| **Application Launch** | < 2 seconds | < 2 seconds | ±10% |
| **Document Load (1000 events)** | < 100 ms | < 100 ms | ±10% |
| **SVG Export (100 objects)** | < 500 ms | < 500 ms | ±15% |
| **PDF Export (100 objects)** | < 500 ms | < 500 ms | ±15% |
| **Undo/Redo Latency** | < 80 ms | < 80 ms | ±10% |
| **Frame Time (Rendering)** | < 16.67 ms (60 FPS) | < 16.67 ms (60 FPS) | ±5% |

### Benchmark Execution

Run performance benchmarks on both platforms:

```bash
# macOS
flutter test test/performance/ --platform macos

# Windows
flutter test test/performance/ --platform windows
```

**Results Storage:**
- Store benchmark outputs in `test/performance/results/`
- Format: JSON with platform metadata
- Compare macOS vs. Windows results for regression

---

## Known Platform Differences

### Expected Differences (By Design)

These differences are intentional and follow platform conventions:

| Feature | macOS | Windows | Reason |
|---------|-------|---------|--------|
| **Window Controls** | Traffic lights (left) | X/□/– buttons (right) | Platform HIG |
| **Menu Bar** | System menu bar | In-window menu | macOS convention |
| **Quit Shortcut** | `Cmd+Q` | `Alt+F4` | Platform standard |
| **Redo Shortcut** | `Cmd+Shift+Z` | `Ctrl+Y` preferred | Windows convention |
| **Fullscreen** | Native macOS fullscreen | Maximize (no separate space) | macOS-specific feature |
| **Menu Mnemonics** | No underlines | Alt+letter underlines | Windows accessibility |
| **File Paths** | `/Users/.../Documents/` | `C:\Users\...\Documents\` | OS file system |

**Acceptance:** These differences are expected and correct.

---

### Unintentional Differences (Bugs)

Document any platform-specific bugs found during testing:

| Issue ID | Description | Platform | Severity | Status |
|----------|-------------|----------|----------|--------|
| _TBD_ | _Example: Save dialog crashes on Windows 11_ | Windows | High | Open |

---

## Sign-Off Template

### QA Execution Log

| Platform | Tester | Date | Automated Tests | Manual Tests | Parity Matrix | Pass/Fail | Notes |
|----------|--------|------|-----------------|--------------|---------------|-----------|-------|
| macOS 14 Sonoma | _____ | ____ | ⬜ | ⬜ | ⬜ | ⬜ | |
| macOS 13 Ventura | _____ | ____ | ⬜ | ⬜ | ⬜ | ⬜ | |
| Windows 11 | _____ | ____ | ⬜ | ⬜ | ⬜ | ⬜ | |
| Windows 10 | _____ | ____ | ⬜ | ⬜ | ⬜ | ⬜ | |

### Release Criteria

- [ ] All automated tests pass on macOS (CI: `macos-latest`)
- [ ] All automated tests pass on Windows (CI: `windows-latest`)
- [ ] macOS manual QA checklist 100% complete
- [ ] Windows manual QA checklist 100% complete
- [ ] Platform parity matrix 100% ✅
- [ ] Export outputs are byte-identical (excluding metadata)
- [ ] Performance benchmarks within ±15% across platforms
- [ ] No unintentional platform differences (bugs) remain open
- [ ] Save/load round-trip works cross-platform
- [ ] All keyboard shortcuts tested and working

### Sign-Off

**QA Lead Approval:**

Name: _______________________________

Signature: _______________________________

Date: _______________________________

**Release Manager Approval:**

Name: _______________________________

Signature: _______________________________

Date: _______________________________

---

## Appendix: Manual Testing Report Template

### Test Session Report

**Tester:** _______________________________

**Platform:** ⬜ macOS _____ ⬜ Windows _____

**Date:** _______________________________

**Build Version:** _______________________________

**Test Environment:**
- OS Version: _______________________________
- Hardware: _______________________________
- Screen Resolution: _______________________________

**Test Results Summary:**

| Test Case ID | Test Name | Result | Notes |
|--------------|-----------|--------|-------|
| M1 / W1 | Keyboard Shortcuts - File | ⬜ Pass ⬜ Fail | |
| M2 / W2 | Keyboard Shortcuts - Undo/Redo | ⬜ Pass ⬜ Fail | |
| M3 / W3 | Window Chrome | ⬜ Pass ⬜ Fail | |
| M4 / W4 | File Picker - Open | ⬜ Pass ⬜ Fail | |
| M5 / W5 | File Picker - Save | ⬜ Pass ⬜ Fail | |
| M6 / W6 | SVG Export | ⬜ Pass ⬜ Fail | |
| M7 / W7 | PDF Export | ⬜ Pass ⬜ Fail | |
| M8 / W8 | Application Menu | ⬜ Pass ⬜ Fail | |

**Issues Found:**

| Issue # | Severity | Description | Steps to Reproduce | Screenshots |
|---------|----------|-------------|-------------------|-------------|
| | ⬜ Critical ⬜ High ⬜ Medium ⬜ Low | | | |

**Overall Assessment:**

⬜ **Pass** - Ready for release
⬜ **Conditional Pass** - Minor issues, can release with notes
⬜ **Fail** - Critical issues, cannot release

**Additional Notes:**

_______________________________

_______________________________

_______________________________

---

**Document Version:** 1.0
**Iteration:** I5.T8
**Maintainer:** WireTuner QA Team
**Next Review:** After I5 release (post-platform parity validation)
