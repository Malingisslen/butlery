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
import { commitInChunks } from "../shared/batch-update";
import { hashUid } from "../shared/hash-uid";
import { ALLERGEN_RELEVANT_PROPERTIES } from "../shared/allergen-properties";

const getDb = () => admin.firestore();

/** Minimum distinct users before an alias is auto-approved. */
const ALIAS_APPROVAL_THRESHOLD = 3;

/**
 * BUT-1468: corrections only count toward the alias quorum when the account
 * has existed for at least this long — mirrors the client/rules maturity
 * window (`kAccountMaturityWindow` / `isAccountMatured()` on
 * `users/{uid}.createdAt`). Stops 3 same-session throwaway accounts from
 * reaching quorum instantly; the decided 3-user threshold is unchanged.
 */
const ACCOUNT_MATURITY_MS = 60 * 60 * 1000;

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
 * Look up an ingredient by its DIACRITICS-STRIPPED name/alias form
 * (`normalizedNames`, stamped by the sync). Used only by the allergen-word
 * hold gate: the client matches learned aliases diacritics-stripped, so an
 * attacker submitting "jordnotter" (no umlaut) must still resolve to the real
 * "jordnötter" ingredient here or the gate is trivially bypassed (BUT-1468,
 * HIGH finding from the xhigh review). Falls back to the diacritic-form
 * lookup for docs the backfill sync hasn't stamped yet (fail toward review).
 */
async function findIngredientByNormalizedName(
  db: admin.firestore.Firestore,
  name: string
): Promise<{ id: string } | null> {
  const normalized = normalizeIngredientName(name);
  if (!normalized) return null;

  const byNormalized = await db
    .collection("ingredients")
    .where("normalizedNames", "array-contains", normalized)
    .limit(1)
    .get();
  if (!byNormalized.empty) {
    return { id: byNormalized.docs[0].id };
  }

  // Pre-backfill fallback: exact-form lookup still catches un-normalized attacks.
  return findIngredientByName(db, name);
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
    await processCorrectionEvent(getDb(), data);
  }
);

/**
 * Handler body, exported so the emulator integration test can drive the
 * 3-user quorum + hold-for-review paths without the Functions runtime.
 */
export async function processCorrectionEvent(
  db: admin.firestore.Firestore,
  data: Record<string, unknown>
): Promise<void> {
  {
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

      // Maturity gate is per-account, not per-candidate: read the user doc
      // once here rather than N times inside the loop (xhigh review Medium 3).
      // An immature account contributes no votes at all this event.
      if (!(await isMatureAccount(db, userId))) {
        logger.debug(
          `Corrections from immature account ${hashUid(userId)} not counted toward alias quorum`
        );
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
}

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
 * True when the account behind a correction is old enough for its vote to
 * count toward the alias quorum. FAIL CLOSED: a missing users doc, missing
 * createdAt, or read error counts as immature (BUT-1468, Trust & Safety).
 */
async function isMatureAccount(
  db: admin.firestore.Firestore,
  userId: string
): Promise<boolean> {
  try {
    const snap = await db.collection("users").doc(userId).get();
    const createdAt = snap.data()?.createdAt as admin.firestore.Timestamp | undefined;
    if (!createdAt || typeof createdAt.toMillis !== "function") return false;
    return Date.now() - createdAt.toMillis() >= ACCOUNT_MATURITY_MS;
  } catch (error) {
    logger.warn(`Maturity check failed for ${hashUid(userId)}, counting as immature`, error);
    return false;
  }
}

type HoldCheck =
  | { kind: "safe" }
  | { kind: "hold"; reason: "allergen_target" | "allergen_alias_text" }
  | { kind: "retry" };

/**
 * Decides whether an alias auto-approval is safe, must be held for human
 * review, or should be retried on a later vote.
 *
 * Two directions are held (BUT-1468):
 * - allergen_target: the ingredient gaining the alias carries an
 *   allergen/dietary-relevant property → a wrong alias creates false
 *   CONTAINS (or, worse, diverts a word away from a true CONTAINS).
 * - allergen_alias_text: the alias text itself is a known name/alias of an
 *   allergen-bearing ingredient → a coordinated correction could redirect a
 *   real allergen word (e.g. "jordnötter") onto a harmless ingredient,
 *   producing false FREE verdicts.
 *
 * A transient read error returns `retry` (not a hold): the candidate stays
 * pending so the NEXT vote re-runs the check — a one-off Firestore hiccup
 * must not permanently strand a harmless alias in the admin queue. It still
 * fails closed for the current event (no auto-write happens on `retry`).
 */
async function determineHoldReason(
  db: admin.firestore.Firestore,
  targetIngredientId: string,
  originalName: string
): Promise<HoldCheck> {
  try {
    const targetSnap = await db.collection("ingredients").doc(targetIngredientId).get();
    const targetProps = (targetSnap.data()?.properties as string[]) || [];
    if (targetProps.some((p) => ALLERGEN_RELEVANT_PROPERTIES.has(p))) {
      return { kind: "hold", reason: "allergen_target" };
    }

    const aliasTextMatch = await findIngredientByNormalizedName(db, originalName);
    if (aliasTextMatch) {
      const matchSnap = await db.collection("ingredients").doc(aliasTextMatch.id).get();
      const matchProps = (matchSnap.data()?.properties as string[]) || [];
      if (matchProps.some((p) => ALLERGEN_RELEVANT_PROPERTIES.has(p))) {
        return { kind: "hold", reason: "allergen_alias_text" };
      }
    }

    return { kind: "safe" };
  } catch (error) {
    logger.warn(
      `Allergen hold-check failed for "${originalName}" → ${targetIngredientId}; will retry on next vote`,
      error
    );
    return { kind: "retry" };
  }
}

/**
 * Process a single alias candidate: track it and auto-approve if threshold met.
 * Allergen-relevant candidates are held for human review instead of
 * auto-writing the live ingredient doc (BUT-1468).
 *
 * The candidate doc is keyed by (normalized original name + target ingredient
 * id), so the 3-user quorum is per *mapping*: three users who correct the same
 * misspelling to three DIFFERENT ingredients never form a consensus, and the
 * doc's `ingredientId` can never diverge from what the votes agreed on — the
 * admin approve/revoke path therefore always acts on the right ingredient.
 */
async function processAliasCandidate(
  db: admin.firestore.Firestore,
  params: {
    originalName: string;
    correctedName: string;
    userId: string;
  }
): Promise<void> {
  // Corrected name must map to a known ingredient (anti-poisoning).
  // Account maturity is already gated once per event by the caller.
  const ingredient = await findIngredientByName(db, params.correctedName);
  if (!ingredient) {
    logger.debug(
      `Corrected name "${params.correctedName}" not found in ingredients, skipping`
    );
    return;
  }

  const nameKey = normalizeForDocId(params.originalName);
  if (!nameKey) return;
  // Per-mapping key: same misspelling + same target ⇒ same candidate.
  const docId = `${nameKey}__${ingredient.id}`;
  // Canonical alias string, written once at create and reused verbatim by
  // both auto-approve and admin revoke so the two can never disagree.
  const canonicalAlias = params.originalName.toLowerCase().trim();

  // Determined OUTSIDE the transaction (it needs queries); consumed at the
  // threshold moment inside it.
  const holdCheck = await determineHoldReason(db, ingredient.id, params.originalName);

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

      // Only pending candidates auto-advance. approved is done; held waits
      // for the admin queue; rejected/revoked are human decisions.
      if (docData.status === "pending") {
        const userIds = (docData.userIds as string[]) || [];
        // +1 because arrayUnion hasn't committed yet — check if adding this user reaches threshold
        const uniqueUsers = new Set([...userIds, params.userId]);
        if (uniqueUsers.size >= ALIAS_APPROVAL_THRESHOLD) {
          if (holdCheck.kind === "retry") {
            // Transient check failure: leave pending, retry on the next vote.
            return;
          }
          const alias = (docData.originalName as string) ?? canonicalAlias;

          if (holdCheck.kind === "hold") {
            // Allergen-relevant: park for human review, do NOT touch the
            // ingredient doc. reviewLearnedAlias (admin) resolves it.
            tx.update(aliasRef, {
              status: "held_for_review",
              heldReason: holdCheck.reason,
              heldAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            logger.info(
              `Held alias for review (${holdCheck.reason}): "${alias}" → ` +
                `ingredient ${ingredient.id}`
            );
            return;
          }

          tx.update(aliasRef, {
            status: "approved",
            approvedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          tx.update(db.collection("ingredients").doc(ingredient.id), {
            learnedAliasesSv: admin.firestore.FieldValue.arrayUnion(alias),
          });

          logger.info(
            `Auto-approved alias: "${alias}" → ingredient ${ingredient.id} ` +
              `(${uniqueUsers.size} distinct users)`
          );
        }
      }
    } else {
      // Create new alias candidate
      tx.set(aliasRef, {
        originalName: canonicalAlias,
        correctedName: params.correctedName.toLowerCase().trim(),
        ingredientId: ingredient.id,
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

    // Held-for-review aliases (allergen-relevant, waiting for a human —
    // BUT-1468). Surfaced first in the admin queue.
    const heldSnapshot = await db
      .collection("analytics").doc("ingredients").collection("learned_aliases")
      .where("status", "==", "held_for_review")
      .orderBy("count", "desc")
      .limit(limit)
      .get();

    const heldAliases = heldSnapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    return {
      domains,
      pendingAliases,
      approvedAliases,
      heldAliases,
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

  // Chunk the writes at the 500-op Firestore batch limit. A prolific corrector
  // can touch more than 500 alias candidates; a single flat batch.commit()
  // would throw past 500 ops and — because the GDPR cascade caller swallows
  // the error — leave the user's data partially un-erased (Art. 17 gap).
  // arrayRemove/decrement are idempotent, so a retry is safe.
  const cleaned = await commitInChunks(
    db,
    snapshot.docs,
    (batch, doc) => {
      batch.update(doc.ref, {
        userIds: admin.firestore.FieldValue.arrayRemove(userId),
        count: admin.firestore.FieldValue.increment(-1),
      });
    },
    { label: "cleanUserFromLearnedAliases" }
  );

  // Never log a raw UID — hash it (see hash-uid / WS10 log-masking sweep).
  logger.info(
    `GDPR: Cleaned user ${hashUid(userId)} from ${cleaned} learned alias documents`
  );
}
