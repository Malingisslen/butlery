# Butlery Scalability Action Plan

**Created:** 2025-12-26
**Based on:** V1 & V2 Scalability Analysis Reports (verified)
**Current Scale:** ~100 users | **Target:** 100K+ users

---

## Executive Summary

| Metric | Current | After Phase 1 | After Phase 2 | After Phase 3 |
|--------|---------|---------------|---------------|---------------|
| Scalability Score | 72/100 | 78/100 | 85/100 | 92/100 |
| Critical Bottlenecks | 6 | 0 | 0 | 0 |
| High Bottlenecks | 8 | 4 | 0 | 0 |
| User Capacity | ~1K | ~5K | ~50K | ~100K+ |
| Monthly Cost @10K | $300 | $200 | $150 | $150 |

**Total Effort:** ~45 days across 3 phases

---

## Phase 1: Immediate Priority (Before 1,000 Users)

**Timeline:** 2 weeks | **Effort:** ~12 days

### FIRE-CRITICAL-001: Move likedByUserIds to Subcollection

**File:** `lib/models/recipe_comment.dart`
**Effort:** 2 days
**Risk:** Medium (requires migration)

**Current Problem:**
```dart
final List<String> likedByUserIds;  // Line 16 - unbounded array in document
```

**Solution:**
1. Create subcollection `recipe_comments/{commentId}/likes/{userId}`
2. Each like = one document with `userId`, `likedAt` fields
3. Add `likeCount` denormalized field to comment document
4. Update Cloud Functions to maintain count on like/unlike

**Files to Modify:**
- `lib/models/recipe_comment.dart` - Remove `likedByUserIds`, add `likeCount`
- `lib/repositories/firebase/firebase_comments_repository.dart` - New subcollection queries
- `functions/src/triggers/comment_like_triggers.ts` - Create if needed

**Migration:**
- Cloud Function to migrate existing likes to subcollection
- Keep backward compatibility during transition

---

### FIRE-CRITICAL-002: Move reactedUserIds to Subcollection

**File:** `lib/models/social/reaction_statistics.dart`
**Effort:** 2 days
**Risk:** Medium (requires migration)

**Current Problem:**
```dart
final Set<String> reactedUserIds;  // Line 37 - stored as list in Firestore
```

**Solution:**
1. Create subcollection `content_reactions/{contentId}/users/{userId}`
2. Store only aggregate counts in ReactionStatistics document
3. Query subcollection for "has user reacted" check

**Files to Modify:**
- `lib/models/social/reaction_statistics.dart` - Remove `reactedUserIds`
- `lib/repositories/firebase/firebase_reaction_repository.dart` - Subcollection queries
- `lib/services/social/reaction_service.dart` - Update reaction logic

---

### QUERY-CRITICAL-001: Add Pagination to Export Operations

**Files:** Export managers
**Effort:** 2 days
**Risk:** Low

**Current Problem:**
```dart
// content_export_manager.dart - Line 21-25
final personalRecipes = await _firestore
    .collection('users').doc(userId).collection('recipes')
    .get();  // NO LIMIT - unbounded
```

**Solution:**
Add `.limit(1000)` + cursor pagination to all export queries:

**Files to Modify:**
- `lib/services/account/export/content_export_manager.dart`
  - Add pagination to personal recipes (line 21-25)
  - Add pagination to unified recipes (line 36-39)
  - Add pagination to menus (lines 65-82)
  - Add pagination to shopping lists (line 108-112)
- `lib/services/account/export/social_export_manager.dart`
  - Add pagination to friends (lines 26-30, 66-70)
  - Add pagination to conversations (lines 103-106)
  - Add pagination to messages (lines 117-120)
  - Add pagination to shared content (lines 159-175)

**Pattern:**
```dart
Future<List<T>> _paginatedQuery<T>(Query query, T Function(DocumentSnapshot) mapper) async {
  final results = <T>[];
  DocumentSnapshot? lastDoc;

  do {
    var q = query.limit(1000);
    if (lastDoc != null) q = q.startAfterDocument(lastDoc);

    final snapshot = await q.get();
    results.addAll(snapshot.docs.map(mapper));
    lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
  } while (lastDoc != null);

  return results;
}
```

---

### QUERY-CRITICAL-003: Denormalize Unread Count

**File:** `lib/repositories/firebase/base_shared_content_repository.dart`
**Effort:** 3 days
**Risk:** Medium

**Current Problem:**
```dart
// Lines 144-148 - O(n) client-side aggregation
final unreadCount = sharedContent
    .where((content) =>
        shouldShowToUser(content, userId) &&
        !isViewedByUser(content, userId))
    .length;
```

**Solution:**
1. Add `unreadCount` field to user document or dedicated counter document
2. Update count via Cloud Function triggers on:
   - New shared content received
   - Content viewed/dismissed
3. Client reads single field instead of aggregating

**Files to Modify:**
- `lib/repositories/firebase/base_shared_content_repository.dart` - Read from counter
- `lib/models/user_profile.dart` - Add `unreadSharedContentCount` field
- Cloud Functions - Triggers to maintain count

---

### V1-QP-001: Fix N+1 Pattern in Shared Content

**File:** `lib/repositories/firebase/base_shared_content_repository.dart`
**Effort:** 3 days
**Risk:** Medium

**Current Problem:**
```dart
// Lines 475-550 - Queries members, then batch-fetches content documents
final memberSnapshot = await memberQuery.get();
// Then N/10 additional queries for content
```

**Solution:**
Denormalize essential content fields into member documents:
```dart
// In members/{userId} subcollection document:
{
  "userId": "...",
  "addedAt": "...",
  // Denormalized fields:
  "contentTitle": "...",
  "contentType": "...",
  "contentImageUrl": "...",
  "ownerDisplayName": "..."
}
```

**Files to Modify:**
- `lib/repositories/firebase/base_shared_content_repository.dart` - Read from member docs
- Share operations - Denormalize on share
- Cloud Functions - Keep denormalized data in sync

---

## Phase 2: Short-Term Priority (Before 10,000 Users)

**Timeline:** 4 weeks | **Effort:** ~18 days

### FIRE-CRITICAL-003: Reference-Based Shared Content

**Files:** `lib/models/shared_recipe.dart`, `lib/models/shared_menu.dart`
**Effort:** 4 days
**Risk:** High (breaking change)

**Current Problem:**
```dart
final Recipe recipeSnapshot;  // Full recipe embedded
final Map<String, List<Recipe>> menuSnapshot;  // Entire menu duplicated
```

**Solution:**
1. Store only content IDs in shared documents
2. Fetch content on-demand when viewing
3. Keep lightweight metadata for list display

**New Structure:**
```dart
class SharedRecipe {
  final String recipeId;  // Reference only
  final String recipeTitle;  // Denormalized for display
  final String? recipeImageUrl;  // Denormalized for display
  final String ownerUserId;
  // ... sharing metadata
}
```

**Files to Modify:**
- `lib/models/shared_recipe.dart` - Replace `recipeSnapshot` with `recipeId` + metadata
- `lib/models/shared_menu.dart` - Replace `menuSnapshot` with IDs
- `lib/repositories/firebase/firebase_shared_recipe_repository.dart` - Fetch on view
- UI views - Load content when opening detail view

---

### FIRE-HIGH-002: Conversation Participants Subcollection

**File:** `lib/models/messaging/conversation.dart`
**Effort:** 3 days
**Risk:** Medium

**Current Problem:**
```dart
final Map<String, String> participantDisplayNames;  // Line 80
final Map<String, String?> participantAvatarUrls;   // Line 85
final Map<String, DateTime> lastReadTimestamps;     // Line 95
```

**Solution:**
For groups >10 members, move to subcollection:
```
conversations/{convId}/participants/{userId}
  - displayName
  - avatarUrl
  - lastReadAt
  - role
```

**Files to Modify:**
- `lib/models/messaging/conversation.dart` - Support both patterns
- `lib/repositories/firebase/firebase_conversation_repository.dart` - Query subcollection
- Group creation - Write to subcollection for large groups

---

### QUERY-HIGH-003: Implement Full-Text Search (Algolia)

**File:** `lib/repositories/firebase/firebase_recipe_repository.dart`
**Effort:** 5 days
**Risk:** Medium (new dependency)

**Current Problem:**
```dart
// Lines 362-392 - Loads 200 recipes, filters client-side
final snap = await getCollectionForUser(userId)
    .limit(200)
    .get();
final results = snap.docs.where((r) => r.title.contains(query));
```

**Solution:**
1. Integrate Algolia (or Meilisearch) for search
2. Sync recipes to search index via Cloud Functions
3. Query search service, return IDs, fetch from Firestore

**Files to Create/Modify:**
- `lib/services/search/algolia_search_service.dart` - New service
- `lib/repositories/firebase/firebase_recipe_repository.dart` - Use search service
- `functions/src/triggers/recipe_sync.ts` - Sync to Algolia on write
- `pubspec.yaml` - Add algolia_helper_flutter dependency

---

### OPS-HIGH-001: Implement Feature Flag System

**Effort:** 3 days
**Risk:** Low

**Solution:**
1. Add Firebase Remote Config dependency
2. Create FeatureFlagService
3. Wrap new features in flag checks

**Files to Create:**
- `lib/services/feature_flags/feature_flag_service.dart`
- `lib/core/di/modules/feature_flag_module.dart`

**Initial Flags:**
- `enable_algolia_search`
- `enable_subcollection_likes`
- `max_group_size_for_embedded_participants`

---

### OP-001: Set Up Alerting

**Effort:** 2 days
**Risk:** Low

**Actions:**
1. Configure Firebase budget alerts
2. Set up Cloud Monitoring alerts for:
   - Error rate spikes
   - Function timeout increases
   - Document read/write anomalies
3. Integrate with PagerDuty/Slack

---

### OP-003: Audit Log Retention with Auto-Cleanup

**File:** `lib/repositories/firebase/firebase_audit_repository.dart`
**Effort:** 2 days
**Risk:** Low

**Current State:**
- Manual `deleteOldAuditLogs()` method exists
- No automatic scheduling

**Solution:**
1. Create scheduled Cloud Function for cleanup
2. Default retention: 90 days (configurable)
3. Archive to BigQuery before deletion (optional)

**Files to Create:**
- `functions/src/scheduled/audit_cleanup.ts`

---

## Phase 3: Medium-Term Priority (Before 100,000 Users)

**Timeline:** 4 weeks | **Effort:** ~15 days

### SEC-HIGH-001: Server-Side Rate Limiting

**Effort:** 3 days

**Current State:**
- Client-side rate limiting in `lib/core/rate_limiting/rate_limiter.dart`
- Can be bypassed by modified clients

**Solution:**
1. Add Cloud Function middleware for rate validation
2. Store rate limit state in Firestore or Redis
3. Return 429 errors for exceeded limits

**Files to Create:**
- `functions/src/middleware/rate_limiter.ts`

---

### FIRE-HIGH-001: Friend Category Junction Collection

**File:** `lib/models/friend_category.dart`
**Effort:** 3 days
**Risk:** Medium

**Current Problem:**
```dart
final List<String> friendUserIds;  // Line 63 - unbounded
```

**Solution:**
Create junction collection:
```
user_categories/{userId}/friends/{friendId}
  - categoryId
  - addedAt
```

---

### FIRE-HIGH-003: Simplify ActivityFeedItem Visibility

**File:** `lib/models/social/activity_feed_item.dart`
**Effort:** 2 days
**Risk:** Low

**Current Problem:**
```dart
final List<String> visibility;  // All friend category IDs
```

**Solution:**
Replace with enum:
```dart
enum VisibilityLevel { public, friends, closeFriends, private }
final VisibilityLevel visibility;
```

---

### Permission Caching Layer

**Effort:** 3 days
**Risk:** Low

**Solution:**
1. Cache permission check results in memory (5-10 min TTL)
2. Invalidate on relevant document changes
3. Reduce Firestore reads for repeated permission checks

**Files to Create:**
- `lib/services/cache/permission_cache_service.dart`

---

### List Virtualization Audit

**Effort:** 3 days
**Risk:** Low

**Actions:**
1. Audit all ListView/GridView usage
2. Ensure `ListView.builder` with proper `itemCount`
3. Add pagination for lists >100 items

---

## Implementation Priority Matrix

| Priority | Issue ID | Action | Effort | Phase |
|----------|----------|--------|--------|-------|
| 1 | FIRE-CRITICAL-001 | likedByUserIds → subcollection | 2d | 1 |
| 2 | FIRE-CRITICAL-002 | reactedUserIds → subcollection | 2d | 1 |
| 3 | QUERY-CRITICAL-001 | Add export pagination | 2d | 1 |
| 4 | QUERY-CRITICAL-003 | Denormalize unread count | 3d | 1 |
| 5 | V1-QP-001 | Fix N+1 pattern | 3d | 1 |
| 6 | FIRE-CRITICAL-003 | Reference-based shared content | 4d | 2 |
| 7 | FIRE-HIGH-002 | Conversation participants subcollection | 3d | 2 |
| 8 | QUERY-HIGH-003 | Algolia search integration | 5d | 2 |
| 9 | OPS-HIGH-001 | Feature flag system | 3d | 2 |
| 10 | OP-001 | Set up alerting | 2d | 2 |
| 11 | OP-003 | Audit log auto-cleanup | 2d | 2 |
| 12 | SEC-HIGH-001 | Server-side rate limiting | 3d | 3 |
| 13 | FIRE-HIGH-001 | Friend category junction | 3d | 3 |
| 14 | FIRE-HIGH-003 | Simplify visibility | 2d | 3 |
| 15 | - | Permission caching | 3d | 3 |
| 16 | - | List virtualization audit | 3d | 3 |

---

## Validation Criteria

### Phase 1 Success Metrics
- [ ] Popular recipes (100+ comments, 50+ likes each) load in <2s
- [ ] Account export completes in <60s for users with 1000+ audit logs
- [ ] Shared content list loads with single round-trip query
- [ ] Unread count retrieved in <100ms (single field read)

### Phase 2 Success Metrics
- [ ] Recipe search works with 10K+ recipes in <500ms
- [ ] Group chats with 100+ members function properly
- [ ] SharedMenu documents <50KB (down from 100-200KB)
- [ ] Feature flags control new feature rollout

### Phase 3 Success Metrics
- [ ] Server rejects requests from rate-exceeded clients
- [ ] Permission checks cached, reducing Firestore reads by 30%
- [ ] All lists virtualized, smooth scrolling with 1000+ items
- [ ] Audit logs auto-cleaned after 90 days

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Migration data loss | Low | High | Backup before migration, staged rollout |
| Breaking API changes | Medium | High | Feature flags, backward compatibility |
| Performance regression | Low | Medium | Load testing before deployment |
| Algolia costs | Medium | Low | Free tier, usage monitoring |
| Cloud Function cold starts | Low | Low | Keep-alive ping, function warming |

---

## Cost Impact

| Phase | Optimization | Expected Savings |
|-------|--------------|------------------|
| 1 | Export pagination | -15% reads |
| 1 | Unread count denormalization | -10% reads |
| 1 | N+1 pattern elimination | -20% reads |
| 2 | Algolia search | -200 reads/search |
| 2 | Audit log retention | -20% storage |
| 3 | Permission caching | -15% reads |

**Projected Monthly Cost After All Optimizations:**
- At 10K users: $150/month (down from $300)
- At 100K users: $1,600/month (down from $3,000)

---

## Dependencies

### External Services
- **Algolia** - Search as a service (Phase 2)
- **Cloud Monitoring** - Alerting (Phase 2)

### Package Additions
- `algolia_helper_flutter` - Algolia SDK
- `firebase_remote_config` - Feature flags

### Cloud Functions
- `comment_like_triggers.ts` - Like count maintenance
- `content_reaction_triggers.ts` - Reaction count maintenance
- `audit_cleanup.ts` - Scheduled cleanup
- `recipe_sync.ts` - Algolia sync
- `rate_limiter.ts` - Server-side rate limiting

---

## Next Steps

1. **Get stakeholder approval** for Phase 1 implementation
2. **Create feature branches** for each major fix
3. **Set up staging environment** for migration testing
4. **Implement Phase 1** (2 weeks)
5. **Deploy with feature flags** for gradual rollout
6. **Monitor and validate** success metrics
7. **Proceed to Phase 2** after Phase 1 validation

---

*Action plan generated from verified scalability analysis findings.*
