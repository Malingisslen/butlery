/**
 * BUT-2452: the guest list. While the gate is on, Identity Platform creates
 * an account only for an address on `signup_allowlist/{email}`; a public web
 * key is enough to reach the Auth REST API, so the check has to run here and
 * not in the app.
 *
 * Password sign-ups (ADR-0034, Malin 2026-10-24): a password does not prove
 * the address, so the invite survives creation and is consumed only once the
 * address is verified. `beforeSignInAllowlist` refuses an unverified sign-in
 * after the sign-up session, which caps a squatter at that one session.
 *
 * Fails closed: a read error refuses creation with its own retryable message,
 * so an invited person is never told they are not invited. Only an exact
 * boolean `false` at `system/config.signupAllowlistEnabled` opens the gate.
 *
 * No email reaches a log line or an error message.
 */

import {
  beforeUserCreated,
  beforeUserSignedIn,
  HttpsError,
} from "firebase-functions/v2/identity";
import type { AuthBlockingEvent } from "firebase-functions/v2/identity";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { hashUid } from "../shared/hash-uid";

export const INVITE_COLLECTION = "signup_allowlist";

// The app matches these markers in the error text (`auth_error_mapper.dart`).
export const SIGNUP_NOT_INVITED = "SIGNUP_NOT_INVITED";
export const SIGNUP_GATE_UNAVAILABLE = "SIGNUP_GATE_UNAVAILABLE";
export const SIGNUP_EMAIL_UNVERIFIED = "SIGNUP_EMAIL_UNVERIFIED";

export type InviteState = "valid" | "missing" | "expired";

export interface AllowlistDeps {
  gateEnabled(): Promise<boolean>;
  /** Reads the invite and, when `consume` and valid, deletes it atomically. */
  checkInvite(email: string, consume: boolean): Promise<InviteState>;
}

export interface GateUser {
  uid: string;
  email?: string;
  emailVerified: boolean;
}

export function normalizeEmail(email: string | undefined | null): string {
  return (email ?? "").trim().toLowerCase();
}

export function readGateSwitch(data: unknown): boolean {
  if (data === null || typeof data !== "object") return true;
  return (data as Record<string, unknown>).signupAllowlistEnabled !== false;
}

/** The TTL sweep can lag by a day or more, so `expireAt` is checked here. */
export function inviteState(data: unknown, nowMs: number): InviteState {
  if (data === null || data === undefined) return "missing";
  const expireAt = (data as Record<string, unknown>).expireAt;
  if (!(expireAt instanceof admin.firestore.Timestamp)) return "expired";
  return expireAt.toMillis() > nowMs ? "valid" : "expired";
}

/**
 * Whether the address can be a `signup_allowlist` document id at all. The
 * rules only accept ids without a slash, so such an address can never be
 * invited, and passing it to `.doc()` would throw an error that repeats it.
 */
export function isInvitableAddress(email: string): boolean {
  return email !== "" && !email.includes("/") && email !== "." &&
    email !== ".." && !/^__.*__$/.test(email);
}

/** Error details for a log line; never the message, which can repeat a path. */
function errFields(err: unknown): { errCode: unknown; errName: string } {
  const code = err !== null && typeof err === "object" ?
    (err as { code?: unknown }).code ?? null : null;
  return { errCode: code, errName: err instanceof Error ? err.name : typeof err };
}

function refuse(marker: string, text: string): never {
  throw new HttpsError("permission-denied", `${marker}: ${text}`);
}

function logOutcome(fn: string, outcome: string, uid: string): void {
  logger.info("signup_gate", { fn, outcome, uidHash: hashUid(uid) });
}

export async function runSignupAllowlistWithDeps(
  deps: AllowlistDeps,
  user: GateUser,
): Promise<void> {
  const fn = "beforeCreateAllowlist";
  let enabled: boolean;
  try {
    enabled = await deps.gateEnabled();
  } catch (err) {
    logger.warn("signup_gate_read_error", {
      fn, stage: "config", uidHash: hashUid(user.uid), ...errFields(err),
    });
    refuse(SIGNUP_GATE_UNAVAILABLE, "Det gick inte att skapa kontot just nu. Försök igen om en stund.");
  }
  if (!enabled) {
    logOutcome(fn, "gate_off", user.uid);
    return;
  }

  const email = normalizeEmail(user.email);
  if (email === "") {
    logOutcome(fn, "refused_no_email", user.uid);
    refuse(SIGNUP_NOT_INVITED, "Butlery är bara öppet för inbjudna just nu.");
  }
  if (!isInvitableAddress(email)) {
    logOutcome(fn, "refused_not_invitable", user.uid);
    refuse(SIGNUP_NOT_INVITED, "Butlery är bara öppet för inbjudna just nu.");
  }

  let state: InviteState;
  try {
    state = await deps.checkInvite(email, user.emailVerified);
  } catch (err) {
    logger.warn("signup_gate_read_error", {
      fn, stage: "invite", uidHash: hashUid(user.uid), ...errFields(err),
    });
    refuse(SIGNUP_GATE_UNAVAILABLE, "Det gick inte att skapa kontot just nu. Försök igen om en stund.");
  }
  if (state !== "valid") {
    logOutcome(fn, `refused_${state}`, user.uid);
    refuse(SIGNUP_NOT_INVITED, "Butlery är bara öppet för inbjudna just nu.");
  }
  logOutcome(
    fn,
    user.emailVerified ? "allowed_consumed" : "allowed_pending_verification",
    user.uid,
  );
}

export async function runSignInAllowlistWithDeps(
  deps: AllowlistDeps,
  user: GateUser,
  isNewUser: boolean,
): Promise<void> {
  const fn = "beforeSignInAllowlist";
  const email = normalizeEmail(user.email);
  if (email === "") return;

  if (!user.emailVerified) {
    // The sign-up session itself must get through, or the app could never
    // send the verification mail.
    if (isNewUser) return;
    let enabled = true;
    try {
      enabled = await deps.gateEnabled();
    } catch (err) {
      logger.warn("signup_gate_read_error", {
        fn, stage: "config", uidHash: hashUid(user.uid), ...errFields(err),
      });
    }
    if (!enabled) return;
    logOutcome(fn, "refused_unverified", user.uid);
    refuse(SIGNUP_EMAIL_UNVERIFIED, "Bekräfta din e-post via länken vi skickade.");
  }

  // A verified user is never refused here; consuming a leftover invite is
  // best effort and the TTL is the backstop.
  try {
    if (!isInvitableAddress(email) || !(await deps.gateEnabled())) return;
    const state = await deps.checkInvite(email, true);
    if (state === "valid") logOutcome(fn, "invite_consumed", user.uid);
  } catch (err) {
    logger.warn("signup_gate_consume_error", {
      fn, uidHash: hashUid(user.uid), ...errFields(err),
    });
  }
}

export function firestoreAllowlistDeps(db: admin.firestore.Firestore): AllowlistDeps {
  return {
    async gateEnabled() {
      const snap = await db.collection("system").doc("config").get();
      return readGateSwitch(snap.exists ? snap.data() : null);
    },
    async checkInvite(email, consume) {
      const ref = db.collection(INVITE_COLLECTION).doc(email);
      return db.runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        const state = inviteState(snap.exists ? snap.data() : null, Date.now());
        if (state === "valid" && consume) tx.delete(ref);
        return state;
      });
    },
  };
}

function gateUser(event: AuthBlockingEvent): GateUser {
  return {
    uid: event.data?.uid ?? "",
    email: event.data?.email,
    emailVerified: event.data?.emailVerified === true,
  };
}

export const beforeCreateAllowlist = beforeUserCreated(
  { region: "europe-west1" },
  async (event) => {
    await runSignupAllowlistWithDeps(firestoreAllowlistDeps(admin.firestore()), gateUser(event));
  },
);

export const beforeSignInAllowlist = beforeUserSignedIn(
  { region: "europe-west1" },
  async (event) => {
    await runSignInAllowlistWithDeps(
      firestoreAllowlistDeps(admin.firestore()),
      gateUser(event),
      event.additionalUserInfo?.isNewUser === true,
    );
  },
);
