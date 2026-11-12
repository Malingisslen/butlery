/**
 * Admin tools for a pooled "Butlery-betyget" (BUT-1517, plan condition C9):
 * look at a pool's numbers and pull the emergency stop.
 *
 * Why quarantine and not "split a bad merge": a bad merge means two different
 * dishes compute the SAME pool key, so removing votes only lasts until the next
 * rating lands in the same pool. Quarantine hides the pool's number at once,
 * keeps every vote, and is reversible; a lasting fix for a real collision is a
 * change to the key rules. It also hides honest votes in that pool, so it is an
 * emergency stop, not a precision tool.
 *
 * Data minimisation (privacy policy 5.3, LIA): the inspection returns numbers
 * only. No uid, no uid hash, no recipe id or title, nothing per person. The
 * account-age and verification shares are computed here and only the shares
 * leave. Responses are never logged.
 *
 * Every call writes an `audit_logs` row (general 180-day purge). The quarantine
 * doc holds the pool key, the state and a fixed reason code: no admin id and no
 * free text.
 */

import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { onCall, CallableRequest, HttpsError } from "firebase-functions/v2/https";
import { requireAdmin } from "../shared/require-admin";
import { WEB_CALLABLE_ORIGINS } from "../shared/web-origins";
import { enforceRateLimit } from "../middleware/rate_limiter";
import { CANONICAL_EVENTS_SUBCOLLECTION } from "../ratings/canonical-rating-aggregation";
import {
  POOL_QUARANTINE_COLLECTION,
  updatePooledRatingStats,
} from "../ratings/update-pooled-rating-stats";

const POOL_KEY_PATTERN = /^v\d+:[0-9a-f]{16}$/;
export const QUARANTINE_REASONS = ["brigading", "bad_merge", "other"] as const;
export type QuarantineReason = (typeof QUARANTINE_REASONS)[number];

/** Most recent votes whose accounts are checked for the risk shares. */
export const RISK_SAMPLE = 200;
/** An account younger than this counts as young in the risk share. */
export const YOUNG_ACCOUNT_MS = 7 * 24 * 60 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;

export const AUDIT_OP_INSPECT = "pool_inspect";
export const AUDIT_OP_QUARANTINE = "pool_quarantine_set";
export const AUDIT_OP_LIFT = "pool_quarantine_lift";

export interface PoolInspection {
  poolKey: string;
  quarantined: boolean;
  reasonCode: QuarantineReason | null;
  count: number;
  average: number | null;
  /** Votes per whole star; a half star counts toward the star below it. */
  distribution: [number, number, number, number, number];
  votes24h: number;
  votes7d: number;
  /** How many of the newest votes the two shares below were computed over. */
  sampled: number;
  youngAccountShare: number | null;
  unverifiedShare: number | null;
}

export interface AccountFacts {
  createdMs: number | null;
  emailVerified: boolean;
}

export interface PoolModerationDeps {
  db: admin.firestore.Firestore;
  nowMs: () => number;
  /** uid → facts; a uid missing from the map is a deleted account. */
  lookupAccounts: (uids: string[]) => Promise<Map<string, AccountFacts>>;
  aggregate: (poolKey: string) => Promise<void>;
  rateLimit: (uid: string, operation: string) => Promise<void>;
}

export function parsePoolKey(data: unknown): string {
  const raw = (data ?? {}) as Record<string, unknown>;
  if (typeof raw.poolKey !== "string" || !POOL_KEY_PATTERN.test(raw.poolKey)) {
    throw new HttpsError("invalid-argument", "invalid_pool_key");
  }
  return raw.poolKey;
}

function eventsForPool(db: admin.firestore.Firestore, poolKey: string): admin.firestore.Query {
  return db.collectionGroup(CANONICAL_EVENTS_SUBCOLLECTION).where("poolKey", "==", poolKey);
}

async function countWhere(q: admin.firestore.Query): Promise<number> {
  const snap = await q.count().get();
  return snap.data().count;
}

async function writeAudit(
  db: admin.firestore.Firestore,
  adminUid: string,
  operation: string,
  poolKey: string,
  extra: Record<string, unknown> = {},
): Promise<void> {
  await db.collection("audit_logs").add({
    userId: adminUid,
    operation,
    resourceType: "canonical_recipe_stats",
    resourceId: poolKey,
    granted: true,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    metadata: { actor: adminUid, ...extra },
  });
}

export async function inspectPool(
  adminUid: string,
  poolKey: string,
  deps: PoolModerationDeps,
): Promise<PoolInspection> {
  const { db } = deps;
  const now = deps.nowMs();
  const events = eventsForPool(db, poolKey);

  const quarantineSnap = await db.collection(POOL_QUARANTINE_COLLECTION).doc(poolKey).get();
  const qData = quarantineSnap.exists ? quarantineSnap.data() ?? {} : {};
  const quarantined = qData.quarantined === true;
  const reasonCode = (QUARANTINE_REASONS as readonly string[]).includes(qData.reasonCode as string)
    ? (qData.reasonCode as QuarantineReason)
    : null;

  // The real numbers, also while quarantined (the public doc then says 0).
  const totals = await events
    .aggregate({
      count: admin.firestore.AggregateField.count(),
      average: admin.firestore.AggregateField.average("ratingValue"),
    })
    .get();
  const count = totals.data().count;
  const average = totals.data().average ?? null;

  const distribution: [number, number, number, number, number] = [0, 0, 0, 0, 0];
  for (let star = 1; star <= 5; star++) {
    let q = events.where("ratingValue", ">=", star);
    if (star < 5) q = q.where("ratingValue", "<", star + 1);
    distribution[star - 1] = await countWhere(q);
  }

  // Every createdAt query is ordered DESC so all of them share the one
  // (poolKey ASC, createdAt DESC) collection-group index.
  const newestFirst = events.orderBy("createdAt", "desc");
  const since = (ms: number) => admin.firestore.Timestamp.fromMillis(now - ms);
  const votes24h = await countWhere(newestFirst.where("createdAt", ">=", since(DAY_MS)));
  const votes7d = await countWhere(newestFirst.where("createdAt", ">=", since(7 * DAY_MS)));

  const recent = await newestFirst.limit(RISK_SAMPLE).get();
  const uids = recent.docs
    .map((d) => d.ref.parent.parent?.id)
    .filter((id): id is string => typeof id === "string");
  let youngAccountShare: number | null = null;
  let unverifiedShare: number | null = null;
  if (uids.length > 0) {
    const facts = await deps.lookupAccounts(uids);
    let young = 0;
    let unverified = 0;
    for (const uid of uids) {
      const f = facts.get(uid);
      if (f == null) continue; // deleted account: its vote goes with the cascade
      if (f.createdMs != null && now - f.createdMs < YOUNG_ACCOUNT_MS) young++;
      if (!f.emailVerified) unverified++;
    }
    youngAccountShare = Math.round((young / uids.length) * 100) / 100;
    unverifiedShare = Math.round((unverified / uids.length) * 100) / 100;
  }

  await writeAudit(db, adminUid, AUDIT_OP_INSPECT, poolKey);
  return {
    poolKey,
    quarantined,
    reasonCode,
    count,
    average,
    distribution,
    votes24h,
    votes7d,
    sampled: uids.length,
    youngAccountShare,
    unverifiedShare,
  };
}

export function parseQuarantine(data: unknown): {
  poolKey: string;
  quarantined: boolean;
  reasonCode: QuarantineReason | null;
} {
  const poolKey = parsePoolKey(data);
  const raw = (data ?? {}) as Record<string, unknown>;
  if (typeof raw.quarantined !== "boolean") {
    throw new HttpsError("invalid-argument", "invalid_quarantined");
  }
  if (!raw.quarantined) return { poolKey, quarantined: false, reasonCode: null };
  if (!(QUARANTINE_REASONS as readonly string[]).includes(raw.reasonCode as string)) {
    throw new HttpsError("invalid-argument", "invalid_reason_code");
  }
  return { poolKey, quarantined: true, reasonCode: raw.reasonCode as QuarantineReason };
}

export async function setPoolQuarantine(
  adminUid: string,
  input: { poolKey: string; quarantined: boolean; reasonCode: QuarantineReason | null },
  deps: PoolModerationDeps,
): Promise<{ ok: true }> {
  const { db } = deps;
  const ref = db.collection(POOL_QUARANTINE_COLLECTION).doc(input.poolKey);
  if (input.quarantined) {
    await ref.set({
      poolKey: input.poolKey,
      quarantined: true,
      reasonCode: input.reasonCode,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } else {
    await ref.delete();
  }
  // Audited before the recompute, so a failed recompute never leaves a state change unlogged.
  await writeAudit(
    db,
    adminUid,
    input.quarantined ? AUDIT_OP_QUARANTINE : AUDIT_OP_LIFT,
    input.poolKey,
    input.quarantined ? { reasonCode: input.reasonCode } : {},
  );
  // Recompute now rather than waiting for the next vote, so the change shows at once.
  await deps.aggregate(input.poolKey);
  logger.info("pool_quarantine_changed", {
    poolKey: input.poolKey,
    quarantined: input.quarantined,
  });
  return { ok: true };
}

async function lookupAccountsWithAuth(uids: string[]): Promise<Map<string, AccountFacts>> {
  const out = new Map<string, AccountFacts>();
  const unique = [...new Set(uids)];
  for (let i = 0; i < unique.length; i += 100) {
    const res = await admin.auth().getUsers(unique.slice(i, i + 100).map((uid) => ({ uid })));
    for (const user of res.users) {
      const created = user.metadata?.creationTime;
      const createdMs = created ? new Date(created).getTime() : NaN;
      out.set(user.uid, {
        createdMs: Number.isNaN(createdMs) ? null : createdMs,
        emailVerified: user.emailVerified === true,
      });
    }
  }
  return out;
}

function productionDeps(): PoolModerationDeps {
  const db = admin.firestore();
  return {
    db,
    nowMs: () => Date.now(),
    lookupAccounts: lookupAccountsWithAuth,
    aggregate: (poolKey) => updatePooledRatingStats(poolKey, db),
    rateLimit: (uid, operation) => enforceRateLimit(uid, operation),
  };
}

export async function handleInspectPool(
  request: CallableRequest<unknown>,
  deps: PoolModerationDeps,
): Promise<PoolInspection> {
  requireAdmin(request);
  const poolKey = parsePoolKey(request.data);
  await deps.rateLimit(request.auth!.uid, "adminInspectPool");
  return inspectPool(request.auth!.uid, poolKey, deps);
}

export async function handleSetPoolQuarantine(
  request: CallableRequest<unknown>,
  deps: PoolModerationDeps,
): Promise<{ ok: true }> {
  requireAdmin(request);
  const input = parseQuarantine(request.data);
  await deps.rateLimit(request.auth!.uid, "adminSetPoolQuarantine");
  return setPoolQuarantine(request.auth!.uid, input, deps);
}

export const adminInspectPool = onCall(
  { timeoutSeconds: 30, cors: WEB_CALLABLE_ORIGINS, enforceAppCheck: true },
  async (request) => handleInspectPool(request, productionDeps()),
);

export const adminSetPoolQuarantine = onCall(
  { timeoutSeconds: 30, cors: WEB_CALLABLE_ORIGINS, enforceAppCheck: true },
  async (request) => handleSetPoolQuarantine(request, productionDeps()),
);
