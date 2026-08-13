/**
 * BUT-1626, repointed by BUT-1838: the minor-membership BACKSTOP.
 *
 * **This is no longer the control.** Until BUT-1838 it was: an
 * `onDocumentCreated` trigger on `conversations/{id}` that removed a minor a
 * non-friend had added. That design could only ever fire once — in the instant
 * the chat was born — so anyone added later was checked by nobody, and there was
 * no invitation moment to move the check to, because the chat WAS the member
 * list.
 *
 * `chat_groups` created that moment. The primary control now runs BEFORE the
 * write, inside the membership callables, via `groups/minor-membership-gate.ts`.
 * This trigger re-asks the SAME question (one policy, one module) after every
 * membership write, and evicts anyone who should not be there.
 *
 * **Why keep it at all, if the callables cannot be bypassed.** Because "cannot"
 * rests on `firestore.rules` refusing every client write to `chat_groups`
 * membership, and on no future code path writing it under the Admin SDK without
 * asking the gate. Both are true today and neither is enforced by the compiler.
 * One invocation per membership change — which is a rare event — buys a check
 * that survives the next author's mistake. It is belt and braces on a
 * child-safety control, and that is worth an invocation.
 *
 * It judges each member against `memberAddedBy[uid]` — who actually seated THEM
 * — rather than against one creator, which is what the old trigger had to do and
 * what made it wrong for anyone added after creation.
 *
 * Cost: bounded to a group's membership (at most MAX_GROUP_PARTICIPANTS reads,
 * plus one friend-doc read per minor). Converges: the eviction write re-fires
 * the trigger once, and that pass finds nothing to remove.
 */

import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { hashUid } from "../shared/hash-uid";
import { Collections } from "../shared/collections";
import { isValidDocId } from "../shared/valid-doc-id";
import {
  computeBlockedMembers,
  readAdderFriendships,
  readIsMinor,
} from "../groups/minor-membership-gate";
import { stageMemberRemoval } from "../groups/chat-group-writes";

/**
 * A conversation id that is safe to put in Cloud Logging.
 *
 * A GROUP id is a client-minted UUIDv4 and discloses nothing. A DIRECT id is
 * `direct_<uidA>_<uidB>` — two raw uids, one of which may belong to someone who
 * just had their account erased. This helper exists because BUT-1822 gave
 * `tryClearRoster` a second caller (the account-deletion cascade) that hands it
 * direct ids for the first time: the helper's code did not change, but the key
 * space it logs did. Hashing keeps a greppable handle that correlates across
 * lines without carrying the uids.
 */
export function logSafeConversationId(conversationId: string): string {
  return conversationId.startsWith("direct_")
    ? `direct_#${hashUid(conversationId)}`
    : conversationId;
}

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
 * of truth and, since BUT-1822, DOES carry `participants` — the account-deletion
 * cascade needed the collection-group id. This file and
 * `leave-group-conversation.ts` still hold their own copies and
 * `admin/reset-user-data.ts` still uses a bare literal, so a rename is four
 * edits, not one. Consolidating them is a separate change; this constant exists
 * so the two uses in THIS file cannot drift from each other.
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

/**
 * Attempts to delete every row under `conversations/{id}/participants`.
 * Returns true only if the roster is provably clear afterwards.
 *
 * TWO CALLERS, in two domains. This trigger's collapse branch, and — since
 * BUT-1822 — `deleteMessages` in `account/account-deletion-cascade.ts`, which
 * gates its 1:1 conversation delete on the same answer for the same reason. The
 * cascade reaching into a trigger module is deliberate (one clearer, not two);
 * extracting this into a neutral module is tracked separately. Anyone changing
 * the contract below — the bound, the never-throws promise, the meaning of the
 * return value — must check that second caller.
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
        conversationId: logSafeConversationId(conversationId),
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
      {
        conversationId: logSafeConversationId(conversationId),
        rosterRows: snap.size,
      },
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
      {
        conversationId: logSafeConversationId(conversationId),
        failedCount: failures.length,
        errCodes: failures,
      },
    );
    return false;
  }
  return true;
}


export const enforceGroupMinorMembership = onDocumentWritten(
  // retry:true — v2 event triggers do NOT retry by default, so a transient
  // failure below would be logged and dropped, leaving a non-friend-added minor
  // in the group (fail-OPEN on a child-safety gate). Every write here is
  // idempotent on re-run: `arrayRemove` and the per-uid `FieldValue.delete()`s
  // are no-ops once applied, and a group that no longer names the minor produces
  // no removals at all on the next pass.
  { document: "chat_groups/{groupId}", retry: true },
  async (event) => {
    const after = event.data?.after;
    if (!after?.exists) return; // group deleted — nothing left to protect
    const data = after.data() ?? {};
    const groupId = event.params.groupId;

    // Sanitise for USE (the reads below splice uids into document paths), and
    // judge on the sanitised list here — unlike the old conversations trigger,
    // which had to gate on the RAW length because `passesMinorDmGate` in
    // firestore.rules fired at raw size 2 and a padded list could slip between
    // the two layers. No rule looks at this document's membership at all, so
    // there is no second layer to stay in step with and no padding attack to
    // defeat.
    const rawMemberIds: unknown[] = Array.isArray(data.memberIds)
      ? (data.memberIds as unknown[])
      : [];
    const memberIds = rawMemberIds.filter(isValidDocId);
    if (memberIds.length === 0) return;

    if (memberIds.length > MAX_GROUP_PARTICIPANTS) {
      // The callables cap membership at the same number, so this is only
      // reachable if something wrote the document without asking them — which is
      // precisely the case this trigger exists for. Refuse the fan-out and alert
      // rather than pay an unbounded, retry-replayed read bill.
      logger.error(
        "[enforceGroupMinorMembership] implausible group size; refusing the read fan-out",
        { groupId, memberCount: memberIds.length },
      );
      return;
    }

    const rawAddedBy =
      data.memberAddedBy && typeof data.memberAddedBy === "object"
        ? (data.memberAddedBy as Record<string, unknown>)
        : {};
    const adderOf = (uid: string): string | null => {
      const v = rawAddedBy[uid];
      return isValidDocId(v) ? v : null;
    };

    const db = admin.firestore();
    const isMinor = await readIsMinor(db, memberIds);
    const minorUids = memberIds.filter((u) => isMinor[u]);
    if (minorUids.length === 0) return;

    const inviterIsFriendOf = await readAdderFriendships(
      db,
      minorUids,
      adderOf,
    );

    const toRemove = computeBlockedMembers({
      candidates: memberIds,
      inviterOf: adderOf,
      isMinor,
      inviterIsFriendOf,
    });
    if (toRemove.length === 0) return;

    const conversationId =
      typeof data.conversationId === "string" ? data.conversationId : null;
    if (!isValidDocId(conversationId)) {
      // Nothing to cut access to, and no path to build. Loud rather than
      // silent: a group with members and no conversation is a shape no code
      // path here produces.
      logger.error(
        "[enforceGroupMinorMembership] group has no usable conversationId",
        { groupId, removedCount: toRemove.length },
      );
      return;
    }

    logger.warn(
      "[enforceGroupMinorMembership] removing non-friend-added minors",
      {
        groupId,
        conversationId: logSafeConversationId(conversationId),
        removedCount: toRemove.length,
        remaining: memberIds.length - toRemove.length,
      },
    );

    const removedAt = admin.firestore.Timestamp.now();
    try {
      await db.runTransaction(async (tx) => {
        // Read the group inside the transaction so a concurrent legitimate
        // removal cannot be clobbered, and so a group deleted between the event
        // and this write is a no-op rather than a resurrection: `tx.update` on a
        // missing document throws NOT_FOUND, which the catch below treats as
        // success.
        const fresh = await tx.get(
          db.collection(Collections.chatGroups).doc(groupId),
        );
        if (!fresh.exists) return;
        for (const uid of toRemove) {
          stageMemberRemoval(tx, {
            db,
            groupId,
            conversationId,
            uid,
            removedAt,
          });
        }
      });
    } catch (e) {
      // NOT_FOUND (grpc 5) is DETERMINISTIC — the group or its conversation was
      // deleted while this ran — and rethrowing it would hand a `retry:true`
      // trigger an error to loop on forever, re-billing the read fan-out each
      // time. The access cut is moot when the documents are gone.
      if ((e as { code?: number } | null)?.code !== 5) throw e;
      logger.info(
        "[enforceGroupMinorMembership] group already gone; skipping the cut",
        { groupId },
      );
    }

    // Best-effort mirror cleanup: stops the group surfacing in the evicted
    // member's conversation list. The membership removal above IS the access
    // cut, so a stale row here costs a list entry, not a disclosure. Errors are
    // logged by CODE, never by `String(e)`: a Firestore error embeds the full
    // document path, which on this path is a raw uid on a child-safety eviction
    // and outlives the group it belonged to.
    await Promise.all(
      toRemove.map((uid) =>
        db
          .doc(`users/${uid}/conversation_memberships/${conversationId}`)
          .delete()
          .catch((e: unknown) =>
            logger.error(
              "[enforceGroupMinorMembership] membership cleanup failed",
              {
                groupId,
                errCode:
                  (e as { code?: number | string } | null)?.code ?? "unknown",
                errName: (e as Error | null)?.name,
              },
            ),
          ),
      ),
    );
  },
);
