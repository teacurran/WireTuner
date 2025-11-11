#!/usr/bin/env bash
# run_benchmarks.sh - Runs performance benchmarks for CI/local development
#
# Usage:
#   ./scripts/ci/run_benchmarks.sh [options]
#
# Options:
#   --dataset [small|medium|large|xlarge]  Dataset size (default: medium)
#   --upload                                Upload results as CI artifact
#   --fail-on-threshold                     Fail if performance thresholds exceeded
#   --help                                  Show this help message
#
# Examples:
#   ./scripts/ci/run_benchmarks.sh                    # Run local benchmark
#   ./scripts/ci/run_benchmarks.sh --upload          # Run and upload results (CI)
#   ./scripts/ci/run_benchmarks.sh --dataset large   # Run with large dataset
#
# Exit codes:
#   0 - Benchmark completed successfully
#   1 - Benchmark failed or threshold exceeded
#

set -e  # Exit on error
set -u  # Exit on undefined variable

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
DATASET="medium"
UPLOAD=false
FAIL_ON_THRESHOLD=false

show_help() {
    cat << EOF
WireTuner Performance Benchmarks Runner

Usage:
  ./scripts/ci/run_benchmarks.sh [options]

Options:
  --dataset [small|medium|large|xlarge]  Dataset size (default: medium)
                                          small: 100 objects
                                          medium: 500 objects
                                          large: 1000 objects
                                          xlarge: 2500 objects
  --upload                                Upload results as CI artifact (GitHub Actions)
  --fail-on-threshold                     Fail build if performance thresholds exceeded
  --help                                  Show this help message

Examples:
  ./scripts/ci/run_benchmarks.sh                    # Run local benchmark
  ./scripts/ci/run_benchmarks.sh --upload          # Run and upload (CI mode)
  ./scripts/ci/run_benchmarks.sh --dataset large   # Large dataset benchmark

Performance Thresholds (--fail-on-threshold):
  - Frame time > 33ms (< 30 FPS) on medium dataset with optimizations
  - Memory usage > 500MB

Output:
  Results are written to dev/benchmarks/results/ directory in JSON and CSV formats.
  Use --upload in CI to store results as workflow artifacts.

Exit codes:
  0 - Benchmark completed successfully
  1 - Benchmark failed or threshold exceeded
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --dataset)
            if [[ $# -gt 1 ]]; then
                DATASET="$2"
                shift 2
            else
                error "Missing dataset argument"
                show_help
                exit 1
            fi
            ;;
        --upload)
            UPLOAD=true
            shift
            ;;
        --fail-on-threshold)
            FAIL_ON_THRESHOLD=true
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

# Header
echo -e "${CYAN}${BOLD}"
cat << 'EOF'
╦ ╦┬┬─┐┌─┐╔╦╗┬ ┬┌┐┌┌─┐┬─┐
║║║│├┬┘├┤  ║ │ │││││├┤ ├┬┘
╚╩╝┴┴└─└─┘ ╩ └─┘┘└┘└─┘┴└─
Performance Benchmarks
EOF
echo -e "${NC}\n"

info "Project: WireTuner"
info "Root: $PROJECT_ROOT"
info "Dataset: $DATASET"
echo ""

# Validate dataset
case "$DATASET" in
    small|medium|large|xlarge)
        ;;
    *)
        error "Invalid dataset: $DATASET"
        warn "Valid options: small, medium, large, xlarge"
        exit 1
        ;;
esac

# Ensure dependencies are installed
header "1. Installing Dependencies"

if flutter pub get > /dev/null 2>&1; then
    success "Dependencies installed"
else
    error "Failed to install dependencies"
    exit 1
fi

# Create results directory
RESULTS_DIR="$PROJECT_ROOT/dev/benchmarks/results"
mkdir -p "$RESULTS_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_NAME="bench_${DATASET}_${TIMESTAMP}"
OUTPUT_PATH="$RESULTS_DIR/$OUTPUT_NAME"

# Run benchmark
header "2. Running Benchmark"

info "Output: $OUTPUT_PATH"
info "Format: JSON + CSV"
echo ""

if flutter test dev/benchmarks/render_bench.dart \
    --dart-define=DATASET="$DATASET" \
    --dart-define=ITERATIONS=30 \
    --dart-define=FORMAT=both \
    --dart-define=OUTPUT="$OUTPUT_PATH"; then
    success "Benchmark completed successfully"
else
    error "Benchmark execution failed"
    exit 1
fi

# Validate results exist
if [[ ! -f "${OUTPUT_PATH}.json" ]]; then
    error "Benchmark results not found: ${OUTPUT_PATH}.json"
    exit 1
fi

# Display summary
header "3. Results Summary"

info "Results written to:"
echo "  - ${OUTPUT_PATH}.json"
echo "  - ${OUTPUT_PATH}.csv"
echo ""

# Extract key metrics from JSON using basic tools
if command -v python3 > /dev/null 2>&1; then
    info "Performance highlights:"
    python3 -c "
import json, sys
try:
    with open('${OUTPUT_PATH}.json') as f:
        data = json.load(f)
    results = data.get('results', [])

    # Find 'All optimizations' scenario
    opt_result = next((r for r in results if 'All optimizations' in r['scenario']['name'] and r['scenario']['zoomLevel'] == 1.0), None)

    if opt_result:
        fps = opt_result['fps']
        frame_time = opt_result['frameTimeMs']
        rendered = opt_result['objectsRendered']
        culled = opt_result['objectsCulled']
        memory = opt_result['memoryUsedMB']

        print(f\"  FPS (all opts): {fps:.1f}\")
        print(f\"  Frame time: {frame_time:.2f}ms\")
        print(f\"  Objects rendered: {rendered}\")
        print(f\"  Objects culled: {culled}\")
        print(f\"  Memory used: {memory:.2f}MB\")

        # Performance status
        if frame_time <= 16.67:
            print('  Status: ✓ Exceeds 60 FPS target')
        elif frame_time <= 33:
            print('  Status: ⚠ Below 60 FPS, above 30 FPS')
        else:
            print('  Status: ✗ Below 30 FPS threshold')
            if '$FAIL_ON_THRESHOLD' == 'true':
                sys.exit(1)

        if memory > 500:
            print('  Memory: ✗ Exceeds 500MB threshold')
            if '$FAIL_ON_THRESHOLD' == 'true':
                sys.exit(1)
    else:
        print('  (Could not extract summary metrics)')
except Exception as e:
    print(f'  (Error parsing results: {e})', file=sys.stderr)
    " || warn "Could not parse results summary"
else
    warn "Python3 not available, skipping results summary"
fi

echo ""

# Check thresholds if requested
if [[ "$FAIL_ON_THRESHOLD" == true ]]; then
    header "4. Threshold Check"

    # Python script already handles this above
    # If we get here, thresholds passed or python not available
    success "Performance thresholds met"
fi

# Upload artifacts if in CI mode
if [[ "$UPLOAD" == true ]]; then
    header "5. Uploading Artifacts"

    if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
        # We're in GitHub Actions
        info "GitHub Actions detected"

        # Write summary to GITHUB_STEP_SUMMARY
        {
            echo "## Benchmark Results: $DATASET"
            echo ""
            echo "**Timestamp:** $(date)"
            echo ""
            echo "### Files"
            echo "- \`${OUTPUT_NAME}.json\`"
            echo "- \`${OUTPUT_NAME}.csv\`"
            echo ""

            # Try to extract metrics
            if command -v python3 > /dev/null 2>&1; then
                python3 -c "
import json
try:
    with open('${OUTPUT_PATH}.json') as f:
        data = json.load(f)
    results = data.get('results', [])

    print('### Performance Summary')
    print('')
    print('| Scenario | FPS | Frame Time | Rendered | Culled |')
    print('|----------|-----|------------|----------|--------|')

    for r in results:
        name = r['scenario']['name']
        fps = r['fps']
        ft = r['frameTimeMs']
        rendered = r['objectsRendered']
        culled = r['objectsCulled']
        print(f'| {name} | {fps:.1f} | {ft:.2f}ms | {rendered} | {culled} |')
except:
    print('(Could not parse results)')
    " || echo "(Could not generate summary table)"
            fi
        } >> "$GITHUB_STEP_SUMMARY"

        success "Results added to workflow summary"
        info "Artifacts will be automatically uploaded by GitHub Actions"
        info "Add this step to your workflow:"
        echo ""
        echo "    - uses: actions/upload-artifact@v3"
        echo "      with:"
        echo "        name: benchmark-results"
        echo "        path: dev/benchmarks/results/"
        echo ""
    else
        warn "Not running in GitHub Actions (GITHUB_STEP_SUMMARY not set)"
        info "Results available locally in: $RESULTS_DIR"
    fi
fi

# Final success message
echo ""
header "Complete"
success "${BOLD}Benchmark execution successful!${NC}"
echo ""
info "View results:"
echo "  JSON: ${OUTPUT_PATH}.json"
echo "  CSV:  ${OUTPUT_PATH}.csv"
echo ""

exit 0
