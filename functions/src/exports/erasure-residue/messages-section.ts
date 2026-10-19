/**
 * BUT-2414: `messages_in_left_conversations` (Malin 2026-10-19, "Ja, via
 * servern").
 *
 * Erasure anonymises every message the requester sent (`deleteMessages`,
 * `senderId == uid`) and rewrites the creator of every poll they opened
 * (`deletePollVotes`, `metadata.poll.creatorId == uid`), in every
 * conversation. The client export reads messages only in conversations whose
 * `participantIds` still holds the requester, so this section returns the
 * rest: those two predicates, kept where the conversation is gone or no
 * longer lists them. A message the requester sent carries its conversation,
 * time, text and type, and a poll row the poll's own question and options;
 * never a sender name, another person's vote or a reaction. A message someone
 * else sent carries only its id: no rule ties `metadata.poll.creatorId` to the
 * sender, so its text is the sender's.
 */

import * as admin from "firebase-admin";
import { Collections } from "../../shared/collections";
import {
  Allowlist,
  Decline,
  Row,
  cappedDocs,
  getAllInChunks,
  isPlainObject,
  project,
  scalars,
  sortRows,
} from "./project";
import { MAX_SECTION_ROWS, SectionDef } from "./account-sections";

/** Messages exported from left conversations, above which the section declines. */
export const MAX_LEFT_MESSAGES = 5000;
/** Own messages scanned (conversation id only) to find the left conversations. */
export const MAX_OWN_MESSAGE_SCAN = 20000;
/** The cascade's poll-authorship cap (`MAX_POLL_VOTE_SWEEP_ROWS`). */
export const MAX_AUTHORED_POLLS = MAX_SECTION_ROWS;

export const MESSAGE_KEYS: Allowlist = scalars("conversationId", "sentAt", "content", "type");

/** `Poll.toMap` without `creatorId` (the requester) and without `voterIds`. */
export const POLL_KEYS: Allowlist = {
  ...scalars("id", "question", "allowMultipleChoices", "deadline", "createdAt", "isClosed"),
  options: { list: scalars("id", "text") },
};

function conversationIdOf(doc: admin.firestore.DocumentSnapshot): string | null {
  const id = doc.get("conversationId");
  return typeof id === "string" && id.length > 0 ? id : null;
}

/** The conversation ids among `ids` whose document is gone or does not list `uid`. */
async function leftConversations(
  database: admin.firestore.Firestore,
  ids: Set<string>,
  uid: string,
): Promise<Set<string>> {
  const snaps = await getAllInChunks(
    database,
    [...ids].map((id) => database.collection(Collections.conversations).doc(id)),
    ["participantIds"],
  );
  const left = new Set<string>();
  for (const snap of snaps) {
    const participants = snap.exists ? snap.get("participantIds") : undefined;
    if (!Array.isArray(participants) || !participants.includes(uid)) left.add(snap.id);
  }
  return left;
}

function messageRow(doc: admin.firestore.DocumentSnapshot, uid: string): Row {
  const data = doc.data() ?? {};
  if (data.senderId !== uid) {
    return { messageId: doc.id, sent_by_you: false, names_you_as_poll_creator: true };
  }
  const row: Row = { messageId: doc.id, ...project(data, MESSAGE_KEYS), sent_by_you: true };
  const metadata = data.metadata;
  const poll = isPlainObject(metadata) ? metadata.poll : undefined;
  if (isPlainObject(poll) && poll.creatorId === uid) row.poll = project(poll, POLL_KEYS);
  return row;
}

async function messagesInLeftConversations(
  database: admin.firestore.Firestore,
  uid: string,
): Promise<Row[]> {
  const messages = database.collection(Collections.messages);
  const [own, authored] = await Promise.all([
    cappedDocs(
      messages.where("senderId", "==", uid).select("conversationId"),
      MAX_OWN_MESSAGE_SCAN,
      "own_message_scan",
    ),
    cappedDocs(
      messages.where("metadata.poll.creatorId", "==", uid),
      MAX_AUTHORED_POLLS,
      "authored_polls",
    ),
  ]);

  const conversationIds = new Set<string>();
  for (const doc of [...own, ...authored]) {
    const id = conversationIdOf(doc);
    if (id !== null) conversationIds.add(id);
  }
  const left = await leftConversations(database, conversationIds, uid);
  const inLeft = (doc: admin.firestore.DocumentSnapshot): boolean => {
    const id = conversationIdOf(doc);
    return id !== null && left.has(id);
  };

  const authoredById = new Map(authored.filter(inLeft).map((doc) => [doc.id, doc]));
  const ownRefs = own
    .filter((doc) => inLeft(doc) && !authoredById.has(doc.id))
    .map((doc) => doc.ref);
  const total = ownRefs.length + authoredById.size;
  if (total > MAX_LEFT_MESSAGES) throw new Decline("left_messages", total);

  const ownFull = await getAllInChunks(database, ownRefs);
  const rows = [
    ...ownFull.filter((snap) => snap.exists && snap.get("senderId") === uid),
    ...authoredById.values(),
  ].map((doc) => messageRow(doc, uid));
  return sortRows(rows, "messageId");
}

export const MESSAGE_SECTIONS: readonly SectionDef[] = [
  { name: "messages_in_left_conversations", read: messagesInLeftConversations },
];
