/**
 * P6-U09 — backup codes for two-step verification (flow 06).
 *
 * "Reservkoder hör i påslagningen — tio engångskoder innan skyddet gäller.
 * Utan reservväg och utan en utmaning i inloggningen (AU-10) får skyddet
 * inte gå att slå på" (produktregler.md:747-749; Skarmar v12 etapp 6
 * #mfalagg #mfaaktiv).
 *
 * Firebase phone MFA has no backup codes, so they live here:
 *
 *  - `generateMfaBackupCodes` (signed in, sign-in at most five minutes old)
 *    creates ten one-time codes, stores ONLY salted scrypt hashes in the
 *    server-only `mfa_backup_codes/{uid}` document, and returns the codes
 *    once. The client shows them and the user acknowledges them before the
 *    phone factor is enrolled.
 *
 *  - `recoverWithMfaBackupCode` is the way in without the phone. The caller
 *    has no ID token (an MFA account gets none before the second factor), so
 *    the callable cannot trust the client: it proves the FIRST factor itself
 *    by a password sign-in against the Identity Toolkit REST API, which for
 *    an enrolled account answers with a pending MFA credential instead of a
 *    token (Q-P6-E08). Only then is the code checked. A matching unused code
 *    is spent in a transaction, the phone factor is removed with the Admin
 *    SDK, every refresh token is revoked, and the client signs in again with
 *    the password and is asked to add a phone again.
 *
 * Security properties (each one has a unit case in
 * `__tests__/mfa-backup-codes.test.ts`):
 *  - codes and passwords are never logged or stored in the clear;
 *  - a code is compared against every stored hash in constant time per hash,
 *    without an early exit;
 *  - a used code fails, and a spent set cannot be replayed;
 *  - failures are counted per e-mail (hashed) and lock recovery for an hour
 *    after five, whether the password or the code was wrong, with the same
 *    answer for both so the endpoint is no password oracle;
 *  - every accepted and every rejected code is written to the audit log.
 *
 * NEEDS the web API key as the `IDENTITY_TOOLKIT_API_KEY` parameter at
 * deploy time. Without it recovery answers `unavailable` and never unlocks
 * anything — which is why the app keeps "Slå på tvåstegsverifiering" hidden
 * until this is deployed and reviewed (PQ-16, BUT-2142).
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineString } from "firebase-functions/params";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import {
  createHash,
  randomBytes,
  randomInt,
  scrypt,
  timingSafeEqual,
} from "crypto";

/** Ten codes, as drawn and as §14.2 says. */
export const BACKUP_CODE_COUNT = 10;

/** No 0/O, 1/I/L: a code is read off paper. 31 symbols, 10 of them ≈ 49 bits. */
export const CODE_ALPHABET = "23456789ABCDEFGHJKMNPQRSTUVWXYZ";
export const CODE_LENGTH = 10;

/** Recovery lock: five failures within an hour lock it for an hour. */
export const MAX_RECOVERY_FAILURES = 5;
export const RECOVERY_WINDOW_MS = 60 * 60 * 1000;
export const RECOVERY_LOCKOUT_MS = 60 * 60 * 1000;

/** Same recent-login rule as account deletion (request-account-deletion.ts). */
export const REAUTH_MAX_AGE_SECONDS = 5 * 60;

/** A new set at most this often per account. */
export const REGENERATE_MIN_INTERVAL_MS = 30 * 1000;

export const BACKUP_CODES_COLLECTION = "mfa_backup_codes";
export const RECOVERY_ATTEMPTS_COLLECTION = "mfa_recovery_attempts";

const SCRYPT_KEYLEN = 32;
const SCRYPT_OPTIONS = { N: 16384, r: 8, p: 1 };

export interface StoredCode {
  salt: string;
  hash: string;
  /** Epoch millis when the code was spent, or null. */
  usedAt: number | null;
}

// --- codes -------------------------------------------------------------------

/** Ten fresh codes from a CSPRNG. [rand] is replaceable in tests. */
export function generateCodes(
  count: number = BACKUP_CODE_COUNT,
  rand: (max: number) => number = randomInt,
): string[] {
  const codes = new Set<string>();
  while (codes.size < count) {
    let raw = "";
    for (let i = 0; i < CODE_LENGTH; i++) {
      raw += CODE_ALPHABET[rand(CODE_ALPHABET.length)];
    }
    codes.add(`${raw.slice(0, 5)}-${raw.slice(5)}`);
  }
  return [...codes];
}

/** What the user typed, as compared: upper case, no spaces or dashes. */
export function normalizeCode(input: string): string {
  return input.toUpperCase().replace(/[\s-]/g, "");
}

function scryptAsync(code: string, salt: Buffer): Promise<Buffer> {
  return new Promise((resolve, reject) =>
    scrypt(code, salt, SCRYPT_KEYLEN, SCRYPT_OPTIONS, (err, key) =>
      err ? reject(err) : resolve(key),
    ),
  );
}

/** A salted scrypt hash of one code. */
export async function hashCode(code: string, salt: Buffer): Promise<string> {
  return (await scryptAsync(normalizeCode(code), salt)).toString("base64");
}

export async function buildStoredCodes(codes: string[]): Promise<StoredCode[]> {
  return Promise.all(
    codes.map(async (code) => {
      const salt = randomBytes(16);
      return { salt: salt.toString("base64"), hash: await hashCode(code, salt), usedAt: null };
    }),
  );
}

/**
 * Index of the stored code [input] matches, and whether it was used.
 * Every hash is computed and compared; nothing returns early.
 */
export async function matchCode(
  stored: StoredCode[],
  input: string,
): Promise<{ index: number; used: boolean } | null> {
  const normalized = normalizeCode(input);
  let found: { index: number; used: boolean } | null = null;
  for (let i = 0; i < stored.length; i++) {
    const salt = Buffer.from(stored[i].salt, "base64");
    const expected = Buffer.from(stored[i].hash, "base64");
    const actual = await scryptAsync(normalized, salt);
    const same =
      expected.length === actual.length && timingSafeEqual(expected, actual);
    if (same && found === null) {
      found = { index: i, used: stored[i].usedAt !== null };
    }
  }
  return found;
}

// --- attempt limiting --------------------------------------------------------

export interface AttemptState {
  failures: number;
  windowStart: number;
  lockedUntil: number | null;
}

export const NO_ATTEMPTS: AttemptState = { failures: 0, windowStart: 0, lockedUntil: null };

/** Whether a recovery may be tried now, and if not, for how long not. */
export function evaluateAttempt(
  state: AttemptState,
  now: number,
): { allowed: boolean; retryAfterMs: number } {
  if (state.lockedUntil !== null && now < state.lockedUntil) {
    return { allowed: false, retryAfterMs: state.lockedUntil - now };
  }
  return { allowed: true, retryAfterMs: 0 };
}

/** The state after one more failure; the fifth in a window locks. */
export function recordFailure(state: AttemptState, now: number): AttemptState {
  const inWindow = now - state.windowStart < RECOVERY_WINDOW_MS;
  const failures = (inWindow ? state.failures : 0) + 1;
  const windowStart = inWindow ? state.windowStart : now;
  return {
    failures,
    windowStart,
    lockedUntil: failures >= MAX_RECOVERY_FAILURES ? now + RECOVERY_LOCKOUT_MS : null,
  };
}

/** The attempt key: a hash of the e-mail, so the collection holds no address. */
export function attemptKey(email: string): string {
  return createHash("sha256").update(email.trim().toLowerCase()).digest("hex");
}

// --- recovery ----------------------------------------------------------------

/** How the first factor answered. */
export type FirstFactor =
  | { outcome: "mfa-required"; uid: string }
  | { outcome: "no-mfa" }
  | { outcome: "invalid" }
  | { outcome: "unavailable" };

export interface RecoveryDeps {
  db: admin.firestore.Firestore;
  verifyFirstFactor(email: string, password: string): Promise<FirstFactor>;
  removeSecondFactors(uid: string): Promise<void>;
  revokeSessions(uid: string): Promise<void>;
  audit(entry: Record<string, unknown>): Promise<void>;
  now(): number;
}

export interface RecoveryRequest {
  email?: unknown;
  password?: unknown;
  code?: unknown;
}

/** Same words for a wrong password and a wrong code: no oracle. */
function rejected(): HttpsError {
  return new HttpsError("permission-denied", "The details do not match.", {
    code: "recovery-rejected",
  });
}

function locked(retryAfterMs: number): HttpsError {
  return new HttpsError("resource-exhausted", "Too many attempts.", {
    code: "recovery-locked",
    retryAfterSeconds: Math.ceil(retryAfterMs / 1000),
  });
}

function asBoundedString(value: unknown, max: number): string | null {
  return typeof value === "string" && value.length > 0 && value.length <= max
    ? value
    : null;
}

async function readAttempts(
  db: admin.firestore.Firestore,
  key: string,
): Promise<AttemptState> {
  const snap = await db.collection(RECOVERY_ATTEMPTS_COLLECTION).doc(key).get();
  const data = snap.exists ? snap.data() : undefined;
  if (!data) return NO_ATTEMPTS;
  return {
    failures: typeof data.failures === "number" ? data.failures : 0,
    windowStart: typeof data.windowStart === "number" ? data.windowStart : 0,
    lockedUntil: typeof data.lockedUntil === "number" ? data.lockedUntil : null,
  };
}

async function countFailure(
  deps: RecoveryDeps,
  key: string,
  state: AttemptState,
): Promise<void> {
  const next = recordFailure(state, deps.now());
  await deps.db
    .collection(RECOVERY_ATTEMPTS_COLLECTION)
    .doc(key)
    .set({ ...next });
}

/**
 * The whole recovery, with its effects injected. Throws an `HttpsError` for
 * every refusal; resolves only when the second factor is gone.
 */
export async function runMfaRecovery(
  deps: RecoveryDeps,
  request: RecoveryRequest,
): Promise<{ recovered: true }> {
  const email = asBoundedString(request.email, 320);
  const password = asBoundedString(request.password, 4096);
  const code = asBoundedString(request.code, 64);
  if (!email || !password || !code) {
    throw new HttpsError("invalid-argument", "email, password and code are required.");
  }

  const key = attemptKey(email);
  const state = await readAttempts(deps.db, key);
  const gate = evaluateAttempt(state, deps.now());
  if (!gate.allowed) throw locked(gate.retryAfterMs);

  const first = await deps.verifyFirstFactor(email, password);
  if (first.outcome === "unavailable") {
    throw new HttpsError("unavailable", "Sign-in could not be checked.");
  }
  if (first.outcome === "invalid") {
    await countFailure(deps, key, state);
    throw rejected();
  }
  if (first.outcome === "no-mfa") {
    // The password is right and there is nothing to recover: plain sign-in
    // works. Not a failure.
    throw new HttpsError("failed-precondition", "Two-step verification is off.", {
      code: "no-mfa",
    });
  }

  const uid = first.uid;
  const codesRef = deps.db.collection(BACKUP_CODES_COLLECTION).doc(uid);
  const spent = await deps.db.runTransaction(async (tx) => {
    const snap = await tx.get(codesRef);
    const codes = (snap.exists ? snap.data()?.codes : undefined) as
      | StoredCode[]
      | undefined;
    if (!Array.isArray(codes)) return null;
    const match = await matchCode(codes, code);
    if (match === null || match.used) return null;
    const next = codes.map((c, i) =>
      i === match.index ? { ...c, usedAt: deps.now() } : c,
    );
    tx.update(codesRef, { codes: next });
    return match.index;
  });

  if (spent === null) {
    await countFailure(deps, key, state);
    await deps.audit({
      userId: uid,
      action: "mfa_backup_code_rejected",
      at: deps.now(),
    });
    throw rejected();
  }

  // The code is spent first, so a crash below costs one code, never a replay.
  await deps.removeSecondFactors(uid);
  await deps.revokeSessions(uid);
  // Two-step verification is off now, so the remaining codes protect nothing;
  // a new set comes with the next enrollment.
  await codesRef.delete();
  await deps.db.collection(RECOVERY_ATTEMPTS_COLLECTION).doc(key).delete();
  await deps.audit({
    userId: uid,
    action: "mfa_backup_code_used",
    at: deps.now(),
  });
  logger.info("[mfa-recovery] second factor removed with a backup code", {
    uid_prefix: uid.slice(0, 6),
  });
  return { recovered: true };
}

// --- generation --------------------------------------------------------------

export interface GenerateDeps {
  db: admin.firestore.Firestore;
  audit(entry: Record<string, unknown>): Promise<void>;
  now(): number;
}

/**
 * Creates a new set for [uid], replacing any old one, and returns the codes.
 * The caller has already checked the sign-in and its age.
 */
export async function runGenerateBackupCodes(
  deps: GenerateDeps,
  uid: string,
): Promise<{ codes: string[] }> {
  const ref = deps.db.collection(BACKUP_CODES_COLLECTION).doc(uid);
  const existing = await ref.get();
  const createdAt = existing.exists ? existing.data()?.createdAt : undefined;
  if (
    typeof createdAt === "number" &&
    deps.now() - createdAt < REGENERATE_MIN_INTERVAL_MS
  ) {
    throw new HttpsError("resource-exhausted", "Backup codes were just created.");
  }
  const codes = generateCodes();
  await ref.set({
    codes: await buildStoredCodes(codes),
    createdAt: deps.now(),
    algorithm: "scrypt-n16384-r8-p1",
  });
  await deps.audit({
    userId: uid,
    action: "mfa_backup_codes_generated",
    at: deps.now(),
  });
  return { codes };
}

// --- production wiring -------------------------------------------------------

const identityToolkitApiKey = defineString("IDENTITY_TOOLKIT_API_KEY", {
  default: "",
});

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
  let response: Response;
  try {
    response = await fetchFn(
      `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${encodeURIComponent(apiKey)}`,
      {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ email, password, returnSecureToken: true }),
      },
    );
  } catch {
    return { outcome: "unavailable" };
  }
  let body: Record<string, unknown>;
  try {
    body = (await response.json()) as Record<string, unknown>;
  } catch {
    return { outcome: "unavailable" };
  }
  if (typeof body.mfaPendingCredential === "string") {
    const uid =
      typeof body.localId === "string" && body.localId.length > 0
        ? body.localId
        : await lookupUid(email);
    return { outcome: "mfa-required", uid };
  }
  if (typeof body.idToken === "string") return { outcome: "no-mfa" };
  const message =
    (body.error as { message?: unknown } | undefined)?.message ?? "";
  if (
    typeof message === "string" &&
    /INVALID_LOGIN_CREDENTIALS|INVALID_PASSWORD|EMAIL_NOT_FOUND|USER_DISABLED|INVALID_EMAIL/.test(
      message,
    )
  ) {
    return { outcome: "invalid" };
  }
  return { outcome: "unavailable" };
}

async function writeAudit(entry: Record<string, unknown>): Promise<void> {
  try {
    // `operation` + a server `timestamp` are what the 180-day purge filters
    // on (audit_logs/purge-expired.ts); nothing secret is in [entry].
    await admin.firestore().collection("audit_logs").add({
      ...entry,
      operation: entry.action,
      resourceType: "mfa",
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (err) {
    logger.error("[mfa-backup-codes] audit write failed", {
      errName: err instanceof Error ? err.name : typeof err,
    });
  }
}

export const generateMfaBackupCodes = onCall(
  {
    cors: ["https://butlery.app", "https://www.butlery.app"],
    enforceAppCheck: true,
  },
  async (request): Promise<{ codes: string[] }> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }
    const authTimeSec = request.auth.token.auth_time;
    const nowSec = Math.floor(Date.now() / 1000);
    if (
      typeof authTimeSec !== "number" ||
      nowSec - authTimeSec > REAUTH_MAX_AGE_SECONDS
    ) {
      throw new HttpsError("failed-precondition", "Recent sign-in required.", {
        code: "requires-recent-login",
      });
    }
    return runGenerateBackupCodes(
      { db: admin.firestore(), audit: writeAudit, now: () => Date.now() },
      request.auth.uid,
    );
  },
);

export const recoverWithMfaBackupCode = onCall<RecoveryRequest>(
  {
    cors: ["https://butlery.app", "https://www.butlery.app"],
    enforceAppCheck: true,
  },
  async (request): Promise<{ recovered: true }> => {
    return runMfaRecovery(
      {
        db: admin.firestore(),
        verifyFirstFactor: (email, password) =>
          verifyFirstFactorWithIdentityToolkit(
            email,
            password,
            identityToolkitApiKey.value(),
          ),
        removeSecondFactors: async (uid) => {
          await admin.auth().updateUser(uid, {
            multiFactor: { enrolledFactors: null },
          });
        },
        revokeSessions: (uid) => admin.auth().revokeRefreshTokens(uid),
        audit: writeAudit,
        now: () => Date.now(),
      },
      request.data ?? {},
    );
  },
);
