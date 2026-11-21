import { logger } from "firebase-functions/logger";

/**
 * BUT-2512: the two log lines the "Account erasure incomplete" alert policy in
 * `infrastructure/alerting/setup-gcp-alerts.sh` filters on. The policy matches
 * the exact text, so a reworded message silently disables the alert; a test
 * reads the script and fails if either string is missing from it.
 */
export const ERASURE_GAVE_UP_LOG =
  "[account-erasure] scheduled erasure gave up incomplete";
export const ERASURE_ON_DEMAND_INCOMPLETE_LOG =
  "[account-erasure] on-demand erasure incomplete";

/** Uid prefix and step names only: no path, no raw error. */
export function logErasureGaveUp(
  uid: string,
  failedCollections: readonly string[],
  attempts: number,
): void {
  logger.error(ERASURE_GAVE_UP_LOG, {
    uid_prefix: uid.slice(0, 6),
    failedCollections: [...failedCollections],
    attempts,
  });
}

/** Called by the account-deletion callable with its result. */
export function reportOnDemandOutcome(
  uid: string,
  result: { success: boolean; failedCollections: readonly string[] },
): void {
  if (result.success) return;
  logger.error(ERASURE_ON_DEMAND_INCOMPLETE_LOG, {
    uid_prefix: uid.slice(0, 6),
    failedCollections: [...result.failedCollections],
  });
}
