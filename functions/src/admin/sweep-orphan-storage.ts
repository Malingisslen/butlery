/**
 * BUT-2409: counts the Storage objects under `users/` that no document points
 * at (see sweep-orphan-storage-core.ts). Counts only, unless `--apply` is
 * passed together with `--max-delete <n>`. A delete cannot be undone, so n is
 * the count Malin approved: more orphans than n deletes nothing.
 *
 * Usage (from functions/):
 *   npm run sweep-orphan-storage -- --project <id>
 *   npm run sweep-orphan-storage -- --project <id> --apply --max-delete <n>
 *
 * Prints counts and bytes per folder, never user ids or file names.
 */

import * as admin from "firebase-admin";
import { initializeAdminApp } from "./admin-init";
import {
  assertScanPlausible,
  assertWithinCap,
  deleteOrphans,
  harvestStoragePaths,
  ObjectInfo,
  orphansOf,
  parseMaxDelete,
  SWEPT_FOLDERS,
  tallyObjects,
  userFolder,
} from "./sweep-orphan-storage-core";

const GET_CHUNK = 300;

/**
 * Walks the whole database, every collection at every depth. listDocuments
 * also returns documents that exist only as the parent of a subcollection,
 * and the root listing means a collection added later cannot hide a
 * reference. A walk that reads too much only keeps more files.
 */
async function harvestTree(
  db: admin.firestore.Firestore,
  collections: admin.firestore.CollectionReference[],
  keep: Set<string>,
): Promise<number> {
  let reads = 0;
  for (const col of collections) {
    const refs = await col.listDocuments();
    for (let i = 0; i < refs.length; i += GET_CHUNK) {
      const snaps = await db.getAll(...refs.slice(i, i + GET_CHUNK));
      for (const snap of snaps) {
        reads++;
        if (snap.exists) harvestStoragePaths(snap.data(), keep);
      }
    }
    for (const ref of refs) {
      reads += await harvestTree(db, await ref.listCollections(), keep);
    }
  }
  return reads;
}

async function main(): Promise<void> {
  const argv = process.argv.slice(2);
  const apply = argv.includes("--apply");
  const maxDelete = parseMaxDelete(argv);
  if (apply && maxDelete === null) {
    throw new Error(
      "REFUSED: --apply needs --max-delete <n>, the orphan count Malin approved.",
    );
  }
  const projectId = initializeAdminApp().options.projectId;
  const db = admin.firestore();
  const bucket = admin.storage().bucket(`${projectId}.firebasestorage.app`);

  const keep = new Set<string>();
  const reads = await harvestTree(db, await db.listCollections(), keep);

  const objects: ObjectInfo[] = [];
  const [files] = await bucket.getFiles({ prefix: "users/" });
  for (const file of files) {
    const folder = userFolder(file.name);
    if (folder === null || !SWEPT_FOLDERS.includes(folder)) continue;
    objects.push({
      name: file.name,
      sizeBytes: Number(file.metadata.size ?? 0),
      createdMs: Date.parse(String(file.metadata.timeCreated ?? "")) || Date.now(),
      generation: file.metadata.generation === undefined ? undefined : String(file.metadata.generation),
    });
  }
  assertScanPlausible(keep.size, objects.length);

  console.log(`Mode: ${apply ? "APPLY (deletes orphans)" : "DRY-RUN (read-only)"}. Firestore reads: ${reads}, references found: ${keep.size}`);
  const tally = tallyObjects(objects, keep, Date.now());
  for (const folder of SWEPT_FOLDERS) {
    const t = tally.get(folder);
    if (!t) {
      console.log(`${folder}: no objects`);
      continue;
    }
    console.log(
      `${folder}: ${t.objects} objects, in use ${t.inUse}, too new to judge ${t.tooNew}, ` +
        `orphans ${t.orphans} (${(t.orphanBytes / 1048576).toFixed(1)} MB)`,
    );
  }

  if (!apply) return;
  const orphans = orphansOf(objects, keep, Date.now());
  assertWithinCap(orphans.length, maxDelete as number);
  await deleteOrphans(bucket, orphans, (r) =>
    console.log(`Deleted ${r.deleted} orphans, skipped ${r.skipped} already gone, changed or unpinnable.`),
  );
}

main().catch((err) => {
  // Firestore and Storage errors can carry a document path or file name.
  const e = err as { code?: unknown; name?: unknown; message?: unknown };
  const refused =
    typeof e.message === "string" && e.message.startsWith("REFUSED") ? e.message : "";
  console.error("sweep-orphan-storage failed:", refused || String(e.code ?? e.name ?? "error"));
  process.exit(1);
});
