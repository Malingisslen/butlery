/**
 * BUT-1840: the conversation-roster clearer, in a module of its own.
 *
 * It lived in the child-safety trigger (`enforce-group-minor-membership.ts`)
 * until its callers were all in other modules. That trigger re-exports
 * everything here, so existing imports keep working.
 */

import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { logSafeConversationId } from "../shared/log-safe-conversation-id";
import { Collections } from "../shared/collections";

/**
 * Upper bound on group members the backstop trigger
 * (`enforce-group-minor-membership.ts`) will read. Far above any real group
 * chat, so it never fires legitimately; it exists purely to bound the billed
 * read fan-out (and its retry replays) on a tampered write. The trigger is
 * `onDocumentWritten` on `chat_groups/{groupId}` and this bounds the sanitised
 * `memberIds` it reads.
 */
export const MAX_GROUP_PARTICIPANTS = 100;

/**
 * Above this many roster rows [tryClearRoster] refuses to clear, so its callers
 * leave the conversation standing. Generous on purpose — a plausibility bound
 * against a SEEDED roster, not a correctness bound on real groups.
 *
 * Group size IS capped: `MAX_CHAT_GROUP_MEMBERS` (100) is enforced by both
 * membership callables, and `firestore.rules` refuses every client write to
 * `chat_groups` membership — so this bound is not about real groups at all. It
 * bounds the three sources named on [tryClearRoster] below, and nothing
 * upstream filters them: the backstop trigger's [MAX_GROUP_PARTICIPANTS] guard
 * governs the GROUP read fan-out, not the roster path, and BUT-1838 left this
 * trigger no collapse branch to reach the helper through.
 *
 * The raw-vs-sanitised distinction that used to be load-bearing here no longer
 * is: the old conversations trigger had to gate on the RAW length because
 * `passesMinorDmGate` fired at raw size 2 and a padded list could slip between
 * the two layers. Rules DO read `chat_groups` membership — the group's read
 * gates on `uid in memberIds` and rename on `adminIds` — but never for a SIZE
 * decision, and no client may write the list at all, so there is no padding
 * attack and no second layer to stay in step with. See the comment on the
 * guard itself.
 */
export const MAX_ROSTER_ROWS = MAX_GROUP_PARTICIPANTS * 5;

/**
 * Attempts to delete every row under `conversations/{id}/participants`.
 * Returns true only if the roster is provably clear afterwards.
 *
 * THREE CALL SITES, in two other modules and NONE in this one — BUT-1838 moved
 * the group collapse out of the backstop trigger. They are `deleteEmptyGroup`
 * (`groups/remove-chat-group-member.ts`), and `deleteMessages` +
 * `deleteChatGroupMemberships` in `account/account-deletion-cascade.ts`; the
 * three gate a conversation delete on this answer, for the same reason.
 * Anyone changing the contract below — the bound, the never-throws promise,
 * the meaning of the return value — must check all three.
 *
 * **The caller's invariant: never delete the conversation while roster rows may
 * survive.** Deleting the parent makes `parentDoc() == null` true, and
 * every predicate that could surface a row reads through the parent, so the
 * rows left behind become UNREADABLE forever. Not unreachable: `allow delete`
 * and the `hasOnly(['lastReadAt'])` update branch key on
 * `participantId == request.auth.uid` alone, so the row's own subject keeps a
 * delete and a cursor stamp — and no client flow uses either. (Up
 * to BUT-1838 the same write was worse: it re-opened a bootstrap branch that
 * let any signed-in user read and write them. That branch is gone; the
 * invariant is not, because an unreadable roster is still a one-way door.) So this
 * function never throws — it reports, and a false answer means the caller must
 * leave the parent standing. Never throws on any error shape the
 * SDK can produce — the read and every delete are caught. (A hostile `code`
 * accessor that throws would escape, since an optional chain guards `null`, not
 * a throwing getter. Firestore rejects with plain objects, so that is a note,
 * not a hole.) A live parent denies the roster to everyone it no longer names —
 * for both group-side callers it names nobody at that point, so the shell is
 * the safe failure; the access cut itself already committed in the caller's own
 * removal transaction (`stageMemberRemoval`), never here.
 * (For the cascade's 1:1 caller the surviving partner IS still named and can claim-lint:ok moved unchanged from the trigger (BUT-1840)
 * list what is left; leg 2 of that cascade is what sweeps the erased user's own
 * row.)
 *
 * BOUNDED READ, not just a bounded delete. `listDocuments()` buffers every ref
 * before any cap could be applied, and this path can hold far more rows than
 * the members the backstop trigger knows about — so an unbounded enumeration inside a
 * `retry:true` trigger is a self-repeating read bill, the same one the
 * MAX_GROUP_PARTICIPANTS guard already refuses. The bound stays, and the reason
 * it stays SURVIVED BUT-1838 even though the hole that motivated it did not.
 * What that ticket closed was the UNATTESTED branch: anyone who guessed a
 * conversation id could seat rows under a parent that did not exist, with no
 * `rateLimitWrite` on the path. Three sources of extra rows remain:
 *   1. rows seeded BEFORE BUT-1838 shipped, still on disk — the backfill was
 *      closed unbuilt (BUT-1839), so they are not hypothetical;
 *   2. a tampered or non-standard Admin-SDK writer, which rules never see;
 *   3. an ATTESTED client write, which is bounded but live. `attestedWriter()`
 *      requires the parent to name the writer AND the subject, and in a direct
 *      conversation `direct_A_B` it names both — so A may write B's row with a
 *      `displayName` of A's choosing. A may also create that conversation:
 *      two adults need no friendship (`passesMinorDmGate` only fires when the
 *      other party is a minor).
 * Do not read "the bootstrap branch is gone" as "no client can write here".
 * Source 3 is unreachable for BOTH group-side callers: `deleteEmptyGroup` only
 * passes group conversations, and `deleteChatGroupMemberships` takes its
 * `conversationId` off a `chat_groups` document — and `mayWriteRoster()` denies
 * every client roster write under a `groupId` parent, so for those two sources
 * 1 and 2 carry the bound on their own. It is named for `deleteMessages`, the ONE call
 * site handed direct ids; its `typeof groupId === "string"` early return is
 * what makes that exact.
 *
 * `.limit(N + 1).get()` bounds the read itself. A plain
 * query is enough here: `listDocuments()` is only required to surface PHANTOM
 * parents (rows that exist solely as ancestors of a subcollection), and no rules
 * path permits a subcollection under a roster row. It does return children whose
 * parent document is absent, which is exactly the state this guards.
 *
 * ENUMERATED, never derived from a uid list. The roster's writer
 * (`ConversationParticipantModule.addParticipants`) iterates
 * `participantDisplayNames.entries`, while the uid list the backstop trigger works from
 * is `chat_groups.memberIds` filtered by `isValidDocId`. A uid that filter rejects —
 * `a.b` — is still a legal document id, and the write rule constrains the
 * id's SHAPE not at all: the only conjunct mentioning `participantId` pins the claim-lint:ok moved unchanged from the trigger (BUT-1840)
 * payload field to the path segment. (Before BUT-1838 the bootstrap branch made
 * this worse still, authorising on the parent alone.) Attestation does constrain
 * WHICH ids may be written — they must appear in `participantIds` — but that list
 * is itself never shape-validated, so a row can exist that no uid list here can
 * name.
 */
export async function tryClearRoster(
  db: admin.firestore.Firestore,
  conversationId: string,
): Promise<boolean> {
  let snap: admin.firestore.QuerySnapshot;
  try {
    snap = await db
      .collection(`conversations/${conversationId}/${Collections.participants}`)
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
