/**
 * BUT-1838: create a chat group, server-side.
 *
 * **Why this cannot be a client write.** The minor-membership check has to run
 * over every proposed member, and `firestore.rules` cannot iterate a list — that
 * is the whole reason the old gate was a trigger that fired after the write and
 * only once (see `messaging/enforce-group-minor-membership.ts`). Moving creation
 * behind a callable is what makes the check run BEFORE anyone is in the group,
 * and what lets `firestore.rules` refuse client-created group conversations
 * outright, closing the squat in BUT-1830.
 *
 * **What it deliberately does not trust the client for.** Display names and
 * avatars are read from `public_profiles`, not taken from the request. The old
 * client path passed them, which meant the person creating a group chose what
 * everyone else's name looked like in it — visible in the roster the whole group
 * lists. The read costs one batched `getAll`, on a path this callable already
 * pays for.
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
import { checkRateLimit } from "../middleware/rate_limiter";
import { isValidDocId } from "../shared/valid-doc-id";
import {
  findInadmissibleMembers,
  MAX_CHAT_GROUP_MEMBERS,
} from "./minor-membership-gate";
import { stageGroupCreation, type ChatGroupMember } from "./chat-group-writes";
import { resolveMemberProfiles } from "./member-profiles";
import { writeGroupSystemMessage, SystemGroupEvent } from "./group-system-message";

const getDb = () => admin.firestore();

/** Matches the `title`/`name` budget the roster validator already allows. */
export const MAX_GROUP_NAME_LENGTH = 100;

export interface CreateChatGroupRequest {
  name: string;
  /** Uids to seat. The caller is added automatically if absent. */
  memberIds: string[];
}

export interface CreateChatGroupResponse {
  groupId: string;
  conversationId: string;
  memberCount: number;
}

export const createChatGroup = onCall<CreateChatGroupRequest>(
  { enforceAppCheck: true },
  async (request): Promise<CreateChatGroupResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }
    const callerUid = request.auth.uid;

    const name = (request.data?.name ?? "").trim();
    if (name.length === 0 || name.length > MAX_GROUP_NAME_LENGTH) {
      throw new HttpsError("invalid-argument", "Group name is required.");
    }
    const requested = Array.isArray(request.data?.memberIds)
      ? request.data.memberIds
      : [];
    if (!requested.every(isValidDocId)) {
      throw new HttpsError("invalid-argument", "memberIds is malformed.");
    }
    // The caller is always a member: a group you create but are not in has no
    // owner, no admin and no way back in, and it is also the degenerate shape
    // BUT-1830's squat relied on.
    const memberIds = [...new Set([callerUid, ...requested])];
    if (memberIds.length < 2) {
      throw new HttpsError(
        "invalid-argument",
        "A group needs at least one other member.",
      );
    }
    if (memberIds.length > MAX_CHAT_GROUP_MEMBERS) {
      throw new HttpsError(
        "invalid-argument",
        `A group can hold at most ${MAX_CHAT_GROUP_MEMBERS} members.`,
      );
    }

    const db = getDb();
    assertAgeCompliant(request.auth);
    await assertAccountMatured(db, request.auth);

    const limit = await checkRateLimit(callerUid, "createChatGroup");
    if (!limit.allowed) {
      throw new HttpsError("resource-exhausted", limit.reason ?? "Slow down.");
    }

    return createChatGroupWithDeps(db, callerUid, name, memberIds);
  },
);

/** Dependency-injected core — exposed for tests with a fake Firestore. */
export async function createChatGroupWithDeps(
  db: admin.firestore.Firestore,
  callerUid: string,
  name: string,
  memberIds: string[],
): Promise<CreateChatGroupResponse> {
  // THE GATE, before any write. A refusal names who could not be added so the
  // caller can act on it; the old trigger could only evict silently after the
  // fact, because by then the group already existed.
  const blocked = await findInadmissibleMembers(db, callerUid, memberIds);
  if (blocked.length > 0) {
    throw new HttpsError(
      "permission-denied",
      "Some people could not be added to this group.",
      { blockedUserIds: blocked },
    );
  }

  const members: ChatGroupMember[] = await resolveMemberProfiles(db, memberIds);

  const groupRef = db.collection(Collections.chatGroups).doc();
  const groupId = groupRef.id;
  const conversationId = groupRef.id;
  const joinedAt = admin.firestore.Timestamp.now();

  await db.runTransaction(async (tx) => {
    stageGroupCreation(tx, {
      db,
      groupId,
      conversationId,
      name,
      creatorUid: callerUid,
      members,
      joinedAt,
    });
  });

  // Outside the transaction on purpose: a failed system message must not undo a
  // created group. It is a courtesy row, not part of the membership contract.
  await writeGroupSystemMessage(db, {
    conversationId,
    event: SystemGroupEvent.groupCreated,
    subjectUserId: callerUid,
    actorDisplayName:
      members.find((m) => m.uid === callerUid)?.displayName ?? "?",
    groupName: name,
  }).catch((e) =>
    logger.error("[createChatGroup] system message write failed", {
      groupId,
      errCode: (e as { code?: number | string } | null)?.code ?? "unknown",
      errName: (e as Error | null)?.name,
    }),
  );

  logger.info("[createChatGroup] created", {
    groupId,
    memberCount: members.length,
  });

  return { groupId, conversationId, memberCount: members.length };
}
