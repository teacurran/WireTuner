# WireTuner Release Process Guide

Quick reference for creating WireTuner releases.

## Prerequisites

Before creating a release, ensure:

1. **Platform Parity QA Complete**
   - See: [`docs/qa/platform_parity_checklist.md`](../qa/platform_parity_checklist.md)
   - All tests passing on macOS and Windows
   - Manual QA completed and signed off

2. **Code Signing Credentials Configured**
   - macOS: Developer ID Application certificate + Apple ID for notarization
   - Windows: Code signing certificate (.pfx or in certificate store)

3. **GitHub Secrets Configured** (for CI builds)
   - See: [`docs/qa/release_checklist.md`](../qa/release_checklist.md#appendix-b-secret-management)

## Local Testing (Unsigned Builds)

### macOS

```bash
# Build unsigned DMG for local testing
./scripts/ci/build_macos_release.sh --version 0.1.0-test --skip-notarize --skip-sign

# Output: build/release/WireTuner-0.1.0-test-macOS.dmg
```

### Windows

```powershell
# Build unsigned installer for local testing
.\scripts\ci\build_windows_release.ps1 -Version 0.1.0-test -SkipSign

# Output: build\release\WireTuner-0.1.0-test-Windows-Setup.exe
```

## Production Release (via GitHub Actions)

### 1. Trigger Release Workflow

Navigate to: **Actions → Release → Run workflow**

**Inputs:**
- **Version**: `0.1.0` (semantic versioning)
- **Skip macOS notarization**: `false` (unchecked for production)
- **Skip code signing**: `false` (unchecked for production)
- **Create GitHub Release**: `true` (checked to auto-publish)

### 2. Monitor Build

Watch the workflow progress:
- Pre-flight checks
- macOS build (parallel)
- Windows build (parallel)
- GitHub Release creation

### 3. Download Artifacts

Artifacts are available for 30 days:
- `WireTuner-macOS.dmg`
- `WireTuner-macOS.sha256`
- `WireTuner-Windows-Setup.exe`
- `WireTuner-Windows-Setup.sha256`

### 4. Verify Release

Follow: [`docs/qa/release_checklist.md`](../qa/release_checklist.md)

Key verification steps:
- SHA256 hash verification
- Code signing verification (macOS: `codesign`, Windows: `signtool`)
- Manual installation testing

## Release Checklist

Full release checklist with all verification steps, sign-off templates, and rollback procedures:

**[`docs/qa/release_checklist.md`](../qa/release_checklist.md)**

## Build Scripts Reference

### macOS: `scripts/ci/build_macos_release.sh`

```bash
# Full help
./scripts/ci/build_macos_release.sh --help

# Options
--version VERSION       # e.g., 0.1.0
--skip-notarize        # Skip Apple notarization (local builds)
--skip-sign            # Skip code signing (local builds)
--output-dir DIR       # Custom output directory

# Environment variables
APPLE_ID               # Apple ID for notarization
AC_PASSWORD            # App-specific password
AC_PROVIDER            # Team ID (if multiple)
SIGNING_IDENTITY       # Developer ID certificate name
```

### Windows: `scripts/ci/build_windows_release.ps1`

```powershell
# Full help
.\scripts\ci\build_windows_release.ps1 -Help

# Options
-Version VERSION       # e.g., 0.1.0
-SkipSign              # Skip code signing (local builds)
-OutputDir DIR         # Custom output directory

# Environment variables
$env:WINDOWS_PFX_PATH      # Path to .pfx certificate
$env:WINDOWS_PFX_PASSWORD  # Certificate password
$env:SIGNING_CERT_THUMBPRINT  # Certificate thumbprint
```

## Workflow Reference

### Release Workflow: `.github/workflows/release.yml`

**Trigger**: Manual (`workflow_dispatch`)

**Jobs**:
1. `preflight` - Pre-flight validation
2. `build-macos` - Build macOS DMG (parallel)
3. `build-windows` - Build Windows installer (parallel)
4. `create-release` - Publish GitHub Release
5. `release-summary` - Overall status

**Artifacts**:
- DMG and installer binaries
- SHA256 hash files
- 30-day retention

## Common Issues

### macOS: "No Developer ID certificate found"

**Solution**:
```bash
# List available certificates
security find-identity -v -p codesigning

# If missing, install from Keychain Access or:
# 1. Download from Apple Developer portal
# 2. Double-click .cer file to install
```

### macOS: "Notarization failed"

**Solution**:
```bash
# Check notarization logs
xcrun notarytool log <SUBMISSION_ID> \
  --apple-id "$APPLE_ID" \
  --password "$AC_PASSWORD"

# Common issues:
# - Invalid app-specific password (regenerate at appleid.apple.com)
# - Bundle ID mismatch (check Info.plist)
# - Hardened runtime issues (check entitlements)
```

### Windows: "signtool not found"

**Solution**:
```powershell
# Install Windows SDK from:
# https://developer.microsoft.com/windows/downloads/windows-sdk/

# Or locate existing install:
Get-ChildItem "C:\Program Files (x86)\Windows Kits\10\bin\*\x64\signtool.exe"
```

### Windows: "Inno Setup not found"

**Solution**:
```powershell
# Install Inno Setup 6:
choco install innosetup -y

# Or download from:
# https://jrsoftware.org/isdl.php
```

## Version Numbering

WireTuner uses [Semantic Versioning](https://semver.org/):

- **Major.Minor.Patch** (e.g., `1.2.3`)
- **Pre-release suffix** (e.g., `0.1.0-beta`, `0.2.0-rc1`)

**Guidelines**:
- `0.x.y` - Pre-1.0 development
- Increment **patch** for bug fixes
- Increment **minor** for new features
- Increment **major** for breaking changes

## Support

For release issues:
- **GitHub Issues**: [WireTuner Issues](https://github.com/wiretuner/WireTuner/issues)
- **Release Checklist**: [`docs/qa/release_checklist.md`](../qa/release_checklist.md)
- **Platform Parity**: [`docs/qa/platform_parity_checklist.md`](../qa/platform_parity_checklist.md)

---

**Last Updated**: 2025-11-09
**Iteration**: I5.T9
