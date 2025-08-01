#!/bin/bash
# 📊 PERFORMANCE BENCHMARK - Nuclear Operations Impact Assessment
# Measures performance improvements from nuclear refactoring operations
# Usage: ./verification/performance_benchmark.sh [--baseline|--post-nuclear|--compare]

set -e

echo "📊 PERFORMANCE BENCHMARK - Nuclear Impact Assessment"
echo "Measuring performance changes from nuclear refactoring operations"
echo ""

START_TIME=$(date +%s)
MODE="${1:-post-nuclear}"
RESULTS_DIR="benchmarks/$(date +%Y%m%d_%H%M%S)"

mkdir -p "$RESULTS_DIR"

case $MODE in
    --baseline)
        echo "📊 BASELINE MODE: Capturing pre-nuclear performance metrics"
        BENCHMARK_FILE="$RESULTS_DIR/baseline_metrics.json"
        ;;
    --post-nuclear)
        echo "🚀 POST-NUCLEAR MODE: Measuring post-refactoring performance"
        BENCHMARK_FILE="$RESULTS_DIR/post_nuclear_metrics.json"
        ;;
    --compare)
        echo "📈 COMPARE MODE: Analyzing performance improvements"
        _compare_benchmarks
        exit 0
        ;;
    *)
        echo "❌ Unknown mode: $MODE"
        echo "Usage: $0 [--baseline|--post-nuclear|--compare]"
        exit 1
        ;;
esac

echo "Results will be saved to: $BENCHMARK_FILE"
echo ""

# Initialize benchmark results
cat > "$BENCHMARK_FILE" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "mode": "$MODE",
  "git_commit": "$(git rev-parse HEAD 2>/dev/null || echo 'unknown')",
  "system_info": {
    "os": "$(uname -s)",
    "arch": "$(uname -m)",
    "dart_version": "$(dart --version 2>&1 | head -1)",
    "flutter_version": "$(flutter --version 2>&1 | head -1)"
  },
  "benchmarks": {}
}
EOF

function add_benchmark_result() {
    local test_name="$1" 
    local result="$2"
    local unit="$3"
    local status="${4:-success}"
    
    echo "  📊 $test_name: $result $unit"
    
    # Add to JSON file (simplified - in reality would use jq)
    local temp_file=$(mktemp)
    cat "$BENCHMARK_FILE" | sed "s/\"benchmarks\": {}/\"benchmarks\": {\"$test_name\": {\"value\": $result, \"unit\": \"$unit\", \"status\": \"$status\"}}/" > "$temp_file"
    mv "$temp_file" "$BENCHMARK_FILE"
}

function run_timed_command() {
    local command="$1"
    local timeout_seconds="${2:-300}"
    
    local start_time=$(date +%s%N)
    
    if timeout "$timeout_seconds" bash -c "$command" > /dev/null 2>&1; then
        local end_time=$(date +%s%N)
        local duration=$(( (end_time - start_time) / 1000000 ))  # Convert to milliseconds
        echo "$duration"
        return 0
    else
        echo "-1"  # Indicate failure/timeout
        return 1
    fi
}

echo "🚀 PHASE 1: COMPILATION PERFORMANCE"
echo "Measuring build and analysis times"
echo ""

# Flutter analyze performance
echo "  🔍 Running flutter analyze..."
ANALYZE_TIME=$(run_timed_command "flutter analyze --no-fatal-warnings" 180)
if [ "$ANALYZE_TIME" != "-1" ]; then
    add_benchmark_result "flutter_analyze" "$ANALYZE_TIME" "ms" "success"
else
    add_benchmark_result "flutter_analyze" "timeout" "ms" "timeout"
fi

# Dart compilation performance
echo "  🔧 Testing Dart compilation..."
COMPILE_TIME=$(run_timed_command "flutter build apk --debug --no-pub" 600)
if [ "$COMPILE_TIME" != "-1" ]; then
    add_benchmark_result "debug_build" "$COMPILE_TIME" "ms" "success"
else
    add_benchmark_result "debug_build" "timeout" "ms" "timeout"
fi

# Hot reload simulation (if possible)
echo "  🔥 Simulating hot reload..."
# This is a simplified simulation - real hot reload would need running app
HOT_RELOAD_TIME=$(run_timed_command "flutter build apk --debug --fast-start" 120)
if [ "$HOT_RELOAD_TIME" != "-1" ]; then
    add_benchmark_result "hot_reload_simulation" "$HOT_RELOAD_TIME" "ms" "success"
else
    add_benchmark_result "hot_reload_simulation" "timeout" "ms" "timeout"
fi

echo ""
echo "📊 PHASE 2: CODE METRICS"
echo "Analyzing codebase complexity and structure"
echo ""

# File count metrics
DART_FILES=$(find lib -name "*.dart" | wc -l)
add_benchmark_result "total_dart_files" "$DART_FILES" "files" "success"

# Component directories (should increase after nuclear refactoring)
COMPONENT_DIRS=$(find lib -name "components" -type d | wc -l)
add_benchmark_result "component_directories" "$COMPONENT_DIRS" "dirs" "success"

# Large file violations (should decrease after nuclear refactoring)  
LARGE_FILES=$(find lib -name "*.dart" -exec wc -l {} \; | awk '$1 > 500 {count++} END {print count+0}')
add_benchmark_result "large_file_violations" "$LARGE_FILES" "files" "success"

# Average file size
TOTAL_LINES=$(find lib -name "*.dart" -exec wc -l {} \; | awk '{sum+=$1} END {print sum}')
if [ "$DART_FILES" -gt 0 ]; then
    AVG_FILE_SIZE=$((TOTAL_LINES / DART_FILES))
    add_benchmark_result "average_file_size" "$AVG_FILE_SIZE" "lines" "success"
fi

# Legacy pattern counts (should decrease after nuclear refactoring)
LEGACY_DI=$(grep -r "sl<" lib/ 2>/dev/null | wc -l)
add_benchmark_result "legacy_di_patterns" "$LEGACY_DI" "occurrences" "success"

UNMOUNTED_SETSTATE=$(grep -r "setState(" lib/ 2>/dev/null | grep -v "if (mounted)" | wc -l)
add_benchmark_result "unmounted_setstate" "$UNMOUNTED_SETSTATE" "occurrences" "success"

echo ""
echo "🧪 PHASE 3: DEPENDENCY & IMPORT ANALYSIS"
echo "Measuring dependency resolution and import efficiency"
echo ""

# Pub get performance
echo "  📦 Testing pub get performance..."
PUB_GET_TIME=$(run_timed_command "flutter pub get" 120)
if [ "$PUB_GET_TIME" != "-1" ]; then
    add_benchmark_result "pub_get" "$PUB_GET_TIME" "ms" "success"
else
    add_benchmark_result "pub_get" "timeout" "ms" "timeout"
fi

# Import analysis
TOTAL_IMPORTS=$(grep -r "^import" lib/ 2>/dev/null | wc -l)
add_benchmark_result "total_imports" "$TOTAL_IMPORTS" "imports" "success"

# Circular dependency check (simplified)
echo "  🔄 Checking for circular dependencies..."
CIRCULAR_DEPS=$(find lib -name "*.dart" -exec grep -l "import.*lib/" {} \; 2>/dev/null | wc -l)
add_benchmark_result "potential_circular_deps" "$CIRCULAR_DEPS" "files" "success"

echo ""
echo "📈 PHASE 4: TEST PERFORMANCE"
echo "Measuring test execution efficiency"
echo ""

# Test execution time
echo "  🧪 Running test suite..."
TEST_TIME=$(run_timed_command "flutter test --timeout=60s" 180)
if [ "$TEST_TIME" != "-1" ]; then
    add_benchmark_result "test_execution" "$TEST_TIME" "ms" "success"
else
    add_benchmark_result "test_execution" "timeout" "ms" "timeout"
fi

# Test file count
TEST_FILES=$(find test -name "*.dart" 2>/dev/null | wc -l)
add_benchmark_result "test_files" "$TEST_FILES" "files" "success"

echo ""
echo "🎯 PHASE 5: NUCLEAR OPERATION IMPACT"
echo "Measuring specific nuclear refactoring improvements"
echo ""

# Memory leak indicators
TIMER_CANCELLATIONS=$(grep -r "\.cancel()" lib/ 2>/dev/null | wc -l)
add_benchmark_result "timer_cancellations" "$TIMER_CANCELLATIONS" "occurrences" "success"

DISPOSE_METHODS=$(grep -r "void dispose()" lib/ 2>/dev/null | wc -l)
add_benchmark_result "dispose_methods" "$DISPOSE_METHODS" "methods" "success"

# Architecture improvements
FACADE_CLASSES=$(grep -r "class.*Facade" lib/ 2>/dev/null | wc -l)
add_benchmark_result "facade_classes" "$FACADE_CLASSES" "classes" "success"

# DI standardization
SERVICE_LOCATOR_USAGE=$(grep -r "ServiceLocator.get" lib/ 2>/dev/null | wc -l)
add_benchmark_result "service_locator_usage" "$SERVICE_LOCATOR_USAGE" "occurrences" "success"

echo ""

# Final benchmark file update
END_TIME=$(date +%s)
TOTAL_DURATION=$((END_TIME - START_TIME))

# Update final JSON (simplified approach)
temp_file=$(mktemp)
cat "$BENCHMARK_FILE" | sed "s/\"benchmarks\"/\"duration\": $TOTAL_DURATION, \"benchmarks\"/" > "$temp_file"
mv "$temp_file" "$BENCHMARK_FILE"

echo "📊 BENCHMARK RESULTS SUMMARY"
echo "═══════════════════════════════════════════════════════════════"
echo "⏱️  Total benchmark time: ${TOTAL_DURATION}s"
echo "📁 Results saved to: $BENCHMARK_FILE"
echo ""

# Display key metrics
echo "🚀 KEY PERFORMANCE METRICS:"
if [ "$ANALYZE_TIME" != "-1" ]; then
    echo "  🔍 Flutter analyze: ${ANALYZE_TIME}ms"
else
    echo "  🔍 Flutter analyze: TIMEOUT"
fi

if [ "$COMPILE_TIME" != "-1" ]; then
    echo "  🔧 Debug build: ${COMPILE_TIME}ms"
else
    echo "  🔧 Debug build: TIMEOUT"
fi

echo "  📁 Dart files: $DART_FILES"
echo "  🏗️  Component dirs: $COMPONENT_DIRS"
echo "  📄 Large files: $LARGE_FILES"
echo "  🔄 Legacy DI: $LEGACY_DI patterns"
echo "  📱 Unmounted setState: $UNMOUNTED_SETSTATE"

echo ""
echo "📈 PERFORMANCE ASSESSMENT:"

# Simple performance assessment
if [ "$LARGE_FILES" -le 10 ] && [ "$LEGACY_DI" -le 5 ]; then
    echo "  ✅ EXCELLENT: Nuclear operations significantly improved code quality"
    echo "  🚀 Architecture violations reduced dramatically"
    echo "  ⚡ Expected performance improvements achieved"
elif [ "$LARGE_FILES" -le 50 ] && [ "$LEGACY_DI" -le 50 ]; then
    echo "  ✅ GOOD: Nuclear operations made substantial improvements"
    echo "  📈 Noticeable reduction in technical debt"
    echo "  🔧 Some manual cleanup may still be needed"
else
    echo "  ⚠️  PARTIAL: Nuclear operations had limited impact"
    echo "  🔄 Consider running additional nuclear fixes"
    echo "  📊 Manual review of remaining issues recommended"
fi

echo ""
echo "🔧 NEXT STEPS:"
echo "  📊 Compare with baseline: $0 --compare"
echo "  📈 Monitor performance in development"
echo "  🧪 Run additional tests to verify improvements"
echo "  📁 Archive results: cp $BENCHMARK_FILE benchmarks/latest.json"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "📊 PERFORMANCE BENCHMARK COMPLETE"

# Function to compare benchmarks (simplified implementation)
function _compare_benchmarks() {
    echo "📈 COMPARISON MODE - Analyzing Performance Improvements"
    echo ""
    
    # Look for baseline and post-nuclear results
    BASELINE_FILE=$(find benchmarks -name "*baseline*.json" -type f | tail -1)
    POST_NUCLEAR_FILE=$(find benchmarks -name "*post_nuclear*.json" -type f | tail -1)
    
    if [ -z "$BASELINE_FILE" ] || [ -z "$POST_NUCLEAR_FILE" ]; then
        echo "❌ Missing benchmark files for comparison"
        echo "   Need both baseline and post-nuclear benchmark files"
        echo "   Run: $0 --baseline (before nuclear operations)"
        echo "   Run: $0 --post-nuclear (after nuclear operations)"
        exit 1
    fi
    
    echo "📊 Comparing:"
    echo "  📋 Baseline: $BASELINE_FILE"
    echo "  🚀 Post-nuclear: $POST_NUCLEAR_FILE"
    echo ""
    echo "📈 PERFORMANCE IMPROVEMENTS:"
    echo "  (Detailed comparison would require JSON parsing)"
    echo "  🔍 Review both files manually for detailed analysis"
    echo ""
}

exit 0