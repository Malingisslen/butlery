/**
 * One-time migration of `users/{uid}/friendCategories` -> `friend_categories`.
 *
 * BUT-2044. `b9a95bd02` (2026-03-19) renamed thirteen collection constants from
 * camelCase to snake_case. It DID add
 * `migrate-collection-names.ts`, whose table listed this very rename — and that
 * tool was deleted the next day (`85a5f3ed0`), with no record of it ever having
 * run against real data. The rows it would have moved are still here.
 *
 * Measured 2026-09-08 against butlery-app-1: one row, `test-group-1`, on one
 * account, whose `friend_categories` is EMPTY — so it is the owner's only copy,
 * not a duplicate left behind by a copy-forward that already ran.
 *
 * **Why migrate rather than teach the export a second path.** The Art. 15
 * export runs through the CLIENT SDK, and `firestore.rules` has no block for
 * the camelCase path, so an export read there is denied for every user. Moving
 * the row puts it under the live spelling, which is already exported by a
 * reviewed section and already erased by a reviewed cascade step — and which
 * `cleanupGroupMemberships` already queries, so other people's uids inside
 * `friendUserIds` become reachable by their own erasure too. Malin's call,
 * 2026-09-08, over building a new rules surface for a dead spelling.
 *
 * It also GRANTS A READ, which is not merely an export change and is named
 * here rather than left to be discovered: `firestore.rules` carries a
 * collection-group rule letting any uid in `friendUserIds` read a
 * `friend_categories` row, and the camelCase path has no block at all. So
 * moving a row hands its members a read they did not have. That is the same
 * access every other category of theirs already grants, which is why it was
 * not treated as a blocker — but it is a widening, not a no-op.
 *
 * COPY, VERIFY, THEN DELETE — in that order, per document. A delete that runs
 * before its copy is confirmed is the one failure this cannot recover from.
 *
 * Usage:
 *   cd functions
 *   npx ts-node src/admin/migrate-friend-categories.ts            # dry run
 *   npx ts-node src/admin/migrate-friend-categories.ts --live
 */

import * as admin from "firebase-admin";
import { initializeAdminApp } from "./admin-init";

const LEGACY = "friendCategories";
const LIVE = "friend_categories";

export interface MigrationOutcome {
  scanned: number;
  copied: number;
  skippedExisting: number;
  deleted: number;
  failures: string[];
}

/**
 * Moves every legacy row for one user. Returns what happened rather than
 * logging it, so a test can assert the outcome.
 *
 * A doc id that already exists under the live spelling is SKIPPED, never
 * overwritten: the live row is the one the app has been reading and writing,
 * and a copy-forward that clobbers it would destroy current data to rescue a
 * stale one. Such a legacy row is also LEFT STANDING and reported, not deleted:
 * its contents were never copied anywhere, so deleting it would discard data
 * this script never read — which the copy-verify-delete contract above does not
 * cover. Which of two divergent rows wins is a person's call, not this script's.
 */
export async function migrateUser(
  userDoc: admin.firestore.DocumentReference,
  live: boolean,
): Promise<MigrationOutcome> {
  const out: MigrationOutcome = {
    scanned: 0,
    copied: 0,
    skippedExisting: 0,
    deleted: 0,
    failures: [],
  };

  const legacy = await userDoc.collection(LEGACY).get();
  out.scanned = legacy.size;

  for (const doc of legacy.docs) {
    const target = userDoc.collection(LIVE).doc(doc.id);
    try {
      const existing = await target.get();
      if (existing.exists) {
        out.skippedExisting++;
        out.failures.push(
          `${doc.id}: a row already exists under the live spelling; legacy row ` +
            "left standing, contents not compared",
        );
        continue;
      }
      if (live) await target.set(doc.data());
      out.copied++;

      if (!live) continue;

      // Re-read the target rather than trusting the write above: the delete
      // below is irreversible, and `set()` resolving is not the same claim as
      // the row being there.
      const confirmed = await target.get();
      if (!confirmed.exists) {
        out.failures.push(`${doc.id}: copy not confirmed, source kept`);
        continue;
      }
      await doc.ref.delete();
      out.deleted++;
    } catch (err) {
      out.failures.push(
        `${doc.id}: ${err instanceof Error ? err.message : String(err)}`,
      );
    }
  }
  return out;
}

async function main(): Promise<void> {
  const live = process.argv.includes("--live");
  initializeAdminApp();
  const db = admin.firestore();

  console.log(live ? "LIVE RUN" : "DRY RUN — nothing is written");
  const totals: MigrationOutcome = {
    scanned: 0,
    copied: 0,
    skippedExisting: 0,
    deleted: 0,
    failures: [],
  };

  for (const userDoc of await db.collection("users").listDocuments()) {
    const r = await migrateUser(userDoc, live);
    if (r.scanned === 0) continue;
    console.log(
      `  ${userDoc.id.slice(0, 6)}…: scanned ${r.scanned}, ` +
        `${live ? "copied" : "would copy"} ${r.copied}, ` +
        `skipped ${r.skippedExisting}, deleted ${r.deleted}`,
    );
    totals.scanned += r.scanned;
    totals.copied += r.copied;
    totals.skippedExisting += r.skippedExisting;
    totals.deleted += r.deleted;
    totals.failures.push(...r.failures);
  }

  console.log(
    `\n  scanned ${totals.scanned}, ` +
      `${live ? "copied" : "would copy"} ${totals.copied}, ` +
      `skipped-existing ${totals.skippedExisting}, deleted ${totals.deleted}`,
  );
  for (const f of totals.failures) console.log(`  FAILURE ${f}`);
  if (totals.failures.length > 0) process.exitCode = 1;
}

if (require.main === module) {
  main()
    .then(() => process.exit(process.exitCode ?? 0))
    .catch((err) => {
      // Without this an exception prints an unhandled-rejection trace and
      // the FAILURE lines above never run, so a partial move reads as a
      // crash with no record of which rows moved.
      console.error(`  FATAL ${err instanceof Error ? err.message : err}`);
      process.exit(1);
    });
}
