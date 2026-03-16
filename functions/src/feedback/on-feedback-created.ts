/**
 * Cloud Function triggered when a new feedback entry is created in Firestore.
 * Logs the feedback for monitoring and can be extended with email
 * notifications in the future.
 */

import * as functions from "firebase-functions";
import * as crypto from "crypto";

function hashUid(uid: string): string {
  return crypto.createHash("sha256").update(uid).digest("hex").substring(0, 12);
}

export const onFeedbackCreated = functions.firestore
  .document("feedback/{feedbackId}")
  .onCreate(async (snapshot, context) => {
    const data = snapshot.data();
    const feedbackId = context.params.feedbackId;

    functions.logger.info(
      `New feedback received [${feedbackId}]: ` +
      `category=${data.category}, userHash=${hashUid(data.userId || "unknown")}`
    );

    // Future enhancement: send email notification to the team
    // Future enhancement: post to Slack channel
  });
