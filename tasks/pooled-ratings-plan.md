# Plan: Butlery-betyget & the pooling ladder (v1 → v2)

**Status: v1 AWAITING MALIN'S APPROVAL — build nothing until she says go.
v1.5/v1.6/v2 are staged roadmap, each needs its own go + panel round at build time.**

- v1 was full-panel reviewed 2026-07-02 (12 roles, 12× approve-with-conditions, 0 blocks) on
  branch `claude/recipe-source-dedup-w29w2i` — that branch's `tasks/todo.md` + ADR-0004 are
  the panel snapshot. **This file is the canonical living plan**; it adds the pooling ladder
  (v1.5/v1.6/v2) decided in conversation with Malin 2026-07-02.
- ADR-0004 (event storage shape) lives on the branch at
  `docs/org/adr/ADR-0004-pooled-rating-event-storage-shape.md`; it merges to main with v1.

## Origin & principle

Malin's insight: Swedish recipes come from a limited source pool, so many users hold the
same recipe (imported via different methods) and their ratings should pool — valid per
content version (bönor→linser = a different recipe). Research confirmed the pattern:
Samsung Food removes ratings from tweaked copies; Goodreads pools editions under a "work";
Vivino uses display thresholds.

The ladder's governing principle, from the comments/cook-snaps follow-up (2026-07-02):
**numbers pool freely; content never crosses sharing circles without explicit opt-in AND a
real moderation chain.** The codebase already encodes the conservative half of this: the
cook-snap per-item visibility toggle (BUT-1214) is deliberately narrowing-only ("the
recipe's audience is the cap"). A widening toggle is a trust-model inversion reserved for
v2 — see "Why a local/global comment toggle is v2, not a middle ground" below.

---

## v1 — Pooled ratings ("Butlery-betyget")

V1 shares ONLY numbers keyed by a content hash — **no recipe content is shared** (keeps EU
database-right/copyright questions out of scope; those belong to the separate, later
"canonical recipe bank" decision). All panel conditions below are binding.

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
- Pooled counters, pooled structured tweaks, public comments/cook-snaps — staged as
  v1.5 / v1.6 / v2 below. Approving v1 does NOT commit any of them.

### Open points surfaced to Malin (not buried)
- **BUT-417** (moderation email stub, 2+ years): T&S/Support flag that this ships a new
  cross-user UGC-adjacent surface while that SLA gap stays open. Accept explicitly or fix first.
- Display floor n=5 is a synthesis of DPO(≥3)/T&S(not 1–2)/PM(keep low) — tunable, say the word.
- v1 payoff is display-only network effect; the real product lever (menu weighting) is v1.1 —
  PM notes the value/effort is weak unless v1.1 is genuinely committed. The ladder below is
  part of the answer: each later step rides v1's infrastructure.

### Rollback
Flag off = feature dark instantly. Additive collections; revert = disable CF triggers, drop
the two collections. No existing rating data is mutated (events are copies; per-copy stats
untouched).

---

## Why a local/global comment toggle is v2, not a middle ground (analysis record, 2026-07-02)

Malin asked whether a per-comment "local or global" toggle could be a middle ground below
public comments. Analysis conclusion — **no**, for four reasons; recorded so it isn't re-litigated:

1. **Store UGC rules are binary, not volume-based.** App Store and Google Play require
   reporting, user-blocking, and timely moderation the moment ANY user content is visible to
   strangers. One global comment costs the same compliance-wise as ten thousand. The toggle
   doesn't buy a cheaper risk class — it IS v2 with a nicer composer. BUT-417 becomes
   blocking on day one.
2. **Comments carry photos** (BUT-983, up to 3 images per comment). A global-comment toggle
   is therefore secretly a public photo-publishing toggle — the highest-risk content class
   (faces, homes, children) riding in through the side door.
3. **Comments expose identity** (authorDisplayName + avatar denormalized on every comment).
   Ratings pool as anonymous numbers; a global comment puts who-you-are in front of
   strangers, including potentially minors' names and faces.
4. **Mixed-audience threads leak.** Comments today belong to one recipe copy and its sharing
   circle. A global comment belongs to the pool and would render inside strangers' threads,
   interleaved with private family discussion; one misread reply-context publishes a private
   note to the world. The cook-snap toggle (BUT-1214) avoided exactly this by being
   narrowing-only — "the recipe's audience is the cap."

The toggle is the **designated v2 mechanism** (right control surface once the moderation
chain is real) — it is not a step below v2.

---

## v1.5 — Pooled counters ("212 hushåll har receptet, 47 lagade det senaste månaden")

**Status: staged. Rides v1 wholesale — do not build before v1 ships. Panel round (router:
likely cheap — re-treads v1's decided ground) at build time.**

- **What:** pool-level counts only, same risk class as ratings: (a) distinct households
  holding a recipe in the pool; (b) cooked-recently count (rolling window, e.g. 30 days).
  Pure numbers — no content, no identity, no moderation surface.
- **Infrastructure reuse (the point):** poolKey + server-only aggregation (deltas/aggregate
  queries, never recount) + display floor + feature flag + rules precedent — all v1 machinery.
  - Holder count: maintained on `canonical_recipe_stats` by the same recipe-write trigger v1
    already needs for edit-detachment (increment on pool join, decrement on leave/delete).
  - Cooked events: mirror of the existing markAsCooked action ("Lagat idag",
    `recipe_detail_actions.dart` → `RecipeManagementHandler.markAsCooked`), CF-side, with
    the SAME eligibility gates as ratings (age-compliant, matured account, never family
    data) and the ADR-0004 per-user event-subcollection idiom (frozen poolKey; deletion
    cascade + export + residual probe in the same PR).
- **Display:** on/next to the Butlery-betyget pill and detail stats row; counts always shown
  as counts; floor applies (no "1 household has this" doxxing a lone holder).
- **Not in v1.5:** any content, any per-user visibility of WHO holds/cooked, any menu use.

## v1.6 — Pooled structured tweaks ("Så lagade andra det här")

**Status: staged. Needs its own full panel at build time (new event type + new UI surface),
but heavily precedented by v1/v1.5. Zero LLM (v1 Monetization guardrail carries over).**

- **What:** controlled-vocabulary adjustments aggregated per pool — "31 % dubblade vitlöken,
  18 % sänkte ugnstemperaturen." Captures the AllRecipes insight (the crowd's consensus fix
  is the real treasure, not the prose) WITHOUT free text or images crossing user boundaries:
  no moderation chain, no reporting flow, no BUT-417 dependency, no identity exposure.
- **Vocabulary:** fixed enum, start small (5–8 tweak types: more/less/doubled/halved of an
  ingredient, swapped an ingredient, oven temp up/down, time longer/shorter). Ingredient
  reference uses the SHARED normalizer (v1 decision 3) so "vitlök" aggregates across copies.
  Exact vocabulary is a product decision at the v1.6 panel — never free text.
- **UX (decided by Malin 2026-07-02): pull-only, no prompts, both sides.**
  - *Read:* a quiet, tappable row on recipe detail ("Så lagade andra det här") that ONLY
    renders when the pool clears the display floor; tap to expand the aggregated tweaks.
    Flag off or pool too small → the row does not exist. Same pattern as the v1 pill:
    passive, threshold-gated, zero interruption.
  - *Contribute:* optional, skippable chips at moments the user already initiated — the
    markAsCooked confirmation ("ändrade du något?"), the rating flow, and a small
    "jag ändrade också något" link inside the tweaks view itself. **No popup anywhere.**
  - *Accepted tradeoff (explicit):* pull-only contribution accumulates slowly → pools reach
    the floor later and the row stays invisible on most recipes early. Chosen deliberately:
    the floor protects correctness, so slow costs visibility, never quality; a nagging
    dialog would poison the data and annoy exactly the users we most want to keep.
- **Storage:** ADR-0004 idiom — `users/{uid}/canonical_tweak_events/{poolKey}` (one doc per
  uid per pool, tweak set inside, poolKey frozen at write); server aggregates counts into
  the pool stats doc via deltas/aggregate queries. Same GDPR same-PR rule: deletion cascade
  + residual probe + export together with the write path.
- **Eligibility + floor:** identical gates to v1 (age, maturity, structurally no family
  data). Draft floor: tweak percentages render only with ≥5 distinct tweak contributors in
  the pool (per-tweak vs per-pool floor is a panel decision at build time).
- **Later value:** the most common tweaks for a pool describe the "collectively refined
  version" of the dish — a future input to menu/suggestions (own decision, not v1.6).

## v2 — Public comments & cook-snaps (per-item local/global opt-in)

**Status: not scheduled. Own full panel + legal round when it becomes relevant.**

- The local/global toggle is the designated mechanism: per-comment / per-snap opt-in to
  publish to the pool, default local, never retroactive.
- **Hard prerequisites, all of them, before any build:**
  1. Real moderation chain — BUT-417 fixed, in-app reporting, user blocking, documented
     response SLA (App Store / Google Play UGC requirements).
  2. Identity & minors policy for publicly attributed content (names/avatars of young users).
  3. Mixed-thread UX solved: global comments keyed by poolKey and rendered as a SEPARATE
     section — never interleaved with private circle threads (no reply-context leaks).
  4. Image policy for public photos (comments carry up to 3 images; cook-snaps are photos
     by nature).
  5. Frozen-poolKey semantics for published content on recipe edit (same detachment
     question v1 answered for ratings).

## Sequencing & commitment

1. **v1 — pooled ratings** (panel-approved, awaiting Malin's go; Step 0 measurement first)
2. **v1.1 — menu weighting on pooled ratings** (Linear ticket filed at v1 approval)
3. **v1.5 — pooled counters** (nearly free on v1's infra)
4. **v1.6 — pooled structured tweaks** (pull-only UX per Malin; own panel)
5. **v2 — public comments/photos with the toggle** (only after the moderation chain is real)

Each step gets its own explicit go from Malin. Approving an earlier step never commits a
later one. Every step keeps the v1 guardrails: server-authoritative keys, eligibility gates,
display floors, feature flags, GDPR same-PR coverage, zero LLM in key/aggregation paths.

## Vad det här betyder på vanlig svenska

- **Steg 1 (klart att bygga när du säger ja):** populära recept får ett gemensamt
  "Butlery-betyg" från alla användare som har samma recept — även om en importerade det som
  länk och en annan som skärmdump. Ändrar du receptet räknas det som ett nytt recept.
  Betyget visas först när minst fem personer tyckt till, alltid med antal röster.
  Familjens betyg är alltid privata. Innan något byggs mäter vi att matchningen faktiskt
  träffar, och integritetspolicyn uppdateras innan gamla betyg räknas in.
- **Steg 2:** veckomenyn börjar väga in det gemensamma betyget — det är där den riktiga
  produktnyttan finns.
- **Steg 3 (räknare):** "212 hushåll har det här receptet, 47 har lagat det senaste
  månaden." Bara siffror — ingen ser vem. Nästan gratis att bygga ovanpå steg 1.
- **Steg 4 (så lagade andra det):** en diskret rad på receptsidan som man kan trycka på om
  man är nyfiken — "31 % dubblade vitlöken." Man bidrar genom valfria knappar när man ändå
  markerat receptet som lagat eller satt betyg. **Inga popupper någonstans** — den som inte
  bryr sig ser aldrig något. Eftersom allt är förvalda knappar (aldrig fritext eller bilder)
  behövs ingen granskning av innehåll, och ingen ser vem som tyckt vad.
- **Steg 5 (längre fram, kräver eget beslut):** möjligheten att göra en kommentar eller
  matbild publik med en reglage per inlägg — men först när rapportering, blockering och
  moderering finns på riktigt (kravet från App Store/Google Play), eftersom en enda publik
  kommentar utlöser hela det regelverket. Reglaget du föreslog är rätt lösning — men den
  hör hemma där, inte tidigare.
- **Risk:** varje steg har en avstängningsknapp, bygger ovanpå föregående steg utan att
  ändra något befintligt, och kan tas bort för sig. Du godkänner varje steg separat.
