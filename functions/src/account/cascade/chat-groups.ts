import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { Collections } from "../../shared/collections";
// Deliberate cross-domain import (BUT-1822). `tryClearRoster` lives in a
// minor-safety TRIGGER module, but it is the one roster clearer: bounded,
// never-throwing, and it answers the exact question this cascade must ask before
// it deletes a conversation. A second implementation here would be a second
// contract to keep in sync on a GDPR path. Extraction into a neutral module is
// tracked separately; until then, that function's docstring names this caller.
import { tryClearRoster } from "../../messaging/enforce-group-minor-membership";
import { logSafeConversationId } from "../../shared/log-safe-conversation-id";
// BUT-1838: the single writer of chat-group membership. Imported rather than
// re-implemented for the same reason as `tryClearRoster` above — a second
// spelling of "remove this member" on a GDPR path is a contract to keep in sync,
// and this one touches three documents.
import { stageMemberRemoval } from "../../groups/chat-group-writes";
import { batchDeleteAll } from "./core";

/**
 * BUT-1838: erase the user's chat-group membership.
 *
 * **Why this is its own leg and not part of `deleteMessages`.** A group's
 * membership lives on `chat_groups/{id}.memberIds` and is MIRRORED onto the
 * conversation; one writer owns both (`groups/chat-group-writes.ts`). Letting
 * the conversation leg strip its half would leave the group still naming the
 * erased user — two copies of one fact, disagreeing, which is the failure
 * BUT-1798 already cost this project once. `deleteMessages` therefore skips any
 * conversation carrying a `groupId`, and this leg does the whole removal
 * through the shared writer.
 *
 * Three things happen per group, in this order:
 *
 *  1. **`createdBy` is re-homed** to a surviving admin (or member) when the
 *     erased user created a group that lives on. Same move `deleteFamilyData`
 *     already makes for households: without it a raw uid sits on a document
 *     other people keep reading, forever, which Art. 17 does not permit and no
 *     field-keyed probe would flag as "residual" once the membership is gone.
 *  2. **The membership goes**, through `stageMemberRemoval` — the same
 *     transaction that clears `memberIds`, `adminIds`, both display maps,
 *     `memberAddedBy`, the conversation's `participantIds`, all five uid-keyed
 *     conversation maps (including `memberSince`) and the roster row.
 *  3. **An emptied group is taken down**, roster FIRST. Deleting a conversation
 *     is what makes `parentDoc()` null in `firestore.rules`; with the bootstrap
 *     branch gone that no longer re-opens a write path, but orphaned roster rows
 *     still carry names and avatars, so the parent delete stays gated on
 *     `tryClearRoster` reporting success. A group left standing reports the step
 *     INCOMPLETE rather than quietly passing.
 *
 * Capped like every other sweep here. Above the cap it DECLINES rather than
 * truncating: a partial pass that reported success would certify an erasure it
 * did not perform.
 *
 * A separate sweep handles what the membership query cannot reach at all — a
 * departure tombstone (the uid is in it precisely because it left `memberIds`)
 * and the meal-vote pointer's owner uid (they can leave the chat and keep
 * owning the social group). See `clearUnreachableChatGroupResiduals`, run
 * BEFORE the loop below so this function's own cap cannot take it down
 * (BUT-1856).
 */
export const MAX_CHAT_GROUPS_PER_USER = 200;

export async function deleteChatGroupMemberships(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  // FIRST, so the membership sweep declining below cannot take the two
  // independent residual legs down with it — they answer different queries and
  // a cap reached by one says nothing about the others.
  const residualsCleared = await clearUnreachableChatGroupResiduals(db, uid);

  const snap = await db
    .collection(Collections.chatGroups)
    .where("memberIds", "array-contains", uid)
    .limit(MAX_CHAT_GROUPS_PER_USER + 1)
    .get();

  if (snap.size > MAX_CHAT_GROUPS_PER_USER) {
    logger.error(
      "[deletion-cascade] implausible chat-group count; declining the sweep",
      { uid_prefix: uid.slice(0, 6), groups: snap.size },
    );
    return false;
  }

  let complete = true;
  const removedAt = admin.firestore.Timestamp.now();

  for (const groupDoc of snap.docs) {
    try {
      const data = groupDoc.data();
      const conversationId =
        typeof data.conversationId === "string" ? data.conversationId : null;
      if (!conversationId) {
        // A group with members and no conversation is a shape no code path
        // produces. Loud, and not counted as done.
        complete = false;
        logger.error("[deletion-cascade] chat group has no conversationId", {
          uid_prefix: uid.slice(0, 6),
          groupId: groupDoc.id,
        });
        continue;
      }

      const memberIds: string[] = Array.isArray(data.memberIds)
        ? (data.memberIds as string[])
        : [];
      const adminIds: string[] = Array.isArray(data.adminIds)
        ? (data.adminIds as string[])
        : [];
      const survivors = memberIds.filter((u) => u !== uid);

      await db.runTransaction(async (tx) => {
        const fresh = await tx.get(groupDoc.ref);
        if (!fresh.exists) return;
        stageMemberRemoval(tx, {
          db,
          groupId: groupDoc.id,
          conversationId,
          uid,
          removedAt,
        });
        if (survivors.length > 0 && data.createdBy === uid) {
          // Prefer a surviving ADMIN so the group keeps someone who can act on
          // it; fall back to any survivor rather than leaving a raw uid behind.
          const survivingAdmin = adminIds.find(
            (a) => a !== uid && survivors.includes(a),
          );
          tx.update(groupDoc.ref, {
            createdBy: survivingAdmin ?? survivors[0],
          });
        }
      });

      if (survivors.length === 0) {
        const cleared = await tryClearRoster(db, conversationId);
        if (!cleared) {
          complete = false;
          logger.warn(
            "[deletion-cascade] roster not clear; empty group left standing",
            {
              uid_prefix: uid.slice(0, 6),
              conversationId: logSafeConversationId(conversationId),
            },
          );
          continue;
        }
        const thread = await db
          .collection(Collections.messages)
          .where("conversationId", "==", conversationId)
          .get();
        await batchDeleteAll(db, thread.docs);
        await db.collection(Collections.conversations).doc(conversationId).delete();
        await groupDoc.ref.delete();
      }

    } catch (e) {
      complete = false;
      logger.error("[deletion-cascade] chat-group removal failed", {
        uid_prefix: uid.slice(0, 6),
        errCode: (e as { code?: number | string } | null)?.code ?? "unknown",
        errName: (e as Error | null)?.name,
      });
    }
  }

  return complete && residualsCleared;
}

/**
 * BUT-1856: raw uids on `chat_groups` the sweep above cannot reach.
 *
 * Not an exhaustive list of that document's residuals — `createdBy` is re-homed
 * only for groups the erased user is still a MEMBER of, and `memberAddedBy`
 * VALUES survive for everyone they seated. Both predate this change and are
 * forward-only work; do not read the two legs below as covering the document.
 *
 * `departedUserIds` records who left a chat group or was removed from it, so
 * the meal-vote category sync cannot seat them again — a uid is in it precisely
 * because it is NOT in `memberIds`. `sourceCategoryOwnerId` names the owner of
 * the social group a meal-vote chat was built from, and outlives their
 * membership: they can leave the chat and still own the category. The sweep
 * above finds groups by `memberIds array-contains`, so it is structurally blind
 * to both, and each would otherwise sit forever on a document the surviving
 * members read — the same residual class `createdBy` is re-homed for.
 *
 * Dropping the pointer breaks nothing: the category itself goes in this same
 * cascade, so it is already dangling, and the group simply stops being any
 * category's chat.
 *
 * Capped and DECLINING per leg, like every other sweep here: a partial pass
 * that reported success would certify an erasure it did not perform.
 */
async function clearUnreachableChatGroupResiduals(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const legs = [
    {
      field: "departedUserIds",
      op: "array-contains" as const,
      patch: { departedUserIds: admin.firestore.FieldValue.arrayRemove(uid) },
    },
    {
      field: "sourceCategoryOwnerId",
      op: "==" as const,
      patch: {
        sourceCategoryId: admin.firestore.FieldValue.delete(),
        sourceCategoryOwnerId: admin.firestore.FieldValue.delete(),
      },
    },
  ];

  let complete = true;
  for (const leg of legs) {
    const snap = await db
      .collection(Collections.chatGroups)
      .where(leg.field, leg.op, uid)
      .limit(MAX_CHAT_GROUPS_PER_USER + 1)
      .get();

    if (snap.size > MAX_CHAT_GROUPS_PER_USER) {
      logger.error(
        "[deletion-cascade] implausible chat-group residual count; declining",
        { uid_prefix: uid.slice(0, 6), field: leg.field, groups: snap.size },
      );
      complete = false;
      continue;
    }

    for (const groupDoc of snap.docs) {
      try {
        await groupDoc.ref.update(leg.patch);
      } catch (e) {
        complete = false;
        logger.error("[deletion-cascade] chat-group residual removal failed", {
          uid_prefix: uid.slice(0, 6),
          field: leg.field,
          errCode: (e as { code?: number | string } | null)?.code ?? "unknown",
          errName: (e as Error | null)?.name,
        });
      }
    }
  }
  return complete;
}
