/**
 * BUT-1468: human review + revoke for auto-learned ingredient aliases.
 *
 * analyze-corrections.ts parks allergen-relevant alias candidates as
 * status=held_for_review instead of auto-writing the live ingredient doc.
 * These admin callables resolve the queue:
 *
 * - reviewLearnedAlias({aliasDocId, decision: "approve"|"reject"})
 * - revokeLearnedAlias({aliasDocId}) — undo for an already-approved alias
 *
 * Every decision writes an audit_logs row (same schema as the cascade audit,
 * cascade-audit-log.ts) IN THE SAME TRANSACTION as the mutation, so the
 * audit trail exists iff the change committed — allergen data changes must
 * be reconstructable after an incident.
 *
 * The pure `performAliasReview` / `performAliasRevoke` functions are exported
 * for the emulator integration test; the callables are thin wrappers adding
 * requireAdmin.
 */

import { onCall, CallableRequest, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { requireAdmin } from "../shared/require-admin";
import { hashUid } from "../shared/hash-uid";

const ALIAS_COLLECTION = ["analytics", "ingredients", "learned_aliases"] as const;

function aliasRef(
  db: admin.firestore.Firestore,
  aliasDocId: string
): admin.firestore.DocumentReference {
  return db
    .collection(ALIAS_COLLECTION[0])
    .doc(ALIAS_COLLECTION[1])
    .collection(ALIAS_COLLECTION[2])
    .doc(aliasDocId);
}

function stageAuditRow(
  db: admin.firestore.Firestore,
  tx: admin.firestore.Transaction,
  params: {
    adminUid: string;
    operation: "alias_approve" | "alias_reject" | "alias_revoke";
    aliasDocId: string;
    ingredientId: string;
    alias: string;
  }
): void {
  const ref = db.collection("audit_logs").doc();
  // audit_logs stores the raw actor uid (matches cascade-audit-log.ts and the
  // rest of the collection) so a forensic "everything admin X did" query works.
  // The collection is admin-only-readable + server-written; the GDPR
  // log-masking rule (hashUid) applies to Cloud Logging, not to this trail.
  tx.set(ref, {
    userId: params.adminUid,
    operation: params.operation,
    resourceType: "learned_aliases",
    resourceId: params.aliasDocId,
    granted: true,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    metadata: {
      actor: "admin",
      ingredientId: params.ingredientId,
      alias: params.alias,
      reason: "but-1468_alias_review",
    },
  });
}

/**
 * Approve or reject a held/pending alias candidate. Approve writes the alias
 * onto the live ingredient doc — the human gate the auto-loop lacks for
 * allergen-relevant targets. Idempotent: re-approving an approved alias or
 * re-rejecting a rejected one is a no-op returning the current status.
 */
export async function performAliasReview(
  db: admin.firestore.Firestore,
  params: { aliasDocId: string; decision: "approve" | "reject"; adminUid: string }
): Promise<{ status: string }> {
  return db.runTransaction(async (tx) => {
    const ref = aliasRef(db, params.aliasDocId);
    const snap = await tx.get(ref);
    if (!snap.exists) {
      throw new HttpsError("not-found", `Alias candidate ${params.aliasDocId} not found`);
    }
    const data = snap.data()!;
    const currentStatus = data.status as string;
    const targetStatus = params.decision === "approve" ? "approved" : "rejected";

    if (currentStatus === targetStatus) {
      return { status: currentStatus }; // idempotent replay
    }
    // approve doubles as the undo for a mistaken reject/revoke — it can run
    // from any non-approved state (re-adds the alias). reject is a review
    // action for candidates that haven't gone live, so only from
    // pending/held_for_review (use revoke to pull an already-approved alias).
    if (params.decision === "reject" && !["pending", "held_for_review"].includes(currentStatus)) {
      throw new HttpsError(
        "failed-precondition",
        `Alias is ${currentStatus}; only pending/held_for_review can be rejected (use revoke for approved)`
      );
    }

    const ingredientId = data.ingredientId as string;
    // The alias string must be the real name, never the dash-normalized docId
    // (which would arrayUnion a bogus token like "pb-krem" as a live alias).
    const alias = data.originalName as string | undefined;
    if (!alias) {
      throw new HttpsError(
        "failed-precondition",
        `Alias candidate ${params.aliasDocId} has no originalName; refusing to write a normalized token`
      );
    }

    if (params.decision === "approve") {
      // Pre-read the ingredient in-txn: a missing doc otherwise throws
      // NOT_FOUND on update() → surfaces to the client as opaque `internal`.
      const ingredientSnap = await tx.get(db.collection("ingredients").doc(ingredientId));
      if (!ingredientSnap.exists) {
        throw new HttpsError(
          "failed-precondition",
          `Ingredient ${ingredientId} no longer exists; cannot approve alias`
        );
      }
      tx.update(db.collection("ingredients").doc(ingredientId), {
        learnedAliasesSv: admin.firestore.FieldValue.arrayUnion(alias),
      });
    }

    tx.update(ref, {
      status: targetStatus,
      reviewedBy: hashUid(params.adminUid),
      reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    stageAuditRow(db, tx, {
      adminUid: params.adminUid,
      operation: params.decision === "approve" ? "alias_approve" : "alias_reject",
      aliasDocId: params.aliasDocId,
      ingredientId,
      alias,
    });

    return { status: targetStatus };
  });
}

/**
 * Revoke an approved alias: removes it from the live ingredient doc and marks
 * the candidate revoked. The undo path for a bad alias that reached
 * production. Idempotent (arrayRemove + repeated status set are safe).
 */
export async function performAliasRevoke(
  db: admin.firestore.Firestore,
  params: { aliasDocId: string; adminUid: string }
): Promise<{ status: string }> {
  return db.runTransaction(async (tx) => {
    const ref = aliasRef(db, params.aliasDocId);
    const snap = await tx.get(ref);
    if (!snap.exists) {
      throw new HttpsError("not-found", `Alias candidate ${params.aliasDocId} not found`);
    }
    const data = snap.data()!;
    const currentStatus = data.status as string;
    if (currentStatus === "revoked") {
      return { status: "revoked" }; // idempotent replay
    }
    // Revoke is the undo for an alias that reached the live ingredient doc.
    // pending/held/rejected candidates were never written there — reject/hold
    // is the right control for those, so refuse to short-circuit the queue.
    if (currentStatus !== "approved") {
      throw new HttpsError(
        "failed-precondition",
        `Alias is ${currentStatus}; only approved aliases can be revoked (use reject for pending/held)`
      );
    }

    const ingredientId = data.ingredientId as string;
    const alias = data.originalName as string | undefined;
    if (!alias) {
      throw new HttpsError(
        "failed-precondition",
        `Alias candidate ${params.aliasDocId} has no originalName`
      );
    }

    // arrayRemove tolerates a since-deleted ingredient doc? No — update() on a
    // missing doc throws NOT_FOUND. Pre-read: if the ingredient is gone the
    // alias is already unreachable, so just mark the candidate revoked.
    const ingredientSnap = await tx.get(db.collection("ingredients").doc(ingredientId));
    if (ingredientSnap.exists) {
      tx.update(db.collection("ingredients").doc(ingredientId), {
        learnedAliasesSv: admin.firestore.FieldValue.arrayRemove(alias),
      });
    }
    tx.update(ref, {
      status: "revoked",
      revokedBy: hashUid(params.adminUid),
      revokedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    stageAuditRow(db, tx, {
      adminUid: params.adminUid,
      operation: "alias_revoke",
      aliasDocId: params.aliasDocId,
      ingredientId,
      alias,
    });

    return { status: "revoked" };
  });
}

export const reviewLearnedAlias = onCall(async (request: CallableRequest) => {
  requireAdmin(request);
  const aliasDocId = request.data?.aliasDocId as string | undefined;
  const decision = request.data?.decision as string | undefined;
  if (!aliasDocId || (decision !== "approve" && decision !== "reject")) {
    throw new HttpsError(
      "invalid-argument",
      "Expected {aliasDocId, decision: 'approve'|'reject'}"
    );
  }
  const result = await performAliasReview(admin.firestore(), {
    aliasDocId,
    decision,
    adminUid: request.auth!.uid,
  });
  logger.info(`Alias ${aliasDocId} reviewed: ${result.status}`);
  return result;
});

export const revokeLearnedAlias = onCall(async (request: CallableRequest) => {
  requireAdmin(request);
  const aliasDocId = request.data?.aliasDocId as string | undefined;
  if (!aliasDocId) {
    throw new HttpsError("invalid-argument", "Expected {aliasDocId}");
  }
  const result = await performAliasRevoke(admin.firestore(), {
    aliasDocId,
    adminUid: request.auth!.uid,
  });
  logger.info(`Alias ${aliasDocId} revoked`);
  return result;
});
