/**
 * BUT-2481 — "Logga ut från alla enheter" for Google/Apple accounts.
 *
 * Revokes every refresh token of the caller and hands back a custom token so
 * the calling device can sign straight back in. Other devices stop working
 * once their ID token expires (up to an hour); there is no client-side check.
 *
 * The caller must have signed in with Google or Apple in the last
 * REAUTH_MAX_AGE_SECONDS (the token's own `sign_in_provider`, not just the
 * account's provider list), and with a second factor if the account has one.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { WEB_CALLABLE_ORIGINS } from "../shared/web-origins";
import { enforceRateLimit } from "../middleware/rate_limiter";
import { REAUTH_MAX_AGE_SECONDS } from "./mfa-backup-codes";

export const REVOKE_OPERATION = "session_revoke_other";
export const REVOKE_RATE_LIMIT_KEY = "revokeOtherSessions";

const ALLOWED_SIGN_IN_PROVIDERS = ["google.com", "apple.com"];

export interface RevokeCaller {
  uid: string;
  token: {
    auth_time?: unknown;
    firebase?: {
      sign_in_provider?: unknown;
      sign_in_second_factor?: unknown;
    };
  };
}

export interface RevokeDeps {
  getAccount(uid: string): Promise<{
    providerIds: string[];
    enrolledFactorCount: number;
  }>;
  createCustomToken(uid: string): Promise<string>;
  revokeRefreshTokens(uid: string): Promise<void>;
  enforceRateLimit(uid: string): Promise<void>;
  markRevoked(uid: string): Promise<void>;
  audit(entry: Record<string, unknown>): Promise<void>;
  now(): number;
}

export type RevokeOutcome =
  | "revoked"
  | "denied_provider"
  | "denied_recent_login"
  | "denied_mfa"
  | "denied_rate_limit"
  | "denied_app_check"
  | "failed";

function recentLogin(): HttpsError {
  return new HttpsError("failed-precondition", "Recent sign-in required.", {
    code: "requires-recent-login",
  });
}

export async function runRevokeOtherSessions(
  deps: RevokeDeps,
  caller: RevokeCaller,
): Promise<{ customToken: string }> {
  const { uid } = caller;
  const record = (outcome: RevokeOutcome) =>
    deps.audit({
      userId: uid,
      action: REVOKE_OPERATION,
      outcome,
      granted: outcome === "revoked",
      at: deps.now(),
    });
  const deny = async (outcome: RevokeOutcome, err: HttpsError) => {
    await record(outcome);
    return err;
  };

  const provider = caller.token.firebase?.sign_in_provider;
  if (
    typeof provider !== "string" ||
    !ALLOWED_SIGN_IN_PROVIDERS.includes(provider)
  ) {
    // A custom-token session, a password session and an anonymous one all land
    // here, so one successful press cannot be chained into another.
    throw await deny(
      "denied_provider",
      new HttpsError("permission-denied", "Sign in with Google or Apple.", {
        code: "requires-recent-login",
      }),
    );
  }

  const authTimeSec = caller.token.auth_time;
  const nowSec = Math.floor(deps.now() / 1000);
  if (
    typeof authTimeSec !== "number" ||
    nowSec - authTimeSec > REAUTH_MAX_AGE_SECONDS
  ) {
    throw await deny("denied_recent_login", recentLogin());
  }

  const account = await deps.getAccount(uid);
  if (!account.providerIds.includes(provider)) {
    throw await deny(
      "denied_provider",
      new HttpsError("permission-denied", "Sign in with Google or Apple.", {
        code: "requires-recent-login",
      }),
    );
  }
  if (
    account.enrolledFactorCount > 0 &&
    !caller.token.firebase?.sign_in_second_factor
  ) {
    throw await deny("denied_mfa", recentLogin());
  }

  try {
    await deps.enforceRateLimit(uid);
  } catch (err) {
    await record("denied_rate_limit");
    throw err;
  }

  let customToken: string;
  try {
    // Minted before the revoke: if this fails nothing has changed. No
    // developer claims, so the new session carries only what the account has.
    customToken = await deps.createCustomToken(uid);
    await deps.revokeRefreshTokens(uid);
  } catch (err) {
    await record("failed");
    logger.error("[revoke-other-sessions] failed", {
      errName: err instanceof Error ? err.name : typeof err,
    });
    throw new HttpsError("internal", "Could not sign out other devices.");
  }

  try {
    await deps.markRevoked(uid);
  } catch (err) {
    // The notice at next sign-in is best effort; the revoke already happened.
    logger.error("[revoke-other-sessions] notice write failed", {
      errName: err instanceof Error ? err.name : typeof err,
    });
  }
  await record("revoked");
  return { customToken };
}

/**
 * `operation` is what the retention purge keys on: a row without it matches
 * neither purge query and would be kept forever.
 */
export function auditRow(entry: Record<string, unknown>): Record<string, unknown> {
  return { ...entry, operation: entry.action, resourceType: "session" };
}

async function writeAudit(entry: Record<string, unknown>): Promise<void> {
  try {
    await admin.firestore().collection("audit_logs").add({
      ...auditRow(entry),
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (err) {
    logger.error("[revoke-other-sessions] audit write failed", {
      errName: err instanceof Error ? err.name : typeof err,
    });
  }
}

export const revokeOtherSessions = onCall(
  {
    cors: WEB_CALLABLE_ORIGINS,
    enforceAppCheck: true,
    consumeAppCheckToken: true,
  },
  async (request): Promise<{ customToken: string }> => {
    if (request.app?.alreadyConsumed === true) {
      if (request.auth) {
        await writeAudit({
          userId: request.auth.uid,
          action: REVOKE_OPERATION,
          outcome: "denied_app_check",
          granted: false,
          at: Date.now(),
        });
      }
      throw new HttpsError("unauthenticated", "App Check token already used.");
    }
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }
    return runRevokeOtherSessions(
      {
        getAccount: async (uid) => {
          const user = await admin.auth().getUser(uid);
          return {
            providerIds: user.providerData.map((p) => p.providerId),
            enrolledFactorCount: user.multiFactor?.enrolledFactors?.length ?? 0,
          };
        },
        createCustomToken: (uid) => admin.auth().createCustomToken(uid),
        revokeRefreshTokens: (uid) => admin.auth().revokeRefreshTokens(uid),
        enforceRateLimit: (uid) => enforceRateLimit(uid, REVOKE_RATE_LIMIT_KEY),
        markRevoked: async (uid) => {
          // update(), not set(): an account being erased must not get a stub
          // profile back. A missing document is swallowed by the caller.
          await admin
            .firestore()
            .collection("users")
            .doc(uid)
            .update({
              sessionsRevokedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        },
        audit: writeAudit,
        now: () => Date.now(),
      },
      { uid: request.auth.uid, token: request.auth.token },
    );
  },
);
