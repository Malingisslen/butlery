import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { commitInChunks } from "../../shared/batch-update";
import { Collections } from "../../shared/collections";
import { batchDeleteAll } from "./core";
import {
  MESSAGE_TOMBSTONE,
  deletePollVotes,
  anonymizeSystemMessagesAboutUser,
} from "./message-side-records";

export async function deleteMessages(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const own = await db
    .collection(Collections.messages)
    .where("senderId", "==", uid)
    .get();
  if (own.docs.length > 0) {
    await commitInChunks(
      db,
      own.docs,
      (batch, doc) => {
        batch.update(doc.ref, {
          senderId: "deleted",
          senderDisplayName: "[Raderad användare]",
          senderAvatarUrl: null,
          content: MESSAGE_TOMBSTONE,
        });
      },
      { label: "anonymizeOwnMessages", strict: false },
    );
  }

  await anonymizeSystemMessagesAboutUser(db, uid);

  const convos = await db
    .collection(Collections.conversations)
    .where("participantIds", "array-contains", uid)
    .get();

  // Bounded parallelism: 10 conversations / wave. Mirrors prior client behavior.
  const chunkSize = 10;
  // Per-conversation failures are COLLECTED, not thrown. A rejection inside
  // `Promise.all` abandons every conversation left in the run. Same shape
  // `deleteShoppingLists` already uses.
  const conversationFailures: string[] = [];
  for (let i = 0; i < convos.docs.length; i += chunkSize) {
    const chunk = convos.docs.slice(i, i + chunkSize);
    await Promise.all(
      chunk.map(async (convoDoc) => {
        try {
          const participants = Array.isArray(convoDoc.data().participantIds)
            ? (convoDoc.data().participantIds as string[])
            : [];
          // BUT-1838: a conversation owned by a chat group is handled ENTIRELY
          // by `deleteChatGroupMemberships`, which removes the uid from the
          // group AND the conversation in one transaction. Touching it here too
          // would be a second writer of membership — the drift this repo has
          // been burned by more than once — and, because the two legs run in
          // parallel, a race as well: this branch would strip the conversation
          // while `chat_groups.memberIds` still named the erased user.
          if (typeof convoDoc.data().groupId === "string") {
            return;
          }
          if (participants.length <= 2) {
            const thread = await db
              .collection(Collections.messages)
              .where("conversationId", "==", convoDoc.id)
              .get();
            await batchDeleteAll(db, thread.docs);
            await convoDoc.ref.delete();
          } else {
            // Transactional re-read: the outer query snapshot can be stale by
            // the time this specific doc's write runs, and a group chat is
            // exactly where a NEW message between query and write is likely. A
            // blind update() would stamp the tombstone from the stale snapshot
            // and silently overwrite that new message's lastMessage copy back
            // to "[Raderad användare]".
            await db.runTransaction(async (tx) => {
              const fresh = await tx.get(convoDoc.ref);
              if (!fresh.exists) return;
              tx.update(convoDoc.ref, buildGroupDepartureUpdate(fresh, uid));
            });
          }
        } catch (e) {
          // Classified, never named: a Firestore error embeds the full document
          // path, which on this path is a conversation id — for a 1:1, two raw
          // uids.
          conversationFailures.push(
            String((e as { code?: number | string } | null)?.code ?? "unknown"),
          );
        }
      }),
    );
  }

  // BUT-1835. Called from inside this step, not registered as its own: Tier 1
  // steps run in PARALLEL, and both this and the conversation loop above write
  // to `messages`. Running it sequentially after the loop removes THIS step's
  // own race with itself.
  //
  // It does NOT remove every race, and the previous version of this comment claim-lint:ok moved unchanged, BUT-2113
  // claimed it did ("sequential-after is the only deterministic order"). claim-lint:ok moved unchanged, BUT-2113
  // `request-account-deletion.ts` puts `chat_groups` and `messages` in the same
  // `Promise.all`, and `deleteChatGroupMemberships` deletes an emptied group's
  // whole thread — so a message this step is about to update can vanish under
  // it from a SIBLING step. That is why the creator scrub below tolerates
  // NOT_FOUND per document instead of relying on ordering, and why BUT-1801
  // added a residual probe on `metadata.poll.creatorId`: ordering is not a
  // control, and a swallowed chunk failure here is silent by construction.
  const pollVotesCleared = await deletePollVotes(db, uid);

  if (conversationFailures.length > 0) {
    logger.error("[deletion-cascade] conversations failed to erase", {
      uid_prefix: uid.slice(0, 6),
      failedCount: conversationFailures.length,
      errCodes: conversationFailures,
    });
    return false;
  }
  return pollVotesCleared;
}

/**
 * The single `update()` that removes a departing user from a SURVIVING group
 * conversation document.
 *
 * One write, not five: a group thread can be large, and the four map-key
 * deletions plus the `lastMessage` tombstone are one logical erasure — a
 * partial application would leave a name on a document the probe cannot see.
 *
 * `lastMessage` is a denormalised COPY of the last message row, so anonymizing
 * the row in `messages` does not touch it. It is rewritten to the same
 * tombstone that row gets, and only when the departing user is its sender.
 */
function buildGroupDepartureUpdate(
  convoDoc: admin.firestore.DocumentSnapshot,
  uid: string,
): Record<string, unknown> {
  const update: Record<string, unknown> = {
    participantIds: admin.firestore.FieldValue.arrayRemove(uid),
  };
  for (const map of PER_USER_CONVERSATION_MAPS) {
    update[`${map}.${uid}`] = admin.firestore.FieldValue.delete();
  }

  const last = (convoDoc.data() ?? {}).lastMessage as
    Record<string, unknown> | undefined;
  if (last && last.senderId === uid) {
    update["lastMessage.senderId"] = "deleted";
    update["lastMessage.senderDisplayName"] = "[Raderad användare]";
    update["lastMessage.senderAvatarUrl"] = null;
    update["lastMessage.content"] = MESSAGE_TOMBSTONE;
  }
  return update;
}

/**
 * The uid-keyed maps `ConversationDto.toFirestore` writes onto a conversation
 * document. `perUserSettings` carries the departing user's mute/pin/archive
 * state, which is theirs and has no purpose once the account is gone. Since
 * BUT-1838 the group path clears it too — `stageMemberRemoval` deletes every
 * key in the SEPARATE list of the same name in `groups/chat-group-writes.ts`,
 * which additionally carries `memberSince`. Two declarations, not one import:
 * a key added to either must be added to the other by hand.
 */
const PER_USER_CONVERSATION_MAPS = [
  "participantDisplayNames",
  "participantAvatarUrls",
  "lastReadTimestamps",
  "perUserSettings",
] as const;
