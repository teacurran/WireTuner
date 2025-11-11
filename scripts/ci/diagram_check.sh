#!/usr/bin/env bash
# diagram_check.sh - Validates PlantUML and Mermaid diagram syntax
#
# Usage:
#   ./scripts/ci/diagram_check.sh [diagram_directory]
#
# Arguments:
#   diagram_directory - Optional: Directory containing diagrams (default: docs/diagrams)
#
# Examples:
#   ./scripts/ci/diagram_check.sh
#   ./scripts/ci/diagram_check.sh docs/diagrams
#
# Requirements:
#   - plantuml (install via: brew install plantuml) OR java + plantuml.jar
#   - mmdc from @mermaid-js/mermaid-cli (install via: npm install -g @mermaid-js/mermaid-cli)
#
# Exit codes:
#   0 - All diagrams valid
#   1 - Invalid arguments or validation failures
#   2 - Required tools not found

set -euo pipefail

# Color output helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

error() {
    echo -e "${RED}ERROR:${NC} $1" >&2
}

success() {
    echo -e "${GREEN}SUCCESS:${NC} $1"
}

info() {
    echo -e "${BLUE}INFO:${NC} $1"
}

warn() {
    echo -e "${YELLOW}WARN:${NC} $1"
}

# Check if PlantUML is available
check_plantuml() {
    if command -v plantuml &> /dev/null; then
        PLANTUML_CMD="plantuml"
        return 0
    elif command -v java &> /dev/null && [ -f "plantuml.jar" ]; then
        PLANTUML_CMD="java -jar plantuml.jar"
        return 0
    else
        error "PlantUML not found."
        info "Install via: brew install plantuml"
        info "Or download plantuml.jar from https://plantuml.com/download"
        return 1
    fi
}

# Check if Mermaid CLI is available
check_mermaid() {
    if command -v mmdc &> /dev/null; then
        return 0
    else
        warn "Mermaid CLI (mmdc) not found. Skipping .mmd validation."
        info "Install via: npm install -g @mermaid-js/mermaid-cli"
        return 1
    fi
}

# Validate PlantUML file syntax
validate_plantuml() {
    local file="$1"
    info "Validating PlantUML: $file"

    # Use -syntax flag to check syntax without generating output
    if $PLANTUML_CMD -syntax "$file" > /dev/null 2>&1; then
        success "  ✓ Valid syntax"
        return 0
    else
        error "  ✗ Syntax error in $file"
        $PLANTUML_CMD -syntax "$file" 2>&1 || true
        return 1
    fi
}

# Validate Mermaid file syntax
validate_mermaid() {
    local file="$1"
    info "Validating Mermaid: $file"

    # Create temporary output file
    local temp_output="/tmp/mermaid_check_$$.svg"

    # Try to render to SVG (validates syntax)
    if mmdc -i "$file" -o "$temp_output" > /dev/null 2>&1; then
        success "  ✓ Valid syntax"
        rm -f "$temp_output"
        return 0
    else
        error "  ✗ Syntax error in $file"
        mmdc -i "$file" -o "$temp_output" 2>&1 || true
        rm -f "$temp_output"
        return 1
    fi
}

# Main execution
main() {
    local diagram_dir="${1:-docs/diagrams}"
    local exit_code=0
    local plantuml_available=false
    local mermaid_available=false

    # Validate diagram directory exists
    if [ ! -d "$diagram_dir" ]; then
        error "Diagram directory not found: $diagram_dir"
        exit 1
    fi

    info "Checking diagram validation tools..."

    # Check tool availability
    if check_plantuml; then
        plantuml_available=true
        success "PlantUML available: $PLANTUML_CMD"
    fi

    if check_mermaid; then
        mermaid_available=true
        success "Mermaid CLI available"
    fi

    if [ "$plantuml_available" = false ] && [ "$mermaid_available" = false ]; then
        error "No diagram validation tools available"
        exit 2
    fi

    echo ""
    info "Validating diagrams in: $diagram_dir"
    echo ""

    # Find and validate PlantUML files
    if [ "$plantuml_available" = true ]; then
        local puml_count=0
        while IFS= read -r -d '' file; do
            ((puml_count++))
            if ! validate_plantuml "$file"; then
                exit_code=1
            fi
            echo ""
        done < <(find "$diagram_dir" -name "*.puml" -print0 2>/dev/null)

        if [ $puml_count -eq 0 ]; then
            info "No PlantUML (.puml) files found"
        else
            info "Checked $puml_count PlantUML file(s)"
        fi
        echo ""
    fi

    # Find and validate Mermaid files
    if [ "$mermaid_available" = true ]; then
        local mmd_count=0
        while IFS= read -r -d '' file; do
            ((mmd_count++))
            if ! validate_mermaid "$file"; then
                exit_code=1
            fi
            echo ""
        done < <(find "$diagram_dir" -name "*.mmd" -print0 2>/dev/null)

        if [ $mmd_count -eq 0 ]; then
            info "No Mermaid (.mmd) files found"
        else
            info "Checked $mmd_count Mermaid file(s)"
        fi
        echo ""
    fi

    # Final result
    if [ $exit_code -eq 0 ]; then
        success "All diagram validations passed!"
        exit 0
    else
        error "Some diagram validations failed"
        exit 1
    fi
}

# Run main with all arguments
main "$@"
