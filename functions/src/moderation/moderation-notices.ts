/**
 * BUT-2353: the notices a moderation decision and an appeal answer leave.
 *
 * Each notice is an inbox row plus a push. The row goes in
 * `notification_history`, which is what the app's Aviseringar list reads
 * (`FirebaseNotificationHistoryRepository.getHistory`), in the shape that
 * repository writes; its id is deterministic and it is written in the same
 * transaction as the decision or the answer, so a retry neither duplicates
 * nor loses it. The push is sent after the commit and may be lost; the row is
 * what the person can always find.
 *
 * The lock-screen text says only that a case is decided (Malin, 2026-10-10).
 */

import { createHash } from "crypto";
import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { sendPushToUser } from "../shared/fcm-tokens";
import { buildNotificationPayload, NotificationRoute } from "../shared/notification-payload";
import { hashUid } from "../shared/hash-uid";
import { AppealRole } from "./appeals";

export const NOTIFICATION_HISTORY = "notification_history";

/** The client's own writer stamps the same 90 days. */
export const NOTICE_RETENTION_DAYS = 90;

export const REPORTS_ROUTE: NotificationRoute = "/my_reports";
export const CONTENT_DECISIONS_ROUTE: NotificationRoute = "/my_content_decisions";

export interface Notice {
  id: string;
  userId: string;
  title: string;
  body: string;
  route: NotificationRoute;
  targetId: string;
  notificationType: string;
}

/**
 * A fixed-length stand-in for a report or appeal id inside a notice id. Report
 * ids are chosen by the client and may be up to Firestore's 1500-byte limit, so
 * a prefix and suffix around the raw id can exceed it and fail the decision's
 * transaction on every retry. The raw id travels in `data.targetId`.
 */
export function noticeKey(id: string): string {
  return createHash("sha256").update(id, "utf8").digest("hex");
}

export function routeForRole(role: AppealRole): NotificationRoute {
  return role === "reporter" ? REPORTS_ROUTE : CONTENT_DECISIONS_ROUTE;
}

/**
 * A round after the first (BUT-1528) gets its own row, so the first decision's
 * row is not overwritten, and says that the decision changed.
 */
function roundSuffix(round: number): string {
  return round > 0 ? `_r${round}` : "";
}

export function reporterNotice(reportId: string, userId: string, round = 0): Notice {
  return {
    id: `moderation_${noticeKey(reportId)}_reporter${roundSuffix(round)}`,
    userId,
    title: round > 0 ? "Beslutet om din anmälan har ändrats" : "Din anmälan är avgjord",
    body: "Tryck för att läsa beslutet.",
    route: REPORTS_ROUTE,
    targetId: reportId,
    notificationType: "moderation_decision_reporter",
  };
}

export function ownerNotice(reportId: string, userId: string, round = 0): Notice {
  return {
    id: `moderation_${noticeKey(reportId)}_owner${roundSuffix(round)}`,
    userId,
    title: round > 0 ? "Ett beslut om ditt innehåll har ändrats" : "Det finns ett beslut om ditt innehåll",
    body: "Tryck för att läsa beslutet.",
    route: CONTENT_DECISIONS_ROUTE,
    targetId: reportId,
    notificationType: "moderation_decision_owner",
  };
}

export function appealAnsweredNotice(
  appealDocId: string,
  reportId: string,
  role: AppealRole,
  userId: string,
): Notice {
  return {
    id: `appeal_${noticeKey(appealDocId)}`,
    userId,
    title: "Din överklagan är besvarad",
    body: "Tryck för att läsa svaret.",
    route: routeForRole(role),
    targetId: reportId,
    notificationType: "moderation_appeal_answered",
  };
}

/**
 * Stages the inbox row. `set` rather than `create`: the id is predictable and
 * the history rules let a client create a row under its own uid, so a row
 * planted there first is overwritten instead of failing the transaction.
 */
export function stageNotice(
  db: admin.firestore.Firestore,
  tx: admin.firestore.Transaction,
  notice: Notice,
  sentAt: Date,
): void {
  tx.set(db.collection(NOTIFICATION_HISTORY).doc(notice.id), {
    userId: notice.userId,
    notificationId: notice.id,
    category: "system",
    type: "immediate",
    data: {
      title: notice.title,
      body: notice.body,
      route: notice.route,
      targetId: notice.targetId,
      notificationType: notice.notificationType,
    },
    sentAt: admin.firestore.Timestamp.fromDate(sentAt),
    delivered: false,
    opened: false,
    expireAt: admin.firestore.Timestamp.fromDate(
      new Date(sentAt.getTime() + NOTICE_RETENTION_DAYS * 24 * 60 * 60 * 1000),
    ),
  });
}

export interface PushDeps {
  /** `user_notification_preferences/{uid}.enabled`; null when unreadable or unset. */
  pushEnabled: (uid: string) => Promise<boolean | null>;
  send: typeof sendPushToUser;
}

export function defaultPushDeps(db: admin.firestore.Firestore): PushDeps {
  return {
    pushEnabled: async (uid) => {
      const snap = await db.collection("user_notification_preferences").doc(uid).get();
      const enabled = snap.get("enabled");
      return typeof enabled === "boolean" ? enabled : null;
    },
    send: sendPushToUser,
  };
}

/**
 * Sends the pushes for notices already committed. Best effort: a failure is
 * logged and swallowed, because rethrowing from a `retry: true` trigger would
 * redeliver an event whose rows are already written and push again.
 *
 * The master toggle is honoured; quiet hours and the daily cap are not, which
 * is how `preference-aware-push.ts` treats a critical send.
 */
export async function pushNotices(notices: Notice[], deps: PushDeps): Promise<void> {
  await Promise.all(
    notices.map(async (notice) => {
      try {
        if ((await deps.pushEnabled(notice.userId)) === false) return;
        await deps.send(
          notice.userId,
          { title: notice.title, body: notice.body },
          buildNotificationPayload({
            route: notice.route,
            targetId: notice.targetId,
            notificationType: notice.notificationType,
            additionalData: { notificationId: notice.id },
          }),
        );
      } catch (err) {
        logger.warn("moderation_notice_push_failed", {
          user_hash: hashUid(notice.userId),
          notificationType: notice.notificationType,
          errCode: (err as { code?: number | string }).code ?? null,
        });
      }
    }),
  );
}
