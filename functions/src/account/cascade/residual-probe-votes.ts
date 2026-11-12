import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { Collections } from "../../shared/collections";
import { liveMenuBallotRows } from "./realtime";

export async function probePollVotes(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<number> {
  let residual = 0;
  // BUT-1801: poll VOTES. `deletePollVotes` deletes through `batchDeleteAll` →
  // `commitInChunks(strict:false)`, which catches a whole failed chunk and still
  // lets the step report success; only the CAP can falsify it. So a single
  // failed commit can leave up to 500 rows whose DOCUMENT ID is the erased uid, claim-lint:ok moved unchanged, BUT-2113
  // with the step reporting a clean erasure. This leg is the only thing that claim-lint:ok moved unchanged, BUT-2113
  // contradicts it. Uncapped: `count()` is cheap, and it must stay loud exactly when the deleter
  // DECLINED. It also fails CLOSED while the collection-group index builds —
  // FAILED_PRECONDITION lands in the catch as a false alarm, never a false
  // all-clear.
  try {
    const snap = await db
      .collectionGroup(Collections.pollVotes)
      .where("voterId", "==", uid)
      .count()
      .get();
    const count = snap.data().count ?? 0;
    if (count > 0) {
      residual += count;
      logger.warn("[deletion-cascade] residual poll votes", {
        uid_prefix: uid.slice(0, 6),
        count,
      });
    }
  } catch (err) {
    residual += 1;
    logger.error("[deletion-cascade] residual probe failed: poll_votes", {
      uid_prefix: uid.slice(0, 6),
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
  }
  return residual;
}

export async function probeLiveMenuBallots(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<number> {
  let residual = 0;
  // BUT-2118: live-menu ballots. `deleteLiveMenuVotes` declines above its cap
  // and reports the step incomplete; this leg stays loud in that case and
  // while the collection-group index builds (FAILED_PRECONDITION lands in the
  // catch). It reads the deleter's own rows, so a `votes` document under
  // another parent is never counted.
  try {
    const rows = await liveMenuBallotRows(db, uid);
    const count = rows === null ? 1 : rows.length;
    if (count > 0) {
      residual += count;
      logger.warn("[deletion-cascade] residual live-menu ballots", {
        uid_prefix: uid.slice(0, 6),
        count,
      });
    }
  } catch (err) {
    residual += 1;
    logger.error("[deletion-cascade] residual probe failed: votes", {
      uid_prefix: uid.slice(0, 6),
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
  }
  return residual;
}
