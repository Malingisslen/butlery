# Specific Fixes Completed

## Issues Fixed (369 → 354 = 15 fixed)

### 1. ✅ Test Infrastructure Functions Added
Created global helper functions in `test/helpers/test_helpers.dart`:
- `setupTestServiceLocator()` - wraps TestServiceLocator.initialize()
- `tearDownTestServiceLocator()` - wraps TestServiceLocator.dispose()  
- `registerFirebaseTestInstances()` - for backward compatibility
- Exported `@mustCallSuper` annotation from meta package
- Exported Firestore types: `Query`, `WriteBatch`, `Transaction`

### 2. ✅ Import Fixes Applied
- `base_repository_test.dart` - Added import for test_helpers.dart
- `base_viewmodel_test.dart` - Added import for test_helpers.dart
- Changed `menu/menu_model.dart` → `shared_menu.dart`

### 3. ✅ Model Parameter Fixes
- Changed `createdBy` → `userId` in RecipeFactory calls (2 instances)
- Changed `MenuModel` → `SharedMenu` type
- Changed `MenuModelFactory` → `SharedMenuFactory`
- Fixed property name: `name` → `title` for SharedMenu

### 4. ✅ Syntax Error Fixed
- Line 409 in base_viewmodel_test.dart: Fixed throw expression syntax

## Remaining Issues (354 total)

### Critical Issues Still Need Fixing:

#### 1. Missing Mock Service/Repository Definitions (~150 issues)
The test files reference mock services that aren't defined:
- Need to create alias types or actual mock classes
- Files affected: `mock_verification_test.dart`

#### 2. URI Import Issues (~25 remaining)
Still need to update imports:
- `authentication_service.dart` → `auth_service.dart`
- `recipe_service.dart` → `unified/unified_recipe_service.dart`
- `chat_service.dart` → `messaging_service.dart`
- Repository paths need updating

#### 3. Missing Factories (~20 issues)
- `MenuModelFactory` → Need to replace with `SharedMenuFactory` everywhere
- `UserFactory` → Replace with `UserProfileFactory`
- `ImportManagerResultFactory` → Use ImportResult class directly

#### 4. Shopping Test Issues (~10 issues)
In `shopping_list_view_example_test.dart`:
- Line 200: `UnifiedShoppingListFactory.buildList(2)` returns wrong type
- Line 243: `buildList()` method doesn't exist, use `build()`
- Line 269-291: List indexing issues

## Next Immediate Actions

### 1. Create Mock Service Aliases
Add to `test/helpers/test_helpers.dart` or create new file:
```dart
// Service mock aliases
typedef MockAuthenticationService = MockAuthService;
typedef MockRecipeService = MockUnifiedRecipeService;
typedef MockSocialService = MockSocialRecipeService;
// ... etc for all missing mocks
```

### 2. Fix Remaining Imports
Update all test files with old service imports to use new paths.

### 3. Fix Factory References
Global find/replace:
- `MenuModelFactory` → `SharedMenuFactory`
- `UserFactory` → `UserProfileFactory`

### 4. Fix Shopping Test
- Use proper factory methods
- Fix list creation and access patterns

## Commands to Run
```bash
# After fixes, run:
cmd.exe /c "dart fix --apply"
cmd.exe /c "flutter analyze"
```

## Expected Result After Completion
- Errors: < 50 (from current 180+)
- Warnings: < 100
- Info: Can be ignored or auto-fixed