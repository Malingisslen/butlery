/**
 * BUT-1626 (BUT-674): group-conversation minor-safety gate.
 *
 * Firestore rules gate 1:1 DMs with a minor (`passesMinorDmGate`), but they
 * cannot iterate a group's `participantIds` list, so a non-friend who adds a
 * minor to a GROUP conversation is not blocked by rules. This trigger closes
 * that gap server-side: on every conversation create, for a group (size > 2),
 * any participant who is a minor AND was NOT added by one of their friends is
 * removed from the conversation.
 *
 * "Added by a friend" is checked against the conversation's `metadata.creatorId`
 * (the only identity the created doc records) via the same directional friend
 * doc the rules use: `users/{minor}/friends/{creatorId}`.
 *
 * Defense-in-depth, not the primary control: a minor is default-private
 * (BUT-1454), so a non-friend cannot even discover them to add them. This
 * trigger backstops a tampered/legacy client that adds a minor anyway. Because
 * `participantIds` is immutable after create (firestore.rules), a create trigger
 * is sufficient — group membership cannot grow via client update.
 *
 * Cost: one invocation per conversation create; reads bounded to group creates
 * only (one users/{uid} read per non-creator participant, plus one friend-doc
 * read per minor). 1:1 and non-group creates return before any read.
 */

import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";

export interface MinorRemovalInput {
  /** All participant uids on the created conversation. */
  participantIds: string[];
  /** `metadata.creatorId`, or null when the doc records no creator. */
  creatorId: string | null;
  /** uid -> whether that account is a compliant minor (isMinor:true). */
  isMinor: Record<string, boolean>;
  /** uid -> whether the creator is a friend of that (minor) uid. */
  creatorIsFriendOf: Record<string, boolean>;
}

/**
 * Pure decision core (unit-tested): which participants must be removed to
 * protect minors from a non-friend group add.
 *
 * A participant is removed when it is a minor, is not the creator, and either
 * (a) the creator is unknown — we cannot prove a friendship, so fail SAFE for
 * the child — or (b) the creator is not a friend of that minor. Adults and the
 * creator are never removed.
 */
export function computeMinorsToRemove(input: MinorRemovalInput): string[] {
  const { participantIds, creatorId, isMinor, creatorIsFriendOf } = input;
  const removals: string[] = [];
  for (const uid of participantIds) {
    if (uid === creatorId) continue; // the creator is not a "non-friend add"
    if (!isMinor[uid]) continue; // only minors are protected
    if (!creatorId) {
      // No identifiable creator ⇒ cannot verify a friendship ⇒ remove the
      // minor (fail-safe). Only reachable for a group that already contains a
      // minor, which a default-private minor makes near-impossible in practice.
      removals.push(uid);
      continue;
    }
    if (!creatorIsFriendOf[uid]) removals.push(uid);
  }
  return removals;
}

/** Reads `isMinor` for each candidate uid via a single batched getAll. */
async function readIsMinor(
  db: admin.firestore.Firestore,
  uids: string[],
): Promise<Record<string, boolean>> {
  const out: Record<string, boolean> = {};
  if (uids.length === 0) return out;
  const refs = uids.map((u) => db.doc(`users/${u}`));
  const snaps = await db.getAll(...refs);
  snaps.forEach((snap, i) => {
    out[uids[i]] = snap.exists && snap.get("isMinor") === true;
  });
  return out;
}

/** Reads, for each minor uid, whether `creatorId` is their friend. */
async function readCreatorFriendships(
  db: admin.firestore.Firestore,
  minorUids: string[],
  creatorId: string | null,
): Promise<Record<string, boolean>> {
  const out: Record<string, boolean> = {};
  if (!creatorId || minorUids.length === 0) return out;
  const refs = minorUids.map((u) => db.doc(`users/${u}/friends/${creatorId}`));
  const snaps = await db.getAll(...refs);
  snaps.forEach((snap, i) => {
    out[minorUids[i]] = snap.exists;
  });
  return out;
}

export const enforceGroupMinorMembership = onDocumentCreated(
  { document: "conversations/{conversationId}" },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data();
    const conversationId = event.params.conversationId;

    const participantIds: string[] = Array.isArray(data?.participantIds)
      ? (data.participantIds as unknown[]).filter(
          (v): v is string => typeof v === "string",
        )
      : [];

    // Only GROUP conversations need this gate. 1:1 (size 2) is handled by
    // firestore.rules; size < 2 is degenerate. isGroup flag OR size > 2.
    const isGroup = data?.isGroup === true || participantIds.length > 2;
    if (!isGroup || participantIds.length <= 2) return;

    const creatorId =
      typeof data?.metadata?.creatorId === "string"
        ? (data.metadata.creatorId as string)
        : null;

    const db = admin.firestore();
    const candidates = participantIds.filter((u) => u !== creatorId);
    const isMinor = await readIsMinor(db, candidates);
    const minorUids = candidates.filter((u) => isMinor[u]);
    const creatorIsFriendOf = await readCreatorFriendships(
      db,
      minorUids,
      creatorId,
    );

    const toRemove = computeMinorsToRemove({
      participantIds,
      creatorId,
      isMinor,
      creatorIsFriendOf,
    });
    if (toRemove.length === 0) return;

    const remaining = participantIds.filter((u) => !toRemove.includes(u));

    logger.warn("[enforceGroupMinorMembership] removing non-friend-added minors", {
      conversationId,
      removedCount: toRemove.length,
      hadCreator: creatorId !== null,
      remaining: remaining.length,
    });

    // If the group collapses below 2 members, the conversation is no longer
    // viable — delete it rather than leave a one-person shell.
    if (remaining.length < 2) {
      await snap.ref.delete();
    } else {
      const update: Record<string, unknown> = {
        participantIds: remaining,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      for (const uid of toRemove) {
        update[`participantDisplayNames.${uid}`] =
          admin.firestore.FieldValue.delete();
        update[`participantAvatarUrls.${uid}`] =
          admin.firestore.FieldValue.delete();
        update[`lastReadTimestamps.${uid}`] =
          admin.firestore.FieldValue.delete();
      }
      await snap.ref.update(update);
    }

    // Best-effort cleanup of each removed minor's per-user membership mirror so
    // the group stops surfacing in their conversation list. Never throws out of
    // the trigger — the participantIds removal above is the real access cut.
    await Promise.all(
      toRemove.map((uid) =>
        db
          .doc(`users/${uid}/conversation_memberships/${conversationId}`)
          .delete()
          .catch((e) =>
            logger.error(
              "[enforceGroupMinorMembership] membership cleanup failed",
              { conversationId, error: String(e) },
            ),
          ),
      ),
    );
  },
);
