/**
 * Images of a deleted comment or cook snap (BUT-2337).
 *
 * A row can go by its author's hand, by `onRecipeDeleted` cleaning up a
 * deleted recipe (BUT-2327), by a moderator or by the account deletion
 * cascade. Before this, the app deleted a comment's images only on the
 * author's own delete, and nothing deleted a cook snap's photos, so they stayed
 * in Storage until the author's account was erased.
 *
 * The URLs come from a document a user wrote, so only files under the row
 * author's own folder are deleted: `users/{authorId}/comment_images/` for a
 * comment, the cook-snap photos under `users/{userId}/recipes/` (thumbnails
 * included) for a snap.
 *
 * A deleted cook snap also takes the snap owner's `cooked` feed event with it
 * (BUT-2346). The event copied the snap's photo URL into `extraData.photoUrl`
 * when it was written and stores no snap id, so that URL is the link. The
 * event's fields are client-written too, so only events whose `actorId` is the
 * snap's owner are matched.
 */

import { onDocumentDeleted } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import {
  deleteCommentImages,
  deleteRecipePhotos,
  PhotoBucket,
  PhotoDeleteResult,
} from "./storage-path-guard";

// The app writes at most `CookSnap.maxPhotos` (5) album photos plus
// `photoUrl` and `thumbnailUrl`; the rules do not bound `photoUrls`.
export const MAX_SNAP_URLS = 7;

// The cap bounds the read for events a user wrote themselves.
export const MAX_FEED_EVENTS_PER_SNAP = 10;

interface FeedEventDoc {
  ref: unknown;
  data(): Record<string, unknown> | undefined;
}

interface FeedEventQuery {
  where(field: string, op: "==" | "in", value: unknown): FeedEventQuery;
  limit(n: number): FeedEventQuery;
  get(): Promise<{ docs: FeedEventDoc[] }>;
}

export interface FeedEventDb {
  collection(name: string): FeedEventQuery;
  batch(): { delete(ref: unknown): unknown; commit(): Promise<unknown> };
}

function stringsIn(value: unknown): string[] {
  if (typeof value === "string") return [value];
  if (!Array.isArray(value)) return [];
  return value.filter((v): v is string => typeof v === "string");
}

function ownerOf(data: Record<string, unknown>, field: string): string | null {
  const uid = data[field];
  return typeof uid === "string" && uid.length > 0 ? uid : null;
}

export async function handleCommentDeleted(
  bucket: PhotoBucket,
  commentId: string,
  data: Record<string, unknown> | undefined,
): Promise<PhotoDeleteResult | null> {
  if (!data) return null;
  const urls = stringsIn(data.imageUrls);
  if (urls.length === 0) return null;
  const authorId = ownerOf(data, "authorId");
  if (authorId === null) {
    logger.warn("[onRecipeCommentDeleted] images but no author; kept", {
      commentId,
    });
    return null;
  }
  const result = await deleteCommentImages(
    bucket,
    authorId,
    urls,
    "onRecipeCommentDeleted",
  );
  logger.info("[onRecipeCommentDeleted] images deleted", {
    commentId,
    ...result,
  });
  return result;
}

export async function handleCookSnapDeleted(
  bucket: PhotoBucket,
  snapId: string,
  data: Record<string, unknown> | undefined,
): Promise<PhotoDeleteResult | null> {
  if (!data) return null;
  const urls = [
    ...stringsIn(data.photoUrls),
    ...stringsIn(data.photoUrl),
    ...stringsIn(data.thumbnailUrl),
  ];
  if (urls.length === 0) return null;
  const userId = ownerOf(data, "userId");
  if (userId === null) {
    logger.warn("[onCookSnapDeleted] photos but no owner; kept", { snapId });
    return null;
  }
  const unique = [...new Set(urls)];
  if (unique.length > MAX_SNAP_URLS) {
    logger.warn("[onCookSnapDeleted] url list over the cap; truncated", {
      snapId,
      count: unique.length,
    });
  }
  const result = await deleteRecipePhotos(
    bucket,
    userId,
    unique.slice(0, MAX_SNAP_URLS),
    "onCookSnapDeleted",
  );
  logger.info("[onCookSnapDeleted] photos deleted", { snapId, ...result });
  return result;
}

function snapUrls(data: Record<string, unknown>): string[] {
  const urls = [...stringsIn(data.photoUrls), ...stringsIn(data.photoUrl)]
    .filter((u) => u.length > 0);
  return [...new Set(urls)].slice(0, MAX_SNAP_URLS);
}

export async function handleCookSnapFeedEvents(
  db: FeedEventDb,
  snapId: string,
  data: Record<string, unknown> | undefined,
): Promise<number> {
  if (!data) return 0;
  const userId = ownerOf(data, "userId");
  const urls = snapUrls(data);
  if (userId === null || urls.length === 0) return 0;
  const snap = await db
    .collection("activity_events")
    .where("actorId", "==", userId)
    .where("extraData.photoUrl", "in", urls)
    .limit(MAX_FEED_EVENTS_PER_SNAP)
    .get();
  if (snap.docs.length === MAX_FEED_EVENTS_PER_SNAP) {
    logger.warn("[onCookSnapDeleted] feed events at the cap; rest kept", {
      snapId,
    });
  }
  const cooked = snap.docs.filter((d) => d.data()?.type === "cooked");
  if (cooked.length === 0) return 0;
  const batch = db.batch();
  for (const doc of cooked) batch.delete(doc.ref);
  await batch.commit();
  logger.info("[onCookSnapDeleted] feed events deleted", {
    snapId,
    deleted: cooked.length,
  });
  return cooked.length;
}

export async function onCookSnapDeletedEvent(
  bucket: PhotoBucket,
  db: FeedEventDb,
  snapId: string,
  data: Record<string, unknown> | undefined,
): Promise<void> {
  // A Firestore failure must not keep the photos, so the feed half catches its
  // own error.
  try {
    await handleCookSnapFeedEvents(db, snapId, data);
  } catch (e) {
    logger.error("[onCookSnapDeleted] feed event cleanup failed", {
      snapId,
      error: (e as Error).message,
    });
  }
  await handleCookSnapDeleted(bucket, snapId, data);
}

export const onRecipeCommentDeleted = onDocumentDeleted(
  "recipe_comments/{commentId}",
  async (event) => {
    await handleCommentDeleted(
      admin.storage().bucket(),
      event.params.commentId,
      event.data?.data(),
    );
  },
);

export const onCookSnapDeleted = onDocumentDeleted(
  "cook_snaps/{snapId}",
  async (event) => {
    await onCookSnapDeletedEvent(
      admin.storage().bucket(),
      admin.firestore(),
      event.params.snapId,
      event.data?.data(),
    );
  },
);
