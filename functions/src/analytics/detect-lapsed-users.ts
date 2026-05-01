/**
 * Detect Lapsed Users (BUT-688 win-back A/B variant resolution).
 *
 * Scheduled daily at 5 AM UTC. Identifies users who have been inactive
 * for 7, 14, or 30 days and writes win-back notifications. Push copy
 * is resolved per-user via Remote Config + a deterministic
 * SHA-256(uid:thresholdType) bucket — see `./winback-variant.ts`.
 *
 * Firestore writes:
 *   /analytics/lapsed_users/events/{auto}        — lapsed user event
 *   /users/{userId}/notifications/{auto}         — win-back notification
 *   /users/{userId}                              — merge: lastWinBack* fields
 *
 * The `lastWinBack*` fields on the user doc are the bridge to the FA
 * dashboard: the client reads them at session start and forwards the
 * variant to FA via `ExperimentAssignment.setExperimentAssignment`
 * (BUT-657). The server cannot set FA user properties directly.
 *
 * Idempotency note: `lastWinBackSentAt` overwrites on every threshold
 * trigger. The same user can legitimately get pinged at mild → moderate
 * → strong as they progress through the dormancy stages, so we DO NOT
 * gate on the field's presence.
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { sendPushToUserRespectingPreferences } from "../shared/preference-aware-push";
import { BATCH_LIMIT } from "../shared/batch-update";
import { buildNotificationPayload } from "../shared/notification-payload";
import { evaluateSendGate } from "../shared/notification-gate";
import { recordNotificationSendEvent } from "../shared/notification-send-events";
import {
  resolveWinbackVariant,
  fetchWinbackCopy,
  DEFAULT_VARIANTS,
} from "./winback-variant";

const getDb = () => admin.firestore();

const MS_PER_HOUR = 60 * 60 * 1000;
const MS_PER_DAY = 24 * MS_PER_HOUR;

interface LapsedThreshold {
  days: number;
  type: string;
}

const THRESHOLDS: LapsedThreshold[] = [
  { days: 7, type: "win_back_mild" },
  { days: 14, type: "win_back_moderate" },
  { days: 30, type: "win_back_strong" },
];

/** Test seams. Production passes nothing; tests inject everything. */
export interface RunDeps {
  db?: admin.firestore.Firestore;
  now?: Date;
  /** Override variant resolution (e.g. force a specific variant in tests). */
  resolveVariant?: (uid: string, thresholdType: string) => string;
  /** Override RC copy fetch (e.g. simulate RC failure). */
  fetchCopy?: (
    thresholdType: string,
    variant: string,
  ) => Promise<{ title: string; body: string }>;
  /** Override the preference-aware push (test the orchestration in isolation). */
  sendPush?: typeof sendPushToUserRespectingPreferences;
  /** Override the gate decision (test paths that proceed/drop without RC). */
  gate?: typeof evaluateSendGate;
  /** Override send-event recording. */
  recordEvent?: typeof recordNotificationSendEvent;
}

export interface RunResult {
  totalDetected: number;
  pushSuccess: number;
  pushSkippedOptOut: number;
  pushSkippedQuietHours: number;
}

/**
 * Test-seam entrypoint. Production schedule wrapper just calls
 * `runDetectLapsedUsers()` with no overrides. Mirrors the shape of
 * `runTrackRetention` in `track-retention.ts`.
 */
export async function runDetectLapsedUsers(
  deps: RunDeps = {},
): Promise<RunResult> {
  const db = deps.db ?? getDb();
  const now =
    deps.now != null
      ? admin.firestore.Timestamp.fromDate(deps.now)
      : admin.firestore.Timestamp.now();
  const nowMs = now.toMillis();
  const resolveVariant = deps.resolveVariant ?? resolveWinbackVariant;
  const fetchCopy = deps.fetchCopy ?? fetchWinbackCopy;
  const sendPush =
    deps.sendPush ?? sendPushToUserRespectingPreferences;
  const gate = deps.gate ?? evaluateSendGate;
  const recordEvent = deps.recordEvent ?? recordNotificationSendEvent;

  logger.info("detect_lapsed_users_start");

  let totalDetected = 0;
  let totalPushSuccess = 0;
  let totalPushSkippedOptOut = 0;
  let totalPushSkippedQuietHours = 0;

  for (const threshold of THRESHOLDS) {
    const targetMs = nowMs - threshold.days * MS_PER_DAY;
    const windowStart = admin.firestore.Timestamp.fromMillis(
      targetMs - 12 * MS_PER_HOUR,
    );
    const windowEnd = admin.firestore.Timestamp.fromMillis(
      targetMs + 12 * MS_PER_HOUR,
    );

    const usersSnapshot = await db
      .collection("users")
      .where("lastActiveAt", ">=", windowStart)
      .where("lastActiveAt", "<=", windowEnd)
      .get();

    if (usersSnapshot.empty) {
      logger.info("no_users_lapsed", { days: threshold.days });
      continue;
    }

    // Resolve variant + copy per user up-front so the batch write can
    // include the variant on the analytics row + notification doc.
    interface PerUser {
      userId: string;
      variant: string;
      title: string;
      body: string;
    }
    const perUser: PerUser[] = [];
    for (const userDoc of usersSnapshot.docs) {
      const variant = resolveVariant(userDoc.id, threshold.type);
      const { title, body } = await fetchCopy(threshold.type, variant);
      perUser.push({ userId: userDoc.id, variant, title, body });
    }

    let batch = db.batch();
    let batchCount = 0;
    let thresholdCount = 0;

    // 3 ops per user: analytics event + notification doc + user doc merge
    // (the user-doc merge is the BUT-688 bridge-field write picked up by
    // the client-side WinbackAttributionService). Reserve under the 500
    // cap.
    const OPS_PER_USER = 3;

    for (const u of perUser) {
      const eventRef = db
        .collection("analytics")
        .doc("lapsed_users")
        .collection("events")
        .doc();
      batch.set(eventRef, {
        userId: u.userId,
        daysInactive: threshold.days,
        detectedAt: now,
        notificationSent: true,
        variant: u.variant,
      });
      batchCount++;

      const notificationRef = db
        .collection("users")
        .doc(u.userId)
        .collection("notifications")
        .doc();
      batch.set(notificationRef, {
        type: threshold.type,
        message: u.body,
        bodyShown: u.body,
        variant: u.variant,
        createdAt: now,
        read: false,
      });
      batchCount++;

      // Bridge to client-side ExperimentAssignment (BUT-657). The client
      // reads these on session start and stamps `exp_winback_copy` onto
      // the FA user property.
      const userRef = db.collection("users").doc(u.userId);
      batch.set(
        userRef,
        {
          lastWinBackVariant: u.variant,
          lastWinBackBucket: threshold.type,
          lastWinBackChannel: "push",
          lastWinBackSentAt: now,
        },
        { merge: true },
      );
      batchCount++;

      thresholdCount++;

      if (batchCount >= BATCH_LIMIT - OPS_PER_USER) {
        await batch.commit();
        batch = db.batch();
        batchCount = 0;
      }
    }

    if (batchCount > 0) {
      await batch.commit();
    }

    // Send FCM pushes. Concurrent batches of 10. Routes through the
    // preference-aware helper + send gate so users who opted out, or
    // who are inside their quiet-hours window, are NOT pinged. The
    // win-back notification doc is still written above — the gate is
    // on the push only, not on the in-app entry.
    let pushSuccessCount = 0;
    let pushSkippedOptOut = 0;
    let pushSkippedQuietHours = 0;
    for (let i = 0; i < perUser.length; i += 10) {
      const chunk = perUser.slice(i, i + 10);
      const results = await Promise.allSettled(
        chunk.map(async (u) => {
          const data = buildNotificationPayload({
            route: "/winback",
            targetId: "",
            notificationType: threshold.type,
            additionalData: {
              type: threshold.type,
              variant: u.variant,
            },
          });
          const decision = await gate({
            userId: u.userId,
            notificationType: threshold.type,
            payload: { title: u.title, body: u.body, data },
          });
          if (decision.action !== "proceed") {
            return { sent: false, reason: decision.action } as const;
          }
          const result = await sendPush(
            u.userId,
            { title: u.title, body: u.body },
            "reEngagement",
            data,
          );
          if (result.sent) {
            await recordEvent({
              userId: u.userId,
              notificationType: threshold.type,
              channel: "fcm",
            });
          }
          return result;
        }),
      );
      for (const result of results) {
        if (result.status !== "fulfilled") continue;
        if (result.value.sent) {
          pushSuccessCount++;
        } else if (
          result.value.reason === "quiet_hours" ||
          result.value.reason === "dropped" ||
          result.value.reason === "delayed"
        ) {
          pushSkippedQuietHours++;
        } else if (
          result.value.reason === "opted_out" ||
          result.value.reason === "master_disabled" ||
          result.value.reason === "type_disabled"
        ) {
          pushSkippedOptOut++;
        }
      }
    }

    totalDetected += thresholdCount;
    totalPushSuccess += pushSuccessCount;
    totalPushSkippedOptOut += pushSkippedOptOut;
    totalPushSkippedQuietHours += pushSkippedQuietHours;

    logger.info("lapsed_threshold_processed", {
      days: threshold.days,
      thresholdType: threshold.type,
      detected: thresholdCount,
      pushDelivered: pushSuccessCount,
      pushOptedOut: pushSkippedOptOut,
      pushQuietHours: pushSkippedQuietHours,
      // Variant distribution for sanity checks. With a uniform hash and
      // 2 variants, expect ~50/50.
      variantBreakdown: countVariants(perUser),
    });
  }

  logger.info("detect_lapsed_users_complete", {
    totalDetected,
    pushSuccess: totalPushSuccess,
    pushSkippedOptOut: totalPushSkippedOptOut,
    pushSkippedQuietHours: totalPushSkippedQuietHours,
  });

  return {
    totalDetected,
    pushSuccess: totalPushSuccess,
    pushSkippedOptOut: totalPushSkippedOptOut,
    pushSkippedQuietHours: totalPushSkippedQuietHours,
  };
}

function countVariants(
  perUser: { variant: string }[],
): Record<string, number> {
  const out: Record<string, number> = {};
  for (const v of DEFAULT_VARIANTS) out[v] = 0;
  for (const u of perUser) {
    out[u.variant] = (out[u.variant] ?? 0) + 1;
  }
  return out;
}

export const detectLapsedUsers = onSchedule(
  { schedule: "0 5 * * *", timeZone: "UTC" },
  async () => {
    try {
      await runDetectLapsedUsers();
    } catch (err) {
      logger.error("detect_lapsed_users_failed", { err });
      throw err;
    }
  },
);
