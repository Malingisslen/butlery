/**
 * Per-feature DAU + rolling 7d/28d WAU/MAU (BUT-599).
 *
 * Scheduled daily at 04:30 UTC — 30 minutes after `track-retention.ts` so
 * the two user-iteration jobs do not collide. For every user with
 * `lastActiveAt` in the trailing 28 days the function checks five feature
 * activity sources for the run-day (UTC) and writes:
 *
 *   /analytics/feature_retention/users/{uid}_{yyyy-mm-dd}
 *     — { userId, date, cooked, imported, shared, mealPlanned, shopped }
 *   /analytics/feature_retention/daily/{yyyy-mm-dd}
 *     — { date, dau:{...}, wau7d:{...}, wau28d:{...}, computedAt }
 *
 * `wau28d` doubles as the MAU proxy — a rolling 28-day window is
 * functionally equivalent to MAU for cohort dashboards and avoids a second
 * pass with different boundaries. The ticket says "WAU/MAU"; the field
 * name pins the actual semantics.
 *
 * **Idempotency**: deterministic doc ids → re-run on the same UTC day
 * overwrites both the per-user-per-day rows and the daily aggregate.
 * Mirrors the BUT-605 retention idempotency contract.
 *
 * **Read budget (per run, ~1k active users)**:
 *   - 1 paginated user scan (`lastActiveAt >= now - 28d`) → ≤1k reads
 *   - 5 per-user per-day activity queries → up to 5k reads (today's flags)
 *   - 28 per-user historical flag-doc reads for WAU rollup → up to 28k reads
 *   - = ~34k reads/day at 1k active users ≈ $0.012/day on the Firestore
 *     read price tier as of 2026. Acceptable for a daily aggregator. If
 *     active users grow past ~10k, the historical-flag scan becomes the
 *     dominant cost — at that scale switch to a daily counter doc per
 *     feature instead of per-user history.
 *
 * Feature → source mapping (verified against codebase 2026-05-01):
 *
 *   | Flag         | Source                                                 |
 *   | cooked       | `cook_snaps` where userId == uid AND createdAt in day  |
 *   | imported     | `users/{uid}/recipes` where core.createdAt in day      |
 *   | shared       | `shared_recipes` where sharedByUserId == uid AND       |
 *   |              | sharedAt in day                                        |
 *   | mealPlanned  | `users/{uid}/menus` where createdAt in day             |
 *   | shopped      | `users/{uid}/shopping_lists` where updatedAt in day    |
 *
 * Rationale for `shopped`: shopping lists are long-lived (created once,
 * updated as items get checked off). `createdAt` would dramatically
 * undercount actual usage. `updatedAt` better reflects the "did the user
 * touch a shopping list today" signal even though it conflates checking
 * off an item with editing the list metadata.
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";

const MS_PER_DAY = 24 * 60 * 60 * 1000;
const BATCH_LIMIT = 500;
const PAGE_SIZE = 500;
const WAU_28D = 28;
const WAU_7D = 7;
/** Reserve 1 op for the daily aggregate write. */
const OPS_RESERVE = 1;

export type FeatureFlag =
  | "cooked"
  | "imported"
  | "shared"
  | "mealPlanned"
  | "shopped";

const FEATURE_FLAGS: readonly FeatureFlag[] = [
  "cooked",
  "imported",
  "shared",
  "mealPlanned",
  "shopped",
];

export interface UserDailyFlags {
  userId: string;
  /** UTC `yyyy-mm-dd`. */
  date: string;
  cooked: boolean;
  imported: boolean;
  shared: boolean;
  mealPlanned: boolean;
  shopped: boolean;
}

export interface DailyAggregate {
  date: string;
  dau: Record<FeatureFlag, number>;
  wau7d: Record<FeatureFlag, number>;
  /** Rolling 28-day window — serves as the MAU proxy. */
  wau28d: Record<FeatureFlag, number>;
  computedAt: admin.firestore.Timestamp;
}

export interface RunDeps {
  db?: admin.firestore.Firestore;
  now?: Date;
}

const getDb = () => admin.firestore();

/** Format a UTC `yyyy-mm-dd` from a millisecond timestamp. */
export function formatUtcDate(ms: number): string {
  const d = new Date(ms);
  const yyyy = d.getUTCFullYear();
  const mm = String(d.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(d.getUTCDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
}

/** Start-of-day (UTC) for a millisecond timestamp. */
function startOfUtcDay(ms: number): number {
  const d = new Date(ms);
  return Date.UTC(
    d.getUTCFullYear(),
    d.getUTCMonth(),
    d.getUTCDate(),
    0,
    0,
    0,
    0,
  );
}

/** Empty zero-counters for a fresh aggregate. */
function emptyCounters(): Record<FeatureFlag, number> {
  return {
    cooked: 0,
    imported: 0,
    shared: 0,
    mealPlanned: 0,
    shopped: 0,
  };
}

/**
 * Probe the five feature sources for a single user on a single day.
 * Each probe is `limit(1)` — we only care whether ANY activity exists,
 * not the exact count. If a probe throws (collection missing, index
 * missing), the flag falls back to `false` and we log once at warn so
 * an operator can investigate; the function does not crash the whole
 * run.
 */
async function probeUserFeatureFlags(
  db: admin.firestore.Firestore,
  userId: string,
  dayStart: admin.firestore.Timestamp,
  dayEnd: admin.firestore.Timestamp,
): Promise<Omit<UserDailyFlags, "userId" | "date">> {
  const safeProbe = async (
    label: FeatureFlag,
    fn: () => Promise<FirebaseFirestore.QuerySnapshot>,
  ): Promise<boolean> => {
    try {
      const snap = await fn();
      return snap.size > 0;
    } catch (err) {
      logger.warn("feature_retention_probe_failed", {
        flag: label,
        userId,
        err,
      });
      return false;
    }
  };

  const [cooked, imported, shared, mealPlanned, shopped] = await Promise.all([
    safeProbe("cooked", () =>
      db
        .collection("cook_snaps")
        .where("userId", "==", userId)
        .where("createdAt", ">=", dayStart)
        .where("createdAt", "<", dayEnd)
        .limit(1)
        .get(),
    ),
    safeProbe("imported", () =>
      db
        .collection("users")
        .doc(userId)
        .collection("recipes")
        .where("core.createdAt", ">=", dayStart)
        .where("core.createdAt", "<", dayEnd)
        .limit(1)
        .get(),
    ),
    safeProbe("shared", () =>
      db
        .collection("shared_recipes")
        .where("sharedByUserId", "==", userId)
        .where("sharedAt", ">=", dayStart)
        .where("sharedAt", "<", dayEnd)
        .limit(1)
        .get(),
    ),
    safeProbe("mealPlanned", () =>
      db
        .collection("users")
        .doc(userId)
        .collection("menus")
        .where("createdAt", ">=", dayStart)
        .where("createdAt", "<", dayEnd)
        .limit(1)
        .get(),
    ),
    safeProbe("shopped", () =>
      db
        .collection("users")
        .doc(userId)
        .collection("shopping_lists")
        .where("updatedAt", ">=", dayStart)
        .where("updatedAt", "<", dayEnd)
        .limit(1)
        .get(),
    ),
  ]);

  return { cooked, imported, shared, mealPlanned, shopped };
}

/** Read a previously-written per-user-per-day flag doc, if any. */
async function readUserDailyFlags(
  db: admin.firestore.Firestore,
  userId: string,
  dateStr: string,
): Promise<Pick<UserDailyFlags, FeatureFlag> | null> {
  const ref = db
    .collection("analytics")
    .doc("feature_retention")
    .collection("users")
    .doc(`${userId}_${dateStr}`);
  const snap = await ref.get();
  if (!snap.exists) return null;
  const data = snap.data() ?? {};
  return {
    cooked: data.cooked === true,
    imported: data.imported === true,
    shared: data.shared === true,
    mealPlanned: data.mealPlanned === true,
    shopped: data.shopped === true,
  };
}

/**
 * Test-seam entrypoint. Production schedule wrapper just calls
 * `runComputeFeatureRetention()`; tests pin `db` and `now`.
 */
export async function runComputeFeatureRetention(
  deps: RunDeps = {},
): Promise<{
  usersScanned: number;
  featureFlagsWritten: number;
  dailyAggregateDocs: number;
}> {
  const db = deps.db ?? getDb();
  const nowMs = deps.now != null ? deps.now.getTime() : Date.now();
  const todayStartMs = startOfUtcDay(nowMs);
  const todayEndMs = todayStartMs + MS_PER_DAY;
  const dateStr = formatUtcDate(todayStartMs);

  const dayStart = admin.firestore.Timestamp.fromMillis(todayStartMs);
  const dayEnd = admin.firestore.Timestamp.fromMillis(todayEndMs);
  const wau28StartMs = todayStartMs - (WAU_28D - 1) * MS_PER_DAY;
  const activeCutoff = admin.firestore.Timestamp.fromMillis(wau28StartMs);

  logger.info("compute_feature_retention_start", { date: dateStr });

  // ── 1. DAU pass: scan every user with activity in the last 28d, probe
  //      feature sources for the run-day, write per-user flag docs.
  const dau = emptyCounters();
  const todayUserFlags = new Map<string, Pick<UserDailyFlags, FeatureFlag>>();

  let usersScanned = 0;
  let featureFlagsWritten = 0;
  let batch = db.batch();
  let batchCount = 0;

  let query = db
    .collection("users")
    .where("lastActiveAt", ">=", activeCutoff)
    .orderBy("lastActiveAt")
    .limit(PAGE_SIZE);
  let usersSnapshot = await query.get();

  while (usersSnapshot.size > 0) {
    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      const flags = await probeUserFeatureFlags(
        db,
        userId,
        dayStart,
        dayEnd,
      );

      const flagDocRef = db
        .collection("analytics")
        .doc("feature_retention")
        .collection("users")
        .doc(`${userId}_${dateStr}`);
      batch.set(flagDocRef, {
        userId,
        date: dateStr,
        ...flags,
      });
      batchCount++;
      featureFlagsWritten++;
      usersScanned++;
      todayUserFlags.set(userId, flags);

      // DAU = users with at least one TRUE today.
      if (flags.cooked) dau.cooked++;
      if (flags.imported) dau.imported++;
      if (flags.shared) dau.shared++;
      if (flags.mealPlanned) dau.mealPlanned++;
      if (flags.shopped) dau.shopped++;

      if (batchCount >= BATCH_LIMIT - OPS_RESERVE) {
        await batch.commit();
        batch = db.batch();
        batchCount = 0;
      }
    }
    const lastDoc = usersSnapshot.docs[usersSnapshot.docs.length - 1];
    usersSnapshot = await query.startAfter(lastDoc).get();
  }

  if (batchCount > 0) {
    await batch.commit();
    batch = db.batch();
    batchCount = 0;
  }

  // ── 2. WAU rollup: for each scanned user, fetch the prior 27 days of
  //      flag docs (deterministic ids), OR-reduce per flag inside the
  //      7d / 28d windows. Today is included from the in-memory map so
  //      we don't read what we just wrote.
  const wau7d = emptyCounters();
  const wau28d = emptyCounters();

  for (const [userId, todayFlags] of todayUserFlags.entries()) {
    const seenAnyIn7 = emptyCounters();
    const seenAnyIn28 = emptyCounters();

    // Day 0 = today; reuse in-memory result.
    accumulateInto(seenAnyIn7, todayFlags);
    accumulateInto(seenAnyIn28, todayFlags);

    // Days 1..27 (UTC midnight backwards). Parallelize the 27 reads
    // for THIS user — Firestore SDK trivially handles 27 concurrent
    // gets, and serial reads are the dominant cost (sequential = 27 ×
    // ~30ms = ~800ms per user, parallel ≈ ~30ms). Cross-user fan-out
    // is still bounded because the outer `for` over users is serial.
    const dayOffsets: number[] = [];
    for (let offset = 1; offset < WAU_28D; offset++) {
      dayOffsets.push(offset);
    }
    const priorReads = await Promise.all(
      dayOffsets.map((offset) => {
        const day = formatUtcDate(todayStartMs - offset * MS_PER_DAY);
        return readUserDailyFlags(db, userId, day).then((prior) => ({
          offset,
          prior,
        }));
      })
    );
    for (const { offset, prior } of priorReads) {
      if (prior == null) continue;
      if (offset < WAU_7D) accumulateInto(seenAnyIn7, prior);
      accumulateInto(seenAnyIn28, prior);
    }

    bumpAggregate(wau7d, seenAnyIn7);
    bumpAggregate(wau28d, seenAnyIn28);
  }

  // ── 3. Daily aggregate doc.
  const aggregateRef = db
    .collection("analytics")
    .doc("feature_retention")
    .collection("daily")
    .doc(dateStr);
  await aggregateRef.set({
    date: dateStr,
    dau,
    wau7d,
    wau28d,
    computedAt: admin.firestore.Timestamp.fromMillis(nowMs),
  });

  logger.info("compute_feature_retention_complete", {
    date: dateStr,
    usersScanned,
    featureFlagsWritten,
    dau,
    wau7d,
    wau28d,
  });

  return {
    usersScanned,
    featureFlagsWritten,
    dailyAggregateDocs: 1,
  };
}

/** OR-merge a flag set into an "any-true-seen" counter. */
function accumulateInto(
  acc: Record<FeatureFlag, number>,
  flags: Pick<UserDailyFlags, FeatureFlag>,
): void {
  for (const f of FEATURE_FLAGS) {
    if (flags[f]) acc[f] = 1;
  }
}

/** Add a per-user any-seen vector into the cohort total. */
function bumpAggregate(
  total: Record<FeatureFlag, number>,
  perUser: Record<FeatureFlag, number>,
): void {
  for (const f of FEATURE_FLAGS) {
    if (perUser[f] > 0) total[f]++;
  }
}

export const computeFeatureRetention = onSchedule(
  { schedule: "30 4 * * *", timeZone: "UTC" },
  async () => {
    try {
      await runComputeFeatureRetention();
    } catch (err) {
      logger.error("compute_feature_retention_failed", { err });
      throw err;
    }
  },
);
