/**
 * BUT-2414: a staged Storage bucket for the `storage_files` section, keyed by
 * the fake Firestore each test builds so the existing helpers stay one
 * argument wide. It pages at 1000 objects, as the Storage JSON API does, and
 * records every listing call.
 */

import { FakeFirestore } from "./_fake-firestore";
import { FileLister, ListedFile } from "../exports/erasure-residue/project";

export interface StagedBucket {
  files: ListedFile[];
  calls: Array<{ prefix: string; maxResults: number; returned: number }>;
}

const BUCKETS = new WeakMap<FakeFirestore, StagedBucket>();

export function stagedBucket(db: FakeFirestore): StagedBucket {
  let staged = BUCKETS.get(db);
  if (!staged) {
    staged = { files: [], calls: [] };
    BUCKETS.set(db, staged);
  }
  return staged;
}

export function stageFile(db: FakeFirestore, name: string, metadata: Record<string, unknown> = {}): void {
  stagedBucket(db).files.push({ name, metadata } as ListedFile);
}

export function bucketOf(db: FakeFirestore): () => FileLister {
  const staged = stagedBucket(db);
  return () => ({
    getFiles: async (query) => {
      const matching = staged.files
        .filter((f) => f.name.startsWith(query.prefix))
        .sort((a, b) => a.name.localeCompare(b.name));
      const start = Number(query.pageToken ?? 0);
      const page = matching.slice(start, start + Math.min(query.maxResults, 1000));
      staged.calls.push({ prefix: query.prefix, maxResults: query.maxResults, returned: page.length });
      const end = start + page.length;
      return [page, end < matching.length ? { pageToken: String(end) } : null];
    },
  });
}
