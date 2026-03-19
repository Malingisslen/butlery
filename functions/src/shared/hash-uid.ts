/**
 * GDPR-safe userId hashing for Cloud Function logs.
 *
 * Dietary preferences are special category data under GDPR Article 9.
 * Raw userIds must not appear in logs — use this hash for correlation.
 */

import * as crypto from "crypto";

/** Hash userId to a 12-char hex prefix for GDPR-safe logging. */
export function hashUid(uid: string): string {
  return crypto.createHash("sha256").update(uid).digest("hex").substring(0, 12);
}
