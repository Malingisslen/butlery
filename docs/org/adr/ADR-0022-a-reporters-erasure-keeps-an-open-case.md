# ADR-0022: a reporter's erasure keeps an open case — without their name, with their words

- **Date:** 2026-09-18
- **Status:** Escalated to Malin → **keep the report, drop the reporter's uid, keep the free
  text; delete on close, at the latest after 180 days** (her choices, 2026-09-18)
- **Trigger:** `tasks/todo.md` — a REPORTER's account deletion emptied an open moderation case
- **Blast-radius tier:** full-panel
- **Stakeholders seated:** Privacy/DPO, Legal Counsel, Trust & Safety, Security Architect,
  DBA/Data-layer, Codebase Archaeologist. Dropped: Financial Controller and Vendor (no cost or
  vendor surface), Product Manager and Software Architect (no new component, only the behaviour
  of existing cascade steps).

## The disagreement

The plan kept an open case's report when its reporter erased, removing both `reporterId` and
the reporter's free text (`description`).

**Trust & Safety objected to removing `description`:** beyond the `reason` enum it is often the
only thing that makes a case decidable, and "written by the reporter" is not the same as "about
the reporter".

**Privacy/DPO held** that what remains after the uid goes may still single the reporter out in
a small friend group (the content, the time, the free text), in which case it is retained
personal data and an Art. 12(4) notice is owed — a determination the plan had asserted away.

**Legal Counsel** asked for a separate, explicit answer on one residual: once the reporter's
identity is gone, the reported person can no longer learn who reported them, e.g. to pursue a
bad-faith report.

## Decision

Escalated: user-safety against privacy, both top-tier, and the singling-out question is
interpretive.

**Malin's explicit calls, 2026-09-18:** keep `description`; yes to the Legal residual; treat the
remainder as capable of singling the reporter out, so the reporter gets the Art. 12(4) notice;
and — asked again because the first two answers falsified the premise of "keep it anonymously
after close" — delete the report and its derived rows when the case closes, at the latest 180
days after the erasure.

She was NOT shown any count of reporters who erase with a case open; there are no users.

## Consequence

- The reporter side now has a retention, a notice, and a daily sweep
  (`sweepRetainedReporterReports`) that ends it.
- ADR-0016 is superseded for OPEN cases; a closed case's row is still deleted.
- The legal basis for the reporter side, GDPR Art. 17(3)(b), was chosen without asking Malin.
- **2026-09-19:** Malin approved GDPR Art. 17(3)(b) as that basis.

Advisory record. Malin decided.
