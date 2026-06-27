/**
 * Cloud Function triggered when a new feedback entry is created in Firestore.
 * Logs the feedback for monitoring and emails the team so beta reports are
 * acted on instead of sitting unseen in Firestore.
 */

import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { defineSecret } from "firebase-functions/params";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { hashUid } from "../shared/hash-uid";

// Resend API key for transactional email. Set with:
//   firebase functions:secrets:set FEEDBACK_EMAIL_API_KEY
// Recipient / sender / dashboard link come from plain env vars (non-secret).
const feedbackEmailApiKey = defineSecret("FEEDBACK_EMAIL_API_KEY");

// BUT-760: feedback ingestion is a Firestore onDocumentCreated trigger, not a
// callable. App Check (`enforceAppCheck`) applies to onCall/onRequest only —
// it does not exist for background triggers. The user-facing write that fans
// out to this trigger goes through Firestore security rules + App Check on the
// client SDK call, not here. Intentionally no enforceAppCheck on this function.
export const onFeedbackCreated = onDocumentCreated(
  {
    document: "feedback/{feedbackId}",
    secrets: [feedbackEmailApiKey],
  },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    const feedbackId = event.params.feedbackId;

    logger.info(
      `New feedback received [${feedbackId}]: ` +
      `category=${data.category}, userHash=${hashUid(data.userId || "unknown")}`
    );

    await notifyByEmail(feedbackId, data);
  }
);

/**
 * Sends a triage email via Resend. Degrades to a log line (never throws) when
 * the API key or recipient isn't configured, so a missing secret can never
 * break feedback ingestion.
 */
async function notifyByEmail(
  feedbackId: string,
  data: FirebaseFirestore.DocumentData
): Promise<void> {
  const apiKey = feedbackEmailApiKey.value();
  const to = process.env.FEEDBACK_EMAIL_TO;
  const from = process.env.FEEDBACK_EMAIL_FROM;

  if (!apiKey || !to || !from) {
    logger.info(
      "Feedback email skipped: FEEDBACK_EMAIL_API_KEY / FEEDBACK_EMAIL_TO / " +
      "FEEDBACK_EMAIL_FROM not configured"
    );
    return;
  }

  const dashboardBase = process.env.FEEDBACK_DASHBOARD_URL;
  const dashboardLink = dashboardBase
    ? `<p><a href="${dashboardBase}">Öppna i admin-dashboarden</a></p>`
    : "";
  // screenshotUrl is user-controllable (Firestore create rules don't constrain
  // its shape), so only embed it when it's a real https URL — blocks a
  // malicious beta user from slipping a javascript:/data: link into our inbox.
  const safeScreenshotUrl =
    typeof data.screenshotUrl === "string" &&
    /^https:\/\//.test(data.screenshotUrl)
      ? data.screenshotUrl
      : null;
  const screenshot = safeScreenshotUrl
    ? `<p>Skärmdump: <a href="${safeScreenshotUrl}">` +
      `${escapeHtml(safeScreenshotUrl)}</a></p>`
    : "<p>(ingen skärmdump)</p>";

  const subject = `Butlery feedback: ${data.category ?? "okänd"}`;
  const html =
    `<h2>Ny feedback (${data.category ?? "okänd"})</h2>` +
    `<p>${escapeHtml(String(data.description ?? ""))}</p>` +
    `<p>E-post: ${escapeHtml(String(data.email ?? "—"))}</p>` +
    `<p>Enhet: ${escapeHtml(String(data.deviceInfo ?? "—"))}</p>` +
    screenshot +
    dashboardLink +
    `<p style="color:#999">id: ${feedbackId}</p>`;

  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ from, to, subject, html }),
    });
    if (!res.ok) {
      const detail = `Resend ${res.status} ${await res.text()}`;
      logger.error(`Feedback email failed: ${detail}`);
      await recordEmailFailure(feedbackId, detail);
      return;
    }
    logger.info(`Feedback email sent for [${feedbackId}]`);
  } catch (err) {
    // Never let a transport failure surface from a background trigger.
    const detail = String(err);
    logger.error(`Feedback email threw for [${feedbackId}]: ${detail}`);
    await recordEmailFailure(feedbackId, detail);
  }
}

/**
 * BUT-1406: a feedback-email delivery failure (Resend non-2xx or a transport
 * throw) is otherwise only a single logged error — invisible to Drift/ops_log
 * and below the GCP error-rate alert threshold, so a beta report can sit unseen
 * if email is misconfigured or Resend is down. Mirror onReportCreated: write a
 * durable `system_events` row with a deterministic id (set+merge → idempotent
 * if the trigger retries). The write is itself failure-safe so it can never
 * surface an error out of the background trigger. The intentional
 * "email not configured" skip above stays an info log — it's a deliberate
 * degradation, not a delivery failure, and a per-feedback event there would be
 * noise in dev/unconfigured environments.
 */
export async function recordEmailFailure(
  feedbackId: string,
  reason: string,
  db: admin.firestore.Firestore = admin.firestore()
): Promise<void> {
  try {
    await db
      .collection("system_events")
      .doc(`feedback_email_failed_${feedbackId}`)
      .set(
        {
          type: "feedback_email_failed",
          severity: "warning",
          feedbackId,
          reason,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
  } catch (e) {
    logger.error(
      `Failed to record feedback_email_failed for [${feedbackId}]: ${String(e)}`
    );
  }
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}
