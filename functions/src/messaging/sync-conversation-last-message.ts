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
 *   is now empty).
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
 */
export function shouldReplaceLastMessage(
  current: { sentAt?: admin.firestore.Timestamp } | null | undefined,
  candidateSentAt: admin.firestore.Timestamp
): boolean {
  if (!current?.sentAt) return true;
  return candidateSentAt.toMillis() >= current.sentAt.toMillis();
}

/**
 * Build the embedded `lastMessage` map written to the conversation doc.
 * Mirrors the shape `MessageDto.fromMap` reads on the client.
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
          { messageId, conversationId }
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
        tx.update(conversationRef, {
          lastMessage: projectLastMessage(
            replacementDoc.id,
            replacementDoc.data() as MessageWireFields
          ),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return;
      }

      // Create or update path.
      if (!after?.sentAt) {
        // serverTimestamp not yet resolved — onDocumentWritten fires twice
        // for that case; the second invocation has the resolved Timestamp
        // and will catch up. Log so a sustained spike (e.g. clients writing
        // null sentAt) is observable.
        logger.warn(
          "[syncConversationLastMessage] after.sentAt unresolved; awaiting follow-up write",
          { messageId, conversationId }
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
