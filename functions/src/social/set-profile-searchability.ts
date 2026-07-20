/**
 * BUT-1629: the ONLY path by which a minor can become discoverable in search.
 *
 * **Why a Cloud Function at all.** BUT-1626 added a rules hard-deny: a CLIENT
 * write that sets `public_profiles/{uid}.isSearchable:true` is rejected when
 * `users/{uid}.isMinor == true`, on both create and update. That closed the
 * tamper hole (a patched client could otherwise re-enable itself), but it also
 * left a compliant 15–17-year-old with no way to opt in at all — and Malin
 * decided (BUT-1454 Q1) that a minor MAY deliberately opt into discovery.
 *
 * This callable is that deliberate path. It writes with the Admin SDK, which
 * bypasses security rules, so the hard-deny can stay maximally strict for
 * every client write while one audited, authenticated, rate-limited server
 * path remains open. The client never gets a rules exemption.
 *
 * **What it deliberately does NOT do.** It writes exactly one field on exactly
 * the caller's own profile. There is no `uid` parameter — the target is always
 * `request.auth.uid`, so the callable cannot be aimed at another account, and
 * it never touches `isMinor` or `birthYear` (both stay CF-authoritative,
 * written only by `verifySignupAge`).
 *
 * Idempotent: a merge-set of the same value is a harmless no-op re-write.
 *
 * Region: inherits europe-west1 via `setGlobalOptions` in index.ts.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { enforceRateLimit } from "../middleware/rate_limiter";
import { hashUid } from "../shared/hash-uid";

const db = admin.firestore();

export interface SetProfileSearchabilityRequest {
  /** Desired discoverability. `true` opts the caller into people-search. */
  searchable: boolean;
}

export interface SetProfileSearchabilityResponse {
  success: boolean;
  /** The value now stored on the caller's public profile. */
  searchable: boolean;
}

export const setProfileSearchability =
  onCall<SetProfileSearchabilityRequest>(
    {
      // Defense-in-depth against a scripted (non-app) caller. Inert until App
      // Check is flipped to Enforce in the console — same posture as the other
      // user-facing social callables.
      enforceAppCheck: true,
    },
    async (request): Promise<SetProfileSearchabilityResponse> => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Sign-in required.");
      }
      const searchable = request.data?.searchable;
      if (typeof searchable !== "boolean") {
        throw new HttpsError(
          "invalid-argument",
          "searchable must be a boolean.",
        );
      }

      const uid = request.auth.uid;

      // enforceRateLimit, not withRateLimit: the latter also consumes the
      // GLOBAL LLM budget, and this callable costs no model spend. A privacy
      // toggle is flipped a handful of times ever, so the per-user bucket is
      // purely an abuse/retry-storm bound (mirrors verifySignupAge).
      await enforceRateLimit(uid, "setProfileSearchability");

      return setProfileSearchabilityWithDeps(db, uid, searchable);
    },
  );

/**
 * DI core — exposed for unit tests with a fake Firestore.
 *
 * Requires the caller's public profile to already exist. A merge-set onto a
 * missing doc would create a half-formed profile (a bare `isSearchable` with
 * no displayName), which the people-search query would then surface as a
 * nameless result; failing closed keeps profile creation on its one path.
 */
export async function setProfileSearchabilityWithDeps(
  database: admin.firestore.Firestore,
  callerUid: string,
  searchable: boolean,
): Promise<SetProfileSearchabilityResponse> {
  const profileRef = database.collection("public_profiles").doc(callerUid);
  const profileSnap = await profileRef.get();

  if (!profileSnap.exists) {
    throw new HttpsError(
      "failed-precondition",
      "Profile does not exist yet.",
    );
  }

  await profileRef.set(
    {
      isSearchable: searchable,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  logger.info("[setProfileSearchability] updated", {
    uid_hash: hashUid(callerUid),
    searchable,
  });

  return { success: true, searchable };
}
