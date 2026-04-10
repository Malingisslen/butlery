/**
 * Shared admin authentication guard for callable functions.
 *
 * Throws HttpsError if the caller is not authenticated or not an admin.
 */

import { CallableRequest, HttpsError } from "firebase-functions/v2/https";

export function requireAdmin(
  request: CallableRequest<unknown>
): void {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Authentication required"
    );
  }

  const isAdmin = request.auth.token.admin === true ||
                  request.auth.token.role === "admin";
  if (!isAdmin) {
    throw new HttpsError(
      "permission-denied",
      "Admin access required"
    );
  }
}
