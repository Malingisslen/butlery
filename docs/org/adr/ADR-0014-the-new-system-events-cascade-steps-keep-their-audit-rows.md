# ADR-0014: the new `system_events` cascade steps keep their audit rows

- **Date:** 2026-09-08
- **Status:** Decided (CTO priority order)
- **Trigger:** `tasks/todo.md` — BUT-2032, make the account-deletion cascade reach `system_events`
- **Blast-radius tier:** full-panel
- **Stakeholders seated:** Privacy/DPO, Trust & Safety, Security Architect, DBA/Data-layer, QA, Codebase Archaeologist

## The disagreement

The plan places both new steps (delete `moderation_threshold_<uid>`; anonymize
`content_report_*` rows) in `account-deletion-cascade.ts` rather than in the
`onUserDeleted` trigger, because `probeResidualData` runs BEFORE `auth.deleteUser` and a
trigger-owned step would make every such erasure report `gdprCompliant: false` (the
BUT-2044 defect). Nobody disputed that placement.

What was disputed is what the placement costs. The cascade has **no**
`stageCascadeAuditEntry` call sites; `on-user-deleted.ts` has twelve. The plan accepted
that reduction and argued it "mirrors BUT-781".

The Security Architect seat refuted the argument rather than the placement: BUT-781's
`anonymizeReportsByContentOwner` runs in the TRIGGER, where it *does* stage a per-row
audit entry naming the counterparty. So the mirror covers the action and not the record.
The DPO seat reached the same conclusion from Art. 5(2) accountability, and cited
BUT-1981 as this repo's own precedent that an audit-row reduction is a decision somebody
makes, not a side effect.

## Decision

**Do not reduce.** The two new cascade steps stage their own audit entries, mirroring
`anonymizeReportsByContentOwner`'s pattern.

Decided by the priority order — data-integrity & security above cost. The cost is roughly
one extra write per mutated row, on a path that runs once per account, ever. No seat
argued the cost was material; the plan had simply inherited the reduction from an analogy
that does not carry it.

## Stakes (per role)

- **Security Architect:** an unaudited mutation of a row naming a third party leaves no
  record of who was erased from what. Protecting against a deletion whose only evidence is
  the summary envelope.
- **Privacy / DPO:** Art. 5(2) — accountability for processing, including erasure, and the
  repo's own BUT-1981 precedent that this trade gets decided explicitly.
- **DBA:** no objection; the write volume is negligible beside the sweep itself.

## Consequence

BUT-2032 ships with `stageCascadeAuditEntry` on both new steps. This is the first audit
staging in `account-deletion-cascade.ts`, so the helper's usability from the cascade's
chunking path (`commitInChunks` / `batchDeleteAll`) is a build-time detail the
implementer must confirm rather than assume — the helper takes `(db, batch, {...})`, and
the cascade's batches are created inside those helpers.

Advisory only. Malin decides whether BUT-2032 proceeds at all.
