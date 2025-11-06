#!/usr/bin/env bash
# WireTuner - Run Script
# This script ensures dependencies are installed and runs the application

set -e  # Exit on error
set -u  # Exit on undefined variable

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

# Ensure dependencies are installed
echo "Checking dependencies..."
bash "$SCRIPT_DIR/install.sh" > /dev/null 2>&1

# Detect platform and run
if [[ "$OSTYPE" == "darwin"* ]]; then
    PLATFORM="macos"
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    PLATFORM="windows"
else
    echo "Error: Unsupported platform: $OSTYPE"
    exit 1
fi

echo "Running WireTuner on $PLATFORM..."
flutter run -d "$PLATFORM"

exit $?
