# Platform Integration Tools

This directory contains platform-specific integrations for WireTuner document previews in native file browsers.

## macOS QuickLook (`quicklook/`)

Provides thumbnail previews in macOS Finder and QuickLook panels.

### Building

```bash
cd quicklook
xcodebuild -project WireTunerQuickLook.xcodeproj -scheme WireTunerQuickLook -configuration Release
```

### Installation

The QuickLook extension is bundled with WireTuner.app and automatically registered on first launch.

Manual installation:
```bash
cp -r build/Release/WireTunerQuickLook.appex ~/Library/QuickLook/
qlmanage -r
```

### Testing

```bash
# Generate test thumbnail
wiretuner --generate-thumbnail test.wiretuner /tmp/preview.png --size 512

# Test QuickLook
qlmanage -p test.wiretuner
```

## Windows Explorer (`explorer/`)

Provides thumbnail previews in Windows File Explorer.

### Building

Requires Visual Studio 2019 or later with C++ desktop development tools.

```bash
cd explorer
msbuild WireTunerExplorerHandler.vcxproj /p:Configuration=Release /p:Platform=x64
```

### Installation

The thumbnail handler is registered during WireTuner installation via the MSI installer.

Manual registration (requires admin):
```powershell
regsvr32 /s WireTunerExplorerHandler.dll
```

### Testing

```powershell
# Generate test thumbnail
wiretuner.exe --generate-thumbnail test.wiretuner C:\temp\preview.png --size 256

# Clear thumbnail cache to force regeneration
ie4uinit.exe -show
```

## Thumbnail CLI

Both platform integrations delegate thumbnail generation to the WireTuner CLI:

```bash
wiretuner --generate-thumbnail <input.wiretuner> <output.png> [--size <pixels>]
```

### Arguments

- `<input.wiretuner>`: Path to WireTuner document file
- `<output.png>`: Path to output PNG thumbnail
- `--size <pixels>`: Thumbnail size in pixels (default: 512)

### Implementation

The CLI command:
1. Loads the document from the .wiretuner file
2. Extracts the first artboard (or artboard specified via `--artboard <id>`)
3. Renders the artboard to a PNG using the existing `ThumbnailService`
4. Saves the PNG to the output path
5. Exits with code 0 on success, non-zero on error

### Caching

Thumbnails are cached in:
- **macOS**: `$TMPDIR/wiretuner-thumbnails/`
- **Windows**: `%TEMP%\wiretuner-thumbnails\`

Cache keys are based on file path + modification time to ensure thumbnails auto-refresh when documents change.

## Architecture

```
┌─────────────────┐
│  Finder/Explorer│
└────────┬────────┘
         │ Request thumbnail
         ▼
┌─────────────────┐
│ Platform Handler│  (QuickLook / COM)
└────────┬────────┘
         │ Call CLI
         ▼
┌─────────────────┐
│  WireTuner CLI  │
└────────┬────────┘
         │ Generate PNG
         ▼
┌─────────────────┐
│ ThumbnailService│  (Reuses app thumbnail renderer)
└─────────────────┘
```

This architecture ensures:
- Consistent thumbnail rendering across platforms
- Single source of truth (ThumbnailService) for rendering logic
- Platform integrations remain lightweight (just wrappers)
- Easy testing (can test CLI independently)

## Requirements

### macOS
- macOS 11.0+ (Big Sur)
- Xcode 13.0+
- Swift 5.5+

### Windows
- Windows 10 or later
- Visual Studio 2019+
- Windows 10 SDK

## Related

- FR-047: macOS Platform Integration
- FR-048: Windows Platform Integration
- Journey 17: Navigator Thumbnail Auto-Update
