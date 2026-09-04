/**
 * BUT-1838 / BUT-1796 / BUT-1828: add members to a chat group, server-side.
 *
 * **This operation has never once worked.** The client rebuilt
 * `participantIds` and wrote it back, which the conversations update rule
 * refuses outright, and then wrote the new member's roster row, which
 * `attestedWriter()` refuses because the parent cannot yet name them. Two
 * different walls, one button, both silent.
 *
 * It is also where the child-safety hole lived: `enforceGroupMinorMembership`
 * fires on conversation CREATE, so anyone added afterwards was checked by
 * nobody. Running the gate here — before the write, per person — is the point of
 * the whole redesign.
 *
 * **Who may add.** Group admins only, which is exactly what the client already
 * enforced in `GroupDetailViewModel.addMembers` and what
 * `authorizeDeparture` enforces for the mirror operation. The difference is that
 * it is now a rule rather than a suggestion a tampered client can skip.
 *
 * Region: inherits europe-west1 via `setGlobalOptions` in index.ts.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { Collections } from "../shared/collections";
import {
  assertAccountMatured,
  assertAgeCompliant,
} from "../shared/caller-eligibility";
import { enforceRateLimit } from "../middleware/rate_limiter";
import { isValidDocId } from "../shared/valid-doc-id";
import {
  findInadmissibleMembers,
  MAX_CHAT_GROUP_MEMBERS,
} from "./minor-membership-gate";
import { stageMemberAdditions, type ChatGroupMember } from "./chat-group-writes";
import { resolveMemberProfiles } from "./member-profiles";
import {
  writeGroupSystemMessage,
  SystemGroupEvent,
} from "./group-system-message";

const getDb = () => admin.firestore();

export interface AddChatGroupMembersRequest {
  groupId: string;
  userIds: string[];
}

export interface AddChatGroupMembersResponse {
  success: boolean;
  /** Uids actually seated by this call; already-present uids are not repeated. */
  addedUserIds: string[];
  memberCount: number;
}

export const addChatGroupMembers = onCall<AddChatGroupMembersRequest>(
  { enforceAppCheck: true },
  async (request): Promise<AddChatGroupMembersResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }
    const groupId = request.data?.groupId;
    if (!isValidDocId(groupId)) {
      throw new HttpsError("invalid-argument", "groupId is required.");
    }
    const requested = Array.isArray(request.data?.userIds)
      ? [...new Set(request.data.userIds)]
      : [];
    if (requested.length === 0 || !requested.every(isValidDocId)) {
      throw new HttpsError("invalid-argument", "userIds is malformed.");
    }

    const db = getDb();
    assertAgeCompliant(request.auth);
    await assertAccountMatured(db, request.auth);

    // `enforceRateLimit`, NOT `withRateLimit`: the latter also spends the
    // GLOBAL LLM budget (`checkGlobalLimit`), so an exhausted AI quota would
    // start refusing group-chat operations that cost no model spend. Same
    // reasoning as `verify-signup-age.ts` and `set-profile-searchability.ts`,
    // and recorded in ADR-0013. It carries `retryAfterSeconds` in `details`,
    // which the hand-rolled throw here dropped, leaving the client to guess
    // (BUT-1862). This bucket declares no `dailyLimit`, so the wait it now
    // reports is the minute bucket's own — the daily-cap gap the ticket is
    // named for is `createChatGroup` and `ensureCategoryChat`.
    await enforceRateLimit(request.auth.uid, "addChatGroupMembers");

    return addChatGroupMembersWithDeps(db, request.auth.uid, groupId, requested);
  },
);

/** Dependency-injected core — exposed for tests with a fake Firestore. */
export async function addChatGroupMembersWithDeps(
  db: admin.firestore.Firestore,
  callerUid: string,
  groupId: string,
  userIds: string[],
): Promise<AddChatGroupMembersResponse> {
  const groupRef = db.collection(Collections.chatGroups).doc(groupId);

  // Read first, OUTSIDE the transaction, to decide authorization and to know
  // which uids are genuinely new — the gate's reads must not run inside a
  // transaction, where every document they touch would join the contention set
  // and a slow friend lookup could abort an unrelated concurrent invite.
  const groupSnap = await groupRef.get();
  if (!groupSnap.exists) {
    // NO ORACLE, same discipline as the removal callable: "no such group" and
    // "not your group" are one answer, because a group id in someone else's
    // hands must not confirm that the group exists.
    throw new HttpsError("permission-denied", "Not allowed.");
  }
  const data = groupSnap.data() ?? {};
  const memberIds: string[] = Array.isArray(data.memberIds)
    ? data.memberIds.filter(isValidDocId)
    : [];
  const adminIds: string[] = Array.isArray(data.adminIds)
    ? data.adminIds.filter(isValidDocId)
    : [];
  if (!memberIds.includes(callerUid)) {
    throw new HttpsError("permission-denied", "Not allowed.");
  }
  if (!adminIds.includes(callerUid)) {
    throw new HttpsError(
      "permission-denied",
      "Only a group admin can add members.",
    );
  }
  const rawConversationId: unknown = data.conversationId;
  if (!isValidDocId(rawConversationId)) {
    throw new HttpsError("failed-precondition", "Group has no conversation.");
  }
  // Bound to a plain `string` here rather than relied on through the closures
  // below: a type guard does not narrow across a callback boundary.
  const conversationId: string = rawConversationId;

  const newUids = userIds.filter((u) => !memberIds.includes(u));
  if (newUids.length === 0) {
    // Idempotent: re-adding people who are already in writes nothing and spams
    // no system message.
    return { success: true, addedUserIds: [], memberCount: memberIds.length };
  }
  if (memberIds.length + newUids.length > MAX_CHAT_GROUP_MEMBERS) {
    throw new HttpsError(
      "invalid-argument",
      `A group can hold at most ${MAX_CHAT_GROUP_MEMBERS} members.`,
    );
  }

  // THE GATE. Checked against the person doing the inviting, per person, before
  // anything is written.
  const blocked = await findInadmissibleMembers(db, callerUid, newUids);
  if (blocked.length > 0) {
    throw new HttpsError(
      "permission-denied",
      "Some people could not be added to this group.",
      { blockedUserIds: blocked },
    );
  }

  const members: ChatGroupMember[] = await resolveMemberProfiles(db, newUids);
  const joinedAt = admin.firestore.Timestamp.now();

  // What the transaction ACTUALLY seated, which is not necessarily what we
  // asked it to. A concurrent invite can seat someone between the read above
  // and the transaction; the loser must not then announce them a second time or
  // report an inflated count. Hoisted out of the closure for exactly that
  // reason — Firestore may run the closure more than once, so the last
  // assignment is the one that committed.
  let seated: ChatGroupMember[] = [];
  let memberCountAfter = memberIds.length;

  await db.runTransaction(async (tx) => {
    // Re-read inside the transaction so two concurrent invites cannot both pass
    // the cap check above and land a group over the limit, and so an add cannot
    // race a removal that emptied the group.
    const fresh = await tx.get(groupRef);
    if (!fresh.exists) {
      throw new HttpsError("failed-precondition", "Group no longer exists.");
    }
    const freshMembers: string[] = Array.isArray(fresh.get("memberIds"))
      ? (fresh.get("memberIds") as unknown[]).filter(isValidDocId)
      : [];
    const stillNew = members.filter((m) => !freshMembers.includes(m.uid));
    seated = stillNew;
    memberCountAfter = freshMembers.length + stillNew.length;
    if (stillNew.length === 0) return;
    if (memberCountAfter > MAX_CHAT_GROUP_MEMBERS) {
      throw new HttpsError(
        "invalid-argument",
        `A group can hold at most ${MAX_CHAT_GROUP_MEMBERS} members.`,
      );
    }
    stageMemberAdditions(tx, {
      db,
      groupId,
      conversationId,
      members: stillNew,
      addedBy: callerUid,
      joinedAt,
    });
  });

  await Promise.all(
    seated.map((member) =>
      writeGroupSystemMessage(db, {
        conversationId,
        event: SystemGroupEvent.memberAdded,
        subjectUserId: member.uid,
        actorDisplayName: member.displayName,
      }).catch((e) =>
        logger.error("[addChatGroupMembers] system message write failed", {
          groupId,
          errCode: (e as { code?: number | string } | null)?.code ?? "unknown",
          errName: (e as Error | null)?.name,
        }),
      ),
    ),
  );

  logger.info("[addChatGroupMembers] added", {
    groupId,
    addedCount: seated.length,
  });

  return {
    success: true,
    addedUserIds: seated.map((m) => m.uid),
    memberCount: memberCountAfter,
  };
}
