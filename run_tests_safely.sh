#!/bin/bash

# Safe test runner to prevent VS Code and system crashes
# This script runs tests in small batches with memory management

echo "==================================="
echo "Safe Test Runner for Butlery"
echo "==================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track results
FAILED_TESTS=()
PASSED_COUNT=0
FAILED_COUNT=0
SKIPPED_COUNT=0

# Function to run a single test file
run_test_file() {
    local test_file=$1
    local test_name=$(basename "$test_file")
    
    echo -e "${YELLOW}Running: $test_name${NC}"
    
    # Convert absolute WSL path to relative path with forward slashes
    # This prevents the "Illegal character in path" error
    local relative_path=$(echo "$test_file" | sed 's|^.*/butlery/||')
    
    # Run test with limited concurrency and capture output
    # Use forward slashes to prevent path errors in Flutter
    cmd.exe /c "flutter test \"$relative_path\" --no-pub --concurrency=1" > /tmp/test_output.txt 2>&1
    EXIT_CODE=$?
    
    if [ $EXIT_CODE -eq 0 ]; then
        echo -e "${GREEN}✓ PASSED: $test_name${NC}"
        PASSED_COUNT=$((PASSED_COUNT + 1))
    else
        echo -e "${RED}✗ FAILED: $test_name${NC}"
        FAILED_TESTS+=("$test_file")
        FAILED_COUNT=$((FAILED_COUNT + 1))
        # Show first few lines of error output for debugging
        if [ -f /tmp/test_output.txt ]; then
            echo "  Error details:"
            tail -5 /tmp/test_output.txt | sed 's/^/    /'
        fi
    fi
    
    # Give system time to recover between tests
    sleep 1
    
    # Clear Dart/Flutter cache periodically (every 10 tests)
    if [ $((($PASSED_COUNT + $FAILED_COUNT) % 10)) -eq 0 ]; then
        echo "Clearing cache to free memory..."
        cmd.exe /c "flutter pub cache repair" > /dev/null 2>&1
        sleep 2
    fi
}

# Function to run tests in a directory
run_tests_in_dir() {
    local dir=$1
    local pattern=${2:-"*_test.dart"}
    
    echo ""
    echo "Testing directory: $dir"
    echo "================================"
    
    # Check if directory exists
    if [ ! -d "$dir" ]; then
        echo -e "${RED}Directory not found: $dir${NC}"
        return 1
    fi
    
    # Find all test files
    local test_files=($(find "$dir" -name "$pattern" -type f 2>/dev/null))
    
    if [ ${#test_files[@]} -eq 0 ]; then
        echo "No test files found in $dir"
        return 0
    fi
    
    echo "Found ${#test_files[@]} test files"
    echo ""
    
    # Run each test file
    for test_file in "${test_files[@]}"; do
        run_test_file "$test_file"
    done
}

# Main execution
echo "Starting safe test execution..."
echo "This will run tests one at a time to prevent crashes"
echo ""

# Parse command line arguments
if [ $# -eq 0 ]; then
    echo "Usage: ./run_tests_safely.sh [all|unit|integration|<directory>]"
    echo ""
    echo "Examples:"
    echo "  ./run_tests_safely.sh all                    # Run all tests"
    echo "  ./run_tests_safely.sh unit                   # Run unit tests"
    echo "  ./run_tests_safely.sh integration            # Run integration tests"
    echo "  ./run_tests_safely.sh test/unit/services     # Run specific directory"
    exit 1
fi

case $1 in
    all)
        echo "Running ALL tests (this will take a while)..."
        run_tests_in_dir "test/unit"
        run_tests_in_dir "test/integration"
        run_tests_in_dir "test/widget"
        ;;
    unit)
        echo "Running unit tests..."
        run_tests_in_dir "test/unit"
        ;;
    integration)
        echo "Running integration tests..."
        run_tests_in_dir "test/integration"
        ;;
    *)
        # Run specific directory
        run_tests_in_dir "$1"
        ;;
esac

# Summary
echo ""
echo "==================================="
echo "Test Run Summary"
echo "==================================="
echo -e "${GREEN}Passed: $PASSED_COUNT${NC}"
echo -e "${RED}Failed: $FAILED_COUNT${NC}"

if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
    echo ""
    echo "Failed tests:"
    for failed_test in "${FAILED_TESTS[@]}"; do
        echo "  - $(basename "$failed_test")"
    done
    exit 1
else
    echo ""
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi