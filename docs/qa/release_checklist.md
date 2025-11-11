<!-- anchor: qa-release-checklist -->
# WireTuner Release Checklist

**Version:** 1.0
**Iteration:** I5.T9
**Last Updated:** 2025-11-09
**Status:** Active

---

## Overview

This release checklist ensures all necessary steps are completed before publishing a WireTuner release to end users. It encompasses code signing, notarization, artifact verification, documentation updates, and final approval gates.

**Reference Documentation:**
- [Platform Parity Checklist](./platform_parity_checklist.md) - Pre-requisite QA validation
- [Deployment Architecture](.codemachine/artifacts/architecture/05_Operational_Architecture.md) - Build and distribution specifications
- [GitHub Actions Release Workflow](../../.github/workflows/release.yml) - Automated build pipeline

**Scope:**
- Pre-release validation
- Build artifact creation (macOS DMG, Windows installer)
- Code signing and notarization
- Artifact verification and integrity checks
- Release documentation
- Distribution and post-release validation

---

## Table of Contents

- [Pre-Release Validation](#pre-release-validation)
- [macOS Release Process](#macos-release-process)
- [Windows Release Process](#windows-release-process)
- [Artifact Verification](#artifact-verification)
- [Release Documentation](#release-documentation)
- [Distribution](#distribution)
- [Post-Release Validation](#post-release-validation)
- [Sign-Off Template](#sign-off-template)

---

## Pre-Release Validation

### 1. Platform Parity QA Completion

**Objective:** Ensure all platform parity testing is complete and passing.

**Prerequisites:**
- [ ] Platform parity checklist completed: [`docs/qa/platform_parity_checklist.md`](./platform_parity_checklist.md)
- [ ] All automated tests pass on macOS (CI: `macos-latest`)
- [ ] All automated tests pass on Windows (CI: `windows-latest`)
- [ ] Manual QA testing 100% complete for both platforms
- [ ] Platform parity matrix shows 100% ✅
- [ ] No unintentional platform differences (bugs) remain open
- [ ] Performance benchmarks within ±15% across platforms

**Evidence Required:**
- Completed platform parity checklist with QA Lead sign-off
- CI build logs showing all tests passing
- Performance benchmark reports

**Gate:** ⬜ **PASS** / ⬜ **FAIL**

**Sign-Off:**
QA Lead: _________________ Date: _________

---

### 2. Code Freeze and Version Tagging

**Objective:** Ensure codebase is stable and properly versioned.

**Prerequisites:**
- [ ] Code freeze initiated (no new features or changes)
- [ ] All critical bugs resolved
- [ ] Version number determined (semantic versioning: `X.Y.Z`)
- [ ] `pubspec.yaml` version updated to match release version
- [ ] Changelog updated with release notes
- [ ] All changes committed to `main` branch
- [ ] No uncommitted changes in working directory

**Version Information:**
- Release Version: _______________
- Git Commit SHA: _______________
- Git Tag: v_______________

**Gate:** ⬜ **PASS** / ⬜ **FAIL**

**Sign-Off:**
Release Manager: _________________ Date: _________

---

### 3. Code Signing Credentials Verification

**Objective:** Verify all necessary code signing credentials are available and valid.

#### macOS Credentials

- [ ] **Developer ID Application Certificate** installed in Keychain
  - Certificate Name: _______________________________
  - Team ID: _______________________________
  - Expiration Date: _______________________________
  - Valid: ⬜ Yes / ⬜ No

- [ ] **Apple ID credentials** for notarization
  - Apple ID: _______________________________
  - App-specific password stored in secrets: ⬜ Yes / ⬜ No
  - Team ID (if multiple teams): _______________________________

- [ ] **Notarization history** reviewed for past issues
  - Previous notarization successful: ⬜ Yes / ⬜ No / ⬜ N/A (first release)

#### Windows Credentials

- [ ] **Code Signing Certificate** available
  - Certificate Type: ⬜ PFX File / ⬜ Certificate Store
  - Certificate Path/Thumbprint: _______________________________
  - Issuer: _______________________________
  - Expiration Date: _______________________________
  - Valid: ⬜ Yes / ⬜ No

- [ ] **Timestamp Server** accessible
  - Server URL: http://timestamp.digicert.com
  - Reachable: ⬜ Yes / ⬜ No

**Gate:** ⬜ **PASS** / ⬜ **FAIL**

**Sign-Off:**
DevOps Lead: _________________ Date: _________

---

## macOS Release Process

### 4. macOS Build and Signing

**Objective:** Build macOS release DMG with proper code signing.

**Build Script:** [`scripts/ci/build_macos_release.sh`](../../scripts/ci/build_macos_release.sh)

#### Local Build (Optional Pre-test)

```bash
# Test unsigned build locally
./scripts/ci/build_macos_release.sh --version 0.1.0 --skip-notarize --skip-sign

# Verify DMG created
ls -lh build/release/WireTuner-0.1.0-macOS.dmg
```

#### CI Build (Production)

- [ ] Trigger GitHub Actions release workflow
  - Navigate to: **Actions → Release → Run workflow**
  - Inputs:
    - Version: _______________ (e.g., `0.1.0`)
    - Skip notarization: ⬜ (leave unchecked for production)
    - Skip code signing: ⬜ (leave unchecked for production)
    - Create GitHub Release: ✅ (check for automatic release)

- [ ] **Monitor build progress**
  - Pre-flight checks: ⬜ PASS / ⬜ FAIL
  - macOS build job: ⬜ PASS / ⬜ FAIL
  - Build duration: _____________ minutes

- [ ] **Verify build outputs**
  - DMG artifact uploaded: ⬜ Yes / ⬜ No
  - SHA256 hash file uploaded: ⬜ Yes / ⬜ No

**Build Output:**
- DMG Path: `build/release/WireTuner-{VERSION}-macOS.dmg`
- SHA256 Path: `build/release/WireTuner-{VERSION}-macOS.sha256`
- DMG Size: _______________ MB
- SHA256 Hash: _______________________________________________

**Gate:** ⬜ **PASS** / ⬜ **FAIL**

---

### 5. macOS Code Signing Verification

**Objective:** Verify DMG and app bundle are properly signed.

#### Verify App Bundle Signature

```bash
# Extract app from DMG or use build directory
APP_PATH="build/macos/Build/Products/Release/WireTuner.app"

# Verify signature
codesign --verify --verbose=4 "$APP_PATH"

# Display signature info
codesign -dv --verbose=4 "$APP_PATH"

# Expected output should include:
# - Identifier=com.wiretuner.app (or your bundle ID)
# - Authority=Developer ID Application: [Your Name] ([Team ID])
# - Signed Time=[Recent timestamp]
# - Info.plist entries=[Expected count]
# - TeamIdentifier=[Your Team ID]
# - Sealed Resources version=2
# - Internal requirements count=[Expected]
```

**Verification Results:**
- [ ] Signature valid (exit code 0)
- [ ] Authority shows "Developer ID Application"
- [ ] Team ID matches expected value
- [ ] Hardened runtime enabled (--options runtime)
- [ ] No invalid entitlements or errors

**Evidence:** Attach `codesign` output

---

#### Verify DMG Signature

```bash
DMG_PATH="build/release/WireTuner-0.1.0-macOS.dmg"

# Verify DMG signature
codesign --verify --verbose=4 "$DMG_PATH"

# Display signature info
codesign -dv --verbose=4 "$DMG_PATH"
```

**Verification Results:**
- [ ] DMG signature valid
- [ ] Authority shows "Developer ID Application"
- [ ] No errors or warnings

**Gate:** ⬜ **PASS** / ⬜ **FAIL**

---

### 6. macOS Notarization Verification

**Objective:** Verify DMG has been notarized by Apple and ticket is stapled.

#### Check Notarization Status

```bash
# Verify notarization ticket is stapled
xcrun stapler validate "$DMG_PATH"

# Expected output:
# Processing: WireTuner-0.1.0-macOS.dmg
# The validate action worked!
```

**Verification Results:**
- [ ] Stapler validation successful ("validate action worked!")
- [ ] No errors about missing tickets

---

#### Download and Review Notarization Log

```bash
# If notarization was done via CI, retrieve submission ID from workflow logs
# Then download the log:
xcrun notarytool log <SUBMISSION_ID> \
  --apple-id "$APPLE_ID" \
  --password "$AC_PASSWORD" \
  notarization-log.json

# Review log for warnings or issues
cat notarization-log.json | jq '.issues'
```

**Notarization Log Review:**
- [ ] No critical issues reported
- [ ] Status: "Accepted"
- [ ] All binaries scanned successfully

**Evidence:**
- Notarization submission ID: _______________________________
- Notarization log attached: ⬜ Yes / ⬜ No

**Gate:** ⬜ **PASS** / ⬜ **FAIL**

**Sign-Off:**
macOS Release Engineer: _________________ Date: _________

---

## Windows Release Process

### 7. Windows Build and Signing

**Objective:** Build Windows release installer with proper code signing.

**Build Script:** [`scripts/ci/build_windows_release.ps1`](../../scripts/ci/build_windows_release.ps1)

#### Local Build (Optional Pre-test)

```powershell
# Test unsigned build locally
.\scripts\ci\build_windows_release.ps1 -Version 0.1.0 -SkipSign

# Verify installer created
Get-Item build\release\WireTuner-0.1.0-Windows-Setup.exe
```

#### CI Build (Production)

- [ ] Trigger GitHub Actions release workflow (same as macOS)
  - Windows build job runs in parallel with macOS
  - Monitor Windows build job: ⬜ PASS / ⬜ FAIL
  - Build duration: _____________ minutes

- [ ] **Verify build outputs**
  - Installer artifact uploaded: ⬜ Yes / ⬜ No
  - SHA256 hash file uploaded: ⬜ Yes / ⬜ No

**Build Output:**
- Installer Path: `build/release/WireTuner-{VERSION}-Windows-Setup.exe`
- SHA256 Path: `build/release/WireTuner-{VERSION}-Windows-Setup.sha256`
- Installer Size: _______________ MB
- SHA256 Hash: _______________________________________________

**Gate:** ⬜ **PASS** / ⬜ **FAIL**

---

### 8. Windows Code Signing Verification

**Objective:** Verify installer and executable are properly signed.

#### Verify Executable Signature

```powershell
# Extract executable from build directory
$exePath = "build\windows\runner\Release\WireTuner.exe"

# Verify signature using signtool
# (Requires Windows SDK installed)
$signtool = "C:\Program Files (x86)\Windows Kits\10\bin\*\x64\signtool.exe"
$signtoolPath = (Get-ChildItem $signtool | Select-Object -First 1).FullName

& $signtoolPath verify /pa /v $exePath

# Expected output should include:
# - Signing Certificate Chain
# - Issued to: [Your Organization]
# - Issued by: [Certificate Authority]
# - Timestamp: [Recent date/time]
# - Successfully verified
```

**Verification Results:**
- [ ] Signature valid (exit code 0)
- [ ] Certificate chain valid
- [ ] Timestamp present (from DigiCert or other TSA)
- [ ] No errors or warnings

**Evidence:** Attach `signtool verify` output

---

#### Verify Installer Signature

```powershell
$installerPath = "build\release\WireTuner-0.1.0-Windows-Setup.exe"

# Verify installer signature
& $signtoolPath verify /pa /v $installerPath

# Display signature details
Get-AuthenticodeSignature $installerPath | Format-List
```

**Verification Results:**
- [ ] Installer signature valid
- [ ] Certificate matches expected issuer
- [ ] Timestamp present
- [ ] Status: Valid
- [ ] No errors or warnings

**Gate:** ⬜ **PASS** / ⬜ **FAIL**

**Sign-Off:**
Windows Release Engineer: _________________ Date: _________

---

## Artifact Verification

### 9. SHA256 Hash Verification

**Objective:** Verify integrity of build artifacts with cryptographic hashes.

#### macOS DMG Hash Verification

```bash
# Generate hash locally
shasum -a 256 build/release/WireTuner-0.1.0-macOS.dmg

# Compare with stored hash file
cat build/release/WireTuner-0.1.0-macOS.sha256

# Verify they match
```

**macOS Hash Verification:**
- [ ] Hash matches between generated and stored file
- [ ] No discrepancies detected

**Hash Value:** _______________________________________________

---

#### Windows Installer Hash Verification

```powershell
# Generate hash locally
Get-FileHash build\release\WireTuner-0.1.0-Windows-Setup.exe -Algorithm SHA256

# Compare with stored hash file
Get-Content build\release\WireTuner-0.1.0-Windows-Setup.sha256

# Verify they match
```

**Windows Hash Verification:**
- [ ] Hash matches between generated and stored file
- [ ] No discrepancies detected

**Hash Value:** _______________________________________________

**Gate:** ⬜ **PASS** / ⬜ **FAIL**

---

### 10. Manual Installation and Smoke Testing

**Objective:** Verify artifacts install and launch successfully on clean systems.

#### macOS Installation Test

**Test Environment:**
- macOS Version: _______________
- Hardware: _______________
- Fresh user account: ⬜ Yes / ⬜ No

**Test Steps:**
1. [ ] Download DMG from build artifacts
2. [ ] Double-click DMG to mount
3. [ ] Verify macOS Gatekeeper allows opening (no quarantine warning if notarized)
4. [ ] Drag WireTuner.app to Applications folder
5. [ ] Launch from Applications
6. [ ] Verify app launches without errors
7. [ ] Create a new document
8. [ ] Draw a simple path
9. [ ] Save document
10. [ ] Reopen document
11. [ ] Export to SVG
12. [ ] Verify SVG renders in browser
13. [ ] Quit application

**macOS Smoke Test Results:**
- Launch successful: ⬜ Yes / ⬜ No
- No security warnings: ⬜ Yes / ⬜ No (expected if notarized)
- Basic functionality works: ⬜ Yes / ⬜ No
- Issues found: _______________________________

---

#### Windows Installation Test

**Test Environment:**
- Windows Version: _______________
- Hardware: _______________
- Fresh user account: ⬜ Yes / ⬜ No

**Test Steps:**
1. [ ] Download installer from build artifacts
2. [ ] Right-click installer → Properties → Digital Signatures
3. [ ] Verify signature present and valid (if signed)
4. [ ] Run installer (as administrator if needed)
5. [ ] Complete installation wizard
6. [ ] Verify no SmartScreen warnings (if signed)
7. [ ] Launch from Start Menu
8. [ ] Verify app launches without errors
9. [ ] Create a new document
10. [ ] Draw a simple path
11. [ ] Save document
12. [ ] Reopen document
13. [ ] Export to PDF
14. [ ] Verify PDF renders in Edge/Acrobat
15. [ ] Uninstall via Control Panel (verify clean uninstall)

**Windows Smoke Test Results:**
- Installation successful: ⬜ Yes / ⬜ No
- No security warnings: ⬜ Yes / ⬜ No (expected if signed)
- Basic functionality works: ⬜ Yes / ⬜ No
- Clean uninstall: ⬜ Yes / ⬜ No
- Issues found: _______________________________

**Gate:** ⬜ **PASS** / ⬜ **FAIL**

**Sign-Off:**
QA Tester: _________________ Date: _________

---

## Release Documentation

### 11. Release Notes Preparation

**Objective:** Document release changes, known issues, and installation instructions.

**Release Notes Contents:**
- [ ] Version number and release date
- [ ] New features summary
- [ ] Bug fixes and improvements
- [ ] Known issues and workarounds
- [ ] System requirements (macOS 10.15+, Windows 10 1809+)
- [ ] Installation instructions for both platforms
- [ ] SHA256 checksums for verification
- [ ] Download links (GitHub Releases)
- [ ] Upgrade instructions (if applicable)

**Release Notes File:** `CHANGELOG.md` or GitHub Release description

**Gate:** ⬜ **PASS** / ⬜ **FAIL**

---

### 12. Documentation Updates

**Objective:** Ensure all documentation reflects the new release.

- [ ] README.md updated with latest version
- [ ] Installation guide updated (if process changed)
- [ ] User manual updated (if features added)
- [ ] API documentation updated (if applicable)
- [ ] Website updated with download links
- [ ] Social media announcement drafted

**Gate:** ⬜ **PASS** / ⬜ **FAIL**

**Sign-Off:**
Documentation Lead: _________________ Date: _________

---

## Distribution

### 13. GitHub Release Publication

**Objective:** Publish release artifacts to GitHub Releases.

**GitHub Release Details:**
- [ ] Release tag created: `v{VERSION}`
- [ ] Release title: "WireTuner v{VERSION}"
- [ ] Release notes populated (from step 11)
- [ ] Artifacts attached:
  - [ ] `WireTuner-{VERSION}-macOS.dmg`
  - [ ] `WireTuner-{VERSION}-macOS.sha256`
  - [ ] `WireTuner-{VERSION}-Windows-Setup.exe`
  - [ ] `WireTuner-{VERSION}-Windows-Setup.sha256`
- [ ] Pre-release flag set appropriately
  - ⬜ Pre-release (beta, RC, etc.)
  - ⬜ Stable release
- [ ] Release published (not draft)

**GitHub Release URL:** https://github.com/___________/WireTuner/releases/tag/v___________

**Gate:** ⬜ **PASS** / ⬜ **FAIL**

---

### 14. Website and Download Page Update

**Objective:** Update public-facing download pages with new release.

- [ ] Website download page updated (wiretuner.com/download)
- [ ] Download links point to GitHub Releases
- [ ] SHA256 hashes displayed for verification
- [ ] Installation instructions current
- [ ] System requirements stated clearly
- [ ] Previous version archived (if applicable)

**Website URL:** https://wiretuner.com/download

**Gate:** ⬜ **PASS** / ⬜ **FAIL**

**Sign-Off:**
Marketing Lead: _________________ Date: _________

---

## Post-Release Validation

### 15. Download and Integrity Verification

**Objective:** Verify public download links work and files are intact.

#### Test macOS Download

```bash
# Download from GitHub Releases
curl -L -o WireTuner-0.1.0-macOS.dmg \
  https://github.com/[ORG]/WireTuner/releases/download/v0.1.0/WireTuner-0.1.0-macOS.dmg

# Verify hash
shasum -a 256 WireTuner-0.1.0-macOS.dmg

# Compare with published hash
```

- [ ] macOS download successful
- [ ] Hash matches published value
- [ ] File size matches expected

---

#### Test Windows Download

```powershell
# Download from GitHub Releases
Invoke-WebRequest -Uri "https://github.com/[ORG]/WireTuner/releases/download/v0.1.0/WireTuner-0.1.0-Windows-Setup.exe" `
  -OutFile "WireTuner-0.1.0-Windows-Setup.exe"

# Verify hash
Get-FileHash WireTuner-0.1.0-Windows-Setup.exe -Algorithm SHA256

# Compare with published hash
```

- [ ] Windows download successful
- [ ] Hash matches published value
- [ ] File size matches expected

**Gate:** ⬜ **PASS** / ⬜ **FAIL**

---

### 16. User Acceptance Testing (UAT)

**Objective:** Validate release with real users in production-like environment.

**UAT Plan:**
- [ ] Beta testers notified of release
- [ ] Installation tested on diverse hardware
- [ ] Core workflows validated:
  - [ ] Document creation and editing
  - [ ] Save/load operations
  - [ ] Undo/redo functionality
  - [ ] Export to SVG/PDF
- [ ] No critical bugs reported
- [ ] User feedback collected

**UAT Duration:** _______________ days

**UAT Results:**
- Critical bugs: _______________
- Major bugs: _______________
- Minor bugs: _______________
- User satisfaction: ⬜ Positive / ⬜ Neutral / ⬜ Negative

**Gate:** ⬜ **PASS** / ⬜ **FAIL**

**Sign-Off:**
UAT Lead: _________________ Date: _________

---

### 17. Monitoring and Issue Tracking

**Objective:** Monitor release for issues and track bug reports.

**Monitoring Period:** First 7 days post-release

- [ ] GitHub Issues monitored for bug reports
- [ ] Download statistics tracked
- [ ] Crash reports reviewed (if telemetry enabled)
- [ ] User support tickets reviewed
- [ ] Hotfix plan prepared (if needed)

**Issues Identified:**

| Issue ID | Severity | Description | Status |
|----------|----------|-------------|--------|
| | | | |

**Gate:** ⬜ **PASS** / ⬜ **FAIL** (if critical issues found)

**Sign-Off:**
Support Lead: _________________ Date: _________

---

## Sign-Off Template

### Final Release Approval

**Release Version:** _______________
**Release Date:** _______________
**GitHub Release URL:** _______________________________________________

### Approval Checklist

- [ ] All pre-release validation complete
- [ ] Platform parity QA passed
- [ ] macOS build signed and notarized
- [ ] Windows build signed
- [ ] Artifact verification passed
- [ ] Manual installation tests passed
- [ ] Release documentation complete
- [ ] GitHub Release published
- [ ] Download verification passed
- [ ] No critical blockers identified

### Sign-Off Approvals

**QA Lead Approval:**

Name: _______________________________

Signature: _______________________________

Date: _______________________________

---

**Release Manager Approval:**

Name: _______________________________

Signature: _______________________________

Date: _______________________________

---

**Engineering Lead Approval:**

Name: _______________________________

Signature: _______________________________

Date: _______________________________

---

**Final Approval (CEO/CTO/Product Owner):**

Name: _______________________________

Signature: _______________________________

Date: _______________________________

---

## Appendix A: Rollback Procedure

In case critical issues are found post-release:

### Immediate Actions

1. [ ] Mark GitHub Release as "pre-release" or delete
2. [ ] Update website download page with warning
3. [ ] Notify users via social media/email
4. [ ] Create hotfix branch from release tag
5. [ ] Investigate root cause
6. [ ] Develop and test fix
7. [ ] Prepare patch release (increment patch version)
8. [ ] Re-run full release checklist for patch

### Communication Template

```
URGENT: WireTuner v{VERSION} Issue Identified

We have identified a critical issue in WireTuner v{VERSION}:
[Description of issue]

RECOMMENDED ACTION:
- Do not install v{VERSION} if you haven't already
- If already installed, revert to v{PREVIOUS_VERSION}
- We are working on a fix and will release v{PATCH_VERSION} soon

Download previous version:
[Link to previous release]

We apologize for the inconvenience and will provide updates shortly.
```

---

## Appendix B: Secret Management

### GitHub Actions Secrets

Required secrets for automated release workflow:

**macOS Secrets:**
- `MACOS_CERTIFICATE` - Base64-encoded .p12 certificate file
- `MACOS_CERTIFICATE_PWD` - Password for .p12 certificate
- `MACOS_SIGNING_IDENTITY` - Full certificate name (e.g., "Developer ID Application: Your Name (TEAMID)")
- `APPLE_ID` - Apple ID email for notarization
- `AC_PASSWORD` - App-specific password for Apple ID
- `AC_PROVIDER` - Team ID (optional, if multiple teams)

**Windows Secrets:**
- `WINDOWS_CERTIFICATE` - Base64-encoded .pfx certificate file
- `WINDOWS_CERTIFICATE_PWD` - Password for .pfx certificate
- `SIGNING_CERT_THUMBPRINT` - Certificate thumbprint (alternative to PFX)

**To set secrets:**
1. Navigate to: **Repository → Settings → Secrets and variables → Actions**
2. Click **New repository secret**
3. Add each secret name and value
4. Verify secrets are available in workflow

---

**Document Version:** 1.0
**Iteration:** I5.T9
**Maintainer:** WireTuner DevOps Team
**Next Review:** After first release (post-0.1.0 validation)
