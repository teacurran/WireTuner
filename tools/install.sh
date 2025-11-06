#!/usr/bin/env bash
# WireTuner - Dependency Installation Script
# This script ensures all dependencies are installed and up-to-date

set -e  # Exit on error
set -u  # Exit on undefined variable

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

echo "Installing Flutter dependencies..."

# Check if Flutter is available
if ! command -v flutter &> /dev/null; then
    echo "Error: Flutter is not installed or not in PATH"
    exit 1
fi

# Check Flutter version
FLUTTER_VERSION=$(flutter --version | head -n 1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
echo "Found Flutter version: $FLUTTER_VERSION"

# Install/update dependencies
flutter pub get

# Check if pubspec.lock exists and dependencies are satisfied
if [ ! -f "pubspec.lock" ]; then
    echo "Error: pubspec.lock not found after running 'flutter pub get'"
    exit 1
fi

echo "Dependencies installed successfully!"
exit 0
