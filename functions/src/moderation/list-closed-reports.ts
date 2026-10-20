/**
 * BUT-1528: the moderator's list of decided reports, newest decision first.
 *
 * Admin only. Malin's call, 2026-10-20: a row shows the decision, the rule,
 * the time and the moderator — what `moderation_decisions` keeps — and never
 * the reported text, the reporter or the reported person.
 *
 * Read from the decision records rather than from `reports`, so a report the
 * reporter-retention sweep has deleted still shows its decision. Each page is
 * at most `PAGE_SIZE` records plus one report and two appeal reads per record.
 *
 * Region: inherits europe-west1 via `setGlobalOptions` in index.ts.
 */

import { onCall, CallableRequest, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { enforceRateLimit } from "../middleware/rate_limiter";
import { requireAdmin } from "../shared/require-admin";
import { appealRef, canHoldAppeal, isSafeDocId } from "./appeals";
import { revisionOf } from "./decision-revision";
import { isDecision } from "./decision-outcome";
import { MODERATION_DECISIONS } from "./report-decision";
import { REPORTS } from "./report-status";
import { ReopenBlock, reopenBlock } from "./reopen-report";

export const RATE_LIMIT_KEY = "listClosedReports";

export const PAGE_SIZE = 50;

export type ModeratorLabel = "self" | "other" | "auto";

export interface PastDecision {
  decision: string;
  rule: string | null;
  /** ISO-8601, null when malformed. */
  decidedAt: string | null;
  moderator: ModeratorLabel;
}

export interface ClosedReportRow extends PastDecision {
  reportId: string;
  contentType: string | null;
  revision: number;
  /** Earlier decisions on the same report, oldest first. */
  history: PastDecision[];
  appealed: boolean;
  /** Null when the report can be reopened. */
  reopenBlock: ReopenBlock | null;
}

export interface ClosedReportsResponse {
  reports: ClosedReportRow[];
  /** Pass back to read the next page; null on the last one. */
  nextCursor: string | null;
}

export interface ListClosedReportsDeps {
  rateLimit: (uid: string, operation: string) => Promise<void>;
  run: (adminUid: string, cursor: Cursor | null) => Promise<ClosedReportsResponse>;
}

export interface Cursor {
  decidedAtMs: number;
  reportId: string;
}

export function encodeCursor(cursor: Cursor): string {
  return Buffer.from(JSON.stringify([cursor.decidedAtMs, cursor.reportId])).toString("base64url");
}

// The range `Timestamp.fromMillis` accepts (years 0001–9999).
const MIN_TIMESTAMP_MS = -62135596800000;
const MAX_TIMESTAMP_MS = 253402300799999;

/** The cursor is opaque to the app; anything it cannot have produced is refused. */
export function decodeCursor(value: unknown): Cursor | null {
  if (value === undefined || value === null) return null;
  if (typeof value !== "string" || value.length > 2200) {
    throw new HttpsError("invalid-argument", "invalid_cursor");
  }
  try {
    const parsed = JSON.parse(Buffer.from(value, "base64url").toString("utf8"));
    if (
      Array.isArray(parsed) &&
      parsed.length === 2 &&
      Number.isSafeInteger(parsed[0]) &&
      parsed[0] >= MIN_TIMESTAMP_MS &&
      parsed[0] <= MAX_TIMESTAMP_MS &&
      isSafeDocId(parsed[1])
    ) {
      return { decidedAtMs: parsed[0], reportId: parsed[1] };
    }
  } catch {
    // Falls through to the refusal.
  }
  throw new HttpsError("invalid-argument", "invalid_cursor");
}

export async function handleListClosedReports(
  request: CallableRequest<unknown>,
  deps: ListClosedReportsDeps,
): Promise<ClosedReportsResponse> {
  requireAdmin(request);
  const cursor = decodeCursor(((request.data ?? {}) as Record<string, unknown>).cursor);
  await deps.rateLimit(request.auth!.uid, RATE_LIMIT_KEY);
  return deps.run(request.auth!.uid, cursor);
}

export const listClosedReports = onCall(
  {
    timeoutSeconds: 30,
    cors: ["https://butlery.app", "https://www.butlery.app"],
    enforceAppCheck: true,
  },
  (request) =>
    handleListClosedReports(request, {
      rateLimit: (uid, operation) => enforceRateLimit(uid, operation),
      run: (adminUid, cursor) => runListClosedReportsWithDb(admin.firestore(), adminUid, cursor),
    }),
);

function iso(value: unknown): string | null {
  return value instanceof admin.firestore.Timestamp ? value.toDate().toISOString() : null;
}

function moderatorLabel(moderatorId: unknown, adminUid: string): ModeratorLabel {
  if (typeof moderatorId !== "string" || moderatorId.length === 0) return "auto";
  return moderatorId === adminUid ? "self" : "other";
}

function pastDecision(entry: Record<string, unknown>, adminUid: string): PastDecision | null {
  if (!isDecision(entry.decision)) return null;
  return {
    decision: entry.decision,
    rule: typeof entry.rule === "string" ? entry.rule : null,
    decidedAt: iso(entry.decidedAt),
    moderator: moderatorLabel(entry.moderatorId, adminUid),
  };
}

/** Test seam — accepts an injected Firestore. */
export async function runListClosedReportsWithDb(
  db: admin.firestore.Firestore,
  adminUid: string,
  cursor: Cursor | null,
): Promise<ClosedReportsResponse> {
  let query = db
    .collection(MODERATION_DECISIONS)
    .orderBy("decidedAt", "desc")
    .orderBy(admin.firestore.FieldPath.documentId(), "desc")
    .limit(PAGE_SIZE);
  if (cursor) {
    query = query.startAfter(admin.firestore.Timestamp.fromMillis(cursor.decidedAtMs), cursor.reportId);
  }
  const records = await query.get();
  if (records.empty) return { reports: [], nextCursor: null };

  const ids = records.docs.map((doc) => doc.id);
  const appealIds = ids.flatMap((id) =>
    (["reporter", "owner"] as const).filter((role) => canHoldAppeal(id, role)).map((role) => ({
      id,
      ref: appealRef(db, id, role),
    })),
  );
  const [reports, appeals] = await Promise.all([
    db.getAll(...ids.map((id) => db.collection(REPORTS).doc(id)), {
      fieldMask: ["status", "reporterId", "contentOwnerId", "reviewRound"],
    }),
    appealIds.length > 0
      ? db.getAll(...appealIds.map((a) => a.ref), { fieldMask: ["status"] })
      : Promise.resolve([]),
  ]);
  const appealed = new Set(appealIds.filter((_, i) => appeals[i].exists).map((a) => a.id));

  const rows: ClosedReportRow[] = [];
  records.docs.forEach((doc, i) => {
    const current = pastDecision(doc.data(), adminUid);
    if (!current) return;
    const history = Array.isArray(doc.get("history")) ? (doc.get("history") as unknown[]) : [];
    const contentType = doc.get("contentType");
    rows.push({
      ...current,
      reportId: doc.id,
      contentType: typeof contentType === "string" ? contentType : null,
      revision: revisionOf(doc.data()),
      history: history
        .filter((e): e is Record<string, unknown> => typeof e === "object" && e !== null)
        .map((e) => pastDecision(e, adminUid))
        .filter((e): e is PastDecision => e !== null),
      appealed: appealed.has(doc.id),
      reopenBlock: reopenBlock(reports[i], doc.data(), appealed.has(doc.id)),
    });
  });

  const last = records.docs[records.docs.length - 1];
  const lastAt = last.get("decidedAt");
  const nextCursor =
    records.size === PAGE_SIZE && lastAt instanceof admin.firestore.Timestamp
      ? encodeCursor({ decidedAtMs: lastAt.toMillis(), reportId: last.id })
      : null;
  return { reports: rows, nextCursor };
}
