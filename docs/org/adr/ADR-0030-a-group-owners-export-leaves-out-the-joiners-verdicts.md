# ADR-0030: A group owner's export leaves out the joiners' verdicts

- **Date:** 2026-10-20
- **Status:** Decided (CTO priority order)
- **Trigger:** BUT-2414 part 2, Malin's card "Behåll koden": a sole remaining member's household
  export shows everything account deletion removes
- **Blast-radius tier:** full-panel
- **Stakeholders seated:** Privacy / Data Protection Officer (GDPR), Legal Counsel, Security
  Architect, Software Architect, Codebase Archaeologist

## The disagreement

`deleteFamilyData` tears a household down in two cases: no member remains, or the erased user
created it from their own group (`ownsGroupLink`) while joiners remain. The DPO asked the export
to mirror both cases, so the export shows all the erasure deletes. Legal Counsel and the Security
Architect asked that the second case is not widened, because the joiners are living members and
their private verdicts are their data (Art. 15(4)).

## Decision

The export widens only for the sole remaining member (`memberUserIds == [uid]`). A group owner
with joiners keeps the section the code already ships: every diner profile in the household and
the verdicts that are theirs or that they entered. The joiners' verdicts, which the teardown
deletes, are not exported to the owner, and the deviation line says so. Decided by the priority
order: user safety and trust, then legal and privacy, over completeness of the mirror.

## Stakes (per role)

- **Privacy / DPO:** an export that shows less than the erasure deletes reads as incomplete under
  Art. 15(1); asked for an exact mirror or a recorded gap. The recorded gap answers it.
- **Legal Counsel:** either mirror or document; do not claim "everything the erasure deletes".
- **Security Architect:** handing other adults' private data to one adult must fail closed.
- **Software Architect:** one named predicate, cited against `family.ts`, with a test per branch.
