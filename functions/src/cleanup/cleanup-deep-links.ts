/**
 * BUT-2463: `deep_links` retention.
 *
 * A short link stores its creator's uid (`createdBy`, and `from=` inside
 * `longUrl`). The app stops opening a link 7 days after it was made
 * (`isTimestampExpired`); this job deletes the document, and its `clicks`, once
 * `createdAt` is older than `DEEP_LINK_RETENTION_DAYS`.
 *
 * A standalone schedule rather than a task in a maintenance chain:
 * `maintenance-dispatchers.ts` keeps the cleanup jobs that carry GDPR
 * retention out of its chains.
 *
 * One range predicate on `createdAt` and no `orderBy`, so the automatic
 * single-field index serves it. A document whose `createdAt` is not a
 * Timestamp never matches; only the account-deletion cascade reaches it.
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { Collections } from "../shared/collections";
import { DEEP_LINK_PAGE, deleteDeepLinkDocs } from "../shared/deep-links";

/** Decided by Malin 2026-10-28: the link's 7 days plus a margin. */
export const DEEP_LINK_RETENTION_DAYS = 14;

/**
 * Per-run row cap. The first run meets the whole backlog; what is left over
 * goes on the next day's run.
 */
export const MAX_DEEP_LINKS_PER_RUN = 20_000;

/** Self-budget, inside the wrapper's `timeoutSeconds` (540). */
export const MAX_EXECUTION_TIME_MS = 8 * 60 * 1000;

export interface DeepLinkSweepOptions {
  now?: admin.firestore.Timestamp;
  maxRows?: number;
  maxExecutionMs?: number;
  /** Wall clock for the deadline; injectable so a test can run it out. */
  clock?: () => number;
}

export interface DeepLinkSweepResult {
  deleted: number;
  stoppedBy: "drained" | "row_cap" | "deadline";
}

/**
 * Deletes links created before the retention cutoff, a page at a time. Each
 * page re-queries the same predicate: deleted links stop matching, so no
 * cursor is needed and a stopped run loses nothing.
 */
export async function pruneExpiredDeepLinks(
  db: admin.firestore.Firestore,
  options: DeepLinkSweepOptions = {},
): Promise<DeepLinkSweepResult> {
  const now = options.now ?? admin.firestore.Timestamp.now();
  const maxRows = options.maxRows ?? MAX_DEEP_LINKS_PER_RUN;
  const maxExecutionMs = options.maxExecutionMs ?? MAX_EXECUTION_TIME_MS;
  const clock = options.clock ?? Date.now;
  const cutoff = admin.firestore.Timestamp.fromMillis(
    now.toMillis() - DEEP_LINK_RETENTION_DAYS * 24 * 60 * 60 * 1000,
  );
  const startedAt = clock();
  let deleted = 0;
  let stoppedBy: DeepLinkSweepResult["stoppedBy"] = "drained";

  for (;;) {
    if (clock() - startedAt > maxExecutionMs) {
      stoppedBy = "deadline";
      break;
    }
    const remaining = maxRows - deleted;
    if (remaining <= 0) {
      stoppedBy = "row_cap";
      break;
    }
    const pageSize = Math.min(DEEP_LINK_PAGE, remaining);
    const snap = await db
      .collection(Collections.deepLinks)
      .where("createdAt", "<", cutoff)
      .limit(pageSize)
      .get();
    if (snap.empty) break;
    await deleteDeepLinkDocs(db, snap.docs);
    deleted += snap.size;
    if (snap.size < pageSize) break;
  }

  logger.info("deep_links retention complete", {
    event: "deep_links_retention.complete",
    deleted,
    stoppedBy,
    cutoff: cutoff.toDate().toISOString(),
  });
  return { deleted, stoppedBy };
}

/** Daily at 03:30 UTC. */
export const cleanupExpiredDeepLinks = onSchedule(
  { schedule: "30 3 * * *", timeZone: "UTC", timeoutSeconds: 540 },
  async () => {
    try {
      await pruneExpiredDeepLinks(admin.firestore());
    } catch (e) {
      logger.error("deep_links retention failed", e);
      throw e;
    }
  },
);
