/**
 * BUT-1838: resolve a member's display name and avatar from `public_profiles`,
 * never from the request payload.
 *
 * The client used to supply both when creating a group chat
 * (`createGroupConversation` took `participantDisplayNames` and
 * `participantAvatarUrls` maps). That meant whoever created the group decided
 * what everybody else was called inside it — a name the whole group then sees in
 * the roster, and which the removed-member and system-message paths copy
 * forward. Reading the profile costs one batched `getAll` on a path that already
 * reads `users/{uid}` for the minor gate.
 *
 * A missing or unreadable profile yields a neutral placeholder rather than an
 * error: a member with no public profile is a real state (a fresh account), and
 * failing the whole invite over a cosmetic field would be the wrong trade.
 */

import * as admin from "firebase-admin";
import { Collections } from "../shared/collections";
import type { ChatGroupMember } from "./chat-group-writes";

/** Matches the roster validator's `displayName.size() <= 100` in firestore.rules. */
const MAX_DISPLAY_NAME = 100;
/** Matches the roster validator's `avatarUrl.size() <= 1000`. */
const MAX_AVATAR_URL = 1000;

export const UNKNOWN_MEMBER_NAME = "?";

export async function resolveMemberProfiles(
  db: admin.firestore.Firestore,
  uids: string[],
): Promise<ChatGroupMember[]> {
  if (uids.length === 0) return [];
  const refs = uids.map((u) => db.collection(Collections.publicProfiles).doc(u));
  const snaps = await db.getAll(...refs);
  return snaps.map((snap, i) => {
    const rawName = snap.exists ? snap.get("displayName") : null;
    const rawAvatar = snap.exists ? snap.get("avatarUrl") : null;
    const displayName =
      typeof rawName === "string" && rawName.length > 0
        ? rawName.slice(0, MAX_DISPLAY_NAME)
        : UNKNOWN_MEMBER_NAME;
    // Truncating an over-long URL would produce a broken link that looks valid;
    // dropping it shows the initials fallback the UI already has.
    const avatarUrl =
      typeof rawAvatar === "string" &&
      rawAvatar.length > 0 &&
      rawAvatar.length <= MAX_AVATAR_URL
        ? rawAvatar
        : null;
    return { uid: uids[i], displayName, avatarUrl };
  });
}
