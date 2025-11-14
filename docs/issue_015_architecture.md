# Issue #015: Shopping List Items Array → Subcollection Migration

**Status**: In Progress
**Estimated Time**: 24 hours
**Pattern**: Following Issue #014 architecture (arrays → subcollections)
**Started**: 2025-01-14

---

## Problem Statement

### Current Limitation
SharedShoppingList stores items as an embedded array field (`List<UnifiedShoppingItem> listItems`) within the Firestore document. This creates a **hard limit of 100 elements** due to Firestore's array constraints.

**Impact**:
- Large shopping lists (200+ items) cannot be created
- Collaborative lists with many contributors hit limit quickly
- Bulk imports from recipes fail for large meal plans
- Poor user experience for power users

### Similar to Issue #014
Issue #014 successfully migrated status tracking arrays (`sharedToUserIds`, `viewedByUserIds`, etc.) to subcollections. This migration follows the same proven pattern.

---

## Solution Architecture

### Firestore Schema Migration

#### BEFORE (Current - Array-Based)
```
shared_shopping_lists/{listId}
  - listItems: [array of 0-100 UnifiedShoppingItem documents]
  - sharedByUserId: string
  - listTitle: string
  - members/{userId} ← Issue #014
  - views/{userId} ← Issue #014
  - engagements/{userId} ← Issue #014
  - dismissals/{userId} ← Issue #014
```

#### AFTER (Target - Subcollection-Based)
```
shared_shopping_lists/{listId}
  - itemCount: number (cached count for UI)
  - sharedByUserId: string
  - listTitle: string
  - items/{itemId} ← NEW SUBCOLLECTION (Issue #015)
    - id: string
    - name: string
    - amount: number
    - unit: string
    - category: string
    - bought: boolean
    - addedByUserId: string
    - addedByDisplayName: string
    - addedAt: timestamp
    - purchasedByUserId: string?
    - purchasedByDisplayName: string?
    - purchasedAt: timestamp?
    - lastModifiedByUserId: string?
    - lastModifiedByDisplayName: string?
    - lastModifiedAt: timestamp?
    - note: string?
    - estimatedPrice: number?
    - priority: number (1-5)
  - members/{userId}
  - views/{userId}
  - engagements/{userId}
  - dismissals/{userId}
```

### Benefits of Subcollection Architecture

1. **Eliminates 100-Element Limit**: Lists can now have unlimited items
2. **Better Performance**: Only load items when needed (lazy loading)
3. **Real-Time Collaboration**: Streams individual item changes, not entire list
4. **Granular Permissions**: Security rules per item (who added/modified)
5. **Scalability**: Individual item documents scale better than large arrays
6. **Atomic Operations**: Add/remove items without loading entire list

---

## Data Model Changes

### SharedShoppingList Model
**File**: `lib/models/shared_shopping_list.dart`

**Removed Fields**:
```dart
final List<UnifiedShoppingItem> listItems; // ❌ REMOVED
```

**Added Fields**:
```dart
/// Number of items in the shopping list.
/// Cached from items subcollection for UI performance (Issue #015).
/// Updated via FieldValue.increment() on item add/remove.
final int itemCount;
```

**Rationale**:
- `itemCount` provides O(1) access to item count for UI badges/counters
- Avoids expensive subcollection queries just to count items
- Maintained via atomic increment/decrement operations

---

## Repository Layer Changes

### FirebaseSharedShoppingRepository
**File**: `lib/repositories/firebase/firebase_shared_shopping_repository.dart`

**New Methods (Items Subcollection CRUD)**:

| Method | Purpose | Firestore Operations |
|--------|---------|---------------------|
| `addItem()` | Add single item | SET item doc + INCREMENT itemCount |
| `addItemsBatch()` | Add multiple items | Batch SET + INCREMENT itemCount |
| `getItems()` | Load all items | Query items subcollection |
| `getItem()` | Get specific item | GET single item doc |
| `updateItem()` | Update item fields | UPDATE item doc |
| `removeItem()` | Delete item | DELETE item doc + DECREMENT itemCount |
| `toggleItemBought()` | Toggle purchased status | UPDATE bought field + metadata |
| `clearCompletedItems()` | Remove bought items | Batch DELETE + RECALCULATE itemCount |
| `uncheckAllItems()` | Uncheck all items | Batch UPDATE bought=false |
| `streamItems()` | Real-time updates | Stream items subcollection |

**Removed Methods**:
- None (createSharedShoppingList still works, just stores itemCount instead of listItems)

**Updated Methods**:
- `createSharedShoppingList()`: Now writes `itemCount: 0` instead of listItems array
- `getSharedShoppingList()`: Returns list with itemCount field (items loaded separately)

---

## Service Layer Impact

### ShoppingItemManagementModule
**File**: `lib/services/unified/modules/shopping_item_management_module.dart`

**No API Changes** - All public methods maintain same signatures:
- `addItemToActiveList()` - delegates to repository.addItem()
- `toggleItemBought()` - delegates to repository.toggleItemBought()
- `removeItemFromActiveList()` - delegates to repository.removeItem()
- `updateItemInActiveList()` - delegates to repository.updateItem()
- `clearCompletedItems()` - delegates to repository.clearCompletedItems()
- `uncheckAllItems()` - delegates to repository.uncheckAllItems()
- `addItemsFromRecipe()` - delegates to repository.addItemsBatch()
- `addItemsBatchToActiveList()` - delegates to repository.addItemsBatch()

**Internal Changes**:
- Replace array manipulation with subcollection CRUD calls
- Add error handling for subcollection operations
- Maintain same transactional guarantees

---

## Firestore Security Rules

### Items Subcollection Rules
**File**: `firestore.rules` (after line 556)

```javascript
// Shopping list items subcollection (Issue #015)
// Allows collaborative editing: all members can add/modify/remove items
match /shared_shopping_lists/{listId}/items/{itemId} {
  // Helper function to check if user has access to the list
  function isSharedWithUser(userId) {
    return userId == get(/databases/$(database)/documents/shared_shopping_lists/$(listId)).data.sharedByUserId
        || exists(/databases/$(database)/documents/shared_shopping_lists/$(listId)/members/$(userId));
  }

  // Members can read all items
  allow read: if request.auth != null && isSharedWithUser(request.auth.uid);

  // Members can add items (collaborative shopping)
  allow create: if request.auth != null
    && isSharedWithUser(request.auth.uid)
    && request.resource.data.keys().hasAll(['id', 'name', 'amount', 'unit', 'category', 'bought'])
    && request.resource.data.id == itemId
    && request.resource.data.addedByUserId == request.auth.uid;

  // Members can update items (check off, modify quantities)
  allow update: if request.auth != null
    && isSharedWithUser(request.auth.uid)
    && request.resource.data.lastModifiedByUserId == request.auth.uid;

  // Members can delete items
  allow delete: if request.auth != null && isSharedWithUser(request.auth.uid);
}
```

**Key Features**:
- ✅ Read access: Owner + all members
- ✅ Write access: Owner + all members (collaborative editing)
- ✅ Audit trail: addedByUserId and lastModifiedByUserId required
- ✅ Data validation: Required fields enforced
- ✅ Security: User can only claim their own userId in metadata

---

## Data Migration Strategy

### Migration Script
**File**: `tools/migrate_issue_015_items_to_subcollections.dart`

**Process**:
1. Query all documents in `shared_shopping_lists` collection
2. For each list with `listItems` array:
   - Read listItems array
   - Create items subcollection documents (one per item)
   - Set `itemCount` field to array length
   - Remove `listItems` field
3. Verify migration (count checks, data validation)
4. Log progress and errors

**Safety Features**:
- **Dry-run mode**: Preview changes without committing
- **Batch processing**: Process 100 lists at a time
- **Progress tracking**: Console output with percentage complete
- **Error handling**: Continue on errors, log failures
- **Rollback capability**: Companion script to reverse migration
- **Backup recommendation**: User prompted to backup before running

**Example Output**:
```
=== Issue #015: Shopping List Items Migration ===
Mode: DRY-RUN (no changes will be made)

Found 47 shopping lists to migrate
Estimated items: ~1,250 (avg 26 items/list)

[1/47] Processing list abc123... 15 items → subcollection ✓
[2/47] Processing list def456... 42 items → subcollection ✓
...
[47/47] Processing list xyz789... 8 items → subcollection ✓

Summary:
  ✅ Successfully migrated: 45 lists (1,203 items)
  ⚠️ Skipped (no items): 2 lists
  ❌ Failed: 0 lists

Ready to run migration for real? Change DRY_RUN to false.
```

---

## Testing Strategy

### Unit Tests
**File**: `test/unit/repositories/firebase_shared_shopping_repository_test.dart`

**New Test Group**: `Items Subcollection CRUD (Issue #015)`
- ✅ Add single item to subcollection
- ✅ Add multiple items in batch
- ✅ Get all items from subcollection
- ✅ Get specific item by ID
- ✅ Update item in subcollection
- ✅ Remove item from subcollection
- ✅ Toggle item bought status
- ✅ Clear completed items (bought=true)
- ✅ Uncheck all items (bought=false)
- ✅ Stream items in real-time
- ✅ Item count increments on add
- ✅ Item count decrements on remove
- ✅ Item count recalculates on clear

**Updated Tests**:
- `seedSharedShoppingList()` helper now accepts `items` parameter
- `createSharedShoppingList()` uses `itemCount` instead of `listItems`
- All existing tests updated to seed items subcollection

### Integration Tests
- Service layer delegates correctly to repository
- Collaborative editing works for multiple users
- Real-time streams propagate changes

### Manual Testing Checklist
- [ ] Create list with 150+ items (exceeds old 100-element limit)
- [ ] Add items from recipe with 50+ ingredients
- [ ] Collaborative editing: 2 users simultaneously add items
- [ ] Performance: Load time for 500-item list
- [ ] Real-time: Item changes stream to all connected clients

---

## Rollout Plan

### Phase 1: Development & Testing (Week 1)
- ✅ Implement all code changes
- ✅ Write comprehensive tests
- ✅ Verify analyzer passes
- ✅ Run migration script in dry-run mode

### Phase 2: Staging Deployment (Week 2)
- Deploy security rules to staging Firestore
- Run migration script on staging data
- Manual QA testing with test users
- Performance monitoring

### Phase 3: Production Deployment (Week 3)
- **Backup production Firestore database**
- Deploy security rules to production
- Run migration script on production data (during low-traffic window)
- Monitor error rates and performance
- Rollback plan ready if needed

### Phase 4: Monitoring (Week 4)
- Track subcollection query performance
- Monitor itemCount consistency
- Collect user feedback on large lists
- Verify no 100-element errors in logs

---

## Success Metrics

### Technical Metrics
- ✅ Zero analyzer errors after migration
- ✅ All 60+ repository tests passing
- ✅ 12+ new items subcollection tests passing
- ✅ Query performance: <200ms for 500-item list
- ✅ Real-time latency: <500ms for item updates

### Business Metrics
- ✅ Support for 200+ item lists
- ✅ Elimination of "list full" errors
- ✅ Collaborative editing works smoothly
- ✅ Zero data loss during migration
- ✅ User satisfaction with large list performance

---

## Risk Assessment

| Risk | Impact | Probability | Mitigation |
|------|--------|------------|-----------|
| Data loss during migration | Critical | Low | Dry-run testing, backups, rollback script |
| Performance regression | High | Medium | Indexed queries, lazy loading, batch operations |
| Breaking collaborative features | High | Low | Comprehensive tests, same service API |
| Security rule misconfiguration | Critical | Low | Follow Issue #014 pattern, emulator testing |
| itemCount desynchronization | Medium | Medium | Atomic increment/decrement, recalculate helper |

---

## Dependencies & Prerequisites

### Completed Dependencies
- ✅ Issue #014: Status arrays → subcollections pattern established
- ✅ BaseFirebaseRepository: CRUD patterns available
- ✅ Copy-on-write mixin: Count field documentation pattern

### Prerequisites
- Firestore database backup (production)
- Security rules deployment access
- Test data for migration validation

---

## References

- **Issue #014**: Status tracking arrays migration (completed 2025-01-14)
- **MASTERPLAN.md**: Issue tracking and progress
- **UnifiedShoppingItem**: Item model documentation
- **Firestore Best Practices**: [Subcollection design patterns](https://firebase.google.com/docs/firestore/data-model#subcollections)

---

**Last Updated**: 2025-01-14
**Status**: Architecture Complete - Ready for Implementation
