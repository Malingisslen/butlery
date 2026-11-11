/**
 * BUT-770: GDPR Article 15 Right of Access export for `audit_logs`.
 *
 * The `audit_logs` collection is admin-only at the rules layer (BUT-424:
 * tampering-detection invariant — a compromised account that could read its
 * own log could craft attacks around the gaps it sees). That correctly
 * locks out user-side reads but means the only way to satisfy Article 15
 * is a server-side export running under Admin SDK.
 *
 * BUT-1805 (Malin, 2026-11-11): a member an admin removed from a group sees
 * that it happened and when, in `removedFromGroups`, and not which admin did
 * it — the admin's identity is withheld under Art. 15(4). That section is
 * built field by field from an allowlist, so nothing else on the row (the
 * admin's uid in `userId` and `metadata.actor`, the doc id) can reach it.
 *
 * Limit rationale: caps at 5000 entries per call so the export bundle
 * doesn't time out the callable. Power users with deeper history can
 * page via the `before` cursor (server-side timestamp).
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { WEB_CALLABLE_ORIGINS } from "../shared/web-origins";
import { ADMIN_REMOVAL_AUDIT_OPERATION } from "../groups/remove-chat-group-member";
import { Collections } from "../shared/collections";
import { isValidDocId } from "../shared/valid-doc-id";

const db = admin.firestore();

/** Cap on entries returned per call. Sized so a single call fits the
 * default callable response budget; pagination handles deeper histories. */
const PAGE_SIZE = 5000;

/** Cap on removal rows; one more is read so `truncated` is a measurement. */
export const MAX_REMOVED_FROM_GROUPS = 200;

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

export interface RemovedFromGroupRow {
  /** ISO-8601 server timestamp of the removal. */
  timestamp: string;
  groupId: string | null;
}

export type RemovedFromGroupsSection =
  | { rows: RemovedFromGroupRow[]; truncated: boolean }
  | { error_code: string };

export interface ExportAuditLogsResponse {
  /** Total entries in this response (≤ PAGE_SIZE). */
  count: number;
  /** Audit-log rows where this user was the actor. */
  rows: AuditLogExportRow[];
  /** First page only (no `before` cursor); absent on later pages. */
  removedFromGroups?: RemovedFromGroupsSection;
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
 * Auth-required (the auth uid scopes the query).
 *
 * BUT-760: enforceAppCheck added to bring this user-facing callable in line
 * with the uniform App Check policy (the CI guard in
 * `__tests__/app-check-enforcement.test.ts` requires it). App Check tokens
 * are minted per-call, not session-scoped, so "passed App Check at sign-in"
 * doesn't cover a later export request. Inert until App Check is flipped from
 * Unenforced to Enforce in the console (mobile attestation roll-out — server
 * half of BUT-760).
 */
export const exportAuditLogs = onCall<ExportAuditLogsRequest>(
  {
    memory: "512MiB",
    timeoutSeconds: 60,
    cors: WEB_CALLABLE_ORIGINS,
    enforceAppCheck: true,
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
    return {
      id: doc.id,
      timestamp: isoTimestamp(data.timestamp),
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

  const removedFromGroups = req.before
    ? undefined
    : await exportRemovedFromGroups(database, uid);

  logger.info("exportAuditLogs.complete", {
    event: "export_audit_logs.complete",
    uid_prefix: uid.slice(0, 6),
    count: rows.length,
    hasNextPage: nextCursor !== null,
  });

  return {
    count: rows.length,
    rows,
    ...(removedFromGroups ? { removedFromGroups } : {}),
    nextCursor,
    gdprArticle: "Article 15 - Right of Access",
  };
}

/**
 * Equality filters only, so Firestore serves it by merging single-field
 * indexes; an `orderBy` would need a composite index, so rows are sorted here.
 *
 * Rows a client wrote before `firestore.rules` refused this operation are
 * dropped where they cannot be the server's: the server stamps a Timestamp and
 * `chat_groups`, and `select` keeps a planted large row out of memory.
 */
async function exportRemovedFromGroups(
  database: admin.firestore.Firestore,
  uid: string
): Promise<RemovedFromGroupsSection> {
  try {
    const snapshot = await database
      .collection("audit_logs")
      .where("metadata.targetUid", "==", uid)
      .where("operation", "==", ADMIN_REMOVAL_AUDIT_OPERATION)
      .select("timestamp", "resourceType", "resourceId")
      .limit(MAX_REMOVED_FROM_GROUPS + 1)
      .get();
    const all: RemovedFromGroupRow[] = snapshot.docs.flatMap((doc) => {
      const data = doc.data();
      if (data.resourceType !== Collections.chatGroups) return [];
      if (!(data.timestamp instanceof admin.firestore.Timestamp)) return [];
      return [
        {
          timestamp: data.timestamp.toDate().toISOString(),
          groupId: isValidDocId(data.resourceId) ? data.resourceId : null,
        },
      ];
    });
    all.sort((a, b) => b.timestamp.localeCompare(a.timestamp));
    return {
      rows: all.slice(0, MAX_REMOVED_FROM_GROUPS),
      truncated: snapshot.size > MAX_REMOVED_FROM_GROUPS,
    };
  } catch (e) {
    // By code, never `String(e)`: a Firestore error can embed the uid.
    const code =
      typeof (e as { code?: unknown })?.code === "string" ||
      typeof (e as { code?: unknown })?.code === "number"
        ? String((e as { code: string | number }).code)
        : "unknown";
    logger.warn("exportAuditLogs.removedFromGroups.failed", {
      uid_prefix: uid.slice(0, 6),
      code,
    });
    return { error_code: "removed-from-groups-failed" };
  }
}

function isoTimestamp(tsRaw: unknown): string {
  if (tsRaw && typeof (tsRaw as { toDate?: unknown }).toDate === "function") {
    return (tsRaw as admin.firestore.Timestamp).toDate().toISOString();
  }
  if (typeof tsRaw === "string") return tsRaw;
  return "unknown";
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return (
    typeof value === "object" &&
    value !== null &&
    !Array.isArray(value)
  );
}
