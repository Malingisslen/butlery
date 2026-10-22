/**
 * BUT-2353: GDPR Article 15 export of the appeals the requester wrote.
 *
 * `moderation_appeals` is server-only; an appeal is the requester's when its
 * `appellantId` is theirs. The report is never read, so neither the other
 * party's appeal nor the reporter is reached.
 *
 * Each row is built from an allowlist (`role, text, createdAt, status,
 * answeredAt`), so a field added to the collection later — and `answeredBy`,
 * the moderator's uid, and `appellantId` today — never reaches the bundle. The
 * decision record stays out, as BUT-2330 decided.
 *
 * Above the cap it DECLINES with `moderation-appeals-too-large` and never
 * truncates: a truncated Art. 15 answer reads as complete.
 *
 * Region: inherits europe-west1 via `setGlobalOptions` in index.ts.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { enforceRateLimit } from "../middleware/rate_limiter";
import {
  AppealRole,
  APPELLANT_ID,
  isAppealRole,
  MODERATION_APPEALS,
} from "../moderation/appeals";
import { WEB_CALLABLE_ORIGINS } from "../shared/web-origins";

export const RATE_LIMIT_KEY = "exportModerationAppeals";
export const TOO_LARGE_ERROR_CODE = "moderation-appeals-too-large";

/** Appeals read per call. */
export const MAX_APPEALS = 1000;

export interface ModerationAppealExport {
  role: AppealRole;
  text: string;
  /** ISO-8601. */
  createdAt: string | null;
  status: string | null;
  /** ISO-8601. */
  answeredAt: string | null;
}

export interface ExportModerationAppealsResponse {
  appeals: ModerationAppealExport[];
  gdprArticle: "Article 15 - Right of Access";
}

export interface ModerationAppealsDeps {
  rateLimit: (uid: string, operation: string) => Promise<void>;
  run: (uid: string) => Promise<ExportModerationAppealsResponse>;
}

/** The uid is taken from `request.auth` only; `request.data` is never read. */
export async function handleExportModerationAppeals(
  request: { auth?: { uid: string } | null },
  deps: ModerationAppealsDeps,
): Promise<ExportModerationAppealsResponse> {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign-in required.");
  }
  const uid = request.auth.uid;
  await deps.rateLimit(uid, RATE_LIMIT_KEY);
  return deps.run(uid);
}

export const exportModerationAppeals = onCall(
  {
    timeoutSeconds: 60,
    cors: WEB_CALLABLE_ORIGINS,
    enforceAppCheck: true,
  },
  (request) =>
    handleExportModerationAppeals(request, {
      rateLimit: (uid, operation) => enforceRateLimit(uid, operation),
      run: (uid) => runExportModerationAppealsWithDb(admin.firestore(), uid),
    }),
);

function iso(value: unknown): string | null {
  return value instanceof admin.firestore.Timestamp ? value.toDate().toISOString() : null;
}

/** Test seam — accepts an injected Firestore. */
export async function runExportModerationAppealsWithDb(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<ExportModerationAppealsResponse> {
  const snap = await db
    .collection(MODERATION_APPEALS)
    .where(APPELLANT_ID, "==", uid)
    .limit(MAX_APPEALS + 1)
    .get();
  if (snap.size > MAX_APPEALS) decline(uid);

  const appeals: ModerationAppealExport[] = [];
  for (const doc of snap.docs) {
    const role = doc.get("role");
    if (!isAppealRole(role)) continue;
    const text = doc.get("text");
    const status = doc.get("status");
    appeals.push({
      role,
      text: typeof text === "string" ? text : "",
      createdAt: iso(doc.get("createdAt")),
      status: typeof status === "string" ? status : null,
      answeredAt: iso(doc.get("answeredAt")),
    });
  }
  appeals.sort((a, b) => (a.createdAt ?? "").localeCompare(b.createdAt ?? ""));

  logger.info("exportModerationAppeals.complete", {
    event: "export_moderation_appeals.complete",
    uid_prefix: uid.slice(0, 6),
    appeals: appeals.length,
  });
  return { appeals, gdprArticle: "Article 15 - Right of Access" };
}

function decline(uid: string): never {
  logger.warn("exportModerationAppeals.declined", {
    event: "export_moderation_appeals.declined",
    uid_prefix: uid.slice(0, 6),
  });
  throw new HttpsError(
    "failed-precondition",
    "Appeals are too many to export in one response.",
    { error_code: TOO_LARGE_ERROR_CODE },
  );
}
