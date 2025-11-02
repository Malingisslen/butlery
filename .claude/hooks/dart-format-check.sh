#!/bin/bash
# Dart Format Check Hook - Remind to format and analyze before committing
# Hook Type: Stop
# Purpose: Session cleanup checklist

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}📋 Session Checklist${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${YELLOW}Before committing, consider running:${NC}"
echo ""

echo -e "${GREEN}1. Format Code${NC}"
echo "   dart format ."
echo ""

echo -e "${GREEN}2. Run Analysis${NC}"
echo "   flutter analyze"
echo "   (or use existing hook output above)"
echo ""

echo -e "${GREEN}3. Run Tests${NC}"
echo "   ./run_tests_safely.sh"
echo "   or"
echo "   flutter test test/unit/your_test.dart"
echo ""

echo -e "${GREEN}4. Check Git Status${NC}"
echo "   git status"
echo "   Review modified files"
echo ""

echo -e "${BLUE}Optional Quality Checks:${NC}"
echo ""

echo -e "${CYAN}• Code Intelligence Analysis:${NC}"
echo "  dart tools/code_intelligence_platform.dart"
echo ""

echo -e "${CYAN}• Test Coverage:${NC}"
echo "  flutter test --coverage"
echo ""

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Thank you for following Butlery's development standards!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Non-blocking
exit 0
