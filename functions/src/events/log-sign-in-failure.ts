/**
 * BUT-2502: a sign-in that failed on the phone leaves no trace anywhere we can
 * read. The app keeps the Firebase error code in its own log, and Crashlytics
 * sends nothing without analytics consent.
 *
 * Malin decided 2026-11-04 (decision card, "Ja, med rad i policyn") that a
 * failed sign-in is reported without consent, on legitimate interest, carrying
 * no personal data: which provider, which step, which platform and the error
 * code. Never an address, a uid or free text.
 *
 * The caller is signed out (the sign-in is what failed), so there is no auth
 * requirement. App Check is enforced, and every field is checked against a
 * closed list or a short code pattern, so a caller cannot put text of its own
 * into the log.
 */

import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import { WEB_CALLABLE_ORIGINS } from "../shared/web-origins";

// The Dart side mirrors these lists (SignInFailureReporter).
export const SIGN_IN_FAILURE_PROVIDERS = ["google", "apple"];
export const SIGN_IN_FAILURE_STAGES = ["signIn", "signInRecovered"];
export const SIGN_IN_FAILURE_PLATFORMS = ["android", "ios", "web"];

// Firebase codes are words joined by '-'; the app prefixes its own with a kind
// and ':'. Anything with a space or an '@' is refused.
const CODE_PATTERN = /^[a-z0-9][a-z0-9:_.-]{0,63}$/i;

export interface SignInFailureData {
  provider?: unknown;
  stage?: unknown;
  platform?: unknown;
  code?: unknown;
}

export type SignInFailureValidation =
  | { kind: "invalid"; reason: string }
  | {
      kind: "log";
      payload: { provider: string; stage: string; platform: string; code: string };
    };

function oneOf(value: unknown, allowed: string[]): string | null {
  return typeof value === "string" && allowed.includes(value) ? value : null;
}

export function validateSignInFailure(
  data: SignInFailureData,
): SignInFailureValidation {
  const provider = oneOf(data.provider, SIGN_IN_FAILURE_PROVIDERS);
  if (provider === null) return { kind: "invalid", reason: "provider" };
  const stage = oneOf(data.stage, SIGN_IN_FAILURE_STAGES);
  if (stage === null) return { kind: "invalid", reason: "stage" };
  const platform = oneOf(data.platform, SIGN_IN_FAILURE_PLATFORMS);
  if (platform === null) return { kind: "invalid", reason: "platform" };
  const code = data.code;
  if (typeof code !== "string" || !CODE_PATTERN.test(code)) {
    return { kind: "invalid", reason: "code" };
  }
  return { kind: "log", payload: { provider, stage, platform, code } };
}

export const logSignInFailure = onCall<SignInFailureData>(
  {
    memory: "256MiB",
    timeoutSeconds: 10,
    cors: WEB_CALLABLE_ORIGINS,
    enforceAppCheck: true,
  },
  async (request: CallableRequest<SignInFailureData>) => {
    const result = validateSignInFailure(request.data ?? {});
    if (result.kind === "invalid") {
      throw new HttpsError("invalid-argument", `Invalid payload: ${result.reason}`);
    }
    // Filter in Cloud Logging with jsonPayload.event="sign_in_failure".
    logger.warn("sign_in_failure", { event: "sign_in_failure", ...result.payload });
    return { success: true };
  },
);
