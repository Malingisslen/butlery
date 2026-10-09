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
 *  - a wrong password, an unknown address, an account WITHOUT two-step
 *    verification and a wrong code all get the same refusal, so the endpoint
 *    is no password oracle and no credential-stuffing proxy;
 *  - every attempt takes a slot per client IP and in a coarse global budget
 *    before the password is checked; wrong codes are counted per account
 *    only after the password is proven, so knowing an address is not enough
 *    to lock its owner out. Each counter is checked and incremented in ONE
 *    transaction, so parallel requests cannot exceed the cap;
 *  - counter keys are HMACs under a secret pepper (no address or IP stored),
 *    and each counter carries `expiresAt` for the Firestore TTL policy;
 *  - every call spends a limited-use App Check token;
 *  - switching two-step verification off deletes the codes server-side
 *    (`clearMfaBackupCodes`), so a stale set never becomes valid again;
 *  - every accepted and every rejected code is written to the audit log;
 *  - a code set only counts for the enrollment it was made for: it must have
 *    been created shortly before a factor that is still enrolled, so a set
 *    left behind by an earlier enrollment cannot remove a later one.
 *
 * NEEDS the `IDENTITY_TOOLKIT_API_KEY` and `MFA_RECOVERY_PEPPER` secrets at
 * deploy time. The key is a server key restricted to the Identity Toolkit
 * API, not the app's web key. Without either, recovery answers `unavailable`
 * and never unlocks anything.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import {
  createHmac,
  randomBytes,
  randomInt,
  scrypt,
  timingSafeEqual,
} from "crypto";
import {
  MfaSecurityEvent,
  mfaEmailApiKey,
  notifyMfaSecurityEvent,
} from "./mfa-security-email";

/** Ten codes, as drawn and as §14.2 says. */
export const BACKUP_CODE_COUNT = 10;

/** No 0/O, 1/I/L: a code is read off paper. 31 symbols, 10 of them ≈ 49 bits. */
export const CODE_ALPHABET = "23456789ABCDEFGHJKMNPQRSTUVWXYZ";
export const CODE_LENGTH = 10;

/** Same recent-login rule as account deletion (request-account-deletion.ts). */
export const REAUTH_MAX_AGE_SECONDS = 5 * 60;

/**
 * How long before a factor's enrollment its code set may have been created.
 * The app creates the set, shows it, and enrolls the phone right after; a day
 * leaves room for an SMS that is slow to arrive.
 */
export const CODES_BEFORE_ENROLLMENT_MAX_MS = 24 * 60 * 60 * 1000;

/** Clock slack between Firestore's writer and the Auth server. */
const ENROLLMENT_CLOCK_SLACK_MS = 60 * 1000;

/**
 * Whether a set created at [createdAt] belongs to one of the factors enrolled
 * at [enrollmentTimes]. A set from an earlier enrollment that survived a
 * switch-off (for example one made outside the app, which never calls
 * `clearMfaBackupCodes`) is older than that window and does not count.
 */
export function codesBelongToEnrollment(
  createdAt: unknown,
  enrollmentTimes: number[],
): boolean {
  if (typeof createdAt !== "number") return false;
  return enrollmentTimes.some(
    (t) =>
      t >= createdAt - ENROLLMENT_CLOCK_SLACK_MS &&
      t - createdAt <= CODES_BEFORE_ENROLLMENT_MAX_MS,
  );
}

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

/**
 * One fixed-window limiter. Every counter below reserves its slot INSIDE a
 * Firestore transaction before the work it guards is done, so parallel
 * requests serialise on the counter document and cannot slip past the cap
 * (review finding 2: a read outside a transaction plus a blind `.set` let N
 * parallel guesses all read "4 failures" and all proceed).
 */
export interface AttemptPolicy {
  limit: number;
  windowMs: number;
  lockoutMs: number;
}

/**
 * Backup-code failures per account, counted only AFTER the password is proven
 * (finding 3): a stranger who merely knows the address cannot lock the owner
 * out. Five wrong codes within an hour lock the account's recovery for an hour.
 */
export const MAX_RECOVERY_FAILURES = 5;
export const RECOVERY_WINDOW_MS = 60 * 60 * 1000;
export const RECOVERY_LOCKOUT_MS = 60 * 60 * 1000;
export const UID_POLICY: AttemptPolicy = {
  limit: MAX_RECOVERY_FAILURES,
  windowMs: RECOVERY_WINDOW_MS,
  lockoutMs: RECOVERY_LOCKOUT_MS,
};

/**
 * Every recovery attempt per client IP (keyed by an HMAC of the IP), whatever
 * its outcome. This is what throttles password guessing and credential
 * stuffing through this endpoint; per-account password throttling is left to
 * Identity Toolkit itself.
 */
export const MAX_IP_ATTEMPTS = 10;
export const IP_POLICY: AttemptPolicy = {
  limit: MAX_IP_ATTEMPTS,
  windowMs: 60 * 60 * 1000,
  lockoutMs: 60 * 60 * 1000,
};

/**
 * A coarse ceiling on all recovery attempts together, against a botnet that
 * rotates IPs. Recovery is rare; this is far above honest use.
 */
export const MAX_GLOBAL_ATTEMPTS = 500;
export const GLOBAL_POLICY: AttemptPolicy = {
  limit: MAX_GLOBAL_ATTEMPTS,
  windowMs: 60 * 60 * 1000,
  lockoutMs: 15 * 60 * 1000,
};

export const GLOBAL_ATTEMPT_KEY = "global";

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

/** The state after one more counted attempt; reaching the limit locks. */
export function recordFailure(
  state: AttemptState,
  now: number,
  policy: AttemptPolicy = UID_POLICY,
): AttemptState {
  const inWindow = now - state.windowStart < policy.windowMs;
  const failures = (inWindow ? state.failures : 0) + 1;
  const windowStart = inWindow ? state.windowStart : now;
  return {
    failures,
    windowStart,
    lockedUntil: failures >= policy.limit ? now + policy.lockoutMs : null,
  };
}

/** When a counter document is useless and the TTL policy may delete it. */
export function attemptExpiry(state: AttemptState, policy: AttemptPolicy): number {
  return Math.max(state.windowStart + policy.windowMs, state.lockedUntil ?? 0);
}

/**
 * A keyed HMAC under the server-only pepper, so the collection holds neither
 * an address nor an IP, and a leaked document cannot be reversed by hashing
 * candidate values (a plain SHA-256 of an e-mail can).
 */
export function pepperedKey(pepper: string, kind: string, value: string): string {
  if (!pepper) throw new Error("mfa recovery pepper is not set");
  return createHmac("sha256", pepper).update(`${kind}:${value}`).digest("hex");
}

export function ipAttemptKey(pepper: string, ip: string | null | undefined): string {
  return `ip_${pepperedKey(pepper, "ip", ip && ip.length > 0 ? ip : "unknown")}`;
}

export function uidAttemptKey(uid: string): string {
  return `uid_${uid}`;
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
  /** The HMAC pepper. Empty means not configured: recovery fails closed. */
  pepper: string;
  verifyFirstFactor(email: string, password: string): Promise<FirstFactor>;
  /** Epoch millis of each second factor's enrollment. */
  enrollmentTimes(uid: string): Promise<number[]>;
  removeSecondFactors(uid: string): Promise<void>;
  revokeSessions(uid: string): Promise<void>;
  notify(uid: string, event: MfaSecurityEvent): Promise<void>;
  audit(entry: Record<string, unknown>): Promise<void>;
  now(): number;
}

export interface RecoveryRequest {
  email?: unknown;
  password?: unknown;
  code?: unknown;
}

/** Where the request came from. Used only as a peppered key, never logged. */
export interface RecoveryContext {
  ip?: string | null;
}

/**
 * The same words for a wrong password, an unknown address, an account without
 * two-step verification, an account whose code lock is on, and a wrong code:
 * the endpoint must not tell an attacker that a password is right (finding 1).
 */
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

function unavailable(): HttpsError {
  return new HttpsError("unavailable", "Sign-in could not be checked.");
}

function asBoundedString(value: unknown, max: number): string | null {
  return typeof value === "string" && value.length > 0 && value.length <= max
    ? value
    : null;
}

function parseAttempts(data: admin.firestore.DocumentData | undefined): AttemptState {
  if (!data) return NO_ATTEMPTS;
  return {
    failures: typeof data.failures === "number" ? data.failures : 0,
    windowStart: typeof data.windowStart === "number" ? data.windowStart : 0,
    lockedUntil: typeof data.lockedUntil === "number" ? data.lockedUntil : null,
  };
}

/**
 * Checks the counter and takes one slot in the same transaction. The slot is
 * taken BEFORE the guarded work runs, so a request that is still in flight
 * already counts; only a successful recovery gives its slot back (by deleting
 * the account counter).
 */
export async function reserveAttempt(
  db: admin.firestore.Firestore,
  key: string,
  policy: AttemptPolicy,
  now: number,
): Promise<{ allowed: boolean; retryAfterMs: number }> {
  const ref = db.collection(RECOVERY_ATTEMPTS_COLLECTION).doc(key);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const state = parseAttempts(snap.exists ? snap.data() : undefined);
    const gate = evaluateAttempt(state, now);
    if (!gate.allowed) return gate;
    const next = recordFailure(state, now, policy);
    tx.set(ref, {
      ...next,
      expiresAt: admin.firestore.Timestamp.fromMillis(attemptExpiry(next, policy)),
    });
    return { allowed: true, retryAfterMs: 0 };
  });
}

/**
 * The whole recovery, with its effects injected. Throws an `HttpsError` for
 * every refusal; resolves only when the second factor is gone.
 */
export async function runMfaRecovery(
  deps: RecoveryDeps,
  request: RecoveryRequest,
  context: RecoveryContext = {},
): Promise<{ recovered: true }> {
  const email = asBoundedString(request.email, 320);
  const password = asBoundedString(request.password, 4096);
  const code = asBoundedString(request.code, 64);
  if (!email || !password || !code) {
    throw new HttpsError("invalid-argument", "email, password and code are required.");
  }
  // Without the pepper no key can be derived safely: fail closed.
  if (!deps.pepper) throw unavailable();

  // Per-IP first, so a throttled client does not also spend the global budget.
  const ipGate = await reserveAttempt(
    deps.db,
    ipAttemptKey(deps.pepper, context.ip),
    IP_POLICY,
    deps.now(),
  );
  if (!ipGate.allowed) throw locked(ipGate.retryAfterMs);
  const globalGate = await reserveAttempt(
    deps.db,
    GLOBAL_ATTEMPT_KEY,
    GLOBAL_POLICY,
    deps.now(),
  );
  if (!globalGate.allowed) throw locked(globalGate.retryAfterMs);

  const first = await deps.verifyFirstFactor(email, password);
  if (first.outcome === "unavailable") throw unavailable();
  // A wrong password and an account without two-step verification answer
  // alike. The client only offers recovery after Firebase demanded a second
  // factor, so an honest caller never lands in "no-mfa".
  if (first.outcome === "invalid" || first.outcome === "no-mfa") {
    throw rejected();
  }

  // The password is proven: from here on the account's own code lock counts.
  const uid = first.uid;
  const uidKey = uidAttemptKey(uid);
  const uidGate = await reserveAttempt(deps.db, uidKey, UID_POLICY, deps.now());
  if (!uidGate.allowed) {
    // Answered like a wrong password: "locked" here would confirm the password.
    await deps.audit({
      userId: uid,
      action: "mfa_backup_code_locked",
      at: deps.now(),
    });
    throw rejected();
  }

  const enrollmentTimes = await deps.enrollmentTimes(uid);
  const codesRef = deps.db.collection(BACKUP_CODES_COLLECTION).doc(uid);
  const outcome = await deps.db.runTransaction(async (tx) => {
    const snap = await tx.get(codesRef);
    const data = snap.exists ? snap.data() : undefined;
    const codes = data?.codes as StoredCode[] | undefined;
    if (!Array.isArray(codes)) return "rejected" as const;
    // Every hash is still computed for a stale set, so the answer takes as
    // long as for a current one.
    const match = await matchCode(codes, code);
    if (!codesBelongToEnrollment(data?.createdAt, enrollmentTimes)) {
      return "stale" as const;
    }
    if (match === null || match.used) return "rejected" as const;
    const next = codes.map((c, i) =>
      i === match.index ? { ...c, usedAt: deps.now() } : c,
    );
    tx.update(codesRef, { codes: next });
    return "spent" as const;
  });

  if (outcome !== "spent") {
    // The slot reserved above stays taken: that is the counted failure.
    await deps.audit({
      userId: uid,
      action:
        outcome === "stale" ? "mfa_backup_codes_stale" : "mfa_backup_code_rejected",
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
  await deps.db.collection(RECOVERY_ATTEMPTS_COLLECTION).doc(uidKey).delete();
  await deps.audit({
    userId: uid,
    action: "mfa_backup_code_used",
    at: deps.now(),
  });
  await deps.notify(uid, "recovered");
  logger.info("[mfa-recovery] second factor removed with a backup code", {
    uid_prefix: uid.slice(0, 6),
  });
  return { recovered: true };
}

// --- unenrolment -------------------------------------------------------------

export interface ClearDeps {
  db: admin.firestore.Firestore;
  enrolledFactorCount(uid: string): Promise<number>;
  audit(entry: Record<string, unknown>): Promise<void>;
  now(): number;
}

/**
 * Deletes the backup codes of an account that no longer has a second factor
 * (finding 7). Called after the user switches two-step verification off, so a
 * stale set can never become valid again when a phone is enrolled later. The
 * server checks the factor list itself; it does not take the client's word.
 */
export async function runClearBackupCodes(
  deps: ClearDeps,
  uid: string,
): Promise<{ cleared: boolean }> {
  if ((await deps.enrolledFactorCount(uid)) > 0) {
    throw new HttpsError(
      "failed-precondition",
      "Two-step verification is still on.",
      { code: "mfa-still-enrolled" },
    );
  }
  const ref = deps.db.collection(BACKUP_CODES_COLLECTION).doc(uid);
  const existed = (await ref.get()).exists;
  if (existed) {
    await ref.delete();
    await deps.audit({
      userId: uid,
      action: "mfa_backup_codes_cleared",
      at: deps.now(),
    });
  }
  return { cleared: existed };
}

// --- generation --------------------------------------------------------------

export interface GenerateDeps {
  db: admin.firestore.Firestore;
  notify(uid: string, event: MfaSecurityEvent): Promise<void>;
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
  await deps.notify(uid, "codes-created");
  return { codes };
}

// --- production wiring -------------------------------------------------------

/** A server key that may call the Identity Toolkit API and nothing else. */
const identityToolkitApiKey = defineSecret("IDENTITY_TOOLKIT_API_KEY");

/**
 * The HMAC pepper for the attempt-counter keys. A secret, never a plain
 * parameter; unset or unreadable means recovery answers `unavailable`.
 */
const recoveryPepper = defineSecret("MFA_RECOVERY_PEPPER");

function readSecret(secret: ReturnType<typeof defineSecret>): string {
  try {
    return secret.value() ?? "";
  } catch {
    return "";
  }
}

/** Epoch millis of each enrolled second factor; an unreadable time is left out. */
async function enrollmentTimesOf(uid: string): Promise<number[]> {
  const factors = (await admin.auth().getUser(uid)).multiFactor?.enrolledFactors ?? [];
  const times = factors.map((f) => Date.parse(f.enrollmentTime ?? ""));
  if (times.some((t) => !Number.isFinite(t))) {
    // Otherwise indistinguishable from a stale set in the audit log.
    logger.warn("[mfa-recovery] factor without a readable enrollmentTime", {
      uid_prefix: uid.slice(0, 6),
    });
  }
  return times.filter((t) => Number.isFinite(t));
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
  if (typeof body.idToken === "string") {
    // The password is right but there is no second factor. The tokens in
    // [body] are never read, returned, stored or logged; the caller answers
    // exactly as for a wrong password.
    return { outcome: "no-mfa" };
  }
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
    secrets: [mfaEmailApiKey],
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
      {
        db: admin.firestore(),
        notify: notifyMfaSecurityEvent,
        audit: writeAudit,
        now: () => Date.now(),
      },
      request.auth.uid,
    );
  },
);

export const recoverWithMfaBackupCode = onCall<RecoveryRequest>(
  {
    cors: ["https://butlery.app", "https://www.butlery.app"],
    enforceAppCheck: true,
    // Replay protection: every call needs a fresh, limited-use App Check
    // token (the client asks for one with `limitedUseAppCheckToken`).
    consumeAppCheckToken: true,
    secrets: [recoveryPepper, identityToolkitApiKey, mfaEmailApiKey],
  },
  async (request): Promise<{ recovered: true }> => {
    if (request.app?.alreadyConsumed === true) {
      throw new HttpsError("unauthenticated", "App Check token already used.");
    }
    return runMfaRecovery(
      {
        db: admin.firestore(),
        pepper: readSecret(recoveryPepper),
        verifyFirstFactor: (email, password) =>
          verifyFirstFactorWithIdentityToolkit(
            email,
            password,
            readSecret(identityToolkitApiKey),
          ),
        enrollmentTimes: enrollmentTimesOf,
        removeSecondFactors: async (uid) => {
          await admin.auth().updateUser(uid, {
            multiFactor: { enrolledFactors: null },
          });
        },
        revokeSessions: (uid) => admin.auth().revokeRefreshTokens(uid),
        notify: notifyMfaSecurityEvent,
        audit: writeAudit,
        now: () => Date.now(),
      },
      request.data ?? {},
      { ip: request.rawRequest?.ip ?? null },
    );
  },
);

/**
 * Called by the app right after the user switches two-step verification off:
 * deletes the now-useless backup codes so they cannot come back to life with
 * a later enrollment. The server checks that no factor is left.
 */
export const clearMfaBackupCodes = onCall(
  {
    cors: ["https://butlery.app", "https://www.butlery.app"],
    enforceAppCheck: true,
  },
  async (request): Promise<{ cleared: boolean }> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }
    return runClearBackupCodes(
      {
        db: admin.firestore(),
        enrolledFactorCount: async (uid) =>
          (await admin.auth().getUser(uid)).multiFactor?.enrolledFactors
            ?.length ?? 0,
        audit: writeAudit,
        now: () => Date.now(),
      },
      request.auth.uid,
    );
  },
);
