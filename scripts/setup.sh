#!/bin/bash
# Butlery Development Environment Setup Script
# Usage: ./scripts/setup.sh

set -e

REQUIRED_FLUTTER="3.32.4"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "========================================"
echo "  Butlery Development Setup"
echo "========================================"
echo ""

cd "$PROJECT_DIR"

# Check Flutter installation
if ! command -v flutter &> /dev/null; then
    echo "ERROR: Flutter is not installed or not in PATH"
    echo "Install Flutter from: https://flutter.dev/docs/get-started/install"
    exit 1
fi

# Verify Flutter version
FLUTTER_VERSION=$(flutter --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
if [ "$FLUTTER_VERSION" != "$REQUIRED_FLUTTER" ]; then
    echo "WARNING: Flutter version mismatch"
    echo "  Expected: $REQUIRED_FLUTTER"
    echo "  Found:    $FLUTTER_VERSION"
    echo "  CI uses Flutter $REQUIRED_FLUTTER - consider switching versions"
    echo ""
else
    echo "Flutter version: $FLUTTER_VERSION"
fi

# Environment file setup
if [ ! -f .env.development ]; then
    if [ -f .env.example ]; then
        cp .env.example .env.development
        echo "Created .env.development from .env.example"
    else
        echo "WARNING: No .env.example found, skipping .env.development creation"
    fi
else
    echo ".env.development already exists"
fi

# Install Flutter dependencies
echo ""
echo "Installing dependencies..."
flutter pub get
echo "Dependencies installed"

# Install Lefthook for pre-commit hooks
echo ""
if command -v lefthook &> /dev/null; then
    echo "Installing pre-commit hooks..."
    lefthook install
    echo "Pre-commit hooks installed"
else
    echo "NOTE: Lefthook not found. Install it for pre-commit hooks:"
    echo "  npm install -g lefthook"
    echo "  Then run: lefthook install"
fi

# Run Flutter analyze to verify setup
echo ""
echo "Verifying setup with Flutter analyze..."
if flutter analyze --no-fatal-infos; then
    echo "Analysis passed"
else
    echo "WARNING: Some analysis issues found (non-fatal)"
fi

# Check for Firebase CLI (needed for integration tests)
echo ""
if command -v firebase &> /dev/null; then
    echo "Firebase CLI: $(firebase --version)"
else
    echo "NOTE: Firebase CLI not found. Install for integration tests:"
    echo "  npm install -g firebase-tools"
fi

echo ""
echo "========================================"
echo "  Setup Complete!"
echo "========================================"
echo ""
echo "Next steps:"
echo "  1. Run tests: flutter test"
echo "  2. Start emulator and run: flutter run"
echo "  3. For integration tests: firebase emulators:start"
echo ""
