import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { hashUid } from "../../shared/hash-uid";
import { scrubWithOneReread, cappedReread } from "./core";
import { scrubCommentField } from "./comments-ratings";

/**
 * Cap on one erasure's sweep of OTHER people's recipes that list this user in
 * `socialData.memberPermissions`. Declines rather than truncates, like the
 * sibling caps: the recipe create and update rules let an owner write any
 * uid into that map on their own recipes, so the row count is not this
 * user's own doing.
 */
export const MAX_RECIPE_MEMBER_SWEEP_ROWS = 2000;

/** True for a document in the erased user's own `users/{uid}/recipes`. */
function isOwnRecipe(
  ref: admin.firestore.DocumentReference,
  uid: string,
): boolean {
  const owner = ref.parent.parent;
  return (
    owner !== null &&
    owner.id === uid &&
    owner.parent.id === "users" &&
    owner.parent.parent === null
  );
}

/**
 * BUT-2272: take the erased uid out of other people's shared recipes — the
 * `socialData.memberPermissions` key that found the recipe, and the
 * `socialData.grants` key beside it. The recipe stays; it belongs to its owner.
 *
 * Both keys are addressed with `FieldPath`, never a dotted string built from
 * the uid. The user's own recipes are skipped: `deleteRecipes` removes them in
 * tier 1, and an update on a document deleted underneath it rejects the whole
 * chunk.
 */
export async function scrubRecipeMemberPermissions(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const read = () =>
    db
      .collectionGroup("recipes")
      .where(
        new admin.firestore.FieldPath("socialData", "memberPermissions", uid),
        "!=",
        null,
      )
      .limit(MAX_RECIPE_MEMBER_SWEEP_ROWS + 1)
      .get();
  const snap = await read();

  if (snap.size > MAX_RECIPE_MEMBER_SWEEP_ROWS) {
    logger.error(
      "[deletion-cascade] implausible recipe member count; not sweeping",
      { uidHash: hashUid(uid), rows: snap.size },
    );
    return false;
  }
  const othersRecipe = (doc: admin.firestore.QueryDocumentSnapshot) =>
    !isOwnRecipe(doc.ref, uid);
  const rows = snap.docs.filter(othersRecipe);
  if (rows.length === 0) return true;

  try {
    await scrubWithOneReread(
      db,
      rows,
      cappedReread(
        read,
        MAX_RECIPE_MEMBER_SWEEP_ROWS,
        "scrubRecipeMemberPermissions",
        othersRecipe,
      ),
      (batch, doc) => {
        batch.update(
          doc.ref,
          new admin.firestore.FieldPath("socialData", "memberPermissions", uid),
          admin.firestore.FieldValue.delete(),
          new admin.firestore.FieldPath("socialData", "grants", uid),
          admin.firestore.FieldValue.delete(),
        );
      },
      "scrubRecipeMemberPermissions",
    );
  } catch (err) {
    logger.error("[deletion-cascade] recipe member scrub failed", {
      uidHash: hashUid(uid),
      rows: rows.length,
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
    return false;
  }

  logger.info("[deletion-cascade] recipe member scrub", {
    uidHash: hashUid(uid),
    rows: rows.length,
  });
  return true;
}

/**
 * BUT-2115: the reaction keys `recipe_comments.reactions` and
 * `messages.reactions` may hold. One list
 * with `reactionKeys()` in firestore.rules and `kReactionEmojis` in
 * emoji_reaction_picker.dart; a functions test parses all three.
 */
export const COMMENT_REACTION_KEYS = [
  "thumbs_up",
  "heart",
  "fire",
  "laughing",
  "yum",
  "thinking",
] as const;

/** Per-key cap for `scrubCommentReactions`, declining like the BUT-2112 caps. */
export const MAX_COMMENT_REACTION_SWEEP_ROWS = 2000;

/**
 * BUT-2115: take the erased uid out of every reaction list on other people's
 * comments. `arrayRemove` leaves the other reactors in place. A key that
 * declines or fails does not stop the others, and fails the step.
 */
export async function scrubCommentReactions(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  let ok = true;
  for (const key of COMMENT_REACTION_KEYS) {
    const swept = await scrubCommentField(
      db,
      uid,
      "recipe_comments",
      {
        field: `reactions.${key}`,
        op: "array-contains",
        cap: MAX_COMMENT_REACTION_SWEEP_ROWS,
      },
      { [`reactions.${key}`]: admin.firestore.FieldValue.arrayRemove(uid) },
      `scrubCommentReactions:${key}`,
    );
    if (!swept) ok = false;
  }
  return ok;
}

/** Per-key cap for `scrubMessageReactions`, declining like the comment cap. */
export const MAX_MESSAGE_REACTION_SWEEP_ROWS = 2000;

/**
 * BUT-2398: take the erased uid out of every reaction list on chat messages.
 * The rules admit the same keys as on comments. `arrayRemove` leaves the other
 * reactors in place. A key that declines or fails does not stop the others,
 * and fails the step.
 */
export async function scrubMessageReactions(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  let ok = true;
  for (const key of COMMENT_REACTION_KEYS) {
    const swept = await scrubCommentField(
      db,
      uid,
      "messages",
      {
        field: `reactions.${key}`,
        op: "array-contains",
        cap: MAX_MESSAGE_REACTION_SWEEP_ROWS,
      },
      { [`reactions.${key}`]: admin.firestore.FieldValue.arrayRemove(uid) },
      `scrubMessageReactions:${key}`,
    );
    if (!swept) ok = false;
  }
  return ok;
}
