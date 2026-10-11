/**
 * P6-U09 / BUT-916 — the FIRST factor for `recoverWithMfaBackupCode`, proven
 * server-side against the Identity Toolkit REST API. The caller has no ID token
 * (an enrolled account gets none before the second factor), so the server
 * repeats the sign-in itself and accepts only an answer carrying
 * `mfaPendingCredential`.
 *
 * Two proofs:
 *  - e-mail + password (`accounts:signInWithPassword`);
 *  - a Google or Apple id token (`accounts:signInWithIdp`), with the raw nonce
 *    for Apple, whose id token carries only its hash.
 *
 * The uid is taken only from Identity Toolkit's answer, never from the request.
 * Id tokens, nonces, passwords and every token in an answer are never logged,
 * stored or returned.
 */

import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";

/** How the first factor answered. */
export type FirstFactor =
  | { outcome: "mfa-required"; uid: string }
  | { outcome: "no-mfa" }
  | { outcome: "invalid" }
  | { outcome: "unavailable" };

export const IDP_PROVIDER_IDS = ["google.com", "apple.com"] as const;
export type IdpProviderId = (typeof IDP_PROVIDER_IDS)[number];

export type FirstFactorProof =
  | { kind: "password"; email: string; password: string }
  | {
      kind: "idp";
      providerId: IdpProviderId;
      idToken: string;
      /** The raw nonce; required for apple.com. */
      nonce: string | null;
    };

export interface ParsedRecoveryRequest {
  proof: FirstFactorProof;
  code: string;
}

const PASSWORD_KEYS = ["email", "password"] as const;
const IDP_KEYS = ["providerId", "idToken", "nonce"] as const;
const ALLOWED_KEYS = new Set<string>(["code", ...PASSWORD_KEYS, ...IDP_KEYS]);

export const MAX_ID_TOKEN_LENGTH = 8192;
export const MAX_NONCE_LENGTH = 512;

export function asBoundedString(value: unknown, max: number): string | null {
  return typeof value === "string" && value.length > 0 && value.length <= max
    ? value
    : null;
}

function present(value: unknown): boolean {
  return value !== undefined && value !== null;
}

/**
 * Exactly one proof plus a code, or null. A request carrying both proofs, half
 * of one, an unknown key or an unknown provider is null, and the caller answers
 * it with the same refusal as a wrong password.
 */
export function parseRecoveryRequest(data: unknown): ParsedRecoveryRequest | null {
  if (typeof data !== "object" || data === null || Array.isArray(data)) return null;
  const req = data as Record<string, unknown>;
  if (Object.keys(req).some((k) => !ALLOWED_KEYS.has(k))) return null;
  const code = asBoundedString(req.code, 64);
  if (!code) return null;
  const hasPassword = PASSWORD_KEYS.some((k) => present(req[k]));
  const hasIdp = IDP_KEYS.some((k) => present(req[k]));
  if (hasPassword === hasIdp) return null;

  if (hasPassword) {
    const email = asBoundedString(req.email, 320);
    const password = asBoundedString(req.password, 4096);
    if (!email || !password) return null;
    return { proof: { kind: "password", email, password }, code };
  }

  const providerId = (IDP_PROVIDER_IDS as readonly unknown[]).includes(req.providerId)
    ? (req.providerId as IdpProviderId)
    : null;
  const idToken = asBoundedString(req.idToken, MAX_ID_TOKEN_LENGTH);
  const nonce = present(req.nonce) ? asBoundedString(req.nonce, MAX_NONCE_LENGTH) : null;
  if (!providerId || !idToken) return null;
  if (present(req.nonce) && nonce === null) return null;
  if (providerId === "apple.com" && nonce === null) return null;
  return { proof: { kind: "idp", providerId, idToken, nonce }, code };
}

/** The OAuth handler of the project's own auth domain, as the Firebase SDKs use. */
export function projectAuthHandlerUri(projectId: string | undefined): string {
  return projectId ? `https://${projectId}.firebaseapp.com/__/auth/handler` : "";
}

/** One Identity Toolkit call; null when it could not be made or read. */
async function callIdentityToolkit(
  method: "signInWithPassword" | "signInWithIdp",
  apiKey: string,
  payload: Record<string, unknown>,
  fetchFn: typeof fetch,
): Promise<Record<string, unknown> | null> {
  let response: Response;
  try {
    response = await fetchFn(
      `https://identitytoolkit.googleapis.com/v1/accounts:${method}?key=${encodeURIComponent(apiKey)}`,
      {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(payload),
      },
    );
  } catch {
    return null;
  }
  try {
    return (await response.json()) as Record<string, unknown>;
  } catch {
    return null;
  }
}

function errorMessage(body: Record<string, unknown>): string {
  const message = (body.error as { message?: unknown } | undefined)?.message;
  return typeof message === "string" ? message : "";
}

function nonEmpty(value: unknown): string | null {
  return typeof value === "string" && value.length > 0 ? value : null;
}

/**
 * The first factor, proven server-side by a password sign-in. An enrolled
 * account answers with `mfaPendingCredential` and no token.
 */
export async function verifyFirstFactorWithIdentityToolkit(
  email: string,
  password: string,
  apiKey: string,
  fetchFn: typeof fetch = fetch,
  lookupUid: (email: string) => Promise<string> = async (e) =>
    (await admin.auth().getUserByEmail(e)).uid,
): Promise<FirstFactor> {
  if (!apiKey) return { outcome: "unavailable" };
  const body = await callIdentityToolkit(
    "signInWithPassword",
    apiKey,
    { email, password, returnSecureToken: true },
    fetchFn,
  );
  if (body === null) return { outcome: "unavailable" };
  if (typeof body.mfaPendingCredential === "string") {
    const uid = nonEmpty(body.localId) ?? (await lookupUid(email));
    return { outcome: "mfa-required", uid };
  }
  if (typeof body.idToken === "string") {
    // The password is right but there is no second factor. The tokens in
    // [body] are never read, returned, stored or logged; the caller answers
    // exactly as for a wrong password.
    return { outcome: "no-mfa" };
  }
  if (
    /INVALID_LOGIN_CREDENTIALS|INVALID_PASSWORD|EMAIL_NOT_FOUND|USER_DISABLED|INVALID_EMAIL/.test(
      errorMessage(body),
    )
  ) {
    return { outcome: "invalid" };
  }
  return { outcome: "unavailable" };
}

/** Identity Toolkit errors that mean "this id token does not sign anyone in". */
const IDP_INVALID =
  /INVALID_IDP_RESPONSE|INVALID_ID_TOKEN|MISSING_OR_INVALID_NONCE|INVALID_CREDENTIAL_OR_PROVIDER_ID|FEDERATED_USER_ID_ALREADY_LINKED|EMAIL_EXISTS|USER_DISABLED|USER_NOT_FOUND|EMAIL_NOT_FOUND/;

export interface IdpVerifierSeams {
  fetchFn?: typeof fetch;
  lookupUid?: (email: string) => Promise<string>;
  deleteUser?: (uid: string) => Promise<void>;
}

/**
 * The first factor, proven server-side by replaying the provider's id token.
 * Only `mfaPendingCredential` proves it. `signInWithIdp` can create an account
 * for an identity it does not know; `autoCreate: false` asks it not to, and an
 * answer that still reports `isNewUser` has that account deleted again before
 * the caller refuses.
 */
export async function verifyIdpFirstFactorWithIdentityToolkit(
  proof: Extract<FirstFactorProof, { kind: "idp" }>,
  apiKey: string,
  requestUri: string,
  seams: IdpVerifierSeams = {},
): Promise<FirstFactor> {
  const fetchFn = seams.fetchFn ?? fetch;
  const lookupUid =
    seams.lookupUid ?? (async (e: string) => (await admin.auth().getUserByEmail(e)).uid);
  const deleteUser = seams.deleteUser ?? ((uid: string) => admin.auth().deleteUser(uid));
  if (!apiKey || !requestUri) return { outcome: "unavailable" };

  const postBody = new URLSearchParams({
    id_token: proof.idToken,
    providerId: proof.providerId,
  });
  if (proof.nonce !== null) postBody.set("nonce", proof.nonce);
  const body = await callIdentityToolkit(
    "signInWithIdp",
    apiKey,
    {
      postBody: postBody.toString(),
      requestUri,
      returnSecureToken: true,
      returnIdpCredential: false,
      autoCreate: false,
    },
    fetchFn,
  );
  if (body === null) return { outcome: "unavailable" };

  if (typeof body.mfaPendingCredential === "string") {
    const localId = nonEmpty(body.localId);
    if (localId) return { outcome: "mfa-required", uid: localId };
    // The account's own address when it differs from the provider's.
    const answeredEmail = nonEmpty(body.originalEmail) ?? nonEmpty(body.email);
    if (!answeredEmail) return { outcome: "unavailable" };
    return { outcome: "mfa-required", uid: await lookupUid(answeredEmail) };
  }
  if (body.needConfirmation === true) return { outcome: "invalid" };
  if (typeof body.idToken === "string") {
    const createdUid = body.isNewUser === true ? nonEmpty(body.localId) : null;
    if (createdUid) {
      try {
        await deleteUser(createdUid);
      } catch (err) {
        logger.error("[mfa-recovery] could not delete an account created by the IdP check", {
          uid_prefix: createdUid.slice(0, 6),
          errCode: (err as { code?: unknown } | undefined)?.code,
        });
      }
    }
    // As on the password path: no token in [body] is read further.
    return { outcome: "no-mfa" };
  }
  if (IDP_INVALID.test(errorMessage(body))) return { outcome: "invalid" };
  return { outcome: "unavailable" };
}

/** The verifier for whichever proof the request carried. */
export function verifyFirstFactorProof(
  proof: FirstFactorProof,
  apiKey: string,
  requestUri: string,
  fetchFn: typeof fetch = fetch,
): Promise<FirstFactor> {
  return proof.kind === "password"
    ? verifyFirstFactorWithIdentityToolkit(proof.email, proof.password, apiKey, fetchFn)
    : verifyIdpFirstFactorWithIdentityToolkit(proof, apiKey, requestUri, { fetchFn });
}
