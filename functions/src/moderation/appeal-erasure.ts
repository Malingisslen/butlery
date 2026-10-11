/**
 * BUT-2353: an erased appellant's appeals do not outlive their erasure.
 *
 * Every appeal whose `appellantId` is the erased uid goes, in both roles. The
 * account cascade deletes them in its `moderation_appeals` step and probes for
 * any left; `onUserDeleted` deletes them again, for an Auth deletion that never
 * ran the cascade.
 *
 * This runs whether or not a legal hold stands. The hold keeps the evidence of
 * an OPEN case; an appeal exists only on a closed one.
 */

import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { commitInChunks } from "../shared/batch-update";
import { APPELLANT_ID, MODERATION_APPEALS } from "./appeals";

/** The cascade step. STRICT: a failed chunk throws, so the step is reported failed. */
export async function deleteAppealsByAppellant(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<number> {
  const snap = await db
    .collection(MODERATION_APPEALS)
    .where(APPELLANT_ID, "==", uid)
    .get();
  if (snap.empty) return 0;
  return commitInChunks(
    db,
    snap.docs,
    (batch, doc) => {
      batch.delete(doc.ref);
    },
    { label: `BUT-2353: appeals for ${uid.slice(0, 6)}`, opsPerItem: 1, strict: true },
  );
}

/**
 * Never throws: its caller is a gen1 Auth trigger with nothing to retry it,
 * and the steps after it must still run. A failure is logged.
 */
export async function deleteAppealsByAppellantWithDb(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<number> {
  try {
    return await deleteAppealsByAppellant(db, uid);
  } catch (err) {
    logger.error("[appeal-erasure] appeals not deleted", {
      uid_prefix: uid.slice(0, 6),
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
    return 0;
  }
}
