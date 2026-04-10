/**
 * Cloud Function triggered when a new feedback entry is created in Firestore.
 * Logs the feedback for monitoring and can be extended with email
 * notifications in the future.
 */

import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/logger";
import { hashUid } from "../shared/hash-uid";

export const onFeedbackCreated = onDocumentCreated(
  "feedback/{feedbackId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    const feedbackId = event.params.feedbackId;

    logger.info(
      `New feedback received [${feedbackId}]: ` +
      `category=${data.category}, userHash=${hashUid(data.userId || "unknown")}`
    );

    // Future enhancement: send email notification to the team
    // Future enhancement: post to Slack channel
  }
);
