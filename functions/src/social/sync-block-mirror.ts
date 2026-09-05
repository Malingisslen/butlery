/**
 * BUT-1917: the server-written mirror of "who has blocked me".
 *
 * **Why a mirror exists at all.** `firestore.rules` cannot iterate a group's
 * participant list — the file says so at the BUT-674 helpers, and that is why
 * the existing `isNotBlockedBy()` helper works only where there is exactly ONE
 * known counterparty (a friend request's `toUserId`, a comment's
 * `recipeOwnerId`). A poll in a group has N counterparties. Checking each in
 * turn would cost N document accesses, and Firestore caps a rule evaluation at
 * 10 — over the cap the write is DENIED, not merely slow. So a per-counterparty
 * check does not degrade at scale, it breaks: a nine-person group would stop
 * accepting votes entirely. One mirror document turns N lookups into 1.
 *
 * **Why the server writes it.** `blocks` is client-written — `firestore.rules`
 * lets the blocker create the row. A client-written mirror would therefore be
 * forgeable by exactly the person it constrains: the blocked user could empty
 * their own mirror and vote again. This trigger is the only writer, and the
 * rules deny every client write to the mirror.
 *
 * **Direction.** The mirror lists INCOMING blocks only — if A blocks B, B's
 * mirror names A, so B's vote is refused in every room A is in, while A keeps
 * voting normally. A symmetric list would silence the BLOCKER in every group
 * they share, which is a penalty for having used a safety feature.
 *
 * **Recompute, never delta.** Every event rebuilds the whole list from the
 * `blocks` collection. That is structural rather than a promise to be careful:
 * a projection recomputed from source cannot drift permanently — a duplicate
 * event is idempotent, and an out-of-order pair heals on the next event. The
 * `sourceRev` guard below stops a slow older invocation from overwriting a
 * newer one in the window before that healing happens.
 *
 * Region: inherits europe-west1 via `setGlobalOptions` in index.ts.
 */

import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { Collections } from "../shared/collections";
import { hashUid } from "../shared/hash-uid";

/**
 * Cap on one mirror's entry count.
 *
 * The list is chosen by OTHER PEOPLE — anyone may block this user and nothing
 * rate-limits it — so this is the roster cap's argument, not the poll-vote
 * one. Reaching it needs that many DISTINCT accounts, because the block
 * document id is `{blockerId}_{blockedId}` and one blocker yields one row.
 *
 * Above the cap the mirror is written TRUNCATED and flagged, and the overflow
 * is logged at ERROR. That direction is deliberate and it is the weaker one:
 * a truncated mirror UNDER-blocks, so a blocker past the cap stops being
 * enforced. The alternative — refusing to write — freezes a mirror that is
 * already stale, which under-blocks too and additionally stops reflecting
 * unblocks. Truncating keeps the document current for the 1000 it holds.
 */
export const MAX_MIRROR_ENTRIES = 1000;

/**
 * How many source rows one reconciliation pass reads, per side.
 *
 * `blocks` is client-written and, as this file says of the mirror cap, nothing
 * rate-limits it — so an uncapped `.get()` here materialises a client-chosen
 * number of documents into a 256MiB task. Every other sweep in this change caps
 * and says so when it hits the cap; this one had been the exception.
 *
 * Above the cap the pass is PARTIAL rather than absent, and logs that it is:
 * reconciling some mirrors beats reconciling none, and the task runs last in
 * the weekly chain so an overrun costs nothing else. The failure to avoid is a
 * pass that reconciled a prefix and reported a clean sweep.
 */
export const MAX_RECONCILE_SOURCE_ROWS = 5000;

/** The mirror document for one user. */
export function mirrorRef(
  db: admin.firestore.Firestore,
  uid: string,
): admin.firestore.DocumentReference {
  // Spelled out as a literal `users/{uid}/block_mirror/current` chain rather
  // than assembled from a string, so the account-cascade drift scanner —
  // which greps for this shape — can see that the collection exists and owes
  // a deleter. Assembling the path would make the mirror invisible to it.
  return db
    .collection(Collections.users)
    .doc(uid)
    .collection(Collections.blockMirror)
    .doc(Collections.blockMirrorDoc);
}

/**
 * The list a mirror SHOULD hold, read from `blocks`.
 *
 * Split out so the reconciliation can compare without writing: a pass that
 * rewrote every mirror in order to discover whether it needed rewriting would
 * cost a write per user per week on a collection that is almost always already
 * correct.
 */
export async function expectedMirrorFor(
  db: admin.firestore.Firestore,
  blockedId: string,
): Promise<string[]> {
  const snap = await db
    .collection(Collections.blocks)
    .where("blockedId", "==", blockedId)
    .limit(MAX_MIRROR_ENTRIES + 1)
    .get();
  const docs =
    snap.size > MAX_MIRROR_ENTRIES ? snap.docs.slice(0, MAX_MIRROR_ENTRIES) : snap.docs;
  return docs
    .map((d) => d.get("blockerId"))
    .filter((v): v is string => typeof v === "string" && v.length > 0)
    .sort();
}

/**
 * Rebuild one user's mirror from `blocks`, and write it if this event is not
 * older than what is already stored.
 *
 * `sourceRev` is the event's own timestamp in millis. The compare is done
 * inside a transaction because two events for the same user can be in flight
 * at once — an unblock landing while a block's recompute is still running
 * would otherwise resolve on arrival order rather than on event order.
 *
 * Returns whether a write happened, so tests can tell "skipped as stale" from
 * "wrote the same thing".
 */
export async function rebuildMirrorFor(
  db: admin.firestore.Firestore,
  blockedId: string,
  sourceRev: number,
): Promise<boolean> {
  const snap = await db
    .collection(Collections.blocks)
    .where("blockedId", "==", blockedId)
    .limit(MAX_MIRROR_ENTRIES + 1)
    .get();

  const truncated = snap.size > MAX_MIRROR_ENTRIES;
  const docs = truncated ? snap.docs.slice(0, MAX_MIRROR_ENTRIES) : snap.docs;

  // Read the FIELD, never the document id. The id is `{blockerId}_{blockedId}`
  // and splitting it guesses where the boundary is; the field is what the
  // create rule pins.
  const blockedByUserIds = docs
    .map((d) => d.get("blockerId"))
    .filter((v): v is string => typeof v === "string" && v.length > 0)
    .sort();

  if (truncated) {
    logger.error("[block-mirror] entry cap exceeded; mirror truncated", {
      uid_hash: hashUid(blockedId),
      kept: blockedByUserIds.length,
      cap: MAX_MIRROR_ENTRIES,
    });
  }

  const ref = mirrorRef(db, blockedId);
  const ownerRef = db.collection(Collections.users).doc(blockedId);
  return db.runTransaction(async (tx) => {
    // The OWNER first. An Admin-SDK delete fires this trigger exactly like a
    // client delete, so the account cascade's own `deleteBlocks` step schedules
    // a rebuild for the very user being erased. Tier 2 then sweeps the mirror
    // and `probeResidualData` passes — and a trigger landing seconds later
    // re-creates a document whose PATH carries the erased uid, with nothing
    // left to remove it and an audit row already saying the erasure was clean.
    //
    // Checking the owner INSIDE the transaction is what makes this a decision
    // about the state at write time rather than at read time.
    const owner = await tx.get(ownerRef);
    if (!owner.exists) {
      // Deleted, or never existed. Leaving the document absent is also what
      // the cascade's sweep intended.
      //
      // For a NEVER-created owner this costs something real: the mirror's
      // beneficiaries are the BLOCKERS, not its owner, so their blocks go
      // unenforced until the weekly pass rebuilds it. Accepted because the
      // alternative — writing a mirror under a uid with no account — is the
      // resurrection this check exists to stop.
      const orphan = await tx.get(ref);
      if (orphan.exists) tx.delete(ref);
      return false;
    }

    const current = await tx.get(ref);
    const storedRev = current.exists ? current.get("sourceRev") : undefined;
    if (typeof storedRev === "number" && storedRev > sourceRev) {
      // A NEWER event already wrote this mirror. Strictly greater, not >=: two
      // events can share a millisecond, and skipping an equal one would drop a
      // real change rather than a stale one.
      return false;
    }
    tx.set(ref, {
      blockedByUserIds,
      sourceRev,
      truncated,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return true;
  });
}

/**
 * Whether a value can be used as a Firestore path SEGMENT.
 *
 * `firestore.rules` pins `blockerId` to the caller and pins the composite
 * document id — and says NOTHING about the SHAPE of `blockedId`. So that field
 * is free-form client input which this file then turns into a path segment, and
 * `blocks/{myUid}_.` is a legal document any authenticated account can write.
 *
 * A segment the SDK rejects makes `mirrorRef` throw INVALID_ARGUMENT. What that
 * costs depends on the caller, and BOTH callers are hostile-input paths:
 * inside the trigger, `retry: true` turns it into a permanent redelivery loop;
 * inside the weekly reconciliation it aborts the pass, so one planted row stops
 * every OTHER user's mirror from being reconciled, every week, indefinitely.
 *
 * Exported and shared for that reason. It first lived inside
 * `blockedIdFromEvent`, which left the reconciliation reading the same field
 * with none of the same protection — the sibling that a fix to one call site
 * leaves behind.
 */
export function isUsableUidSegment(value: unknown): value is string {
  if (typeof value !== "string" || value.length === 0) return false;
  // `/` cannot occur in a document id, so it is unreachable through the id —
  // but both callers read the FIELD, which carries no such guarantee.
  return (
    value !== "." &&
    value !== ".." &&
    !value.includes("/") &&
    !/^__.*__$/.test(value) &&
    Buffer.byteLength(value, "utf8") <= 1500
  );
}

/**
 * Which user's mirror this event affects.
 *
 * Read from the document FIELDS, taking `after` when the row exists and
 * `before` when it was deleted (an unblock). Both carry `blockedId` because
 * the create rule requires it and the row is immutable.
 */
export function blockedIdFromEvent(
  before: admin.firestore.DocumentData | undefined,
  after: admin.firestore.DocumentData | undefined,
): string | null {
  const value = after?.blockedId ?? before?.blockedId;
  // Rejecting lands on the same log-and-return branch as a missing field, which
  // is the only exit that does not retry forever.
  return isUsableUidSegment(value) ? value : null;
}

/**
 * Which uids a reconciliation pass must visit.
 *
 * Two sources, and BOTH are needed. Every uid named by a live `blocks` row
 * covers "a block exists that the mirror is missing". Every uid that already
 * owns a mirror covers the opposite and less obvious case: the blocks were all
 * removed while the trigger was down, so no `blocks` row names that user any
 * more and a blocks-only pass would never visit them — leaving a mirror that
 * blocks people who have unblocked them.
 *
 * The mirror side is a `collectionGroup` read, which the unit fake does not
 * model, so this function has no unit case — including the `isUsableUidSegment`
 * skip below, which is therefore UNPINNED: reverting it reddens nothing.
 */
export async function collectUidsToReconcile(
  db: admin.firestore.Firestore,
): Promise<{ uids: Set<string>; partial: boolean }> {
  const uids = new Set<string>();
  let partial = false;

  const blocks = await db
    .collection(Collections.blocks)
    .limit(MAX_RECONCILE_SOURCE_ROWS + 1)
    .get();
  if (blocks.size > MAX_RECONCILE_SOURCE_ROWS) {
    // Reported, not thrown: an incomplete pass is better than none, and the
    // task runs LAST in the weekly chain so nothing else is at risk. What must
    // not happen silently is the pass looking clean while it reconciled a
    // prefix.
    partial = true;
    logger.error("[block-mirror] reconciliation source too large; pass is partial", {
      rows: blocks.size,
      cap: MAX_RECONCILE_SOURCE_ROWS,
    });
  }
  for (const doc of blocks.docs) {
    const blockedId = doc.get("blockedId");
    if (isUsableUidSegment(blockedId)) {
      uids.add(blockedId);
    } else if (blockedId !== undefined) {
      // Skipped rather than allowed to throw: `mirrorRef` would raise
      // INVALID_ARGUMENT and abort the whole pass, so one planted row would
      // stop every other user's mirror being reconciled for good.
      // HASHED: a `blocks` document id is `{blockerId}_{blockedId}`, so the
      // raw id carries two uids into a log that outlives the account and that
      // no erasure cascade reaches — on a path a client plants at will.
      logger.error("[block-mirror] unusable blockedId in blocks; skipping", {
        doc_id_hash: hashUid(doc.id),
      });
    }
  }

  const mirrors = await db
    .collectionGroup(Collections.blockMirror)
    .limit(MAX_RECONCILE_SOURCE_ROWS + 1)
    .get();
  if (mirrors.size > MAX_RECONCILE_SOURCE_ROWS) {
    partial = true;
    logger.error("[block-mirror] more mirrors than one pass reads; pass is partial", {
      rows: mirrors.size,
      cap: MAX_RECONCILE_SOURCE_ROWS,
    });
  }
  for (const doc of mirrors.docs) {
    // `users/{uid}/block_mirror/current` — the uid is the grandparent id.
    const uid = doc.ref.parent.parent?.id;
    if (typeof uid === "string" && uid.length > 0) uids.add(uid);
  }

  return { uids, partial };
}

/**
 * Rebuild every named mirror, and report how many were WRONG.
 *
 * The count is the point. A reconciliation that silently repairs is how a
 * three-month trigger outage goes unnoticed — the mirrors end up correct at
 * every weekly checkpoint and nobody learns that they were wrong in between.
 * So this compares before repairing and logs a non-zero repair count at ERROR,
 * which is a signal about the TRIGGER rather than about this pass.
 *
 * It reuses `rebuildMirrorFor`, so the `sourceRev` guard applies here exactly
 * as it does to a trigger event — that is deliberate and is the answer to
 * "does the guard hold between the reconciliation and the trigger, not just
 * between two triggers". A reconciliation stamped older than the newest
 * trigger write skips, rather than resurrecting the state it computed from a
 * read it took before that write landed.
 */
export async function reconcileMirrors(
  db: admin.firestore.Firestore,
  uids: Iterable<string>,
  sourceRev: number,
): Promise<{
  checked: number;
  repaired: number;
  skipped: number;
  failed: number;
}> {
  let checked = 0;
  let repaired = 0;
  let skipped = 0;
  let failed = 0;

  for (const uid of uids) {
    checked++;
    try {
      const before = await mirrorRef(db, uid).get();
      const storedIds = before.exists ? before.get("blockedByUserIds") : undefined;
      const stored = Array.isArray(storedIds)
        ? storedIds.slice().sort().join(",")
        : null;

      // Compare BEFORE writing. A pass that rewrote every mirror to find out
      // whether it needed rewriting would cost a write per user per week for a
      // collection that is almost always already correct, and it would make the
      // repair count unmeasurable without a third read.
      const expected = await expectedMirrorFor(db, uid);
      if (stored !== null && stored === expected.join(",")) continue;

      const wrote = await rebuildMirrorFor(db, uid, sourceRev);
      if (wrote) {
        repaired++;
      } else {
        // Not "nothing was wrong". `rebuildMirrorFor` also returns false when a
        // NEWER trigger event owns the document, and when the owner is gone —
        // in which case it DELETED an orphaned mirror, which is a repair by any
        // other name. Folding those into `repaired: 0` would make the pass log
        // "found no drift" on a run that changed something.
        skipped++;
      }
    } catch (err) {
      // Per uid, like every leg of `probeResidualData`. Without this, one
      // planted row or one transient contention abandons every REMAINING user
      // in the set — and this pass is the only net under a control whose
      // failure shows on no screen.
      failed++;
      logger.error("[block-mirror] reconciliation failed for one user", {
        uid_hash: hashUid(uid),
        errName: err instanceof Error ? err.name : typeof err,
      });
    }
  }

  if (repaired > 0 || failed > 0) {
    logger.error("[block-mirror] reconciliation did not find a clean sweep", {
      checked,
      repaired,
      skipped,
      failed,
    });
  } else {
    logger.info("[block-mirror] reconciliation found no drift", {
      checked,
      skipped,
    });
  }

  return { checked, repaired, skipped, failed };
}

/**
 * How far the reconciliation holds its own revision BACK.
 *
 * The trigger stamps `event.time`, a server-assigned commit time. This pass has
 * no event, so it stamps its own instance clock — a DIFFERENT clock. An
 * instance running ahead would write a future revision, and every genuinely
 * newer trigger write would then be skipped as stale: a frozen mirror on a
 * safety control, repaired by nothing until the clocks drift back.
 *
 * A repair must never outrank a real event, so the pass deliberately stamps
 * itself in the past. Holding back too far costs only that a trigger event from
 * within the window wins over this pass — the safe direction, since the trigger
 * read `blocks` more recently.
 */
export const RECONCILE_REV_SKEW_MS = 60 * 60 * 1000;

/**
 * Weekly safety net for the trigger.
 *
 * The mirror is a safety control whose failure is SILENT — a missing entry lets
 * a blocked person keep acting, and nothing on any screen says so — which is
 * what earns a scheduled pass rather than trusting `retry: true` alone.
 *
 * A TASK in the existing weekly chain rather than its own `onSchedule`, per the
 * standing rule in `maintenance-dispatchers.ts`: Cloud Scheduler bills per job,
 * and this needs neither its own frequency nor failure isolation. It also
 * inherits that chain's declared timeout, which a standalone job would not have
 * had — the v2 default is 60 seconds.
 */
export async function runReconcileBlockMirrors(): Promise<void> {
  const db = admin.firestore();
  const { uids, partial } = await collectUidsToReconcile(db);
  const result = await reconcileMirrors(
    db,
    uids,
    Date.now() - RECONCILE_REV_SKEW_MS,
  );

  // ONE verdict for the week. Without it the two halves each log their own
  // line, and a run that read a truncated source could still print
  // "found no drift" — two true sentences adding up to a false impression.
  const clean = !partial && result.failed === 0 && result.repaired === 0;
  const summary = { ...result, partial };
  if (clean) {
    logger.info("[block-mirror] weekly pass: clean", summary);
  } else {
    logger.error("[block-mirror] weekly pass: NOT clean", summary);
  }
}

export const syncBlockMirror = onDocumentWritten(
  {
    document: `${Collections.blocks}/{blockId}`,
    // The mirror is a safety control: a dropped event leaves a blocked person
    // able to act until the weekly reconciliation catches it, so a failed
    // invocation must be retried rather than logged and forgotten.
    retry: true,
  },
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    const blockedId = blockedIdFromEvent(before, after);

    if (blockedId === null) {
      // Neither side carried the field. Nothing identifies whose mirror to
      // rebuild, and retrying cannot change that, so this returns rather than
      // throwing — a throw with `retry: true` would loop forever.
      logger.error("[block-mirror] event carried no blockedId; skipping", {
        block_id_present: event.params.blockId !== undefined,
      });
      return;
    }

    const sourceRev = Date.parse(event.time);
    await rebuildMirrorFor(
      admin.firestore(),
      blockedId,
      Number.isNaN(sourceRev) ? Date.now() : sourceRev,
    );
  },
);
