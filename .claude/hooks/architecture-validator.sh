#!/bin/bash
# Architecture Validator Hook (PostToolUse)
# Event: PostToolUse (runs after file changes)
# Enforcement: HYBRID - BLOCKS critical violations, WARNS on style issues

# This hook validates MVVM + Repository architecture compliance
# CRITICAL violations (BLOCK): Security and architecture integrity issues
# STYLE violations (WARN): Maintainability and consistency issues

set -e

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Counters
CRITICAL_COUNT=0
WARN_COUNT=0

# Output formatting
echo -e "\n${GREEN}🔍 Running Architecture Validation...${NC}\n"

# Get list of changed Dart files
CHANGED_FILES=$(git diff --name-only --diff-filter=ACMR HEAD | grep '\.dart$' || true)

if [ -z "$CHANGED_FILES" ]; then
    echo -e "${GREEN}✓ No Dart files changed${NC}\n"
    exit 0
fi

# Function to check for critical violations (BLOCKS)
check_critical_violations() {
    local file=$1
    local violations=""

    # CRITICAL 1: Direct FirebaseFirestore.instance usage
    if grep -n "FirebaseFirestore\.instance" "$file" 2>/dev/null | grep -v "// "; then
        violations+="${RED}[CRITICAL] Direct FirebaseFirestore.instance usage detected${NC}\n"
        violations+="  File: $file\n"
        violations+="  Lines: $(grep -n 'FirebaseFirestore\.instance' "$file" | grep -v '//' | cut -d: -f1 | tr '\n' ',' | sed 's/,$//')\n"
        violations+="  ❌ NEVER use FirebaseFirestore.instance directly\n"
        violations+="  ✅ USE: Inject repository via constructor\n"
        violations+="  Example: MyService({required RecipeRepository repository})\n\n"
        CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
    fi

    # CRITICAL 2: Legacy sl<T>() pattern
    if grep -n "\bsl<" "$file" 2>/dev/null | grep -v "//"; then
        violations+="${RED}[CRITICAL] Legacy sl<T>() pattern detected${NC}\n"
        violations+="  File: $file\n"
        violations+="  Lines: $(grep -n '\bsl<' "$file" | grep -v '//' | cut -d: -f1 | tr '\n' ',' | sed 's/,$//')\n"
        violations+="  ❌ sl<T>() pattern removed from codebase\n"
        violations+="  ✅ USE: ServiceLocator.get<T>()\n\n"
        CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
    fi

    # CRITICAL 3: ViewModel accessing Repository directly (layer bypass)
    if echo "$file" | grep -q "viewmodels/" && grep -q "Repository" "$file" 2>/dev/null; then
        # Check if it's a field declaration or constructor parameter (not just import)
        if grep -E "final.*Repository |required.*Repository " "$file" 2>/dev/null | grep -v "//"; then
            violations+="${RED}[CRITICAL] ViewModel accessing Repository directly${NC}\n"
            violations+="  File: $file\n"
            violations+="  ❌ ViewModels must NOT access repositories directly\n"
            violations+="  ✅ USE: Services layer instead\n"
            violations+="  Example: final UnifiedRecipeService _service;\n\n"
            CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
        fi
    fi

    # CRITICAL 4: Repository not extending BaseFirebaseRepository
    if echo "$file" | grep -q "repositories/firebase/" && ! grep -q "extends BaseFirebaseRepository" "$file" 2>/dev/null; then
        if grep -q "class.*Repository" "$file" 2>/dev/null && ! grep -q "Mock" "$file"; then
            violations+="${RED}[CRITICAL] Firebase repository not extending BaseFirebaseRepository${NC}\n"
            violations+="  File: $file\n"
            violations+="  ❌ All Firebase repositories must extend BaseFirebaseRepository\n"
            violations+="  ✅ This provides: Permission validation, audit logging, CRUD operations\n\n"
            CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
        fi
    fi

    if [ -n "$violations" ]; then
        echo -e "$violations"
    fi
}

# Function to check for style warnings (ALLOWS with warning)
check_style_warnings() {
    local file=$1
    local warnings=""

    # WARN 1: File size >500 LOC without clear facade pattern
    if [ -f "$file" ]; then
        LINE_COUNT=$(wc -l < "$file")
        if [ "$LINE_COUNT" -gt 500 ]; then
            # Check if it has extracted modules (facade pattern indicators)
            if ! grep -q "Manager\|Module\|Coordinator\|Handler" "$file" 2>/dev/null; then
                warnings+="${YELLOW}[WARN] File exceeds 500 LOC without facade pattern${NC}\n"
                warnings+="  File: $file ($LINE_COUNT lines)\n"
                warnings+="  ⚠️ Consider using facade pattern with extracted modules\n"
                warnings+="  Example: RecipeFormViewModel (905 lines) with 6 extracted managers\n\n"
                WARN_COUNT=$((WARN_COUNT + 1))
            fi
        fi
    fi

    # WARN 2: Service not extending BaseService
    if echo "$file" | grep -q "services/" && grep -q "class.*Service" "$file" 2>/dev/null; then
        if ! grep -q "extends BaseService\|extends ChangeNotifier\|abstract class" "$file" 2>/dev/null; then
            if ! grep -q "Mock\|Test\|Fake" "$file"; then
                warnings+="${YELLOW}[WARN] Service not extending BaseService${NC}\n"
                warnings+="  File: $file\n"
                warnings+="  ⚠️ Services should extend BaseService for ErrorHandlingMixin\n"
                warnings+="  ✅ Provides: executeServiceOperation(), error handling, lifecycle hooks\n\n"
                WARN_COUNT=$((WARN_COUNT + 1))
            fi
        fi
    fi

    # WARN 3: Manual try-catch instead of ErrorHandlingMixin
    if echo "$file" | grep -q "services/\|viewmodels/" && grep -q "try {" "$file" 2>/dev/null; then
        if ! grep -q "executeServiceOperation\|executeAsync" "$file" 2>/dev/null; then
            warnings+="${YELLOW}[WARN] Manual error handling detected${NC}\n"
            warnings+="  File: $file\n"
            warnings+="  ⚠️ Consider using ErrorHandlingMixin via BaseService or AsyncOperationMixin\n"
            warnings+="  ✅ Provides: Consistent error handling, retry logic, user feedback\n\n"
            WARN_COUNT=$((WARN_COUNT + 1))
        fi
    fi

    # WARN 4: Manual null-safe parsing instead of SerializationUtils
    if echo "$file" | grep -q "models/" && grep -E "as String\? \?\? ''|as int\? \?\? 0|as List\?.*\?\? \[\]" "$file" 2>/dev/null | head -n 1 >/dev/null; then
        warnings+="${YELLOW}[WARN] Manual null-safe parsing detected${NC}\n"
        warnings+="  File: $file\n"
        warnings+="  ⚠️ Consider using SerializationUtils for consistent parsing\n"
        warnings+="  ✅ Provides: Safe data extraction, type conversion, timestamp handling\n"
        warnings+="  Example: SerializationUtils.safeString(data, 'field')\n\n"
        WARN_COUNT=$((WARN_COUNT + 1))
    fi

    if [ -n "$warnings" ]; then
        echo -e "$warnings"
    fi
}

# Main validation loop
echo "Checking files:"
for file in $CHANGED_FILES; do
    if [ -f "$file" ]; then
        echo "  - $file"

        # Check critical violations (will block)
        check_critical_violations "$file"

        # Check style warnings (won't block)
        check_style_warnings "$file"
    fi
done

# Summary and exit code
echo ""
echo "================================"
echo "Architecture Validation Summary"
echo "================================"

if [ $CRITICAL_COUNT -gt 0 ]; then
    echo -e "${RED}✗ CRITICAL VIOLATIONS: $CRITICAL_COUNT${NC}"
    echo -e "${RED}❌ COMMIT BLOCKED - Fix critical violations before committing${NC}\n"
    echo "Critical violations break architecture integrity and security."
    echo "These must be fixed before proceeding."
    exit 1
fi

if [ $WARN_COUNT -gt 0 ]; then
    echo -e "${YELLOW}⚠ STYLE WARNINGS: $WARN_COUNT${NC}"
    echo -e "${YELLOW}✓ Commit allowed, but consider addressing warnings${NC}\n"
    echo "Style warnings indicate maintainability issues."
    echo "Fix when convenient to improve code quality."
fi

if [ $CRITICAL_COUNT -eq 0 ] && [ $WARN_COUNT -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
fi

echo ""
exit 0
