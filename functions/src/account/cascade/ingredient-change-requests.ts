import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { commitInChunks } from "../../shared/batch-update";
import { Collections } from "../../shared/collections";
import { hashUid } from "../../shared/hash-uid";
import { stageCascadeAuditEntry } from "../../cleanup/cascade-audit-log";

/** The fields of an admin ingredient proposal that hold an admin's uid. */
export const PROPOSAL_UID_FIELDS = ["createdBy", "withdrawnBy"] as const;

// Two ops per proposal (the update and its audit row), so one page is one batch.
export const PROPOSAL_SCRUB_PAGE = 250;

/**
 * Nulls [uid] wherever it is `createdBy` or `withdrawnBy` on an admin
 * ingredient proposal. The proposal itself is kept: its content is curation
 * history about an ingredient, not the admin's data (Malin, 2026-11-02).
 *
 * Shared by the account cascade and `onUserDeleted`, so an admin account
 * deleted outside the app is covered too.
 *
 * Never throws, so the trigger's later steps still run. Returns false when a
 * proposal still names [uid] afterwards, asked of the store; a re-run picks up
 * what is left, since every scrubbed proposal drops out of both queries.
 */
export async function scrubIngredientChangeRequestAuthors(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const col = db.collection(Collections.ingredientChangeRequests);
  try {
    for (const field of PROPOSAL_UID_FIELDS) {
      let previous: Set<string> | null = null;
      for (;;) {
        const snap = await col
          .where(field, "==", uid)
          .limit(PROPOSAL_SCRUB_PAGE)
          .get();
        if (snap.empty) break;
        const paths = new Set(snap.docs.map((d) => d.ref.path));
        const prior: Set<string> | null = previous;
        // A failed chunk brings the same page back. A proposal the TTL deleted
        // meanwhile is missing from it, so a smaller page is progress.
        if (
          prior !== null &&
          paths.size === prior.size &&
          [...paths].every((p) => prior.has(p))
        ) {
          logger.error(
            "[ingredient-change-requests] page did not shrink; stopping",
            { uid_hash: hashUid(uid), field, rows: snap.size },
          );
          break;
        }
        previous = paths;
        await commitInChunks(
          db,
          snap.docs,
          (batch, doc) => {
            const cleared = PROPOSAL_UID_FIELDS.filter(
              (f) => doc.get(f) === uid,
            );
            batch.update(
              doc.ref,
              Object.fromEntries(cleared.map((f) => [f, null])),
            );
            stageCascadeAuditEntry(db, batch, {
              subjectUserId: uid,
              targetUid: null,
              operation: "cascade_anonymize",
              resourceType: Collections.ingredientChangeRequests,
              resourceId: doc.id,
              extra: { fields: cleared },
            });
          },
          { label: "ingredient change request authors", opsPerItem: 2 },
        );
      }
    }
    const rest = await Promise.all(
      PROPOSAL_UID_FIELDS.map((f) => col.where(f, "==", uid).limit(1).get()),
    );
    return rest.every((s) => s.empty);
  } catch (err) {
    logger.error("[ingredient-change-requests] scrub failed", {
      uid_hash: hashUid(uid),
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
    return false;
  }
}
