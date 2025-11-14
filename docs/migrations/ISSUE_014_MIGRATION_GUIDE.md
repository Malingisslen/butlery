# Issue #014 Migration Guide: Arrays to Subcollections

**Migration Type:** Data Structure Migration
**Risk Level:** Medium (production data modification)
**Estimated Time:** 15-30 minutes (depends on data volume)
**Rollback Strategy:** Available (arrays preserved)

## Overview

This migration moves shared content status tracking from Firestore array fields to subcollections, eliminating the 100-element array limit and enabling unlimited sharing.

### What Changes

**Before (Array-based):**
```
shared_recipes/{recipeId}
├─ sharedToUserIds: [userId1, userId2, ...] ❌ Limited to 100
├─ viewedByUserIds: [userId3, userId4, ...] ❌ Limited to 100
├─ engagedByUserIds: [userId5, ...]        ❌ Limited to 100
└─ dismissedByUserIds: [userId6, ...]      ❌ Limited to 100
```

**After (Subcollection-based):**
```
shared_recipes/{recipeId}
├─ viewCount: 150                          ✅ Unlimited
├─ engagementCount: 80                     ✅ Unlimited
├─ dismissalCount: 20                      ✅ Unlimited
├─ members/{userId}                        ✅ Unlimited subcollection
│  ├─ userId: "user123"
│  ├─ addedBy: "owner456"
│  └─ addedAt: Timestamp
├─ views/{userId}                          ✅ Unlimited subcollection
├─ engagements/{userId}                    ✅ Unlimited subcollection
└─ dismissals/{userId}                     ✅ Unlimited subcollection
```

### Benefits

- ✅ **Unlimited sharing**: No more 100-element limit
- ✅ **Better performance**: Indexed subcollection queries
- ✅ **Atomic operations**: No concurrent array modification conflicts
- ✅ **Scalability**: Production-ready for large-scale sharing

---

## Pre-Migration Checklist

### 1. Backup Production Data

```bash
# Use Firebase Console or CLI to export Firestore data
firebase firestore:export gs://your-bucket/backups/pre-issue-014-migration
```

**Verify backup:**
- Backup size matches expected data volume
- Backup timestamp is correct
- Access to restore process documented

### 2. Code Deployment

**CRITICAL:** Deploy Phase 3 code changes BEFORE running migration:

```bash
# Ensure latest code is deployed
git checkout main
git pull origin main

# Verify Phase 3 changes are present
grep -r "Issue #014" lib/repositories/firebase/base_shared_content_repository.dart
# Should show: "Issue #014: Unlimited sharing support"

# Deploy to production
flutter build web --release
# Deploy to hosting...
```

**Verify deployment:**
- [ ] New repository methods exist: `getMembers()`, `hasViewed()`, etc.
- [ ] ViewModels use status caching
- [ ] UI doesn't call removed model methods

### 3. Environment Setup

```bash
# Ensure Firebase is configured
flutter pub get

# Test Firebase connectivity
dart tools/migrate_issue_014_arrays_to_subcollections.dart --dry-run
```

### 4. Maintenance Window Planning

**Recommended:** Schedule during low-traffic period
- Migration is **non-blocking** (users can continue using app)
- New shares will use subcollections immediately
- Old shares will be migrated in batches

**Estimated Downtime:** None (zero-downtime migration)

---

## Migration Steps

### Step 1: Dry Run (REQUIRED)

**Purpose:** Verify script works without modifying data

```bash
dart tools/migrate_issue_014_arrays_to_subcollections.dart --dry-run
```

**Expected Output:**
```
🚀 Issue #014 Migration Script Starting...
📋 Mode: DRY RUN (no changes)

═══════════════════════════════════════════════════════════
📦 Migrating collection: shared_recipes
═══════════════════════════════════════════════════════════
📊 Found 245 documents to process

🔄 Processing: recipe_abc123
   📋 Migrating 5 members...
   👁️  Migrating 12 views...
   💫 Migrating 3 engagements...
   🚫 Migrating 1 dismissals...
   📊 Updating counts: views=12, engagements=3, dismissals=1
   ✅ Migrated successfully

...

═══════════════════════════════════════════════════════════
📊 MIGRATION SUMMARY
═══════════════════════════════════════════════════════════
Documents processed:         245
Documents skipped:           0
Subcollection entries created: 1,428
Errors:                      0
═══════════════════════════════════════════════════════════

✅ Dry run complete. Run without --dry-run to apply changes.
```

**Verification:**
- [ ] No errors reported
- [ ] Document count matches expected
- [ ] Subcollection entry count seems reasonable

### Step 2: Migrate Single Collection (TEST)

**Purpose:** Test migration on smallest collection first

```bash
# Migrate shared_shopping_lists first (usually smallest)
dart tools/migrate_issue_014_arrays_to_subcollections.dart --collection shared_shopping_lists
```

**Verification:**
```bash
# Check Firebase Console:
# 1. Open shared_shopping_lists collection
# 2. Select any document
# 3. Verify subcollections appear: members, views, engagements, dismissals
# 4. Verify counts updated: viewCount, engagementCount, dismissalCount
```

### Step 3: Migrate Remaining Collections

```bash
# Migrate all collections
dart tools/migrate_issue_014_arrays_to_subcollections.dart
```

**Expected Duration:**
- Small dataset (<1000 docs): 2-5 minutes
- Medium dataset (1000-5000 docs): 5-15 minutes
- Large dataset (>5000 docs): 15-30 minutes

### Step 4: Verification

#### A. Firebase Console Verification

1. Open Firebase Console → Firestore Database
2. Navigate to `shared_recipes` collection
3. Select any document
4. **Verify subcollections exist:**
   - `members` subcollection with user documents
   - `views` subcollection with view records
   - `engagements` subcollection with engagement records
   - `dismissals` subcollection with dismissal records

5. **Verify count fields updated:**
   - `viewCount` matches number of docs in `views` subcollection
   - `engagementCount` matches number of docs in `engagements`
   - `dismissalCount` matches number of docs in `dismissals`

#### B. Application Testing

**Test Scenario 1: View Shared Recipe**
1. Log in as user A
2. Share recipe with user B
3. Log in as user B
4. View shared recipe
5. **Verify:** `views` subcollection contains user B's document

**Test Scenario 2: Import/Join Content**
1. User B imports shared recipe
2. **Verify:** `engagements` subcollection contains user B's document
3. **Verify:** `engagementCount` incremented

**Test Scenario 3: Dismiss Content**
1. User B dismisses shared recipe
2. **Verify:** `dismissals` subcollection contains user B's document
3. **Verify:** Recipe no longer shows in user B's "Shared with me"

**Test Scenario 4: Large Sharing (>100 users)**
1. Create test recipe
2. Share with 150+ users (if possible in test environment)
3. **Verify:** All members added to `members` subcollection
4. **Verify:** No errors, no truncation

#### C. Performance Verification

```dart
// Test subcollection query performance
final members = await repository.getMembers(recipeId);
// Should complete in <500ms for 100+ members

final hasViewed = await repository.hasViewed(recipeId, userId);
// Should complete in <200ms (indexed query)
```

---

## Rollback Procedure

**If migration fails or issues detected:**

### Option 1: Re-run Migration (Idempotent)

The migration script is idempotent - you can run it multiple times safely:

```bash
# Re-run will skip already-migrated documents
dart tools/migrate_issue_014_arrays_to_subcollections.dart
```

### Option 2: Restore from Backup

```bash
# Restore from Firebase backup
firebase firestore:import gs://your-bucket/backups/pre-issue-014-migration

# Redeploy previous code version
git checkout <previous-release-tag>
flutter build web --release
# Deploy...
```

### Option 3: Manual Rollback (NOT RECOMMENDED)

Original arrays are preserved during migration. The app will continue working with arrays until Phase 5 (when arrays are optionally removed).

**No immediate rollback needed** - both systems work in parallel.

---

## Post-Migration Tasks

### 1. Monitor Application

**First 24 hours after migration:**
- Monitor error logs for subcollection query failures
- Check Firebase Console for unusual subcollection growth
- Verify performance metrics (query times, load times)

**Key Metrics:**
- Firebase Reads: Should be similar or slightly lower
- Query Latency: Should be similar or better
- Error Rate: Should remain at baseline

### 2. Performance Validation

Run performance tests:

```bash
# Run integration tests
flutter test test/integration/

# Check for subcollection query performance
# Expected: <500ms for 100+ member queries
```

### 3. Optional: Clean Up Arrays (Phase 5)

**WAIT 1-2 WEEKS** before removing arrays to ensure stability.

Arrays can be safely removed after migration is stable:

```dart
// Future cleanup (Phase 5 - deferred)
await docRef.update({
  'sharedToUserIds': FieldValue.delete(),
  'viewedByUserIds': FieldValue.delete(),
  'engagedByUserIds': FieldValue.delete(),
  'dismissedByUserIds': FieldValue.delete(),
});
```

---

## Troubleshooting

### Error: "Permission denied"

**Cause:** Firebase security rules not updated
**Fix:** Deploy Phase 5 security rules (see SECURITY_RULES.md)

### Error: "Document limit exceeded"

**Cause:** Batch write too large
**Fix:** Script handles this automatically with smaller batches

### Migration Stuck/Slow

**Cause:** Large dataset or network issues
**Fix:**
- Check Firebase Console quota usage
- Run with `--collection` flag to migrate one collection at a time
- Consider running during off-peak hours

### Subcollections Not Appearing

**Cause:** Dry-run mode still enabled
**Fix:** Run without `--dry-run` flag

### Count Fields Incorrect

**Cause:** Migration ran before Phase 3 code deployed
**Fix:**
1. Deploy Phase 3 code
2. Re-run migration (idempotent, will update counts)

---

## Migration Script Reference

### Command-Line Options

```bash
# Dry run (preview only, no changes)
dart tools/migrate_issue_014_arrays_to_subcollections.dart --dry-run

# Migrate all collections
dart tools/migrate_issue_014_arrays_to_subcollections.dart

# Migrate specific collection only
dart tools/migrate_issue_014_arrays_to_subcollections.dart --collection shared_recipes
dart tools/migrate_issue_014_arrays_to_subcollections.dart --collection shared_menus
dart tools/migrate_issue_014_arrays_to_subcollections.dart --collection shared_shopping_lists
```

### Script Features

- ✅ **Idempotent**: Safe to run multiple times
- ✅ **Non-destructive**: Preserves original arrays
- ✅ **Progress logging**: Real-time status updates
- ✅ **Error handling**: Continues on individual document errors
- ✅ **Dry-run mode**: Preview changes without modifying data

---

## Success Criteria

Migration is successful when:

- ✅ All documents have subcollections (`members`, `views`, `engagements`, `dismissals`)
- ✅ Count fields match subcollection document counts
- ✅ No errors in migration summary
- ✅ Application functions normally (sharing, viewing, importing works)
- ✅ Performance metrics remain stable or improve
- ✅ Users can share with >100 people without errors

---

## Support

**Issues or Questions:**
- Check [Issue #014 tracking document](../audit/ISSUE_TRACKER.md)
- Review [Architecture documentation](../architecture/)
- Contact development team

**Emergency Rollback:**
- Restore from backup immediately
- Redeploy previous code version
- Document issue for post-mortem
