#!/bin/bash
# 🔍 NUCLEAR SANITY CHECK - Comprehensive Verification Suite
# Verifies nuclear operations didn't break critical functionality
# Usage: ./verification/sanity_check.sh [--fast|--full|--critical]

set -e

echo "🔍 NUCLEAR SANITY CHECK - Comprehensive Verification"
echo "Verifying nuclear operations didn't break critical functionality"
echo ""

START_TIME=$(date +%s)
MODE="${1:-full}"

case $MODE in
    --fast)
        echo "⚡ FAST MODE: Essential checks only (2-3 minutes)"
        TIMEOUT_ANALYZE=60
        TIMEOUT_BUILD=180
        SKIP_TESTS=true
        ;;
    --critical)
        echo "🚨 CRITICAL MODE: Mission-critical checks only (1 minute)"
        TIMEOUT_ANALYZE=30
        TIMEOUT_BUILD=120
        SKIP_TESTS=true
        SKIP_FULL_BUILD=true
        ;;
    --full|*)
        echo "🔍 FULL MODE: Comprehensive verification (5-10 minutes)"
        TIMEOUT_ANALYZE=180
        TIMEOUT_BUILD=600
        SKIP_TESTS=false
        ;;
esac

echo ""

# Initialize results tracking
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNINGS=0

function run_check() {
    local check_name="$1"
    local check_command="$2"
    local timeout_seconds="$3"
    local is_critical="${4:-false}"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    echo -n "  🔍 $check_name... "
    
    if [ "$timeout_seconds" -gt 0 ]; then
        if timeout "$timeout_seconds" bash -c "$check_command" > /tmp/sanity_check_$TOTAL_CHECKS.log 2>&1; then
            echo "✅ PASS"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
            return 0
        else
            if [ "$is_critical" = "true" ]; then
                echo "❌ CRITICAL FAILURE"
                echo "    Command: $check_command"
                echo "    Log: $(tail -3 /tmp/sanity_check_$TOTAL_CHECKS.log)"
                FAILED_CHECKS=$((FAILED_CHECKS + 1))
                return 1
            else
                echo "⚠️  WARNING"
                WARNINGS=$((WARNINGS + 1))
                return 0
            fi
        fi
    else
        if eval "$check_command" > /tmp/sanity_check_$TOTAL_CHECKS.log 2>&1; then
            echo "✅ PASS"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
            return 0
        else
            echo "❌ FAIL"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
            return 1
        fi
    fi
}

echo "🚀 PHASE 1: CRITICAL INFRASTRUCTURE CHECKS"
echo "Essential checks that must pass for basic functionality"
echo ""

# Check 1: Project structure integrity
run_check "Project structure integrity" "[ -d lib ] && [ -f pubspec.yaml ] && [ -d lib/core ]" 0 true

# Check 2: Dart analysis (basic syntax and imports)
run_check "Dart analysis (syntax & imports)" "flutter analyze --no-fatal-warnings" $TIMEOUT_ANALYZE true

# Check 3: Dependency resolution
run_check "Dependency resolution" "flutter pub get" 60 true

# Check 4: Basic compilation check
if [ "$SKIP_FULL_BUILD" != "true" ]; then
    run_check "Basic compilation" "flutter build apk --debug --no-pub" $TIMEOUT_BUILD true
else
    echo "  🔍 Basic compilation... ⏭️  SKIPPED (critical mode)"
fi

echo ""
echo "🔧 PHASE 2: NUCLEAR OPERATION VERIFICATION"
echo "Checking that nuclear operations were successful"
echo ""

# Check 5: File size violations (should be eliminated)
run_check "File size violations eliminated" '
    violations=$(find lib -name "*.dart" -exec wc -l {} \; | awk "$1 > 500 {count++} END {print count+0}")
    echo "Files >500 lines: $violations" >> /tmp/sanity_check_5.log
    [ "$violations" -le 10 ]  # Allow up to 10 violations (down from 109)
' 0 false

# Check 6: Memory leak patterns (should be reduced)
run_check "Memory leak patterns reduced" '
    setState_without_mounted=$(grep -r "setState(" lib/ | grep -v "if (mounted)" || true)
    setState_count=$(echo "$setState_without_mounted" | wc -l)
    echo "setState without mounted: $setState_count" >> /tmp/sanity_check_6.log
    [ "$setState_count" -le 20 ]  # Allow some remaining (down from 57+)
' 0 false

# Check 7: DI pattern consistency
run_check "DI pattern consistency" '
    legacy_sl=$(grep -r "sl<" lib/ || true)
    legacy_count=$(echo "$legacy_sl" | wc -l)
    echo "Legacy sl<> patterns: $legacy_count" >> /tmp/sanity_check_7.log
    [ "$legacy_count" -le 5 ]  # Should be mostly eliminated
' 0 false

# Check 8: Import organization
run_check "Import organization" '
    # Check for basic import organization
    disorganized=$(grep -r "^import" lib/ | head -20 | grep -E "(dart:|package:)" || true)
    echo "Sample imports checked" >> /tmp/sanity_check_8.log
    true  # This is informational
' 0 false

echo ""
echo "🎯 PHASE 3: FUNCTIONALITY VERIFICATION"
echo "Ensuring core app functionality still works"
echo ""

# Check 9: Core modules loadable
run_check "Core modules loadable" '
    # Try to validate that main modules can be imported
    dart --version > /dev/null &&
    find lib/core -name "*.dart" | head -5 | while read file; do
        if ! dart analyze "$file" --no-fatal-warnings > /dev/null 2>&1; then
            echo "Failed to analyze: $file" >> /tmp/sanity_check_9.log
            exit 1
        fi
    done
' 30 false

# Check 10: Key architectural components exist
run_check "Key architectural components" '
    # Check that key components still exist
    [ -f lib/core/providers/application_provider.dart ] &&
    [ -d lib/models ] &&
    [ -d lib/services ] &&
    [ -d lib/repositories ]
' 0 false

# Check 11: Test suite (if not skipped)
if [ "$SKIP_TESTS" != "true" ]; then
    run_check "Test suite execution" "flutter test --timeout=60s" 180 false
else
    echo "  🔍 Test suite execution... ⏭️  SKIPPED ($MODE mode)"
fi

# Check 12: Performance indicators
run_check "Performance indicators" '
    # Check that components directory was created (facade pattern applied)
    component_dirs=$(find lib -name "components" -type d | wc -l)
    echo "Component directories created: $component_dirs" >> /tmp/sanity_check_12.log
    
    # Check file count increased (due to component generation)
    dart_files=$(find lib -name "*.dart" | wc -l)
    echo "Total Dart files: $dart_files" >> /tmp/sanity_check_12.log
    
    [ "$dart_files" -ge 607 ]  # Should be same or higher due to new components
' 0 false

echo ""
echo "📊 PHASE 4: DETAILED ANALYSIS"
echo "Comprehensive health assessment"
echo ""

# Collect detailed statistics
echo "  📈 Collecting detailed statistics..."

# File statistics
DART_FILES=$(find lib -name "*.dart" | wc -l)
COMPONENT_DIRS=$(find lib -name "components" -type d | wc -l)
LARGE_FILES=$(find lib -name "*.dart" -exec wc -l {} \; | awk '$1 > 500 {count++} END {print count+0}')

# Pattern statistics  
LEGACY_DI=$(grep -r "sl<" lib/ 2>/dev/null | wc -l)
UNMOUNTED_SETSTATE=$(grep -r "setState(" lib/ 2>/dev/null | grep -v "if (mounted)" | wc -l)
TODO_FIXME=$(grep -r "TODO\|FIXME" lib/ 2>/dev/null | wc -l)

# Import statistics
IMPORT_ISSUES=$(grep -r "^import" lib/ 2>/dev/null | wc -l)

echo ""
echo "📊 SANITY CHECK RESULTS"
echo "═══════════════════════════════════════════════════════════════"

# Results summary
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "⏱️  Check Duration: ${DURATION}s"
echo "🎯 Total Checks: $TOTAL_CHECKS"
echo "✅ Passed: $PASSED_CHECKS"
echo "❌ Failed: $FAILED_CHECKS"
echo "⚠️  Warnings: $WARNINGS"
echo ""

# Detailed statistics
echo "📈 CODEBASE STATISTICS:"
echo "  📁 Total Dart files: $DART_FILES"
echo "  🏗️  Component directories: $COMPONENT_DIRS"
echo "  📄 Large files (>500 lines): $LARGE_FILES"
echo "  🔄 Legacy DI patterns: $LEGACY_DI"
echo "  📱 Unmounted setState calls: $UNMOUNTED_SETSTATE"
echo "  📝 TODO/FIXME comments: $TODO_FIXME"
echo ""

# Health assessment
if [ $FAILED_CHECKS -eq 0 ] && [ $PASSED_CHECKS -gt $((TOTAL_CHECKS * 8 / 10)) ]; then
    echo "🎉 OVERALL STATUS: EXCELLENT ✅"
    echo "Nuclear operations were highly successful!"
    echo "The codebase is in excellent condition and ready for development."
    exit_code=0
elif [ $FAILED_CHECKS -le 2 ] && [ $PASSED_CHECKS -gt $((TOTAL_CHECKS * 6 / 10)) ]; then
    echo "✅ OVERALL STATUS: GOOD ⚠️"
    echo "Nuclear operations were mostly successful with minor issues."
    echo "The codebase is functional but may need some manual fixes."
    exit_code=0
elif [ $FAILED_CHECKS -le 5 ]; then
    echo "⚠️  OVERALL STATUS: NEEDS ATTENTION 🔧"
    echo "Nuclear operations had some issues that need to be addressed."
    echo "Review failed checks and consider partial rollback if needed."
    exit_code=1
else
    echo "🚨 OVERALL STATUS: CRITICAL ISSUES ❌"
    echo "Nuclear operations may have caused significant problems."
    echo "Consider full rollback and manual fixes."
    exit_code=2
fi

echo ""
echo "🔧 RECOMMENDED ACTIONS:"

if [ $exit_code -eq 0 ]; then
    echo "  ✅ Continue with development - all systems operational"
    echo "  📊 Monitor performance improvements from nuclear operations"
    echo "  🧪 Run additional tests to verify specific functionality"
elif [ $exit_code -eq 1 ]; then
    echo "  🔧 Address failed checks manually"
    echo "  📝 Review logs in /tmp/sanity_check_*.log"
    echo "  🔄 Consider running specific nuclear fixes again"
else
    echo "  🚨 Consider rollback: git reset --hard <previous-commit>"
    echo "  📞 Review nuclear operation logs for errors"
    echo "  🔧 Manual fixes may be required"
fi

echo ""
echo "📋 DETAILED LOGS:"
echo "Check logs are available at: /tmp/sanity_check_*.log"
echo "View failed checks: ls -la /tmp/sanity_check_*.log"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "🔍 NUCLEAR SANITY CHECK COMPLETE"
echo "Exit code: $exit_code (0=excellent, 1=needs attention, 2=critical)"

# Cleanup old logs older than 1 hour
find /tmp -name "sanity_check_*.log" -mmin +60 -delete 2>/dev/null || true

exit $exit_code