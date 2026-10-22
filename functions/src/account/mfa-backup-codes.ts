/**
 * P6-U09 — backup codes for two-step verification (flow 06).
 *
 * "Reservkoder hör i påslagningen — tio engångskoder innan skyddet gäller.
 * Utan reservväg och utan en utmaning i inloggningen (AU-10) får skyddet
 * inte gå att slå på" (produktregler.md:747-749; Skarmar v12 etapp 6
 * #mfalagg #mfaaktiv).
 *
 * Firebase MFA has no backup codes, so they live here:
 *
 *  - `generateMfaBackupCodes` (signed in, sign-in at most five minutes old)
 *    creates ten one-time codes, stores ONLY salted scrypt hashes in the
 *    server-only `mfa_backup_codes/{uid}` document, and returns the codes
 *    once. The client shows them and the user acknowledges them before the
 *    second factor is enrolled.
 *
 *  - `recoverWithMfaBackupCode` is the way in without the second factor. The caller
 *    has no ID token (an MFA account gets none before the second factor), so
 *    the callable cannot trust the client: it proves the FIRST factor itself
 *    by a password sign-in against the Identity Toolkit REST API, which for
 *    an enrolled account answers with a pending MFA credential instead of a
 *    token (Q-P6-E08). A Google or Apple sign-in is proven the same way with
 *    the provider's id token (`mfa-first-factor.ts`). Only then is the code
 *    checked. A matching unused code is spent in a transaction, every second
 *    factor is removed with the Admin SDK, every refresh token is revoked,
 *    and the client signs in again and is asked to switch two-step
 *    verification on again.
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
  StoredCode,
  buildStoredCodes,
  codesBelongToEnrollment,
  generateCodes,
  matchCode,
} from "./mfa-codes";
import {
  GLOBAL_ATTEMPT_KEY,
  GLOBAL_POLICY,
  IP_POLICY,
  RECOVERY_ATTEMPTS_COLLECTION,
  UID_POLICY,
  ipAttemptKey,
  reserveAttempt,
  uidAttemptKey,
} from "./mfa-recovery-attempts";
import {
  FirstFactor,
  FirstFactorProof,
  parseRecoveryRequest,
  projectAuthHandlerUri,
  verifyFirstFactorProof,
} from "./mfa-first-factor";
import { WEB_CALLABLE_ORIGINS } from "../shared/web-origins";

export * from "./mfa-codes";
export * from "./mfa-recovery-attempts";
export * from "./mfa-first-factor";

/** Same recent-login rule as account deletion (request-account-deletion.ts). */
export const REAUTH_MAX_AGE_SECONDS = 5 * 60;
/** A new set at most this often per account. */
export const REGENERATE_MIN_INTERVAL_MS = 30 * 1000;

export const BACKUP_CODES_COLLECTION = "mfa_backup_codes";

// --- recovery ----------------------------------------------------------------

export interface RecoveryDeps {
  db: admin.firestore.Firestore;
  /** The HMAC pepper. Empty means not configured: recovery fails closed. */
  pepper: string;
  verifyFirstFactor(proof: FirstFactorProof): Promise<FirstFactor>;
  /** Epoch millis of each second factor's enrollment. */
  enrollmentTimes(uid: string): Promise<number[]>;
  removeSecondFactors(uid: string): Promise<void>;
  revokeSessions(uid: string): Promise<void>;
  audit(entry: Record<string, unknown>): Promise<void>;
  now(): number;
}

/** Either e-mail + password or a Google/Apple id token, plus the code. */
export interface RecoveryRequest {
  email?: unknown;
  password?: unknown;
  providerId?: unknown;
  idToken?: unknown;
  nonce?: unknown;
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

/**
 * The whole recovery, with its effects injected. Throws an `HttpsError` for
 * every refusal; resolves only when the second factor is gone.
 */
export async function runMfaRecovery(
  deps: RecoveryDeps,
  request: unknown,
  context: RecoveryContext = {},
): Promise<{ recovered: true }> {
  // A malformed or mixed request gets the wrong-password refusal, before any read.
  const parsed = parseRecoveryRequest(request);
  if (!parsed) throw rejected();
  const { proof, code } = parsed;
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

  const first = await deps.verifyFirstFactor(proof);
  if (first.outcome === "unavailable") throw unavailable();
  // A wrong password and an account without two-step verification answer
  // alike. The client only offers recovery after Firebase demanded a second
  // factor, so an honest caller never lands in "no-mfa".
  if (first.outcome === "invalid" || first.outcome === "no-mfa") {
    throw rejected();
  }

  // The first factor is proven: from here on the account's own code lock counts.
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
 * stale set can never become valid again when a factor is enrolled later. The
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
    cors: WEB_CALLABLE_ORIGINS,
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
      {
        db: admin.firestore(),
        audit: writeAudit,
        now: () => Date.now(),
      },
      request.auth.uid,
    );
  },
);

export const recoverWithMfaBackupCode = onCall<RecoveryRequest>(
  {
    cors: WEB_CALLABLE_ORIGINS,
    enforceAppCheck: true,
    // Replay protection: every call needs a fresh, limited-use App Check
    // token (the client asks for one with `limitedUseAppCheckToken`).
    consumeAppCheckToken: true,
    secrets: [recoveryPepper, identityToolkitApiKey],
  },
  async (request): Promise<{ recovered: true }> => {
    if (request.app?.alreadyConsumed === true) {
      throw new HttpsError("unauthenticated", "App Check token already used.");
    }
    return runMfaRecovery(
      {
        db: admin.firestore(),
        pepper: readSecret(recoveryPepper),
        verifyFirstFactor: (proof) =>
          verifyFirstFactorProof(
            proof,
            readSecret(identityToolkitApiKey),
            projectAuthHandlerUri(
              process.env.GCLOUD_PROJECT ?? admin.app().options.projectId,
            ),
          ),
        enrollmentTimes: enrollmentTimesOf,
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
    cors: WEB_CALLABLE_ORIGINS,
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
