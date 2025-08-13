# Script to Remove Invalid @override Annotations

## Problem
90+ warnings about @override annotations on non-overriding members in `test/helpers/mocks/submodule_viewmodel_mocks.dart`

## Quick Fix Commands

```bash
# Find all lines with @override in the problematic file
grep -n "@override" test/helpers/mocks/submodule_viewmodel_mocks.dart

# Count override annotations
grep -c "@override" test/helpers/mocks/submodule_viewmodel_mocks.dart
```

## Manual Fix Pattern
For each warning like:
```
warning - The getter doesn't override an inherited getter - test\helpers\mocks\submodule_viewmodel_mocks.dart:49:20
```

1. Go to line 49
2. Remove the `@override` annotation from the line above
3. Save the file

## Automated Fix (PowerShell)
```powershell
# Create backup
Copy-Item test\helpers\mocks\submodule_viewmodel_mocks.dart test\helpers\mocks\submodule_viewmodel_mocks.dart.bak

# Run dart fix for this specific file
dart fix --apply test\helpers\mocks\submodule_viewmodel_mocks.dart
```

## Common Patterns to Fix

### Pattern 1: Getters without override
```dart
// Before
@override
bool get someProperty => _someProperty;

// After (if not actually overriding)
bool get someProperty => _someProperty;
```

### Pattern 2: Methods without override
```dart
// Before
@override
void someMethod() {
  // implementation
}

// After (if not actually overriding)
void someMethod() {
  // implementation
}
```

## Verification
After fixing, run:
```bash
flutter analyze test/helpers/mocks/submodule_viewmodel_mocks.dart
```

## Expected Result
Should eliminate ~90 override warnings, reducing total issues by approximately 40%.