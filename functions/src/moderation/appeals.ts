/**
 * BUT-2353: one appeal per party per decision, in `moderation_appeals`.
 *
 * The document id is `{reportId}_{role}`, so "one appeal" is a create
 * precondition rather than a query. The appeal stores its appellant
 * (`appellantId`) because the report can be deleted while the appellant is
 * still here: the answer, the export and the erasure find the appeal through
 * that field, not through the report. Clients cannot read or write it:
 * `firestore.rules` has no block for it.
 */

import * as admin from "firebase-admin";

export const MODERATION_APPEALS = "moderation_appeals";

/** The appellant's uid on an appeal. Never leaves the server. */
export const APPELLANT_ID = "appellantId";

export const APPEAL_ROLES = ["reporter", "owner"] as const;
export type AppealRole = (typeof APPEAL_ROLES)[number];

export const APPEAL_OUTCOMES = ["upheld", "reversed"] as const;
export type AppealOutcome = (typeof APPEAL_OUTCOMES)[number];
export type AppealStatus = "open" | AppealOutcome;

/** Malin's call, 2026-10-10: an appeal is open for six months. */
export const APPEAL_WINDOW_DAYS = 183;

export const APPEAL_TEXT_MIN = 10;
export const APPEAL_TEXT_MAX = 1000;

const DAY_MS = 24 * 60 * 60 * 1000;

export function isAppealRole(value: unknown): value is AppealRole {
  return (APPEAL_ROLES as readonly unknown[]).includes(value);
}

export function appealId(reportId: string, role: AppealRole): string {
  return `${reportId}_${role}`;
}

export function appealRef(
  db: admin.firestore.Firestore,
  reportId: string,
  role: AppealRole,
): admin.firestore.DocumentReference {
  return db.collection(MODERATION_APPEALS).doc(appealId(reportId, role));
}

export function appealDeadlineFrom(decidedAt: Date): Date {
  return new Date(decidedAt.getTime() + APPEAL_WINDOW_DAYS * DAY_MS);
}

/**
 * A client-supplied id that becomes a document path segment. A bad segment
 * makes the ref builder throw, so it is refused before any read.
 */
export function isSafeDocId(value: unknown): value is string {
  if (typeof value !== "string" || value.length === 0) return false;
  if (Buffer.byteLength(value, "utf8") > 1500) return false;
  if (value.includes("/")) return false;
  if (value === "." || value === "..") return false;
  return !/^__.*__$/.test(value);
}

/**
 * Whether [reportId] can carry an appeal for [role]. A report id near the
 * 1500-byte limit cannot: the suffix pushes the appeal id past it.
 */
export function canHoldAppeal(reportId: string, role: AppealRole): boolean {
  return isSafeDocId(appealId(reportId, role));
}

/**
 * The [role] appeals on [reportIds], keyed by report id. A report id that
 * cannot hold an appeal is skipped rather than read.
 */
export async function readAppeals(
  db: admin.firestore.Firestore,
  reportIds: string[],
  role: AppealRole,
  fieldMask: string[],
): Promise<Map<string, admin.firestore.DocumentSnapshot>> {
  const ids = reportIds.filter((id) => canHoldAppeal(id, role));
  if (ids.length === 0) return new Map();
  const snaps = await db.getAll(...ids.map((id) => appealRef(db, id, role)), { fieldMask });
  return new Map(ids.map((id, i) => [id, snaps[i]]));
}

/** The appellant the report names for [role], or null once it names nobody. */
export function appellantOf(
  report: admin.firestore.DocumentData | undefined,
  role: AppealRole,
): string | null {
  const uid = role === "reporter" ? report?.reporterId : report?.contentOwnerId;
  return typeof uid === "string" && uid.length > 0 ? uid : null;
}
