/**
 * BUT-458: Backfill `recipeOwnerId` + `sharedWithUserIds` on existing
 * `recipe_comments` docs.
 *
 * **LIFECYCLE — REMOVE THIS FILE WHEN:**
 *   1. A successful invocation returns `hasMore: false` (no comments left
 *      missing the denorm fields), AND
 *   2. A 30-day soak window has passed without rule-error reports tied to
 *      missing denorm fields.
 *
 * After both conditions are satisfied, delete this file and remove the
 * `backfillRecipeCommentsDenorm` export from `functions/src/index.ts` plus
 * the `test:backfill-recipe-comments` script entry in `functions/package.json`.
 * One-shot migration code is liability after the soak; new comments
 * always write the denorm fields client-side via FirebaseCommentsRepository.
 *
 * Comments written before the BUT-458 denorm have neither field; their
 * security-rule path falls back to author-only read. This migration stamps
 * the fields so that:
 *   - Recipe owners can read all comments on their own recipe.
 *   - Shared/collaborative recipe members can read all comments on the
 *     recipe.
 *
 * **Lookup strategy** (no collectionGroup index required for this script —
 * we use the existing per-user `recipes` index):
 *   1. Read each `recipe_comments` doc lacking `recipeOwnerId`.
 *   2. Use a `collectionGroup('recipes')` query filtering on `__name__`
 *      to find the owning recipe doc. (`recipeId` is unique across users
 *      since it's a Firestore-generated id.)
 *   3. Stamp `recipeOwnerId` (the parent `users/{uid}` segment) and
 *      `sharedWithUserIds` (from `core.socialData.memberPermissions`
 *      excluding the owner).
 *   4. If no recipe doc is found (orphaned comment — recipe was deleted
 *      or lives in a top-level shape we don't know about), stamp
 *      `recipeOwnerId = authorId, sharedWithUserIds = []` so the row
 *      stays author-only-readable forever (graceful degradation).
 *
 * **Idempotent:** comments that already have both fields are skipped.
 *
 * **Region:** europe-west1 (Butlery convention).
 *
 * **Auth:** admin custom claim required (`request.auth.token.admin === true`
 * or `role === 'admin'`). Non-admin callers get `permission-denied`.
 */

import {
  onCall,
  HttpsError,
  CallableRequest,
} from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";

import { requireAdmin } from "../shared/require-admin";

const REGION = "europe-west1";
const BATCH_SIZE = 200;
const MAX_BATCHES_PER_INVOCATION = 50; // ~10k comments per call ceiling

const getDb = () => admin.firestore();

/**
 * Resolve the recipe-ownership snapshot for a given recipeId by
 * scanning the `recipes` collection group. Returns null if no recipe
 * doc with that id is found.
 */
export async function resolveRecipeOwnership(
  recipeId: string,
  db: admin.firestore.Firestore
): Promise<{ recipeOwnerId: string; sharedWithUserIds: string[] } | null> {
  // Try the user-subcollection path first via collectionGroup. Recipe
  // ids are server-generated UUIDs so we expect 0 or 1 hit.
  const cgQuery = await db
    .collectionGroup("recipes")
    .where(admin.firestore.FieldPath.documentId(), "==", recipeId)
    .limit(1)
    .get();

  if (cgQuery.empty) {
    return null;
  }

  // Pick the first match. If two users somehow hold the same recipeId
  // (shouldn't happen with UUID generation), the first wins — the
  // backfill stamps something rather than nothing, which is the
  // safe-degrade direction.
  const recipeDoc = cgQuery.docs[0];
  const recipeData = recipeDoc.data();

  // Parent path: users/{uid}/recipes/{recipeId} — uid is two segments up.
  const parentUserDoc = recipeDoc.ref.parent.parent;
  const ownerFromPath = parentUserDoc?.id ?? null;

  // Prefer socialData.ownerId for collaborative recipes; fall back to
  // path-derived uid (which is also `core.createdBy` for personal).
  const core = recipeData.core ?? recipeData;
  const socialData = core.socialData ?? null;
  const recipeOwnerId =
    (socialData?.ownerId as string | undefined) ||
    (core.createdBy as string | undefined) ||
    ownerFromPath ||
    null;

  if (!recipeOwnerId) {
    return null;
  }

  // Members from socialData (any permission level grants read).
  const memberPermissions =
    (socialData?.memberPermissions as Record<string, unknown> | undefined) ||
    {};
  const sharedWithUserIds = Object.keys(memberPermissions).filter(
    (uid) => uid && uid !== recipeOwnerId
  );

  return { recipeOwnerId, sharedWithUserIds };
}

interface BackfillRequest {
  /** Dry-run: scan + log without writing. Default false. */
  dryRun?: boolean;
  /** Hard ceiling on docs to process this invocation. */
  maxComments?: number;
}

interface BackfillResponse {
  success: boolean;
  migrated: number;
  skipped: number;
  failed: number;
  orphanedAuthorOnly: number;
  batchesProcessed: number;
  hasMore: boolean;
}

/**
 * Iterate `recipe_comments` paginated by document id, stamping denorm
 * fields. Exposed for unit testing alongside the callable wrapper.
 */
export async function runBackfill(
  db: admin.firestore.Firestore,
  options: { dryRun: boolean; maxComments: number }
): Promise<BackfillResponse> {
  const { dryRun, maxComments } = options;

  let migrated = 0;
  let skipped = 0;
  let failed = 0;
  let orphanedAuthorOnly = 0;
  let batchesProcessed = 0;
  let totalScanned = 0;
  let lastDocId: string | null = null;
  let hasMore = false;

  while (batchesProcessed < MAX_BATCHES_PER_INVOCATION) {
    let query = db
      .collection("recipe_comments")
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(BATCH_SIZE);

    if (lastDocId) {
      query = query.startAfter(lastDocId);
    }

    const snapshot = await query.get();
    if (snapshot.empty) {
      break;
    }

    const writeBatch = db.batch();
    let batchWrites = 0;

    for (const commentDoc of snapshot.docs) {
      totalScanned += 1;
      if (totalScanned > maxComments) {
        hasMore = true;
        break;
      }

      const data = commentDoc.data();

      // Idempotency: skip if already migrated (recipeOwnerId present).
      if (typeof data.recipeOwnerId === "string" && data.recipeOwnerId) {
        skipped += 1;
        continue;
      }

      const recipeId = data.recipeId as string | undefined;
      const authorId = data.authorId as string | undefined;
      if (!recipeId || !authorId) {
        // Malformed doc — log but don't crash the batch.
        failed += 1;
        logger.warn(
          `[backfill-recipe-comments] doc ${commentDoc.id} missing recipeId/authorId; skipping`
        );
        continue;
      }

      try {
        const ownership = await resolveRecipeOwnership(recipeId, db);

        let recipeOwnerId: string;
        let sharedWithUserIds: string[];

        if (ownership === null) {
          // Orphan: recipe gone or in a shape we don't index. Stamp
          // author-only so the row stays readable by the comment author
          // but invisible to others — graceful degradation.
          recipeOwnerId = authorId;
          sharedWithUserIds = [];
          orphanedAuthorOnly += 1;
        } else {
          recipeOwnerId = ownership.recipeOwnerId;
          sharedWithUserIds = ownership.sharedWithUserIds;
        }

        if (!dryRun) {
          writeBatch.update(commentDoc.ref, {
            recipeOwnerId,
            sharedWithUserIds,
          });
          batchWrites += 1;
        }
        migrated += 1;
      } catch (e) {
        failed += 1;
        logger.warn(
          `[backfill-recipe-comments] resolve failed for comment ${commentDoc.id} (recipe ${recipeId}): ${e}`
        );
      }
    }

    if (!dryRun && batchWrites > 0) {
      await writeBatch.commit();
    }

    batchesProcessed += 1;
    logger.info(
      JSON.stringify({
        migrated,
        skipped,
        failed,
        orphanedAuthorOnly,
        batchNumber: batchesProcessed,
      })
    );

    lastDocId = snapshot.docs[snapshot.docs.length - 1].id;

    // Stop if this batch was the last one or we hit the cap.
    if (snapshot.size < BATCH_SIZE) break;
    if (totalScanned >= maxComments) {
      hasMore = true;
      break;
    }
  }

  if (batchesProcessed >= MAX_BATCHES_PER_INVOCATION) {
    hasMore = true;
  }

  return {
    success: true,
    migrated,
    skipped,
    failed,
    orphanedAuthorOnly,
    batchesProcessed,
    hasMore,
  };
}

/**
 * Admin-only callable that triggers the backfill. Idempotent — safe to
 * re-run; already-migrated comments are skipped.
 */
export const backfillRecipeCommentsDenorm = onCall(
  { region: REGION },
  async (
    request: CallableRequest<BackfillRequest>
  ): Promise<BackfillResponse> => {
    requireAdmin(request);

    const { dryRun = false, maxComments = 10000 } = request.data ?? {};

    logger.info(
      `[backfill-recipe-comments] starting: dryRun=${dryRun}, maxComments=${maxComments}, admin=${request.auth?.uid}`
    );

    try {
      const result = await runBackfill(getDb(), { dryRun, maxComments });

      logger.info(
        `[backfill-recipe-comments] done: ${JSON.stringify(result)}`
      );

      return result;
    } catch (e) {
      logger.error(
        `[backfill-recipe-comments] fatal: ${e instanceof Error ? e.message : String(e)}`
      );
      throw new HttpsError(
        "internal",
        `Backfill failed: ${e instanceof Error ? e.message : String(e)}`
      );
    }
  }
);
