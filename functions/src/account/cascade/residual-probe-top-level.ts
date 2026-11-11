import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { Collections } from "../../shared/collections";
import { learnedAliasesCollection } from "./learned-aliases";

export async function probeUserIdCollections(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<number> {
  // `recipes` is NOT in this list, and must never be added back. These probes are
  // top-level collections filtered by a `userId` FIELD; recipes live in the
  // subcollection `users/{uid}/recipes` and are probed separately below. Reading
  // them here counted a collection with no documents, so the probe returned zero
  // on every deletion — an all-clear that was true by accident and would have
  // stayed true if `deleteRecipes` ever stopped working. Exactly the failure the
  // comment further down calls "the realtime_recipes wrong-field trap" (BUT-1801).
  const probes = [
    "user_notifications",
    "user_fcm_tokens",
    // BUT-1450: notification analytics the cascade erases (all userId-scoped).
    "notification_history",
    "notification_batches",
    "notification_engagement",
    // BUT-1473: allergen tag-override corrections (top-level, userId-scoped).
    "tag_overrides_log",
    // The user-typed parser corrections `deleteParsingCorrections` erases.
    "parsing_corrections",
    // The import log `deleteParseEvents` erases.
    "parse_events",
    // BUT-2028: the collection `deleteIngredientSuggestions` erases. Same
    // shape as the rest of this list — top-level, filtered on a `userId`
    // field — so it belongs here rather than needing a leg of its own.
    "ingredient_suggestions",
    // BUT-1693: the collection `deleteHouseholdAllergenShares` erases.
    "household_allergen_shares",
  ] as const;
  let residual = 0;
  for (const col of probes) {
    try {
      const snap = await db
        .collection(col)
        .where("userId", "==", uid)
        .count()
        .get();
      const count = snap.data().count ?? 0;
      if (count > 0) {
        residual += count;
        logger.warn(`[deletion-cascade] residual in ${col}: ${count} docs`);
      }
    } catch (err) {
      residual += 1;
      logger.error(`[deletion-cascade] residual probe failed: ${col}`, { err });
    }
  }
  return residual;
}

export async function probeOwnerFieldCollections(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<number> {
  let residual = 0;
  // BUT-2350: `activity_events` is keyed on `actorId`, so it cannot join the
  // `userId` list above.
  try {
    const snap = await db
      .collection("activity_events")
      .where("actorId", "==", uid)
      .count()
      .get();
    const count = snap.data().count ?? 0;
    if (count > 0) {
      residual += count;
      logger.warn(
        `[deletion-cascade] residual in activity_events: ${count} docs`,
      );
    }
  } catch (err) {
    residual += 1;
    logger.error("[deletion-cascade] residual probe failed: activity_events", {
      uid_prefix: uid.slice(0, 6),
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
  }
  // BUT-2354: templates are keyed on `ownerId`, not `userId`.
  try {
    const snap = await db
      .collection(Collections.shoppingListTemplates)
      .where("ownerId", "==", uid)
      .count()
      .get();
    const count = snap.data().count ?? 0;
    if (count > 0) {
      residual += count;
      logger.warn(
        `[deletion-cascade] residual in ${Collections.shoppingListTemplates}: ${count} docs`,
      );
    }
  } catch (err) {
    residual += 1;
    logger.error(
      `[deletion-cascade] residual probe failed: ${Collections.shoppingListTemplates}`,
      {
        uid_prefix: uid.slice(0, 6),
        errCode: (err as { code?: number | string }).code ?? null,
        errName: err instanceof Error ? err.name : typeof err,
      },
    );
  }
  // BUT-2463: short links are keyed on `createdBy`.
  try {
    const snap = await db
      .collection(Collections.deepLinks)
      .where("createdBy", "==", uid)
      .count()
      .get();
    const count = snap.data().count ?? 0;
    if (count > 0) {
      residual += count;
      logger.warn(
        `[deletion-cascade] residual in ${Collections.deepLinks}: ${count} docs`,
      );
    }
  } catch (err) {
    residual += 1;
    logger.error(
      `[deletion-cascade] residual probe failed: ${Collections.deepLinks}`,
      {
        uid_prefix: uid.slice(0, 6),
        errCode: (err as { code?: number | string }).code ?? null,
        errName: err instanceof Error ? err.name : typeof err,
      },
    );
  }
  // Alias candidates hold voters in a `userIds` array, so they cannot join
  // the `userId` list above.
  try {
    const snap = await learnedAliasesCollection(db)
      .where("userIds", "array-contains", uid)
      .count()
      .get();
    const count = snap.data().count ?? 0;
    if (count > 0) {
      residual += count;
      logger.warn(`[deletion-cascade] residual in learned_aliases: ${count} docs`);
    }
  } catch (err) {
    residual += 1;
    logger.error("[deletion-cascade] residual probe failed: learned_aliases", {
      uid_prefix: uid.slice(0, 6),
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
  }
  return residual;
}

export async function probeOwnRecipes(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<number> {
  let residual = 0;
  // BUT-1801: recipes are a SUBCOLLECTION, so they need a path-scoped probe
  // rather than a userId-field filter. Counted directly under the user document:
  // no index is required for a bare `count()`, and it makes no assumption about
  // recipe documents carrying a top-level `userId` field (they are not known to).
  // A `collectionGroup("recipes").where("userId","==",uid)` probe would need both
  // — a COLLECTION_GROUP index this repo does not declare for that field, and the
  // field itself — and would fail the same silent way the top-level read did.
  try {
    const snap = await db
      .collection("users")
      .doc(uid)
      .collection("recipes")
      .count()
      .get();
    const count = snap.data().count ?? 0;
    if (count > 0) {
      residual += count;
      logger.warn(`[deletion-cascade] residual in recipes: ${count} docs`);
    }
  } catch (err) {
    residual += 1;
    logger.error("[deletion-cascade] residual probe failed: recipes", {
      uid_prefix: uid.slice(0, 6),
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
  }
  return residual;
}
