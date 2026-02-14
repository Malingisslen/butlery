# BUTLERY PERFORMANCE & SCALABILITY ANALYSIS -- PHASE 1

```
Analysis Date:    2026-02-10
Analyst:          Claude (Opus 4.6)
Firebase Project: butlery-app-1
Platforms:        Android, iOS, Web, macOS, Windows
flutter analyze:  No issues found!
```

## OVERALL SCORE: 71/100

```
  1. App Startup & Frame Rate:         12/18
  2. Memory & Resource Management:     11/15
  3. Firebase Query & Schema Design:   13/18
  4. Real-time Listeners & Streams:     9/12
  5. Scalability Projections:          10/15
  6. Bundle Size & Network Efficiency:  9/12
  7. Offline Performance & Sync:        7/10

STATUS: Good (with targeted optimization opportunities)

CRITICAL ISSUES: 2 found
HIGH PRIORITY:   6 found
MEDIUM PRIORITY: 9 found
LOW PRIORITY:    5 found
```

---

## Performance Benchmarks Table

| Metric | Current (est.) | Target | Gap | Status |
|---|---|---|---|---|
| Cold start time | ~3.0-4.0s | < 2.0s | +1.0-2.0s | NEEDS WORK |
| Warm start time | ~1.0-1.5s | < 1.0s | +0.0-0.5s | ACCEPTABLE |
| Average FPS | ~55-60fps | 60fps | -0-5fps | GOOD |
| Jank percentage | ~2-3% | < 1% | +1-2% | ACCEPTABLE |
| Memory usage (typical) | ~120-180MB | < 150MB | ~+30MB | ACCEPTABLE |
| Memory usage (peak) | ~200-280MB | < 250MB | ~+30MB | NEEDS WORK |
| Bundle size (Android) | ~40-55MB | < 50MB | ~+5MB | BORDERLINE |
| Firestore queries/screen | 3-8 | < 5 | +0-3 | ACCEPTABLE |
| Data transfer/hour | ~3-8MB | < 5MB | +0-3MB | ACCEPTABLE |
| Offline features | ~80% | 100% | -20% | NEEDS WORK |

---

## Firestore Collection Structure Map

### User-Scoped Collections

| Collection Path | Key Fields | Avg Doc Size | Queries | Index Status | Issues |
|---|---|---|---|---|---|
| `users/{userId}/recipes` | core.*, ingredients[], instructions[], tagResult.*, personalTagIds[] | ~5-15KB | watchRecipes (limit 50), readAll (limit 100), searchRecipes (limit 200), fetchAllUserRecipes (cursor-based) | 10 composite indexes on userId+various | GOOD: All queries have limits |
| `users/{userId}/menus` | days{}, recipes[], name | ~2-5KB | CRUD operations | Single-field | OK |
| `users/{userId}/shopping_lists` | items[], name, collaborators[] | ~1-5KB | Query + watch (limit 20) | 1 composite index | OK |
| `users/{userId}/personal_tags` | name, rules[], createdAt | ~0.5-2KB | watchAll, getByIds | Single-field | OK |
| `users/{userId}/notifications` | type, isRead, userId | ~0.5-1KB | Watch (limit 50) | 1 composite index | OK |

### Global Collections

| Collection Path | Key Fields | Avg Doc Size | Queries | Index Status | Issues |
|---|---|---|---|---|---|
| `shared_recipes` | sharedWith[], sharedWithUserIds[], sharedAt | ~5-15KB | array-contains + orderBy | 2 composite indexes | **MEDIUM**: sharedWith array may grow |
| `shared_menus` / `sharedMenus` | sharedWith[], sharedWithUserIds[] | ~3-8KB | array-contains + orderBy | 2 composite indexes | **LOW**: Duplicate collection naming |
| `shared_shopping_lists` / `sharedShoppingLists` | collaborators[], sharedWithUserIds[] | ~2-5KB | array-contains + orderBy | 2 composite indexes | **LOW**: Duplicate collection naming |
| `friend_requests` | fromUserId, toUserId, status, sentAt | ~0.5-1KB | Compound queries (limit 50) | 2 composite indexes | GOOD |
| `groups` + `groups/{id}/members` | name, memberIds[], members subcollection | ~1-3KB | Subcollection queries | Collection group index on members.userId | GOOD |
| `recipe_comments` | recipeId, parentId, createdAt | ~0.5-2KB | Compound queries (limit 50) | 2 composite indexes | GOOD |
| `recipe_ratings` | recipeId, rating, createdAt | ~0.3-0.5KB | By recipeId (Cloud Function aggregation) | Single-field | GOOD |
| `conversations` | participantIds[], isGroup, updatedAt | ~1-2KB | array-contains + compound (limit 50) | 1 composite index | GOOD |
| `messages` | conversationId, sentAt | ~0.5-2KB | Compound queries (limit 20) | 1 composite index | GOOD |
| `audit_logs` | userId, resourceType, timestamp | ~0.5-1KB | 4 compound queries | 4 composite indexes | GOOD |
| `ingredients` | name, category, properties.* | ~1-3KB | **Unbounded collection snapshot listener** | Single-field | **CRITICAL**: No limit on listener |

### Index Summary
- **34 composite indexes** defined in `firestore.indexes.json`
- **2 field overrides** (friendCategories.friendUserIds, members.userId collection group)
- All major query patterns appear to have matching indexes
- No obvious missing indexes detected (queries with compound where + orderBy are covered)

---

## Cost Analysis

| Scale | Active Users | Est. Reads/Day | Est. Writes/Day | Est. Monthly Cost | Per User/Month |
|---|---|---|---|---|---|
| Current | ~50 | ~15,000 | ~2,000 | ~$5-10 | ~$0.10-0.20 |
| 10x | ~500 | ~150,000 | ~20,000 | ~$40-80 | ~$0.08-0.16 |
| 100x | ~5,000 | ~1,500,000 | ~200,000 | ~$350-700 | ~$0.07-0.14 |
| 1000x | ~50,000 | ~15,000,000 | ~2,000,000 | ~$3,000-6,000 | ~$0.06-0.12 |

**Cost Notes:**
- Per-user cost trends sub-linearly due to shared content caching
- Ingredient collection listener is the single biggest cost driver at scale (every user triggers full collection read on changes)
- Cloud Functions LLM calls (structureRecipe, ocrRecipeImage) are the wildcard -- Mistral AI API costs scale linearly with import volume
- Rating aggregation Cloud Functions are efficient (trigger-based, not polling)

---

## Scalability Limits Table

| Bottleneck | Hits at | Impact | Mitigation Effort |
|---|---|---|---|
| Ingredient collection unbounded listener | ~100 users | Every ingredient change triggers full collection download for ALL connected users | 3-5 days |
| CACHE_SIZE_UNLIMITED Firestore cache | ~1000 recipes/user | Device storage exhaustion on low-end devices | 1-2 days |
| sharedWith[] array growth | ~500 shares/recipe | Approaching Firestore 1MB doc limit; array-contains queries degrade | 5-8 days |
| Client-side recipe search (200 doc reads) | ~500 recipes/user | Slow search, high read costs | 3-5 days (Algolia integration exists) |
| 527 notifyListeners() calls across 108 files | Now | Excessive widget rebuilds, potential jank | 5-10 days |
| 9 DI modules initialized sequentially | Now | Startup latency ~3-4s | 3-5 days |
| 50+ concurrent Firestore listeners per user | ~1000 users | Firebase connection limit (100K/project) | 5-8 days |
| updateRecipeRatingStats reads ALL ratings | ~1000 ratings/recipe | Cloud Function timeout at high rating counts | 2-3 days |

---

## Detailed Findings by Dimension

---

## 1. APP STARTUP & FRAME RATE -- Score: 12/18

### Summary
Startup involves sequential initialization of 9 DI modules, 5 bootstrap stages, Firebase SDK initialization, SharedPreferences, OfflineService database, and UnifiedRecipeService cache loading. Estimated cold start is 3-4 seconds on mid-range devices. Frame rate is generally good thanks to ListView.builder adoption (64 uses) and deferred imports for social/messaging/extraction routes.

### Issues Found

#### CRITICAL

1. **Sequential DI module initialization blocks first frame** -- `lib/main.dart:162-195`, `lib/core/bootstrap/application_bootstrap.dart:362-371`
   - Impact: 9 modules initialized sequentially before `runApp()` is called. Each module's `configure()` + `initialize()` runs in series. ContentModule alone initializes OfflineService, UnifiedRecipeService, UnifiedMenuService, and RecipeParserService sequentially.
   - Current: `_initializeModularSystem()` is `await`ed before `runApp(const ButleryApp())` at `lib/main.dart:132,151`.
   - Best Practice: Show splash screen immediately, initialize critical services (auth, persistence) first, defer non-critical modules (Social, Messaging, Collaboration, Performance, UI) to post-first-frame.
   - Scale Threshold: Affects all users from day 1
   - Effort: 3-5 days

#### HIGH

2. **CoreStage has unnecessary 100ms delay** -- `lib/core/bootstrap/stages/core_stage.dart:61`
   - Impact: `await Future.delayed(const Duration(milliseconds: 100))` adds 100ms to every startup
   - Current: Comment says "Basic validation that we can proceed" but does nothing useful
   - Best Practice: Remove the delay; validation should be synchronous checks
   - Effort: 0.5 hours

3. **UIStage has unnecessary 150ms of delays** -- `lib/core/bootstrap/stages/ui_stage.dart:42-48`
   - Impact: Two `Future.delayed` calls (100ms + 50ms) with comments like "would happen here"
   - Current: Placeholder delays that serve no purpose
   - Best Practice: Remove delays or replace with actual initialization logic
   - Effort: 0.5 hours

4. **ContentModule initializes 4 services sequentially in initialize()** -- `lib/core/di/modules/content_module.dart:374-392`
   - Impact: OfflineService.initialize(), UnifiedRecipeService.initialize(), UnifiedMenuService.initialize(), RecipeParserService.init() all run sequentially
   - Current: Some of these could run in parallel (e.g., RecipeParserService and UnifiedMenuService are independent)
   - Best Practice: Use `Future.wait()` for independent initializations
   - Effort: 1 day

#### MEDIUM

5. **ListView without .builder in 15+ views** -- Multiple files
   - Impact: All items rendered eagerly even when off-screen. Examples:
     - `lib/widgets/menu/menu_content_widgets.dart:148` -- `ListView(`
     - `lib/views/tag_detail_view.dart:226,306,939` -- Three `ListView(` instances
     - `lib/views/edit_recipe_view.dart:134` -- `ListView(`
     - `lib/views/personal_tags_view.dart:206` -- `ListView(`
     - `lib/views/skriv_sjalv_recept_view.dart:331` -- `ListView(`
     - `lib/widgets/common/navigation/adaptive_navigation.dart:330` -- `ListView(`
   - Current: Some are acceptable (fixed small lists), but tag detail view and recipe edit could have many items
   - Best Practice: Use `ListView.builder` for any list that could exceed ~20 items
   - Effort: 2-3 days

6. **527 notifyListeners() calls across 108 files may cause excessive rebuilds**
   - Impact: Broad notifications trigger full subtree rebuilds. Particularly concerning in ViewModels like `recipe_form_state.dart` (22 calls), `friends_state_manager.dart` (29 calls), `recipe_image_manager.dart` (15 calls)
   - Current: Every state change triggers full listener notification
   - Best Practice: Consider more granular state notification (ValueNotifier per field) or selector-based patterns
   - Effort: 5-10 days (architectural change)

### Quick Wins
- Remove CoreStage 100ms delay (`core_stage.dart:61`) -- saves 100ms startup, 0.5 hours effort
- Remove UIStage 150ms delays (`ui_stage.dart:42-48`) -- saves 150ms startup, 0.5 hours effort
- Total quick win: ~250ms faster startup for 1 hour of work

---

## 2. MEMORY & RESOURCE MANAGEMENT -- Score: 11/15

### Summary
Strong StreamManagementMixin adoption (28 classes) with proper disposal patterns. IntelligentCacheManager has a 50MB memory cap with intelligent eviction. Memory pressure handling is implemented. However, several ViewModels using StreamManagementMixin don't call `disposeStreamResources()`, and CACHE_SIZE_UNLIMITED for Firestore is risky.

### Issues Found

#### HIGH

1. **MenuStateManager has StreamManagementMixin but no dispose method** -- `lib/viewmodels/menu/menu_state_manager.dart:14`
   - Impact: Memory leak -- stream subscriptions and timers managed by the mixin are never cleaned up
   - Current: `class MenuStateManager extends ChangeNotifier with StreamManagementMixin` but no `dispose()` override found
   - Best Practice: Override dispose() and call `disposeStreamResources()`
   - Effort: 0.5 hours

2. **Firestore CACHE_SIZE_UNLIMITED may exhaust device storage** -- `lib/services/unified/unified_recipe_service.dart:437`
   - Impact: `cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED` means the Firestore SDK will cache unlimited data locally. For users with hundreds of recipes, shared content, and social data, this could consume gigabytes of device storage.
   - Current: Both `unified_recipe_service.dart:437` and `firebase_service_mixin.dart:671` default to CACHE_SIZE_UNLIMITED
   - Best Practice: Set explicit cache size (e.g., 100MB) with LRU eviction. Firebase default is 40MB for good reason.
   - Scale Threshold: Becomes problematic at ~500+ recipes per user
   - Effort: 1-2 days

3. **ChatViewModel.dispose() does not call disposeStreamResources()** -- `lib/viewmodels/chat_viewmodel.dart:461`
   - Impact: ChatViewModel uses StreamManagementMixin but its dispose() method does not call `disposeStreamResources()`, potentially leaking chat stream subscriptions
   - Current: Has `dispose()` at line 461 but grep shows no `disposeStreamResources` call in that file
   - Best Practice: Add `await disposeStreamResources()` to dispose()
   - Effort: 0.5 hours

#### MEDIUM

4. **IntelligentCacheManager.dispose() not called on app termination** -- `lib/services/performance/intelligent_cache_manager.dart:560-566`
   - Impact: Two periodic timers (_prefetchTimer every 5min, _behaviorSaveTimer every 10min) may not be properly cleaned up. `onAppPaused()` is called from main.dart but full `dispose()` is never called.
   - Current: `_ButleryAppState.dispose()` does not dispose IntelligentCacheManager
   - Best Practice: Call `cacheManager.dispose()` in app-level dispose
   - Effort: 0.5 hours

5. **86 Timer usages across 33 files need audit** -- Various files
   - Impact: Timers not managed through StreamManagementMixin could leak
   - Current: `lib/services/performance/performance_monitoring_service.dart` has 9 timer usages, `lib/services/notifications/modules/notification_offline_manager.dart` has 7, `lib/services/notifications/modules/notification_batch_manager.dart` has 6
   - Best Practice: Ensure all timers are registered with StreamManagementMixin or properly cancelled
   - Effort: 2-3 days for audit + fixes

6. **Image cache cleared on memory pressure but no size limit configured** -- `lib/main.dart:441-443`
   - Impact: Flutter's default image cache has no explicit size limit configured. `PaintingBinding.instance.imageCache.clear()` is called on memory pressure, which is good, but proactive size limiting would prevent the pressure in the first place.
   - Current: 19 CachedNetworkImage/Image.network usages across 17 files
   - Best Practice: Set `PaintingBinding.instance.imageCache.maximumSize = 100` and `maximumSizeBytes = 50 * 1024 * 1024`
   - Effort: 0.5 hours

### Quick Wins
- Add `disposeStreamResources()` to MenuStateManager -- prevents memory leak, 0.5 hours
- Set explicit imageCache size limits in main.dart -- prevents memory bloat, 0.5 hours
- Add `disposeStreamResources()` to ChatViewModel -- prevents stream leak, 0.5 hours

---

## 3. FIREBASE QUERY & SCHEMA DESIGN -- Score: 13/18

### Summary
Query patterns are generally well-designed with limits on most queries. 34 composite indexes cover all major compound query patterns. Cursor-based pagination exists for `fetchAllUserRecipes`. The main concerns are the unbounded ingredient collection listener and client-side search that fetches 200 documents.

### Issues Found

#### CRITICAL

1. **Ingredient collection listener has no limit** -- `lib/repositories/firebase/firebase_ingredient_repository.dart:85`
   - Impact: `_subscription = _collection.snapshots().listen(...)` listens to the ENTIRE ingredients collection without any `.limit()` or `.where()` clause. Every ingredient change triggers a full collection download for every connected client. With 500+ ingredients and 100+ concurrent users, this creates enormous read costs and bandwidth usage.
   - Current: `_collection.snapshots()` at line 85 (initialize), `_collection.snapshots().map(...)` at line 533 (watchAll)
   - Best Practice: Use a server-side trigger to invalidate a version counter. Clients check version, only re-fetch if changed. Or use timestamp-based incremental sync.
   - Scale Threshold: Becomes expensive at ~50+ concurrent users
   - Effort: 3-5 days

#### HIGH

2. **Client-side recipe search reads up to 200 documents** -- `lib/repositories/firebase/firebase_recipe_repository.dart:376`
   - Impact: `searchRecipes()` fetches 200 documents and filters client-side with `toLowerCase().contains()`. Each search costs 200 reads regardless of result count.
   - Current: Algolia integration exists (`lib/repositories/algolia/algolia_search_repository.dart`) but client-side fallback is the default
   - Best Practice: Enable Algolia search as primary, use Firestore only as fallback
   - Effort: 2-3 days (integration already exists)

3. **Duplicate collection naming (shared_menus vs sharedMenus, etc.)** -- `firestore.indexes.json:125-178`
   - Impact: Both `shared_menus` and `sharedMenus` have indexes. Same for `shared_shopping_lists` and `sharedShoppingLists`. This suggests a migration was incomplete or both formats are used, doubling index storage costs and potentially causing data fragmentation.
   - Current: 4 indexes across duplicate collection names
   - Best Practice: Consolidate to single naming convention, migrate data, remove stale indexes
   - Effort: 2-3 days

#### MEDIUM

4. **N+1 pattern in personal tag fetching** -- `lib/repositories/firebase/firebase_personal_tag_repository.dart:122`
   - Impact: `tagIds.map((id) => ref.doc(id).get())` fetches each tag individually in a loop wrapped in `Future.wait()`. While parallelized, each is a separate Firestore read.
   - Current: Good that it uses `Future.wait()` for parallelism, but `whereIn` would be more efficient for up to 30 IDs
   - Best Practice: Use `.where(FieldPath.documentId, whereIn: tagIds)` for batches of 10
   - Effort: 1-2 days

5. **Rating aggregation Cloud Function queries ALL ratings without limit** -- `functions/src/index.ts:82-85`
   - Impact: `db.collection("recipe_ratings").where("recipeId", "==", recipeId).get()` fetches all ratings for a recipe. For popular shared recipes with thousands of ratings, this could exceed Cloud Function timeout (default 60s).
   - Current: No limit on query, processes all ratings in memory
   - Best Practice: Maintain running counters with increment/decrement instead of full recalculation. Or limit to most recent 500 ratings with warning.
   - Scale Threshold: Becomes problematic at ~1000+ ratings per recipe
   - Effort: 2-3 days

6. **base_shared_content_repository uses limit * 2 for client-side filtering** -- `lib/repositories/firebase/base_shared_content_repository.dart:622`
   - Impact: Fetches 2x the requested limit from Firestore, then filters client-side. This is a known pattern to handle dismissed content but doubles read costs.
   - Best Practice: Server-side filtering where possible, or accept slightly less accurate pagination
   - Effort: 2-3 days

### Quick Wins
- Use `whereIn` for personal tag batch fetching -- reduces reads, 1 day
- Audit and remove duplicate collection indexes -- reduces index storage, 1 day

---

## 4. REAL-TIME LISTENERS & STREAMS -- Score: 9/12

### Summary
~55 `.snapshots()` calls across the codebase create real-time listeners. StreamManagementMixin is adopted by 28 classes (services + viewmodels + repositories), providing proper lifecycle management. Most listeners have appropriate limits. The main concern is the ingredient collection listener and the total concurrent listener count per user session.

### Issues Found

#### HIGH

1. **Estimated 15-25 concurrent listeners per active user session** -- Various files
   - Impact: Typical user session activates listeners for: recipes (1), menus (1), shopping lists (1-3), notifications (1), friend requests (2), presence (1-2), conversations (1), ingredients (1), personal tags (1-2), connectivity (1), plus any social content views (2-5). Total: ~15-25 per user.
   - Current: At 50,000 users = ~750K-1.25M concurrent listeners against Firebase limit of 100K per project (but this is concurrent connections, not listeners)
   - Best Practice: Lazy-activate listeners only when views are visible. Deactivate on navigation away.
   - Scale Threshold: ~5,000 concurrent users may approach Firebase connection limits
   - Effort: 5-8 days

2. **Permission cache invalidator opens 3 listeners simultaneously** -- `lib/services/cache/permission_cache_invalidator.dart:63-89`
   - Impact: Opens real-time listeners on shared_recipes, shared_menus, and shared_shopping_lists simultaneously for cache invalidation. These persist for the entire session.
   - Current: 3 always-on listeners per authenticated user
   - Best Practice: Use a single aggregated listener or polling-based invalidation
   - Effort: 2-3 days

#### MEDIUM

3. **13 ViewModels with StreamManagementMixin correctly call disposeStreamResources(), but 2 do not**
   - Impact: MenuStateManager and ChatViewModel may leak subscriptions (detailed in Dimension 2)
   - Current: 13 of 15 ViewModels using the mixin properly dispose
   - Best Practice: 100% compliance
   - Effort: 1 hour

4. **21 service files use .listen() directly** -- Various service files
   - Impact: Services like `firebase_sync_manager.dart` (14 StreamSubscription references), `realtime_session_manager.dart` (15 references) have complex stream management. Some use StreamManagementMixin, but manual `.listen()` calls in files not using the mixin need auditing.
   - Best Practice: Adopt StreamManagementMixin in all services with active listeners
   - Effort: 3-5 days

### Real-time Listener Inventory

| Listener Category | Count | Scope | Limit | Lifecycle |
|---|---|---|---|---|
| Recipe collection | 2 | User-scoped | 50/100 | Auth session |
| Menu operations | 1-2 | Document | N/A | View lifetime |
| Shopping lists | 2-3 | User-scoped | 20 | Auth session |
| Notifications | 1 | User-scoped | 50 | Auth session |
| Friend requests | 2 | User-filtered | 50 | Auth session |
| Ingredients | 1 | **Global unbounded** | **NONE** | App lifetime |
| Conversations | 1 | User-filtered | 50 | Auth session |
| Comments | 1 | Document-scoped | 50 | View lifetime |
| Presence | 1-2 | Document | N/A | View lifetime |
| Connectivity | 1 | Global | 1 | App lifetime |
| Social sharing | 2-3 | User-filtered | 50 | View lifetime |
| Permission cache | 3 | User-filtered | N/A | Auth session |
| Personal tags | 1-2 | User-scoped | N/A | Auth session |

**Total per user: ~15-25 concurrent listeners**

---

## 5. SCALABILITY PROJECTIONS -- Score: 10/15

### Summary
Architecture is fundamentally sound with user-scoped collections, denormalized data (via Cloud Functions), and cursor-based pagination. Firebase is viable to 10,000+ users. Key bottlenecks are the global ingredient listener, client-side search, and connection limits at scale.

### Issues Found

#### HIGH

1. **Global ingredient listener scales linearly with user count** -- `firebase_ingredient_repository.dart:85`
   - Impact: N users * full collection reads on every ingredient change = O(N * M) reads where M = ingredient count. At 1000 users with 500 ingredients, a single ingredient update triggers 500,000 reads.
   - Scale Threshold: Breaks at ~100 concurrent users
   - Mitigation: Version-counter invalidation pattern or server-push of only changed ingredients
   - Effort: 3-5 days

2. **Cloud Functions without maxInstances configuration** -- `functions/src/llm/structure-recipe.ts:61-62`, `functions/src/llm/ocr-recipe-image.ts:61-62`
   - Impact: LLM functions have memory (512MiB/1GiB) and timeout (60s/120s) configured but no `maxInstances` limit. A spike in import requests could trigger hundreds of concurrent Cloud Function instances, each calling Mistral AI API, leading to API rate limiting and cost spikes.
   - Current: `memory: "512MiB"/"1GiB"`, `timeoutSeconds: 60/120`, no maxInstances
   - Best Practice: Set `maxInstances: 10-20` for LLM functions, implement client-side queuing
   - Effort: 1 day

3. **sharedWith/sharedWithUserIds arrays in shared content documents** -- Various shared_* collections
   - Impact: Array fields used for `array-contains` queries. These grow as content is shared with more users. At ~500 entries, documents approach performance degradation. At ~20,000 entries, they hit the Firestore array element limit.
   - Current: No server-side limit on array growth
   - Best Practice: Switch to subcollection-based membership model (already partially implemented in groups). Limit array size to 100.
   - Scale Threshold: Breaks at ~500 shares per document
   - Effort: 5-8 days

#### MEDIUM

4. **No horizontal read distribution strategy**
   - Impact: All reads go to same Firestore database. No read replicas or CDN for static content.
   - Current: Single Firestore instance for everything
   - Best Practice: Consider Firebase Hosting CDN for static assets, Firestore Data Connect for read scaling at 10K+ users
   - Scale Threshold: 10K+ daily active users
   - Effort: Decision point, not implementation

5. **Firebase connection limit of 100K concurrent per project**
   - Impact: With 15-25 listeners per user, ~4,000-6,700 concurrent users saturate the connection pool
   - Current: Not an issue at current scale
   - Best Practice: Implement listener pooling, lazy activation, and connection monitoring
   - Scale Threshold: ~4,000 concurrent users
   - Effort: 5-8 days

---

## 6. BUNDLE SIZE & NETWORK EFFICIENCY -- Score: 9/12

### Summary
Good use of deferred imports (17 deferred modules for social, messaging, and extraction routes). Asset footprint is moderate (~2MB total). Image compression before upload is implemented with multi-pass quality reduction. However, PNG illustrations could be converted to WebP and some heavy dependencies (flutter_inappwebview, drift+sqlcipher) inflate the bundle.

### Issues Found

#### HIGH

1. **Illustration assets are unoptimized PNGs** -- `assets/illustrations/`
   - Impact: 12 PNG files totaling ~1.3MB. PNGs like `broccoli.png` (244KB), `champinjon.PNG` (156KB), `rodlok.PNG` (157KB) could be 50-70% smaller as WebP.
   - Current: All illustrations are PNG format
   - Best Practice: Convert to WebP for ~60% size reduction. Consider vector (SVG) for simple illustrations.
   - Effort: 0.5 days

2. **6 custom font files totaling ~736KB** -- `assets/fonts/`
   - Impact: JosefinSans (3 weights, 231KB) + SpaceGrotesk (4 weights, 504KB). Seven font files is generous for a recipe app.
   - Current: Both font families loaded at startup
   - Best Practice: Consider reducing to 2-3 font weights. Use variable fonts if available to reduce file count.
   - Effort: 0.5 days

#### MEDIUM

3. **Heavy native dependencies inflate APK** -- `pubspec.yaml`
   - Impact: `flutter_inappwebview` (web scraping), `drift` + `sqlcipher_flutter_libs` (encrypted local DB), and the Firebase suite collectively add 15-25MB to native library size.
   - Current: `sqlcipher_flutter_libs` may be unused (flagged in Dependencies report 05)
   - Best Practice: Remove unused dependencies, consider lighter alternatives for web scraping
   - Effort: 2-5 days (requires testing)

4. **No cache-first pattern for Firestore reads (Source.cache only used in 1 location)** -- `lib/services/tagging/tag_config_service.dart:273-277`
   - Impact: Only tag config forces `Source.server`. No explicit `Source.cache` usage for read operations. Firestore SDK handles caching automatically but explicit cache-first patterns could reduce network usage.
   - Current: Relies on Firestore SDK automatic caching behavior
   - Best Practice: Use `GetOptions(source: Source.cache)` for frequently accessed, rarely changing data (ingredients, tag configs), with periodic background refresh.
   - Effort: 2-3 days

5. **Firebase Performance traces only in 3 files (16 total usages)** -- `lib/repositories/firebase/firebase_recipe_repository.dart`, `lib/repositories/firebase/firebase_storage_repository.dart`, `lib/services/performance/firebase_performance_service.dart`
   - Impact: Limited visibility into actual performance characteristics. Critical user journeys (startup, list loading, search, navigation) are mostly uninstrumented.
   - Current: `traceSearch` and `traceOperation` cover recipe reads and storage, but not menu, shopping, social operations
   - Best Practice: Add performance traces to all critical user journeys
   - Effort: 2-3 days

### Asset Size Summary

| Category | Size | Notes |
|---|---|---|
| Illustrations | ~1.3MB | 12 PNG files, unoptimized |
| Fonts | ~736KB | 7 TTF files, 2 families |
| Legal docs | ~20KB | Privacy policy (sv, en) |
| **Total assets** | **~2.1MB** | Below target but optimizable |
| Flutter InAppWebView assets | ~50KB | T-Rex runner game, CSS |
| CupertinoIcons font | ~290KB | Standard Flutter asset |

---

## 7. OFFLINE PERFORMANCE & SYNC -- Score: 7/10

### Summary
Firestore offline persistence is explicitly enabled with `CACHE_SIZE_UNLIMITED`. The app has a dedicated OfflineService with Drift-based local database for structured caching. Basic offline viewing of cached recipes and menus works. However, there is no user-visible offline indicator, no explicit pending writes tracking, and conflict resolution for collaborative editing is complex.

### Issues Found

#### HIGH

1. **No offline indicator shown to users** -- Missing feature
   - Impact: Users have no visual feedback when they are offline. Operations may silently queue to Firestore's pending writes queue without user awareness.
   - Current: `ConnectivityMonitoringService` exists (`lib/services/connectivity_monitoring_service.dart`) but no UI widget displays offline status
   - Best Practice: Show a persistent banner or snackbar when offline, indicate pending changes count
   - Effort: 1-2 days

2. **No pending writes indicator** -- Missing feature
   - Impact: Users cannot tell if their changes have been synced to the server. In collaborative scenarios (shared shopping lists, collaborative recipes), this creates data loss anxiety.
   - Current: Firestore SDK handles pending writes automatically, but UI gives no feedback
   - Best Practice: Display "Syncing..." or "X changes pending" indicator
   - Effort: 1-2 days

#### MEDIUM

3. **CACHE_SIZE_UNLIMITED risk on low-end devices** -- `lib/services/unified/unified_recipe_service.dart:437`
   - Impact: Firestore cache grows without bound. On devices with limited storage (16-32GB Android phones), this could fill the device.
   - Current: `Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED)`
   - Best Practice: Set to 100-200MB explicit limit
   - Effort: 0.5 hours

4. **Collaborative shopping list offline conflict resolution** -- Conceptual
   - Impact: Two collaborators editing the same shopping list offline will both generate pending writes. Firestore uses last-write-wins by default, which could lose items.
   - Current: No explicit conflict resolution strategy documented
   - Best Practice: Use Firestore transactions for item additions, or implement operational transform for collaborative lists
   - Effort: 3-5 days

### Offline Functionality Matrix

| Feature | Works Offline? | Notes |
|---|---|---|
| View cached recipes | Yes | Cached via UnifiedRecipeService + Drift |
| View menus | Yes | Cached via Firestore persistence |
| View shopping lists | Yes | Cached via Firestore persistence |
| Create/edit recipes | Partially | Writes queue, but no feedback shown |
| Add to shopping list | Partially | Writes queue, but no pending indicator |
| Import recipes (URL/photo) | No | Requires network for Cloud Functions |
| Social features (share, comment) | No | Requires network |
| Search recipes | Partially | Client-side search works on cached data |
| View friend activity | No | Requires network |
| Collaborative editing | Partially | Last-write-wins, no conflict UI |

---

## Remediation Roadmap

### Immediate (CRITICAL items + quick wins) -- 2-3 days effort

| # | Item | Effort | Impact |
|---|---|---|---|
| 1 | Remove CoreStage 100ms delay (`core_stage.dart:61`) | 0.5h | -100ms startup |
| 2 | Remove UIStage 150ms delays (`ui_stage.dart:42-48`) | 0.5h | -150ms startup |
| 3 | Add `disposeStreamResources()` to MenuStateManager | 0.5h | Fix memory leak |
| 4 | Add `disposeStreamResources()` to ChatViewModel | 0.5h | Fix stream leak |
| 5 | Set explicit Firestore cache size (100-200MB) | 0.5h | Prevent storage exhaustion |
| 6 | Set Flutter imageCache size limits | 0.5h | Prevent memory bloat |
| 7 | Set `maxInstances: 15` on LLM Cloud Functions | 0.5h | Prevent cost spikes |

### Short-term (HIGH items, 10x readiness) -- 10-15 days effort

| # | Item | Effort | Impact |
|---|---|---|---|
| 8 | Fix ingredient collection unbounded listener | 3-5 days | Eliminate biggest cost driver |
| 9 | Enable Algolia search as primary (integration exists) | 2-3 days | Reduce 200-doc reads per search |
| 10 | Add offline indicator UI | 1-2 days | User experience for offline scenarios |
| 11 | Add pending writes indicator | 1-2 days | User confidence in data sync |
| 12 | Convert PNG illustrations to WebP | 0.5 days | ~750KB bundle reduction |
| 13 | Parallelize ContentModule initialization | 1 day | -500ms+ startup time |
| 14 | Defer Social/Messaging/Performance/UI module initialization to post-first-frame | 3-5 days | Sub-2s cold start |

### Medium-term (MEDIUM items, 100x readiness) -- 15-20 days effort

| # | Item | Effort | Impact |
|---|---|---|---|
| 15 | Consolidate duplicate collection naming | 2-3 days | Clean schema, reduce index cost |
| 16 | Optimize N+1 tag fetching to whereIn batches | 1-2 days | Reduce Firestore reads |
| 17 | Audit 86 Timer usages for proper lifecycle | 2-3 days | Prevent timer leaks |
| 18 | Replace ListView with ListView.builder where needed | 2-3 days | Reduce frame drops |
| 19 | Add Firebase Performance traces to critical journeys | 2-3 days | Enable data-driven optimization |
| 20 | Implement cache-first patterns for stable data | 2-3 days | Reduce network usage |
| 21 | Optimize rating aggregation Cloud Function | 2-3 days | Prevent timeout at scale |

### Long-term (Architecture decisions, 1000x readiness) -- Decision points

| # | Decision | Trigger |
|---|---|---|
| 22 | Migrate sharedWith arrays to subcollection model | >100 shares per document |
| 23 | Implement listener pooling and lazy activation | >4,000 concurrent users |
| 24 | Consider Firestore Data Connect or read replicas | >10,000 daily active users |
| 25 | Address notifyListeners() granularity (consider Riverpod or selector patterns) | Measurable jank in profiling |
| 26 | Evaluate Firebase vs hybrid backend | Monthly cost exceeds $2,000 |

---

## Butlery-Specific Performance Verification

| Check | Status | Details |
|---|---|---|
| FirebaseServiceMixin adoption | GOOD | Used by UnifiedRecipeService and others. `executeFirebaseOperation()`, `executeFirebaseOperationWithRetry()`, `executeFirebaseOperationWithDNSResilience()` all present. 820 lines. |
| StreamManagementMixin adoption | GOOD | 28 classes: 8 services, 6 repositories, 14 viewmodels. Proper disposal in 26/28. |
| IntelligentCacheManager | GOOD | 50MB cap, intelligent eviction, behavior analysis, memory pressure handling, pause/resume lifecycle. |
| Firebase Performance Traces | PARTIAL | Only 16 trace usages across 3 files. Missing coverage for menu, shopping, social, navigation flows. |
| Image compression before upload | GOOD | `FirebaseStorageRepository` uses `FlutterImageCompress`. Multi-pass compression. Skips <500KB images. Thumbnail generation present. |
| Stream pagination limits | GOOD | Recipe stream limited to 50, shopping lists to 20, notifications to 50, conversations to 50, comments to 50. **Exception**: Ingredient collection has NO limit. |
| Cloud Functions config | PARTIAL | structureRecipe: 512MiB/60s, ocrRecipeImage: 1GiB/120s. Missing `maxInstances`. Rating aggregation has no query limit. |
| Multi-platform | GOOD | Platform-aware: Web gets NoOpAnalytics, Crashlytics disabled on web, App Check configured per platform. Deferred imports for route modules. |

---

## Phase 1 Completion Checklist

- [x] All 7 dimensions scored and documented
- [x] Startup sequence traced with blocking operations identified
- [x] Widget build performance audited (ListView, notifyListeners patterns)
- [x] Memory leak risks documented with file:line references
- [x] All Firestore collections mapped with fields, queries, and issues
- [x] Composite indexes cross-referenced (34 indexes vs actual query needs)
- [x] Real-time listeners inventoried with lifecycle and cost analysis
- [x] Cost projections calculated at 4 scale levels
- [x] Scalability bottlenecks identified with scale thresholds
- [x] Offline functionality mapped per feature
- [x] Bundle size breakdown complete
- [x] All issues classified by severity with effort estimates
- [x] Zero code changes made
- [x] Phase 2 roadmap structure prepared

**Phase 1 Output:** Complete. Ready for Phase 2 smart optimization planning.
