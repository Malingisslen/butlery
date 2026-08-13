/**
 * BUT-1838: the system rows a group chat writes about itself.
 *
 * Generalises `writeDepartureSystemMessage` from the callable this replaces. The
 * client has always tried to write these ("X skapade gruppen", "X har lagts till
 * i gruppen") and the `messages` create rule has always refused them —
 * `senderId: "system"` can never equal `request.auth.uid`. Under the Admin SDK
 * they finally land, which is a feature and a trap at once.
 *
 * **`metadata.subjectUserId` is the Article-17 erasure handle, and it is not
 * optional.** These rows embed a real display name in free text under a sender
 * nobody owns, so the deletion cascade's `messages where senderId == uid` sweep
 * never matches them, and `syncConversationLastMessage` copies the name onward
 * into `conversations/{id}.lastMessage.content`. Once the person has left the
 * group, the cascade stops visiting the conversation at all. The handle is what
 * `anonymizeSystemMessagesAboutUser` queries; equality on a nested field is
 * covered by the automatic single-field index, so it needs no declaration.
 *
 * Copy mirrors `chatGroupCreatedMessage`, `chatParticipantAdded` and
 * `chatParticipantLeft` in `lib/l10n/app_sv.arb`. Two homes for one sentence is
 * a real cost, and the alternative — shipping the ARB to the server — is a
 * bigger one; the mitigation is that these three strings are named here so a
 * translator's edit can be followed.
 */

import * as admin from "firebase-admin";
import { Collections } from "../shared/collections";

export enum SystemGroupEvent {
  groupCreated = "group_created",
  memberAdded = "member_added",
  memberLeft = "participant_left",
}

export interface GroupSystemMessageParams {
  conversationId: string;
  event: SystemGroupEvent;
  /**
   * Who the row is ABOUT — the erasure handle. For a creation row that is the
   * creator; for an add or a departure it is the member added or removed, not
   * the person who did it.
   */
  subjectUserId: string;
  /** Display name of the person the row is about. */
  actorDisplayName: string;
  groupName?: string;
}

function contentFor(params: GroupSystemMessageParams): string {
  switch (params.event) {
    case SystemGroupEvent.groupCreated:
      return `${params.actorDisplayName} skapade gruppen "${params.groupName ?? ""}"`;
    case SystemGroupEvent.memberAdded:
      return `${params.actorDisplayName} har lagts till i gruppen`;
    case SystemGroupEvent.memberLeft:
      return `${params.actorDisplayName} har lämnat gruppen`;
  }
}

/**
 * Field names mirror `MessageDto.toFirestore` so the existing client parser and
 * the `syncConversationLastMessage` trigger read these rows unchanged.
 */
export async function writeGroupSystemMessage(
  db: admin.firestore.Firestore,
  params: GroupSystemMessageParams,
): Promise<void> {
  const now = admin.firestore.FieldValue.serverTimestamp();
  await db.collection(Collections.messages).add({
    conversationId: params.conversationId,
    senderId: "system",
    senderDisplayName: "System",
    senderAvatarUrl: null,
    content: contentFor(params),
    type: "system",
    status: "delivered",
    sentAt: now,
    deliveredAt: null,
    readAt: null,
    metadata: {
      systemEvent: params.event,
      subjectUserId: params.subjectUserId,
    },
    replyToMessageId: null,
    isEdited: false,
    editedAt: null,
    createdAt: now,
    updatedAt: now,
  });
}
