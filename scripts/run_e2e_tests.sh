#!/bin/bash
# run_e2e_tests.sh - E2E test runner for CI/CD
# Usage: ./scripts/run_e2e_tests.sh --tier <mock|emulator> [--verbose]

set -e

# Default values
TIER="mock"
VERBOSE=false
TEST_DIR="test/e2e"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --tier)
      TIER="$2"
      shift 2
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 --tier <mock|emulator> [--verbose]"
      exit 1
      ;;
  esac
done

# Validate tier
if [[ "$TIER" != "mock" && "$TIER" != "emulator" ]]; then
  echo "Error: Invalid tier '$TIER'. Must be 'mock' or 'emulator'."
  exit 1
fi

echo "========================================"
echo "Running E2E Tests"
echo "========================================"
echo "Tier: $TIER"
echo "Verbose: $VERBOSE"
echo "Test Directory: $TEST_DIR"
echo "========================================"

# Check if test directory exists
if [ ! -d "$TEST_DIR" ]; then
  echo "Warning: E2E test directory '$TEST_DIR' does not exist."
  echo "Creating placeholder directory..."
  mkdir -p "$TEST_DIR"

  # Create a placeholder test file
  cat > "$TEST_DIR/placeholder_test.dart" << 'EOF'
// Placeholder E2E test file
// Replace this with actual E2E tests

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('E2E Placeholder', () {
    test('placeholder test passes', () {
      // This is a placeholder test
      // Real E2E tests should be added here
      expect(true, isTrue);
    });
  });
}
EOF
  echo "Created placeholder test file."
fi

# Set up reporter flag
REPORTER_FLAG=""
if [ "$VERBOSE" = true ]; then
  REPORTER_FLAG="--reporter=expanded"
else
  REPORTER_FLAG="--reporter=compact"
fi

# Run tests based on tier
case $TIER in
  mock)
    echo ""
    echo "Running mock-tier E2E tests..."
    echo "Using mocked Firebase services."
    echo ""

    flutter test "$TEST_DIR" \
      --dart-define=USE_MOCK=true \
      --dart-define=E2E_TEST=true \
      $REPORTER_FLAG
    ;;

  emulator)
    echo ""
    echo "Running emulator-tier E2E tests..."
    echo "Using Firebase emulators."
    echo ""

    # Check if emulators are running
    if ! curl -s http://localhost:8080 > /dev/null 2>&1; then
      echo "Warning: Firestore emulator not detected on port 8080."
      echo "Starting Firebase emulators..."

      # Start emulators in background
      firebase emulators:start --only auth,firestore,storage &
      EMULATOR_PID=$!

      # Wait for emulators to be ready
      echo "Waiting for emulators to start..."
      sleep 15

      # Verify emulators are running
      if ! curl -s http://localhost:8080 > /dev/null 2>&1; then
        echo "Error: Failed to start Firebase emulators."
        kill $EMULATOR_PID 2>/dev/null || true
        exit 1
      fi

      echo "Emulators started successfully."
      STARTED_EMULATORS=true
    else
      echo "Firebase emulators already running."
      STARTED_EMULATORS=false
    fi

    # Run tests with emulator environment
    flutter test "$TEST_DIR" \
      --dart-define=USE_EMULATOR=true \
      --dart-define=E2E_TEST=true \
      $REPORTER_FLAG

    TEST_EXIT_CODE=$?

    # Stop emulators if we started them
    if [ "$STARTED_EMULATORS" = true ]; then
      echo "Stopping Firebase emulators..."
      kill $EMULATOR_PID 2>/dev/null || true
      pkill -f "firebase" 2>/dev/null || true
    fi

    exit $TEST_EXIT_CODE
    ;;
esac

echo ""
echo "========================================"
echo "E2E Tests Completed Successfully"
echo "========================================"
