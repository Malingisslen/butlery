/**
 * Server-side pre-send gate (BUT-647 + BUT-645).
 *
 * Combines four checks, in order:
 *   1. RC flag `notifications.enabled.<type>` — if false, drop. Fail-open.
 *   2. Quiet-hours window — low-importance drop, high-importance delay.
 *   3. (Caller still applies the existing preference-aware gate after
 *      this returns `proceed=true` — preferences + master toggle.)
 *   4. Records a `notification_send_events` row when the gate decides
 *      to PROCEED or DELAY (the delay enqueue is done here too — caller
 *      doesn't have to know about the queue).
 *
 * Why centralize: three different senders (`sendNotification` callable,
 * `detectLapsedUsers`, `sendWeeklyActivityDigest`) all need the same
 * decision tree. Duplicated in three places ⇒ drift.
 */

import { logger } from "firebase-functions/logger";
import { logAnalyticsEvent } from "./analytics-server";
import { classifyImportance } from "./notification-importance";
import {
  isNotificationTypeEnabled,
  RcFlagsDeps,
} from "./notification-rc-flags";
import {
  evaluateQuietHours,
  QuietHoursConfig,
} from "./quiet-hours";
import {
  enqueueScheduledNotification,
  ScheduledNotificationPayload,
} from "./scheduled-notifications";
import { recordNotificationSendEvent } from "./notification-send-events";

export type GateAction = "proceed" | "dropped" | "delayed" | "type_disabled";

export interface GateDecision {
  action: GateAction;
  /** Set when `action === "delayed"`. */
  deliverAt?: Date;
  /** Reason string for log/analytics. */
  reason: string;
}

export interface GateOpts {
  userId: string;
  notificationType: string;
  /**
   * Required when the gate may decide to delay (high-importance push).
   * Low-importance drops don't need it. Callers who never delay can
   * omit it.
   */
  payload?: ScheduledNotificationPayload;
  now?: Date;
  /** Test seams. */
  rcDeps?: RcFlagsDeps;
  quietHoursLoader?: (uid: string) => Promise<QuietHoursConfig>;
  enqueue?: typeof enqueueScheduledNotification;
  recordEvent?: typeof recordNotificationSendEvent;
}

/**
 * Runs the full gate. Caller proceeds with their normal send path
 * iff `decision.action === "proceed"`. Otherwise the gate has handled
 * everything (drop = no-op, delay = enqueued, disabled = no-op).
 */
export async function evaluateSendGate(opts: GateOpts): Promise<GateDecision> {
  const {
    userId,
    notificationType,
    payload,
    now = new Date(),
    rcDeps,
    quietHoursLoader,
    enqueue = enqueueScheduledNotification,
    recordEvent = recordNotificationSendEvent,
  } = opts;

  // 1. Per-type RC flag.
  const enabled = await isNotificationTypeEnabled(notificationType, rcDeps);
  if (!enabled) {
    logger.info("notification_type_disabled", { notificationType, userId });
    logAnalyticsEvent("notification_type_disabled", {
      userId,
      notificationType,
    });
    return { action: "type_disabled", reason: "rc_flag_disabled" };
  }

  // 2. Quiet hours.
  const decision = await evaluateQuietHours(userId, now, quietHoursLoader);
  if (!decision.inWindow) {
    return { action: "proceed", reason: "outside_window" };
  }

  const importance = classifyImportance(notificationType);
  if (importance === "low") {
    logger.info("quiet_hours_dropped", {
      userId,
      notificationType,
      timezone: decision.config.timezone,
    });
    logAnalyticsEvent("quiet_hours_suppressed", {
      userId,
      notificationType,
      action: "dropped",
    });
    return { action: "dropped", reason: "quiet_hours_low_importance" };
  }

  // 3. High importance + in-window → delay.
  const deliverAt = decision.deliverAt ?? new Date(now.getTime() + 60 * 60 * 1000);
  if (!payload) {
    // Caller didn't give us a payload to enqueue — they're presumably a
    // path that can't be delayed (e.g. legacy). Best we can do: drop and
    // record. This shouldn't happen in production.
    logger.warn("quiet_hours_high_importance_no_payload_drop", {
      userId,
      notificationType,
    });
    logAnalyticsEvent("quiet_hours_suppressed", {
      userId,
      notificationType,
      action: "dropped",
      reason: "no_payload_for_delay",
    });
    return { action: "dropped", reason: "no_payload_for_delay" };
  }

  await enqueue({ userId, notificationType, deliverAt, payload });
  logAnalyticsEvent("quiet_hours_suppressed", {
    userId,
    notificationType,
    action: "delayed",
    deliverAt: deliverAt.toISOString(),
  });
  // Record the send-event under the `scheduled_queue` channel so CTR
  // analysis attributes the open to the eventual delivery, not now.
  await recordEvent({
    userId,
    notificationType,
    channel: "scheduled_queue",
    now,
  });
  return { action: "delayed", deliverAt, reason: "quiet_hours_high_importance" };
}
