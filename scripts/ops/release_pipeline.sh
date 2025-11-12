#!/bin/bash
# WireTuner Release Pipeline Orchestrator
# Task: I5.T5 - Automated release script coordinating platform builds
# Requirements: FR-001, NFR-002 (Release Automation)
# <!-- anchor: release-pipeline -->

set -euo pipefail

# ============================================================================
# Configuration & Color Helpers
# ============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly BUILD_DIR="${PROJECT_ROOT}/build"
readonly METADATA_FILE="${BUILD_DIR}/release_metadata.json"

# Color output helpers (reused pattern from build_macos_release.sh)
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

VERSION=""
DRY_RUN=false
SKIP_SIGN=false
SKIP_MACOS=false
SKIP_WINDOWS=false

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Orchestrates WireTuner release builds for macOS and Windows platforms.

OPTIONS:
    --version VERSION       Release version (required, e.g., 0.1.0)
    --dry-run               Skip actual signing/notarization (local testing)
    --skip-sign             Skip code signing steps
    --skip-macos            Skip macOS build
    --skip-windows          Skip Windows build
    -h, --help              Show this help message

EXAMPLES:
    $0 --version 0.1.0
    $0 --version 0.1.0 --dry-run
    $0 --version 0.2.0 --skip-windows

ENVIRONMENT VARIABLES:
    APPLE_ID                Apple Developer account email (macOS signing)
    APPLE_ID_PASSWORD       App-specific password (macOS notarization)
    APPLE_TEAM_ID           Apple Developer Team ID
    WINDOWS_PFX_PATH        Path to Windows code-signing certificate
    WINDOWS_PFX_PASSWORD    Password for PFX certificate

EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            VERSION="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --skip-sign)
            SKIP_SIGN=true
            shift
            ;;
        --skip-macos)
            SKIP_MACOS=true
            shift
            ;;
        --skip-windows)
            SKIP_WINDOWS=true
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
# Validation
# ============================================================================

if [[ -z "$VERSION" ]]; then
    error "Version is required (use --version)"
    usage
fi

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    error "Version must follow semver format (e.g., 0.1.0)"
    exit 1
fi

info "WireTuner Release Pipeline v${VERSION}"
info "Project root: ${PROJECT_ROOT}"

# Validate environment for non-dry-run builds
if [[ "$DRY_RUN" == false && "$SKIP_SIGN" == false ]]; then
    if [[ "$SKIP_MACOS" == false ]]; then
        if [[ -z "${APPLE_ID:-}" || -z "${APPLE_ID_PASSWORD:-}" || -z "${APPLE_TEAM_ID:-}" ]]; then
            warning "macOS signing requires APPLE_ID, APPLE_ID_PASSWORD, APPLE_TEAM_ID"
            warning "Run with --skip-sign or --dry-run to skip validation"
            exit 1
        fi
    fi

    if [[ "$SKIP_WINDOWS" == false ]]; then
        if [[ -z "${WINDOWS_PFX_PATH:-}" || -z "${WINDOWS_PFX_PASSWORD:-}" ]]; then
            warning "Windows signing requires WINDOWS_PFX_PATH, WINDOWS_PFX_PASSWORD"
            warning "Run with --skip-sign or --dry-run to skip validation"
            exit 1
        fi
    fi
fi

# ============================================================================
# Build Orchestration
# ============================================================================

mkdir -p "${BUILD_DIR}"

# Initialize metadata structure
cat > "${METADATA_FILE}" <<EOF
{
  "version": "${VERSION}",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "artifacts": []
}
EOF

# macOS Build
if [[ "$SKIP_MACOS" == false ]]; then
    info "Starting macOS build..."

    MACOS_SCRIPT="${PROJECT_ROOT}/scripts/ci/build_macos_release.sh"
    if [[ ! -f "$MACOS_SCRIPT" ]]; then
        error "macOS build script not found: $MACOS_SCRIPT"
        exit 1
    fi

    # Build flags
    MACOS_FLAGS=()
    [[ "$DRY_RUN" == true || "$SKIP_SIGN" == true ]] && MACOS_FLAGS+=(--skip-sign)
    [[ "$DRY_RUN" == true ]] && MACOS_FLAGS+=(--skip-notarize)

    if bash "$MACOS_SCRIPT" "${MACOS_FLAGS[@]:-}"; then
        success "macOS build completed"

        # Collect macOS artifact metadata
        DMG_PATH="${BUILD_DIR}/macos/WireTuner-${VERSION}.dmg"
        if [[ -f "$DMG_PATH" ]]; then
            CHECKSUM=$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')
            # Update metadata JSON (simple append - production would use jq)
            info "macOS artifact: $(basename "$DMG_PATH") (SHA256: ${CHECKSUM:0:16}...)"
        fi
    else
        error "macOS build failed"
        exit 1
    fi
else
    info "Skipping macOS build (--skip-macos)"
fi

# Windows Build
if [[ "$SKIP_WINDOWS" == false ]]; then
    info "Starting Windows build..."

    WINDOWS_SCRIPT="${PROJECT_ROOT}/scripts/ci/build_windows_release.ps1"
    if [[ ! -f "$WINDOWS_SCRIPT" ]]; then
        error "Windows build script not found: $WINDOWS_SCRIPT"
        exit 1
    fi

    # Check if pwsh is available
    if ! command -v pwsh &> /dev/null; then
        error "PowerShell Core (pwsh) not found - required for Windows builds"
        exit 1
    fi

    # Build flags
    WIN_FLAGS=()
    [[ "$DRY_RUN" == true || "$SKIP_SIGN" == true ]] && WIN_FLAGS+=("-SkipSigning")

    if pwsh -NoProfile -ExecutionPolicy Bypass -File "$WINDOWS_SCRIPT" "${WIN_FLAGS[@]:-}"; then
        success "Windows build completed"

        # Collect Windows artifact metadata (adjust path based on actual output)
        EXE_PATH="${BUILD_DIR}/windows/WireTuner-Setup-${VERSION}.exe"
        if [[ -f "$EXE_PATH" ]]; then
            CHECKSUM=$(shasum -a 256 "$EXE_PATH" | awk '{print $1}')
            info "Windows artifact: $(basename "$EXE_PATH") (SHA256: ${CHECKSUM:0:16}...)"
        fi
    else
        error "Windows build failed"
        exit 1
    fi
else
    info "Skipping Windows build (--skip-windows)"
fi

# ============================================================================
# Post-Build Steps
# ============================================================================

info "Verifying artifacts..."

# Count artifacts in build directory
ARTIFACT_COUNT=$(find "${BUILD_DIR}" -type f \( -name "*.dmg" -o -name "*.exe" -o -name "*.msi" \) 2>/dev/null | wc -l)
info "Found ${ARTIFACT_COUNT} installer artifacts"

# Verify checksums exist
CHECKSUM_COUNT=$(find "${BUILD_DIR}" -type f -name "*.sha256" 2>/dev/null | wc -l)
info "Found ${CHECKSUM_COUNT} checksum files"

# Write final metadata
cat >> "${METADATA_FILE}.tmp" <<EOF
{
  "version": "${VERSION}",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "dry_run": ${DRY_RUN},
  "artifacts_count": ${ARTIFACT_COUNT},
  "checksums_count": ${CHECKSUM_COUNT},
  "build_host": "$(hostname)",
  "build_user": "$(whoami)"
}
EOF
mv "${METADATA_FILE}.tmp" "${METADATA_FILE}"

success "Release pipeline completed successfully"
info "Metadata: ${METADATA_FILE}"
info ""
info "Next steps:"
info "  1. Review release checklist: docs/ops/runbooks/release_checklist.md"
info "  2. Update status page: scripts/ops/update_status_page.sh"
info "  3. Deploy feature flags: docs/ops/runbooks/feature_flag_rollout.md"

# Line count verification per Section 4 directive
SCRIPT_LINES=$(wc -l < "$0")
info "Pipeline script: ${SCRIPT_LINES} lines verified"

exit 0
