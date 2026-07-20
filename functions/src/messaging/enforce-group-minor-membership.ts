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

/**
 * Upper bound on participants this trigger will read. Far above any real group
 * chat, so it never fires legitimately; it exists purely to bound the billed
 * read fan-out (and its retry replays) on a tampered create.
 */
export const MAX_GROUP_PARTICIPANTS = 100;

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

/**
 * True only for a uid this trigger can safely use BOTH ways: as a document id
 * (`users/${uid}`) AND as a FIELD-PATH segment
 * (`participantDisplayNames.${uid}`). Those are different constraint sets, and
 * the field-path one is stricter — that is the trap this guards.
 *
 * Why it must be strict: a uid containing a dot or a field-path metacharacter
 * is a legal document id but an ILLEGAL field path. `update()` then rejects it
 * with INVALID_ARGUMENT (grpc 3, NOT the NOT_FOUND 5 handled below), which
 * `retry: true` replays deterministically forever while the minor is never
 * removed — the child-safety gate fails OPEN, in exactly the tampered-client
 * threat model this trigger exists for. A dotted uid is dangerous even when it
 * does NOT throw: `participantDisplayNames.a.b` addresses a NESTED map rather
 * than the literal key "a.b", so the removed minor's name and avatar would
 * survive the cut.
 *
 * Real Firebase Auth uids are alphanumeric, so rejecting these forms drops only
 * entries that cannot correspond to a real account (and which therefore confer
 * no membership — the rules test `uid in participantIds`).
 */
export function isValidDocId(v: unknown): v is string {
  return (
    typeof v === "string" &&
    v.length > 0 &&
    v !== "." &&
    v !== ".." &&
    !/^__.*__$/.test(v) &&
    // "/" breaks the doc path; ".[]*`" break the field path. Rejecting the
    // union keeps the uid safe for both uses.
    !/[/.[\]*`]/.test(v) &&
    // Bytes, not characters: the 1500-byte doc-id cap is busted by a multibyte
    // uid at ~500 chars. Only "" and "/" throw client-side; the rest of these
    // forms are rejected by the BACKEND when getAll() runs, which under
    // retry:true is a deterministic error that repeats forever.
    Buffer.byteLength(v, "utf8") <= 1500
  );
}

export const enforceGroupMinorMembership = onDocumentCreated(
  // retry:true — v2 event triggers do NOT retry by default, so a transient
  // failure in the reads/writes below is logged and dropped, leaving a
  // non-friend-added minor in the group (fail-OPEN on a child-safety gate).
  // Every write here is idempotent on re-run — participantIds is set to the
  // absolute `remaining` value (not arrayRemove), the per-uid FieldValue.delete()s
  // and snap.ref.delete() are no-ops on a missing doc, and the membership-mirror
  // deletes are already best-effort — with ONE exception: `update()` throws
  // NOT_FOUND on a deleted conversation, a DETERMINISTIC error that retry would
  // repeat forever (a poison pill re-billing the read fan-out). That case is
  // caught explicitly below, so only genuinely transient failures reach a retry.
  { document: "conversations/{conversationId}", retry: true },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data();
    const conversationId = event.params.conversationId;

    const rawParticipantIds: unknown[] = Array.isArray(data?.participantIds)
      ? (data.participantIds as unknown[])
      : [];

    // Drop uids Firestore would reject as a doc id (see isValidDocId) so the
    // reads below cannot throw and strand the gate fail-OPEN.
    const participantIds: string[] = rawParticipantIds.filter(isValidDocId);

    // Only GROUP conversations need this gate. 1:1 (size 2) is handled by
    // firestore.rules; size < 2 is degenerate.
    //
    // The size is judged on the RAW list, never the sanitised one. Sanitising
    // first would reopen the very gap this trigger exists to close:
    // `passesMinorDmGate` in firestore.rules fires only at raw size()==2, so a
    // tampered client can pad participantIds with one junk entry
    // (["attacker","minor","__x__"]) — rules see 3 and skip the DM gate, while
    // a filtered count here would see 2 and return early, leaving the minor
    // protected by NEITHER layer. Sanitise for the USE (path building), gate on
    // the RAW shape.
    const isGroup = data?.isGroup === true || rawParticipantIds.length > 2;
    if (!isGroup || rawParticipantIds.length <= 2) return;

    // firestore.rules caps neither participantIds' length nor the create rate,
    // so a tampered client can post thousands of uids and make the getAll
    // fan-out below arbitrarily expensive — and retry:true replays it. Refuse
    // implausibly large groups outright and alert instead: no real group
    // approaches this, and returning early costs one log line rather than an
    // unbounded, self-repeating read bill.
    if (participantIds.length > MAX_GROUP_PARTICIPANTS) {
      logger.error(
        "[enforceGroupMinorMembership] implausible group size; refusing the read fan-out",
        { conversationId, participantCount: participantIds.length },
      );
      return;
    }

    // A malformed creatorId is treated as NO creator ⇒ the fail-safe path
    // (unknown creator ⇒ remove minors) rather than a
    // `users/${creatorId}/friends/...` path build that would throw.
    const rawCreatorId: unknown = data?.metadata?.creatorId;
    const creatorId = isValidDocId(rawCreatorId) ? rawCreatorId : null;

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
    // viable — delete it rather than leave a one-person shell. Everyone's
    // mirror is then stale, not just the removed minors', so the survivors are
    // folded into the cleanup list below; otherwise the lone remaining member
    // keeps a conversation-list row pointing at a deleted doc, which they can
    // open but never dismiss.
    const mirrorsToClear = [...toRemove];
    if (remaining.length < 2) {
      mirrorsToClear.push(...remaining);
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
      try {
        await snap.ref.update(update);
      } catch (e) {
        // NOT_FOUND (grpc code 5): the conversation was deleted between the
        // create that fired this trigger and this write. The access cut we were
        // about to make is moot — there is no group left to remove the minor
        // from — so this is success, not failure. Rethrowing would hand
        // retry:true a deterministic error to loop on forever. Deliberately
        // does NOT return: the removed minors' membership mirrors below still
        // point at the (now deleted) conversation and must still be cleaned.
        if ((e as { code?: number }).code !== 5) throw e;
        logger.info(
          "[enforceGroupMinorMembership] conversation already deleted; skipping the cut, still clearing mirrors",
          { conversationId },
        );
      }
    }

    // Best-effort cleanup of each removed minor's per-user membership mirror so
    // the group stops surfacing in their conversation list. Never throws out of
    // the trigger — the participantIds removal above is the real access cut.
    await Promise.all(
      [...new Set(mirrorsToClear)].map((uid) =>
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
