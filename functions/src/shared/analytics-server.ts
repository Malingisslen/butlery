/**
 * Server-side analytics emitter (BUT-647 / BUT-645 / BUT-638).
 *
 * Cloud Functions can't call the Firebase Analytics SDK directly — that's
 * a client-only API. Instead we emit structured `logger.info` entries
 * with a stable `event` field, and Cloud Logging → BigQuery export picks
 * them up. Downstream dashboards (Looker Studio, BigQuery) key off
 * `jsonPayload.event` to bucket counts.
 *
 * Contract:
 *   - First log arg is a stable string `event=<name>` for grep-ability.
 *   - Second arg is the structured object Cloud Logging surfaces as
 *     jsonPayload fields. NEVER include PII (no emails, message bodies,
 *     full recipe titles).
 *   - Caller is responsible for hashing user ids if the event will be
 *     visible to non-internal viewers (`hashUid` from shared/hash-uid.ts).
 *     For internal-ops dashboards we keep raw uids.
 */

import { logger } from "firebase-functions/logger";

export interface ServerAnalyticsFields {
  // Common dimensions across all events.
  userId?: string;
  notificationType?: string;
  // Free-form additional fields. Coerced to JSON-safe primitives by the
  // logger automatically.
  [key: string]: unknown;
}

/**
 * Emits a structured analytics event to Cloud Logging. The shape:
 *   `{ "event": "<eventName>", ...fields }`
 *
 * Picked up by the BigQuery export and bucketed by `event`.
 */
export function logAnalyticsEvent(
  eventName: string,
  fields: ServerAnalyticsFields = {}
): void {
  logger.info(`event=${eventName}`, { event: eventName, ...fields });
}
