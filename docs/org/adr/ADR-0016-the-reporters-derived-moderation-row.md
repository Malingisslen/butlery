# ADR-0016: the reporter's derived moderation row — delete or anonymize

- **Date:** 2026-09-08
- **Status:** Escalated to Malin → **DELETE** (her choice, 2026-09-08)
- **Trigger:** `tasks/todo.md` — BUT-2032, make the account-deletion cascade reach `system_events`
- **Blast-radius tier:** full-panel
- **Stakeholders seated:** Privacy/DPO, Trust & Safety, Security Architect, DBA/Data-layer, QA, Codebase Archaeologist

## The disagreement

When the person who FILED a report erases their account, what happens to the derived
`system_events/content_report_<reportId>` row that names them in `details.reporterId`?

The row also names the reported person in `details.contentOwnerId`, so it is not purely the
reporter's own data.

**The plan proposed: delete the row.** A derived copy should not outlive its source, and the
source — the `reports` document — is already hard-deleted on the reporter's erasure by
`deleteUserReports`. Any other answer creates a third policy for one event.

**Trust & Safety proposed: anonymize instead** — null `details.reporterId`, keep the row.
The content-owner side of this same ticket keeps its row (mirroring BUT-781) precisely so
moderation history survives; the reporter side deserves the same standard. Under deletion, an
admin later reviewing an old `moderation_threshold_reached` alert cannot see that a report
existed there at all, not merely who filed it.

T&S also measured that this is not a new evasion hole: the reporter's `reports` rows are
already hard-deleted today, so BUT-2032 extends an existing precedent to a derived copy
rather than opening anything. The real anti-brigading gap is `user_moderation` (ADR-0015).

## Decision

Escalated rather than resolved by the panel: the conflict pits user-safety and audit
continuity against a privacy-and-consistency argument, both top-tier stakes, and the
resolution changes what a still-present reported user's history looks like.

**Malin's explicit call, 2026-09-08: DELETE the row.** She was shown both options and the
cost of each as stated below — including that an admin reviewing an old
`moderation_threshold_reached` alert will not be able to see that a report existed there at
all, which is the exact loss Trust & Safety's alternative was protecting against. She was
NOT shown any measurement of how often a reporter erases an account with live reports
outstanding; nobody has counted it, and the app is not live.

The condition T&S attached to this outcome rides along: the moderation-runbook rewrite must
say plainly that a filed report's trace disappears entirely when its reporter erases, so a
future admin is not misled by silence.

The corresponding entry is written into `.claude/rules/accepted-deviations.md` and
`docs/architecture/ACCEPTED_DEVIATIONS.md` in the same edit as the code.

## Stakes (per role)

- **Trust & Safety:** audit continuity. A moderator must be able to see that a report was
  filed, even when the filer is gone. Risk: silent gaps in the moderation record.
- **Privacy / DPO:** the reporter's identifier must not survive their erasure either way; the
  question is only whether the surrounding row does. Warned against shipping the plan's
  recommendation as a stand-in for Malin's decision.
- **Security Architect:** either answer is implementable; wants whichever is chosen recorded
  rather than inferred from the sibling collection's behaviour.

## Consequence — what follows from each choice

- **Delete:** consistent with `deleteUserReports`; one policy per actor rather than three.
  The moderation-runbook rewrite must then state plainly that a filed report's trace can
  disappear entirely when its reporter erases, so a future admin is not misled by silence.
- **Anonymize:** the row survives with a nulled `reporterId` and an
  `anonymizedAt`-style tombstone, symmetric with the content-owner half. Costs one more
  divergence from the source `reports` row, which is still hard-deleted — the derived copy
  would then outlive its source, which is the thing the plan's argument objected to.

Advisory only. Malin decides.
