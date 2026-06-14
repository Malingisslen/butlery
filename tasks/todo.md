# Sprint Backlog

## Sprint: backend-rules-and-test-gaps — close the iter-157 verifier follow-ups + a real prod rules gap (5 tickets) — 2026-06-14 (iter-158)

The iter-157 plan (close 4 acceptance-criteria gaps from iter-156) already shipped in commits `74825b1f2`, `ee3f6b487`, `565f1d330`. Its own firebase-backend-security + testing-specialist reviews then filed a fresh wave of follow-ups (BUT-1294..1296, BUT-1287, BUT-1282). This sprint takes the clear-mandate slice of that wave: one genuine production bug (the activity-feed feature cannot write a single event under production Firestore rules) plus four precise, already-acceptance-specified test/bookkeeping closes. Two batches, fully disjoint files: Batch A is backend (firestore.rules + a new rules test + two lib-comment attributions); Batch B is three Dart test files (import VM, social widget, shopping service).

### Agent A: backend-rules — give the activity feed a server-side write rule + attribute two ride-along fixes
- [ ] **A1. Add `activity_events` block to firestore.rules + rules unit test** `[Tier A]` — `firestore.rules`, `functions/src/__tests__/activity-events-rules.test.ts` (new). Mirror the client `validateCreatePermission` (`actorId == request.auth.uid`) as a server-side create rule; scope reads to actor + friends as the feed reads; prove it with a rules test. (BUT-1294)
  - Acceptance: `firestore.rules` has an explicit `match /activity_events/...` block so the collection no longer falls through to the default-deny `match /{document=**}` at line 2067 · A new rules test in `functions/src/__tests__/` proves (a) an authed user CAN create an event with `actorId == own uid`, (b) CANNOT create one with a forged `actorId` for another user, (c) reads are scoped (not world-readable) · The rules test runs green in the existing emulator harness · No other collection's existing rule is loosened by the edit
- [ ] **A2. Attribute the GDPR success-path audit-persistence change to a behavioral note** `[Tier A]` — `lib/repositories/firebase/firebase_user_repository.dart` + `lib/repositories/firebase/modules/user_root_deletion_mixin.dart` (comment only). Add a WHY comment at the `logPermissionCheck(..., auditRepository: auditRepository)` sites recording the console-only → Firestore-persisted (Art.30) transition; the Linear close-out is the primary deliverable. (BUT-1287)
  - Acceptance: Both `deletePublicProfile` and `deleteUserRootDoc` audit-log sites carry a one-line comment naming the console-only → persisted Art.30 transition · No behavioral/logic change to the write path (comment-only diff in lib) · The change is discoverable from the GDPR/audit area, not only from a test ticket
- [ ] **A3. Attribute the onboarding nextPage() persistence fix to BUT-675** `[Tier A]` — `lib/viewmodels/onboarding_viewmodel.dart` (comment only). Add a WHY comment at the `nextPage()` → `_persistStepCompletion(_currentPage)` call (line ~154) noting it fixes forward-step persistence the `setPage` guard misses; primary deliverable is the BUT-675 Linear close-out referencing the shipping commit. (BUT-1282)
  - Acceptance: The `nextPage()` persist call carries a comment explaining the forward-step persistence fix (why `setPage`'s guard alone is insufficient) · No logic change (comment-only diff) · The existing `onboarding_viewmodel_test.dart` nextPage-then-setPage persistence test still passes unchanged

### Agent B: dart-test-gaps — close three precise test-assertion gaps (disjoint test files)
- [ ] **B1. Unit-test `successfulBatchText` getter on the URL-import viewmodel** `[Tier A]` — `test/unit/viewmodels/url_import_viewmodel_test.dart` (extend; file ends at line 1213), drives `lib/viewmodels/url_import_viewmodel.dart`. (BUT-1295)
  - Acceptance: A VM unit test with rows `[success, failure, success]` asserts `successfulBatchText == "text1\n\ntext3"` (failed row excluded, blank-line `\n\n` separator) · A single-success case and an all-failure case pin boundary behavior (all-failure → empty string) · Test-only change — no file under `lib/` is modified · The existing url-import VM tests still pass
- [ ] **B2. Assert retry FIRES on the shared-recipes error state** `[Tier A]` — `test/widget/social/shared_recipes_by_friend_view_test.dart` (extend), drives `lib/views/social/shared_with_me/shared_recipes_by_friend_view.dart`. (BUT-1296 part 1)
  - Acceptance: The error-state test taps the retry control and verifies `refreshAllContent` is invoked (a dispatch assertion via spy, not just a label `find`) · The existing loading/empty/title/error-message cases still pass · Test-only change (no `lib/` edit)
- [ ] **B3. Make the staple-pantry read userId self-documenting** `[Tier A]` — `test/unit/services/shopping/menu_shopping_list_generator_test.dart` (extend). (BUT-1296 part 2)
  - Acceptance: The BUT-1279 staple-drop test adds an explicit `verify(() => pantryService.getAll(_testUserId))` so the user-scoping is pinned directly, not just transitively via mocktail default · The existing staple-exclusion assertions still pass · Test-only change (no `lib/` edit)

### Needs you (not built — flagged for your call)
- **BUT-1290** (Medium) — Decide the fate of the one-time activity-feed hint banner (the backend once-only mechanism + ARB string already exist; only the visible banner in `privacy_section.dart` is missing). Product/UX choice: a second nudge surface vs the existing in-feed hint. Recommendation: lean **won't-build** (the in-feed hint already nudges once; a settings-page banner is redundant) — but it's your call, so it parks.
- **BUT-1259** (Low) — PREMISE GONE, recommend **drop**. The ticket asks to correct an ACCEPTED_LARGE_FILES.md line count for `lib/butlery_app.dart`, but that file does not exist and the doc has no such entry — `main.dart` is still 1395 lines, i.e. the BUT-530 ButleryApp extraction it depends on never actually shipped. The doc fix has no target. Close as obsolete or re-file against the real (un-done) BUT-530 extraction.
- **BUT-1288** (Low) — iOS Info.plist/AppDelegate confirmation half is a trivial doc note, but the substantive half (on-device/simulator smoke test that a real timer notification fires) needs a Mac the loop can't reach (Tier D). Recommendation: do the doc-confirmation now only if you want it tracked; the smoke test waits for a real device.

### Obsolete (done in git, still open in Linear)
- (none — the iter-157 batch tickets BUT-1289/1291/1292/1293 were closed when commits `74825b1f2`/`ee3f6b487` shipped)

### Post-Sprint Steps
- [ ] Run `dart analyze --fatal-infos`
- [ ] Run the touched Dart tests (`url_import_viewmodel_test.dart`, `shared_recipes_by_friend_view_test.dart`, `menu_shopping_list_generator_test.dart`)
- [ ] Run the new rules test via the emulator harness (`functions/src/__tests__/activity-events-rules.test.ts`)
- [ ] Commit, push to main
- [ ] Update Linear: BUT-1294/1295/1296/1287/1282 → Done (all Tier A, fully verifiable). Leave BUT-1290/1259/1288 untouched (flagged for Malin).

---
## ARCHIVED — iter-157 (verifier-followups: BUT-1293/1289/1291 widget-test gaps + BUT-1292 security re-review — shipped commits `74825b1f2`/`ee3f6b487`/`565f1d330`; spawned BUT-1294..1296/1287/1282) · iter-156 (completeness-sweep widget-test gaps BUT-1274/1275/1280/1269/1270/1271 + security re-review BUT-1281 — `74825b1f2`) · iter-155 (cooking-mode + user-repo follow-up BUT-1283/1284/1285/1286 — `3bf7a50f3`) · iter-154 (BUT-734 user-repo split + BUT-1242 multi-timer cooking mode — `22ab49ae9`) · iter-153 (tagging drained) · iter-152 (menu BUT-1278/1279/1043/930 — `1711d297c`) · iter-151 (import BUT-1040/931/947/903/1205 — `673f80c87`) · iter-150..143 — se git-historiken
