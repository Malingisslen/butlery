#!/bin/bash
# Dart Analyze Check Hook (Stop)
# Event: Stop (runs before returning control to user)
# Enforcement: suggest (shows errors/warnings but doesn't block)

# This hook runs flutter analyze to check for code quality issues
# Helps catch issues early without blocking development flow

set -e

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "\n${BLUE}📊 Running Flutter Analyze...${NC}\n"

# Run flutter analyze with timeout to prevent hanging
ANALYZE_OUTPUT=$(timeout 30s flutter analyze 2>&1 || echo "Analysis timed out after 30 seconds")

# Check if there are any issues
if echo "$ANALYZE_OUTPUT" | grep -q "No issues found"; then
    echo -e "${GREEN}✓ No analysis issues found!${NC}\n"
    exit 0
fi

# Parse and display analysis results
ERROR_COUNT=$(echo "$ANALYZE_OUTPUT" | grep -c "error •" || echo "0")
WARNING_COUNT=$(echo "$ANALYZE_OUTPUT" | grep -c "warning •" || echo "0")
INFO_COUNT=$(echo "$ANALYZE_OUTPUT" | grep -c "info •" || echo "0")

echo "================================"
echo "Flutter Analyze Summary"
echo "================================"

if [ "$ERROR_COUNT" -gt 0 ]; then
    echo -e "${RED}✗ Errors: $ERROR_COUNT${NC}"
fi

if [ "$WARNING_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}⚠ Warnings: $WARNING_COUNT${NC}"
fi

if [ "$INFO_COUNT" -gt 0 ]; then
    echo -e "${BLUE}ℹ Info: $INFO_COUNT${NC}"
fi

echo ""

# Show top issues (limit to 10 for readability)
echo "Top Issues:"
echo "$ANALYZE_OUTPUT" | grep "•" | head -n 10

if [ "$ERROR_COUNT" -gt 10 ] || [ "$WARNING_COUNT" -gt 10 ]; then
    echo ""
    echo "... and more (run 'flutter analyze' for full output)"
fi

echo ""
echo "💡 Tip: Run 'flutter analyze' to see full details"
echo "💡 Tip: Use 'dart fix --apply' to auto-fix some issues"
echo ""

# Return success (non-blocking)
exit 0
