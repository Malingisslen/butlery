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
 *      the run is recorded as failed and retried, never a silent partial purge).
 * Reactivation at any point clears the scheduled purge.
 *
 * Dormancy signal: the newest of the household's `updatedAt`, its diner
 * profiles' `updatedAt`, and its family ratings' `lastUpdatedAt`.
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { commitInChunks } from "../shared/batch-update";

const DAY_MS = 24 * 60 * 60 * 1000;
const DORMANCY_DAYS = 730; // 24 months (DPO-confirmed)
const GRACE_DAYS = 30; // warn-before-purge window
const HOUSEHOLDS_PER_RUN = 200; // bounded; paginates at scale

export interface PurgeRunResult {
  scanned: number;
  warned: number;
  purged: number;
  reactivated: number;
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

  const [diners, ratings] = await Promise.all([
    db.collection("diner_profiles").where("householdId", "==", hid).get(),
    db.collection("family_ratings").where("householdId", "==", hid).get(),
  ]);

  // Nothing to purge → don't carry a stale schedule.
  if (diners.empty && ratings.empty) {
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
  ratings.forEach((r) => {
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
    const memberUserIds = Array.isArray(data.memberUserIds)
      ? (data.memberUserIds as unknown[]).filter(
          (id): id is string => typeof id === "string"
        )
      : [];
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
  // failed chunk throws (run recorded failed + retried), never a silent partial
  // purge of children's data.
  const childDocs = [...diners.docs, ...ratings.docs];
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
 * Core sweep — `db` and `now` injected for emulator tests.
 */
export async function runDormantFamilyPurge(
  db: admin.firestore.Firestore,
  now: Date
): Promise<PurgeRunResult> {
  const result: PurgeRunResult = {
    scanned: 0,
    warned: 0,
    purged: 0,
    reactivated: 0,
  };
  const dormancyCutoffMs = now.getTime() - DORMANCY_DAYS * DAY_MS;

  // Paginate through ALL households (stateless within the run) so none is ever
  // silently skipped — this sweep is a legal retention guarantee, not a sample.
  let cursor: admin.firestore.QueryDocumentSnapshot | undefined;
  for (;;) {
    let q = db
      .collection("households")
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(HOUSEHOLDS_PER_RUN);
    if (cursor) q = q.startAfter(cursor);
    const page = await q.get();
    if (page.empty) break;
    for (const hh of page.docs) {
      await processHousehold(db, hh, now, dormancyCutoffMs, result);
    }
    cursor = page.docs[page.docs.length - 1];
    if (page.size < HOUSEHOLDS_PER_RUN) break;
  }

  logger.info("family-retention.sweep_complete", {
    event: "family-retention.sweep_complete",
    ...result,
  });
  return result;
}

/** Weekly scheduled sweep (region pinned via setGlobalOptions in index.ts). */
export const purgeDormantFamilyData = onSchedule(
  { schedule: "30 3 * * 0", timeZone: "UTC", timeoutSeconds: 300 },
  async () => {
    await runDormantFamilyPurge(admin.firestore(), new Date());
  }
);
