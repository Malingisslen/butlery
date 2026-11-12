import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { USER_MODERATION, REPORT_HISTORY } from "./moderation";

export async function probeModerationRecords(
  db: admin.firestore.Firestore,
  uid: string,
  held: boolean,
): Promise<number> {
  let residual = 0;
  // BUT-2046: the erased uid as a REPORTER, on rows under OTHER people's
  // moderation records, and their OWN moderation record's rows. Two legs
  // because two deleters, per this file's rule that the deleter stays a strict
  // superset of the probe. Both are collection-group / subcollection reads,
  // so neither the `probes` list nor the owner-keyed loop below can serve them.
  //
  // Uncapped on purpose: when a sweep DECLINES above
  // `MAX_REPORT_HISTORY_SWEEP_ROWS` it removes nothing, and this is what says
  // so. The reporter leg uses the same collection-group index the sweep needs,
  // so a missing index lands in the catch as a false alarm, never as a false
  // all-clear.
  try {
    const snap = await db
      .collectionGroup(REPORT_HISTORY)
      .where("reporterId", "==", uid)
      .count()
      .get();
    const count = snap.data().count ?? 0;
    if (count > 0) {
      residual += count;
      logger.warn("[deletion-cascade] residual report rows as reporter", {
        uid_prefix: uid.slice(0, 6),
        count,
      });
    }
  } catch (err) {
    residual += 1;
    logger.error("[deletion-cascade] residual probe failed: report_history", {
      uid_prefix: uid.slice(0, 6),
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
  }
  // Skipped under a hold: the held person's OWN rows. The reporter leg above
  // is NOT skipped — see the note on `held`.
  if (!held) try {
    const snap = await db
      .collection(USER_MODERATION)
      .doc(uid)
      .collection(REPORT_HISTORY)
      .count()
      .get();
    const count = snap.data().count ?? 0;
    if (count > 0) {
      residual += count;
      logger.warn("[deletion-cascade] residual own moderation rows", {
        uid_prefix: uid.slice(0, 6),
        count,
      });
    }
  } catch (err) {
    residual += 1;
    logger.error("[deletion-cascade] residual probe failed: user_moderation", {
      uid_prefix: uid.slice(0, 6),
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
  }
  // The PARENT document, whose id is the erased uid and which holds
  // `totalReports`/`lastReportedAt`. The leg above counts its rows; without
  // this one a parent standing with no rows beneath it reads as clean.
  //
  // Skipped under a hold.
  if (!held) try {
    const snap = await db.collection(USER_MODERATION).doc(uid).get();
    if (snap.exists) {
      residual += 1;
      logger.warn("[deletion-cascade] residual moderation record", {
        uid_prefix: uid.slice(0, 6),
      });
    }
  } catch (err) {
    residual += 1;
    logger.error(
      "[deletion-cascade] residual probe failed: user_moderation parent",
      {
        uid_prefix: uid.slice(0, 6),
        errCode: (err as { code?: number | string }).code ?? null,
        errName: err instanceof Error ? err.name : typeof err,
      },
    );
  }
  return residual;
}
