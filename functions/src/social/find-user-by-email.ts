/**
 * BUT-2264: find a user by their exact e-mail address without publishing it.
 *
 * `public_profiles` is readable by every signed-in account, so an address
 * stored there was readable by everyone whatever `allowEmailSearch` said. The
 * address now lives only in Auth, and the exact-address search comes here.
 *
 * Answers with the uid only, and only when the profile has
 * `allowEmailSearch == true` and is not hidden, the conditions the client
 * query had. A minor is found only after opting into search
 * (`isSearchable == true`), the BUT-1454 default-private rule. Every other
 * outcome is the same empty answer.
 *
 * Region: inherits europe-west1 via `setGlobalOptions` in index.ts.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { Collections } from "../shared/collections";
import { assertAgeCompliant } from "../shared/caller-eligibility";
import { enforceRateLimit } from "../middleware/rate_limiter";

export const MAX_EMAIL_LENGTH = 320;

export interface FindUserByEmailRequest {
  email: string;
}

export interface FindUserByEmailResponse {
  uid: string | null;
}

/** Returns the Auth uid for [email], or null when no account has it. */
export type UidByEmail = (email: string) => Promise<string | null>;

const authLookup: UidByEmail = async (email) => {
  try {
    return (await admin.auth().getUserByEmail(email)).uid;
  } catch (err) {
    const code = (err as { code?: string }).code;
    if (code === "auth/user-not-found") return null;
    if (code === "auth/invalid-email") {
      throw new HttpsError("invalid-argument", "email is malformed.");
    }
    throw err;
  }
};

export const findUserByEmail = onCall<FindUserByEmailRequest>(
  { enforceAppCheck: true },
  async (request): Promise<FindUserByEmailResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }
    const raw = request.data?.email;
    if (
      typeof raw !== "string" ||
      raw.length > MAX_EMAIL_LENGTH ||
      !raw.includes("@")
    ) {
      throw new HttpsError("invalid-argument", "email is malformed.");
    }
    assertAgeCompliant(request.auth);
    // `enforceRateLimit`, not `withRateLimit`: no LLM budget is spent here.
    await enforceRateLimit(request.auth.uid, "findUserByEmail");

    return findUserByEmailWithDeps(
      admin.firestore(),
      authLookup,
      request.auth.uid,
      raw,
    );
  },
);

/** Dependency-injected core, exposed for the emulator integration test. */
export async function findUserByEmailWithDeps(
  db: admin.firestore.Firestore,
  uidByEmail: UidByEmail,
  callerUid: string,
  email: string,
): Promise<FindUserByEmailResponse> {
  const none: FindUserByEmailResponse = { uid: null };
  const uid = await uidByEmail(email.trim().toLowerCase());
  if (uid == null || uid === callerUid) return none;

  const [profileSnap, userSnap] = await db.getAll(
    db.collection(Collections.publicProfiles).doc(uid),
    db.collection(Collections.users).doc(uid),
  );
  const profile = profileSnap.data();
  if (profile == null) return none;
  if (profile.allowEmailSearch !== true || profile.isHidden === true) {
    return none;
  }
  if (userSnap.get("isMinor") === true && profile.isSearchable !== true) {
    return none;
  }
  return { uid };
}
