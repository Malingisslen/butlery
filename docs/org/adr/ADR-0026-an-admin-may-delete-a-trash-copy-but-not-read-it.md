# ADR-0026: An admin may delete a recipe's trash copy but not read it

- **Date:** 2026-10-09
- **Status:** Decided (CTO priority order)
- **Trigger:** `/mnt/project-files/plans/but-907-plan.md` (BUT-907 step 1, the trash for deleted
  recipes), section 11
- **Blast-radius tier:** full-panel
- **Stakeholders seated:** Privacy/DPO, Security Architect, Database Administrator, Trust & Safety,
  Software Architect, Codebase Archaeologist

## The disagreement
A deleted recipe is kept as a copy in `users/{uid}/trash/{recipeId}` for 30 days so its owner can
restore it.

- **Database Administrator:** only the owner should be able to delete a copy, the same as reading
  it; left the call to Trust & Safety.
- **Trust & Safety:** an owner who deletes a reported recipe before the review must not be able
  to restore it afterwards. A recipe with an open report skips the trash, but a report filed after
  the owner's delete would find nothing live to remove, so the moderator needs to delete the copy
  as a fallback.

## Decision
Decided by the priority order: user safety before data integrity. The trash rule allows delete for
the owner or an admin, and read for the owner only. `deleteReportedContent` deletes the live recipe
and the trash copy in one batch.

## Stakes (per role)
- **Database Administrator:** one more writer on a user's private subcollection.
- **Trust & Safety:** a reported recipe must not come back through the trash.
- **Privacy/DPO:** an admin never reads the owner's deleted recipes; the delete needs no read.

## Consequence
`firestore.rules` (the `trash` block), `lib/services/moderation/report_service.dart` and
`docs/ops/moderation-runbook.md` carry it.
