/**
 * Preference-Aware Push Helper (BUT-438)
 *
 * Wraps `sendPushToUser` with two gates that the raw FCM helper does not
 * apply:
 *   1. Notification preferences — master `enabled` flag + per-category
 *      opt-out (e.g. re-engagement / win-back pings).
 *   2. Quiet hours — skips delivery when the current Stockholm wall-clock
 *      time falls inside the user's configured window.
 *
 * Reads from `user_notification_preferences/{userId}` (root collection),
 * matching `FirebaseNotificationsRepository` on the client side. The
 * client-side `NotificationPreferences` model writes:
 *   - enabled: bool                         (master toggle)
 *   - quietHoursStart: { hour, minute }     (nullable)
 *   - quietHoursEnd:   { hour, minute }     (nullable)
 *   - categorySettings: { [Enum.toString]: bool }
 *
 * `reEngagement` is not yet a first-class field in the client model, so we
 * accept the value through TWO paths so we honor both the spec and any
 * future client schema:
 *   1. A top-level boolean `reEngagement` on the prefs doc (preferred).
 *   2. The closest existing category — `NotificationCategory.system` —
 *      since win-back is a system-driven, non-social ping and shares the
 *      same opt-in semantics.
 * If neither is set, we treat re-engagement as ENABLED (default-on),
 * matching the rest of the repo's permissive defaults. Users who have
 * never touched settings are not silently muted.
 *
 * Intentionally NOT migrating the other call sites (digest, etc.) here —
 * out of scope for BUT-438. This helper only fixes the win-back path;
 * other call sites should adopt it in a follow-up sprint.
 */

import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { sendPushToUser } from "./fcm-tokens";
import {
  checkAndIncrement,
  Priority,
  RateCapResult,
} from "../notifications/notification-rate-cap";

export type PushSkipReason =
  | "sent"
  | "opted_out"
  | "quiet_hours"
  | "no_token"
  | "master_disabled"
  | "rate_capped"; // BUT-651: per-user 24h fatigue cap

/** Notification categories the helper currently knows how to gate. */
export type NotificationCategory = "reEngagement";

export interface PreferenceAwarePushResult {
  sent: boolean;
  reason: PushSkipReason;
  successCount?: number;
  failureCount?: number;
}

interface QuietHourPoint {
  hour: number;
  minute: number;
}

interface PreferencesShape {
  enabled?: boolean;
  reEngagement?: boolean;
  quietHoursStart?: QuietHourPoint | null;
  quietHoursEnd?: QuietHourPoint | null;
  categorySettings?: Record<string, boolean>;
}

/** Injected by tests; production resolves via admin.firestore() lazily. */
export interface Deps {
  getPreferences: (userId: string) => Promise<PreferencesShape | null>;
  getNow: () => Date;
  send: typeof sendPushToUser;
  /**
   * BUT-1223: rate-cap seam. The real `checkAndIncrement` opens a Firestore
   * transaction via `admin.firestore()` — tests without an initialized app
   * MUST inject a stub here (same convention as the gate/recordEvent seams
   * on DispatchOptions in send-notification.ts).
   */
  checkRateCap: (args: {
    userId: string;
    priority?: Priority;
    now?: Date;
  }) => Promise<RateCapResult>;
}

const STOCKHOLM_TZ = "Europe/Stockholm";

const _stockholmFmt = new Intl.DateTimeFormat("en-GB", {
  timeZone: STOCKHOLM_TZ,
  hour: "2-digit",
  minute: "2-digit",
  hour12: false,
});

/**
 * Returns `{hour, minute}` for the given UTC Date, expressed in Stockholm
 * wall-clock time. Uses Intl rather than a date library to keep this
 * helper dependency-free.
 */
export function stockholmHourMinute(now: Date): QuietHourPoint {
  const parts = _stockholmFmt.formatToParts(now);
  const hour = Number(parts.find((p) => p.type === "hour")?.value ?? "0");
  const minute = Number(parts.find((p) => p.type === "minute")?.value ?? "0");
  // "24:00" appears on some ICU builds — normalize.
  return { hour: hour === 24 ? 0 : hour, minute };
}

/**
 * Returns true when `nowMinutes` falls in the [start, end) window. Handles
 * windows that wrap midnight (e.g. 22:00 → 08:00 means 22:00–23:59 OR
 * 00:00–07:59). Equal start/end → empty window (never quiet).
 */
export function isInQuietWindow(
  now: QuietHourPoint,
  start: QuietHourPoint,
  end: QuietHourPoint
): boolean {
  const n = now.hour * 60 + now.minute;
  const s = start.hour * 60 + start.minute;
  const e = end.hour * 60 + end.minute;
  if (s === e) return false;
  if (s < e) return n >= s && n < e;
  // Wraps midnight.
  return n >= s || n < e;
}

function isCategoryAllowed(
  prefs: PreferencesShape,
  category: NotificationCategory
): boolean {
  if (category === "reEngagement") {
    if (typeof prefs.reEngagement === "boolean") return prefs.reEngagement;
    // Fallback: the closest existing client-side category. The Dart enum
    // serializes as `NotificationCategory.system`.
    const fromCategory = prefs.categorySettings?.["NotificationCategory.system"];
    if (typeof fromCategory === "boolean") return fromCategory;
    return true; // default-on, matching client defaults
  }
  return true;
}

async function defaultGetPreferences(
  userId: string
): Promise<PreferencesShape | null> {
  const snap = await admin
    .firestore()
    .collection("user_notification_preferences")
    .doc(userId)
    .get();
  if (!snap.exists) return null;
  return (snap.data() as PreferencesShape) ?? null;
}

/**
 * Sends a push only if the user has not opted out and is not currently
 * in a quiet-hours window.
 */
export async function sendPushToUserRespectingPreferences(
  userId: string,
  notification: { title: string; body: string },
  category: NotificationCategory,
  data?: Record<string, string>,
  deps: Partial<Deps> = {}
): Promise<PreferenceAwarePushResult> {
  const getPreferences = deps.getPreferences ?? defaultGetPreferences;
  const getNow = deps.getNow ?? (() => new Date());
  const send = deps.send ?? sendPushToUser;
  const checkRateCap = deps.checkRateCap ?? checkAndIncrement;

  const prefs = (await getPreferences(userId)) ?? {};

  // Master toggle. If the doc is missing or `enabled` is undefined, treat
  // as opted-in (matches client defaults).
  if (prefs.enabled === false) {
    logger.info(
      `Skipping push to ${userId}: master notifications disabled`
    );
    return { sent: false, reason: "master_disabled" };
  }

  if (!isCategoryAllowed(prefs, category)) {
    logger.info(
      `Skipping push to ${userId}: opted out of ${category}`
    );
    return { sent: false, reason: "opted_out" };
  }

  const start = prefs.quietHoursStart;
  const end = prefs.quietHoursEnd;
  if (start && end) {
    const stockholmNow = stockholmHourMinute(getNow());
    if (isInQuietWindow(stockholmNow, start, end)) {
      logger.info(
        `Skipping push to ${userId}: quiet hours ` +
          `(${start.hour}:${String(start.minute).padStart(2, "0")} - ` +
          `${end.hour}:${String(end.minute).padStart(2, "0")} Europe/Stockholm)`
      );
      return { sent: false, reason: "quiet_hours" };
    }
  }

  // BUT-651: global per-user 24h fatigue cap. Win-back, digests, and other
  // category-aware sends are non-critical by definition; critical sends
  // (security alerts, admin moderation) call sendPushToUser directly and
  // therefore bypass this gate intentionally.
  const capDecision = await checkRateCap({
    userId,
    priority: "noncritical" as Priority,
    now: getNow(),
  });
  if (!capDecision.allowed) {
    return { sent: false, reason: "rate_capped" };
  }

  const result = await send(userId, notification, data);
  if (result.successCount === 0) {
    return {
      sent: false,
      reason: "no_token",
      successCount: 0,
      failureCount: result.failureCount,
    };
  }
  return {
    sent: true,
    reason: "sent",
    successCount: result.successCount,
    failureCount: result.failureCount,
  };
}
