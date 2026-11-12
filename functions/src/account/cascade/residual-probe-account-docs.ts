import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { Collections } from "../../shared/collections";
// P6-U09: the two-step-verification collections. Imported rather than
// retyped so the cascade and the writer cannot disagree about a name or about
// the shape of the per-account counter key.
import {
  BACKUP_CODES_COLLECTION,
  RECOVERY_ATTEMPTS_COLLECTION,
  uidAttemptKey,
} from "../mfa-backup-codes";

export async function probeUidKeyedAccountDocs(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<number> {
  let residual = 0;
  // P6-U09: the two documents `deleteMfaRecoveryData` removes. Both are keyed
  // by the uid itself and carry no uid field, so neither the `probes` list
  // nor the field-filter loop can see them; an existence read is the leg.
  // BUT-920: `guest_quotas/{uid}` (`deleteGuestQuota`) is keyed the same way.
  for (const [col, id] of [
    [BACKUP_CODES_COLLECTION, uid],
    [RECOVERY_ATTEMPTS_COLLECTION, uidAttemptKey(uid)],
    [Collections.guestQuotas, uid],
  ] as const) {
    try {
      const snap = await db.collection(col).doc(id).get();
      if (snap.exists) {
        residual += 1;
        logger.warn(`[deletion-cascade] residual in ${col}`, {
          uid_prefix: uid.slice(0, 6),
        });
      }
    } catch (err) {
      residual += 1;
      logger.error(`[deletion-cascade] residual probe failed: ${col}`, {
        uid_prefix: uid.slice(0, 6),
        errCode: (err as { code?: number | string }).code ?? null,
        errName: err instanceof Error ? err.name : typeof err,
      });
    }
  }
  return residual;
}
