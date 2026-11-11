import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { hashUid } from "../../shared/hash-uid";
import { commentLikeRows } from "./comments-ratings";
import { COMMENT_REACTION_KEYS } from "./recipe-members-reactions";

export async function probeRatingOwnerStamps(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<number> {
  let residual = 0;
  // BUT-2072: the erased uid as the recipe OWNER on other people's ratings. Its
  // own leg because the `probes` list above filters on `userId`, which is the
  // rater. Uncapped, so it stays loud when the capped scrub declined.
  try {
    const snap = await db
      .collection("recipe_ratings")
      .where("recipeOwnerId", "==", uid)
      .count()
      .get();
    const count = snap.data().count ?? 0;
    if (count > 0) {
      residual += count;
      logger.warn("[deletion-cascade] residual rating owner stamps", {
        uid_prefix: uid.slice(0, 6),
        count,
      });
    }
  } catch (err) {
    residual += 1;
    logger.error("[deletion-cascade] residual probe failed: rating owner", {
      uid_prefix: uid.slice(0, 6),
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
  }
  return residual;
}

export async function probeCommentStamps(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<number> {
  let residual = 0;
  // BUT-2112: the erased uid in other people's comments — as recipe owner, as
  // a share recipient — and their own comment likes. Own legs for the same
  // reason as the rating-owner leg above.
  for (const [label, field, op] of [
    ["comment owner", "recipeOwnerId", "=="],
    ["comment shared-with", "sharedWithUserIds", "array-contains"],
  ] as const) {
    try {
      const snap = await db
        .collection("recipe_comments")
        .where(field, op, uid)
        .count()
        .get();
      const count = snap.data().count ?? 0;
      if (count > 0) {
        residual += count;
        logger.warn(`[deletion-cascade] residual ${label} stamps`, {
          uid_prefix: uid.slice(0, 6),
          count,
        });
      }
    } catch (err) {
      residual += 1;
      logger.error(`[deletion-cascade] residual probe failed: ${label}`, {
        uid_prefix: uid.slice(0, 6),
        errCode: (err as { code?: number | string }).code ?? null,
        errName: err instanceof Error ? err.name : typeof err,
      });
    }
  }
  return residual;
}

export async function probeRecipeMemberKeys(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<number> {
  let residual = 0;
  // BUT-2272: the erased uid as a member of other people's shared recipes.
  // A plain count, with no skip for the user's own recipes: the probe runs
  // after tier 1, where `deleteRecipes` removes those, so one still standing
  // is residue too. Uncapped, so it stays loud when the capped scrub declined.
  try {
    const snap = await db
      .collectionGroup("recipes")
      .where(
        new admin.firestore.FieldPath("socialData", "memberPermissions", uid),
        "!=",
        null,
      )
      .count()
      .get();
    const count = snap.data().count ?? 0;
    if (count > 0) {
      residual += count;
      logger.warn("[deletion-cascade] residual recipe member keys", {
        uidHash: hashUid(uid),
        field: "socialData.memberPermissions.<uid>",
        count,
      });
    }
  } catch (err) {
    residual += 1;
    logger.error("[deletion-cascade] residual probe failed: recipe members", {
      uidHash: hashUid(uid),
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
  }
  return residual;
}

export async function probeReactionStamps(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<number> {
  let residual = 0;
  // BUT-2115 (comments) and BUT-2398 (messages): one leg per reaction key,
  // the deleter's own query shape.
  for (const [collection, noun] of [
    ["recipe_comments", "comment"],
    ["messages", "message"],
  ] as const) {
    for (const key of COMMENT_REACTION_KEYS) {
      const label = `${noun} reaction ${key}`;
      try {
        const snap = await db
          .collection(collection)
          .where(`reactions.${key}`, "array-contains", uid)
          .count()
          .get();
        const count = snap.data().count ?? 0;
        if (count > 0) {
          residual += count;
          logger.warn(`[deletion-cascade] residual ${label} stamps`, {
            uid_prefix: uid.slice(0, 6),
            count,
          });
        }
      } catch (err) {
        residual += 1;
        logger.error(`[deletion-cascade] residual probe failed: ${label}`, {
          uid_prefix: uid.slice(0, 6),
          errCode: (err as { code?: number | string }).code ?? null,
          errName: err instanceof Error ? err.name : typeof err,
        });
      }
    }
  }
  return residual;
}

export async function probeCommentLikes(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<number> {
  let residual = 0;
  // A read rather than `count()`, because only rows under `recipe_comments`
  // are the deleter's to remove. Over the cap reads as residual.
  try {
    const rows = await commentLikeRows(db, uid);
    const count = rows === null ? 1 : rows.length;
    if (count > 0) {
      residual += count;
      logger.warn("[deletion-cascade] residual comment likes", {
        uid_prefix: uid.slice(0, 6),
        count,
        overCap: rows === null,
      });
    }
  } catch (err) {
    residual += 1;
    logger.error("[deletion-cascade] residual probe failed: comment likes", {
      uid_prefix: uid.slice(0, 6),
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
  }
  return residual;
}
