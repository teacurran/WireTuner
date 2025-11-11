#!/bin/bash
# WireTuner macOS DMG Builder
# Task: I5.T5 - Platform-specific installer generation
# Requirements: FR-001 (macOS Distribution), NFR-003 (Code Signing)
# <!-- anchor: macos-dmg-builder -->

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
readonly BUILD_DIR="${PROJECT_ROOT}/build/macos"
readonly APP_NAME="WireTuner"

# Color helpers
color_print() {
    local color=$1
    shift
    echo -e "\033[${color}m$*\033[0m"
}

success() { color_print "0;32" "✓ $*"; }
error() { color_print "0;31" "✗ $*"; }
info() { color_print "0;34" "ℹ $*"; }
warning() { color_print "0;33" "⚠ $*"; }

# ============================================================================
# Argument Parsing
# ============================================================================

SKIP_SIGN=false
SKIP_NOTARIZE=false
VERSION="0.1.0"

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Builds signed and notarized DMG installer for macOS.

OPTIONS:
    --version VERSION       App version (default: 0.1.0)
    --skip-sign             Skip code signing
    --skip-notarize         Skip notarization (implies skip-staple)
    -h, --help              Show this help

ENVIRONMENT:
    APPLE_ID                Apple Developer account email
    APPLE_ID_PASSWORD       App-specific password
    APPLE_TEAM_ID           Developer Team ID
    DEVELOPER_ID            Developer ID Application certificate name

NOTES:
    - Use --skip-notarize for local dry runs
    - Notarization requires network access and can take 5-15 minutes
    - Stapling embeds notarization ticket into DMG for offline verification

EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            VERSION="$2"
            shift 2
            ;;
        --skip-sign)
            SKIP_SIGN=true
            shift
            ;;
        --skip-notarize)
            SKIP_NOTARIZE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            error "Unknown option: $1"
            usage
            ;;
    esac
done

# ============================================================================
# Pre-flight Checks
# ============================================================================

info "WireTuner macOS DMG Builder v${VERSION}"

# Check for required tools
if ! command -v flutter &> /dev/null; then
    error "Flutter not found in PATH"
    exit 1
fi

# Validate signing environment
if [[ "$SKIP_SIGN" == false ]]; then
    if [[ -z "${DEVELOPER_ID:-}" ]]; then
        warning "DEVELOPER_ID not set, will attempt auto-detection"
        DEVELOPER_ID="Developer ID Application"
    fi

    if ! security find-identity -v -p codesigning | grep -q "$DEVELOPER_ID"; then
        error "Code signing identity not found: $DEVELOPER_ID"
        error "Run: security find-identity -v -p codesigning"
        exit 1
    fi
    success "Code signing identity verified"
fi

# Validate notarization environment
if [[ "$SKIP_NOTARIZE" == false ]]; then
    if [[ -z "${APPLE_ID:-}" || -z "${APPLE_ID_PASSWORD:-}" || -z "${APPLE_TEAM_ID:-}" ]]; then
        error "Notarization requires: APPLE_ID, APPLE_ID_PASSWORD, APPLE_TEAM_ID"
        exit 1
    fi

    if ! command -v xcrun &> /dev/null; then
        error "xcrun not found - Xcode Command Line Tools required"
        exit 1
    fi
    success "Notarization credentials verified"
fi

# ============================================================================
# Build Flutter App
# ============================================================================

info "Building Flutter macOS app..."
mkdir -p "${BUILD_DIR}"

cd "${PROJECT_ROOT}"

# Clean previous builds
flutter clean
success "Cleaned previous builds"

# Build release app
if flutter build macos --release; then
    success "Flutter build completed"
else
    error "Flutter build failed"
    exit 1
fi

APP_BUNDLE="${PROJECT_ROOT}/build/macos/Build/Products/Release/${APP_NAME}.app"

if [[ ! -d "$APP_BUNDLE" ]]; then
    error "App bundle not found: $APP_BUNDLE"
    exit 1
fi

info "App bundle: $APP_BUNDLE"

# ============================================================================
# Code Signing
# ============================================================================

if [[ "$SKIP_SIGN" == false ]]; then
    info "Signing app bundle with: $DEVELOPER_ID"

    # Sign all executables and frameworks recursively
    if codesign --force --deep --sign "$DEVELOPER_ID" \
        --options runtime \
        --entitlements "${PROJECT_ROOT}/macos/Runner/Release.entitlements" \
        --timestamp \
        "$APP_BUNDLE"; then
        success "App bundle signed successfully"
    else
        error "Code signing failed"
        exit 1
    fi

    # Verify signature
    if codesign --verify --verbose=4 "$APP_BUNDLE"; then
        success "Signature verified"
    else
        error "Signature verification failed"
        exit 1
    fi
else
    warning "Skipping code signing (--skip-sign)"
fi

# ============================================================================
# DMG Creation
# ============================================================================

DMG_PATH="${BUILD_DIR}/${APP_NAME}-${VERSION}.dmg"
DMG_TEMP="${BUILD_DIR}/${APP_NAME}-${VERSION}-temp.dmg"

info "Creating DMG..."

# Remove existing DMGs
rm -f "$DMG_PATH" "$DMG_TEMP"

# Check for create-dmg tool
if command -v create-dmg &> /dev/null; then
    # Use create-dmg for professional appearance
    if create-dmg \
        --volname "${APP_NAME}" \
        --volicon "${APP_BUNDLE}/Contents/Resources/AppIcon.icns" \
        --window-pos 200 120 \
        --window-size 800 400 \
        --icon-size 100 \
        --icon "${APP_NAME}.app" 200 190 \
        --hide-extension "${APP_NAME}.app" \
        --app-drop-link 600 185 \
        --no-internet-enable \
        "$DMG_PATH" \
        "$APP_BUNDLE"; then
        success "DMG created with create-dmg"
    else
        error "create-dmg failed"
        exit 1
    fi
else
    # Fallback to hdiutil
    warning "create-dmg not found, using hdiutil (basic DMG)"

    hdiutil create -volname "${APP_NAME}" \
        -srcfolder "$APP_BUNDLE" \
        -ov -format UDZO \
        "$DMG_PATH"

    success "DMG created with hdiutil"
fi

if [[ ! -f "$DMG_PATH" ]]; then
    error "DMG not created: $DMG_PATH"
    exit 1
fi

info "DMG: $DMG_PATH ($(du -h "$DMG_PATH" | cut -f1))"

# ============================================================================
# Sign DMG
# ============================================================================

if [[ "$SKIP_SIGN" == false ]]; then
    info "Signing DMG..."

    if codesign --force --sign "$DEVELOPER_ID" \
        --timestamp \
        "$DMG_PATH"; then
        success "DMG signed"
    else
        error "DMG signing failed"
        exit 1
    fi
else
    warning "Skipping DMG signing"
fi

# ============================================================================
# Notarization
# ============================================================================

if [[ "$SKIP_NOTARIZE" == false ]]; then
    info "Submitting DMG for notarization (this may take 5-15 minutes)..."

    # Submit to Apple
    SUBMIT_OUTPUT=$(xcrun notarytool submit "$DMG_PATH" \
        --apple-id "$APPLE_ID" \
        --password "$APPLE_ID_PASSWORD" \
        --team-id "$APPLE_TEAM_ID" \
        --wait 2>&1)

    echo "$SUBMIT_OUTPUT"

    if echo "$SUBMIT_OUTPUT" | grep -q "status: Accepted"; then
        success "Notarization accepted"

        # Staple notarization ticket
        info "Stapling notarization ticket..."
        if xcrun stapler staple "$DMG_PATH"; then
            success "Notarization ticket stapled"
        else
            warning "Stapling failed - DMG is notarized but requires network for first verification"
        fi
    else
        error "Notarization failed or timed out"
        error "Check status with: xcrun notarytool log <REQUEST_ID> --apple-id $APPLE_ID --password \$APPLE_ID_PASSWORD --team-id $APPLE_TEAM_ID"
        exit 1
    fi
else
    warning "Skipping notarization (--skip-notarize)"
    warning "DMG will show security warnings on first launch"
fi

# ============================================================================
# Generate Checksum
# ============================================================================

CHECKSUM_FILE="${DMG_PATH}.sha256"
shasum -a 256 "$DMG_PATH" > "$CHECKSUM_FILE"
success "Checksum: $CHECKSUM_FILE"

cat "$CHECKSUM_FILE"

# ============================================================================
# Summary
# ============================================================================

success "macOS DMG build completed!"
info ""
info "Artifact: $DMG_PATH"
info "Checksum: $CHECKSUM_FILE"
info "Signed: $([ "$SKIP_SIGN" == false ] && echo "Yes" || echo "No")"
info "Notarized: $([ "$SKIP_NOTARIZE" == false ] && echo "Yes" || echo "No")"
info ""
info "Verification:"
info "  spctl -a -vv -t install $DMG_PATH"
info "  codesign -dvv $DMG_PATH"

# Line count verification
SCRIPT_LINES=$(wc -l < "$0")
info "Script verified: ${SCRIPT_LINES} lines"

exit 0
