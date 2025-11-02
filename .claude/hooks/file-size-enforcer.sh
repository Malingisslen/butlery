#!/bin/bash
# File Size Enforcer Hook - Warn when files exceed 500 lines without facade pattern
# Hook Type: PostToolUse (Edit, Write)
# Purpose: Enforce 500-line guideline OR facade pattern usage

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
MAX_LINES=500
TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
FILE_PATH="${CLAUDE_TOOL_ARG_file_path:-}"

# Only run for Edit and Write tools
if [ "$TOOL_NAME" != "Edit" ] && [ "$TOOL_NAME" != "Write" ]; then
  exit 0
fi

# Skip if no file path
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Skip non-Dart files
if [[ ! "$FILE_PATH" =~ \.dart$ ]]; then
  exit 0
fi

# Skip test files (they can be longer)
if [[ "$FILE_PATH" =~ test/ ]] || [[ "$FILE_PATH" =~ _test\.dart$ ]]; then
  exit 0
fi

# Skip generated files
if [[ "$FILE_PATH" =~ \.g\.dart$ ]] || [[ "$FILE_PATH" =~ \.freezed\.dart$ ]]; then
  exit 0
fi

# Check if file exists
if [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# Count lines
line_count=$(wc -l < "$FILE_PATH" | tr -d ' ')

# If under limit, all good
if [ "$line_count" -le "$MAX_LINES" ]; then
  exit 0
fi

# File exceeds limit - check for facade pattern indicators
has_facade_pattern=0

# Check for module extraction comments
if grep -q "Module:" "$FILE_PATH" || grep -q "Facade for" "$FILE_PATH"; then
  has_facade_pattern=1
fi

# Check for clear separation via class comments
module_count=$(grep -c "^/// Module:" "$FILE_PATH" || echo "0")
if [ "$module_count" -ge 3 ]; then
  has_facade_pattern=1
fi

# Check for extracted module imports (pattern: importing from same directory with _module suffix)
if grep -qE "import '.*_module\.dart';" "$FILE_PATH" || \
   grep -qE "import '.*_manager\.dart';" "$FILE_PATH" || \
   grep -qE "import '.*_operations\.dart';" "$FILE_PATH"; then
  has_facade_pattern=1
fi

# Output based on pattern detection
filename=$(basename "$FILE_PATH")
relative_path="${FILE_PATH#*/lib/}"

if [ "$has_facade_pattern" -eq 1 ]; then
  echo -e "${BLUE}ℹ File Size: $filename ($line_count lines)${NC}"
  echo -e "${GREEN}✓ Uses facade pattern - acceptable for >500 lines${NC}"
  echo ""
  echo "Detected modular design with extracted components."
  echo "This follows the Butlery pattern of well-architected facades."
else
  echo -e "${YELLOW}⚠ WARNING: File Size Violation${NC}"
  echo -e "${YELLOW}File: $relative_path${NC}"
  echo -e "${YELLOW}Lines: $line_count (exceeds $MAX_LINES line limit)${NC}"
  echo ""
  echo "Recommendations:"
  echo "  1. Extract modules using facade pattern (preferred)"
  echo "     Example: recipe_form_viewmodel.dart with 6 extracted managers"
  echo "  2. Split into focused single-responsibility files"
  echo "  3. Move complex logic to separate service/repository files"
  echo ""
  echo "Acceptable patterns for >500 lines:"
  echo "  • Facade with extracted modules (imports from *_module.dart, *_manager.dart)"
  echo "  • Clear module comments (/// Module: ...)"
  echo "  • Extracted operations pattern (unified services use this)"
  echo ""
  echo "See: .claude/skills/butlery-architecture for patterns"
fi

# Non-blocking (exit 0 to allow the operation)
exit 0
