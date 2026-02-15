/**
 * Cloud Function triggered when a new feedback entry is created in Firestore.
 * Logs the feedback for monitoring and can be extended with email
 * notifications in the future.
 */

import * as functions from "firebase-functions";

export const onFeedbackCreated = functions.firestore
  .document("feedback/{feedbackId}")
  .onCreate(async (snapshot, context) => {
    const data = snapshot.data();
    const feedbackId = context.params.feedbackId;

    functions.logger.info(
      `New feedback received [${feedbackId}]: ` +
      `category=${data.category}, userId=${data.userId}`
    );

    // Future enhancement: send email notification to the team
    // Future enhancement: post to Slack channel
  });
