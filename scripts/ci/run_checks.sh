#!/usr/bin/env bash
# run_checks.sh - Orchestrates all CI checks locally
#
# Usage:
#   ./scripts/ci/run_checks.sh [options]
#
# Options:
#   --skip-lint       Skip linting checks
#   --skip-test       Skip test execution
#   --skip-diagrams   Skip diagram validation
#   --skip-format     Skip format checking
#   --help            Show this help message
#
# Examples:
#   ./scripts/ci/run_checks.sh                    # Run all checks
#   ./scripts/ci/run_checks.sh --skip-diagrams   # Skip diagram validation
#   ./scripts/ci/run_checks.sh --skip-test        # Skip tests
#
# Exit codes:
#   0 - All checks passed
#   1 - One or more checks failed

set -u  # Exit on undefined variable (but allow individual checks to fail)

# Color output helpers
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

# Parse command line arguments
SKIP_LINT=false
SKIP_TEST=false
SKIP_DIAGRAMS=false
SKIP_FORMAT=false

show_help() {
    cat << EOF
WireTuner CI Checks Runner

Usage:
  ./scripts/ci/run_checks.sh [options]

Options:
  --skip-lint       Skip linting checks (flutter analyze)
  --skip-test       Skip test execution (flutter test)
  --skip-diagrams   Skip diagram validation (PlantUML/Mermaid)
  --skip-format     Skip format checking (dart format)
  --help            Show this help message

Examples:
  ./scripts/ci/run_checks.sh                    # Run all checks
  ./scripts/ci/run_checks.sh --skip-diagrams   # Skip diagram validation
  ./scripts/ci/run_checks.sh --skip-test        # Skip tests

Exit codes:
  0 - All checks passed
  1 - One or more checks failed
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-lint)
            SKIP_LINT=true
            shift
            ;;
        --skip-test)
            SKIP_TEST=true
            shift
            ;;
        --skip-diagrams)
            SKIP_DIAGRAMS=true
            shift
            ;;
        --skip-format)
            SKIP_FORMAT=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Track overall success
OVERALL_EXIT_CODE=0

# Store check results
declare -a PASSED_CHECKS
declare -a FAILED_CHECKS

# Header
echo -e "${CYAN}${BOLD}"
cat << 'EOF'
╦ ╦┬┬─┐┌─┐╔╦╗┬ ┬┌┐┌┌─┐┬─┐
║║║│├┬┘├┤  ║ │ │││││├┤ ├┬┘
╚╩╝┴┴└─└─┘ ╩ └─┘┘└┘└─┘┴└─
CI Checks Runner
EOF
echo -e "${NC}\n"

info "Project: WireTuner"
info "Root: $PROJECT_ROOT"
echo ""

# 1. Flutter Analyze (Lint)
if [ "$SKIP_LINT" = false ]; then
    header "1. Running Flutter Analyze"

    if bash "$PROJECT_ROOT/tools/lint.sh" > /dev/null 2>&1; then
        success "Flutter analyze passed"
        PASSED_CHECKS+=("Lint")
    else
        error "Flutter analyze failed"
        FAILED_CHECKS+=("Lint")
        OVERALL_EXIT_CODE=1
        warn "Re-run with full output: bash tools/lint.sh"
    fi
else
    info "Skipping lint checks (--skip-lint)"
fi

# 2. Format Check
if [ "$SKIP_FORMAT" = false ]; then
    header "2. Checking Code Formatting"

    if dart format --set-exit-if-changed lib/ test/ > /dev/null 2>&1; then
        success "Code formatting is correct"
        PASSED_CHECKS+=("Format")
    else
        error "Code formatting issues found"
        FAILED_CHECKS+=("Format")
        OVERALL_EXIT_CODE=1
        warn "Fix with: dart format lib/ test/"
    fi
else
    info "Skipping format checks (--skip-format)"
fi

# 3. Flutter Test
if [ "$SKIP_TEST" = false ]; then
    header "3. Running Tests"

    # Capture test output for summary
    if TEST_OUTPUT=$(bash "$PROJECT_ROOT/tools/test.sh" 2>&1); then
        success "All tests passed"
        PASSED_CHECKS+=("Tests")

        # Extract test count if available
        if echo "$TEST_OUTPUT" | grep -q "All tests passed"; then
            TEST_COUNT=$(echo "$TEST_OUTPUT" | grep -oE '[0-9]+ tests?' | head -1 || echo "")
            if [ -n "$TEST_COUNT" ]; then
                info "  $TEST_COUNT"
            fi
        fi
    else
        error "Tests failed"
        FAILED_CHECKS+=("Tests")
        OVERALL_EXIT_CODE=1
        warn "Re-run with full output: bash tools/test.sh"
    fi
else
    info "Skipping tests (--skip-test)"
fi

# 4. Diagram Validation
if [ "$SKIP_DIAGRAMS" = false ]; then
    header "4. Validating Diagrams"

    if bash "$SCRIPT_DIR/diagram_check.sh" docs/diagrams > /dev/null 2>&1; then
        success "All diagrams valid"
        PASSED_CHECKS+=("Diagrams")
    else
        error "Diagram validation failed"
        FAILED_CHECKS+=("Diagrams")
        OVERALL_EXIT_CODE=1
        warn "Re-run with full output: bash scripts/ci/diagram_check.sh"
    fi
else
    info "Skipping diagram validation (--skip-diagrams)"
fi

# 5. SQLite Smoke Test (if applicable)
header "5. SQLite Smoke Test"

# Check if we have SQLite-specific tests
if dart test test/infrastructure/persistence/ --name="smoke" > /dev/null 2>&1; then
    success "SQLite smoke tests passed"
    PASSED_CHECKS+=("SQLite")
elif dart test test/ --tags=smoke > /dev/null 2>&1; then
    success "SQLite smoke tests passed"
    PASSED_CHECKS+=("SQLite")
else
    warn "No SQLite smoke tests found or they failed"
    info "  (This is optional - skipping)"
fi

# Summary
echo ""
header "Summary"

if [ ${#PASSED_CHECKS[@]} -gt 0 ]; then
    success "Passed checks (${#PASSED_CHECKS[@]}):"
    for check in "${PASSED_CHECKS[@]}"; do
        echo -e "  ${GREEN}✓${NC} $check"
    done
    echo ""
fi

if [ ${#FAILED_CHECKS[@]} -gt 0 ]; then
    error "Failed checks (${#FAILED_CHECKS[@]}):"
    for check in "${FAILED_CHECKS[@]}"; do
        echo -e "  ${RED}✗${NC} $check"
    done
    echo ""
fi

# Final result
echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

if [ $OVERALL_EXIT_CODE -eq 0 ]; then
    success "${BOLD}All CI checks passed! ✓${NC}"
    echo ""
    exit 0
else
    error "${BOLD}Some CI checks failed ✗${NC}"
    echo ""
    info "Run individual checks with full output to debug:"
    echo "  - bash tools/lint.sh"
    echo "  - bash tools/test.sh"
    echo "  - bash scripts/ci/diagram_check.sh"
    echo ""
    exit 1
fi
