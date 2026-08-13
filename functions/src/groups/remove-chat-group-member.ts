/**
 * BUT-1838: leave a chat group, or remove someone from it, server-side.
 *
 * Replaces `messaging/leave-group-conversation.ts`, which is deleted in the same
 * change rather than left standing beside this one — two homes for one operation
 * is the exact failure BUT-1795 records, and keeping the old callable alive
 * would leave a second path to membership that the group object does not know
 * about.
 *
 * **What carries over unchanged**, because it was right: the authorization core
 * (`authorizeDeparture`) and its verdict shape, the no-oracle gate, idempotency,
 * `arrayRemove` rather than an absolute list, and logging errors by CODE rather
 * than by `String(e)` — a Firestore error embeds the document path, which here
 * is a raw uid that outlives the group.
 *
 * **What changed, and why.** The old core refused direct conversations
 * (`isGroup: false`) because it was reachable with any conversation id; this one
 * takes a `groupId`, so a direct conversation cannot be addressed at all and the
 * branch has nothing to guard. And "admin" is now `chat_groups.adminIds` instead
 * of `conversations.metadata.creatorId` — one authoritative list rather than a
 * field on a document the client can write other parts of.
 *
 * Region: inherits europe-west1 via `setGlobalOptions` in index.ts.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { Collections } from "../shared/collections";
import { checkRateLimit } from "../middleware/rate_limiter";
import { isValidDocId } from "../shared/valid-doc-id";
import { tryClearRoster } from "../messaging/enforce-group-minor-membership";
import { stageMemberRemoval } from "./chat-group-writes";
import {
  writeGroupSystemMessage,
  SystemGroupEvent,
} from "./group-system-message";

const getDb = () => admin.firestore();

export interface RemoveChatGroupMemberRequest {
  groupId: string;
  /** Uid to remove. Omit to leave the group yourself. */
  userId?: string;
}

export interface RemoveChatGroupMemberResponse {
  success: boolean;
  /** False when the uid was already absent (idempotent re-invocation). */
  removed: boolean;
  /** Member count AFTER the removal. */
  remainingMembers: number;
}

export interface DepartureAuthorizationInput {
  callerUid: string;
  targetUid: string;
  /** `memberIds` from the group document, already sanitised. */
  memberIds: string[];
  /** `adminIds` from the group document, already sanitised. */
  adminIds: string[];
}

export type DepartureVerdict =
  | { kind: "proceed" }
  | { kind: "noop" }
  | { kind: "deny"; code: "permission-denied"; message: string };

/**
 * Pure authorization core (unit-tested): may `callerUid` remove `targetUid`?
 *
 * - Leaving yourself needs no admin right, and is a no-op success when you are
 *   already out (a double-tap, or a retry after a dropped response).
 * - Removing SOMEONE ELSE requires the caller to be an admin of the group.
 * - A group with no usable admin therefore has no remover — members can still
 *   leave, but nobody can be evicted. That fails CLOSED rather than handing the
 *   removal right to every member, which would be a group-takeover primitive.
 *
 * The caller-membership branch is defence in depth: the callable's own
 * no-oracle gate already turns every non-member into a uniform no-op before this
 * function is reached.
 */
export function authorizeDeparture(
  input: DepartureAuthorizationInput,
): DepartureVerdict {
  const { callerUid, targetUid, memberIds, adminIds } = input;
  const targetIsMember = memberIds.includes(targetUid);

  if (targetUid === callerUid) {
    return targetIsMember ? { kind: "proceed" } : { kind: "noop" };
  }
  if (!memberIds.includes(callerUid)) {
    return {
      kind: "deny",
      code: "permission-denied",
      message: "Only a member can remove people from this group.",
    };
  }
  if (!adminIds.includes(callerUid)) {
    return {
      kind: "deny",
      code: "permission-denied",
      message: "Only a group admin can remove other members.",
    };
  }
  return targetIsMember ? { kind: "proceed" } : { kind: "noop" };
}

export const removeChatGroupMember = onCall<RemoveChatGroupMemberRequest>(
  { enforceAppCheck: true },
  async (request): Promise<RemoveChatGroupMemberResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }
    const groupId = request.data?.groupId;
    if (!isValidDocId(groupId)) {
      throw new HttpsError("invalid-argument", "groupId is required.");
    }
    const rawTarget = request.data?.userId;
    const targetUid =
      rawTarget === undefined || rawTarget === null
        ? request.auth.uid
        : rawTarget;
    // Not merely a doc id: the uid is spliced into field paths
    // (`memberDisplayNames.${uid}`) by stageMemberRemoval, where a dot would
    // address a nested map instead of the literal key and leave the departed
    // member's name behind. See isValidDocId's own comment.
    if (!isValidDocId(targetUid)) {
      throw new HttpsError("invalid-argument", "userId is malformed.");
    }

    const db = getDb();
    // No age or maturity gate here, deliberately, and unlike the create and add
    // callables: those grant access, this one withdraws it. A user whose token
    // has gone stale must always be able to leave a group.
    const limit = await checkRateLimit(
      request.auth.uid,
      "removeChatGroupMember",
    );
    if (!limit.allowed) {
      throw new HttpsError("resource-exhausted", limit.reason ?? "Slow down.");
    }

    return removeChatGroupMemberWithDeps(
      db,
      request.auth.uid,
      groupId,
      targetUid,
    );
  },
);

/** Dependency-injected core — exposed for tests with a fake Firestore. */
export async function removeChatGroupMemberWithDeps(
  db: admin.firestore.Firestore,
  callerUid: string,
  groupId: string,
  targetUid: string,
): Promise<RemoveChatGroupMemberResponse> {
  const groupRef = db.collection(Collections.chatGroups).doc(groupId);

  const outcome = await db.runTransaction(async (tx) => {
    const snap = await tx.get(groupRef);
    const data = snap.exists ? (snap.data() ?? {}) : {};
    const memberIds: string[] = Array.isArray(data.memberIds)
      ? (data.memberIds as unknown[]).filter(isValidDocId)
      : [];
    const adminIds: string[] = Array.isArray(data.adminIds)
      ? (data.adminIds as unknown[]).filter(isValidDocId)
      : [];

    // NO ORACLE. Runs before any branch that reveals document shape, and
    // collapses three situations into one indistinguishable answer: the group
    // does not exist, the caller is not in it, or the caller already left.
    // Without it, holding a group id would answer "does this group exist, and
    // how many people are in it?" for any signed-in account.
    if (!snap.exists || !memberIds.includes(callerUid)) {
      return { removed: false, remaining: 0, displayName: "?", conversationId: null };
    }

    const verdict = authorizeDeparture({
      callerUid,
      targetUid,
      memberIds,
      adminIds,
    });
    if (verdict.kind === "deny") {
      throw new HttpsError(verdict.code, verdict.message);
    }
    if (verdict.kind === "noop") {
      return {
        removed: false,
        remaining: memberIds.length,
        displayName: "?",
        conversationId: null,
      };
    }

    const rawConversationId: unknown = data.conversationId;
    if (!isValidDocId(rawConversationId)) {
      throw new HttpsError("failed-precondition", "Group has no conversation.");
    }
    const conversationId: string = rawConversationId;

    const names = data.memberDisplayNames as Record<string, unknown> | undefined;
    const rawName = names?.[targetUid];
    const displayName =
      typeof rawName === "string" && rawName.length > 0 ? rawName : "?";

    stageMemberRemoval(tx, {
      db,
      groupId,
      conversationId,
      uid: targetUid,
      removedAt: admin.firestore.Timestamp.now(),
    });

    return {
      removed: true,
      remaining: memberIds.filter((u) => u !== targetUid).length,
      displayName,
      conversationId,
    };
  });

  if (outcome.removed && outcome.conversationId) {
    await db
      .collection(Collections.users)
      .doc(targetUid)
      .collection("conversation_memberships")
      .doc(outcome.conversationId)
      .delete()
      .catch((e) =>
        logger.error("[removeChatGroupMember] membership mirror cleanup failed", {
          groupId,
          errCode: (e as { code?: number | string } | null)?.code ?? "unknown",
          errName: (e as Error | null)?.name,
        }),
      );

    await writeGroupSystemMessage(db, {
      conversationId: outcome.conversationId,
      event: SystemGroupEvent.memberLeft,
      subjectUserId: targetUid,
      actorDisplayName: outcome.displayName,
    }).catch((e) =>
      logger.error("[removeChatGroupMember] system message write failed", {
        groupId,
        errCode: (e as { code?: number | string } | null)?.code ?? "unknown",
        errName: (e as Error | null)?.name,
      }),
    );

    if (outcome.remaining === 0) {
      await deleteEmptyGroup(db, groupId, outcome.conversationId);
    }
  }

  logger.info("[removeChatGroupMember] completed", {
    groupId,
    selfLeave: targetUid === callerUid,
    removed: outcome.removed,
    remaining: outcome.remaining,
  });

  return {
    success: true,
    removed: outcome.removed,
    remainingMembers: outcome.remaining,
  };
}

/**
 * The last member left: take the empty group down.
 *
 * **ORDER MATTERS, and it is the opposite of the obvious one.** The roster rows
 * must go BEFORE the conversation document, and the conversation before the
 * group. Deleting the conversation is the write that makes `parentDoc() == null`
 * true in `firestore.rules`; with the bootstrap branch removed in BUT-1838 that
 * no longer re-opens a write path, but the rows would still be orphaned under a
 * parent nobody can produce, and orphaned roster rows carrying names and avatars
 * are precisely the residual BUT-1825 exists for.
 *
 * `tryClearRoster` reports rather than throws, and a false answer means rows may
 * survive — so the conversation is left standing in that case. An empty group
 * whose documents linger is untidy; an unreachable set of rows carrying people's
 * names is a disclosure. Best-effort throughout: the access cut already happened
 * in the transaction above, and failing the caller's "leave" because cleanup
 * stumbled would be the wrong answer to give a person trying to get out.
 */
async function deleteEmptyGroup(
  db: admin.firestore.Firestore,
  groupId: string,
  conversationId: string,
): Promise<void> {
  const cleared = await tryClearRoster(db, conversationId);
  if (!cleared) {
    logger.error(
      "[removeChatGroupMember] roster not cleared; leaving the empty group standing",
      { groupId },
    );
    return;
  }
  await db
    .collection(Collections.conversations)
    .doc(conversationId)
    .delete()
    .catch((e) =>
      logger.error("[removeChatGroupMember] conversation delete failed", {
        groupId,
        errCode: (e as { code?: number | string } | null)?.code ?? "unknown",
      }),
    );
  await db
    .collection(Collections.chatGroups)
    .doc(groupId)
    .delete()
    .catch((e) =>
      logger.error("[removeChatGroupMember] group delete failed", {
        groupId,
        errCode: (e as { code?: number | string } | null)?.code ?? "unknown",
      }),
    );
}
