/**
 * BUT-2169: a block hides what the two people shared with each other, in BOTH
 * directions, and an unblock brings it back. Nothing is deleted.
 *
 * **Why the server moves the recipient instead of a rule hiding the row.** The
 * inbox is a `list` query on `sharedToUserIds`. A rule that looked up
 * `blocks/{sharer}_{me}` per candidate row cannot be proven for a query, so
 * Firestore would refuse the whole inbox. Taking the person out of the field
 * the inbox queries on makes the row disappear for a hand-rolled client too.
 *
 * **What "held" means.** The person leaves `sharedToUserIds` and enters
 * `blockHeldUserIds` on the same row, and `blockHeld.<uid>` keeps what has to
 * come back on unblock: their `members/{uid}` row, if the share wrote one, and
 * for a recipe the `'direct'` grant the share wrote and, when that was their
 * only grant, their `memberPermissions` entry, which is what actually grants
 * read access to the recipe document. A `group:` grant stays, because a block
 * does not touch groups.
 *
 * **Scope (Malin, 2026-10-07, F2):** one-off shares in `shared_content` and the
 * `'direct'` grant the same share wrote on a recipe. Groups, live shared lists and
 * realtime menus are not touched.
 *
 * **Release** happens only when no block remains in either direction and both
 * accounts still exist. Each row re-reads both `blocks` documents inside its
 * own transaction, so an unblock racing a re-block cannot release a row the
 * new block should hold, and a hold arriving after the block is gone holds
 * nothing. The account cascade clears every held entry naming the
 * erased user BEFORE it deletes their `blocks` rows (step
 * `shared_content_block_held`), so the release that deletion fires finds
 * nothing to put back for them. A hold that commits after that scrub would
 * still be released by the same deletion, so the cascade also writes
 * `erasures_in_progress/{uid}` before its first step, and every row's release
 * reads that marker for both people inside its transaction.
 *
 * Region: inherits europe-west1 via `setGlobalOptions` in index.ts.
 */

import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { Collections } from "../shared/collections";
import { hashUid } from "../shared/hash-uid";
import { accountExists, isUsableUidSegment } from "./sync-block-mirror";

export const SHARED_CONTENT = "shared_content";

/**
 * Rows read per direction per event. Blocks are rare and two people rarely
 * share hundreds of things, so the cap is a bound on hostile input, not on use.
 * Above it the pass works on the first rows and logs at ERROR; the blocker's
 * own app still hides the rest of what the blocked person shared.
 */
export const MAX_ROWS_PER_DIRECTION = 500;

/**
 * How long an erasure marker stops a release, which bounds what a cascade that
 * crashed can block. Longer than `HOLD_TIMEOUT_SECONDS`, so a release already
 * running when the account is erased finishes inside it.
 */
export const ERASURE_MARKER_WINDOW_MS = 60 * 60 * 1000;

/** Whether a marker read from `erasures_in_progress` still stops a release. */
export function erasureUnderway(
  marker: admin.firestore.DocumentSnapshot,
  nowMs: number = Date.now(),
): boolean {
  if (!marker.exists) return false;
  const startedAtMs = marker.get("startedAtMs");
  // A marker whose start cannot be read is honoured: releasing on a row an
  // erasure is clearing is the outcome the marker exists to stop.
  if (typeof startedAtMs !== "number") return true;
  return nowMs - startedAtMs < ERASURE_MARKER_WINDOW_MS;
}

/** What `blockHeld.<uid>` stores, so the unblock can put it back. */
export interface HeldEntry {
  member: admin.firestore.DocumentData | null;
  /** Their permission when held; null when the hold took nothing from the recipe. */
  recipePermission: string | null;
  /** Whether the recipe recorded grants for them, so the unblock adds `'direct'` back. */
  recipeHadGrants: boolean;
}

const DIRECT = "direct";

type Db = admin.firestore.Firestore;
type Ref = admin.firestore.DocumentReference;

/**
 * A uid used inside a dotted update key. The Admin SDK refuses a string field
 * path holding `.`, `~`, `*`, `/`, `[` or `]`, and the `blocks` rules do not
 * constrain `blockedId`'s shape, so anything outside the alphabet Firebase Auth
 * issues is refused here rather than thrown on every retry.
 */
export function isUsableUidKey(value: unknown): value is string {
  return (
    isUsableUidSegment(value) &&
    typeof value === "string" &&
    /^[A-Za-z0-9_-]{1,128}$/.test(value)
  );
}

function blockRefs(db: Db, a: string, b: string): [Ref, Ref] {
  return [
    db.collection(Collections.blocks).doc(`${a}_${b}`),
    db.collection(Collections.blocks).doc(`${b}_${a}`),
  ];
}

function recipeRefFor(db: Db, row: admin.firestore.DocumentData): Ref | null {
  if (row.contentType !== "recipe") return null;
  const owner = row.sharedByUserId;
  const recipeId = row.originalRecipeId;
  if (!isUsableUidSegment(owner) || !isUsableUidSegment(recipeId)) return null;
  return db
    .collection(Collections.users)
    .doc(owner)
    .collection(Collections.recipes)
    .doc(recipeId);
}

/** Moves [other] out of one row, and out of the recipe that row shared. */
export async function holdRow(db: Db, rowRef: Ref, other: string): Promise<boolean> {
  const memberRef = rowRef.collection("members").doc(other);
  return db.runTransaction(async (tx) => {
    const row = await tx.get(rowRef);
    const data = row.data();
    if (!data) return false;
    const recipients = Array.isArray(data.sharedToUserIds) ? data.sharedToUserIds : [];
    if (!recipients.includes(other)) return false;
    const sharer = data.sharedByUserId;
    if (!isUsableUidKey(sharer)) return false;
    const [ab, ba] = blockRefs(db, sharer, other);
    const blocks = [await tx.get(ab), await tx.get(ba)];
    if (!blocks.some((b) => b.exists)) return false;

    const member = await tx.get(memberRef);
    const recipeRef = recipeRefFor(db, data);
    const recipe = recipeRef ? await tx.get(recipeRef) : null;
    const social = recipe?.exists ? recipe.get("socialData") : undefined;
    const permission = social?.memberPermissions?.[other];
    const grants = social?.grants?.[other];
    // The sharer is the recipe's owner; holding the owner's own entry would
    // orphan the recipe, and a sharer is never the `other` of their own row.
    const ownsRecipe = social?.ownerId === sharer;
    const hasGrants = Array.isArray(grants);
    // Without a `'direct'` grant this person reads the recipe through a group,
    // and a block leaves groups alone. A missing grants record is not read as
    // direct (BUT-1797).
    const takesRecipe =
      ownsRecipe &&
      typeof permission === "string" &&
      hasGrants &&
      (grants as unknown[]).includes(DIRECT);
    const otherGrants = takesRecipe
      ? (grants as unknown[]).filter((g) => g !== DIRECT)
      : [];

    const entry: HeldEntry = {
      member: member.exists ? (member.data() ?? null) : null,
      recipePermission: takesRecipe ? permission : null,
      recipeHadGrants: takesRecipe,
    };

    tx.update(rowRef, {
      sharedToUserIds: admin.firestore.FieldValue.arrayRemove(other),
      blockHeldUserIds: admin.firestore.FieldValue.arrayUnion(other),
      [`blockHeld.${other}`]: entry,
    });
    if (member.exists) tx.delete(memberRef);
    if (recipeRef && takesRecipe) {
      tx.update(
        recipeRef,
        otherGrants.length > 0
          ? { [`socialData.grants.${other}`]: otherGrants }
          : {
            [`socialData.memberPermissions.${other}`]: admin.firestore.FieldValue.delete(),
            [`socialData.grants.${other}`]: admin.firestore.FieldValue.delete(),
          },
      );
    }
    return true;
  });
}

/** Puts [other] back on one row, and back on the recipe that row shared. */
export async function releaseRow(db: Db, rowRef: Ref, other: string): Promise<boolean> {
  const memberRef = rowRef.collection("members").doc(other);
  return db.runTransaction(async (tx) => {
    const row = await tx.get(rowRef);
    const data = row.data();
    if (!data) return false;
    const held = Array.isArray(data.blockHeldUserIds) ? data.blockHeldUserIds : [];
    if (!held.includes(other)) return false;
    const sharer = data.sharedByUserId;
    if (!isUsableUidKey(sharer)) return false;
    const [ab, ba] = blockRefs(db, sharer, other);
    const blocks = [await tx.get(ab), await tx.get(ba)];
    if (blocks.some((b) => b.exists)) return false;
    const markers = [
      await tx.get(db.collection(Collections.erasuresInProgress).doc(sharer)),
      await tx.get(db.collection(Collections.erasuresInProgress).doc(other)),
    ];
    if (markers.some((m) => erasureUnderway(m))) return false;

    const entry = (data.blockHeld?.[other] ?? null) as HeldEntry | null;
    const recipeRef =
      entry?.recipePermission != null ? recipeRefFor(db, data) : null;
    const recipe = recipeRef ? await tx.get(recipeRef) : null;
    const social = recipe?.exists ? recipe.get("socialData") : undefined;
    // A recipe deleted or handed to someone else while the block stood keeps
    // what it has now; restoring onto it would grant access its new owner
    // never gave.
    const restoreRecipe = social?.ownerId === sharer;

    tx.update(rowRef, {
      sharedToUserIds: admin.firestore.FieldValue.arrayUnion(other),
      blockHeldUserIds: admin.firestore.FieldValue.arrayRemove(other),
      [`blockHeld.${other}`]: admin.firestore.FieldValue.delete(),
    });
    if (entry?.member) tx.set(memberRef, entry.member);
    if (recipeRef && restoreRecipe && entry) {
      // Only what the hold took: a permission someone set while the block
      // stood is newer than the one saved here, and other grants stay.
      const restore: admin.firestore.UpdateData<admin.firestore.DocumentData> = {};
      if (social?.memberPermissions?.[other] === undefined) {
        restore[`socialData.memberPermissions.${other}`] = entry.recipePermission;
      }
      if (entry.recipeHadGrants) {
        const current = social?.grants?.[other];
        const kept = Array.isArray(current) ? current : [];
        if (!kept.includes(DIRECT)) {
          restore[`socialData.grants.${other}`] = [...kept, DIRECT];
        }
      }
      if (Object.keys(restore).length > 0) tx.update(recipeRef, restore);
    }
    return true;
  });
}

async function rowsBetween(
  db: Db,
  sharer: string,
  field: "sharedToUserIds" | "blockHeldUserIds",
  other: string,
): Promise<Ref[]> {
  const snap = await db
    .collection(SHARED_CONTENT)
    .where("sharedByUserId", "==", sharer)
    .where(field, "array-contains", other)
    .limit(MAX_ROWS_PER_DIRECTION + 1)
    .get();
  if (snap.size > MAX_ROWS_PER_DIRECTION) {
    logger.error("[block-shares] row cap exceeded; pass is partial", {
      sharer_hash: hashUid(sharer),
      field,
      cap: MAX_ROWS_PER_DIRECTION,
    });
  }
  return snap.docs.slice(0, MAX_ROWS_PER_DIRECTION).map((d) => d.ref as Ref);
}

/** Hides what [a] and [b] shared with each other, both directions. */
export async function holdPair(db: Db, a: string, b: string): Promise<number> {
  let held = 0;
  for (const [sharer, other] of [[a, b], [b, a]]) {
    for (const ref of await rowsBetween(db, sharer, "sharedToUserIds", other)) {
      if (await holdRow(db, ref, other)) held++;
    }
  }
  return held;
}

async function blockStands(db: Db, a: string, b: string): Promise<boolean> {
  const [ab, ba] = await Promise.all([
    db.collection(Collections.blocks).doc(`${a}_${b}`).get(),
    db.collection(Collections.blocks).doc(`${b}_${a}`).get(),
  ]);
  return ab.exists || ba.exists;
}

/**
 * Brings back what [a] and [b] shared, once nothing keeps it hidden.
 *
 * Returns null when it declined: a block still stands in either direction, or
 * one of the accounts is gone.
 */
export async function releasePair(
  db: Db,
  a: string,
  b: string,
  /** Seam, as on `rebuildMirrorFor`: the unit suite has no Auth emulator. */
  ownerExists: (uid: string) => Promise<boolean> = accountExists,
): Promise<number | null> {
  if (await blockStands(db, a, b)) return null;
  if (!(await ownerExists(a)) || !(await ownerExists(b))) return null;
  let released = 0;
  for (const [sharer, other] of [[a, b], [b, a]]) {
    for (const ref of await rowsBetween(db, sharer, "blockHeldUserIds", other)) {
      if (await releaseRow(db, ref, other)) released++;
    }
  }
  return released;
}

/**
 * The two people a `blocks` event is about, or null when the row cannot name
 * them safely. Read from the fields, like `blockedIdFromEvent`.
 */
export function pairFromEvent(
  before: admin.firestore.DocumentData | undefined,
  after: admin.firestore.DocumentData | undefined,
): { blockerId: string; blockedId: string } | null {
  const source = after ?? before;
  const blockerId = source?.blockerId;
  const blockedId = source?.blockedId;
  if (!isUsableUidKey(blockerId) || !isUsableUidKey(blockedId)) return null;
  if (blockerId === blockedId) return null;
  return { blockerId, blockedId };
}

/** What one `blocks` event did: a hold count, a release count, or nothing. */
export type BlockEventOutcome =
  | { kind: "held"; count: number }
  | { kind: "released"; count: number | null }
  | { kind: "skipped" };

/** The trigger's body, with the database and Auth check passed in. */
export async function handleBlockEvent(
  db: Db,
  before: admin.firestore.DocumentData | undefined,
  after: admin.firestore.DocumentData | undefined,
  ownerExists: (uid: string) => Promise<boolean> = accountExists,
): Promise<BlockEventOutcome> {
  const pair = pairFromEvent(before, after);
  if (pair === null) {
    // A throw here would retry forever on a row that can never be read.
    logger.error("[block-shares] event carried no usable pair; skipping");
    return { kind: "skipped" };
  }
  const { blockerId, blockedId } = pair;
  if (after !== undefined) {
    const count = await holdPair(db, blockerId, blockedId);
    logger.info("[block-shares] held", { held: count });
    return { kind: "held", count };
  }
  const count = await releasePair(db, blockerId, blockedId, ownerExists);
  logger.info("[block-shares] release", {
    released: count,
    declined: count === null,
  });
  return { kind: "released", count };
}

/** Two directions of at most `MAX_ROWS_PER_DIRECTION` sequential transactions. */
export const HOLD_TIMEOUT_SECONDS = 300;

export const holdSharesOnBlock = onDocumentWritten(
  {
    document: `${Collections.blocks}/{blockId}`,
    // Every step is idempotent (a row already moved is skipped), so a retry
    // repeats nothing and a dropped event would leave a share visible.
    retry: true,
    timeoutSeconds: HOLD_TIMEOUT_SECONDS,
  },
  async (event) => {
    await handleBlockEvent(
      admin.firestore(),
      event.data?.before?.data(),
      event.data?.after?.data(),
    );
  },
);
