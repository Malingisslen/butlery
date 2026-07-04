# LIA — Pooled Ratings ("Butlery-betyget")

**Legitimate Interest Assessment (GDPR Art. 6(1)(f)) + DPIA screening (Art. 35)**

> ⚠️ **DRAFT — awaiting Malin's review/sign-off (§7).** Drafted by engineering as
> the starting point for the controller/DPO review, not as legal advice. The
> feature ships behind an OFF feature flag; the backfill of pre-existing ratings
> (§5) is **hard-gated on this assessment being signed off AND the privacy policy
> disclosure being live** — see `tasks/pooled-ratings-plan.md` decision 12(e).

- **Feature:** Pooled recipe ratings — a user's 1–5 star "alla" rating of a
  recipe is contributed to a **shared community average for the same dish**
  ("Butlery-betyget"), so users who hold the same recipe (imported by any method)
  see one combined score. Identity is a deterministic content hash (`poolKey`)
  of the recipe's title + ingredients; no recipe content is shared, only numbers.
- **Controller:** Butlery (Malin Gisslén, sole founder).
- **Date drafted:** 2026-07-04
- **Status:** ⚠️ **DRAFT — not yet signed off.**
- **Chosen lawful basis:** **Art. 6(1)(f) — legitimate interest.** (Not consent:
  the processing is low-impact, uses ordinary data already lawfully held, and a
  consent gate on a background aggregation would be disproportionate and would
  fragment the signal. The user retains an Art. 21 objection right — see §4.)

---

## 1. The data

| Data | Category | Where |
|---|---|---|
| The 1–5 star rating value (`ratingValue`) | Ordinary (Art. 6) | `users/{uid}/canonical_rating_events/{poolKey}` |
| `poolKey` — a content hash of the rater's recipe title + ingredients | Ordinary; a reproducible pseudonym | same event doc (doc-id) |
| `recipeId` — which of the rater's own recipe copies the vote came from | Ordinary | same event doc |
| The rater's `uid` (as the subcollection owner path) | Ordinary identifier | path `users/{uid}/…` |
| Combined `count` + `average` per pool | **Anonymous aggregate** | `canonical_recipe_stats/{poolKey}` |

**Pseudonymous, NOT anonymous (Breyer C-582/14).** The per-user event store links
a `uid` to a `poolKey` that is *reproducible from the shipped app*, so it is
personal data (pseudonymous) and carries the full GDPR rights. Only the
uid-free `canonical_recipe_stats` aggregate is anonymous. **No document, code
comment, or policy text may describe the events store as "anonymous."**

## 2. Purpose (test 1 — is the interest legitimate?)

Improve recipe discovery and menu quality by surfacing a trustworthy, crowd-sourced
quality signal for a dish that is otherwise fragmented across every user's private
copy. The Swedish recipe pool is small and heavily duplicated (the same dish
imported as URL / screenshot / caption), so per-copy averages are thin and
misleading; pooling gives an honest signal and, later (v1.1), a better weekly menu.
This is a real, present, specific business interest — the app's core value
proposition — not speculative. **Legitimate: yes.**

## 3. Necessity (test 2 — is the processing necessary, and minimal?)

- **Necessary:** there is no less-intrusive way to produce a cross-copy average
  than to key each rating to a content-identity and combine them server-side.
- **Data minimisation:**
  - Only a single integer (the star) plus a derived hash is stored per pool — no
    review text, no timestamps beyond housekeeping, no rater identity in the
    public number.
  - The identity is a **hash**, not the recipe content — no title/ingredient text
    crosses a user boundary (keeps EU database-right/copyright out of scope).
  - **Family/household ratings are structurally excluded**: they live in a
    separate `family_ratings` collection; the mirror trigger is bound to
    `recipe_ratings` ONLY, so a family/child verdict can never reach a pool
    (code-level guarantee, not a filter). Children's data is therefore out of
    scope for this processing entirely.
  - **Eligibility gates:** a rating counts toward a pool only if the account is
    age-compliant (already enforced on the source rating) AND matured
    (email-verified or ≥ 60 min old) — throwaway-account spam is excluded.
- **Proportionate storage:** the event **dies with the rating** — deleting the
  rating (retraction) or the account removes the pool contribution and recomputes
  the affected pool; there is no orphan log. Retention is therefore "as long as
  the underlying rating exists," no separate period. (Art. 30 record:
  `../security/pooled-ratings-retention.md`.)

## 4. Balancing (test 3 — does the interest override the data subject's rights?)

| Factor | Assessment |
|---|---|
| Nature of the data | Ordinary, a single 1–5 integer. No special category. No children's data (structurally excluded). |
| Reasonable expectations | A user rating a recipe reasonably expects the rating to inform others' view of that recipe — this is the ordinary meaning of "rating." Disclosed in the privacy policy before the backfill. |
| Impact on the individual | Very low: the public value is an **anonymous aggregate** shown only at **n ≥ 5** distinct raters (k-anonymity margin over the DPO's ≥3 floor), always with the count. A single vote is never individually visible. |
| Intrusiveness | No new data collection — this re-uses the star the user already gave. No tracking, profiling, or automated decision with legal/similar effect (Art. 22 N/A). |
| Safeguards | Server-authoritative key (no pool-poisoning), display floor, feature-flag kill switch, full GDPR export + erasure coverage, spike-detection + admin split-a-bad-merge tooling (decision 13). |
| **Objection right (Art. 21)** | Because the basis is legitimate interest, the user may object. **Practical mechanic:** deleting the rating removes the pool contribution immediately; the feature kill switch removes it globally. A standing per-user opt-out is a candidate enhancement if objections arise. |

**Balancing outcome (proposed): the legitimate interest is NOT overridden.** The
processing is low-impact, expected, minimal, reversible, and heavily safeguarded.
**[Malin/DPO to confirm.]**

## 5. Purpose-change screening for the BACKFILL (Art. 5(1)(b) + Art. 6(4))

The backfill applies the pool aggregation to ratings **already collected** before
this feature. This is a compatibility check, not a new collection:
- **Link between purposes:** the original purpose ("rate a recipe") and the new
  purpose ("combine that rating into the dish's community average") are closely
  linked — both are "evaluate the recipe." Compatible.
- **Context & expectations:** see §4 — within reasonable expectations of "rating."
- **Nature of the data & impact:** ordinary, low-impact, anonymised at display.
- **Safeguards:** the aggregate is anonymous; the events remain fully erasable.
- **IMY stance:** to be checked at sign-off; the mainstream analogue (Goodreads
  pooling editions, Vivino display thresholds) is well-established.

**Backfill hard gate (do not run until ALL hold):** (a) this LIA signed off;
(b) privacy policy EN/SV pooling disclosure **live**; (c) the poolKey hit-rate
harness re-run on ≥20–30 REAL corpus scans with **0 false merges** (C6/C7/C8).
The backfill CF is BUILT but refuses to run while the flag is off.

## 6. DPIA screening (Art. 35(3)) — is a full DPIA required?

| Art. 35(3) trigger | Present? |
|---|---|
| Systematic & extensive profiling with legal/similar effect | No — no profiling, no individual decision |
| Large-scale special-category (Art. 9) or criminal data | No — ordinary data only; family/health data structurally excluded |
| Systematic large-scale monitoring of a public area | No |
| Children's data at scale | No — children's ratings cannot reach a pool (structural) |

**Screening conclusion (proposed): a full DPIA is NOT triggered.** None of the
Art. 35(3) criteria apply; the WP248 nine-criteria count is low (essentially only
"matching/combining datasets," and that on ordinary, anonymised-at-output data).
This LIA + the Art. 30 record are the proportionate documentation. **[Malin/DPO to
confirm the screening.]**

## 7. Sign-off
- **Reviewed & agreed:** ☐ pending — Malin Gisslén (controller / DPO review).
- **Date:** ____________
- **Decision:** ☐ Approved  ☐ Approved with conditions  ☐ Rejected
- **Conditions / notes:** ____________

## 8. Linked artifacts
- Art. 30 record + retention: [`../security/pooled-ratings-retention.md`](../security/pooled-ratings-retention.md)
- Plan + all 16 decisions: [`../../tasks/pooled-ratings-plan.md`](../../tasks/pooled-ratings-plan.md)
- Event storage shape: ADR-0004 (branch `docs/org/adr/`)
- Privacy policy §4 (legal basis) + §5.2 (pooled ratings) + §8 (retention).
- Family-rating DPIA (template + the separate, household-scoped rating path): [`family-rating-dpia.md`](family-rating-dpia.md)

## 9. Engineering attestation
As of 2026-07-04 the safeguards in §3–§4 are implemented and tested: the
server-authoritative key + Stage-A mirror (maturity/family gates), the Stage-B
anonymous aggregate (no read-all), the n≥5 display floor, the feature-flag kill
switch, and the same-PR GDPR coverage (deletion cascade + residual probe + export
of `canonical_rating_events`). What remains is **legal/DPO sign-off** and the
real-corpus backfill gate — not engineering work.
