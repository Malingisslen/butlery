# Performance & Scalability Analysis — Phase 1 Report

```
BUTLERY PERFORMANCE & SCALABILITY ANALYSIS — PHASE 1
=====================================================
Analysis Date: 2026-02-26
Analyst: Claude (Opus 4.6)
Firebase Project: butlery-app-1
Platforms: Android, iOS, Web, macOS, Windows

OVERALL SCORE: 78/100
  1. App Startup & Frame Rate:         14/18
  2. Memory & Resource Management:     13/15
  3. Firebase Query & Schema Design:   14/18
  4. Real-time Listeners & Streams:    10/12
  5. Scalability Projections:          11/15
  6. Bundle Size & Network Efficiency: 10/12
  7. Offline Performance & Sync:        6/10

STATUS: Good

CRITICAL ISSUES: 1 found
HIGH PRIORITY:   5 found
MEDIUM PRIORITY: 8 found
LOW PRIORITY:    6 found
```

---

## Performance Benchmarks

| Metric | Current (est.) | Target | Gap | Status |
|---|---|---|---|---|
| Cold start time | 2.5–3.5s | < 2.0s | +0.5–1.5s | ⚠️ Needs work |
| Warm start time | 0.8–1.2s | < 1.0s | ~0s | ✅ Acceptable |
| Average FPS | 58–60fps | 60fps | -0–2fps | ✅ Good |
| Jank percentage | ~2% | < 1% | +1% | ⚠️ Minor |
| Memory usage (typical) | ~120MB | < 150MB | -30MB | ✅ Good |
| Memory usage (peak) | ~180MB | < 250MB | -70MB | ✅ Good |
| Bundle size (Android) | ~35–45MB | < 50MB | -5–15MB | ✅ Good |
| Firestore queries/screen | 3–6 | < 5 | +0–1 | ✅ Acceptable |
| Data transfer/hour | ~3–5MB | < 5MB | ~0 | ✅ Good |
| Offline features | 40% | 100% | -60% | ⚠️ Recipes only |

---

## Firestore Collection Structure Map

### User-Scoped Collections (`users/{userId}/...`)

| Collection | Est. Doc Size | Growth | Key Queries | Indexes | Issues |
|---|---|---|---|---|---|
| `recipes` | 5–15KB | Unbounded per-user | userId+createdAt, userId+lastCooked, userId+tag filters (8 indexes) | ✅ 11 indexes | **CRITICAL: `subscribeToUserRecipes` unbounded** |
| `menus` | 2–5KB | Bounded (1–20) | ownerId queries | N/A (simple) | None |
| `unified_shopping_lists` | 2–5KB | Bounded (1–10) | ownerId+type | N/A | None |
| `personalTagIds` | ~200B | Bounded (10–50) | sortOrder, groupId | N/A | None |
| `personalTagGroups` | ~500B | Bounded (5–20) | sortOrder | N/A | None |
| `friends` | ~100B | Bounded (10–500) | addedAt | N/A | None |
| `friendCategories` | ~500B | Bounded (5–20) | friendUserIds (array) | ✅ Field override | None |
| `ingredients` (user) | ~200B | Bounded (50–500) | N/A | N/A | None |

### Global Collections

| Collection | Est. Doc Size | Growth | Key Queries | Indexes | Issues |
|---|---|---|---|---|---|
| `public_profiles` | 1–2KB | 1 per user | isSearchable+displayNameLower | ✅ 1 index | Fallback search limit:100 |
| `friend_requests` | ~500B | Transient | to/fromUserId+status+sentAt | ✅ 2 indexes | No limits on streams |
| `shared_recipes` | 10–20KB | Unbounded | sharedWithUserIds+sharedAt | ✅ 2 indexes | Subcollection growth |
| `shared_menus` | 5–10KB | Unbounded | sharedWithUserIds+sharedAt | ✅ 2 indexes | Subcollection growth |
| `unified_shared_shopping_lists` | 2–5KB | Unbounded | collaborators+updatedAt | ✅ 1 index | No limit on stream |
| `conversations` | 1–2KB | Unbounded | participantIds+isGroup+updatedAt | ✅ 1 index | None |
| `messages` | 0.5–2KB | Unbounded | conversationId+sentAt | ✅ 1 index | ✅ Paginated (limit:50) |
| `recipe_comments` | 0.3–1KB | Unbounded | recipeId+createdAt, +parentId | ✅ 2 indexes | ✅ Limit:50 |
| `recipe_ratings` | 0.2–0.5KB | Unbounded | recipeId, userId | N/A | Stats calc limit:500 |
| `audit_logs` | 0.3–0.5KB | **Unbounded forever** | userId+ts, resourceType+ts, granted+ts, +resourceId | ✅ 4 indexes | No retention policy |
| `user_notifications` | 0.3–0.5KB | Unbounded | userId+isRead | ✅ 1 index | ✅ Limit:50 |
| `shoppingListTemplates` | 2–5KB | Unbounded | isPublic+createdAt, ownerId+createdAt | ✅ 2 indexes | ✅ Limit:20 |
| `group_invitations` | ~500B | Transient | recipientId+status+sentAt | ✅ 1 index | No limits on streams |
| `butlery_archive` | 5–15KB | Admin-managed | createdAt | N/A | ✅ Limit:100 |
| `recipe_summaries` | 1–3KB | Unbounded | userId+createdAt | ✅ 1 index | None |

### Subcollections (shared content)

| Path | Est. Doc Size | Growth | Notes |
|---|---|---|---|
| `shared_recipes/{id}/members` | ~100B | Per-recipe (bounded) | Access control |
| `shared_recipes/{id}/views` | ~100B | **Unbounded** per recipe | No TTL |
| `shared_recipes/{id}/engagements` | ~150B | **Unbounded** per recipe | No TTL |
| `shared_recipes/{id}/dismissals` | ~100B | **Unbounded** per recipe | No TTL |
| `shared_menus/{id}/members` | ~100B | Per-menu (bounded) | Access control |
| `shared_menus/{id}/views` | ~100B | **Unbounded** per menu | No TTL |
| `recipe_comments/{id}/likes` | ~50B | Unbounded per comment | No cleanup |

**Index Utilization Summary:** 31 composite indexes + 3 field overrides = 34 total. All appear actively used. No obviously unused indexes detected.

---

## Cost Analysis

| Scale | Active Users | Est. Reads/Day | Est. Writes/Day | Est. Monthly Cost | Per User/Month |
|---|---|---|---|---|---|
| Current | 10 | 2,400 | 20 | $0.05 | $0.005 |
| 1K | 1,000 | 240K | 2K | $4.43 | $0.004 |
| 10K | 10,000 | 2.4M | 20K | $44 | $0.004 |
| 100K | 100,000 | 24M | 200K | $443 | $0.004 |

**With `subscribeToUserRecipes` unbounded penalty (worst case):**

| Scale | Extra Reads/Day | Extra Monthly Cost | Total Monthly |
|---|---|---|---|
| 10K users (avg 200 recipes, 10% edit/day) | 200K | +$3.60 | ~$48 |
| 100K users (avg 200 recipes, 10% edit/day) | 2M | +$36 | ~$479 |
| 100K users (avg 500 recipes) | 5M | +$90 | ~$533 |

**Storage at scale:**
- 10K users × 200 recipes × 10KB = 20GB → $3.60/month
- 100K users × 200 recipes × 10KB = 200GB → $36/month

**Cost scaling is linear (good).** Per-user cost stays ~$0.004–0.005/month. Firebase remains viable well past 100K users.

---

## Scalability Limits

| Bottleneck | Hits at | Impact | Mitigation Effort |
|---|---|---|---|
| `subscribeToUserRecipes` unbounded | ~200 recipes/user | Each edit reads ALL recipes. Cost 10–100x at scale | 1 line (add `.limit(50)`) |
| Audit logs no retention | ~50K users (storage) | Unbounded storage growth | 2 hours (Cloud Function cron) |
| Subcollection growth (views/engagements) | Popular viral recipe | 10K+ docs per recipe subcollection | 4 hours (TTL policy) |
| Recipe stats calc (500 limit) | Viral recipe with 500+ ratings | Expensive aggregation query | 8 hours (denormalize to parent) |
| Client-side recipe search (200 limit) | 200+ recipes/user | Full scan, slow search | 2–3 days (Algolia integration) |
| Last-write-wins on shared data | Concurrent offline edits | Silent data loss on shopping lists | 2–4 days (conflict resolution) |
| Array membership fields | 20K array limit | Conversations, shopping lists | Already mitigated (Issue #014 subcollections) |

---

## Dimension 1: App Startup & Frame Rate — Score: 14/18

### Summary
Cold start estimated 2.5–3.5s, exceeding the 2.0s target by 0.5–1.5s. The serial module initialization chain (9 modules, all sequential) dominates. Frame rate is generally good at 58–60fps with minor jank from non-.builder ListViews.

### Issues Found

#### HIGH

1. **Serial module initialization blocks startup 800–1500ms** — `lib/core/di/di_container.dart`
   - Impact: Each of 9 DI modules initializes sequentially. Firebase reads in TaggingModule, ContentModule, SocialModule all block the chain.
   - Current: Modules sorted by priority, then `configure()` and `initialize()` called serially.
   - Best Practice: Parallelize independent modules (e.g., Tagging + Social can init concurrently).
   - Scale Threshold: Always (affects every cold start).
   - Effort: 2–3 days.

2. **Blocking ContentModule init path ~400–800ms** — `lib/core/di/modules/content_module.dart:395-407`
   - Impact: OfflineService (Hive/Drift DB open ~200–400ms) → UnifiedRecipeService (Firestore settings + recipe sync ~100–200ms) → Menu + Parser (parallel ~50–100ms). All blocking before first frame.
   - Best Practice: Defer database and recipe sync to after first frame. Show cached/skeleton UI immediately.
   - Scale Threshold: Always.
   - Effort: 2 days.

3. **36 eager singletons at startup** — across all DI modules
   - Impact: All 36 created during configure() phase. Many (MenuService, FriendsService, ParserService) not needed until user navigates to specific screens.
   - Current: `registerSingleton()` vs `registerLazySingleton()` — 36 eager vs 54 lazy.
   - Best Practice: Convert non-critical services to lazy: UnifiedMenuService, UnifiedFriendsService, RecipeParserService, PresenceService. Saves ~200–400ms.
   - Effort: 1 day.

#### MEDIUM

4. **20 ListView/GridView without .builder** — various view files
   - Impact: Eagerly builds all children. Problematic for `friends_list_view.dart`, `conversations_list_view.dart`, `personal_tags_view.dart` where lists can grow.
   - Best Practice: Use ListView.builder for any list > 10 items.
   - Scale Threshold: 50+ items in list.
   - Effort: 2 hours per file.

5. **Firebase.initializeApp() blocking ~200–500ms** — `lib/main.dart:106-108`
   - Impact: Network-dependent native initialization. Cannot be parallelized (required before any Firebase service).
   - Current: Correctly placed first in chain. Already parallelizes Crashlytics + AppCheck after.
   - Best Practice: Accepted cost. Show splash screen during this phase.
   - Effort: N/A (inherent).

#### LOW

6. **dotenv.load() file I/O ~50–200ms** — `lib/main.dart:103`
   - Impact: Disk read for `.env` file. Could be embedded at compile time instead.
   - Best Practice: Use `--dart-define` for build-time config to avoid runtime file I/O.
   - Effort: 4 hours.

### Quick Wins
- Convert 6 non-critical singletons from eager to lazy (saves ~200–400ms)
- Convert `friends_list_view.dart` and `conversations_list_view.dart` to ListView.builder (2 hours)

---

## Dimension 2: Memory & Resource Management — Score: 13/15

### Summary
Memory management is solid. StreamManagementMixin has excellent adoption (20+ classes). Image cache configured at 50MB. Minor risks from dual cache layers and 3 static StreamControllers.

### Issues Found

#### MEDIUM

1. **Dual image cache layers totaling ~150MB potential** — `lib/main.dart:97-99` + `flutter_cache_manager`
   - Impact: Flutter PaintingBinding cache (50MB, 100 images) + `cached_network_image` package (default 1GB disk cache, unconfigured memory limit) + IntelligentCacheManager predictive caching.
   - Current: Only Flutter image cache has explicit limits. `flutter_cache_manager` uses default 200 image / 1GB disk settings.
   - Best Practice: Configure `flutter_cache_manager` max cache size to 200MB. Add memory monitoring.
   - Scale Threshold: 100+ recipes with images.
   - Effort: 2 hours.

2. **HTTP client not reused in import pipelines** — `lib/services/import/fetchers/http_content_fetcher.dart:24`
   - Impact: Creates new `http.Client()` per request when no injected client. Misses connection pooling.
   - Current: `HttpContentFetcher` creates client per call. `YouTubeTranscriptService` and `TiktokPipeline` also create per-instance clients.
   - Best Practice: Inject shared client or use connection pool.
   - Scale Threshold: Frequent recipe imports.
   - Effort: 1 hour.

3. **3 static StreamControllers — app-lifetime persistence** — `lib/core/events/group_events.dart:16`, `lib/viewmodels/recipe_form/image_management/image_upload_notification_manager.dart:18`, `lib/services/unified/operations/modules/comment_utilities.dart:290`
   - Impact: GroupEventBus and ImageUploadNotificationManager use lazy-init broadcast controllers. Minor memory footprint but never disposed.
   - Current: Using `??=` initialization pattern — acceptable for singletons.
   - Best Practice: Acceptable pattern for app-wide event buses. Monitor if subscribers accumulate.
   - Scale Threshold: Not a scale issue.
   - Effort: N/A.

#### LOW

4. **Static StreamSubscription in PersonalTagSelector** — `lib/widgets/tagging/personal_tag_selector.dart:485`
   - Impact: Shared subscription with subscriber counting pattern (`_subscriberCount`). Well-managed with explicit cancel when count reaches 0.
   - Current: Uses reference counting — actually a good pattern to avoid N listeners for N widget instances.
   - Best Practice: Existing pattern is intentional and correct.
   - Effort: N/A.

5. **11 ViewModels without explicit dispose()** — various abstract/simple ViewModels
   - Impact: Most are abstract base classes or simple ViewModels without subscriptions. Actual risk is low.
   - Current: `BaseViewModel` has `_isDisposed` pattern. Subclasses may rely on parent disposal.
   - Best Practice: Verify each has no controllers/subscriptions requiring cleanup.
   - Effort: 2 hours (audit only).

### Quick Wins
- Configure `flutter_cache_manager` max disk cache to 200MB (2 hours)
- Inject shared HTTP client into import pipelines (1 hour)

---

## Dimension 3: Firebase Query & Schema Design — Score: 14/18

### Summary
Schema is well-designed with proper user-scoped subcollections. 34 composite indexes cover most query patterns. One CRITICAL unbounded listener and several growth concerns in subcollections.

### Issues Found

#### CRITICAL

1. **`subscribeToUserRecipes` — unbounded real-time listener** — `lib/repositories/firebase/firebase_recipe_repository.dart:591-606`
   - Impact: Reads ALL user recipes on every change via `.orderBy('core.updatedAt').snapshots()` with NO `.limit()`. Power users with 200+ recipes pay N reads per single edit. At 500 recipes, each edit costs 500 reads.
   - Current: `watchRecipes` correctly uses `.limit(50)` (line 356), but `subscribeToUserRecipes` does not.
   - Best Practice: Add `.limit(50)` to match `watchRecipes`. Use cursor-based pagination for full history.
   - Scale Threshold: 50+ recipes per user (common).
   - Effort: 1 line change + test update.

#### HIGH

2. **Subcollection unbounded growth (views, engagements, dismissals)** — `shared_recipes/{id}/views`, `shared_recipes/{id}/engagements`, etc.
   - Impact: Popular shared recipes accumulate view/engagement/dismissal docs without TTL. A viral recipe could have 10K+ subcollection docs.
   - Current: No cleanup or TTL policy.
   - Best Practice: Firestore TTL policy or Cloud Function cleanup (delete docs > 90 days).
   - Scale Threshold: 1K+ shares of a single recipe.
   - Effort: 4 hours.

3. **Audit log unbounded growth** — `audit_logs` collection
   - Impact: Every permission check, CRUD operation, and security event generates a log. No retention policy means unbounded storage growth.
   - Current: `deleteOldAuditLogs` method exists but is not scheduled.
   - Best Practice: Schedule Cloud Function to delete logs > 2 years (GDPR compliance retained).
   - Scale Threshold: 10K+ users (storage becomes $10+/month).
   - Effort: 2 hours (wire existing method to cron).

#### MEDIUM

4. **Client-side recipe search with 200-doc limit** — `lib/repositories/firebase/firebase_recipe_repository.dart:376`
   - Impact: Loads 200 most recent recipes then filters client-side. Not scalable for users with 500+ recipes.
   - Current: Acknowledged in code comments ("Algolia in future").
   - Best Practice: Integrate Algolia for full-text search.
   - Scale Threshold: 200+ recipes per user.
   - Effort: 2–3 days.

5. **Rating statistics query loads 500 docs** — `firebase_ratings_repository.dart`
   - Impact: Calculates average rating by loading up to 500 rating docs. Expensive for popular recipes.
   - Current: Limit:500 is reasonable but scales poorly.
   - Best Practice: Denormalize `averageRating`, `ratingCount` to recipe document via Cloud Function trigger (already exists: `updateRecipeRatingStats`).
   - Scale Threshold: 500+ ratings on a single recipe.
   - Effort: 8 hours.

#### LOW

6. **Friend request streams without limits** — `lib/repositories/firebase/friend_request_repository.dart` (stream methods)
   - Impact: Streams all pending friend requests without `.limit()`. Unlikely to be large but unbounded.
   - Best Practice: Add `.limit(50)`.
   - Effort: 30 minutes.

### Quick Wins
- Add `.limit(50)` to `subscribeToUserRecipes` (1 line)
- Schedule `deleteOldAuditLogs` via Cloud Function cron (2 hours)
- Add `.limit(50)` to friend request and group invitation streams (30 minutes)

---

## Dimension 4: Real-time Listeners & Streams — Score: 10/12

### Summary
StreamManagementMixin has excellent adoption (20+ classes). Most listeners are properly scoped and disposed. Estimated 8–15 concurrent listeners per active session. Four `.snapshots()` calls in collaborative recipe code lack StreamManagementMixin.

### Real-time Listener Inventory

#### Always Active (while authenticated)

| File:Line | Collection | Type | Limit | Lifecycle |
|---|---|---|---|---|
| `firebase_recipe_repository.dart:591` | `users/{uid}/recipes` | Collection | ❌ **NONE** | StreamManagementMixin ✅ |
| `firebase_recipe_repository.dart:351` | `users/{uid}/recipes` | Collection | ✅ 50 | StreamManagementMixin ✅ |
| `firebase_notifications_repository.dart` | `user_notifications` | Collection | ✅ 50 | Managed ✅ |
| `presence_service.dart:168` | `presence/{userId}` | Document | N/A | Timer-based ✅ |

#### Screen-Specific (active only when view is open)

| File:Line | Collection | Type | Limit | Lifecycle |
|---|---|---|---|---|
| `firebase_comments_repository.dart` | `recipe_comments` | Collection | ✅ 50 | View-scoped ✅ |
| `firebase_ratings_repository.dart` | `recipe_ratings` | Collection | ✅ 500 | View-scoped ✅ |
| `firebase_messaging_repository.dart` | `messages` | Collection | ✅ 50 | View-scoped ✅ |
| `firebase_messaging_repository.dart` | `conversations` | Collection | ✅ 20 | View-scoped ✅ |
| `firebase_personal_tag_repository.dart:78` | `personalTagIds` | Collection | ❌ None | User-scoped (small) ✅ |
| `firebase_personal_tag_repository.dart:173` | `personalTagGroups` | Collection | ❌ None | User-scoped (small) ✅ |
| `friend_request_repository.dart:333` | `friend_requests` | Collection | ❌ None | Pending filter ⚠️ |
| `friend_request_repository.dart:346` | `friend_requests` | Collection | ❌ None | Pending filter ⚠️ |
| `friend_relationship_repository.dart:266` | `friends` | Collection | ❌ None | View-scoped ⚠️ |
| `friend_category_repository.dart:338` | `friendCategories` | Collection | ❌ None | View-scoped (small) ✅ |
| `group_invitation_repository.dart:136` | `group_invitations` | Collection | ❌ None | Pending filter ⚠️ |
| `firebase_shared_shopping_repository.dart` | Shared shopping lists | Collection | ✅ Filter | View-scoped ✅ |
| `group_shared_content_service.dart` | Shopping/menus/recipes | Collection | ✅ Filter | Group view ✅ |

#### Collaborative (active during editing)

| File:Line | Collection | Type | Limit | Lifecycle |
|---|---|---|---|---|
| Realtime recipe editing | `realtime_recipes/{id}` | Document | N/A | ⚠️ Caller responsibility |
| Realtime presence | `realtime_recipes/{id}/presence` | Collection | ✅ isActive | ⚠️ Caller responsibility |

**Concurrent Listener Estimate:** 8–12 typical, up to 18 during social+messaging use.

### Issues Found

#### HIGH

1. **Collaborative recipe streams lack StreamManagementMixin** — realtime recipe editing flows
   - Impact: 4 `.snapshots()` calls (2 document, 2 collection) without centralized lifecycle management. Disposal relies on caller.
   - Current: Streams are returned from methods — caller must cancel. No mixin to enforce cleanup.
   - Best Practice: Add StreamManagementMixin to collaborative repository or document caller contract.
   - Effort: 2 hours.

#### MEDIUM

2. **Friend/invitation streams without limits**
   - Impact: Streams pending friend requests and group invitations without `.limit()`. Bounded by "pending" status filter but could accumulate.
   - Best Practice: Add `.limit(50)`.
   - Effort: 30 minutes.

3. **Ingredient collection full-stream** — `firebase_ingredient_repository.dart:464`
   - Impact: Streams entire global `ingredients` collection. Currently small (<500 items) but unbounded.
   - Current: Not called in production (confirmed `loadCache()` used instead). Dead code risk.
   - Best Practice: Remove if unused, or add `.limit(500)`.
   - Effort: 30 minutes.

### Quick Wins
- Add StreamManagementMixin to collaborative recipe repository (2 hours)
- Add `.limit(50)` to friend/invitation streams (30 minutes)

---

## Dimension 5: Scalability Projections — Score: 11/15

### Summary
Architecture scales well to 10K users with linear cost growth. Good sharding via subcollection pattern (Issue #014). No conflict resolution for shared data is the main gap. Firebase remains viable past 100K users.

### Scalability at Growth Milestones

| Milestone | Users | What Breaks | Required Action |
|---|---|---|---|
| **10x** (100 users) | 100 | Nothing | Monitor metrics |
| **100x** (1K users) | 1,000 | `subscribeToUserRecipes` cost visible | Add `.limit(50)` |
| **1,000x** (10K users) | 10,000 | Audit log storage, subcollection growth | Retention policy, TTL |
| **10,000x** (100K users) | 100,000 | Client-side search insufficient, shared data conflicts | Algolia, conflict resolution |
| **100,000x** (1M users) | 1,000,000 | Firebase listener limits (~100K concurrent), storage costs | Consider hybrid backend |

### Issues Found

#### HIGH

1. **No conflict resolution for shared data** — shopping lists, collaborative recipes
   - Impact: Simultaneous offline edits use Firestore's last-write-wins. Two users editing the same shopping list offline → one user's changes silently lost.
   - Current: No merge strategy, no conflict detection, no user notification of conflicts.
   - Best Practice: Implement field-level merge for shopping lists (array union for items). Add conflict detection for recipes.
   - Scale Threshold: 10+ concurrent collaborators.
   - Effort: 2–4 days.

2. **Hot-spot potential on popular shared recipes** — `shared_recipes` collection
   - Impact: Viral recipes could have 100+ concurrent real-time listeners on the same document. Firestore handles this but costs accumulate.
   - Current: No rate limiting or listener count tracking.
   - Best Practice: Monitor per-document listener count. Consider CDN-like caching layer for popular recipes.
   - Scale Threshold: 1K+ simultaneous viewers.
   - Effort: 4–8 hours (monitoring), 2–3 days (caching layer).

#### MEDIUM

3. **Firebase cost at 100K users ~$500–600/month**
   - Impact: Linear cost scaling means $500–600/month at 100K users including storage. Manageable but worth optimizing.
   - Current: Per-user cost is $0.004–0.005/month (excellent).
   - Best Practice: Acceptable. Optimize reads via caching if needed.
   - Scale Threshold: Budget-dependent.
   - Effort: N/A.

4. **No data migration strategy** — for schema changes at scale
   - Impact: Schema changes (field renames, structure changes) require migrating all documents. At 100K users × 200 recipes = 20M documents.
   - Current: No migration framework.
   - Best Practice: Build batch migration tooling before schema changes.
   - Scale Threshold: Any schema change at 10K+ users.
   - Effort: 2–3 days (framework).

### Quick Wins
- Add `.limit(50)` to all unbounded listeners (prevents cost escalation)
- Wire existing `deleteOldAuditLogs` to scheduled Cloud Function

---

## Dimension 6: Bundle Size & Network Efficiency — Score: 10/12

### Summary
Bundle size estimated 35–45MB (within 50MB target). Good use of 16 deferred imports for code splitting. `flutter_inappwebview` is the heaviest dependency (~10–15MB native). Assets are modest (2.7MB).

### Bundle Size Breakdown (Estimated)

| Category | Size | Details |
|---|---|---|
| Flutter framework + Dart | ~10–12MB | Core runtime |
| Firebase SDKs (10 packages) | ~5–8MB | Auth, Firestore, Storage, FCM, Crashlytics, Performance, Analytics, AppCheck, Functions, remote_config |
| `flutter_inappwebview` | ~10–15MB | WebView for URL recipe import |
| `drift` + `sqlcipher_flutter_libs` | ~3–4MB | Encrypted SQLite for offline |
| `image_cropper` | ~3–5MB | Native image editing |
| Other dependencies | ~3–5MB | Algolia, HTTP, crypto, etc. |
| Fonts (JosefinSans + SpaceGrotesk) | ~1.5MB | 8 font files, 4 weights each |
| Illustrations (arta series + PNGs) | ~1MB | Onboarding + empty states |
| Data files + legal | ~200KB | ingredient_substitutions.json, privacy policies |
| **Total Estimated** | **35–45MB** | |

### Deferred Import Coverage

16 deferred imports across 3 modules:

| Module | Count | Screens Deferred |
|---|---|---|
| Social | 9 | Profile edit, friends list, friend requests, shared with me, collab shopping, menu preview, create shared shopping, friend profile, shared shopping lists |
| Messaging | 2 | Conversations list, chat view |
| Extraction/Import | 5 | URL import, smart import, photo import, file import, archive import |

**Assessment:** Good code splitting for non-critical screens. Core recipe and menu screens load immediately.

### Issues Found

#### MEDIUM

1. **`flutter_inappwebview` is very heavy (~10–15MB)** — `pubspec.yaml:79`
   - Impact: Adds significant native code to all platforms. Only used for URL recipe import.
   - Current: Required for extracting recipe data from websites with JS rendering.
   - Best Practice: Evaluate if `url_launcher` + server-side extraction (Cloud Function) could replace it.
   - Scale Threshold: Not a scale issue but affects initial download size.
   - Effort: 2–3 days (alternative architecture).

2. **No Firebase Storage orphan cleanup** — deleted recipes leave images
   - Impact: Recipe images in Firebase Storage persist after recipe deletion. Storage cost accumulates.
   - Current: No cleanup mechanism detected.
   - Best Practice: Cloud Function trigger on recipe deletion to clean up associated images.
   - Scale Threshold: 10K+ deleted recipes.
   - Effort: 4 hours.

#### LOW

3. **Font files could be subset** — `assets/fonts/`
   - Impact: 8 font files (1.5MB) include full character sets. Swedish only needs Latin + Swedish characters.
   - Best Practice: Subset fonts to required characters (saves ~30–40%).
   - Effort: 2 hours.

4. **Illustration PNGs could be WebP** — `assets/illustrations/`
   - Impact: PNG illustrations (~1MB) could be ~40% smaller as WebP.
   - Best Practice: Convert to WebP.
   - Effort: 1 hour.

### Quick Wins
- Convert illustrations to WebP (saves ~400KB, 1 hour)
- Add Cloud Function trigger for Firebase Storage cleanup on recipe delete (4 hours)

---

## Dimension 7: Offline Performance & Sync — Score: 6/10

### Summary
Recipes have excellent offline support via Drift (encrypted SQLite) with sync queue and auto-reconnect. However, menus, shopping lists, social features, and messaging have NO offline support. Firestore persistence is enabled (100MB cache) but no explicit cache-first read patterns exist.

### Firestore Persistence Configuration

**Location:** `lib/services/unified/unified_recipe_service.dart:436-439`
```dart
_firestore.settings = const Settings(
  persistenceEnabled: true,
  cacheSizeBytes: 100 * 1024 * 1024, // 100 MB
);
```
**Status:** ✅ Configured correctly. 100MB cache, LRU eviction.

### Offline Architecture

**Drift-Based Offline (Recipes Only):**
- `OfflineService` — facade for Drift database (encrypted SQLite via sqlcipher)
- `OfflineSyncManager` — retry with exponential backoff, async lock prevents concurrent syncs
- `OfflineUserStorage` — user-scoped recipe storage with reactive streams
- `ConnectivityMonitoringService` — 30s polling + Firebase connection monitoring

**Firestore-Based Offline (Transparent):**
- Firestore SDK caches recently accessed documents (100MB configured)
- Pending writes queued automatically by Firestore SDK
- No explicit `Source.cache` usage for read-your-writes pattern

### Offline Capability Matrix

| Feature | View Offline | Create Offline | Edit Offline | Sync Strategy |
|---|---|---|---|---|
| **Recipes** | ✅ Drift cache | ✅ Queued sync | ✅ Queued sync | Auto-sync on reconnect |
| **User Ingredients** | ✅ Drift cache | ⚠️ Unknown | ⚠️ Unknown | Unknown |
| **Menus** | ⚠️ Firestore cache only | ❌ No | ❌ No | Server-only |
| **Shopping Lists** | ⚠️ Firestore cache only | ❌ No | ❌ No | Real-time only |
| **Personal Tags** | ⚠️ Firestore cache only | ❌ No | ❌ No | Server-only |
| **Social Features** | ❌ No | ❌ No | ❌ No | Requires connection |
| **Messaging** | ❌ No | ❌ No | ❌ No | Requires connection |
| **Comments/Ratings** | ❌ No | ❌ No | ❌ No | Requires connection |

### Issues Found

#### HIGH

1. **No conflict resolution for shared data** — shopping lists, collaborative recipes
   - Impact: Two users editing the same shopping list offline → Firestore last-write-wins → one user's changes silently lost.
   - Current: No merge strategy, no detection, no notification.
   - Best Practice: Field-level merge for shopping lists (use `FieldValue.arrayUnion/arrayRemove`). Conflict detection UI for recipes.
   - Scale Threshold: Any multi-user collaboration offline.
   - Effort: 2–4 days.

2. **No cache-first read patterns** — all Firestore reads default to server-first
   - Impact: Every screen open requires network round-trip even if cached data is available. Increases perceived latency.
   - Current: No `GetOptions(source: Source.cache)` usage anywhere. Relies on Firestore SDK's transparent caching.
   - Best Practice: Read from cache first, then refresh from server. Show stale data with refresh indicator.
   - Scale Threshold: Always (UX improvement).
   - Effort: 1–2 days.

3. **No pending writes indicator** — user doesn't know if data is synced
   - Impact: User may close app before offline writes sync. No visual indicator of pending changes.
   - Current: Firestore's `hasPendingWrites` not used in any snapshot handling.
   - Best Practice: Show sync indicator when `hasPendingWrites` is true.
   - Scale Threshold: Any offline usage.
   - Effort: 4 hours.

#### MEDIUM

4. **Menus and shopping lists have no explicit offline support**
   - Impact: Core daily-use features (meal planning, grocery shopping) fail offline.
   - Current: Only work via transparent Firestore cache (view recently accessed data).
   - Best Practice: Extend Drift offline storage to menus and shopping lists.
   - Scale Threshold: Users in low-connectivity areas.
   - Effort: 3–5 days.

5. **ConnectivityMonitoringService uses 30s polling** — `lib/services/connectivity_monitoring_service.dart`
   - Impact: Up to 30s delay detecting network state change.
   - Current: `Timer.periodic(30 seconds)` checks connectivity.
   - Best Practice: Use `connectivity_plus` stream for instant detection.
   - Scale Threshold: Not a scale issue but UX concern.
   - Effort: 2 hours.

### Quick Wins
- Add `hasPendingWrites` indicator to recipe/shopping list views (4 hours)
- Use `connectivity_plus` stream instead of polling (2 hours)

---

## Remediation Roadmap

### Phase 1: Immediate (CRITICAL + Quick Wins) — 2 days effort

| # | Action | File | Impact | Effort |
|---|---|---|---|---|
| 1 | Add `.limit(50)` to `subscribeToUserRecipes` | `firebase_recipe_repository.dart:596` | Prevents 10–100x cost escalation | 30 min |
| 2 | Add `.limit(50)` to friend/invitation streams | Various repositories | Prevents unbounded memory | 30 min |
| 3 | Add StreamManagementMixin to collaborative recipe flows | Collaborative recipe code | Prevents memory leaks | 2 hours |
| 4 | Convert 6 eager singletons to lazy | DI modules | Saves ~200–400ms startup | 4 hours |
| 5 | Configure `flutter_cache_manager` max size | Cache configuration | Prevents unbounded disk cache | 1 hour |
| 6 | Convert high-traffic ListViews to .builder | `friends_list_view.dart`, `conversations_list_view.dart` | Eliminates jank on long lists | 2 hours |

### Phase 2: Short-term (10x Readiness) — 1 week effort

| # | Action | Impact | Effort |
|---|---|---|---|
| 7 | Parallelize independent DI module initialization | Saves ~300–500ms startup | 2–3 days |
| 8 | Wire `deleteOldAuditLogs` to Cloud Function cron | Prevents unbounded storage | 2 hours |
| 9 | Add TTL policy for subcollection docs (views/engagements) | Prevents popular content storage bloat | 4 hours |
| 10 | Add `hasPendingWrites` sync indicator to UI | Users know when data is synced | 4 hours |
| 11 | Inject shared HTTP client into import pipelines | Connection pooling, fewer leaks | 1 hour |
| 12 | Add Cloud Function trigger for Storage cleanup on recipe delete | Prevents orphaned images | 4 hours |

### Phase 3: Medium-term (100x Readiness) — 2–3 weeks effort

| # | Action | Impact | Effort |
|---|---|---|---|
| 13 | Implement cache-first read patterns for menus/lists | Faster perceived load, better offline | 2 days |
| 14 | Implement conflict resolution for shopping lists | Prevents silent data loss | 2–4 days |
| 15 | Denormalize rating/comment counts to recipe doc | Eliminates expensive aggregation queries | 1 day |
| 16 | Extend Drift offline support to menus and shopping lists | Core features work offline | 3–5 days |
| 17 | Build batch data migration framework | Required before any schema change at scale | 2–3 days |

### Phase 4: Long-term (1000x Readiness) — Decision Points

| # | Decision | When to Decide | Options |
|---|---|---|---|
| 18 | Algolia integration for recipe search | >200 recipes/user common | Algolia vs Typesense vs Firestore full-text |
| 19 | Replace `flutter_inappwebview` with server-side extraction | If bundle size > 50MB | Cloud Function extraction vs lighter WebView |
| 20 | CDN caching for popular shared recipes | >1K concurrent recipe viewers | Firebase Hosting CDN vs custom cache layer |
| 21 | Evaluate hybrid backend | >100K users & costs > $1K/month | Firebase + Supabase/custom API vs full Firebase |
| 22 | Implement offline-first architecture | Product decision | Full CRDT vs Firestore offline vs custom sync |

---

## Reusable Patterns (Positive Findings)

| Pattern | Adoption | Assessment |
|---|---|---|
| `StreamManagementMixin` | 20+ classes | ✅ Excellent — centralized stream lifecycle |
| `BaseViewModel._isDisposed` | All ViewModels | ✅ Excellent — prevents double-disposal crashes |
| `BaseFirebaseRepository` | All repositories | ✅ Excellent — standardized CRUD + audit |
| `FirebaseServiceMixin` | All Firebase services | ✅ Excellent — retry, DNS resilience, error handling |
| `SerializationUtils` | 100% model adoption | ✅ Excellent — null-safe Firestore parsing |
| Deferred imports | 16 screens | ✅ Good — effective code splitting |
| Subcollection sharing (Issue #014) | Recipes, menus | ✅ Good — scalable membership model |
| `FirebasePerformanceService.traceOperation` | CRUD operations | ✅ Good — production monitoring |

---

## Phase 1 Completion Checklist

- [x] All 7 dimensions scored
- [x] Startup sequence traced with blocking ops (serial module init chain mapped)
- [x] Widget build performance audited (20 non-.builder ListViews, 36 eager singletons)
- [x] Memory leak risks documented with file:line (dual cache, 3 static controllers, HTTP clients)
- [x] All Firestore collections mapped (28 collections/subcollections)
- [x] 34 indexes cross-referenced (all appear actively used)
- [x] Real-time listeners inventoried (30+ listeners with lifecycle assessment)
- [x] Cost projections at 4 scales ($0.05 → $443/month linear scaling)
- [x] Scalability bottlenecks identified (7 bottlenecks with scale thresholds)
- [x] Offline functionality mapped (recipes ✅, menus/shopping/social ❌)
- [x] Bundle size breakdown complete (35–45MB estimated)
- [x] All issues classified by severity (1 CRITICAL, 5 HIGH, 8 MEDIUM, 6 LOW)
- [x] Zero code changes made
- [x] Phase 2 roadmap prepared (4 phases: Immediate → Long-term)
