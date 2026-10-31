/**
 * The server's own check of the AI-processing consent, read from
 * `users/{uid}/consent/current` and never taken from the client (ADR-0037).
 */

import * as admin from "firebase-admin";
import { CallableRequest, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import { hashUid } from "../shared/hash-uid";

/** `details.reason` of the refusal; the app maps it to its own Swedish text. */
export const AI_CONSENT_REQUIRED = "ai-consent-required";

export async function hasAiConsentIn(
  db: admin.firestore.Firestore,
  uid: string
): Promise<boolean> {
  const doc = await db.doc(`users/${uid}/consent/current`).get();
  if (!doc.exists) return false;
  const purposes = doc.get("purposes") as Record<string, unknown> | undefined;
  return purposes?.aiProcessing === true;
}

/**
 * Refuses the call unless the caller has consented to AI processing. A missing
 * consent document, a withdrawn consent and a failed read all refuse, and a
 * guest is held to the same rule. Runs before any quota or rate-limit counter
 * is touched, so a refused call costs the caller nothing.
 */
export function withAiConsent<TRequest, TResponse>(
  handler: (request: CallableRequest<TRequest>) => Promise<TResponse>,
  hasAiConsent: (uid: string) => Promise<boolean> = (uid) =>
    hasAiConsentIn(admin.firestore(), uid)
): (request: CallableRequest<TRequest>) => Promise<TResponse> {
  return async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Du måste vara inloggad för att använda denna funktion."
      );
    }
    let consented: boolean;
    try {
      consented = await hasAiConsent(request.auth.uid);
    } catch (err) {
      logger.error("[ai-consent] consent read failed; refusing", {
        uid_hash: hashUid(request.auth.uid),
        errName: err instanceof Error ? err.name : typeof err,
      });
      // Not the consent refusal: the app turns that one into "give consent in
      // settings", which is wrong advice for someone who already has.
      throw new HttpsError(
        "unavailable",
        "Tjänsten är tillfälligt otillgänglig. Försök igen."
      );
    }
    if (!consented) {
      throw new HttpsError(
        "failed-precondition",
        "AI-tolkning kräver ditt samtycke.",
        { reason: AI_CONSENT_REQUIRED }
      );
    }
    return handler(request);
  };
}
