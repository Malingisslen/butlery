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
      // BUT-1856: somebody decided this person is out — themselves, or an
      // admin. The meal-vote category sync must not undo that decision on the
      // next poll just because they are still listed in the social group.
      tombstone: true,
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
 * Above this, `deleteGroupMenuPlans` declines rather than truncating. Not a
 * capacity estimate: it bounds what a hostile writer can make this pass cost,
 * since the create rule lets any signed-in account plant rows against another
 * group's id.
 */
export const MAX_GROUP_MENU_PLANS = 500;

/**
 * BUT-1979: delete every weekly menu plan belonging to a collapsed group.
 *
 * Selected on the `groupId` FIELD, not on the `{groupId}_{ISO week}` doc-id
 * prefix the Dart repository uses. A single equality filter needs no composite
 * index, it does not depend on the id convention, and — unlike a documentId
 * range — it is expressible against the unit-test fake, so this cleanup is
 * provable rather than assumed. What makes the field selector safe is the
 * WRITER: `GroupWeeklyMenuPlan.toFirestore` emits `groupId` unconditionally.
 *
 * [groupKey] is the CONVERSATION id, because that is what the producer writes
 * into the field (`messaging_service.dart` passes `groupId: conversation.id`).
 * It equals the chat-group id only because `create-chat-group.ts` sets
 * `conversationId = groupRef.id` — equal by construction, not by definition.
 *
 * Never throws. The caller has already cut the departing member's access, and
 * failing their "leave" because cleanup stumbled would be the wrong answer.
 */
async function deleteGroupMenuPlans(
  db: admin.firestore.Firestore,
  groupKey: string,
): Promise<void> {
  try {
    // CAPPED, and it DECLINES above the cap rather than truncating — the same
    // shape as `tryClearRoster` and the account cascade's roster sweep, and for
    // the same reason: the row count is chosen by whoever can write the
    // collection, not by us. `firestore.rules`' create limb for
    // `group_weekly_menu_plans` ties the caller only to their OWN submitted
    // `memberPermissions`, never to the chat group's members, and the doc-id
    // suffix is free — so any signed-in account can plant rows carrying another
    // group's `groupId`. `select()` keeps the bodies out of memory; each row is
    // otherwise up to 1 MB and `hasRequiredFields` is not `hasOnly`. That rule
    // also interpolates the submitted `groupId` into its regex UNESCAPED, so a
    // `groupId` of `.*` matches any id — which grants nothing extra here, since
    // the writer already chooses both sides and this sweep filters on exact
    // `==`.
    const snap = await db
      .collection(Collections.groupWeeklyMenuPlans)
      .where("groupId", "==", groupKey)
      .select()
      .limit(MAX_GROUP_MENU_PLANS + 1)
      .get();
    if (snap.empty) return;
    if (snap.size > MAX_GROUP_MENU_PLANS) {
      logger.error(
        "[removeChatGroupMember] implausible group menu plan count; not sweeping",
        { groupKey, planRows: snap.size },
      );
      return;
    }

    // Chunked to bound concurrency; the read above is capped.
    //
    // `allSettled`, not `all`: a rejection from `all` escapes the loop and
    // strands every LATER chunk too, so one un-deletable row would cost the
    // rest.
    const CHUNK = 50;
    let failed = 0;
    for (let i = 0; i < snap.docs.length; i += CHUNK) {
      const results = await Promise.allSettled(
        snap.docs.slice(i, i + CHUNK).map((d) => d.ref.delete()),
      );
      failed += results.filter((r) => r.status === "rejected").length;
    }
    const payload = { groupKey, count: snap.docs.length - failed, failed };
    if (failed > 0) {
      // At ERROR, matching `tryClearRoster`'s partial-failure severity: a leave
      // that strands plans is otherwise invisible to any error-level view, and
      // the teardown is never retried.
      logger.error(
        "[removeChatGroupMember] group menu plans partially deleted",
        payload,
      );
    } else {
      logger.info("[removeChatGroupMember] group menu plans deleted", payload);
    }
  } catch (e) {
    logger.error("[removeChatGroupMember] group menu plan cleanup failed", {
      groupKey,
      errCode: (e as { code?: number | string } | null)?.code ?? "unknown",
    });
  }
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
  // BEFORE the roster gate, deliberately. These plans never dereference the
  // conversation — `firestore.rules` gates their read, update and delete on
  // `memberPermissions` alone — so a declined roster clear must not strand
  // them for a reason that has nothing to do with them. A step that
  // early-returns skips every leg below it.
  await deleteGroupMenuPlans(db, conversationId);

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
