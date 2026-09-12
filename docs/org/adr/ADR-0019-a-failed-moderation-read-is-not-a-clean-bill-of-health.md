# ADR-0019: A failed moderation read is not a clean bill of health

- **Date:** 2026-09-12
- **Status:** Decided (synthesizer, reconciliation — both stakes satisfied)
- **Trigger:** the plan for the Art. 12(4) notice delivery
  (`tasks/art12-besked-leverans-plan.md`)
- **Blast-radius tier:** full-panel (`tools/stakeholder_router.py --json` →
  `{"tier": "full-panel", "high_stakes_hits":
  ["lib/services/account/pending_retention_notice_store.dart"]}`)
- **Stakeholders seated:** Privacy / Data Protection Officer (GDPR), Legal Counsel,
  Trust & Safety / Content Moderation, Security Architect, Software Architect,
  Codebase Archaeologist (blindspot pass). Dropped, with reasons, in the review report:
  Data Analyst / BI, Performance Engineer, Financial Controller / FinOps, Monetization,
  Information Architect / Wayfinding, Product Manager, Claude AI-Harness Owner.

## The disagreement

Step 1 of the plan warns a person, before they delete their account, that a moderation
review may exist. The signal is their own `totalReports`, read from
`user_moderation/{uid}` — a read `firestore.rules` already permits to its own subject.
The plan specified `hasBeenReported()` as returning `bool` and **failing silently to
`false`** on any error or denial.

**Trust & Safety asked for that fail-silent behaviour to be kept**, explicitly: a network
or permission error must not surface any moderation-adjacent UI, and the erasure hold is
the real backstop regardless of what the warning shows.

**The Security Architect asked for the opposite property.** The read limb is
`hasOnly(['totalReports','lastReportedAt'])`, which fails CLOSED: the day any writer adds a
field to that document, the read is refused for **every** user, not narrowed. Collapsed
into `false`, that outage is indistinguishable from "this person has never been reported" —
so the warning would stop firing for exactly the people who have an open case, indefinitely,
with nothing reddening. The seat named the precedent already live in this file family:
`isMinorAccount()` deliberately separates `null` (the read failed) from `false` (confirmed
no).

## Decision

**Tri-state internally, silent in the UI, observable in the logs.**

`ReportService` returns a three-valued answer — reported / confirmed-not-reported /
could-not-tell — rather than a `bool`. The UI treats could-not-tell exactly as Trust &
Safety asked: no extra row, no moderation-adjacent text, nothing that turns a transient
error into a disclosure. The difference is that could-not-tell is *recorded* as itself,
so an allowlist mismatch that refuses every read is visible as a failure rather than as a
population with no reports.

Both stakes are satisfied; neither seat is overruled. The conflict was between a UI
property and an observability property that were being carried by one `bool`, and the
resolution is to stop making one value answer two questions.

**Do not "simplify" the tri-state back to a `bool`.** Collapsing it restores precisely the
silent failure this entry exists to prevent, and it will look like tidying: the UI
behaviour is identical in every state a test is likely to stage, because the difference
only appears on a day somebody widens a document in another file.

The Security Architect's second condition rides along: the expected key set for this new
read is bound to the same source of truth as the existing Art. 15 projection and
`rules_allowlist_drift_test.dart`, so a widening is caught mechanically rather than only
degrading this feature quietly. The accepted-deviations record for `user_moderation`
already names a SILENT third drift direction; a second bespoke hand-written copy of that
allowlist, outside the drift test's reach, would have re-opened it.

## Escalated, and decided by Malin the same day

**RESOLVED 2026-09-12 — Malin chose (b): a neutral first line with a "Visa mer" expander.**
The first line says only that a message about a deleted account exists on this device;
everything the Art. 12(4) notice owes — what was kept, why, for how long, and the right to
complain to IMY or go to court — sits behind the expander. She was shown all three options
rendered, the two seats' independent recommendation, and what (b) costs: one extra tap for
the person the notice is actually for.

**What she was NOT shown**, stated because an attribution is a claim about a person no test
can hold: no measurement of how often a Butlery account is used on a shared device, and no
measurement of how many people abandon a notice behind an expander rather than opening it.
Neither is measurable — there are no users. The choice was made on the shape of the trade.

The record of the question as it stood follows.

**What the re-shown notice may disclose on a shared device was Malin's, and it was open.**
When the notice was never acknowledged it is re-shown on the sign-in screen, where the
next person on a family device sees it. It names nobody, but it discloses that the previous
account holder had content under moderation review. Three options were put to her: (a) show
as today, (b) a neutral first line with a "Visa mer" expander, (c) require typing the email
address to expand.

Trust & Safety and Legal Counsel independently recommended **(b)**, and Legal placed it in
its own lane rather than product taste — it is an Art. 5(1)(c) minimisation call, not a
preference. Trust & Safety noted that (a) is the one option repeating a pattern this repo
has rejected in every prior analogous decision: BUT-1917's one-directional ballot strip,
BUT-2054's readable comments, BUT-1904's silent duplicate guard — do not let a safety
mechanism's existence leak to an adjacent party.

It is recorded here rather than in a handoff message because an open question that lives
outside the decision record is invisible to the next grep.

## What the panel added that no single-file review could

- **The Codebase Archaeologist found the defect that would have made the whole mechanism a
  no-op.** The entire outcome-handling block in `auth_action_handler.dart` sits inside one
  `if (context.mounted)` gate. `AccountDeletionService.deleteUserAccount` signs out *inside
  itself* before returning, and `AuthWrapper` rebuilds to the signed-out tree on that — so
  the context can already be dead when the outcome arrives. That is the race the persisted
  notice exists to survive, and the natural reading of the plan ("write before showing the
  dialog") would have put the write inside the gate, where the same race suppresses it.
  The write is now unconditional on `owesRetentionNotice`, outside that gate.
- **The DPO named a residual nobody else saw:** the store holds one slot with no key (no
  key being the correct minimisation call). A second account deleted on the same device
  before the first notice is shown overwrites it, silently and unrecoverably.
- **Legal required the decision record to state what still fails** — uninstall, wipe, new
  device — rather than only that the one-shot problem is diminished, and required a test
  proving the re-shown dialog carries the same four Art. 12(4) elements as the original
  rather than assuming it from "same dialog, different trigger".
- **The Security Architect noted the persisted record is a locally forgeable trigger for a
  legal-sounding notice** — no exfiltration, no action beyond a Close button, but a new
  class of thing this codebase stores unauthenticated-writable, and worth a sentence at the
  code site so a later audit need not rediscover the reasoning.

## Consequences

- The pre-deletion warning over-warns: `totalReports` counts reports, not open cases, so
  someone whose case was closed or dismissed is warned too. Accepted, and it is the price
  of adding no new server surface. An exact answer needs a callable running
  `hasOpenModerationCase`, which is not in this build.
- The warning is a heads-up that could prompt a reported person to act outside the app
  before the hold is placed. The hold itself is unaffected — it is evaluated server-side
  from report status, not from anything the client showed.
- There is no per-person record that anybody received the notice, and there must not be:
  such a record would be new personal data about an erased person, which is the objection
  that sank the email-keyed alternative. The step 3 counters are consent-gated aggregates
  and are an undercount by construction; they must never be described as delivery proof.
