---
description: Analyze test coverage for a specific file or module
argument-hint: <file_path or directory>
---

Analyze test coverage for the specified file or directory.

Target: $ARGUMENTS

## Analysis Steps

1. **Find Source Files**
   - Identify all .dart files in scope
   - Exclude generated files, mocks, test files

2. **Find Corresponding Tests**
   - Match source files to test files
   - Check test/unit/, test/widget/, test/integration/

3. **Coverage Analysis**
   For each source file:
   - Has test file? (yes/no)
   - Test file line count vs source line count (coverage ratio)
   - Key methods/classes tested?
   - Permission validation tested? (for repositories)
   - Edge cases covered?

4. **Gap Identification**
   - Files with no tests
   - Files with minimal tests (<30% coverage)
   - Critical paths not tested
   - Missing permission validation tests

## Output Format

```markdown
## Test Coverage Report: [path]

### Summary
- Files analyzed: X
- Files with tests: Y (Z%)
- Estimated coverage: XX%

### Coverage by File
| File | Test File | Coverage | Priority |
|------|-----------|----------|----------|
| auth_service.dart | auth_service_test.dart | 85% | - |
| backup_service.dart | None | 0% | HIGH |

### Recommended Actions
1. [HIGH] Create tests for backup_service.dart
2. [MEDIUM] Expand tests for shopping_viewmodel.dart
```

Ask: "Should I generate tests for the highest-priority gaps using /test-generate?"
