# ADR-0027: Live-menu vote options carry no content filter, and a vote is settled in two writes

- **Date:** 2026-10-09
- **Status:** Decided (CTO priority order)
- **Trigger:** `/mnt/project-files/plans/samarbetsmenyn-plan.md`, section "PR 3" (BUT-2118,
  BUT-2223, BUT-1499 part 2)
- **Blast-radius tier:** full-panel
- **Stakeholders seated:** Security Architect, Privacy/DPO, Database Administrator, Product
  Manager, Trust & Safety, Codebase Archaeologist

## The disagreements
Votes move to one document per person, `realtime_resources/{menuId}/votes/{uid}`.

1. **Free text in an option.** An option is a dish from the proposer's recipes. Trust & Safety
   asked for a content filter, caps and a report path, or a stated exemption.
2. **Settling a vote.** The Database Administrator asked that writing the winner into the menu
   and marking the vote settled be atomic. They are two documents written by two services.

## Decision
1. Decided by the priority order: a stated exemption. An option has the same writers
   (participants with an edit role) and readers (the menu's participants) as `menuSnapshot`,
   which has no filter or report path either; the rules cap each map's size. Recorded as an
   accepted deviation.
2. Decided by the priority order (data integrity): the dish is written first and the vote marked
   settled after. A failed menu write leaves the vote open to settle again; a failed second write
   leaves the dish on the slot and the vote waiting, which settling again repairs.

The locked ballot is not a disagreement: every seated role accepted it as the provisional answer
to produktregler 4.8, with Malin asked to choose between a changeable vote and locked options.

## Stakes (per role)
- **Trust & Safety:** free text another person reads needs a filter or a report path, or a
  written reason it has neither.
- **Database Administrator:** a settled vote with nothing on the slot, or the reverse, is an
  inconsistency people see.

## Consequence
`lib/viewmodels/menu_voting_viewmodel.dart` (`settle`) and
`docs/architecture/ACCEPTED_DEVIATIONS.md` (BUT-2118) carry it.
