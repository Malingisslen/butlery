import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { commitInChunks } from "../../shared/batch-update";
// BUT-2032 / ADR-0014: the first audit staging in this file. The cascade had
// none and `on-user-deleted.ts` stages one per mutated row; the panel measured
// that BUT-781's analogy carries the ACTION and not the record, so the two new
// steps below keep the trigger's posture rather than inherit the cascade's.
import { stageCascadeAuditEntry } from "../../cleanup/cascade-audit-log";
import {
  openReportIds,
  SYSTEM_EVENTS,
  USER_MODERATION,
  REPORT_HISTORY,
} from "./moderation";

/**
 * Cap on one erasure's `system_events` sweep. Same contract as
 * `MAX_BLOCK_SWEEP_ROWS` — decline above it rather than truncate, because a
 * truncated sweep reports a clean erasure over rows it never looked at.
 *
 * The count is chosen by OTHER PEOPLE on the owner-keyed legs: anyone may file
 * a report naming this user as `contentOwnerId`, and `firestore.rules` has no
 * write limb on this collection at all — every row here is an Admin-SDK write
 * from `onReportCreated`, so nothing a client can be rate-limited on bounds it
 * directly. That is the roster cap's argument, not the poll-vote cap's, and the
 * two differ (BUT-1801).
 */
const MAX_SYSTEM_EVENT_SWEEP_ROWS = 2000;

/**
 * The report a `content_report_<reportId>` row is about. The trigger writes the
 * id both into `details.reportId` and into the document id.
 */
function reportIdOfEvent(doc: admin.firestore.QueryDocumentSnapshot): string {
  return (
    (doc.get("details.reportId") as string | undefined) ??
    doc.id.replace(/^content_report_/, "")
  );
}

/**
 * BUT-2032: the moderation rows in the admin ops log, which no erasure path
 * reached. `feedback/on-report-created.ts` writes TWO shapes about a report, and
 * a step written from the document id alone covers only one of them:
 *
 *   `moderation_threshold_<contentOwnerId>` — the uid is the document's own
 *       identity, and `details.userId` repeats it. Deleted: a document whose id
 *       IS the identifier cannot be anonymized.
 *   `content_report_<reportId>` — no uid in the id, and BOTH parties in the
 *       fields (`details.reporterId`, `details.contentOwnerId`).
 *
 * The policy is derived from the two already-decided outcomes on the SOURCE
 * collection rather than invented here, because a third policy for one event is
 * how two records of one decision drift apart:
 *
 *   reporter erases  -> the row follows its `reports` document: DELETED when
 *       that case is closed (ADR-0016, 2026-09-08), KEPT with
 *       `details.reporterId` nulled while it is open (Malin, 2026-09-18).
 *   reported erases  -> ANONYMIZE, exactly as `anonymizeReportsByContentOwnerWithDb`
 *       does on the source row (BUT-781): the row stays, the identifier goes.
 *
 * Each mutation stages its own `audit_logs` row (ADR-0014). The step runs in the
 * CASCADE and not in `onUserDeleted` because `probeResidualData` runs before
 * `auth.deleteUser` and the trigger runs after it — a trigger-owned step with a
 * probe leg turns every affected erasure into a false `gdprCompliant: false`,
 * which is the defect BUT-2044 records.
 *
 * NOT closed by this step, and named rather than left to be discovered:
 * `onReportCreated` is an `onDocumentCreated` trigger on `reports/{reportId}`
 * with NO ordering relationship to account deletion in either direction — it
 * re-throws for retry — so a report created, or a delivery retried, around the
 * erasure writes a fresh row naming the erased uid afterwards. Malin accepted
 * that as a named residual on 2026-09-08 rather than build the reconciliation
 * pass the block mirror has for the same race.
 */
export async function deleteModerationSystemEvents(
  db: admin.firestore.Firestore,
  uid: string,
  /**
   * BUT-2046 follow-up. Under a legal hold every row ABOUT this person is kept:
   * the `details.contentOwnerId` anonymize does not run, and the
   * `details.userId` threshold alert is not deleted — that field carries the
   * REPORTED person's uid (`feedback/on-report-created.ts` writes
   * `userId: contentOwnerId`), so deleting it would keep the report and destroy
   * the alert derived from it, which is a half-held case.
   *
   * Only `details.reporterId` is genuinely the other party, and that leg runs
   * unchanged: the hold is one-directional by design.
   *
   * `sweepErasureHolds` calls this again with the default once the hold lifts.
   */
  held = false,
): Promise<boolean> {
  let complete = true;

  /** Runs one capped leg. Returns null when the leg declined. */
  const sweep = async (
    field: string,
  ): Promise<admin.firestore.QueryDocumentSnapshot[] | null> => {
    const snap = await db
      .collection(SYSTEM_EVENTS)
      .where(field, "==", uid)
      .limit(MAX_SYSTEM_EVENT_SWEEP_ROWS + 1)
      .get();
    if (snap.size > MAX_SYSTEM_EVENT_SWEEP_ROWS) {
      logger.error(
        "[deletion-cascade] implausible system_events count; not sweeping",
        { uid_prefix: uid.slice(0, 6), field, rows: snap.size },
      );
      return null;
    }
    return snap.docs;
  };

  // The rows this erasure DELETES, sharing one commit. Which legs those are
  // depends on `held` — see the array below. `details.userId` is queried rather than the document id
  // rebuilt, so a threshold row whose id ever differs from the convention is
  // still reached, and no audit row is staged for a document that never existed.
  const deletions: admin.firestore.QueryDocumentSnapshot[] = [];
  const deletedIds = new Set<string>();
  // Reporter rows whose case is still open: kept, with the reporter removed.
  const reporterAnonymizations: admin.firestore.QueryDocumentSnapshot[] = [];
  const legs = held
    ? (["details.reporterId"] as const)
    : (["details.userId", "details.reporterId"] as const);
  for (const field of legs) {
    const docs = await sweep(field);
    if (docs === null) {
      // `continue`, not `return`: the legs are independent and half an erasure
      // beats none, as long as the step still reports itself incomplete.
      complete = false;
      continue;
    }
    let open = new Set<string>();
    if (field === "details.reporterId") {
      // The row follows its `reports` document: an open case keeps it, with
      // the reporter's uid nulled, exactly as `deleteUserReports` keeps the
      // report. A failed read keeps every row — keeping is recoverable,
      // deleting an open case's record is not — and the step says so.
      try {
        open = await openReportIds(
          db,
          docs.map(reportIdOfEvent),
        );
      } catch (err) {
        logger.error(
          "[deletion-cascade] report status unreadable; keeping reporter rows",
          {
            uid_prefix: uid.slice(0, 6),
            errCode: (err as { code?: number | string }).code ?? null,
            errName: err instanceof Error ? err.name : typeof err,
          },
        );
        complete = false;
        open = new Set(
          docs.map(reportIdOfEvent),
        );
      }
    }
    for (const doc of docs) {
      if (deletedIds.has(doc.id)) continue;
      if (field === "details.reporterId" && open.has(reportIdOfEvent(doc))) {
        reporterAnonymizations.push(doc);
        continue;
      }
      deletedIds.add(doc.id);
      deletions.push(doc);
    }
  }
  if (reporterAnonymizations.length > 0) {
    await commitInChunks(
      db,
      reporterAnonymizations,
      (batch, doc) => {
        batch.update(doc.ref, {
          "details.reporterId": null,
          reporterErasedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        stageCascadeAuditEntry(db, batch, {
          subjectUserId: uid,
          targetUid: null,
          operation: "cascade_anonymize",
          resourceType: SYSTEM_EVENTS,
          resourceId: doc.id,
          extra: { field: "details.reporterId" },
        });
      },
      {
        label: `system_events reporter anonymize for ${uid.slice(0, 6)}`,
        opsPerItem: 2,
        strict: true,
      },
    );
  }
  if (deletions.length > 0) {
    await commitInChunks(
      db,
      deletions,
      (batch, doc) => {
        batch.delete(doc.ref);
        stageCascadeAuditEntry(db, batch, {
          subjectUserId: uid,
          targetUid: null,
          operation: "cascade_delete",
          resourceType: SYSTEM_EVENTS,
          resourceId: doc.id,
        });
      },
      {
        label: `BUT-2032: system_events delete for ${uid.slice(0, 6)}`,
        opsPerItem: 2,
      },
    );
  }

  // The reported-side rows survive with the identifier removed. Read AFTER the
  // deletes above.
  //
  // Under a hold the identifier STAYS — that is the whole exception, and the
  // reports rows one collection over are held by the same decision. Returning
  // here rather than filtering below is deliberate: the sweep itself would be a
  // read whose only product is rows nothing may touch.
  if (held) return complete;

  const owned = await sweep("details.contentOwnerId");
  if (owned === null) {
    complete = false;
  } else {
    const toAnonymize = owned.filter((doc) => !deletedIds.has(doc.id));
    if (toAnonymize.length > 0) {
      await commitInChunks(
        db,
        toAnonymize,
        (batch, doc) => {
          batch.update(doc.ref, {
            "details.contentOwnerId": null,
            contentOwnerAnonymizedAt:
              admin.firestore.FieldValue.serverTimestamp(),
          });
          stageCascadeAuditEntry(db, batch, {
            subjectUserId: uid,
            targetUid: null,
            operation: "cascade_anonymize",
            resourceType: SYSTEM_EVENTS,
            resourceId: doc.id,
            extra: { field: "details.contentOwnerId" },
          });
        },
        {
          label: `BUT-2032: system_events anonymize for ${uid.slice(0, 6)}`,
          opsPerItem: 2,
        },
      );
    }
  }

  return complete;
}

/**
 * Cap on one erasure's `report_history` sweeps. Same contract as
 * `MAX_SYSTEM_EVENT_SWEEP_ROWS`: decline above it rather than truncate.
 *
 * BOTH legs need it, and for the roster cap's reason rather than the poll
 * cap's: the row count is chosen by OTHER PEOPLE. Anyone may report this user
 * (the owner leg) and there is no client-side throttle on report creation, and
 * anyone may be reported by them (the reporter leg).
 */
const MAX_REPORT_HISTORY_SWEEP_ROWS = 2000;

/**
 * BUT-2046: the moderation strike record about the erased user, and the report
 * rows beneath it.
 *
 * `user_moderation/{contentOwnerId}` is keyed on the REPORTED person's uid and
 * holds their strike counter; `report_history/{reportId}` beneath it is one row
 * per report, each naming a reporter. Firestore never cascade-deletes a
 * subcollection, so the parent alone leaves every row standing.
 *
 * CHILDREN FIRST, parent last. The repo's rule about orphaning is a one-way
 * door does NOT bite here, and the reason is worth stating so a later reader
 * does not reason from the conversation-roster case by analogy: those rows are
 * discovered through a query on the PARENT, so losing the parent loses the
 * rows forever. These sit at a path derived from the uid alone, so a retry — and
 * `probeResidualData`'s own leg — reaches them whether or not the parent
 * survived. The order is kept anyway because it costs nothing and it is what
 * every sibling in this file does.
 */
export async function deleteModerationRecord(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const parent = db.collection(USER_MODERATION).doc(uid);
  const history = await parent
    .collection(REPORT_HISTORY)
    .limit(MAX_REPORT_HISTORY_SWEEP_ROWS + 1)
    .get();

  if (history.size > MAX_REPORT_HISTORY_SWEEP_ROWS) {
    logger.error(
      "[deletion-cascade] implausible report_history count; not sweeping",
      { uid_prefix: uid.slice(0, 6), rows: history.size },
    );
    // The parent is left standing too: deleting it while its rows remain would
    // hide them from a reader without erasing them, and the probe leg below
    // counts them either way.
    return false;
  }

  if (!history.empty) {
    await commitInChunks(
      db,
      history.docs,
      (batch, doc) => {
        batch.delete(doc.ref);
        stageCascadeAuditEntry(db, batch, {
          subjectUserId: uid,
          targetUid: null,
          operation: "cascade_delete",
          resourceType: REPORT_HISTORY,
          resourceId: doc.id,
        });
      },
      {
        label: `BUT-2046: report_history delete for ${uid.slice(0, 6)}`,
        opsPerItem: 2,
      },
    );
  }

  const batch = db.batch();
  batch.delete(parent);
  stageCascadeAuditEntry(db, batch, {
    subjectUserId: uid,
    targetUid: null,
    operation: "cascade_delete",
    resourceType: USER_MODERATION,
    resourceId: uid,
  });
  await batch.commit();
  return true;
}

/**
 * BUT-2046: the erased user as the REPORTER — their uid on rows that live under
 * OTHER people's moderation records.
 *
 * A cross-user sweep, and it runs AFTER tier 1 for the same reason
 * `deleteBlockMirrors` does: `onReportCreated` can write a row while the
 * cascade is running, and running last makes this the final word on everything
 * tier 1 removed.
 *
 * It does not close that race, and nothing here can. `onReportCreated` is an
 * `onDocumentCreated` trigger that re-throws for retry and has NO ordering
 * relationship to account deletion, so a report filed — or a delivery retried —
 * around the erasure lands a fresh row naming this uid afterwards. Accepted as a
 * named residual, the same call Malin made for the sibling `system_events` rows
 * on 2026-09-08, and the reason the 180-day TTL on `expireAt` matters: it is
 * what eventually removes such a row.
 *
 * The legacy shape is NOT reachable from here. Before BUT-2046 these rows were
 * entries in a `reportHistory` ARRAY on the parent, and a uid inside an array of
 * maps cannot be queried — so a reporter's uid in somebody else's un-migrated
 * document is reached by `admin/migrate-report-history.ts` and by nothing else.
 */
export async function deleteReportHistoryByReporter(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const snap = await db
    .collectionGroup(REPORT_HISTORY)
    .where("reporterId", "==", uid)
    .limit(MAX_REPORT_HISTORY_SWEEP_ROWS + 1)
    .get();

  if (snap.size > MAX_REPORT_HISTORY_SWEEP_ROWS) {
    logger.error(
      "[deletion-cascade] implausible reporter row count; not sweeping",
      { uid_prefix: uid.slice(0, 6), rows: snap.size },
    );
    return false;
  }

  if (snap.empty) return true;

  // The row follows its `reports` document (the doc id IS the report id): an
  // open case keeps it with the reporter's uid nulled. A failed read keeps
  // every row, and the step reports itself incomplete.
  let complete = true;
  let open: Set<string>;
  try {
    open = await openReportIds(db, snap.docs.map((d) => d.id));
  } catch (err) {
    logger.error(
      "[deletion-cascade] report status unreadable; keeping reporter rows",
      {
        uid_prefix: uid.slice(0, 6),
        errCode: (err as { code?: number | string }).code ?? null,
        errName: err instanceof Error ? err.name : typeof err,
      },
    );
    complete = false;
    open = new Set(snap.docs.map((d) => d.id));
  }

  await commitInChunks(
    db,
    snap.docs,
    (batch, doc) => {
      if (open.has(doc.id)) {
        batch.update(doc.ref, { reporterId: null });
        stageCascadeAuditEntry(db, batch, {
          subjectUserId: uid,
          targetUid: null,
          operation: "cascade_anonymize",
          resourceType: REPORT_HISTORY,
          resourceId: doc.id,
          extra: { field: "reporterId" },
        });
        return;
      }
      batch.delete(doc.ref);
      stageCascadeAuditEntry(db, batch, {
        subjectUserId: uid,
        // `resourceId` is the REPORT id, so this row does not record whose
        // moderation record was touched — the owner leg's `resourceId` is the
        // uid, this one's is not. Naming the parent owner would put a third
        // party's uid in `audit_logs`, which is a privacy decision rather than
        // an omission.
        targetUid: null,
        operation: "cascade_delete",
        resourceType: REPORT_HISTORY,
        resourceId: doc.id,
      });
    },
    {
      label: `BUT-2046: reporter rows delete for ${uid.slice(0, 6)}`,
      opsPerItem: 2,
    },
  );
  return complete;
}
