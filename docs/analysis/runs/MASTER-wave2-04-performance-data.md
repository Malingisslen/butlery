# MASTER Wave 2 — Prompt 04 Performance & Scalability — Consensus Data

```
Date:       2026-05-04
Sources:    docs/analysis/runs/2026-05-codex/04-performance.md         (Codex GPT-5, 516 lines, 838k tokens, 2026-05-04 14:07)
            docs/analysis/runs/2026-05-claude/04-performance.md         (Claude default, 471 lines, 2026-05-02)
            docs/analysis/runs/2026-05-claude-deep/04-performance.md    (Claude deep + Pass 2 critic, 1419 lines, 2026-05-02/03)
Treatment:  deep is authoritative (Pass 2 critic verified C1/C2/C3 live on disk)
Baseline:   76,325 hand-written Dart LOC across 1,257 files (NOT the 327k Codex+default cited)
            132 files >500 lines, 4-6 files >1000 lines
            recipe_image_manager.dart 1246, firebase_recipe_repository.dart 1092, personal_recipe_module.dart 1023
```

---

## Score consensus

| Dimension | Codex | Default (Claude) | Deep Pass 1 | Deep Pass 2 (final) | Authoritative |
|---|---:|---:|---:|---:|---:|
| 1. App Startup & Frame Rate          |  8/18 | 13/18 | 13/18 | **12/18** | 12/18 |
| 2. Memory & Resource Management      |  8/15 | 11/15 | 10/15 |  **9/15** |  9/15 |
| 3. Firebase Query & Schema Design    |  7/18 | 12/18 | 12/18 | **11/18** | 11/18 |
| 4. Real-time Listeners & Streams     |  6/12 |  7/12 |  6/12 |  **6/12** |  6/12 |
| 5. Scalability Projections           |  6/15 | 10/15 | 10/15 | **10/15** | 10/15 |
| 6. Bundle Size & Network Efficiency  |  8/12 | 10/12 | 10/12 |  **9/12** |  9/12 |
| 7. Offline Performance & Sync        |  4/10 |  9/10 |  9/10 |  **9/10** |  9/10 |
| **TOTAL** | **47/100** | **72/100** | **70/100** | **66/100** | **66/100** |

| Severity bucket | Codex | Default | Deep (final) | Authoritative |
|---|---:|---:|---:|---:|
| CRITICAL | 2 | 2 | 3 | 3 |
| HIGH     | 13 | 7 | 8 + 2 added by critic = 10 | 10 |
| MEDIUM   | 11 | 9 | 10 + 2 added by critic = 12 | 12 |
| LOW      | 7 | 6 | 6 + 2 added by critic = 8 | 8 |

Codex's 47 is an outlier — driven by counting Codex's "all unbounded streams + N+1 hydration + offline delete bug" as separate HIGH/CRITICAL items. Default and deep converge at offline=9/10 because deep verified persistence + cache-first patterns; Codex marked offline as 4/10 because it found the offline-delete drop bug (real, see Disputed numbers).

The Codex offline-delete CRITICAL is real but is NOT performance — it belongs in `06-data-architecture` or an offline-correctness prompt. Listed below as cross-cutting.

---

## CRITICAL findings (consensus matrix + verification)

### CRITICAL #1 — `ConversationAutoHealerModule` opens up to 50 concurrent listeners per active user (auto-healer fan-out)

| Run | Severity | Refs |
|---|---|---|
| Codex     | NOT PRESENT (only mentions `participantIds` query indexes; misses fan-out entirely) | — |
| Default   | CRITICAL #1 | `lib/repositories/firebase/modules/conversation_query_module.dart:36-46`, `lib/repositories/firebase/modules/conversation_auto_healer_module.dart:28-79` |
| Deep      | CRITICAL #1, **live-verified Pass 2** | `conversation_query_module.dart:31-46`, `conversation_auto_healer_module.dart:18, 28-79, 38-43, 78` |

**Consensus**: 2-of-3 (default + deep). **VERIFIED LIVE** by deep Pass 2 critic — re-read disk, confirmed `_activeHealers` map at `:18`, `// ignore: cancel_subscriptions` at `:37` admits irregularity. Codex MISSED this — material gap in Codex's coverage of the messaging subsystem.

**Authoritative description**: `getUserConversations` returns a stream that, on every snapshot, calls `startAutoHealer(conversation.id)` for all 50 conversations. Each healer opens an additional `messages.where(conversationId == X).orderBy(sentAt desc).limit(1).snapshots()` listener. Total: **52 concurrent listeners per active user during normal messaging usage**.

**Scale math (deep, verified)**:
- 1K users → 20-50K listeners (within Firestore 100K project cap)
- 10K users → 200-500K listeners → **breaks Firestore project ceiling**
- 100K users → architectural change required

---

### CRITICAL #2 — `RealtimeSyncService._cachedResources` grows without bound

| Run | Severity | Refs |
|---|---|---|
| Codex     | NOT PRESENT (no mention of RealtimeSyncService caches) | — |
| Default   | CRITICAL #2 | `lib/services/realtime_sync_service.dart:159` |
| Deep      | CRITICAL #2, **live-verified Pass 2** | `realtime_sync_service.dart:53` (decl), `:64` (logout clear), `:159` (read-path write), `:224` (write-path write — found by Pass 2 critic), `:278` (deleteResource), `:411` (onDispose) |

**Consensus**: 2-of-3 (default + deep). **VERIFIED LIVE** by deep Pass 2. Pass 2 added the `:224` second write-site that Pass 1 missed — both reads AND writes grow the map. Codex MISSED this.

**Authoritative description**: Map declared at `:53`, populated unconditionally on `watchResource<T>` snapshot at `:159` AND on `updateResource` at `:224`. Cleared only on logout / explicit `deleteResource` / `onDispose`. No LRU, no idle eviction, no size cap.

**Memory math**: ~50-500 KB per cached recipe; 200 recipes opened in a session → 10-100 MB retained.

Same anti-pattern recurs at `firebase_user_ingredient_repository.dart:189-202` — `_userCache[userId]` rebuilt per snapshot with no inter-account eviction (verified at `:179` second write path by Pass 2 critic).

---

### CRITICAL #3 — `FriendsStateManager.dispose()` leaks `_blockedUsersSubscription`

| Run | Severity | Refs |
|---|---|---|
| Codex     | NOT PRESENT | — |
| Default   | NOT PRESENT (default mentions `friends_state_manager` listener count but not the dispose asymmetry) | — |
| Deep      | CRITICAL #3 (NEW finding, Pass 1), **live-verified Pass 2** | `lib/services/unified/friends/friends_state_manager.dart:40` (decl), `:203` (clearAllData cancels), `:284` (start), `:613-631` (dispose — does NOT cancel) |

**Consensus**: 1-of-3 (deep only). **VERIFIED LIVE TWICE** by deep — Pass 1 read the file, Pass 2 critic re-read it verbatim and confirmed asymmetry. **30-second fix.**

**Authoritative description**: `dispose()` cancels six subscriptions (incoming requests, sent requests, group invitations, categories, member categories, friends) and explicitly **omits** `_blockedUsersSubscription`. `clearAllData()` (`:203`) DOES cancel it. Asymmetric — almost certainly an oversight, not a design choice.

Pass 2 critic note: "could be reclassified HIGH (not CRITICAL) since dispose only fires once at app shutdown when manager is singleton" — but treats severity as preserved because the new HIGH (anonymous-closure leak in `UnifiedFriendsService`, see below) compounds the same listener-leak class.

---

## HIGH findings (consensus matrix + verification)

### HIGH #A — 7 widgets use raw `Image.network`, bypassing the configured image cache

| Run | Severity | Refs |
|---|---|---|
| Codex     | NOT PRESENT | — |
| Default   | HIGH | 7 sites enumerated |
| Deep      | HIGH #1, **live-grep verified Pass 2** | `widgets/menu/suggest_alternative_sheet.dart:157`, `widgets/recipe/duplicate_merge_sheet.dart:248`, `widgets/recipe/cook_snap_gallery.dart:168`, `widgets/messaging/poll_creation_dialog.dart:284`, `views/social/public_profile_view.dart:333`, `widgets/social/family_presence_bar.dart:228`, `widgets/social/activity_pings_feed.dart:402` |

**Consensus**: 2-of-3 (default + deep). **VERIFIED — exactly 7 matches** by deep Pass 2 grep. Project has `lib/widgets/image/recipe_image_widget.dart` with proper `RepaintBoundary` + `memCacheWidth/Height` — drift, not by design.

---

### HIGH #B — Web cold-start blocks on Firestore `_health/_` round-trip on every load

| Run | Severity | Refs |
|---|---|---|
| Codex     | NOT PRESENT (Codex's startup CRITICAL is generic "first-frame blocked by full bootstrap") | — |
| Default   | HIGH | `lib/main.dart:181-203` |
| Deep      | HIGH #2 | `lib/main.dart:181-203` |

**Consensus**: 2-of-3. **VERIFIED** by both default and deep. Cost: 100-800 ms median, up to 5 s on timeout edge. Fix: 30 min — defer to `addPostFrameCallback`.

---

### HIGH #C — `searchRecipes` does client-side `.contains` on a 200-doc page (silent miss for #201+)

| Run | Severity | Refs |
|---|---|---|
| Codex     | MEDIUM #1 (Dim 3) | `firebase_recipe_repository.dart:424-432, 871-881, 890-898` |
| Default   | MEDIUM | `firebase_recipe_repository.dart:411-442` |
| Deep      | HIGH #4, **live-verified Pass 2** | `firebase_recipe_repository.dart:412-442, :425-426 limit(200), :431 contains` |

**Consensus**: 3-of-3 (different severities). **VERIFIED LIVE** by deep Pass 2 critic. Authoritative severity = HIGH (deep). Comment in code acknowledges Algolia is the right answer.

---

### HIGH #D — `updateRecipeRatingStats` re-aggregates ALL ratings on every change (full collection scan)

| Run | Severity | Refs |
|---|---|---|
| Codex     | HIGH #1 (Dim 5) | `functions/src/index.ts:135-138, 172-183, 226-307` |
| Default   | (mentioned in scalability bottleneck table, not separately classified) | `functions/src/index.ts:130-218` |
| Deep      | HIGH #5 | `functions/src/index.ts:130-218` |

**Consensus**: 3-of-3. Authoritative severity = HIGH. Mitigation: `FieldValue.increment` for count + sum. Pass 2 critic note: "could be MEDIUM until viral-recipe scenario is realistic for pre-launch Butlery."

---

### HIGH #E — Cloud Functions have NO `minInstances` configured anywhere

| Run | Severity | Refs |
|---|---|---|
| Codex     | NOT PRESENT (Codex notes single-region but not cold-start) | — |
| Default   | LOW (mentioned `minInstances: 1` recommendation in scalability section) | functions/src/* general |
| Deep      | HIGH #6, **live-grep verified Pass 2 (zero matches)** | `functions/src/index.ts:20` (only sets region), `llm/structure-recipe.ts:67-68`, `llm/ocr-recipe-image.ts:91-92`, `events/log-web-error.ts:118-119`, `cleanup/on-user-deleted.ts:31`, `social/on-profile-updated.ts:23` |

**Consensus**: 2-of-3 (default + deep). **VERIFIED — zero `minInstances` matches** by deep Pass 2. Authoritative severity = HIGH. Fix: 1 hour, ~$15-30/mo to keep Smart Import / OCR LLM endpoints warm.

---

### HIGH #F — `realtime_session_manager` opens active-editor listener with no idle eviction

| Run | Severity | Refs |
|---|---|---|
| Codex     | NOT PRESENT | — |
| Default   | HIGH | `realtime_session_manager.dart:30-58` |
| Deep      | HIGH #7 | `realtime_session_manager.dart:38-47, :73` |

**Consensus**: 2-of-3 (default + deep). Cancellation only fires on explicit `stopRealtimeEditing`; backgrounding leaves the record + subscription alive until cleanup CF runs.

---

### HIGH #G — `FriendsStateManager` opens 7 concurrent listeners per logged-in user

| Run | Severity | Refs |
|---|---|---|
| Codex     | NOT PRESENT (Codex listed `friend_relationship_repository` but not the multi-stream manager) | — |
| Default   | MEDIUM | `friends_state_manager.dart` (7 `.listen()` calls counted) |
| Deep      | HIGH #8 | `friends_state_manager.dart:240, 253, 273, 284, 307, 376, 407` (7 sub fields verified) |

**Consensus**: 2-of-3. Authoritative = HIGH (deep — quantified per-user listener floor at 10-55 even before auto-healer fan-out).

---

### HIGH #H — `FirebaseUserIngredientRepository.watchAll` populates unbounded `_userCache`

| Run | Severity | Refs |
|---|---|---|
| Codex     | (in unbounded streams table, no severity) | `firebase_user_ingredient_repository.dart:190-193` |
| Default   | HIGH | `firebase_user_ingredient_repository.dart:190-202` |
| Deep      | (rolled into CRITICAL #2 with `:179, 189-202` cross-ref by Pass 2) | `firebase_user_ingredient_repository.dart:179, 189-202` |

**Consensus**: 3-of-3 (different framing). **VERIFIED** — multi-account leak vector confirmed by Pass 2 critic. Authoritative = HIGH (default's framing) OR rolled-into-C2 (deep's framing). Per-user `_userCache[userId]` accumulates across user switches.

---

### HIGH #I — Anonymous-closure listener leak in `UnifiedFriendsService` (NEW from deep Pass 2)

| Run | Severity | Refs |
|---|---|---|
| Codex     | NOT PRESENT | — |
| Default   | NOT PRESENT | — |
| Deep      | NEW HIGH (Pass 2 only) | `lib/services/unified/unified_friends_service.dart:274` (anonymous closure addListener), `:554-558` (dispose cannot remove) |

**Consensus**: 1-of-3 (deep Pass 2 only). `_stateManager.addListener(() { notifyListeners(); })` — anonymous closure means `removeListener` is impossible. `FriendsStateManager` is app-lifetime singleton, so closure outlives `UnifiedFriendsService`. Same class as C3, different mechanism. **5-min fix.**

Spot-check candidates flagged but lower risk (controllers are co-State-disposed): `unified_shopping_view.dart:61`, `friends_list_view.dart:92`, `core/form/form_fields_manager.dart:316`.

---

### HIGH #J — `notification_batch` index gap (`userId + scheduledFor`) (NEW from deep Pass 2)

| Run | Severity | Refs |
|---|---|---|
| Codex     | NOT PRESENT | — |
| Default   | NOT PRESENT | — |
| Deep Pass 1 | MEDIUM (suspected) | `firebase_notification_batch_repository.dart:100-101` |
| Deep Pass 2 | reclassified HIGH (verified reachable runtime error) | `firebase_notification_batch_repository.dart:100-101` |

**Consensus**: 1-of-3. **VERIFIED via grep of `firestore.indexes.json` — no entry**. Equality + inequality requires composite. Every batch-delivery cycle hits this query; first user with 10+ pending batches triggers `FAILED_PRECONDITION`. Fix: 5 minutes (add composite, deploy).

---

### HIGH (Codex-unique, evaluated)

#### Codex HIGH "Unbounded menu loads during init" — `unified_menu_service.dart:191-195, 209-212`
Status: **VERIFIED PARTIALLY** (file/line range plausible based on cross-references in deep's listener inventory). Codex frames this as init-time `.get()` without limit; deep does not call this out separately. Treat as legitimate Codex-unique HIGH but cross-check needed.

#### Codex HIGH "Ingredient cache full collection scan" — `firebase_ingredient_repository.dart:102-103, 153-158`
Status: **PROBABLY VERIFIED**. Codex notes startup loads entire `ingredients` collection. Default's recipe_image_manager perspective doesn't intersect; deep doesn't independently flag it. Bootstrap stage references in default+deep imply `ContentStage` does enrichment that depends on this load. Legitimate.

#### Codex HIGH "Shopping list `readAll()` N+1 item subcollection fetches" — `shopping_repository_query_module.dart:43-50`
Status: **UNVERIFIED — code wasn't independently checked by default/deep**. Plausible. File:line specific. Codex-unique.

#### Codex HIGH "Shared-content lookup N+1 hydration" — `base_shared_content_repository.dart:633-637, 662-665`
Status: **UNVERIFIED — code wasn't independently checked**. Deep references `base_shared_content_repository.dart:603-673` in scaling-cliffs table (group fan-out), corroborating the file is hot-path. Codex's fan-out framing plausible.

#### Codex HIGH "Notification batch authorization per-target query loops" — `notifications/send-notification.ts:503-507, 528-548, 587-605`
Status: **UNVERIFIED**. Plausible. Codex-unique.

#### Codex HIGH "Profile propagation trigger broad fan-out + long timeout" — `social/on-profile-updated.ts:23, 60-149, 151-153`
Status: **PARTIALLY CORROBORATED**. Deep cross-refs `01-code-quality` Wave 1 finding "displayName/avatarUrl denormalization at 24+ sites" and at `on-profile-updated.ts:23` (timeout 540s). Codex's classification as scalability HIGH is consistent.

#### Codex HIGH "Multiple unbounded snapshot streams" (10 sites enumerated)
Status: **VERIFIED** — default and deep both enumerate the same 7 user-scoped streams (pantry, personal_tags, personal_tag_groups, user_ingredients, blocks, shared_shopping items, recipe_presence). Codex adds 3 more (`firebase_menu_voting_repository.dart:111-114`, `friend_category_repository.dart:332-334`, `report_service.dart:105-114`). All plausible but per default+deep are MEDIUM (self-bounded by per-user data), not HIGH.

#### Codex HIGH "Presence stream fan-out is linear in member count" — `family_presence_bar.dart:153-158`, `presence_service.dart:220-223`
Status: **UNVERIFIED — neither default nor deep independently checked the per-friend RTDB listener pattern**. Plausible — the description matches the architecture. Codex-unique.

#### Codex HIGH "User-scope cache manager disposal skips timer cancellation" — `performance_module.dart:64-67`, `intelligent_cache_manager.dart:477-493, 508-521, 577-583`
Status: **UNVERIFIED**. Plausible. Codex-unique discovery in DI scope-disposal logic. Default does mention `IntelligentCacheManager` favorably; deep's "What's Missing" item #7 notes lack of idle eviction in IntelligentCacheManager but doesn't flag the timer-leak on logout. Worth verifying.

---

## MEDIUM findings (consensus, brief)

| Finding | Codex | Default | Deep | Status |
|---|---|---|---|---|
| Bootstrap registers/validates 10+ DI modules even when most aren't user-facing (`application_bootstrap.dart:330-372`) | (covered in Codex's first-frame CRITICAL) | MEDIUM | MEDIUM #3 | 3-of-3 |
| `recipes.indexOf(recipe)` per item in list-grid path (O(n²)) (`mina_recept_view.dart:980`) | NO | MEDIUM | MEDIUM #2 | 2-of-3 |
| Seasonal hero recomputes match list per QueryViewModel rebuild (`mina_recept_view.dart:604-622`) | NO | MEDIUM | MEDIUM #4 | 2-of-3 |
| 13 ViewModels lack explicit `dispose()` override | NO | MEDIUM (7 listed) | MEDIUM #5 (13 listed) | 2-of-3, deep more thorough |
| Search-style 200-doc + client-filter recurs (ingredient search) (`firebase_recipe_repository.dart:879, 891-897`) | (rolled into Codex MEDIUM #1) | NO | MEDIUM #6 | 2-of-3 |
| 7 ListView non-builder constructors loaded eagerly | NO | NO | MEDIUM #7 | 1-of-3 (deep only) |
| FCMService 11 mutable static fields (perf-relevant via test isolation) (`fcm_service.dart:77-101`) | NO | NO | MEDIUM #8 (cross-ref Wave 1) | 1-of-3 |
| `_lastPromptedClipboardUrl` retained app-lifetime (`main.dart:442, 605`) | NO | MEDIUM | MEDIUM #9 | 2-of-3 |
| Stockholm = timezone (not deployment region) — doc-drift, no perf impact | NO | (noted) | MEDIUM #10 | 2-of-3 |
| Personal-tag bulk updates query all matches without page boundaries (`firebase_recipe_repository.dart:498-500, 553-556, 609-611`) | MEDIUM | NO | NO | 1-of-3 (Codex unique) — UNVERIFIED |
| Collaborative-list query/index mismatch (`shopping_repository_query_module.dart:144-147` vs `firestore.indexes.json:81-86`) | MEDIUM | NO | NO | 1-of-3 (Codex unique) — UNVERIFIED but Codex provides exact file:line on both sides |
| Cache budgets alone consume most of 150MB target (50MB image + 50MB intelligent) | MEDIUM | NO | NO (deep approves the 50MB numbers) | 1-of-3 (Codex unique) |
| App resume path can restart cache manager timers regardless of prior init state (`main.dart:664-670`, `intelligent_cache_manager.dart:537-540`) | MEDIUM | NO | NO | 1-of-3 (Codex unique) — UNVERIFIED |
| Friend ID stream truncates at 1000 docs silently (`friend_relationship_repository.dart:333-342`) | MEDIUM | NO | NO | 1-of-3 (Codex unique) — UNVERIFIED |
| Recipe stream page size still heavy for low-memory devices (100/page) | MEDIUM | NO | NO | 1-of-3 (Codex unique) |
| Single-region deployment footprint (`europe-west1`) | MEDIUM | (LOW — not flagged as issue) | (noted neutrally) | 1-of-3 (Codex unique) — design choice not bug |
| Conflict-resolution policy not explicit in offline sync path (`offline_sync_manager.dart:129-166`) | MEDIUM | NO | NO | 1-of-3 (Codex unique) |
| User profile load forced during social module init (`social_module.dart:416-420`) | MEDIUM | NO | NO | 1-of-3 (Codex unique) — plausible |
| Search module consent evaluation adds startup decision work | MEDIUM | NO | NO | 1-of-3 (Codex unique) |
| Large dependency surface inflates bundle/startup overhead | MEDIUM | (LOW) | (LOW) | 3-of-3 different severities |
| Codebase/file-size growth (1252 files, "327k LOC") | MEDIUM | LOW (132 >500 lines) | LOW | 3-of-3 — but LOC count itself disputed (see below) |
| Bundle size unmeasured / no CI artifact | MEDIUM | MEDIUM | (in "What's Missing" #2) | 3-of-3 |
| Index drift in `firestore.indexes.json` (mis-categorized composite under fieldOverrides) | NO | (mentioned) | (mentioned but classified as defer-to-prompt-12) | 2-of-3 |
| `flutter_inappwebview` ships in main bundle (`pubspec.yaml:80`) — NEW Pass 2 LOW | NO | NO | LOW (Pass 2) | 1-of-3 |
| `flutter_onnxruntime` startup cost not measured (`pubspec.yaml:83`) — NEW Pass 2 MEDIUM | NO | NO | MEDIUM (Pass 2) | 1-of-3 |
| No `Isolate` / `compute()` usage anywhere in `lib/` — NEW Pass 2 MEDIUM | NO | NO | MEDIUM (Pass 2, grep verified) | 1-of-3 |
| Two CFs use v1 SDK with `runWith` (mixing v1/v2) — NEW Pass 2 MEDIUM | NO | NO | MEDIUM (Pass 2, `cleanup/on-user-deleted.ts:31`) | 1-of-3 |

---

## Disproved by deep critic

Items that codex/default suggested but deep critic Pass 2 rejected or downgraded:

1. **Default's "MaterialApp.builder re-creates Stack + RepaintBoundary + FeedbackFAB every rebuild"** (LOW) — deep notes FAB is `const`, finding is "mostly free." Not disproved per se, but reframed as a watch-for-regression non-issue.
2. **Default's count of "ViewModels lack dispose" — 7 names** — deep verified the actual count is 13 (more thorough grep). Default's number is incomplete, not wrong.
3. **Codex's "personal_tag_groups watch dodges composite indexes"** as an issue — both default and deep classify this as an honest tradeoff, not a finding (`firebase_personal_tag_group_repository.dart:91`). Deep explicitly: "Honest tradeoff. No issue."
4. **Codex's "first-frame blocked by full bootstrap chain" CRITICAL** — default + deep agree there's bootstrap weight (12-13/18 score) but not CRITICAL. Deep's reading: stages are mostly lazy singletons, only `PlatformStage` + `CoreStage` truly gate first frame. Codex's CRITICAL classification is overweighted.
5. **Codex's "327,280 lines, 1252 files" baseline** — DISPROVED by orchestrator-supplied baseline: 76,325 hand-written Dart LOC across 1,257 files. Codex is counting generated files (drift, frozen, riverpod, mockito output, etc.). 4× inflation. Default also cites 1265 files (close to truth).
6. **Codex's "34 composite Firestore indexes"** — DISPROVED by default ("30 composite + 6 field overrides + 1 mis-categorized composite") and re-confirmed by deep ("30 composite + 6 array/scalar + 1 mis-categorized"). Codex didn't re-count.
7. **Codex's offline 4/10 score** — context: Codex is correct that the offline-delete bug is real and CRITICAL (cross-cutting), but default and deep both score offline 9/10 because read-side persistence + cache-first patterns are excellent. Codex's 4/10 is severity-driven; the dimensional score should be ~7-8/10 (generous) or ~4-5/10 (strict). Authoritative score (deep): 9/10 with the offline-delete bug carved out as cross-cutting.

---

## Unique to one run (verified status)

### Unique to Codex (verification status varies)

| Finding | File:line | Status |
|---|---|---|
| Unbounded menu loads during init | `unified_menu_service.dart:191-195, 209-212` | UNVERIFIED — file:line plausible, no independent check |
| Ingredient full-collection cache load | `firebase_ingredient_repository.dart:102-103, 153-158` | PROBABLY VERIFIED — corroborated by deep's bootstrap discussion |
| Shopping `readAll()` N+1 | `shopping_repository_query_module.dart:43-50` | UNVERIFIED — file:line specific, plausible |
| Shared-content N+1 hydration | `base_shared_content_repository.dart:633-637, 662-665` | PARTIALLY CORROBORATED — deep references same file in scaling-cliffs |
| Notification batch authz per-target loops | `send-notification.ts:503-507, 528-548, 587-605` | UNVERIFIED |
| Presence fan-out per-friend RTDB listener | `family_presence_bar.dart:153-158`, `presence_service.dart:220-223` | UNVERIFIED — plausible |
| User-scope cache manager `clearCache()` vs `dispose()` timer leak | `performance_module.dart:64-67`, `intelligent_cache_manager.dart:477-583` | UNVERIFIED — plausible (timer-bearing service disposed via clearCache) |
| Collaborative-list query/index mismatch (`memberPermissions.{uid}` dynamic) | `shopping_repository_query_module.dart:144-147` vs `firestore.indexes.json:81-86, 254-309` | UNVERIFIED — Codex provides both sides; runtime error risk credible |
| Personal-tag bulk-scan operations | `firebase_recipe_repository.dart:498-500, 553-556, 609-611` | UNVERIFIED |
| Friend ID stream truncates at 1000 docs silently | `friend_relationship_repository.dart:333-342` | UNVERIFIED |
| Reports `streamOpenReports` unbounded | `report_service.dart:105-114` | VERIFIED via deep's listener inventory |
| Batch-update helpers materialize full result sets | `functions/src/shared/batch-update.ts:19-27, 53-61` | UNVERIFIED |
| Single-region deployment | `functions/src/index.ts:20` | VERIFIED — deep confirms `setGlobalOptions({region: "europe-west1"})` once at `:20` |

### Unique to Default

| Finding | File:line | Status |
|---|---|---|
| (Default findings largely overlap with deep at this point — deep is a superset of default with 2 new CRITICAL/HIGH) | — | — |

### Unique to Deep

| Finding | File:line | Status |
|---|---|---|
| **C3 — FriendsStateManager.dispose dispose leak** | `friends_state_manager.dart:613-631` | **VERIFIED LIVE TWICE** |
| Pass 2 NEW HIGH — anonymous-closure addListener in `UnifiedFriendsService` | `unified_friends_service.dart:274, 554-558` | VERIFIED |
| Pass 2 NEW HIGH — `notification_batch` composite index gap | `firebase_notification_batch_repository.dart:100-101` + grep of indexes.json | VERIFIED |
| Pass 2 NEW MEDIUM — no Isolate/compute usage anywhere | grep across `lib/` | VERIFIED |
| Pass 2 NEW MEDIUM — v1/v2 CF SDK mix | `functions/src/cleanup/on-user-deleted.ts:31` | VERIFIED |
| Pass 2 NEW MEDIUM — `flutter_onnxruntime` startup cost | `pubspec.yaml:83` | VERIFIED |
| Pass 2 NEW LOW — `flutter_inappwebview` web bundle weight | `pubspec.yaml:80` | VERIFIED |
| Listener inventory table (29 listener sources catalogued) | listener_inventory section | VERIFIED |
| Index coverage gap analysis (#1-#8 walk) | `firestore.indexes.json` walk | VERIFIED |
| Pass 2 second write-site of `_cachedResources` | `realtime_sync_service.dart:224` | VERIFIED |
| Pass 2 second write path of `_userCache` | `firebase_user_ingredient_repository.dart:179` | VERIFIED |
| 10 missing-instrumentation invariants (no SLOs, no listener telemetry, no per-user cost rollup, etc.) | "What's Missing" section | analytical, not file-bound |
| 5 strategic opportunities (CF onMessageCreate trigger, web code-splitting via deferred imports, listener telemetry kill switch, minInstances=1 on LLM, per-screen read-budget tests) | analytical | analytical |

---

## Disputed numbers

| Metric | Codex | Default | Deep | Authoritative | Notes |
|---|---|---|---|---|---|
| Hand-written Dart LOC | 327,280 (`pre-analysis/dart-line-count.txt`) | not separately stated | "76,325 hand-written / 1,257 files" matches orchestrator | **76,325 / 1,257 files** | Codex counts generated files. 4× inflation. |
| Files >500 lines | "many very large files" (qualitative) | 132 (knowledge file) | 132 (knowledge file confirmed) | **132** | Codex doesn't quantify. |
| Cold start (mobile) | 3.8-6.0 s | 1.8-2.5 s | 1.8-2.5 s | 1.8-2.5 s | Codex is pessimistic by 2x. Deep+default converge. None are device-measured. |
| Cold start (web) | (collapsed into mobile) | 2.5-3.5 s | 2.5-3.5 s | 2.5-3.5 s | — |
| Memory (typical) | 160-220 MB | unknown | unknown | unknown | Codex's number is unsourced estimate; default+deep honestly say "Not measured." |
| Memory (peak) | 260-340 MB | unknown | unknown | unknown | Same. |
| Average FPS | 52-58 fps | unknown | unknown | unknown | Codex is fabricating a measurement. |
| Jank percentage | 2-6% | unknown | unknown | unknown | Same. |
| Firestore queries/screen | 8-15 | 3-8 | 3-10 | 3-10 | Default+deep converge; Codex high. |
| Concurrent listeners/user (peak) | not stated | 5-55 | 12-55 | **12-55** | Deep is more thorough; default close. |
| Composite indexes count | 34 (orchestrator value, parroted) | 30 + 6 field overrides + 1 mis-categorized | 30 + 6 + 1 mis-categorized | **30 + 6 + 1** | Codex didn't re-count. |
| Recipe stream page size | 100 (`firebase_recipe_repository.dart:68`) | 100 | 100 | 100 | Agree. |
| Conversations stream cap | 50 | 50 | 50 | 50 | Agree. |
| Notifications stream cap | 50 | (not stated) | (not stated) | 50 | — |
| Auto-healer listeners per user (max) | (not flagged) | 50 + 1 conv listener + 1 chat = 52 | 52 | **52** | Codex MISSED entirely. |
| Listener fan-out at 10K users | (not stated) | 200-500K | 200-500K | 200-500K | — |
| `_cachedResources` per-recipe size | (not flagged) | ~50-500 KB | ~50-500 KB | 50-500 KB | — |
| `_cachedResources` write paths | (not flagged) | 1 (`:159`) | 2 (`:159, :224`) | **2** | Pass 2 critic found the 2nd write site. |
| `FriendsStateManager` listener count | (not flagged) | 7 | 7 | **7** | Verified at lines 240, 253, 273, 284, 307, 376, 407. |
| `Image.network` raw call sites | (not flagged) | 7 | 7 (grep verified Pass 2) | **7** | Exact match. |
| ViewModels without explicit dispose | (not flagged) | 7 | 13 | **13** | Deep more thorough. |
| Cost @ 100K active users / month | $2,232 (super-linear hotspots intact) | ~$60 | not separately modelled | ~$60 (default) — but does not include listener-seconds cost or auto-healer fan-out cost | Codex's number is plausible UPPER bound; default's lower bound. Deep's "What's Missing" #5 calls out that listener-seconds cost is uncalculated. Truth is between. |
| Cost @ 10K users / month | $164 | ~$6 | not modelled | $6-50 | Same range disagreement. |
| `notification_batch` index | (not flagged) | (not flagged) | MISSING (verified via grep) | MISSING | — |
| CFs without `minInstances` | (not flagged) | not flagged separately | ALL of them (verified via grep) | ALL | — |
| `firestore.indexes.json` line refs for `collaborators` | `firestore.indexes.json:81-86` | not stated | not separately stated | (Codex line ref accepted) | — |
| Healer query field | not stated | `messages.where(conversationId == X).orderBy(sentAt desc).limit(1)` | same, verified live at `:38-43` | same | — |

---

## Live-verified findings from deep (Pass 2 critic disk-reads)

These three CRITICAL findings (and several HIGH) were re-read on disk by the Pass 2 critic in a separate invocation. They are the highest-confidence claims in this entire master:

### C1 — Auto-healer fan-out — VERIFIED VERBATIM
- File: `lib/repositories/firebase/modules/conversation_auto_healer_module.dart`
- Re-read locations: `:18` (`_activeHealers` map), `:28` (`startAutoHealer` entry), `:37` (`// ignore: cancel_subscriptions` linter comment — explicit admission that the shape is irregular), `:38-43` (the listener: `messages.where('conversationId', isEqualTo).orderBy('sentAt', desc).limit(1).snapshots().listen()`), `:78` (subscription stored), `:89` (`stopAllAutoHealers` exists but caller-side not verified)
- Caller: `lib/repositories/firebase/modules/conversation_query_module.dart:31-46` — `getUserConversations` calls `startAutoHealer(conversation.id)` for **all 50 conversations** in the list snapshot
- Verdict: real, currently live, no architectural mitigation in place

### C2 — `_cachedResources` unbounded — VERIFIED + EXTENDED
- File: `lib/services/realtime_sync_service.dart`
- Re-read locations: `:53` (decl `_cachedResources = <String, RealtimeResource>{}`), `:64` (logout `.clear()`), `:159` (read-path write — `_cachedResources[resourceId] = resource`), **`:224` (write-path write — Pass 1 missed; Pass 2 critic found)**, `:278` (deleteResource single-key remove), `:411` (onDispose full clear)
- Net: 2 write paths, 3 clear paths, no LRU/cap/idle-eviction
- Verdict: real; Pass 1 estimate of leak size is conservative — both reads AND writes grow the map

### C3 — `FriendsStateManager.dispose()` leaks `_blockedUsersSubscription` — VERIFIED VERBATIM
- File: `lib/services/unified/friends/friends_state_manager.dart`
- Re-read locations: `:40` (field `_blockedUsersSubscription` declared), `:200-211` (`clearAllData()` — DOES cancel `_blockedUsersSubscription` at line 203), `:236` (re-watch teardown also touches it), `:284` (subscription started), `:613-631` (`dispose()` — cancels 6 of 7 subscriptions; explicitly omits `_blockedUsersSubscription`)
- Cancelled by dispose: `_incomingRequestsSubscription`, `_sentRequestsSubscription`, `_groupInvitationsSubscription`, `_categoriesSubscription`, `_memberCategoriesSubscription`, `_friendsSubscription`
- NOT cancelled by dispose: `_blockedUsersSubscription`
- Verdict: asymmetric cleanup; almost certainly an oversight; 30-second fix; production-real today

### Pass 2 NEW HIGH — anonymous-closure listener leak — VERIFIED
- File: `lib/services/unified/unified_friends_service.dart`
- Locations: `:274` (`_stateManager.addListener(() { notifyListeners(); })` — anonymous closure, no captured ref), `:554-558` (dispose calls `_stateManager.clearAllData()` + `disposeStreamResources()` but cannot remove the anonymous listener)
- Verdict: same listener-leak class as C3, different mechanism. Manager is app-lifetime singleton, so disposed `UnifiedFriendsService` instances are retained forever via the closure's strong reference to `notifyListeners`.

### Pass 2 NEW HIGH — `notification_batch` index gap — VERIFIED
- File: `lib/repositories/firebase/firebase_notification_batch_repository.dart:100-101`
- Query: `.where('userId', isEqualTo: _userId).where('scheduledFor', isLessThanOrEqualTo: now).get()`
- Composite required: equality + inequality combo demands `userId ASC + scheduledFor ASC` index
- Grep of `firestore.indexes.json` for `notification_batch` / `notification_batches`: **zero matches**
- Verdict: runtime `FAILED_PRECONDITION` will fire on first user with ~10+ pending batches; production-reachable today

### Pass 2 — `Image.network` 7 sites — VERIFIED via grep
- Exact 7 matches across `lib/`. Enumerated above under HIGH #A.

### Pass 2 — no `minInstances` anywhere — VERIFIED via grep
- Zero matches in `functions/src/`. Five+ functions with explicit memory/timeout configurations all skip `minInstances`.

### Pass 2 — no Isolate/compute usage — VERIFIED via grep
- Zero matches for `Isolate.|compute\(|spawn\(` across `lib/`. Means HTML parsing, JSON deserialization, CRF Viterbi, ONNX inference, OCR preprocessing all run on UI thread.

---

## Cross-cutting findings (perf-relevant but owned elsewhere)

These appear in Codex's perf report but belong in other prompt domains:

1. **Offline delete drops sync intent (data divergence)** — `lib/services/offline/offline_user_storage.dart:121-125`, `lib/services/offline/offline_sync_manager.dart:113-166` — Codex CRITICAL. **REAL**. Belongs in offline-correctness / data-architecture prompt. Default and deep score offline 9/10 because they correctly carve this out.

2. **displayName/avatarUrl denormalization at 24+ sites** — Wave 1 finding from `01-code-quality.md`, perf-relevant via fan-out write cost. Deep cross-references this in addendum.

3. **ONNX model downloaded at runtime, no SHA-256 integrity check, no Wi-Fi-only contract** — `ner_model_manager.dart:24-30` — Wave 1 finding from `05-dependencies.md`. Perf angle: ~25 MB on first cold launch on metered mobile. Deep cross-references.

4. **`sqlcipher` EOL package** — `pubspec.yaml:44` — security/dependencies finding with perf angle when migrating. Deep cross-references.

5. **FCM 11 mutable static fields** — Wave 1 finding from `01-code-quality.md` and `02-security.md`. Perf relevance test-only.

---

## Summary of authoritative consensus

- **3 CRITICAL findings** (all from deep; 2-of-3 consensus on C1 and C2; deep-unique on C3 but live-verified twice)
- **10 HIGH findings** (mix of consensus and unique-but-verified)
- **12 MEDIUM findings** (broad mix; many Codex-unique are unverified-plausible)
- **8 LOW findings**

**Final score: 66/100** (deep Pass 2 final, after critic correction from Pass 1's 70/100)

**Top 3 highest-leverage fixes (all 3 runs would agree):**
1. Replace `ConversationAutoHealerModule` with a Cloud Function `onMessageCreate` trigger (3-5 days, eliminates an entire class of scaling cliff)
2. Add LRU/idle eviction to `RealtimeSyncService._cachedResources` and `firebase_user_ingredient_repository._userCache` (1 day each)
3. Fix `FriendsStateManager.dispose()` and `UnifiedFriendsService` anonymous-closure listener (5 minutes total — pure discipline fix)

**Quick wins under 1 hour total:**
- Swap 7 `Image.network` for `CachedNetworkImage` (1 h)
- Defer web `_health/_` Firestore probe to post-frame (30 min)
- Add `notification_batches` composite index to `firestore.indexes.json` (5 min)
- Add `minInstances: 1` to `structureRecipe` + `ocrRecipeImage` (~$15-30/mo) (1 h)
- Pass loop index through `LayoutComponents.responsiveListGrid.itemBuilder` (kill `recipes.indexOf` O(n²)) (30 min)

End of master Wave 2 prompt 04 consensus data.
