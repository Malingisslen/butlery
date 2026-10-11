/**
 * P6-U09 — the attempt counters `recoverWithMfaBackupCode` reserves before it
 * does any work. Split out of `mfa-backup-codes.ts` (500-line rule).
 */

import * as admin from "firebase-admin";
import { createHmac } from "crypto";

export const RECOVERY_ATTEMPTS_COLLECTION = "mfa_recovery_attempts";

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
