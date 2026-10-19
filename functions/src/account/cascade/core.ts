import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { commitInChunks } from "../../shared/batch-update";

/**
 * One thing kept, and why — the Art. 12(4) notice is rendered from this.
 *
 * Declared here rather than beside the hold logic in `moderation/erasure-hold.ts`
 * so that file can import from this one and this one need not import back: a
 * value cycle between the cascade and the hold is avoidable, so it is avoided.
 */
export interface RetainedRecord {
  /** Collection the retained rows live in. */
  resourceType: string;
  /** GDPR article the retention rests on. */
  legalBasis: string;
  /** When the hold lifts at the latest, regardless of the case. */
  holdUntil: admin.firestore.Timestamp;
  /**
   * True when the hold was placed without the predicate being answered — the
   * query threw, or the hold write did.
   *
   * It crosses to the client because the Art. 12(4) notice must not assert a
   * pending review as fact when nothing measured one — Malin's call, 2026-09-09
   * (BUT-2047). The sweep treats both kinds identically; only the wording
   * differs.
   */
  provisional: boolean;
}

export interface DeletionResult {
  deletedCollections: string[];
  failedCollections: string[];
  errors: string[];
  /**
   * Records LAWFULLY kept, with the article they rest on (BUT-2046 follow-up).
   *
   * Deliberately separate from `failedCollections`: a disclosed refusal under
   * Art. 17(3) is not a failure, and expressing one as `gdprCompliant: false`
   * would say "something went wrong" about a decision that went right — and
   * nothing could ever clear the flag.
   */
  retained: RetainedRecord[];
}

export type Step = () => Promise<boolean>;

/**
 * Run one cascade step, recording its outcome on `result`. Never throws —
 * a step exception is logged and rolled into `failedCollections`.
 */
export async function runStep(
  name: string,
  result: DeletionResult,
  step: Step,
): Promise<void> {
  try {
    const ok = await step();
    if (ok) {
      result.deletedCollections.push(name);
    } else {
      result.failedCollections.push(name);
    }
  } catch (err) {
    result.failedCollections.push(name);
    result.errors.push(
      `${name}: ${err instanceof Error ? err.message : String(err)}`,
    );
    logger.error(`[deletion-cascade] step ${name} failed`, { err });
  }
}

/** Batch-delete every doc, chunked at `BATCH_LIMIT` (500) ops/batch. */
export async function batchDeleteAll(
  db: admin.firestore.Firestore,
  docs: admin.firestore.QueryDocumentSnapshot[],
): Promise<void> {
  if (docs.length === 0) return;
  await commitInChunks(db, docs, (batch, doc) => batch.delete(doc.ref), {
    label: "batchDeleteAll",
    strict: false,
  });
}

/**
 * BUT-2338: a strict scrub over rows other people can delete — a comment or
 * rating whose recipe `onRecipeDeleted` cleans up, or whose author removes it;
 * a share or a recipe its owner deletes (BUT-2344). One such delete between
 * the read and the commit rejects the whole chunk with NOT_FOUND, so a
 * NOT_FOUND re-reads once and writes what is still there. Any other failure,
 * a second one, or a throwing re-read throws.
 */
export async function scrubWithOneReread(
  db: admin.firestore.Firestore,
  rows: admin.firestore.QueryDocumentSnapshot[],
  reread: () => Promise<admin.firestore.QueryDocumentSnapshot[]>,
  mutate: (
    batch: admin.firestore.WriteBatch,
    doc: admin.firestore.QueryDocumentSnapshot,
  ) => void,
  label: string,
): Promise<void> {
  const write = (docs: admin.firestore.QueryDocumentSnapshot[]) =>
    commitInChunks(db, docs, mutate, { label, strict: true });

  try {
    await write(rows);
    return;
  } catch (err) {
    if ((err as { code?: number | string }).code !== 5) throw err;
  }
  await write(await reread());
}

/**
 * The re-read for `scrubWithOneReread` over one capped query: throws over the
 * cap, and keeps only the rows `keep` accepts, as the first read did.
 */
export function cappedReread(
  read: () => Promise<admin.firestore.QuerySnapshot>,
  cap: number,
  label: string,
  keep: (doc: admin.firestore.QueryDocumentSnapshot) => boolean = () => true,
): () => Promise<admin.firestore.QueryDocumentSnapshot[]> {
  return async () => {
    const again = await read();
    if (again.size > cap) {
      throw new Error(`${label}: re-read over the cap (${again.size})`);
    }
    return again.docs.filter(keep);
  };
}

/** One fixed update map for every row, as the BUT-2338 scrubs write. */
export function updateWith(
  update: Record<string, unknown>,
): (
  batch: admin.firestore.WriteBatch,
  doc: admin.firestore.QueryDocumentSnapshot,
) => void {
  return (batch, doc) => {
    batch.update(doc.ref, update);
  };
}
