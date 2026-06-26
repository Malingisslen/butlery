/**
 * Cloud Function to notify admins when new ingredient suggestions are submitted.
 *
 * When a user suggests an unknown ingredient:
 * 1. Logs the suggestion for monitoring
 * 2. Updates suggestion with metadata
 * 3. (Future) Sends email notification to admin
 *
 * This enables crowdsourced improvement of the ingredient database.
 */

import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { hashUid } from "../shared/hash-uid";

// Lazy initialization to avoid calling firestore() before initializeApp()
const getDb = () => admin.firestore();

/**
 * Interface for ingredient suggestion documents.
 */
interface IngredientSuggestion {
  userId: string;
  ingredientName: string;
  originalName: string;
  suggestedCategory?: string;
  suggestedProperties?: string[];
  recipeContext?: string;
  status: "pending" | "approved" | "rejected" | "cancelled";
  createdAt: admin.firestore.Timestamp;
  reviewedAt?: admin.firestore.Timestamp;
  reviewedBy?: string;
  reviewNotes?: string;
  // Metadata added by this function
  notifiedAt?: admin.firestore.Timestamp;
  sourceApp?: string;
}

/**
 * Trigger: When a new ingredient suggestion is created
 *
 * Path: ingredientSuggestions/{suggestionId}
 * Event: onCreate
 */
export const onSuggestionCreated = onDocumentCreated(
  "ingredient_suggestions/{suggestionId}",
  async (event) => {
    const suggestionId = event.params.suggestionId;
    const suggestion = event.data?.data() as IngredientSuggestion | undefined;
    if (!suggestion) return;

    logger.info(
      `📥 New ingredient suggestion received`,
      {
        suggestionId,
        userHash: hashUid(suggestion.userId),
        suggestedCategory: suggestion.suggestedCategory,
      }
    );

    try {
      // Idempotency: onDocumentCreated is at-least-once, and `suggestion`
      // here is the creation-time snapshot — on a retry its `notifiedAt` is
      // still undefined, so the old snapshot-based guard never fired. Claim
      // the suggestion transactionally instead, using the doc's own
      // `notifiedAt` as the marker (mirrors onReportCreated's marker claim).
      // If a future real email send is wired in, a retried delivery will
      // skip here rather than send a duplicate moderator email.
      const docRef = getDb()
        .collection("ingredient_suggestions")
        .doc(suggestionId);

      const claimed = await getDb().runTransaction(async (tx) => {
        const snap = await tx.get(docRef);
        const current = snap.data() as IngredientSuggestion | undefined;
        if (!current || current.notifiedAt) {
          return false;
        }
        tx.update(docRef, {
          notifiedAt: admin.firestore.FieldValue.serverTimestamp(),
          sourceApp: "butlery-mobile",
        });
        return true;
      });

      if (!claimed) {
        logger.info(`Suggestion ${suggestionId} already processed, skipping`);
        return;
      }

      // Log for monitoring dashboard
      logger.info(
        `✅ Suggestion processed: ${suggestionId}`,
        {
          status: "notification_sent",
        }
      );

      // Admin notification — stubbed until email infra lands (BUT-417),
      // mirroring onReportCreated. We log a structured payload so it's
      // alertable in Cloud Logging today and trivial to swap for a real send
      // later. UID is hashed (never log a raw uid — see hash-uid).
      const adminEmail = process.env.MODERATOR_EMAIL;
      if (adminEmail) {
        // Log only stable ids (never the free-text originalName — it's
        // user-submitted and could carry PII). The admin looks up the
        // suggested name in the doc by suggestionId.
        logger.info(
          `[ingredient-suggestion-email:TODO] would dispatch to ${adminEmail} ` +
            `— suggestion=${suggestionId} userHash=${hashUid(suggestion.userId)}`,
        );
      } else {
        logger.warn(
          `[ingredient-suggestion-email] MODERATOR_EMAIL not set; skipping ` +
            `admin notification for suggestion ${suggestionId}`,
        );
      }

    } catch (error) {
      logger.error(
        `❌ Failed to process suggestion: ${suggestionId}`,
        { error, suggestionId }
      );
      throw error;
    }
  }
);

/**
 * Trigger: When a suggestion status changes
 *
 * Path: ingredientSuggestions/{suggestionId}
 * Event: onUpdate
 *
 * Logs status changes for audit trail.
 */
export const onSuggestionStatusChanged = onDocumentUpdated(
  "ingredient_suggestions/{suggestionId}",
  async (event) => {
    const before = event.data!.before.data() as IngredientSuggestion;
    const after = event.data!.after.data() as IngredientSuggestion;
    const suggestionId = event.params.suggestionId;

    // Only track status changes
    if (before.status === after.status) {
      return;
    }

    logger.info(
      `📋 Suggestion status changed: ${before.status} → ${after.status}`,
      {
        suggestionId,
        oldStatus: before.status,
        newStatus: after.status,
      }
    );

    // If approved, log for ingredient sync
    if (after.status === "approved") {
      logger.info(
        `✅ Suggestion approved for addition`,
        {
          suggestionId,
          suggestedCategory: after.suggestedCategory,
        }
      );
    }
  }
);
