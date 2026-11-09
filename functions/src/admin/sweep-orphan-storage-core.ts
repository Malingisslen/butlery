/**
 * The orphan decision for BUT-2409: which Storage objects under `users/` no
 * document points at any more. Deletes made before the owner-delete rule
 * (BUT-2294) all failed silently, so replaced avatars, removed recipe photos
 * and dropped comment images were left behind.
 *
 * Pure on purpose: the script supplies the object listing and the documents,
 * this file only decides, so the decision is testable without Storage.
 */

import { extractStoragePath, recipeThumbnailPaths } from "../cleanup/storage-path-guard";

/** Folders whose files are only ever referenced by a document field. */
export const SWEPT_FOLDERS: readonly string[] = [
  "avatars",
  "recipes",
  "comment_images",
  "chat_images",
];

/**
 * An upload lands before the document that points at it, and the offline
 * queue can hold a file for days before its row is written.
 */
export const GRACE_MS = 7 * 24 * 60 * 60 * 1000;

export interface ObjectInfo {
  name: string;
  sizeBytes: number;
  createdMs: number;
  /** Pins a delete to the exact version that was judged an orphan. */
  generation?: string;
}

export type Verdict = "not-swept" | "in-use" | "too-new" | "orphan";

/**
 * Adds the object path of every Storage reference found anywhere in [value]
 * to [into]. Walking every string, rather than named fields, means a field
 * nobody listed here (a cookbook cover, a later feature) still counts as a
 * reference instead of turning its file into a false orphan.
 */
export function harvestStoragePaths(value: unknown, into: Set<string>): void {
  if (typeof value === "string") {
    if (!value.includes("users")) return;
    const path = extractStoragePath(value);
    if (path === null || !path.startsWith("users/")) return;
    into.add(path);
    for (const thumb of recipeThumbnailPaths(path)) into.add(thumb);
    return;
  }
  if (Array.isArray(value)) {
    for (const item of value) harvestStoragePaths(item, into);
    return;
  }
  if (value !== null && typeof value === "object") {
    for (const item of Object.values(value as Record<string, unknown>)) {
      harvestStoragePaths(item, into);
    }
  }
}

/** The folder directly under `users/{uid}/`, or null for any other path. */
export function userFolder(objectName: string): string | null {
  const parts = objectName.split("/");
  if (parts.length < 4 || parts[0] !== "users") return null;
  return parts[2];
}

export function classifyObject(
  obj: ObjectInfo,
  keep: ReadonlySet<string>,
  nowMs: number,
): Verdict {
  const folder = userFolder(obj.name);
  if (folder === null || !SWEPT_FOLDERS.includes(folder)) return "not-swept";
  if (keep.has(obj.name)) return "in-use";
  if (nowMs - obj.createdMs < GRACE_MS) return "too-new";
  return "orphan";
}

export interface FolderTally {
  objects: number;
  inUse: number;
  tooNew: number;
  orphans: number;
  orphanBytes: number;
}

export function tallyObjects(
  objects: Iterable<ObjectInfo>,
  keep: ReadonlySet<string>,
  nowMs: number,
): Map<string, FolderTally> {
  const byFolder = new Map<string, FolderTally>();
  for (const obj of objects) {
    const verdict = classifyObject(obj, keep, nowMs);
    if (verdict === "not-swept") continue;
    const folder = userFolder(obj.name) as string;
    const t = byFolder.get(folder) ?? {
      objects: 0,
      inUse: 0,
      tooNew: 0,
      orphans: 0,
      orphanBytes: 0,
    };
    t.objects++;
    if (verdict === "in-use") t.inUse++;
    else if (verdict === "too-new") t.tooNew++;
    else {
      t.orphans++;
      t.orphanBytes += obj.sizeBytes;
    }
    byFolder.set(folder, t);
  }
  return byFolder;
}

/**
 * A failed or empty document scan would make every file look orphaned, which
 * is the one mistake a later delete cannot take back. Refuse to report when
 * swept objects exist but the scan found no reference at all.
 */
export function assertScanPlausible(
  keepSize: number,
  sweptObjectCount: number,
): void {
  if (sweptObjectCount > 0 && keepSize === 0) {
    throw new Error(
      "REFUSED: objects exist but no document references any of them; the " +
        "document scan is broken, so every file would read as an orphan.",
    );
  }
}

export function orphansOf(
  objects: Iterable<ObjectInfo>,
  keep: ReadonlySet<string>,
  nowMs: number,
): ObjectInfo[] {
  const orphans: ObjectInfo[] = [];
  for (const obj of objects) {
    if (classifyObject(obj, keep, nowMs) === "orphan") orphans.push(obj);
  }
  return orphans;
}

/** The value of `--max-delete <n>`, or null when absent or not a positive integer. */
export function parseMaxDelete(argv: readonly string[]): number | null {
  const i = argv.indexOf("--max-delete");
  if (i === -1) return null;
  const raw = argv[i + 1];
  if (raw === undefined || !/^[1-9][0-9]*$/.test(raw)) return null;
  return Number(raw);
}

/**
 * The count Malin approved is the ceiling: if more orphans exist now, nothing
 * is deleted, so a changed database cannot widen an approved delete.
 */
export function assertWithinCap(orphanCount: number, cap: number): void {
  if (orphanCount > cap) {
    throw new Error(
      `REFUSED: ${orphanCount} orphans found but --max-delete allows ${cap}. Nothing was deleted.`,
    );
  }
}

export interface DeletableBucket {
  file(name: string): {
    delete(options: { ifGenerationMatch: string }): Promise<unknown>;
  };
}

export interface DeleteResult {
  deleted: number;
  skipped: number;
}

/**
 * Each delete is pinned to the version that was judged an orphan, so a file
 * replaced since is left alone (412), as is one already gone (404). An object
 * with no generation cannot be pinned and is skipped. Any other error stops
 * the run; `onProgress` has already seen the counts so far.
 */
export async function deleteOrphans(
  bucket: DeletableBucket,
  orphans: readonly ObjectInfo[],
  onProgress: (result: DeleteResult) => void,
): Promise<DeleteResult> {
  const result: DeleteResult = { deleted: 0, skipped: 0 };
  try {
    for (const obj of orphans) {
      if (!obj.generation) {
        result.skipped++;
        continue;
      }
      try {
        await bucket.file(obj.name).delete({ ifGenerationMatch: obj.generation });
        result.deleted++;
      } catch (err) {
        const code = (err as { code?: unknown }).code;
        if (code !== 404 && code !== 412) throw err;
        result.skipped++;
      }
    }
  } finally {
    onProgress(result);
  }
  return result;
}
