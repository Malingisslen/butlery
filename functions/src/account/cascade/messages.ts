import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { commitInChunks } from "../../shared/batch-update";
import { Collections } from "../../shared/collections";
// Deliberate cross-domain import (BUT-1822). `tryClearRoster` lives in a
// minor-safety TRIGGER module, but it is the one roster clearer: bounded,
// never-throwing, and it answers the exact question this cascade must ask before
// it deletes a conversation. A second implementation here would be a second
// contract to keep in sync on a GDPR path. Extraction into a neutral module is
// tracked separately; until then, that function's docstring names this caller.
import { tryClearRoster } from "../../messaging/enforce-group-minor-membership";
import { logSafeConversationId } from "../../shared/log-safe-conversation-id";
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
  // `Promise.all` abandons every conversation left in the run — including the
  // roster sweep below, which is the leg added to catch exactly this kind of
  // leftover. Same shape `deleteShoppingLists` already uses. `complete` tracks
  // the erasures that finished but did not finish CLEANLY (a conversation left
  // standing, a declined sweep): those must not be reported as a done erasure.
  const conversationFailures: string[] = [];
  let complete = true;
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
            // BUT-1822: THE ROSTER FIRST, and the parent delete gated on it.
            // Deleting the conversation is the write that makes `parentDoc() ==
            // null` true. Every predicate that could surface a row reads through
            // the parent, so every surviving row becomes UNREADABLE forever —
            // including the SURVIVING partner's, whose `participantId` is not
            // this uid, so the collection-group sweep below can never reach it
            // either. (Not unreachable: delete and the `lastReadAt` update
            // branch key on `participantId == request.auth.uid` alone, so the
            // subject keeps those two — and no client flow uses either.) Until
            // BUT-1838 this was worse: a bootstrap branch re-opened those rows
            // to any signed-in user, which for a 1:1 disclosed the erased user's
            // name and avatar to their former partner forever. The branch is
            // gone; an unreadable roster is still a one-way door, so the
            // ordering below is unchanged.
            //
            // No try/catch around this call, on purpose: `tryClearRoster` reports
            // rather than throws, and a catch here could only turn its `false`
            // back into the delete it exists to prevent.
            //
            // The thread delete runs BEFORE it, not between it and the parent
            // delete: while the parent lives it still names both participants, so
            // anything between the clear and the delete is a window in which a
            // fresh roster row could be written and then orphaned. Nothing writes
            // one for a 1:1 today; the ordering costs nothing and shrinks the
            // window to a single round trip.
            const thread = await db
              .collection(Collections.messages)
              .where("conversationId", "==", convoDoc.id)
              .get();
            await batchDeleteAll(db, thread.docs);
            const rosterClear = await tryClearRoster(db, convoDoc.id);
            if (rosterClear) {
              await convoDoc.ref.delete();
            } else {
              // The parent must stand — see above. But leaving it untouched would
              // keep the erased user's name and avatar in
              // `participantDisplayNames` / `participantAvatarUrls` forever, which
              // is the Art. 17 defect this step exists to fix. So the document
              // gets the same departure update a surviving GROUP gets: the maps
              // lose their uid keys and `participantIds` loses the entry.
              //
              // This is the first code path that can leave a `direct_`
              // conversation standing with fewer than two participants —
              // no client can leave a direct chat — the departure callable takes a
              // `groupId`, so a direct conversation cannot be addressed at all — so
              // no client has rendered that state before (it degrades: every
              // "other participant" lookup in `conversation.dart` carries an
              // `orElse`). For a DIRECT conversation the seeded-roster route is
              // not reachable at all, and post-BUT-1838 for a STRONGER reason
              // than this comment used to give. Only the two attested
              // participants may write rows, and `directIdBinds` pins
              // `participantIds` to exactly two, with the update rule denying any
              // diff that touches it — so a direct conversation's roster holds at
              // most TWO client-written rows, ever, and two rows can never reach
              // the refusal cap. For a `direct_` id this branch therefore means a
              // transient roster read or delete failure. It is NOT direct-only,
              // though: the gate is `participants.length <= 2` on any conversation
              // without a `groupId`, and a LEGACY non-direct one can genuinely hit
              // the cap through rows seeded before BUT-1838 (the old bootstrap
              // branch excluded `direct_` explicitly, so those rows are exactly
              // the non-direct population). Do not read a `gdprCompliant: false`
              // here as necessarily an outage.
              //
              // The step reports INCOMPLETE afterwards. A `direct_` id is
              // literally `direct_<erasedUid>_<survivorUid>`, so a conversation
              // left standing retains the erased user's identifier in its own
              // document id, where no field-keyed probe can ever see it. Erasure
              // is not done; the audit row must not say it is.
              //
              // The id is HASHED in the log for the same reason: this line would
              // otherwise carry both uids into a sink that outlives the account.
              complete = false;
              logger.warn(
                "[deletion-cascade] roster not clear; conversation left standing",
                {
                  uid_prefix: uid.slice(0, 6),
                  conversationId: logSafeConversationId(convoDoc.id),
                },
              );
              await db.runTransaction(async (tx) => {
                const fresh = await tx.get(convoDoc.ref);
                if (!fresh.exists) return;
                tx.update(convoDoc.ref, buildGroupDepartureUpdate(fresh, uid));
              });
            }
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

  const swept = await deleteOwnRosterRows(db, uid);

  // BUT-1835. Called from inside this step, not registered as its own, for the
  // reason spelled out on `deleteOwnRosterRows`: Tier 1 steps run in PARALLEL,
  // and both this and the conversation loop above write to `messages`. Running
  // it sequentially after the loop removes THIS step's own race with itself.
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
  return complete && swept && pollVotesCleared;
}

/**
 * Upper bound on roster rows one account deletion will sweep.
 *
 * Generous — a real user in 200 conversations holds 200 rows — and it is a
 * plausibility bound, not a correctness one. Without a bound, somebody else
 * chooses how large a read-and-delete bill this step pays for a chosen victim's
 * erasure (BUT-1830).
 *
 * THE BOUND STAYS. BUT-1838 closed the hole this was written against — the
 * UNATTESTED bootstrap branch, which let anyone who guessed a conversation id
 * seat rows under a parent that did not exist — and the bound is still load-
 * bearing, for three reasons:
 *   1. rows seeded BEFORE that shipped are still on disk; the backfill was
 *      closed unbuilt (BUT-1839);
 *   2. a tampered or non-standard Admin-SDK writer never passes through rules;
 *   3. an ATTESTED client write is bounded but LIVE. `attestedWriter()` needs
 *      the parent to name the writer AND the subject, and a direct conversation
 *      `direct_A_B` names both — so A may write B's row. A may also create that
 *      conversation: two adults need no friendship (`passesMinorDmGate` only
 *      fires when the other party is a minor). Against a
 *      CHOSEN victim this yields at most two rows per distinct peer account —
 *      `directIdBinds` accepts both orderings, so A may create `direct_A_V`
 *      and `direct_V_A`, each holding one such row — so it is unbounded only
 *      against your OWN uid.
 * The write rule constrains a row's id SHAPE not at all: attestation requires
 * only that the id appear in `participantIds`, which is never shape-validated.
 *
 * Over the bound the sweep DECLINES rather than truncating, and reports it, so
 * `deleteMessages` returns false and the step lands in `failedCollections`. That
 * decline, and the uncapped `count()` probe that raises the alarm, are FROZEN:
 * they are the Art. 17 completeness signal, and they do not depend on which of
 * the three sources above is the live one. Do not relax either to truncation on
 * the argument that the bootstrap hole is closed.
 * Truncating would be loud too — the probe below is an uncapped `count()`, so
 * either way `residual_data_detected` fires and the audit row says
 * `gdprCompliant: false`. Declining is chosen because it is strictly less
 * erasure for the same alarm.
 *
 * The cost of declining, stated: rows planted by routes 1 or 2 — or by a user
 * inflating their OWN count — block the sweep of
 * that user's LEGITIMATE roster rows,
 * and nothing retries automatically — the auth user is gone by then, so
 * recovery needs a human with the Admin SDK. The alarm is what makes that
 * recoverable rather than silent.
 */
const MAX_ROSTER_SWEEP_ROWS = 2000;

/**
 * BUT-1822: the erased user's OWN roster rows, wherever they are.
 *
 * `conversations/{id}/participants/{uid}` carries their `displayName` and
 * `avatarUrl`, and nothing in this cascade has ever touched it. The gap became a
 * disclosure the day that path got its first `match` block — before it, writes
 * were default-denied, so no row existed to leak.
 *
 * Runs AFTER the conversation loop, and inside this step rather than as its own
 * `runStep`: Tier 1 steps run in parallel, so a separate step would interleave
 * two deleters over the same rows, while the loop's 1:1 branch already clears
 * whole rosters. Sequential-after is the only deterministic order. claim-lint:ok moved unchanged, BUT-2113
 *
 * It also sweeps rows orphaned by the other conversation deleters — the client's
 * own "delete conversation"; the eviction trigger's collapse branch, a LEGACY
 * source since BUT-1838 removed it; and `removeChatGroupMember.deleteEmptyGroup`,
 * which clears the roster first and so orphans nothing — whenever a row belongs
 * to the user being erased. Rows belonging to anyone else under a deleted parent are BUT-1825.
 */
async function deleteOwnRosterRows(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const snap = await db
    .collectionGroup(Collections.participants)
    .where("participantId", "==", uid)
    .limit(MAX_ROSTER_SWEEP_ROWS + 1)
    .get();

  if (snap.size > MAX_ROSTER_SWEEP_ROWS) {
    logger.error(
      "[deletion-cascade] implausible roster-row count; not sweeping",
      { uid_prefix: uid.slice(0, 6), rows: snap.size },
    );
    return false;
  }
  await batchDeleteAll(db, snap.docs);
  return true;
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
