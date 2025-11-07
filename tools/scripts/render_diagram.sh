#!/usr/bin/env bash
# render_diagram.sh - Renders PlantUML diagrams to PNG/SVG format
#
# Usage:
#   ./tools/scripts/render_diagram.sh <diagram.puml> [output_format]
#
# Arguments:
#   diagram.puml    - Path to the PlantUML file to render
#   output_format   - Optional: 'png' (default), 'svg', or 'txt'
#
# Examples:
#   ./tools/scripts/render_diagram.sh docs/diagrams/component_overview.puml
#   ./tools/scripts/render_diagram.sh docs/diagrams/component_overview.puml svg
#
# Requirements:
#   - plantuml (install via: brew install plantuml)
#   OR
#   - java and plantuml.jar (download from plantuml.com)
#
# Exit codes:
#   0 - Success
#   1 - Invalid arguments or missing file
#   2 - PlantUML not found
#   3 - Rendering failed

set -euo pipefail

# Color output helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

error() {
    echo -e "${RED}ERROR:${NC} $1" >&2
}

success() {
    echo -e "${GREEN}SUCCESS:${NC} $1"
}

info() {
    echo -e "${YELLOW}INFO:${NC} $1"
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
        return 2
    fi
}

# Validate arguments
if [ $# -lt 1 ]; then
    error "Missing required argument: diagram file"
    echo "Usage: $0 <diagram.puml> [output_format]"
    echo ""
    echo "Examples:"
    echo "  $0 docs/diagrams/component_overview.puml"
    echo "  $0 docs/diagrams/component_overview.puml svg"
    exit 1
fi

DIAGRAM_FILE="$1"
OUTPUT_FORMAT="${2:-png}"

# Validate diagram file exists
if [ ! -f "$DIAGRAM_FILE" ]; then
    error "Diagram file not found: $DIAGRAM_FILE"
    exit 1
fi

# Validate output format
case "$OUTPUT_FORMAT" in
    png|svg|txt)
        ;;
    *)
        error "Invalid output format: $OUTPUT_FORMAT"
        info "Valid formats: png, svg, txt"
        exit 1
        ;;
esac

# Check PlantUML availability
check_plantuml || exit $?

# Determine output directory (same as input file)
OUTPUT_DIR=$(dirname "$DIAGRAM_FILE")
DIAGRAM_NAME=$(basename "$DIAGRAM_FILE" .puml)

info "Rendering $DIAGRAM_FILE to $OUTPUT_FORMAT format..."

# Render the diagram
case "$OUTPUT_FORMAT" in
    png)
        $PLANTUML_CMD -tpng "$DIAGRAM_FILE"
        OUTPUT_FILE="$OUTPUT_DIR/$DIAGRAM_NAME.png"
        ;;
    svg)
        $PLANTUML_CMD -tsvg "$DIAGRAM_FILE"
        OUTPUT_FILE="$OUTPUT_DIR/$DIAGRAM_NAME.svg"
        ;;
    txt)
        $PLANTUML_CMD -ttxt "$DIAGRAM_FILE"
        OUTPUT_FILE="$OUTPUT_DIR/$DIAGRAM_NAME.txt"
        ;;
esac

# Check if rendering succeeded
if [ $? -eq 0 ] && [ -f "$OUTPUT_FILE" ]; then
    success "Diagram rendered successfully: $OUTPUT_FILE"
    exit 0
else
    error "Failed to render diagram"
    exit 3
fi
