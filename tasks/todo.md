# Sprint Backlog

## Sprint: completeness-sweep — widget-test gaps for shipped In-Review UI + 1 security re-review (7 tickets) — 2026-06-14 (iter-156)

The genuinely-clean Tier-A code-only slice is drained (the cooking-mode + user-repo chain BUT-1283/1284/1285/1286 all shipped Done in commit `3bf7a50f3`). What's left buildable is a **completeness sweep**: widget-test gaps on user-facing UI that already shipped to main and is parked In Review (multi-page photo import, multi-URL import, weekly-menu bulk-move, multi-photo cook snaps, activity-feed privacy toggles, shared-by-friend view), plus one stale-marker security re-review. All are clear-mandate Tier-A follow-ups to already-approved/shipped work — they pin acceptance criteria the original Tier-B tickets deferred. Clustered into 4 disjoint-file batches by area (test files don't overlap across batches; the security review touches lib services not tests).

### Agent A: import-tests — widget coverage for the import UI seams
- [ ] **A1. Widget test for PhotoPageStrip (multi-page photo import)** `[Tier A]` — `test/widget/import/photo_page_strip_test.dart` (new), drives `lib/views/photo_import/photo_page_strip.dart`. (BUT-1274)
  - Acceptance: Test renders exactly one tile per page for a multi-page list · A reorder drag fires `viewModel.reorderPage` with the expected indices · Removing a page drops exactly that tile · The add-page affordance is disabled (not tappable) once the page count reaches the 5-page cap
- [ ] **A2. Widget test for multi-URL import view (per-URL rows + retry)** `[Tier A]` — `test/widget/import/import_via_url_view_multi_test.dart` (new), drives `lib/views/import_via_url_view.dart`. (BUT-1275)
  - Acceptance: Pasting N newline-separated URLs renders exactly N per-URL progress rows · A failed row exposes a retry affordance that re-fetches only that row · The import CTA label/count reflects `successfulUrlCount` (partial success) · A single-URL input does NOT render the multi-URL row list (legacy single path)

### Agent B: menu-tests — bulk-move target-picker coverage
- [ ] **B1. Widget test for bulk-move target-picker flow** `[Tier A]` — `test/widget/menu/calendar_weekly_menu_widget_test.dart` (extend existing). (BUT-1280)
  - Acceptance: Entering selection mode + tapping 'Flytta' opens the move-target bottom sheet listing (day, slot) options · Picking a (day, slot) calls `service.bulkMoveEntries` with the expected target and renders the success snackbar · Dismissing the sheet without picking fires no move (service not called) · Existing bulk-move tests in this file still pass (no regression to the selection-mode swap)

### Agent C: social-tests — render-decision + privacy-toggle + shared-view coverage
- [ ] **C1. Widget test: CookSnap photo carousel render decision (>1 vs ==1)** `[Tier A]` — `test/widget/social/cook_snap_photo_carousel_test.dart` (new), drives `lib/widgets/recipe/cook_snap_photo_carousel.dart` + `lib/widgets/recipe/cook_snap_gallery.dart`. (BUT-1269)
  - Acceptance: A >1-photo snap renders `CookSnapPhotoCarousel` with the photo-count badge · A ==1-photo snap renders a single `Image` and NO carousel · A page-change/swipe advances the carousel index · A zero-photo event renders neither (no empty carousel)
- [ ] **C2. Widget test: activity-feed per-type privacy toggles + one-time hint** `[Tier A]` — `test/widget/social/privacy_section_activity_toggles_test.dart` (new), drives `lib/views/social/user_profile_edit/privacy_section.dart`. (BUT-1270)
  - Acceptance: The per-type switch list renders with an absent map defaulting every switch to ON · Toggling a switch persists the updated per-type map (service called with the changed entry) · The first-event hint banner renders exactly once · The hint banner is not re-shown after dismissal/seen
- [ ] **C3. Widget test: SharedRecipesByFriendView render states + design check** `[Tier A]` — `test/widget/social/shared_recipes_by_friend_view_test.dart` (new), drives `lib/views/social/shared_with_me/shared_recipes_by_friend_view.dart`. (BUT-1271)
  - Acceptance: Empty state renders when the friend has shared nothing · List state renders the shared recipes for a friend · Loading and error branches each render their distinct state · Design-language check: no rounded cards/badges in the rendered tree (square/cream per memory UI prefs)

### Agent D: security-review — stale-marker re-review of staple pantry read + isStaple persistence
- [ ] **D1. firebase-backend-security re-review (BUT-1279/930 final diff)** `[Tier A]` — review-only over `lib/services/shopping/*`, `lib/services/menu/weekly_menu_plan_service.dart`, `lib/models/pantry/pantry_item.dart`; refresh `.claude/state/firebase-security-done.marker`. (BUT-1281)
  - Acceptance: The staple pantry read (`_stapleNames()` via `ServiceLocator<AuthRepository>.currentUserId`) is confirmed user-scoped with no cross-user leak path · The new `isStaple` boolean round-trips safely through `PantryItem` `fromFirestore`/`toFirestore` with no rules/permission gap · Any finding above Low is filed as a follow-up Linear ticket (not silently dropped) · `.claude/state/firebase-security-done.marker` is refreshed only after a clean review

### Needs you (not built — flagged for your call)
- **BUT-1282** (Low, no labels) — Attribute the `nextPage()` persistence fix to BUT-675. Pure bookkeeping: the code + test already shipped (in the BUT-930 diff); the only action is moving BUT-675 to Done with a commit reference. Recommendation: **drop or handle as a Linear-comment-only close** — there is no code to build, and auto-implementing it just risks a no-op diff.
- **BUT-1287** (Medium, backend/tech-debt) — Re-attribute the GDPR success-path audit persistence (console → Firestore) to a behavioral ticket. The code + tests already shipped under BUT-1286; this is a claim-vs-diff attribution correction, not a code change. Recommendation: **close as documentation-only** (relabel BUT-1286 or note it here) — nothing to implement.
- **BUT-1288** (Low, test-gap) — Two halves: (a) trivial doc-confirmation that no iOS Info.plist/AppDelegate entry is needed for local timer notifications, and (b) an on-device iOS smoke test that a real timer notification fires. Half (b) is Tier-D (needs a Mac/simulator the loop can't reach). Recommendation: **record the half-(a) decision as a Linear comment; defer half-(b)** to a manual iOS pass — don't auto-close.

### Obsolete (done in git, still open in Linear)
- **BUT-1272** (High, import) — "Multi-URL import fetches concurrently — switch to sequential." Already fully resolved by commit `10325a5bb`: `fetchMultipleUrls` uses a sequential `for`-await loop (not `Future.wait`), with the explanatory comment, AND the non-overlap test exists (`ConcurrencyTrackingUrlImportViewModel` asserts `maxInFlight == 1` in `url_import_viewmodel_test.dart`). Both acceptance criteria met. → close as obsolete referencing `10325a5bb`.

### Post-Sprint Steps
- [ ] Run `dart analyze --fatal-infos`
- [ ] Run relevant widget tests (`test/widget/import/`, `test/widget/menu/`, `test/widget/social/`)
- [ ] Commit, push to main
- [ ] Update Linear: BUT-1274/1275/1280/1269/1270/1271 → Done (Tier A test close-outs, fully verifiable); BUT-1281 → Done if review clean (else file findings + In Review). Close BUT-1272 as obsolete (`10325a5bb`).

---
## ARCHIVED — iter-155 (recipe focus drained; cooking-mode + user-repo follow-up close-out: BUT-1283/1284/1285/1286 Tier A — all shipped Done in commit `3bf7a50f3`; spawned attribution follow-ups BUT-1287/1288; BUT-445/643/976/610/907 needsApproval, BUT-1179/1156 Tier-D/EPIC) · iter-154 (backend thin slice: BUT-734 Tier C user-repo split + BUT-1242 Tier B multi-timer cooking mode — shipped commit 22ab49ae9; spawned BUT-1283/1284/1285/1286) · iter-153 (tagging: area drained; BUT-907 needsApproval) · iter-152 (menu: BUT-1278/1279/1043/930 — commit 1711d297c) · iter-151 (import: BUT-1040/931/947/903/1205 — 673f80c87 + 10325a5bb) · iter-150 (social conflict-cleanup + activity/sharing UI: BUT-1267/1266/1220/1000/949) · iter-149..143 — se git-historiken
