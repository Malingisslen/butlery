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

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import * as crypto from "crypto";

/** Hash userId for GDPR-safe logging (dietary prefs = special category data). */
function hashUserId(uid: string): string {
  return crypto.createHash("sha256").update(uid).digest("hex").substring(0, 12);
}

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
export const onSuggestionCreated = functions.firestore
  .document("ingredientSuggestions/{suggestionId}")
  .onCreate(async (snapshot, context) => {
    const suggestionId = context.params.suggestionId;
    const suggestion = snapshot.data() as IngredientSuggestion;

    functions.logger.info(
      `📥 New ingredient suggestion received`,
      {
        suggestionId,
        userHash: hashUserId(suggestion.userId),
        suggestedCategory: suggestion.suggestedCategory,
      }
    );

    try {
      // Update document with notification metadata
      await getDb()
        .collection("ingredientSuggestions")
        .doc(suggestionId)
        .update({
          notifiedAt: admin.firestore.FieldValue.serverTimestamp(),
          sourceApp: "butlery-mobile",
        });

      // Log for monitoring dashboard
      functions.logger.info(
        `✅ Suggestion processed: ${suggestionId}`,
        {
          status: "notification_sent",
        }
      );

      // TODO: Add email notification to admin
      // await sendAdminNotification({
      //   subject: `Ny ingrediensförslag: ${suggestion.originalName}`,
      //   body: `Användare ${suggestion.userId} föreslår att lägga till "${suggestion.originalName}" i ingrediensdatabasen.`,
      // });

    } catch (error) {
      functions.logger.error(
        `❌ Failed to process suggestion: ${suggestionId}`,
        { error, suggestionId }
      );
      throw error;
    }
  });

/**
 * Trigger: When a suggestion status changes
 *
 * Path: ingredientSuggestions/{suggestionId}
 * Event: onUpdate
 *
 * Logs status changes for audit trail.
 */
export const onSuggestionStatusChanged = functions.firestore
  .document("ingredientSuggestions/{suggestionId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data() as IngredientSuggestion;
    const after = change.after.data() as IngredientSuggestion;
    const suggestionId = context.params.suggestionId;

    // Only track status changes
    if (before.status === after.status) {
      return;
    }

    functions.logger.info(
      `📋 Suggestion status changed: ${before.status} → ${after.status}`,
      {
        suggestionId,
        oldStatus: before.status,
        newStatus: after.status,
      }
    );

    // If approved, log for ingredient sync
    if (after.status === "approved") {
      functions.logger.info(
        `✅ Suggestion approved for addition`,
        {
          suggestionId,
          suggestedCategory: after.suggestedCategory,
        }
      );
    }
  });
