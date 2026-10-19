import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { batchUpdateRefs } from "../../shared/batch-update";
import { Collections } from "../../shared/collections";
import {
  batchDeleteAll,
  scrubWithOneReread,
  cappedReread,
  updateWith,
} from "./core";

/**
 * Cap on one erasure's sweep of OTHER people's block mirrors.
 *
 * Same contract as the sibling caps and the same DECLINE-rather-than-truncate
 * choice, for the roster cap's reason rather than the poll-vote one: the row
 * count here is chosen by how many people this user blocked, which is their own
 * doing — but each mirror belongs to somebody else, and a half-finished sweep
 * would leave the erased uid inside a live safety control on an unknown subset
 * of them. Declining reports itself; truncating would not.
 */
export const MAX_MIRROR_SWEEP_ROWS = 2000;

/**
 * BUT-1917: take the erased uid out of everybody else's block mirror.
 *
 * The mirror is a PROJECTION of `blocks`, and `deleteBlocks` has already
 * removed the rows it is derived from. In principle `syncBlockMirror` would
 * rebuild each affected mirror on its own, because an Admin-SDK delete fires
 * the same trigger a client delete does. This step exists because that is not
 * good enough for an erasure: the trigger is asynchronous and may land after
 * the callable has returned and after `probeResidualData` has already decided
 * the account is clean, so an Art. 17 guarantee that depends on it is a
 * guarantee about scheduling. Doing it here makes the erasure synchronous, and
 * the trigger then rebuilds an already-correct document.
 *
 * Probe-covered on both halves. The deleted user's OWN mirror is reached by the
 * enumeration of what is left under `users/{uid}`; this cross-user half has its
 * own uncapped `count()` leg on the same collection-group index this sweep
 * uses, beside the poll-vote leg it is modelled on.
 */
export async function deleteBlockMirrors(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const snap = await db
    .collectionGroup(Collections.blockMirror)
    .where("blockedByUserIds", "array-contains", uid)
    .limit(MAX_MIRROR_SWEEP_ROWS + 1)
    .get();

  if (snap.size > MAX_MIRROR_SWEEP_ROWS) {
    logger.error(
      "[deletion-cascade] implausible block-mirror count; not sweeping",
      { uid_prefix: uid.slice(0, 6), rows: snap.size },
    );
    return false;
  }

  // Per document with `arrayRemove`, not a recompute: the mirror belongs to
  // another living user, and rebuilding it from `blocks` here would rewrite
  // THEIR document from this cascade's view of the world. Removing one entry
  // is the smallest change that erases the uid, and it leaves every other
  // blocker of that user untouched.
  await batchUpdateRefs(
    snap.docs.map((d) => d.ref),
    () => ({
      blockedByUserIds: admin.firestore.FieldValue.arrayRemove(uid),
      // Stamped so a `syncBlockMirror` rebuild that read `blocks` BEFORE
      // `deleteBlocks` committed cannot land afterwards and put the uid back:
      // its own `sourceRev` guard then sees a newer revision and skips. Without
      // this the sweep is invisible to that guard, because `arrayRemove` alone
      // leaves the revision untouched.
      sourceRev: Date.now(),
    }),
    db,
  );
  return true;
}

/**
 * Cap on one erasure's `blocks` sweep, per direction.
 *
 * The two directions do NOT have the same cap argument, and saying so is the
 * point of writing it down.
 *
 * `blockerId == uid` is self-chosen: only this user can create a row naming
 * themselves as blocker (`firestore.rules` pins
 * `request.resource.data.blockerId == request.auth.uid` on create), so the
 * count is theirs, and the cap is the self-inflation guard.
 *
 * `blockedId == uid` is chosen by OTHER PEOPLE. Any authenticated account may
 * block this user, and nothing rate-limits it, so this leg has the roster
 * cap's argument rather than the poll-vote one: a peer can seat rows keyed on
 * this user. That is the leg the cap is really for.
 *
 * Above the cap the leg DECLINES rather than truncating, and the step reports
 * itself incomplete — `gdprCompliant: false`. Declining is strictly less
 * erasure for the same alarm, which is the choice `deleteOwnRosterRows` already
 * made.
 *
 * Recovery is a human running `admin/reset-user-data.ts`, which names this
 * collection. That script was inert from 2026-03-19 to 2026-09-05 —
 * `tag_configs` was in both the delete and keep lists, and the overlap guard
 * exited before Phase 1 (BUT-2010, fixed 2026-09-05). Read that file's header
 * before running it: it is a whole-project clean slate rather than a per-user
 * remedy. For one declined sweep the recovery is a human with the Admin SDK.
 */
export const MAX_BLOCK_SWEEP_ROWS = 2000;

/**
 * BUT-1917: the `blocks` collection, BOTH directions.
 *
 * Nothing in this cascade has ever touched it. `blocks/{blockerId}_{blockedId}`
 * is written by the client (`FirebaseBlockRepository.blockUser`) and no server
 * code read the collection before this, so an erased account's uid survived
 * erasure inside every block row it was party to — in the DOCUMENT ID as well
 * as in the fields, which is why a projection would not have been enough.
 *
 * `probeResidualData` did not see it either, and the reason is simply that no
 * leg of that probe named the collection — it queries top-level collections by
 * field as well as enumerating subcollections, so being top-level was never the
 * obstacle. Two legs ship in this same change, because a sweep that reports on
 * itself through `commitInChunks(strict:false)` needs an independent check.
 *
 * BOTH directions are erased, and the second one deserves its own sentence
 * because it deletes a row another living user created. A block naming a
 * deleted account is a decision about an account that no longer exists: it can
 * never be acted on again, and it carries the erased uid. Art. 17 reaches it;
 * the blocker loses nothing they can use.
 *
 * The client method that used to claim this job, `deleteAllBlocksForUser`, is
 * removed in the same change. It had no caller, and it could not have worked:
 * `firestore.rules` lets only the BLOCKER delete a row, so its second query's
 * deletes would have been refused and taken the whole batch with them.
 */
export async function deleteBlocks(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  let complete = true;

  for (const field of ["blockerId", "blockedId"] as const) {
    const snap = await db
      .collection(Collections.blocks)
      .where(field, "==", uid)
      .limit(MAX_BLOCK_SWEEP_ROWS + 1)
      .get();

    if (snap.size > MAX_BLOCK_SWEEP_ROWS) {
      logger.error(
        "[deletion-cascade] implausible block count; not sweeping",
        { uid_prefix: uid.slice(0, 6), field, rows: snap.size },
      );
      // `continue`, not `return`: the two directions are independent, and half
      // an erasure beats none as long as the step still reports itself
      // incomplete. Same shape as `deletePollVotes`.
      complete = false;
      continue;
    }

    await batchDeleteAll(db, snap.docs);
  }

  return complete;
}

/** Cap on one erasure's sweep of held shares (BUT-2169). Declines above it. */
export const MAX_BLOCK_HELD_SWEEP_ROWS = 2000;

/**
 * BUT-2169: the held state a block left on `shared_content` that involves the
 * erased uid, both ways round: the uid HELD on someone else's share
 * (`blockHeldUserIds` plus the `blockHeld.<uid>` entry, which keeps their
 * member row and recipe permission), and other people held on a share the
 * erased user made.
 *
 * Runs BEFORE tier 1. Tier 1 deletes the user's `blocks` rows, and each delete
 * fires `holdSharesOnBlock`'s release, which puts held people back on the
 * shares; with nothing held left, that release has nothing to write. It runs
 * again after tier 1 for a hold that committed while the cascade was running.
 */
export async function scrubBlockHeldShares(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  if (uid.includes(".")) {
    // A dotted key would address a different path; Auth never issues one.
    logger.error("[deletion-cascade] uid unusable as a map key; not sweeping held shares");
    return false;
  }
  const readHeld = () =>
    db
      .collection("shared_content")
      .where("blockHeldUserIds", "array-contains", uid)
      .limit(MAX_BLOCK_HELD_SWEEP_ROWS + 1)
      .get();
  const snap = await readHeld();
  if (snap.size > MAX_BLOCK_HELD_SWEEP_ROWS) {
    logger.error("[deletion-cascade] implausible held-share count; not sweeping", {
      uid_prefix: uid.slice(0, 6),
      rows: snap.size,
    });
    return false;
  }
  try {
    // First, so a decline on the owned half below cannot leave this user held
    // for tier 1's release to put back.
    await scrubWithOneReread(
      db,
      snap.docs,
      cappedReread(readHeld, MAX_BLOCK_HELD_SWEEP_ROWS, "scrubBlockHeldShares"),
      updateWith({
        blockHeldUserIds: admin.firestore.FieldValue.arrayRemove(uid),
        [`blockHeld.${uid}`]: admin.firestore.FieldValue.delete(),
      }),
      "scrubBlockHeldShares",
    );
  } catch (err) {
    logger.error("[deletion-cascade] scrubBlockHeldShares failed", {
      uid_prefix: uid.slice(0, 6),
      rows: snap.size,
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
    return false;
  }

  const readOwned = () =>
    db
      .collection("shared_content")
      .where("sharedByUserId", "==", uid)
      .limit(MAX_BLOCK_HELD_SWEEP_ROWS + 1)
      .get();
  const owned = await readOwned();
  if (owned.size > MAX_BLOCK_HELD_SWEEP_ROWS) {
    logger.error("[deletion-cascade] implausible owned-share count; not sweeping", {
      uid_prefix: uid.slice(0, 6),
      rows: owned.size,
    });
    return false;
  }
  const holdsSomeone = (doc: admin.firestore.QueryDocumentSnapshot) => {
    const held = doc.get("blockHeldUserIds");
    return Array.isArray(held) && held.length > 0;
  };
  const ownedHeld = owned.docs.filter(holdsSomeone);
  try {
    // Tier 1 deletes these rows; until then a release would rewrite member
    // rows that name the erased user as the one who added them.
    await scrubWithOneReread(
      db,
      ownedHeld,
      cappedReread(
        readOwned,
        MAX_BLOCK_HELD_SWEEP_ROWS,
        "scrubBlockHeldShares:owned",
        holdsSomeone,
      ),
      updateWith({
        blockHeldUserIds: admin.firestore.FieldValue.delete(),
        blockHeld: admin.firestore.FieldValue.delete(),
      }),
      "scrubBlockHeldShares:owned",
    );
  } catch (err) {
    logger.error("[deletion-cascade] scrubBlockHeldShares owned half failed", {
      uid_prefix: uid.slice(0, 6),
      rows: ownedHeld.length,
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
    return false;
  }
  logger.info("[deletion-cascade] scrubBlockHeldShares", {
    uid_prefix: uid.slice(0, 6),
    rows: snap.size,
    owned_rows: ownedHeld.length,
  });
  return true;
}
