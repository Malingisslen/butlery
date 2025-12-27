---
description: Analyze file for refactoring opportunities following project patterns
argument-hint: <file_path>
---

Analyze the specified file for refactoring opportunities following Butlery's established patterns.

Target file: $ARGUMENTS

## Analysis Checklist

1. **Line Count Check**
   - Current line count vs 500-line limit
   - Check if file is in docs/architecture/ACCEPTED_LARGE_FILES.md (if so, note the documented reason)

2. **Pattern Compliance**
   - Does it follow MVVM + Repository pattern?
   - Is it using the correct mixins (ErrorHandlingMixin, AsyncOperationMixin, etc.)?
   - ServiceLocator.get<T>() usage (not sl<T>())
   - SerializationUtils for Firestore parsing

3. **Facade Pattern Opportunity**
   - Can responsibilities be delegated to focused managers?
   - Reference: recipe_form_viewmodel.dart delegates to 6 managers

4. **Deduplication**
   - Code that exists elsewhere in the codebase
   - Opportunities to use existing utilities

5. **Security & Validation**
   - PermissionValidationMixin on repositories
   - Proper data source usage (UserService vs PermissionService)

## Output

Create a structured refactoring plan with:
- Current issues found
- Recommended changes (ordered by priority)
- Files that would be created/modified
- Risk assessment

Ask: "Would you like me to proceed with Phase 1 of this refactoring?"
