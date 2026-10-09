/**
 * Trash Storage Cleanup Cloud Function (BUT-907)
 *
 * Triggered when a copy in `users/{userId}/trash/{itemId}` is deleted: by the
 * TTL policy after 30 days, by "Radera för gott" or "Töm", by a restore, by a
 * moderator, or by the account deletion cascade. The photos of a recipe in the
 * trash were left in place by `onRecipeDeleted`; this removes them, unless the
 * recipe came back.
 *
 * Trigger path: users/{userId}/trash/{itemId}
 * Event: onDelete
 */

import { onDocumentDeleted } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { CleanupDb } from "./cleanup-recipe-storage";
import {
  deleteRecipePhotos,
  PhotoBucket,
  recipePhotoUrls,
} from "./storage-path-guard";

export interface TrashCleanupDeps {
  db: CleanupDb;
  bucket: PhotoBucket;
}

export type TrashCleanupOutcome =
  | "restored"
  | "superseded"
  | "deleted"
  | "no-data";

/**
 * Deletes the photos in the deleted copy's payload only when
 *   - the recipe does not exist (it was not restored), and
 *   - no copy with the same id exists now.
 * The second check covers delete → restore → delete with the first trigger
 * arriving late: the recipe is gone again, but the new copy still needs the
 * photos, and its own delete trigger removes them later.
 */
export async function handleTrashItemDeleted(
  deps: TrashCleanupDeps,
  userId: string,
  itemId: string,
  data: Record<string, unknown> | undefined,
): Promise<TrashCleanupOutcome> {
  if (!data) {
    logger.warn("[onTrashItemDeleted] copy had no data on delete", { itemId });
    return "no-data";
  }
  const sourceId =
    typeof data.sourceId === "string" && data.sourceId.length > 0
      ? data.sourceId
      : itemId;

  const recipe = await deps.db.doc(`users/${userId}/recipes/${sourceId}`).get();
  if (recipe.exists) {
    logger.info("[onTrashItemDeleted] recipe restored; photos kept", { itemId });
    return "restored";
  }

  const current = await deps.db.doc(`users/${userId}/trash/${itemId}`).get();
  if (current.exists) {
    logger.info("[onTrashItemDeleted] a newer copy holds the photos", {
      itemId,
    });
    return "superseded";
  }

  const urls = recipePhotoUrls(data.payload);
  if (typeof data.thumbnailUrl === "string") urls.push(data.thumbnailUrl);
  const result = await deleteRecipePhotos(
    deps.bucket,
    userId,
    urls,
    "onTrashItemDeleted",
  );
  logger.info("[onTrashItemDeleted] photos deleted", { itemId, ...result });
  return "deleted";
}

export const onTrashItemDeleted = onDocumentDeleted(
  "users/{userId}/trash/{itemId}",
  async (event) => {
    const { userId, itemId } = event.params;
    await handleTrashItemDeleted(
      {
        db: admin.firestore() as unknown as CleanupDb,
        bucket: admin.storage().bucket(),
      },
      userId,
      itemId,
      event.data?.data(),
    );
  },
);
