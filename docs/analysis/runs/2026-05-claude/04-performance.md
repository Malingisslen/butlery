# Performance & Scalability — Phase 1 Findings

```
Analyst:        Claude (Opus 4.7, 1M context)
Date:           2026-05-02
Run:            2026-05-claude
Scope:          Prompt 04 — Performance & Scalability (12% weight)
Method:         Static, read-only audit. No code changes, no profiling on device.
```

> **Phase 1 caveat — what this score is and isn't.** All numbers are
> static-analysis estimates. Cold start, FPS, memory, jank — none were
> measured on a device. Confidence is high on Firebase-side findings
> (repository code is unambiguous), medium on widget-rebuild claims
> (no profiler), and low on memory budgets (no DevTools snapshot). The
> intent is to surface where to instrument, not to declare ground truth.

---

## Executive Summary

```
OVERALL SCORE: 72 / 100   ("Acceptable — prioritized remediation within 2 sprints")

  1. App Startup & Frame Rate          : 13 / 18
  2. Memory & Resource Management      : 11 / 15
  3. Firebase Query & Schema Design    : 12 / 18
  4. Real-time Listeners & Streams     :  7 / 12   <-- weakest
  5. Scalability Projections           : 10 / 15
  6. Bundle Size & Network Efficiency  : 10 / 12
  7. Offline Performance & Sync        :  9 / 10

CRITICAL: 2 found
HIGH:     7 found
MEDIUM:   9 found
LOW:      6 found
```

**Top three risks (in order):**

1. **Auto-healer listener fan-out on conversations** — opens up to 50
   concurrent message listeners per logged-in user as a side-effect of
   loading the inbox (`conversation_query_module.dart:41` calling
   `startAutoHealer` per row). At 100K active users this is several
   million concurrent listeners against the 10K/project soft cap; hard
   ceiling is reached well before app store submission of beta features.
2. **`realtime_sync_service._cachedResources` grows without bound** —
   every recipe ever watched is cached in a process-lifetime map
   (`realtime_sync_service.dart:159`). No LRU, no expiration. On a
   long-running session this leaks proportional to recipes opened.
3. **`Image.network` instead of `CachedNetworkImage` in 7 places** — image
   cache configured to 50 MB / 300 entries (good), but raw `Image.network`
   bypasses both. Each scroll past `family_presence_bar`, `cook_snap_gallery`,
   `public_profile_view` re-decodes from network.

The codebase has clearly seen targeted perf work (BUT-470 image cache
sizing, BUT-430 denormalized rating stats, recipe pagination at 100/page,
chunked `whereIn` for cook snaps, `IntelligentCacheManager` with memory
pressure handling). The remaining issues are concentrated in real-time
sync — exactly the area where complexity grew fastest.

---

## Performance Benchmarks Table

| Metric                  | Static estimate     | Target    | Status |
|-------------------------|---------------------|-----------|--------|
| Cold start time         | ~2.5–3.5s (web), ~1.8–2.5s (mobile) | <2.0s | At risk |
| Warm start time         | ~0.6–0.9s          | <1.0s     | OK     |
| Time to first frame     | ~600–900ms (loading screen) | <500ms | At risk |
| Average FPS             | unknown            | 60fps     | Not measured |
| Jank percentage         | unknown            | <1%       | Not measured |
| Memory (typical)        | unknown            | <150MB    | Not measured |
| Image cache cap         | 50 MB / 300 entries | <50MB    | OK     |
| Firestore queries / screen | 3–8             | <5        | Mostly OK |
| Concurrent listeners / user | 5–55 (during chat) | <10 | At risk |
| Offline cache size      | 100 MB             | (config)  | OK     |

---

## Dimension 1 — App Startup & Frame Rate (13 / 18)

### Summary

Bootstrap is well-staged (5 stages, 10 DI modules, mostly lazy
singletons). Web cold start is heavier than mobile because of the
synchronous `_health/_` Firestore probe on every web load. Frame-rate
posture is decent — image cache sized correctly per knowledge file
2026-04-26, RepaintBoundary on the main child — but several views still
do per-build O(n) lookups into the recipe list.

### HIGH — Web cold start blocks on a Firestore round-trip every load
`lib/main.dart:181-203`

The web boot path calls `FirebaseFirestore.instance.collection('_health').doc('_').get().timeout(5s)` synchronously inside `runZonedGuarded`. Comment notes it's there to detect IndexedDB corruption in JS SDK 12.x. Performance cost: every web load pays 100–800ms on the critical path before `runApp` is called. The `permission-denied` error path is treated as "expected" and ignored; only `INTERNAL ASSERTION` triggers the recovery branch.

- **Impact**: TTI on web shifts +300–800ms (median) or +up-to-5000ms (timeout edge).
- **Fix sketch**: defer the probe to after first frame using `WidgetsBinding.instance.addPostFrameCallback`. Recovery on detected corruption can show a banner + reload after fixing.
- **Effort**: 0.5 day.

### MEDIUM — Bootstrap registers and validates 10+ DI modules even when most aren't user-facing
`lib/core/bootstrap/application_bootstrap.dart:330-372`

`_executeBootstrapStages` runs all stages serially with their full timeouts. `Messaging`, `Pantry`, `Tagging`, `Search` modules register lazy singletons (good — see `collaboration_module.dart:69`), but the stages themselves still execute. `_validateInitialization` (`:432-471`) runs a full DI health check when user scope exists. On warm start with cached auth, this delays first user-visible frame.

- **Impact**: ~50–150ms on the critical path, multiplied by stage count.
- **Effort**: 1 day to rework stage prioritization (only `PlatformStage` + `CoreStage` need to gate first frame).

### MEDIUM — `recipes.indexOf(recipe)` per item in list builder
`lib/views/mina_recept_view.dart:980`

```dart
itemBuilder: (context, recipe) => _buildRecipeCard(
    viewModel, recipe, allergenPrefs,
    index: recipes.indexOf(recipe)),
```

`indexOf` is O(n), so the list-grid path is O(n²) per build. With 100 recipes that's 10K linear scans per frame on rebuild. The grid path (line 965) correctly uses the loop index. Same O(n²) trap likely exists in other LayoutComponents.responsiveListGrid call sites.

- **Impact**: Measurable jank on grid → list switch with >50 recipes; otherwise minor.
- **Effort**: 30 min — pass index through `responsiveListGrid`'s itemBuilder signature.

### MEDIUM — Seasonal hero recomputes match list on every QueryViewModel rebuild
`lib/views/mina_recept_view.dart:604-622`

`_buildSeasonalHero` calls `_seasonalHeroService.matchUserRecipes(month, queryVm.personalRecipes)` inside the FutureBuilder builder. Future is cached, but the match call runs on every rebuild and walks all recipes.

- **Impact**: O(n×ingredient_count) per filter change.
- **Effort**: 30 min — memoize on `(month, recipes.length, recipes.first?.id)` key.

### LOW — `MaterialApp.builder` re-creates Stack + RepaintBoundary + FeedbackFAB every rebuild
`lib/main.dart:907-937`

The shell wrap is fine (RepaintBoundary on `child`), but FeedbackFAB is `const`, so this is mostly free. Listed to confirm no regression if FAB ever gains state.

---

## Dimension 2 — Memory & Resource Management (11 / 15)

### Summary

`StreamManagementMixin` is widely adopted (see knowledge of 40+ services
consolidated). But several long-lived caches grow without bound, and
seven raw `Image.network` calls bypass the configured image cache.

### CRITICAL — `RealtimeSyncService._cachedResources` grows without bound
`lib/services/realtime_sync_service.dart:159`

```dart
return docRef.snapshots().map<T>((snapshot) {
  ...
  // Cache resource locally
  _cachedResources[resourceId] = resource;
  ...
});
```

Every recipe ever watched is added to a process-lifetime `Map`. Never evicted. No LRU. No expiration. On a session where a user opens 200 recipes, the map holds 200 fully-deserialized `RealtimeRecipe` instances. Compounds with the existing image cache.

- **Impact**: ~50–500 KB per cached recipe (varies with image URLs / instructions length). 200 recipes × 200 KB ≈ 40 MB retained for the session.
- **Best practice**: bounded LRU keyed by access time, or evict on unsubscribe.
- **Effort**: 1 day (introduce `LRUMap` or piggyback on `IntelligentCacheManager`).

### HIGH — 7 widgets use raw `Image.network`, bypassing the configured cache
- `lib/views/social/public_profile_view.dart:333`
- `lib/widgets/menu/suggest_alternative_sheet.dart:157`
- `lib/widgets/messaging/poll_creation_dialog.dart:284`
- `lib/widgets/recipe/cook_snap_gallery.dart:168`
- `lib/widgets/recipe/duplicate_merge_sheet.dart:248`
- `lib/widgets/social/activity_pings_feed.dart:402`
- `lib/widgets/social/family_presence_bar.dart:228`

Knowledge file (2026-04-26) records that `imageCache.maximumSize` was bumped 100→300 specifically to reduce grid thrash. That win is partially negated wherever raw `Image.network` is used, because raw network images don't share the disk cache and re-decode on every viewport entry. `family_presence_bar` and `activity_pings_feed` are scrollable, hot-path widgets.

- **Impact**: redundant network fetches + decode work on every scroll past these widgets. Mobile-data users feel it most.
- **Effort**: 0.5 day — straight `CachedNetworkImage` swap with `memCacheWidth` matching the layout slot.

### HIGH — `FirebaseUserIngredientRepository.watchAll` populates an unbounded `_userCache`
`lib/repositories/firebase/firebase_user_ingredient_repository.dart:190-202`

The watcher caches **all** user ingredients in a per-user map on every snapshot. No bound. Power users with hundreds of custom ingredients accumulate the full set on every snapshot — fine for the cache, but the cache is rebuilt from scratch every snapshot (linearly in N) and never trimmed across user switches.

- **Impact**: O(n) per snapshot × snapshot frequency. Memory grows with users-switched count.
- **Effort**: 0.5 day.

### MEDIUM — `_lastPromptedClipboardUrl` retained for the app lifetime
`lib/main.dart:442, 605`

A single string, not a leak per se, but the entire pattern of "remember last clipboard URL" is a global singleton on `_ButleryAppState`. Edge case: across logout/login the previous URL persists. Low memory cost; flagging because related URL strings can be long (TikTok deep links).

### MEDIUM — Several ViewModels lack explicit `dispose()`
Confirmed from grep: no `dispose` in:
- `lib/viewmodels/notifications_viewmodel.dart`
- `lib/viewmodels/ingredient_search_viewmodel.dart`
- `lib/viewmodels/shared_shopping_lists_viewmodel.dart`
- `lib/viewmodels/account_security_viewmodel.dart`
- `lib/viewmodels/onboarding_viewmodel.dart`
- `lib/viewmodels/text_import_viewmodel.dart`
- `lib/viewmodels/allergen_preferences_viewmodel.dart`

Inspection of `notifications_viewmodel.dart` shows it holds no listeners/timers/streams — extends `BaseViewModel` which presumably handles its own cleanup. Verified safe for that one. Need to spot-check the others; if any holds a `StreamSubscription` or calls `addListener` on a singleton service, it leaks.

- **Effort**: 0.5 day to audit + remediate.

### LOW — `widgets/cooking/cooking_session_stream.dart` and similar holders are correct (verified)
`mina_recept_view.dart:163-168` shows `CookingSessionStreamHolder` is owned by the State and disposed in `dispose()`. Pattern is good.

---

## Dimension 3 — Firebase Query & Schema Design (12 / 18)

### Summary

Most queries are paginated. Some streams are unbounded (pantry, personal_tags, user_ingredients), but bounded by per-user data so unlikely to break in practice. Index drift between docs and reality is the hidden cost.

### Index drift confirmed (orchestrator claim is wrong)
- Orchestrator: "34 composite Firestore indexes."
- Reality (`firestore.indexes.json`): **30 composite + 6 field overrides + 1 single-field collection-scope rule (notification_history under fieldOverrides — but it's actually a composite index in disguise: `userId ASC + sentAt DESC`)**.

The 7th `fieldOverrides` entry is mis-categorized — it's a regular composite index that's nested inside `fieldOverrides` because of how `firebase deploy --only firestore:indexes` re-emitted the file. Functionally correct, but a maintenance trap: anyone reading `firestore.indexes.json` to understand the schema will undercount by 1.

### Unbounded streams (bounded by per-user data, but no defensive cap)

| File | Stream | Bound |
|------|--------|-------|
| `firebase_personal_tag_repository.dart:93-98` | `watchAllSorted` | none |
| `firebase_personal_tag_group_repository.dart:93-98` | `watchAllSorted` | none |
| `firebase_pantry_repository.dart:88-92` | `watchAll` | none |
| `firebase_user_ingredient_repository.dart:189-202` | `watchAll` | none |
| `firebase_block_repository.dart:114-123` | `watchBlockedUserIds` | none |
| `firebase_shared_shopping_repository.dart:659-675` | `streamItems` | none |
| `firebase_recipe_presence_repository.dart:184-193` | `watchActiveUsers` | none |

All are user-scoped or document-scoped, so they're "self-bounded" by the size of one user's data. Power users with 500+ pantry items / 1000+ blocks experience full payload on every snapshot.

- **Effort**: 1 day to add `.limit()` defensive caps + telemetry on truncation.

### MEDIUM — `searchRecipes` does client-side `.contains` on a 200-doc page
`lib/repositories/firebase/firebase_recipe_repository.dart:411-442`

```dart
final snap = await getCollectionForUser(userId)
    .orderBy('core.updatedAt', descending: true)
    .limit(200) // Limit search scope to most recent 200 recipes
    .get();
final results = snap.docs.map(fromFirestore).where((r) =>
    r.title.toLowerCase().contains(lower)).toList();
```

Search misses recipes #201+. Power user with 500 recipes searching for an old recipe by title gets zero results. Comment acknowledges Algolia is the future fix.

- **Impact**: silent search failure on large libraries.
- **Effort**: 1 day for `core.titleLower` prefix search; 5 days for proper Algolia.

### MEDIUM — `findByTitle`/`findBySourceUrl` use `limit(5)` but no index hint
`firebase_recipe_repository.dart:644, 663`

These queries filter on `core.titleLower` / `core.sourceUrl` — single-field, so Firestore creates an automatic index. No composite needed. Confirmed not in `firestore.indexes.json` and not needed.

### MEDIUM — Per-conversation auto-healer fan-out (also Critical in Dim 4 — see below)
Cross-referenced finding.

### LOW — `personal_tag_groups` watch uses single-field `orderBy('sortOrder')` to avoid composite index
Comment at `firebase_personal_tag_group_repository.dart:91` is honest: dodging composite indexes for user-scoped subcollections. Reasonable tradeoff. No issue.

---

## Dimension 4 — Real-time Listeners & Streams (7 / 12)

### Summary

This is the weakest dimension. The listener-per-conversation pattern in
`conversation_query_module.dart` + `conversation_auto_healer_module.dart`
is the single highest-impact bug for scale. Stream cancellation hygiene
elsewhere is good — `StreamManagementMixin` adoption looks broad
(15 self-uses + 14 in `firebase_sync_manager` + 7 in
`friends_state_manager` + 15 in `realtime_session_manager`).

### CRITICAL — `getUserConversations` opens an auto-healer listener for every conversation row
`lib/repositories/firebase/modules/conversation_query_module.dart:36-46`
`lib/repositories/firebase/modules/conversation_auto_healer_module.dart:28-79`

```dart
return firestore.collection(collectionName)
    .where('participantIds', arrayContains: userId)
    .orderBy('updatedAt', descending: true)
    .limit(50) // Limit to 50 most recent conversations
    .snapshots()
    .map((snapshot) {
  final conversations = snapshot.docs.map(fromFirestore).toList();
  // Auto-start healers for all conversations
  for (final conversation in conversations) {
    startAutoHealer(conversation.id);
  }
  return conversations;
});
```

Each healer is `messages.where(conversationId == X).orderBy(sentAt desc).limit(1).snapshots()`. So **opening the conversations list spawns up to 50 concurrent message listeners just to keep `lastMessage` in sync**. Plus the conversations listener itself (1) and the active chat's message listener (1) = up to **52 concurrent Firestore listeners** during normal messaging usage.

**Scale impact:**
- 1K active users with messaging → ~20–50K concurrent listeners. Within Firestore's ~100K project ceiling.
- 10K active users → ~200–500K concurrent listeners. **Breaks Firestore.**
- 100K users → game over.

**Why the auto-healer exists**: comment says "ensure lastMessage is always accurate, even if atomic update fails." That's a defensive backstop for a write-side race. But you don't need a real-time listener for it — a one-shot reconciliation on conversation-screen open is sufficient, or push the heal logic into a Cloud Function `onMessageCreate` trigger that also writes the parent conversation's `lastMessage` (single source of truth).

- **Effort**: 1–2 sprints. Migration: deploy `onMessageCreate` Cloud Function that writes `lastMessage` to the conversation doc, then delete `ConversationAutoHealerModule` entirely.

### HIGH — `_cachedResources` map (cross-ref to Dim 2) means listener cancellation doesn't free memory
Already covered in Dim 2 CRITICAL. Listener-side cleanup is correct (StreamSubscription is cancelled), but the parsed object lingers in the map.

### HIGH — `realtime_session_manager.dart:30-58` registers an "active editor" with no idle eviction
Each open recipe edit registers an active editor record + per-recipe subscription. If the user opens edit, then backgrounds the app, then never returns, the active-editor record stays in Firestore until TTL/cleanup. Subscription is also held. Knowledge of the cleanup hooks in `presence_tracking_module` mitigates but doesn't eliminate.

### MEDIUM — `friends_state_manager` holds 7 stream subscriptions per logged-in user
`lib/services/unified/friends/friends_state_manager.dart` — 7 `.listen()` calls counted. These are friends, friend-requests, social-requests, blocks, categories, etc. All necessary for current UX, but the total per-user listener floor is `7 (friends) + 1 (conversations) + N (auto-healers) + 1-3 (active recipe / shopping) ≈ 10–55`. At scale this is the cost-driver.

### MEDIUM — `presence_service.dart:301`, `ping_service.dart:135`, `report_service.dart:93,110`, `cache/permission_cache_invalidator.dart:65` all open lifetime-scoped listeners
None take a `limit()`. All are single-user-scoped queries, but defensive limits are missing.

---

## Dimension 5 — Scalability Projections (10 / 15)

### Bottleneck table

| Bottleneck | Hits at | Impact |
|------------|---------|--------|
| Auto-healer listener fan-out | ~5K active users with messaging | Hits 100K listener project ceiling |
| `recipe_ratings` aggregation (fan-in to single recipe doc) | ~viral recipe scenario (~100 ratings/sec) | Hot-doc write contention; `updateRecipeRatingStats` re-reads all ratings |
| `searchRecipes` 200-recipe scan window | Power user with >200 recipes | Silent search miss |
| `cleanup-rate-limits.ts` USER_CHUNK_SIZE=1000 | 1M users | One scheduled run × 1000 chunks; OK |
| Image cache 50 MB | Tablet grid scrolling >300 unique images | LRU thrash |
| `_cachedResources` unbounded | Long-session users opening 100+ recipes | Memory leak, OOM eventually |

### Cost model (rough, static)

Reads/writes per user/day estimates from the code:

| Operation | Reads | Writes |
|-----------|-------|--------|
| App open | 5–10 (auth, profile, prefs) | 1 (analytics) |
| Open recipe list (mina_recept) | 100 (page) + 7 friends streams | 0 |
| Open conversations list | 50 + (50 × 1 healer listeners on first open) | 0 |
| Active chat | 50 messages/min real-time | 1–10/min |
| Open a recipe | 10 (recipe + comments + ratings stats + cook snaps) | 0 |
| Cook a recipe | 1 (incrementCookCount) | 1 |

Assuming median user opens app 2× per day, opens 5 recipes, sends 10 messages: ~250 reads + ~30 writes/user/day.

| Scale       | Users    | Reads/day  | Writes/day | $ Reads/mo (~$0.06/100K) | $ Writes/mo (~$0.18/100K) | Total $/mo |
|-------------|----------|------------|------------|---------------------------|----------------------------|------------|
| Current     | ~100     | 25K        | 3K         | $0.45                     | $0.16                      | ~$1        |
| 10x         | 1K       | 250K       | 30K        | $4.50                     | $1.62                      | ~$6        |
| 100x        | 10K      | 2.5M       | 300K       | $45                       | $16                        | ~$60       |
| 1000x       | 100K     | 25M        | 3M         | $450                      | $162                       | ~$610      |

Costs look manageable on the read/write line. The hidden cost is **listener-seconds** (Firestore charges concurrent listener fan-out as reads on snapshot deltas). Auto-healer fan-out 10x'es the effective read cost on conversations.

### Bottleneck: `updateRecipeRatingStats` re-aggregates all ratings on every change
`functions/src/index.ts:130-218`

For a viral recipe with 1000 ratings, every new rating triggers `O(N)` Cloud Function execution. Becomes a hot-spot at ~10 ratings/sec — Firestore's 1 write/sec/document soft limit on `recipe_social_stats/{recipeId}` becomes the bottleneck before CF scaling does. Knowledge: comment claims "10–100 ratings typical" and "50–200ms execution." Both reasonable for that range; degrades super-linearly outside it.

- **Mitigation at scale**: use `FieldValue.increment` for count + sum, recompute average on read. (Distribution map needs careful handling.)

### Cloud Functions — generally well-configured

`setGlobalOptions({ region: "europe-west1" })` confirmed correct. Per-function `memory` and `timeoutSeconds` set:
- `structureRecipe`: 512 MiB / 60s
- `ocrRecipeImage`: 1 GiB / 120s (Vision)
- `logWebError`: 256 MiB / 10s
- `onUserDeleted`: 512 MB / 540s
- Default for unspecified: 256 MiB / 60s

No `minInstances` set anywhere — every cold start eats Vertex AI initialization. For LLM functions called from user-facing flows (Smart Import), p95 cold start is ~3–8s. Adding `minInstances: 1` on `structureRecipe` and `ocrRecipeImage` would smooth this out at ~$15–30/mo.

### `Stockholm` mentions analyzed

41 mentions in `lib/`+`functions/`. All are **timezone references** (`Europe/Stockholm` IANA TZ for quiet-hours, digest scheduling, lapsed-user detection). **None refer to deployment region** — that's correctly `europe-west1`. No perf implication from this drift; doc-drift only (deferred to prompt 12).

---

## Dimension 6 — Bundle Size & Network Efficiency (10 / 12)

### Summary

Asset side is excellent (knowledge file 2026-04-26 — WebP conversion saved 10.4 MB, 94% reduction). Bundle size unmeasured. Network efficiency is mostly good with one weak spot: raw `Image.network` (cross-ref Dim 2).

### MEDIUM — Bundle size unmeasured by this audit
No build artifact in pre-analysis. Recommend running `flutter build apk --analyze-size` and `flutter build web --release --analyze-size` and tracking trends.

### LOW — Several large files >500 lines that could be split
132 hand-written files >500 lines (knowledge: orchestrator claim was 33). Top offenders for perf-relevant code:
- `lib/main.dart` (1250 lines) — boot logic + AuthWrapper + InitializationWrapper + OnboardingResumeGate all in one file. Splitting reduces tree-shaking surface but won't change runtime.
- `lib/repositories/firebase/firebase_recipe_repository.dart` (1092)
- `lib/services/unified/modules/personal_recipe_module.dart` (1023)
- `lib/services/unified/unified_recipe_service.dart` (995)

These don't directly hurt perf (Dart's tree-shaking is per-symbol, not per-file). They hurt maintainability — perf bugs are easier to plant in an 1100-line file.

### LOW — `assets/illustrations/arta/` PNG frames intentionally NOT WebP-converted
Knowledge confirms — animation frames at q=85 introduce artifacts. Correct decision documented.

---

## Dimension 7 — Offline Performance & Sync (9 / 10)

### Summary

Best-scoring dimension. Persistence is enabled, cache-first patterns are in place, web has explicit IndexedDB recovery (cross-ref Dim 1 web cold-start finding).

`lib/main.dart:172-175`:
```dart
FirebaseFirestore.instance.settings = const Settings(
  persistenceEnabled: true,
  cacheSizeBytes: 100 * 1024 * 1024, // 100 MB
);
```

100 MB Firestore cache is generous and appropriate.

`getDocCacheFirst` is used for archive recipes (`firebase_recipe_repository.dart:763`). Pattern is good but only one site; other read-heavy paths (recipe detail, friends profiles) could benefit.

### LOW — No "offline pending writes" UI indicator
The repo exposes `metadata.hasPendingWrites` and `isFromCache` (recipe stream's `onSyncStatusChanged` callback at `firebase_recipe_repository.dart:711, 719-722`). VM exposes `hasPendingWrites` getter (`recipe_list_viewmodel.dart:193`). But I didn't find UI consumption — likely a small UX gap, not a perf gap.

---

## Quick Wins (highest ROI)

1. **Swap 7 `Image.network` calls for `CachedNetworkImage`** with `memCacheWidth/Height`. ~30 min total.
2. **Defer the web `_health/_` Firestore probe to after first frame.** ~30 min.
3. **Pass loop index through `LayoutComponents.responsiveListGrid` itemBuilder** so `recipes.indexOf` dies. ~30 min.
4. **Add `.limit(N)` to the 7 unbounded user-scoped streams** (pantry, tags, blocks, ingredients, etc). Defensive — won't change observable behavior for normal users, prevents future surprises. ~1 hour.

## Larger but high-impact

1. **Replace `ConversationAutoHealerModule` with a Cloud Function trigger.** Single largest scale unblock. 1–2 sprints.
2. **Bound `RealtimeSyncService._cachedResources` with an LRU.** 1 day.
3. **Add `minInstances: 1` to LLM Cloud Functions** for predictable warm-start latency on user-facing flows. 1 hour + cost monitoring.
4. **Pre-emptively migrate `searchRecipes` to a `core.titleLower` prefix index** before hitting users with >200 recipes. 1 day.

---

## Knowledge file alignment

The two patterns recorded in `.claude/agents/performance-optimizer.knowledge.md` (image cache size 300 + WebP conversion) are both still in effect and correct. This audit doesn't supersede them.

New patterns worth appending after Phase 2 verification:
- "Real-time auto-healer fan-out" anti-pattern (per-row listener spawned by a list listener).
- "Cached-resource map without LRU" anti-pattern (any `Map<id, parsedDoc>` in a service that takes streams as input).
- "Raw `Image.network` in scrollable widgets" — bypasses configured cache; same regression class as forgetting `const`.

These will be appended when Phase 2 fixes land and we have measurements.

---

## Phase 2 input

This report is ready to drive Phase 2's prioritized roadmap. Suggested phasing:

- **Now (Sprint 1)**: All quick wins above + image cache audit + bound `_cachedResources`. Estimated 3–5 days.
- **10x readiness (Sprint 2)**: Replace auto-healer with CF trigger + add Algolia for search + LLM `minInstances`. Estimated 2 weeks.
- **100x readiness**: Distributed counter pattern for `recipe_social_stats` + listener pooling library. 1 month.
- **1000x readiness**: Hybrid backend evaluation (Firestore for low-fan-out data, separate write-optimized store for messaging fan-out). Decision point, not yet a project.

---

End of Phase 1 report.
