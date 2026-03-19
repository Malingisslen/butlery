/**
 * Admin-only callable function to migrate data from old camelCase collection
 * names to new snake_case names.
 *
 * Handles both top-level and user subcollection renames.
 * Dry-run by default, admin-only, idempotent, never deletes source data.
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { hashUid } from "../shared/hash-uid";

const getDb = () => admin.firestore();
const BATCH_LIMIT = 500;

interface MigrationRequest {
  dryRun?: boolean;
  collection?: string;
}

interface CollectionStats {
  found: number;
  alreadyExists: number;
  migrated: number;
  errors: number;
}

interface MigrationResult {
  success: boolean;
  dryRun: boolean;
  collections: Record<string, CollectionStats>;
}

// Top-level collection renames
const TOP_LEVEL_RENAMES: Array<{ from: string; to: string }> = [
  { from: "shoppingListTemplates", to: "shopping_list_templates" },
  { from: "tagConfigs", to: "tag_configs" },
  { from: "ingredientSuggestions", to: "ingredient_suggestions" },
];

// User subcollection renames (under users/{uid}/)
const USER_SUBCOLLECTION_RENAMES: Array<{ from: string; to: string }> = [
  { from: "friendCategories", to: "friend_categories" },
  { from: "categoryMemberships", to: "category_memberships" },
  { from: "personalTagIds", to: "personal_tags" },
  { from: "personalTagGroups", to: "personal_tag_groups" },
  { from: "conversationMemberships", to: "conversation_memberships" },
  { from: "rateLimits", to: "rate_limits" },
];

// Top-level collections with nested subcollections that need path changes
const NESTED_RENAMES: Array<{
  fromBase: string;
  toBase: string;
  fromSub: string;
  toSub: string;
}> = [
  {
    fromBase: "userSharedMenus",
    toBase: "user_shared_menus",
    fromSub: "receivedMenus",
    toSub: "received_menus",
  },
  {
    fromBase: "userSharedShoppingLists",
    toBase: "user_shared_shopping_lists",
    fromSub: "receivedLists",
    toSub: "received_lists",
  },
];

async function migrateTopLevel(
  db: admin.firestore.Firestore,
  from: string,
  to: string,
  dryRun: boolean
): Promise<CollectionStats> {
  const stats: CollectionStats = { found: 0, alreadyExists: 0, migrated: 0, errors: 0 };

  try {
    const sourceSnapshot = await db.collection(from).get();
    stats.found = sourceSnapshot.size;

    if (sourceSnapshot.empty) return stats;

    let batch = db.batch();
    let batchCount = 0;

    for (const doc of sourceSnapshot.docs) {
      const targetRef = db.collection(to).doc(doc.id);
      const existing = await targetRef.get();

      if (existing.exists) {
        stats.alreadyExists++;
        continue;
      }

      if (!dryRun) {
        batch.set(targetRef, doc.data());
        batchCount++;

        if (batchCount >= BATCH_LIMIT) {
          await batch.commit();
          batch = db.batch();
          batchCount = 0;
        }
      }

      stats.migrated++;
    }

    if (!dryRun && batchCount > 0) {
      await batch.commit();
    }
  } catch (error) {
    stats.errors++;
    functions.logger.error(`Error migrating "${from}" → "${to}": ${error}`);
  }

  return stats;
}

async function migrateUserSubcollections(
  db: admin.firestore.Firestore,
  from: string,
  to: string,
  dryRun: boolean
): Promise<CollectionStats> {
  const stats: CollectionStats = { found: 0, alreadyExists: 0, migrated: 0, errors: 0 };

  try {
    const usersSnapshot = await db.collection("users").get();

    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      const sourceSnapshot = await db
        .collection("users")
        .doc(userId)
        .collection(from)
        .get();

      stats.found += sourceSnapshot.size;

      if (sourceSnapshot.empty) continue;

      let batch = db.batch();
      let batchCount = 0;

      for (const doc of sourceSnapshot.docs) {
        const targetRef = db
          .collection("users")
          .doc(userId)
          .collection(to)
          .doc(doc.id);
        const existing = await targetRef.get();

        if (existing.exists) {
          stats.alreadyExists++;
          continue;
        }

        if (!dryRun) {
          batch.set(targetRef, doc.data());
          batchCount++;

          if (batchCount >= BATCH_LIMIT) {
            await batch.commit();
            batch = db.batch();
            batchCount = 0;
          }
        }

        stats.migrated++;
      }

      if (!dryRun && batchCount > 0) {
        await batch.commit();
      }

      functions.logger.info(
        `User ${hashUid(userId)}: subcollection "${from}" → "${to}": ${sourceSnapshot.size} docs`
      );
    }
  } catch (error) {
    stats.errors++;
    functions.logger.error(
      `Error migrating user subcollection "${from}" → "${to}": ${error}`
    );
  }

  return stats;
}

async function migrateNestedCollections(
  db: admin.firestore.Firestore,
  fromBase: string,
  toBase: string,
  fromSub: string,
  toSub: string,
  dryRun: boolean
): Promise<CollectionStats> {
  const stats: CollectionStats = { found: 0, alreadyExists: 0, migrated: 0, errors: 0 };

  try {
    const baseSnapshot = await db.collection(fromBase).get();

    for (const baseDoc of baseSnapshot.docs) {
      const subSnapshot = await db
        .collection(fromBase)
        .doc(baseDoc.id)
        .collection(fromSub)
        .get();

      stats.found += subSnapshot.size;

      if (subSnapshot.empty) continue;

      let batch = db.batch();
      let batchCount = 0;

      for (const doc of subSnapshot.docs) {
        const targetRef = db
          .collection(toBase)
          .doc(baseDoc.id)
          .collection(toSub)
          .doc(doc.id);
        const existing = await targetRef.get();

        if (existing.exists) {
          stats.alreadyExists++;
          continue;
        }

        if (!dryRun) {
          batch.set(targetRef, doc.data());
          batchCount++;

          if (batchCount >= BATCH_LIMIT) {
            await batch.commit();
            batch = db.batch();
            batchCount = 0;
          }
        }

        stats.migrated++;
      }

      if (!dryRun && batchCount > 0) {
        await batch.commit();
      }
    }
  } catch (error) {
    stats.errors++;
    functions.logger.error(
      `Error migrating "${fromBase}/${fromSub}" → "${toBase}/${toSub}": ${error}`
    );
  }

  return stats;
}

export const migrateCollectionNames = functions.https.onCall(
  async (data: MigrationRequest, context): Promise<MigrationResult> => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Authentication required"
      );
    }

    const isAdmin =
      context.auth.token.admin === true ||
      context.auth.token.role === "admin";
    if (!isAdmin) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Admin access required"
      );
    }

    const dryRun = data?.dryRun !== false;
    const filterCollection = data?.collection;
    const db = getDb();
    const result: MigrationResult = {
      success: true,
      dryRun,
      collections: {},
    };

    functions.logger.info(
      `Collection name migration started by admin ${hashUid(context.auth.uid)} (dryRun=${dryRun})`
    );

    // Top-level renames
    for (const { from, to } of TOP_LEVEL_RENAMES) {
      if (filterCollection && filterCollection !== from) continue;
      result.collections[from] = await migrateTopLevel(db, from, to, dryRun);
      const s = result.collections[from];
      if (s.errors > 0) result.success = false;
      functions.logger.info(
        `"${from}" → "${to}": ${s.found} found, ${s.alreadyExists} exist, ${s.migrated} ${dryRun ? "would migrate" : "migrated"}`
      );
    }

    // User subcollection renames
    for (const { from, to } of USER_SUBCOLLECTION_RENAMES) {
      if (filterCollection && filterCollection !== from) continue;
      result.collections[`users/*/` + from] = await migrateUserSubcollections(
        db,
        from,
        to,
        dryRun
      );
      const s = result.collections[`users/*/` + from];
      if (s.errors > 0) result.success = false;
      functions.logger.info(
        `"users/*/${from}" → "users/*/${to}": ${s.found} found, ${s.alreadyExists} exist, ${s.migrated} ${dryRun ? "would migrate" : "migrated"}`
      );
    }

    // Nested collection renames
    for (const { fromBase, toBase, fromSub, toSub } of NESTED_RENAMES) {
      if (filterCollection && filterCollection !== fromBase) continue;
      const key = `${fromBase}/*/${fromSub}`;
      result.collections[key] = await migrateNestedCollections(
        db,
        fromBase,
        toBase,
        fromSub,
        toSub,
        dryRun
      );
      const s = result.collections[key];
      if (s.errors > 0) result.success = false;
      functions.logger.info(
        `"${key}" → "${toBase}/*/${toSub}": ${s.found} found, ${s.alreadyExists} exist, ${s.migrated} ${dryRun ? "would migrate" : "migrated"}`
      );
    }

    return result;
  }
);
