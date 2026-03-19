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
import { requireAdmin } from "../shared/require-admin";

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
  // Legacy camelCase collections (Phase 3)
  { from: "sharedMenus", to: "shared_menus" },
  { from: "sharedShoppingLists", to: "shared_shopping_lists" },
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
    const [sourceSnapshot, targetSnapshot] = await Promise.all([
      db.collection(from).get(),
      db.collection(to).select().get(),
    ]);
    stats.found = sourceSnapshot.size;

    if (sourceSnapshot.empty) return stats;

    const existingIds = new Set(targetSnapshot.docs.map(d => d.id));
    let batch = db.batch();
    let batchCount = 0;

    for (const doc of sourceSnapshot.docs) {
      if (existingIds.has(doc.id)) {
        stats.alreadyExists++;
        continue;
      }

      if (!dryRun) {
        batch.set(db.collection(to).doc(doc.id), doc.data());
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
      const userRef = db.collection("users").doc(userDoc.id);
      const [sourceSnapshot, targetSnapshot] = await Promise.all([
        userRef.collection(from).get(),
        userRef.collection(to).select().get(),
      ]);

      stats.found += sourceSnapshot.size;
      if (sourceSnapshot.empty) continue;

      const existingIds = new Set(targetSnapshot.docs.map(d => d.id));
      let batch = db.batch();
      let batchCount = 0;

      for (const doc of sourceSnapshot.docs) {
        if (existingIds.has(doc.id)) {
          stats.alreadyExists++;
          continue;
        }

        if (!dryRun) {
          batch.set(userRef.collection(to).doc(doc.id), doc.data());
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
      const sourceRef = db.collection(fromBase).doc(baseDoc.id);
      const targetBaseRef = db.collection(toBase).doc(baseDoc.id);
      const [subSnapshot, targetSubSnapshot] = await Promise.all([
        sourceRef.collection(fromSub).get(),
        targetBaseRef.collection(toSub).select().get(),
      ]);

      stats.found += subSnapshot.size;
      if (subSnapshot.empty) continue;

      const existingIds = new Set(targetSubSnapshot.docs.map(d => d.id));
      let batch = db.batch();
      let batchCount = 0;

      for (const doc of subSnapshot.docs) {
        if (existingIds.has(doc.id)) {
          stats.alreadyExists++;
          continue;
        }

        if (!dryRun) {
          batch.set(targetBaseRef.collection(toSub).doc(doc.id), doc.data());
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
    requireAdmin(context);

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
