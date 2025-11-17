# Architectural Decision: firebase_social_recipe_repository.dart and BaseFirebaseRepository

**Date**: 2025-01-15
**Status**: Accepted
**Context**: Issue #017 - BaseFirebaseRepository adoption gaps

## Decision

`firebase_social_recipe_repository.dart` will **NOT** be migrated to extend `BaseFirebaseRepository` at this time.

## Rationale

### 1. **Architectural Mismatch: Non-CRUD Operations**

BaseFirebaseRepository is designed for single-entity CRUD (Create, Read, Update, Delete) patterns. However, firebase_social_recipe_repository implements **specialized update operations** rather than traditional CRUD:

**Implemented Operations:**
- `markSharedRecipeAsViewed(recipeId, userId)`
- `markSharedMenuAsViewed(menuId, userId)`
- `markSharedRecipeAsImported(recipeId, userId)`
- `markSharedMenuAsImported(menuId, userId)`
- `dismissSharedRecipe(recipeId, userId)`
- `dismissSharedMenu(menuId, userId)`
- `undismissSharedRecipe(recipeId, userId)`
- `undismissSharedMenu(menuId, userId)`
- `shareContent(fromUserId, toUserId, contentType, contentData)`

**Missing Operations:**
- ❌ No `create()` - Documents created by other repositories
- ❌ No `read()` - Data accessed via specialized queries
- ❌ No `update()` - Only field-specific updates (viewed, imported, dismissed)
- ❌ No `delete()` - Not applicable to this repository's domain

### 2. **Multi-Entity Repository Pattern**

This repository operates on **two distinct entity types**:
- `SharedRecipe` (from shared_recipes collection)
- `SharedMenu` (from shared_menus collection)

BaseFirebaseRepository is designed for **single-entity** repositories with one collection and one model type. Forcing this repository into BaseFirebaseRepository would require:
- Creating two separate repositories (unnecessary code duplication)
- OR implementing a complex generic solution that adds more complexity than it removes

### 3. **Document Modification Pattern**

This repository primarily **modifies documents created elsewhere**:
- Documents are created by `SharedRecipeRepository` and `SharedMenuRepository`
- This repository adds metadata fields (viewed timestamps, import flags, dismissed flags)
- It operates as a **metadata annotation service** rather than a primary data store

BaseFirebaseRepository's permission validation model assumes ownership and creation, which doesn't apply to this repository's use case.

## Current Architecture

```dart
class FirebaseSocialRecipeRepository with PermissionValidationMixin
    implements SocialRecipeRepository {

  // Works with multiple entity types
  CollectionReference<Map<String, dynamic>> get sharedRecipesRef => ...;
  CollectionReference<Map<String, dynamic>> get sharedMenusRef => ...;

  // Specialized operations only
  Future<void> markSharedRecipeAsViewed(...) async { ... }
  Future<void> markSharedMenuAsViewed(...) async { ... }
  // ... 7 more specialized operations
}
```

## GDPR Compliance Gap Identified

⚠️ **CRITICAL FINDING**: This repository uses `logPermissionCheck` (console-only logging) instead of persistent audit logging via `FirebaseAuditRepository`.

**Current State:**
```dart
logPermissionCheck(
  userId: currentUser,
  resource: 'shared_recipe',
  operation: 'mark_viewed',
  granted: true,
);
```

**Should Be:**
```dart
await logPermissionCheck(
  userId: currentUser,
  resource: 'shared_recipe',
  operation: 'mark_viewed',
  granted: true,
  auditRepository: _auditRepository, // ← Missing!
);
```

**Impact**: Violations of GDPR Article 30 (Records of processing activities). All access to shared content should be audit-logged for compliance.

## Recommended Action

### Short-Term (Issue #017)
1. ✅ Document architectural decision (this file)
2. ⏳ Create separate issue for audit logging enhancement
3. ⏳ Continue using current architecture (no forced migration)

### Long-Term (Future Refactoring)
Consider creating a **BaseMetadataRepository** pattern for repositories that:
- Annotate documents created by other repositories
- Perform field-specific updates rather than full CRUD
- Work with multiple entity types
- Need consistent permission validation and audit logging

**Example Architecture:**
```dart
abstract class BaseMetadataRepository<T> with PermissionValidationMixin {
  // Metadata-specific operations
  Future<void> addMetadata(String resourceId, Map<String, dynamic> metadata);
  Future<void> removeMetadata(String resourceId, List<String> fields);

  // Permission validation hooks
  Future<bool> validateMetadataAccess(String userId, String resourceId);
}
```

## Related Files

- [lib/repositories/firebase/firebase_social_recipe_repository.dart](../../lib/repositories/firebase/firebase_social_recipe_repository.dart) - Repository implementation
- [lib/repositories/firebase/base_firebase_repository.dart](../../lib/repositories/firebase/base_firebase_repository.dart) - Base repository pattern
- [docs/ultimate/MASTERPLAN.md](../ultimate/MASTERPLAN.md) - Issue #017 tracking

## References

- **Issue #017**: BaseFirebaseRepository adoption gaps
- **GDPR Article 30**: Records of processing activities
- **BaseFirebaseRepository Design**: Single-entity CRUD pattern with permission validation
