# Sprint Backlog

## Plan: Pooled ratings via canonical recipe identity ("Butlery-betyget") — 2026-07-02

**Status: AWAITING MALIN'S APPROVAL — do not implement until she says go.**

Origin: Malin's insight that Swedish recipes come from a limited source pool, so many users
hold the same recipe (imported via different methods), and their ratings should pool — valid
per content version (bönor→linser = a different recipe). Research confirmed the pattern:
Samsung Food removes ratings from tweaked copies ("no longer the same recipe"); Goodreads
pools editions under a "work"; Vivino uses display thresholds. V1 shares ONLY numbers keyed
by a content hash — **no recipe content is shared** (keeps EU database-right/copyright
questions out of scope; those belong to the separate, later "canonical recipe bank" decision).

Panel: **full-panel, 12 roles, 12× approve-with-conditions, 0 blocks.** One conflict resolved
by CTO priority order → **ADR-0004** (event storage shape). All conditions below are binding.

### Step 0 — GATE: offline hit-rate measurement (Data/Integrations condition; build nothing before this)
- Deterministic script (`tools/measure_poolkey_hitrate.dart`, no LLM): compute the proposed
  poolKey for known same-recipe pairs across import methods (URL vs OCR vs Instagram samples;
  reuse corpus fixtures + a hand-built sample set) and report exact-match collision rate.
- **Gate:** if cross-method (OCR/Instagram↔URL) hit-rate is near zero, extend normalization
  for OCR noise (å/ä/ö misreads, digit/letter confusion) and Instagram caption junk (emoji,
  hashtags) and re-measure BEFORE any CF/rules/backfill work. URL↔URL pooling alone still
  justifies v1 — but report the measured number to Malin either way.
- Known pipeline reality (RECIPE_PIPELINE.md): photo/OCR uses TextImportStrategy's regex
  parser, not the URL cascade — ingredient-string shape differs structurally. Do not assume
  the schema.org-oriented normalizer transfers.

### Architecture (panel-resolved decisions)
1. **Identity:** `ratingPoolKey`, versioned (`v1:` prefix baked into the key string, following
   the kTagGeneratorVersion precedent). Derived from title keywords + normalized ingredient
   NAMES (amounts stripped; instructionCount deliberately EXCLUDED — unlike the cache
   fingerprint). Exact match in v1; fuzzy (MinHash/LSH) is v2 and would be a new vendor/infra
   decision (Vendor flag) — never slide it in silently.
2. **Server is authoritative for the key (Security, hard condition):** the aggregation CF and
   backfill CF **recompute the poolKey server-side (TS) from recipe content** — a
   client-written key field is never trusted for pool routing (pool-poisoning vector on a
   public reputation signal). Client Dart computation exists only as a display/index hint.
   Cross-language golden-fixture test (same inputs → identical keys in Dart and TS) in CI.
3. **Normalization sharing (Software Architect + Data/Integrations):** extract
   `ContentFingerprint`'s private normalization into a standalone, independently-tested
   utility used by BOTH ContentFingerprint and the new CanonicalPoolKey — extraction-only,
   zero algorithmic change, all existing content_fingerprint tests stay green unmodified
   (regression guard for the live GlobalRecipeCache dedup hit rate). Later poolKey-motivated
   normalizer changes must NOT silently change cache fingerprints — the two consumers pin
   their behavior with separate golden tests.
4. **Event storage (ADR-0004):** `users/{uid}/canonical_rating_events/{poolKey}` — doc-ID
   upsert = free one-vote-per-uid-per-pool dedupe; **poolKey frozen at write time** (a rating
   belongs to the version it judged; an edit never reclassifies past ratings); deletion
   cascade reuses the existing per-user subcollection pattern. NOT a field on recipe_ratings.
5. **Aggregation (FinOps + DBA, hard condition):** `canonical_recipe_stats/{poolKey}` is
   maintained via **Firestore aggregate queries (count/sum/average, supported in the pinned
   firebase-admin) or transactional deltas — NEVER read-all-and-recompute** (pool cardinality
   is unbounded by design; the BUT-482 recount pattern must not be ported unchanged).
   Debounce: **generalize** rating-aggregation.ts's marker module to a generic key (explicit
   decision — don't fork a second copy of the debounce logic).
6. **Edit-triggered pool migration (Software Architect — the gap in the draft):** a recipe-
   write trigger detects poolKey change on the user's copy and removes the user's
   contribution from the old pool (stats delta), leaving the frozen event as history or
   tombstoning it — spec'd precisely in implementation. Same debounce marker pattern
   (Vendor condition: no new unthrottled trigger path). Plus a **one-time user-visible
   notice** when an edit detaches a recipe from its pool (Support condition — not silent).
7. **Eligibility gates (T&S + Security):** a rating counts toward the pool only if
   `isAgeCompliant()` AND `isAccountMatured()` (reuse kAccountMaturityWindow — no new
   mechanism). Family/household ratings are **structurally** excluded: the mirror CF reads
   only the 'alla' rating path, never family_ratings (code-level guarantee, reviewed by
   firebase-backend-security).
8. **Display floor (DPO k-anonymity + T&S/Security anti-gaming vs PM's keep-it-low):**
   pooled rating renders only at **n ≥ 5** distinct raters (constant, trivially tunable;
   satisfies DPO's ≥3 floor with margin, stays far under Vivino's 25 so the feature is
   visible early). Always shown WITH the count. Bayesian shrinkage (C≈10 phantom votes at
   the global mean) is for future ranking/menu use only — never for the displayed average.
9. **UI relationship to existing ratings (PM condition — resolved):** recipe cards show the
   pooled "Butlery-betyget" pill INSTEAD of the per-copy 'alla' aggregate when the pool
   meets the floor (per-copy `averageRating` remains as data and as fallback display);
   detail view may show both, clearly labeled. No fourth competing number on cards.
10. **firestore.rules:** `canonical_recipe_stats` mirrors the recipe_social_stats precedent
    exactly — read: authenticated; create/update/delete: false (server-only, with comment).
    `canonical_rating_events`: owner read (export/UI), all client writes denied (CF-only).
    Proven by firestore-rules-tester emulator tests, not asserted.
11. **Feature flag + kill switch (PM):** CF mirror step AND client display gated by a
    FeatureFlagService flag, consistent with existing rollout levers.
12. **GDPR (Legal + DPO, same-PR requirements):** (a) events subcollection added to the
    deletion cascade AND `probeResidualData` AND DataExportService **in the same PR** as the
    write path (export ⊇ erased, BUT-1450 invariant); (b) deletion recomputes affected pools;
    (c) retention: the event dies with the rating (no orphan log); (d) short DPIA-screening
    note + LIA (legitimate interest, Art. 6(1)(f)) in docs/legal/ following
    family-rating-dpia.md, covering the backfill's purpose-change over already-collected
    ratings (Art. 5(1)(b) + IMY stance check); (e) privacy policy EN/SV discloses the pooling
    purpose **BEFORE the backfill runs** — backfill is hard-gated on the policy being live;
    (f) Art. 30 record entry. NOTE (DPO): the uid+poolKey events store is **pseudonymous, not
    anonymous** (Breyer C-582/14 — the hash is reproducible from the shipped app); only the
    uid-free aggregate is anonymous. Never describe the events store as anonymous in any doc.
13. **Abuse surface (T&S):** report path for a pooled aggregate (reuse the report pipeline
    with poolKey standing in for contentOwnerId — one new report-reason enum) + admin
    visibility into per-poolKey rating velocity (spike detection). Accepted, documented side
    effect: editing a recipe resets its pool membership ("rating laundering") — legitimate
    recipe evolution outweighs it; user-level reports/strikes persist regardless.
14. **Backfill CF (DBA + Vendor + FinOps + Support):** server-derives all keys from content
    (never replays client fields); batched + throttled with explicit batch size, cost
    estimate (recipe count × writes), dry-run mode, and mid-run abort; file header carries
    the delete-after-completion+30-day-soak marker (backfill-recipe-comments-denorm.ts
    precedent); admin inspection runbook (look up a poolKey, list member recipes, split a
    bad merge) exists BEFORE backfill runs; any collectionGroup index enablement is an
    explicit deploy step in the runbook.
15. **Telemetry (PM + FinOps + Monetization):** analytics events `pool_rating_shown` /
    `pool_rating_contributed`; read-volume estimate for the detail-open stats read stated
    before ship; new read/write paths visible in cost monitoring (not blended).
16. **Product guardrails (Monetization):** Butlery-betyget stays fully free/ungated forever
    (consistent with decided FREE-to-user strategy); poolKey computation stays pure
    deterministic string processing — zero LLM, now and in follow-ups, without a new review.

### Fit check (identity approaches)
| Requirement | Exact content key | Fuzzy clusters (MinHash) | Source-URL identity |
|---|---|---|---|
| Matches across import methods (screenshot↔URL) | Y* | Y | N |
| No false merges (different recipes, one pool) | Y | N | Y |
| Zero new infra/vendor | Y | N | Y |
| Deterministic, server-recomputable | Y | N | Y |
| Edit naturally breaks identity (Malin's rule) | Y | N | N |

*gated by Step 0 measurement. Exact key wins (fewest fails); fuzzy is a v2 candidate.

### Files
1. `tools/measure_poolkey_hitrate.dart` — Step 0 gate script (disposable after decision).
2. `lib/services/import/cache/recipe_text_normalizer.dart` — extraction-only move of
   ContentFingerprint's normalization (+ its unit tests; existing tests untouched).
3. `lib/services/rating/canonical_pool_key.dart` — versioned key builder (display hint),
   DI-registered in the content module.
4. `functions/src/ratings/canonical-pool-key.ts` — TS twin + shared golden fixture JSON.
5. `functions/src/ratings/canonical-rating-aggregation.ts` — mirror CF (gates, frozen-key
   event upsert, delta/aggregate-query stats update, debounce reuse) + recipe-edit
   detachment trigger + backfill CF (separate file, soak-marked).
6. `functions/src/account/account-deletion-cascade.ts` + export service + probe array —
   same-PR GDPR coverage.
7. `firestore.rules` — two new blocks per decision 10.
8. `lib/models/recipe_unified.dart` — poolKey hint field; `lib/widgets/recipe/recipe_card.dart`
   + detail view — Butlery-betyget pill (floor n≥5, count always, butler-voice copy).
9. `assets/legal/privacy_policy_{en,sv}.md`, `docs/legal/pooled-ratings-lia.md`, Art. 30 record.
10. Tests: golden fixtures (Dart↔TS key parity), CF unit tests (dedupe, deltas, gates,
    detachment), rules emulator tests, GDPR cascade test, widget test for floor behavior.

### Acceptance criteria (binding, from panel conditions)
- AC1. Step 0 hit-rate number reported to Malin before build proceeds.
- AC2. Pool routing key is server-recomputed; a tampered client key field cannot direct a
  rating into a foreign pool (CF unit test proves it).
- AC3. One uid = max one live contribution per poolKey, regardless of copy count (test).
- AC4. Editing a recipe (key-changing) removes the user's contribution from the old pool and
  shows the one-time notice; non-key-changing edits (instructions, portions, photos) do NOT
  detach (test both).
- AC5. Stats updates are O(1) per event (deltas/aggregate queries) — no full pool recount
  anywhere (code review + test asserts no query-all in the drain path).
- AC6. Family ratings can never reach the pool (structural test).
- AC7. Pooled display absent below n=5; shows count at ≥5; existing per-copy display intact
  as fallback (widget tests).
- AC8. Deletion cascade + residual probe + data export all cover the events subcollection in
  the same PR (emulator test: delete user → pool recomputed, no orphan events).
- AC9. Rules: all client writes to stats/events denied; owner-only event reads
  (rules-tester suite).
- AC10. Feature flag kills both mirror and display; backfill refuses to run when flag off or
  privacy-policy version predates the pooling disclosure.
- AC11. Dart/TS golden fixture parity test in CI.
- AC12. `dart analyze --fatal-infos` + CF `tsc` clean; all named test files pass.

### Not in v1 (explicit)
- Menu-weighting on pooled ratings (v1.1 — **file the Linear ticket at approval time**, PM
  condition, so it doesn't rot); variant discovery; fuzzy matching; canonical recipe bank
  (content sharing — separate legal review); any change to GlobalRecipeCache or family ratings.

### Open points surfaced to Malin (not buried)
- **BUT-417** (moderation email stub, 2+ years): T&S/Support flag that this ships a new
  cross-user UGC-adjacent surface while that SLA gap stays open. Accept explicitly or fix first.
- Display floor n=5 is my synthesis of DPO(≥3)/T&S(not 1–2)/PM(keep low) — tunable, say the word.
- v1 payoff is display-only network effect; the real product lever (menu weighting) is v1.1 —
  PM notes the value/effort is weak unless v1.1 is genuinely committed.

### Rollback
Flag off = feature dark instantly. Additive collections; revert = disable CF triggers, drop
the two collections. No existing rating data is mutated (events are copies; per-copy stats
untouched).

## Vad det här betyder på vanlig svenska
- Idag ser bara du (och de du delar med) betyg på dina recept. Det här ger populära recept
  ett gemensamt "Butlery-betyg" från alla användare som har samma recept — även om en
  importerade det som länk och en annan som skärmdump.
- Ändrar du i receptet (byter bönor mot linser) räknas din version som ett nytt recept och
  det gemensamma betyget följer inte med — precis som du föreslog, och precis som Samsungs
  matapp gör.
- Betyget visas bara när minst fem personer tyckt till, och alltid med antalet röster — så
  ett "betyg" aldrig är en enda persons åsikt i förklädnad.
- Familjens betyg förblir helt privata och räknas aldrig in.
- Fusk försvåras: bara konton som funnits ett tag räknas, en person = en röst per recept,
  och allt räknas ihop på servern där ingen app kan manipulera det.
- Innan något byggs mäter vi om skärmdumps- och Instagram-recept faktiskt matchar
  länk-recepten — gör de inte det justerar vi först, så vi inte bygger något som inte träffar.
- Integritetspolicyn uppdateras innan gamla betyg räknas in, och allt raderas/exporteras med
  kontot som vanligt.
- Risk: låg — funktionen har en avstängningsknapp, inget befintligt ändras, och allt nytt
  kan tas bort i ett steg.

---

## Sprint: weekly-menu personalization (linchpin) — 2026-07-01

Building the autonomous-laned tickets from the malin decision queue. Batch 1 = the
menu-scoring cluster (shares `menu_service.dart` `_recipeWeight`). Remaining autonomous
tickets follow in later batches.

### Agent A: flutter-developer — menu scoring (Tier C, single-panel: Product Manager)
- [ ] **A1. Pantry-aware weighting** `[Tier C]` — `lib/services/menu_service.dart`: gentle pantry-overlap boost via `PantryService.getMatchingRecipes` (⚠️ ticket's `scoreRecipesByPantry` is stale — corrected in BUT-1321 body). (BUT-1321)
  - Acceptance: higher pantry-match out-weights identical no-match · zero match → weight unchanged · matches fetched once per generation · analyze clean, existing menu tests green
- [ ] **A2. Cuisine-affinity + cooking-skill bias** `[Tier C]` — same file: affinity-cuisine boost from `UserProfile.cuisineAffinities`; gentle skill-based complexity bias from `cookingSkillLevel`. (BUT-1320 scoring half)
  - Acceptance: affinity cuisine out-weights non-affinity sibling · beginner skill biases toward simpler recipe · `MenuScoringContext.empty` yields pre-change weights (parity) · never excludes a recipe

### Deferred to later batches (autonomous lane)
- BUT-1320 Settings UI (Tier B) · BUT-1324 protein/category balance · BUT-1322 household-size scaling · BUT-1323 who's-eating (L) · BUT-1454 minor safety (full-panel) · BUT-1360 offline polish · BUT-945 easier rejoin · BUT-684 handwritten OCR · BUT-520 6 priority VM migration

**Carried PM conditions (bind when these batches build):**
- BUT-1324 (protein pass): add a test with a pool triggering BOTH cuisine (3+ same) AND protein (3+ same) clusters simultaneously, asserting the final selection satisfies both constraints (or documents which pass wins) — the two post-selection swap passes must not undo each other.
- BUT-1320 Settings UI: point-of-use copy must say cuisine/skill *tunes menu suggestions* (today they read as a social "cooking identity" bio field) — ship in the same release as the scoring so users attribute the menu change.

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos` · relevant unit tests · code-reviewer + testing-specialist on staged · commit + push · Linear: Tier C → In Review + notify

---

## Sprint: malin decision-queue — 2026-07-01

Autonomous Tier-A backlog is nearly drained (only BUT-1240 carries `autonomous`, and it's
genuinely infra-blocked). The headline of this `malin` run is the Phase 3.6 decision queue on
the 23 `need-malin` tickets. The autonomous half is one clean win + one measured/conditional.

### Agent A: e2e-test-specialist — age-gate journey
- [ ] **A1. e2e under-15 rejection journey test** `[Tier A]` — `test/views/onboarding_journey_test.dart`: make the stub age-gate "next" handler call `verifyAgeGate()` and branch like production (`OnboardingView._handleNext` switch), add an under-15 journey case. (BUT-1437)
  - Acceptance: (1) the stub `_OnboardingBody` age-gate page advance calls `viewModel.verifyAgeGate()` and switches on `AgeGateAdvanceResult` exactly like production (compliant→advance, rejected→route-to-start, error→stay) · (2) new case: under-15 year picked → `verifyAge` mock returns false → rejection UI shown + routed to a start/auth screen, no allergen/UGC page reachable · (3) the existing compliant journey still completes AND now routes through the gate: `verifyAge` called exactly once (at the gate, not re-called at completion) · (4) `dart analyze --fatal-infos` clean; file's tests pass.
  - Stakeholders: Software Architect, Product Manager (router: `single`) — folded into the e2e-test-specialist's faithful-mirror check.

### Conditional (measured, not blind)
- [ ] **BUT-1149 restore coverage floor 60.0** `[Tier A]` — GATED on a measured run. Flip `OVERALL_FLOOR` 55.0→60.0 in `.github/workflows/test.yml:305` ONLY if the live coverage run clears 60%. Strong prior it's still <60 (ticket: stalled 55.5%, needs 4-6 more test batches) → then leave open with the measured number, do NOT flip blind.

### Needs you (Tier D — flagged, not worked)
- BUT-1240 — needs a device-capable CI lane (Android emulator or desktop-native runner with the ONNX native lib) + a CI secret to download the NER model. Infrastructure/ops, can't be done from here.
- BUT-1441 — needs a prod Firestore data migration (console/script run). I'll draft the one-off backfill script; you run it against prod.

### Phase 3.6 — Malin decision queue (live)
- 23 `need-malin` tickets + any Tier-D blockers. Capped at top ~6 by stakes (security/legal/launch first), prepped into decision briefs, asked live.

---

## Plan: BUT-1450 — export notification-analytics collections (Art.15 ⊇ Art.17) — 2026-06-30 (rev. 2)

Sensitive domain (GDPR / user data, data-export). Router tier: **full-panel**. Panel convened
(Privacy/DPO, Legal, Security Architect, Performance Engineer) — all approve-with-conditions, no blocks.

**Malin's decision on the one interpretive point:** the panel's Privacy/DPO + Legal advice to
**anonymise the notification counterparty** is **consciously overridden**. Real-world exports
(Facebook, Google) include the counterparty; Art.15(4) is a *balancing test*, not a blanket
redaction rule; and the export should reflect what the user already saw in the app. So the
counterparty is **included as seen**, not anonymised. This deviation gets an entry in
`.claude/rules/accepted-deviations.md` so future Privacy/security reviews don't re-flag it.

### Problem
The account-deletion cascade `deleteNotificationAnalytics` (functions/src/account/account-deletion-cascade.ts:634)
erases four collections, but DataExportService never exports them — a right-of-access gap
(export must ⊇ erased):
- `notification_history`     WHERE userId == uid
- `notification_batches`     WHERE userId == uid
- `notification_engagement`  WHERE userId == uid
- `notification_delivery`    WHERE senderId == uid  (notifications the user triggered)
- `notification_delivery`    WHERE targetUserId == uid (notifications delivered to the user)

### Approach (mirror the just-shipped BUT-1396 pattern)
Read-only export reads through `FirebaseDataExportRepository` (`_guardSelfExport` →
`validateOwnership`), surfaced via `PreferencesExportManager`, wired into
`DataExportService.exportUserData()`. No deletion change, no firestore.rules change.

### Pre-implementation verification (Step 0 — drives the counterparty representation)
- Read where `notification_delivery` + `notification_history` are written (send-notification.ts
  and friends) to confirm each record's real fields.
- Decide the counterparty representation **from reality**: prefer the human-readable name /
  notification content the user already saw; include a bare internal Firebase UID only if no
  friendlier field exists. Do NOT add expensive bulk UID→name profile lookups for a rare export.
- Confirm these notifications are user-facing (things the user actually saw). If any category
  involves a counterparty the user never saw (hidden third-party telemetry), flag it before
  including — that narrow case is the only place the panel's caution could still apply.

### Files
1. `lib/repositories/firebase/firebase_data_export_repository.dart`
   - +4 `ExportResourceType` enum values (notificationHistory, notificationBatches, notificationEngagement, notificationDelivery).
   - +5 methods via `_queryList`: history/batches/engagement (userId==uid); delivery **sent** (senderId==uid) and **received** (targetUserId==uid) as TWO separate queries (Firestore has no cross-field OR). History sorted `descending` on sentAt/createdAt; explicit `maxDocuments` per collection.
2. `lib/services/account/export/export_pagination_helper.dart`
   - Add `exportLimits` entries: notification_history 2000, notification_delivery 1000, notification_batches 500, notification_engagement 1000. Passed as `maxDocuments` (NOT the 10k default).
3. `lib/services/account/export/preferences_export_manager.dart`
   - +manager methods returning `{data, total_count, truncated, note}`. The delivery method merges sent+received and **includes the counterparty as the user saw it** (human-readable where stored; no anonymisation). In-code comment recording the Art.15(4) balancing call (include, per Malin's decision + industry norm).
4. `lib/services/account/data_export_service.dart`
   - +4 futures keys (notification_history, notification_batches, notification_engagement, notification_delivery).
5. `functions/src/account/account-deletion-cascade.ts`
   - Add the 4 collections to the GDPR probe/coverage array (~line 85) so the export⊇erased invariant stays self-checking.
6. `.claude/rules/accepted-deviations.md` — entry: notification counterparty is exported (not anonymised) — Malin's call, Art.15(4) balancing + industry norm; don't re-flag.
7. `docs/security/` — Art.30 record entry for notification analytics (lawful basis, retention, export treatment = included-as-seen), following the family-data-retention.md pattern.
8. `assets/legal/privacy_policy_en.md` + `_sv.md` — add "notification delivery and engagement records" as a disclosed data category in the Art.15/30 section.
9. `test/unit/services/account/data_export_service_test.dart` — new tests.

### Acceptance criteria (binding)
- AC1. Export output contains keys `notification_history`, `notification_batches`, `notification_engagement`, `notification_delivery`, each scoped to the calling user.
- AC2. `notification_delivery` is two queries (senderId + targetUserId), merged and de-duplicated.
- AC3. The counterparty is **included as the user already saw it** (name / notification content), not anonymised — matching how mainstream exports format interaction data. Bare internal Firebase UIDs are not dumped where a human-readable field exists. (Malin's decision, overriding the Privacy/Legal redaction recommendation.)
- AC4. Each section paginated with its explicit per-collection limit and emits `truncated: true` + a note when capped; `DataExportService` surfaces it in `export_metadata.truncated_collections`.
- AC5. `notification_history` returns most-recent-first.
- AC6. The four collections are added to the deletion-cascade GDPR probe array.
- AC7. The override (include, not anonymise) is recorded in `.claude/rules/accepted-deviations.md`.
- AC8. Art.30 record updated; privacy policy (EN+SV) lists the new data category.
- AC9. Tests prove: each section present; an OTHER user's first-party rows excluded (ownership-negative on userId-scoped collections); empty-safe (keys present, no error, for a user with none); truncation flag when over the cap.
- AC10. No firestore.rules change; `dart analyze --fatal-infos` clean; CF `tsc` clean.

### Negative constraints
- Don't dump bare internal Firebase UIDs where a human-readable counterparty field exists.
- Don't include any counterparty data the user never saw in-app (the narrow hidden-telemetry case).
- Don't change any deletion behavior or any existing export section's shape.

### Verification + gates
- dart analyze; the new unit tests; firebase-backend-security + code-reviewer + testing-specialist; cloud-functions-specialist for the cascade-probe edit.

### Rollback
Purely additive (new export sections + doc edits). Revert the single commit — no migration, no
change to existing export/deletion flows.

## What this means in plain language
- This is about your "download all my data" feature, which the law requires to be complete.
- Right now it leaves out four behind-the-scenes notification record types (history of what was sent to you, delivery records, engagement stats). This adds them, so the download is honest and complete.
- **On the "other person" question you caught:** you were right — your export will show the other people the way you already see them in the app (e.g. "Anna shared a recipe with you"), exactly like Facebook/Google do. We're *not* blanking them out. The only thing we avoid dumping is the meaningless internal database ID — you get the name/notification you actually saw, not a 28-character code.
- Big notification lists get capped (a few thousand most-recent) so the download doesn't balloon, and it'll clearly say if anything was trimmed.
- I'll list these records in your privacy policy and the internal compliance record, and note our decision (show the counterparty, don't anonymise) so a future automated review doesn't "correct" it back.
- **Risk:** very low. It only *adds* to the data export; nothing about how the app works changes; one-commit undo.

---

## Sprint: compliance quick wins (need-malin, interactive) — 2026-06-30

(archived — BUT-1395/1396/1399/1400 all Done + pushed; CF deletion leak fixed; Swedish email
migration done; acquisition-rules CI red fixed. Follow-up BUT-1450 planned above.)
