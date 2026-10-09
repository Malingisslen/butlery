/**
 * BUT-1842: a server-side TEXT copy of what a report points at, so the
 * moderator still sees what was reported after its author edits or deletes it.
 *
 * Malin's call, 2026-10-09: the server keeps the copy, text only (no images),
 * deleted when the case closes and at the latest 180 days after capture.
 *
 * Every field the client wrote on the report is untrusted: `contentType`,
 * `contentId` and `contentOwnerId` choose WHICH document the Admin SDK reads.
 * So the copy is kept only when the reporter could have read that document
 * themselves under `firestore.rules` — otherwise a forged report would have the
 * server preserve somebody else's private text.
 *
 * The copy carries no `reporterId`. It is deleted by `onReportEvidenceLifecycle`
 * when its report is deleted, closed or loses its `contentOwnerId` (the
 * reported person's erasure nulls that field), and by the TTL on `expireAt`.
 */

import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { isValidDocId } from "../shared/valid-doc-id";
import { isClosedReportStatus, REPORTS } from "./report-status";

export const REPORT_EVIDENCE = "report_evidence";

/** Malin's cap, counted from capture — not extended by an erasure hold. */
export const EVIDENCE_RETENTION_DAYS = 180;

/**
 * Total budget for the copied text. Firestore refuses a document over 1 MiB,
 * and a refused write here would cost the copy entirely.
 */
export const MAX_EVIDENCE_TEXT_BYTES = 64 * 1024;

const MAX_LIST_ROWS = 200;

export type EvidenceOutcome =
  | "captured"
  | "missing"
  | "owner_mismatch"
  | "not_visible_to_reporter"
  | "unsupported_type"
  | "invalid_ref"
  | "capture_failed";

/** Why no copy was written at all. */
export type EvidenceSkip = "report_gone" | "report_closed" | "no_owner" | "already_captured";

type Data = admin.firestore.DocumentData;

interface Source {
  ref: admin.firestore.DocumentReference;
  /** Where the text lives inside the document, keyed by the name the copy uses. */
  textFields: Array<[name: string, path: string[]]>;
  /** Where [textFields] start; the document itself when absent. */
  textRoot?: (data: Data) => Data;
  /** The document's own author field, when its path does not already pin the owner. */
  authorField?: string;
  /** Mirrors the read rule for this collection, from the reporter's side. */
  reporterCanRead: (
    data: Data,
    reporterId: string,
    tx: admin.firestore.Transaction,
  ) => Promise<boolean>;
}

function listHas(value: unknown, uid: string): boolean {
  return Array.isArray(value) && value.includes(uid);
}

function mapHas(value: unknown, uid: string): boolean {
  return typeof value === "object" && value !== null && !Array.isArray(value) &&
    Object.prototype.hasOwnProperty.call(value, uid);
}

function resolveSource(
  db: admin.firestore.Firestore,
  contentType: unknown,
  contentId: string,
  ownerId: string,
): Source | null {
  switch (contentType) {
    case "recipe":
      return {
        ref: db.collection("users").doc(ownerId).collection("recipes").doc(contentId),
        // Older recipes are stored flat, without `core`; the app reads both.
        textFields: (["title", "description", "ingredients", "instructions"] as const)
          .map((f): [string, string[]] => [f, [f]]),
        textRoot: (d) => (typeof d.core === "object" && d.core !== null ? d.core as Data : d),
        reporterCanRead: async (d, uid) =>
          mapHas((d.socialData as Data | undefined)?.memberPermissions, uid),
      };
    case "comment":
      return {
        ref: db.collection("recipe_comments").doc(contentId),
        textFields: [["text", ["text"]]],
        authorField: "authorId",
        reporterCanRead: async (d, uid) =>
          d.recipeOwnerId === uid || listHas(d.sharedWithUserIds, uid),
      };
    case "message":
      return {
        ref: db.collection("messages").doc(contentId),
        textFields: [["content", ["content"]]],
        authorField: "senderId",
        reporterCanRead: async (d, uid, tx) => {
          if (!isValidDocId(d.conversationId)) return false;
          const conv = await tx.get(db.collection("conversations").doc(d.conversationId));
          return listHas(conv.get("participantIds"), uid);
        },
      };
    case "cook_snap":
      return {
        ref: db.collection("cook_snaps").doc(contentId),
        textFields: [["caption", ["caption"]]],
        authorField: "userId",
        reporterCanRead: async (d, uid, tx) => {
          if (d.visibility !== "sameAsRecipe") return false;
          const friend = await tx.get(
            db.collection("users").doc(ownerId).collection("friends").doc(uid),
          );
          return friend.exists;
        },
      };
    case "group":
      return {
        ref: db.collection("users").doc(ownerId).collection("friend_categories").doc(contentId),
        textFields: [
          ["name", ["name"]],
          ["description", ["description"]],
        ],
        reporterCanRead: async (d, uid) => listHas(d.friendUserIds, uid),
      };
    case "profile":
      // Readable by every signed-in account, so only the id binding matters.
      if (contentId !== ownerId) return null;
      return {
        ref: db.collection("public_profiles").doc(contentId),
        textFields: [
          ["displayName", ["displayName"]],
          ["bio", ["bio"]],
        ],
        reporterCanRead: async () => true,
      };
    default:
      return null;
  }
}

function readPath(data: Data, path: string[]): unknown {
  let cur: unknown = data;
  for (const key of path) {
    if (typeof cur !== "object" || cur === null) return undefined;
    cur = (cur as Data)[key];
  }
  return cur;
}

/** Cuts [s] to at most [budget] UTF-8 bytes without splitting a code point. */
function cutToBytes(s: string, budget: number): string {
  if (Buffer.byteLength(s, "utf8") <= budget) return s;
  let out = "";
  let used = 0;
  for (const ch of s) {
    const n = Buffer.byteLength(ch, "utf8");
    if (used + n > budget) break;
    out += ch;
    used += n;
  }
  return out;
}

/** Copies only strings and lists of strings, inside [MAX_EVIDENCE_TEXT_BYTES]. */
export function extractText(
  data: Data,
  fields: Array<[string, string[]]>,
): { text: Record<string, string | string[]>; truncated: boolean } {
  const text: Record<string, string | string[]> = {};
  let budget = MAX_EVIDENCE_TEXT_BYTES;
  let truncated = false;

  const take = (s: string): string => {
    const cut = cutToBytes(s, budget);
    if (cut.length < s.length) truncated = true;
    budget -= Buffer.byteLength(cut, "utf8");
    return cut;
  };

  for (const [name, path] of fields) {
    const value = readPath(data, path);
    if (typeof value === "string") {
      text[name] = take(value);
    } else if (Array.isArray(value)) {
      const rows = value.filter((v): v is string => typeof v === "string");
      if (rows.length > MAX_LIST_ROWS) truncated = true;
      const kept: string[] = [];
      for (const row of rows.slice(0, MAX_LIST_ROWS)) {
        if (budget <= 0) {
          truncated = true;
          break;
        }
        kept.push(take(row));
      }
      text[name] = kept;
    }
  }
  return { text, truncated };
}

function expireAtFrom(now: Date): admin.firestore.Timestamp {
  return admin.firestore.Timestamp.fromDate(
    new Date(now.getTime() + EVIDENCE_RETENTION_DAYS * 24 * 60 * 60 * 1000),
  );
}

/**
 * Writes the copy for [reportId], once. Re-reads the report inside the same
 * transaction, so a report that was closed, deleted or anonymised before this
 * ran gets no copy — nothing would delete one written that late until the TTL.
 *
 * Never throws: `onReportCreated` has no `retry`, so a throw would only cost
 * the log line. An unexpected failure leaves a `capture_failed` row so the
 * moderator can tell it apart from content that was already gone.
 */
export async function captureReportEvidence(
  db: admin.firestore.Firestore,
  reportId: string,
  now: Date = new Date(),
): Promise<EvidenceOutcome | EvidenceSkip> {
  const reportRef = db.collection(REPORTS).doc(reportId);
  const evidenceRef = db.collection(REPORT_EVIDENCE).doc(reportId);

  try {
    return await db.runTransaction(async (tx) => {
      const [report, existing] = await Promise.all([tx.get(reportRef), tx.get(evidenceRef)]);
      if (!report.exists) return "report_gone";
      if (isClosedReportStatus(report.get("status"))) return "report_closed";
      if (existing.exists) return "already_captured";

      const ownerId = report.get("contentOwnerId");
      if (typeof ownerId !== "string" || ownerId.length === 0) return "no_owner";
      const reporterId = report.get("reporterId");
      const contentType = report.get("contentType");
      const contentId = report.get("contentId");

      const base = {
        reportId,
        contentType: typeof contentType === "string" ? contentType : null,
        contentId: isValidDocId(contentId) ? contentId : null,
        contentOwnerId: ownerId,
        capturedAt: admin.firestore.Timestamp.fromDate(now),
        expireAt: expireAtFrom(now),
      };
      const write = (outcome: EvidenceOutcome, extra: Data = {}): EvidenceOutcome => {
        tx.create(evidenceRef, { ...base, outcome, ...extra });
        return outcome;
      };

      if (!isValidDocId(ownerId) || !isValidDocId(contentId) || !isValidDocId(reporterId)) {
        return write("invalid_ref");
      }
      const source = resolveSource(db, contentType, contentId, ownerId);
      if (!source) {
        return write(contentType === "profile" ? "owner_mismatch" : "unsupported_type");
      }

      const content = await tx.get(source.ref);
      const data = content.data();
      if (!data) return write("missing");
      if (source.authorField && data[source.authorField] !== ownerId) {
        return write("owner_mismatch");
      }
      if (!(await source.reporterCanRead(data, reporterId, tx))) {
        return write("not_visible_to_reporter");
      }

      const { text, truncated } = extractText(source.textRoot?.(data) ?? data, source.textFields);
      return write("captured", { text, truncated });
    });
  } catch (err) {
    // Error CODE only: a Firestore error message can echo a path with a uid in it.
    logger.error("report_evidence_capture_failed", {
      report_prefix: reportId.slice(0, 6),
      errCode: (err as { code?: number | string }).code ?? null,
    });
    try {
      await evidenceRef.create({
        reportId,
        outcome: "capture_failed",
        capturedAt: admin.firestore.Timestamp.fromDate(now),
        expireAt: expireAtFrom(now),
      });
    } catch {
      // Already written by a racing delivery, or the database is unreachable;
      // either way the moderator view shows "no copy".
    }
    return "capture_failed";
  }
}

/**
 * Should a write to `reports/{id}` delete its copy? True when the report is
 * deleted, newly closed, or its `contentOwnerId` changes — the reported
 * person's erasure nulls that field, so the copy follows the report's own
 * anonymisation and is covered by whatever re-checks that.
 */
export function evidenceShouldGo(before: Data | undefined, after: Data | undefined): boolean {
  if (!before) return false;
  if (!after) return true;
  if (isClosedReportStatus(after.status) && !isClosedReportStatus(before.status)) return true;
  return after.contentOwnerId !== before.contentOwnerId;
}

export async function deleteReportEvidence(
  db: admin.firestore.Firestore,
  reportId: string,
): Promise<void> {
  await db.collection(REPORT_EVIDENCE).doc(reportId).delete();
}
