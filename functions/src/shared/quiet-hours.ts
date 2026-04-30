/**
 * Server-side quiet-hours enforcement (BUT-647).
 *
 * Mirror of the client-side window check, moved server-side so the user
 * is never woken up by a push that the client would have silently dropped
 * after delivery. The behavior tier-splits on importance:
 *
 *   - LOW importance (win-back, digest, marketing) → DROP outright. The
 *     in-app notification doc still lands, so the user sees it next
 *     time they open the app.
 *   - HIGH importance (comments, friend-requests, recipe-shares) → DELAY
 *     until window end via the `scheduled_notifications` queue (drained
 *     by `deliverScheduledNotifications` every 5 min).
 *
 * Storage: extends the existing `user_notification_preferences/{uid}` doc
 * with optional `timezone` (IANA, e.g. `Europe/Stockholm`). Defaults to
 * `Europe/Stockholm` when missing — matches the implicit prior behavior
 * (`preference-aware-push.ts` hard-coded that TZ).
 *
 * Quiet-window shape on the prefs doc (unchanged from BUT-438):
 *   - `quietHoursStart: { hour: int, minute: int } | null`
 *   - `quietHoursEnd:   { hour: int, minute: int } | null`
 *
 * Missing prefs (no doc, or no quiet-hours fields) → `inWindow: false`
 * everywhere. The product call: don't black-hole users who haven't
 * configured quiet hours.
 */

import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";

export const DEFAULT_TIMEZONE = "Europe/Stockholm";

export interface QuietHourPoint {
  hour: number;
  minute: number;
}

export interface QuietHoursConfig {
  /** IANA timezone — defaults to `Europe/Stockholm` if absent. */
  timezone: string;
  start: QuietHourPoint | null;
  end: QuietHourPoint | null;
  /** When false (or quiet-hours fields missing), the gate is a no-op. */
  enabled: boolean;
}

export interface QuietHoursDecision {
  inWindow: boolean;
  /** Set when `inWindow=true`; the next UTC moment the window ends. */
  deliverAt?: Date;
  /** The resolved config used for the decision (for logging). */
  config: QuietHoursConfig;
}

/**
 * Reads the user's quiet-hours config from `user_notification_preferences/{uid}`.
 * Returns a default-disabled config when the doc is missing. Test seam.
 */
export async function loadQuietHoursConfig(
  userId: string,
  db: admin.firestore.Firestore = admin.firestore()
): Promise<QuietHoursConfig> {
  try {
    const snap = await db
      .collection("user_notification_preferences")
      .doc(userId)
      .get();
    if (!snap.exists) {
      return { timezone: DEFAULT_TIMEZONE, start: null, end: null, enabled: false };
    }
    const data = snap.data() ?? {};
    const start = data.quietHoursStart as QuietHourPoint | null | undefined;
    const end = data.quietHoursEnd as QuietHourPoint | null | undefined;
    const timezone = (data.timezone as string | undefined) ?? DEFAULT_TIMEZONE;
    const enabled = Boolean(start && end);
    return {
      timezone,
      start: start ?? null,
      end: end ?? null,
      enabled,
    };
  } catch (err) {
    // Fail-open: prefs read errors must not black-hole the push. Log and
    // pretend the user has no quiet hours configured.
    logger.warn("loadQuietHoursConfig failed; treating as disabled", {
      userId,
      err,
    });
    return { timezone: DEFAULT_TIMEZONE, start: null, end: null, enabled: false };
  }
}

/**
 * Returns local hour/minute for `now` in the given IANA timezone.
 * Pure Intl — no date library dep.
 */
export function localHourMinute(now: Date, timezone: string): QuietHourPoint {
  const fmt = new Intl.DateTimeFormat("en-GB", {
    timeZone: timezone,
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });
  const parts = fmt.formatToParts(now);
  const hour = Number(parts.find((p) => p.type === "hour")?.value ?? "0");
  const minute = Number(parts.find((p) => p.type === "minute")?.value ?? "0");
  return { hour: hour === 24 ? 0 : hour, minute };
}

/**
 * True iff `now` falls in `[start, end)`. Handles wrap-around midnight
 * (e.g. 22:00 → 08:00 means 22:00–23:59 OR 00:00–07:59). `start === end`
 * means an empty window (never quiet) — defensive against operator typos.
 */
export function isInWindow(
  now: QuietHourPoint,
  start: QuietHourPoint,
  end: QuietHourPoint
): boolean {
  const n = now.hour * 60 + now.minute;
  const s = start.hour * 60 + start.minute;
  const e = end.hour * 60 + end.minute;
  if (s === e) return false;
  if (s < e) return n >= s && n < e;
  return n >= s || n < e;
}

/**
 * Computes the next UTC `Date` at which the local-clock window-end fires.
 * Used to schedule a delayed push for high-importance notifications.
 *
 * Approach: iterate forward in 5-minute steps (≤ 24h × 12 = 288 steps)
 * checking `localHourMinute === end`. This is O(constant), avoids
 * date-arithmetic across DST boundaries, and stays dependency-free.
 *
 * Edge: when the user is currently AT the end-minute (window just ended),
 * we still return ~24h later — but in practice this branch isn't reached
 * because callers only ask for `deliverAt` when `inWindow=true`.
 */
export function nextWindowEndUtc(
  now: Date,
  end: QuietHourPoint,
  timezone: string
): Date {
  const STEP_MIN = 5;
  const MAX_STEPS = (24 * 60) / STEP_MIN + 1;
  for (let i = 1; i <= MAX_STEPS; i++) {
    const candidate = new Date(now.getTime() + i * STEP_MIN * 60 * 1000);
    const local = localHourMinute(candidate, timezone);
    if (local.hour === end.hour && local.minute === end.minute) {
      return candidate;
    }
    // Also accept "first minute past end" for granularity buffering.
    const localMin = local.hour * 60 + local.minute;
    const endMin = end.hour * 60 + end.minute;
    if (i > 1 && localMin === (endMin + 1) % (24 * 60)) {
      return candidate;
    }
  }
  // Fallback: 8h from now. Should never hit unless TZ is exotic.
  return new Date(now.getTime() + 8 * 60 * 60 * 1000);
}

/**
 * Top-level decision call. Returns whether the push falls inside the
 * user's quiet window and (if so) when it would next be safe to deliver.
 *
 * Test seam: pass `now` and `loader` for deterministic assertions.
 */
export async function evaluateQuietHours(
  userId: string,
  now: Date = new Date(),
  loader: (uid: string) => Promise<QuietHoursConfig> = (uid) =>
    loadQuietHoursConfig(uid)
): Promise<QuietHoursDecision> {
  const config = await loader(userId);
  if (!config.enabled || !config.start || !config.end) {
    return { inWindow: false, config };
  }
  const local = localHourMinute(now, config.timezone);
  if (!isInWindow(local, config.start, config.end)) {
    return { inWindow: false, config };
  }
  const deliverAt = nextWindowEndUtc(now, config.end, config.timezone);
  return { inWindow: true, deliverAt, config };
}
