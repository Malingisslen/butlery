/**
 * Recipe Storage Cleanup Cloud Function
 *
 * Triggered when a recipe document is deleted from a user's recipe collection.
 * Deletes associated Storage images (full-size and thumbnails) to prevent
 * orphaned files from accumulating storage costs.
 *
 * Trigger path: users/{userId}/recipes/{recipeId}
 * Event: onDelete
 *
 * Storage paths cleaned:
 * - users/{userId}/recipes/{filename}
 * - users/{userId}/recipes/thumbnails/{filename}_thumb
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

/**
 * Trigger: When a recipe document is deleted
 *
 * Extracts imageUrls from the deleted document and deletes the
 * corresponding Storage files. Handles both full-size images and thumbnails.
 */
export const onRecipeDeleted = functions
  .region("europe-west1")
  .firestore.document("users/{userId}/recipes/{recipeId}")
  .onDelete(async (snapshot, context) => {
    const { userId, recipeId } = context.params;
    const data = snapshot.data();

    if (!data) {
      functions.logger.warn(`Recipe ${recipeId} had no data on delete`);
      return;
    }

    const imageUrls: string[] = data.imageUrls || [];

    if (imageUrls.length === 0) {
      functions.logger.info(
        `Recipe ${recipeId} (user: ${userId}) had no images to clean up`
      );
      return;
    }

    functions.logger.info(
      `Cleaning up ${imageUrls.length} images for deleted recipe ${recipeId} (user: ${userId})`
    );

    const bucket = admin.storage().bucket();
    let deletedCount = 0;
    let failedCount = 0;

    for (const imageUrl of imageUrls) {
      const filePath = extractStoragePath(imageUrl);
      if (!filePath) {
        functions.logger.warn(`Could not extract path from URL: ${imageUrl}`);
        failedCount++;
        continue;
      }

      // Path traversal protection: reject paths containing ../ sequences
      // that could escape the user's directory after URL decoding
      if (filePath.includes("..") || filePath.includes("//")) {
        functions.logger.warn(
          `Path traversal attempt blocked: ${filePath}`
        );
        failedCount++;
        continue;
      }

      // Validate the file belongs to this user
      if (!filePath.startsWith(`users/${userId}/`)) {
        functions.logger.warn(
          `Skipping file not owned by user ${userId}: ${filePath}`
        );
        failedCount++;
        continue;
      }

      // Delete the full-size image
      try {
        await bucket.file(filePath).delete();
        deletedCount++;
      } catch (e: any) {
        if (e.code === 404) {
          functions.logger.info(`File already deleted: ${filePath}`);
        } else {
          functions.logger.error(`Failed to delete file ${filePath}:`, e);
          failedCount++;
        }
      }

      // Try to delete the thumbnail
      const thumbPath = filePath
        .replace("/recipes/", "/recipes/thumbnails/")
        .replace(".jpg", "_thumb.jpg");

      try {
        await bucket.file(thumbPath).delete();
      } catch (e: any) {
        // Thumbnails may not exist — silently ignore 404
        if (e.code !== 404) {
          functions.logger.warn(`Failed to delete thumbnail ${thumbPath}:`, e);
        }
      }
    }

    functions.logger.info(
      `Storage cleanup for recipe ${recipeId}: ${deletedCount} deleted, ${failedCount} failed out of ${imageUrls.length} images`
    );
  });

/**
 * Extracts the Storage file path from a Firebase Storage download URL.
 *
 * Handles URLs like:
 * https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{encoded_path}?alt=media&token=...
 */
function extractStoragePath(url: string): string | null {
  try {
    // Handle Firebase Storage download URLs
    const match = url.match(/\/o\/(.+?)(\?|$)/);
    if (match && match[1]) {
      return decodeURIComponent(match[1]);
    }

    // Handle gs:// URLs
    if (url.startsWith("gs://")) {
      const parts = url.replace(/^gs:\/\/[^/]+\//, "");
      return parts;
    }

    return null;
  } catch (e) {
    functions.logger.error(`Failed to parse storage URL: ${url}`, e);
    return null;
  }
}
