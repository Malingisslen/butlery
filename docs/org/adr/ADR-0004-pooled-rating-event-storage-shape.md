# ADR-0004: Pooled-rating event storage — user-owned subcollection, not a field on recipe_ratings

- **Date:** 2026-07-02
- **Status:** Decided (CTO priority order)
- **Trigger:** Plan draft "Poolade betyg via kanonisk receptidentitet" (tasks/pooled-ratings-proposal-draft.md, full plan in tasks/todo.md)
- **Blast-radius tier:** full-panel (12 roles)
- **Stakeholders seated:** Customer Support/Operations, Data/Integrations Engineer, DBA/Data-layer Engineer, FinOps, Legal Counsel, Monetization Lead, Privacy/DPO, Product Manager, Security Architect, Software Architect, Trust & Safety, Vendor/Procurement

## The disagreement

Where does the per-user pooled-rating contribution live?

- **FinOps** and **Software Architect** favored adding a `ratingPoolKey` field to the
  existing `recipe_ratings` docs: one write per rating action instead of two, no new
  collection, deletion cascade already walks that collection.
- **DBA/Data-layer** argued the opposite — a dedicated user-owned subcollection
  `users/{uid}/canonical_rating_events/{poolKey}`: (a) `recipe_ratings` doc IDs are
  `{recipeId}_{userId}`, so one uid can hold N docs mapping to the same poolKey (N copies
  of the same recipe) — "one vote per uid per poolKey" would need query+grouping instead of
  a natural doc-ID upsert; (b) the poolKey must be **frozen at rating time** (decision:
  a rating belongs to the version it rated) — a live field on a mutable doc silently
  reclassifies past ratings when the recipe is edited; (c) bolting a new pinned-immutable
  field onto `recipe_ratings`' already-dense, heavily rules-tested write rules is
  unnecessary blast radius; (d) the per-user subcollection reuses the existing
  subcollection-delete cascade shape for free (no new collectionGroup index for deletion).

## Decision

**DBA's shape wins: `users/{uid}/canonical_rating_events/{poolKey}`, doc-ID-keyed on
poolKey, poolKey frozen at write time.** Decided by the CTO priority order at the
**data-integrity & correctness** level (beats **cost**): the field-on-existing-doc option
is cheaper by one small write per rating action, but gets vote-dedupe and
edit-reclassification *wrong by construction*, and both failure modes corrupt a public
cross-user signal. Security Architect's independent condition (server recomputes the key,
never trusts a client field) further weakens the case for a client-writable field on
`recipe_ratings`. Software Architect's own caveat ("only deviate if DBA gives a concrete
reason") was satisfied.

## Stakes (per role)

- **FinOps:** write-amplification on a new unbounded-cardinality subsystem; conceded once
  the bigger cost lever (incremental aggregation instead of full recount) was made a hard
  condition — the extra event write is marginal next to that.
- **Software Architect:** avoiding a new collection and keeping the cascade simple;
  satisfied by the subcollection reusing the existing per-user cascade pattern.
- **DBA:** dedupe correctness, frozen-at-write-time key semantics, rules blast radius,
  cascade cost — all structural, all cheap now and expensive to unwind after backfill.
- **Privacy/DPO (adjacent):** the uid-bearing store must be trivially findable for
  Art. 17 deletion and Art. 15/20 export — the user-owned subcollection is the shape the
  existing cascade already handles.

## Consequence

If Butlery proceeds: one extra small write per rating action (the event doc), doc-ID upsert
gives vote dedupe for free, ratings stay pinned to the recipe version they judged, and the
deletion cascade / export / rules work is a mechanical repeat of existing per-user
subcollection idioms. Aggregation over the events must use Firestore aggregate queries or
transactional deltas (never full recount) — that condition rides with this decision.
Advisory only; Malin decides whether the feature proceeds at all.
