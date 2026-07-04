# Pooled Ratings ("Butlery-betyget") — Retention & Art. 30 Record

Companion to the LIA ([`../legal/pooled-ratings-lia.md`](../legal/pooled-ratings-lia.md)).
Covers the two collections the pooled-ratings pipeline adds. Lawful basis
throughout: **Art. 6(1)(f) legitimate interest** (see the LIA for the balancing
test). Region: **europe-west1** (EU). No third-party processor beyond Google
Firebase (existing DPA).

## Retention model — "the event dies with the rating"

There is **no separate retention period**. A pool event exists exactly as long as
the rating that produced it:
- **Rating retracted** (the user deletes their 'alla' rating) → the Stage-A mirror
  deletes the matching event(s) by stored `recipeId` → the affected pool
  recomputes. No orphan log.
- **Account deleted** → the deletion cascade erases
  `users/{uid}/canonical_rating_events`; each delete fires the Stage-B trigger, so
  the pools the user contributed to shrink automatically (decision 12, same-PR
  coverage). Residual-probe verified (fail-closed).
- **Recipe edited into a different dish** → the past event stays **frozen** in the
  pool it judged (decision 4/6 — no edit-detachment); it is removed only by the
  two mechanisms above. This is a deliberate, decided behaviour, not a leak.

Because erasure is driven by the rating/account lifecycle, storage-limitation
(Art. 5(1)(e)) is satisfied without a timer: nothing outlives its source rating.

## Pseudonymity note (Breyer C-582/14)

`canonical_rating_events` is **pseudonymous, not anonymous** — a `uid` linked to a
`poolKey` that is reproducible from the shipped app. It carries full data-subject
rights and is included in the Art. 15 export. Only the uid-free
`canonical_recipe_stats` aggregate is anonymous. Never label the events store
anonymous in any artifact.

## Per-field record (Art. 30) — `users/{uid}/canonical_rating_events/{poolKey}`

One frozen pool event per pool the user has voted in (doc-id = `poolKey` ⇒ one vote
per user per pool). **Server-only writes** (Cloud Functions / Admin SDK);
owner-only read (firestore.rules, decision 10). Server-authoritative key —
a client-written key is never trusted for routing (pool-poisoning defence).

| Field | Purpose | Lawful basis | Special category? |
|---|---|---|---|
| `poolKey` (doc-id) | Content-identity of the dish; groups ratings of the same dish across copies | Art. 6(1)(f) | No (a reproducible content hash — pseudonym) |
| `ratingValue` (1–5) | The rater's contribution to the pool average | Art. 6(1)(f) | No |
| `recipeId` | Which of the rater's own recipe copies the vote came from; edit-proof retraction key | Art. 6(1)(f) | No |
| `createdAt` | Lifecycle housekeeping | Art. 6(1)(c) | N/A |
| `uid` (owner path segment) | Scopes the event to its rater; enforces one-vote-per-pool + erasure | Art. 6(1)(f) | No (a UID) |

## Per-field record (Art. 30) — `canonical_recipe_stats/{poolKey}`

The **anonymous** public aggregate. Any authenticated user may read; all client
writes denied (server-only, decision 10). Not personal data — no data-subject
record applies; listed for completeness of the processing inventory.

| Field | Purpose | Personal data? |
|---|---|---|
| `count` | Number of distinct raters in the pool; drives the n≥5 display floor | No (aggregate) |
| `average` | The displayed community score | No (aggregate) |
| `updatedAt` | Lifecycle housekeeping | No |

## Rights mechanics

- **Access / portability (Art. 15/20):** `canonical_rating_events` is included in
  the GDPR data export (`DataExportService`, `pooled_rating_events` section),
  labelled pseudonymous. Export ⊇ erased (BUT-1450 invariant).
- **Erasure (Art. 17):** covered by the deletion cascade (above).
- **Objection (Art. 21):** the basis is legitimate interest, so the user may
  object; deleting the rating removes the contribution immediately, and the
  feature kill switch removes it globally. See LIA §4.
- **Display floor:** the public value renders only at **n ≥ 5** distinct raters,
  always with the count — a k-anonymity margin over the DPO's ≥3 minimum. This is
  a UX/anti-gaming gate, not the confidentiality control (the rules already gate
  reads to authenticated users; the aggregate carries no identity).

## Abuse / integrity (decision 13)

Per-poolKey rating velocity is available to admin spike-detection, and an admin
"split a bad merge" path exists before any backfill runs. Editing a recipe resets
its pool membership ("rating laundering") — an accepted, documented side effect;
user-level reports/strikes persist regardless.
