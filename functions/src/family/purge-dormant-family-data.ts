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

const DAY_MS = 24 * 60 * 60 * 1000;
const DORMANCY_DAYS = 730; // 24 months (DPO-confirmed)
const GRACE_DAYS = 30; // warn-before-purge window
const HOUSEHOLDS_PER_RUN = 200; // bounded; paginates at scale

export interface PurgeRunResult {
  scanned: number;
  warned: number;
  purged: number;
  reactivated: number;
  /** BUT-1600: family_ratings deleted because their rater left the household. */
  orphansReconciled: number;
}

/** String memberIds still present in the household roster (accounts + diners). */
function rosterMemberIds(
  memberUserIds: string[],
  diners: admin.firestore.QuerySnapshot
): Set<string> {
  return new Set<string>([...memberUserIds, ...diners.docs.map((d) => d.id)]);
}

/** Firestore's getAll rejects an empty arg list; page it so an unbounded
 * candidate set (a heavy rater leaving) never builds one oversized read. */
async function getAllChunked(
  db: admin.firestore.Firestore,
  refs: admin.firestore.DocumentReference[]
): Promise<admin.firestore.DocumentSnapshot[]> {
  const CHUNK = 300;
  const out: admin.firestore.DocumentSnapshot[] = [];
  for (let i = 0; i < refs.length; i += CHUNK) {
    out.push(...(await db.getAll(...refs.slice(i, i + CHUNK))));
  }
  return out;
}

/** A recipe copy already carries a denormalised family pill worth refreshing. */
function hasDenormFamilyValue(data: admin.firestore.DocumentData | undefined): boolean {
  const core = data?.core as Record<string, unknown> | undefined;
  return core != null &&
    (core.familyRatingCount != null || core.familyAverage != null);
}

/**
 * BUT-1600: recompute the denormalised recipe-card family average on every
 * household member's own recipe copy for each recipe an orphan rating touched.
 * Uses the SURVIVING ratings (simple unweighted mean, matching the client's
 * `FamilyRatingSummary.fromRatings`); clears the pill (null) when no rating
 * remains. Only patches copies that already hold a family value — never adds the
 * fields to a copy that never had a family pill. Best-effort: a failure here
 * leaves the pill to self-heal on the next in-app rating.
 */
async function recomputeDenormalisedAverages(
  db: admin.firestore.Firestore,
  orphans: admin.firestore.QueryDocumentSnapshot[],
  survivors: admin.firestore.QueryDocumentSnapshot[],
  memberUserIds: string[]
): Promise<void> {
  const affectedRecipeIds = new Set<string>();
  for (const o of orphans) {
    const rid = o.data().recipeId;
    if (typeof rid === "string" && rid) affectedRecipeIds.add(rid);
  }
  if (affectedRecipeIds.size === 0 || memberUserIds.length === 0) return;

  const byRecipe = new Map<string, { sum: number; count: number }>();
  for (const s of survivors) {
    const d = s.data();
    const rid = d.recipeId;
    const stars = d.stars;
    if (typeof rid !== "string" || !affectedRecipeIds.has(rid)) continue;
    if (typeof stars !== "number" || stars < 1 || stars > 5) continue;
    const agg = byRecipe.get(rid) ?? { sum: 0, count: 0 };
    agg.sum += stars;
    agg.count += 1;
    byRecipe.set(rid, agg);
  }

  const refs: admin.firestore.DocumentReference[] = [];
  for (const uid of memberUserIds) {
    for (const rid of affectedRecipeIds) {
      refs.push(
        db.collection("users").doc(uid).collection("recipes").doc(rid)
      );
    }
  }
  const snaps = await getAllChunked(db, refs);
  const patchable = snaps.filter(
    (s) => s.exists && hasDenormFamilyValue(s.data())
  );
  if (patchable.length === 0) return;

  await commitInChunks(
    db,
    patchable,
    (batch, snap) => {
      const agg = byRecipe.get(snap.ref.id);
      const hasRatings = agg != null && agg.count > 0;
      batch.update(snap.ref, {
        "core.familyAverage": hasRatings ? agg!.sum / agg!.count : null,
        "core.familyRatingCount": hasRatings ? agg!.count : null,
      });
    },
    { label: "recomputeFamilyCardAverage", strict: false }
  );
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
  const orphans = ratings.docs.filter((r) => {
    const mid = r.data().memberId;
    return typeof mid === "string" && !roster.has(mid);
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
  // failed chunk throws (run recorded failed + retried), never a silent partial
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
    orphansReconciled: 0,
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
