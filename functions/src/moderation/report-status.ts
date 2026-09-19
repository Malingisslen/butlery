/**
 * Report status, for both directions of an erasure: the legal hold over the
 * REPORTED person (`erasure-hold.ts`) and the anonymize-instead-of-delete rule
 * for the REPORTER (`account-deletion-cascade.ts`, `reporter-retention.ts`).
 * The cascade cannot import `erasure-hold.ts`, which imports the cascade, so
 * this lives where neither owns it.
 */

/**
 * Every status that is NOT terminal. `closed` is the only finished one —
 * `actioned` reads as done and is deliberately still open: a case a moderator
 * has acted on but not closed keeps its evidence until they close it.
 *
 * An `in` filter over this list, rather than `!=`, is what keeps
 * `hasOpenModerationCase` servable by the single-field indexes.
 */
export const OPEN_REPORT_STATUSES = ["new", "in_review", "actioned"] as const;

/**
 * True only for the exact terminal status. A missing or unrecognised status
 * reads as OPEN, because the two answers do not cost the same: treating an open
 * case as closed destroys its evidence, treating a closed one as open keeps the
 * report until `REPORTER_RETENTION_DAYS` runs out.
 */
export function isClosedReportStatus(status: unknown): boolean {
  return status === "closed";
}

/**
 * The outer cap on keeping a report whose REPORTER has erased their account,
 * counted from that erasure. Malin's call, 2026-09-18: the report is deleted
 * when its case closes, and at the latest after this many days.
 *
 * Its own constant rather than `ERASURE_HOLD_MAX_DAYS`: the two retentions rest
 * on different grounds and about different people, and one number behind two
 * purposes is how it gets changed for the wrong reason.
 */
export const REPORTER_RETENTION_DAYS = 180;

/**
 * The article the reporter-side retention rests on: the obligation to process
 * a notice diligently (DSA Art. 16(6)) is a legal obligation, which is what
 * GDPR Art. 17(3)(b) excepts.
 */
export const REPORTER_RETENTION_BASIS = "GDPR Art. 17(3)(b)";

/**
 * The `resourceType` a reporter-side `RetainedRecord` carries. The client tells
 * the two kinds of notice apart on this value.
 */
export const REPORTS = "reports";
