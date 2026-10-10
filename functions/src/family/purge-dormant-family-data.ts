/**
 * Storage-limitation sweep for family-rating data (GDPR Art. 5(1)(e)).
 *
 * DPO-confirmed retention: a household whose FAMILY data has been dormant for
 * 24 months is **warned, then purged** unless it reactivates. See
 * `docs/security/family-data-retention.md`.
 *
 * "Family data" = the household's `diner_profiles` + `family_ratings`. The
 * household doc and member accounts have their own lifecycle and are NOT
 * deleted here — only the family-feature data under storage limitation.
 *
 * Two-pass, so data is never purged the instant it becomes eligible:
 *   1. WARN — first time a household crosses the dormancy line: write an in-app
 *      notification to each member and stamp `familyDataPurgeScheduledAt` =
 *      now + grace. (In-app is the recorded warning; email is a stronger
 *      channel for truly-dormant users and is a sensible future enhancement.)
 *   2. PURGE — only once the grace window has elapsed AND the household is still
 *      dormant: delete the family data (strict batch — a failed chunk throws so
 *      the run is recorded as failed, never a silent partial purge).
 * Reactivation at any point clears the scheduled purge.
 *
 * Dormancy signal: the newest of the household's `updatedAt`, its diner
 * profiles' `updatedAt`, and its family ratings' `lastUpdatedAt`.
 *
 * BUT-1600 — orphan reconciliation (runs first, every household, every sweep,
 * regardless of dormancy): a `family_ratings` doc whose `memberId` is no longer
 * in the household roster (a deleted diner profile, or a departed account
 * holder) still counts toward the recipe-detail breakdown total and the
 * denormalised recipe-card family average, even though no roster row renders for
 * it — so the count can exceed the visible rows. Diner-profile deletion does not
 * cascade to its ratings, so this janitor is the catch-all: it deletes such
 * orphaned ratings (each delete fires `onFamilyRatingDeleted` → public
 * aggregation recompute) and recomputes the denormalised
 * `core.familyAverage`/`core.familyRatingCount` on each household member's own
 * recipe copy from the surviving ratings.
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { commitInChunks } from "../shared/batch-update";
import { recomputeDenormalisedAverages } from "./family-card-averages";

const DAY_MS = 24 * 60 * 60 * 1000;
const DORMANCY_DAYS = 730; // 24 months (DPO-confirmed)
const GRACE_DAYS = 30; // warn-before-purge window
const HOUSEHOLDS_PER_RUN = 200; // bounded; paginates at scale

/**
 * BUT-1671: wall clock one run gives itself, under the 300 s function timeout,
 * before it saves its place and leaves the rest of the pass to next week. A
 * pass that outgrows one run therefore spans several, and every household is
 * still reached in turn instead of the front of the collection every week.
 */
const SWEEP_DEADLINE_MS = 240_000;

/**
 * The longest a pass may take before the run is recorded failed: the accepted
 * maximum slip past a household's purge date (Privacy / DPO, 2026-10-09).
 */
const MAX_PASS_AGE_DAYS = 28;

/**
 * Where an unfinished pass resumes. It holds the last household id visited, so
 * it is deleted when a pass completes and overwritten on every run before then.
 */
export const PURGE_CURSOR_DOC = "_internal/family_purge_cursor";

export interface PurgeRunResult {
  scanned: number;
  warned: number;
  purged: number;
  reactivated: number;
  /** BUT-1600: family_ratings deleted because their rater left the household. */
  orphansReconciled: number;
  /** Households whose processing threw; the pass moved past each of them. */
  failed: number;
  /** True when this run reached the end of the collection. */
  passComplete: boolean;
  /** Whole days since the current pass started. */
  passAgeDays: number;
  /** The pass is older than `MAX_PASS_AGE_DAYS`. */
  overdue: boolean;
}

/** String memberIds still present in the household roster (accounts + diners). */
function rosterMemberIds(
  memberUserIds: string[],
  diners: admin.firestore.QuerySnapshot
): Set<string> {
  return new Set<string>([...memberUserIds, ...diners.docs.map((d) => d.id)]);
}

/**
 * BUT-1600: delete family_ratings whose rater left the roster and recompute the
 * affected recipe cards. Reuses the already-fetched `diners`/`ratings`
 * snapshots (no extra household reads). Returns the surviving rating docs so the
 * dormancy pass below judges activity + purges on the reconciled set. Idempotent:
 * a re-run finds no orphans (set difference) and the recompute is deterministic.
 */
async function reconcileDepartedMemberRatings(
  db: admin.firestore.Firestore,
  memberUserIds: string[],
  diners: admin.firestore.QuerySnapshot,
  ratings: admin.firestore.QuerySnapshot,
  result: PurgeRunResult
): Promise<admin.firestore.QueryDocumentSnapshot[]> {
  if (ratings.empty) return ratings.docs;
  const roster = rosterMemberIds(memberUserIds, diners);
  // Fail closed on a fully-empty keep-set (BOTH id-space halves collapsed). A
  // rating's existence proves a member once existed, so an empty roster means the
  // read was empty/under-populated, NOT that everyone left. Diff-deleting against
  // ∅ would delete EVERY rating — irreversible, silent (strict:false), and it
  // also corrupts public aggregates via onFamilyRatingDeleted. Skip; the orphans
  // re-detect next sweep once the roster reads correctly.
  if (roster.size === 0) {
    logger.warn("family-retention: skipped orphan reconcile (empty roster)", {
      householdId: (ratings.docs[0].data().householdId as string) ?? "unknown",
      ratingCount: ratings.docs.length,
    });
    return ratings.docs;
  }
  // The keep-set has two INDEPENDENT halves with different trust properties:
  //  - Diner ids come from an authoritative equality query: an empty result is
  //    the genuine "all diner profiles deleted" signal, so a profile-type rating
  //    absent from it is a real orphan even when the diner set is empty.
  //  - Account ids come from `memberUserIds`, a DENORMALISED projection that can
  //    read empty/missing on a corrupt or partially-written household doc. An
  //    empty projection is "unknown", not "no members" — trusting it would delete
  //    EVERY account-holder rating at once (same fault as the total wipe above,
  //    but hidden because live diners keep `roster` non-empty). So only treat a
  //    user-type rating as orphaned when the account half is non-empty; otherwise
  //    defer it to a sweep that reads a real roster.
  const accountRosterTrusted = memberUserIds.length > 0;
  const orphans = ratings.docs.filter((r) => {
    const data = r.data();
    const mid = data.memberId;
    if (typeof mid !== "string" || roster.has(mid)) return false;
    // Delete only when the rating positively belongs to a TRUSTED keep-half.
    // Fail closed on anything else: a user-type rating whose account half is
    // untrusted, and any rating whose memberType is missing/unrecognised (legacy
    // or corrupt doc), is kept rather than deleted — a stale count is cheap; an
    // irreversible wrong delete of a member's/child's rating is not.
    const type = data.memberType;
    if (type === "user") return accountRosterTrusted;
    if (type === "profile") return true; // diner half is authoritative
    return false;
  });
  if (orphans.length === 0) return ratings.docs;

  const orphanIds = new Set(orphans.map((o) => o.id));
  const survivors = ratings.docs.filter((d) => !orphanIds.has(d.id));

  // Best-effort (strict:false): an orphan left behind is re-detected next sweep,
  // and this is hygiene, not a legal-retention guarantee (that is the purge pass
  // below, which stays strict).
  await commitInChunks(db, orphans, (batch, doc) => batch.delete(doc.ref), {
    label: "reconcileDepartedFamilyRatings",
    strict: false,
  });
  result.orphansReconciled += orphans.length;

  await recomputeDenormalisedAverages(db, orphans, survivors, memberUserIds);
  return survivors;
}

/** Millis of a Firestore Timestamp-ish value, or 0 if absent/!Timestamp. */
function millisOf(v: unknown): number {
  return v && typeof (v as admin.firestore.Timestamp).toMillis === "function"
    ? (v as admin.firestore.Timestamp).toMillis()
    : 0;
}

/** Best-effort in-app warning to each household member. */
async function warnMembers(
  db: admin.firestore.Firestore,
  memberUserIds: string[],
  now: Date
): Promise<void> {
  await Promise.all(
    memberUserIds.map(async (uid) => {
      try {
        await db.collection("user_notifications").add({
          userId: uid,
          senderId: uid, // system / self-notification
          type: "family_data_retention",
          title: "Era familjebetyg raderas snart",
          body:
            "Hushållet har varit inaktivt länge. Om ingen använder " +
            "familjebetygen snart raderas de automatiskt.",
          createdAt: admin.firestore.Timestamp.fromDate(now),
        });
      } catch (err) {
        logger.warn(`family-retention: warn notification failed for ${uid}`, {
          err,
        });
      }
    })
  );
}

/** Warn / purge / reactivate one household. Mutates `result`. */
async function processHousehold(
  db: admin.firestore.Firestore,
  hh: admin.firestore.QueryDocumentSnapshot,
  now: Date,
  dormancyCutoffMs: number,
  result: PurgeRunResult
): Promise<void> {
  result.scanned++;
  const data = hh.data();
  const hid = hh.id;
  const memberUserIds = Array.isArray(data.memberUserIds)
    ? (data.memberUserIds as unknown[]).filter(
        (id): id is string => typeof id === "string"
      )
    : [];

  const [diners, ratings] = await Promise.all([
    db.collection("diner_profiles").where("householdId", "==", hid).get(),
    db.collection("family_ratings").where("householdId", "==", hid).get(),
  ]);

  // BUT-1600: prune ratings whose rater left the roster (and refresh the
  // affected recipe cards) before any dormancy judgement — an orphan's activity
  // must not keep a household alive, and the purge pass acts on the pruned set.
  const liveRatings = await reconcileDepartedMemberRatings(
    db,
    memberUserIds,
    diners,
    ratings,
    result
  );

  // Nothing to purge → don't carry a stale schedule.
  if (diners.empty && liveRatings.length === 0) {
    if (data.familyDataPurgeScheduledAt) {
      await hh.ref.update({
        familyDataPurgeScheduledAt: admin.firestore.FieldValue.delete(),
      });
    }
    return;
  }

  let lastActivityMs = millisOf(data.updatedAt);
  diners.forEach((d) => {
    lastActivityMs = Math.max(lastActivityMs, millisOf(d.data().updatedAt));
  });
  liveRatings.forEach((r) => {
    lastActivityMs = Math.max(lastActivityMs, millisOf(r.data().lastUpdatedAt));
  });

  // Active within the window → clear any pending purge.
  if (lastActivityMs >= dormancyCutoffMs) {
    if (data.familyDataPurgeScheduledAt) {
      await hh.ref.update({
        familyDataPurgeScheduledAt: admin.firestore.FieldValue.delete(),
      });
      result.reactivated++;
    }
    return;
  }

  // Dormant. First time → warn + schedule; never purge on the same pass.
  const scheduledAt = data.familyDataPurgeScheduledAt as
    | admin.firestore.Timestamp
    | undefined;
  if (!scheduledAt) {
    await warnMembers(db, memberUserIds, now);
    await hh.ref.update({
      familyDataPurgeScheduledAt: admin.firestore.Timestamp.fromDate(
        new Date(now.getTime() + GRACE_DAYS * DAY_MS)
      ),
    });
    result.warned++;
    return;
  }

  // Still inside the grace window → wait.
  if (now.getTime() < scheduledAt.toMillis()) return;

  // Grace elapsed and still dormant → purge the family data. strict:true so a
  // failed chunk throws (run recorded failed), never a silent partial
  // purge of children's data.
  const childDocs = [...diners.docs, ...liveRatings];
  await commitInChunks(db, childDocs, (batch, doc) => batch.delete(doc.ref), {
    label: "purgeDormantFamilyData",
    strict: true,
  });
  await hh.ref.update({
    familyDataPurgeScheduledAt: admin.firestore.FieldValue.delete(),
    familyDataPurgedAt: admin.firestore.Timestamp.fromDate(now),
  });
  result.purged++;
  logger.info(
    `family-retention: purged ${childDocs.length} family docs for household ${hid}`
  );
}

/**
 * Core sweep — `db` and `now` injected for emulator tests, and the wall-clock
 * budget with its clock so the deferral branch is reachable from a test.
 *
 * Resumes after the stored cursor and saves it after every page, so a run cut
 * off by the platform repeats at most one page. A household that throws is
 * logged and passed over, so it cannot hold the cursor and stop every
 * household behind it; the failure is counted and the scheduled wrapper
 * records the run as failed.
 */
export async function runDormantFamilyPurge(
  db: admin.firestore.Firestore,
  now: Date,
  deadlineMs: number = SWEEP_DEADLINE_MS,
  clock: () => number = Date.now
): Promise<PurgeRunResult> {
  const result: PurgeRunResult = {
    scanned: 0,
    warned: 0,
    purged: 0,
    reactivated: 0,
    orphansReconciled: 0,
    failed: 0,
    passComplete: false,
    passAgeDays: 0,
    overdue: false,
  };
  const dormancyCutoffMs = now.getTime() - DORMANCY_DAYS * DAY_MS;
  const startedAt = clock();

  const cursorRef = db.doc(PURGE_CURSOR_DOC);
  const stored = (await cursorRef.get()).data();
  let lastHouseholdId =
    typeof stored?.lastHouseholdId === "string" ? stored.lastHouseholdId : null;
  const passStartedAt =
    lastHouseholdId != null && stored?.passStartedAt instanceof admin.firestore.Timestamp
      ? stored.passStartedAt
      : admin.firestore.Timestamp.fromDate(now);

  const saveCursor = (): Promise<unknown> =>
    cursorRef.set({
      lastHouseholdId,
      passStartedAt,
      updatedAt: admin.firestore.Timestamp.fromDate(now),
    });

  let deferred = false;
  for (;;) {
    let q = db
      .collection("households")
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(HOUSEHOLDS_PER_RUN);
    // A plain id string, so a cursor household deleted since needs no document.
    if (lastHouseholdId != null) q = q.startAfter(lastHouseholdId);
    const page = await q.get();
    if (page.empty) {
      result.passComplete = true;
      break;
    }
    for (const hh of page.docs) {
      if (result.scanned > 0 && clock() - startedAt >= deadlineMs) {
        deferred = true;
        break;
      }
      try {
        await processHousehold(db, hh, now, dormancyCutoffMs, result);
      } catch (err) {
        result.failed++;
        logger.error("family-retention.household_failed", {
          event: "family-retention.household_failed",
          householdId: hh.id,
          errName: err instanceof Error ? err.name : typeof err,
          errCode: (err as { code?: number | string })?.code,
        });
      }
      lastHouseholdId = hh.id;
    }
    if (deferred) break;
    if (page.size < HOUSEHOLDS_PER_RUN) {
      result.passComplete = true;
      break;
    }
    await saveCursor();
  }

  if (result.passComplete) {
    await cursorRef.delete();
  } else {
    await saveCursor();
  }

  result.passAgeDays = Math.floor(
    (now.getTime() - passStartedAt.toMillis()) / DAY_MS
  );
  result.overdue = result.passAgeDays > MAX_PASS_AGE_DAYS;
  const event = result.passComplete
    ? "family-retention.sweep_complete"
    : "family-retention.sweep_deferred";
  logger.info(event, { event, ...result });
  if (result.overdue) {
    logger.error("family-retention.pass_overdue", {
      event: "family-retention.pass_overdue",
      passAgeDays: result.passAgeDays,
      maxPassAgeDays: MAX_PASS_AGE_DAYS,
    });
  }
  return result;
}

/** Why the run must be recorded as failed, or null when it need not be. */
export function purgeRunFailure(result: PurgeRunResult): string | null {
  if (result.failed === 0 && !result.overdue) return null;
  return (
    `purgeDormantFamilyData: ${result.failed} household(s) failed` +
    (result.overdue ? `, pass is ${result.passAgeDays} days old` : "")
  );
}

/** Weekly scheduled sweep (region pinned via setGlobalOptions in index.ts). */
export const purgeDormantFamilyData = onSchedule(
  { schedule: "30 3 * * 0", timeZone: "UTC", timeoutSeconds: 300 },
  async () => {
    const result = await runDormantFamilyPurge(admin.firestore(), new Date());
    const failure = purgeRunFailure(result);
    if (failure) throw new Error(failure);
  }
);
