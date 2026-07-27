# Sprint 2026-07-26 — Selection

Backlog scanned: 104 Backlog + 4 Todo + 0 In Progress + 0 Triage, team Butlery (Linear MCP
live). No ticket carries `onboarding-reserved` in the selected set (two backlog items —
BUT-677, BUT-722 — carry it and were excluded from scoring entirely, per instruction).

**Obsolete:** BUT-1670 (shopping analytics) — built and shipped partially in `c0989a3a3`/
`38d3a715e`, graded FAIL at Phase 2.7 (AC2 unmet, AC1 half met, zero tests). Its exact
remaining scope was already re-filed with corrected acceptance criteria as BUT-1681.
Closed as Canceled/duplicate-of-BUT-1681, comment posted.

**Premise re-verified against current `main`** for every ticket below via targeted grep
(not just `git log`) before selecting: BUT-1696's `createCollaborativeList` still has no
escalation guard, BUT-1697's `account-deletion-cascade.ts` still only scrubs item-level
fields, BUT-1698's `social_export_manager.dart` still emits no `truncated` key,
BUT-1691's `ingredient_line_detector.dart` still uses raw `\b` over single-letter tokens
(`l`, `g`), BUT-1675/1676/1677's guard scripts don't exist yet, BUT-1685's
`menu_content_widgets.dart` still only branches on `!= singleUser`, BUT-1681's
`addItemsFromRecipe` source tag still has zero production callers and
`recipe_shopping_handler.dart` still calls the unlogged `addItemsBatch`. All still live —
nothing here is already fixed.

Every ticket below was Claude-authored (mostly the BUT-1679 post-hoc specialist review of
the 2026-07-25 sprint, some from the 2026-07-24 test-infra review), never human-approved —
the mandate column records why each is safe to build anyway.

## Agent A — shopping (trust & safety + analytics)
Area: shopping. Files: `lib/repositories/firebase/modules/shopping_repository_routing_module.dart`,
`lib/repositories/interfaces/shopping_repository.dart`, `lib/services/unified/unified_shopping_service.dart`,
`lib/services/unified/modules/shopping_item_management_module.dart`, `lib/models/unified/unified_shopping_list.dart`,
`lib/views/unified_shopping_view.dart`, `lib/viewmodels/unified_shopping_viewmodel.dart`,
`lib/services/shopping/menu_shopping_list_generator.dart`, `lib/views/recipe_detail/handlers/recipe_shopping_handler.dart`,
`functions/src/account/account-deletion-cascade.ts` (disjoint from every other batch).
**Note:** BUT-1681's fix site (`unified_shopping_service.dart`) overlaps BUT-1696's fix
site in the same file — kept in one batch/agent deliberately so the two land sequentially
in one PR instead of conflicting across parallel worktrees.

- [ ] **BUT-1683** [Tier C][build-review] Shared shopping list: the offline `_mutateFromCache`
  fallback still allows a lost update (the client-merge BUT-1665 exists to close), and the
  new `updateCollaborativeList` authorization change shipped with no
  firebase-backend-security / firestore-rules-tester review. **requiresPlanMode: true**
  (High priority + security label + `lib/repositories/`). Router: single — Trust & Safety,
  Security Architect, Software Architect.
  - **Signoff reason:** whether to narrow the offline path (reject cache-based edits of an
    existing row, only allow adds) or accept the lost-update window as a documented
    tradeoff in `ACCEPTED_DEVIATIONS.md` — a real availability-vs-consistency product call.
    Default the build to the conservative option (narrow the window) but flag it.
  - Acceptance:
    1. The offline `_mutateFromCache` path either narrows to reject edits of an existing
       item, or is left as-is with a new dated `ACCEPTED_DEVIATIONS.md` entry — not left
       silently undocumented either way.
    2. `updateCollaborativeList`'s privilege-escalation and edit-rights checks get an
       actual firebase-backend-security + firestore-rules-tester review as part of this
       diff's commit gate (not deferred a second time).
    3. The BUT-1665 online transactional concurrent-edit test still passes unchanged.

- [ ] **BUT-1696** [Tier C][build] Shared shopping list: a rejected edit silently reverts
  with no message; the offline replay can't tell a permission denial from network noise; a
  dead branch masks a wrong-exception-type bug; `createCollaborativeList` is the one write
  path with no escalation guard. **requiresPlanMode: true** (High + security + shopping
  repository). Router: single — Trust & Safety, Security Architect.
  - Fix: `UnifiedShoppingService.mutateSharedList` catches and surfaces
    `PermissionDeniedException` distinctly (Swedish string + `_error` + notify), instead of
    collapsing every failure into `false`. `_mutateFromCache` branches on
    `e.code == 'permission-denied'` and surfaces it rather than logging generic noise. The
    `if (!cached.exists)` branch is replaced with a try/catch around the cache get that
    converts the real `FirebaseException(unavailable)` into `ResourceNotFoundException`; the
    `fake_cloud_firestore`-only test that "proves" the old branch is corrected.
    `createCollaborativeList` gets the same ownership/escalation check as its siblings (or
    its `logPermissionCheck(granted: true)` is corrected to reflect no check ran).
  - Acceptance:
    1. `mutateSharedList` distinguishes `PermissionDeniedException` from other failures and
       surfaces a distinct Swedish message for it (not a single collapsed `false`).
    2. `_mutateFromCache`'s offline replay treats a `permission-denied` FirebaseException
       distinctly from other failures — surfaced, not swallowed as generic network noise.
    3. The `if (!cached.exists)` dead branch is fixed so an offline mutation of a
       never-fetched list produces `ResourceNotFoundException`; the misleading
       fake-Firestore-only test is corrected.
    4. `createCollaborativeList` gets the same escalation-guard pattern as
       `updateCollaborativeList`/`mutateCollaborativeList`, or its audit log is corrected to
       not claim a check that didn't happen.

- [ ] **BUT-1697** [Tier C][build] Shared list "last changed by" can attribute an edit to
  the wrong person, reads the wrong source (Auth handle instead of
  `userService.currentUserProfile` — the CLAUDE.md footgun), and survives account
  deletion; "uncheck all" now fires N concurrent single-doc transactions instead of one.
  **requiresPlanMode: true** (High + security + Bug + account/GDPR + shopping repository).
  Router: single — Trust & Safety, Privacy/DPO, Security Architect.
  - Fix: stamp `lastActivityByUserId`/`lastActivityByDisplayName` atomically from
    `userService.currentUserProfile` (never the Auth handle, and never let a null name fall
    through to the previous editor's cached name). Extend
    `account-deletion-cascade.ts`'s scrub to the list-level
    `lastActivityByUserId`/`lastActivityByDisplayName`/`ownerDisplayName` fields using the
    same `{queryField, updateField}` pairs already enumerated in `on-profile-updated.ts`.
    Rewrite `uncheckAllItems` to apply all unchecks inside one Firestore transaction on the
    document instead of `Future.wait` over N per-item transactions.
  - Acceptance:
    1. The id/name pair is stamped atomically from the profile source — no state where the
       id advances but the name doesn't, and no fallback to the previous editor's name when
       the new editor's name is unknown.
    2. Account deletion's cascade scrub removes the deleted user's raw uid/name from the
       list-level `lastActivityBy*`/`ownerDisplayName` fields, not just item-level fields.
    3. `uncheckAllItems` is one transaction per call, not N concurrent transactions on the
       same document.
    4. A test proves a no-Auth-displayName account's edit doesn't retain the previous
       editor's cached name.

- [ ] **BUT-1681** [Tier A][build] Shopping analytics: the real recipe→list path
  (`recipe_shopping_handler.dart` → `addItemsBatch`) still logs nothing; `logShoppingListCreated`
  still carries no `source`; the per-item generation-analytics loop has an unresolved cost
  question; all four BUT-1670 acceptance criteria are untested. **requiresPlanMode: false**
  (Medium priority, no security label). Router: single — Software Architect, Product
  Manager, FinOps (cost question).
  - Fix: wire `source: 'recipe'` through the actual production call path
    (`addItemsBatch`), add a `source` parameter to `logShoppingListCreated` and pass
    `'menu_generated'` from the generator, and decide (and implement) per-item vs one
    summary event for the generation-analytics loop per the repo's cost principle. Add the
    two missing test files.
  - Acceptance:
    1. The real recipe→list path fires `source: 'recipe'` analytics (not just the
       zero-caller viewmodel method).
    2. A menu-generated list's `shopping_list_created` event carries `source:
       'menu_generated'`.
    3. The per-item vs summary-event cost question is resolved and implemented, not left
       as an unbounded per-item loop with no stated reason.
    4. `unified_shopping_viewmodel_test.dart` and `menu_shopping_list_generator_test.dart`
       get the four missing test cases.

## Agent B — GDPR export hardening
Area: account. Files: `lib/services/account/export/social_export_manager.dart`,
`lib/services/account/export/activity_export_manager.dart`,
`test/unit/services/account/export/preferences_export_manager_test.dart`,
`test/unit/services/account/export/activity_export_manager_test.dart`,
`test/unit/services/account/export/social_export_manager_test.dart` (disjoint from every
other batch).

- [ ] **BUT-1698** [Tier C][build] `social_export_manager.dart` caps four sections
  (friends, friend_requests, shared recipes, shared menus) and emits no `truncated` flag at
  all — the under-reporting twin of the BUT-1662 over-reporting bug. **requiresPlanMode:
  true** (High + security + Bug + GDPR/account is a sensitive domain regardless of tier).
  Router: single — Privacy/DPO, Security Architect.
  - Fix: move all four sections onto `ExportPaginationHelper.fetchCapped` (the N+1 probe
    BUT-1662 generalised). Do the BUT-1686-noted `ActivityExportManager` sibling gap
    (`exportCommentsAndRatings`, `exportFeedback`) in the same change per the ticket's own
    instruction to do them together.
  - Acceptance:
    1. All four `social_export_manager.dart` sections emit a `truncated` boolean via
       `fetchCapped`, never omitting the key.
    2. A section with exactly `cap` documents reports `truncated: false`; one exceeding it
       reports `truncated: true` — both proven by test.
    3. `ActivityExportManager.exportCommentsAndRatings` and `exportFeedback` also get the
       truncation flag in this same change.

- [ ] **BUT-1686** [Tier C][build] Two of three export managers have no boundary tests for
  the BUT-1662 truncation fix — the exact "exactly at the cap" case the ticket exists to
  prove is unverified for 7 of 16 migrated sections. **requiresPlanMode: true** (High +
  GDPR/account sensitive domain). Router: single — Privacy/DPO.
  - Fix: add boundary-exact + genuinely-truncated cases to
    `preferences_export_manager_test.dart` (six sections + the two-leg OR case) and
    `activity_export_manager_test.dart` (pooled-ratings section).
  - Acceptance:
    1. `preferences_export_manager_test.dart` gets boundary-exact and over-limit cases for
       all six migrated sections, including the two-leg notification-delivery OR case.
    2. `activity_export_manager_test.dart` gets the same boundary pair for the
       pooled-rating-events section.
    3. No existing passing assertion is weakened to make a new case pass.

## Agent C — import (Swedish word boundary)
Area: parsing / import. Files: `lib/services/import/heuristics/ingredient_line_detector.dart`,
`lib/utils/text/swedish_word_boundary.dart` (new), `lib/services/menu/parser/text_normalizer.dart`,
`lib/services/voice/cooking_command_interpreter.dart`, `lib/services/shopping/ingredient_categorizer.dart`,
`lib/services/import/parsers/recipe_section_detector.dart` (disjoint from every other
batch; touches a BUT-1666/BUT-1661-shipped file only to swap its local lookaround for the
shared helper, not to change its already-shipped behavior).

- [ ] **BUT-1691** [Tier A][build] `ingredient_line_detector.dart`'s ASCII `\b` (over
  single-letter unit tokens `l`, `g`) swallows Swedish section headings (`Lök:`, `Kål`,
  `Gäddan`) and at least one instruction header (`Gör så här`) as ingredient lines during
  import; the Swedish-safe lookaround is now hand-rolled in four separate files.
  **requiresPlanMode: true** (High priority; also a multi-file codemod across 5 production
  files per workflow-discipline.md regardless of domain). Router: single — Software
  Architect, Data/Integrations Engineer.
  - Fix: replace the raw `\b` boundary in `ingredient_line_detector.dart` with the
    Swedish-safe lookaround. Create `lib/utils/text/swedish_word_boundary.dart` exporting
    `kNoWordBefore`, `kNoWordAfter`, `RegExp swedishWholeWord(String)` (promote
    `cooking_command_interpreter._phrase` verbatim) and migrate the four named hand-rolled
    sites to it with no behavior change at any of them.
  - Acceptance:
    1. `ingredient_line_detector.dart` no longer classifies `Lök:`, `Rödkål:`, `Kål`,
       `Gäddan`, or `Gör så här` as ingredient lines.
    2. `lib/utils/text/swedish_word_boundary.dart` exists and the four named sites
       (`text_normalizer.dart`, `cooking_command_interpreter.dart`,
       `ingredient_categorizer.dart`, `recipe_section_detector.dart`) are migrated to it
       with every existing test for those four files still passing unchanged.
    3. The repo's `swedish-boundary-guard` commit hook still passes (comment-aware
       exclusion added if the guard needs one — the guard itself is not weakened).

## Agent D — CI / test-infrastructure guards
Area: backend (tooling/CI, not `lib/` or `functions/src/` production code). Files:
`functions/scripts/check-test-registration.js` (new), `.github/workflows/cloud-functions-unit.yml`,
`.github/workflows/firestore-rules.yml`, `lefthook.yml` (disjoint from every other batch).

- [ ] **BUT-1675** [Tier A][build] Two CI triggers (Cloud Functions test discovery,
  firestore-rules job's own `paths:` trigger) are hand-maintained lists nothing checks
  against reality — a new test file or rules test can silently run nowhere, forever.
  **requiresPlanMode: true** (High priority — the risk-gate priority rule fires regardless
  of the file domain being tooling/config, not production `lib/`/`functions/src/`).
  Router: single — Security Architect (finding (b) is the security-rules trigger).
  - Fix: build `check-test-registration.js` per the ticket's two assertions
    (`test:*` script coverage + both `paths:` trigger blocks), wire it into
    `cloud-functions-unit.yml` and a scoped `lefthook.yml` pre-commit step, with a
    ticket-backed `UNREGISTERED_OK` escape hatch.
  - Acceptance:
    1. The script fails, naming the file, when a `.test.ts` has no `test:*` script entry.
    2. It fails, naming the file and trigger block, when a `*rules*.test.ts` is missing
       from either `paths:` list in `firestore-rules.yml`.
    3. Passes clean on HEAD (0 orphans, matching the ticket's verified baseline).
    4. An `UNREGISTERED_OK` entry without a Linear ticket reference fails the check.

- [ ] **BUT-1677** [Tier B/C][build] Firestore rules coverage (108 `match` blocks, 29 rules
  test files) has never been measured — an untested rule on children's-data access is the
  highest-consequence unmeasured surface in the repo. **requiresPlanMode: true** (High
  priority; touches the security-rules CI job). Router: single — Security Architect.
  - Fix: fetch `ruleCoverage.json` from the emulator after `test:rules:all`, render a
    per-block hit table into the job summary + artifact; gate on a SET diff of normalized
    match-block patterns (HEAD vs base) with zero hits — never a line-diff. Add
    `fetch-depth: 0` to the checkout step; base ref = `github.event.before` on push,
    `github.base_ref` on pull_request. File one follow-up ticket with the actual
    untested-block count once the first green run lands.
  - Acceptance:
    1. Job summary lists all 108 match blocks with hit counts; artifact uploaded.
    2. A deliberately untested newly-added match block fails the job; moving/re-indenting
       an existing block does not.
    3. `fetch-depth: 0` present; base-ref selection correct for both push and pull_request.
    4. The untested-block-count follow-up ticket exists before this ships.

## Agent E — menu allergen visibility
Area: menu. Files: `lib/widgets/menu/menu_content_widgets.dart`,
`test/widget/menu/menu_allergen_visibility_test.dart`,
`docs/architecture/ACCEPTED_DEVIATIONS.md` (disjoint from every other batch).

- [ ] **BUT-1685** [Tier B][build-review] The `MenuPrefSource.householdIncomplete` state
  BUT-1663 introduced is produced but never surfaced — a menu built on a guessed safety
  floor shows identical wording to a healthy run. Two BUT-1663 safety deviations
  (widen-vs-exclude, dropped `trackedDietary`) were also never recorded.
  **requiresPlanMode: true** (High priority + allergen-safety domain). Router: single —
  Trust & Safety, Product Manager.
  - **Signoff reason:** whether the menu screen should visibly warn on an incomplete
    household roster (and with what wording/placement), or whether the enum value stays
    telemetry-only for now — a genuine UX call on a safety-adjacent screen. Build the
    warning banner as the default guess; flag for her look either way.
  - Acceptance:
    1. The menu screen visibly communicates the `householdIncomplete` state, OR that
       decision is explicitly recorded as telemetry-only rather than left a silent gap.
    2. `menu_allergen_visibility_test.dart` gets a test case for the new enum value.
    3. The two BUT-1663 deviations get a dated entry in `ACCEPTED_DEVIATIONS.md`.

## Needs your call (not built this sprint)

- **BUT-1672** — `addItemsFromRecipe`'s dedup-and-merge branch is unreachable (bulk recipe
  adds always duplicate). Two genuinely different fixes (wire it through vs delete the dead
  branch) depend on how much duplicate lines bother you in practice; Low priority. Posted a
  Linear comment recommending "wire it through" next time shopping gets a slot.
- **BUT-1693** — Let a household member share their allergy list (BUT-1663 Part 2).
  Already labeled `need-malin`; a real feature with a consent/UX decision layered on top,
  not an autonomous build. Posted a comment recommending a short `/interview` pass before
  building, same pattern as BUT-1611/BUT-1625.
- **BUT-1480** — Unify the two URL import pipelines. Carried forward from the 2026-07-25
  sprint; still labeled `need-malin`, comment already on file.
- **BUT-1323** — "Who's eating" per-day presence EPIC (DIFFERENTIATOR). Carried forward;
  too large/speculative for an autonomous pick, comment already on file recommending an
  `/interview` + slice-based plan.

## Post-sprint steps (to run after implementation)

1. `dart analyze --fatal-infos` + the TS equivalent for `functions/` on the full tree.
2. File follow-up Linear tickets for every deferred sub-scope before commit (per-batch
   deviation log below feeds this).
3. Commit through the gate (code-reviewer on all `.dart`, firebase-backend-security on
   Agent A's repository files, cloud-functions-specialist on Agent A's/B's `functions/src`
   touches, firestore-rules-tester only if `firestore.rules` itself is touched — it isn't
   in this sprint's scope, only the CI job that measures it).
4. Push (push triggers deploy in this repo — treat it as a release).
5. Transition tickets: Tier A build + all-pass → Done. Tier B/C or build-review or any
   failed/unclear criterion → In Review + plain-language comment + PushNotification.
6. Re-check `docs/onboarding/workflow-map.stale` — if any of this sprint's flows touch
   mapped code, re-trace before commit per CLAUDE.md.

## Outcome table — 2026-07-26 (written at post-sprint)

Ship state: **STAGED AND UNCOMMITTED.** No commit-gate specialist reviewed any file of this
diff (every `.claude/state/*.marker` predates the implementation and pins only BUT-1690
paths), so per the delivery digest the sprint ends staged, the unblocking ticket is filed
(**BUT-1703**) and all Linear transitions are HELD. `dart analyze --fatal-infos` on the full
tree: **No issues found.** `tools/check_workflow_map.py`: **OK** (360 nodes, 54 flows).

| Ticket | AC verdicts | Grade | Disposition |
|---|---|---|---|
| BUT-1696 | AC1 pass, AC2 pass, AC3 pass | pass | Code complete; visible half untested → BUT-1710. HELD (no commit) |
| BUT-1681 | AC1 pass (untested), AC2–AC4 pass | pass | Code complete; AC1 has no test → BUT-1711. HELD |
| BUT-1698 | AC1–AC3 pass | pass | Code complete. HELD |
| BUT-1691 | AC1–AC3 pass | pass | Code complete; 3 sibling sites deferred → BUT-1713/1714/1715. HELD |
| BUT-1675 | AC1 unproven, AC2 unproven, AC3 pass, AC4 unproven | partial | Guard is itself untested → BUT-1709. HELD |
| BUT-1683 | AC1 pass, **AC2 fail (3rd deferral)**, AC3 pass | fail | → BUT-1706. Founder's call on the availability/consistency tradeoff still open. HELD |
| BUT-1697 | AC1 **fail** (Auth-handle fallback), AC2 **fail** (removed-member residual), AC3 pass, AC4 pass | fail | → BUT-1705, BUT-1716, BUT-1718. HELD |
| BUT-1686 | AC1 **fail** (zero work), AC2 pass, AC3 pass | partial | → BUT-1712. The verifier's "8 tests RED / `>=` still live" verdict was **refuted by running the suite** (`+106 All tests passed`; `fetchCapped` line 243 already reads `rows.length > cap` on a `cap + 1` fetch — the `>=` at line 104 is a log-warning in a different method). BUT-1704 was filed off that false claim and CANCELLED. HELD |
| BUT-1677 | AC1 unproven, AC2 **fail** (two parser holes, no tests), AC3 unproven, AC4 **fail** | fail | → BUT-1707, BUT-1708. HELD |
| BUT-1685 | AC1 **fail**, AC2 **fail**, AC3 **fail** — zero artifacts | **dropped** | batch-4 never applied; all 3 declared files byte-identical to HEAD. → Todo + `need-malin` (2nd consecutive drop) |
| BUT-1670 | n/a | obsolete | Superseded by BUT-1681, which re-scoped and replaced it |

Follow-ups filed: **BUT-1703 – BUT-1718** (16, of which **BUT-1704 was cancelled as a false
premise** — 15 live).

**Ground-truth checks run in this phase, not inherited:** `dart analyze --fatal-infos` (clean),
`tools/check_workflow_map.py` (OK), `flutter test test/unit/services/account/export/`
(**+106 all passed** — refuting the BUT-1686 red-suite verdict), `file` on all six new
files (text, no binary blobs), and a read of the three BUT-1691 residual sites and the two
`export_pagination_helper.dart` comparison sites.

**One** of the four "verification failed" verdicts (BUT-1686's) was reproduced and **refuted**.
The other three (BUT-1683, BUT-1697, BUT-1677) were NOT re-run here — BUT-1683's marker
claims were independently confirmed against `.claude/state/`, but BUT-1697's and BUT-1677's
code claims are still only the verifier's word. Reproduce each before acting on it; one
verdict in four being wrong is enough to make that mandatory, not optional.

## Deviation log

Recorded at post-sprint from the implementers' reports (it was empty during Phase 2 — see
the lesson added to `tasks/lessons.md` on that).

**Scope corrections — the ticket named the wrong file**
- BUT-1696: the silently-reverting checkbox does not route through `mutateSharedList` at all
  (viewmodel → `service.toggleItemBought` → `ShoppingItemManagementModule` → repository) →
  fixed both paths with the same distinct-exception shape.
- BUT-1697: the attribution bug is in the repository-layer `ShoppingItemOperationsModule`,
  not the service module the batch fileset named → fixed where it actually is.
- BUT-1681: the per-item event loop the ticket describes had already been reverted and the
  generated path logged nothing → re-scoped to "implement it once, at the decided
  granularity" and the Linear body updated before coding.

**Fileset widenings (all outside the declared batch list)**
- BUT-1691 → `lib/widgets/import/ingredient_line_detector.dart` (+52). The assisted-import
  duplicate class, reached from `assisted_import_viewmodel.dart:112`; fixing only the
  URL-import copy would have left the bug live on half the import surface. Correct call,
  unrecorded at the time — so this sprint's batch-disjointness guarantee was never verified
  against the final diff. Must be named explicitly in the code-reviewer marker.
- BUT-1683, BUT-1685 → `.claude/rules/accepted-deviations.md`, per the same-edit sync
  contract, though only the docs file was in the fileset.
- BUT-1681 → `shopping_events_tracker.dart`, `analytics_service.dart` (both new params
  optional, no call site changes behaviour).
- BUT-1697 → `updateItemsBatch` added to `ShoppingRepository` + the Firebase repository +
  the item-ops module, because one-transaction uncheck needed a batch capability that did
  not exist.
- BUT-1698 → `export_pagination_helper.dart` (`'feedback': 1000`); routing feedback through
  `fetchCapped` with no declared limit would have fallen back to `defaultBatchSize` (500)
  and SHRUNK the export.
- BUT-1677 → `functions/scripts/rules-coverage-report.js`; ~450 lines of collector/parser
  inlined as YAML heredocs would be unmaintainable.
- BUT-1675 → `firestore-rules.yml` added to both `paths:` blocks of
  `cloud-functions-unit.yml`, so editing the file the guard reads re-runs the guard.

**Conservative choices — surprise found, scope NOT expanded**
- BUT-1696: reused existing ARB keys rather than adding one (a new key regenerates three
  committed l10n files — high conflict risk against parallel batches).
- BUT-1697: scrubbed `lastActivityByUserId`/`lastActivityByDisplayName`/`ownerDisplayName`
  but deliberately left `ownerId` — nulling it orphans the list for every remaining member.
- BUT-1697: non-owners cannot leave a shared list; a real fix is a rules change + a product
  decision → left untouched, now BUT-1718.
- BUT-1698: fixed only the enumerated capped reads; six more ride repository defaults →
  BUT-1701. Skipped probing the conversation-list cap — an N+1 probe costs up to 1001 extra
  reads per export, against the repo's cost principle.
- BUT-1686: skipped the preferences half, claiming `38d3a715e` already covered it. The
  verifier disagreed after reading the same file → BUT-1712 opens by settling that
  disagreement, not by writing tests.
- BUT-1691: did NOT migrate `_subHeadingUnitGuard` — tightening that boundary is the UNSAFE
  direction (it would strip gluten words out of the list allergen tagging reads) → BUT-1714
  as a product call.
- BUT-1675: found four registered-but-unrun emulator suites; did NOT append them to
  `test:rules:all` (a red suite would redden main's rules gate) → ticket-backed allowlist +
  BUT-1702.
- BUT-1683: appends can be made genuinely lossless with `arrayUnion` while existing-row
  edits have no offline-replayable primitive → narrowed the half that can be narrowed,
  documented the residual half; the offline fallback was neither removed nor weakened.
- BUT-1685: the ticket offered "wire it up" OR "telemetry-only"; chose to wire it up, because
  telemetry-only ships a silent safety gap on an allergen app. (Moot — the batch never
  applied.)

**Verification-method notes**
- BUT-1677: three of the plan's four external assumptions were wrong against the live API —
  the endpoint has no `.json` suffix, the payload shape is `{rules:{files:[{content}]}, report:[]}`
  with counts in `values[].count` and no `endLine`, and coverage is scoped per `projectId`
  (29 distinct ids across the suites, so the planned `demo-test` would have measured almost
  nothing). The first collector, written from the assumed shape, would have collected zero nodes.
- BUT-1691 / BUT-1685: instructions said `git add -A`; `flutter pub get` had dirtied 7
  generated plugin-registrant files plus `.claude/settings.local.json`, none of them the
  batch's → staged by explicit pathspec per the repo's parallel-sessions rule.
- BUT-1685: a mutation test (flip the guard to `singleUser`) reddened only 2 of 3 relevant
  cases, so negative assertions were added to the solo-user and no-hidden cases.
- BUT-1683: the agent could not spawn sub-agents and `functions/node_modules` was absent →
  performed the rules-parity review directly, fixed the one gap found, and flagged the
  rules-test gap rather than writing a test it could not run.

---

# Archived — 2026-07-25 sprint (10 tickets + BUT-1679 ship remediation)

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

**Outcome: shipped in `38d3a715e`, 2026-07-26.** All three blockers below were fixed (verified
against `main` at 2026-07-26 selection time: `_requireNoPrivilegeEscalation` present on both
`updateCollaborativeList` and `mutateCollaborativeList`; `RecipeFormCoordinator.dispose()` wired
into the viewmodel and `syncToCollaborative` guarded). The specialist-review findings this pass
generated (display-name misattribution, offline replay swallowing `permission-denied`,
`lastActivityBy*` not scrubbed on deletion, `createCollaborativeList` left unguarded) were filed
as BUT-1696/BUT-1697 and selected into the 2026-07-26 sprint above.

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

- [x] **BLOCKER 1 — privilege-escalation gate missing on the transactional write path.**
  Found independently by firebase-backend-security (High 1) and code-reviewer (Medium 3).
  `_requireNoPrivilegeEscalation` added to both the transaction path and the offline
  cached-base path.
- [x] **BLOCKER 2 — `createRecipe`'s new post-dispose `StateError` had an unguarded caller.**
  `RecipeFormCoordinator.syncToCollaborative` guarded on `_disposed || _state.isDisposed`;
  `_coordinator.dispose()` wired into the viewmodel's dispose; false comment corrected.
- [x] **BLOCKER 3 — BUT-1669 shipped with no test for the crash it fixes.** Test added.
- [x] Comment corrections folded in (zero behaviour change).
- [x] Swedish-boundary guard false positive — comments reworded.

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
