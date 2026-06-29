# ADR-0003: Household diner profiles for under-15s (managed, guardian-consented)

- **Date:** 2026-06-29
- **Status:** Decided (Malin) — **build complete; launch gated on DPO sign-off** ([DPIA](../../legal/family-rating-dpia.md))
- **Trigger:** Family-rating feature — to capture per-person meal verdicts and
  allergen-safe meal planning, the household must record people who are too
  young for their own accounts (children under 15) and guests.
- **Relates to:** [ADR-0001](ADR-0001-minimum-age-floor.md) (single minimum age 15).

## Context

ADR-0001 set Butlery's account floor at 15 and deliberately avoided storing
data about under-15s (no parental-consent flow). The family-rating feature needs
the opposite for a *bounded* case: to plan meals safely (allergens) and reflect
the whole family's taste, the household must record a child's name, age band,
and — with explicit consent — allergens, plus that child's meal ratings.

This is a **deliberate, consented departure** from ADR-0001's "no under-15 data"
posture — not a reversal of the **account** floor (under-15s still cannot hold
accounts).

## Decision

1. **Managed "diner profiles"** represent non-account people (children & guests)
   inside a household. A child is data *about* whom an adult guardian is the
   controller — never an account holder.
2. **Two-tier consent** at profile creation: a required guardian consent
   (Art. 6/8: name + age band) and a *separate, unbundled, not-pre-ticked*
   explicit consent for allergens (Art. 9 health data). Versioned, timestamped,
   one-tap withdrawable (withdrawal erases the allergen data).
3. **Household-shared, co-controlled:** both adult members see/edit the same
   diner profile; ratings merge.
4. **Ratings feed the public counter anonymously:** each rater (account users +
   diner profiles, children included) counts once toward a recipe's public
   average, computed server-side as an anonymous aggregate. Individual ratings
   and all allergen data stay household-private.
5. **Custody disputes are out of scope** — Butlery is not the arbiter (see the
   Terms custody clause). Both members co-control.
6. **Deletion (§5b):** sole-member household → full teardown; other members
   remain → re-home the child profiles to a remaining member, never orphan.

## Consequences

- **Positive:** safe, per-person meal planning; whole-family taste signal;
  children's data minimised (coarse age band, no DOB/photo/contact) and
  consent-gated.
- **Cost / risk:** Butlery now processes children's data incl. Art. 9 health
  data → a **mandatory DPIA** ([family-rating-dpia.md](../../legal/family-rating-dpia.md))
  and privacy-policy + consent-text + Terms updates. These are **launch
  blockers** owned by the DPO.
- **Engineering:** fully implemented and tested as of 2026-06-29 (consent gates,
  household-scoped rules, anonymous server-side aggregation, deletion cascade,
  export scoping, retention design).

## Status of launch conditions
Tracked in [`../../legal/family-rating-legal-backlog.md`](../../legal/family-rating-legal-backlog.md):
DPIA sign-off, privacy-policy publication, guardian-consent-text approval,
retention-window confirmation, this ADR, Terms custody clause.
