/**
 * BUT-1725: Backfill `contributorUserIds` on existing
 * `unified_shared_shopping_lists` docs.
 *
 * **LIFECYCLE — REMOVE THIS FILE WHEN:**
 *   1. An invocation returns `hasMore: false` AND `failed: 0`, AND
 *   2. A 30-day soak window has passed with no account-deletion audit row
 *      reporting `residual_data_detected` for a shared shopping list.
 *
 * After both, delete this file, drop the `backfillSharedListContributors`
 * export from `functions/src/index.ts`, and remove the matching
 * `test:backfill-shared-list-contributors` script entry. One-shot migration
 * code is liability after the soak; every new item write unions the field
 * client-side via `ShoppingRepositoryRoutingModule`.
 *
 * **Why the field exists.** Account erasure locates a user's shared shopping
 * lists by `memberPermissions.<uid>` or `ownerId`. A user who LEFT a list, or
 * was removed from one, has neither — while every item they added still
 * carries `addedByDisplayName` and `addedByUserId`. Firestore cannot query
 * fields nested inside an array of maps, so those lists were unreachable and
 * the departed member's name stayed on them indefinitely. `contributorUserIds`
 * is a flat, `array-contains`-queryable trail of everyone who has ever written
 * an item here; it is append-only, so leaving cannot erase it.
 *
 * **Reconstruction.** For a pre-existing doc the trail is rebuilt from the uids
 * still visible on the document: the owner (only while still a member — see
 * `reconstructContributors`), the last-activity stamp, and the four per-item
 * identity fields. That is necessarily a LOWER BOUND — a member whose every item
 * was subsequently deleted leaves no trace to recover, and no amount of scanning
 * invents one. It is nonetheless a strict improvement: every uid that still has a
 * name attached to it becomes reachable by erasure, which is exactly the set that
 * matters.
 *
 * **Resuming (BUT-1725 review).** This is a full-collection scan with NO filter,
 * so an already-migrated doc stays matched and keeps burning the per-invocation
 * scan cap. Without a caller-supplied cursor, invocation 2 re-reads exactly what
 * invocation 1 read and the corpus beyond `BATCH_SIZE * MAX_BATCHES_PER_INVOCATION`
 * is never reached, while every run still answers `success: true` (measured: a
 * 20,000-doc corpus stalled at 10,350 across three runs). So the protocol is the
 * one `backfillCanonicalRatings` uses: while `hasMore` is true, re-invoke with
 * `{ startAfter: <nextCursor> }` until it returns false. Do NOT copy
 * `backfillRecipeCommentsDenorm`, which has this defect.
 *
 * **Idempotent:** docs whose `contributorUserIds` already covers the
 * reconstructed set are skipped, so a re-run after a partial failure is free.
 * The write itself is a per-doc TRANSACTION that re-derives the missing uids from
 * a fresh read: the erasure cascade may scrub this very list between the page read
 * and the write, and a blind `arrayUnion` built from the stale page would re-add
 * the uids the cascade had just removed.
 *
 * **Region:** europe-west1 (Butlery convention).
 *
 * **Auth:** admin custom claim required.
 */

import { onCall, CallableRequest, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";

import { requireAdmin } from "../shared/require-admin";

const REGION = "europe-west1";
const COLLECTION = "unified_shared_shopping_lists";
// Page size for the id-ordered scan. Kept at the BUT-458 backfill's value; it is
// no longer a writeBatch cap, since each stamp is now its own transaction.
const BATCH_SIZE = 450;
const MAX_BATCHES_PER_INVOCATION = 23;
// Per-doc transactions are serialised only by this pool: a whole page run
// strictly sequentially would spend ~450 round-trips against a 540s budget.
const WRITE_CONCURRENCY = 25;

/** Per-item fields that carry a raw uid on a shared list. */
const ITEM_UID_FIELDS = [
  "addedByUserId",
  "purchasedByUserId",
  "assignedToUserId",
  "lastModifiedByUserId",
] as const;

/** Sentinel written by the erasure cascade in place of a deleted uid. */
const ANONYMIZED = "deleted";

interface BackfillRequest {
  /** Scan + log without writing. Default false. */
  dryRun?: boolean;
  /** Hard ceiling on docs to process this invocation. Default 10000. */
  maxLists?: number;
  /**
   * Resume cursor — the `nextCursor` of the previous invocation. Omit on the
   * first call. Without it the scan restarts at the first document id every
   * time and can never reach past one invocation's cap.
   */
  startAfter?: string;
}

interface BackfillResponse {
  /** False when any document failed to stamp; re-run (already-done docs skip). */
  success: boolean;
  migrated: number;
  skipped: number;
  /** Documents whose stamping transaction threw. Their uids are NOT reachable. */
  failed: number;
  batchesProcessed: number;
  hasMore: boolean;
  /** Pass as `startAfter` on the next invocation while `hasMore`; else null. */
  nextCursor: string | null;
}

/**
 * A caller-supplied cursor is interpolated straight into a Firestore query
 * bound, so it gets the full document-id validator rather than a "non-empty,
 * no slash" half-check: `.`/`..`/`__reserved__` are equally deterministic
 * throws, and the byte length (not `.length`) is what Firestore actually caps.
 */
export function assertValidCursor(value: unknown): string {
  const invalid = (why: string): never => {
    throw new HttpsError("invalid-argument", `startAfter ${why}`);
  };
  if (typeof value !== "string" || value.length === 0) {
    return invalid("must be a non-empty document id string");
  }
  if (Buffer.byteLength(value, "utf8") > 1500) {
    return invalid("exceeds Firestore's 1500-byte document-id limit");
  }
  if (value.includes("/")) return invalid('must not contain "/"');
  if (value === "." || value === "..") return invalid('must not be "." or ".."');
  if (/^__.*__$/.test(value)) {
    return invalid("must not match the reserved __*__ pattern");
  }
  return value;
}

/**
 * Every uid still visible on [data], excluding both the `"deleted"` sentinel the
 * cascade writes AND the identifiers it deliberately RETAINS — re-adding either
 * would resurrect a handle erasure had removed.
 */
export function reconstructContributors(
  data: admin.firestore.DocumentData
): string[] {
  const uids = new Set<string>();
  const add = (value: unknown) => {
    if (typeof value === "string" && value.length > 0 && value !== ANONYMIZED) {
      uids.add(value);
    }
  };

  // `ownerId` only while the owner is still a member. The cascade DELETES
  // `memberPermissions.<uid>` but deliberately KEEPS `ownerId` raw — the rules
  // read it to decide who may write the list, so nulling it would orphan the
  // list for everyone else (`account-deletion-cascade.ts` scrubs only
  // `ownerDisplayName`). A bare `add(data.ownerId)` therefore re-creates an
  // already-erased uid in `contributorUserIds`, which `firestore.rules` makes
  // APPEND-ONLY for every client including the owner: no client write and no
  // future cascade run (that account's cascade already finished) could ever
  // remove it again. Membership is the handle that actually tracks erasure —
  // the create rule pins a live owner into `memberPermissions`.
  const perms = (data.memberPermissions ?? {}) as Record<string, unknown>;
  if (
    typeof data.ownerId === "string" &&
    Object.prototype.hasOwnProperty.call(perms, data.ownerId)
  ) {
    add(data.ownerId);
  }
  add(data.lastActivityByUserId);

  const items = data.items;
  if (Array.isArray(items)) {
    for (const raw of items) {
      if (!raw || typeof raw !== "object") continue;
      const item = raw as Record<string, unknown>;
      for (const field of ITEM_UID_FIELDS) add(item[field]);
    }
  }

  return [...uids];
}

/** The uids [data] should carry but does not yet. Empty ⇒ nothing to write. */
export function missingContributors(
  data: admin.firestore.DocumentData
): string[] {
  const existing = Array.isArray(data.contributorUserIds)
    ? (data.contributorUserIds as unknown[]).filter(
        (v): v is string => typeof v === "string"
      )
    : [];
  return reconstructContributors(data).filter((uid) => !existing.includes(uid));
}

type StampOutcome = "written" | "raced" | "failed";

/**
 * Stamp one list. The missing set is re-derived INSIDE the transaction from a
 * fresh read, so a cascade scrub landing between the page read and this write
 * wins: its anonymized items and deleted member key yield an empty set and we
 * write nothing, instead of re-adding the uids it just erased.
 */
async function stampContributors(
  db: admin.firestore.Firestore,
  ref: admin.firestore.DocumentReference
): Promise<StampOutcome> {
  try {
    return await db.runTransaction(async (tx) => {
      const fresh = await tx.get(ref);
      // Gone, or another writer got there first: both are success, not failure.
      if (!fresh.exists) return "raced";
      const missing = missingContributors(fresh.data() ?? {});
      if (missing.length === 0) return "raced";
      // arrayUnion, never a whole-array set: a member may be ticking items on
      // this very list, and their live write must not be clobbered.
      tx.update(ref, {
        contributorUserIds: admin.firestore.FieldValue.arrayUnion(...missing),
      });
      return "written";
    });
  } catch (err) {
    // Code and name, never `err` or `err.message`: firebase-functions unwraps
    // only a POSITIONAL Error, and a Firestore message can embed a document
    // path. The list id is a random doc id, not an identifier of a person.
    logger.error("[backfill-shared-list-contributors] stamp failed", {
      listId: ref.id,
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
    return "failed";
  }
}

/** Run [fn] over [items] with at most [limit] in flight, preserving order. */
async function mapWithConcurrency<T, R>(
  items: T[],
  limit: number,
  fn: (item: T) => Promise<R>
): Promise<R[]> {
  const out = new Array<R>(items.length);
  let next = 0;
  const worker = async (): Promise<void> => {
    for (;;) {
      const index = next++;
      if (index >= items.length) return;
      out[index] = await fn(items[index]);
    }
  };
  await Promise.all(
    Array.from({ length: Math.min(limit, items.length) }, worker)
  );
  return out;
}

/**
 * Iterate the shared-list collection paginated by document id, stamping the
 * reconstructed trail. Exposed for unit testing alongside the callable wrapper.
 */
export async function runBackfill(
  db: admin.firestore.Firestore,
  options: { dryRun: boolean; maxLists: number; startAfter?: string }
): Promise<BackfillResponse> {
  const { dryRun, maxLists } = options;

  let migrated = 0;
  let skipped = 0;
  let failed = 0;
  let batchesProcessed = 0;
  let totalScanned = 0;
  let lastDocId: string | null =
    options.startAfter === undefined
      ? null
      : assertValidCursor(options.startAfter);
  // Set at every exhaustion break. Inferring completion from
  // `batchesProcessed >= MAX` instead reports `hasMore: true` precisely when the
  // final allowed page was SHORT — i.e. when the corpus IS done — and the
  // lifecycle gate at the top of this file could then never open.
  let reachedEnd = false;

  while (batchesProcessed < MAX_BATCHES_PER_INVOCATION) {
    let query = db
      .collection(COLLECTION)
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(BATCH_SIZE);
    if (lastDocId) query = query.startAfter(lastDocId);

    const snapshot = await query.get();
    if (snapshot.empty) {
      reachedEnd = true;
      break;
    }

    const needWrite: admin.firestore.DocumentReference[] = [];
    for (const doc of snapshot.docs) {
      totalScanned += 1;
      if (missingContributors(doc.data()).length === 0) {
        skipped += 1;
        continue;
      }
      if (dryRun) {
        migrated += 1;
        continue;
      }
      needWrite.push(doc.ref);
    }

    if (needWrite.length > 0) {
      const outcomes = await mapWithConcurrency(
        needWrite,
        WRITE_CONCURRENCY,
        (ref) => stampContributors(db, ref)
      );
      for (const outcome of outcomes) {
        if (outcome === "written") migrated += 1;
        else if (outcome === "failed") failed += 1;
        else skipped += 1;
      }
    }

    lastDocId = snapshot.docs[snapshot.docs.length - 1].id;
    batchesProcessed += 1;

    if (snapshot.size < BATCH_SIZE) {
      reachedEnd = true;
      break;
    }
    if (totalScanned >= maxLists) break;
  }

  const hasMore = !reachedEnd;
  const nextCursor = hasMore ? lastDocId : null;

  logger.info("[backfill-shared-list-contributors] pass complete", {
    dryRun,
    migrated,
    skipped,
    failed,
    batchesProcessed,
    hasMore,
  });

  return {
    success: failed === 0,
    migrated,
    skipped,
    failed,
    batchesProcessed,
    hasMore,
    nextCursor,
  };
}

export const backfillSharedListContributors = onCall(
  { region: REGION, timeoutSeconds: 540, memory: "512MiB" },
  async (request: CallableRequest<BackfillRequest>) => {
    requireAdmin(request);
    return runBackfill(admin.firestore(), {
      dryRun: request.data?.dryRun === true,
      maxLists: request.data?.maxLists ?? 10000,
      startAfter: request.data?.startAfter,
    });
  }
);
