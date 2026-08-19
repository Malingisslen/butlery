/**
 * BUT-778: server-side replacement for the deprecated `ConversationAutoHealerModule`
 * client-side listener swarm. Previously, every conversation rendered into a
 * user's list spawned a per-conversation `messages` snapshot listener (~50 per
 * active user, 520k concurrent at 10k DAU) just to keep
 * `conversation.lastMessage` in sync.
 *
 * This trigger does the same job server-side, once per message write:
 * - On message create: set `conversation.lastMessage` if the new message is
 *   newer than what's stored.
 * - On message update: same, so an edit also refreshes the preview.
 * - On message delete: if the deleted message WAS the lastMessage, recompute
 *   from the remaining messages (or clear `lastMessage` if the conversation
 *   is now empty, or if the surviving message carries no resolved `sentAt`).
 *
 * Idempotent. Uses a Firestore transaction so concurrent message writes for
 * the same conversation can't clobber each other into a stale state.
 *
 * Cost vs. the client healer: ~one CF invocation per message write (cheap and
 * bounded by user activity), zero per-listener Firestore charges, and works
 * even when the client is offline. Replaces ~520k concurrent listeners at
 * 10k DAU with ~N invocations where N = total messages/sec.
 */

import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
// BUT-1872: a DIRECT conversation id is `direct_<uidA>_<uidB>` — two raw uids.
// One helper, so every logger on a conversation path hashes it the same way.
import { logSafeConversationId } from "./enforce-group-minor-membership";

interface MessageWireFields {
  conversationId?: string;
  senderId?: string;
  content?: string;
  type?: string;
  status?: string;
  sentAt?: admin.firestore.Timestamp;
}

/**
 * Returns true when `candidate` should replace `current` as the conversation's
 * lastMessage. Newer `sentAt` wins; ties (same timestamp) prefer the candidate
 * — message edits land with the same `sentAt` and need to overwrite the
 * stored snapshot to refresh the preview text.
 *
 * `current.sentAt` is typed as a Timestamp but is read back off a stored
 * document, so it can be anything a past write left there. Measured
 * 2026-08-19: a stored STRING is truthy, so the old `!current?.sentAt` test
 * let it through to `current.sentAt.toMillis()` and threw — which froze that
 * conversation's preview permanently, since every later message write hit the
 * same line. An unusable stored stamp is now always replaceable, so a real
 * message heals the document instead of dying on it.
 */
export function shouldReplaceLastMessage(
  current: { sentAt?: admin.firestore.Timestamp } | null | undefined,
  candidateSentAt: admin.firestore.Timestamp
): boolean {
  if (!(current?.sentAt instanceof admin.firestore.Timestamp)) return true;
  return candidateSentAt.toMillis() >= current.sentAt.toMillis();
}

/**
 * Build the embedded `lastMessage` map written to the conversation doc.
 * Mirrors the shape `MessageDto.fromMap` reads on the client.
 *
 * Call it only with a resolved `sentAt` (BUT-1853): the client substitutes
 * `clock.now()` for a missing one, which defeats the group history cut-off.
 * The `?? null` below is a type fallback, not a licence to skip that check.
 */
function projectLastMessage(messageId: string, data: MessageWireFields) {
  return {
    id: messageId,
    conversationId: data.conversationId ?? null,
    senderId: data.senderId ?? null,
    content: data.content ?? "",
    type: data.type ?? "text",
    status: data.status ?? "sent",
    sentAt: data.sentAt ?? null,
  };
}

export const syncConversationLastMessage = onDocumentWritten(
  {
    document: "messages/{messageId}",
    region: "europe-west1",
  },
  async (event) => {
    const messageId = event.params.messageId;
    const before = event.data?.before?.data() as MessageWireFields | undefined;
    const after = event.data?.after?.data() as MessageWireFields | undefined;

    const conversationId = after?.conversationId ?? before?.conversationId;
    if (!conversationId) {
      logger.warn(
        "[syncConversationLastMessage] message has no conversationId, skipping",
        { messageId }
      );
      return;
    }
    const db = admin.firestore();
    const conversationRef = db.collection("conversations").doc(conversationId);

    const isDelete = !!before && !after;

    await db.runTransaction(async (tx) => {
      const convDoc = await tx.get(conversationRef);
      if (!convDoc.exists) {
        logger.warn(
          "[syncConversationLastMessage] conversation not found, skipping",
          { messageId, conversationId: logSafeConversationId(conversationId) }
        );
        return;
      }
      const convData = convDoc.data() ?? {};
      const currentLastMessage = convData.lastMessage as
        | { id?: string; sentAt?: admin.firestore.Timestamp }
        | null
        | undefined;

      if (isDelete) {
        // Only act when the deleted message WAS the conversation's
        // lastMessage; otherwise the preview is unaffected.
        if (currentLastMessage?.id !== messageId) return;

        // Recompute by reading the most recent surviving message. Outside
        // the transaction would be cheaper but introduces a TOCTOU race;
        // a single get() inside the txn is acceptable for the rare delete
        // path.
        const replacement = await tx.get(
          db
            .collection("messages")
            .where("conversationId", "==", conversationId)
            .orderBy("sentAt", "desc")
            .limit(1)
        );
        if (replacement.empty) {
          tx.update(conversationRef, {
            lastMessage: null,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          return;
        }
        const replacementDoc = replacement.docs[0];
        const replacementData = replacementDoc.data() as MessageWireFields;
        // BUT-1853, STRENGTHENED 2026-08-19. A truthiness check is NOT enough
        // here, and the gap is reachable by any participant rather than by
        // accident. Measured against the live rules on the emulator:
        //
        //   · the messages CREATE rule checks that the key `sentAt` EXISTS,
        //     never what TYPE it holds — `sentAt: "nope"` returns ALLOW;
        //   · Firestore's type ordering sorts STRINGS above every timestamp,
        //     measured `string > new ts > old ts > null`.
        //
        // So a planted string WINS `orderBy('sentAt','desc').limit(1)` outright
        // and walks straight past `!data.sentAt`. Anyone in a group could make
        // their own message the permanent recomputed preview for everyone else.
        // Require a real Timestamp; anything else clears.
        //
        // The rules-side close (`request.resource.data.sentAt is timestamp` on
        // the create) is deliberately NOT in this change — it needs its own
        // rules tests beside M1-M9, which today have no missing- or
        // malformed-`sentAt` case at all. Filed separately; do not assume this
        // guard makes the rule unnecessary.
        if (
          !(replacementData.sentAt instanceof admin.firestore.Timestamp)
        ) {
          // A projection with an unusable `sentAt` fails OPEN on the
          // client — `MessageDto.fromMap` substitutes `clock.now()` for a
          // missing stamp, which always clears `Conversation.canReadMessageAt`,
          // so a member added to a running group would see a preview of a
          // message sent before they joined. Clear instead of projecting: the
          // preview is worth less than the cut-off, and the next message write
          // restores it. (The query can return such a row because Firestore
          // orders an explicit null lowest rather than excluding it.)
          logger.warn(
            "[syncConversationLastMessage] replacement has no sentAt; clearing lastMessage",
            {
              messageId,
              replacementId: replacementDoc.id,
              conversationId: logSafeConversationId(conversationId),
            }
          );
          tx.update(conversationRef, {
            lastMessage: null,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          return;
        }
        tx.update(conversationRef, {
          lastMessage: projectLastMessage(replacementDoc.id, replacementData),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return;
      }

      // Create or update path.
      // The TYPE test, not a truthiness test, and the two rejected cases are
      // different animals:
      //
      //  · MISSING — a malformed write, and NOTHING catches up. This comment
      //    used to say a serverTimestamp sentinel resolves on a follow-up
      //    write; measured against the emulator 2026-08-19, that is false for
      //    every writer this trigger has. `writeGroupSystemMessage` uses the
      //    Admin SDK, whose serverTimestamp is resolved server-side at commit,
      //    so the stored value is already a real Timestamp and the document is
      //    written once; `MessageDto.toFirestore` writes a concrete
      //    `Timestamp.fromDate`. Skipping is the fail-closed choice: the
      //    preview waits for the next well-formed message, which is what test
      //    I7 pins.
      //  · WRONG TYPE — nothing catches up, ever. `sentAt: "nope"` passes the
      //    create rule (which only tests that the key exists), is truthy, and
      //    then reached `candidateSentAt.toMillis()` and threw; measured
      //    2026-08-19 by the integration test below. Worse, when the
      //    conversation had no lastMessage the string was PROJECTED, after
      //    which every later write in that conversation threw on the stored
      //    value. Refusing it here is what keeps that out of the document.
      //
      // Logged as one line either way: the log is for spotting a sustained
      // spike, and both shapes mean the same thing to whoever reads it —
      // messages arriving without a usable stamp.
      if (!(after?.sentAt instanceof admin.firestore.Timestamp)) {
        logger.warn(
          "[syncConversationLastMessage] after.sentAt missing or not a Timestamp; skipping",
          { messageId, conversationId: logSafeConversationId(conversationId) }
        );
        return;
      }
      if (!shouldReplaceLastMessage(currentLastMessage, after.sentAt)) {
        return;
      }
      tx.update(conversationRef, {
        lastMessage: projectLastMessage(messageId, after),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
  }
);
