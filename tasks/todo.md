# Sprint 2026-07-11c — backend/test-gap hardening + backlog hygiene

`/sprint-execute` Phase 1 selection. 8 tickets across 7 disjoint-file batches (parallel-safe).
State UUIDs: Todo 5a6d3faa · InProgress f8a3cf05 · InReview 9929b3b0 · Done 57dc8a84

**Step-0 grep-of-main sweep found 5 more scanner-duplicate tickets already fixed under other
IDs — closed as obsolete before selection (see bottom of this file). This is the exact pattern
BUT-1575 exists to hunt down at scale, which is why it's selected below.**

## Batch A — Backend Functions Bug Fix (functions/src, gate: cloud-functions-specialist)

### BUT-1511 — fix onFamilyRatingUpdated trigger missing recomputation on memberType-only changes [Tier A, build, router: single]
`functions/src/index.ts` (family-rating trigger family, ~line 315). Recompute only fires on
`before.stars !== after.stars`; a `memberType` flip (e.g. proxy → profile) without a star change
skips recomputation, silently mis-folding that row into/out of the public average.
- [ ] Add `before.memberType !== after.memberType` to the recompute-trigger condition alongside the existing star-change check
- [ ] New unit test: recompute is scheduled when only memberType changes (stars unchanged)
- Acceptance: (1) trigger condition covers memberType flips explicitly; (2) new test proves recompute fires on memberType-only change; (3) existing star-change test still passes unmodified
- Gates: cloud-functions-specialist. Close: Done.

## Batch B — Analytics Cleanup (lib/services/analytics, gate: code-reviewer+testing-specialist)

### BUT-1539 — retire dead subscription_tier analytics (hardcoded 'free' forever) [Tier A, build, router: single]
`lib/services/analytics/analytics_events.dart:247-251`, `lib/services/analytics/user_property_bootstrap.dart:38,55,63-69`.
Malin decision 2026-07-04 (role-org scan Q&A): retire entirely — consumer subscriptions were dropped.
- [ ] Delete the `subscription_tier` property + `emitSubscriptionTier` and all call sites
- [ ] Grep confirms no remaining production reference to `subscription_tier`
- Acceptance: (1) property + emit code deleted; (2) no dangling call sites in user_property_bootstrap.dart; (3) no behavior change to any other emitted property
- Gates: code-reviewer, testing-specialist. Close: Done.

## Batch C — UI Test Coverage (lib/widgets/common/layout, gate: code-reviewer+testing-specialist)

### BUT-1589 — widget test: LayoutScaffolds.detailBottomNav renders the shared bottom nav [Tier A, build, router: single]
Follow-up to BUT-1526 (shipped). `lib/widgets/common/layout/layout_scaffolds.dart` — no test
today, verification was a manual screenshot sign-off only.
- [ ] New widget test pumps `LayoutScaffolds.detailBottomNav` (or a consuming view) and asserts `ButleryBottomNavigation` renders with `currentIndex: null`
- [ ] Test asserts tapping an item navigates via `pushNamed` (stack-based)
- Acceptance: (1) test renders the shared bottom nav; (2) asserts no tab pre-selected; (3) asserts pushNamed nav; (4) no production code behavior changed
- Gates: code-reviewer, testing-specialist. Close: Done.

## Batch D — Tagging Test Coverage (lib/models/tagging + lib/services/tagging/config, gate: code-reviewer+testing-specialist)

### BUT-1492 — TagResult serialization/migration round-trip tests [Tier A, build, router: FULL-PANEL (tag_result.dart high-stakes)]
`lib/models/tagging/tag_result.dart` + `test/unit/models/tagging/tag_result_test.dart`. Existing
tests cover plain JSON/Firestore roundtrip but NOT the read-time-only V0→V2 migration path or the
cross-user cache path (verified: no "V0"/"migration" hits in the current test file).
- [ ] Phase 1.4 full-panel blind critique (allergen-tagging-adjacent file) → fold must-haves
- [ ] New test: a V0-shaped payload deserializes into a valid V2 TagResult (migration round-trip)
- [ ] New test: cross-user cache path — a TagResult built under one user context is correctly (re)read under another user's cache lookup
- Acceptance: (1) V0→V2 migration round-trip covered; (2) cross-user cache path covered; (3) no production code changed unless a test seam is genuinely required (state so in the diff)
- Gates: code-reviewer, testing-specialist. Close: Done (Tier A) unless panel raises a sign-off item.

### BUT-1491 — reserved_tags.dart consistency test [Tier A, build, router: single]
`lib/services/tagging/config/reserved_tags.dart` (no test file exists today, confirmed).
~120 hand-copied tag literals with nothing asserting they match what the tagging phases emit.
- [ ] New test asserting reserved_tags.dart literals match tags actually emitted by the tagging phase calculators
- [ ] Test fails if a new auto-tag is added to a phase without being added to reserved_tags.dart
- Acceptance: (1) consistency test added; (2) proven to catch the shadowing bug (new emitted tag missing from reserved list fails the test); (3) no production code changed
- Gates: code-reviewer, testing-specialist. Close: Done.

## Batch E — Import Test Coverage (test/unit/services/import, gate: code-reviewer+testing-specialist)

### BUT-1493 — strengthen import_manager_test happy path [Tier A, build, router: single]
`test/unit/services/import/import_manager_test.dart:183-201` ("should auto-detect text strategy
and parse"). Confirmed: only asserts `isSuccess`/`strategy != null` today.
- [ ] Add title assertion to the happy-path test
- [ ] Add ingredient-count assertion to the happy-path test
- Acceptance: (1) title assertion added and passes against the real parsed fixture; (2) ingredient-count assertion added and passes; (3) existing assertions preserved, not weakened; (4) no production code changed
- Gates: code-reviewer, testing-specialist. Close: Done.

## Batch F — GDPR Export Truncation Fix (lib/services/account/export, gate: firebase-backend-security)

### BUT-1562 — GDPR export truncation-flag bugs (notification 500-cap + pantry flag) [Tier A, build, router: FULL-PANEL (security label + high-stakes export files)]
`lib/services/account/export/preferences_export_manager.dart:46-66` (notification export never
sets `truncated: true` even when the 500-cap is hit — confirmed). `lib/services/account/export/content_export_manager.dart:343-371`
(pantry export's `truncated` flag logic — verified on read: `maxDocuments` IS applied via the
`.limit()` query and the flag IS gated on `items.length >= pantryLimit`, so this half of the
original finding may already be correct; re-verify against the actual repository/query path
before "fixing" a non-bug).
- [ ] Notification export sets `truncated: true` when the export actually hits the 500-notification cap
- [ ] Re-verify pantry export's truncation flag against current code; fix only if a real gap is found, otherwise pin the correct behavior with a test
- [ ] New/updated test(s) for both behaviors
- Acceptance: (1) notification truncated-flag reflects reality; (2) pantry truncated-flag reflects reality (fixed or confirmed-already-correct with a pinning test); (3) no change to what data is exported, only to metadata accuracy; (4) don't "fix" a non-bug — state the finding either way
- Gates: firebase-backend-security. Close: Done (Tier A) unless panel raises a sign-off item.

## Batch G — Backlog Hygiene (Linear-only, no production files, gate: none)

### BUT-1575 — bulk-verify remaining 2026-07-04 org-scan tickets against current code; close false positives [Tier A meta, build, router: n/a]
No code diff — Linear administration only. This sprint's own Step-0 sweep already found 5 more
false positives in the BUT-1521–1568 range (BUT-1542, BUT-1543, BUT-1549, BUT-1552 — org-scan —
plus BUT-1588 from the follow-up range), closed below with commit evidence. This ticket continues
that sweep across the rest of the still-open range.
- [ ] Re-verify every still-open BUT-1521–1568-range ticket against current code (grep/blame), not just re-read the ticket text
- [ ] Close false positives citing the specific resolving commit
- [ ] Correctly lane survivors (autonomous/need-malin/deferred) for future sprint trust
- Acceptance: (1) every open ticket in range has been re-verified or closed; (2) each closure cites commit/blame evidence; (3) survivors carry a correct lane label
- Gates: none (no code diff). Close: Done.

## Needs you (Tier D / needs-approval — not built this sprint)

- **BUT-1523** (decide + wire the socialFeatures consent toggle) — need-malin labeled, still open.
  Two directions (gate social writes on the toggle, or remove it since social is core/non-optional)
  are a product+legal call, not something to guess at. Recommendation: pick a direction when you
  have five minutes — either is a small, well-scoped fix once decided.
- **BUT-1516** (v1.1 — weight weekly menu on pooled "Butlery-betyget" ratings) — depends on pooled
  ratings, which is code-complete but flag-OFF (memory: `project_pooled_ratings.md`). Building
  menu-weighting logic against an unshipped signal is premature. Recommendation: park until pooled
  ratings actually ships and has real data to weight on.
- **BUT-1465** (settings toggle: opt out of household allergen filtering) — a new user-facing
  safety-adjacent toggle; whether/how to let users opt OUT of allergen filtering is a product and
  safety-messaging decision, not a build call. Recommendation: worth having, but wants a quick
  product sign-off on the copy/framing (this is filtering people's kids' allergens) before building.
- **BUT-1498** (tagging register/config cleanup: excludes_tags column, vocabulary drift, doc-ID
  collision logging) — bundles several distinct fixes on the high-stakes allergen-tagging surface
  into one ticket with unclear atomic scope. Recommendation: split into 2-3 atomic tickets before
  building any of it — don't build a bundle blind.
- **BUT-1513** (rewrite ~120 bulk-skipped BUT-369 integration tests on the emulator lane) — real
  test debt, but ~120 tests is not one sprint ticket's worth of scope, and the emulator-lane
  approach itself is a tooling decision. Recommendation: worth doing, but reframe into a handful
  of smaller per-area tickets (e.g. "emulator-lane: shopping" / "...: social") so a batch can
  actually land one at a time.
- **BUT-1555** (deploy safety: no post-deploy smoke gate, no rollback path, health-alert watches
  only 3 of 14 workflows) — bundles three different infra decisions (smoke-test design, rollback
  mechanism, alert coverage) that each want her steer on approach/cost before building.
  Recommendation: worth doing; split into the three sub-decisions and pick an approach for each
  first.
- **BUT-1315** (EPIC — weekly menu: make it personal & fresh, the linchpin) — epic-level product
  vision ticket, not an atomic build. Recommendation: keep as the epic umbrella; child tickets get
  scored/selected individually as they're broken out.
- **BUT-1323** ("who's eating" per-day household presence — DIFFERENTIATOR) — feature-level idea
  ticket without an implementation-ready scope. Recommendation: needs a scoping pass (what's the
  smallest useful slice?) before it's buildable — not this sprint.

## Obsolete (closed this session — Step-0 grep-of-main check found the premise already resolved elsewhere)

- **BUT-1588** — closed Done. Resolved by commit `26f7a594e` (test(rate-limit): pin withRateLimit
  per-user-before-global ordering, BUT-1577) — `functions/src/__tests__/rate-limiter-withratelimit-ordering.test.ts`
  already covers exactly this guarantee.
- **BUT-1543** — closed Done. Resolved by commit `03067cb38` (fix(l10n): localize shared
  state-facade + maintenance + required-field strings, BUT-1430) — `message_states.dart` already
  routes both fallback titles through `context.l10n`.
- **BUT-1549** — closed Done. Resolved by commit `412efb5ed` (fix(analytics): preserve
  un-attributed win-back send's bridge fields, BUT-1428) — `detect-lapsed-users.ts` already gates
  the overwrite exactly as requested.
- **BUT-1552** — closed Done. Resolved by commit `bcbc763b1` (feat(hooks): migrate 14
  workflow/role-org hooks to shared malin-plugins) — `.claude/shared-plugin.json` already wires
  `cloud-functions-specialist` to `^functions/src/` (covers `__tests__/` too).
- **BUT-1542** — closed Done. Both sub-issues already fixed in current code (`privacyActivityFeedHint`
  in both ARB files, `maintenance_mode_blocker.dart` fully localized) — no hardcoded Swedish
  literal remains; no single resolving commit identified, but the code is provably clean.

## Deviation log

(none yet — filled during Phase 2 execution)

---
# Sprint 2026-07-11b — backend hardening test-gaps + decided-preference UI burndown [ARCHIVED — SHIPPED]

`/sprint-execute` Phase 1 selection. 8 tickets across 5 disjoint-file batches (parallel-safe).
State UUIDs: Todo 5a6d3faa · InProgress f8a3cf05 · InReview 9929b3b0 · Done 57dc8a84

All 8 tickets in this batch (BUT-1577, BUT-1573, BUT-1578, BUT-1572, BUT-1481, BUT-1574,
BUT-1526, BUT-1587) shipped in commit `a16611f27` and follow-on commits; none remain in
Backlog/Todo as of the 2026-07-11c selection. BUT-1588 (a BUT-1577 test-coverage follow-up
filed after this sprint) was found obsolete and closed above.

## Needs you (Tier D / needs-approval — not built this sprint)

- **BUT-1149** (restore coverage floor to 60%) — recurring, diminishing-returns ticket with no
  atomic scope left (remaining low-coverage code needs DB seeding / widget tests / VM refactors,
  not a single sprint's work). Recommendation: either accept 55% as the durable floor, or reframe
  into ONE specific low-coverage module per future ticket instead of an open-ended "close the gap."
  — SUPERSEDED 2026-07-11: Malin decided 55% is the durable floor (`project_coverage_floor_decision.md`).
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
