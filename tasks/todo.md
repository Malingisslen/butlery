# Sprint-salvage: fix the 6 confirmed /code-review findings, then ship

Context: the parallel sprint (wf_31f86296) built 5 tickets but the pre-commit
`/code-review high` gate found 6 confirmed defects the sprint's own verification
missed. Malin decided (2026-07-09): fix everything, re-review, then commit the
full batch. Nothing has shipped to main yet; the work is staged.

## Fixes

- [ ] **Finding 0/1 — BUT-1483 cross-recipe config split** (`tag_generator.dart`,
  `tagging_pipeline_runner.dart`). Root cause: BUT-1483 made `_phase1`/`_phase5`
  mutable on the single shared `TaggingService._tagGenerator`; under parallel
  retagging (`Future.wait` in retagging_scheduler) a sibling recipe's rebuild
  swaps phases mid-run. Fix: phases become final boot phases;
  `resolveConfigPhases()` returns an immutable per-run pair (memoised per
  version); the runner resolves ONCE per run and threads the pair into
  `runPhase1`/`runPhase5`/`runPhase5FromPhase1`. Update `tagging_service_test`
  stubs for the new signatures. Add a generator test proving a resolved pair is
  isolated from a later config change.
- [ ] **Finding 2/4 — BUT-1503 accepted share stuck pending**
  (`recipe_share_request_module.dart`). `acceptRecipeShareRequest` aborts on
  `!shared` even when the primary memberPermissions write succeeded. Fix: treat
  a granted-primary as accepted (flip request status) even if the secondary
  shared_recipes write failed.
- [ ] **Finding 3 — BUT-1503 recipient not notified**
  (`social_recipe_coordinator.dart`). Notification gated on the now-false
  result. Fix: notify when the recipient was actually granted access.
- [ ] **Finding 5/7 — BUT-1466 menu override exclusion + dedup**
  (`menu_service.dart`). `_matchesConstraint` early-returns false on null
  tagResult, ignoring a manual FREE override; also duplicates `_passesGlobals`'
  trust loops. Fix: route through `MenuAllergenTrust` (honours override) and
  share one helper.
- [ ] **Finding 6 — BUT-1512 missing friend_categories wildcard test**
  (`collection-group-wildcards-rules.test.ts`). Add the 6th catch-all wildcard.

## Verification
- `flutter test` the touched tagging + service + menu suites; `dart analyze`
  clean; re-run the specialist reviewers + a fresh `/code-review` before commit.

## Open questions
No architecture-changing unknowns — Malin approved the full fix-and-ship scope
via AskUserQuestion. Assumptions: (a) proportionate correctness fixes over
larger redesigns; (b) BUT-1503's "return false on persistent secondary failure"
stays (it's the intended signal) — only the downstream callers are corrected.

## What this means in plain language
- Same five improvements as before, but with the bugs the review caught now
  fixed: sharing won't leave requests stuck or people un-notified during a
  database hiccup; the menu builder respects your manual "gluten-free" marks;
  and the tagging fix is now safe when the app re-tags many recipes at once.
- You won't see anything new beyond the original five items working correctly.
- Risk: these are careful correctness fixes; each is re-reviewed before it
  lands, and everything is a clean revert if needed.

## Fix-pass review (2026-07-10) — 2 findings on the fixes themselves
- [ ] CONFIRMED menu_service.dart: removing the null-tagResult early-return let
  untagged recipes slip past an excludedTags gate. Fix: exclude untagged when
  excludedTags present (conservative); add a regression test.
- [ ] PLAUSIBLE social_recipe_sharing_service.dart: a throw from SharedRecipe.create
  after the primary save returns failed not partial. Fix: build the SharedRecipe
  BEFORE the primary memberPermissions save so a construction throw is pre-access.
