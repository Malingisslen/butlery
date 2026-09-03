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
- [ADR-0013](ADR-0013-two-fixes-whose-obvious-form-was-wrong.md) — The panel refuted the plan's own prescriptions on both items with real user impact: routing three chat-group callables through `withRateLimit` would have gated *leaving a group* on the shared LLM budget (use `enforceRateLimit`, a convention that lives in two inline comments and nowhere else), and `??=` on the Art. 15 export would only have changed which of two failures vanishes (a dedicated key, mirroring `poll_votes_error_code`). Third item: mirroring `viewedBase` into rules may guard an unreachable path while a non-owner admin cannot manage members at all — so it became a measurement, not a build (2026-09-03).
- [ADR-0012](ADR-0012-real-recipe-pages-as-test-fixtures-in-a-public-repo.md) — BUT-1490's fabricated site fixtures get replaced with real captured pages; Legal Counsel recommended DOM structure with placeholder text instead, because `Malingisslen/butlery` is PUBLIC and the DSM art. 4 TDM exception covers the fetch but not indefinite redistribution, with the sui generis database right (URL 49 §) running separately from copyright — Malin overrode it and chose full capture, keeping every condition: clause text shown before any fetch, restrictive-or-silent sites keep fabricated HTML, provenance is hygiene not permission (2026-09-03).
- [ADR-0010](ADR-0010-edit-trail-is-not-an-audit-row.md) — BUT-1971's edit trail was chosen INSTEAD of restoring the granted audit row, on the premise that it buys the same attribution for free; Security and the DBA independently refuted that (a client-written trail can name the wrong person, and a legitimate row can vanish under two concurrent editors), so it went to Malin — she chose to ship BOTH, the trail to show and the audit row to prove, superseding the BUT-1981/BUT-1971 resolution on the GROUP repository only. Same sitting: the trail's export filter now also carries rows where the requester is the subject, not just the actor (2026-08-29).
- [ADR-0008](ADR-0008-clock-bound-on-message-timestamps-and-its-error-message.md) — A future-dated `Timestamp` pinned a chat message to the top AND froze the chat-list preview every participant sees without opening the thread; the bound had to trade a harassment window against locking out a device with a wrong clock, so it went to Malin — she chose ONE HOUR plus a real error message over 24 hours plus no app change, and the two ship together because neither is defensible alone (2026-08-19).
- [ADR-0007](ADR-0007-silent-deletion-of-duplicate-chat-messages.md) — The chat duplicate guard has never fired (wrong trigger path, same bug BUT-1766 already fixed once in this subsystem); repointing it switches on SILENT server-side deletion of people's messages, so the panel's five conditions and the deletion question itself went to Malin — she said yes, but only on real spam, with the switch shipping OFF. The `sentAt is timestamp` rules fix beside it: unanimous approve (2026-08-19).
- [ADR-0006](ADR-0006-unread-count-query-limit.md) — The unread-conversations query keeps `limit(500)`; Performance's must-have to lower it to 100 declined on a factual objection (Firestore bills per document returned, so the lower ceiling saves nothing typical and undercounts first) — priority order, correctness > cost (2026-08-15).
- [ADR-0005](ADR-0005-household-allergen-sharing.md) — Household allergen sharing scopes to `households/{householdId}` (priority order, over the friend category); Malin escalations: one combined allergens+diet toggle, live household scope incl. later joiners, June minimisation override re-confirmed, papers before code (2026-08-12).
- [ADR-0004](ADR-0004-shared-list-self-removal-rule-allowlist.md) — Shared-list self-removal allowlists exactly `memberPermissions` + `updatedAt`; Security's blocklist objection was correct and the synthesizer's three-key override rested on a false verification the cold audit caught (2026-07-31).
- [ADR-0002](ADR-0002-age-enforcement-mechanism.md) — Age enforcement = signup Cloud Function (authoritative) + Firestore rule (gate); CTO ruled security/correctness > cost (2026-06-27).
- [ADR-0001](ADR-0001-minimum-age-floor.md) — Butlery's single minimum age is **15**; escalated to Malin (interpretive Swedish-law split, 13 vs 15) → she chose 15 (2026-06-27).
