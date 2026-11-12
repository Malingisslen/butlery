import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { Collections } from "../../shared/collections";

export async function probeConversationRoster(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<number> {
  let residual = 0;
  // BUT-1822: the conversation roster rows. A SUBCOLLECTION, so neither the
  // top-level loops at the head of this function nor the `users/{uid}/...` loop
  // can express it — only a collection-group query can, and the loops above are
  // all `db.collection(...)`. Same handle `deleteOwnRosterRows` uses, keeping the
  // deleter a strict superset of the probe. Appended rather than folded into an
  // existing `try`, for the reason the blocks above state.
  //
  // Uncapped on purpose, unlike the deleter: `count()` is cheap, and this is the
  // leg that must stay loud when the deleter DECLINES an implausible row count.
  // It also fails CLOSED while the collection-group index is still building —
  // FAILED_PRECONDITION lands in the catch as `residual += 1`, a false alarm
  // rather than a false all-clear. Do not "simplify" that into a silent swallow.
  try {
    const snap = await db
      .collectionGroup(Collections.participants)
      .where("participantId", "==", uid)
      .count()
      .get();
    const count = snap.data().count ?? 0;
    if (count > 0) {
      residual += count;
      logger.warn("[deletion-cascade] residual conversation roster rows", {
        uid_prefix: uid.slice(0, 6),
        count,
      });
    }
  } catch (err) {
    residual += 1;
    logger.error(
      "[deletion-cascade] residual probe failed: conversation participants",
      {
        uid_prefix: uid.slice(0, 6),
        errCode: (err as { code?: number | string }).code ?? null,
        errName: err instanceof Error ? err.name : typeof err,
      },
    );
  }
  return residual;
}
