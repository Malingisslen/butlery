/**
 * Per-feature DAU + rolling 7d/28d WAU/MAU (BUT-599).
 *
 * Runs as the second task in the `dailyAnalytics` chain (06:00 UTC — see
 * `scheduled/maintenance-dispatchers.ts`); it no longer owns a Cloud
 * Scheduler job. It shares a process with `trackDayNRetention` and runs
 * strictly after it, so the two user-iteration scans can no longer overlap
 * AT ALL — the old 30-minute stagger is obsolete, not merely moved. Do not
 * "restore" it by re-adding an `onSchedule`: that re-introduces the
 * per-job Cloud Scheduler charge this merge exists to remove. For every user with
 * `lastActiveAt` in the trailing 28 days the function checks six feature
 * activity sources for the PREVIOUS, COMPLETED UTC day and writes:
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
 * **Which day is probed, and why it is not the run day (BUT-1791)**: the job
 * runs at 06:00 UTC, so `startOfUtcDay(now)` — the day it is currently
 * standing in — is only 6 hours old when it is asked about. Every activity
 * later that day lands after the run, and the next run used to ask about the
 * NEXT day instead, so it was never queried by anyone: all five flags measured
 * the small hours (02:00–06:30 Swedish summer time) while reading as a whole
 * day. The window is therefore `startOfUtcDay(now) - MS_PER_DAY`, a day that
 * has finished, and `dateStr` labels the row with the day it actually
 * measures. Two consequences a reader should expect rather than file: the
 * newest `daily/{date}` document is dated YESTERDAY (one-day dashboard lag,
 * the price of a complete day), and every row written before this deploy
 * carries the truncated meaning — see KNOWN GAP 3.
 *
 * **Idempotency**: deterministic doc ids → re-run on the same UTC day
 * overwrites both the per-user-per-day rows and the daily aggregate.
 * Mirrors the BUT-605 retention idempotency contract.
 *
 * **Retention of the per-user rows (BUT-1789)**: `users/{uid}_{date}` is
 * personal data keyed by a live uid, so account deletion erases it —
 * `deleteFeatureRetentionFlags` in `account/account-deletion-cascade.ts`
 * sweeps `userId == uid` and `probeResidualData` counts the same handle
 * afterwards. There is deliberately NO TTL on this subcollection: its
 * collectionGroup id is `users`, the same id as the top-level profile
 * collection, so a TTL fieldOverride here would arm a delete policy over real
 * user documents. The `daily/{date}` aggregates hold integer counts and no
 * uid, and are not rewritten when an account goes (accepted deviation,
 * BUT-1789).
 *
 * **Read budget (per run, ~1k active users)**:
 *   - 1 paginated user scan (`lastActiveAt >= now - 28d`) → ≤1k reads
 *   - 6 per-user per-day activity queries → up to 6k reads (probed day's flags)
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
 *  2. CLOSED by BUT-1762 (2026-07-31) — kept here because the shape of the fix
 *     is what the numbers mean. Personal items live in an `items`
 *     subcollection, and every item write touched only that subcollection, so
 *     the parent's `updatedAt` never moved. The gap was WIDER than "tick-only":
 *     add, amend, remove and both bulk paths were all invisible, so the
 *     PERSONAL leg saw list creation and list-level edits and nothing else.
 *     `ShoppingItemOperationsModule._touchPersonalListDay` now stamps the
 *     parent — at most ONCE PER UTC DAY, from all six write branches, and only
 *     after the item write succeeds. Day-coalescing is the cost decision: a
 *     30-item shop bills one extra write instead of thirty, and a unit test
 *     pins it (removing the day guard reddens exactly that test), because
 *     without the guard this silently degrades into the ~18x-dearer variant
 *     that was rejected. The collaborative leg never shared this gap — a shared
 *     list embeds `items` in the list document.
 *
 *     WHAT `shopped` MEANS NOW, stated once so it is not re-derived: the
 *     personal leg STAMPS every shopping day, "Rensa klart" included, and
 *     since BUT-1791 the job asks about a day that has finished, so the stamp
 *     is actually inside the queried window. The collaborative
 *     leg is additionally LAST-WRITER-ONLY (gap 1) — `lastActivityByUserId` is
 *     a single stamp, so when two household members shop the same shared list
 *     on the same day, only the last writer scores. Every flag this job writes
 *     therefore remains a LOWER BOUND, for the gap-4 reason if no other.
 *
 *     Residual, accepted: the parent stamp is fire-and-forget with a swallowed
 *     warning — it must never fail a shopper's tick — and there is no alerting
 *     on that warning today, so a systematic failure would degrade this metric
 *     quietly. Recorded rather than assumed covered.
 *
 *  3. THE ROLLUPS RAMP IN AFTER DEPLOY, AND THE RAMP LOOKS LIKE ADOPTION.
 *     `wau7d` and `wau28d` OR together previously STORED per-day flag docs, and
 *     every one of those written before a fix carries whichever structural
 *     zero that fix removed. The ramp triggers, oldest to newest:
 *       - BUT-1724 — the personal `shopped` leg read a retired collection;
 *       - BUT-1761 — the collaborative `shopped` leg did not exist;
 *       - BUT-1762 (2026-07-31) — personal ITEM activity never moved the
 *         parent list's `updatedAt`;
 *       - BUT-1791 (2026-08-01) — the job probed the day it was standing in
 *         and so saw only its first 4.5 hours. This one is the latest AND the
 *         widest: it caps every flag, not just `shopped`, so it is the entry
 *         that sets the clock for all five series.
 *     So each series climbs for 7 and then 28 days after the latest of those
 *     deploys, purely as the window refills with correct days — a dashboard
 *     artefact, not behaviour change. The rollups only mean anything 28 days
 *     after 2026-08-01. The DAU figure is trustworthy from the first run
 *     AFTER that deploy, not from the rows already on disk.
 *
 *     Said plainly for whoever reads the dashboard: each of those deploys makes
 *     the numbers rise on their own for up to a month afterwards, and that rise
 *     is the measurement catching up, not growth.
 *
 *     BUT-1762 produced almost no ramp of its own, and that was expected
 *     rather than a failed deploy: until BUT-1791 the queried window ended at
 *     04:30 UTC, so the personal leg only caught a shopping trip whose FIRST
 *     item write of the day landed before then — almost nobody. Day-coalescing
 *     neither caused nor rescued that (the first write of a day always stamps,
 *     and that is precisely the one inside the old window). The two fixes
 *     compound from BUT-1791 onward.
 *
 *     (NO series this job writes is one of `detect-anomalies.ts`'s five
 *     MONITORED_SERIES — those read `import_health`, `recipes`,
 *     `parsing_corrections`, `ops` and `feedback`, all written by
 *     `daily-snapshots.ts`. So none of these step changes, BUT-1791's
 *     across-the-board one included, can trip a false z-score alert. Checked
 *     2026-07-31 for `shopped`, re-checked against the whole flag set
 *     2026-08-01.)
 */

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
 * Test-seam entrypoint, and the production entrypoint: the `dailyAnalytics`
 * dispatcher calls it with no overrides; tests pin `db` and `now`.
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
  // BUT-1791: the PREVIOUS UTC day, not the one the 06:00 run is standing in.
  // Everything downstream — `dateStr`, the probe window, the WAU offsets and
  // the active-user cutoff — is derived from this one base so the row, the
  // window it measures and the rollup that reads it can never disagree.
  const probeStartMs = startOfUtcDay(nowMs) - MS_PER_DAY;
  const probeEndMs = probeStartMs + MS_PER_DAY;
  const dateStr = formatUtcDate(probeStartMs);

  const dayStart = admin.firestore.Timestamp.fromMillis(probeStartMs);
  const dayEnd = admin.firestore.Timestamp.fromMillis(probeEndMs);
  const wau28StartMs = probeStartMs - (WAU_28D - 1) * MS_PER_DAY;
  const activeCutoff = admin.firestore.Timestamp.fromMillis(wau28StartMs);

  logger.info("compute_feature_retention_start", { date: dateStr });

  // ── 1. DAU pass: scan every user with activity in the last 28d, probe
  //      feature sources for the probed day, write per-user flag docs.
  const dau = emptyCounters();
  const probeDayUserFlags = new Map<string, Pick<UserDailyFlags, FeatureFlag>>();

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
      probeDayUserFlags.set(userId, flags);

      // DAU = users with at least one TRUE on the probed day.
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
  //      7d / 28d windows. The probed day itself is included from the
  //      in-memory map so we don't read what we just wrote.
  const wau7d = emptyCounters();
  const wau28d = emptyCounters();

  for (const [userId, probeDayFlags] of probeDayUserFlags.entries()) {
    const seenAnyIn7 = emptyCounters();
    const seenAnyIn28 = emptyCounters();

    // Day 0 = the probed day; reuse in-memory result.
    accumulateInto(seenAnyIn7, probeDayFlags);
    accumulateInto(seenAnyIn28, probeDayFlags);

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
        const day = formatUtcDate(probeStartMs - offset * MS_PER_DAY);
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
