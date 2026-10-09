/**
 * Other people's content a deleted recipe leaves behind (comments, ratings,
 * cook snaps and the owner's shares), removed when the recipe document goes
 * (BUT-907 F6: none of it goes to the owner's trash). The stats aggregate is
 * deleted too; the rating recompute that each deleted rating schedules may
 * write it back with zero ratings.
 *
 * Server-side (BUT-2327) because the rules let only each row's author delete
 * it and `recipe_social_stats` only the Admin SDK, so the app's own cleanup
 * could not remove anyone else's row.
 *
 * Recipe ids are client-chosen, so anyone can create and delete a recipe under
 * their own uid with someone else's recipe id. The cleanup therefore runs only
 * when no live recipe anywhere still holds the id (in `core.id`, or `id` on
 * the older flat shape), and leaves a row whose `recipeOwnerId` or
 * `sharedByUserId` names another account.
 *
 * A row with an open report stays: the recipe owner is not its author, and the
 * row may be all that points at what a moderator needs to see.
 *
 * Skipped while the owner's account erasure runs: the cascade deletes their
 * recipes first and then scrubs `recipeOwnerId` on these same comments and
 * ratings with strict updates, which a delete from here would turn into
 * NOT_FOUND and an incomplete erasure.
 */

import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { Collections } from "../shared/collections";
import { erasureUnderway } from "../social/hold-shares-on-block";
import { isClosedReportStatus, REPORTS } from "../moderation/report-status";

export const REFERENCE_PAGE_SIZE = 450;

/** A bound on hostile input: rows anyone can write against any recipe id. */
export const MAX_REFERENCE_PAGES = 10;

/** Firestore's limit on the values of one `in` filter. */
const IN_CHUNK = 30;

/**
 * `ownerField`: a row naming another account there is not this deletion's to
 * remove. Absent on rows written before the field existed, which are removed.
 */
export const REFERENCE_QUERIES = [
  { collection: "recipe_comments", field: "recipeId", ownerField: "recipeOwnerId" },
  { collection: "recipe_ratings", field: "recipeId", ownerField: "recipeOwnerId" },
  { collection: "cook_snaps", field: "recipeId", ownerField: null },
  { collection: "shared_content", field: "originalRecipeId", ownerField: "sharedByUserId" },
] as const;

interface ReferencePage {
  docs: { id: string; ref: unknown; get(field: string): unknown }[];
}

/** The Firestore calls the cleanup makes, so tests can fake them. */
export interface ReferenceCleanupDb {
  collection(path: string): {
    where(
      field: string,
      op: "==" | "in",
      value: unknown,
    ): {
      limit(n: number): { get(): Promise<ReferencePage> };
      get(): Promise<ReferencePage>;
    };
  };
  collectionGroup(id: string): {
    where(
      field: string,
      op: "==",
      value: unknown,
    ): {
      limit(n: number): { get(): Promise<{ empty: boolean }> };
    };
  };
  doc(path: string): {
    get(): Promise<unknown>;
    delete(): Promise<unknown>;
  };
  recursiveDelete(ref: unknown): Promise<void>;
}

export interface ReferenceCleanupResult {
  skippedForErasure: boolean;
  /** Another live recipe holds the id, or the check could not be made. */
  skippedForLiveRecipe: boolean;
  /** Rows left because they name another account or have an open report. */
  kept: number;
  /** Rows deleted per collection, the stats document not included. */
  deleted: Record<string, number>;
  /** Collections that threw or hit `MAX_REFERENCE_PAGES`. */
  incomplete: string[];
}

export async function cleanupRecipeReferences(
  db: ReferenceCleanupDb,
  ownerId: string,
  recipeId: string,
  nowMs: number,
): Promise<ReferenceCleanupResult> {
  const result: ReferenceCleanupResult = {
    skippedForErasure: false,
    skippedForLiveRecipe: false,
    kept: 0,
    deleted: {},
    incomplete: [],
  };

  const marker = (await db
    .doc(`${Collections.erasuresInProgress}/${ownerId}`)
    .get()) as admin.firestore.DocumentSnapshot;
  if (erasureUnderway(marker, nowMs)) {
    logger.info("[recipeReferenceCleanup] owner erasure underway; skipped", {
      recipeId,
    });
    result.skippedForErasure = true;
    return result;
  }

  // Fails closed: a probe that cannot answer deletes nothing.
  try {
    const recipes = db.collectionGroup("recipes");
    const probes = await Promise.all([
      recipes.where("core.id", "==", recipeId).limit(1).get(),
      recipes.where("id", "==", recipeId).limit(1).get(),
    ]);
    if (probes.some((live) => !live.empty)) {
      logger.warn("[recipeReferenceCleanup] recipe id still live; skipped", {
        recipeId,
      });
      result.skippedForLiveRecipe = true;
      return result;
    }
  } catch (err) {
    logger.error("[recipeReferenceCleanup] live-recipe probe failed; skipped", {
      recipeId,
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
    result.skippedForLiveRecipe = true;
    result.incomplete.push("recipes");
    return result;
  }

  for (const { collection, field, ownerField } of REFERENCE_QUERIES) {
    let deleted = 0;
    try {
      const query = db
        .collection(collection)
        .where(field, "==", recipeId)
        .limit(REFERENCE_PAGE_SIZE);
      let pages = 0;
      for (;;) {
        if (pages === MAX_REFERENCE_PAGES) {
          logger.error("[recipeReferenceCleanup] page cap reached", {
            recipeId,
            collection,
            deleted,
          });
          result.incomplete.push(collection);
          break;
        }
        const snap = await query.get();
        pages++;
        if (snap.docs.length === 0) break;
        const reported = await openlyReported(
          db,
          snap.docs.map((doc) => doc.id),
        );
        const ours = snap.docs.filter((doc) => {
          if (reported.has(doc.id)) return false;
          if (ownerField === null) return true;
          const owner = doc.get(ownerField);
          return owner === undefined || owner === null || owner === ownerId;
        });
        // `recursiveDelete` also removes a comment's likes and a share's
        // members and items.
        await Promise.all(ours.map((doc) => db.recursiveDelete(doc.ref)));
        deleted += ours.length;
        const kept = snap.docs.length - ours.length;
        result.kept += kept;
        // Kept rows would come back on the next page, so the paging stops.
        if (kept > 0) {
          logger.warn("[recipeReferenceCleanup] rows kept", {
            recipeId,
            collection,
            kept,
            reported: reported.size,
          });
          if (snap.docs.length === REFERENCE_PAGE_SIZE) {
            result.incomplete.push(collection);
          }
          break;
        }
        if (snap.docs.length < REFERENCE_PAGE_SIZE) break;
      }
    } catch (err) {
      logger.error("[recipeReferenceCleanup] collection cleanup failed", {
        recipeId,
        collection,
        deleted,
        errCode: (err as { code?: number | string }).code ?? null,
        errName: err instanceof Error ? err.name : typeof err,
      });
      result.incomplete.push(collection);
    }
    result.deleted[collection] = deleted;
  }

  try {
    await db.doc(`recipe_social_stats/${recipeId}`).delete();
  } catch (err) {
    logger.error("[recipeReferenceCleanup] stats delete failed", {
      recipeId,
      errCode: (err as { code?: number | string }).code ?? null,
    });
    result.incomplete.push("recipe_social_stats");
  }

  logger.info("[recipeReferenceCleanup] done", { recipeId, ...result });
  return result;
}

/**
 * Which of these ids an open report names. Matched on `contentId` alone,
 * whatever its `contentType`, so a collision keeps a row rather than losing one.
 */
async function openlyReported(
  db: ReferenceCleanupDb,
  ids: string[],
): Promise<Set<string>> {
  const open = new Set<string>();
  for (let i = 0; i < ids.length; i += IN_CHUNK) {
    const snap = await db
      .collection(REPORTS)
      .where("contentId", "in", ids.slice(i, i + IN_CHUNK))
      .get();
    for (const report of snap.docs) {
      if (!isClosedReportStatus(report.get("status"))) {
        open.add(report.get("contentId") as string);
      }
    }
  }
  return open;
}
