/**
 * BUT-920: a guest (Firebase anonymous sign-in) gets three AI imports, then
 * has to create an account.
 *
 * One import can make more than one AI call (an OCR read, then an enhance or
 * an ingredient-line pass), so the client names each import with
 * `guestImportId` and the count is of distinct ids, not of calls. The id is
 * client-chosen, so it is not trusted to bound cost on its own: a guest also
 * has a lifetime ceiling on calls, and all guests together share a daily
 * ceiling, because a fresh anonymous account starts a fresh per-uid count.
 *
 * Applied in the callable wrappers of structureRecipe and ocrRecipeImage, not
 * in runStructureRecipe: ocrRecipeImage calls that function itself, and one
 * photo import must not be counted twice.
 */

import * as admin from "firebase-admin";
import { HttpsError, type CallableRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import { Collections } from "../shared/collections";
import { hashUid } from "../shared/hash-uid";
import { signalIfCrossed } from "../middleware/ai_cap_signal";

export const GUEST_IMPORT_LIMIT = 3;
export const GUEST_CALL_LIMIT = 12;
export const DEFAULT_GUEST_DAILY_IMPORT_LIMIT = 300;

/** Same day key shape as checkGlobalLimit in middleware/rate_limiter.ts. */
function utcDayKey(now: Date): string {
  return `${now.getUTCFullYear()}-${now.getUTCMonth()}-${now.getUTCDate()}`;
}

const IMPORT_ID = /^[A-Za-z0-9_-]{1,64}$/;

export interface GuestQuotaDeps {
  db: admin.firestore.Firestore;
  now: () => Date;
  /** `system/config.guestDailyImportLimit`, else the default. */
  loadDailyLimit: () => Promise<number>;
}

async function defaultLoadDailyLimit(
  db: admin.firestore.Firestore,
): Promise<number> {
  try {
    const v = (await db.doc("system/config").get()).get(
      "guestDailyImportLimit",
    );
    return typeof v === "number" && Number.isFinite(v) && v >= 0
      ? v
      : DEFAULT_GUEST_DAILY_IMPORT_LIMIT;
  } catch {
    return DEFAULT_GUEST_DAILY_IMPORT_LIMIT;
  }
}

export function isGuestRequest(auth: CallableRequest["auth"]): boolean {
  return auth?.token?.firebase?.sign_in_provider === "anonymous";
}

/** The call ceiling has its own reason so the app can log it apart from the
 *  import limit, though it shows the same sheet. */
function limitReached(
  reason: "guest-import-limit" | "guest-call-limit",
): HttpsError {
  return new HttpsError("resource-exhausted", reason, { reason });
}

/** What `consumeGuestCall` charged, which `refundGuestCall` needs to undo it. */
export interface GuestCharge {
  newImport: boolean;
  importId: string;
}

/**
 * Per held import id: calls charged against it and not refunded (a success
 * is never refunded, so a finished import stays held), the day its opener
 * charged the shared count on, and whether any call on it paid for a model.
 */
interface HeldImport {
  open: number;
  day: string | null;
  spent: boolean;
}

function readQuota(snap: admin.firestore.DocumentSnapshot): {
  ids: string[];
  held: Record<string, HeldImport>;
  calls: number;
} {
  const ids = snap.get("importIds");
  const held = snap.get("imports");
  return {
    ids: Array.isArray(ids) ? ids : [],
    held: held && typeof held === "object" ? { ...held } : {},
    calls: snap.get("calls") ?? 0,
  };
}

/** Counts one AI call against the guest's quota. */
export async function consumeGuestCall(
  deps: GuestQuotaDeps,
  uid: string,
  importId: unknown,
): Promise<GuestCharge> {
  // The id becomes a map key, and Firestore reserves `__x__` field names.
  if (
    typeof importId !== "string" ||
    !IMPORT_ID.test(importId) ||
    /^__.*__$/.test(importId)
  ) {
    throw new HttpsError("failed-precondition", "guest-import-id-required", {
      reason: "guest-import-id-required",
    });
  }
  const quotaRef = deps.db.collection(Collections.guestQuotas).doc(uid);
  const dailyRef = deps.db.doc("system/guestImportLimits");

  let shared: { count: number; limit: number } | null = null;
  const charge = await deps.db.runTransaction(async (tx) => {
    shared = null;
    const quotaSnap = await tx.get(quotaRef);
    const { ids, held, calls } = readQuota(quotaSnap);
    if (calls >= GUEST_CALL_LIMIT) throw limitReached("guest-call-limit");

    const newImport = !ids.includes(importId);
    if (newImport) {
      if (ids.length >= GUEST_IMPORT_LIMIT) {
        throw limitReached("guest-import-limit");
      }
      // The shared document is read only for a new import, so calls within
      // one import do not queue behind every other guest on it.
      const dailySnap = await tx.get(dailyRef);
      const dailyLimit = await deps.loadDailyLimit();
      const day = utcDayKey(deps.now());
      const dailyCount =
        dailySnap.get("dayKey") === day ? dailySnap.get("dailyCount") ?? 0 : 0;
      if (dailyCount >= dailyLimit) {
        throw new HttpsError("resource-exhausted", "guest-capacity", {
          reason: "guest-capacity",
        });
      }
      tx.set(dailyRef, {
        dayKey: day,
        dailyCount: dailyCount + 1,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      shared = { count: dailyCount + 1, limit: dailyLimit };
      held[importId] = { open: 1, day, spent: false };
    } else {
      const entry = held[importId] ?? { open: 0, day: null, spent: false };
      held[importId] = { ...entry, open: entry.open + 1 };
    }
    tx.set(quotaRef, {
      importIds: newImport ? [...ids, importId] : ids,
      imports: held,
      calls: calls + 1,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { newImport, importId };
  });
  // After the transaction, which may run its callback more than once.
  const crossed = shared as { count: number; limit: number } | null;
  if (crossed) signalIfCrossed({ cap: "guest_day", ...crossed });
  return charge;
}

/**
 * Undoes a charge. The call comes back only when [spent] is false: the call
 * ceiling bounds what the AI cost. The import slot comes back when the
 * import's open count reaches zero, and the shared daily count with it
 * unless a call on that import paid for a model.
 */
export async function refundGuestCall(
  deps: Pick<GuestQuotaDeps, "db">,
  uid: string,
  charge: GuestCharge,
  spent: boolean,
): Promise<void> {
  const quotaRef = deps.db.collection(Collections.guestQuotas).doc(uid);
  const dailyRef = deps.db.doc("system/guestImportLimits");
  await deps.db.runTransaction(async (tx) => {
    const snap = await tx.get(quotaRef);
    if (!snap.exists) return;
    const { ids, held, calls } = readQuota(snap);
    const entry = held[charge.importId];
    let nextIds = ids;
    let refundDay: string | null = null;
    if (entry) {
      const open = Math.max(0, entry.open - 1);
      const everSpent = entry.spent || spent;
      if (open === 0) {
        nextIds = ids.filter((id) => id !== charge.importId);
        delete held[charge.importId];
        if (!everSpent) refundDay = entry.day;
      } else {
        held[charge.importId] = { ...entry, open, spent: everSpent };
      }
    }
    const dailySnap = refundDay !== null ? await tx.get(dailyRef) : null;
    tx.set(quotaRef, {
      importIds: nextIds,
      imports: held,
      calls: spent ? calls : Math.max(0, calls - 1),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    if (dailySnap && dailySnap.get("dayKey") === refundDay) {
      tx.set(dailyRef, {
        dayKey: refundDay,
        dailyCount: Math.max(0, (dailySnap.get("dailyCount") ?? 0) - 1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });
}

/**
 * Wraps a callable handler so a guest's call is counted first and refunded
 * when it throws or answers `success: false`. Everyone else passes through.
 * A throw is treated as nothing spent: the refusals and validation inside
 * the wrapper all throw before any model call.
 */
export function withGuestImportQuota<
  TRequest extends { guestImportId?: string },
  TResponse extends { success?: boolean; estimatedCost: number },
>(
  handler: (request: CallableRequest<TRequest>) => Promise<TResponse>,
  depsOverride?: Partial<GuestQuotaDeps>,
): (request: CallableRequest<TRequest>) => Promise<TResponse> {
  return async (request) => {
    if (!isGuestRequest(request.auth)) return handler(request);
    const db = depsOverride?.db ?? admin.firestore();
    const deps: GuestQuotaDeps = {
      db,
      now: depsOverride?.now ?? (() => new Date()),
      loadDailyLimit:
        depsOverride?.loadDailyLimit ?? (() => defaultLoadDailyLimit(db)),
    };
    const uid = request.auth!.uid;
    const charge = await consumeGuestCall(
      deps,
      uid,
      request.data?.guestImportId,
    );
    const refund = (spent: boolean) =>
      refundGuestCall(deps, uid, charge, spent).catch((err) =>
        logger.warn(`Guest import refund failed for ${hashUid(uid)}`, err),
      );
    let result: TResponse;
    try {
      result = await handler(request);
    } catch (err) {
      await refund(false);
      throw err;
    }
    if (result?.success === false) await refund(result.estimatedCost > 0);
    return result;
  };
}
