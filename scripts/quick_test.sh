#!/bin/bash

# Quick E2E Test Runner for Development
# 
# Simplified script for rapid E2E test execution during development.
# Focuses on mock tests for speed and provides common development scenarios.
# 
# Usage:
#   ./scripts/quick_test.sh [flow_name]
#
# Examples:
#   ./scripts/quick_test.sh                    # Run all mock tests
#   ./scripts/quick_test.sh recipe_creation    # Run recipe creation mock test
#   ./scripts/quick_test.sh --help             # Show help

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

show_help() {
    cat << EOF
Quick E2E Test Runner for Development

Usage: $0 [flow_name]

Available flows:
  authentication        Basic auth flow (login, register)
  recipe_creation      Recipe creation workflow 
  shopping_sync        Shopping collaboration and sync
  social_collaboration Social features and friend requests
  all                  All flows (default)

Options:
  --help              Show this help

Examples:
  $0                           # Run all mock tests (fastest)
  $0 recipe_creation          # Test recipe creation only
  $0 shopping_sync            # Test shopping features only

This script runs MOCK tests only for speed during development.
For full integration testing, use: ./scripts/run_e2e_tests.sh

EOF
}

# Handle help
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_help
    exit 0
fi

# Determine flow to test
FLOW=${1:-all}

log "Quick E2E Test Runner Starting..."
log "Flow: $FLOW (Mock tier only)"

# Quick dependency check
if ! command -v flutter &> /dev/null; then
    error "Flutter not found. Please install Flutter and add to PATH."
    exit 1
fi

cd "$PROJECT_ROOT"

# Check for WSL and use appropriate flutter command
FLUTTER_CMD="flutter"
if [[ "$OSTYPE" == "linux-gnu"* ]] && grep -qi microsoft /proc/version; then
    FLUTTER_CMD="cmd.exe /c flutter"
    log "Detected WSL - using Windows Flutter"
fi

# Run quick tests based on flow
case $FLOW in
    "authentication")
        log "Running authentication mock test..."
        $FLUTTER_CMD test test/e2e/flows/authentication_flow_test.dart --name="Mock Environment"
        success "Authentication test completed"
        ;;
    "recipe_creation")
        log "Running recipe creation mock test..."
        $FLUTTER_CMD test test/e2e/flows/recipe_creation_flow_test.dart --name="Mock Environment"
        success "Recipe creation test completed"
        ;;
    "shopping_sync")
        log "Running shopping sync mock test..."
        $FLUTTER_CMD test test/e2e/flows/shopping_sync_flow_test.dart --name="Mock Environment"
        success "Shopping sync test completed"
        ;;
    "social_collaboration")
        log "Running social collaboration mock test..."
        $FLUTTER_CMD test test/e2e/flows/social_collaboration_flow_test.dart --name="Mock Environment"
        success "Social collaboration test completed"
        ;;
    "all")
        log "Running all mock tests sequentially..."
        
        flows=("authentication" "recipe_creation" "shopping_sync" "social_collaboration")
        failed_flows=()
        
        for flow in "${flows[@]}"; do
            log "Testing $flow..."
            
            if $FLUTTER_CMD test "test/e2e/flows/${flow}_flow_test.dart" --name="Mock Environment" --quiet; then
                success "$flow - PASSED"
            else
                error "$flow - FAILED"
                failed_flows+=("$flow")
            fi
        done
        
        echo ""
        if [ ${#failed_flows[@]} -eq 0 ]; then
            success "All quick tests PASSED! 🎉"
            log "Total flows tested: ${#flows[@]}"
        else
            error "Some tests FAILED:"
            for failed in "${failed_flows[@]}"; do
                echo "  - $failed"
            done
            log "Passed: $((${#flows[@]} - ${#failed_flows[@]}))"
            log "Failed: ${#failed_flows[@]}"
            exit 1
        fi
        ;;
    *)
        error "Unknown flow: $FLOW"
        echo ""
        warning "Available flows: authentication, recipe_creation, shopping_sync, social_collaboration, all"
        exit 1
        ;;
esac

echo ""
log "Quick test completed!"
warning "Note: This ran MOCK tests only. For full testing run: ./scripts/run_e2e_tests.sh"