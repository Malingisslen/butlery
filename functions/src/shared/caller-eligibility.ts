/**
 * BUT-1838: the age and anti-spam gates, re-expressed for the Admin SDK.
 *
 * `firestore.rules` gates every client-written social document behind
 * `isAgeCompliant()` (the server-set `ageCompliant` custom claim, ADR-0002) and
 * `isAccountMatured()` (BUT-659's one-hour anti-spam cooldown for accounts with
 * an unverified email). A callable running under the Admin SDK bypasses rules
 * entirely — so an operation MOVED from a client write to a callable silently
 * loses both gates unless it re-implements them. That is not a hypothetical:
 * BUT-1838 moves group creation and add-member off the client, and the same trap
 * already bit this repo once when a system message that rules had always denied
 * started landing the moment it moved to the Admin SDK.
 *
 * Deliberately a mirror, not a shared implementation: rules are CEL and this is
 * TypeScript, so the two can only be kept in step by saying so. If
 * `isAccountMatured()` in firestore.rules changes, change this too.
 */

import * as admin from "firebase-admin";
import { HttpsError } from "firebase-functions/v2/https";

/**
 * Structural, not `import type { AuthData }`: the two fields these gates read
 * are stable across firebase-functions versions while the exported type has
 * moved between entry points more than once, and a broken import here would
 * take out a child-safety gate rather than a convenience.
 */
export interface CallerAuth {
  uid: string;
  token?: { ageCompliant?: unknown; email_verified?: unknown };
}

/** Mirrors the 60-minute window in `isAccountMatured()` (firestore.rules:111). */
export const ACCOUNT_MATURITY_MS = 60 * 60 * 1000;

/**
 * Throws unless the caller satisfies the age gate.
 *
 * Fails CLOSED, like the rule: a missing or false claim denies. A token issued
 * before `verifySignupAge` set the claim is stale and also denies, which is the
 * intended behaviour — the client refreshes and retries.
 */
export function assertAgeCompliant(auth: CallerAuth | undefined): void {
  if (auth?.token?.ageCompliant !== true) {
    throw new HttpsError(
      "permission-denied",
      "Account is not age-verified for social features.",
    );
  }
}

/**
 * Throws unless the caller's account has matured past the anti-spam cooldown.
 *
 * A verified email satisfies it immediately; otherwise the account must be at
 * least an hour old, measured from `users/{uid}.createdAt` exactly as the rule
 * measures it. A user document with no `createdAt` denies, matching the rule's
 * `'createdAt' in ...` conjunct.
 */
export async function assertAccountMatured(
  db: admin.firestore.Firestore,
  auth: CallerAuth | undefined,
): Promise<void> {
  if (!auth) {
    throw new HttpsError("unauthenticated", "Sign-in required.");
  }
  if (auth.token?.email_verified === true) return;

  const snap = await db.doc(`users/${auth.uid}`).get();
  const createdAt = snap.exists ? snap.get("createdAt") : null;
  const createdMs =
    createdAt instanceof admin.firestore.Timestamp
      ? createdAt.toMillis()
      : null;
  if (createdMs === null || Date.now() - createdMs < ACCOUNT_MATURITY_MS) {
    throw new HttpsError(
      "permission-denied",
      "New accounts must verify their email or wait before using this.",
    );
  }
}
