import * as admin from "firebase-admin";
import { commitInChunks } from "../../shared/batch-update";
// BUT-2032 / ADR-0014: the first audit staging in this file. The cascade had
// none and `on-user-deleted.ts` stages one per mutated row; the panel measured
// that BUT-781's analogy carries the ACTION and not the record, so the two new
// steps below keep the trigger's posture rather than inherit the cascade's.
import { stageCascadeAuditEntry } from "../../cleanup/cascade-audit-log";
import {
  isClosedReportStatus,
  REPORTER_RETENTION_DAYS,
  REPORTS,
} from "../../moderation/report-status";
import { batchDeleteAll } from "./core";

export async function deletePingsByUser(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const snap = await db
    .collectionGroup("pings")
    .where("fromUserId", "==", uid)
    .get();
  await batchDeleteAll(db, snap.docs);
  return true;
}

export interface ReporterErasureOutcome {
  ok: boolean;
  /** Reports kept because their case was still open. */
  keptOpen: number;
  /** When a kept report is deleted at the latest, whatever its case does. */
  retainUntil: admin.firestore.Timestamp;
}

function reporterRetainUntilFrom(now: Date): admin.firestore.Timestamp {
  return admin.firestore.Timestamp.fromDate(
    new Date(now.getTime() + REPORTER_RETENTION_DAYS * 24 * 60 * 60 * 1000),
  );
}

/**
 * The erased user as the person who FILED a report.
 *
 * A closed case's report is deleted. An open one is KEPT with the reporter's
 * uid removed, so the case can still be decided — Malin's call, 2026-09-18.
 * Its free text (`description`) stays: it is often all a moderator has beyond
 * the `reason` category. `reporter-retention.ts` deletes the row once the case
 * closes or `reporterRetainUntil` passes.
 *
 * ONE equality, and the status is read off the row rather than filtered in the
 * query: the orchestration suite's fixture keys on "two chained `where`s on
 * `reports`" to recognise `hasOpenModerationCase`, and a second chained filter
 * here would be answered by it.
 *
 * STRICT: a failed chunk throws, so the step is reported failed rather than
 * leaving the uid behind under a success.
 */
export async function deleteUserReports(
  db: admin.firestore.Firestore,
  uid: string,
  now: Date = new Date(),
): Promise<ReporterErasureOutcome> {
  const retainUntil = reporterRetainUntilFrom(now);
  const snap = await db
    .collection(REPORTS)
    .where("reporterId", "==", uid)
    .get();
  if (snap.empty) return { ok: true, keptOpen: 0, retainUntil };

  let keptOpen = 0;
  await commitInChunks(
    db,
    snap.docs,
    (batch, doc) => {
      if (isClosedReportStatus(doc.get("status"))) {
        batch.delete(doc.ref);
        stageCascadeAuditEntry(db, batch, {
          subjectUserId: uid,
          targetUid: null,
          operation: "cascade_delete",
          resourceType: REPORTS,
          resourceId: doc.id,
        });
        return;
      }
      keptOpen += 1;
      batch.update(doc.ref, {
        reporterId: null,
        reporterErasedAt: admin.firestore.FieldValue.serverTimestamp(),
        reporterRetainUntil: retainUntil,
      });
      stageCascadeAuditEntry(db, batch, {
        subjectUserId: uid,
        targetUid: null,
        operation: "cascade_anonymize",
        resourceType: REPORTS,
        resourceId: doc.id,
        extra: { field: "reporterId" },
      });
    },
    {
      label: `reporter reports for ${uid.slice(0, 6)}`,
      opsPerItem: 2,
      strict: true,
    },
  );
  return { ok: true, keptOpen, retainUntil };
}

/**
 * Whether each linked report's case is still open, keyed by report id.
 *
 * Read one document at a time in bounded groups rather than with `getAll`: the
 * sweeps it serves are capped at 2000 rows, and neither cascade test fake
 * implements a top-level `getAll`.
 *
 * A report that does not exist reads as NOT open — its case can no longer be
 * decided. Throws when a read fails; callers treat that as "open".
 */
export async function openReportIds(
  db: admin.firestore.Firestore,
  reportIds: string[],
): Promise<Set<string>> {
  const open = new Set<string>();
  const unique = [...new Set(reportIds)];
  const GROUP = 100;
  for (let i = 0; i < unique.length; i += GROUP) {
    const group = unique.slice(i, i + GROUP);
    const snaps = await Promise.all(
      group.map((id) => db.collection(REPORTS).doc(id).get()),
    );
    snaps.forEach((snap, i) => {
      if (snap.exists && !isClosedReportStatus(snap.data()?.status)) {
        open.add(group[i]);
      }
    });
  }
  return open;
}

/**
 * The admin ops log. Named through a local const because `Collections` does not
 * carry it; the coverage guard resolves file-local consts, so this stays
 * discoverable to it (BUT-2043).
 */
export const SYSTEM_EVENTS = "system_events";

/**
 * The moderation strike record, keyed on the REPORTED user's uid (BUT-2046).
 *
 * Exported because `held` is keyed on it in TWO files, and the comments on both
 * say they must agree — a second string literal is how they stop agreeing.
 */
export const USER_MODERATION = "user_moderation";

/** One row per report, beneath a `user_moderation` document (BUT-2046). */
export const REPORT_HISTORY = "report_history";
