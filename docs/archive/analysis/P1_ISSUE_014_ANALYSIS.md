# Issue #014: Unbounded Tracking Arrays Analysis

**Date**: November 13, 2025
**Priority**: P1 (High Priority)
**Estimated Effort**: 40 hours
**Status**: Investigation Complete - Ready for Implementation

---

## Executive Summary

Butlery's shared content system (recipes, menus, shopping lists) uses Firestore arrays to track members, viewers, and engagement. **Firestore has a hard 100-element limit on arrays**, causing complete failures when content is shared with/viewed by 100+ users. This blocks viral content scenarios and large group sharing.

**Impact Severity**: **CRITICAL** for scalability
- Viral recipes shared with 100+ friends → Complete failure
- Popular group recipes with 100+ views → Data loss
- Large organization shopping lists with 100+ members → System crash

**Root Cause**: Arrays used for unbounded tracking data (members, views, imports, dismissals, collaborators)

**Solution**: Migrate arrays to subcollections for unlimited scalability

---

## Affected Data Structures

### 1. SharedRecipe (lib/models/shared_recipe.dart)

**Unbounded Arrays** (5 total):
```dart
// Line 73: Members who can view
final List<String> sharedToUserIds;

// Line 78: Users who have viewed
final List<String> viewedByUserIds;

// Line 79: Users who have imported
final List<String> engagedByUserIds; // aka importedByUserIds

// Line 80: Users who have dismissed
final List<String> dismissedByUserIds;

// Line 66: Active collaborators (copy-on-write)
final List<String> activeCollaboratorIds;
```

**Firestore Collection**: `shared_recipes`
**Repository**: `lib/repositories/firebase/firebase_shared_recipe_repository.dart`

**Failure Scenarios**:
- ✅ Viral recipe shared with 150 friends → **FAILURE** at 101st share
- ✅ Popular recipe with 120 views → **FAILURE** at 101st view
- ✅ Community recipe with 80 imports + 30 dismissals → **FAILURE** at threshold
- ✅ Collaborative recipe with 105 active editors → **FAILURE** at 101st editor

### 2. SharedMenu (lib/models/shared_menu.dart)

**Unbounded Arrays** (5 total):
```dart
// Line 82: Members who can view
final List<String> sharedToUserIds;

// Line 87: Users who have viewed
final List<String> viewedByUserIds;

// Line 88: Users who have imported
final List<String> engagedByUserIds; // aka importedByUserIds

// Line 89: Users who have dismissed
final List<String> dismissedByUserIds;

// Line 75: Active collaborators
final List<String> activeCollaboratorIds;
```

**Firestore Collection**: `shared_menus`
**Repository**: `lib/repositories/firebase/firebase_shared_menu_repository.dart`

**Failure Scenarios**:
- ✅ Weekly menu shared with large family group (120 members) → **FAILURE**
- ✅ Popular meal plan with 150 views → **FAILURE**

### 3. SharedShoppingList (lib/models/shared_shopping_list.dart)

**Unbounded Arrays** (4 total):
```dart
// Line 100: Members who can view
final List<String> sharedToUserIds;

// Line 105: Users who have viewed
final List<String> viewedByUserIds;

// Line 106: Users who have joined
final List<String> engagedByUserIds; // aka joinedByUserIds

// Line 107: Users who have dismissed
final List<String> dismissedByUserIds;

// NOTE: Issue #015 covers shopping list items array (listItems)
```

**Firestore Collection**: `shared_shopping_lists`
**Repository**: `lib/repositories/firebase/firebase_shared_shopping_list_repository.dart`

**Failure Scenarios**:
- ✅ Office shopping list with 200 employees → **FAILURE** at 101st member
- ✅ Community food drive list with 150 participants → **FAILURE**

---

## Technical Root Cause

### Firestore Array Limitations

**Hard Limits**:
- ✅ **100 elements maximum** per array field
- ✅ **1 MiB maximum** document size (arrays contribute to this)
- ✅ **20,000 writes/second** per collection (batch operations limited)

**Current Implementation**:
```firestore
// shared_recipes/{recipeId}
{
  "sharedToUserIds": ["user1", "user2", ..., "user100"],  // ❌ HITS LIMIT
  "viewedByUserIds": ["user5", "user7", ...],            // ❌ HITS LIMIT
  "importedByUserIds": ["user3", "user9", ...],          // ❌ HITS LIMIT
  "dismissedByUserIds": ["user12", ...],                 // ❌ HITS LIMIT
  "activeCollaboratorIds": ["user1", "user5", ...]       // ❌ HITS LIMIT
}
```

**Error Behavior**:
- ❌ **Silent truncation** - Firestore drops elements beyond 100 without error
- ❌ **Data loss** - Users 101+ are silently excluded
- ❌ **Inconsistent state** - Counters don't match array lengths

---

## Proposed Solution: Subcollection Migration

### New Architecture

Replace arrays with subcollections for unlimited scalability:

```firestore
// shared_recipes/{recipeId}
{
  "sharedByUserId": "user123",
  "title": "Amazing Pasta",
  "viewCount": 250,        // ✅ Keep counts for performance
  "importCount": 87,       // ✅ Keep counts for performance
  "dismissalCount": 12     // ✅ Add dismissal count
}

// Subcollections (unlimited elements):
shared_recipes/{recipeId}/members/{userId}      // ✅ Who can view
shared_recipes/{recipeId}/views/{userId}        // ✅ Who has viewed
shared_recipes/{recipeId}/imports/{userId}      // ✅ Who has imported
shared_recipes/{recipeId}/dismissals/{userId}   // ✅ Who has dismissed
shared_recipes/{recipeId}/collaborators/{userId}// ✅ Active collaborators
```

**Subcollection Document Structure**:
```typescript
// members/{userId}
{
  "userId": "user123",
  "addedAt": Timestamp,
  "addedBy": "owner456",
  "role": "viewer" | "editor"
}

// views/{userId}
{
  "userId": "user123",
  "viewedAt": Timestamp,
  "viewCount": 5  // Number of times viewed
}

// imports/{userId}
{
  "userId": "user123",
  "importedAt": Timestamp,
  "importedRecipeId": "recipe789"  // ID of their imported copy
}

// dismissals/{userId}
{
  "userId": "user123",
  "dismissedAt": Timestamp,
  "reason": "not_interested" | "already_have" | null
}

// collaborators/{userId}
{
  "userId": "user123",
  "joinedAt": Timestamp,
  "lastEditAt": Timestamp,
  "editCount": 42
}
```

### Benefits

**Scalability**:
- ✅ **Unlimited members** - No 100-element limit
- ✅ **Unlimited views/imports** - Support viral content
- ✅ **Efficient queries** - Firestore subcollection queries scale to millions

**Performance**:
- ✅ **Faster writes** - No need to read-modify-write entire array
- ✅ **Atomic updates** - Subcollection documents update independently
- ✅ **Parallel operations** - Multiple users can view/import simultaneously

**Data Integrity**:
- ✅ **No silent truncation** - Firestore won't drop data
- ✅ **Consistent counts** - Count fields separate from subcollections
- ✅ **Rich metadata** - Store timestamps, reasons, additional context

**Cost**:
- ✅ **Lower read costs** - Query only needed subcollections
- ✅ **Lower write costs** - No full document reads for array updates

---

## Migration Strategy

### Phase 1: Repository Layer (8 hours)

1. **Update BaseSharedContentRepository** (3 hours)
   - Add subcollection helper methods (`addMember`, `removeMember`, `checkMembership`)
   - Add batch subcollection operations
   - Maintain backward compatibility with arrays during transition

2. **Update FirebaseSharedRecipeRepository** (2 hours)
   - Implement subcollection methods for recipes
   - Update queries to use subcollections
   - Add migration helper methods

3. **Update FirebaseSharedMenuRepository** (1.5 hours)
   - Implement subcollection methods for menus

4. **Update FirebaseSharedShoppingListRepository** (1.5 hours)
   - Implement subcollection methods for shopping lists

### Phase 2: Model Layer (4 hours)

1. **Update SharedRecipe Model** (1.5 hours)
   - Remove array fields
   - Add subcollection query methods
   - Update serialization

2. **Update SharedMenu Model** (1.5 hours)
   - Same changes as SharedRecipe

3. **Update SharedShoppingList Model** (1 hour)
   - Same changes (fewer fields - no collaborators)

### Phase 3: Service Layer (6 hours)

1. **Update Social Recipe Services** (2 hours)
   - Update sharing logic to use subcollections
   - Update status tracking methods

2. **Update Social Menu Services** (2 hours)
   - Same updates

3. **Update Social Shopping Services** (2 hours)
   - Same updates

### Phase 4: Data Migration (12 hours)

1. **Create Migration Scripts** (4 hours)
   - Script to migrate existing shared_recipes
   - Script to migrate existing shared_menus
   - Script to migrate existing shared_shopping_lists
   - Dry-run and validation logic

2. **Test Migration on Staging** (3 hours)
   - Run migration on copy of production data
   - Validate data integrity
   - Performance testing

3. **Production Migration** (3 hours)
   - Schedule maintenance window
   - Run migration with monitoring
   - Verify success

4. **Cleanup Old Arrays** (2 hours)
   - Remove array fields after validation period (7 days)
   - Update documentation

### Phase 5: Security Rules (4 hours)

1. **Update firestore.rules** (2 hours)
   - Add rules for new subcollections
   - Maintain security for members/views/imports/dismissals/collaborators

2. **Test Security Rules** (2 hours)
   - Verify member access control
   - Verify only owners can add members
   - Verify users can only mark themselves as viewed/imported/dismissed

### Phase 6: Testing (6 hours)

1. **Repository Tests** (2 hours)
   - Test subcollection CRUD operations
   - Test batch operations
   - Test query performance

2. **Integration Tests** (2 hours)
   - Test full sharing workflows
   - Test status tracking workflows
   - Test edge cases (100+ members)

3. **Performance Tests** (2 hours)
   - Load test with 1000+ members
   - Load test with 10,000+ views
   - Verify query performance

---

## Rollback Plan

**IF migration fails**, rollback strategy:

1. **Keep Arrays During Transition** (2 weeks)
   - Write to BOTH arrays AND subcollections
   - Read from subcollections, fallback to arrays
   - Monitor for errors

2. **Rollback Procedure**:
   - Switch reads back to arrays
   - Stop writing to subcollections
   - Investigate issues
   - Re-attempt migration after fixes

3. **Data Integrity**:
   - All array data preserved during migration
   - No data loss possible
   - Can revert to arrays at any time during 2-week transition

---

## Firestore Security Rules

### New Rules Required

```javascript
// Subcollection rules for shared_recipes (same pattern for menus/shopping_lists)
match /shared_recipes/{recipeId}/members/{userId} {
  allow read: if request.auth != null &&
    (request.auth.uid == userId ||
     isRecipeOwner(recipeId, request.auth.uid));

  allow create: if request.auth != null &&
    isRecipeOwner(recipeId, request.auth.uid) &&
    request.resource.data.userId == userId;

  allow delete: if request.auth != null &&
    (request.auth.uid == userId ||
     isRecipeOwner(recipeId, request.auth.uid));
}

match /shared_recipes/{recipeId}/views/{userId} {
  allow read: if request.auth != null && request.auth.uid == userId;
  allow create, update: if request.auth != null &&
    request.auth.uid == userId &&
    isMemberOfRecipe(recipeId, userId);
}

match /shared_recipes/{recipeId}/imports/{userId} {
  allow read: if request.auth != null && request.auth.uid == userId;
  allow create: if request.auth != null &&
    request.auth.uid == userId &&
    isMemberOfRecipe(recipeId, userId);
}

match /shared_recipes/{recipeId}/dismissals/{userId} {
  allow read: if request.auth != null && request.auth.uid == userId;
  allow create, delete: if request.auth != null && request.auth.uid == userId;
}

match /shared_recipes/{recipeId}/collaborators/{userId} {
  allow read: if request.auth != null && isMemberOfRecipe(recipeId, request.auth.uid);
  allow create, update: if request.auth != null &&
    (request.auth.uid == userId || isRecipeOwner(recipeId, request.auth.uid));
  allow delete: if request.auth != null &&
    (request.auth.uid == userId || isRecipeOwner(recipeId, request.auth.uid));
}

// Helper functions
function isRecipeOwner(recipeId, userId) {
  return get(/databases/$(database)/documents/shared_recipes/$(recipeId)).data.sharedByUserId == userId;
}

function isMemberOfRecipe(recipeId, userId) {
  return exists(/databases/$(database)/documents/shared_recipes/$(recipeId)/members/$(userId));
}
```

---

## Query Performance Comparison

### Current Implementation (Arrays)

```dart
// Query recipes shared with user (100-element limit)
await firestore
  .collection('shared_recipes')
  .where('sharedToUserIds', arrayContains: userId)
  .get();

// Problem: Fails silently if user is element 101+
```

### New Implementation (Subcollections)

```dart
// Query 1: Get all recipes where user is a member (unlimited)
await firestore
  .collectionGroup('members')
  .where('userId', isEqualTo: userId)
  .get();

// Query 2: Get parent recipe documents
final recipeIds = memberDocs.map((doc) => doc.reference.parent.parent!.id);
// Batch get recipes (max 10 at a time, but unlimited total)

// Performance: O(members) instead of O(recipes × avg_array_size)
```

**Benefits**:
- ✅ **Collection group queries** - Firestore optimized for subcollection queries
- ✅ **Composite indexes** - Can add indexes for complex queries
- ✅ **Scalable** - Works with millions of members

---

## Cost Analysis

### Current Costs (Arrays)

```
Read cost: 1 document read per query
Write cost: 1 document read + 1 write (read-modify-write for arrays)
Storage cost: ~50 bytes per userId in array
```

**Example** (recipe shared with 50 users, 200 views):
- Storage: `50 users × 20 bytes + 200 views × 20 bytes = 5KB`
- Each new view: `1 read (to get array) + 1 write (to update array) = 2 operations`

### New Costs (Subcollections)

```
Read cost: 1 document read per query (same)
Write cost: 1 write only (no read required)
Storage cost: ~100 bytes per subcollection document
```

**Example** (recipe shared with 50 users, 200 views):
- Storage: `50 × 100 bytes + 200 × 100 bytes = 25KB` (5× larger BUT...)
- Each new view: `1 write only = 1 operation` (2× faster)

**Net Cost**: Slightly higher storage (5×), significantly lower write cost (2×)

**Scaling** (recipe with 1000 users, 5000 views):
- Current: **IMPOSSIBLE** (hits 100-element limit at 100 users)
- New: `1000 × 100 + 5000 × 100 = 600KB` (well within 1MiB document limit)

---

## Risk Assessment

### High Risk Areas

1. **Data Migration** (Risk: HIGH)
   - Mitigation: Dual-write period, extensive testing, rollback plan
   - Impact: If failed, users lose access to shared content temporarily

2. **Query Performance** (Risk: MEDIUM)
   - Mitigation: Add composite indexes before migration
   - Impact: Slower queries during migration period

3. **Breaking Changes** (Risk: LOW)
   - Mitigation: Maintain API compatibility, deprecate gradually
   - Impact: Existing code continues to work during transition

### Success Criteria

- ✅ All existing shared content migrated successfully
- ✅ Zero data loss during migration
- ✅ Queries work with 1000+ members (validated in testing)
- ✅ Write operations 50% faster than before
- ✅ All tests passing (repositories, services, integration)
- ✅ Security rules validated and deployed

---

## Implementation Checklist

**Phase 1: Repository Layer (8 hrs)**
- [ ] Update BaseSharedContentRepository with subcollection helpers
- [ ] Update FirebaseSharedRecipeRepository
- [ ] Update FirebaseSharedMenuRepository
- [ ] Update FirebaseSharedShoppingListRepository

**Phase 2: Model Layer (4 hrs)**
- [ ] Update SharedRecipe model
- [ ] Update SharedMenu model
- [ ] Update SharedShoppingList model

**Phase 3: Service Layer (6 hrs)**
- [ ] Update social recipe services
- [ ] Update social menu services
- [ ] Update social shopping services

**Phase 4: Data Migration (12 hrs)**
- [ ] Create migration scripts
- [ ] Test on staging data
- [ ] Run production migration
- [ ] Cleanup old arrays after validation

**Phase 5: Security Rules (4 hrs)**
- [ ] Write new subcollection rules
- [ ] Test security rules
- [ ] Deploy to production

**Phase 6: Testing (6 hrs)**
- [ ] Write repository tests
- [ ] Write integration tests
- [ ] Run performance tests with 1000+ members

**Total Effort**: 40 hours (matches estimate)

---

## Related Issues

- **Issue #015**: Shopping list items array (24 hrs) - Separate but related migration
- **Issue #112-#113**: Firebase schema migrations - Same migration tooling

---

## Conclusion

The unbounded array problem is a **critical scalability blocker** that prevents viral content and large-scale collaboration. The subcollection migration is well-understood, low-risk (with rollback plan), and provides unlimited scalability while improving performance.

**Recommendation**: Proceed with implementation immediately after user approval.

**Next Steps**:
1. Get user approval for migration plan
2. Start Phase 1 (Repository Layer)
3. Implement dual-write period for safety
4. Execute migration with monitoring
5. Validate success and cleanup

---

**Analysis Complete** ✅
**Ready for Implementation** ✅
**Documentation**: docs/ultimate/P1_ISSUE_014_ANALYSIS.md
