/**
 * Reset User Data — Clean Slate Script
 *
 * Wipes the collections named in `COLLECTIONS_TO_DELETE` below from Firebase
 * (Auth + Firestore + Storage), preserving config/seed data (site_configs,
 * tag_configs, ingredients, etc.).
 *
 * ⚠ It does NOT wipe everything. Top-level collections with `firestore.rules`
 * blocks appear in neither list, including uid-keyed personal data the account
 * cascade erases. Phase 1 deletes every Auth user first, so anything skipped is
 * left orphaned and unreachable by that cascade, which runs from an
 * authenticated callable. The run prints CLEANUP COMPLETE either way. See
 * BUT-2028, which also carries a second hazard: Phase 1 fires the live
 * `onUserDeleted` trigger, which writes into collections Phase 2 is
 * concurrently deleting.
 *
 * Any counts live in BUT-2028, where they can be re-derived. A count in a
 * comment goes stale the next time anyone adds a rules block or a list entry,
 * and nothing reddens when it does.
 *
 * Live runs are REFUSED while BUT-2028 is open — see the guard at the top of
 * `main()`. `--dry-run` still works, and is how you inspect the script.
 *
 * Usage:
 *   cd functions
 *   npm run reset-user-data:dry-run   # preview what gets deleted
 */

import * as admin from "firebase-admin";
import * as readline from "readline";
import { initializeAdminApp } from "./admin-init";

// --- Configuration ---

// The three collection lists live in their own side-effect-free module so the
// guards can import the real values instead of parsing this file as text —
// this file runs `main()` at module scope, which is why they had to.
import {
  CollectionTarget,
  COLLECTIONS_TO_DELETE,
  COLLECTIONS_TO_KEEP,
} from "./reset-collection-lists";

const STORAGE_PREFIXES_TO_DELETE = ["users/", "shared/"];

const BATCH_SIZE = 500;
const CONFIRMATION_PHRASE = "YES DELETE ALL USER DATA";
/** Opt-out for the BUT-2028 refusal below. Live runs only; `--dry-run` is free. */
const BUT_2028_ACK_FLAG = "--but-2028-acknowledged";

// --- Helpers ---

async function promptUser(question: string): Promise<string> {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });
  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      rl.close();
      resolve(answer.trim());
    });
  });
}

async function deleteCollection(
  db: admin.firestore.Firestore,
  collectionPath: string,
  dryRun: boolean
): Promise<number> {
  if (dryRun) {
    const snapshot = await db.collection(collectionPath).count().get();
    return snapshot.data().count;
  }

  let totalDeleted = 0;
  let query = db.collection(collectionPath).limit(BATCH_SIZE);

  while (true) {
    const snapshot = await query.get();
    if (snapshot.empty) break;

    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    totalDeleted += snapshot.size;

    if (snapshot.size < BATCH_SIZE) break;
  }

  return totalDeleted;
}

/**
 * Recursively delete a document and all its subcollections (any depth).
 */
async function deleteDocRecursive(
  docRef: admin.firestore.DocumentReference,
  subCounts: Record<string, number>,
  dryRun: boolean
): Promise<void> {
  const subCollections = await docRef.listCollections();
  for (const subCol of subCollections) {
    // Delete docs in this subcollection (each may have its own subs)
    const subDocRefs = await subCol.listDocuments();
    for (const subDocRef of subDocRefs) {
      await deleteDocRecursive(subDocRef, subCounts, dryRun);
    }
    const count = await deleteCollection(subCol.firestore, subCol.path, dryRun);
    subCounts[subCol.id] = (subCounts[subCol.id] || 0) + count;
  }

  if (!dryRun) {
    await docRef.delete();
  }
}

async function deleteWithSubcollections(
  db: admin.firestore.Firestore,
  target: CollectionTarget,
  dryRun: boolean
): Promise<{ parentCount: number; subCounts: Record<string, number> }> {
  const subCounts: Record<string, number> = {};

  const docRefs = await db.collection(target.name).listDocuments();
  let parentCount = docRefs.length;

  for (const docRef of docRefs) {
    await deleteDocRecursive(docRef, subCounts, dryRun);
  }

  // Also delete any real (non-phantom) docs via batch query
  const topCount = await deleteCollection(db, target.name, dryRun);
  if (topCount > parentCount) parentCount = topCount;

  return { parentCount, subCounts };
}

// --- Main ---

async function main() {
  const args = process.argv.slice(2);
  const dryRun = args.includes("--dry-run");

  // BUT-2028: live runs are REFUSED, in code, not in prose.
  //
  // Until BUT-2010 was fixed the overlap guard stopped every run, so the
  // hazards BUT-2028 records could not be reached. Repairing that guard removed
  // the only thing enforcing this file's warning — and `admin-init.ts`
  // hardcodes the production project, so an unrefused live run wipes every Auth
  // user there.
  //
  // Placed above `initializeAdminApp()` deliberately: it reads only `args`, so
  // it fires without credentials and cannot be pre-empted by a credential
  // discovery failure.
  //
  // `--dry-run` is deliberately unaffected: inspecting the script is how anyone
  // resolves BUT-2028 in the first place.
  if (!dryRun && !args.includes(BUT_2028_ACK_FLAG)) {
    console.error(
      "REFUSED: BUT-2028 is open. This script's delete list skips top-level " +
        "collections that have `firestore.rules` blocks — several of them " +
        "uid-keyed personal data, left orphaned because Phase 1 deletes every " +
        "Auth user first — and Phase 1 fires the live onUserDeleted trigger " +
        "into collections Phase 2 is concurrently deleting. " +
        "Resolve BUT-2028, or re-run with:  npm run reset-user-data -- " +
        BUT_2028_ACK_FLAG
    );
    process.exit(1);
  }

  initializeAdminApp();

  const db = admin.firestore();
  const projectId =
    admin.app().options.projectId || admin.app().options.credential;

  console.log("=".repeat(60));
  console.log(dryRun ? "  DRY RUN — no data will be modified" : "  LIVE RUN");
  console.log(`  Project: ${projectId}`);
  console.log("=".repeat(60));
  console.log();

  // Safety: verify preserved collections exist
  console.log("Preserved collections (will NOT be touched):");
  for (const col of COLLECTIONS_TO_KEEP) {
    const snapshot = await db.collection(col).limit(1).get();
    const status = snapshot.empty ? "empty" : "has data";
    console.log(`  ${col}: ${status}`);
  }
  console.log();

  // Verify no overlap between delete and keep lists
  const deleteNames = new Set(COLLECTIONS_TO_DELETE.map((t) => t.name));
  for (const keep of COLLECTIONS_TO_KEEP) {
    if (deleteNames.has(keep)) {
      console.error(
        `SAFETY ERROR: "${keep}" is in both delete and keep lists!`
      );
      process.exit(1);
    }
  }

  // Confirmation gate (live run only)
  if (!dryRun) {
    console.log("This will PERMANENTLY DELETE all user data.");
    console.log(`Type "${CONFIRMATION_PHRASE}" to proceed:\n`);
    const answer = await promptUser("> ");
    if (answer !== CONFIRMATION_PHRASE) {
      console.log("Aborted.");
      process.exit(0);
    }
    console.log();
  }

  // --- Phase 1: Delete Auth users ---
  console.log("Phase 1: Firebase Auth users");
  let totalAuthDeleted = 0;

  let pageToken: string | undefined;
  do {
    const result = await admin.auth().listUsers(1000, pageToken);
    const uids = result.users.map((u) => u.uid);
    totalAuthDeleted += uids.length;

    if (!dryRun && uids.length > 0) {
      const deleteResult = await admin.auth().deleteUsers(uids);
      if (deleteResult.failureCount > 0) {
        console.log(
          `  Warning: ${deleteResult.failureCount} users failed to delete`
        );
      }
    }

    pageToken = result.pageToken;
  } while (pageToken);

  console.log(
    `  ${dryRun ? "Would delete" : "Deleted"}: ${totalAuthDeleted} users`
  );
  console.log();

  // --- Phase 2: Delete Firestore collections ---
  console.log("Phase 2: Firestore collections");
  const results: {
    collection: string;
    docs: number;
    subs: Record<string, number>;
  }[] = [];

  for (const target of COLLECTIONS_TO_DELETE) {
    process.stdout.write(`  ${target.name}...`);
    const { parentCount, subCounts } = await deleteWithSubcollections(
      db,
      target,
      dryRun
    );
    results.push({
      collection: target.name,
      docs: parentCount,
      subs: subCounts,
    });

    const subSummary = Object.entries(subCounts)
      .filter(([, v]) => v > 0)
      .map(([k, v]) => `${k}=${v}`)
      .join(", ");
    const subStr = subSummary ? ` (subs: ${subSummary})` : "";
    console.log(` ${parentCount} docs${subStr}`);
  }
  console.log();

  // --- Phase 3: Delete Storage files ---
  console.log("Phase 3: Firebase Storage");
  let totalStorageFiles = 0;

  try {
    const bucket = admin.storage().bucket(`${projectId}.firebasestorage.app`);

    for (const prefix of STORAGE_PREFIXES_TO_DELETE) {
      if (dryRun) {
        const [files] = await bucket.getFiles({ prefix });
        console.log(`  ${prefix}: ${files.length} files (would delete)`);
        totalStorageFiles += files.length;
      } else {
        const [files] = await bucket.getFiles({ prefix });
        totalStorageFiles += files.length;
        if (files.length > 0) {
          await bucket.deleteFiles({ prefix, force: true });
        }
        console.log(`  ${prefix}: ${files.length} files deleted`);
      }
    }
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    console.log(`  Storage cleanup skipped: ${message}`);
  }
  console.log();

  // --- Phase 4: Summary ---
  console.log("=".repeat(60));
  console.log(dryRun ? "  DRY RUN SUMMARY" : "  CLEANUP COMPLETE");
  console.log("=".repeat(60));
  console.log(`  Auth users ${dryRun ? "to delete" : "deleted"}: ${totalAuthDeleted}`);

  const totalDocs = results.reduce((sum, r) => sum + r.docs, 0);
  const totalSubDocs = results.reduce(
    (sum, r) =>
      sum + Object.values(r.subs).reduce((s, v) => s + v, 0),
    0
  );
  console.log(
    `  Firestore docs ${dryRun ? "to delete" : "deleted"}: ${totalDocs} parent + ${totalSubDocs} subcollection`
  );
  console.log(
    `  Storage files ${dryRun ? "to delete" : "deleted"}: ${totalStorageFiles}`
  );
  console.log();
  console.log("  Preserved: " + COLLECTIONS_TO_KEEP.join(", "));
  console.log();
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
