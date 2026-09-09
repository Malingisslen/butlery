# ADR-0015: `user_moderation` stays out of BUT-2032

- **Date:** 2026-09-08
- **Status:** Decided (CTO priority order)
- **Trigger:** `tasks/todo.md` — BUT-2032, make the account-deletion cascade reach `system_events`
- **Blast-radius tier:** full-panel
- **Stakeholders seated:** Privacy/DPO, Trust & Safety, Security Architect, DBA/Data-layer, QA, Codebase Archaeologist

## The disagreement

Investigating BUT-2032 surfaced a sibling gap: `user_moderation/{contentOwnerId}` keys its
document id on the reported person's uid and carries `reportHistory`, an array of maps each
holding a `reporterId` — other people's uids. No cascade leg, no probe, no trigger, no
export reaches it. It is written by the same trigger, in the same transaction, about the
same event as the `system_events` rows this ticket covers.

The plan recommended folding it in, on the ground that deciding one and leaving the other
means two decisions about one fact — the drift pattern this repo has paid for repeatedly.

**Trust & Safety objected.** `reportHistory` is the only data that survives the *reporter's*
own erasure and can answer whether one account repeatedly reports the same target.
(`reports` also carries `reporterId`, but `deleteUserReports` hard-deletes those rows when
the reporter erases — measured.) Stripping `reporterId` from the array on GDPR symmetry
grounds would destroy Butlery's only signal against coordinated or abusive reporting, with
nothing built to replace it, as a side effect of tidying two collections that happen to
share a trigger.

The DPO and Security seats did not take the opposite side; both asked only that the gap get
a recorded decision and a tracked ticket rather than remaining an informal note.

## Decision

**`user_moderation` is out of scope for BUT-2032, and gets its own ticket with a dedicated
Trust & Safety review before any `reporterId` is stripped.** Filed as **BUT-2046**, which
carries the measurements and the transactional precondition below.

Decided by the priority order — user-safety & trust sits above the data-integrity argument
for a shared truth that motivated the fold-in. Consistency between two collections is worth
less than the one signal the platform has against report-brigading.

## Stakes (per role)

- **Trust & Safety:** DSA Art. 23 expects a platform to identify users who repeatedly file
  abusive notices. Butlery has no reporter-side counterpart to the content-owner strike
  counter; `reportHistory` is the closest thing. Protecting against losing it silently.
- **Privacy / DPO:** the gap is a real Art. 17 residual and must not be lost — a plan
  paragraph is not the backlog. Protecting against BUT-2032 closing while the larger hole
  stays untracked.
- **Security Architect:** wants a dated record naming an owner rather than an open note.
- **DBA:** if it is ever built, the array rewrite must read `reportHistory` inside the same
  transaction that writes it, with contention retry — the live writer uses `arrayUnion`
  inside its own transaction, and a `get()` followed by a later `update()` silently drops a
  report that lands in between.

## Consequence

BUT-2032 covers `system_events` only. `user_moderation` remains a named, unclosed residual
with a ticket and an owner, and its erasure design is a Trust & Safety question before it is
a GDPR one. The DBA condition above is a precondition on that future build, recorded here so
it is not rediscovered during implementation.

Advisory only. Malin decides whether BUT-2032 proceeds at all.

---

## SUPERSEDED IN PART — 2026-09-09 (BUT-2046 follow-up)

What this record says, quoted so a grep returns both: *"DSA Art. 23 expects a platform to
identify users who repeatedly file"*. DSA Art. 23 sits in Section 3, which Art. 19 DOES
exempt micro and small enterprises from — so it does not bind Butlery, and the Trust &
Safety seat's legal half fell away.

What the CODE does now: the brigading signal was not built, `reportHistory` is a
`report_history` subcollection with a 180-day TTL that the cascade erases, and a legal hold
under GDPR Art. 17(3)(e) keeps an open case's evidence past the reported person's erasure.

The decision this record argued for is unchanged; the argument it rests on is not the one
it states. Nothing above is edited.
