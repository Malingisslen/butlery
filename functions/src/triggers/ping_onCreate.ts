/**
 * BUT-627: Server-side hourly rate-limit enforcement on ping creates.
 *
 * The Firestore rule for pings carries a 60s burst guard via
 * `rateLimitWrite`, but that guard never binds: `rateLimitWrite` passes
 * whenever the bucket document is absent, and nothing writes
 * `users/{uid}/rate_limits/pings`. The 5/h aggregate cap is likewise
 * documented but not enforced server-side — clients run the count
 * themselves, which a malicious actor can bypass by writing directly
 * via the SDK.
 *
 * This trigger fires on every ping create. It counts the user's pings
 * in the past hour via collection-group query. If the count exceeds
 * the cap, the just-written ping is deleted and an audit row is appended
 * to `audit_logs/{auto}` with `operation: 'ping_rate_limit_exceeded'` —
 * inherits the BUT-665 6-month retention purger and the BUT-424
 * admin-only read rule for free.
 *
 * Required composite index (firestore.indexes.json):
 *   collectionGroup `pings` on (`fromUserId` ASC, `createdAt` DESC).
 *
 * Idempotency: the trigger fires once per create; on retry the ping is
 * already deleted (no-op delete), the audit `add()` would duplicate but
 * the audit collection is append-only telemetry — duplicates are visible
 * but not harmful. If duplicates become a problem, switch the audit doc
 * to a deterministic id (`<userId>_<deletedPingId>`).
 *
 * Region pinned via `setGlobalOptions` in index.ts.
 */

import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";

const HOURLY_PING_CAP = 5;
const WINDOW_MS = 60 * 60 * 1000; // 1 hour

interface PingDoc {
  fromUserId?: string;
  createdAt?: admin.firestore.Timestamp;
}

export interface RateLimitDeps {
  db?: admin.firestore.Firestore;
  now?: () => Date;
}

/**
 * Test seam — exercise the same logic without the v2 trigger wrapper.
 *
 * Returns whether the ping was deleted (cap exceeded) or kept.
 */
export async function enforcePingRateLimit(
  pingId: string,
  groupId: string,
  data: PingDoc,
  deps: RateLimitDeps = {}
): Promise<{ deleted: boolean; count: number }> {
  const fromUserId = data.fromUserId;
  if (!fromUserId) {
    logger.warn("ping_rate_limit.missing_fromUserId", {
      event: "ping_rate_limit.missing_fromUserId",
      pingId,
      groupId,
    });
    return { deleted: false, count: 0 };
  }

  const db = deps.db ?? admin.firestore();
  const now = (deps.now ?? (() => new Date()))();
  const windowStart = admin.firestore.Timestamp.fromMillis(
    now.getTime() - WINDOW_MS
  );

  // count() aggregate — single billable read regardless of result count.
  const snap = await db
    .collectionGroup("pings")
    .where("fromUserId", "==", fromUserId)
    .where("createdAt", ">=", windowStart)
    .count()
    .get();
  const count = snap.data().count;

  if (count <= HOURLY_PING_CAP) {
    return { deleted: false, count };
  }

  // Cap exceeded — delete the just-written ping + write audit row.
  const ref = db.doc(`pings/${groupId}/pings/${pingId}`);
  try {
    await ref.delete();
  } catch (err) {
    // Defence-in-depth: if the delete races with a client-side cleanup
    // we don't fail the trigger (avoids retry storm).
    logger.warn("ping_rate_limit.delete_failed", {
      event: "ping_rate_limit.delete_failed",
      pingId,
      groupId,
      err,
    });
  }

  await db.collection("audit_logs").add({
    userId: fromUserId,
    operation: "ping_rate_limit_exceeded",
    resourceType: "ping",
    timestamp: admin.firestore.Timestamp.fromDate(now),
    deletedPingId: pingId,
    groupId,
    count,
    cap: HOURLY_PING_CAP,
  });

  logger.info("ping_rate_limit.exceeded", {
    event: "ping_rate_limit.exceeded",
    userId: fromUserId,
    deletedPingId: pingId,
    groupId,
    count,
  });

  return { deleted: true, count };
}

export const onPingCreated = onDocumentCreated(
  "pings/{groupId}/pings/{pingId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data() as PingDoc;
    await enforcePingRateLimit(event.params.pingId, event.params.groupId, data);
  }
);
