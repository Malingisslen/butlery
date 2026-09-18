# ADR-0021: The group-menu erasure handle stays out of the Art. 15 bundle

- **Date:** 2026-09-17
- **Status:** Escalated to Malin → decided
- **Trigger:** `tasks/todo.md` — the four open Art. 15
  withholding questions (BUT-1838, BUT-1971, BUT-2028, BUT-1716)
- **Blast-radius tier:** full-panel
- **Stakeholders seated:** Privacy / Data Protection Officer (GDPR), Legal Counsel, Security
  Architect, UX Writer / Content Strategist, Technical Writer / Documentation, Codebase
  Archaeologist, plus a cold plan audit

## The disagreement

She answered all four in one sitting. One — `contributorUserIds` on the group
weekly menu plan — she answered KEEP, which would have been the only row in the batch to WIDEN
third-party data in a bundle the requester can forward.

The panel was convened on that keep and did not dispute her authority to make it. It disputed the
price she had been quoted.

- **Privacy / DPO:** the field unions the WHOLE roster since BUT-1971, so it accumulates uids of
  people who have LEFT and of PASSIVE participants who never proposed, voted or edited. For a
  passive leaver it becomes the only surviving record that they were ever on that week. No widget
  renders it. Conditioned approval on the record naming that residual and leaving BUT-2006 question
  1 open.
- **Security Architect:** measured that the field is CLIENT-written and that
  `groupMenuKeepsContributorTrail` enforces only append-only writes plus a 200 cap — nothing
  verifies that a uid was ever a participant. `public_profiles/{uid}` is
  `allow read: if isAuthenticated()`, so any signed-in account resolves a uid to that profile.
- **Legal Counsel:** the Art. 15(4) balance needs an actual weighing, not a bare founder
  preference, and asked whether a minor's uid can be in the field — which changes the weight on the
  other side.
- **Technical Writer:** found the plan's verbatim supersession quotes wrong or missing; the
  two mirror files are worded differently and each must retire its own copy.
- **Codebase Archaeologist:** no reverted history — the strip was introduced once (`6039d86e1`) and
  never touched. Flagged the `workflow-map.stale` step the plan had omitted.

## Decision

Escalated to Malin, who **reversed her own answer** on 2026-09-17 after being shown the three
measurements the original question had not carried: the field is client-written and unverified, any
signed-in account resolves a uid to a profile, and a minor's uid can be in it
(`MessagingService._prepareWinnerForGroupPlan` seeds the roster from `conversation.participantIds`).

Offered three ways out — stand fast, keep the field filtered to her own uid, or keep stripping — she
chose **keep stripping**. `_redactGroupPlan` is unchanged; no production behaviour changes.

Row 4 was likewise re-asked and deferred to BUT-1747 once it was measured that a client cannot read
`shared_content/{id}/items` at all (BUT-1716 step 3 removed the rules block; the terminal
`match /{document=**}` denies every client, and the export runs on the client SDK).

## Stakes (per role)

- **Privacy / DPO:** a durable record that a passive participant existed, in a forwardable file.
- **Security Architect:** an unverified, client-written array becoming machine-readable and
  name-resolvable for every current member.
- **Legal Counsel:** Art. 15(4) — the right to a copy may not adversely affect others' rights; a
  minor's uid weighs more heavily on that side.
- **UX Writer:** a bundle that misdescribes itself is its own Art. 12(1) defect.
- **Technical Writer:** a half-done supersession leaves the paper trail arguing both ways.
- **Codebase Archaeologist:** a plan repeating a prior failed attempt; none found here.

## Consequence

All four withholdings stand and are now decisions rather than inherited conservative choices. BUT-1747 is a pre-launch gate carrying two
gaps. BUT-2006 question 1 — whether the field should union passive participants at all — is
untouched and still Malin's.

The pricing failure is the lesson worth keeping: her first answer was given on an incomplete
question, and the correct move was to return to her with the measurement rather than build what she
had said yes to. Advisory only.

**Superseded in part, 2026-09-18.** BUT-2006 question 1 is answered: `contributorUserIds` now records
uids that left a trace on the week (Malin's call). Retired: "BUT-2006 question 1 — whether the
field should union passive participants at all — is untouched and still Malin's." The decision is
recorded in the 2026-09-18 entry of `.claude/rules/accepted-deviations.md`.
