# Sprint Backlog

## Sprint: social conflict-cleanup + activity/sharing UI — 2026-06-14 (iter-150)

Focus = `social` area label (per orchestrator). Backlog scan: 10 social-labeled Backlog tickets + 5 Todo carryover (Triage/In Progress empty). The prior sprint's only pick, BUT-1265, is already on `main` (HEAD `f37c9af03`) — confirmed obsolete-vs-open and listed below.

Selected 5 buildable social tickets: **2 build (Tier A)** + **3 build-review (Tier B)**. The rest of the social pool is `idea`-labeled speculation, ops-blocked, or large GDPR scope → flagged under "Needs you", not built.

Batches are file-disjoint so they can run in parallel worktrees without patch collisions.

### Agent A: social-realtime — conflict-module cleanup + coverage `[Tier A]`
- [ ] **A1. Delete dead duplicate `RealtimeSyncService.resolveConflict` + re-point its pinning tests** `[Tier A]` — `lib/services/realtime_sync_service.dart` (delete method, lines ~377-409), `test/unit/services/realtime_sync_service_test.dart` (remove/re-point the 4 last-write-wins tests that exercise the dead copy). (BUT-1267)
  - Acceptance: `RealtimeSyncService.resolveConflict<T>(T local, T remote)` is removed entirely · no test references the deleted method (the 4 last-write-wins tests are deleted or re-pointed to the live `_conflictModule`/`updateResource` emit path) · `grep` shows zero callers of the bare service-level `resolveConflict` remain · `flutter test test/unit/services/realtime_sync_service_test.dart` passes green
- [ ] **A2. Module-level tests for the three FALSE branches of `shouldResolveConflict`** `[Tier A]` — `test/unit/services/realtime/conflict_resolution_module_test.dart`: add tests for (a) no prior `recordLocalUpdate` (lastUpdate null), (b) 5000ms window elapsed, (c) remote not after lastUpdate. (BUT-1266)
  - Acceptance: a test asserts `shouldResolveConflict` returns false when no `recordLocalUpdate` preceded it · a `withClock` test asserts strict window boundary — true/conflict at 4999ms, false at 5000ms (proves `<` not `<=`) · a test asserts false when remote `lastEditedAt` is not after `lastUpdate` · all new tests drive the real `recordLocalUpdate` + `shouldResolveConflict` path (no injected sink, no pre-seeded controller) · `flutter test test/unit/services/realtime/conflict_resolution_module_test.dart` passes green

### Agent B: social-activity — per-event-type feed toggles + first-time hint `[Tier B]`
- [ ] **B1. Per-event-type activity-feed toggles under the master toggle + one-time onboarding hint** `[Tier B]` — `lib/models/user_profile.dart` (per-type toggle map field, absent=on), `lib/services/social/activity_feed_service.dart` (check master AND per-type before publish), `lib/views/social/user_profile_edit/privacy_section.dart` (toggle UI), one-time hint flag + l10n strings. (BUT-1220)
  - Acceptance: per-type toggles persist on `UserProfile` as a map where an absent key means ON (no migration needed) · `ActivityFeedService` does NOT publish an event whose type toggle is off, even when the master toggle is on · the first-time hint shows exactly once (gated by a profile flag) and is not re-shown after the flag is set · master-toggle-off still suppresses ALL event types (per-type toggles do not override it)
  - Sign-off: defaults + Swedish copy + whether per-type granularity is wanted for beta vs master-only.

### Agent C: social-sharing — "recipes shared by friend X" filter view `[Tier B]`
- [ ] **C1. Per-friend shared-recipes filter view/section** `[Tier B]` — `lib/views/social/shared_with_me/` (new per-friend section/view reusing the shared-content card scaffold), query shared-content where `sharedByUserId == friendId` for the current recipient; viewmodel under `lib/viewmodels/social/`. (BUT-1000)
  - Acceptance: the view lists only shared content where `sharedByUserId == friendId` AND the current user is a recipient (no leakage of content shared to others) · empty state renders when the friend has shared nothing · reuses the existing `shared_recipe_card`/shared-content scaffold rather than a new bespoke card · follows the square/cream design language (no rounded badges/cards)
  - Sign-off: placement (friend profile vs shared-with-me tab) + empty-state copy.

### Agent D: social-cooksnap — cook-snap photo album (multi-photo) `[Tier B]`
- [ ] **D1. Multiple photos per cook snap (album), backward-compatible** `[Tier B]` — `lib/models/cook_snap.dart` (`photoUrls: List<String>`, keep legacy `photoUrl` read-mapped into list, cap 5), `lib/services/cook_snap_service.dart` (upload/storage layout), carousel render in feed + recipe-detail "people who cooked this". (BUT-949)
  - Acceptance: `CookSnap` exposes a photo list capped at 5 · an old document with only the singular `photoUrl` deserializes into a one-element list (no data loss, no migration required) · the feed/detail renders a carousel when >1 photo and a single image when ==1 · uploading more than 5 photos is rejected/capped, not silently truncated mid-list
  - Sign-off: carousel interaction + 5-photo cap + editor UX.

### Needs you (not built — flagged for your call)
- **BUT-934** — premise likely gone: lapsed-user win-back already shipped via BUT-688 (`detect-lapsed-users.ts`, A/B winback). Recommend: verify against the shipped CF and close as obsolete, or reframe to the specific remaining gap.
- **BUT-945** — pure `idea`: "recently removed friends" re-add + "past groups". Speculative discoverability feature, no concrete demand. Recommend: drop until a real request.
- **BUT-840** — ops/infra-adjacent: extend `on-profile-updated.ts` to refresh an Algolia search mirror. Needs confirmation Algolia is wired + the mirror index exists. Recommend: confirm Algolia infra before building.
- **BUT-674** — large GDPR/security product scope: minors (15-17) parental consent + social restrictions + minimization. Recommend: scope as its own legal/product decision, not an autonomous sprint pick.
- **BUT-1179** — Tier D manual QA: live concurrent-edit ConflictBanner verification across 3 surfaces; can't be unit/widget-tested. Recommend: run by hand on a device when convenient.

### Obsolete (done in git, still open in Linear)
- **BUT-1265** — already on `main` at `f37c9af03` ("test(realtime): end-to-end conflictStream delivery test"). Close to Done.

### Post-Sprint Steps
- [ ] Run `dart analyze --fatal-infos`
- [ ] Run relevant unit tests (realtime sync + conflict module; activity feed; cook snap)
- [ ] Phase 2.7 outcome-grading (fresh-context verifier per agent group)
- [ ] Commit, push
- [ ] Linear: Tier A (BUT-1267, BUT-1266) → Done; Tier B (BUT-1220, BUT-1000, BUT-949) → In Review + notify; BUT-1265 → Done (obsolete close)

---
## ARCHIVED — iter-149 (BUT-1265 conflictStream end-to-end delivery test — landed `f37c9af03`) · iter-148 (BUT-1263/1264 recoverLocalVersion test-gaps — HEAD d4ee51b0f) · iter-147 (BUT-1262 realtime data-loss-path sign-off) · iter-146 (BUT-1053/1247/1250) · iter-145 (BUT-1251/1246/1249 Done) · iter-144 (BUT-648/1057 In Review) · iter-143 (BUT-1245/626 Done) · äldre i git-historiken
