# ADR-0024: A restorable version past 30 days stays hidden until its next write

- **Date:** 2026-10-08
- **Status:** Escalated to Malin → decided
- **Trigger:** `/mnt/project-files/plans/but-2140-aterstall-plan.md` (BUT-2140, Återställ in the
  shopping list and the pantry), question 2
- **Blast-radius tier:** full-panel
- **Stakeholders seated:** the panel listed in the plan's "Panelen" section

## The disagreement
Firestore TTL deletes whole documents, never single fields, and the earlier versions live inline:
`previous` on a shopping row, `recentlyRemoved` on a shopping list, `previous` on a pantry item.
An entry older than 30 days is never offered for restore, but it is only removed when that
document is written again.

- **Privacy:** an entry the user can no longer see should not outlive the 30 days the product
  promises for restore.
- **Cost:** removing it on time needs a nightly job that reads every list and pantry item.

## Decision
Escalated to Malin, who decided on 2026-10-08 (the recommended option, "Ja"): an older version
may stay in the document, unshown, after 30 days until the next write that replaces or prunes
it, or until the item, list or account is deleted. It is part of the Art. 15 export while it
stays. There is no nightly job.

On the same day she also decided that rows cleared with "Rensa klart" are not kept for restore.

## Stakes (per role)
- **Privacy:** the data is the user's own or their household's list, already visible to the
  same people before; it is exported and erased with the document.
- **Cost:** no reads beyond what each write already makes.

## Where it is recorded
`docs/architecture/ACCEPTED_DEVIATIONS.md` (the pantry section and the shopping entry beside it),
`.claude/rules/accepted-deviations-pantry.md` and `.claude/rules/accepted-deviations-areas.md`.
