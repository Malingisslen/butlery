/**
 * Admin-only callable function to migrate data from legacy camelCase
 * collections to current snake_case collections.
 *
 * Covers:
 * - sharedMenus → shared_menus
 * - sharedShoppingLists → shared_shopping_lists
 *
 * Safety: dry-run by default, admin-only, idempotent, never deletes source data.
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

interface MigrationResult {
  success: boolean;
  dryRun: boolean;
  collections: Record<string, {
    found: number;
    alreadyExists: number;
    migrated: number;
    errors: number;
  }>;
}

const LEGACY_MAPPINGS: Array<{ from: string; to: string }> = [
  { from: "sharedMenus", to: "shared_menus" },
  { from: "sharedShoppingLists", to: "shared_shopping_lists" },
];

export const migrateLegacyCollections = functions.https.onCall(
  async (data: MigrationRequest, context): Promise<MigrationResult> => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Authentication required"
      );
    }

    const isAdmin = context.auth.token.admin === true ||
                    context.auth.token.role === "admin";
    if (!isAdmin) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Admin access required"
      );
    }

    const dryRun = data?.dryRun !== false; // Default to dry-run
    const filterCollection = data?.collection;
    const db = getDb();
    const result: MigrationResult = {
      success: true,
      dryRun,
      collections: {},
    };

    functions.logger.info(
      `Legacy migration started by admin ${hashUid(context.auth.uid)} (dryRun=${dryRun})`
    );

    const mappings = filterCollection
      ? LEGACY_MAPPINGS.filter(m => m.from === filterCollection)
      : LEGACY_MAPPINGS;

    for (const { from, to } of mappings) {
      const stats = { found: 0, alreadyExists: 0, migrated: 0, errors: 0 };

      try {
        const sourceSnapshot = await db.collection(from).get();
        stats.found = sourceSnapshot.size;

        if (sourceSnapshot.empty) {
          functions.logger.info(`Collection "${from}": empty, skipping`);
          result.collections[from] = stats;
          continue;
        }

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

        functions.logger.info(
          `Collection "${from}" → "${to}": ${stats.found} found, ${stats.alreadyExists} already exist, ${stats.migrated} ${dryRun ? "would migrate" : "migrated"}`
        );
      } catch (error) {
        stats.errors++;
        result.success = false;
        functions.logger.error(`Error migrating "${from}": ${error}`);
      }

      result.collections[from] = stats;
    }

    return result;
  }
);
