# Sprint 2026-07-11b — backend hardening test-gaps + decided-preference UI burndown

`/sprint-execute` Phase 1 selection. 8 tickets across 5 disjoint-file batches (parallel-safe).
State UUIDs: Todo 5a6d3faa · InProgress f8a3cf05 · InReview 9929b3b0 · Done 57dc8a84

## Batch A — Backend Functions Hardening (functions/src, gate: cloud-functions-specialist)

### BUT-1577 — withRateLimit ordering: per-user check before global-counter increment [Tier A, build, router: single]
`functions/src/middleware/rate_limiter.ts`. Denied per-user spam currently still inflates the
shared global hourly/daily LLM counters (checkGlobalLimit increments before the per-user check).
- [ ] Reorder so the global counter is only incremented after the per-user check allows the request (read-then-commit-after-allow, or check-order swap)
- [ ] New/updated test: a per-user-denied request does NOT increment the global counter
- Acceptance: (1) global increment happens only after per-user check passes; (2) denied-user request doesn't inflate global counter; (3) existing rate-limit tests still pass
- Gates: cloud-functions-specialist. Close: Done.

### BUT-1573 — export + pin RATE_LIMIT_CONFIGS dailyLimit values in a test [Tier A, build, router: single]
`functions/src/middleware/rate_limiter.ts` (same file as BUT-1577 — sequence after it in this batch).
The production dailyLimit values (100/50/100) are module-private and unpinned.
- [ ] Export a config seam (or the table itself) from rate_limiter.ts
- [ ] Test asserts the three dailyLimit values (structureRecipe/importRecipe/ocrRecipeImage)
- Acceptance: (1) dailyLimit values exported via a seam; (2) test pins all three values; (3) changing a value would fail the test
- Gates: cloud-functions-specialist. Close: Done.

### BUT-1578 — pin parse_events expireAt computation with a test [Tier A, build, router: single]
`functions/src/events/log-parse-event.ts`. The 30-day GDPR retention field has no test seam.
- [ ] Extract expireAt computation behind a testable seam, or assert it against the write payload via the existing log-parse-event-expiry.test.ts harness
- [ ] Test pins the 30-day window
- Acceptance: (1) expireAt computation is testable/asserted directly; (2) test pins 30-day window; (3) breaking the field fails the test
- Gates: cloud-functions-specialist. Close: Done.

## Batch B — Import Test Coverage

### BUT-1572 — pin ImportManager's default-constructor strategy registry [Tier A, build, router: single]
`lib/services/import/import_manager.dart` + `test/unit/services/import/import_manager_test.dart`.
No active test pins that the default-constructed registry keeps PhotoImportStrategy registered.
- [ ] Test asserts default-constructed ImportManager registers PhotoImportStrategy (and other expected strategies)
- Acceptance: (1) test added asserting PhotoImportStrategy registration; (2) covers other default strategies too; (3) no production code behavior changed
- Gates: code-reviewer, testing-specialist. Close: Done.

## Batch C — Tagging Cleanup + Test (router: BUT-1574 is full-panel — allergen-lookup surface)

### BUT-1481 — delete TagGenerator.generate() [Tier A, build, router: single]
`lib/services/tagging/tag_generator.dart` + `test/unit/.../tag_generator_test.dart` + phase
calculators / TaggingPipelineRunner. ~175-line dead duplicate orchestrator; 142 tests pinned to it.
- [ ] Delete TagGenerator.generate()
- [ ] Re-home the 142 pinned tests onto phase calculators / TaggingPipelineRunner (no coverage lost)
- Acceptance: (1) TagGenerator.generate() deleted; (2) 142 tests re-homed, not deleted; (3) no coverage regression
- Gates: code-reviewer, testing-specialist. Close: Done.

### BUT-1574 — test the quantity-only fallback branch in IngredientLookupService.lookupFromRaw [Tier A, build, router: FULL-PANEL (allergen-lookup file)]
`lib/services/tagging/ingredient_lookup_service.dart` + its test. New defensive fallback
(`namesToNormalize.isEmpty → [raw]`, hit by e.g. "2 dl") has no test.
- [ ] Phase 1.4 full-panel blind critique (file is on the allergen-lookup surface) → fold must-haves
- [ ] Test feeds a quantity-only input and asserts the fallback branch
- Acceptance: (1) test added for quantity-only input; (2) asserts the isEmpty→[raw] fallback; (3) no production code behavior changed
- Gates: code-reviewer, testing-specialist. Close: Done (Tier A) unless panel raises a sign-off item.

## Batch D — Settings/Legal Bottom Nav (Tier B — decided UI preference, not a new decision)

### BUT-1526 — bottom nav on settings/legal/notifications/FAQ detail views [Tier B, build, router: single]
Malin decided 2026-07-07 (already in project memory "UI/UX Design Preferences"): bottom nav
applies to ALL detail views. Extend the 4 that lack it.
Files: `lib/widgets/layout_scaffolds.dart`, `lib/views/settings/settings_hub_view.dart`,
`lib/views/legal/community_guidelines_view.dart`, `lib/views/legal/privacy_policy_view.dart`,
`lib/views/legal/terms_of_service_view.dart`, `lib/views/notifications/notifications_view.dart`,
`lib/views/faq_view.dart`. Reuse `recipe_detail_view.dart:219`'s existing implementation.
- [ ] Add bottom nav (cream-dark bg, greenMuted inactive, greenDark active, rust underline) to all 4 view groups
- [ ] Navigation via pushNamed (stack-based; back returns to the detail view) — identical everywhere, no per-view override
- Acceptance: (1) all 4 view groups render the spec'd bottom nav; (2) pushNamed stack-based nav, no override; (3) no regression to existing detail views' bottom nav
- Gates: code-reviewer, testing-specialist. Close: In Review (Tier B — screenshot for sign-off).

## Batch E — Deep-link Expiry Follow-ups (Tier B — includes new user-facing copy)

### BUT-1587 — extend expiry to menu/shopping links + user-facing expired/not-found message [Tier B, build, router: single]
Follow-up to just-shipped BUT-1540. `lib/core/bootstrap/handlers/deep_link_handler.dart` +
`lib/l10n/app_sv.arb` / `app_en.arb` + test.
- [ ] Gate expiry ONCE at the shared dispatch point (processDeepLink, before routing to recipe/menu/shopping handlers) using each link type's existing timestamp; fail-open on missing timestamp (staleness hygiene, not access control)
- [ ] Add a short Butler-voice message (no exclamation marks) for both expired-link and not-found-recipe dead-ends
- [ ] Test: expired menu/shopping link is rejected (no navigation) same as recipe links
- Acceptance: (1) expiry gated once at dispatch, covers recipe+menu+shopping; (2) expired/not-found show a Butler-voice message instead of failing silently; (3) test covers expired menu/shopping rejection; (4) no exclamation marks in the new copy
- Gates: code-reviewer, testing-specialist. Close: In Review (Tier B — new user-facing copy for sign-off).

## Needs you (Tier D / needs-approval — not built this sprint)

- **BUT-1149** (restore coverage floor to 60%) — recurring, diminishing-returns ticket with no
  atomic scope left (remaining low-coverage code needs DB seeding / widget tests / VM refactors,
  not a single sprint's work). Recommendation: either accept 55% as the durable floor, or reframe
  into ONE specific low-coverage module per future ticket instead of an open-ended "close the gap."
- **BUT-1580** (post-BUT-1571 ops: check + run ingredient-sync healing pass) — writes to
  production allergen-safety data (ingredient register `normalizedNames`/aliasesSv). Genuinely
  worth doing (fragment aliases can silently degrade allergen verdicts) but wants an attended,
  watched run with the dry-run diff reviewed by a human — not a background parallel-worktree batch.
- **BUT-1581** (require-review-before-commit gate misfires on pathspec/cross-repo commits) — the
  fix lives in `C:/claude-plugins/plugins/workflow-guards` (shared infra outside this repo's tree,
  affects Butlery+binge+synat). Can't be built inside a Butlery worktree batch. Recommendation:
  do it — real, reproduced bug — as a direct session against the claude-plugins repo.
- **BUT-1585** (sprint accounting fix) — items A (BUT-1540/1551 ship) and B (7 duplicate closures)
  are already resolved; BUT-1539 is confirmed obsolete here (see below). The residual item C
  ("add Step-0 grep-of-main guard to sprint-select") is itself a shared-plugin skill edit — same
  file family as BUT-1581. Recommendation: fold into the BUT-1581 fix session, then close BUT-1585.

## Deviation log

(none yet — filled during Phase 2 execution)

---
# Sprint 2026-07-11 (serial) — ready-set burndown from the salvage [ARCHIVED — mostly shipped]

Serial `/sprint-execute` (parallel engine held — BUT-1569 deny-rule bug). 5 tickets, one
at a time, each its own commit. BUT-1523 held (need-malin, plan-first).

State UUIDs: Todo 5a6d3faa · InProgress f8a3cf05 · InReview 9929b3b0 · Done 57dc8a84

## BUT-1586 — server retention classifier: inDays→ms (Tier A, router: single) — SHIPPED (Done in Linear)
Mirror the BUT-1550 client fix on the server. `functions/src/analytics/track-retention.ts`.
- [x] Drop `Math.floor` in `classifyLifecycleStageServer`; compare ms (`> 30*MS_PER_DAY`, `>= 14*MS_PER_DAY`) in BOTH active + never-active branches
- [x] Server test: 30d12h → churned, both branches

## BUT-1551 — route account-deletion through AuthService (Tier A, router: single) — SHIPPED (Done in Linear)
`onboarding_age_gate_blocked_view.dart:57` calls FirebaseAuth directly.
- [x] Add `AuthService.deleteCurrentAuthUser()` wrapping the Firebase Auth delete
- [x] View calls the service method, not FirebaseAuth.instance directly

## BUT-1540 — enforce shared-link expiry on live recipe path (Tier A, router: single) — SHIPPED (Done in Linear)
`deep_link_handler.dart` `_handleRecipeLink` navigates with no expiry gate.
- [x] Wire `isLinkExpired`/`isLinkValid` into the live path before navigation
- [x] Expired link → rejected + user-facing message, no navigation
(Follow-ups filed as BUT-1587, carried into the new sprint above.)

## BUT-1525 — tokenise PII in shareable-URL slugs (Tier A code, router: FULL-PANEL high-stakes) — NOT SHIPPED, still open (need-malin label added, held)
`lib/services/llm/pii_scrubber.dart:236`. Malin: tokenise. Still in Backlog as of 2026-07-11 — not
carried into the new sprint (now labeled need-malin; excluded from auto-selection).

## BUT-1524 — age-maturity gate on comment posting (Tier C, router: FULL-PANEL high-stakes, firestore.rules) — CANCELED in Linear 2026-07-11
Malin: gate comments. Ticket was canceled (not built) — see Linear history.

## Needs you (Tier D): none in this batch.
## Held: BUT-1523 (consent-toggle removal) — need-malin, plan-first. Still open, still held.

---
(prior sprint plans archived in git history: commit 0db2fbca4 and earlier)
