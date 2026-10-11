/**
 * BUT-920: erases guest accounts (Firebase anonymous sign-in) nobody has used
 * for 30 days, with everything in them.
 *
 * "Used" is the Auth record's `lastRefreshTime`: a running app refreshes its
 * ID token about hourly, so this measures use without a Firestore write per
 * session. Identity Platform's own anonymous-account cleanup must stay off;
 * it counts from creation, not from last use.
 *
 * A standalone schedule, not a task in scheduled/maintenance-dispatchers.ts:
 * that file keeps GDPR retention jobs out of its chains so an erasure gets its
 * own time budget and failure isolation.
 *
 * A guest has no email, so the deletion audit row carries no email hash and
 * `reason` says why it was erased.
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import type { UserRecord } from "firebase-admin/auth";
import {
  DeletionDeps,
  runAccountDeletionWithDeps,
} from "../account/request-account-deletion";
import { Collections } from "../shared/collections";

export const GUEST_INACTIVE_DAYS = 30;
const DAY_MS = 24 * 60 * 60 * 1000;

/** Erasures per run; the backlog is picked up by the next hourly run. */
export const MAX_GUEST_ERASURES_PER_RUN = 20;

/** No new erasure starts after this much of the 540 s timeout has gone. */
export const GUEST_RUN_BUDGET_MS = 400 * 1000;

export const GUEST_INACTIVE_REASON = "guest_inactive_30_days";

/**
 * True only for an anonymous account idle past the window. Every other kind
 * of account has a sign-in provider or an address, and either keeps the
 * account.
 */
export function isAbandonedGuest(user: UserRecord, nowMs: number): boolean {
  if (user.providerData.length > 0) return false;
  if (user.email || user.phoneNumber) return false;
  const last = Date.parse(
    user.metadata.lastRefreshTime ??
      user.metadata.lastSignInTime ??
      user.metadata.creationTime,
  );
  if (!Number.isFinite(last)) return false;
  return nowMs - last >= GUEST_INACTIVE_DAYS * DAY_MS;
}

export interface GuestSweepSummary {
  scanned: number;
  erased: number;
  failed: number;
  /** Abandoned guests left for the next run (cap or time budget). */
  deferred: number;
}

export interface GuestSweepDeps {
  auth: Pick<admin.auth.Auth, "listUsers" | "getUser">;
  /** Erases one account; production runs the full account cascade. */
  erase: (
    uid: string,
  ) => Promise<{ success: boolean; failedCollections: string[] }>;
  /**
   * Hands an incomplete erasure to runDueAccountDeletions, which retries it.
   * Needed once the Auth account is gone: listUsers never shows it again.
   */
  requeue: (uid: string, nowMs: number) => Promise<void>;
}

export function productionGuestSweepDeps(deps: DeletionDeps): GuestSweepDeps {
  return {
    auth: deps.auth,
    erase: (uid) =>
      runAccountDeletionWithDeps(deps, uid, "", GUEST_INACTIVE_REASON),
    requeue: async (uid, nowMs) => {
      const now = admin.firestore.Timestamp.fromMillis(nowMs);
      await deps.db
        .collection(Collections.accountDeletionRequests)
        .doc(uid)
        .set({
          requestedAt: now,
          scheduledFor: now,
          reason: GUEST_INACTIVE_REASON,
          attempts: 1,
        });
    },
  };
}

export async function cleanupInactiveGuestsWithDeps(
  deps: GuestSweepDeps,
  nowMs: number,
  clock: () => number = Date.now,
): Promise<GuestSweepSummary> {
  const summary: GuestSweepSummary = {
    scanned: 0,
    erased: 0,
    failed: 0,
    deferred: 0,
  };
  const startedAt = clock();
  let pageToken: string | undefined;
  do {
    const page = await deps.auth.listUsers(1000, pageToken);
    pageToken = page.pageToken;
    for (const listed of page.users) {
      summary.scanned++;
      if (!isAbandonedGuest(listed, nowMs)) continue;
      if (
        summary.erased + summary.failed >= MAX_GUEST_ERASURES_PER_RUN ||
        clock() - startedAt > GUEST_RUN_BUDGET_MS
      ) {
        summary.deferred++;
        continue;
      }
      // The guest may have created an account (linked a provider) or opened
      // the app since the page was listed; judge the fresh record.
      let fresh: UserRecord;
      try {
        fresh = await deps.auth.getUser(listed.uid);
      } catch (err) {
        // Not-found means the account is already gone. Anything else is an
        // Auth failure, and it must not read as a clean run.
        const errCode = (err as { code?: string })?.code ?? null;
        if (errCode !== "auth/user-not-found") {
          summary.failed++;
          logger.warn("[cleanupInactiveGuests] getUser failed", {
            uid_prefix: listed.uid.slice(0, 6),
            errCode,
          });
        }
        continue;
      }
      if (!isAbandonedGuest(fresh, nowMs)) continue;
      try {
        const result = await deps.erase(fresh.uid);
        if (result.success) {
          summary.erased++;
        } else {
          summary.failed++;
          logger.error("[cleanupInactiveGuests] erasure incomplete", {
            uid_prefix: fresh.uid.slice(0, 6),
            failedCollections: result.failedCollections,
          });
          // A failed Auth delete leaves the guest listed, so the next run
          // finds it again by itself.
          if (!result.failedCollections.includes("auth_deletion")) {
            await deps.requeue(fresh.uid, nowMs).catch((err) =>
              logger.error("[cleanupInactiveGuests] re-queue failed", {
                uid_prefix: fresh.uid.slice(0, 6),
                errCode: (err as { code?: string })?.code ?? null,
              }),
            );
          }
        }
      } catch (err) {
        summary.failed++;
        logger.error("[cleanupInactiveGuests] erasure threw", {
          uid_prefix: fresh.uid.slice(0, 6),
          errName: err instanceof Error ? err.name : typeof err,
        });
      }
    }
  } while (pageToken && clock() - startedAt <= GUEST_RUN_BUDGET_MS);
  logger.info("[cleanupInactiveGuests] run complete", summary);
  return summary;
}

export const cleanupInactiveGuests = onSchedule(
  {
    schedule: "every 60 minutes",
    timeZone: "Europe/Stockholm",
    timeoutSeconds: 540,
    memory: "512MiB",
    retryCount: 0,
  },
  async () => {
    await cleanupInactiveGuestsWithDeps(
      productionGuestSweepDeps({
        db: admin.firestore(),
        auth: admin.auth(),
        storage: admin.storage(),
      }),
      Date.now(),
    );
  },
);
