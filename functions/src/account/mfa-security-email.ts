/**
 * The security e-mail for two-step verification (BUT-2142, Malin's F3-5 = A):
 * the account owner hears about it when backup codes are created and when a
 * backup code removes the second factor, because either is what someone who
 * has the password would do to take the account over.
 *
 * Sent through Resend with the same key as the feedback e-mail. The message
 * carries no code, no number and nothing else about the account: only what
 * happened, and what to do if it was not the owner. It is written in Swedish
 * and English in one body, so no language lookup is needed.
 *
 * Never throws: a mail that cannot be sent must not undo a recovery or block
 * an enrollment. A missing key or sender is a logged skip.
 */

import { defineSecret } from "firebase-functions/params";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";

export const mfaEmailApiKey = defineSecret("FEEDBACK_EMAIL_API_KEY");

export type MfaSecurityEvent = "codes-created" | "recovered";

export interface MfaSecurityEmail {
  subject: string;
  text: string;
}

const IF_NOT_YOU_SV =
  "Om det inte var du: byt lösenord direkt i appen under Inställningar > Kontosäkerhet.";
const IF_NOT_YOU_EN =
  "If this was not you, change your password right away in the app under Settings > Account security.";

export function buildMfaSecurityEmail(event: MfaSecurityEvent): MfaSecurityEmail {
  if (event === "codes-created") {
    return {
      subject: "Butlery: nya reservkoder skapades / new backup codes were created",
      text: [
        "Nya reservkoder för tvåstegsverifiering skapades för ditt Butlery-konto.",
        IF_NOT_YOU_SV,
        "",
        "New backup codes for two-step verification were created for your Butlery account.",
        IF_NOT_YOU_EN,
      ].join("\n"),
    };
  }
  return {
    subject:
      "Butlery: tvåstegsverifieringen stängdes av / two-step verification was turned off",
    text: [
      "Någon loggade in på ditt Butlery-konto med en reservkod, och tvåstegsverifieringen är nu avstängd.",
      `${IF_NOT_YOU_SV} Slå sedan på tvåstegsverifieringen igen.`,
      "",
      "Someone signed in to your Butlery account with a backup code, and two-step verification is now off.",
      `${IF_NOT_YOU_EN} Then turn two-step verification on again.`,
    ].join("\n"),
  };
}

export interface MfaEmailTransport {
  apiKey: string;
  from: string;
  fetchFn: typeof fetch;
  /** The mail is awaited on the callable's response path, so it may not hang. */
  timeoutMs?: number;
}

const DEFAULT_TIMEOUT_MS = 5000;

/** Sends [event]'s mail to [to]. Resolves whether it was accepted. */
export async function sendMfaSecurityEmail(
  transport: MfaEmailTransport,
  to: string,
  event: MfaSecurityEvent,
): Promise<boolean> {
  if (!transport.apiKey || !transport.from || !to) {
    logger.warn("[mfa-email] skipped: key, sender or recipient missing", { event });
    return false;
  }
  const { subject, text } = buildMfaSecurityEmail(event);
  const abort = new AbortController();
  const timer = setTimeout(
    () => abort.abort(),
    transport.timeoutMs ?? DEFAULT_TIMEOUT_MS,
  );
  try {
    const res = await transport.fetchFn("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${transport.apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ from: transport.from, to, subject, text }),
      signal: abort.signal,
    });
    if (!res.ok) {
      logger.error("[mfa-email] Resend refused the mail", { event, status: res.status });
      return false;
    }
    return true;
  } catch (err) {
    logger.error("[mfa-email] send threw", {
      event,
      errName: err instanceof Error ? err.name : typeof err,
    });
    return false;
  } finally {
    clearTimeout(timer);
  }
}

function readKey(): string {
  try {
    return mfaEmailApiKey.value() ?? "";
  } catch {
    return "";
  }
}

/** Production wiring: looks the address up and sends. Never throws. */
export async function notifyMfaSecurityEvent(
  uid: string,
  event: MfaSecurityEvent,
  lookupEmail: (uid: string) => Promise<string> = async (u) =>
    (await admin.auth().getUser(u)).email ?? "",
  send: typeof sendMfaSecurityEmail = sendMfaSecurityEmail,
): Promise<void> {
  try {
    const email = await lookupEmail(uid);
    await send(
      { apiKey: readKey(), from: process.env.MFA_EMAIL_FROM ?? "", fetchFn: fetch },
      email,
      event,
    );
  } catch (err) {
    logger.error("[mfa-email] could not look up the account", {
      event,
      errName: err instanceof Error ? err.name : typeof err,
    });
  }
}
