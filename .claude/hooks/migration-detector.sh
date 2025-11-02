#!/bin/bash
# Migration Detector Hook - Suggest infrastructure adoption opportunities
# Hook Type: PostToolUse (Edit, Write)
# Purpose: Detect manual patterns that could use Butlery infrastructure

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
FILE_PATH="${CLAUDE_TOOL_ARG_file_path:-}"

# Only run for Edit and Write tools on Dart files
if [ "$TOOL_NAME" != "Edit" ] && [ "$TOOL_NAME" != "Write" ]; then
  exit 0
fi

if [ -z "$FILE_PATH" ] || [[ ! "$FILE_PATH" =~ \.dart$ ]]; then
  exit 0
fi

if [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# Track detected opportunities
declare -a opportunities=()

# Check for manual error handling (try-catch without ErrorHandlingMixin)
try_catch_count=$(grep -c "try {" "$FILE_PATH" || echo "0")
has_error_mixin=$(grep -c "ErrorHandlingMixin\|executeServiceOperation\|safeOperation" "$FILE_PATH" || echo "0")

if [ "$try_catch_count" -gt 0 ] && [ "$has_error_mixin" -eq 0 ]; then
  # Check if it's a service file
  if [[ "$FILE_PATH" =~ service.*\.dart$ ]]; then
    opportunities+=("error_handling")
  fi
fi

# Check for manual Firestore parsing (map access without SerializationUtils)
manual_parsing=$(grep -cE "data\['[^']+'\]|doc\.data\(\)" "$FILE_PATH" || echo "0")
has_serialization=$(grep -c "SerializationUtils\|safeString\|safeInt" "$FILE_PATH" || echo "0")

if [ "$manual_parsing" -gt 3 ] && [ "$has_serialization" -eq 0 ]; then
  opportunities+=("serialization_utils")
fi

# Check for manual null coalescing (without extension methods)
null_coalescing=$(grep -cE " \?\? ''\| \?\? \[\]\| \?\? 0\| \?\? false" "$FILE_PATH" || echo "0")
has_extensions=$(grep -c "\.orEmpty\|\.orZero\|\.orFalse\|default_value_extensions" "$FILE_PATH" || echo "0")

if [ "$null_coalescing" -gt 5 ] && [ "$has_extensions" -eq 0 ]; then
  opportunities+=("default_value_extensions")
fi

# Check for service not extending BaseService
if [[ "$FILE_PATH" =~ service.*\.dart$ ]] && [[ ! "$FILE_PATH" =~ _test\.dart$ ]]; then
  extends_base=$(grep -c "extends BaseService" "$FILE_PATH" || echo "0")
  is_change_notifier=$(grep -c "extends ChangeNotifier" "$FILE_PATH" || echo "0")

  if [ "$extends_base" -eq 0 ] && [ "$is_change_notifier" -eq 0 ]; then
    # Check if it's an instance-based service (has constructor DI)
    has_constructor=$(grep -cE "^  [A-Z][a-zA-Z]+\({" "$FILE_PATH" || echo "0")
    if [ "$has_constructor" -gt 0 ]; then
      opportunities+=("base_service")
    fi
  fi
fi

# Check for repository not extending BaseFirebaseRepository
if [[ "$FILE_PATH" =~ repository.*\.dart$ ]] && [[ ! "$FILE_PATH" =~ _test\.dart$ ]]; then
  extends_base_repo=$(grep -c "extends BaseFirebaseRepository" "$FILE_PATH" || echo "0")
  if [ "$extends_base_repo" -eq 0 ]; then
    # Check if it's a Firebase repository
    has_firestore=$(grep -c "FirebaseFirestore\|Firestore" "$FILE_PATH" || echo "0")
    if [ "$has_firestore" -gt 0 ]; then
      opportunities+=("base_firebase_repository")
    fi
  fi
fi

# Check for ViewModel not using AsyncOperationMixin
if [[ "$FILE_PATH" =~ viewmodel.*\.dart$ ]] && [[ ! "$FILE_PATH" =~ _test\.dart$ ]]; then
  has_async_mixin=$(grep -c "AsyncOperationMixin\|executeAsync" "$FILE_PATH" || echo "0")
  has_manual_loading=$(grep -c "_isLoading\|_loading\|setLoading" "$FILE_PATH" || echo "0")

  if [ "$has_async_mixin" -eq 0 ] && [ "$has_manual_loading" -gt 0 ]; then
    opportunities+=("async_operation_mixin")
  fi
fi

# Output migration opportunities
if [ ${#opportunities[@]} -gt 0 ]; then
  filename=$(basename "$FILE_PATH")
  echo -e "${CYAN}💡 Migration Opportunities Detected: $filename${NC}"
  echo ""

  for opportunity in "${opportunities[@]}"; do
    case "$opportunity" in
      error_handling)
        echo -e "${YELLOW}⚠ Manual Error Handling${NC}"
        echo "  Found $try_catch_count try-catch blocks"
        echo "  Consider: Extend BaseService for automatic error handling"
        echo "  Benefit: Consistent error handling, retry logic, logging"
        echo ""
        ;;

      serialization_utils)
        echo -e "${YELLOW}⚠ Manual Firestore Parsing${NC}"
        echo "  Found $manual_parsing manual data access patterns"
        echo "  Consider: Use SerializationUtils for safe parsing"
        echo "  Benefit: Null safety, type conversion, 400-800 lines saved"
        echo "  Example: SerializationUtils.safeString(data, 'field')"
        echo ""
        ;;

      default_value_extensions)
        echo -e "${YELLOW}⚠ Manual Null Coalescing${NC}"
        echo "  Found $null_coalescing null coalescing operations"
        echo "  Consider: Use default value extensions"
        echo "  Benefit: Cleaner syntax, consistency"
        echo "  Example: value.orEmpty() instead of value ?? ''"
        echo ""
        ;;

      base_service)
        echo -e "${YELLOW}⚠ Service Not Using BaseService${NC}"
        echo "  Consider: Extend BaseService"
        echo "  Benefit: Error handling, caching, lifecycle hooks, batch ops"
        echo "  Example: class MyService extends BaseService { ... }"
        echo ""
        ;;

      base_firebase_repository)
        echo -e "${YELLOW}⚠ Repository Not Using BaseFirebaseRepository${NC}"
        echo "  Consider: Extend BaseFirebaseRepository<T>"
        echo "  Benefit: CRUD operations, permissions, audit logging, streaming"
        echo "  Saves: 400 lines per repository"
        echo ""
        ;;

      async_operation_mixin)
        echo -e "${YELLOW}⚠ Manual Loading State Management${NC}"
        echo "  Found manual loading state implementation"
        echo "  Consider: Use AsyncOperationMixin (if simple state pattern)"
        echo "  Benefit: Automatic loading/error states, debouncing, caching"
        echo "  Note: Only for ViewModels with simple loading patterns"
        echo ""
        ;;
    esac
  done

  echo -e "${BLUE}📚 Resources:${NC}"
  echo "  • .claude/skills/butlery-architecture/ - Architecture patterns"
  echo "  • docs/architecture/DEDUPLICATION_PATTERNS.md - Full guide"
  echo ""

  echo -e "${GREEN}Note: These are suggestions, not requirements.${NC}"
  echo "Well-architected custom implementations are acceptable."
  echo ""
fi

# Non-blocking
exit 0
