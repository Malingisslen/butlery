---
name: "source-command-verify"
description: "Run full verification — dart analyze + flutter test on changed files. Use before declaring work done."
---

# source-command-verify

Use this skill when the user asks to run the migrated source command `verify`.

## Command Template

# Verification Steps

Run these checks in order. Stop and fix any failures before proceeding.

## 1. Static Analysis

```bash
dart analyze --fatal-infos
```

If errors are found, fix them before continuing.

## 2. Find Changed Files

Detect which `lib/` files have been modified (staged + unstaged):

```bash
git diff --name-only HEAD -- 'lib/**/*.dart'
git diff --cached --name-only -- 'lib/**/*.dart'
```

## 3. Run Corresponding Tests

For each changed file in `lib/`, find and run its test:
- `lib/services/foo_service.dart` → `test/unit/services/foo_service_test.dart`
- `lib/viewmodels/foo_viewmodel.dart` → `test/unit/viewmodels/foo_viewmodel_test.dart`
- `lib/repositories/foo_repository.dart` → `test/unit/repositories/foo_repository_test.dart`
- `lib/views/foo_view.dart` → `test/views/foo_view_test.dart`
- `lib/widgets/foo_widget.dart` → `test/widget/foo_widget_test.dart`

Run each found test file:
```bash
flutter test test/unit/path/to_test.dart
```

Use forward slashes in all test paths.

## 4. Report Summary

Report a pass/fail summary:
- Analysis: pass/fail
- Tests run: N passed, N failed, N skipped (no test file found)
- If any failures: list them with error output
