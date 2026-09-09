/**
 * BUT-781's report anonymizer, in its own module.
 *
 * It lived in `cleanup/on-user-deleted.ts` until BUT-2046's legal hold needed
 * it from two directions: the trigger calls it through the hold guard, and
 * `liftErasureHold` calls it directly once the hold is released. With both the
 * guard and the lift in `moderation/erasure-hold.ts`, leaving the anonymizer in
 * the trigger module would close an import cycle — so the thing both sides need
 * moved to where neither owns it.
 */

import * as admin from "firebase-admin";
import { commitInChunks } from "../shared/batch-update";
import { stageCascadeAuditEntry } from "../cleanup/cascade-audit-log";

/**
 * BUT-781: anonymize /reports rows where the deleted user was the reported
 * `contentOwnerId`. The reports themselves are moderation evidence (and the
 * reporter retains read access to their own submissions), so deletion would
 * destroy a record the reporter is GDPR-entitled to access. Anonymizing
 * removes the linked PII (contentOwnerId → null, plus a `contentOwnerAnonymizedAt`
 * tombstone for audit) while keeping the rest of the row intact.
 *
 * BEST-EFFORT PER CHUNK: a failed batch commit logs a warn and continues, and
 * the return value counts rows MATCHED, not commits that succeeded. That is
 * load-bearing rather than incidental — `liftErasureHold` re-probes `reports`
 * precisely because this function cannot report its own failure, and the
 * deviation entry for the legal hold reasons from the same fact.
 *
 * Takes an injected Firestore so callers can run it against a stub.
 */
export async function anonymizeReportsByContentOwnerWithDb(
  database: admin.firestore.Firestore,
  userId: string
): Promise<number> {
  const snapshot = await database
    .collection("reports")
    .where("contentOwnerId", "==", userId)
    .get();
  if (snapshot.empty) return 0;

  return commitInChunks(
    database,
    snapshot.docs,
    (batch, doc) => {
      batch.update(doc.ref, {
        contentOwnerId: null,
        contentOwnerAnonymizedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      // BUT-886: anonymize cascade — the deleted user's id is being scrubbed
      // from /reports rows authored by other users (reporters). The report
      // itself is moderation evidence retained for the reporter's GDPR
      // access right; targetUid is null since the reporter is not the
      // direct subject of the anonymization.
      stageCascadeAuditEntry(database, batch, {
        subjectUserId: userId,
        targetUid: null,
        operation: "cascade_anonymize",
        resourceType: "reports",
        resourceId: doc.id,
        extra: { field: "contentOwnerId" },
      });
    },
    {
      // Prefix only. `commitInChunks` logs this label on a failed chunk, and a
      // full uid there lands unredactable in Cloud Logging's textPayload —
      // the rule every other log on this path already follows.
      label: `BUT-781: report anonymize for ${userId.slice(0, 6)}`,
      // BUT-886: mutate stages update + audit = 2 ops per item.
      opsPerItem: 2,
    }
  );
}
