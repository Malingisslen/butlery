/**
 * BUT-2353: the moderator's queue of unanswered appeals.
 *
 * Admin only. The appellant is not part of a row: the moderator judges the
 * decision and the appeal text, and `answerAppeal` resolves who to tell.
 *
 * Region: inherits europe-west1 via `setGlobalOptions` in index.ts.
 */

import { onCall, CallableRequest } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { enforceRateLimit } from "../middleware/rate_limiter";
import { requireAdmin } from "../shared/require-admin";
import { REPORTS } from "./report-status";
import { MODERATION_DECISIONS } from "./report-decision";
import { isSafeDocId, MODERATION_APPEALS } from "./appeals";
import { DECISION_FIELDS, isDecision } from "./decision-outcome";
import { resolveMotivation } from "./motivation";
import { WEB_CALLABLE_ORIGINS } from "../shared/web-origins";

export const RATE_LIMIT_KEY = "listOpenAppeals";

/** Open appeals read per call. */
export const MAX_OPEN_APPEALS = 200;

export interface OpenAppeal {
  appealId: string;
  reportId: string;
  role: string;
  contentType: string | null;
  contentId: string | null;
  reason: string | null;
  decision: string | null;
  motivation: string | null;
  /** ISO-8601, null when the decision record is gone. */
  decidedAt: string | null;
  text: string;
  /** ISO-8601. */
  createdAt: string;
}

export interface OpenAppealsResponse {
  appeals: OpenAppeal[];
  /**
   * More appeals are open than one call reads. Which ones are left out is not
   * chosen by age (no index orders the query), so the queue is not complete
   * until this is false.
   */
  truncated: boolean;
}

export interface ListOpenAppealsDeps {
  rateLimit: (uid: string, operation: string) => Promise<void>;
  run: () => Promise<OpenAppealsResponse>;
}

export async function handleListOpenAppeals(
  request: CallableRequest<unknown>,
  deps: ListOpenAppealsDeps,
): Promise<OpenAppealsResponse> {
  requireAdmin(request);
  await deps.rateLimit(request.auth!.uid, RATE_LIMIT_KEY);
  return deps.run();
}

export const listOpenAppeals = onCall(
  {
    timeoutSeconds: 30,
    cors: WEB_CALLABLE_ORIGINS,
    enforceAppCheck: true,
  },
  (request) =>
    handleListOpenAppeals(request, {
      rateLimit: (uid, operation) => enforceRateLimit(uid, operation),
      run: () => runListOpenAppealsWithDb(admin.firestore()),
    }),
);

function iso(value: unknown): string | null {
  return value instanceof admin.firestore.Timestamp ? value.toDate().toISOString() : null;
}

function str(value: unknown): string | null {
  return typeof value === "string" ? value : null;
}

/**
 * Test seam — accepts an injected Firestore and cap.
 *
 * An equality filter alone, sorted here, so no composite index is needed.
 */
export async function runListOpenAppealsWithDb(
  db: admin.firestore.Firestore,
  max: number = MAX_OPEN_APPEALS,
): Promise<OpenAppealsResponse> {
  const snap = await db
    .collection(MODERATION_APPEALS)
    .where("status", "==", "open")
    .limit(max + 1)
    .get();
  const truncated = snap.size > max;
  const docs = snap.docs
    .slice(0, max)
    .filter((doc) => isSafeDocId(doc.get("reportId")) && iso(doc.get("createdAt")) !== null);
  if (docs.length === 0) return { appeals: [], truncated };

  const reportIds = docs.map((doc) => doc.get("reportId") as string);
  const [reports, decisions] = await Promise.all([
    db.getAll(...reportIds.map((id) => db.collection(REPORTS).doc(id)), {
      fieldMask: ["contentType", "contentId"],
    }),
    db.getAll(...reportIds.map((id) => db.collection(MODERATION_DECISIONS).doc(id)), {
      fieldMask: DECISION_FIELDS,
    }),
  ]);

  const appeals: OpenAppeal[] = [];
  docs.forEach((doc, i) => {
    const record = decisions[i];
    const report = reports[i];
    const decision = record.exists ? record.get("decision") : undefined;
    const rule = record.get("rule");
    appeals.push({
      appealId: doc.id,
      reportId: reportIds[i],
      role: String(doc.get("role") ?? ""),
      contentType: str(record.get("contentType")) ?? str(report.get("contentType")),
      contentId: str(report.get("contentId")),
      reason: str(rule),
      decision: isDecision(decision) ? decision : null,
      motivation: isDecision(decision)
        ? resolveMotivation(decision, rule, record.get("motivation"))
        : null,
      decidedAt: iso(record.get("decidedAt")),
      text: String(doc.get("text") ?? ""),
      createdAt: iso(doc.get("createdAt")) as string,
    });
  });
  appeals.sort((a, b) => a.createdAt.localeCompare(b.createdAt));
  return { appeals, truncated };
}
