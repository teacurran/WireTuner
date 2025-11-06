#!/usr/bin/env bash
# WireTuner - Lint Script
# This script ensures dependencies are installed and lints the codebase
# Output is exclusively in JSON format to stdout

set -e  # Exit on error
set -u  # Exit on undefined variable

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

# Ensure dependencies are installed (silently)
bash "$SCRIPT_DIR/install.sh" > /dev/null 2>&1

# Run Flutter analyze and capture output
ANALYZE_OUTPUT=$(flutter analyze 2>&1 || true)

# Parse the output and convert to JSON
# Initialize empty JSON array
echo "["

# Check if there are any issues
if echo "$ANALYZE_OUTPUT" | grep -q "No issues found!"; then
    # No issues - output empty array
    :
else
    # Parse issues and output as JSON
    FIRST_ENTRY=true

    # Parse analyze output line by line
    while IFS= read -r line; do
        # Match lines like: "  info • Description • path/to/file.dart:123:45 • rule_name"
        if echo "$line" | grep -qE '^\s+(error|warning|info)\s+•'; then
            # Extract components
            TYPE=$(echo "$line" | sed -E 's/^\s+(error|warning|info)\s+•.*/\1/')
            MESSAGE=$(echo "$line" | sed -E 's/^\s+(error|warning|info)\s+•\s+([^•]+)\s+•.*/\2/' | xargs)
            FILE_AND_LOCATION=$(echo "$line" | sed -E 's/.*•\s+([^•]+)\s+•\s+([a-z_]+)$/\1/')
            RULE=$(echo "$line" | sed -E 's/.*•\s+([a-z_]+)$/\1/')

            # Extract file path, line, and column
            FILE_PATH=$(echo "$FILE_AND_LOCATION" | sed -E 's/^([^:]+):.*/\1/')
            LINE_NUM=$(echo "$FILE_AND_LOCATION" | sed -E 's/^[^:]+:([0-9]+):.*/\1/')
            COLUMN_NUM=$(echo "$FILE_AND_LOCATION" | sed -E 's/^[^:]+:[0-9]+:([0-9]+).*/\1/')

            # Print comma before entry if not first
            if [ "$FIRST_ENTRY" = true ]; then
                FIRST_ENTRY=false
            else
                echo ","
            fi

            # Output JSON object
            echo -n "{\"type\":\"$TYPE\",\"path\":\"$FILE_PATH\",\"obj\":\"\",\"message\":\"$MESSAGE\",\"line\":\"$LINE_NUM\",\"column\":\"$COLUMN_NUM\"}"
        fi
    done <<< "$ANALYZE_OUTPUT"
fi

echo ""
echo "]"

# Exit with appropriate code
if echo "$ANALYZE_OUTPUT" | grep -q "No issues found!"; then
    exit 0
else
    # Count errors
    ERROR_COUNT=$(echo "$ANALYZE_OUTPUT" | grep -cE '^\s+error\s+•' || true)
    if [ "$ERROR_COUNT" -gt 0 ]; then
        exit 1
    fi
    exit 0
fi
