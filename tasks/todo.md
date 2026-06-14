# Sprint Backlog

## Sprint: activity-feed-test-gap + import-flow re-review — back the just-shipped untested activity-event write path + close a stale-marker review gap (2 tickets) — 2026-06-14 (iter-159)

The iter-158 sprint (BUT-1294/1295/1296/1287, BUT-1282 cancelled) shipped fully — all five prior-sprint tickets are resolved in Linear and in git (`fe28279d0`, `ee3f6b487`, `565f1d330`). This is a fresh, deliberately-small sprint: the genuinely-clean Tier-A code slice is nearly drained (most of the 101 open tickets are launch-gated/ops, epics, monetization/marketing ideas, SDK-blocked dependency bumps, or product/UX decisions). Two honest Tier-A items remain that I can vouch for, both disjoint:

- **Batch A** — a real test gap on production code that shipped *untested* last sprint: `FirebaseActivityEventRepository.addEvent` (permission gate + the load-bearing rate-limit batch) has no repository-level test.
- **Batch B** — a process/verification close: re-run the Tier-2 specialist reviews against the final import-flow diff where the review markers were stale at ship time.

### Agent A: activity-feed-test-gap — back the activity-event write path with a real repository test
- [ ] **A1. Unit-test `FirebaseActivityEventRepository.addEvent` permission gate + rate-limit batch** `[Tier A]` — `test/unit/repositories/firebase/firebase_activity_event_repository_test.dart` (new), drives `lib/repositories/firebase/firebase_activity_event_repository.dart`. Use fake_cloud_firestore + mocktail per sibling repo tests (`firebase_cook_snap_repository_test.dart`, `firebase_pantry_repository_test.dart`). (BUT-1297)
  - Acceptance: Deny path — when `validateCreatePermission` is false (forged `actorId != currentUser`), `addEvent` throws `PermissionDeniedException` AND zero docs are written (assert the event doc and the rate-limit marker are both absent) · Success path — the committed batch contains BOTH the event doc at `activity_events/{id}` AND the rate-limit marker at `users/{uid}/rate_limits/activity_events` · The audit `logPermissionCheck` is invoked (spy/recording audit repo observes the create-permission check) · Test-only change — no file under `lib/` is modified

### Agent B: import-flow-rereview — re-run the stale Tier-2 reviews against the final import diff
- [ ] **B1. Re-dispatch code-reviewer + testing-specialist against the BUT-947/903/1205/931/1040 import-flow diff** `[Tier A]` — review-only over `lib/viewmodels/url_import_viewmodel.dart`, `lib/viewmodels/smart_import_viewmodel.dart`, `lib/views/recipe_detail_view.dart`, `lib/viewmodels/recipe_detail_viewmodel.dart`, `lib/models/recipe_personal_tag.dart` (the files whose mtime post-dated the markers). Fix any Critical/High inline; file the rest as follow-ups. (BUT-1277)
  - Acceptance: `code-reviewer` and `testing-specialist` have each been run against the final state of the import-flow files and their verdicts recorded in the close-out comment · Any Critical/High finding is either fixed inline (with the fix in the diff) or filed as a new Linear follow-up ticket referenced in the close-out · If no findings, the close-out explicitly states "clean — no missed findings against final state" (the gap was stale markers, so a clean re-review legitimately closes it)

### Needs you (not built — flagged for your call)
- **BUT-1260** (Medium) — PREMISE STALE, recommend **reframe**. Asks for a test/injection seam for the Phase-A/Phase-B cold-start ordering, but `lib/bootstrap/app_initializer.dart` and `runPhaseA`/`runPhaseB` do not exist — the BUT-431 cold-start phase-split it depends on was never actually shipped. There is no ordering to test. Re-file against the real (un-done) BUT-431, or drop.
- **BUT-840** (Low) — recommend **reframe / drop for now**. Asks to extend `on-profile-updated.ts` to update the Algolia search mirror, but there is NO Algolia integration anywhere in `functions/src/` (indexing is client-side today). This is a new external-API surface needing the Algolia admin key as a secret + a deploy — effectively Tier D, not the "extend an existing CF" the ticket implies. Decide whether the stale-search-name cost is worth a new server-side Algolia dependency.
- **BUT-1276** (Low) — your call. The BUT-1205 overwrite confirm is unconditional, not edit-aware (Recipe has no dirty-tracking primitive). Recommendation: **accept-and-close** — always-confirming is the safe choice under the BUT-954 destructive-action convention; building `hasUserEdits` dirty-tracking is disproportionate. But it's a behavior/UX call, so it parks.
- **BUT-1261** (Medium) — your call. Conflict diff view uses one generic renderer for recipe/menu/shopping-list and stringifies ingredient lists rather than showing semantic add/remove/reorder. Recommendation: lean **(b) narrow the acceptance** to the shipped generic diff after you confirm it reads clearly — per-type + semantic ingredient diffing is a sizeable build for a feature you haven't yet said needs it.
- **BUT-1290** (Medium) — your call (carried). Decide the fate of the one-time activity-feed hint banner (backend mechanism + ARB string exist; only the visible banner in `privacy_section.dart` is missing). Recommendation: lean **won't-build** — the in-feed hint already nudges once; a settings-page banner is redundant.
- **BUT-1299** (Low) — recommend **close as confirmed, no action**. Bookkeeping confirm: BUT-675 does not exist in Linear (`Entity not found`) and the `nextPage()` forward-persistence WHY comment is already in HEAD, so there is nothing to close or change. Pure Linear housekeeping, no diff.
- **BUT-1288** (Low) — carried. iOS Info.plist/AppDelegate doc-confirm is trivial, but the substantive half (on-device test that a real timer notification fires) needs a Mac the loop can't reach (Tier D). Do the doc note only if you want it tracked; the smoke test waits for a real device.

### Obsolete (done in git, still open in Linear)
- (none — iter-158 tickets BUT-1294/1295/1296/1287 are already Done, BUT-1282 already Canceled)

### Post-Sprint Steps
- [ ] Run `dart analyze --fatal-infos`
- [ ] Run the new repository test (`test/unit/repositories/firebase/firebase_activity_event_repository_test.dart`)
- [ ] Commit, push to main
- [ ] Update Linear: BUT-1297 → Done (Tier A, fully verifiable); BUT-1277 → Done if re-review is clean / In Review if it surfaced findings needing your eyes. Leave BUT-1260/840/1276/1261/1290/1299/1288 untouched (flagged for Malin).

---
## ARCHIVED — iter-158 (backend-rules + dart-test-gaps: BUT-1294 activity_events rules + BUT-1295/1296 test assertions + BUT-1287 GDPR-audit attribution; BUT-1282 cancelled — shipped `fe28279d0`/`ee3f6b487`/`565f1d330`) · iter-157 (verifier-followups BUT-1293/1289/1291/1292 — `74825b1f2`/`ee3f6b487`/`565f1d330`; spawned BUT-1294..1297/1287/1299) · iter-156 (completeness-sweep widget-test gaps BUT-1274/1275/1280/1269/1270/1271 + security re-review BUT-1281 — `74825b1f2`) · iter-155 (cooking-mode + user-repo follow-up BUT-1283/1284/1285/1286 — `3bf7a50f3`) · iter-154 (BUT-734 user-repo split + BUT-1242 multi-timer cooking mode — `22ab49ae9`) · iter-153 (tagging drained) · iter-152 (menu BUT-1278/1279/1043/930 — `1711d297c`) · iter-151 (import BUT-1040/931/947/903/1205 — `673f80c87`) · iter-150..143 — se git-historiken
