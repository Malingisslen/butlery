import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { Collections } from "../../shared/collections";

export async function probeBlockMirrors(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<number> {
  let residual = 0;
  // BUT-1917: the erased uid inside OTHER people's block mirrors. Same shape as
  // the poll-vote leg above, and for the same reason — `deleteBlockMirrors` is
  // a cross-user sweep, so nothing under `users/{uid}` can see whether it
  // finished. It uses the collection-group index the sweep itself needs, so a
  // missing index shows up here as a false alarm rather than as a false
  // all-clear.
  try {
    const snap = await db
      .collectionGroup(Collections.blockMirror)
      .where("blockedByUserIds", "array-contains", uid)
      .count()
      .get();
    const count = snap.data().count ?? 0;
    if (count > 0) {
      residual += count;
      logger.warn("[deletion-cascade] residual block mirrors", {
        uid_prefix: uid.slice(0, 6),
        count,
      });
    }
  } catch (err) {
    residual += 1;
    logger.error("[deletion-cascade] residual probe failed: block_mirror", {
      uid_prefix: uid.slice(0, 6),
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
  }
  return residual;
}
