import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { commitInChunks } from "../../shared/batch-update";
import { Collections } from "../../shared/collections";
import { hashUid } from "../../shared/hash-uid";
import { stageCascadeAuditEntry } from "../../cleanup/cascade-audit-log";

/** The fields of an admin ingredient proposal that hold an admin's uid. */
export const PROPOSAL_UID_FIELDS = ["createdBy", "withdrawnBy"] as const;

// Two ops per document (the update and its audit row), so one page is one batch.
export const PROPOSAL_SCRUB_PAGE = 250;

/** The run records' field, which holds `hashUid` of the admin who ran it. */
export const RUN_UID_HASH_FIELD = "adminUidHash";

interface Leg {
  collection: string;
  field: string;
  value: string;
  // The fields this doc holds [value] in, to null.
  cleared: (doc: admin.firestore.QueryDocumentSnapshot) => string[];
}

/**
 * Nulls [uid] wherever it is `createdBy` or `withdrawnBy` on an admin
 * ingredient proposal, and its hash where it is `adminUidHash` on a
 * `createIngredientChangePr` run record. Both are kept: their content is
 * curation history about ingredients, not the admin's data (Malin,
 * 2026-11-02, for the proposals).
 *
 * Shared by the account cascade and `onUserDeleted`, so an admin account
 * deleted outside the app is covered too.
 *
 * Never throws, so the trigger's later steps still run. Returns false when a
 * document still names [uid] afterwards, asked of the store; a re-run picks
 * up what is left, since every scrubbed document drops out of its query.
 */
export async function scrubIngredientChangeRequestAuthors(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const uidHash = hashUid(uid);
  const legs: Leg[] = [
    ...PROPOSAL_UID_FIELDS.map((field) => ({
      collection: Collections.ingredientChangeRequests,
      field,
      value: uid,
      cleared: (doc: admin.firestore.QueryDocumentSnapshot) =>
        PROPOSAL_UID_FIELDS.filter((f) => doc.get(f) === uid),
    })),
    {
      collection: Collections.ingredientChangeRuns,
      field: RUN_UID_HASH_FIELD,
      value: uidHash,
      cleared: () => [RUN_UID_HASH_FIELD],
    },
  ];
  try {
    for (const leg of legs) {
      const col = db.collection(leg.collection);
      let previous: Set<string> | null = null;
      for (;;) {
        const snap = await col
          .where(leg.field, "==", leg.value)
          .limit(PROPOSAL_SCRUB_PAGE)
          .get();
        if (snap.empty) break;
        const paths = new Set(snap.docs.map((d) => d.ref.path));
        const prior: Set<string> | null = previous;
        // A failed chunk brings the same page back. A document the TTL deleted
        // meanwhile is missing from it, so a smaller page is progress.
        if (
          prior !== null &&
          paths.size === prior.size &&
          [...paths].every((p) => prior.has(p))
        ) {
          logger.error(
            "[ingredient-change-requests] page did not shrink; stopping",
            { uid_hash: uidHash, collection: leg.collection, field: leg.field, rows: snap.size },
          );
          break;
        }
        previous = paths;
        await commitInChunks(
          db,
          snap.docs,
          (batch, doc) => {
            const cleared = leg.cleared(doc);
            batch.update(
              doc.ref,
              Object.fromEntries(cleared.map((f) => [f, null])),
            );
            stageCascadeAuditEntry(db, batch, {
              subjectUserId: uid,
              targetUid: null,
              operation: "cascade_anonymize",
              resourceType: leg.collection,
              resourceId: doc.id,
              extra: { fields: cleared },
            });
          },
          { label: `${leg.collection} authors`, opsPerItem: 2 },
        );
      }
    }
    const rest = await Promise.all(
      legs.map((leg) => db.collection(leg.collection).where(leg.field, "==", leg.value).limit(1).get()),
    );
    return rest.every((s) => s.empty);
  } catch (err) {
    logger.error("[ingredient-change-requests] scrub failed", {
      uid_hash: uidHash,
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
    return false;
  }
}
