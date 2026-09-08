/**
 * One-time migration of `user_moderation/{uid}.reportHistory` (an array of maps)
 * -> `user_moderation/{uid}/report_history/{reportId}` (one document per row).
 *
 * BUT-2046. Each array entry carries a `reporterId` — another person's uid —
 * and Firestore cannot query a uid inside an array of maps. So before this
 * runs, a reporter's uid sitting in SOMEBODY ELSE's moderation document is
 * reachable by no erasure path at all: the account cascade can delete the
 * document whose id is the erased user's own uid, and nothing more. This script
 * is what closes that, and the cascade's collection-group leg
 * (`deleteReportHistoryByReporter`) only works on rows this has moved.
 *
 * **Run it only after the new writer is live.** `on-report-created.ts` no
 * longer touches `reportHistory`, but a deployment still running the old code
 * appends to the array. This script clears that field, so an old writer plus
 * this script means a report can be written and then wiped. The per-document
 * transaction below makes that a retry rather than a silent loss for a write
 * that lands DURING the migration — it does nothing about an old writer
 * appending AFTER it. Deploy first, confirm, then run.
 *
 * TRANSACTIONAL PER DOCUMENT, which is where this differs from
 * `migrate-friend-categories.ts`, the script it is otherwise modelled on: that
 * one moves rows nothing writes any more, so a plain read-then-delete is safe
 * there. Here the parent document has a live writer (the strike counter), so a
 * read, a fan-out and a field clear done as three separate operations lets a
 * concurrent `arrayUnion` land between the read and the clear and vanish with
 * no error. Inside one transaction, that write forces a retry instead.
 *
 * A target document id that already exists is SKIPPED, never overwritten. The
 * id is the report id, so a collision means either a previous run of this
 * script or the live writer got there first — and both wrote the same row from
 * the same source. Overwriting would be harmless today and wrong the day the
 * row carries a field the array never had.
 *
 * Usage:
 *   cd functions
 *   npx ts-node src/admin/migrate-report-history.ts            # dry run
 *   npx ts-node src/admin/migrate-report-history.ts --live
 */

import * as admin from "firebase-admin";
import { initializeAdminApp } from "./admin-init";

const PARENT = "user_moderation";
const CHILD = "report_history";
const LEGACY_FIELD = "reportHistory";

/** Mirrors the writer's retention: 180 days, as on `report_processing_markers`. */
const RETENTION_DAYS = 180;

export interface MigrationOutcome {
  scanned: number;
  moved: number;
  skippedExisting: number;
  emptied: number;
  failures: string[];
}

interface LegacyEntry {
  reportId?: unknown;
  reporterId?: unknown;
  reason?: unknown;
  contentType?: unknown;
  contentId?: unknown;
}

/**
 * Rows written per transaction. A Firestore transaction takes at most 500
 * operations INCLUDING the parent's field-clear, so the bound is what stops an
 * oversized array throwing INVALID_ARGUMENT — which would leave that one
 * document unmigratable by any run, i.e. its reporters' uids unerasable, which
 * is the single thing this script exists to prevent. Comfortably under 500 so
 * the clear always fits.
 */
const ROWS_PER_TRANSACTION = 400;

/**
 * Moves one document's array into its subcollection and clears the field.
 *
 * Returns what happened rather than logging it, so a test can assert the
 * outcome.
 *
 * CHUNKED, and the chunking is what makes it correct rather than what makes it
 * fast: each pass re-reads the parent inside its own transaction, moves up to
 * `ROWS_PER_TRANSACTION` entries, and clears the field only on the pass that
 * finds nothing left to move. A concurrent write to the parent aborts the pass
 * and Firestore re-runs it, so an entry landing mid-migration is retried rather
 * than wiped by the clear.
 *
 * Reads precede writes within each pass, as Firestore requires: one `getAll`
 * for every candidate target after the parent read, rather than a `get` per
 * entry.
 *
 * An entry with no usable `reportId` is left in place and reported as a
 * failure, and the field then survives: such an entry cannot be given a
 * generated id without losing the idempotency the document id carries, and it
 * cannot be dropped, because it names a person.
 */
export async function migrateDocument(
  db: admin.firestore.Firestore,
  uid: string,
  dryRun: boolean,
): Promise<MigrationOutcome> {
  const outcome: MigrationOutcome = {
    scanned: 0,
    moved: 0,
    skippedExisting: 0,
    emptied: 0,
    failures: [],
  };
  const parentRef = db.collection(PARENT).doc(uid);

  // Each pass takes the NEXT slice by index rather than re-reading the whole
  // array and asking what is left. Re-reading looks equivalent and is not: an
  // entry written by an earlier pass comes back as "already exists", so both
  // the skipped count and the per-entry failures would be recorded once per
  // pass instead of once per entry. Walking by offset visits each entry exactly
  // once. The parent is still re-read inside every transaction, which is what
  // makes a concurrent write abort the pass rather than be wiped by the clear.
  let offset = 0;
  for (;;) {
    let processedThisPass = 0;
    let movedThisPass = 0;
    let skippedThisPass = 0;
    let failuresThisPass: string[] = [];
    let atEnd = false;

    await db.runTransaction(async (tx) => {
      // Reset the per-pass counters: a transaction retry re-runs this whole
      // body, and a losing attempt's numbers would be counted twice.
      processedThisPass = 0;
      movedThisPass = 0;
      skippedThisPass = 0;
      failuresThisPass = [];
      atEnd = false;

      const parentSnap = await tx.get(parentRef);
      const raw = parentSnap.data()?.[LEGACY_FIELD];
      if (!Array.isArray(raw) || raw.length === 0) {
        atEnd = true;
        return;
      }

      // The array length is a property of the document, not of a pass.
      outcome.scanned = raw.length;

      const slice = (raw as LegacyEntry[]).slice(
        offset,
        offset + ROWS_PER_TRANSACTION,
      );
      processedThisPass = slice.length;
      atEnd = offset + slice.length >= raw.length;

      const candidates: Array<{ reportId: string; entry: LegacyEntry }> = [];
      for (const item of slice) {
        const reportId =
          typeof item?.reportId === "string" && item.reportId.length > 0
            ? item.reportId
            : null;
        if (reportId === null) {
          failuresThisPass.push(`${uid}: entry with no reportId`);
          continue;
        }
        candidates.push({ reportId, entry: item });
      }

      // One array can carry the same report twice, and a transaction read does
      // not see its own pending writes — two `set`s on one ref would inflate
      // the moved count without writing anything extra.
      const seen = new Set<string>();
      const unique = candidates.filter(({ reportId }) => {
        if (seen.has(reportId)) return false;
        seen.add(reportId);
        return true;
      });

      const refs = unique.map(({ reportId }) =>
        parentRef.collection(CHILD).doc(reportId),
      );
      const existing = refs.length > 0 ? await tx.getAll(...refs) : [];

      const writable = unique.filter((_, i) => {
        if (existing[i]?.exists) {
          skippedThisPass += 1;
          return false;
        }
        return true;
      });

      movedThisPass = writable.length;

      if (dryRun) return;

      for (const { reportId, entry } of writable) {
        tx.set(parentRef.collection(CHILD).doc(reportId), {
          reportId,
          reporterId: entry.reporterId ?? null,
          reason: entry.reason ?? null,
          contentType: entry.contentType ?? null,
          contentId: entry.contentId ?? null,
          // The array carried no timestamp, so the clock starts now rather than
          // at the report. It expires later than a row written by the live
          // writer would have; the alternative is a row that never expires.
          expireAt: admin.firestore.Timestamp.fromDate(
            new Date(Date.now() + RETENTION_DAYS * 24 * 60 * 60 * 1000),
          ),
        });
      }

      // The field goes only on the pass that reaches the END of the array, and
      // only when nothing anywhere in it was left behind — so a chunked run
      // never clears an array whose tail has not been written yet, and one
      // unmovable entry keeps the whole field alive.
      if (
        atEnd &&
        outcome.failures.length + failuresThisPass.length === 0
      ) {
        tx.update(parentRef, {
          [LEGACY_FIELD]: admin.firestore.FieldValue.delete(),
        });
        outcome.emptied = 1;
      }
    });

    outcome.moved += movedThisPass;
    outcome.skippedExisting += skippedThisPass;
    outcome.failures.push(...failuresThisPass);
    offset += processedThisPass;

    // A dry run writes nothing, so it reports the first slice and stops rather
    // than walking an array it cannot change.
    if (atEnd || processedThisPass === 0 || dryRun) break;
  }

  return outcome;
}

/** Walks every `user_moderation` document. */
export async function migrateAll(
  db: admin.firestore.Firestore,
  dryRun: boolean,
): Promise<MigrationOutcome> {
  const total: MigrationOutcome = {
    scanned: 0,
    moved: 0,
    skippedExisting: 0,
    emptied: 0,
    failures: [],
  };

  const docs = await db.collection(PARENT).listDocuments();
  for (const ref of docs) {
    try {
      const one = await migrateDocument(db, ref.id, dryRun);
      total.scanned += one.scanned;
      total.moved += one.moved;
      total.skippedExisting += one.skippedExisting;
      total.emptied += one.emptied;
      total.failures.push(...one.failures);
    } catch (err) {
      total.failures.push(
        `${ref.id}: ${err instanceof Error ? err.message : String(err)}`,
      );
    }
  }

  return total;
}

async function main(): Promise<void> {
  const dryRun = !process.argv.includes("--live");
  initializeAdminApp();
  const db = admin.firestore();

  const outcome = await migrateAll(db, dryRun);

  // eslint-disable-next-line no-console
  console.log(
    JSON.stringify({ mode: dryRun ? "dry-run" : "live", ...outcome }, null, 2),
  );

  // A non-zero exit on failures so a run that could not finish is not read as
  // a clean one. The residual it leaves is the whole reason this exists.
  if (outcome.failures.length > 0) process.exitCode = 1;
}

if (require.main === module) {
  void main();
}
