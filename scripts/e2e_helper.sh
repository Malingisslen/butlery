#!/bin/bash

# E2E Test Helper Script
# 
# Simple utilities for E2E test development and troubleshooting.
# Most functionality is now handled by the main run_e2e_tests.sh script.

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
    echo -e "${BLUE}[E2E Helper] $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

show_help() {
    cat << EOF
E2E Test Helper - Essential Utilities

Usage: $0 <command>

COMMANDS:
  clean                     Clean all test artifacts and results
  emulator-status          Check Firebase emulator status
  quick-test               Run comprehensive E2E test in mock mode
  validate                 Validate E2E test setup
  help                     Show this help message

EXAMPLES:
  $0 clean                 # Clean up test artifacts
  $0 quick-test           # Quick E2E test run
  $0 validate             # Check if E2E setup works

NOTE: For full E2E test execution, use ./scripts/run_e2e_tests.sh
EOF
}

clean_artifacts() {
    log "Cleaning E2E test artifacts..."
    
    # Clean test results
    if [ -d "$PROJECT_ROOT/test/e2e/results" ]; then
        rm -rf "$PROJECT_ROOT/test/e2e/results"/*
        log "Cleaned test results directory"
    fi
    
    # Clean Flutter test cache
    cd "$PROJECT_ROOT"
    if command -v cmd.exe >/dev/null 2>&1; then
        cmd.exe /c "flutter clean" >/dev/null 2>&1 || true
    else
        flutter clean >/dev/null 2>&1 || true
    fi
    
    success "All E2E test artifacts cleaned"
}

check_emulator_status() {
    log "Checking Firebase emulator status..."
    
    if command -v firebase >/dev/null 2>&1; then
        if curl -s http://localhost:4000 >/dev/null 2>&1; then
            success "Firebase emulators are running (UI available at http://localhost:4000)"
        else
            error "Firebase emulators are not running"
            echo "  Start with: firebase emulators:start --only firestore,auth,storage"
        fi
    else
        error "Firebase CLI not installed"
        echo "  Install with: npm install -g firebase-tools"
    fi
}

quick_test() {
    log "Running quick E2E test (mock mode)..."
    cd "$PROJECT_ROOT"
    
    if command -v cmd.exe >/dev/null 2>&1; then
        cmd.exe /c "flutter test test/e2e/flows/comprehensive_e2e_test.dart --reporter compact"
    else
        flutter test test/e2e/flows/comprehensive_e2e_test.dart --reporter compact
    fi
}

validate_setup() {
    log "Validating E2E test setup..."
    
    # Check test file exists
    if [ -f "$PROJECT_ROOT/test/e2e/flows/comprehensive_e2e_test.dart" ]; then
        success "E2E test file exists"
    else
        error "E2E test file missing"
    fi
    
    # Check Flutter installation
    if command -v cmd.exe >/dev/null 2>&1; then
        if cmd.exe /c "flutter --version" >/dev/null 2>&1; then
            success "Flutter is available (via Windows)"
        else
            error "Flutter not found"
        fi
    else
        if command -v flutter >/dev/null 2>&1; then
            success "Flutter is available"
        else
            error "Flutter not found"
        fi
    fi
    
    # Check Firebase CLI (optional)
    if command -v firebase >/dev/null 2>&1; then
        success "Firebase CLI available (for emulator tests)"
    else
        echo "  Firebase CLI not found (emulator tests will be skipped)"
    fi
    
    success "E2E test setup validation complete"
}

# Command handling
case "${1:-help}" in
    "clean")
        clean_artifacts
        ;;
    "emulator-status")
        check_emulator_status
        ;;
    "quick-test")
        quick_test
        ;;
    "validate")
        validate_setup
        ;;
    "help"|"--help"|"")
        show_help
        ;;
    *)
        error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac