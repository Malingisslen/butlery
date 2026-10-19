import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { commitInChunks } from "../../shared/batch-update";
import {
  batchDeleteAll,
  scrubWithOneReread,
  cappedReread,
  updateWith,
} from "./core";

export async function deleteCommentsAndRatings(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  // recipe_comments: anonymize to preserve thread structure.
  const recipeComments = await db
    .collection("recipe_comments")
    .where("authorId", "==", uid)
    .get();
  if (recipeComments.docs.length > 0) {
    await commitInChunks(
      db,
      recipeComments.docs,
      (batch, doc) => {
        batch.update(doc.ref, {
          authorId: "deleted",
          authorDisplayName: "[Raderad användare]",
          authorAvatarUrl: null,
          isDeleted: true,
          text: "[Borttagen kommentar]",
        });
      },
      { label: "anonymizeRecipeComments", strict: false },
    );
  }

  // Hard-delete ratings + collectionGroup comments/ratings.
  const [recipeRatings, cgComments, cgRatings] = await Promise.all([
    db.collection("recipe_ratings").where("userId", "==", uid).get(),
    db.collectionGroup("comments").where("commentedBy", "==", uid).get(),
    db.collectionGroup("ratings").where("ratedBy", "==", uid).get(),
  ]);
  await batchDeleteAll(db, [
    ...recipeRatings.docs,
    ...cgComments.docs,
    ...cgRatings.docs,
  ]);
  return true;
}

/**
 * Cap on one erasure's sweep of OTHER people's ratings that name this user as
 * the recipe owner. Declines rather than truncates, like the sibling caps: any
 * rater can write any uid into `recipeOwnerId` (BUT-2057), so the row count is
 * not this user's own doing.
 */
export const MAX_RATING_OWNER_SWEEP_ROWS = 2000;

/**
 * BUT-2072: take the erased uid out of `recipeOwnerId` on ratings OTHER people
 * wrote on this user's recipes. The field is removed, never nulled — the rules'
 * block gate reads its PRESENCE — and the rating itself stays, because it
 * belongs to the rater.
 *
 * Runs after tier 1, not inside it: `deleteCommentsAndRatings` hard-deletes the
 * ratings this user wrote on their OWN recipes, which match this query too, and
 * a `batch.update` on a row deleted underneath it rejects the whole chunk.
 */
export async function scrubRatingRecipeOwner(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const read = () =>
    db
      .collection("recipe_ratings")
      .where("recipeOwnerId", "==", uid)
      .limit(MAX_RATING_OWNER_SWEEP_ROWS + 1)
      .get();
  const snap = await read();

  if (snap.size > MAX_RATING_OWNER_SWEEP_ROWS) {
    logger.error(
      "[deletion-cascade] implausible rating owner count; not sweeping",
      { uid_prefix: uid.slice(0, 6), rows: snap.size },
    );
    return false;
  }
  if (snap.empty) return true;

  try {
    await scrubWithOneReread(
      db,
      snap.docs,
      cappedReread(read, MAX_RATING_OWNER_SWEEP_ROWS, "scrubRatingRecipeOwner"),
      updateWith({ recipeOwnerId: admin.firestore.FieldValue.delete() }),
      "scrubRatingRecipeOwner",
    );
  } catch (err) {
    logger.error("[deletion-cascade] rating owner scrub failed", {
      uid_prefix: uid.slice(0, 6),
      rows: snap.size,
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
    return false;
  }

  logger.info("[deletion-cascade] rating owner scrub", {
    uid_prefix: uid.slice(0, 6),
    rows: snap.size,
  });
  return true;
}

/**
 * Caps on one erasure's sweeps of `recipe_comments` (BUT-2112). Decline rather
 * than truncate, like the sibling caps. `recipeOwnerId` and `sharedWithUserIds`
 * are written by the commenting client, so their row counts are not this
 * user's own doing.
 */
export const MAX_COMMENT_OWNER_SWEEP_ROWS = 2000;

export const MAX_COMMENT_SHARE_SWEEP_ROWS = 2000;

export const MAX_COMMENT_LIKE_SWEEP_ROWS = 2000;

/**
 * One capped scrub over rows of `collection` that carry the erased uid in a
 * field someone else's client wrote. The row stays; only the uid goes.
 */
export async function scrubCommentField(
  db: admin.firestore.Firestore,
  uid: string,
  collection: "recipe_comments" | "messages",
  query: { field: string; op: "==" | "array-contains"; cap: number },
  update: Record<string, unknown>,
  label: string,
): Promise<boolean> {
  const read = () =>
    db
      .collection(collection)
      .where(query.field, query.op, uid)
      .limit(query.cap + 1)
      .get();
  const snap = await read();

  if (snap.size > query.cap) {
    logger.error(`[deletion-cascade] implausible ${label} count; not sweeping`, {
      uid_prefix: uid.slice(0, 6),
      rows: snap.size,
    });
    return false;
  }
  if (snap.empty) return true;

  try {
    await scrubWithOneReread(
      db,
      snap.docs,
      cappedReread(read, query.cap, label),
      updateWith(update),
      label,
    );
  } catch (err) {
    logger.error(`[deletion-cascade] ${label} failed`, {
      uid_prefix: uid.slice(0, 6),
      rows: snap.size,
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
    return false;
  }

  logger.info(`[deletion-cascade] ${label}`, {
    uid_prefix: uid.slice(0, 6),
    rows: snap.size,
  });
  return true;
}

/**
 * BUT-2112: remove the erased uid from `recipeOwnerId` on comments on their
 * recipes. Removed, never nulled: the read rule and the block gate both test
 * the field's PRESENCE.
 */
export async function scrubCommentRecipeOwner(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  return scrubCommentField(
    db,
    uid,
    "recipe_comments",
    { field: "recipeOwnerId", op: "==", cap: MAX_COMMENT_OWNER_SWEEP_ROWS },
    { recipeOwnerId: admin.firestore.FieldValue.delete() },
    "scrubCommentRecipeOwner",
  );
}

/**
 * BUT-2112: remove the erased uid from `sharedWithUserIds`. `arrayRemove`
 * takes out that one element, so every other recipient keeps read access.
 */
export async function scrubCommentSharedWith(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  return scrubCommentField(
    db,
    uid,
    "recipe_comments",
    {
      field: "sharedWithUserIds",
      op: "array-contains",
      cap: MAX_COMMENT_SHARE_SWEEP_ROWS,
    },
    { sharedWithUserIds: admin.firestore.FieldValue.arrayRemove(uid) },
    "scrubCommentSharedWith",
  );
}

/** True for `recipe_comments/{id}`, and for nothing nested deeper. */
function isRecipeCommentParent(ref: admin.firestore.DocumentReference): boolean {
  return ref.parent.id === "recipe_comments" && ref.parent.parent === null;
}

/**
 * The erased user's like rows under comments, found by collection group and
 * kept only when they sit under a top-level `recipe_comments` document.
 * `null` when the read exceeds the cap.
 */
export async function commentLikeRows(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<admin.firestore.QueryDocumentSnapshot[] | null> {
  const snap = await db
    .collectionGroup("likes")
    .where("userId", "==", uid)
    .limit(MAX_COMMENT_LIKE_SWEEP_ROWS + 1)
    .get();
  if (snap.size > MAX_COMMENT_LIKE_SWEEP_ROWS) return null;
  return snap.docs.filter((doc) => {
    const parent = doc.ref.parent.parent;
    return parent !== null && isRecipeCommentParent(parent);
  });
}

/**
 * BUT-2112: delete the erased user's comment likes, then take each one off
 * its comment's `likesCount`.
 *
 * Two passes, deletes first. A like can outlive its comment — the author, an
 * admin or the duplicate guard can delete the comment and nothing deletes
 * its subcollection — and an update on that missing parent would reject
 * every other write in its chunk. Deleting a missing document never throws.
 * Deletes first also means a re-run finds no rows.
 *
 * A failed decrement pass is logged, not reported: the personal data is gone
 * after the first pass, and what is left is a display counter one too high.
 */
export async function deleteCommentLikes(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const rows = await commentLikeRows(db, uid);
  if (rows === null) {
    logger.error("[deletion-cascade] implausible comment like count; not sweeping", {
      uid_prefix: uid.slice(0, 6),
    });
    return false;
  }
  if (rows.length === 0) return true;

  try {
    await commitInChunks(
      db,
      rows,
      (batch, doc) => {
        batch.delete(doc.ref);
      },
      { label: "deleteCommentLikes", strict: true },
    );
  } catch (err) {
    logger.error("[deletion-cascade] comment like delete failed", {
      uid_prefix: uid.slice(0, 6),
      rows: rows.length,
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
    return false;
  }

  let decremented = 0;
  try {
    const parents: admin.firestore.DocumentReference[] = [];
    const GROUP = 100;
    for (let i = 0; i < rows.length; i += GROUP) {
      const group = rows.slice(i, i + GROUP);
      const snaps = await Promise.all(
        group.map((doc) => (doc.ref.parent.parent as admin.firestore.DocumentReference).get()),
      );
      snaps.forEach((snap, j) => {
        const count = snap.data()?.likesCount;
        if (snap.exists && typeof count === "number" && count > 0) {
          parents.push(group[j].ref.parent.parent as admin.firestore.DocumentReference);
        }
      });
    }
    decremented = parents.length;
    await commitInChunks(
      db,
      parents,
      (batch, ref) => {
        batch.update(ref, {
          likesCount: admin.firestore.FieldValue.increment(-1),
        });
      },
      { label: "decrementCommentLikes", strict: true },
    );
  } catch (err) {
    logger.warn("[deletion-cascade] comment likesCount decrement failed", {
      uid_prefix: uid.slice(0, 6),
      rows: rows.length,
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
  }

  logger.info("[deletion-cascade] comment likes deleted", {
    uid_prefix: uid.slice(0, 6),
    rows: rows.length,
    decremented,
  });
  return true;
}
