#!/usr/bin/env bash
# build_macos_release.sh - Build and package macOS release DMG
#
# Usage:
#   ./scripts/ci/build_macos_release.sh [options]
#
# Options:
#   --version VERSION     Specify version string (e.g., "0.1.0")
#   --skip-notarize       Skip notarization step (for local builds)
#   --skip-sign           Skip code signing (for local builds)
#   --output-dir DIR      Output directory for DMG (default: build/release)
#   --help                Show this help message
#
# Environment Variables:
#   APPLE_ID              Apple ID email for notarization
#   AC_PASSWORD           App-specific password for notarization
#   AC_PROVIDER           Apple Developer Team ID (if multiple teams)
#   SIGNING_IDENTITY      Developer ID Application certificate name
#   SKIP_NOTARIZE         Set to "true" to skip notarization (alternative to --skip-notarize)
#   SKIP_SIGN             Set to "true" to skip signing (alternative to --skip-sign)
#
# Examples:
#   ./scripts/ci/build_macos_release.sh --version 0.1.0
#   ./scripts/ci/build_macos_release.sh --skip-notarize --skip-sign  # Local unsigned build
#   SKIP_NOTARIZE=true ./scripts/ci/build_macos_release.sh           # CI without credentials
#
# Requirements:
#   - macOS 10.15+ (for notarization)
#   - Xcode Command Line Tools
#   - Flutter 3.16.0+
#   - create-dmg tool (brew install create-dmg)
#   - Valid Developer ID certificate (for signing)
#
# Exit codes:
#   0 - Success
#   1 - Build or packaging failed
#   2 - Missing dependencies or configuration

set -euo pipefail  # Exit on error, undefined variable, or pipe failure

# Color output helpers (matching run_checks.sh style)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

error() {
    echo -e "${RED}✗ ERROR:${NC} $1" >&2
}

success() {
    echo -e "${GREEN}✓ SUCCESS:${NC} $1"
}

info() {
    echo -e "${BLUE}ℹ INFO:${NC} $1"
}

warn() {
    echo -e "${YELLOW}⚠ WARN:${NC} $1"
}

header() {
    echo -e "\n${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}${BOLD}  $1${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

# Default values
VERSION="${VERSION:-0.1.0}"
OUTPUT_DIR="$PROJECT_ROOT/build/release"
SKIP_NOTARIZE="${SKIP_NOTARIZE:-false}"
SKIP_SIGN="${SKIP_SIGN:-false}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"
APP_NAME="WireTuner"

# Parse command line arguments
show_help() {
    cat << EOF
WireTuner macOS Release Build Script

Usage:
  ./scripts/ci/build_macos_release.sh [options]

Options:
  --version VERSION     Specify version string (e.g., "0.1.0")
  --skip-notarize       Skip notarization step (for local builds)
  --skip-sign           Skip code signing (for local builds)
  --output-dir DIR      Output directory for DMG (default: build/release)
  --help                Show this help message

Environment Variables:
  APPLE_ID              Apple ID email for notarization
  AC_PASSWORD           App-specific password for notarization
  AC_PROVIDER           Apple Developer Team ID (if multiple teams)
  SIGNING_IDENTITY      Developer ID Application certificate name
  SKIP_NOTARIZE         Set to "true" to skip notarization
  SKIP_SIGN             Set to "true" to skip signing

Examples:
  # Full signed and notarized release build
  SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \\
    APPLE_ID="your@email.com" \\
    AC_PASSWORD="app-specific-password" \\
    ./scripts/ci/build_macos_release.sh --version 0.1.0

  # Local unsigned build for testing
  ./scripts/ci/build_macos_release.sh --skip-notarize --skip-sign

Requirements:
  - macOS 10.15+ (for notarization)
  - Xcode Command Line Tools
  - Flutter 3.16.0+
  - create-dmg tool (brew install create-dmg)
  - Valid Developer ID certificate (for signing)

Exit codes:
  0 - Success
  1 - Build or packaging failed
  2 - Missing dependencies or configuration
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            VERSION="$2"
            shift 2
            ;;
        --skip-notarize)
            SKIP_NOTARIZE=true
            shift
            ;;
        --skip-sign)
            SKIP_SIGN=true
            shift
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            show_help
            exit 2
            ;;
    esac
done

# Header
echo -e "${CYAN}${BOLD}"
cat << 'EOF'
╦ ╦┬┬─┐┌─┐╔╦╗┬ ┬┌┐┌┌─┐┬─┐
║║║│├┬┘├┤  ║ │ │││││├┤ ├┬┘
╚╩╝┴┴└─└─┘ ╩ └─┘┘└┘└─┘┴└─
macOS Release Build
EOF
echo -e "${NC}\n"

info "Version: $VERSION"
info "Project Root: $PROJECT_ROOT"
info "Output Directory: $OUTPUT_DIR"
echo ""

# Pre-flight checks
header "Pre-flight Checks"

# Check macOS
if [[ "$(uname)" != "Darwin" ]]; then
    error "This script must be run on macOS"
    exit 2
fi
success "Running on macOS"

# Check Flutter
if ! command -v flutter &> /dev/null; then
    error "Flutter is not installed or not in PATH"
    exit 2
fi
FLUTTER_VERSION=$(flutter --version | head -1 | awk '{print $2}')
success "Flutter $FLUTTER_VERSION installed"

# Check Xcode Command Line Tools
if ! xcode-select -p &> /dev/null; then
    error "Xcode Command Line Tools not installed"
    info "Install with: xcode-select --install"
    exit 2
fi
success "Xcode Command Line Tools installed"

# Check create-dmg tool (optional but recommended)
if ! command -v create-dmg &> /dev/null; then
    warn "create-dmg not found (will use manual DMG creation)"
    info "Install with: brew install create-dmg"
    USE_CREATE_DMG=false
else
    success "create-dmg tool available"
    USE_CREATE_DMG=true
fi

# Check signing configuration
if [[ "$SKIP_SIGN" == "false" ]]; then
    if [[ -z "$SIGNING_IDENTITY" ]]; then
        warn "SIGNING_IDENTITY not set, will attempt to auto-detect"
        # Try to find a Developer ID Application certificate
        SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed -E 's/.*"(.*)"/\1/' || echo "")
        if [[ -z "$SIGNING_IDENTITY" ]]; then
            error "No Developer ID Application certificate found"
            info "Either install a certificate or use --skip-sign for local builds"
            exit 2
        else
            success "Found signing identity: $SIGNING_IDENTITY"
        fi
    else
        success "Using signing identity: $SIGNING_IDENTITY"
    fi
else
    warn "Code signing will be skipped"
fi

# Check notarization configuration
if [[ "$SKIP_NOTARIZE" == "false" ]]; then
    if [[ -z "${APPLE_ID:-}" ]] || [[ -z "${AC_PASSWORD:-}" ]]; then
        error "Notarization requested but APPLE_ID or AC_PASSWORD not set"
        info "Either set environment variables or use --skip-notarize for local builds"
        exit 2
    fi
    success "Notarization credentials configured"
else
    warn "Notarization will be skipped"
fi

echo ""

# Step 1: Get Flutter dependencies
header "1. Getting Flutter Dependencies"

flutter pub get
success "Dependencies fetched"

# Step 2: Clean previous builds
header "2. Cleaning Previous Builds"

flutter clean
mkdir -p "$OUTPUT_DIR"
success "Build directory cleaned"

# Step 3: Build macOS release
header "3. Building macOS Release"

flutter build macos --release

APP_PATH="$PROJECT_ROOT/build/macos/Build/Products/Release/$APP_NAME.app"

if [[ ! -d "$APP_PATH" ]]; then
    error "Build failed - app bundle not found at $APP_PATH"
    exit 1
fi

success "macOS app built successfully"
info "App bundle: $APP_PATH"

# Step 4: Code signing
if [[ "$SKIP_SIGN" == "false" ]]; then
    header "4. Code Signing"

    info "Signing with identity: $SIGNING_IDENTITY"

    # Sign the app bundle with hardened runtime
    codesign --deep --force --verify --verbose \
        --options runtime \
        --sign "$SIGNING_IDENTITY" \
        "$APP_PATH"

    # Verify signature
    codesign --verify --verbose=4 "$APP_PATH"

    success "App bundle signed successfully"
else
    warn "Skipping code signing"
fi

# Step 5: Create DMG
header "5. Creating DMG"

DMG_NAME="$APP_NAME-$VERSION-macOS.dmg"
DMG_PATH="$OUTPUT_DIR/$DMG_NAME"

# Remove existing DMG if present
rm -f "$DMG_PATH"

if [[ "$USE_CREATE_DMG" == true ]]; then
    # Use create-dmg tool for better DMG layout
    info "Creating DMG with create-dmg..."

    # Build create-dmg arguments
    DMG_ARGS=(
        --volname "$APP_NAME $VERSION"
        --window-pos 200 120
        --window-size 600 400
        --icon-size 100
        --icon "$APP_NAME.app" 175 120
        --hide-extension "$APP_NAME.app"
        --app-drop-link 425 120
    )

    # Add volume icon if AppIcon.icns exists
    if [[ -f "$APP_PATH/Contents/Resources/AppIcon.icns" ]]; then
        DMG_ARGS+=(--volicon "$APP_PATH/Contents/Resources/AppIcon.icns")
    fi

    create-dmg "${DMG_ARGS[@]}" "$DMG_PATH" "$APP_PATH" || {
        warn "create-dmg failed, falling back to manual creation"
        USE_CREATE_DMG=false
    }
fi

if [[ "$USE_CREATE_DMG" == false ]]; then
    # Manual DMG creation
    info "Creating DMG manually with hdiutil..."

    DMG_TEMP_DIR="$(mktemp -d)"
    cp -R "$APP_PATH" "$DMG_TEMP_DIR/"

    hdiutil create -volname "$APP_NAME $VERSION" \
        -srcfolder "$DMG_TEMP_DIR" \
        -ov -format UDZO \
        "$DMG_PATH"

    rm -rf "$DMG_TEMP_DIR"
fi

if [[ ! -f "$DMG_PATH" ]]; then
    error "DMG creation failed"
    exit 1
fi

success "DMG created: $DMG_PATH"

# Step 6: Sign DMG (if signing enabled)
if [[ "$SKIP_SIGN" == "false" ]]; then
    header "6. Signing DMG"

    codesign --sign "$SIGNING_IDENTITY" "$DMG_PATH"
    codesign --verify --verbose=4 "$DMG_PATH"

    success "DMG signed successfully"
else
    warn "Skipping DMG signing"
fi

# Step 7: Notarization
if [[ "$SKIP_NOTARIZE" == "false" ]]; then
    header "7. Notarizing with Apple"

    info "Submitting DMG for notarization (this may take several minutes)..."

    # Submit for notarization
    NOTARIZE_ARGS=(
        "$DMG_PATH"
        --wait
        --apple-id "$APPLE_ID"
        --password "$AC_PASSWORD"
    )

    # Add team ID if provided (required for accounts with multiple teams)
    if [[ -n "${AC_PROVIDER:-}" ]]; then
        NOTARIZE_ARGS+=(--team-id "$AC_PROVIDER")
    fi

    if xcrun notarytool submit "${NOTARIZE_ARGS[@]}"; then
        success "Notarization successful"

        # Staple the notarization ticket to the DMG
        info "Stapling notarization ticket..."
        xcrun stapler staple "$DMG_PATH"

        # Verify stapling
        xcrun stapler validate "$DMG_PATH"

        success "Notarization ticket stapled"
    else
        error "Notarization failed"
        warn "You can check notarization logs with:"
        warn "  xcrun notarytool log <submission-id> --apple-id $APPLE_ID --password [PASSWORD]"
        exit 1
    fi
else
    warn "Skipping notarization"
fi

# Step 8: Generate SHA256 hash
header "8. Generating SHA256 Hash"

HASH_FILE="$OUTPUT_DIR/$APP_NAME-$VERSION-macOS.sha256"
shasum -a 256 "$DMG_PATH" | awk '{print $1}' > "$HASH_FILE"
HASH_VALUE=$(cat "$HASH_FILE")

success "SHA256 hash generated"
info "Hash: $HASH_VALUE"
info "Hash file: $HASH_FILE"

# Final summary
echo ""
header "Build Summary"

DMG_SIZE=$(du -h "$DMG_PATH" | awk '{print $1}')

success "macOS release build completed successfully!"
echo ""
echo -e "${BOLD}Build Information:${NC}"
echo "  Version:        $VERSION"
echo "  DMG:            $DMG_PATH"
echo "  DMG Size:       $DMG_SIZE"
echo "  SHA256:         $HASH_VALUE"
echo "  Signed:         $(if [[ "$SKIP_SIGN" == "false" ]]; then echo "✓ Yes"; else echo "✗ No"; fi)"
echo "  Notarized:      $(if [[ "$SKIP_NOTARIZE" == "false" ]]; then echo "✓ Yes"; else echo "✗ No"; fi)"
echo ""

if [[ "$SKIP_SIGN" == "true" ]] || [[ "$SKIP_NOTARIZE" == "true" ]]; then
    warn "This build is NOT suitable for public distribution"
    info "For release builds, ensure code signing and notarization are enabled"
    echo ""
fi

success "All steps completed!"
echo ""

exit 0
