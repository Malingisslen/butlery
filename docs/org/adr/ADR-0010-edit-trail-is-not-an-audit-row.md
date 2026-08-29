# ADR-0010: the edit trail is not the audit row it was chosen instead of — both ship

- **Date:** 2026-08-29
- **Status:** Escalated to Malin → both mechanisms ship
- **Trigger:** `tasks/but-1971-proveniens-plan.md` (BUT-1971 provenance build: per-entry
  provenance on the weekly menu + an append-only edit trail on the group plan)
- **Blast-radius tier:** full-panel
- **Stakeholders seated:** Privacy / DPO, Security Architect, Database Administrator /
  Data-layer Engineer, Legal Counsel, Software Architect, Codebase Archaeologist
  (dropped, with reasons: FinOps — the change adds no read or write per view and the
  document-size question is seated on the DBA; Trust & Safety — no moderation or
  minor-safety surface; Support/Ops — no support-facing flow changes; Vendor — no vendor
  change; Product Manager — every product question here had already been decided by the
  founder before the panel convened)

## The disagreement

Not role against role. Every seated role returned `approve-with-conditions` and none
contradicted another. The disagreement was between the **panel's measurements and the
premise of a decision the founder had already made.**

On 2026-08-29, under BUT-1981/BUT-1971, Malin was asked whether to restore the granted
audit row on the group weekly-menu repository. She chose an alternative named beside it: an
append-only trail on the plan document, on the stated grounds that it *"buys the same
attribution with no second write"*. That sentence is recorded in
`.claude/rules/accepted-deviations.md`.

Two roles independently refuted it, from different stakes:

- **Security Architect:** the trail as designed is written by the CLIENT, and `entries`
  is not validated element-wise (and, per the same plan, will not be). Any group editor can
  write `{actorId: <another member's uid>, action: 'removed'}` and point at a groupmate for
  an edit they never made. The abandoned granted-audit row stamped the AUTHENTICATED actor
  and could not be forged by the caller. The trail is therefore not equivalent on the one
  axis that made the old mechanism trustworthy.
- **Database Administrator:** `FirebaseGroupWeeklyMenuPlanRepository.save` writes the whole
  document with `set()`. Two legitimate editors on the same week means the later writer
  silently discards the earlier one's trail row along with everything else. A genuine row
  can be lost — under precisely the multi-editor scenario that motivated building the trail
  at all.

So the trail is neither reliably truthful nor reliably complete, and the decision to
prefer it over the audit row rested on it being both.

## Decision

**Escalated to Malin → she chose to build BOTH.** Shown the two findings and three options
(accept the trail as a soft convenience and write down the residuals; add the
server-verified audit row alongside it; or defer the trail entirely), she chose the second:
*"spåret visas, revisionsraden bevisar."*

Consequently:

- `logPermissionCheck` is called again on the GRANTED branch of
  `FirebaseGroupWeeklyMenuPlanRepository.save` — **on the group repository only.** The
  per-user repository keeps BUT-1981's reduction unchanged: its gate is a tautology that
  never recorded a decision which could have gone the other way, and nothing in this ADR
  disturbs that half.
- Cost: roughly one extra write per interactive removal or undo. Not per view, not per
  read. That is the cost Malin weighed.
- This **supersedes** the BUT-1981/BUT-1971 entry's "RESOLVED — build an EDIT TRAIL
  instead" clause. The old entry is superseded with a date and a reason, never struck: the
  house rule on decision records is that a stale entry is superseded, not deleted.

A second escalation was resolved in the same sitting. Legal Counsel showed that filtering
the trail export to `actorId == requester` passes rows the requester ACTED on but drops
rows where someone acted ON them — if another member removes the requester's dish, that row
concerns the requester and would not reach their Art. 15 export; worse, the trail schema as
planned could not even identify such a row. **Malin chose to include rows where the
requester is the subject.** The trail row therefore gains `subjectId` and `entryId`.

## Stakes (per role)

- **Security Architect** — protecting against a group member being framed for an edit they
  did not make. Also required the 50-row cap on the `create` limb, not `update` alone, and
  a written type gap for a non-list `editTrail`.
- **Database Administrator** — protecting the trail from claiming a durability the storage
  shape cannot give. Confirmed the embedded capped list is the right shape for a
  `set()`-based repository (a subcollection would cost exactly the extra write the design
  avoids), and that the deletion cascade's scrub fits the existing chunked batch without
  new machinery.
- **Privacy / DPO** — protecting Art. 17. Found the single largest defect in the plan: a
  proposer uid stored inline in `metadata.poll.options[]` is structurally unerasable,
  the exact bug class BUT-1832/1835 already paid to fix by moving `voterIds` out to a
  `poll_votes` subcollection. The plan had not mentioned the `messages` collection at all.
- **Legal Counsel** — protecting against Art. 15 under-disclosure, and against the two new
  deviation entries being written as derived from BUT-1732/1772/1774 rather than on their
  own merits.
- **Software Architect** — protecting the window between the field shipping and the rules
  cap deploying, since a `.dart` diff and a `firestore.rules` diff route to different
  commit gates.
- **Codebase Archaeologist** — found that `GroupWeeklyMenuViewModel.undoLastRemoval`
  bypasses every service mutator the plan intended to instrument, so an `undone` row would
  never have appeared; and that a trail append placed above a mutator's no-op early-return
  would defeat the save-skip the screen relies on.

## Consequence

Advisory only — Malin decided, and the build proceeds under the plan's revised acceptance
criteria. What follows if Butlery proceeds:

- The group weekly-menu plan carries a 50-row edit trail AND the group repository writes a
  granted audit row. Two mechanisms, two purposes, both documented as such: the trail is a
  readable history, the audit row is the record that can be relied on.
- Poll provenance must be redesigned before any code ships, so it lands somewhere the
  deletion cascade can query.
- Seven decision-record entries are owed in both deviation files, including one naming an
  open question the founder has NOT answered: a member who leaves a group without deleting
  their account keeps their uid on the plan's entries and in the trail indefinitely, and no
  cascade touches it.
