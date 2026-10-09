/**
 * BUT-2084: the day's rating-recompute reads, one increment per drain minute
 * that read anything, so a rating storm shows as a number per UTC day at
 * `analytics/rating_reads/daily/{yyyy-mm-dd}.docsRead`. The doc holds a count
 * and nothing that names a person.
 *
 * A failed write is logged and dropped: the counter must never fail the drain
 * it measures.
 */

import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";

export async function recordRatingReads(
  docsRead: number,
  db: admin.firestore.Firestore = admin.firestore(),
  now: Date = new Date()
): Promise<void> {
  if (docsRead <= 0) return;
  try {
    await db
      .collection("analytics")
      .doc("rating_reads")
      .collection("daily")
      .doc(now.toISOString().slice(0, 10))
      .set(
        { docsRead: admin.firestore.FieldValue.increment(docsRead) },
        { merge: true }
      );
  } catch (err) {
    // `{ errCode, errName }`, never the error object: see `logDrainRejection`
    // in `scheduled/maintenance-dispatchers.ts`.
    logger.error("rating_aggregation.read_counter_failed", {
      errName: err instanceof Error ? err.name : typeof err,
      errCode: (err as { code?: number | string })?.code,
    });
  }
}
