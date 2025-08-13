#!/bin/bash

# Script to run tests locally with proper separation of unit and integration tests
# Usage: ./scripts/run_tests.sh [unit|integration|all]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to run unit tests
run_unit_tests() {
    print_info "Running unit tests (excluding integration tests)..."
    flutter test --exclude-tags=integration
}

# Function to run integration tests
run_integration_tests() {
    print_info "Running integration tests..."
    
    # Check if Firebase emulator is installed
    if ! command -v firebase &> /dev/null; then
        print_warning "Firebase CLI not found. Please install it with: npm install -g firebase-tools"
        exit 1
    fi
    
    # Start Firebase emulator
    print_info "Starting Firebase emulator..."
    
    # Create minimal firebase.json if it doesn't exist
    if [ ! -f firebase.json ]; then
        print_info "Creating minimal firebase.json..."
        cat > firebase.json << 'EOF'
{
  "emulators": {
    "auth": {
      "port": 9099
    },
    "firestore": {
      "port": 8080
    },
    "storage": {
      "port": 9199
    },
    "ui": {
      "enabled": true,
      "port": 4000
    }
  }
}
EOF
    fi
    
    # Start emulator in background
    firebase emulators:start --only auth,firestore,storage &
    EMULATOR_PID=$!
    
    # Wait for emulator to be ready
    print_info "Waiting for emulator to be ready..."
    sleep 10
    
    # Run integration tests
    flutter test --tags=integration
    TEST_EXIT_CODE=$?
    
    # Stop emulator
    print_info "Stopping Firebase emulator..."
    kill $EMULATOR_PID 2>/dev/null || true
    
    return $TEST_EXIT_CODE
}

# Function to run all tests
run_all_tests() {
    print_info "Running all tests..."
    
    # Run unit tests first
    print_info "=== UNIT TESTS ==="
    run_unit_tests
    UNIT_EXIT_CODE=$?
    
    if [ $UNIT_EXIT_CODE -ne 0 ]; then
        print_error "Unit tests failed!"
        return $UNIT_EXIT_CODE
    fi
    
    print_info "Unit tests passed!"
    
    # Then run integration tests
    print_info "=== INTEGRATION TESTS ==="
    run_integration_tests
    INTEGRATION_EXIT_CODE=$?
    
    if [ $INTEGRATION_EXIT_CODE -ne 0 ]; then
        print_error "Integration tests failed!"
        return $INTEGRATION_EXIT_CODE
    fi
    
    print_info "All tests passed!"
    return 0
}

# Main script logic
TEST_TYPE=${1:-all}

case $TEST_TYPE in
    unit)
        run_unit_tests
        ;;
    integration)
        run_integration_tests
        ;;
    all)
        run_all_tests
        ;;
    *)
        print_error "Invalid test type: $TEST_TYPE"
        echo "Usage: $0 [unit|integration|all]"
        exit 1
        ;;
esac

exit $?