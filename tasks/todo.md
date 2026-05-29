# Sprint Backlog

## Sprint: iter-103 — 4 code-only tech-debt tickets (PLANNED, not yet implemented) — 2026-05-29 (Fri)

**Status: PLANNED ONLY.** Selection done in a long session; implementation deferred to a fresh session for quality. All 4 transitioned to "Todo" in Linear. None are risk-gated (all P3/P4 tech-debt, no security/Bug → no Phase 1.5 expansion). Ops-blocked tickets (App Check client BUT-1166, AI ops BUT-1167, store/deploy/MFA) and EPICs were deliberately excluded.

**Fresh session: re-run Step 0 per ticket** (`get_issue` for the full description — the lines below are summaries; current code-read wins over ticket text).

### Batch A — backend / realtime (independent files)

- [x] **A1. BUT-1165: iter-99 review follow-ups** — RESOLVED (iter-103a). Umbrella's actionable notes were unrecoverable (sprint-scratch overwritten, no durable code markers). Spot-check confirmed all 6 areas shipped defensively with tests in `631fceec4`. Closed honestly + captured umbrella anti-pattern lesson. (BUT-1165, P3)
- [x] **A2. BUT-472: audit `lib/services/unified/modules/realtime_session_manager.dart`** — DONE (iter-103a). Premise re-scoped: file is a stateless static helper; maps owned by `RealtimeRecipeModule`; dispose chain (`UnifiedRecipeService.dispose` → `module.dispose` → `RealtimeCacheManager.dispose`) is complete + tested at every layer. No leak. Added a module-level leak guard asserting `dispose()` leaves zero outstanding handles across all 3 maps. (BUT-472, P3)

### Batch B — tech-debt / data

- [~] **B1. BUT-520: migrate standalone ViewModels → `BaseViewModel`** — iter-103b: migrated `create_shared_list_viewmodel.dart` (raw ChangeNotifier hand-rolling `_error`/`_setError` with NO disposed-guard → `BaseViewModel`; fixes a latent disposed-notify bug; all 32 tests green unmodified). **Premise corrected** (Step 0): the ticket's "62 raw ChangeNotifier VMs" conflates 3 populations — 24 already use `StateNotifierMixin` (a *superset* of BaseViewModel incl. disposed-guarding + `executeNamedOperation`; migrating them = DOWNGRADE, do NOT), ~14 are tiny selection/state managers with no loading/error (BaseViewModel = no-op churn), only ~10 genuinely hand-roll loading/error (the real targets, several with operation-specific flags). EPIC stays open with the refined target list. (BUT-520, P4)
- [x] **B2. BUT-1164: migrate legacy `meatFish`/`fruitVeg` shopping categories → fine-grained `meat`/`fish`/`fruit`/`veg`** — DONE (iter-103a, write-side slice). `ShoppingCategoryMapper` now emits fine-grained buckets (deterministic from group path, no data migration). Backfill of existing docs + legacy-constant removal deferred to BUT-1169 (needs telemetry + Cloud Function). (BUT-1164, P4)

### iter-103c (continuation — backlog picks)

- [x] **BUT-1111: `FakePermissionService.setPermissionState` auth toggle** — fix: honor explicit `isAuthenticated:false` even when `currentUser` is set (was unconditionally forced true). Added `fake_permission_service_test.dart` (4 tests pinning the toggle). Test-infra only. (BUT-1111, P4)
- [~] **BUT-1122: loadMoreContent dead-code guardrail** — premise-gone (closed). The `supportsPagination` throw-gate superseded the duplicate-risk; guardrail tests already exist in `shared_shopping_viewmodel_test.dart:743-758`. No code change. (BUT-1122, P4)

### iter-103d (continuation — backlog picks)

- [x] **BUT-1121: joinSharedMenu inner addParticipant catch independence** — added test proving the inner "continue anyway" catch is independent of the outer catch: with `addParticipant` throwing, the collaborative join still returns a `MenuJoinResult` (isCollaborative, correct menuId), still marks the share joined, and sets NO error banner. New `_CollaborativeSharedMenuRepository` + `_AddParticipantThrowsRealtimeMenuService` test doubles. 33/33 pass, reviewed clean (mutation-verified). Test-only. (BUT-1121, P3)
- [x] **BUT-1123: joinSharedMenu all-failure-paths contract** — DONE (iter-103e). Added 2 tests pinning the remaining internal failure modes: markAsImportedOrJoined-throws (collaborative branch → outer catch → null+banner) and importSharedMenu-throws (static branch → outer catch → null+banner). read-throws already covered by the BUT-1090 regression test; addParticipant-inner-catch by BUT-1121. Both assert `lastError isNotNull` to distinguish a genuine caught throw from an accidental null. 35/35 pass, reviewed clean. (BUT-1123, P4)

### iter-103f (continuation — backlog pick)

- [x] **BUT-1075: BaseSharedContentViewModel injectable PermissionService + UnifiedFriendsService** — DONE (code complete, verified; commit pending a transient Bash-classifier outage). Added optional ctor params to the base VM (resolved via `?? ServiceLocator.get/tryGet`, behavior-identical) + super-parameter forwarding in the 3 subclasses (recipe/menu/shopping). `currentUserId` now reads the injected `_permissionService`. 2 injection-proof tests added (permissionService + friendsService each override the locator via distinct values). All 206 shared_content tests + 36 recipe-VM tests pass; analyze clean; both review agents clean. (BUT-1075, P4)

### Post-Sprint Steps (for the implementing session)

- [ ] Per-ticket Step 0 (read code; classify fits / premise-gone / plan-stale).
- [ ] `dart analyze --fatal-infos` clean.
- [ ] Relevant unit tests pass.
- [ ] code-reviewer + testing-specialist on staged Dart (commit-gate hooks).
- [ ] Commit (conventional; footer Co-Authored-By Claude Opus 4.8), push to main.
- [ ] Close BUT-1165, BUT-472, BUT-520, BUT-1164 in Linear with the commit SHA.
- [ ] File any deferred follow-ups in Linear before commit.

---

Prior sprints (iter-100 / iter-101 / iter-102) shipped and closed — see git history (`43b3aadb3`, `b091da229`, `c2d95fb65`). This file is sprint-scratch; the durable record is Linear + git.
