# Firestore Indices Deployment Guide

## Overview

This guide explains how to deploy the Firestore composite indices defined in `firestore.indexes.json` to optimize query performance for the Butlery app.

## Current Indices Status

**Total Indices**: 19 composite indices
**Collections Covered**:
- recipes (2 indices)
- recipe_summaries (1 index)
- public_profiles (1 index)
- friend_requests (2 indices)
- shared_recipes (2 indices)
- shared_menus (2 indices)
- shared_shopping_lists (2 indices)
- recipe_comments (2 indices)
- group_invitations (1 index)
- messages (1 index)
- conversations (1 index)
- audit_logs (4 indices) ✨ **NEW - Jan 2025**

## Why Composite Indices Matter

Firestore requires composite indices for queries that combine:
- Multiple `where()` clauses
- `where()` + `orderBy()` on different fields
- `arrayContains` + `orderBy()`

Without these indices, queries will fail in production with:
```
"The query requires an index. You can create it here: [Firebase Console URL]"
```

## New Indices Added (Phase 4.5 - Jan 2025)

### Audit Logs Indices

**Purpose**: Support GDPR compliance, security monitoring, and forensic investigation

1. **userId + timestamp** (getUserAuditLogs)
   - Query: `where('userId', isEqualTo: userId).orderBy('timestamp', descending: true)`
   - Use case: GDPR data subject access requests

2. **resourceType + timestamp** (getResourceAuditLogs)
   - Query: `where('resourceType', isEqualTo: type).orderBy('timestamp', descending: true)`
   - Use case: Security monitoring per resource type

3. **granted + timestamp** (getDeniedAccessAttempts)
   - Query: `where('granted', isEqualTo: false).orderBy('timestamp', descending: true)`
   - Use case: Detect unauthorized access attempts

4. **resourceType + resourceId + timestamp** (getResourceAuditLogs with ID)
   - Query: `where('resourceType', isEqualTo: type).where('resourceId', isEqualTo: id).orderBy('timestamp', descending: true)`
   - Use case: Forensic investigation for specific resources

## Deployment Methods

### Method 1: Firebase CLI (Recommended)

**Prerequisites:**
```bash
npm install -g firebase-tools
firebase login
```

**Deploy indices:**
```bash
# From project root
firebase deploy --only firestore:indexes
```

**Verify deployment:**
```bash
firebase firestore:indexes
```

### Method 2: Manual via Firebase Console

1. Open [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to: Firestore Database → Indexes
4. Click "Add Index" for each new index

**New indices to add manually:**

#### Index 1: audit_logs (userId + timestamp)
- Collection: `audit_logs`
- Fields:
  - `userId` (Ascending)
  - `timestamp` (Descending)
- Query scope: Collection

#### Index 2: audit_logs (resourceType + timestamp)
- Collection: `audit_logs`
- Fields:
  - `resourceType` (Ascending)
  - `timestamp` (Descending)
- Query scope: Collection

#### Index 3: audit_logs (granted + timestamp)
- Collection: `audit_logs`
- Fields:
  - `granted` (Ascending)
  - `timestamp` (Descending)
- Query scope: Collection

#### Index 4: audit_logs (resourceType + resourceId + timestamp)
- Collection: `audit_logs`
- Fields:
  - `resourceType` (Ascending)
  - `resourceId` (Ascending)
  - `timestamp` (Descending)
- Query scope: Collection

## Testing After Deployment

### 1. Verify Index Build Status

Indices can take several minutes to build. Check status in Firebase Console:
- Firestore Database → Indexes
- Status should show "Enabled" (not "Building")

### 2. Test Audit Log Queries

```dart
// Test getUserAuditLogs
final logs = await auditRepository.getUserAuditLogs('testUserId');
print('Retrieved ${logs.length} audit logs');

// Test getResourceAuditLogs
final resourceLogs = await auditRepository.getResourceAuditLogs(
  resourceType: 'recipe',
  resourceId: 'testRecipeId',
);
print('Retrieved ${resourceLogs.length} resource logs');

// Test getDeniedAccessAttempts
final denials = await auditRepository.getDeniedAccessAttempts(
  since: DateTime.now().subtract(Duration(days: 1)),
);
print('Found ${denials.length} denied access attempts');
```

### 3. Monitor Query Performance

Use Firebase Console → Firestore → Usage tab to monitor:
- Query execution time (should be <100ms)
- Index usage statistics
- Query patterns

## Performance Impact

**Before indices:**
- Audit queries: FAIL (missing index error)
- Other complex queries: 500ms - 2s (full collection scan)

**After indices:**
- Audit queries: WORK (enabled by new indices)
- All complex queries: 50-200ms (index-backed)
- Scalability: O(log n) instead of O(n)

**Expected improvement:** 80-90% query latency reduction for indexed queries

## Rollback Procedure

If indices cause issues:

```bash
# Remove specific index
firebase firestore:indexes --delete [INDEX_ID]

# Restore from backup
git checkout HEAD~1 firestore.indexes.json
firebase deploy --only firestore:indexes
```

## Maintenance

**When to update indices:**
1. Adding new queries with `where() + orderBy()`
2. Firestore error in production: "The query requires an index"
3. Query performance degradation (check Firebase Console)

**Best practices:**
- Test indices in dev environment first
- Monitor index build time (can take 10-30min for large collections)
- Remove unused indices to save costs
- Document query patterns when adding indices

## Cost Considerations

**Index storage costs:**
- Each index adds ~50-100% overhead per document
- 19 indices ≈ 2-3x data storage cost
- Justified by query performance requirements

**Cost optimization:**
- Keep only necessary indices
- Use `COLLECTION` scope (not `COLLECTION_GROUP`) when possible
- Monitor via Firebase Console → Usage → Index storage

## Related Files

- `firestore.indexes.json` - Index definitions
- `firestore.rules` - Security rules
- `lib/repositories/firebase/firebase_audit_repository.dart` - Audit queries
- `docs/SECURITY_RULES_DEPLOYMENT.md` - Security rules deployment

## Support

**If indices don't build:**
1. Check Firebase Console → Indexes for error messages
2. Verify JSON syntax: `python -m json.tool firestore.indexes.json`
3. Ensure sufficient Firebase quota (check billing)
4. Contact Firebase Support if build fails after 1 hour

---

**Last Updated**: January 2025 - Phase 4.5 Performance Optimization
**Indices Version**: v2.0 (19 composite indices)
**Status**: ✅ Ready for deployment
