/**
 * BUT-920: a guest that has linked an e-mail and password to its anonymous
 * account (the uid stays the same) gets the `ageCompliant` claim here, which
 * verifySignupAge withholds from a guest.
 *
 * The birth year comes from `users/{uid}.birthYear`, never from the request, so
 * upgrading cannot change the age the guest declared. The check is
 * verifySignupAge's own core, so the claim, the artefacts and the under-15
 * deletion are those of an ordinary signup.
 *
 * The client calls `getIdToken(true)` after a compliant result, as it does
 * after verifySignupAge.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { hashUid } from "../shared/hash-uid";
import { enforceRateLimit } from "../middleware/rate_limiter";
import { CallerAuth, assertNotGuest } from "../shared/caller-eligibility";
import {
  VerifySignupAgeDeps,
  VerifySignupAgeResponse,
  enforceIpAuditCap,
  isValidBirthYear,
  runVerifySignupAgeWithDeps,
  writeComplianceAudit,
} from "./verify-signup-age";
import { WEB_CALLABLE_ORIGINS } from "../shared/web-origins";

/** The provider the guest linked, as the refreshed token names it. */
const UPGRADE_PROVIDERS: ReadonlySet<string> = new Set([
  "password",
  "google.com",
  "apple.com",
]);

export function assertUpgradeCaller(
  auth: CallerAuth | undefined,
): asserts auth is CallerAuth {
  if (!auth) {
    throw new HttpsError("unauthenticated", "Sign-in required.");
  }
  assertNotGuest(auth);
  const provider = auth.token?.firebase?.sign_in_provider;
  if (typeof provider !== "string" || !UPGRADE_PROVIDERS.has(provider)) {
    throw new HttpsError("permission-denied", "upgrade-provider-not-supported");
  }
}

export const finishGuestUpgrade = onCall(
  {
    memory: "256MiB",
    timeoutSeconds: 60,
    cors: WEB_CALLABLE_ORIGINS,
    enforceAppCheck: true,
  },
  async (request): Promise<VerifySignupAgeResponse> => {
    // Refused before the rate-limit token and the per-IP audit slot are spent.
    assertUpgradeCaller(request.auth);
    const uid = request.auth.uid;
    await enforceRateLimit(uid, "finishGuestUpgrade");
    await enforceIpAuditCap(
      admin.firestore(),
      request.rawRequest?.ip ?? "unknown",
    );
    return runFinishGuestUpgradeWithDeps(
      { db: admin.firestore(), auth: admin.auth() },
      request.auth,
    );
  },
);

/**
 * DI core. Safe to retry: the age core re-ensures its artefacts once the claim
 * is set, and the upgrade audit row has a deterministic id.
 */
export async function runFinishGuestUpgradeWithDeps(
  deps: VerifySignupAgeDeps,
  caller: CallerAuth | undefined,
): Promise<VerifySignupAgeResponse> {
  // Checked again here because this exported core is what sets the claim.
  assertUpgradeCaller(caller);
  const uid = caller.uid;

  const stored = (await deps.db.doc(`users/${uid}`).get()).get("birthYear");
  if (!isValidBirthYear(stored)) {
    throw new HttpsError("failed-precondition", "no-stored-birth-year");
  }

  const result = await runVerifySignupAgeWithDeps(deps, uid, stored, {
    guest: false,
  });
  if (result.compliant) {
    await writeComplianceAudit(deps.db, uid, stored, "guest_upgrade");
    logger.info("[finishGuestUpgrade] claim set", { uid_prefix: hashUid(uid) });
  }
  return result;
}
