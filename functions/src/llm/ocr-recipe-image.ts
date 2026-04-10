/**
 * Cloud Function for OCR and recipe extraction from images using Gemini Vision.
 *
 * This callable function takes an image (base64 or URL) and extracts
 * a structured recipe using Gemini's native multimodal capabilities.
 */

import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { hashUid } from "../shared/hash-uid";
import { isAllowedUrl } from "../shared/url-safety";
import {
  getGeminiClient,
  getTextModel,
  geminiApiKey,
  PROMPT_VERSION,
  IMAGE_OCR_SYSTEM_PROMPT,
  parseRecipeResponse,
  calculateGeminiCost,
  ExtractedRecipe,
} from "./gemini-client";
import { withRateLimit } from "../middleware/rate_limiter";
import { scrubPii } from "./pii-scrubber";

// =============================================================================
// Request/Response Types
// =============================================================================

interface OcrRecipeImageRequest {
  /** Base64-encoded image data */
  imageBase64?: string;
  /** Image URL (alternative to base64) */
  imageUrl?: string;
  /** MIME type of the image */
  mimeType?: string;
  /** Additional context (e.g., recipe title from filename) */
  context?: string;
}

interface OcrRecipeImageResponse {
  success: boolean;
  recipe?: ExtractedRecipe;
  /** Raw OCR text if extraction failed but text was readable */
  rawText?: string;
  error?: string;
  /** Estimated cost in USD */
  estimatedCost: number;
  /** Prompt version used for this extraction */
  promptVersion?: string;
}

// =============================================================================
// Callable Function
// =============================================================================

/**
 * Extract recipe from an image using vision AI.
 *
 * Supports:
 * - Photos of recipes (printed or handwritten)
 * - Screenshots of recipe websites
 * - Recipe cards and book pages
 */
export const ocrRecipeImage = onCall<OcrRecipeImageRequest>(
  {
    secrets: [geminiApiKey],
    memory: "1GiB", // Vision needs more memory
    timeoutSeconds: 120,
    cors: ["https://butlery.app", "https://www.butlery.app"],
    region: "europe-west1",
    enforceAppCheck: true,
  },
  withRateLimit("ocrRecipeImage", async (request): Promise<OcrRecipeImageResponse> => {
    // Authentication is handled by withRateLimit middleware
    const { imageBase64, imageUrl, mimeType, context } = request.data;

    // Validate input
    if (!imageBase64 && !imageUrl) {
      throw new HttpsError(
        "invalid-argument",
        "Antingen imageBase64 eller imageUrl krävs."
      );
    }

    // Validate URL if provided
    if (imageUrl && !isAllowedUrl(imageUrl)) {
      throw new HttpsError(
        "invalid-argument",
        "Ogiltig bild-URL."
      );
    }

    // Validate image size (base64 is ~33% larger than binary)
    if (imageBase64 && imageBase64.length > 10 * 1024 * 1024) {
      throw new HttpsError(
        "invalid-argument",
        "Bilden är för stor (max 7.5 MB)."
      );
    }

    try {
      // Check AI kill switch
      const configDoc = await admin.firestore().doc("system/config").get();
      if (configDoc.exists && configDoc.data()?.aiEnabled === false) {
        return {
          success: false,
          error: "AI-funktioner är tillfälligt avstängda.",
          estimatedCost: 0,
        };
      }

      const client = getGeminiClient(geminiApiKey.value());
      const model = getTextModel(client);

      functions.logger.info(
        `[ocrRecipeImage] Processing image for user ${hashUid(request.auth!.uid)} (prompt v${PROMPT_VERSION})`,
        { inputType: imageUrl ? "url" : "base64" }
      );

      // Build user prompt — scrub context text for PII
      let userPrompt =
        "Läs texten i denna bild och extrahera receptet. Svara med JSON.";
      if (context) {
        userPrompt += `\n\nKontext: ${scrubPii(context)}`;
      }

      // Build content parts for Gemini
      const parts = buildContentParts(imageBase64, imageUrl, mimeType, userPrompt);

      // Call Gemini Vision API
      const result = await model.generateContent({
        contents: [
          { role: "user", parts },
        ],
        systemInstruction: { role: "model", parts: [{ text: IMAGE_OCR_SYSTEM_PROMPT }] },
      });

      const response = result.response;
      const content = response.text();

      // Calculate actual cost from API usage (higher min floor for vision)
      const actualCost = calculateGeminiCost(response.usageMetadata, 0.01);

      if (!content) {
        functions.logger.error("[ocrRecipeImage] Empty response from Gemini");
        return {
          success: false,
          error: "Inget svar från AI-tjänsten.",
          estimatedCost: actualCost,
        };
      }

      // Try to parse as structured recipe
      const recipe = parseRecipeResponse(content);
      if (recipe) {
        functions.logger.info(
          `[ocrRecipeImage] Successfully extracted: "${recipe.title}" with ${recipe.ingredients.length} ingredients (cost: $${actualCost.toFixed(6)})`
        );
        return {
          success: true,
          recipe,
          estimatedCost: actualCost,
          promptVersion: PROMPT_VERSION,
        };
      }

      // If parsing failed, the model might have returned raw text
      functions.logger.warn(
        "[ocrRecipeImage] Could not parse as recipe, returning raw text"
      );
      return {
        success: false,
        rawText: content,
        error: "Kunde inte strukturera texten som ett recept.",
        estimatedCost: actualCost,
      };
    } catch (error) {
      functions.logger.error("[ocrRecipeImage] Error:", error);

      if (error instanceof HttpsError) {
        throw error;
      }

      // Check for rate limiting
      if (error instanceof Error && error.message.includes("rate limit")) {
        throw new HttpsError(
          "resource-exhausted",
          "AI-tjänsten är tillfälligt överbelastad. Försök igen om en stund."
        );
      }

      throw new HttpsError(
        "internal",
        "Ett fel uppstod vid bildbearbetning. Försök igen."
      );
    }
  })
);

// =============================================================================
// Helper Functions
// =============================================================================

interface TextPart {
  text: string;
}

interface InlineDataPart {
  inlineData: {
    mimeType: string;
    data: string;
  };
}

interface FileDataPart {
  fileData: {
    mimeType: string;
    fileUri: string;
  };
}

type ContentPart = TextPart | InlineDataPart | FileDataPart;

/**
 * Build content parts array for Gemini multimodal input.
 * Gemini uses inlineData for base64 images (not image_url like Mistral).
 */
function buildContentParts(
  base64?: string,
  url?: string,
  mimeType?: string,
  textPrompt?: string
): ContentPart[] {
  const parts: ContentPart[] = [];

  if (base64) {
    // Strip data URL prefix if present
    let rawBase64 = base64;
    if (rawBase64.startsWith("data:")) {
      const commaIndex = rawBase64.indexOf(",");
      if (commaIndex > 0) {
        rawBase64 = rawBase64.substring(commaIndex + 1);
      }
    }

    const mime = mimeType || detectMimeType(rawBase64);
    parts.push({
      inlineData: {
        mimeType: mime,
        data: rawBase64,
      },
    });
  } else if (url) {
    // For URL images, Gemini supports fileData with URI
    // However, for HTTPS URLs we use inlineData after fetching
    // For simplicity, pass as fileData — Gemini handles HTTPS URLs
    parts.push({
      fileData: {
        mimeType: mimeType || "image/jpeg",
        fileUri: url,
      },
    });
  }

  if (textPrompt) {
    parts.push({ text: textPrompt });
  }

  return parts;
}

/**
 * Detect MIME type from base64 header or default to JPEG.
 */
function detectMimeType(base64: string): string {
  if (base64.startsWith("/9j/")) return "image/jpeg";
  if (base64.startsWith("iVBORw")) return "image/png";
  if (base64.startsWith("R0lGOD")) return "image/gif";
  if (base64.startsWith("UklGR")) return "image/webp";
  return "image/jpeg"; // Default
}
