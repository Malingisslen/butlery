/**
 * BUT-1788: server-side "leave group" / "remove member".
 *
 * **The bug this closes.** Both operations ran entirely on the client:
 * `ConversationMutationModule.removeParticipant` rebuilt the conversation and
 * wrote the whole document back. But `firestore.rules` denies EVERY client
 * update whose diff touches `participantIds`:
 *
 *     allow update: if ... && !request.resource.data.diff(resource.data)
 *         .affectedKeys().hasAny(['participantIds', 'createdAt']);
 *
 * so leaving a group and removing a member have never once succeeded — the
 * write is refused, the ViewModel shows "kunde inte lämna gruppen", and the
 * user stays in the thread. The follow-up system message was dead on arrival
 * too: it carries `senderId: "system"`, which the `messages` create rule
 * (`request.auth.uid == request.resource.data.senderId`) also denies.
 *
 * **Why a Cloud Function and not a narrower rule.** A rule permissive enough to
 * let a client shrink `participantIds` cannot express "…and only by exactly
 * one entry, only your own uid unless you are the group admin". Rules cannot
 * diff array CONTENTS, so the narrow version would have to allow any client to
 * rewrite the membership list of any group it belongs to — trading a broken
 * feature for a takeover primitive. Admin SDK bypasses rules, so the deny above
 * stays exactly as it is and the authorization moves somewhere it can be
 * expressed.
 *
 * The write shape mirrors `buildGroupDepartureUpdate` in
 * `account/account-deletion-cascade.ts`: one `update()` removing the uid from
 * `participantIds` plus the four uid-keyed maps, because a partial application
 * would leave a departed member's name on a document they can no longer read.
 *
 * Region: inherits europe-west1 via `setGlobalOptions` in index.ts.
 * Idempotent: re-invocation after the member is already gone is a no-op success
 * and writes no second system message.
 *
 * **Discloses nothing to a non-participant.** A missing conversation, a
 * conversation the caller is not in, and a completed prior departure are ONE
 * answer with no participant count attached — see the gate in
 * `removeGroupParticipantWithDeps`.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { Collections } from "../shared/collections";
import { isValidDocId } from "./enforce-group-minor-membership";

// Lazy, like every sibling in this folder. A module-scope `admin.firestore()`
// runs at require() time and only worked here because tsc's CommonJS emit
// happens to place this module's require AFTER initializeApp() in index.ts —
// move the export above it and cold start throws "default Firebase app does
// not exist".
const getDb = () => admin.firestore();

/**
 * The uid-keyed maps `ConversationDto.toFirestore` writes onto a conversation
 * document. Mirrors `PER_USER_CONVERSATION_MAPS` in account-deletion-cascade.ts
 * (kept local rather than exported across the account/messaging boundary — the
 * two lists describe the same document but are owned by different flows, and a
 * shared symbol would make a change to one silently rewrite the other).
 */
const PER_USER_CONVERSATION_MAPS = [
  "participantDisplayNames",
  "participantAvatarUrls",
  "lastReadTimestamps",
  "perUserSettings",
] as const;

/** Mirror of `FirestoreCollections.userConversationMemberships` on the client. */
const USER_CONVERSATION_MEMBERSHIPS = "conversation_memberships";

/** Mirror of `FirestoreCollections.participants` on the client. */
const CONVERSATION_PARTICIPANTS = "participants";

/** Swedish UI string — mirrors `chatParticipantLeft` in `app_sv.arb`. */
function departureMessage(displayName: string): string {
  return `${displayName} har lämnat gruppen`;
}

export interface LeaveGroupConversationRequest {
  /** Document id in the top-level `conversations` collection. */
  conversationId: string;
  /**
   * Uid to remove. Omit (or pass your own uid) to leave the group yourself;
   * any other uid is an admin removal and requires the caller to be
   * `metadata.creatorId`.
   */
  participantId?: string;
}

export interface LeaveGroupConversationResponse {
  success: boolean;
  /** False when the uid was already absent (idempotent re-invocation). */
  removed: boolean;
  /** Participant count AFTER the removal. */
  remainingParticipants: number;
}

export interface DepartureAuthorizationInput {
  callerUid: string;
  targetUid: string;
  /** `participantIds` from the conversation doc, already sanitised. */
  participantIds: string[];
  isGroup: boolean;
  /** `metadata.creatorId`, or null when the doc records no usable creator. */
  creatorId: string | null;
}

export type DepartureVerdict =
  | { kind: "proceed" }
  | { kind: "noop" }
  | {
      kind: "deny";
      code: "failed-precondition" | "permission-denied";
      message: string;
    };

/**
 * Pure authorization core (unit-tested): may `callerUid` remove `targetUid`
 * from this conversation?
 *
 * Encodes the two checks the ViewModel does client-side — where they are UX
 * only, since a tampered client skips them — plus idempotency:
 *
 * - Direct (1:1) conversations have no leave semantics; membership there is
 *   fixed at create. Refused, matching the old client `ValidationException`.
 * - Leaving yourself needs no admin right, and is a no-op success when you are
 *   already out (a double-tap, or a retry after a dropped response).
 * - Removing SOMEONE ELSE requires the caller to be the group's recorded
 *   creator. The caller-membership branch below is defence in depth: the
 *   callable's own no-oracle gate already turns every non-participant into a
 *   uniform no-op before this function is reached.
 *   `metadata.creatorId` is bound to the creating client by the conversation
 *   CREATE rule (BUT-1626) and pinned by the UPDATE rule (BUT-1788), so it is a
 *   trustworthy admin identity. Both halves are load-bearing: `affectedKeys()`
 *   is top-level, so before the update conjunct existed any participant could
 *   rewrite `metadata` wholesale, name themselves creator and use this callable
 *   to evict everyone else.
 *   A group with no usable creatorId therefore has no admin — nobody but the
 *   member themselves can leave, which fails CLOSED rather than handing the
 *   removal right to every participant.
 */
export function authorizeDeparture(
  input: DepartureAuthorizationInput,
): DepartureVerdict {
  const { callerUid, targetUid, participantIds, isGroup, creatorId } = input;

  if (!isGroup) {
    return {
      kind: "deny",
      code: "failed-precondition",
      message: "Cannot remove participants from a direct conversation.",
    };
  }

  const targetIsParticipant = participantIds.includes(targetUid);

  if (targetUid === callerUid) {
    return targetIsParticipant ? { kind: "proceed" } : { kind: "noop" };
  }

  if (!participantIds.includes(callerUid)) {
    return {
      kind: "deny",
      code: "permission-denied",
      message: "Only a participant can remove members from this group.",
    };
  }
  // A null creatorId never equals a uid, so a group with no trustworthy admin
  // identity denies here — see the fail-closed note on this function.
  if (creatorId !== callerUid) {
    return {
      kind: "deny",
      code: "permission-denied",
      message: "Only the group admin can remove other members.",
    };
  }
  return targetIsParticipant ? { kind: "proceed" } : { kind: "noop" };
}

/**
 * The single `update()` that cuts a member out of a group conversation.
 *
 * One write, not five: the `participantIds` removal is the access cut and the
 * four map-key deletions are the same logical erasure. `arrayRemove` rather
 * than an absolute list so a concurrent add/remove on the same doc cannot be
 * clobbered by a stale snapshot.
 */
export function buildDepartureUpdate(uid: string): Record<string, unknown> {
  const update: Record<string, unknown> = {
    participantIds: admin.firestore.FieldValue.arrayRemove(uid),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  for (const map of PER_USER_CONVERSATION_MAPS) {
    update[`${map}.${uid}`] = admin.firestore.FieldValue.delete();
  }
  return update;
}

export const leaveGroupConversation = onCall<LeaveGroupConversationRequest>(
  {
    // BUT-760: user-facing messaging callable — App Check defense-in-depth.
    // Inert until App Check is flipped to Enforce in the console.
    enforceAppCheck: true,
  },
  async (request): Promise<LeaveGroupConversationResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }
    const conversationId = request.data?.conversationId;
    if (!isValidDocId(conversationId)) {
      throw new HttpsError("invalid-argument", "conversationId is required.");
    }
    // Omitted participantId means "leave the group myself".
    const rawTarget = request.data?.participantId;
    const targetUid =
      rawTarget === undefined || rawTarget === null
        ? request.auth.uid
        : rawTarget;
    // Not merely a doc id: the uid is spliced into field paths
    // (`participantDisplayNames.${uid}`) by buildDepartureUpdate, where a dot
    // would address a nested map instead of the literal key and leave the
    // departed member's name behind. See isValidDocId's own comment.
    if (!isValidDocId(targetUid)) {
      throw new HttpsError("invalid-argument", "participantId is malformed.");
    }

    return removeGroupParticipantWithDeps(
      getDb(),
      request.auth.uid,
      conversationId,
      targetUid,
    );
  },
);

/** Dependency-injected core — exposed for tests with a fake Firestore. */
export async function removeGroupParticipantWithDeps(
  database: admin.firestore.Firestore,
  callerUid: string,
  conversationId: string,
  targetUid: string,
): Promise<LeaveGroupConversationResponse> {
  const convoRef = database
    .collection(Collections.conversations)
    .doc(conversationId);

  const outcome = await database.runTransaction(async (tx) => {
    const snap = await tx.get(convoRef);
    const data = snap.exists ? (snap.data() ?? {}) : {};

    // Sanitise for USE (field-path building) but judge group-ness on the RAW
    // shape — same split as enforce-group-minor-membership.ts, so a padded
    // list cannot flip a group into the "direct conversation" refusal path.
    const rawParticipantIds: unknown[] = Array.isArray(data.participantIds)
      ? (data.participantIds as unknown[])
      : [];
    const participantIds = rawParticipantIds.filter(isValidDocId);

    // NO ORACLE. This gate runs before ANY branch that reveals document shape,
    // and collapses three situations into one indistinguishable answer: the
    // conversation does not exist, the caller is not in it, or the caller
    // already left. Without it the callable answered "does A DM B?" for
    // arbitrary uids to any signed-in account — direct-conversation ids are
    // deterministic (`direct_${sortedA}_${sortedB}`,
    // conversation_mutation_module.dart:57) and every uid is enumerable
    // (`public_profiles` doc id IS the uid, readable by any authenticated
    // user, firestore.rules:609-611), so a `not-found` vs. a
    // `failed-precondition` "cannot remove from a direct conversation" vs. a
    // `{removed:false, remainingParticipants:N}` reconstructed the private
    // messaging graph and leaked group sizes.
    //
    // Idempotency survives: a genuine retry after a successful leave is a
    // non-member too, and gets the same success/no-op it always did. What it
    // no longer gets is the participant COUNT.
    if (!snap.exists || !participantIds.includes(callerUid)) {
      return { removed: false, remaining: 0, displayName: "?" };
    }

    const isGroup = data.isGroup === true || rawParticipantIds.length > 2;

    const rawCreatorId: unknown = data.metadata?.creatorId;
    const creatorId = isValidDocId(rawCreatorId) ? rawCreatorId : null;

    const verdict = authorizeDeparture({
      callerUid,
      targetUid,
      participantIds,
      isGroup,
      creatorId,
    });
    if (verdict.kind === "deny") {
      throw new HttpsError(verdict.code, verdict.message);
    }
    if (verdict.kind === "noop") {
      return {
        removed: false,
        remaining: participantIds.length,
        displayName: "?",
      };
    }

    const names = data.participantDisplayNames as
      | Record<string, unknown>
      | undefined;
    const rawName = names?.[targetUid];
    const displayName = typeof rawName === "string" && rawName.length > 0
      ? rawName
      : "?";

    tx.update(convoRef, buildDepartureUpdate(targetUid));
    return {
      removed: true,
      remaining: participantIds.filter((u) => u !== targetUid).length,
      displayName,
    };
  });

  if (outcome.removed) {
    // Best-effort mirror cleanup. The participantIds cut above IS the access
    // revocation; a stale mirror only means the thread lingers in a list until
    // the next write, so a failure here must never fail the whole call.
    await Promise.all([
      convoRef
        .collection(CONVERSATION_PARTICIPANTS)
        .doc(targetUid)
        .delete()
        .catch((e) =>
          // By CODE, not `String(e)`: a Firestore error embeds the full document
          // path, which on these two deletes is a raw uid. The code is what
          // separates PERMISSION_DENIED from DEADLINE_EXCEEDED; the uid tells
          // nothing and outlives the group. Same RULE as the cleanup logs in
          // enforce-group-minor-membership.ts — not the same code, and the point
          // is the rule: two answers to one question is how the next author
          // guesses wrong.
          logger.error("[leaveGroupConversation] participant mirror cleanup failed", {
            conversationId,
            errCode: (e as { code?: number | string } | null)?.code ?? "unknown",
            errName: (e as Error | null)?.name,
          }),
        ),
      database
        .collection(Collections.users)
        .doc(targetUid)
        .collection(USER_CONVERSATION_MEMBERSHIPS)
        .doc(conversationId)
        .delete()
        .catch((e) =>
          logger.error("[leaveGroupConversation] membership mirror cleanup failed", {
            conversationId,
            errCode: (e as { code?: number | string } | null)?.code ?? "unknown",
            errName: (e as Error | null)?.name,
          }),
        ),
    ]);

    // The "X har lämnat gruppen" row the client used to attempt and the rules
    // always refused (senderId "system" != request.auth.uid). Written only on
    // a real removal so a retry cannot spam the thread.
    await writeDepartureSystemMessage(
      database,
      conversationId,
      outcome.displayName,
      targetUid,
    ).catch((e) =>
      logger.error("[leaveGroupConversation] system message write failed", {
        conversationId,
        errCode: (e as { code?: number | string } | null)?.code ?? "unknown",
        errName: (e as Error | null)?.name,
      }),
    );
  }

  logger.info("[leaveGroupConversation] completed", {
    conversationId,
    selfLeave: targetUid === callerUid,
    removed: outcome.removed,
    remaining: outcome.remaining,
  });

  return {
    success: true,
    removed: outcome.removed,
    remainingParticipants: outcome.remaining,
  };
}

/**
 * Field names mirror `MessageDto.toFirestore` so the existing client parser and
 * the `syncConversationLastMessage` trigger read this row unchanged.
 *
 * **`metadata.subjectUserId` is the Article-17 erasure handle, and it is not
 * optional.** This row embeds a real display name in free text under
 * `senderId: "system"`, and it is the FIRST system message in this app that
 * actually lands — the identical client-side write was always denied by the
 * `messages` create rule, which is exactly the trap: moving an operation to the
 * Admin SDK makes a long-dead PII write start working. The deletion cascade's
 * `deleteMessages` only anonymizes `messages where senderId == uid`, and
 * `buildGroupDepartureUpdate` only tombstones `lastMessage` when
 * `lastMessage.senderId === uid`; neither matches a row authored by "system".
 * Worse, once the person has left, the cascade never visits that conversation at
 * all (`participantIds array-contains uid` no longer matches them), and
 * `syncConversationLastMessage` has meanwhile copied the name verbatim into
 * `conversations/{id}.lastMessage.content`.
 *
 * The handle gives the cascade something to query: see
 * `anonymizeSystemMessagesAboutUser` in `account/account-deletion-cascade.ts`,
 * which rewrites both copies. Equality on a nested field is covered by the
 * automatic single-field index, so this needs no index declaration.
 */
export const SYSTEM_EVENT_PARTICIPANT_LEFT = "participant_left";

async function writeDepartureSystemMessage(
  database: admin.firestore.Firestore,
  conversationId: string,
  displayName: string,
  subjectUserId: string,
): Promise<void> {
  const now = admin.firestore.FieldValue.serverTimestamp();
  await database.collection(Collections.messages).add({
    conversationId,
    senderId: "system",
    senderDisplayName: "System",
    senderAvatarUrl: null,
    content: departureMessage(displayName),
    type: "system",
    status: "delivered",
    sentAt: now,
    deliveredAt: null,
    readAt: null,
    metadata: {
      systemEvent: SYSTEM_EVENT_PARTICIPANT_LEFT,
      subjectUserId,
    },
    replyToMessageId: null,
    isEdited: false,
    editedAt: null,
    createdAt: now,
    updatedAt: now,
  });
}
