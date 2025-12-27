---
description: Quality review of current changes before committing
argument-hint: [--staged | path]
---

Perform a comprehensive quality review of changes before committing.

Options: $ARGUMENTS

First, run `git diff` (or `git diff --staged` if --staged option) to see what changed.

## Review Checklist

### 1. Architecture Compliance
- [ ] MVVM + Repository pattern followed
- [ ] No files exceed 500 lines (check ACCEPTED_LARGE_FILES.md if they do)
- [ ] Correct mixin usage (ErrorHandlingMixin, AsyncOperationMixin, etc.)
- [ ] ServiceLocator.get<T>() used correctly

### 2. Security
- [ ] PermissionValidationMixin on new repository methods
- [ ] No direct FirebaseFirestore.instance usage
- [ ] Correct data source (UserService.currentUserProfile vs PermissionService.currentUser)

### 3. Code Quality
- [ ] SerializationUtils for all Firestore parsing
- [ ] No deprecated APIs (withOpacity -> withValues)
- [ ] Comments explain WHY not WHAT
- [ ] No section dividers (// ===== SECTION =====)
- [ ] All comments in English

### 4. Testing
- [ ] New code has corresponding tests
- [ ] Existing tests still pass

### 5. Documentation
- [ ] No unnecessary .md files created
- [ ] Existing docs updated if behavior changed

## Output

Provide:
- Summary of changes reviewed
- Issues found (categorized by severity)
- Recommended fixes
- Overall assessment: Ready to commit? (Yes/No/With fixes)

If issues found, ask: "Should I fix these issues before you commit?"
