# ADR-0017: withholding a subject's own moderation count from the Art. 15 export

- **Date:** 2026-09-08
- **Status:** SUPERSEDED the same day — Malin reversed it, 2026-09-08. The count IS exported.
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
  **Measured false on 2026-09-08 by the `firestore-rules-tester` gate, and it matters:** on a
  document the BUT-2046 migration has not moved, the identities are ALSO on the parent, in the
  legacy `reportHistory` array. Seeded on the emulator, an owner read returned
  `[{"reportId":"r1","reporterId":"…","reason":"spam"}]`. The two are separable only after that
  migration, so an un-migrated document is denied whole. Recorded here because this seat's sentence is what the
  first version of the rules comment rested on.
- **Codebase Archaeologist:** confirmed the entry cannot live in `EXPORT_EXEMPT`, which is
  scoped to `users/{uid}` subcollections — so both halves are prose in the deviations files,
  where a merge back into one sentence is easy and unguarded.

## Superseded, 2026-09-08, hours after it was decided

**Malin reversed this: the count is exported.** She asked why open items were being
left behind, which sent me to look up the thing this record says nobody looked up —
"She was NOT shown any authority for or against the restriction under Swedish
implementing law; nobody looked one up."

What the search found: withholding a subject's own data because disclosing it would
undermine an ongoing process is an Art. 23 restriction, and Art. 23 requires a
legislative measure. None was found. So the ground this ADR records her choosing does
not stand on anything, and she chose again with that stated.

Art. 15(4) still carries the other half, and that half is unchanged: the REPORTERS'
identities stay withheld. What ships is `totalReports` and `lastReportedAt`, projected
through an allowlist, plus a `data_minimisation` line telling the reader that who
reported them is deliberately not included.

The DPO seat's original finding was therefore right twice: the single justification
covered only half the collection, and the half it did not cover could not be repaired
by writing it down more carefully.

## Consequence

The deviations entry states both grounds separately and labels the second as weaker. They must
not be merged back into one sentence — that merge is the defect this record exists to prevent,
and it is the same shape as the cross-collection analogies `.claude/rules/accepted-deviations.md`
already warns about.

Open, and not decided here: whether the restriction on the count survives contact with an
actual legal source. Revisit if the app goes live or if a supervisory question is ever raised.

**SUPERSEDED the same day by the reversal recorded above.** Both sentences in this section are
retired. "Open, and not decided here: whether the restriction on the count survives contact with
an actual legal source" — it did not: a search found no legislative measure, which is what
Art. 23 requires, and that is why the count is exported. And "The deviations entry states both
grounds separately and labels the second as weaker … They must not be merged back into one
sentence" — there is no second ground left to keep separate; the entry now records one
withholding, the reporters' identities, on Art. 15(4). What the CODE does: the export ships
`totalReports` and `lastReportedAt` through an allowlist, and `firestore.rules` gates the read
on that same key set.

Advisory only. Malin decided.
