# Architecture / org Decision Records (ADRs)

Append-only, dated records of **disagreements** surfaced by the Phase-2
stakeholder-review system (`/stakeholder-review`) — whether resolved by the
Chief-Architect priority order or escalated to Malin. The org remembers its own
arguments so a settled tradeoff isn't silently re-litigated.

**The good outcome is "approve WITH CONDITIONS"** — productive convergence, not a
unanimous rubber-stamp or a veto. A thin "just do it" plan turning into an
N-condition safe plan (plus escalations and follow-up tickets) is the value these
records exist to preserve.

- **Written by** `/stakeholder-review` whenever a panel produces a genuine conflict.
- **One file per decision:** `ADR-NNNN-<slug>.md` (zero-padded, incrementing).
- **Append-only:** never edit a decided ADR's substance. To change a decision,
  write a new ADR that supersedes it and flip the old one's status to `Superseded by ADR-NNNN`.
- ADRs **record** decisions; they don't authorize action. The review is advisory —
  Malin decides whether to proceed.

## Format

```markdown
# ADR-0001: <short title>

- **Date:** YYYY-MM-DD
- **Status:** Decided (CTO priority order) | Escalated to Malin | Accepted | Superseded by ADR-NNNN
- **Trigger:** the plan/ticket/fileset reviewed
- **Blast-radius tier:** full-panel | single
- **Stakeholders seated:** Role A, Role B, …

## The disagreement
Which roles disagreed and their positions (who wanted what, and why — each from its stake).

## Decision
What was decided and **by whom** — the CTO priority-order rule applied (cite the level),
or "escalated to Malin → <her choice>". Keep it concrete.

## Stakes (per role)
- **Role A:** position + the risk it was protecting against.
- **Role B:** …

## Consequence
What follows if Butlery proceeds; any conditions the panel attached. Advisory only.
```

## Index

<!-- newest first; one line per ADR -->
- [ADR-0004](ADR-0004-pooled-rating-event-storage-shape.md) — Pooled-rating events live in `users/{uid}/canonical_rating_events/{poolKey}` (frozen key, doc-ID dedupe), not as a field on recipe_ratings; CTO ruled data-integrity/correctness > cost (2026-07-02).
- [ADR-0002](ADR-0002-age-enforcement-mechanism.md) — Age enforcement = signup Cloud Function (authoritative) + Firestore rule (gate); CTO ruled security/correctness > cost (2026-06-27).
- [ADR-0001](ADR-0001-minimum-age-floor.md) — Butlery's single minimum age is **15**; escalated to Malin (interpretive Swedish-law split, 13 vs 15) → she chose 15 (2026-06-27).
