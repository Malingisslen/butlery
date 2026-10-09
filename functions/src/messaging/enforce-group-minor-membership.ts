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
import { logSafeConversationId } from "../shared/log-safe-conversation-id";
import { Collections } from "../shared/collections";
import { cutGroupMenuPlanAccess } from "../groups/group-menu-access";
import { isValidDocId } from "../shared/valid-doc-id";
import {
  computeBlockedMembers,
  readAdderFriendships,
  readIsMinor,
} from "../groups/minor-membership-gate";
import { stageMemberRemoval } from "../groups/chat-group-writes";
import { MAX_GROUP_PARTICIPANTS } from "./roster-cleanup";

// BUT-1840: re-exported so imports and tests written against this module keep
// resolving after the move.
export {
  MAX_GROUP_PARTICIPANTS,
  MAX_ROSTER_ROWS,
  tryClearRoster,
} from "./roster-cleanup";

/**
 * Stage the backstop's evictions — and NEVER a departure tombstone (BUT-1856).
 *
 * Everything that tombstones also writes a visible `memberLeft` system row.
 * This trigger writes none, so a tombstone here would be the one departure with
 * no counterpart, and `departedUserIds` minus the uids with a `memberLeft` row
 * would then be exactly "the accounts the child-safety backstop evicted" — a
 * durable, queryable claim that someone is a minor, on a document every member
 * of the group can read.
 *
 * Leaving it off costs nothing the policy wants: what this trigger removes is a
 * minor seated by a NON-friend, and the meal-vote category sync re-runs the same
 * per-inviter gate before it could seat anyone again.
 *
 * Exported only so a test can hold that: the trigger itself reads
 * `admin.firestore()` and has no seam, and the absent argument is a decision at
 * THIS call site that no assertion on `stageMemberRemoval`'s default can pin.
 */
export function stageBackstopRemovals(
  tx: admin.firestore.Transaction,
  params: {
    db: admin.firestore.Firestore;
    groupId: string;
    conversationId: string;
    uids: string[];
    removedAt: admin.firestore.Timestamp;
  },
): void {
  const { db, groupId, conversationId, uids, removedAt } = params;
  for (const uid of uids) {
    stageMemberRemoval(tx, { db, groupId, conversationId, uid, removedAt });
  }
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
    // the two layers. Rules do read this document's membership (the group's
    // read gates on `uid in memberIds`), but never for a size decision, and no
    // client may write the list — so there is no second layer to stay in step
    // with and no padding attack to defeat.
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
        stageBackstopRemovals(tx, {
          db,
          groupId,
          conversationId,
          uids: toRemove,
          removedAt,
        });
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

    // BUT-2005: the menu access cut, OUTSIDE the transaction above. Until this
    // the eviction removed a minor from the group and the conversation and left
    // their read AND write access to every one of the group's weekly menu plans
    // intact — so a minor evicted FOR THEIR OWN PROTECTION could still read what
    // the group was planning and change it.
    //
    // Outside, because `cutGroupMenuPlanAccess` does its own non-transactional
    // reads and chunked writes: called from inside the transaction body, a
    // contention retry would re-run them.
    //
    // A NULL actor, so a promotion this triggers writes no `editTrail` row.
    // Malin's call, 2026-09-09: the row would be written only by this path, on
    // a document every plan participant can read, beside a uid that just
    // vanished with no `memberLeft` row — the same durable inference the absent
    // `tombstone` above refuses (BUT-1856). The promotion is logged instead.
    await cutGroupMenuPlanAccess(
      db,
      conversationId,
      toRemove,
      null,
      "enforceGroupMinorMembership",
    );

  },
);
