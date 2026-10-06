/**
 * Per-user AI cost ledger (BUT-2243, closes BUT-2102).
 *
 * The callables that call Gemini already compute what each call cost
 * (`calculateGeminiCost`, returned as `estimatedCost`). This module adds it to
 * `users/{uid}/rate_limits/llm_cost` and refuses a call once the user's UTC
 * day or UTC month has reached its ceiling. The app may READ that doc; the
 * rules give no client limb that writes or deletes it, so the ceiling is one a
 * client cannot reset. The per-user and global CALL caps in `rate_limiter.ts`
 * still sit underneath it.
 *
 * Residuals, stated rather than fixed:
 *   - A call that is billed and then THROWS records nothing (the catch blocks
 *     of `runStructureRecipe` and `runOcrRecipeImage`, an OCR retry that
 *     throws). The call caps bound that.
 *   - The check and the record are separate, so concurrent calls can all pass
 *     the check against the same total.
 *   - Calendar windows let a user spend up to twice a ceiling across a UTC
 *     midnight or a month boundary.
 *   - One person with several accounts gets several ceilings.
 */

import * as admin from "firebase-admin";
import { HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import { hashUid } from "../shared/hash-uid";

export interface LlmCostCeilings {
  perDayUsd: number;
  perMonthUsd: number;
}

/** Mirrored by `ImportRateLimits.llmCostPerDay/PerMonth` in the app. */
export const LLM_COST_CEILINGS: LlmCostCeilings = {
  perDayUsd: 0.5,
  perMonthUsd: 10,
};

/**
 * The one place a ceiling is looked up, so a future per-plan ceiling changes
 * this function and not its callers. Every user gets the same ceilings today.
 */
export function ceilingsFor(_uid: string): LlmCostCeilings {
  return LLM_COST_CEILINGS;
}

/** Doc id under `users/{uid}/rate_limits`. Excluded from the rules' stamp limb. */
export const LLM_COST_DOC_ID = "llm_cost";

/** Long enough to outlive the month the doc counts; the `rate_limits` TTL reads it. */
const EXPIRE_AFTER_MS = 40 * 24 * 60 * 60 * 1000;

/** `YYYY-MM-DD` in UTC. The app builds the same string (`ServerLlmCost`). */
export function utcDayKey(now: Date): string {
  return now.toISOString().slice(0, 10);
}

/** `YYYY-MM` in UTC. The app builds the same string (`ServerLlmCost`). */
export function utcMonthKey(now: Date): string {
  return now.toISOString().slice(0, 7);
}

export interface LedgerDeps {
  db?: () => admin.firestore.Firestore;
  now?: () => Date;
}

function resolve(deps?: LedgerDeps): {
  db: admin.firestore.Firestore;
  now: Date;
} {
  return {
    db: (deps?.db ?? (() => admin.firestore()))(),
    now: (deps?.now ?? (() => new Date()))(),
  };
}

function ledgerRef(
  db: admin.firestore.Firestore,
  uid: string
): admin.firestore.DocumentReference {
  return db
    .collection("users")
    .doc(uid)
    .collection("rate_limits")
    .doc(LLM_COST_DOC_ID);
}

export interface LedgerSpend {
  today: number;
  month: number;
  operationsThisMonth: number;
}

/** What the stored doc means at `now`: a stale day or month key counts as 0. */
export function spendAt(
  data: admin.firestore.DocumentData | undefined,
  now: Date
): LedgerSpend {
  const sameMonth = data?.monthKey === utcMonthKey(now);
  return {
    today: data?.dayKey === utcDayKey(now) ? numberOr0(data?.costToday) : 0,
    month: sameMonth ? numberOr0(data?.costThisMonth) : 0,
    operationsThisMonth: sameMonth ? numberOr0(data?.operationsThisMonth) : 0,
  };
}

function numberOr0(value: unknown): number {
  return typeof value === "number" && Number.isFinite(value) ? value : 0;
}

/**
 * Throws `resource-exhausted` with `details.reason` `llm_cost_month` or
 * `llm_cost_day` when a ceiling is reached, so the app can tell this apart from
 * the call caps' "too many requests". Fails CLOSED on a read error, like
 * `checkRateLimit`.
 */
export async function checkCostCeiling(
  uid: string,
  deps?: LedgerDeps
): Promise<void> {
  const { db, now } = resolve(deps);
  let spend: LedgerSpend;
  try {
    const snap = await ledgerRef(db, uid).get();
    spend = spendAt(snap.data(), now);
  } catch (error) {
    logger.error("llm_cost_ledger_read_failed", {
      uidHash: hashUid(uid),
      errName: error instanceof Error ? error.name : typeof error,
    });
    throw new HttpsError(
      "unavailable",
      "AI-hjälpen kunde inte nås just nu. Försök igen om en stund."
    );
  }

  const ceilings = ceilingsFor(uid);
  if (spend.month >= ceilings.perMonthUsd) {
    deny(uid, "llm_cost_month", spend);
  }
  if (spend.today >= ceilings.perDayUsd) {
    deny(uid, "llm_cost_day", spend);
  }
}

function deny(
  uid: string,
  reason: "llm_cost_day" | "llm_cost_month",
  spend: LedgerSpend
): never {
  logger.warn("llm_cost_ceiling_denied", {
    uidHash: hashUid(uid),
    ceiling: reason,
    today: spend.today,
    month: spend.month,
  });
  throw new HttpsError(
    "resource-exhausted",
    reason === "llm_cost_month"
      ? "Du har använt månadens AI-hjälp. Försök igen nästa månad."
      : "Du har använt dagens AI-hjälp. Försök igen i morgon.",
    { reason }
  );
}

/**
 * Adds `cost` to the user's day and month. A failed write is logged and NOT
 * thrown: the caller already has its result, and the call caps still bound
 * spend.
 */
export async function recordLlmCost(
  uid: string,
  cost: number,
  deps?: LedgerDeps
): Promise<void> {
  if (!(typeof cost === "number" && Number.isFinite(cost) && cost > 0)) return;
  const { db, now } = resolve(deps);
  const ref = ledgerRef(db, uid);
  try {
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const spend = spendAt(snap.data(), now);
      tx.set(ref, {
        costToday: spend.today + cost,
        dayKey: utcDayKey(now),
        costThisMonth: spend.month + cost,
        monthKey: utcMonthKey(now),
        operationsThisMonth: spend.operationsThisMonth + 1,
        updatedAt: admin.firestore.Timestamp.fromDate(now),
        expireAt: admin.firestore.Timestamp.fromMillis(
          now.getTime() + EXPIRE_AFTER_MS
        ),
      });
    });
  } catch (error) {
    logger.error("llm_cost_ledger_record_failed", {
      uidHash: hashUid(uid),
      cost,
      errName: error instanceof Error ? error.name : typeof error,
    });
  }
}

/**
 * Wraps a callable so its cost is checked before and recorded after.
 *
 * Goes OUTSIDE `withRateLimit`: a cost denial must not touch the per-user
 * bucket or the global counter (BUT-1577's reason for checking per-user first).
 * That puts it ahead of `withRateLimit`'s login check, so it checks login
 * itself before reading anything.
 *
 * The OCR callable's in-process structureRecipe retry is already folded into
 * its `estimatedCost`, so recording the outer result counts it once.
 */
export function withCostLedger<TRequest, TResponse extends { estimatedCost: number }>(
  handler: (request: CallableRequest<TRequest>) => Promise<TResponse>,
  deps?: LedgerDeps
): (request: CallableRequest<TRequest>) => Promise<TResponse> {
  return async (request: CallableRequest<TRequest>): Promise<TResponse> => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError(
        "unauthenticated",
        "Du måste vara inloggad för att använda denna funktion."
      );
    }
    await checkCostCeiling(uid, deps);
    const result = await handler(request);
    await recordLlmCost(uid, result.estimatedCost, deps);
    return result;
  };
}
