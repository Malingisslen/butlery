### Executive Summary
```text
BUTLERY PERFORMANCE & SCALABILITY ANALYSIS -- PHASE 1
======================================================
Analysis Date: 2026-05-04
Analyst: Codex (GPT-5)
Firebase Project: butlery-app-1
Platforms: Android, iOS, Web, macOS, Windows

OVERALL SCORE: 47/100
  1. App Startup & Frame Rate:         8/18
  2. Memory & Resource Management:     8/15
  3. Firebase Query & Schema Design:   7/18
  4. Real-time Listeners & Streams:    6/12
  5. Scalability Projections:          6/15
  6. Bundle Size & Network Efficiency: 8/12
  7. Offline Performance & Sync:       4/10

STATUS: Critical Issues

CRITICAL ISSUES: 2 found
HIGH PRIORITY:   13 found
MEDIUM PRIORITY: 11 found
LOW PRIORITY:    7 found
```

### Performance Benchmarks Table

Modeling note: Runtime profiling traces are not present in the pre-analysis artifact set, so current values are engineering estimates from startup/query/listener code paths and known test/analyze outputs (`docs/analysis/runs/2026-05-codex/_pre-analysis/SUMMARY.md:7-20`, `lib/main.dart:165-244`, `lib/core/bootstrap/application_bootstrap.dart:293-301`, `lib/core/di/di_container.dart:228-252`, `lib/repositories/firebase/firebase_recipe_repository.dart:366-372`, `lib/repositories/firebase/firebase_notifications_repository.dart:314-320`, `lib/repositories/firebase/modules/conversation_query_module.dart:31-37`).

| Metric | Current (est.) | Target | Gap | Status |
|---|---:|---:|---:|---|
| Cold start time | 3.8-6.0s | < 2.0s | +1.8-4.0s | At risk |
| Warm start time | 1.4-2.2s | < 1.0s | +0.4-1.2s | At risk |
| Average FPS | 52-58fps | 60fps | -2 to -8fps | Likely below target |
| Jank percentage | 2-6% | < 1% | +1-5% | At risk |
| Memory usage (typical) | 160-220MB | < 150MB | +10-70MB | At risk |
| Memory usage (peak) | 260-340MB | < 250MB | +10-90MB | At risk |
| Bundle size (Android) | Not captured | < 50MB | Unknown | Unverified |
| Firestore queries/screen | 8-15 | < 5 | +3-10 | Above target |
| Data transfer/hour | 8-20MB | < 5MB | +3-15MB | Above target |
| Offline features | ~70% | 100% | -30% | Critical gap |

### Firestore Collection Structure Map

| Collection Path | Scope | Fields Used in Queries | Query Patterns / Index Status | Issues |
|---|---|---|---|---|
| `users/{userId}/recipes` | User-scoped | `core.updatedAt` (Timestamp), `core.personalTagIds` (array), `core.personalTags` (array of maps) (`lib/repositories/firebase/firebase_recipe_repository.dart:369-371`, `lib/repositories/firebase/firebase_recipe_repository.dart:498-500`, `lib/repositories/firebase/firebase_recipe_repository.dart:515-527`) | Live stream capped at 100 (`lib/repositories/firebase/firebase_recipe_repository.dart:369-371`); multiple tag/search scans (`lib/repositories/firebase/firebase_recipe_repository.dart:498-500`, `lib/repositories/firebase/firebase_recipe_repository.dart:871-873`) | Client-side filtering and unbounded tag maintenance scans |
| `users/{userId}/shopping_lists` + `items` subcollection | User-scoped | `updatedAt`, item docs (`lib/repositories/firebase/modules/shopping_repository_query_module.dart:39-50`, `lib/repositories/firebase/modules/shopping_repository_query_module.dart:129-132`) | Personal stream capped at 20 (`lib/repositories/firebase/modules/shopping_repository_query_module.dart:129-132`) | `readAll()` loops each list and fetches items subcollection (N+1) |
| `user_notifications` | Global with `userId` filter | `userId`, `isRead`, `createdAt` (`lib/repositories/firebase/firebase_notifications_repository.dart:305-319`) | Stream capped at 50 (`lib/repositories/firebase/firebase_notifications_repository.dart:318-319`); indexes exist for `userId+isRead` and `userId+createdAt` (`firestore.indexes.json:189-203`) | Healthy cap present |
| `conversations` | Global | `participantIds` array, `updatedAt` (`lib/repositories/firebase/modules/conversation_query_module.dart:33-36`) | Stream capped at 50 (`lib/repositories/firebase/modules/conversation_query_module.dart:35-36`); composite indexes exist (`firestore.indexes.json:123-137`) | Healthy cap present |
| `conversations/{id}/participants` | Subcollection | participant docs (`lib/repositories/firebase/modules/conversation_participant_module.dart:264-269`) | Unbounded snapshots (`lib/repositories/firebase/modules/conversation_participant_module.dart:264-269`) | Broad live stream per conversation |
| `shared_content/{id}/members` + parent docs | Global shared | `members.userId` and parent content IDs (`lib/repositories/firebase/base_shared_content_repository.dart:633-637`, `lib/repositories/firebase/base_shared_content_repository.dart:662-665`) | `collectionGroup('members')` then per-doc fetch via `Future.wait` | N+1 fan-out per page |
| `unified_shared_shopping_lists` (via `sharedListsRef`) | Global shared | dynamic `memberPermissions.{uid}`, `updatedAt` (`lib/repositories/firebase/modules/shopping_repository_query_module.dart:144-147`) | Query shape uses dynamic map field + inequality (`lib/repositories/firebase/modules/shopping_repository_query_module.dart:144`) | Index mismatch risk: current indexes define `collaborators` for `shared_shopping_lists`, not dynamic `memberPermissions.*` (`firestore.indexes.json:81-86`) |
| `reports` | Global | `status`, `createdAt` (`lib/services/moderation/report_service.dart:108-110`) | Unbounded snapshots on open reports (`lib/services/moderation/report_service.dart:105-114`) | Broad admin stream can grow without cap |
| `ingredients` | Global | full-collection cache load (`lib/repositories/firebase/firebase_ingredient_repository.dart:102-103`, `lib/repositories/firebase/firebase_ingredient_repository.dart:153-158`) | Entire collection read into memory | Startup/network cost scales with ingredient catalog size |
| `menus` + `realtime_menus` | Global/shared | `sharedByUserId`, `participantIds` (`lib/services/unified/unified_menu_service.dart:193-195`, `lib/services/unified/unified_menu_service.dart:209-212`) | Both reads unbounded `.get()` | Unbounded load on initialization |
| `users/{userId}/friend_categories` | User-scoped | `friendUserIds` (`lib/repositories/firebase/friends/friend_category_repository.dart:332-346`) | One unbounded stream (`lib/repositories/firebase/friends/friend_category_repository.dart:332-334`) and one capped at 200 (`lib/repositories/firebase/friends/friend_category_repository.dart:345-346`) | Owner stream can grow unbounded |
| `users/{userId}/pantry` / `users/{userId}/personal_tags` / `users/{userId}/personal_tag_groups` / `users/{userId}/ingredients` | User-scoped | pantry/tag/group/ingredient docs (`lib/repositories/firebase/firebase_pantry_repository.dart:89-91`, `lib/repositories/firebase/firebase_personal_tag_repository.dart:94-97`, `lib/repositories/firebase/firebase_personal_tag_repository.dart:190-193`, `lib/repositories/firebase/firebase_personal_tag_group_repository.dart:94-97`, `lib/repositories/firebase/firebase_user_ingredient_repository.dart:190-193`) | All use unbounded snapshots | Listener cost and memory scale linearly with collection growth |

### Cost Analysis

Assumptions for estimate: per-user read/write activity modeled from current query caps and listener patterns (recipes 100, notifications 50, conversations 50, shopping 20+20, comments 50, plus uncapped paths) (`lib/repositories/firebase/firebase_recipe_repository.dart:68`, `lib/repositories/firebase/firebase_recipe_repository.dart:366-372`; `lib/repositories/firebase/firebase_notifications_repository.dart:314-320`; `lib/repositories/firebase/modules/conversation_query_module.dart:31-37`; `lib/repositories/firebase/modules/shopping_repository_query_module.dart:129-147`; `lib/repositories/firebase/firebase_comments_repository.dart:430-434`; unbounded streams in map above).

| Scale | Active Users | Est. Reads/Day | Est. Writes/Day | Est. Monthly Cost | Per User/Month |
|---|---:|---:|---:|---:|---:|
| Current | 1,000 | 450,000 | 90,000 | $13 | $0.013 |
| 10x | 10,000 | 5,500,000 | 1,200,000 | $164 | $0.016 |
| 100x | 100,000 | 70,000,000 | 18,000,000 | $2,232 | $0.022 |
| 1000x | 1,000,000 | 950,000,000 | 250,000,000 | $30,600 | $0.031 |

Cost hot spots:
- Full-scan rating recompute on each rating write/delete (`functions/src/index.ts:135-138`, `functions/src/index.ts:172-183`, `functions/src/index.ts:226-307`).
- Unbounded startup/menu/ingredient reads (`lib/services/unified/unified_menu_service.dart:191-195`, `lib/services/unified/unified_menu_service.dart:209-212`; `lib/repositories/firebase/firebase_ingredient_repository.dart:153-158`).
- N+1 content/list hydration patterns (`lib/repositories/firebase/base_shared_content_repository.dart:662-665`; `lib/repositories/firebase/modules/shopping_repository_query_module.dart:43-50`).

Break-even guidance:
- Firebase-only remains workable at current/10x.
- At ~100x DAU, super-linear hotspots should be re-architected (aggregation + fan-out + unbounded listeners) before cost and latency drift become severe (`functions/src/index.ts:135-138`; `functions/src/social/on-profile-updated.ts:23`, `functions/src/social/on-profile-updated.ts:60-149`).

### Scalability Limits Table

| Bottleneck | Hits at | Impact | Mitigation Effort |
|---|---:|---|---:|
| Blocking startup chain before first frame | Current (1x) | Cold start consistently above target; slow first interaction (`lib/main.dart:165-244`, `lib/core/bootstrap/application_bootstrap.dart:293-301`) | 3-5 days |
| Ingredient full-cache load (`ingredients.get()`) | ~10x data growth | Startup and memory grow with catalog size (`lib/repositories/firebase/firebase_ingredient_repository.dart:153-158`) | 2-4 days |
| Rating full-scan aggregation trigger | ~100x activity or highly-rated recipes | Write amplification and trigger latency spikes (`functions/src/index.ts:135-138`, `functions/src/index.ts:172-183`) | 4-7 days |
| Profile propagation fan-out trigger | ~100x social graph density | Long-running updates near function timeout (`functions/src/social/on-profile-updated.ts:23`, `functions/src/social/on-profile-updated.ts:60-149`) | 5-8 days |
| Unbounded streams (pantry/tags/participants/reports) | ~10x active power users | Read cost and RAM grow per open session (`lib/repositories/firebase/firebase_pantry_repository.dart:89-91`, `lib/repositories/firebase/firebase_personal_tag_repository.dart:94-97`, `lib/repositories/firebase/modules/conversation_participant_module.dart:264-269`, `lib/services/moderation/report_service.dart:105-114`) | 2-5 days |
| Offline delete not synced | Current (1x) | Cross-device data divergence and loss of delete intent (`lib/services/offline/offline_user_storage.dart:121-125`, `lib/services/offline/offline_sync_manager.dart:113-166`) | 1-2 days |

### Detailed Findings by Dimension

## 1) App Startup & Frame Rate -- Score: 8/18

### Summary
Startup has a long synchronous critical path before `runApp`, including Firebase init, Firestore setup/recovery logic, App Check activation, module bootstrap, and consent-gated collection toggles (`lib/main.dart:165-244`, `lib/main.dart:263-296`, `lib/main.dart:313-315`). DI configuration is partially serial, and bootstrap stages run sequentially (`lib/core/di/di_container.dart:228-231`, `lib/core/bootstrap/application_bootstrap.dart:367-369`). This architecture makes the <2s cold-start target difficult at current scale.

### Issues Found

#### CRITICAL
1. **First-frame blocked by full bootstrap chain** -- `lib/main.dart:165-244`, `lib/core/bootstrap/application_bootstrap.dart:293-301`, `lib/core/di/di_container.dart:228-252`
   - Impact: Slow cold start, delayed interactivity, higher churn on lower-end devices.
   - Current: Firebase, Firestore settings/recovery, App Check, modular DI, stage execution, and consent-gated initialization all occur before UI mounts.
   - Best Practice: Move non-essential network/service initialization behind first frame and progressively hydrate.
   - Scale Threshold: Already active at 1x.
   - Effort: 3-5 days.

#### HIGH
1. **Startup stage performs network-dependent flag fetch and integrity startup** -- `lib/core/bootstrap/stages/core_stage.dart:44-53`, `lib/services/feature_flags/feature_flag_service.dart:96-103`, `lib/services/device_integrity_service.dart:141-143`
   - Impact: Added boot latency and timeout variability.
   - Current: `fetchAndActivate()` and integrity startup run in `CoreStage`.
   - Best Practice: Gate critical flags only; defer non-critical remote fetch post-frame.
   - Scale Threshold: 1x.
   - Effort: 1-2 days.
2. **Content bootstrap triggers ingredient enrichment that depends on full ingredient cache load** -- `lib/core/bootstrap/stages/content_stage.dart:52-75`, `lib/repositories/firebase/firebase_ingredient_repository.dart:153-158`
   - Impact: Startup latency and network reads scale with ingredients catalog.
   - Current: Enrichment runs during boot and repository loads entire collection.
   - Best Practice: Lazy-load or ship snapshot bundle; background refresh.
   - Scale Threshold: ~10x content size.
   - Effort: 2-4 days.

#### MEDIUM
1. **User profile load is forced during social module initialization** -- `lib/core/di/modules/social_module.dart:416-420`, `lib/services/user_service.dart:100-103`, `lib/services/user_service.dart:352-375`
   - Impact: Extra startup network/CPU; profile creation path may execute during boot.
   - Current: `UserService.initialize()` subscribes auth and may fetch/create profile immediately.
   - Best Practice: Load profile on first social surface.
   - Scale Threshold: 1x.
   - Effort: 1-2 days.
2. **Search module consent evaluation adds startup decision work** -- `lib/core/di/modules/search_module.dart:113-117`, `lib/core/di/modules/search_module.dart:153-155`, `lib/services/account/consent_service.dart:144-148`, `lib/repositories/firebase/firebase_consent_repository.dart:120-126`
   - Impact: Additional startup dependency on consent fetch path.
   - Current: Search provider decision is run at module init.
   - Best Practice: Start with Firestore fallback and re-evaluate asynchronously.
   - Scale Threshold: 1x.
   - Effort: 0.5-1 day.

#### LOW
1. **High stage timeout ceilings can mask poor startup behavior** -- `lib/core/bootstrap/stages/content_stage.dart:37`, `lib/core/bootstrap/stages/social_stage.dart:36`, `lib/core/di/di_container.dart:441-446`
   - Impact: Slow paths may persist without failing fast.
   - Current: Content=45s, Social=60s, module init timeout warning at 10s.
   - Best Practice: tighter SLO-aligned thresholds + instrumentation.
   - Scale Threshold: 1x.
   - Effort: 0.5 day.

### Quick Wins
- Defer `ContentStage` enrichment and social/profile initialization until after first interactive frame.
- Keep local/default feature flags during boot; run remote fetch in background.
- Split mandatory vs optional startup services and move optional ones off critical path.

## 2) Memory & Resource Management -- Score: 8/15

### Summary
Memory pressure is partly mitigated (image-cache cap and memory-pressure hooks), but cache/timer lifecycle handling across login/logout is inconsistent (`lib/main.dart:152-154`, `lib/main.dart:682-696`). The user-scope cache manager is disposed with `clearCache()` instead of `dispose()`, leaving timer lifecycle ambiguous (`lib/core/di/modules/performance_module.dart:64-67`, `lib/services/performance/intelligent_cache_manager.dart:508-521`, `lib/services/performance/intelligent_cache_manager.dart:577-583`).

### Issues Found

#### CRITICAL
- None.

#### HIGH
1. **User-scope cache manager disposal skips timer cancellation** -- `lib/core/di/modules/performance_module.dart:64-67`, `lib/services/performance/intelligent_cache_manager.dart:477-493`, `lib/services/performance/intelligent_cache_manager.dart:508-521`, `lib/services/performance/intelligent_cache_manager.dart:577-583`, `lib/services/auth_service.dart:180`, `lib/core/di/di_container.dart:392-395`
   - Impact: Potential timer/resource leak across auth scope transitions.
   - Current: Scope drop calls `clearCache()`; timers are only cancelled in `dispose()`.
   - Best Practice: Scope disposal should invoke `dispose()` for timer-bearing services.
   - Scale Threshold: 1x (logout/login cycles).
   - Effort: 0.5-1 day.

#### MEDIUM
1. **Cache budgets alone consume most of the 150MB target** -- `lib/main.dart:152-154`, `lib/services/performance/intelligent_cache_manager.dart:145`
   - Impact: Reduced headroom for widgets, decoded images, and Firestore snapshots.
   - Current: 50MB Flutter image cache + 50MB intelligent cache target.
   - Best Practice: dynamic cache sizing by device class and active screen.
   - Scale Threshold: 1x.
   - Effort: 1 day.
2. **App resume path can restart cache manager timers regardless of prior init state** -- `lib/main.dart:664-670`, `lib/services/performance/intelligent_cache_manager.dart:537-540`
   - Impact: Background tasks may run without full warmup context.
   - Current: Resume directly starts periodic timers.
   - Best Practice: guard timer restarts behind explicit initialized/active session state.
   - Scale Threshold: 1x.
   - Effort: 0.5 day.

#### LOW
1. **Positive: memory-pressure handling is implemented** -- `lib/main.dart:686-696`, `lib/services/performance/intelligent_cache_manager.dart:547-575`
   - Impact: Reduces OOM risk during system pressure.
   - Current: Clears image cache + app-level caches.
   - Best Practice: keep this path and instrument memory reclaimed.
   - Scale Threshold: N/A.
   - Effort: 0 days (already in place).

### Quick Wins
- Change user-scope dispose callback to call `IntelligentCacheManager.dispose()`.
- Add telemetry counters for cache memory and timer state transitions.
- Set per-platform cache caps (mobile vs desktop/web).

## 3) Firebase Query & Schema Design -- Score: 7/18

### Summary
The data model has solid caps in some high-traffic streams, but multiple unbounded reads and N+1 fetch patterns remain in startup and collaborative flows (`lib/repositories/firebase/firebase_recipe_repository.dart:366-372`, `lib/services/unified/unified_menu_service.dart:191-195`, `lib/services/unified/unified_menu_service.dart:209-212`). Index coverage is strong for several known query families, but dynamic collaborative-list query shape does not align with declared indexes (`firestore.indexes.json:81-86`, `firestore.indexes.json:189-203`; `lib/repositories/firebase/modules/shopping_repository_query_module.dart:144-147`).

### Issues Found

#### CRITICAL
- None.

#### HIGH
1. **Unbounded menu loads during init** -- `lib/services/unified/unified_menu_service.dart:191-195`, `lib/services/unified/unified_menu_service.dart:209-212`
   - Impact: Reads and latency scale directly with user menu volume.
   - Current: both owned and collaborative menu queries use unbounded `.get()`.
   - Best Practice: cursor pagination with fixed page size.
   - Scale Threshold: ~10x user content.
   - Effort: 1-2 days.
2. **Ingredient cache performs full collection scan** -- `lib/repositories/firebase/firebase_ingredient_repository.dart:102-103`, `lib/repositories/firebase/firebase_ingredient_repository.dart:153-158`
   - Impact: startup/network costs rise with ingredient catalog growth.
   - Current: cold load fetches entire `ingredients` collection.
   - Best Practice: shard by group/version and fetch incrementally.
   - Scale Threshold: ~10x catalog.
   - Effort: 2-3 days.
3. **Shopping list `readAll()` uses N+1 item subcollection fetches** -- `lib/repositories/firebase/modules/shopping_repository_query_module.dart:43-50`
   - Impact: latency grows with number of lists.
   - Current: per-list item query loop.
   - Best Practice: denormalized preview fields or batched fetch strategy.
   - Scale Threshold: ~10x list count.
   - Effort: 2 days.
4. **Shared-content lookup performs N+1 document hydration** -- `lib/repositories/firebase/base_shared_content_repository.dart:633-637`, `lib/repositories/firebase/base_shared_content_repository.dart:662-665`
   - Impact: high latency and extra reads for large shared sets.
   - Current: member docs then per-id content doc fetches.
   - Best Practice: maintain queryable inverse index with direct payload.
   - Scale Threshold: ~10x shared memberships.
   - Effort: 3-4 days.

#### MEDIUM
1. **Client-side filtering after broad 200-doc reads** -- `lib/repositories/firebase/firebase_recipe_repository.dart:424-432`, `lib/repositories/firebase/firebase_recipe_repository.dart:871-881`, `lib/repositories/firebase/firebase_recipe_repository.dart:890-898`
   - Impact: wasted reads and CPU for text search.
   - Current: fetch latest 200 then `contains()` in client.
   - Best Practice: dedicated search backend / indexed prefix strategy.
   - Scale Threshold: ~10x DAU.
   - Effort: 3-5 days.
2. **Personal-tag bulk updates query all matches without page boundaries** -- `lib/repositories/firebase/firebase_recipe_repository.dart:498-500`, `lib/repositories/firebase/firebase_recipe_repository.dart:553-556`, `lib/repositories/firebase/firebase_recipe_repository.dart:609-611`
   - Impact: costly maintenance operations on users with many recipes.
   - Current: reads all matching docs before chunked writes.
   - Best Practice: paged processing + background tasks.
   - Scale Threshold: ~10x heavy users.
   - Effort: 1-2 days.
3. **Collaborative-list query/index mismatch risk** -- `lib/repositories/firebase/modules/shopping_repository_query_module.dart:144-147`, `lib/models/unified/unified_shopping_list.dart:583-585`, `firestore.indexes.json:81-86`, `firestore.indexes.json:254-309`
   - Impact: runtime index errors or expensive query planning as usage grows.
   - Current: query uses `memberPermissions.<uid>` inequality + sort; index file defines `collaborators` path for different collection group.
   - Best Practice: stable indexed field (`collaborators` array) for membership query.
   - Scale Threshold: 1x-10x.
   - Effort: 2-3 days.

#### LOW
1. **Positive caps in key streams** -- `lib/repositories/firebase/firebase_recipe_repository.dart:68`, `lib/repositories/firebase/firebase_recipe_repository.dart:369-371`; `lib/repositories/firebase/firebase_notifications_repository.dart:318-319`; `lib/repositories/firebase/modules/conversation_query_module.dart:35-36`; `lib/repositories/firebase/modules/shopping_repository_query_module.dart:131-132`, `lib/repositories/firebase/modules/shopping_repository_query_module.dart:146-147`
   - Impact: reduces worst-case read bursts.
   - Current: recipe=100, notifications=50, conversations=50, shopping=20.
   - Best Practice: keep caps and add cursor-based “load more”.
   - Scale Threshold: beneficial at all scales.
   - Effort: 0 days.

### Quick Wins
- Add `limit + cursor` to `UnifiedMenuService` loads immediately.
- Replace tag bulk-scan operations with paged worker tasks.
- Normalize collaborative membership query field and align index definitions.

## 4) Real-time Listeners & Stream Management -- Score: 6/12

### Summary
Listener lifecycle hygiene exists in some services, but many collection streams remain unbounded and broad (`lib/services/presence_service.dart:238-243`; unbounded stream refs below). Presence fan-out creates one RTDB listener per member, which can become expensive in social surfaces (`lib/widgets/social/family_presence_bar.dart:153-158`, `lib/services/presence_service.dart:220-223`).

### Issues Found

#### CRITICAL
- None.

#### HIGH
1. **Multiple unbounded snapshot streams** -- `lib/repositories/firebase/firebase_pantry_repository.dart:89-91`, `lib/repositories/firebase/firebase_personal_tag_repository.dart:94-97`, `lib/repositories/firebase/firebase_personal_tag_repository.dart:190-193`, `lib/repositories/firebase/firebase_personal_tag_group_repository.dart:94-97`, `lib/repositories/firebase/firebase_user_ingredient_repository.dart:190-193`, `lib/repositories/firebase/modules/conversation_participant_module.dart:264-269`, `lib/repositories/firebase/firebase_menu_voting_repository.dart:111-114`, `lib/repositories/firebase/firebase_shared_shopping_repository.dart:662-667`, `lib/repositories/firebase/friends/friend_category_repository.dart:332-334`, `lib/services/moderation/report_service.dart:105-114`
   - Impact: read and memory growth with collection size.
   - Current: several listeners stream entire collections.
   - Best Practice: constrain with `limit`, filters, or screen-scoped pagination.
   - Scale Threshold: ~10x.
   - Effort: 2-5 days.
2. **Presence stream fan-out is linear in member count** -- `lib/widgets/social/family_presence_bar.dart:153-158`, `lib/services/presence_service.dart:220-223`
   - Impact: one connection/listener per friend in active roster.
   - Current: loop attaches individual RTDB listeners for each user.
   - Best Practice: batch presence aggregation or capped roster streaming.
   - Scale Threshold: ~10x social users.
   - Effort: 2-3 days.

#### MEDIUM
1. **Friend ID stream truncates at 1000 docs** -- `lib/repositories/firebase/friends/friend_relationship_repository.dart:333-342`
   - Impact: correctness and UX drift for very large graphs.
   - Current: warns when truncated but still returns partial set.
   - Best Practice: cursor paging for large friend lists.
   - Scale Threshold: high-degree users.
   - Effort: 1-2 days.
2. **Recipe stream page size still heavy for low-memory devices** -- `lib/repositories/firebase/firebase_recipe_repository.dart:68`, `lib/repositories/firebase/firebase_recipe_repository.dart:369-372`
   - Impact: large initial snapshot + rebuild pressure.
   - Current: page size fixed at 100.
   - Best Practice: device-adaptive page sizing.
   - Scale Threshold: 1x low-end devices.
   - Effort: 1 day.

#### LOW
1. **Positive: listener cancellation pattern exists in presence stream** -- `lib/services/presence_service.dart:238-243`
   - Impact: mitigates leak risk for that flow.
   - Current: `onCancel` cancels subscriptions and closes controller.
   - Best Practice: replicate across all composite listener builders.
   - Scale Threshold: N/A.
   - Effort: 0 days.

### Quick Wins
- Add limits to pantry/tag/group/ingredient/report streams.
- Cap visible presence roster and lazy-load overflow users.
- Add listener budget telemetry per screen.

## 5) Scalability Projections -- Score: 6/15

### Summary
Current architecture handles present load but includes super-linear hotspots in triggers and fan-out jobs (`functions/src/index.ts:135-138`, `functions/src/index.ts:172-183`; `functions/src/social/on-profile-updated.ts:60-149`). At 100x growth, these patterns become primary latency/cost drivers without structural changes.

### Issues Found

#### CRITICAL
- None.

#### HIGH
1. **Rating aggregation trigger rescans all ratings on every change** -- `functions/src/index.ts:135-138`, `functions/src/index.ts:172-183`, `functions/src/index.ts:226-307`
   - Impact: O(n) work per rating write; heavy for popular recipes.
   - Current: every create/update/delete recomputes by full query scan.
   - Best Practice: transactional incremental counters or event-id guarded delta updates.
   - Scale Threshold: ~100x activity / hot recipes.
   - Effort: 4-7 days.
2. **Profile propagation trigger has broad fan-out and long timeout** -- `functions/src/social/on-profile-updated.ts:23`, `functions/src/social/on-profile-updated.ts:60-149`, `functions/src/social/on-profile-updated.ts:151-153`
   - Impact: elevated timeout/retry risk, burst write load.
   - Current: updates many collections and collection groups in one trigger.
   - Best Practice: queue-based partitioning and bounded workers.
   - Scale Threshold: ~100x social graph.
   - Effort: 5-8 days.
3. **Notification batch authorization performs per-target query loops** -- `functions/src/notifications/send-notification.ts:503-507`, `functions/src/notifications/send-notification.ts:528-548`, `functions/src/notifications/send-notification.ts:587-605`
   - Impact: batch latency grows with target count; read amplification.
   - Current: friendship/request checks repeated per target before send.
   - Best Practice: precomputed relationship edges or batched authorization lookup.
   - Scale Threshold: ~10x send volume.
   - Effort: 2-4 days.

#### MEDIUM
1. **Batch-update helpers materialize full query result sets** -- `functions/src/shared/batch-update.ts:19-27`, `functions/src/shared/batch-update.ts:53-61`
   - Impact: high memory and long execution on large datasets.
   - Current: `query.get()` then iterate.
   - Best Practice: paged query windows.
   - Scale Threshold: ~100x data size.
   - Effort: 2-3 days.
2. **Single-region deployment footprint** -- `functions/src/index.ts:20`, `docs/analysis/runs/2026-05-codex/_pre-analysis/functions-regions.txt:1`
   - Impact: non-EU latency concentration and limited regional failover options.
   - Current: all functions pinned to `europe-west1`.
   - Best Practice: explicit multi-region strategy for future geo expansion.
   - Scale Threshold: ~100x/geo expansion.
   - Effort: 3-6 days.

#### LOW
1. **Positive: notification batch size hard-capped** -- `functions/src/notifications/send-notification.ts:503-507`
   - Impact: avoids unbounded caller abuse per request.
   - Current: max 100 per batch.
   - Best Practice: retain cap with adaptive concurrency.
   - Scale Threshold: N/A.
   - Effort: 0 days.

### Quick Wins
- Replace full-scan rating recompute with incremental aggregation.
- Partition profile propagation updates into queued chunks.
- Rework batch notification auth checks into single-pass batched lookups.

## 6) Bundle Size & Network Efficiency -- Score: 8/12

### Summary
Network efficiency has meaningful positives (image compression, thumbnails, cleanup trigger), but dependency breadth and large codebase size increase bundle and runtime footprint risk (`lib/repositories/firebase/firebase_storage_repository.dart:216-233`, `lib/repositories/firebase/firebase_storage_repository.dart:467-491`, `lib/repositories/firebase/firebase_storage_repository.dart:518-538`; `functions/src/cleanup/cleanup-recipe-storage.ts:26-29`, `functions/src/cleanup/cleanup-recipe-storage.ts:81-107`). Pre-analysis did not capture actual APK/IPA size artifacts, so target compliance is currently unverified (`docs/analysis/runs/2026-05-codex/_pre-analysis/SUMMARY.md:7-20`).

### Issues Found

#### CRITICAL
- None.

#### HIGH
- None.

#### MEDIUM
1. **Large dependency surface likely inflates binary and startup overhead** -- `docs/analysis/runs/2026-05-codex/_pre-analysis/pub-deps.txt:6-37`, `docs/analysis/runs/2026-05-codex/_pre-analysis/pub-deps.txt:44-65`
   - Impact: larger binaries and heavier plugin initialization paths.
   - Current: broad Firebase + media/webview/native integrations.
   - Best Practice: dependency audit + deferred loading of feature bundles.
   - Scale Threshold: 1x.
   - Effort: 2-4 days.
2. **Codebase/file-size growth increases instruction and parse pressure** -- `docs/analysis/runs/2026-05-codex/_pre-analysis/dart-file-count.txt:1`, `dart-line-count.txt:1`, `files-over-500-lines.txt:2-7`
   - Impact: maintainability and potential build/runtime footprint drift.
   - Current: 1252 Dart files, 327,280 lines, many very large files.
   - Best Practice: split oversized modules and reduce monolith files.
   - Scale Threshold: 1x.
   - Effort: ongoing.
3. **Bundle-size target cannot be verified from current artifacts** -- `docs/analysis/runs/2026-05-codex/_pre-analysis/SUMMARY.md:7-20`
   - Impact: release risk (unknown APK/IPA compliance).
   - Current: no build-size outputs in captured artifacts.
   - Best Practice: add CI artifact for size budgets per platform.
   - Scale Threshold: 1x.
   - Effort: 1 day.

#### LOW
1. **Positive image optimization pipeline exists** -- `lib/repositories/firebase/firebase_storage_repository.dart:216-233`, `lib/repositories/firebase/firebase_storage_repository.dart:467-491`, `lib/repositories/firebase/firebase_storage_repository.dart:518-538`
   - Impact: reduces upload and storage/network cost.
   - Current: compression + thumbnail generation before upload.
   - Best Practice: retain and add format heuristics.
   - Scale Threshold: beneficial at all scales.
   - Effort: 0 days.
2. **Positive storage cleanup trigger exists for deleted recipes** -- `functions/src/cleanup/cleanup-recipe-storage.ts:26-29`, `functions/src/cleanup/cleanup-recipe-storage.ts:37-44`, `functions/src/cleanup/cleanup-recipe-storage.ts:81-107`
   - Impact: limits orphaned media costs.
   - Current: delete + thumbnail cleanup on recipe delete.
   - Best Practice: keep idempotent and monitor failure count.
   - Scale Threshold: beneficial at all scales.
   - Effort: 0 days.
3. **Assets/fonts are explicitly declared and scoped** -- `pubspec.yaml:148-153`, `pubspec.yaml:158-173`
   - Impact: predictable packaging behavior.
   - Current: known asset and font directories declared.
   - Best Practice: pair with automated unused-asset checks.
   - Scale Threshold: N/A.
   - Effort: 0.5 day.

### Quick Wins
- Add build-size artifact checks in CI for Android/iOS/Web.
- Prune dormant dependencies and gate heavy packages behind feature flags.
- Add “network bytes/session” telemetry for top screens.

## 7) Offline Performance & Sync -- Score: 4/10

### Summary
Firestore offline persistence and cache-first helpers are implemented, and UI exposes pending-write status (`lib/main.dart:172-175`, `lib/main.dart:196-199`; `lib/repositories/firebase/base_firebase_repository.dart:337-355`; `lib/views/mina_recept_view.dart:464-467`). However, offline delete semantics are broken: delete intent is removed locally without a server-side delete sync path (`lib/services/offline/offline_user_storage.dart:121-125`, `lib/services/offline/offline_sync_manager.dart:113-166`).

### Offline Functionality Matrix

| Feature | Works Offline? | Notes |
|---|---|---|
| View cached recipes | Yes (partial) | Firestore persistence enabled and recipe stream exposes cache metadata (`lib/main.dart:172-175`, `lib/main.dart:196-199`; `lib/repositories/firebase/firebase_recipe_repository.dart:719-722`) |
| View sync/cache state | Yes | UI shows pending writes / cache status (`lib/views/mina_recept_view.dart:464-467`) |
| Create/edit recipes offline | Yes | Offline save enqueues update sync operation (`lib/services/offline/offline_user_storage.dart:61-66`) |
| Delete recipes offline | No (critical gap) | Offline delete removes queued sync instead of enqueuing delete (`lib/services/offline/offline_user_storage.dart:121-125`) |
| Replay delete on reconnect | No | Sync manager handles `tag` specially, otherwise upserts; no delete branch (`lib/services/offline/offline_sync_manager.dart:113-127`, `lib/services/offline/offline_sync_manager.dart:141-166`) |
| Local queue persistence | Yes | Drift stores `SyncQueueEntries` and related offline tables (`lib/core/storage/drift/app_database.dart:29-35`) |

### Issues Found

#### CRITICAL
1. **Offline delete drops sync intent (data divergence risk)** -- `lib/services/offline/offline_user_storage.dart:121-125`, `lib/core/storage/drift/tables/sync_queue.dart:4-8`
   - Impact: deleted item may reappear from server or remain on server indefinitely.
   - Current: delete removes local data and queue entries; no queued delete op.
   - Best Practice: enqueue `SyncOperation.delete` and replay idempotently.
   - Scale Threshold: 1x.
   - Effort: 1-2 days.

#### HIGH
1. **Sync manager has no delete-operation execution path** -- `lib/services/offline/offline_sync_manager.dart:113-127`, `lib/services/offline/offline_sync_manager.dart:141-166`
   - Impact: reconnect cannot apply offline delete operations.
   - Current: non-tag operations go through upsert path.
   - Best Practice: explicit op-switch for create/update/delete with conflict handling.
   - Scale Threshold: 1x.
   - Effort: 1-2 days.

#### MEDIUM
1. **Conflict-resolution policy is not explicit in offline sync path** -- `lib/services/offline/offline_sync_manager.dart:129-166`, `lib/repositories/firebase/base_firebase_repository.dart:337-355`
   - Impact: ambiguous behavior for concurrent edits across devices.
   - Current: write path is effectively last-write-wins via `set` merge semantics.
   - Best Practice: explicit conflict metadata/versioning for collaborative entities.
   - Scale Threshold: ~10x collaboration.
   - Effort: 2-4 days.
2. **Positive: persistence and cache-first primitives are implemented** -- `lib/main.dart:172-175`, `lib/main.dart:196-199`; `lib/repositories/firebase/base_firebase_repository.dart:337-355`
   - Impact: improves read resilience while offline.
   - Current: persistence enabled, cache-first helper exists.
   - Best Practice: keep and extend to more read paths.
   - Scale Threshold: beneficial at all scales.
   - Effort: 0 days.

#### LOW
1. **Offline telemetry depth is limited in artifacts** -- `docs/analysis/runs/2026-05-codex/_pre-analysis/SUMMARY.md:7-20`
   - Impact: hard to validate reconnect SLOs and offline success rates.
   - Current: no captured offline-performance traces in pre-analysis set.
   - Best Practice: add offline sync latency/error metrics.
   - Scale Threshold: 1x.
   - Effort: 1 day.

### Quick Wins
- Implement `delete` enqueue + replay path first (highest risk reduction).
- Add sync-operation metrics by op type (`create/update/delete/tag`).
- Add conflict markers for collaborative/offline entities.

### Remediation Roadmap

- **Immediate (CRITICAL items, quick wins):**
  - Fix offline delete semantics end-to-end (`lib/services/offline/offline_user_storage.dart:121-125`, `lib/services/offline/offline_sync_manager.dart:113-166`).
  - Remove first-frame blockers by deferring non-critical startup tasks (`lib/main.dart:165-244`, `lib/core/bootstrap/stages/content_stage.dart:52-75`).
  - Add hard limits to currently unbounded live streams (`lib/repositories/firebase/firebase_pantry_repository.dart:89-91`, `lib/repositories/firebase/firebase_personal_tag_repository.dart:94-97`, `lib/services/moderation/report_service.dart:105-114`).
  - Total effort: ~5-9 days.

- **Short-term (HIGH items, 10x readiness):**
  - Page menu loads and replace N+1 hydrations (`lib/services/unified/unified_menu_service.dart:191-195`, `lib/services/unified/unified_menu_service.dart:209-212`; `lib/repositories/firebase/modules/shopping_repository_query_module.dart:43-50`; `lib/repositories/firebase/base_shared_content_repository.dart:662-665`).
  - Replace rating full-scan aggregation with incremental updates (`functions/src/index.ts:135-138`, `functions/src/index.ts:172-183`).
  - Correct collaborative shopping query/index strategy (`lib/repositories/firebase/modules/shopping_repository_query_module.dart:144-147`; `firestore.indexes.json:81-86`).
  - Total effort: ~8-14 days.

- **Medium-term (MEDIUM items, 100x readiness):**
  - Refactor client-side recipe search filtering to indexed search backend (`lib/repositories/firebase/firebase_recipe_repository.dart:424-432`, `lib/repositories/firebase/firebase_recipe_repository.dart:871-881`, `lib/repositories/firebase/firebase_recipe_repository.dart:890-898`).
  - Break profile propagation into queued/partitioned workers (`functions/src/social/on-profile-updated.ts:60-149`).
  - Add CI size/perf artifact gates (`docs/analysis/runs/2026-05-codex/_pre-analysis/SUMMARY.md:7-20`).
  - Total effort: ~8-15 days.

- **Long-term (architecture decisions, 1000x readiness):**
  - Introduce event-driven aggregation and background pipelines for fan-out-heavy flows (`functions/src/index.ts:226-307`, `functions/src/shared/batch-update.ts:19-27`).
  - Define regional expansion strategy beyond single-region deployment (`functions/src/index.ts:20`).
  - Formalize offline conflict-resolution model for collaborative entities (`lib/services/offline/offline_sync_manager.dart:129-166`).
  - Decision points: Firebase-only with stricter constraints vs hybrid (queue/worker/search services) as DAU approaches 100k+.

