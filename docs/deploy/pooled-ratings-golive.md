# Pooled Ratings ("Butlery-betyget") — Go-Live Runbook

Operator checklist to take the feature live. Companion to
[`../../tasks/pooled-ratings-plan.md`](../../tasks/pooled-ratings-plan.md) (decisions)
and the LIA [`../legal/pooled-ratings-lia.md`](../legal/pooled-ratings-lia.md) (signed 2026-07-04).

## Pre-flight — VERIFIED deploy-ready 2026-07-04
On branch `claude/pooled-ratings-v1`, all green (re-run before deploy if the branch moves):
- `cd functions && npx tsc --noEmit` — clean.
- Pooled CF unit suites: `test:canonical-rating-aggregation` (18), `test:pool-aggregation` (9),
  `test:pooled-ratings-flag` (4), `test:backfill-canonical-ratings` (10) — 41/41.
- Rules emulator: `test:rules:canonical-stats` — 12/12 (client writes denied, owner-only event
  reads, any-authed reads on the anonymous stats).
- `firestore.indexes.json` declares the composite collectionGroup index
  `canonical_rating_events (poolKey ASC, ratingValue ASC)`.

## Go-live SEQUENCE — order matters
Do these in order. The flag is the last step and is instantly reversible.

1. **Merge `claude/pooled-ratings-v1` → main.** (Finish E3 detail scorebar + E4 analytics first.)
2. **⚠️ ENABLE THE INDEX FIRST.** Deploy/enable the `canonical_rating_events (poolKey, ratingValue)`
   composite index and wait for it to finish building. Stage B's aggregate query
   (`count()` + `average('ratingValue')`) throws `FAILED_PRECONDITION` in prod without it —
   so this MUST be live before any pool event is written. `firebase deploy --only firestore:indexes`.
3. **Deploy the rules:** `firebase deploy --only firestore:rules`.
4. **Deploy the functions:** `firebase deploy --only functions` — brings up the mirror
   (`onRecipeRatingWrittenForPool`), the pool aggregator (`onPooledRatingEventWritten` +
   `drainPooledRatingAggregations`), and the (dormant) backfill. Region `europe-west1`.
5. **Ship a store build** carrying the client display (card pill + detail scorebar) AND the
   updated privacy policy (v1.3.0 pooling disclosure must be LIVE in the app users run, not just
   in the repo). NOTE: gated by the store-submission hold.
6. **Flip the flag ON:** set Remote Config `enable_pooled_ratings = true`. This starts BOTH the
   server mirror and the client display in one switch. Backend can start collecting pooled scores
   as soon as functions are deployed + flag on, even before a store build reaches users.

## Rollback
Set `enable_pooled_ratings = false` — the mirror no-ops (retractions still honoured) and the
client hides the pill instantly. No existing rating data is mutated; the two new collections
(`canonical_recipe_stats`, `users/*/canonical_rating_events`) are additive and can be dropped.

## The backfill is SEPARATE and stays locked
Folding pre-existing ratings into scores is NOT part of going live (pooling works going-forward
without it). The backfill CF (`functions/src/migrations/backfill-canonical-ratings.ts`) refuses a
real run unless the flag is on, AND is operationally hard-gated on: privacy policy LIVE + the
real-corpus hit-rate re-measure with 0 false merges (C6/C7/C8, still pending real scans). Preview
with `{ dryRun: true }` any time; do NOT run a real backfill until those clear.

## Still-open pre-ship conditions (from the plan)
- **C9** — pooled-rating spike detection + admin "split a bad merge" tooling should be OPERATIONAL
  before ship (a shared score is a public reputation signal). Not yet built.
- **C10** — anchor-only title-change telemetry (rating-laundering visibility). Not yet built.
- **BUT-417** (moderation SLA) is NOT a v1 blocker — v1 shares only numbers, no user content.

## Visibility reality
The pill renders only at **≥5 raters of the same dish**. Without the backfill, most dishes show no
pill for a while after launch — it fills in as people rate. The real product payoff is the
weekly-menu weighting on pooled scores (v1.1), which is a separate follow-on.
