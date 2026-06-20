/**
 * MT-4: Correction-Driven Improvement Loop
 *
 * Analyzes user corrections to parsed recipes, learns ingredient aliases,
 * and aggregates domain/tier statistics.
 *
 * When 3+ distinct users correct the same ingredient name → the same known
 * ingredient, the alias is auto-approved and written to the ingredient doc.
 *
 * Firestore collections:
 * - analytics/ingredients/learned_aliases/{normalizedOriginal} — alias candidates
 * - analytics/parsing/corrections/{domain} — domain/tier stats
 * - ingredients/{id}.learnedAliasesSv — approved learned aliases
 */

import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onCall, CallableRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { stripDiacritics } from "../shared/swedish-normalize";
import { requireAdmin } from "../shared/require-admin";
import { clampLimit } from "../shared/validate-limit";

const getDb = () => admin.firestore();

/** Minimum distinct users before an alias is auto-approved. */
const ALIAS_APPROVAL_THRESHOLD = 3;

/**
 * Normalize ingredient name for consistent deduplication.
 * Matches Dart-side normalization in FirebaseIngredientRepository._normalize.
 */
function normalizeIngredientName(name: string): string {
  return stripDiacritics(name.toLowerCase().trim());
}

/**
 * Normalize name for use as Firestore document ID (no special chars).
 */
function normalizeForDocId(name: string): string {
  return normalizeIngredientName(name)
    .replace(/[^a-z0-9]/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "");
}

/**
 * Look up an ingredient by its Swedish name or alias.
 * Returns the ingredient doc ID if found, null otherwise.
 */
async function findIngredientByName(
  db: admin.firestore.Firestore,
  name: string
): Promise<{ id: string; docId: string } | null> {
  const normalized = normalizeIngredientName(name);
  if (!normalized) return null;

  // Try exact Swedish name match
  const bySwedish = await db
    .collection("ingredients")
    .where("swedish", "==", name)
    .limit(1)
    .get();

  if (!bySwedish.empty) {
    return { id: bySwedish.docs[0].id, docId: bySwedish.docs[0].id };
  }

  // Try lowercase Swedish name match
  const bySwedishLower = await db
    .collection("ingredients")
    .where("swedish", "==", name.toLowerCase().trim())
    .limit(1)
    .get();

  if (!bySwedishLower.empty) {
    return { id: bySwedishLower.docs[0].id, docId: bySwedishLower.docs[0].id };
  }

  // Try alias match — check all ingredients for alias containment
  // (Firestore array-contains works for exact match within aliasesSv)
  const byAlias = await db
    .collection("ingredients")
    .where("aliasesSv", "array-contains", name.toLowerCase().trim())
    .limit(1)
    .get();

  if (!byAlias.empty) {
    return { id: byAlias.docs[0].id, docId: byAlias.docs[0].id };
  }

  // Also check learnedAliasesSv
  const byLearnedAlias = await db
    .collection("ingredients")
    .where("learnedAliasesSv", "array-contains", name.toLowerCase().trim())
    .limit(1)
    .get();

  if (!byLearnedAlias.empty) {
    return {
      id: byLearnedAlias.docs[0].id,
      docId: byLearnedAlias.docs[0].id,
    };
  }

  return null;
}

/**
 * Trigger: When a new correction document is created.
 *
 * Path: parsing_corrections/{correctionId}
 * Event: onCreate
 */
export const analyzeCorrections = onDocumentCreated(
  "parsing_corrections/{correctionId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const userId = data.userId as string | undefined;
    const domain = data.domain as string | undefined;
    const successfulTier = data.successfulTier as string | undefined;
    const ingredientCorrections =
      (data.ingredientCorrections as Array<Record<string, unknown>>) || [];
    const titleCorrection = data.titleCorrection;
    const portionsCorrection = data.portionsCorrection;
    const timeCorrection = data.timeCorrection;
    const instructionCorrections = data.instructionCorrections || [];

    try {
      const db = getDb();

      // --- Aggregate domain/tier stats ---
      await aggregateDomainStats(db, {
        domain: domain || "unknown",
        successfulTier: successfulTier || "unknown",
        titleCorrection: !!titleCorrection,
        portionsCorrection: !!portionsCorrection,
        timeCorrection: !!timeCorrection,
        ingredientCorrectionCount: ingredientCorrections.length,
        instructionCorrectionCount: Array.isArray(instructionCorrections)
          ? instructionCorrections.length
          : 0,
      });

      // --- Process ingredient name corrections for alias learning ---
      if (!userId) {
        logger.warn("Correction missing userId, skipping alias learning");
        return;
      }

      for (const correction of ingredientCorrections) {
        if (!correction.nameChanged) continue;

        const originalName = correction.originalName as string | undefined;
        const correctedName = correction.correctedName as string | undefined;

        if (!originalName || !correctedName) continue;

        // Skip if names are the same after normalization
        const normOriginal = normalizeIngredientName(originalName);
        const normCorrected = normalizeIngredientName(correctedName);
        if (normOriginal === normCorrected) continue;

        await processAliasCandidate(db, {
          originalName,
          correctedName,
          userId,
        });
      }
    } catch (error) {
      // Never throw on analytics — log and return
      logger.error("Failed to analyze corrections:", error);
    }
  }
);

/**
 * Aggregate correction stats by domain and tier.
 */
async function aggregateDomainStats(
  db: admin.firestore.Firestore,
  params: {
    domain: string;
    successfulTier: string;
    titleCorrection: boolean;
    portionsCorrection: boolean;
    timeCorrection: boolean;
    ingredientCorrectionCount: number;
    instructionCorrectionCount: number;
  }
): Promise<void> {
  const docRef = db
    .collection("analytics")
    .doc("parsing")
    .collection("corrections")
    .doc(params.domain);

  await docRef.set(
    {
      domain: params.domain,
      totalCorrections: admin.firestore.FieldValue.increment(1),
      titleCorrections: admin.firestore.FieldValue.increment(
        params.titleCorrection ? 1 : 0
      ),
      ingredientCorrections: admin.firestore.FieldValue.increment(
        params.ingredientCorrectionCount
      ),
      instructionCorrections: admin.firestore.FieldValue.increment(
        params.instructionCorrectionCount
      ),
      portionCorrections: admin.firestore.FieldValue.increment(
        params.portionsCorrection ? 1 : 0
      ),
      timeCorrections: admin.firestore.FieldValue.increment(
        params.timeCorrection ? 1 : 0
      ),
      lastCorrectionAt: admin.firestore.FieldValue.serverTimestamp(),
      [`tierBreakdown.${params.successfulTier}`]:
        admin.firestore.FieldValue.increment(1),
    },
    { merge: true }
  );
}

/**
 * Process a single alias candidate: track it and auto-approve if threshold met.
 */
async function processAliasCandidate(
  db: admin.firestore.Firestore,
  params: {
    originalName: string;
    correctedName: string;
    userId: string;
  }
): Promise<void> {
  // Corrected name must map to a known ingredient (anti-poisoning)
  const ingredient = await findIngredientByName(db, params.correctedName);
  if (!ingredient) {
    logger.debug(
      `Corrected name "${params.correctedName}" not found in ingredients, skipping`
    );
    return;
  }

  const docId = normalizeForDocId(params.originalName);
  if (!docId) return;

  const aliasRef = db.collection("analytics").doc("ingredients").collection("learned_aliases").doc(docId);

  // Use transaction to atomically update, check threshold, and approve
  // to prevent race condition where concurrent calls double-approve
  await db.runTransaction(async (tx) => {
    const doc = await tx.get(aliasRef);
    const docData = doc.data();

    if (doc.exists && docData) {
      // Update existing alias candidate
      tx.update(aliasRef, {
        userIds: admin.firestore.FieldValue.arrayUnion(params.userId),
        count: admin.firestore.FieldValue.increment(1),
        lastSeen: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Check if threshold is met for auto-approval
      if (docData.status !== "approved") {
        const userIds = (docData.userIds as string[]) || [];
        // +1 because arrayUnion hasn't committed yet — check if adding this user reaches threshold
        const uniqueUsers = new Set([...userIds, params.userId]);
        if (uniqueUsers.size >= ALIAS_APPROVAL_THRESHOLD) {
          tx.update(aliasRef, { status: "approved" });

          const ingredientRef = db
            .collection("ingredients")
            .doc(ingredient!.id);
          tx.update(ingredientRef, {
            learnedAliasesSv: admin.firestore.FieldValue.arrayUnion(
              params.originalName.toLowerCase().trim()
            ),
          });

          logger.info(
            `Auto-approved alias: "${params.originalName}" → ` +
              `"${params.correctedName}" (ingredient: ${ingredient!.id}, ` +
              `${uniqueUsers.size} distinct users)`
          );
        }
      }
    } else {
      // Create new alias candidate
      tx.set(aliasRef, {
        originalName: params.originalName.toLowerCase().trim(),
        correctedName: params.correctedName.toLowerCase().trim(),
        ingredientId: ingredient!.id,
        userIds: [params.userId],
        count: 1,
        firstSeen: admin.firestore.FieldValue.serverTimestamp(),
        lastSeen: admin.firestore.FieldValue.serverTimestamp(),
        status: "pending",
      });
    }
  });
}

/**
 * Callable admin function: get correction stats and pending alias candidates.
 */
export const getCorrectionStats = onCall(
  async (request: CallableRequest) => {
    requireAdmin(request);

    const db = getDb();
    const limit = clampLimit(request.data?.limit);

    // Get domain stats
    const domainsSnapshot = await db
      .collection("analytics")
      .doc("parsing")
      .collection("corrections")
      .orderBy("totalCorrections", "desc")
      .limit(limit)
      .get();

    const domains = domainsSnapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    // Get pending alias candidates
    const pendingSnapshot = await db
      .collection("analytics").doc("ingredients").collection("learned_aliases")
      .where("status", "==", "pending")
      .orderBy("count", "desc")
      .limit(limit)
      .get();

    const pendingAliases = pendingSnapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    // Get approved aliases
    const approvedSnapshot = await db
      .collection("analytics").doc("ingredients").collection("learned_aliases")
      .where("status", "==", "approved")
      .orderBy("count", "desc")
      .limit(limit)
      .get();

    const approvedAliases = approvedSnapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    return {
      domains,
      pendingAliases,
      approvedAliases,
    };
  }
);

/**
 * GDPR: Remove userId from all learned alias documents on account deletion.
 *
 * Called from the existing GDPR deletion cascade.
 */
export async function cleanUserFromLearnedAliases(
  userId: string
): Promise<void> {
  const db = getDb();

  const snapshot = await db
    .collection("analytics").doc("ingredients").collection("learned_aliases")
    .where("userIds", "array-contains", userId)
    .get();

  if (snapshot.empty) return;

  const batch = db.batch();

  for (const doc of snapshot.docs) {
    batch.update(doc.ref, {
      userIds: admin.firestore.FieldValue.arrayRemove(userId),
      count: admin.firestore.FieldValue.increment(-1),
    });
  }

  await batch.commit();

  logger.info(
    `GDPR: Cleaned userId ${userId} from ${snapshot.size} learned alias documents`
  );
}
