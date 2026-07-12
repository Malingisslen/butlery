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
 * Bridge-field gating (BUT-1428): `lastWinBack*` normally overwrites on
 * every threshold trigger — a user can legitimately progress mild →
 * moderate → strong through the dormancy stages. BUT while an EARLIER
 * send is still un-attributed and inside its 7-day attribution window the
 * overwrite is SKIPPED: clobbering it would let the client's single-
 * attribution latch credit the conversion to the later variant and bias
 * the A/B toward whichever stage fired last. The client CLEARS these
 * fields on attribution, so their presence + freshness means "earlier
 * send not yet attributed". A stale prior send (past the window) is safe
 * to overwrite. The user still receives this notification either way;
 * only the attribution bridge is preserved.
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
import {
  resolveContextualWinbackCopy,
  type ContextualCopy,
} from "./winback-context";

const getDb = () => admin.firestore();

const MS_PER_HOUR = 60 * 60 * 1000;
const MS_PER_DAY = 24 * MS_PER_HOUR;

/** BUT-1428: how long an un-attributed win-back send keeps its bridge fields
 *  protected from a later threshold overwrite. Matches the client-side
 *  attribution window — a send older than this is assumed never converted and
 *  is safe to overwrite. */
const WINBACK_ATTRIBUTION_WINDOW_MS = 7 * MS_PER_DAY;

/** BUT-1567: on the very first run (no stored cursor) we don't want to sweep
 *  every dormant user who ever crossed a threshold in one giant backfill.
 *  Default the cursor to one scheduling interval back so the first run
 *  behaves like a normal daily run; every subsequent run reads the real
 *  stored cursor. */
const DEFAULT_CURSOR_LOOKBACK_MS = MS_PER_DAY;

/** BUT-1567: the cursor doc holding `lastRunAt` — the parent of the
 *  lapsed-user events subcollection (a Firestore doc can carry fields AND
 *  own subcollections). */
const CURSOR_DOC = { collection: "analytics", doc: "lapsed_users" } as const;

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
  /** Override contextual-copy resolution (BUT-934). */
  resolveContext?: (
    userId: string,
    userData: admin.firestore.DocumentData,
  ) => Promise<ContextualCopy | null>;
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
  const resolveContext =
    deps.resolveContext ??
    ((userId: string, userData: admin.firestore.DocumentData) =>
      resolveContextualWinbackCopy(userId, userData, {
        db,
        now: nowMs,
      }));
  const sendPush =
    deps.sendPush ?? sendPushToUserRespectingPreferences;
  const gate = deps.gate ?? evaluateSendGate;
  const recordEvent = deps.recordEvent ?? recordNotificationSendEvent;

  logger.info("detect_lapsed_users_start");

  // BUT-1567: read the last-run cursor. The old predicate matched a fixed
  // ±12h band centred on each threshold, so a run that was skipped (outage,
  // schedule drift) left a permanent gap — any user whose lastActiveAt fell
  // in that day's band was never detected. We instead detect users who
  // CROSSED a threshold since the previous run, covering the whole gap and
  // catching irregular users the point-in-time band missed. First run (no
  // cursor) falls back to a bounded one-interval lookback.
  const cursorRef = db.collection(CURSOR_DOC.collection).doc(CURSOR_DOC.doc);
  const cursorSnap = await cursorRef.get();
  const storedCursor = cursorSnap.exists
    ? (cursorSnap.data()?.lastRunAt as admin.firestore.Timestamp | undefined)
    : undefined;
  const lastRunMs = storedCursor?.toMillis() ?? nowMs - DEFAULT_CURSOR_LOOKBACK_MS;

  let totalDetected = 0;
  let totalPushSuccess = 0;
  let totalPushSkippedOptOut = 0;
  let totalPushSkippedQuietHours = 0;

  for (const threshold of THRESHOLDS) {
    // A user has crossed the N-day inactivity threshold once their last
    // activity is older than N days: lastActiveAt <= now - N*days. To catch
    // every crosser exactly once — including those from a skipped run — pick
    // only users who were NOT yet past the threshold at the previous run:
    // window = (lastRun - N*days, now - N*days]. The upper bound is inclusive
    // (just-crossed) and the lower bound exclusive (already handled last run,
    // so no double-notify).
    const crossedByNow = admin.firestore.Timestamp.fromMillis(
      nowMs - threshold.days * MS_PER_DAY,
    );
    const alreadyCrossedAtLastRun = admin.firestore.Timestamp.fromMillis(
      lastRunMs - threshold.days * MS_PER_DAY,
    );

    // Degenerate window (cursor at/after now — clock moved backwards, or a
    // duplicate same-instant run) → nothing newly crossed; skip.
    if (alreadyCrossedAtLastRun.toMillis() >= crossedByNow.toMillis()) {
      logger.info("lapsed_window_empty", { days: threshold.days });
      continue;
    }

    const usersSnapshot = await db
      .collection("users")
      .where("lastActiveAt", ">", alreadyCrossedAtLastRun)
      .where("lastActiveAt", "<=", crossedByNow)
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
      /** BUT-934: signal that produced contextual copy, or null if generic. */
      contextKey: string | null;
      /** BUT-1428: the user's existing `lastWinBackSentAt`, if any, so the
       *  bridge write can avoid clobbering a still-un-attributed earlier send. */
      existingWinBackSentAt?: admin.firestore.Timestamp;
    }
    const perUser: PerUser[] = [];
    for (const userDoc of usersSnapshot.docs) {
      const variant = resolveVariant(userDoc.id, threshold.type);
      const data = userDoc.data();
      const existingWinBackSentAt = data.lastWinBackSentAt as
        | admin.firestore.Timestamp
        | undefined;
      // BUT-934: try contextual copy first; fall back to the A/B variant
      // copy when no signal applies. The variant is still recorded so the
      // deterministic bucket is preserved; contextKey marks contextual
      // sends as a separate cohort in analytics.
      const context = await resolveContext(userDoc.id, data);
      if (context) {
        perUser.push({
          userId: userDoc.id,
          variant,
          title: context.title,
          body: context.body,
          contextKey: context.contextKey,
          existingWinBackSentAt,
        });
      } else {
        const { title, body } = await fetchCopy(threshold.type, variant);
        perUser.push({
          userId: userDoc.id,
          variant,
          title,
          body,
          contextKey: null,
          existingWinBackSentAt,
        });
      }
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
        contextKey: u.contextKey,
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
        contextKey: u.contextKey,
        createdAt: now,
        read: false,
      });
      batchCount++;

      // Bridge to client-side ExperimentAssignment (BUT-657). The client
      // reads these on session start and stamps `exp_winback_copy` onto
      // the FA user property.
      //
      // BUT-1428: skip the overwrite while an earlier send is still
      // un-attributed and inside its window — otherwise the client's
      // single-attribution latch would credit the conversion to this later
      // variant and bias the A/B. Presence of `lastWinBackSentAt` means the
      // client hasn't attributed yet (it clears the fields on attribution).
      const prevSentAtMs = u.existingWinBackSentAt?.toMillis();
      const earlierSendStillPending =
        prevSentAtMs != null &&
        nowMs - prevSentAtMs < WINBACK_ATTRIBUTION_WINDOW_MS;

      if (earlierSendStillPending) {
        logger.info("winback_bridge_skipped_pending_attribution", {
          bucket: threshold.type,
        });
      } else {
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
      }

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
      // BUT-934: how many sends used each contextual signal vs generic.
      contextBreakdown: countContexts(perUser),
    });
  }

  // BUT-1567: advance the cursor only after every threshold has been
  // processed. If a threshold threw, we never reach here and the cursor
  // stays put, so the next run re-covers the gap — deliberately favouring
  // occasional re-coverage over silently missing a lapse.
  await cursorRef.set({ lastRunAt: now }, { merge: true });

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

function countContexts(
  perUser: { contextKey: string | null }[],
): Record<string, number> {
  const out: Record<string, number> = {};
  for (const u of perUser) {
    const key = u.contextKey ?? "generic";
    out[key] = (out[key] ?? 0) + 1;
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
