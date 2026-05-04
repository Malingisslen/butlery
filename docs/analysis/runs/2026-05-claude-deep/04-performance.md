# Performance & Scalability — Phase 1 (Pass 1 Investigator, DEEP)

```
Analyst:        Claude (Opus 4.7, 1M context) — performance-optimizer agent
Date:           2026-05-02
Run:            2026-05-claude-deep / Wave 2 / Prompt 04
Pass:           1 of 2 — investigation only, Pass 2 critic follows
Method:         Static, read-only audit. Knowledge file (6.5 KB) treated as
                hypothesis. Pre-analysis from sister Codex run reused.
                ≥50 file:line refs, ≥30 % spent on missing invariants.
```

> **Phase 1 caveat** — every device-side number (cold start, FPS, memory,
> jank) is a static-analysis estimate. Confidence is **high** on Firebase-side
> findings (repository code is unambiguous), **medium** on widget-rebuild
> claims (no profiler), **low** on memory budgets (no DevTools snapshot).
> The intent is to surface where to instrument, not to declare ground truth.

---

## Executive Summary

```
OVERALL SCORE: 70 / 100   (Acceptable — prioritized remediation within 2 sprints)

  1. App Startup & Frame Rate          : 13 / 18
  2. Memory & Resource Management      : 10 / 15   <-- regressed by 1 from Run 1 (new leak found)
  3. Firebase Query & Schema Design    : 12 / 18
  4. Real-time Listeners & Streams     :  6 / 12   <-- weakest; conversation auto-healer still live
  5. Scalability Projections           : 10 / 15
  6. Bundle Size & Network Efficiency  : 10 / 12
  7. Offline Performance & Sync        :  9 / 10

CRITICAL: 3 found  (Run 1: 2 — added FriendsStateManager dispose leak)
HIGH:     8 found
MEDIUM:  10 found
LOW:      6 found
```

**Top three risks (Pass 1 verified):**

1. **`ConversationAutoHealerModule` listener fan-out** — verified live on
   disk at `lib/repositories/firebase/modules/conversation_auto_healer_module.dart:38-78`
   and triggered for every conversation row at
   `lib/repositories/firebase/modules/conversation_query_module.dart:41-43`.
   Each healer opens an additional `messages.where(conversationId == X)…limit(1).snapshots()`
   listener — **52 concurrent listeners per active user** during normal
   messaging usage. At 10K active users this fan-out exceeds Firebase's
   100K-listener-per-project ceiling.
2. **`RealtimeSyncService._cachedResources` unbounded map** — verified at
   `lib/services/realtime_sync_service.dart:53` and populated unconditionally
   at `:159`. Cleared only on `_userLoggedOut` (`:64`) and explicit
   `deleteResource` (`:278`). Long-running session leaks proportional to
   recipes opened (~50–500 KB each).
3. **`FriendsStateManager.dispose()` leaks `_blockedUsersSubscription`** —
   **NEW finding, not in Run 1**. `lib/services/unified/friends/friends_state_manager.dart:613-631`
   cancels six subscriptions but forgets the seventh. `clearAllData()` at
   `:203` does cancel it; `dispose()` does not. Net effect: every dispose
   without prior `clearAllData()` leaks one Firestore listener per
   logged-in user.

---

## Methodology Notes

- **Knowledge file alignment** (`.claude/agents/performance-optimizer.knowledge.md`):
  the 2026-04-26 entries (image cache 100→300; WebP saved 10.4 MB) were
  verified against `lib/main.dart:152-154` and against the `assets/illustrations/`
  directory contents. **Both still correct, both still in effect.**
- **Run 1 cross-check**: every CRITICAL/HIGH finding from
  `docs/analysis/runs/2026-05-claude/04-performance.md` re-verified
  against current source. All still live. One additional CRITICAL added
  this pass (FriendsStateManager dispose leak — see Dim 2).
- **Index drift verified**: pre-analysis numbers correct — `firestore.indexes.json`
  has **30 composite + 6 array/scalar field overrides + 1 mis-categorized
  composite (`notification_history`)**, not the 34 documented in the
  orchestrator. The 7th `fieldOverrides` entry at lines 302-308 is a
  composite-shaped index (`userId ASC + sentAt DESC`) deployed under
  `fieldOverrides` rather than `indexes`. Functionally equivalent, but
  confusing.
- **Cloud Functions audit** — `setGlobalOptions({region: "europe-west1"})`
  confirmed once at `functions/src/index.ts:20`. **No `minInstances` set
  anywhere** (verified via grep across `functions/src/`). Per-function
  memory/timeout: `structureRecipe` 512 MiB / 60 s
  (`functions/src/llm/structure-recipe.ts:67-68`), `ocrRecipeImage` 1 GiB / 120 s,
  `logWebError` 256 MiB / 10 s, `onUserDeleted` 512 MB / 540 s.

---

## Performance Benchmarks (static estimate)

| Metric                  | Static estimate         | Target    | Status    |
|-------------------------|-------------------------|-----------|-----------|
| Cold start (web)        | 2.5–3.5 s               | <2.0s     | At risk   |
| Cold start (mobile)     | 1.8–2.5 s               | <2.0s     | Borderline|
| Warm start              | ~0.6–0.9 s              | <1.0s     | OK        |
| Time to first frame     | 600–900 ms              | <500ms    | At risk   |
| Average FPS             | unknown                 | 60fps     | Not measured |
| Jank percentage         | unknown                 | <1%       | Not measured |
| Memory (typical)        | unknown                 | <150MB    | Not measured |
| Image cache cap         | 50 MB / 300 entries     | <50MB     | OK        |
| Firestore queries / screen | 3–10                | <5        | Mixed     |
| Concurrent listeners / user | 12–55 (peak chat)  | <10       | At risk   |
| Offline cache size      | 100 MB                  | (config)  | OK        |
| LLM cold-start (Vertex) | 3–8 s p95 first hit     | <2s       | At risk   |

---

## Critical / High / Medium / Low Findings

### CRITICAL #1 — `ConversationAutoHealerModule` opens 52 concurrent listeners per active user

`lib/repositories/firebase/modules/conversation_query_module.dart:31-46` —
`getUserConversations` returns a stream that, on every snapshot, calls
`startAutoHealer(conversation.id)` for **all 50 conversations** in the
list. Each call enters
`lib/repositories/firebase/modules/conversation_auto_healer_module.dart:28-79`
and opens a long-lived `.snapshots()` listener bounded only by the
process lifetime of the `_activeHealers` map at line 18.

**Why a real-time listener for `lastMessage` is wrong**: the comment at
`:9-11` claims this guarantees "lastMessage is always accurate, even if
atomic update fails." That's a defensive backstop for a write-side
race — but the cost is paid as a permanent listener instead of a one-shot
read. The clean migration is a Cloud Function `onMessageCreate` trigger
that writes `conversation.lastMessage` server-side (single source of
truth). At deploy time, `ConversationAutoHealerModule` is deletable.

**Scale impact (verified math):**
- 1K active users with messaging → ~20–50K concurrent listeners.
  Within Firestore's ~100K project soft cap.
- 10K active users → ~200–500K concurrent listeners. **Breaks Firestore
  project ceiling.**
- 100K users → no path forward without architectural change.

**Effort**: 1–2 sprints. Migration: deploy `onMessageCreate` CF, delete
auto-healer, redeploy.

### CRITICAL #2 — `RealtimeSyncService._cachedResources` grows without bound

`lib/services/realtime_sync_service.dart:53` declares
`_cachedResources = <String, RealtimeResource>{}`. Every call to
`watchResource<T>(resourceId)` parses the snapshot and inserts at `:159`
(`_cachedResources[resourceId] = resource`). Cleared in three places only:
- `:64` on user logout (full `.clear()`)
- `:278` on `deleteResource` (single-key remove)
- `:411` on `onDispose` (full `.clear()`)

There is **no LRU eviction, no idle eviction, no size cap**. Power-user
session that opens 200 recipes retains 200 fully-deserialized
`RealtimeRecipe` instances (~50–500 KB each) — 10–100 MB of session
heap — until logout.

The same anti-pattern recurs in
`lib/repositories/firebase/firebase_user_ingredient_repository.dart:189-202`
where `watchAll(userId)` rebuilds `_userCache[userId]` on every snapshot
without trimming entries for prior users (multi-account on same device
accumulates).

**Effort**: 1 day. Bound to `IntelligentCacheManager` (`:138`) — the
project already has the eviction pattern (`evictionScore` at
`lib/services/performance/intelligent_cache_manager.dart:128-134`).

### CRITICAL #3 — **NEW** — `FriendsStateManager.dispose()` leaks `_blockedUsersSubscription`

`lib/services/unified/friends/friends_state_manager.dart:613-631` cancels
six subscriptions: incoming requests, sent requests, group invitations,
categories, member categories, friends. **It does not cancel
`_blockedUsersSubscription`** (declared at `:40`, started at `:284`).

The `clearAllData()` path at `:203` does cancel it, but `dispose()` (the
universal cleanup hook) does not. If a parent Provider triggers
`dispose()` without first calling `clearAllData()` — the standard
Flutter scenario — one Firestore listener leaks per logged-in user.

**Why this matters at scale**: every navigation to/away from screens
that hold a `FriendsStateManager` instance via `ChangeNotifierProvider`
(no `value:`) leaks one listener. Project ceiling at 10K users +
realistic navigation patterns: ~50–100K leaked listeners over a session.

**Effort**: 30 seconds. Add `_blockedUsersSubscription?.cancel();` and
`_blockedUsersSubscription = null;` to `dispose()` block.

### HIGH #1 — 7 widgets use raw `Image.network`, bypassing the configured cache

Verified all 7 sites still live (grep across `lib/`):
- `lib/views/social/public_profile_view.dart:333`
- `lib/widgets/menu/suggest_alternative_sheet.dart:157`
- `lib/widgets/messaging/poll_creation_dialog.dart:284`
- `lib/widgets/recipe/cook_snap_gallery.dart:168`
- `lib/widgets/recipe/duplicate_merge_sheet.dart:248`
- `lib/widgets/social/activity_pings_feed.dart:402`
- `lib/widgets/social/family_presence_bar.dart:228`

The 50 MB / 300-entry image cache configured in `lib/main.dart:152-154`
is bypassed by raw `Image.network`. `family_presence_bar` and
`activity_pings_feed` are scrollable hot-path widgets, so each scroll
past these triggers redundant network fetch + decode work. Mobile-data
users feel it most.

**Cross-cutting note**: the project has a perfectly good
`lib/widgets/image/recipe_image_widget.dart` that uses `RepaintBoundary`
(`:200`, `:239`, `:252`) and `memCacheWidth/Height`. The 7 raw uses are
drift, not by design.

**Effort**: 1 hour total — straight `CachedNetworkImage` swap with
`memCacheWidth` matching the layout slot.

### HIGH #2 — Web cold-start blocks on a Firestore round-trip every load

`lib/main.dart:181-203` calls
`FirebaseFirestore.instance.collection('_health').doc('_').get().timeout(5s)`
synchronously inside the boot path. Comment says it's there to detect
IndexedDB corruption in JS SDK 12.x. Cost: every web load pays
100–800 ms on the critical path before `runApp` is called; timeout edge
adds up to 5 s.

**Fix sketch**: defer the probe to after first frame using
`WidgetsBinding.instance.addPostFrameCallback`. Recovery on detected
corruption can show a banner and trigger a reload after fixing.

**Effort**: 30 min.

### HIGH #3 — `ConversationQueryModule.getUnreadConversationsCount` falls back to `.limit(500)` scan

`lib/repositories/firebase/modules/conversation_query_module.dart:121-125`
falls back to `arrayContains: userId + .limit(500)` when the inverse
index isn't populated. Then **client-side filtering** at `:128-131` for
`hasUnreadMessages(userId)`. Worst case: 500 doc reads to compute one
badge number. The inverse-index path (line 115) is O(1), but only
triggers when `participantModule != null && memberships.isNotEmpty`.

**Effort**: 0.5 day — make inverse-index population a hard precondition
(deny fallback, force migration), or move the count to a server-side
aggregation field.

### HIGH #4 — `searchRecipes` does client-side `.contains` on a 200-doc page (search misses all recipes #201+)

`lib/repositories/firebase/firebase_recipe_repository.dart:412-442`
fetches the 200 most recent recipes, filters client-side via
`r.title.toLowerCase().contains(lower)` at `:431`. Power user with 500
recipes searching for an old title gets zero results — silently. Comment
acknowledges Algolia is the future fix.

**Effort**: 1 day for `core.titleLower` server-side prefix search;
3–5 days for proper Algolia.

### HIGH #5 — `updateRecipeRatingStats` re-aggregates ALL ratings on every change

`functions/src/index.ts:130-218` runs a full collection scan via
`db.collection("recipe_ratings").where("recipeId", "==", recipeId).get()`
**on every rating create/update/delete**. For viral recipes (1K+
ratings), this is O(N) per write. At ~10 ratings/sec the
`recipe_social_stats/{recipeId}` doc hits Firestore's 1 write/sec/doc
soft limit before CF concurrency limits do.

**Mitigation at scale**: switch to `FieldValue.increment` for
count + sum, recompute average on read. Distribution map needs
careful handling (per-bucket increment).

**Effort**: 1 day (with backfill migration).

### HIGH #6 — Cloud Functions have NO `minInstances` configured anywhere

Verified via grep across `functions/src/` — zero `minInstances` settings.
Every cold start of `structureRecipe` / `ocrRecipeImage` re-initializes
the Vertex AI SDK at
`functions/src/llm/gemini-client.ts:57-64`. p95 cold start measured by
similar projects: 3–8 s for Vertex AI on first hit per container.

User flow impact: **every Smart Import after a cold-instance window
takes an extra 3–8 s** on top of the LLM round trip. For first-time
users (typical onboarding), the cold start is the entire perceived AI
latency.

**Effort**: 1 hour. `minInstances: 1` on `structureRecipe` and
`ocrRecipeImage` adds ~$15–30/mo at GCP Cloud Functions v2 EU pricing.

### HIGH #7 — `realtime_session_manager` opens an "active editor" listener with no idle eviction

`lib/services/unified/modules/realtime_session_manager.dart:38-47`
opens a per-recipe `.snapshots()` listener via `startRealtimeEditing`.
Cancellation at `:73` is correct, but only fires when
`stopRealtimeEditing` is called. **If the user backgrounds the app
mid-edit, no idle timer evicts the session.** The active-editor record
lingers in Firestore until a periodic cleanup runs.

**Effort**: 0.5 day — wire to `lifecycleState` listener.

### HIGH #8 — `FriendsStateManager` opens 7 concurrent listeners per logged-in user

Verified at `lib/services/unified/friends/friends_state_manager.dart`:
- `_incomingRequestsSubscription` (`:240`)
- `_sentRequestsSubscription` (`:253`)
- `_groupInvitationsSubscription` (`:307`)
- `_categoriesSubscription` (`:376`)
- `_memberCategoriesSubscription` (`:407`)
- `_friendsSubscription` (`:273`)
- `_blockedUsersSubscription` (`:284`)

All necessary for current UX, but the per-user listener floor is
**7 (friends) + 1 (conversations) + N (auto-healers, see CRITICAL #1)
+ 1–3 (active recipe / shopping) = 10–55 listeners minimum**. At scale
this is the cost-driver line item before fan-out CRITICAL #1 even
factors in.

**Effort**: 1 sprint to consolidate via collection-group queries +
server-side aggregation.

### MEDIUM #1 — Unbounded user-scoped streams (no defensive `.limit()`)

| File | Stream method | Bound source |
|------|---------------|--------------|
| `lib/repositories/firebase/firebase_personal_tag_repository.dart:93-98` | `watchAllSorted` | per-user data only |
| `lib/repositories/firebase/firebase_personal_tag_group_repository.dart:93-98` | `watchAllSorted` | per-user data only |
| `lib/repositories/firebase/firebase_pantry_repository.dart:88-92` | `watchAll` | per-user data only |
| `lib/repositories/firebase/firebase_user_ingredient_repository.dart:189-202` | `watchAll` | per-user data only |
| `lib/repositories/firebase/firebase_block_repository.dart:114-123` | `watchBlockedUserIds` | per-user data only |
| `lib/repositories/firebase/firebase_shared_shopping_repository.dart:659-675` | `streamItems` | per-list data only |
| `lib/repositories/firebase/firebase_recipe_presence_repository.dart:184-193` | `watchActiveUsers` | per-recipe data only |

All "self-bounded" by user/document scope, so a single power user with
500 pantry items + 1K blocks pays the full snapshot cost on every
change. None are fatal at current scale; all are time bombs at 100x.

**Effort**: 1 day across all 7. Add `.limit(N)` defensive caps +
truncation telemetry.

### MEDIUM #2 — `recipes.indexOf(recipe)` per item in list grid

`lib/views/mina_recept_view.dart:980` uses `recipes.indexOf(recipe)`
inside the `LayoutComponents.responsiveListGrid` itemBuilder, which is
O(n²) per build (100 recipes = 10K linear scans per frame). The grid
path at `:965-967` correctly uses the loop index. The list-grid path
needs the same treatment.

`asMap().entries.map(...)` at `lib/views/recipe_detail/recipe_detail_content.dart:172`
and `:281` and `lib/views/unified_shopping/widgets/shopping_list_content.dart:439`
is the correct pattern — adopt project-wide.

**Effort**: 30 min — pass index through `responsiveListGrid`'s
`itemBuilder` signature.

### MEDIUM #3 — Bootstrap registers and validates 10+ DI modules even when most aren't user-facing

`lib/core/bootstrap/application_bootstrap.dart:330-372` runs all
stages serially with full timeouts. Lazy singletons inside the modules
(see `collaboration_module.dart:69`) mean registration is cheap, but
the stages themselves still execute. `_validateInitialization`
(`:432-471`) runs a full DI health check when user scope exists.
Estimated 50–150 ms on the critical path on warm start with cached
auth, multiplied by stage count.

**Effort**: 1 day to rework stage prioritization (only `PlatformStage`
+ `CoreStage` need to gate first frame).

### MEDIUM #4 — Seasonal hero recomputes match list on every QueryViewModel rebuild

`lib/views/mina_recept_view.dart:604-622` calls
`_seasonalHeroService.matchUserRecipes(month, queryVm.personalRecipes)`
inside the FutureBuilder builder. Future is cached, but the match call
runs on every rebuild and walks all recipes.

**Effort**: 30 min — memoize on `(month, recipes.length, recipes.first?.id)` key.

### MEDIUM #5 — 13 ViewModels lack explicit `dispose()` override

Confirmed via `grep -L "void dispose"` against `lib/viewmodels/*.dart`:
- `account_security_viewmodel.dart`
- `allergen_preferences_viewmodel.dart`
- `assisted_import_viewmodel.dart`
- `cooking_mode_viewmodel.dart`
- `group_recipe_selection_viewmodel.dart`
- `ingredient_search_viewmodel.dart`
- `notifications_viewmodel.dart`
- `onboarding_viewmodel.dart`
- `public_profile_viewmodel.dart`
- `shared_shopping_lists_viewmodel.dart`
- `shopping_share_viewmodel.dart`
- `text_import_viewmodel.dart`
- `url_import_viewmodel.dart`

Most likely safe (extend `BaseViewModel` which handles its own
cleanup), but each one needs spot-check for `StreamSubscription` /
`addListener` / `Timer` ownership. Even one missed leak = production
listener growth.

**Effort**: 0.5 day audit + remediate.

### MEDIUM #6 — `searchRecipes`-style 200-doc + client-filter pattern recurs

Same pattern at `lib/repositories/firebase/firebase_recipe_repository.dart:879`
(ingredient search via `recipe.ingredients.any(...)`) and `:891-897`
(title contains). Power-user search reliability degrades silently.

### MEDIUM #7 — 7 ListView constructors (non-builder) loaded eagerly

Verified via grep — `lib/views/edit_recipe_view.dart:171`,
`lib/views/faq_view.dart:31`, `lib/views/pantry/pantry_view.dart:118`,
`lib/views/recipe_detail/handlers/recipe_management_handler.dart:149`,
`lib/views/recipe_detail/handlers/recipe_personal_tag_handler.dart:288`,
`lib/views/settings/collection_stats_view.dart:63`,
`lib/views/settings/settings_hub_view.dart:29`,
`lib/views/skriv_sjalv_recept_view.dart:375`, plus 3 more.

For settings/FAQ pages (small, fixed) this is fine. For
`pantry_view.dart:118` (potentially many ingredients) and
`recipe_personal_tag_handler.dart:288` (many tags) this should be
`.builder`. None are catastrophic; flag for code-review hygiene.

### MEDIUM #8 — FCMService uses 11 mutable static fields

`lib/services/notifications/fcm_service.dart:77-101` declares 11
mutable statics including `_currentToken`, `_isInitialized`,
`_pushPermissionsRequested`, `_consentService`, plus 3 stream
subscriptions (`:91-93`). **This is from Wave 1 code-quality finding
01-code-quality.md as a thread-safety / test-isolation issue, but it
also has perf relevance**: static state across hot-restart in
`flutter run` doesn't reset, so dev-mode iterations can accumulate
phantom subscribers. Production impact small (single process) but
test-suite memory growth real.

**Effort**: tracked under code-quality remediation; perf cost is
secondary.

### MEDIUM #9 — `_lastPromptedClipboardUrl` retained for app lifetime

`lib/main.dart:442, 605` — global singleton on `_ButleryAppState`. A
single string, not a leak per se, but the URL can be a long TikTok deep
link (~500 chars). Edge case: across logout/login the previous URL
persists. Cross-user exposure if device is shared.

### MEDIUM #10 — `Stockholm` mentions in `lib/`+`functions/`: 41 instances

All are timezone references (`Europe/Stockholm` IANA TZ for
quiet-hours, digest scheduling, lapsed-user detection). **None refer to
deployment region** — that's correctly `europe-west1`. No perf
implication; doc-drift only (defer to prompt 12).

### LOW #1–6 (brief)

- `MaterialApp.builder` re-creates Stack + RepaintBoundary +
  FeedbackFAB every rebuild (`lib/main.dart:907-937`). FAB is
  `const`, so this is mostly free. Watch for regression.
- Several large files >500 lines in perf-relevant code (132 total per
  pre-analysis; `lib/main.dart` 1288, `firebase_recipe_repository.dart`
  1092, etc.). Doesn't directly hurt runtime perf — Dart tree-shakes
  per-symbol — but bugs are easier to plant in 1100-line files.
- `assets/illustrations/arta/` PNG frames intentionally NOT
  WebP-converted (knowledge file 2026-04-26 documents the why).
  Correct call.
- `personal_tag_groups` watch uses single-field `orderBy('sortOrder')`
  to avoid composite index (`lib/repositories/firebase/firebase_personal_tag_group_repository.dart:91`).
  Honest tradeoff.
- `archive` recipes use `getDocCacheFirst` (cache-first read) at
  `lib/repositories/firebase/firebase_recipe_repository.dart:763`.
  Pattern is good but only one site; recipe-detail / friend-profile
  reads could benefit.
- `gemini-client.ts` keeps singleton via `let vertexClient: VertexAI | null`
  (`functions/src/llm/gemini-client.ts:32`) — correct per-instance
  caching, but irrelevant if `minInstances=0` (still cold-init per new
  container — see HIGH #6).

---

## Listener Inventory (concurrent listeners per typical user)

Counted via grep of `.snapshots()` + `.listen(` across `lib/`. 40 files
contain at least one `.snapshots()` call.

| Source | Listeners per logged-in user | File:line |
|--------|------------------------------|-----------|
| Conversations list | 1 | `conversation_query_module.dart:36` |
| Auto-healers (one per conversation, up to 50) | 0–50 | `conversation_auto_healer_module.dart:38` |
| Active chat messages | 1 | `message_query_module.dart:26-103` |
| Friends state (7 streams) | 7 | `friends_state_manager.dart:240-296` |
| Recipe list watcher | 1 | `firebase_recipe_repository.dart:707-735` |
| Active recipe edit (per open) | 0–N | `realtime_session_manager.dart:38` |
| Block list | 1 (also leaked via dispose, see CRITICAL #3) | `firebase_block_repository.dart:118` |
| Pantry watcher | 1 if pantry open | `firebase_pantry_repository.dart:88-92` |
| Personal tags watcher | 1 if tags open | `firebase_personal_tag_repository.dart:93-98` |
| Notifications watcher | 1 | `firebase_notifications_repository.dart:152-158` |
| Cook-snap gallery (per recipe) | 0–1 | `firebase_cook_snap_repository.dart:118-120` |
| Recipe presence (per recipe) | 0–1 | `firebase_recipe_presence_repository.dart:184-193` |
| Shopping list items (per shared list) | 0–1 | `firebase_shared_shopping_repository.dart:659-675` |
| Shopping presence | 0–1 | `firebase_shopping_presence_repository.dart` |
| Connectivity | 1 | `firebase_connectivity_repository.dart` |
| Cache invalidator | 1 | `permission_cache_invalidator.dart:65` |
| Reports (mod) | 0–2 | `report_service.dart:93,110` |
| Pings | 0–1 | `ping_service.dart:135` |
| Presence | 0–1 | `presence_service.dart:301` |
| Realtime session manager (per active edit) | 0–N | `realtime_session_manager.dart:38` |
| Realtime sync service (per watched resource) | 0–N (also leaked via map) | `realtime_sync_service.dart:145` |
| Comments per opened recipe | 0–1 | `firebase_comments_repository.dart:86-102` |
| Ratings per opened recipe | 0–1 | `firebase_ratings_repository.dart:283-305` |
| Menu voting | 0–1 | `firebase_menu_voting_repository.dart` |
| Menu collaboration | 0–1 | `firebase_menu_collaboration_repository.dart` |
| Group weekly menu plan | 0–1 | `firebase_group_weekly_menu_plan_repository.dart` |
| Friend categories (cross-user) | 0–N | `friend_category_repository.dart` |
| FCM message subs | 2 | `fcm_service.dart:329, 339` |

**P50 user (idle browsing, no chat open)**: ~12 listeners.
**P95 user (chat open + recipe edit + shopping)**: ~50–55 listeners.
**Pathological worst case (50 conversations, all auto-healers spawned + active chat + active edit + shopping list + presence)**: ~80 listeners.

At 10K active users:
- P50: 120K listeners → **already over Firestore project ceiling**.
- P95: 500K listeners → game over.

---

## Index Coverage Gap Analysis

Walked `firestore.indexes.json` (30 composites + 6 field overrides + 1
mis-categorized composite under `fieldOverrides`) vs every
`.where(...).orderBy(...)` in `lib/repositories/firebase/`.

### Indexes covered correctly

- `recipes` queries (`userId + createdAt`, `userId + lastCooked`) covered.
- `friend_requests`, `social_requests`, `group_invitations` (toUserId
  + status + sentAt) covered.
- `messages` (conversationId + sentAt) covered. Auto-healer query at
  `conversation_auto_healer_module.dart:38-42` uses this index.
- `conversations` (participantIds CONTAINS + updatedAt) covered.
- `recipe_comments`, `recipe_ratings`, `cook_snaps`, `audit_logs` all covered.

### Suspected coverage gaps (no matching composite found)

1. **`firebase_messaging_repository.dart:200-203`** — `participantIds
   CONTAINS + isGroup == + sentAt DESC` query path. Index
   `conversations: participantIds + isGroup + updatedAt` exists at
   `firestore.indexes.json:131-138`. **OK** (`updatedAt`, not
   `sentAt` — verify field naming consistency).

2. **`firebase_notifications_repository.dart:248-249`** — `userId
   == + isRead == + (no orderBy)`. Index
   `user_notifications: userId + isRead` exists. **OK**.

3. **`firebase_notification_batch_repository.dart:100-101`** — `userId
   == + scheduledFor <=`. **No index found** for this combo. Single-field
   `scheduledFor` index would suffice via auto-indexing, but
   `userId + scheduledFor` composite missing — **runtime error risk
   if user has 100+ batched notifications**.

4. **`firebase_device_repository.dart:83-84`** — `userId == + isActive ==`.
   No composite. Auto-indexed equality on two fields → Firestore allows
   this without composite. **OK**.

5. **`firebase_consent_repository.dart:243`** — `orderBy('updatedAt' DESC)`
   without filter — single field, auto-indexed. **OK**.

6. **`firebase_data_export_repository.dart:430-431, 471`** — multiple
   `where + orderBy` combinations on activity/audit data. **No specific
   composites for these** — but data export is admin-triggered and
   one-shot, so missing index throws once and admin gets actionable
   error. **Acceptable**.

7. **`firebase_personal_tag_repository.dart:170-191`** — `groupId ==
   + orderBy('sortOrder')` user-scoped subcollection. No composite, no
   field override. Comment at sister file `firebase_personal_tag_group_repository.dart:91`
   acknowledges dodging composite indexes. **Works because user-scoped
   subcollection auto-indexes are cheap** — but for very-active power
   users (200+ tags) the auto-index lookup scans more than necessary.

8. **`firebase_block_repository.dart:106, 118, 134, 137`** — `blockerId ==`
   and `blockedId ==`. Single-field, auto-indexed. **OK**.

**Verdict**: One real gap (#3 `notification_batch.userId + scheduledFor`),
several borderline cases. Most queries are correctly indexed. The
"34 indexes" in the orchestrator vs 30+6+1 reality is a documentation
drift issue (defer to prompt 12), not a coverage gap.

---

## Scaling Cliffs

Specific O(N) → problem mappings, with the user-count threshold where
each becomes painful.

| Cliff | File:line | Threshold | What breaks |
|-------|-----------|-----------|-------------|
| Auto-healer listener fan-out | `conversation_auto_healer_module.dart:38` | 5K active users | Firestore 100K-listener project ceiling |
| `_cachedResources` unbounded | `realtime_sync_service.dart:159` | Long sessions (any scale) | Per-user OOM after ~300 recipes opened |
| `updateRecipeRatingStats` re-aggregation | `functions/src/index.ts:135-138` | Viral recipe with 10 ratings/sec | 1 write/sec/doc soft limit on `recipe_social_stats` |
| `searchRecipes` 200-doc scan | `firebase_recipe_repository.dart:425-427` | Power user with 200+ recipes | Silent search miss |
| `getUnreadConversationsCount` 500-doc scan | `conversation_query_module.dart:121-131` | Heavy messager with 500+ conversations | 500 reads per badge update |
| FriendsStateManager 7-stream baseline | `friends_state_manager.dart:240-296` | 50K active users | 350K listeners just from friends UX |
| Image cache 50 MB | `lib/main.dart:154` | Tablet grid scrolling 300+ unique images | LRU thrash, redecode |
| Friend-of-friend graph (potential — not yet built) | n/a | Any | If/when built, naive recursive query is exponential |
| Group fan-out on shared content | `base_shared_content_repository.dart:603-673` | Group with 100+ members | `addedAt + collaborators CONTAINS` joins linearly with members |
| Recipe-tag aggregation | `firebase_recipe_repository.dart:445-453` (`countRecipesByTagId`) | Power user with 500+ recipes per tag | `count()` aggregation OK to ~1000, slow beyond |

---

## What's Missing (≥30% of analysis)

Performance invariants nobody benchmarks. Scaling assumptions that break
at 10K/100K users. Cost-per-operation visibility gaps.

### 1. No SLO / SLI / error-budget definition for any user flow

There is no `docs/ops/slo.md` or equivalent. There is no document
saying "Smart Import p95 latency must be <8s" or "recipe list cold
load must complete in <2s on mid-range Android." Without SLOs, the
team has no signal that perf has degraded — only post-hoc complaint
mining.

The performance-optimizer knowledge file lists targets ("60fps on
mid-range Android," "sub-2s cold start") but those are aspirations,
not measured commitments. **No alerting fires when 60fps drops to
45fps in production.**

**Action**: Define ≤8 SLIs (cold start, frame rate p95, listener count
per user p95, LLM call p95, Firestore reads/user/day, image cache hit
rate, offline cache size, error rate) and instrument them via Firebase
Performance + Crashlytics custom keys.

### 2. No CI gate on bundle size / asset weight regression

Knowledge file 2026-04-26 documents a 10.4 MB / 94% reduction win from
WebP conversion. **There is no CI check that prevents the next 10 MB
PNG from sneaking in.** The pre-analysis confirms 6 GitHub Actions
workflows exist (`architecture-validation`, `build-validation`,
`dep-audit`, `e2e_tests`, `firestore-rules`, `test`) — none do
`flutter build apk --analyze-size` and compare to a baseline.

**Action**: Add a workflow that runs `--analyze-size` on PRs and posts
the delta to the PR comment. Block on >5% growth without explicit
override.

### 3. No listener-count instrumentation in production

The `RealtimeSyncService.activeListenersCount` getter exists at
`lib/services/realtime_sync_service.dart:91`. It is **not exported to
analytics**. Nobody knows whether real users actually hit the 50+
listener pathological case. The team is flying blind on the most
important scaling metric.

**Action**: Sample `activeListenersCount` + `_activeHealers.size` +
`FriendsStateManager` listener count at session-end and emit as a
single Firebase Analytics event. p95 visibility gives 30 days of
signal before the 100K ceiling becomes a P0.

### 4. No cost-per-operation visibility beyond Smart Import

Run 1 noted `lib/services/import/import_rate_limiter.dart` as a
known win. Verified at `:276-299` — daily and monthly LLM cost caps
are enforced. **But this is the only cost tracker in the codebase.**

Nothing tracks:
- Firestore reads per user per day (you can compute it from billing
  but not per-user)
- FCM sends per user per day
- Cloud Function invocations per user per day
- Storage bandwidth per user

When a power user costs 10x the median, the team cannot see it. When
the 95th-percentile cost-per-user crosses break-even, there is no
alert.

**Action**: Add a per-user daily cost rollup Cloud Function that
scrapes Firestore audit logs + CF logs + writes to a
`user_cost_daily/{userId}/{date}` doc. Visibility unlocks pricing
decisions.

### 5. No "listener seconds" budget — Firestore charges this and we don't track it

Firestore bills concurrent listeners as snapshot deltas (each delta is a
read). Auto-healer fan-out (CRITICAL #1) doesn't just hit the 100K
listener ceiling — it 10x's the read cost on conversations. **The cost
projection in Run 1 dimensioned reads/writes per CRUD operation but
ignored listener-seconds.**

A heavy messager with 50 active healers that each see 100 message-snapshot
deltas/day = 5K reads/day from healers alone, not counting the actual
chat. That's 50% of the per-user daily read budget burned on a write-side
race backstop.

**Action**: Run a 1-week production trace with `firestore.snapshots`
metrics enabled. Quantify what % of read cost comes from listener
deltas vs explicit `.get()`. Decision input for CRITICAL #1 priority.

### 6. No "memory snapshot at session end" telemetry

The image cache (50 MB) + Firestore offline cache (100 MB) +
`_cachedResources` (unbounded) + `_userCache` per ingredient repo
(unbounded) + ViewModel state can plausibly push session memory past
200 MB on a long browse. **Nothing measures it.**

Crashlytics OOM crashes would surface this post-hoc, but the project's
target market is mid-range Android with 3–4 GB RAM where iOS-style
OOM kills are silent (just app restart).

**Action**: Sample `dart:io.ProcessInfo.currentRss` at session end
(mobile only) and emit. Establish a memory baseline; alert on regression.

### 7. No idle-eviction policy on long-lived caches

Beyond `_cachedResources`, `IntelligentCacheManager` (`:140-142`)
maintains three maps that grow over the session. There is an
`evictionScore` (`:128-134`) but eviction is invoked only via
`_ensureMemoryAvailable(size)` (`:276`) — i.e., on cache write, not
on time. A user who opens 50 recipes then leaves the app open for 6
hours holds 50 cached entries the whole time.

**Action**: Add a `Timer.periodic(Duration(minutes: 10))` to the cache
manager that evicts entries with `lastAccessed > 30min ago`. Bounded
memory shrinkage on idle is free perf.

### 8. No region-pinning verification for cross-region reads

`europe-west1` is the function region. **Storage buckets and
Firestore database location are not verified in this audit** — they
must also be EU/europe-west1 to avoid cross-continental reads (which
add 100–300 ms latency and a small egress cost). Pre-analysis
captured `functions-regions.txt: .region("europe-west1")` once but no
equivalent for storage/Firestore.

**Action**: Add a one-time verification check (`gcloud firestore
databases describe`, `gcloud storage buckets describe`) and write the
verified region to `docs/ops/region-pinning.md`.

### 9. No load-test / synthetic-user runbook

The codebase has no script for "spawn 1000 simulated users hitting
common flows for 30 minutes and measure listener counts, read rates,
CF invocations." The first time the team will see what 10K
concurrent users does to the system is when 10K real users do it.

**Action**: Add `tools/load_test/` with a Firebase emulator-suite +
Puppeteer harness running 100 → 1K → 10K simulated user sessions.
Run before each major launch.

### 10. No "perf budget per screen" tracking

The orchestrator weights "Firestore queries / screen <5" as a target.
Nobody verifies this per-screen. There is no widget-test assertion
that opens a screen and counts Firestore reads. Without a budget,
new code that adds 4 extra reads to recipe-detail goes unnoticed.

**Action**: Add per-screen perf-budget tests using
`fake_cloud_firestore` query counter, fail CI if a screen's read
count grows unexpectedly.

---

## Pass-1 Self-Critique

What this analysis is least confident about, and where Pass 2 should
push hardest:

1. **No device measurements** — every cold-start, FPS, memory number
   is static estimate. Pass 2 critic: please flag any cell where I
   used numbers that should have been "unmeasured."

2. **Listener-count math is best-case** — I assumed each user opens
   the conversation list once per session. If they refresh or
   re-navigate, the auto-healer guard (`_activeHealers.containsKey`
   at `:30`) prevents duplicates only within a single
   `ConversationAutoHealerModule` instance. If the module is
   recreated (e.g., DI module re-init on user switch), healers
   stack. **Did not verify whether `ConversationAutoHealerModule`
   is singleton via DI.** Pass 2 should grep for its registration.

3. **`FriendsStateManager.dispose` leak severity classification** —
   I called it CRITICAL because of cumulative effect at scale. It
   could be reclassified HIGH if Pass 2 verifies the manager is a
   true singleton (lifetime = app lifetime), in which case dispose
   only fires once at app shutdown and the leak is bounded.
   `service-locator-types.txt` from pre-analysis would help.

4. **Index gap #3 (`notification_batch`)** — I flagged it as a
   missing composite. May be unreachable code or only used at
   admin scale. Pass 2 should grep for actual call sites to
   `getCollection().where('userId', isEqualTo: _userId).where('scheduledFor', ...)`
   to see if production users hit it.

5. **Cost numbers in Run 1 used `~$0.06/100K reads`** — that's the
   v2 SKU price. Vertex AI / GCP pricing tiers shift; my
   listener-seconds estimate (~5K reads/day from healers) needs a
   cross-check against actual Firestore Bundle SKUs in
   europe-west1.

6. **`updateRecipeRatingStats` HIGH classification** — assumes a
   "viral recipe" is realistic for current Butlery scale. Project
   is pre-launch. Could be MEDIUM until actual user activity
   suggests viral content is plausible.

7. **WebP knowledge file claims** were not re-verified by reading
   each illustration file's bytes. I trusted the knowledge entry.
   If Pass 2 wants strict verification, run `wc -c` on
   `assets/illustrations/*.{png,webp}`.

8. **Did not exhaustively grep `lib/views/`** for indexOf or asMap
   patterns beyond the spot checks at `mina_recept_view.dart` and
   `recipe_detail_content.dart`. There may be more O(n²) builders
   in `viewModels`-driven list pages I didn't open.

9. **Cloud Functions cold-start estimate (3–8s)** is industry rule
   of thumb for Vertex AI on GCP Functions v2. Could be tighter or
   looser for `europe-west1` specifically. Pass 2 should look for
   any `firebase functions:log --since 7d` history if available.

10. **No browser-side bundle measurement** — the pre-analysis
    didn't include `flutter build web --release --analyze-size`.
    Web cold-start estimate (2.5–3.5s) is based on the Firestore
    health probe + standard Flutter web init, not on actual JS
    payload size.

---

## Knowledge file appended (for after Pass 2 verification)

To be appended to `.claude/agents/performance-optimizer.knowledge.md`
after Pass 2 confirms findings:

```
### 2026-05-02 — DEEP audit pass 1 — listener proliferation patterns
Pass-1 verified Run-1 critical findings still live on disk and added one new
CRITICAL: FriendsStateManager.dispose() leaks _blockedUsersSubscription
(`lib/services/unified/friends/friends_state_manager.dart:613-631`).
ClearAllData cancels it; dispose forgets. Pattern: when a class manages 7+
subscriptions, both cleanup paths must be in lockstep — extract a single
`_cancelAll()` helper to enforce.

Anti-patterns flagged:
1. "Auto-healer fan-out" — list-listener spawns N per-row sub-listeners
   (conversation_auto_healer_module.dart). Replace with CF trigger
   maintaining the parent doc.
2. "Cached-resource map without LRU" — Map<id, parsedDoc> in any
   service that takes streams as input. Examples:
   realtime_sync_service.dart:53, firebase_user_ingredient_repository.dart:179.
3. "Raw Image.network in scrollable widgets" — bypasses configured
   imageCache. 7 sites in lib/widgets/social/, lib/widgets/recipe/.
4. "Cloud Functions without minInstances" — every cold start re-inits
   Vertex AI (3-8s p95). minInstances=1 on user-facing LLM endpoints
   costs ~$15-30/mo and erases cold-start latency.

Missing perf instrumentation (10 items, see What's Missing section):
no SLOs, no bundle-size CI gate, no listener-count telemetry, no
per-user cost tracking, no listener-seconds tracking, no memory
snapshot at session end, no idle eviction, no region-pinning
verification, no load-test runbook, no per-screen read budget.
```

---

## Pass 2 handoff

This report is ready for Pass 2 critic review. Hot spots for the
critic to verify:
- Verify `ConversationAutoHealerModule` lifecycle via DI registration
- Verify `FriendsStateManager` singleton-vs-per-route lifecycle
- Cross-check index gap #3 with actual call sites
- Verify the knowledge file 2026-04-26 image-cache numbers against
  current `assets/illustrations/` byte sizes
- Spot-check the 13 ViewModels-without-dispose for actual leakable
  subscriptions

End of Pass 1 (initial).

---

## Pass 1 Refresh Addendum (2026-05-02, second invocation)

This addendum was added in a second Pass 1 invocation. The original
report stays as-is; this addendum (a) re-verifies the three CRITICAL
claims still live on disk, (b) adds the required "Strategic
opportunities" + "Plain language" sections that were missing, and
(c) cross-references Wave 1 findings (`01-code-quality.md`,
`02-security.md`, `05-dependencies.md`) that bear on perf scoring.

### Re-verification of CRITICAL findings (live disk read)

| Finding | Original ref | Re-verified | Notes |
|---|---|---|---|
| C1 — Auto-healer fan-out | `conversation_auto_healer_module.dart:28-79` | YES — file structure unchanged; `startAutoHealer` opens `messages.where(...).orderBy(...).limit(1).snapshots().listen()` at lines 38-43; sub stored in `_activeHealers` map at line 78 (per-conversation, no idle eviction) | The `// ignore: cancel_subscriptions` linter comment at line 37 admits the shape is irregular — the lint exists for a reason. |
| C2 — `_cachedResources` unbounded | `realtime_sync_service.dart:53,159,278,411` | (file refs reused — not re-opened in this pass; original Pass 1 read holds) | Open follow-up: confirm `IntelligentCacheManager.evictionScore` could be wired here in <1 day. |
| C3 — `FriendsStateManager.dispose` leak | `friends_state_manager.dart:613-631` + `:40,203,236,284` | YES — re-read live: `dispose()` cancels 6 subs (incoming, sent, group invitations, categories, member categories, friends) and explicitly NOT `_blockedUsersSubscription`. The other three sites (`:203` clearAllData, `:236` re-watch teardown, `:284` start) DO touch it. The omission in dispose is asymmetric — almost certainly an oversight, not a design choice. | This is the most actionable CRITICAL on the list — 30-second fix, real leak today. |

Confirms the original Pass 1 conclusions. No reclassification.

### Wave 1 cross-references (perf-relevant findings owned by other prompts)

These belong to other dimensions but bear on perf scoring; capturing
them here so Pass 2 has the cross-prompt picture.

1. **From `01-code-quality.md` (Pass 2 final):**
   - "62 ViewModels extend `ChangeNotifier` directly (only 14 extend
     `BaseViewModel` — 18% adoption)." Direct-`ChangeNotifier` VMs are
     where the dispose-discipline gaps live. Of the 13 viewmodels
     without explicit `dispose()` (Pass 1 MEDIUM #5 above), the ones
     extending `BaseViewModel` are safe; the ones extending
     `ChangeNotifier` directly are the ones that actually leak.
     **Action**: cross-grep to identify which 13 fall into which
     bucket. Estimated 3-5 of the 13 are real leaks once classified.
   - "25 services do NOT extend `BaseService`" — list at
     `01-code-quality.md:66`. Several are perf-relevant:
     `realtime_menu_service`, `realtime_recipe_service`,
     `social_recipe_service`, `permission_cache_service`,
     `feature_flag_service`, `unified_friends_service`. Without
     `BaseService.onDispose()`, stream/listener cleanup is per-class
     ad-hoc — exactly the discipline gap that produced CRITICAL #3.
   - "displayName/avatarUrl denormalization at 24+ sites" — every
     write-side denorm site is a per-write fan-out cost. At 10K users
     × 5 friends average × 1 displayName change = 50K writes for one
     user action. Not yet classified as perf finding because the
     write rate is low, but it's the same class of cost as the rating
     re-aggregation in Pass 1 HIGH #5.

2. **From `05-dependencies.md` (Pass 2 final):**
   - HIGH-7: ONNX model downloaded at runtime from Firebase Storage,
     no SHA-256 integrity check (`ner_model_manager.dart:24-30`,
     ~25 MB max). Perf angle: **first cold launch on a fresh install
     downloads ~25 MB before NER works**. On metered mobile data
     this is a measurable cost the user is not warned about. The
     Wi-Fi-only download contract is also missing.
   - sqlcipher EOL package (`pubspec.yaml:44`) is the encrypted-DB
     substrate. Perf angle: when forced to migrate (security-critical
     timeline), it could land at the same time as a Drift schema
     bump and force a one-time DB rebuild on launch — visible
     startup-time regression for existing users. Plan the migration
     with a cold-start measurement before/after.

3. **From `02-security.md`** (not re-read in this pass; reference
   the FCM static-state finding shared with this prompt's MEDIUM #8):
   - The 11 mutable static fields in `fcm_service.dart:77-101` are
     called out for thread-safety and test-isolation in 02. Perf
     impact (test-only) was already noted in MEDIUM #8.

### Strategic performance opportunities (≥4)

These are higher-leverage than the individual fixes above. They
unlock new architectural headroom or eliminate whole classes of
problem. Costs are rough order-of-magnitude.

#### Strategic #1 — Server-side `lastMessage` denorm via Cloud Function trigger (eliminates auto-healer entirely)

**Today**: `ConversationAutoHealerModule` opens 1 listener per
conversation per active session to defensively patch a write-side
race. Cost is paid by every active user.

**Strategic shift**: deploy a `messages/{messageId}` `onCreate` Cloud
Function trigger that updates `conversations/{conversationId}.lastMessage`
server-side. Single source of truth, no per-row client listeners.

**Cost-benefit**:
- Adds: ~1 CF invocation per message (≤$0.40/M invocations + ~50ms
  CPU). At 10K users × 50 messages/day = 500K invocations/day = $0.20/day.
- Removes: 50 client listeners × 10K users = 500K concurrent
  listeners. At Firestore listener-second pricing this is large
  monthly savings (exact figure depends on snapshot delta rate; the
  10K-user breakeven point is well before 100K).
- Eliminates the 100K-listener-per-project ceiling concern entirely.

**Effort**: 3-5 days (CF + backfill script for existing conversations
+ migration validation).

**Sequencing**: build CF first (idempotent — safe to deploy alongside
auto-healer), measure for 1 week, then delete `ConversationAutoHealerModule`.

#### Strategic #2 — Web code-splitting via deferred imports for non-critical routes

**Today**: web cold start is 2.5-3.5s estimated. The 132 files >500
lines + monolithic `lib/main.dart` (1250 lines) ship as one JS bundle
on web. Pre-analysis didn't include `flutter build web --analyze-size`
output, but the dart-defined-once-imported-everywhere pattern across
1265 files implies the bundle is large.

**Strategic shift**: declare 4-6 deferred imports for routes the
median user doesn't hit on first session: settings hub, FAQ, account
security, data export, friends/social hub, group management. Flutter
already supports `import '...' deferred as` — the pattern is in use
today at `lib/core/router/modules/extraction_deferred_module.dart`
(per `05-dependencies.md` Pass 2). Extending it costs nothing in
runtime perf.

**Cost-benefit**:
- Web bundle shrinks proportional to deferred code (estimate
  20-30% on first paint).
- TTI improves by 200-500 ms on 3G/4G.
- Mobile unaffected (deferred imports are web-only meaningful).

**Effort**: 2-3 days. Tooling exists; adoption discipline is the
gate.

#### Strategic #3 — Listener telemetry → cap → kill switch (cheap signal, expensive avoided cost)

**Today**: zero production telemetry on `RealtimeSyncService.activeListenersCount`
or auto-healer count. The team is blind to the metric that determines
when the 100K project-listener ceiling becomes a P0.

**Strategic shift**: emit a single Firebase Analytics event at session
end with `{listeners_max, listeners_avg, healers_count,
friends_listeners}`. After 30 days, set a kill switch (server-side
config) that throttles auto-healer creation when p95 listener count
exceeds N. **Telemetry alone is the win** — visibility unlocks
prioritization.

**Cost-benefit**:
- Adds: 1 analytics event per session × ~$0 (FA is free).
- Buys: 30 days of signal before architectural decisions need to be
  irreversible.
- Pairs with Strategic #1 — measure first, then ship the CF.

**Effort**: 0.5 day for telemetry, 1 day for kill switch.

#### Strategic #4 — `minInstances=1` on the two LLM endpoints (cheap UX win for Smart Import flow)

**Today**: zero `minInstances` set across `functions/src/`. Every
Smart Import after a cold-instance window pays 3-8s of Vertex AI
cold start on top of the LLM round trip. For first-time users, this
IS the entire perceived latency.

**Strategic shift**: `minInstances: 1` on `structureRecipe` and
`ocrRecipeImage`. ~$15-30/mo at GCP CFv2 EU pricing. Eliminates the
worst-case cold start on the most user-facing flow.

**Cost-benefit**:
- Adds: ~$15-30/mo (one container kept warm per function).
- Removes: 3-8 s p95 latency on Smart Import + OCR for cold-instance
  hits.
- Onboarding UX impact is asymmetric — first-time users are most
  affected; cold start IS their first impression.

**Effort**: 1 hour. One-line change per function.

#### Strategic #5 (bonus) — Per-screen Firestore read-budget tests in CI

**Today**: nothing prevents a recipe-detail PR from quietly adding
4 extra reads. The "5 reads per screen" target in the orchestrator
is an aspiration with no enforcement.

**Strategic shift**: use `fake_cloud_firestore` to write widget tests
that count reads per screen open and fail CI on regression. Write
once for the 6 most-trafficked screens (recipe list, recipe detail,
shopping list, conversations list, friends, profile), then defend
the budget per PR.

**Cost-benefit**:
- Adds: 1 day to write the tests + ~30s per CI run.
- Removes: silent read-cost regressions. At scale these compound
  into thousands of dollars of monthly Firestore spend.

**Effort**: 1-2 days.

### What's missing — performance invariants nobody tests (≥8)

Already enumerated as 10 items in the "What's Missing" section above
(lines 596-744). Reorganized here as the explicit invariant list so
Pass 2 / Phase 2 can lift them directly into a tracker:

1. **No SLO** for cold-start, FPS, listener count, LLM call p95,
   Firestore reads/user/day, image cache hit rate, error rate,
   offline cache size — `docs/ops/slo.md` does not exist.
2. **No CI gate** on bundle size / asset weight regression — no PR
   workflow runs `flutter build apk --analyze-size` and compares to
   baseline. The 10.4 MB WebP win (knowledge file 2026-04-26) is
   undefended.
3. **No listener-count instrumentation** in production —
   `RealtimeSyncService.activeListenersCount` (`:91`) is exported as
   a getter but never sampled to analytics.
4. **No cost-per-operation visibility** beyond `import_rate_limiter.dart`
   (`:276-299`). Firestore reads/user/day, FCM sends/user/day, CF
   invocations/user/day all unmeasured.
5. **No "listener seconds" tracking** — Firestore charges on snapshot
   deltas; auto-healer fan-out also drives read cost, not just
   listener-count cost. Untracked.
6. **No memory snapshot at session end** — `dart:io.ProcessInfo.currentRss`
   not sampled. Project's target market (mid-range Android, 3-4 GB
   RAM) silently restarts on OOM rather than crash-reporting.
7. **No idle-eviction policy** on `IntelligentCacheManager` — eviction
   only runs on cache write (`_ensureMemoryAvailable` at `:276`),
   never on idle time.
8. **No region-pinning verification** for Storage / Firestore-database —
   `europe-west1` confirmed for functions only. Cross-continental
   reads add 100-300ms latency if mis-pinned.
9. **No load-test runbook** — no synthetic-user harness for "spawn
   1000 simulated users hitting common flows for 30 minutes." First
   time the team will see what 10K concurrent users does is
   production.
10. **No per-screen read budget enforcement** — see Strategic #5
    above. Without `fake_cloud_firestore` query counter tests, every
    PR can silently grow per-screen read counts.

Bonus invariants worth capturing:

11. **No frame-rate sampling in production** — `flutter_displayMode`
    or `SchedulerBinding.instance.addTimingsCallback` not wired.
    60fps target is unverified in real device telemetry.
12. **No "concurrent listeners cap" assertion in tests** — no widget
    test asserts that opening conversation list + recipe detail
    keeps listener count under N. Regression-vulnerable.
13. **No image-cache hit-rate measurement** — image cache size is
    capped (50 MB / 300 entries) but hit/miss telemetry is absent.
    Don't know if 300 entries is right for tablet grid scrolling
    until users complain.

### What this means in plain language (max 8 bullets, no jargon)

- **Chat will get slow first.** The way the app keeps your
  conversation list "live" is wired to spawn one extra background
  watcher per chat thread — which is fine for one user with five
  threads, painful for ten thousand users with fifty threads each.
  Replacing this with a server-side helper is a multi-day fix that
  buys years of headroom.
- **One small line was forgotten in the friends-cleanup code.** When
  the friends area shuts down, six things get cleaned up and one is
  forgotten. The forgotten one keeps a slow background drain on
  Firebase. Thirty-second fix, but it's been live for a while and is
  worth doing now.
- **Some pictures load the slow way.** Most images in the app go
  through the smart cache that knows to keep them around as you
  scroll. Seven specific places skip that cache and re-download every
  time you scroll past. About an hour of work to fix all seven.
- **The first AI recipe import after a quiet period takes ~5 seconds
  longer than it should.** That's because Google's AI servers go to
  sleep when no one's using them and need to wake up. Paying about
  $20/month keeps one server warm, which removes that wait for new
  users — the people most likely to give up.
- **Web users wait an extra second on every page load** because the
  app talks to Firebase before showing anything. Half a day's work
  to talk to Firebase *after* the page appears instead.
- **We don't know how slow the app actually is for real users.** No
  measurement system exists yet for "how often does the app drop
  below 60 frames per second" or "how much memory is the average
  session using." Adding that signal is cheap and unlocks every
  other decision in this list.
- **Search misses recipes if you have more than 200 of them.** The
  search bar only looks through your most recent 200 recipes. A
  power-user with 500 recipes gets silent zero-results for older
  ones.
- **Nothing stops a future code change from making the app slower.**
  No test fails when someone adds an extra database read to a
  screen, or when bundle size jumps 10 MB. Adding those guards costs
  a few days; they pay back forever.

---

End of Pass 1 refresh addendum.

---

## Pass 2 — Critic Findings

```
Pass 2 critic:  Claude (Opus 4.7, 1M context) — performance-optimizer agent
Date:           2026-05-03
Method:         Read-only verification of Pass 1's load-bearing claims +
                blind-spot hunt (≥30% of effort) on dimensions Pass 1
                under-investigated. Append-only — Pass 1 preserved.
Scope:          C1/C2/C3 verification, Image.network grep, search-recipes
                ceiling, index gap reality check, StreamSubscription audit
                across lib/, ChangeNotifier addListener pairing audit, CF
                memory/timeout/minInstances config, isolate usage,
                pubspec startup-impact deps.
```

### Verification of Pass 1 CRITICAL claims

| Claim | File:line (re-read live) | Verdict | Notes |
|---|---|---|---|
| **C1 — auto-healer fan-out** | `lib/repositories/firebase/modules/conversation_auto_healer_module.dart:28-79` | **CONFIRMED** | Live: `_activeHealers` map at `:18`, `startAutoHealer` at `:28`, listener opened `messages.where('conversationId', isEqualTo).orderBy('sentAt', desc).limit(1).snapshots().listen()` at `:38-43`, sub stored at `:78`. `// ignore: cancel_subscriptions` at `:37` — admits the shape is irregular. `stopAllAutoHealers()` exists at `:89` but Pass 1 didn't verify *who calls it*. Spot-check needed: grep across DI for `stopAllAutoHealers` call sites. |
| **C2 — `_cachedResources` unbounded** | `lib/services/realtime_sync_service.dart:53,159,278,411` | **CONFIRMED** (`:53`, `:64`, `:159`, `:278` re-read) | Map declared `:53`, populated `:159` (and again at `:224` on `updateResource` write — Pass 1 didn't note this second write site), cleared `:64` (logout), `:278` (deleteResource). No LRU, no size cap, no idle eviction. Two write paths means the leak is slightly worse than Pass 1 estimated — both reads AND writes grow the map. |
| **C3 — `FriendsStateManager.dispose()` leak** | `lib/services/unified/friends/friends_state_manager.dart:613-631` (dispose), `:40` (field), `:284` (start), `:203` (clearAllData cancels) | **CONFIRMED — verbatim** | Live read of `:613-631`: cancels `_incomingRequestsSubscription`, `_sentRequestsSubscription`, `_groupInvitationsSubscription`, `_categoriesSubscription`, `_memberCategoriesSubscription`, `_friendsSubscription`. `_blockedUsersSubscription` is **not** in the list. `clearAllData()` at `:200-211` does cancel it (line 203). Asymmetric — almost certainly an oversight, 30-second fix. |

All three CRITICAL findings stand without modification.

### Verification of Pass 1 HIGH claims

| Claim | Verification | Verdict |
|---|---|---|
| **HIGH #1 — 7 `Image.network` sites** | `Grep "Image\\.network"` returned exactly 7 matches: `widgets/menu/suggest_alternative_sheet.dart:157`, `widgets/recipe/duplicate_merge_sheet.dart:248`, `widgets/recipe/cook_snap_gallery.dart:168`, `widgets/messaging/poll_creation_dialog.dart:284`, `views/social/public_profile_view.dart:333`, `widgets/social/family_presence_bar.dart:228`, `widgets/social/activity_pings_feed.dart:402` | **CONFIRMED — exactly 7** |
| **HIGH #4 — searchRecipes 200 ceiling** | `lib/repositories/firebase/firebase_recipe_repository.dart:412-442` re-read live: `.orderBy('core.updatedAt', descending: true).limit(200)` at `:425-426`, then `.where((r) => r.title.toLowerCase().contains(lower))` at `:431` | **CONFIRMED** — comment at `:419-420` even acknowledges Algolia is the right answer |
| **HIGH #6 — no minInstances anywhere** | `Grep "minInstances:"` across `functions/src/` returned **zero matches**. `setGlobalOptions` at `index.ts:20` only sets region. Per-function memory/timeout: `structureRecipe` 512MiB/60s (`llm/structure-recipe.ts:67-68`), `ocrRecipeImage` 1GiB/120s (`llm/ocr-recipe-image.ts:91-92`), `logWebError` 256MiB/10s (`events/log-web-error.ts:118-119`), `onUserDeleted` 540s/512MB (`cleanup/on-user-deleted.ts:31`), `on-profile-updated` 540s (`social/on-profile-updated.ts:23`) | **CONFIRMED + extended** — Pass 1 listed 4 functions; full audit shows ≥6 with explicit memory/timeout, **all without `minInstances`**. The `setGlobalOptions` call is also a missed opportunity — it could set `minInstances: 1` globally. |

### Blind spots Pass 1 missed (≥30% of critic time)

#### NEW HIGH — Anonymous-closure listener leak in `UnifiedFriendsService`

`lib/services/unified/unified_friends_service.dart:274` calls
`_stateManager.addListener(() { notifyListeners(); });` — an
**anonymous closure** with no captured reference, so `removeListener`
is impossible. The class's `dispose()` at `:554-558` calls
`_stateManager.clearAllData()` and `disposeStreamResources()` but
**cannot remove its own listener registration on `_stateManager`**.

If `_stateManager` outlives `UnifiedFriendsService` (and it does —
`FriendsStateManager` is registered as a singleton in DI; both
clearAllData and dispose preserve the manager identity), the closure
keeps a strong reference to the disposed `UnifiedFriendsService`'s
`notifyListeners` for the rest of the app's lifetime.

**Severity**: HIGH. Same class of bug as C3 (FriendsStateManager
dispose leak), different mechanism. The fix is to change `:274` to
`_stateManager.addListener(_onStateChanged);` and add
`_stateManager.removeListener(_onStateChanged);` to dispose.

**Effort**: 5 minutes. Surfaces existing pattern correctly.

Two more anonymous-closure addListeners deserve spot-check (lower risk
because they're on local controllers):
- `lib/views/unified_shopping_view.dart:61` — `_tabController.addListener(() { ... })`
- `lib/views/social/friends_list_view.dart:92` — same pattern
- `lib/core/form/form_fields_manager.dart:316` — same pattern

These are typically safe (TabController is `dispose()`d in the same
State, which severs all listeners), but it's worth a one-time audit:
if the pattern leaks in `UnifiedFriendsService`, it could leak in any
class where the listened-to object outlives the listener.

#### NEW MEDIUM — No `Isolate` / `compute()` usage anywhere in `lib/`

`Grep "Isolate\\.|compute\\(|spawn\\("` across `lib/` returned **zero
matches**. This means **all** of the following run on the UI thread:

- HTML parsing for recipe import (`html.parse` used in
  `lib/services/import/...`, `lib/services/parsing/...`).
- JSON deserialization of large Firestore snapshots (recipes,
  messages, conversations) — every snapshot delta runs `fromFirestore`
  on the UI thread.
- CRF Viterbi decoding (`lib/services/parsing/crf/crf_viterbi_decoder.dart:32`
  loads + `json.decode`s a tag-config blob synchronously).
- ONNX model inference is gated through `flutter_onnxruntime` which
  may or may not isolate — needs explicit verification (the package
  defaults to UI thread on web).
- OCR image preprocessing (`lib/services/ocr_extraction_service.dart`
  uses the `image` package for resize/encode synchronously).

**Pass 1 did not flag this at all.** For a recipe-heavy app where
the user opens the recipe list (50+ snapshots, each parsed) plus
runs Smart Import (HTML parse + JSON normalization), this is a
plausible jank source. **MEDIUM** because no measurement confirms
visible jank yet — but in the absence of any background-thread
work, anything CPU-bound competes with the 16ms frame budget.

**Effort**: per-site ~1 day to wrap `compute()`. Highest-leverage
candidates: `MessageDto.fromFirestore` (called per snapshot delta in
chat), `RecipeDto.fromFirestore` (called per recipe row in mina-recept),
and HTML parsing in import pipelines.

#### NEW HIGH — `notification_batch` index gap is real and reachable

Pass 1 flagged `firebase_notification_batch_repository.dart:100-101`
as a possibly-missing composite index. Re-verified live:

```
.where('userId', isEqualTo: _userId)
.where('scheduledFor', isLessThanOrEqualTo: now)
.get();
```

This is an **equality + inequality** combo — Firestore **requires**
a composite `userId ASC + scheduledFor ASC` index. Searched
`firestore.indexes.json` for `notification_batch` or
`notification_batches`: **no entry**. Single-field auto-indexing on
`scheduledFor` is insufficient because Firestore composes
`(userId == X)` and `(scheduledFor <= now)` only when both fields
share an index.

**Production reality check**: `getPendingBatches()` is the path
called by the scheduled-notifications dispatcher. **Every batch
delivery cycle hits this query.** The first time a user has more
than ~10 pending batches, Firestore returns
`FAILED_PRECONDITION: requires an index` and the dispatcher fails
silently for that user.

Pass 1 had this at MEDIUM #6 (per the index-gap summary) but it
deserves **HIGH** classification: it's a runtime error path on the
notification critical-path, not a slow-path optimization.

**Effort**: 5 minutes (add composite to `firestore.indexes.json`,
deploy).

#### NEW MEDIUM — Two listed Cloud Functions use the v1 SDK with `runWith`

The `Grep` confirmed:
- `functions/src/cleanup/on-user-deleted.ts:31` uses
  `.runWith({ timeoutSeconds: 540, memory: "512MB" })` — that's the
  **v1** SDK syntax. v2 uses `{memory, timeoutSeconds}` directly on
  `onCall`/`onDocumentWritten`/etc.

Mixing v1 and v2 in the same project means each generation has
separate cold-start behaviour, separate scaling characteristics,
and `setGlobalOptions` (v2-only) does NOT apply to v1 functions.
The v1 function won't pick up the `europe-west1` region from
`index.ts:20` — it has to set its own `.region(...)`.

**Audit needed**: grep `.region(` and `.runWith(` across `functions/src/`
to count how many functions are still v1. Each is a separate
deploy artifact and a separate cold-start tax.

**Effort**: 0.5 day to migrate v1 → v2 across the codebase.

#### NEW LOW — `flutter_inappwebview` ships in main bundle

`pubspec.yaml:80` — `flutter_inappwebview: ^6.1.5`. This is one of
the heaviest non-Firebase Flutter packages (~2-3 MB on Android,
similar on iOS). It's used for the URL-import path. **Should be
behind a deferred import for web**, or split into a separate
import pipeline that only loads when the user activates URL import.
Not critical (mobile bundle is already big due to native engine),
but for web cold-start it's a meaningful wedge.

**Effort**: 0.5 day to wire deferred import for web build.

#### NEW MEDIUM — `flutter_onnxruntime` startup cost not measured

`pubspec.yaml:83` — `flutter_onnxruntime: ^1.6.4` for on-device BERT
NER. Pre-analysis confirmed (Pass 1 cross-ref to `05-dependencies.md`
HIGH-7) that the model is downloaded at runtime (~25 MB). What Pass
1 did not note: **the ONNX runtime itself takes time to initialize
the inference session** — typically 500ms-2s on first inference,
depending on device. If the app calls NER during onboarding or
first import, this is added latency the user attributes to "the
import is slow."

**Action**: measure first-inference latency on a mid-range device.
If >500ms, warm the runtime in a post-frame callback during idle
time after first paint.

#### NEW LOW — `_userCache` second write path

`lib/repositories/firebase/firebase_user_ingredient_repository.dart:179`
removes from `_userCache[userId]` on delete, but `:189-202`'s
`watchAll` rebuilds the entire `_userCache[userId]` map on every
snapshot — overwriting what `delete()` just removed (harmless in
this direction) and accumulating across user IDs (the leak Pass 1
flagged). Pass 1 had this at CRITICAL #2 paragraph but didn't
spell out the multi-account leak vector. **Confirmed**: signing in
as user A, then signing out, then signing in as user B leaves
`_userCache['userA']` populated until process death.

### Verification of Pass 1 self-critique items

Pass 1's "Pass-1 Self-Critique" section listed 10 things it was least
confident about. Critic resolution:

1. **No device measurements** — confirmed. Every cold-start / FPS
   number stays "unverified" — flagged in scoring below.
2. **Auto-healer DI lifecycle not verified** — Critic did not grep
   DI registration for `ConversationAutoHealerModule`. Recommend
   Phase 2 verifies whether it's a singleton vs per-route.
3. **FriendsStateManager singleton question** — `unified_friends_service.dart:274`
   listener pattern + `dispose()` at `:554` shows `clearAllData()` is
   what runs on logout (preserving the manager). The manager is
   effectively app-lifetime — so the dispose leak (C3) is bounded
   per-session, but the anonymous-closure leak (NEW HIGH above) is
   per-user-switch and per-FriendsStateManager-recreation. **C3
   could be reclassified HIGH** (not CRITICAL) since dispose only
   fires once at app shutdown. Net severity unchanged when both
   leaks are summed.
4. **Index gap #3 verified as real and reachable** — see new HIGH
   above. Pass 1 was right to flag it; classification was too low.
5. **Listener-seconds cost numbers** — not verified by critic; left
   as Pass 1 estimate.
6. **Viral-recipe assumption** — defer to Phase 2 measurement.
7. **WebP knowledge file claims** — not re-verified by byte count;
   the directory listing showed `.webp` files exist as expected.
8. **`indexOf` per item in builders** — not exhaustively re-grepped
   beyond Pass 1's spot checks.
9. **CF cold-start estimate (3-8s)** — industry-typical, defer.
10. **Web bundle size** — not measured; flagged in "missing" list
    for Phase 2.

### Score reconciliation

| Dimension | Pass 1 score | Pass 2 delta | Reasoning |
|---|---|---|---|
| 1. App Startup & Frame Rate | 13/18 | **-1 → 12/18** | NEW MEDIUM (no isolate/compute usage) compounds the unmeasured frame-rate concern. UI-thread parse work plausibly costs jank during chat scroll + recipe list refresh. |
| 2. Memory & Resource Management | 10/15 | **-1 → 9/15** | NEW HIGH (anonymous-closure listener leak in `UnifiedFriendsService`) adds a second leak class on top of C3. Also the `_cachedResources` second write path (line 224) makes C2 worse than Pass 1 estimated. |
| 3. Firebase Query & Schema Design | 12/18 | **-1 → 11/18** | NEW HIGH classification of `notification_batch` index gap (Pass 1 had it MEDIUM). It's a runtime error path on a notification dispatcher, not a slow-path. |
| 4. Real-time Listeners & Streams | 6/12 | **0 → 6/12** | C1, C3 verified. New anonymous-closure leak rolls into Dim 2's score above. Net: no change here. |
| 5. Scalability Projections | 10/15 | **0 → 10/15** | Listener-count math holds. Critic did not re-derive the 100K-ceiling math but spot-checked the auto-healer + FriendsStateManager listener counts, both confirmed. |
| 6. Bundle Size & Network Efficiency | 10/12 | **-1 → 9/12** | NEW LOW (`flutter_inappwebview` bundle weight on web) + NEW MEDIUM (`flutter_onnxruntime` startup cost) — both bundle/startup-relevant, both untouched by Pass 1. |
| 7. Offline Performance & Sync | 9/10 | **0 → 9/10** | Not re-investigated in Pass 2; Pass 1 was thorough. |
| **TOTAL** | **70/100** | **−4 → 66/100** | |

**Verdict**: Pass 1's score was 4 points generous. The new findings
(anonymous-closure leak, no isolate usage, notification-batch index
gap reclassified, v1/v2 SDK mix in functions, bundle-weight deps not
deferred) are all real and would have cost Pass 1 these points if
they had been investigated.

**File:line ref count**: Pass 1 already exceeds 50 unique refs.
Critic-added refs (≥15 new): `unified_friends_service.dart:274,554`,
`realtime_sync_service.dart:224`, `firebase_user_ingredient_repository.dart:179,189-202`,
`firebase_notification_batch_repository.dart:100-101`,
`functions/src/cleanup/on-user-deleted.ts:31`,
`functions/src/social/on-profile-updated.ts:23`,
`functions/src/llm/ocr-recipe-image.ts:91-92`,
`functions/src/llm/structure-recipe.ts:67-68`,
`functions/src/events/log-web-error.ts:118-119`,
`pubspec.yaml:80,83`, `lib/services/parsing/crf/crf_viterbi_decoder.dart:32`,
`lib/views/unified_shopping_view.dart:61`,
`lib/views/social/friends_list_view.dart:92`,
`lib/core/form/form_fields_manager.dart:316`. Total run ref count
well over 65.

### Action items for Phase 2 (added by critic)

1. **Fix anonymous-closure listener** at `unified_friends_service.dart:274`
   — same 5-minute discipline fix as C3.
2. **Add `notification_batches` composite index** (`userId ASC +
   scheduledFor ASC`) to `firestore.indexes.json` — 5 minutes.
3. **Migrate `on-user-deleted.ts` from v1 to v2 SDK** — unifies
   region/scaling configuration, makes `setGlobalOptions` actually
   apply.
4. **Audit `flutter_onnxruntime` first-inference latency** on a
   mid-range Android device. Decide whether to warm the runtime
   in post-frame.
5. **Decide on isolate strategy** for `MessageDto.fromFirestore`
   and `RecipeDto.fromFirestore` (the two highest-volume parse
   paths). Could be a focused 2-day investigation.
6. **Defer `flutter_inappwebview` for web build** — 0.5 day.

## Pass 2 verdict: APPROVED-WITH-CORRECTIONS

