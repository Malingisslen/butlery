/**
 * The reset's verification verdict, in its own side-effect-free module so a
 * test can exercise the RULE rather than read the script's source for the word
 * "indeterminate" (BUT-2028).
 *
 * `admin/reset-user-data.ts` runs `main()` at module scope, so nothing in it
 * can be imported. A source check for the string survives every collapse of
 * the three answers into two — the constant map below still spells it — which
 * makes such a check read as guarded while proving nothing.
 */

/** The three answers a verification pass can honestly give. */
export type Verdict = "clean" | "not-clean" | "indeterminate";

/**
 * Exit-code convention, new in this repo (every other `admin/` script is
 * binary). Meant to be reused rather than reinvented:
 *
 *   0  clean          — every probe answered, and answered zero
 *   1  not clean      — a probe found rows, or the kill switch is still set
 *   2  indeterminate  — a probe could not answer, or the run had a soft failure
 *
 * 2 is not a softer 1. It means the script does not know, which is a
 * different instruction to the operator than "there is residue".
 *
 * Neither code means "run it again". Re-running is a full destructive
 * production wipe, and the commonest cause of a 1 — a kill switch left
 * standing — is fixed by deleting one document, not by wiping again. The
 * printed lines say which fault occurred; `docs/ops/reset-user-data-runbook.md`
 * says what to do about each.
 */
export const EXIT_CODE_BY_VERDICT: Record<Verdict, number> = {
  "clean": 0,
  "not-clean": 1,
  "indeterminate": 2,
};

/**
 * Three answers, not two.
 *
 * `reconcileMirrors` gets away with a binary verdict by running every week: a
 * wrong "clean" is corrected seven days later. This script runs once, by hand,
 * against a project whose data is gone — so "there is residue" and "I could
 * not tell" have to stay apart, because they are different instructions.
 *
 * A fact outranks not knowing: rows found is a measurement, and a probe that
 * threw elsewhere does not make it less true.
 */
export function verdictFor(
  sawRows: boolean,
  sawUnanswerable: boolean,
): Verdict {
  if (sawRows) return "not-clean";
  if (sawUnanswerable) return "indeterminate";
  return "clean";
}
