# Sprint Backlog

## Sprint: iter-77 — BUT-1085 + BUT-1090 ticket-then-flip pair — 2026-05-25 (Mon)

Theme: Two P2 High social-bug fixes with pre-existing PINS BUG tests. Same "ticket-then-flip" shape as `fee1147ae` (BUT-1094) and `907268f0b` (BUT-1089) — production fix + test assertion flip in one commit. Skipping BUT-1086 (sign-out race) because the fix requires a product decision (A/B/C) and a cross-repo transaction surface; commented + left open.

### Ship this sprint

- [ ] **A1. SharedShoppingViewModel: route loadContentWithPagination through filtered path** — `lib/viewmodels/shared_content/shared_shopping_viewmodel.dart:112-130`. Replace override body with `return loadContentFromRepository();`. (BUT-1085)
- [ ] **A2. Flip 3 PINS BUG tests** — `test/unit/viewmodels/shared_content/shared_shopping_viewmodel_test.dart:181,201,223`. Dismissed `['v','d']`→`['v']`, blocked `['b','f']`→`['f']`, `verifyNever`→`verify(...).called(1)`. Update test comments to add BUT-1085 ref alongside BUT-1069. (BUT-1085)
- [ ] **B1. SocialMenuCoordinator: wrap joinSharedMenu in try-catch** — `lib/services/unified/modules/social_menu/social_menu_coordinator.dart:230-293`. Mirror legacy `importSharedMenu` shape: `try { ... } catch (e) { AppLogger.error(...); setError(sanitizeErrorForUser(e)); return null; }`. (BUT-1090)
- [ ] **B2. Flip joinSharedMenu test** — `test/unit/services/unified/modules/social_menu/social_menu_coordinator_test.dart:691-701`. `throwsA(anything)` → `expect(out, isNull)` + assert `lastError` was set. (BUT-1090)

### Step 0 — premise verification (done)

- **BUT-1085** verified: `loadContentWithPagination` override (lines 112-130) bypasses `loadContentFromRepository`'s 3 filtering steps. Sibling `SharedRecipeViewModel:110-117` delegates correctly. 3 `PINS BUG` tests in shared_shopping_viewmodel_test.dart pre-pin the bug.
- **BUT-1090** verified: `joinSharedMenu` body (lines 234-293) has zero outer try-catch. Only the inner `addParticipant` call (lines 247-259) is wrapped. Repository's `read()` throw escapes. Test at line 691 pins via `throwsA(anything)`.

### ★ Risky-ticket plan — BUT-1085 ──────────────────
Classification: **fits** (no premise drift; bug exists at named lines; pinning tests already aligned)
Files: `lib/viewmodels/shared_content/shared_shopping_viewmodel.dart` (12 lines deleted, 3 added) + test (3 assertion flips + comment updates)
Blast radius: This is the production path for `BaseSharedContentViewModel.loadContent()`. After fix, dismissed/blocked filtering will activate for ALL existing shopping-list loads. Sibling VM verifies this is the correct shape. No callers depend on the bypass.
Proceeding automatically (no approval gate).
─────────────────────────────────────────────────

### ★ Risky-ticket plan — BUT-1090 ──────────────────
Classification: **fits** (bug exists at named lines; legacy `importSharedMenu` is the canonical pattern in the same file)
Files: `lib/services/unified/modules/social_menu/social_menu_coordinator.dart` (wrap ~60-line method body) + test (1 assertion flip)
Blast radius: Method-local. Existing inner try-catch around `addParticipant` continues to work. After fix, callers (UI) see `null` + a banner-eligible error instead of an uncaught throw. Already-imported / standard happy paths return the same `MenuJoinResult`.
Proceeding automatically (no approval gate).
─────────────────────────────────────────────────

### Acceptance

- [ ] `flutter analyze` clean.
- [ ] `flutter test test/unit/viewmodels/shared_content/shared_shopping_viewmodel_test.dart` passes.
- [ ] `flutter test test/unit/services/unified/modules/social_menu/social_menu_coordinator_test.dart` passes.

### Post-Sprint Steps

- [ ] Commit + push
- [ ] Close BUT-1085 + BUT-1090
- [ ] BUT-1086 stays open (deferred — see comment posted 2026-05-25)

---

## Archived iter-76 (commit `fee1147ae` — BUT-1094 setError on swallow catches) — 2026-05-25 (Mon)

3-coordinator setError consistency fix shipped. All acceptance criteria met.
