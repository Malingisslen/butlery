# ADR-0017: withholding a subject's own moderation count from the Art. 15 export

- **Date:** 2026-09-08
- **Status:** Escalated to Malin → **withhold the count too** (her choice, 2026-09-08)
- **Trigger:** `tasks/todo.md` — BUT-2046, moving `reportHistory` to a subcollection and making account deletion reach it
- **Blast-radius tier:** full-panel (reduced to three seats with genuine new stake)
- **Stakeholders seated:** Privacy/DPO, Database Administrator, Codebase Archaeologist

## The disagreement

Malin had already decided (BUT-2046 Q&A) that the whole `user_moderation` collection stays
out of the Art. 15 export. The reason she was given was a single one: Art. 15(4) protects the
reporters, and disclosing the count tells a reported person that review is under way.

**The DPO seat showed that reason covers only half the collection.** The reporters'
identities in `report_history` are third-party data and Art. 15(4) is squarely on point. But
`totalReports` and `lastReportedAt` are the requester's **own** aggregate about themselves.
Art. 15(4) does not authorise withholding a subject's own data from them; the
"it discloses that moderation is underway" argument is a different claim, closer to a national
Art. 23 restriction, and nothing in this repo establishes a basis for it.

The seat's recommendation was to split the entry in two and either argue the second half
explicitly or reverse it and export the count.

## Decision

**Escalated, because it is legal-interpretive.** Put to Malin the same day with both options.

**Her choice: withhold the count as well**, with its own written ground — that handing a
reported person a live count of reports against them invites account-switching and undermines
the moderation the count exists to drive.

**Recorded as the weaker of the two positions, deliberately.** She was told that Art. 15(4)
does not carry this half, that the ground she is relying on is not established anywhere in
this repo, and that exporting the count alone was the alternative. She was NOT shown any
authority for or against the restriction under Swedish implementing law; nobody looked one up.

## Stakes (per role)

- **Privacy / DPO:** a single justification presented as covering two different kinds of data
  is how an exemption reads as settled when half of it is not. Protecting against an export
  gap that a future reader believes was reasoned.
- **DBA:** no stake in the split; flagged only that the count lives on the parent document and
  the identities beneath it, so the two are separable at no cost.
- **Codebase Archaeologist:** confirmed the entry cannot live in `EXPORT_EXEMPT`, which is
  scoped to `users/{uid}` subcollections — so both halves are prose in the deviations files,
  where a merge back into one sentence is easy and unguarded.

## Consequence

The deviations entry states both grounds separately and labels the second as weaker. They must
not be merged back into one sentence — that merge is the defect this record exists to prevent,
and it is the same shape as the cross-collection analogies `.claude/rules/accepted-deviations.md`
already warns about.

Open, and not decided here: whether the restriction on the count survives contact with an
actual legal source. Revisit if the app goes live or if a supervisory question is ever raised.

Advisory only. Malin decided.
