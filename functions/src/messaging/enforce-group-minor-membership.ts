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
 * read per minor; and on the collapse and concurrent-delete paths ONLY, a
 * bounded roster read of at most MAX_ROSTER_ROWS + 1 documents plus at most
 * MAX_ROSTER_ROWS deletes). 1:1 and non-group creates return before any read.
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

/**
 * Mirrors `FirestoreCollections.participants` on the client, and the identical
 * declaration in `leave-group-conversation.ts`.
 *
 * Honest about what this buys: a SECOND local copy protects nothing against a
 * rename — it just moves the literal. The real home is
 * `functions/src/shared/collections.ts`, which declares itself the single source
 * of truth and does not yet carry `participants`; `admin/reset-user-data.ts`
 * still uses a bare literal. Consolidating all three is a separate change; this
 * constant exists so the two uses in THIS file cannot drift from each other.
 */
const CONVERSATION_PARTICIPANTS = "participants";

/**
 * Above this many roster rows the collapse branch refuses to delete the
 * conversation. Generous on purpose — a plausibility bound against a SEEDED
 * roster, not a correctness bound on real groups. Nothing actually caps a
 * group's size (neither the conversations create rule nor
 * `createGroupConversation` checks it), but a conversation carrying more than
 * [MAX_GROUP_PARTICIPANTS] VALID participants is refused by this trigger before
 * this helper is reachable at all. Valid, not raw — that guard runs on the
 * `isValidDocId`-filtered list, so a document carrying 400 raw ids of which 100
 * survive the filter does reach here. No consequence either way, because the
 * `.limit()` below is what actually bounds the read; said precisely because
 * raw-vs-sanitised is load-bearing 250 lines down, where conflating them was a
 * real bypass.
 */
export const MAX_ROSTER_ROWS = MAX_GROUP_PARTICIPANTS * 5;

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

/**
 * Attempts to delete every row under `conversations/{id}/participants`.
 * Returns true only if the roster is provably clear afterwards.
 *
 * **The caller's invariant: never delete the conversation while roster rows may
 * survive.** Deleting the parent is the write that makes `parentDoc() == null`
 * true, which re-opens the bootstrap branch in firestore.rules over whatever is
 * left. So this function never throws — it reports, and a false answer means the
 * caller must leave the parent standing. Never throws on any error shape the
 * SDK can produce — the read and every delete are caught. (A hostile `code`
 * accessor that throws would escape, since an optional chain guards `null`, not
 * a throwing getter. Firestore rejects with plain objects, so that is a note,
 * not a hole.) A live parent that no longer names the
 * evicted members denies the roster to everyone, so the shell is the safe
 * failure, and the child-safety cut still lands via the update branch.
 *
 * BOUNDED READ, not just a bounded delete. `listDocuments()` buffers every ref
 * before any cap could be applied, and this path is writable by any signed-in
 * user while the parent is absent (`rosterUnclaimed()`) with no
 * `rateLimitWrite` on it — so an unbounded enumeration inside a `retry:true`
 * trigger is a self-repeating read bill, the same one the MAX_GROUP_PARTICIPANTS
 * guard already refuses. `.limit(N + 1).get()` bounds the read itself. A plain
 * query is enough here: `listDocuments()` is only required to surface PHANTOM
 * parents (rows that exist solely as ancestors of a subcollection), and no rules
 * path permits a subcollection under a roster row. It does return children whose
 * parent document is absent, which is exactly the state this guards.
 *
 * ENUMERATED, never derived from a uid list. The roster's writer
 * (`ConversationParticipantModule.addParticipants`) iterates
 * `participantDisplayNames.entries`, while every uid list in this trigger comes
 * from `participantIds` filtered by `isValidDocId`. A uid that filter rejects —
 * `a.b` — is still a legal document id, and the bootstrap branch
 * (`rosterUnclaimed()`) authorises on the PARENT alone; the only conjunct that
 * mentions `participantId` merely pins the payload field to the path segment,
 * and constrains the id's shape not at all. So a row can exist that no uid list
 * here can name.
 */
export async function tryClearRoster(
  db: admin.firestore.Firestore,
  conversationId: string,
): Promise<boolean> {
  let snap: admin.firestore.QuerySnapshot;
  try {
    snap = await db
      .collection(`conversations/${conversationId}/${CONVERSATION_PARTICIPANTS}`)
      .limit(MAX_ROSTER_ROWS + 1)
      .get();
  } catch (e) {
    // The read is the one `await` here not already covered by a per-delete
    // catch, and it is exactly the one a "never throws" claim forgets. The
    // code-5 branch below depends on that claim: its parent is already gone, so
    // `update()` throws NOT_FOUND on every retry, and a rejection escaping from
    // here would turn a handled code-5 into the retry loop that branch exists
    // to prevent.
    logger.error(
      "[enforceGroupMinorMembership] roster read failed; leaving the conversation standing",
      {
        conversationId,
        errCode: (e as { code?: number | string } | null)?.code ?? "unknown",
        errName: (e as Error | null)?.name,
      },
    );
    return false;
  }

  if (snap.size > MAX_ROSTER_ROWS) {
    // Roster rows are written 1:1 with participants, so a roster this large is
    // not a real group — it is a seeded one.
    logger.error(
      "[enforceGroupMinorMembership] implausible roster size; not clearing it",
      { conversationId, rosterRows: snap.size },
    );
    return false;
  }

  const refs = snap.docs.map((d) => d.ref);
  const failures: string[] = [];
  // Chunked to bound the concurrency. Each delete carries its OWN catch, so a
  // rejection can never abandon the chunks that have not run yet — a bare
  // `Promise.all` over rejecting promises would stop at the failing chunk.
  for (let i = 0; i < refs.length; i += 100) {
    await Promise.all(
      refs.slice(i, i + 100).map((ref) =>
        ref.delete().catch((e: unknown) => {
          // Count and classify; never name. The id IS a uid, and this log
          // outlives the group it belonged to. Optional-chained so a null
          // rejection cannot raise a TypeError inside the catch.
          failures.push(
            String((e as { code?: number | string } | null)?.code ?? "unknown"),
          );
        }),
      ),
    );
  }

  if (failures.length > 0) {
    logger.error(
      "[enforceGroupMinorMembership] roster cleanup failed; leaving the conversation standing",
      { conversationId, failedCount: failures.length, errCodes: failures },
    );
    return false;
  }
  return true;
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
  // caught explicitly below, and the roster cleanup reports rather than throws
  // for the same reason, so only genuinely transient failures reach a retry.
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

    // ORDER MATTERS on the collapse branch, and it is the opposite of the
    // obvious one. Deleting the conversation is the exact write that makes
    // `parentDoc() == null` true in firestore.rules, i.e. it OPENS the roster's
    // bootstrap branch. Closing the rows that branch grants must therefore
    // happen FIRST: a crash or a swallowed failure in between would leave every
    // surviving row readable, with no parent left to deny it, forever.
    //
    // VERIFIED, not best-effort — and note that is not the same as STRICT, which
    // in this repo means "throws". The verdict GATES the parent delete. A
    // swallowed failure that still deleted the parent would be a permanent
    // unmonitored disclosure, which is exactly why a false answer takes the
    // update branch instead. On the update branch a failed roster delete is
    // harmless anyway: the parent survives and no longer names the evicted uid,
    // and the read fallback requires an ABSENT parent.
    //
    // If the roster could not be cleared — too large to be real, or a delete
    // failed — we take the update branch instead: strip the minors and leave the
    // shell standing. The child-safety cut still lands, and a LIVE parent that
    // no longer names anyone is precisely what keeps `rosterUnclaimed()` and the
    // read fallback shut. Deleting the parent instead would re-open the roster;
    // throwing would hand a `retry:true` trigger a deterministic error to loop
    // on. The shell is the safe failure.
    //
    // "Shell" can mean ZERO members: `remaining` is empty when nobody survives
    // the cut (e.g. every participant is a minor and `metadata.creatorId` is
    // absent). The update then writes `participantIds: []`, and since the
    // conversations block's own rules all gate on `uid in participantIds`, that
    // document becomes unreadable, unupdatable and undeletable by anyone —
    // permanently. Accepted knowingly as the safest of three bad outcomes.
    //
    // **A later sweep must clear the roster BEFORE deleting such a shell.**
    // Deleting it flips `parentDoc()` to null, which re-opens `rosterUnclaimed()`
    // and the own-row read fallback over whatever rows survive — including the
    // legitimate members' and the evicted minor's name and avatar. The shell is
    // safe only while it stands. Recorded in ACCEPTED_DEVIATIONS.md.
    const rosterCleared =
      remaining.length < 2 && (await tryClearRoster(db, conversationId));

    if (rosterCleared) {
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
        // Optional-chained like every other error read in this file: a null
        // rejection would otherwise raise a TypeError here and escape a
        // `retry:true` handler. `undefined !== 5` still rethrows, so the
        // semantics are unchanged.
        if ((e as { code?: number } | null)?.code !== 5) throw e;
        logger.info(
          "[enforceGroupMinorMembership] conversation already deleted; skipping the cut, still clearing mirrors",
          { conversationId },
        );
        // This is the OTHER parent-destroyed path, and it is not the collapse
        // branch: somebody else deleted the conversation while this trigger ran.
        // The per-uid cleanup below only covers `toRemove`, so the REMAINING
        // members' roster rows would survive under an absent parent — readable,
        // and re-seatable, forever. Same state `tryClearRoster` exists to
        // prevent, reached by a different route, so it gets the same treatment.
        // The return value is deliberately ignored: there is no parent left to
        // protect, so there is nothing for a false answer to prevent. It logs
        // its own failure. `tryClearRoster` never throws, so this cannot turn a
        // handled code-5 into the poison pill this branch exists to avoid.
        //
        // Note this leaves `remaining`'s MEMBERSHIP mirrors uncleaned — the loop
        // below only walks `toRemove` on this path — so the survivors keep a
        // conversation-list row pointing at a deleted document. Pre-existing,
        // and not the disclosure half; the roster is.
        void (await tryClearRoster(db, conversationId));
      }
    }

    // Best-effort cleanup of each affected uid's TWO mirrors. Never throws out
    // of the trigger — on this path `participantIds` no longer names them, and
    // that removal is the real access cut.
    //
    // 1. `users/{uid}/conversation_memberships/{id}` — stops the group
    //    surfacing in their conversation list. Cosmetic; a stale row is the
    //    only cost, which is what "best-effort" was ever justified by.
    // 2. `conversations/{id}/participants/{uid}` — the roster row. **Missing
    //    until 2026-08-12, and it became a disclosure the day that path got
    //    rules at all.** It used to be default-deny, so a surviving row was
    //    inert; now the roster's read rule grants the list to anyone the parent
    //    NAMES, so a row outliving the eviction keeps the evicted minor's own
    //    name and avatar readable to the group that removed them. The read-back
    //    direction is denied here by the rules half (the parent survives and no
    //    longer names them); it is the COLLAPSE branch above, where the parent
    //    is destroyed, that rules cannot reach. Note a destroyed `direct_*`
    //    parent leaves its rows READABLE but not re-seatable — `rosterUnclaimed`
    //    excludes that prefix, the read fallback does not.
    //
    // Errors are logged by CODE, not by `String(e)`: a Firestore error embeds
    // the full document path, which on this path is a raw uid on a
    // child-safety eviction. The code is what tells PERMISSION_DENIED from
    // DEADLINE_EXCEEDED; the uid tells nothing and outlives the group.
    // Optional-chained: this closure runs inside a `.catch`, and a TypeError
    // raised here would reject a promise the caller believes cannot reject —
    // against this block's stated promise never to throw out of the trigger.
    const logCleanupFailure = (what: string) => (e: unknown) =>
      logger.error(`[enforceGroupMinorMembership] ${what} cleanup failed`, {
        conversationId,
        errCode: (e as { code?: number | string } | null)?.code ?? "unknown",
        errName: (e as Error | null)?.name,
      });

    await Promise.all(
      [...new Set(mirrorsToClear)].flatMap((uid) => [
        db
          .doc(`users/${uid}/conversation_memberships/${conversationId}`)
          .delete()
          .catch(logCleanupFailure("membership")),
        // Skipped when the COLLAPSE branch already enumerated and cleared the
        // whole roster — otherwise every row is deleted twice, and worse, two
        // pieces of code both look like the owner of that cleanup.
        //
        // Not skipped on the concurrent-delete branch, where `rosterCleared` is
        // still false even though that branch calls the same helper. The rows
        // are therefore deleted twice there, deliberately: deleting a missing
        // document resolves, the second pass is a no-op, and a second flag to
        // suppress it would buy nothing but another state to keep in step.
        ...(rosterCleared
          ? []
          : [
              db
                .doc(
                  `conversations/${conversationId}/` +
                    `${CONVERSATION_PARTICIPANTS}/${uid}`,
                )
                .delete()
                .catch(logCleanupFailure("roster")),
            ]),
      ]),
    );
  },
);
