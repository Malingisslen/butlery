/**
 * Shared admin authentication guard for callable functions.
 *
 * Throws HttpsError if the caller is not authenticated or not an admin.
 */

import * as functions from "firebase-functions";

export function requireAdmin(
  context: functions.https.CallableContext
): void {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Authentication required"
    );
  }

  const isAdmin = context.auth.token.admin === true ||
                  context.auth.token.role === "admin";
  if (!isAdmin) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Admin access required"
    );
  }
}
