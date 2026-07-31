/**
 * Per-feature DAU + rolling 7d/28d WAU/MAU (BUT-599).
 *
 * Scheduled daily at 04:30 UTC — 30 minutes after `track-retention.ts` so
 * the two user-iteration jobs do not collide. For every user with
 * `lastActiveAt` in the trailing 28 days the function checks six feature
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
 *   - 6 per-user per-day activity queries → up to 6k reads (today's flags)
 *   - 28 per-user historical flag-doc reads for WAU rollup → up to 28k reads
 *   - = ~35k reads/day at 1k active users ≈ $0.013/day on the Firestore
 *     read price tier as of 2026. Acceptable for a daily aggregator. If
 *     active users grow past ~10k, the historical-flag scan becomes the
 *     dominant cost — at that scale switch to a daily counter doc per
 *     feature instead of per-user history.
 *
 * Feature → source mapping (`shopped` re-verified 2026-07-30, BUT-1724 +
 * BUT-1761):
 *
 *   | Flag         | Source                                                 |
 *   | cooked       | `cook_snaps` where userId == uid AND createdAt in day  |
 *   | imported     | `users/{uid}/recipes` where core.createdAt in day      |
 *   | shared       | `shared_recipes` where sharedByUserId == uid AND       |
 *   |              | sharedAt in day                                        |
 *   | mealPlanned  | `users/{uid}/menus` where createdAt in day             |
 *   | shopped      | EITHER leg true: (a) `users/{uid}/unified_shopping_    |
 *   |              | lists` where updatedAt in day — the PERSONAL leg;      |
 *   |              | (b) `unified_shared_shopping_lists` where              |
 *   |              | lastActivityByUserId == uid AND updatedAt in day —     |
 *   |              | the COLLABORATIVE leg (BUT-1761)                       |
 *
 * Rationale for `shopped`: shopping lists are long-lived (created once,
 * updated as items get checked off). `createdAt` would dramatically
 * undercount actual usage, so both legs filter on `updatedAt`.
 *
 * BUT-1724: this probe used to read `users/{uid}/shopping_lists`, the
 * pre-rename name that nothing has written since BUT-1697 — so `shopped`
 * was false for every user every day and every `shopped` number in the
 * retention dashboard was structurally zero, not a real signal. The live
 * personal-list path is `users/{uid}/unified_shopping_lists`
 * (`FirebaseShoppingRepository.collectionName`); its documents carry both
 * `createdAt` and `updatedAt` as Timestamps.
 *
 * BUT-1761: BUT-1724 fixed only the PERSONAL leg, and a collaborative list
 * never lived under `users/{uid}` at all — `ListType.collaborative` is routed
 * to the top-level `unified_shared_shopping_lists` by
 * `ShoppingRepositoryRoutingModule`. So a household that shops exclusively on
 * a shared list still scored `shopped: false` every day: the flagship
 * collaborative flow was structurally zero for exactly the same reason the
 * whole flag was before BUT-1724, just one collection over. The second leg
 * below closes that. It matches on `lastActivityByUserId`, the same stamp
 * `account-deletion-cascade.ts` queries to find a user's shared-list activity,
 * and every list mutator on `UnifiedShoppingList` (add / tick / amend /
 * remove) rewrites it together with `updatedAt`. Equality + range on two
 * different fields needs a DECLARED COMPOSITE INDEX (`lastActivityByUserId`
 * ASC, `updatedAt` ASC) — unlike the equality-only queries elsewhere in the
 * app; it is in `firestore.indexes.json` and a test pins it there, because
 * without it the probe throws FAILED_PRECONDITION, `safeProbe` swallows it,
 * and the leg reads as a silent zero again.
 *
 * KNOWN GAPS in `shopped` — read these before quoting the number:
 *
 *  1. THE COLLABORATIVE LEG IS LAST-WRITER-ONLY, SO IT IS A LOWER BOUND
 *     (BUT-1761 residual). `lastActivityByUserId` is a single stamp the list
 *     document overwrites on every mutation. When two household members both
 *     shop off the same list on the same day, only the one who wrote LAST
 *     scores `shopped` for it. The obvious alternative is worse in the other
 *     direction: `contributorUserIds` is append-only and never cleared
 *     (BUT-1725 makes that a rule), so `array-contains` would credit every
 *     member who has EVER touched the list with shopping on any day anyone
 *     touched it. A per-day-exact answer needs a per-member activity stamp the
 *     document does not carry, which is a schema change, not a probe change.
 *
 *  2. Personal-list item ticks are under-counted (accepted, not a bug in this
 *     file): items live in an `items` subcollection and a tick or amend writes
 *     only that subcollection — the parent list document's `updatedAt` is not
 *     bumped. So the PERSONAL leg catches list creation and list-level edits,
 *     and misses a session that only checked items off. Closing it means
 *     either bumping the parent on every item write (an extra write per tick)
 *     or a per-day counter doc; both are cost decisions beyond this probe.
 *     The collaborative leg does not share this gap — a shared list embeds its
 *     `items` array in the list document, so a tick rewrites that document.
 *
 *  3. THE ROLLUPS RAMP IN AFTER DEPLOY, AND THE RAMP LOOKS LIKE ADOPTION.
 *     `wau7d` and `wau28d` OR together previously STORED per-day flag docs, and
 *     every one of those written before a `shopped` fix carries whichever
 *     structural zero that fix removed — BUT-1724 for the personal leg,
 *     BUT-1761 for the collaborative one. So `shopped` climbs for 7 and then
 *     28 days after each deploy purely as the window refills with correct
 *     days — a dashboard artefact, not behaviour change. The rollups only mean
 *     anything 28 days after the latest of those deploy dates; the DAU figure
 *     is trustworthy from day one.
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { Collections } from "../shared/collections";
import { hashUid } from "../shared/hash-uid";

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
 * Probe log labels. `shopped` has TWO probes behind one flag, so the labels
 * name the leg rather than the flag: an operator reading
 * `feature_retention_probe_failed` has to be able to tell a missing composite
 * index on the shared collection from a failure on the personal
 * subcollection, and both would otherwise print `"flag":"shopped"`.
 */
type ProbeLabel = FeatureFlag | "shoppedShared";

/**
 * Probe the six feature sources for a single user on a single day.
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
    label: ProbeLabel,
    fn: () => Promise<FirebaseFirestore.QuerySnapshot>,
  ): Promise<boolean> => {
    try {
      const snap = await fn();
      return snap.size > 0;
    } catch (err) {
      // Two separate defects lived on this line. `userId` in cleartext put a
      // raw uid in an operator-readable log, against the family convention
      // (`hashUid` everywhere else, e.g. on-profile-updated.ts:74). And `err`
      // nested inside the payload object serialises to `{}` — firebase-functions
      // only unwraps an Error passed POSITIONALLY — so the one field that was
      // supposed to say WHY the probe failed said nothing at all. The suite's
      // own passing output printed `{"flag":"cooked","userId":"uProbe","err":{}}`.
      //
      // `message` stays excluded ON PURPOSE, and that is not an oversight to
      // helpfully repair: a Firestore error text carries `users/<raw uid>/...`
      // paths and `create_composite` URLs, so adding it back would defeat the
      // hash on the line below. `code`/`name` are enough to tell a missing
      // index from a deadline, which is the whole operational question here.
      logger.warn("feature_retention_probe_failed", {
        flag: label,
        userIdHash: hashUid(userId),
        errCode: (err as { code?: number | string }).code,
        errName: (err as { name?: string }).name,
      });
      return false;
    }
  };

  const [
    cooked,
    imported,
    shared,
    mealPlanned,
    shoppedPersonal,
    shoppedShared,
  ] = await Promise.all([
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
        .collection(Collections.unifiedShoppingLists)
        .where("updatedAt", ">=", dayStart)
        .where("updatedAt", "<", dayEnd)
        .limit(1)
        .get(),
    ),
    // BUT-1761: the collaborative leg. Top-level collection, so membership has
    // to come from a field — `lastActivityByUserId` is the one the document
    // actually carries per-user activity in. Needs the declared composite; see
    // the header note and `sharedShoppingListCompositeDeclared` in the test.
    safeProbe("shoppedShared", () =>
      db
        .collection(Collections.unifiedSharedShoppingLists)
        .where("lastActivityByUserId", "==", userId)
        .where("updatedAt", ">=", dayStart)
        .where("updatedAt", "<", dayEnd)
        .limit(1)
        .get(),
    ),
  ]);

  // One flag, two sources: the dashboard question is "did this person shop
  // today", not "on which kind of list". Splitting it would change the stored
  // document schema and every historical row's meaning.
  return {
    cooked,
    imported,
    shared,
    mealPlanned,
    shopped: shoppedPersonal || shoppedShared,
  };
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
