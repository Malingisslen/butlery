# Sprint Backlog

## Sprint: verifier-followups — close the 4 acceptance-criteria gaps the iter-156 sweep spawned (4 tickets) — 2026-06-14 (iter-157)

The iter-156 completeness sweep shipped in commit `74825b1f2` (cook-snap carousel, activity-feed toggles, shared-recipes view, multi-URL import widget tests). Its fresh-context verifier then filed five follow-ups (BUT-1289..1293) naming the exact acceptance criteria those tests left uncovered. Four are unambiguous clear-mandate Tier-A closes (three untested branches in already-shipped UI + one audit-gap security re-review). The fifth (BUT-1290) is a genuine product decision — build a one-time hint banner or close it as won't-build — so it is flagged for Malin, not built. All four batched tickets touch disjoint files (one import test, two social tests, one review-only over lib services).

### Agent A: import-test — close the legacy single-URL branch gap
- [ ] **A1. Widget test: single-URL input does NOT render the multi-URL row list** `[Tier A]` — `test/widget/import/import_via_url_view_multi_test.dart` (extend): add a case with `isMultiUrl => false`. (BUT-1293)
  - Acceptance: A fake VM with `isMultiUrl => false` renders the legacy single-URL UI and NO per-URL row list · The existing three multi-URL cases (per-URL rows, per-row retry, successfulUrlCount CTA) still pass · No production file under `lib/` is modified (test-only change)

### Agent B: social-tests — close carousel-swipe + populated-list gaps
- [ ] **B1. Widget test: swipe advances carousel index + zero-photo renders neither** `[Tier A]` — `test/widget/social/cook_snap_photo_carousel_test.dart` (extend), drives `lib/widgets/recipe/cook_snap_photo_carousel.dart`. (BUT-1289)
  - Acceptance: Dragging a multi-photo PageView one page asserts the counter moves from `1/N` to `2/N` (exercises the `onPageChanged`/`setState` path at line 90) · A zero-URL carousel renders neither a PageView nor a counter (the `urls.isEmpty -> SizedBox.shrink()` branch at line 70) · The existing >1-photo and ==1-photo cases still pass · Test-only change (no `lib/` edit)
- [ ] **B2. Widget test: populated shared-recipes list state for a friend** `[Tier A]` — `test/widget/social/shared_recipes_by_friend_view_test.dart` (extend), drives `lib/views/social/shared_with_me/shared_recipes_by_friend_view.dart`. (BUT-1291)
  - Acceptance: With a stubbed `MessagingService` and N shared recipes, the populated-list branch renders N `SharedRecipeCard` (or N recipe titles) for the friend · The existing loading/error/empty/title cases still pass · The square-design (no-rounded-chrome) assertion stays scoped to the view chrome, NOT the intentionally-rounded `SharedRecipeCard` · Test-only change (no `lib/` edit)

### Agent C: security-review — re-run BUT-1281 audit against the correct diff
- [ ] **C1. firebase-backend-security re-review of the actual staple-pantry diff** `[Tier A]` — review-only over `lib/models/pantry/pantry_item.dart`, `lib/services/menu/weekly_menu_plan_service.dart`, `lib/services/shopping/menu_shopping_list_generator.dart` (staple read + `isStaple` round-trip); APPEND a dated `.knowledge.md` entry naming those files, then refresh `.claude/state/firebase-security-done.marker`. (BUT-1292)
  - Acceptance: The staple pantry read (`_stapleNames` via `AuthRepository.currentUserId`) is confirmed user-scoped with no cross-user leak path · The `isStaple` boolean round-trips safely through `PantryItem` `fromFirestore`/`toFirestore` with no rules/permission gap · A dated knowledge entry in `firebase-backend-security.knowledge.md` explicitly names `pantry_item.dart` + `weekly_menu_plan_service.dart` + `menu_shopping_list_generator.dart` (greppable for `isStaple`/`stapleNames`) · Any finding above Low is filed as a follow-up Linear ticket; the marker is refreshed only after a clean review

### Needs you (not built — flagged for your call)
- **BUT-1290** (Medium, no labels) — Decide the fate of the one-time activity-feed hint banner. The once-only backend mechanism already exists (`ActivityFeedService.firstEventHint` gated by the durable `UserProfile.hasSeenActivityFeedHint` flag, plus the `privacyActivityFeedHint` ARB string at `app_sv.arb:3788`) — what's missing is the visible banner in `privacy_section.dart`. This is a product/UX choice (does a banner add value over the in-feed hint, and how should it look), so it parks for you. Recommendation: **reframe slightly and decide** — if you want users nudged once about per-type privacy from the settings page, build it (small Tier-B banner wired to the existing flag); if the in-feed hint is enough, close the banner half of BUT-1270 as won't-build. I lean won't-build (the mechanism already nudges in-feed; a second surface is redundant), but it is your call.

### Obsolete (done in git, still open in Linear)
- (none this iteration — the iter-156 plan's BUT-1272 obsolete-close and the BUT-1274/1275/1280/1269/1270/1271/1281 close-outs were all handled when commit `74825b1f2` shipped)

### Post-Sprint Steps
- [ ] Run `dart analyze --fatal-infos`
- [ ] Run the touched widget tests (`test/widget/import/import_via_url_view_multi_test.dart`, `test/widget/social/cook_snap_photo_carousel_test.dart`, `test/widget/social/shared_recipes_by_friend_view_test.dart`)
- [ ] Commit, push to main
- [ ] Update Linear: BUT-1293/1289/1291 -> Done (Tier-A test close-outs, fully verifiable); BUT-1292 -> Done if review clean (else file findings + In Review). Leave BUT-1290 untouched (flagged for Malin).

---
## ARCHIVED — iter-156 (completeness-sweep: widget-test gaps for shipped In-Review UI BUT-1274/1275/1280/1269/1270/1271 + security re-review BUT-1281 — shipped commit `74825b1f2`; spawned verifier follow-ups BUT-1289..1293; closed BUT-1272 obsolete via `10325a5bb`) · iter-155 (recipe focus drained; cooking-mode + user-repo follow-up close-out BUT-1283/1284/1285/1286 Tier A — commit `3bf7a50f3`; spawned BUT-1287/1288) · iter-154 (backend thin slice: BUT-734 Tier C user-repo split + BUT-1242 Tier B multi-timer cooking mode — commit 22ab49ae9) · iter-153 (tagging drained) · iter-152 (menu: BUT-1278/1279/1043/930 — 1711d297c) · iter-151 (import: BUT-1040/931/947/903/1205 — 673f80c87 + 10325a5bb) · iter-150 (social conflict-cleanup + activity/sharing UI) · iter-149..143 — se git-historiken
