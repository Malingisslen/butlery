/**
 * BUT-770: GDPR Article 15 Right of Access export for `audit_logs`.
 *
 * The `audit_logs` collection is admin-only at the rules layer (BUT-424:
 * tampering-detection invariant — a compromised account that could read its
 * own log could craft attacks around the gaps it sees). That correctly
 * locks out user-side reads but means the only way to satisfy Article 15
 * is a server-side export running under Admin SDK.
 *
 * Schema reality (verified 2026-05-06): `audit_logs` rows carry a single
 * `userId` field naming the actor; there is no separate `subject` field.
 * The "subject" case in the original ticket spec was a misread of the
 * schema — for now, an Article-15 export means "every row where this
 * user was the actor". A subject-side cascade for admin-action audit
 * trails (rare today) is tracked as a follow-up.
 *
 * Limit rationale: caps at 5000 entries per call so the export bundle
 * doesn't time out the callable. Power users with deeper history can
 * page via the `before` cursor (server-side timestamp).
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";

const db = admin.firestore();

/** Cap on entries returned per call. Sized so a single call fits the
 * default callable response budget; pagination handles deeper histories. */
const PAGE_SIZE = 5000;

export interface ExportAuditLogsRequest {
  /**
   * Optional pagination cursor. Pass the `nextCursor` from a previous
   * response to fetch the next chunk. Cursor is the ISO-8601 timestamp of
   * the last entry returned, descending order.
   */
  before?: string;
}

export interface AuditLogExportRow {
  id: string;
  /** ISO-8601 server timestamp. */
  timestamp: string;
  operation: string;
  resourceType: string;
  resourceId: string | null;
  granted: boolean;
  metadata: Record<string, unknown> | null;
}

export interface ExportAuditLogsResponse {
  /** Total entries in this response (≤ PAGE_SIZE). */
  count: number;
  /** Audit-log rows where this user was the actor. */
  rows: AuditLogExportRow[];
  /**
   * Cursor for the next page when more rows exist; absent / null when the
   * caller has reached the end of their history.
   */
  nextCursor: string | null;
  /** Echo the ticket source for traceability in the export bundle. */
  gdprArticle: "Article 15 - Right of Access";
}

/**
 * Callable that returns the calling user's `audit_logs` rows in pages.
 * Auth-required (the auth uid scopes the query). No App Check enforcement
 * here because the caller is running in an authenticated app context that
 * already passed App Check at sign-in; adding a second gate doesn't
 * meaningfully raise the bar against the threat models that matter for
 * Article 15 (the user is reading their own data).
 */
export const exportAuditLogs = onCall<ExportAuditLogsRequest>(
  {
    memory: "512MiB",
    timeoutSeconds: 60,
    cors: ["https://butlery.app", "https://www.butlery.app"],
  },
  async (request): Promise<ExportAuditLogsResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }
    const uid = request.auth.uid;
    return runExportAuditLogs(uid, request.data ?? {});
  }
);

/**
 * Server-callable core. Exposed for unit tests; production goes through
 * the `exportAuditLogs` callable above.
 */
export async function runExportAuditLogs(
  uid: string,
  req: ExportAuditLogsRequest
): Promise<ExportAuditLogsResponse> {
  return runExportAuditLogsWithDb(db, uid, req);
}

/**
 * Test seam — accepts an injected Firestore. Production goes through
 * `runExportAuditLogs`.
 */
export async function runExportAuditLogsWithDb(
  database: admin.firestore.Firestore,
  uid: string,
  req: ExportAuditLogsRequest
): Promise<ExportAuditLogsResponse> {
  let query = database
    .collection("audit_logs")
    .where("userId", "==", uid)
    .orderBy("timestamp", "desc")
    .limit(PAGE_SIZE);

  if (req.before) {
    const beforeDate = new Date(req.before);
    if (Number.isNaN(beforeDate.getTime())) {
      throw new HttpsError(
        "invalid-argument",
        "`before` must be a valid ISO-8601 timestamp."
      );
    }
    query = query.startAfter(admin.firestore.Timestamp.fromDate(beforeDate));
  }

  const snapshot = await query.get();
  const rows: AuditLogExportRow[] = snapshot.docs.map((doc) => {
    const data = doc.data();
    const tsRaw = data.timestamp;
    let timestamp = "unknown";
    if (tsRaw && typeof tsRaw.toDate === "function") {
      timestamp = (tsRaw as admin.firestore.Timestamp).toDate().toISOString();
    } else if (typeof tsRaw === "string") {
      timestamp = tsRaw;
    }
    return {
      id: doc.id,
      timestamp,
      operation: typeof data.operation === "string" ? data.operation : "unknown",
      resourceType:
        typeof data.resourceType === "string" ? data.resourceType : "unknown",
      resourceId:
        typeof data.resourceId === "string" ? data.resourceId : null,
      granted: data.granted === true,
      metadata: isPlainObject(data.metadata) ? data.metadata : null,
    };
  });

  // BUT-770: nextCursor signals more rows when we hit the page cap exactly.
  // Strict less-than would also work for "more than PAGE_SIZE rows", but a
  // hit on the cap is sufficient — the client iterates until count < cap.
  const nextCursor =
    snapshot.size === PAGE_SIZE && rows.length > 0
      ? rows[rows.length - 1].timestamp
      : null;

  logger.info("exportAuditLogs.complete", {
    event: "export_audit_logs.complete",
    uid_prefix: uid.slice(0, 6),
    count: rows.length,
    hasNextPage: nextCursor !== null,
  });

  return {
    count: rows.length,
    rows,
    nextCursor,
    gdprArticle: "Article 15 - Right of Access",
  };
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return (
    typeof value === "object" &&
    value !== null &&
    !Array.isArray(value)
  );
}
