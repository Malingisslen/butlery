#!/bin/bash

# Simplified E2E Test Execution Script for Butlery Flutter Application
# 
# Focused script for running the comprehensive E2E test suite with essential options.
# Supports Mock, Emulator, and Staging tiers with basic emulator automation.

set -e  # Exit on any error

# ======================
# Configuration
# ======================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
TIER="mock"
CLEAN=false
VERBOSE=false

# ======================
# Utility Functions
# ======================

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[VERBOSE] $1${NC}"
    fi
}

# ======================
# Help Function
# ======================

show_help() {
    cat << EOF
Butlery E2E Test Execution Script

Usage: $0 [options]

Options:
    --tier <tier>         Run specific test tier:
                         - mock (fast isolated testing)
                         - emulator (Firebase emulator integration)  
                         - staging (production-like validation)
                         - all (run all tiers)

    --clean              Clean setup: restart emulators, clear cache
    --verbose            Enable verbose logging output
    --help               Show this help message

Examples:
    $0 --tier mock
    $0 --tier emulator --clean
    $0 --tier all --verbose
EOF
}

# ======================
# Argument Parsing
# ======================

while [[ $# -gt 0 ]]; do
    case $1 in
        --tier)
            TIER="$2"
            shift 2
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# ======================
# Main Execution
# ======================

log "Starting Butlery E2E Test Execution..."
log "Configuration: Tier=$TIER, Clean=$CLEAN, Verbose=$VERBOSE"

# Setup test directories
log "Setting up test directories..."
mkdir -p "$PROJECT_ROOT/test/e2e/results"

# Check dependencies
log "Checking dependencies..."
if command -v cmd.exe >/dev/null 2>&1; then
    log "Detected WSL environment - using Windows Flutter commands"
    FLUTTER_CMD="cmd.exe /c flutter"
else
    FLUTTER_CMD="flutter"
fi

# Clean setup if requested
if [ "$CLEAN" = true ]; then
    log "Cleaning previous results..."
    rm -rf "$PROJECT_ROOT/test/e2e/results"/*
    verbose "Cleaned test results directory"
fi

# ======================
# Test Execution Functions
# ======================

run_comprehensive_test() {
    local tier=$1
    log "Running comprehensive E2E test - $tier tier..."
    
    cd "$PROJECT_ROOT"
    
    if [ "$VERBOSE" = true ]; then
        $FLUTTER_CMD test test/e2e/flows/comprehensive_e2e_test.dart
    else
        $FLUTTER_CMD test test/e2e/flows/comprehensive_e2e_test.dart --reporter compact
    fi
    
    if [ $? -eq 0 ]; then
        success "Comprehensive E2E test ($tier) - PASSED"
        return 0
    else
        error "Comprehensive E2E test ($tier) - FAILED"
        return 1
    fi
}

start_emulator() {
    if command -v firebase >/dev/null 2>&1; then
        log "Starting Firebase emulators..."
        firebase emulators:start --only firestore,auth,storage --detach >/dev/null 2>&1 || true
        sleep 3
        verbose "Firebase emulators started"
    else
        warning "Firebase CLI not found - emulator tests may fail"
    fi
}

stop_emulator() {
    if command -v firebase >/dev/null 2>&1; then
        firebase emulators:stop >/dev/null 2>&1 || true
        verbose "Firebase emulators stopped"
    fi
}

# ======================
# Execute Tests by Tier
# ======================

case $TIER in
    "mock")
        run_comprehensive_test "mock"
        ;;
    "emulator")
        start_emulator
        run_comprehensive_test "emulator"
        stop_emulator
        ;;
    "staging")
        log "Staging tests require proper staging Firebase project setup"
        run_comprehensive_test "staging"
        ;;
    "all")
        log "Running all test tiers..."
        
        # Run mock tests
        run_comprehensive_test "mock"
        mock_result=$?
        
        # Run emulator tests
        start_emulator
        run_comprehensive_test "emulator"
        emulator_result=$?
        stop_emulator
        
        # Run staging tests (may be skipped)
        run_comprehensive_test "staging"
        staging_result=$?
        
        # Summary
        if [ $mock_result -eq 0 ] && [ $emulator_result -eq 0 ] && [ $staging_result -eq 0 ]; then
            success "All E2E test tiers PASSED! 🎉"
        else
            error "Some E2E test tiers failed. Check logs for details."
            exit 1
        fi
        ;;
    *)
        error "Unknown tier: $TIER"
        show_help
        exit 1
        ;;
esac

success "All E2E tests completed successfully! 🎉"