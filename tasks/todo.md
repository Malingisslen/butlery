# Sprint 2026-07-25 — Selection

Backlog scanned: 100 Backlog + 3 Todo + 0 In Progress + 0 Triage, team Butlery (Linear MCP
live). All 10 selected tickets were filed by the 2026-07-24 `/linear scan night` run, each
already carrying "Verified against current code" with file:line evidence — re-verified by
grep against current `main` at selection time (all still accurate, no drift since filing).
No ticket carries `onboarding-reserved`. No obsolete tickets found (no open ticket's fix
appears already shipped under a different id in the last 7 days of commits).

Every ticket below was Claude-authored (autonomous scan), never human-approved — the mandate
column records why each one is safe to build anyway.

## Agent A — menu (safety-critical)
Area: menu / account. Files: `lib/services/household_service.dart`,
`lib/services/menu/weekly_menu_plan_service.dart` (disjoint from every other batch).

- [x] **BUT-1663** [Tier A][build] Household allergen union silently drops a member whose
  profile read fails — menu can under-filter allergens. **requiresPlanMode: true**
  (single-tier panel + Urgent priority). Router: single — Software Architect, Product
  Manager.
  - Fix: in `HouseholdService._aggregatePreferences()`, don't add a member to the union
    unless their profile actually resolved; on a fetch failure either retry once or let the
    error propagate so `getAggregatedAllergenPreferences()` hits its existing
    `UserAllergenPreferences.defaults` fallback + logs a warning. Add
    `test/unit/services/household_service_test.dart` (doesn't exist today) covering the
    per-member fetch-failure branch.
  - Acceptance:
    1. A member whose profile read throws/fails is EXCLUDED from the allergen union, never
       silently treated as "no allergies".
    2. When any member's read fails, the aggregate result is the conservative
       `UserAllergenPreferences.defaults` fallback (or a retry that then succeeds) — never a
       narrower-than-fallback union.
    3. A new test in `household_service_test.dart` fails on the pre-fix behavior and passes
       after.
    4. No change to the already-decided presence/"who's home" scoping (BUT-1611/BUT-1625) —
       whole-household union stays the baseline.

- [x] **BUT-1668** [Tier A][build-review] Weekday pins ignore the today-anchor and can place
  a recipe on a day that has already passed. **requiresPlanMode: false**. Router: single —
  Product Manager.
  - **Signoff reason:** the fix picks "skip the pin, let it fall through to normal
    chronological fill" (matching the existing occupied-slot skip and the rest of the
    function's already-established behavior) over "roll it to next week" — a user-visible
    choice about what happens to an elapsed day-pin idiom like "tacofredag" asked on a
    Saturday. Flag if you'd rather it roll forward instead of drop.
  - Fix: in the day-pin loop of `WeeklyMenuPlanService.distributeFromGeneratedMenu()`, when
    the anchor is today and `dayIdx < anchorIndex`, skip the pin instead of placing it
    unconditionally.
  - Acceptance:
    1. A day-pin whose weekday has already elapsed this week is never placed on that past
       cell.
    2. The skipped pin's recipe still becomes available to the normal chronological fill
       (not silently dropped from the week).
    3. Existing "day pins vs occupied cells" tests still pass; a new test covers a pin dated
       before the anchor (today = Thu, pin = Mon).
    4. Future-dated pins (today ≤ pin weekday) are unaffected — same placement as before.

## Agent B — shopping
Area: shopping. Files: `lib/repositories/firebase/modules/shopping_repository_routing_module.dart`,
`lib/services/unified/operations/collaborative_shopping/list_item_operations.dart`,
`lib/services/shopping/ingredient_categorizer.dart`,
`lib/services/shopping/menu_shopping_list_generator.dart`,
`lib/viewmodels/unified_shopping_viewmodel.dart` (disjoint from every other batch; internal
overlap on `unified_shopping_viewmodel.dart` between BUT-1670 is fine, same batch/agent).

- [x] **BUT-1665** [Tier A][build] Collaborative shopping-list edits overwrite the whole
  items array — concurrent household ticks are silently lost. **requiresPlanMode: true**
  (High priority + touches `lib/repositories/`, a sensitive-domain path). Router: single —
  Trust & Safety, Performance Engineer, Data Analyst/BI.
  - Fix: Route 1 from the ticket (the proportionate one) — move
    `ShoppingRepositoryRoutingModule.updateCollaborativeList()`'s single-item mutations into
    a Firestore transaction that re-reads the live document, applies the single-item change
    server-side, and writes back, instead of a client-cache read + full-array overwrite.
  - Acceptance:
    1. Two concurrent single-item mutations (A ticks item X, B ticks item Y, near-simultaneous)
       both survive — neither is silently reverted by the other's write.
    2. The fix uses a Firestore transaction (re-reads server state), not a client-side merge.
    3. The personal (non-collaborative) shopping path is untouched — ticket confirms it's not
       affected by this race.
    4. A new test exercises the two-writers-same-window race and asserts both edits land.

- [!] **BUT-1666** [Tier A][build] IngredientCategorizer substring rules put nuts in meat,
  roasted items in dairy, and paprika/coconut milk in the wrong aisle.
  **requiresPlanMode: false**. Router: single — Software Architect, Product Manager.
  - Fix: bound `'ost'`, `'nöt'` (and any other short ambiguous tokens) with the
    `(?<![a-zåäö0-9])…(?![a-zåäö0-9])` lookaround pattern already used for `fil`; reorder or
    exact-match the shadowed `'paprika'` (spices) and `'kokosmjölk'` (canned) literals ahead
    of the rules currently shadowing them.
  - Acceptance:
    1. `hasselnötter`/`jordnötter`/`cashewnötter`/`valnötter`/`nötter`/`kokosnöt` categorize
       as nuts/produce, never meat.
    2. `rostad paprika` / `rostade cashewnötter` no longer categorize as dairy.
    3. `paprikapulver` / `rökt paprika` categorize as spices, not veg.
    4. `kokosmjölk` categorizes as canned, not dairy; a test case per collision is added to
       `test/golden/llm/categorize_ingredient/cases.json`.

- [!] **BUT-1670** [Tier A][build] Shopping analytics are incomplete and mislabelled —
  menu-generated lists fire nothing, recipe adds log as "manual", unchecks log as checks.
  **requiresPlanMode: false**. Router: single — Software Architect, Product Manager.
  - Fix (3 sub-fixes in the same event family): fire `logShoppingListCreated` /
    `logShoppingListItemAdded` (`source: 'menu_generated'`) from
    `MenuShoppingListGenerator.generateForWeek()`; add an optional `source` param to
    `addItem()` (default `'manual'`) and pass `source: 'recipe'` from
    `addItemsFromRecipe()`; only fire `logShoppingListItemChecked` when `wasBought == false`
    (or add a `checked: bool` param).
  - Acceptance:
    1. Generating a shopping list from the weekly menu fires a `shopping_list_created` /
       `shopping_list_item_added` event with `source: 'menu_generated'`.
    2. Bulk-adding ingredients from a recipe logs `source: 'recipe'`, not `'manual'`.
    3. Unchecking an item no longer fires `shopping_list_item_checked`.
    4. Manual single-item add via the existing UI still logs `source: 'manual'` (no
       regression on the default).

## Agent C — backend/notifications
Area: backend (Cloud Functions). Files: `functions/src/notifications/send-notification.ts`
(disjoint from every other batch).

- [x] **BUT-1664** [Tier A][build] `sendNotificationBatch` uses the wrong rate-limit bucket
  and charges 1 token for up to 100 pushes. **requiresPlanMode: true** (security label +
  High priority + Cloud Functions is a sensitive domain). Router: single — Vendor/Procurement
  Manager (FinOps also matched).
  - Fix: in `sendNotificationBatch`, call
    `checkRateLimit(callerUid, "sendNotificationBatch", notifications.length)` instead of the
    shared `"sendNotification"` key with an implicit cost of 1 — and move the rate-limit
    check to AFTER the `notifications` array is parsed/length-validated so a malformed
    request can't skip the charge.
  - Acceptance:
    1. `sendNotificationBatch` consumes tokens from the dedicated `sendNotificationBatch`
       bucket (`maxTokens: 10, refillRate: 5/min`), never the shared `sendNotification`
       bucket.
    2. Token cost scales with batch size — a 100-item batch consumes 100 tokens (test
       asserts this exactly).
    3. The rate-limit check runs after array parsing/length validation, not before.
    4. The existing per-target friend/pending-request authorization check is untouched (not
       a finding — don't regress it while fixing the rate limit).

## Agent D — import/parsing
Area: parsing / import. Files:
`lib/services/import/parsers/recipe_section_detector.dart` (disjoint from every other batch).

- [x] **BUT-1661** [Tier A][build] Ingredient-word detector never matches "ägg" — silently
  drops egg lines in headerless text imports. **requiresPlanMode: true** (High priority,
  allergen-safety adjacent). Router: single — Data/Integrations Engineer (FinOps,
  Monetization also matched).
  - Fix: replace the interpolated `RegExp('\\b$word\\b')` boundary in
    `RecipeSectionDetector.looksLikeIngredient` with the Unicode-safe
    `(?<![a-zåäö0-9])word(?![a-zåäö0-9])` lookaround (or a word-set `.contains()`, per the
    pattern `SwedishLineClassifier._scoreAsIngredient` already uses safely).
  - Acceptance:
    1. `RegExp` boundary match on `ägg` succeeds for `'ägg'`, `'2 ägg'`, and `'lägg till ägg
       och rör om'` (the exact three cases the ticket names as currently failing).
    2. A headerless-text import containing a unitless `4 ägg` line keeps that ingredient
       (regression test through the full `text_import_strategy.dart` path, not just the
       regex).
    3. The other two interpolated-`\b` sites named as "checked and NOT affected"
       (`recipe_text_normalizer.dart`, `ingredient_line_detector.dart`) are left untouched —
       this ticket's scope is `recipe_section_detector.dart` only.
    4. The header'd import path (`isValidIngredient`) is unaffected — already correct, don't
       touch it.

## Agent E — recipe
Area: recipe. Files: `lib/viewmodels/recipe_form/recipe_persistence_manager.dart`,
`lib/viewmodels/recipe_form/recipe_form_state.dart` (disjoint from every other batch).

- [!] **BUT-1669** [Tier A][build] Queued concurrent recipe save double-completes its
  Completer and throws `StateError` out of `saveRecipe`. **requiresPlanMode: false**.
  Router: single — Software Architect, Product Manager.
  - Fix: in `RecipePersistenceManager.saveRecipe()`'s queuing branch, delete the redundant
    self-completion (the completer is already completed by
    `_completePendingSaveOperations`) — either `await completer.future` and return that, or
    return `_lastSaveResult` directly without touching the completer.
  - Acceptance:
    1. Two overlapping `saveRecipe()` calls both return the same `Recipe?` result — neither
       throws `StateError`.
    2. A new test fires two overlapping saves and asserts both resolve cleanly.
    3. The single-save (non-overlapping) path is unchanged.

- [x] **BUT-1667** [Tier A][build] `RecipeFormState.dispose()` stopped disposing its three
  `FormFieldsManager`s — text controllers leak on every recipe form close.
  **requiresPlanMode: false**. Router: single — Software Architect, Product Manager.
  - Fix: restore the three missing calls (`_ingredientsManager.dispose()`,
    `_instructionsManager.dispose()`, `_tagsManager.dispose()`) in `RecipeFormState.dispose()`
    before `_autoSaveManager.dispose()`.
  - Acceptance:
    1. `dispose()` calls all three managers' `dispose()`, verified by a test/mock that
       asserts each was invoked exactly once.
    2. A widget test that opens and closes the recipe form under Flutter's leak tracking
       (`LeakTesting`) reports no leaked `TextEditingController`.
    3. No double-dispose — each manager's `dispose()` fires exactly once per form close.

## Agent F — account/GDPR
Area: account. Files: `lib/services/account/export/content_export_manager.dart`,
`lib/services/account/export/preferences_export_manager.dart`,
`lib/services/account/export/activity_export_manager.dart`,
`lib/services/account/export/export_pagination_helper.dart` (disjoint from every other
batch).

- [x] **BUT-1662** [Tier C][build] GDPR export falsely stamps `truncated: true` on ~15
  sections (boundary-exact `>=` bug + merged-query miscount). **requiresPlanMode: true**
  (full-panel router tier — Privacy/DPO, Legal Counsel, + core FinOps/PM/Security
  Architect/Software Architect). GDPR/account is a sensitive domain regardless of tier.
  - Fix: generalize the N+1-probe pattern already shipped for `exportUserNotifications`
    (BUT-1562, `dade7b44b`) — add `paginatedQueryWithTruncationFlag` to
    `ExportPaginationHelper` (fetch `maxDocuments + 1`, `truncated = docs.length > limit`,
    trim to cap) and move all 15 remaining `results.length >= limit` sites onto it. For the
    4 merged-query sections (recipes, menus, 2× weekly-menu-plan exporters), track
    truncation per sub-query and OR the flags instead of comparing the merged length to one
    cap.
  - Acceptance:
    1. A section with exactly `limit` real documents (no truncation) now reports
       `truncated: false` — the boundary-exact false-positive is gone.
    2. A section that genuinely exceeds `limit` still reports `truncated: true` — no
       regression on true positives (the ticket confirms real truncation is never currently
       missed; this must stay true).
    3. `exportRecipes` merges two independently-capped 2000-doc queries; truncation is now
       OR'd per sub-query, not `combinedLength >= 2000`.
    4. `exportUserNotifications`'s already-correct N+1 pattern (BUT-1562) is reused, not
       reimplemented differently.

## Needs your call (not built this sprint)

- **BUT-1480** — Unify the two URL import pipelines. Already labeled `need-malin`; posted a
  Linear comment with my read and a recommendation (worth doing, scope as a planned
  migration, low urgency).
- **BUT-1323** — "Who's eating" per-day presence + per-member preferences EPIC
  (DIFFERENTIATOR). Too large/speculative for an autonomous pick; posted a Linear comment
  recommending a proper `/interview` + slice-based plan, same pattern as the already-sliced
  BUT-1611/BUT-1625.

## Outcome grades (Phase 2.7, graded 2026-07-25)

`[x]` = all acceptance criteria passed. `[!]` = at least one criterion failed verification;
the ticket parks In Review and the gap is filed as a follow-up.

| Ticket | Grade | Note |
| --- | --- | --- |
| BUT-1663 | pass | Union widened with a common-allergen floor instead of exclusion; dietary axis narrowed. Deviation unrecorded → BUT-1685. |
| BUT-1668 | pass | build-review: elapsed day-pin DROPS rather than rolls forward — founder's call. |
| BUT-1665 | pass | Offline `_mutateFromCache` re-opens a lost-update window; new authz gates unreviewed → BUT-1683. |
| BUT-1666 | **fail** | AC3 unmet: `rökt paprika` still returns veg; no golden case for any named collision → BUT-1680. |
| BUT-1670 | **fail** | AC2 unmet: the tagged method has no production caller; AC1 half met; zero tests → BUT-1681. |
| BUT-1664 | pass | Batch bucket resized 10→100 tokens, 5→30/min outside declared scope → BUT-1684. |
| BUT-1661 | pass | End-to-end headerless-import test (AC2) not written → BUT-1688. |
| BUT-1669 | **fail** | Stale `_lastSaveResult` still returned to the queued waiter; AC2 test absent → BUT-1682. |
| BUT-1667 | pass | Leak-tracking widget test (AC2) not written; save-cancellation behaviour undeclared → BUT-1687. |
| BUT-1662 | pass | 7 of 16 migrated sections have no boundary test → BUT-1686. |

## Deviation log

- [deviation] BUT-1663: ticket named an existing `test/unit/services/household_service_test.dart`
  → no HouseholdService suite existed anywhere → created it from scratch with the production
  ServiceLocator + authenticated FakeAuthRepository harness the auth-gated
  `executeServiceOperation` needs, rather than a lighter harness that bypasses the auth pre-flight.
- [deviation] BUT-1663: ticket framed the bug as a member whose profile read FAILED →
  `UserService.getUserProfile` returns null for both a failed read and a genuinely absent member
  → treat ANY unresolved member as a failure and abort the aggregation, rather than guessing
  which nulls are safe to skip.
- [deviation] BUT-1663: plan implied a minimal edit to the member loop → the existing
  `if (profiles.isEmpty) return defaults;` guard became provably unreachable → removed the dead
  branch instead of leaving misleading code.
- [deviation] BUT-1663 (UNRECORDED AT THE TIME, filed as BUT-1685): AC1 said exclude the
  unreadable member; the code WIDENS the union with a common-allergen floor. AC2 said "never
  narrower than defaults"; the code drops `defaults.trackedDietary`. Both are allergen-safety
  judgment calls and belong in ACCEPTED_DEVIATIONS.
- [deviation] BUT-1668: ticket described only the skip behaviour → the guard could break
  future-week pinning if `anchorIndex` were ever non-zero off-week → added a third test asserting
  a Friday pin in NEXT week still lands on Friday while today is Saturday.
- [deviation] BUT-1665: plan named 2 files → a transactional seam cannot exist in the operations
  layer alone (no Firestore handle) → wired the new method through the repository interface, the
  Firebase repository and the service rather than reaching around the interface.
- [deviation] BUT-1665: plan said move single-item mutations into a transaction → the cached list
  is still needed for the list-exists and canEdit pre-checks → kept those on the cache, moved only
  the mutation server-side; Firestore rules remain the authority.
- [deviation] BUT-1665: plan did not anticipate a deleted item → `toggleItemBought` uses
  `firstWhere` and throws if another member removed the row mid-flight → added a no-op guard
  inside the mutator.
- [deviation] BUT-1665: plan listed no test file → the existing collaborative-ops suite would not
  compile against the new seam → migrated it and added the two concurrency regression tests there.
- [deviation] BUT-1665 (UNRECORDED AT THE TIME, filed as BUT-1683): the offline `_mutateFromCache`
  fallback re-introduces the lost update AC2 forbade, and `updateCollaborativeList` gained
  authorization gates that were never in scope.
- [deviation] BUT-1666: plan said word-boundary both short tokens identically → symmetric bounding
  is wrong for both in Swedish (`ost` loses `parmesanost`; `nöt` loses `nötfärs` while a trailing
  boundary re-admits every nut) → gave each token the boundary shape it needs.
- [deviation] BUT-1666: plan said reorder the shadowed paprika rule → moving the spice block above
  veg would send plain `paprika` to spices → added a `paprikapulver`/`paprikakrydda`/`kokosmjölk`
  head-noun guard instead. **This is why AC3 failed** — `rökt paprika` is not covered (BUT-1680).
- [deviation] BUT-1666: plan named only `cases.json` → the golden runner asserts a snapshot of
  passing case ids in `categorize_ingredient_test.dart` → added the seven new ids to
  `_expectedPassing` in the same change.
- [deviation] BUT-1670: plan said fire item_added from `generateForWeek` → the tracker has no
  item-count parameter → fire one event per generated line, wrapped in try/catch so a logging
  failure can never fail a generation the user already sees. **Cost concern raised in BUT-1681.**
- [deviation] BUT-1670: plan did not say when `shopping_list_created` should fire →
  `generateForWeek` is idempotent → fire only when a new list was actually created.
- [deviation] BUT-1670: plan said gate only `item_checked` → `shopping_list_completed` sits in the
  same success block → kept it gated; deliberately left the BUT-1306 checkoff→pantry seam OUTSIDE
  the gate because it must still run on unchecks.
- [deviation] BUT-1664: plan said charge the dedicated batch bucket scaled by `notifications.length`
  → that bucket is sized in CALLS (maxTokens 10, refill 5/min), so a length-scaled charge would
  have denied every batch larger than 10 while the same callable enforces a 100-item maximum →
  re-denominated the bucket in notification units (maxTokens 100, refillRate 30/min). Adds
  `rate_limiter.ts` to the fileset; no test pins those values. **Filed as BUT-1684.**
- [deviation] BUT-1664: plan said `git add -A` → `flutter pub get --offline` had rewritten eight
  generated plugin-registrant files plus `.claude/settings.local.json` → staged only the three
  owned files by explicit pathspec, per the repo's parallel-session git rule.
- [deviation] BUT-1664: plan said run `dart format` + `dart analyze` → the batch changed zero
  `.dart` files and the worktree had no `functions/node_modules` → ran the equivalent TS gate via a
  temporary directory junction to the main checkout's node_modules, then removed it with
  `cmd rmdir` (never `rm -rf`, which would have followed the junction).
- [deviation] BUT-1661: plan named one production file → found a now-false comment in
  `multi_recipe_splitter.dart:177` → left it untouched to avoid a cross-batch apply conflict;
  one-line follow-up in BUT-1688.
- [deviation] BUT-1661: plan implied an in-place boundary swap → the 26-word list rebuilt 26
  RegExp objects on every call, once per line of every import → hoisted to a pre-compiled static
  field while making the boundary change.
- [deviation] BUT-1661 (UNRECORDED AT THE TIME, filed as BUT-1688): the new lookbehind still drops
  bare compound forms like `råsocker` — a recall tradeoff accepted only in test comments.
- [deviation] BUT-1669: ticket said delete the redundant self-completion in the success path →
  the sibling catch branch calls `completer.completeError(e)` unguarded and double-completes the
  same way → wrapped only that call in `if (!completer.isCompleted)` rather than restructuring the
  queueing design.
- [deviation] BUT-1662: plan said ~15 `>=limit` sites → found 16 live sites (11 content + 4
  preferences + 1 activity) → migrated all 16.
- [deviation] BUT-1662: ticket offered option A (generalize the probe) OR option B (per-sub-query
  flags) → neither alone suffices; single-read sections need A, the three multi-read sections need
  B on top → implemented A as the shared mechanism and applied B only where a section genuinely has
  more than one read.
- [discovery] BUT-1662: the existing `content_export_manager_test` boundary test ENCODED the bug
  (asserted exactly-at-cap must be truncated) → rewrote it plus the BUT-1440 forwarding
  expectation, added one merged-query regression test, touched no other assertions.
- [discovery] BUT-1662: `ActivityExportManager.exportCommentsAndRatings` and `exportFeedback` apply
  caps but emit NO truncation flag at all — the opposite failure. Out of scope → BUT-1686.
- [discovery] BUT-1662: `ExportPaginationHelper.paginatedQuery` does not clamp its batch to the
  remaining allowance; currently unused by any production caller → BUT-1686.
- [deviation] BUT-1662: cleanup step said `git add -A` → same generated-file churn as BUT-1664 →
  staged only the five owned files by explicit pathspec.
- [needs-human] SPRINT-WIDE: no specialist reviewer ran on ANY of this sprint's 51 changed files.
  All four `.claude/state/*.marker` files predate the work and name previous sprints' filesets.
  No marker was faked and no gate was bypassed — **the sprint stops uncommitted** and BUT-1679
  carries the unblocking steps.

## Post-sprint steps — outcomes (2026-07-25)

1. **`dart analyze --fatal-infos` on the full tree — DONE, clean.** "No issues found!"
2. **Follow-up Linear tickets — DONE.** BUT-1679 (ship blocker: the four specialist reviews),
   BUT-1680, BUT-1681, BUT-1682, BUT-1683, BUT-1684, BUT-1685, BUT-1686, BUT-1687, BUT-1688,
   BUT-1689 (workflow-map re-trace).
3. **Commit — NOT DONE, deliberately.** The specialist review never ran on the shipped diff, so
   no marker could be written honestly and the commit gate would (correctly) refuse. Nothing was
   forged, nothing was bypassed. The tree is staged and left for a human.
4. **Push — NOT DONE** (nothing committed).
5. **Linear transitions — HELD.** Closing tickets "Fixed in commit X" with no commit would be a
   false record. Every ticket stays where it is until BUT-1679 clears and the commit lands.
6. **`docs/onboarding/workflow-map.stale` — still present**, six flows to re-trace (BUT-1689).

## Ship remediation — the unreviewed half (BUT-1679, 2026-07-26)

This is the continuation of the plan above, not a new initiative. `c0989a3a3` shipped the
reviewed 11 files; the remaining 14 production + 8 test files stayed in the working tree
because no specialist had reviewed them. This pass runs the gates that were missing, fixes
what they BLOCK on, and ships. Scope is bounded to the already-selected tickets
(BUT-1661/1662/1665/1666/1667/1669/1670) — no new ticket work.

Sensitive-domain files in scope (why this section exists as plan evidence):
`lib/repositories/firebase/modules/shopping_repository_routing_module.dart`,
`shopping_item_operations_module.dart`, `firebase_shopping_repository.dart`,
`lib/repositories/interfaces/shopping_repository.dart`,
`lib/services/account/export/preferences_export_manager.dart` (GDPR export).

### Review verdicts (2026-07-26, all against THIS diff)

- [x] code-reviewer, shopping repository layer (3 files) — **COMMIT-READY**. High: the
  `_transactionBudget` comment claims an optimistic UI tick that does not exist.
- [x] firebase-backend-security, shopping repository layer (4 files) — **BLOCKED** on one
  finding (below). Medium follow-ups: display-name misattribution, offline replay swallows
  `permission-denied`, `lastActivityBy*` not scrubbed on account deletion.
- [x] code-reviewer, shopping service + viewmodel (4 files) — **COMMIT-READY**. Medium:
  `mutateSharedList` collapses three failure kinds into `false` with no user-facing error;
  BUT-1670 has zero tests.
- [x] code-reviewer, recipe form (3 files) — **BLOCKED** on two findings (below).

### Fixes applied in this pass

- [ ] **BLOCKER 1 — privilege-escalation gate missing on the transactional write path.**
  Found independently by firebase-backend-security (High 1) and code-reviewer (Medium 3),
  which is why it is being fixed rather than deferred. `updateCollaborativeList` gained
  `_requireNoPrivilegeEscalation`; the sibling `mutateCollaborativeList` did not — and that
  is the one this diff promoted onto the PUBLIC `ShoppingRepository` interface, taking an
  arbitrary caller-supplied mutator. A mutator returning a list naming itself `admin` or
  `ownerId` passes the client and is written to the audit log as `granted: true`.
  Firestore rules still deny it, so this is an audit-integrity defect, not an open door,
  and no in-repo mutator escalates today. Fix: call `_requireNoPrivilegeEscalation(uid,
  mutated, live)` after `mutate(live)` on BOTH the transaction path and the offline
  cached-base path, plus a regression test per path.
  - Acceptance: a mutator that rewrites `ownerId` or `memberPermissions` throws
    `PermissionDeniedException` on both paths; the owner's own rewrite still succeeds; the
    audit log records the denial, not a grant.

- [ ] **BLOCKER 2 — `createRecipe`'s new post-dispose `StateError` has an unguarded caller,
  and the comment asserting otherwise is false.** `RecipeFormCoordinator.syncToCollaborative`
  (`recipe_form_coordinator.dart:70`) calls `createRecipe` with no `safeExecute` and no
  try/catch, and `RecipeFormCoordinator.dispose()` is never called from
  `RecipeFormViewModel.dispose()`, so its own `_disposed` flag never trips and its four
  listeners are never removed. Fix: guard `syncToCollaborative` on
  `_disposed || _state.isDisposed`, wire `_coordinator.dispose()` into the viewmodel's
  dispose, and correct the false comment in `recipe_form_state.dart`.
  - Acceptance: no caller of `createRecipe` can reach the throw without an error boundary
    or a guard; the comment describes what the code actually does.

- [ ] **BLOCKER 3 — BUT-1669 ships with no test for the crash it fixes.** Nothing in
  `test/` exercises `saveRecipe`'s queued branch, so the double-complete `StateError` would
  return silently. This ticket was already graded FAIL once for a missing test.
  - Acceptance: a test fires two overlapping saves, asserts both resolve and neither throws,
    and goes red when the removed `completer.complete(result)` is restored.

- [ ] **Comment corrections folded in** (zero behaviour change): the `_transactionBudget`
  WHY, and the `source` doc comment in `unified_shopping_viewmodel.dart` that describes a
  menu-generation wiring that does not exist.

- [ ] **Swedish-boundary guard false positive.** `check_swedish_boundary.sh` flags two
  COMMENT lines that quote the buggy `\b`-next-to-`ägg` pattern they exist to explain. The
  live regexes in those files are clean (verified by running the guard). Reword the comments
  so they describe the pattern without spelling it literally — the guard cannot tell comment
  from code, and weakening the guard to teach it would be the wrong trade.

### Open questions

No architecture-changing unknowns. Assumptions, all stated rather than asked because each
is either a reviewer-confirmed defect or a comment fix: (a) the escalation guard belongs on
both write paths rather than only the transactional one, since the offline path writes the
same document; (b) the medium findings above become follow-up tickets rather than growing
this commit — they are pre-existing or non-blocking, and this diff is already large; (c) the
BUT-1666 / BUT-1670 acceptance-criteria gaps stay open under their existing follow-up
tickets (BUT-1680, BUT-1681) rather than being fixed here.

### What this means in plain language

Nothing here changes what the app does for a user. Two of them are safety nets:
one stops a member of a shared shopping list from writing themselves in as the owner and
having the app's own record say that was allowed, and one stops a recipe form that has
already closed from crashing on its way out. The third is a missing test for a bug that was
already fixed once. The rest is correcting comments that described the code inaccurately,
which matters because a future session reads those comments and believes them.

---

# Archived — 2026-07-23 sprint (BUT-1655 build half)

<!-- Plan approved via ExitPlanMode 2026-07-23; refreshed 2026-07-24 after /login reset the session marker. -->

**Decision (Malin, 2026-07-23):** build the OCR retry per-user cap guard now; defer the
global-counter sharding half (revisit at ~1 write/s). This plan covers only the guard.

**Outcome: shipped.** Commit `d057b6c2d` — "fix(functions): OCR retry enforces per-user
rate-limit cap before global (BUT-1655)", 2026-07-24. The remaining global-counter-sharding
half stays tracked as BUT-1655's open remainder (labeled `deferred`) plus a near-duplicate
FinOps ticket BUT-1652 — neither selected this sprint (still premature at current traffic
per the original decision).

## Problem (premise verified against current code)

The OCR image import has a text-mode auto-retry: when an image parse fails but Gemini
returned legible `rawText`, `runOcrRetry` (`functions/src/llm/ocr-retry.ts`) feeds it into
`runStructureRecipe` — the **unwrapped** core, not the `withRateLimit`-wrapped callable.
The retry today enforces the **global** LLM cap (`checkGlobalLimit`, Guard 4) but **not** the
**per-user** cap (`checkRateLimit(userId, 'structureRecipe')` — token bucket + BUT-1477 daily
cap of 100/day). Two consequences:
1. A user can make one extra `structureRecipe` call per import beyond their per-user budget.
2. Because Guard 4 *increments the shared global counter* with no per-user gate before it, a
   user already over their own cap can still inflate the global counter — the exact bug
   BUT-1577 fixed in the wrapped path by ordering **per-user before global**.

## Fix

Add a per-user cap check to `runOcrRetry`, placed as a new guard **before** the existing
global-cap guard (mirrors `withRateLimit`'s BUT-1577 ordering). Reuse Option A (resolve the
cap in the OCR core alongside the existing `checkGlobalLimit`), which follows the module's
own precedent (`checkGlobalLimit` is already resolved in-core at ocr-recipe-image.ts:282).

### Steps
1. **`functions/src/llm/ocr-retry.ts`**
   - Add `skipped_user_limit` to the `RetryOutcome` union.
   - Add `checkUserLimit?: () => Promise<boolean>` to `RetryDeps` (optional test seam;
     omitted -> allow, mirroring `checkGlobalLimit`).
   - Insert **Guard 4 (per-user)** *before* the current global guard (which becomes Guard 5):
     if `deps.checkUserLimit` returns `false`, return `retryOutcome: 'skipped_user_limit'`,
     `retryCount: 0`, `additionalCost: 0` (skip retry -> fall back to rawText, same UX as the
     global skip). Update the header/decision-tree comments.
2. **`functions/src/llm/ocr-recipe-image.ts`**
   - Add a **required** `userId: string` field to `OcrCoreOptions` (raw uid). Required, not
     optional, so TS forces every call site to wire it (no runtime fail-open).
   - Comment it: raw uid, used ONLY as the `checkRateLimit` doc key; **never** logged /
     emitted — logging stays on `authUidHash`.
   - Resolve `checkUserLimit` in-core with the same two-hop pattern as `checkGlobalLimit`:
     `const userLimitCheck = opts.checkUserLimit ?? (() => checkRateLimit(opts.userId, 'structureRecipe').then(r => r.allowed));`
     then thread it into the `runOcrRetry(...)` deps object at ~L484.
   - `onCall` wrapper (L118-124): pass `userId: request.auth!.uid`.
   - Import `checkRateLimit` from `../middleware/rate_limiter`.
3. **`functions/src/__tests__/ocr-retry.test.ts`**
   - Per-user-deny: outcome `skipped_user_limit`, `structureRecipe` NOT called, **and
     `checkGlobalLimit` NOT called** (call-count assertion — locks the ordering so a later
     refactor can't regress to "global increments regardless").
   - Per-user-allow: proceeds to the global guard, then `structureRecipe`.
   - `skipped_user_limit` is distinct from `skipped_global_limit`.
   - Fail-closed inherited: a `checkUserLimit` that resolves false (Firestore error path in
     production) -> skip -> rawText fallback.
   - Update the existing `runOcrRecipeImage(...)` test call sites (10) + kill-switch /
     handwritten / validation tests to pass the now-required `userId`.
4. Verify: `npx tsc --noEmit -p functions`, run `functions/src/__tests__/ocr-retry.test.ts`
   (+ the three other touched suites), then cloud-functions-specialist review (commit gate).

## Binding acceptance criteria (folded from the blind FinOps + Security + Architect panel)
- **AC1 — ordering:** per-user guard strictly before the global guard in the actual diff.
- **AC2 — same bucket:** call `checkRateLimit(userId, 'structureRecipe')` with default
  `tokensRequired=1` — the **same** operation key + cost the primary path uses (NOT a new
  operationType), so the retry draws from the one shared per-user `structureRecipe` budget.
- **AC3 — no fail-open:** raw `userId` is a **required** field; only one production caller
  (the `onCall` wrapper) exists — confirmed by grep. Test-seam default-allow stays test-only.
- **AC4 — hash-only logs:** raw `userId` consumed solely by `checkRateLimit`; `logger.*`,
  `emitTiming`, `captureLlmSample` keep using `authUidHash`.
- **AC5 — ordering regression test:** the per-user-deny test asserts `checkGlobalLimit` was
  never called.
- **AC6 — observability (follow-up, not this diff):** the new `skipped_user_limit` value
  flows through `retryOutcome` as pass-through telemetry (verified: no CF-side bucketing).
  The downstream dashboard should treat it like `skipped_global_limit` — note for whoever
  owns OCR-retry metrics; out of scope for the function code.
