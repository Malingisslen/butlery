/**
 * BUT-1386 (ADR-0002): authoritative server-side age enforcement.
 *
 * Butlery's minimum age is **15** — grounded in Sweden's Dataskyddslag
 * 2 kap. 4 § (information-society services with a social component), NOT
 * GDPR Art 8 (whose Swedish floor is 13). See ADR-0001 (the number + basis)
 * and ADR-0002 (this dual-layer enforcement design). BUT-1384 aligned every
 * client-visible age number to 15 and tightened the `settings/preferences`
 * rule floor; it left a real bypass: the client could skip / null-out
 * `birthYear` and still reach the gated collections.
 *
 * This callable closes that bypass. It is the **authoritative and only
 * writer of `birthYear`** and the only writer of the age-enforcement audit
 * event. Firestore rules (this same commit) reject any client write that
 * carries `birthYear`, and gate the four UGC create paths
 * (`recipe_comments`, `messages`, `social_requests`, `recipe_ratings`) on
 * an `ageCompliant` custom claim that only this function can set.
 *
 * **Why a custom claim, not a Firestore doc the rules `get()`** — the full
 * stakeholder panel (2026-06-27) was unanimous: a claim is bound to the
 * Firebase-issued token (unspoofable), and costs *zero* extra Firestore
 * reads on every UGC write, where a `get()` would bill one read per comment /
 * message / friend-request / rating forever. Cost is the price of the gate
 * being on a hot write path.
 *
 * **Under-15 sequencing** (decided by Malin 2026-06-27): the Auth account
 * already exists by the time onboarding collects `birthYear`, so a rejected
 * minor's account is **deleted synchronously** here and only a non-identifying
 * "a signup was blocked" record is kept — no uid / email / birth year tied to
 * the fact that a person is under 15 (Legal: do not create that link). The
 * stronger pre-Auth Identity-Platform intercept is filed as a post-launch
 * follow-up.
 *
 * **Token-refresh contract** — `setCustomUserClaims` does not change a token
 * already in the client's hand. The onboarding client MUST
 * `getIdToken(forceRefresh: true)` after a compliant result, before it lets
 * the user reach any UGC-capable screen, or `isAgeCompliant()` will deny the
 * first write off a stale token.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { hashUid } from "../shared/hash-uid";
import { enforceRateLimit } from "../middleware/rate_limiter";

const db = admin.firestore();

/** ADR-0001. Kept in sync with `OnboardingViewModel.minAgeYears` (Dart) and
 *  `UserProfile`'s birthYear invariant. */
export const MIN_AGE_YEARS = 15;

/** Lower plausibility bound for a self-declared birth year. Mirrors the
 *  Firestore rule + `UserProfile` validation. */
const MIN_PLAUSIBLE_BIRTH_YEAR = 1900;

/** Per-IP audit-write ceiling, FinOps condition: a bot rotating UIDs from one
 *  IP must not be able to loop the billable audit collection. 5 writes / hour. */
const IP_AUDIT_CAP_PER_HOUR = 5;

export interface VerifySignupAgeRequest {
  /** Self-declared birth year collected during onboarding. */
  birthYear: number;
}

export interface VerifySignupAgeResponse {
  /** True when the caller is ≥15 and the `ageCompliant` claim was set. When
   *  false, the caller's Auth account has been deleted server-side. */
  compliant: boolean;
}

/**
 * Coarsen a birth year to its decade ("1994" -> "1990s") for the audit event.
 * Data-minimisation (Privacy condition): the audit only needs to prove the
 * check happened and its outcome, not replay the exact input.
 */
function birthDecade(birthYear: number): string {
  return `${Math.floor(birthYear / 10) * 10}s`;
}

/**
 * BUT-1436: sanitized error fields for structured logging — never the raw error
 * object, which on some Firebase error paths (e.g. an `auth.deleteUser` failure)
 * can embed the operating account's uid. Keeps logs consistent with the
 * hashUid-everywhere discipline: only a string code + message reach Cloud
 * Logging.
 */
function errorFields(err: unknown): { errCode?: string; errMessage: string } {
  const code = (err as { code?: unknown })?.code;
  return {
    errCode: typeof code === "string" ? code : undefined,
    errMessage: err instanceof Error ? err.message : String(err),
  };
}

export const verifySignupAge = onCall<VerifySignupAgeRequest>(
  {
    memory: "256MiB",
    timeoutSeconds: 60,
    cors: ["https://butlery.app", "https://www.butlery.app"],
    // BUT-760 pattern: user-facing account callable — App Check defense-in-depth.
    // Inert until App Check is flipped to Enforce in the console; that flip is a
    // release gate on this ticket (Security + FinOps conditions), not a follow-up.
    enforceAppCheck: true,
  },
  async (request): Promise<VerifySignupAgeResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }
    const uid = request.auth.uid;

    // Validate input before any work. A non-int / out-of-range year is a
    // client bug or an attack — reject loudly, write nothing.
    const birthYear = request.data?.birthYear;
    const currentYear = new Date().getFullYear();
    if (
      typeof birthYear !== "number" ||
      !Number.isInteger(birthYear) ||
      birthYear < MIN_PLAUSIBLE_BIRTH_YEAR ||
      birthYear > currentYear
    ) {
      throw new HttpsError(
        "invalid-argument",
        "A valid birth year is required.",
      );
    }

    // Per-user token bucket (operation 'verifySignupAge'). Deliberately NOT
    // `withRateLimit` — that helper also gates on the LLM global limiter
    // (system/llmLimits, the `aiEnabled` kill switch), which would wrongly
    // break signups whenever AI is disabled. Per-user + per-IP is the right
    // pair for an account callable.
    await enforceRateLimit(uid, "verifySignupAge");

    // Per-IP hourly cap — independent of uid, so a bot rotating fresh accounts
    // from one IP can't loop the audit write. Fail closed.
    const ip = request.rawRequest?.ip ?? "unknown";
    await enforceIpAuditCap(db, ip);

    return runVerifySignupAgeWithDeps(
      { db, auth: admin.auth() },
      uid,
      birthYear,
    );
  },
);

export interface VerifySignupAgeDeps {
  db: admin.firestore.Firestore;
  auth: admin.auth.Auth;
}

/**
 * DI core — exposed for unit tests (mirrors `runAccountDeletionWithDeps`).
 * Idempotent: a retried signup whose claim is already set returns success
 * without a duplicate write or audit row.
 */
export async function runVerifySignupAgeWithDeps(
  deps: VerifySignupAgeDeps,
  uid: string,
  birthYear: number,
): Promise<VerifySignupAgeResponse> {
  const { db: database, auth } = deps;
  const currentYear = new Date().getFullYear();
  const age = currentYear - birthYear;
  const compliant = age >= MIN_AGE_YEARS;

  if (!compliant) {
    // Non-identifying record ONLY (Legal): never link a real identity to the
    // fact that a person is under 15. No uid, no email, no birth year — just
    // that a signup was blocked, when, and on what basis.
    await writeRejectionAudit(database);

    // Synchronous deletion of the just-created Auth account. Firing
    // `auth.deleteUser` triggers the existing `onUserDeleted` v1 trigger,
    // which cascades any partial onboarding Firestore data (user doc,
    // settings) and cross-user rows. The client surfaces a butler-voice
    // rejection and returns to start.
    try {
      await auth.deleteUser(uid);
    } catch (err) {
      logger.error("[verifySignupAge] under-15 auth delete failed", {
        uid_prefix: hashUid(uid),
        ...errorFields(err),
      });
      // Surface so the client does NOT proceed as if admitted.
      throw new HttpsError(
        "internal",
        "Could not complete age verification. Please try again.",
      );
    }
    logger.info("[verifySignupAge] rejected under-15 + account deleted");
    return { compliant: false };
  }

  // Idempotency: if the claim is already set, this is a retry.
  const user = await auth.getUser(uid);
  const existingClaims = user.customClaims ?? {};
  if (existingClaims.ageCompliant === true) {
    // BUT-1435: NOT a bare no-op. The write order is claim-first, so an earlier
    // attempt may have set the claim but then failed before/within the artifact
    // writes — leaving a compliant user with the gate claim but no stored
    // birthYear / consent-audit row. Re-assert the artifacts idempotently
    // (merge-sets + a deterministic-id audit → no duplicates) so a
    // partial-failure retry converges, then return success.
    await writeComplianceArtifacts(database, uid, birthYear);
    logger.info("[verifySignupAge] idempotent retry — artifacts re-ensured", {
      uid_prefix: hashUid(uid),
    });
    return { compliant: true };
  }

  // First successful pass. Claim first (the gate) so that if anything fails the
  // user is never left able-to-post without a recorded age; then the
  // idempotent compliance artifacts (a partial failure here is recovered by the
  // retry branch above).
  await auth.setCustomUserClaims(uid, { ...existingClaims, ageCompliant: true });
  await writeComplianceArtifacts(database, uid, birthYear);

  logger.info("[verifySignupAge] admitted ≥15 + claim set", {
    uid_prefix: hashUid(uid),
  });
  return { compliant: true };
}

/**
 * Idempotent compliance artifacts written after the gate claim is set: the
 * dual-located `birthYear` and the consent-audit row. Safe to re-run on a
 * retry (BUT-1435) — both birthYear writes are merge-sets, and the audit uses a
 * deterministic doc id (set+merge), so re-running never clobbers sibling fields
 * or duplicates the audit row.
 *
 * birthYear is dual-located in the client read paths: the profile doc
 * (users/{uid}, read by `UserProfile.fromMap`) and the settings/preferences
 * copy (read by the GDPR export). The client no longer writes either; this CF
 * is the sole writer of both.
 */
async function writeComplianceArtifacts(
  database: admin.firestore.Firestore,
  uid: string,
  birthYear: number,
): Promise<void> {
  await Promise.all([
    database.doc(`users/${uid}`).set({ birthYear }, { merge: true }),
    database
      .doc(`users/${uid}/settings/preferences`)
      .set({ birthYear }, { merge: true }),
  ]);

  await writeComplianceAudit(database, uid, birthYear);
}

/** Production entry point — wraps the live Firestore + Auth. */
export async function runVerifySignupAge(
  uid: string,
  birthYear: number,
): Promise<VerifySignupAgeResponse> {
  return runVerifySignupAgeWithDeps(
    { db, auth: admin.auth() },
    uid,
    birthYear,
  );
}

/**
 * Consent-category audit row. The `consent_` operation prefix makes
 * `purgeExpiredAuditLogs` retain it for 730 days (GDPR Art 7(1) — demonstrate
 * the age-eligibility condition was met). Stores derived fact only: outcome +
 * coarse decade + hashed uid. No raw birth year, no email.
 *
 * BUT-1435: written at a DETERMINISTIC doc id (one consent row per user, the
 * correct semantics for a consent record) with set+merge, so a retry that
 * re-asserts artifacts overwrites in place rather than appending a duplicate.
 * The purge job matches by the `consent_` operation prefix + timestamp, not by
 * id, so retention is unaffected.
 */
async function writeComplianceAudit(
  database: admin.firestore.Firestore,
  uid: string,
  birthYear: number,
): Promise<void> {
  await database
    .collection("audit_logs")
    .doc(`consent_age_verification_${hashUid(uid)}`)
    .set(
      {
        operation: "consent_age_verification",
        userIdHash: hashUid(uid),
        isAgeCompliant: true,
        birthDecade: birthDecade(birthYear),
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
}

/**
 * Non-identifying rejection record (general 180-day retention — no `consent_`
 * prefix). Deliberately carries NO identifier and NO birth year: it must not
 * be possible to derive from this collection that a specific person is under
 * 15 (Legal condition).
 */
async function writeRejectionAudit(
  database: admin.firestore.Firestore,
): Promise<void> {
  await database.collection("audit_logs").add({
    operation: "age_verification_rejected",
    reason: "under_minimum_age",
    basis: "dataskyddslag_2_4",
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/**
 * Per-IP hourly audit-write cap. Atomic counter keyed by hashed IP + hour
 * bucket; fails closed on the cap and on Firestore errors so it can't be used
 * to bill the audit collection unbounded.
 */
export async function enforceIpAuditCap(
  database: admin.firestore.Firestore,
  ip: string,
): Promise<void> {
  const hour = Math.floor(Date.now() / (60 * 60 * 1000));
  const key = `${hashUid(ip)}_${hour}`;
  const ref = database.collection("system_ip_audit_caps").doc(key);
  try {
    await database.runTransaction(async (tx) => {
      const doc = await tx.get(ref);
      const count = doc.exists ? ((doc.data()?.count as number) ?? 0) : 0;
      if (count >= IP_AUDIT_CAP_PER_HOUR) {
        throw new HttpsError(
          "resource-exhausted",
          "Too many attempts. Please try again later.",
        );
      }
      tx.set(
        ref,
        {
          count: count + 1,
          // TTL field so a cleanup job / policy can reap stale buckets.
          expireAt: admin.firestore.Timestamp.fromDate(
            new Date(Date.now() + 2 * 60 * 60 * 1000),
          ),
        },
        { merge: true },
      );
    });
  } catch (err) {
    if (err instanceof HttpsError) throw err;
    logger.error("[verifySignupAge] IP audit cap check failed — denying", {
      ...errorFields(err),
    });
    throw new HttpsError(
      "resource-exhausted",
      "Verification temporarily unavailable. Please try again shortly.",
    );
  }
}
