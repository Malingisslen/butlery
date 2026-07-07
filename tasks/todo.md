## Sprint: Pipeline-audit bug burndown + allergen/tagging correctness — 2026-07-07

**Selection note (important):** the backlog carried a large 2026-07-04 "28-role org-scan"
batch (BUT-1521–1568-ish range). Spot-verifying my first-pass picks from that batch against
CURRENT code found a very high false-positive rate — see `obsolete` list below. All 10
tickets actually selected here come from sources verified against live code this session:
the 2026-07-01 pipeline audit (`docs/architecture/PIPELINE_IMPROVEMENT_ROADMAP.md`, "every
P0/P1 item adversarially verified against the code"), a BUT-1464 implementer follow-up, and
the `tasks/hardest-issues.md` 2026-07 deep scan. Recommend a follow-up pass to bulk-triage
the rest of the 2026-07-04 scan batch before it's trusted for future sprints (see needsApproval).

### Agent A: menu-allergen-safety — per-slot allergen trust guard
- [ ] **A1. Route `_matchesConstraint` through `MenuAllergenTrust`** `[Tier A]` — `lib/services/menu_service.dart`: per-slot prompt constraints (e.g. "3 glutenfria middagar") still read raw `tr.getAllergenStatus`/`getDietaryStatus` instead of `MenuAllergenTrust.effectiveAllergenStatus`/`effectiveDietaryStatus` (the trust guard `_passesGlobals` already uses). A manual CONTAINS override on an auto-FREE recipe can currently satisfy a "free from X" per-slot constraint. (BUT-1466)
  - Acceptance: a per-slot "fri från X" constraint rejects a recipe with a manual override marking it CONTAINS-X · a stale-FREE (needsRetagging/low-coverage) recipe follows `includeUnknownInMenu` in per-slot matching, same as the global-constraint path · a `menu_service_test.dart`-level test covers both
  - Stakeholders: Product Manager (single tier) — requiresPlanMode: **true** (single-tier + High priority)

### Agent B: tagging-data-integrity — register sync + normalization
- [ ] **B1. Split ingredient aliases on both `;` and `,`** `[Tier A]` — `functions/src/admin/sync-ingredients-core.ts:188`: `parseList(row.aliases_sv, ";")` only splits on semicolon; Sheet rows using commas (seen live: `vegofärs`, `tartar-sauce`) sync as one comma-joined array element. (BUT-1495)
  - Acceptance: alias cells split on both `;` and `,` · regression-tested against the two live-observed cases (`vegofärs`, `tartar-sauce`) · existing semicolon-only rows keep working (no regression)
- [ ] **B2. Fix three normalization defects in ingredient lookup** `[Tier A]` — `lib/services/tagging/ingredient_lookup_service.dart` `_generateLookupVariations`/`_cleanForLookup`: (a) no `-erna`/`-orna` definite-plural stripping ("morötterna" never matches — CONFIRMED missing from the current suffix-stripping list), (b) trailing-space misses ("halloumi ost "), (c) "och"-conjunction lines not split ("salt och peppar"). (BUT-1496)
  - Acceptance: "morötterna" resolves to the same ingredient as "morot" · a trailing-space input no longer misses a lookup that would otherwise hit · "salt och peppar"-style lines split into separate matchable ingredients · don't touch the unrelated existing plural rules (or/ar/er/n/en/et) — only add the missing cases
  - Stakeholders: full-panel (Data/ML high-stakes hit + FinOps/Legal/Privacy/PM/Security/Architect core) — requiresPlanMode: **true**

### Agent C: tagging-pipeline-cleanup — TagGenerator lifecycle + dead orchestrator
- [ ] **C1. Rebuild `TagGenerator` when remote config loads late** `[Tier A]` — `lib/services/tagging/tag_generator.dart`: constructed once from `configOrNull`; a slow/failed config fetch pins the whole session to static fallback rules even after the real config arrives. (BUT-1483)
  - Acceptance: a session that starts with a slow/failed config fetch picks up the real config once it arrives (no permanent pin to fallback) · existing fast-path (config already loaded) behavior unchanged
- [ ] **C2. Delete `TagGenerator.generate()` dead orchestrator** `[Tier A]` — `lib/services/tagging/tag_generator.dart`: ~175-line dead duplicate orchestrator (confirmed: no non-test callers); `test/unit/services/tagging/tag_generator_test.dart` pins it 142×. Re-home phase tests onto the phase calculators / `TaggingPipelineRunner`. (BUT-1481)
  - Acceptance: `TagGenerator.generate()` is deleted · the 142 pinned test assertions are re-homed onto phase calculators/`TaggingPipelineRunner`, not just deleted (no net coverage loss) · production tagging behavior is unchanged (only the dead duplicate path is removed)
  - Do C1 before C2 in the same file (sequential within this agent, not parallel).

### Agent D: import-tagging-dead-code — misc cleanup
- [ ] **D1. Remove/wire three dead-code items** `[Tier A]` — `lib/services/import/file_import_strategy.dart` (`FileImportStrategy` unreachable in the `autoImport` loop — either wire it in or delete it), `lib/services/extraction/extractors/instagram_content_extractor.dart` (`extractWithResult` dead), `lib/services/tagging/ingredient_categorizer.dart` (mis-homed under `tagging/` — relocate to its correct home). (BUT-1487)
  - Acceptance: each of the three items is either wired to a real caller or deleted, with a one-line note on which choice was made and why · `ingredient_categorizer.dart` moves out of `tagging/` with all imports updated · `dart analyze` clean after the move

### Agent E: backend-cost-guardrails — LLM cap + parse_events TTL + pricing check
- [ ] **E1. Add a per-user daily LLM call cap** `[Tier A]` — `functions/src/middleware/rate_limiter.ts`: today's server-side ceiling is per-minute-per-user only (theoretical ~4.3k calls/user/day) plus a separate GLOBAL aggregate daily/hourly cap (`checkGlobalLimit`, confirmed system-wide not per-user) — there is no per-user daily counter. Add one inside the existing per-user rate-limiter transaction (mirror the existing hourly/daily pattern already used for the global limit). (BUT-1477)
  - Acceptance: a per-user daily counter exists in the rate-limiter transaction, distinct from the existing global aggregate cap · exceeding it denies further LLM calls for that user until the day rolls over (UTC) · existing per-minute and global-aggregate behavior unchanged
- [ ] **E2. TTL on `parse_events`** `[Tier A]` — `functions/src/events/log-parse-event.ts` (+ wherever the existing `llm_response_samples` TTL is declared, to mirror it): `parse_events` grows unbounded, one doc per import attempt, storing raw userId+URL forever (a quiet GDPR surface). (BUT-1478)
  - Acceptance: `parse_events` docs carry a TTL field/policy mirroring `llm_response_samples` · existing 30-day-style expiry pattern reused, not reinvented · no change to what gets logged, only to its retention
- [ ] **E3. Confirm Gemini pricing constants** `[Tier A]` — `functions/src/llm/gemini-client.ts:833`: two unverified pricing constants feed all cost telemetry and spend ceilings (BUT-1187 TODO). Verify against current published Gemini pricing (web/Context7) and correct if drifted. (BUT-1479)
  - Acceptance: the two constants are checked against a cited current Gemini pricing source · if unchanged, the ticket closes with the citation recorded in the commit; if drifted, the constants are corrected and the delta is called out in the commit message
  - Stakeholders: full-panel (parse_events is a high-stakes hit; FinOps/Legal/Privacy/PM/Security/Architect core) — requiresPlanMode: **true** for E1–E3 as a group.

### Agent F: social-recipe-sharing — non-atomic share write (build-review)
- [ ] **F1. Make `shareRecipeWithUsers`'s two writes safe against partial failure** `[Tier B]` — `lib/services/unified/modules/social_recipe/social_recipe_sharing_service.dart:50-183`: confirmed live — on secondary `shared_recipes` write failure, the method deliberately `return`s `true` (BUT-1131 comment: "rules-based access works without the secondary doc; it's only a query-optimisation"). BUT-1503 argues this is still user-visible as "my friend never got the recipe" and asks for an atomic write or self-heal. **This revisits a previous deliberate call (BUT-1131)** — build the narrower, safer half only: make the two writes atomic (WriteBatch) OR add a retry/self-heal on the secondary write, and surface a clear error to the user when both fail. Do **NOT** build the ticket's second ask ("decide one canonical share model and converge") — that's a separate, larger architecture decision (the two-share-models divergence is a known tracked fragility, see memory `reference_recipe_share_two_paths`) and belongs in its own plan, not this fix. (BUT-1503)
  - Acceptance: the primary recipe-permission write and the secondary `shared_recipes` write either both succeed or the failure is surfaced (no more silent `return true` on secondary-write failure) · the fix does NOT attempt to merge/converge `SocialRecipeOperations.shareRecipe`'s separate collaborative-doc model — that stays out of scope · a test drives a forced secondary-write failure and asserts the caller can tell it happened
  - Stakeholders: Software Architect, Product Manager (single tier, High priority) — requiresPlanMode: **true**
  - signoffReason: this reopens a documented BUT-1131 trade-off (return-true-on-secondary-failure was deliberate); Malin should confirm the new failure-surfacing behavior (hard fail vs. retry-and-warn) matches what she wants users to see, before this closes to Done instead of parking In Review.

### Needs you (Tier D — flagged, not worked)
- None this sprint — all 10 selected tickets are buildable now (no ops/deploy/external-account blockers).

### Post-Sprint Steps
- [ ] Run `dart analyze --fatal-infos` (Dart-touching batches: A, C, D)
- [ ] Run `npm run build` / relevant `functions` tests (TS-touching batches: B1, E)
- [ ] Run relevant unit tests per batch
- [ ] Commit, push (direct to main per solo workflow)
- [ ] Update Linear ticket states (Done for Tier A; In Review + notify for Tier B — Agent F)

## Deviation log
- [discovery] Six tickets originally shortlisted from the 2026-07-04 "28-role org-scan" batch
  (BUT-1529, BUT-1530, BUT-1532, BUT-1534, BUT-1535, BUT-1537) turned out to be already-fixed
  false positives on direct code verification — see `obsolete` in the structured plan output for
  per-ticket evidence (commit hashes / blame dates, all predating the tickets' filing). Swapped
  them for pipeline-audit-sourced tickets (verified against current code this session). Flagging
  for a follow-up bulk-triage of the rest of that scan batch — see needsApproval.
- [deviation] BUT-1529 ("solo weekly-menu includes untagged recipes") was also checked and found
  already fixed by the BUT-1464 unification commit (`820e89b76`) two days before BUT-1529 was
  filed — not swapped in, dropped from selection entirely (see obsolete).

---

# ARCHIVE — prior sprint (pooled-ratings v1, shipped)

## Implementation plan — Pooled ratings v1: the aggregation pipeline

**Status: SHIPPED.** Increments 1–6 (Stage A mirror CF, Stage B pool aggregator, rules,
GDPR export/deletion coverage, client display) plus backfill CF (hard-gated, not run) are all
committed on `claude/pooled-ratings-v1` per `memory/project_pooled_ratings.md`. Flag OFF in
prod — deploy-only remaining. Content below kept as the historical build record.

**Scope:** build the live "Butlery-betyget" pipeline specified in `tasks/pooled-ratings-plan.md`
(decisions 2,4,5,6,7,8,9,10,11,12,13,15). The **key-design (C1–C5) foundation is already
shipped** on `claude/pooled-ratings-v1`. This plan turns the panel-approved architecture into a
sequenced, per-increment-gated build. **The v1 architecture was already full-panel reviewed
(2026-07-02, 12 roles, approve-with-conditions); its conditions are the acceptance criteria below.**
But panel sign-off on the *architecture* is NOT the same as the build-go: `pooled-ratings-plan.md`
says "AWAITING MALIN'S APPROVAL — build nothing until she says go," each step needing its own go.
**This plan requests that go.** On approval I implement per-increment (not re-deciding the
architecture — CLAUDE.md rule #5); the commit-gate specialists review each increment's diff.

**Every increment, before its commit:** `dart analyze --fatal-infos` (Dart) / `npm run build`
(`tsc`) clean + named tests green + the listed specialist gate. Not implied by "Gate:" — run and
report each. If an increment edits code the workflow-map covers (recipe-write / rating-display
flows), re-trace the flagged flows and clear `docs/onboarding/workflow-map.stale` in the same
commit (CLAUDE.md).

**Grounding (from precedent maps, 2026-07-03):**
- 'alla' ratings write to `recipe_ratings/{recipeId}_{userId}`; family ratings to the separate
  `family_ratings` collection → structural family exclusion = trigger only on `recipe_ratings`
  (decision 7). ✓
- Eligibility today: `recipe_ratings` create gates on `isAgeCompliant()` **only** (not maturity),
  in firestore.rules. So the **account-maturity gate (decision 7) must be enforced inside the
  mirror CF** (age is already guaranteed by the source doc existing).
- The existing recipe/family aggregation is **read-all-then-recompute** (folds every rating in
  memory). Decision 5 **forbids porting that** for pools (unbounded cardinality) → use a
  **collectionGroup aggregate query**.
- Debounce marker module lives in `functions/src/ratings/rating-aggregation.ts`
  (`_internal/rating_debounce/markers`, keyed by recipeId). Decision 5: **generalize it, don't
  fork.**
- Feature flags: Remote Config, read client-side via `FeatureFlagService.isEnabled` and
  server-side via the `functions/src/shared/notification-rc-flags.ts` pattern (RC template +
  5-min cache + fail-open). No generic Firestore mirror — use RC on both sides.
- Optional `String?` model fields: follow `sourceUrl` in `recipe_unified.dart` (6 sites, sentinel
  copyWith, `safeNullableString`); nullable add is backward-safe, no migration.
- GDPR: cascade `subs` array (`account-deletion-cascade.ts:748`), subcollection-shaped residual
  probe (NOT the top-level `where userId` array), `DataExportService` (manager + repo query +
  `FirestoreCollections` const + `ExportResourceType` enum + the `'should include all required
  sections'` test). No automated export⊇erased test — update the Dart assertion by hand.
- rules precedents: `recipe_social_stats` (read auth / writes false, line 2394) for the stats doc;
  synthesize owner-read + writes-false for the events subcollection (acquisition + stats blocks).
  Rules-test harness = `recipe-ratings-rules.test.ts` shape; register in `test:rules:all` +
  `.github/workflows/firestore-rules.yml`.

---

## Increment 1 — Generalize the debounce/marker module (foundation; touches LIVE code)
**Goal:** one generic debounce used by BOTH the existing rating aggregation and the new pool
aggregator (decision 5: "don't fork a second copy").
- Extract `scheduleAggregation(namespace, key, deps)` + `drainAggregationQueue(namespace,
  drainFn, deps)` from `rating-aggregation.ts` — parameterize the marker collection path by
  `namespace` and rename `recipeId`→`key`. Keep the transaction coalesce + delete-then-drain
  claim logic verbatim.
- Rewire existing recipe/family aggregation to call it with `namespace='rating', key=recipeId`.
- **Behavior-preserving:** `npm run test:rating-aggregation` (existing) stays green unmodified —
  it is the regression guard for the live family/recipe path.
- **Gate:** cloud-functions-specialist. **Risk:** live aggregation — do not change timing/shape.

## Increment 2 — Stage A: server-authoritative mirror CF + event store (decisions 2,4,7)
**Goal:** every eligible 'alla' rating produces one frozen pool event; the key is recomputed
server-side (never trust a client field — pool-poisoning defense).
- New `functions/src/ratings/canonical-rating-aggregation.ts`: `onDocumentWritten
  recipe_ratings/{ratingId}` (create/update/delete).
- On write: read `recipes/{recipeId}` (the rater's own copy) → extract title + flat ingredient
  strings → `computePoolKey(title, ingredients)` (the TS authority). Null (fail-closed) → no
  event.
- **Maturity gate (decision 7):** skip unless the account is matured (`admin.auth().getUser` →
  emailVerified OR account age ≥ `kAccountMaturityWindow` 60min). Age already guaranteed.
- Upsert `users/{uid}/canonical_rating_events/{poolKey}` = `{poolKey, ratingValue, recipeId,
  createdAt}` (doc-ID = poolKey ⇒ one vote per uid per pool, frozen key). On rating delete →
  delete the event (only if no other rated copy maps to the same pool for this uid).
- **Feature-flag gated:** flag off ⇒ CF no-ops (writes no events). Kill switch (decision 11).
- **Tests** (`ts-node` unit): AC2 tampered client key can't route (server recomputes); AC3 one
  vote per uid regardless of copy count; AC6 family rating never reaches the pool (structural);
  maturity gate rejects an immature account.
- **Gate:** cloud-functions-specialist. Confirm the recipe Firestore field names for title +
  flat ingredients at build (small read).

## Increment 3 — Stage B: pool aggregator + stats doc (decision 5 — the crux)
**Goal:** maintain `canonical_recipe_stats/{poolKey}` in O(1)-per-event, never read-all.
- `onDocumentWritten users/{uid}/canonical_rating_events/{poolKey}` → `scheduleAggregation('pool',
  poolKey, deps)` (generalized debounce from incr 1).
- Drain: for each pending poolKey, `db.collectionGroup('canonical_rating_events')
  .where('poolKey','==',key)` → `.count()` + `.average('ratingValue')` (Firestore aggregate
  queries) → write `canonical_recipe_stats/{poolKey} = {count, average, updatedAt}`.
- **Build-time verify** the pinned `firebase-admin` supports `.average()`; if only `.count()`,
  compute average via `.sum('ratingValue')/count` (still an aggregate query, decision-5 OK) —
  never fold-all-in-memory.
- Add the collectionGroup index (`canonical_rating_events`, `poolKey`) to
  `firestore.indexes.json`; enabling it is an explicit deploy step (decision 14).
- **Tests:** AC5 — assert the drain path issues an aggregate query and does NOT read all docs
  into memory (no `.get()` fold over the pool); stats correctness for a small pool.
- **Gate:** cloud-functions-specialist.

## Increment 4 — firestore.rules + rules tests (decision 10)
- `canonical_recipe_stats/{poolKey}`: `read: isAuthenticated(); create,update,delete: false`
  (server-only) — after `recipe_social_stats` (line 2394).
- `users/{uid}/canonical_rating_events/{poolKey}`: `read: isAuthenticated() && auth.uid==uid;
  create,update,delete: false` (CF-only) — after the user subcollections (line 1925). Update the
  header index comment.
- New `functions/src/__tests__/canonical-stats-rules.test.ts` (mirror `recipe-ratings-rules`
  harness): owner reads own events / stranger denied; all client writes to both denied; any
  auth'd user reads stats. Register in `test:rules:all` + both path lists of
  `firestore-rules.yml`.
- **Gate:** firestore-rules-tester (emulator-proven, AC9).

## Increment 5 — GDPR same-PR coverage (decision 12) — MUST land before the flag ever turns on
- Deletion: add `"canonical_rating_events"` to the `subs` array
  (`account-deletion-cascade.ts:748`). Cascade delete of events fires the Stage-B trigger →
  affected pools recompute (no explicit recompute call — established separation).
- Residual probe: add a **subcollection-shaped** block
  (`db.collection('users').doc(uid).collection('canonical_rating_events').count()`), not a
  top-level `where userId` entry.
- Export: `DataExportService` new manager method + repo query
  (`.collection('canonical_rating_events')`) + `FirestoreCollections` const + `ExportResourceType`
  enum; extend the `'should include all required sections'` test (BUT-1450 export⊇erased,
  hand-maintained).
- **Pseudonymous, not anonymous** (decision 12 note) — never label the events store anonymous.
- **Gate:** firebase-backend-security + cloud-functions-specialist (AC8 emulator: delete user →
  pool recomputed, no orphan events). **Flag stays OFF in prod until incr 1–5 are all merged** —
  this satisfies decision-12's same-PR intent (no un-erasable data created before erasure exists).

## Increment 6 — DESIGN APPROVED (Malin 2026-07-03): green + slate two-pill scheme
Visual preview approved (`docs/design/previews/butlery-betyget-pill-preview.html`):
- **Community "Butlery-betyget" pill** = filled **brand green** square pill, star +
  score + vote count (`★ 4.3 · 12 betyg`). It's the flagship number, so it keeps
  green. Shown only at n ≥ 5, always with the count.
- **Personal / household ("alla i ditt kök") pill** = quiet **neutral slate** square
  pill (`★ 4.0`, no count) — moved OFF green so the two read apart instantly by hue
  (supersedes the old "rating badge stays green" default for the per-copy number; the
  community pill now owns green). Slate ≈ `rgba(44,44,44,.06)` bg / `#3A3A3A` text /
  `--cream-darker` border / grey star.
- Cards: community pill REPLACES the per-copy star when n ≥ 5; below floor / loading /
  offline / missing → the slate personal pill (never a blank pill). Detail page shows
  BOTH, labelled ("butlery-betyget" tinted-green panel leads; "alla i ditt kök" slate
  as context). Square everywhere, butler-voice Swedish, no exclamation marks.

## Increment 6 — IN PROGRESS (2026-07-04) — executing the approved plan in 2 slices
Design approved (green + slate, above). Implementing per this plan (no re-decide):

**Slice 6a — data foundation (backend-ish, unit-testable, no visual):**
1. `FirestoreCollections.canonicalRecipeStats = 'canonical_recipe_stats'` ✓
2. `RatingsRepository.getPooledStats(poolKey)` + `PooledStats {count, average?}` with
   `displayFloor=5` / `meetsDisplayFloor` (interface + FirebaseRatingsRepository, raw-doc
   read of `canonical_recipe_stats/{poolKey}`, any-authed read) ✓
3. `RecipeCore.ratingPoolKey` (String?) — mirror `sourceUrl` at its 6 sites (field,
   ctor, copyWith sentinel, toJson, toFirestore, fromJson, fromMap). Nullable +
   backward-safe, NO schemaVersion bump (lazy-compat).
4. Compute the hint on save via `CanonicalPoolKey.compute(title, ingredients)` in the
   personal-recipe create/update path (first production call site).
5. `FeatureFlags.enablePooledRatings = 'enable_pooled_ratings'` + default false.
6. Unit tests: getPooledStats (null when absent, parses count/avg, floor logic);
   ratingPoolKey round-trips through toMap/fromMap.
- Gate: firebase-backend-security + code-reviewer + testing-specialist.

**Slice 6b — UI (the visible pills):**
7. Card: new green "Butlery-betyget" pill (`★ 4.3 · 12 betyg`) shown at n≥5, replacing
   the per-copy star; demote the existing "alla" pill to slate. Pool stats fetched via a
   `RecipeListViewModel` cache (mirror the `pantryMatches` map + `RecipeCard` param).
8. Detail: add both pills labelled (butlery-betyget tinted-green leads; "alla i ditt kök"
   slate as context) — async fetch mirroring `_checkUserRating()`.
9. l10n: SV(source)+EN ARB keys (`pooledRatingPill`, `pooledRatingCount "{count} betyg"`,
   a11y variants); `flutter gen-l10n`.
10. Feature-flag gated display + analytics `pool_rating_shown`/`pool_rating_contributed`.
11. Widget test (AC7): pill absent <5, shows count at ≥5, per-copy fallback intact,
    offline→fallback, never a blank pill.
- Gate: flutter-developer/uiux-designer + code-reviewer + testing-specialist.

Flag OFF in prod throughout. No existing rating data mutated.

## Increment 6 — Client hint + display + telemetry (decisions 8,9,15)
- `RecipeCore.ratingPoolKey` (String?) mirroring `sourceUrl` (6 sites); compute the hint on save
  via `CanonicalPoolKey.compute` (display/index only — server stays authoritative).
- **Read layer (named):** add a lightweight `canonical_recipe_stats/{poolKey}` read to the
  existing ratings repository (`FirebaseRatingsRepository`, `PermissionValidationMixin` already
  present) — a `getPooledStats(poolKey)` returning `{average, count}` — surfaced through the
  recipe-detail/card ViewModel that already exposes `averageRating`. No new repository/service.
- Butlery-betyget pill: render pooled average + count only at **n ≥ 5** (decision 8), **instead
  of** the per-copy 'alla' aggregate on cards when the floor is met; detail view may show both,
  labelled; per-copy `averageRating` stays as fallback (decision 9). Butler-voice copy, **square**
  design (memory UI prefs — no rounded edges), green pill (memory: keep green, not gold).
- **Pill states:** loading → show per-copy fallback (no spinner flash); pool < 5 or stat missing
  → per-copy fallback (pill absent); offline/error → per-copy fallback; success (n≥5) → pooled
  pill + count. Never a bare/empty pill.
- **l10n:** add SV+EN ARB keys (e.g. `pooledRatingCount` "{count} betyg" / "{count} ratings")
  following butler-voice (no exclamation). Swedish is source-of-truth.
- **Feature-flag gated display** (decision 11); analytics `pool_rating_shown` /
  `pool_rating_contributed` (decision 15).
- **Tests:** AC7 widget — pill absent below n=5, shows count at ≥5, per-copy fallback intact;
  offline → fallback.
- **Gate:** flutter-developer/uiux-designer + code-reviewer + testing-specialist.
- **Visual preview:** HTML preview of the pill (card + detail) before Flutter, per
  `.claude/rules/html-previews.md`. ASCII sketch (card row):
  ```
  ┌───────────────────────────────────────────┐
  │ [img] köttbullar          ★ 4.3 · 12 betyg│   ← pooled pill (n≥5), replaces per-copy
  │       25 min · lagat idag                  │
  └───────────────────────────────────────────┘
  pool < 5  →  ★ 4.0   (per-copy 'alla' average, no count pill — current behaviour)
  ```

## Increment 7 — REMOVED (Malin 2026-07-03: no edit-triggered detachment)
Ratings are frozen to the pool of the dish they judged; editing a recipe never moves or removes
a past rating (pure decision 4). No recipe-write detachment trigger, no stats delta on edit, no
one-time notice. Re-rating the edited recipe pools that fresh rating to the new dish via Stage A.
Recorded in `pooled-ratings-plan.md` decision 6 (superseded) + AC4 + `accepted-deviations.md`.
**Net effect: the intricate increment is deleted — buildable set is now 1–6.**

## Increment 8 — Backfill CF (decision 14) — WRITTEN, HARD-GATED, DOES NOT RUN
- Server-derives all keys from content; batched + throttled + explicit batch size + cost
  estimate + dry-run + mid-run abort; delete-after-completion+30-day-soak header marker; admin
  runbook (look up a poolKey, list member recipes, split a bad merge) BEFORE it runs.
- **Hard gate (do NOT run until, all of):** C6/C7/C8 real-corpus re-measurement (≥20–30 scans,
  0 false merges) + privacy policy EN/SV pooling disclosure live + LIA/DPIA note + Art.30 entry
  (decision 12 d/e/f). These are Malin/legal + real-scans items — **not buildable now.**

---

## Surfaced to Malin (decisions needed / not buried)
1. **Detachment semantics (incr 7):** confirm my reading — key-changing edit removes the user's
   contribution from the old pool, does not auto-re-add to the new pool. (Alternative: re-mirror
   into the new pool if the copy is still rated. I recommend the simpler remove-only for v1.)
2. **BUT-417 moderation SLA gap:** v1 is numbers-only (no UGC), so this is NOT a v1 blocker —
   it becomes blocking at v2 (comments). Flagging only so the deferral is explicit.
3. **Backfill + legal (incr 8):** cannot run until real cookbook scans exist AND the privacy
   policy is updated. Timing is your call. Everything else (incr 1–7) ships behind an OFF flag
   and touches no existing rating data.
4. **v1.1 menu-weighting Linear ticket:** PM condition — file at approval so it doesn't rot
   (the real product payoff; v1 alone is display-only).
5. **Display floor n=5:** decided, trivially tunable — say the word to change.

## Increment 2 — DONE (Stage A committed 2026-07-03) — all review findings resolved
Stage A shipped after a hard review cycle: the `cloud-functions-specialist` gate passed but a
`/code-review xhigh` found **12 issues incl. a dead-on-arrival showstopper**; the rework fixed
all 12, a second xhigh found **8 more (incl. a critical kill-switch precedence bug I introduced)**,
those were fixed, and a focused delta-check came back clean. Final: 18/18 mirror + 4/4 flag-module
+ 5/5 regression tests green. The two xhigh passes are why nothing broken reached a commit. The
finding history below is kept as a record; every item is addressed in the committed code.

**Showstopper**
1. **Wrong recipe path (DOA).** Reads top-level `recipes/{recipeId}` which does not exist —
   recipes are user-scoped `users/{ownerUid}/recipes/{recipeId}` (rules line ~337 nested-only;
   `UserScopedFirebaseRepository`). `recipe_ratings` carries no owner uid (only
   `recipeId,userId,rating,review,createdAt,updatedAt`). **Fix:** read
   `users/{userId}/recipes/{recipeId}` (rater's own copy = the pooled model's primary case).
   Friend-recipe ratings w/o an own copy → `skipped_no_recipe` (v1 pools own copies; note it).
   **Fix the tests too:** `seedRecipe` must write the user-scoped path or the bug stays invisible.

**High (data-integrity)**
2. **Retraction wipes a still-live vote.** delete-by-`recipeId` on a shared poolKey doc removes a
   vote another still-rated copy backs. **Fix:** on delete, recompute K from
   `users/{uid}/recipes/{recipeId}`, delete `…/canonical_rating_events/{K}` iff its `recipeId`===
   the deleted recipe; fall back to where-recipeId only if the recipe is gone. (Rare two-own-copies
   edge stays — document it.)
3. **No CF retry.** `onDocumentWritten` defaults `retry=false`; the `throw` is dropped. **Fix:**
   register with `{ retry: true }` (returns don't retry, so flag/immature/no-recipe paths are safe).
4. **`isAccountMatured` swallows transient auth errors → permanent vote loss.** **Fix:** in catch,
   `throw` on transient errors (→ retry); return false only for terminal `auth/user-not-found`.
5. **`skipped_unchanged` runs before the maturity gate** (a bug I ADDED this turn): an
   immature-time rating never pools even after the account matures. **Fix:** remove the
   value-equality gate entirely — always run maturity→recompute→upsert on create/update (recipe
   edits don't fire this trigger, so the incidental-re-pool corner the specialist worried about is
   negligible; the gate's cost is not worth reintroducing #5).
6. **Kill-switch gates the delete branch → flag-off orphans retractions.** **Fix:** flag-gate only
   create/update; deletes/retractions ALWAYS run (like the existing `onRatingDeleted`).
7. **RC blip caches disabled for the full 5-min TTL** (`pooled-ratings-flag.ts`). **Fix:** on
   loader error return false WITHOUT caching (or a short negative TTL), so the next call retries RC.

**Medium / Low**
8. NaN rating passes `<1||>5` (both false for NaN) → `ratingValue:NaN`. **Fix:** add
   `!Number.isInteger(rating)` to the guard (defense-in-depth; rules also reject NaN today).
9. Flag reader ignores RC conditional/percentage values (reads only `defaultValue.value`), can
   diverge from the client. **Fix (v1):** document "roll this flag out via defaultValue only, no RC
   conditions," or use `getServerTemplate().evaluate()`. v1 = simple on/off, defaultValue is fine.
10. Maturity `getUser` runs per-write. **Fix:** in-isolate `Set<uid>` memo of matured uids.
11. AC6 test is tautological (asserts a const equals its own literal). **Fix:** read `index.ts`
    source and assert the trigger binds a `recipe_ratings` path (real wiring guard).
12. Third hand-rolled RC reader (dup of notification-rc-flags + prompts-config). **DEFER** —
    extracting `shared/rc-boolean-flag.ts(key,{failMode})` touches 3 modules; out of scope here.

Recorded: `cloud-functions-specialist.knowledge.md` (2026-07-03 correction), `tasks/lessons.md`.

## Increment 3 — DONE (Stage B committed 2026-07-03)
Pool aggregator shipped: `update-pooled-rating-stats.ts` runs ONE Firestore
aggregate query (`collectionGroup(canonical_rating_events).where(poolKey==)
.aggregate({count, average(ratingValue)})`) → `canonical_recipe_stats/{poolKey}`
— decision 5's no-read-all invariant holds in the real code (O(1) memory). Debounce
reuses `shared/debounce-queue.ts` via `pool-aggregation.ts` (POOL_DEBOUNCE, separate
`_internal/pool_debounce/markers` namespace — no fork). `index.ts` wires the event
trigger `users/{uid}/canonical_rating_events/{poolKey}` (retry:true) + a 1-min drain
scheduler passing the real aggregator. cloud-functions-specialist gate: clean. A
focused adversarial review then caught a **test-hidden ship-blocker**: the
`average("ratingValue")` aggregate needs a COMPOSITE collection-group index
`(poolKey, ratingValue)`, not the single-field poolKey index first written — a
single-field index serves count() but makes average() throw FAILED_PRECONDITION in
prod (the in-memory test fake models data, not the index layer, so it stayed green).
Fixed to the composite; added `requiredCompositeIndexDeclared` test that asserts the
index config matches the aggregate's needs; recorded in `tasks/lessons.md`. Final:
9/9 Stage B + 18/18 Stage A + 5/5 shared-debounce + 4/4 flag green. Index enablement
remains an explicit deploy step (decision 14); feature flag OFF in prod throughout.

## Increment 4 — DONE (rules + rules tests committed 2026-07-03)
firestore.rules gained two server-authoritative matches (decision 10):
`users/{uid}/canonical_rating_events/{poolKey}` (owner-only read, all client writes
denied — CF-only) and `canonical_recipe_stats/{poolKey}` (any-authed read, all client
writes denied — mirrors recipe_social_stats). COLLECTION INVENTORY header updated. New
`canonical-stats-rules.test.ts` registered in package.json (`test:rules:canonical-stats`
+ `test:rules:all`) and both path lists of `.github/workflows/firestore-rules.yml`.
firestore-rules-tester gate: proven on the real emulator, 12/12 (it added an
unauthenticated-events-read deny + a collection-group leak guard, and independently
confirmed no broader rule unions in a client write — union-safety holds). No production
CF logic changed this increment.

## Increment 5 — DONE (GDPR same-PR coverage committed 2026-07-03)
The pooled-rating events store is now covered by deletion + export in the same
branch as the write path (decision 12), so no un-erasable data can exist before
erasure does. Three parts:
- **Deletion:** `canonical_rating_events` added to the deleteUserSubcollections
  `subs` array (account-deletion-cascade.ts). Each event delete fires the Stage-B
  trigger → the pools the user contributed to recompute (no explicit call).
- **Residual probe:** a subcollection-shaped `.count()` block (NOT a top-level
  `where('userId'==)` which would silently match zero) — a leftover pushes
  `residual_data_detected` into failedCollections (fail-closed).
- **Export:** new `exportCanonicalRatingEvents` repo method (routes through the
  `_guardSelfExport` ownership check) + `ActivityExportManager.exportPooledRatingEvents`
  + `FirestoreCollections.canonicalRatingEvents` const + `ExportResourceType`
  enum value + pagination limit; wired into the export fan-out as
  `pooled_rating_events`. Section is ALWAYS present (Art. 15 holds for a user with
  none). Labelled **pseudonymous, never anonymous** (decision 12 / Breyer).
Gates all clean: firebase-backend-security + cloud-functions-specialist (the
plan-designated pair) + code-reviewer + testing-specialist. Emulator: account
deletion 44/44 (target's events erased, another user's retained, residual clean);
Dart export suite 33/33 (incl. a data-flow test proving a seeded event reaches the
export, not just section presence). Flag stays OFF in prod until incr 1–5 merged.

## Sequencing & safety
Build order 1→2→3→4→5 (pipeline + rules + GDPR) with the **feature flag OFF in prod throughout**;
then 6 (client display) still behind the flag; then 7 (detachment). 8 stays dormant until its
legal/real-corpus gates clear. Each increment is one commit, individually gated by its
specialist(s). No existing rating data is mutated; flag-off = feature fully dark.

## What this means in plain language
- We're building the machine that gathers everyone's private star-ratings of the *same* recipe
  into one shared "Butlery-betyg," **without touching anything that works today** and with the
  whole thing switched **off** until it's finished and checked.
- It works in two steps behind the scenes: when you rate a recipe, the server quietly files an
  anonymous "one vote" slip for that dish; a second job adds those slips up into a shared score.
  The score only ever appears once **at least five different people** have rated the dish, and it
  always shows the number of votes.
- **Your family's private ratings never go into it** — they live in a completely separate place,
  so there's no way for them to leak in.
- If you **edit** a recipe enough to make it a different dish, your vote leaves the old dish's
  score (you can't pad a score by tweaking a recipe). I've written down how I think that should
  behave and flagged it for you to confirm.
- Everything a person contributes is included in their data download and erased when they delete
  their account — built in from the start, not bolted on.
- Two things wait for you: turning old existing ratings into shared scores (that needs the
  privacy policy updated first and real recipe scans to prove the matching is safe), and the
  weekly-menu using these scores (the real payoff — I'll file it as its own task).
- **Risk:** low. It's all new, additive, behind an off-switch; removing it is just flipping the
  switch and dropping two new data piles. Nothing existing changes.
</content>
