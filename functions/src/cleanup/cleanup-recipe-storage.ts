/**
 * Recipe Storage Cleanup Cloud Function
 *
 * Triggered when a recipe document is deleted from a user's recipe collection.
 * Deletes the recipe's Storage photos (full-size and thumbnails) so orphaned
 * files do not accumulate, except while the recipe sits in the trash
 * (BUT-907): the app moves a deleted recipe to `users/{uid}/trash/{recipeId}`
 * in the same batch that deletes it, and the photos stay for "Återställ".
 * `onTrashItemDeleted` removes them once that copy is gone.
 *
 * Trigger path: users/{userId}/recipes/{recipeId}
 * Event: onDelete
 */

import { onDocumentDeleted } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { OPEN_REPORT_STATUSES, REPORTS } from "../moderation/report-status";
import {
  deleteRecipePhotos,
  PhotoBucket,
  recipePhotoUrls,
} from "./storage-path-guard";

/**
 * How close the trash copy's `deletedAt` must be to the recipe's deletion for
 * the copy to keep the photos. `deletedAt` is the phone's clock, which the
 * trash rule lets sit up to an hour off the server's, so the window is that
 * hour plus slack; an old copy left from an earlier delete is outside it.
 */
export const FRESH_COPY_WINDOW_MS = 70 * 60 * 1000;

/** The Firestore calls the handler makes, so tests can fake them. */
export interface CleanupDb {
  doc(path: string): {
    get(): Promise<{ exists: boolean; get(field: string): unknown }>;
    delete(): Promise<unknown>;
  };
  collection(path: string): {
    where(field: string, op: string, value: unknown): CleanupQuery;
  };
}

export interface CleanupQuery {
  where(field: string, op: string, value: unknown): CleanupQuery;
  limit(n: number): CleanupQuery;
  get(): Promise<{ empty: boolean }>;
}

export interface CleanupDeps {
  db: CleanupDb;
  bucket: PhotoBucket;
}

/** Epoch millis of a Firestore Timestamp, a Date or a number; else null. */
export function millisOf(value: unknown): number | null {
  if (value === null || value === undefined) return null;
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (value instanceof Date) return value.getTime();
  const toMillis = (value as { toMillis?: unknown }).toMillis;
  if (typeof toMillis === "function") {
    const ms = (toMillis as () => unknown).call(value);
    return typeof ms === "number" && Number.isFinite(ms) ? ms : null;
  }
  return null;
}

/** Whether a report on this recipe is still open (anything but `closed`). */
export async function hasOpenRecipeReport(
  db: CleanupDb,
  recipeId: string,
): Promise<boolean> {
  const snap = await db
    .collection(REPORTS)
    .where("contentType", "==", "recipe")
    .where("contentId", "==", recipeId)
    .where("status", "in", [...OPEN_REPORT_STATUSES])
    .limit(1)
    .get();
  return !snap.empty;
}

export type RecipeCleanupOutcome =
  | "reported"
  | "kept-for-trash"
  | "restored"
  | "deleted"
  | "no-data";

/**
 * (a) An open report: the recipe does not go to the trash. Any copy is
 *     deleted and the photos with it, as before BUT-907.
 * (b) A trash copy whose `deletedAt` lies within FRESH_COPY_WINDOW_MS of the
 *     deletion: the photos stay.
 * (c) Otherwise (no copy, or an old one): the photos are deleted.
 * Before either delete the recipe is read again: a restore that won the race
 * (or a redelivery after one) means the photos belong to the live recipe. A
 * restore needs the copy (restoreRecipe's transaction), so the read comes
 * after the copy was deleted or seen missing.
 */
export async function handleRecipeDeleted(
  deps: CleanupDeps,
  userId: string,
  recipeId: string,
  data: Record<string, unknown> | undefined,
  deletedAtMs: number,
): Promise<RecipeCleanupOutcome> {
  if (!data) {
    logger.warn("[onRecipeDeleted] recipe had no data on delete", { recipeId });
    return "no-data";
  }
  const liveAgain = async (): Promise<boolean> => {
    const live = await deps.db.doc(`users/${userId}/recipes/${recipeId}`).get();
    if (live.exists) {
      logger.info("[onRecipeDeleted] recipe is live again; photos kept", {
        recipeId,
      });
    }
    return live.exists;
  };

  const trashRef = deps.db.doc(`users/${userId}/trash/${recipeId}`);
  const urls = recipePhotoUrls(data);

  if (await hasOpenRecipeReport(deps.db, recipeId)) {
    await trashRef.delete();
    if (await liveAgain()) return "restored";
    const result = await deleteRecipePhotos(
      deps.bucket,
      userId,
      urls,
      "onRecipeDeleted",
    );
    logger.info("[onRecipeDeleted] reported recipe: copy and photos deleted", {
      recipeId,
      ...result,
    });
    return "reported";
  }

  const copy = await trashRef.get();
  if (copy.exists) {
    const copyDeletedAt = millisOf(copy.get("deletedAt"));
    if (
      copyDeletedAt !== null &&
      Math.abs(deletedAtMs - copyDeletedAt) <= FRESH_COPY_WINDOW_MS
    ) {
      logger.info("[onRecipeDeleted] recipe is in the trash; photos kept", {
        recipeId,
      });
      return "kept-for-trash";
    }
  }

  if (await liveAgain()) return "restored";
  const result = await deleteRecipePhotos(
    deps.bucket,
    userId,
    urls,
    "onRecipeDeleted",
  );
  logger.info("[onRecipeDeleted] photos deleted", { recipeId, ...result });
  return "deleted";
}

export const onRecipeDeleted = onDocumentDeleted(
  "users/{userId}/recipes/{recipeId}",
  async (event) => {
    const { userId, recipeId } = event.params;
    const deletedAtMs = Date.parse(event.time);
    await handleRecipeDeleted(
      {
        db: admin.firestore() as unknown as CleanupDb,
        bucket: admin.storage().bucket(),
      },
      userId,
      recipeId,
      event.data?.data(),
      Number.isFinite(deletedAtMs) ? deletedAtMs : Date.now(),
    );
  },
);
