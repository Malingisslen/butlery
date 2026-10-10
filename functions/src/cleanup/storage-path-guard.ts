/**
 * Which Storage files a recipe cleanup may delete, and the delete itself.
 */

import { logger } from "firebase-functions/logger";

/** The part of the Admin SDK bucket this module calls. */
export interface PhotoBucket {
  file(path: string): { delete(): Promise<unknown> };
}

export interface PhotoDeleteResult {
  deleted: number;
  /** URLs the guard refused, or deletes that failed with something other than 404. */
  failed: number;
}

/**
 * The object path inside a Firebase Storage download URL or a `gs://` URL,
 * percent-decoded. Null when the URL is neither, or does not decode.
 */
export function extractStoragePath(url: string): string | null {
  if (typeof url !== "string" || url.length === 0) return null;
  try {
    const match = url.match(/\/o\/(.+?)(\?|$)/);
    if (match && match[1]) {
      return decodeURIComponent(match[1]);
    }
    if (url.startsWith("gs://")) {
      return url.replace(/^gs:\/\/[^/]+\//, "");
    }
    return null;
  } catch {
    return null;
  }
}

/**
 * The decoded object path of [url] when it is one of [uid]'s recipe photos,
 * else null. Checked AFTER decoding, so `%2e%2e%2f` cannot slip past as text.
 */
export function recipePhotoPath(url: string, uid: string): string | null {
  return userFilePath(url, uid, "recipes");
}

/**
 * The decoded object path of [url] when it is a file directly or deeper under
 * `users/{uid}/{folder}/`, else null. The checks run after decoding.
 */
export function userFilePath(
  url: string,
  uid: string,
  folder: string,
): string | null {
  if (typeof uid !== "string" || uid.length === 0 || uid.includes("/")) {
    return null;
  }
  const filePath = extractStoragePath(url);
  if (filePath === null) return null;
  if (
    filePath.includes("..") ||
    filePath.includes("//") ||
    filePath.includes("\\") ||
    // A `%` left after one decode is a double-encoded path; no app writer
    // produces one.
    filePath.includes("%") ||
    // eslint-disable-next-line no-control-regex
    /[\x00-\x1f\x7f]/.test(filePath)
  ) {
    return null;
  }
  const prefix = `users/${uid}/${folder}/`;
  if (!filePath.startsWith(prefix) || filePath.length === prefix.length) {
    return null;
  }
  if (filePath.endsWith("/")) return null;
  return filePath;
}

/**
 * The thumbnail paths a recipe photo at [photoPath] may have. The app's writer
 * (`createAndUploadThumbnail` in firebase_storage_repository.dart) moves the
 * file under `recipes/thumbnails/` and replaces `.jpg` with `_thumb.jpg`, so a
 * `.png`, `.jpeg`, `.gif` or `.webp` photo keeps its own file name there. Both
 * that name and `<name>_thumb<ext>` are returned, so the result does not depend
 * on the extension. A path already under `thumbnails/` has none.
 */
export function recipeThumbnailPaths(photoPath: string): string[] {
  const marker = "/recipes/";
  const at = photoPath.indexOf(marker);
  if (at < 0) return [];
  const head = photoPath.slice(0, at + marker.length);
  const rest = photoPath.slice(at + marker.length);
  if (rest.startsWith("thumbnails/") || rest.length === 0) return [];

  const candidates = new Set<string>();
  candidates.add(`${head}thumbnails/${rest.split(".jpg").join("_thumb.jpg")}`);
  const slash = rest.lastIndexOf("/");
  const dot = rest.lastIndexOf(".");
  if (dot > slash + 1) {
    candidates.add(
      `${head}thumbnails/${rest.slice(0, dot)}_thumb${rest.slice(dot)}`,
    );
  }
  return [...candidates];
}

/**
 * The photo URLs a recipe map carries: `core.imageUrls`,
 * `core.thumbnailUrl` and the heirloom scan `core.heirloom.sourceImageUrl`
 * (BUT-2286), or the same keys at the top of a legacy flat recipe.
 */
export function recipePhotoUrls(recipe: unknown): string[] {
  if (recipe === null || typeof recipe !== "object") return [];
  const map = recipe as Record<string, unknown>;
  const core =
    map.core !== null && typeof map.core === "object"
      ? (map.core as Record<string, unknown>)
      : map;
  const urls: string[] = [];
  if (Array.isArray(core.imageUrls)) {
    for (const u of core.imageUrls) if (typeof u === "string") urls.push(u);
  }
  if (typeof core.thumbnailUrl === "string") urls.push(core.thumbnailUrl);
  const heirloom = core.heirloom;
  if (heirloom !== null && typeof heirloom === "object") {
    const scan = (heirloom as Record<string, unknown>).sourceImageUrl;
    if (typeof scan === "string") urls.push(scan);
  }
  return urls;
}

function isNotFound(e: unknown): boolean {
  const code = (e as { code?: unknown } | null)?.code;
  return code === 404 || code === "404";
}

/**
 * Deletes each of [urls] that passes the guard for [uid], with its thumbnails.
 * A 404 counts as done: the file is already gone, which is the goal.
 */
export async function deleteRecipePhotos(
  bucket: PhotoBucket,
  uid: string,
  urls: string[],
  context: string,
): Promise<PhotoDeleteResult> {
  const result: PhotoDeleteResult = { deleted: 0, failed: 0 };
  const seen = new Set<string>();
  for (const url of urls) {
    const filePath = recipePhotoPath(url, uid);
    if (filePath === null) {
      logger.warn(`[${context}] refused a photo path outside users/{uid}/recipes/`, {
        uid_prefix: uid.slice(0, 6),
      });
      result.failed++;
      continue;
    }
    for (const target of [filePath, ...recipeThumbnailPaths(filePath)]) {
      if (seen.has(target)) continue;
      seen.add(target);
      try {
        await bucket.file(target).delete();
        if (target === filePath) result.deleted++;
      } catch (e) {
        if (isNotFound(e)) continue;
        const err = e as { code?: unknown; name?: unknown } | null;
        logger.error(`[${context}] failed to delete a recipe photo`, {
          uid_prefix: uid.slice(0, 6),
          file: target.slice(`users/${uid}/`.length),
          errCode: err?.code,
          errName: err?.name,
        });
        if (target === filePath) result.failed++;
      }
    }
  }
  return result;
}

/**
 * Deletes each of [urls] that is one of [uid]'s comment images under
 * `users/{uid}/comment_images/`. Comment images have no thumbnails. A 404
 * counts as done.
 */
export async function deleteCommentImages(
  bucket: PhotoBucket,
  uid: string,
  urls: string[],
  context: string,
): Promise<PhotoDeleteResult> {
  const result: PhotoDeleteResult = { deleted: 0, failed: 0 };
  const seen = new Set<string>();
  for (const url of urls) {
    const filePath = userFilePath(url, uid, "comment_images");
    if (filePath === null) {
      logger.warn(
        `[${context}] refused an image path outside users/{uid}/comment_images/`,
        { uid_prefix: uid.slice(0, 6) },
      );
      result.failed++;
      continue;
    }
    if (seen.has(filePath)) continue;
    seen.add(filePath);
    try {
      await bucket.file(filePath).delete();
      result.deleted++;
    } catch (e) {
      if (isNotFound(e)) continue;
      const err = e as { code?: unknown; name?: unknown } | null;
      logger.error(`[${context}] failed to delete a comment image`, {
        uid_prefix: uid.slice(0, 6),
        file: filePath.slice(`users/${uid}/`.length),
        errCode: err?.code,
        errName: err?.name,
      });
      result.failed++;
    }
  }
  return result;
}
