#!/usr/bin/env bash
# WireTuner - Test Script
# This script ensures dependencies are installed and runs project tests

set -e  # Exit on error
set -u  # Exit on undefined variable

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

# Ensure dependencies are installed
echo "Checking dependencies..."
bash "$SCRIPT_DIR/install.sh" > /dev/null 2>&1

echo "Running tests..."

# Run Flutter tests
flutter test

exit $?
