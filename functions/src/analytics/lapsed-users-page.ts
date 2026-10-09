/**
 * One page of the lapsed-user sweep (`detect-lapsed-users.ts`): resolve each
 * user's copy, write the page's analytics rows, notification docs, bridge
 * fields and the threshold's resume cursor, then send the pushes.
 *
 * Split out of `detect-lapsed-users.ts` (BUT-1671) when the sweep began paging,
 * to keep that file under the 500-line limit. The behaviour per user is the
 * one that file documents (BUT-688, BUT-934, BUT-1428).
 */

import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { sendPushToUserRespectingPreferences } from "../shared/preference-aware-push";
import { BATCH_LIMIT } from "../shared/batch-update";
import { buildNotificationPayload } from "../shared/notification-payload";
import { evaluateSendGate } from "../shared/notification-gate";
import { recordNotificationSendEvent } from "../shared/notification-send-events";
import { DEFAULT_VARIANTS } from "./winback-variant";
import type { ContextualCopy } from "./winback-context";

const MS_PER_DAY = 24 * 60 * 60 * 1000;

/** BUT-1428: how long an un-attributed win-back send keeps its bridge fields
 *  protected from a later threshold overwrite. Matches the client-side
 *  attribution window — a send older than this is assumed never converted and
 *  is safe to overwrite. */
const WINBACK_ATTRIBUTION_WINDOW_MS = 7 * MS_PER_DAY;

export interface LapsedThreshold {
  days: number;
  type: string;
}

export interface PageDeps {
  db: admin.firestore.Firestore;
  now: admin.firestore.Timestamp;
  resolveVariant: (uid: string, thresholdType: string) => string;
  fetchCopy: (
    thresholdType: string,
    variant: string,
  ) => Promise<{ title: string; body: string }>;
  resolveContext: (
    userId: string,
    userData: admin.firestore.DocumentData,
  ) => Promise<ContextualCopy | null>;
  sendPush: typeof sendPushToUserRespectingPreferences;
  gate: typeof evaluateSendGate;
  recordEvent: typeof recordNotificationSendEvent;
}

export interface PageResult {
  detected: number;
  pushSuccess: number;
  pushSkippedOptOut: number;
  pushSkippedQuietHours: number;
  variantBreakdown: Record<string, number>;
  contextBreakdown: Record<string, number>;
}

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
  /** The `lastActiveAt` this detection is for, as millis: part of the doc ids
   *  below, so a page that is processed twice overwrites its rows instead of
   *  adding a second notification. */
  lapseKey: number;
}

/**
 * Process one page. `cursorWrite` is staged in the page's LAST batch, so the
 * cursor advances together with the rows it covers: a run that dies before
 * that commit re-covers the page, and one that dies after it has nothing left
 * to re-send. Pushes go only after every batch of the page has committed.
 */
export async function processLapsedPage(
  deps: PageDeps,
  threshold: LapsedThreshold,
  docs: admin.firestore.QueryDocumentSnapshot[],
  cursorWrite: (batch: admin.firestore.WriteBatch) => void,
): Promise<PageResult> {
  const { db, now } = deps;
  const nowMs = now.toMillis();

  // Resolve variant + copy per user up-front so the batch write can
  // include the variant on the analytics row + notification doc.
  const perUser: PerUser[] = [];
  for (const userDoc of docs) {
    const variant = deps.resolveVariant(userDoc.id, threshold.type);
    const data = userDoc.data();
    const existingWinBackSentAt = data.lastWinBackSentAt as
      | admin.firestore.Timestamp
      | undefined;
    const lapseKey = (data.lastActiveAt as admin.firestore.Timestamp).toMillis();
    // BUT-934: try contextual copy first; fall back to the A/B variant
    // copy when no signal applies. The variant is still recorded so the
    // deterministic bucket is preserved; contextKey marks contextual
    // sends as a separate cohort in analytics.
    const context = await deps.resolveContext(userDoc.id, data);
    if (context) {
      perUser.push({
        userId: userDoc.id,
        variant,
        title: context.title,
        body: context.body,
        contextKey: context.contextKey,
        existingWinBackSentAt,
        lapseKey,
      });
    } else {
      const { title, body } = await deps.fetchCopy(threshold.type, variant);
      perUser.push({
        userId: userDoc.id,
        variant,
        title,
        body,
        contextKey: null,
        existingWinBackSentAt,
        lapseKey,
      });
    }
  }

  let batch = db.batch();
  let batchCount = 0;

  // 3 ops per user: analytics event + notification doc + user doc merge
  // (the user-doc merge is the BUT-688 bridge-field write picked up by
  // the client-side WinbackAttributionService). Reserve under the 500
  // cap, plus one for the cursor. A page whose tie group runs past one
  // batch commits its early batches without the cursor; the fixed doc ids
  // make a re-run of that page overwrite them.
  const OPS_PER_USER = 3;

  for (const u of perUser) {
    const eventRef = db
      .collection("analytics")
      .doc("lapsed_users")
      .collection("events")
      .doc(`${u.userId}_${threshold.type}_${u.lapseKey}`);
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
      .doc(`winback_${threshold.type}_${u.lapseKey}`);
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

    if (batchCount >= BATCH_LIMIT - OPS_PER_USER - 1) {
      await batch.commit();
      batch = db.batch();
      batchCount = 0;
    }
  }

  cursorWrite(batch);
  await batch.commit();

  // Send FCM pushes. Concurrent batches of 10. Routes through the
  // preference-aware helper + send gate so users who opted out, or
  // who are inside their quiet-hours window, are NOT pinged. The
  // win-back notification doc is still written above — the gate is
  // on the push only, not on the in-app entry.
  let pushSuccess = 0;
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
        const decision = await deps.gate({
          userId: u.userId,
          notificationType: threshold.type,
          payload: { title: u.title, body: u.body, data },
        });
        if (decision.action !== "proceed") {
          return { sent: false, reason: decision.action } as const;
        }
        const result = await deps.sendPush(
          u.userId,
          { title: u.title, body: u.body },
          "reEngagement",
          data,
        );
        if (result.sent) {
          await deps.recordEvent({
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
        pushSuccess++;
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

  return {
    detected: perUser.length,
    pushSuccess,
    pushSkippedOptOut,
    pushSkippedQuietHours,
    variantBreakdown: countVariants(perUser),
    contextBreakdown: countContexts(perUser),
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
