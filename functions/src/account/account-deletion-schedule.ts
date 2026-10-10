/**
 * BUT-950: a grace period before an account is erased.
 *
 * `scheduleAccountDeletion` records the request and signs the account out
 * everywhere; nothing is erased yet. Signing in during the window shows the
 * app's pending-deletion page, which can `cancelAccountDeletion` or erase at
 * once through `requestAccountDeletion`. `runDueAccountDeletions` erases every
 * account whose window has passed, through the same `runAccountDeletionWithDeps`
 * as the immediate path.
 *
 * App versions from before BUT-950 still call `requestAccountDeletion` and
 * erase immediately.
 *
 * The pending state reaches the client as the custom claim
 * `deletionScheduledFor` (epoch ms), so the sign-in check costs no Firestore
 * read and needs no rules block. `account_deletion_requests` is Admin SDK only.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { Collections } from "../shared/collections";
import {
  DeletionDeps,
  REAUTH_MAX_AGE_SECONDS,
  runAccountDeletionWithDeps,
} from "./request-account-deletion";

export const DELETION_GRACE_DAYS = 7;
const DAY_MS = 24 * 60 * 60 * 1000;

/** The custom claim the client reads to show the pending-deletion page. */
export const DELETION_CLAIM = "deletionScheduledFor";

/** Accounts erased per scheduler run; each erasure can take minutes. */
const MAX_PER_RUN = 5;

/** A claim older than this is taken to belong to a run that died. */
const LEASE_MS = 15 * 60 * 1000;

/** No new erasure starts after this much of the 540 s timeout has gone. */
export const RUN_BUDGET_MS = 400 * 1000;

/**
 * Runs that may end incomplete before the request is given up. Bounded,
 * because a re-run after a successful Auth delete reports `auth_deletion`
 * failed every time. Each run leaves its `gdprCompliant` audit row.
 */
export const MAX_ATTEMPTS = 3;

const MAX_REASON_LENGTH = 1000;

export interface ScheduleAccountDeletionResponse {
  scheduledFor: number;
}

function requireRecentLogin(auth: {
  token: { auth_time?: unknown };
}): void {
  const authTimeSec = auth.token.auth_time;
  if (typeof authTimeSec !== "number") {
    throw new HttpsError(
      "unauthenticated",
      "Missing auth_time claim — re-authenticate.",
    );
  }
  if (Math.floor(Date.now() / 1000) - authTimeSec > REAUTH_MAX_AGE_SECONDS) {
    throw new HttpsError(
      "failed-precondition",
      "Recent sign-in required (re-authenticate within last 5 minutes).",
      { code: "requires-recent-login" },
    );
  }
}

async function setDeletionClaim(
  auth: admin.auth.Auth,
  uid: string,
  scheduledFor: number | null,
): Promise<void> {
  const user = await auth.getUser(uid);
  const claims: Record<string, unknown> = { ...(user.customClaims ?? {}) };
  if (scheduledFor === null) {
    if (!(DELETION_CLAIM in claims)) return;
    delete claims[DELETION_CLAIM];
  } else {
    claims[DELETION_CLAIM] = scheduledFor;
  }
  await auth.setCustomUserClaims(uid, claims);
}

export async function scheduleAccountDeletionWithDeps(
  deps: Pick<DeletionDeps, "db" | "auth">,
  uid: string,
  reason: string,
  nowMs: number,
): Promise<ScheduleAccountDeletionResponse> {
  const ref = deps.db.collection(Collections.accountDeletionRequests).doc(uid);
  // A repeated request inside the window keeps the first date, so asking
  // twice never pushes the erasure further away.
  const { scheduledFor, created } = await deps.db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const existing = snap.exists ? snap.get("scheduledFor") : null;
    if (existing instanceof admin.firestore.Timestamp) {
      return { scheduledFor: existing.toMillis(), created: false };
    }
    const at = nowMs + DELETION_GRACE_DAYS * DAY_MS;
    tx.set(ref, {
      requestedAt: admin.firestore.Timestamp.fromMillis(nowMs),
      scheduledFor: admin.firestore.Timestamp.fromMillis(at),
      reason,
    });
    return { scheduledFor: at, created: true };
  });
  try {
    await setDeletionClaim(deps.auth, uid, scheduledFor);
  } catch (err) {
    // Without the claim a sign-in would never show the pending page, so the
    // user could not cancel: withdraw the request rather than erase unseen.
    // Only one this call created; an earlier request already has its claim.
    if (created) {
      try {
        await ref.delete();
      } catch (deleteErr) {
        logger.error("[scheduleAccountDeletion] withdrawing the request failed", {
          uid_prefix: uid.slice(0, 6),
          errCode: (deleteErr as { code?: string }).code ?? null,
        });
      }
    }
    throw err;
  }
  // Every device signs in again, so each one meets the pending page.
  await deps.auth.revokeRefreshTokens(uid);
  logger.info("[scheduleAccountDeletion] scheduled", {
    uid_prefix: uid.slice(0, 6),
    scheduledFor,
  });
  return { scheduledFor };
}

export async function cancelAccountDeletionWithDeps(
  deps: Pick<DeletionDeps, "db" | "auth">,
  uid: string,
): Promise<{ cancelled: boolean }> {
  const ref = deps.db.collection(Collections.accountDeletionRequests).doc(uid);
  const cancelled = await deps.db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return false;
    // A run that has already started erasing cannot be called back.
    const attempts = snap.get("attempts");
    if (
      snap.get("processingStartedAt") != null ||
      (typeof attempts === "number" && attempts > 0)
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Deletion already in progress.",
        { code: "deletion-in-progress" },
      );
    }
    tx.delete(ref);
    return true;
  });
  await setDeletionClaim(deps.auth, uid, null);
  logger.info("[cancelAccountDeletion] done", {
    uid_prefix: uid.slice(0, 6),
    cancelled,
  });
  return { cancelled };
}

export interface DueRunSummary {
  erased: number;
  skipped: number;
  failed: number;
}

export async function runDueAccountDeletionsWithDeps(
  deps: DeletionDeps,
  nowMs: number,
): Promise<DueRunSummary> {
  const due = await deps.db
    .collection(Collections.accountDeletionRequests)
    .where("scheduledFor", "<=", admin.firestore.Timestamp.fromMillis(nowMs))
    .orderBy("scheduledFor")
    .limit(MAX_PER_RUN)
    .get();

  const summary: DueRunSummary = { erased: 0, skipped: 0, failed: 0 };
  const startedAt = Date.now();
  for (const doc of due.docs) {
    if (Date.now() - startedAt > RUN_BUDGET_MS) {
      summary.skipped++;
      continue;
    }
    const uid = doc.id;
    const claimed = await deps.db.runTransaction(async (tx) => {
      const snap = await tx.get(doc.ref);
      if (!snap.exists) return null;
      const started = snap.get("processingStartedAt");
      if (
        started instanceof admin.firestore.Timestamp &&
        nowMs - started.toMillis() < LEASE_MS
      ) {
        return null;
      }
      tx.update(doc.ref, {
        processingStartedAt: admin.firestore.Timestamp.fromMillis(nowMs),
      });
      const reason = snap.get("reason");
      const attempts = snap.get("attempts");
      return {
        reason:
          typeof reason === "string" && reason.length > 0
            ? reason
            : "user_request",
        attempts: typeof attempts === "number" ? attempts : 0,
        requestedAt: snap.get("requestedAt") as unknown,
        scheduledFor: snap.get("scheduledFor") as unknown,
      };
    });
    if (claimed === null) {
      summary.skipped++;
      continue;
    }

    let email = "unknown";
    try {
      email = (await deps.auth.getUser(uid)).email ?? "unknown";
    } catch (err) {
      // An Auth account already gone still has data to erase.
      logger.warn("[runDueAccountDeletions] auth user unavailable", {
        uid_prefix: uid.slice(0, 6),
        errCode: (err as { code?: string }).code ?? null,
      });
    }

    try {
      const result = await runAccountDeletionWithDeps(
        deps,
        uid,
        email,
        claimed.reason,
      );
      if (result.success) {
        summary.erased++;
        continue;
      }
      summary.failed++;
      // Put the request back, unleased, for the next run.
      const attempt = claimed.attempts + 1;
      logger.error("[runDueAccountDeletions] erasure incomplete", {
        uid_prefix: uid.slice(0, 6),
        failedCollections: result.failedCollections,
        attempt,
      });
      if (attempt < MAX_ATTEMPTS) {
        try {
          await doc.ref.set({
            requestedAt: claimed.requestedAt,
            scheduledFor: claimed.scheduledFor,
            reason: claimed.reason,
            attempts: attempt,
          });
        } catch (err) {
          logger.error("[runDueAccountDeletions] re-queue failed", {
            uid_prefix: uid.slice(0, 6),
            errCode: (err as { code?: string }).code ?? null,
          });
        }
      }
    } catch (err) {
      summary.failed++;
      logger.error("[runDueAccountDeletions] erasure threw", {
        uid_prefix: uid.slice(0, 6),
        errName: err instanceof Error ? err.name : typeof err,
      });
    }
  }
  logger.info("[runDueAccountDeletions] run complete", summary);
  return summary;
}

export const scheduleAccountDeletion = onCall<{ reason?: string }>(
  {
    cors: ["https://butlery.app", "https://www.butlery.app"],
    enforceAppCheck: true,
  },
  async (request): Promise<ScheduleAccountDeletionResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }
    requireRecentLogin(request.auth);
    const raw = request.data?.reason;
    const reason =
      typeof raw === "string" && raw.trim().length > 0
        ? raw.trim().slice(0, MAX_REASON_LENGTH)
        : "user_request";
    return scheduleAccountDeletionWithDeps(
      { db: admin.firestore(), auth: admin.auth() },
      request.auth.uid,
      reason,
      Date.now(),
    );
  },
);

export const cancelAccountDeletion = onCall(
  {
    cors: ["https://butlery.app", "https://www.butlery.app"],
    enforceAppCheck: true,
  },
  async (request): Promise<{ cancelled: boolean }> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }
    return cancelAccountDeletionWithDeps(
      { db: admin.firestore(), auth: admin.auth() },
      request.auth.uid,
    );
  },
);

// Its own Scheduler job rather than a task in `maintenance-dispatchers.ts`:
// erasure is a GDPR guarantee and needs its own time budget and failure
// isolation, the reasons that file gives for keeping the cleanup jobs out.
export const runDueAccountDeletions = onSchedule(
  {
    schedule: "every 60 minutes",
    timeZone: "Europe/Stockholm",
    timeoutSeconds: 540,
    memory: "512MiB",
    retryCount: 0,
  },
  async () => {
    await runDueAccountDeletionsWithDeps(
      {
        db: admin.firestore(),
        auth: admin.auth(),
        storage: admin.storage(),
      },
      Date.now(),
    );
  },
);
