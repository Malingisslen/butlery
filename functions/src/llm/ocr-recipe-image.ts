/**
 * Cloud Function for OCR and recipe extraction from images using Gemini Vision.
 *
 * This callable function takes an image (base64 or URL) and extracts
 * a structured recipe using Gemini's native multimodal capabilities.
 */

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import { hashUid } from "../shared/hash-uid";
import { isAllowedUrl } from "../shared/url-safety";
import type { Part } from "@google-cloud/vertexai";
import {
  getGeminiClient,
  getTextModel,
  extractResponseText,
  PROMPT_VERSION,
  IMAGE_OCR_SYSTEM_PROMPT,
  parseRecipeResponse,
  calculateGeminiCost,
  ExtractedRecipe,
} from "./gemini-client";
import { withRateLimit } from "../middleware/rate_limiter";
import { scrubPii } from "./pii-scrubber";
import { runStructureRecipe } from "./structure-recipe";
import {
  runOcrRetry,
  RetryOutcome,
} from "./ocr-retry";

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
  /** Estimated cost in USD (sum of OCR + retry, if any) */
  estimatedCost: number;
  /** Prompt version used for this extraction */
  promptVersion?: string;
  /**
   * BUT-559: how many times we retried via `structureRecipe` after the
   * initial image-mode parse failed. 0 = no retry (image parse succeeded
   * or budget/text guard skipped it). 1 = retry attempted (success or
   * failure).
   */
  retryCount: number;
  /**
   * BUT-559: classifier for observability. `null` when the original parse
   * succeeded (no retry needed).
   */
  retryOutcome: RetryOutcome;
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
    // Vertex AI uses ADC (Cloud Functions service account) — no API key secret needed.
    memory: "1GiB", // Vision needs more memory
    timeoutSeconds: 120,
    cors: ["https://butlery.app", "https://www.butlery.app"],
    enforceAppCheck: true,
  },
  withRateLimit("ocrRecipeImage", async (request): Promise<OcrRecipeImageResponse> => {
    // Authentication is handled by withRateLimit middleware
    return runOcrRecipeImage({
      data: request.data,
      authUidHash: hashUid(request.auth!.uid),
    });
  })
);

// =============================================================================
// Test-seamable core
// =============================================================================

export interface OcrCoreOptions {
  data: OcrRecipeImageRequest;
  /** Pre-hashed uid for logging — caller computes from request.auth. */
  authUidHash: string;
  /**
   * Test seam: structureRecipe retry. Production resolves to the imported
   * `runStructureRecipe` from `./structure-recipe`.
   */
  structureRecipe?: typeof runStructureRecipe;
  /** Test seam: image OCR call. Returns the raw `{content, cost}` pair. */
  performOcr?: (
    args: OcrPerformArgs
  ) => Promise<OcrPerformResult>;
  /** Test seam: AI kill-switch lookup. Default reads `system/config`. */
  isAiDisabled?: () => Promise<boolean>;
  /** Test seam: clock. Default `Date.now`. */
  now?: () => number;
}

export interface OcrPerformArgs {
  imageBase64?: string;
  imageUrl?: string;
  mimeType?: string;
  context?: string;
}

export interface OcrPerformResult {
  /** Raw text response from the vision model (may be JSON or free text). */
  content: string;
  /** Cost in USD billed by the OCR call. */
  cost: number;
}

async function defaultPerformOcr(
  args: OcrPerformArgs
): Promise<OcrPerformResult> {
  const client = getGeminiClient();
  const model = getTextModel(client);

  // Build user prompt — scrub context text for PII
  let userPrompt =
    "Läs texten i denna bild och extrahera receptet. Svara med JSON.";
  if (args.context) {
    userPrompt += `\n\nKontext: ${scrubPii(args.context)}`;
  }

  const parts = buildContentParts(
    args.imageBase64,
    args.imageUrl,
    args.mimeType,
    userPrompt
  );

  const result = await model.generateContent({
    contents: [{ role: "user", parts }],
    systemInstruction: IMAGE_OCR_SYSTEM_PROMPT,
  });

  const response = result.response;
  const content = extractResponseText(response) ?? "";
  const cost = calculateGeminiCost(response.usageMetadata, 0.01);
  return { content, cost };
}

async function defaultIsAiDisabled(): Promise<boolean> {
  const configDoc = await admin.firestore().doc("system/config").get();
  return configDoc.exists && configDoc.data()?.aiEnabled === false;
}

/**
 * Server-callable core. Exposed for unit testing — the callable wrapper
 * above and any in-process caller can both target this function with
 * dependency-injected test seams.
 *
 * BUT-559: on parse failure with non-empty `rawText`, automatically retries
 * via `structureRecipe` (budget permitting) and returns the structured
 * result. New `retryCount` / `retryOutcome` fields are added for
 * observability; existing fields are preserved.
 */
export async function runOcrRecipeImage(
  opts: OcrCoreOptions
): Promise<OcrRecipeImageResponse> {
  const { data, authUidHash } = opts;
  const { imageBase64, imageUrl, mimeType, context } = data;
  const performOcr = opts.performOcr ?? defaultPerformOcr;
  const isAiDisabled = opts.isAiDisabled ?? defaultIsAiDisabled;
  const structureRecipe = opts.structureRecipe ?? runStructureRecipe;
  const now = opts.now ?? Date.now;

  const ocrStartMs = now();

  // Validate input
  if (!imageBase64 && !imageUrl) {
    throw new HttpsError(
      "invalid-argument",
      "Antingen imageBase64 eller imageUrl krävs."
    );
  }

  // Validate URL if provided
  if (imageUrl && !isAllowedUrl(imageUrl)) {
    throw new HttpsError("invalid-argument", "Ogiltig bild-URL.");
  }

  // Validate image size (base64 is ~33% larger than binary)
  if (imageBase64 && imageBase64.length > 10 * 1024 * 1024) {
    throw new HttpsError(
      "invalid-argument",
      "Bilden är för stor (max 7.5 MB)."
    );
  }

  try {
    // AI kill switch
    if (await isAiDisabled()) {
      return {
        success: false,
        error: "AI-funktioner är tillfälligt avstängda.",
        estimatedCost: 0,
        retryCount: 0,
        retryOutcome: null,
      };
    }

    logger.info(
      `[ocrRecipeImage] Processing image for user ${authUidHash} (prompt v${PROMPT_VERSION})`,
      { inputType: imageUrl ? "url" : "base64" }
    );

    const { content, cost: ocrCost } = await performOcr({
      imageBase64,
      imageUrl,
      mimeType,
      context,
    });

    if (!content) {
      logger.error("[ocrRecipeImage] Empty response from Gemini");
      return {
        success: false,
        error: "Inget svar från AI-tjänsten.",
        estimatedCost: ocrCost,
        retryCount: 0,
        retryOutcome: null,
      };
    }

    // Try to parse as structured recipe
    const recipe = parseRecipeResponse(content);
    if (recipe) {
      logger.info(
        `[ocrRecipeImage] Successfully extracted: "${recipe.title}" with ${recipe.ingredients.length} ingredients (cost: $${ocrCost.toFixed(6)})`
      );
      return {
        success: true,
        recipe,
        estimatedCost: ocrCost,
        promptVersion: PROMPT_VERSION,
        retryCount: 0,
        retryOutcome: null,
      };
    }

    // Parse failed. Try the structureRecipe retry path (BUT-559).
    logger.warn(
      "[ocrRecipeImage] Image-mode parse failed, attempting structureRecipe retry"
    );

    const retryResult = await runOcrRetry(content, ocrStartMs, authUidHash, {
      structureRecipe,
      now,
    });

    const totalCost = ocrCost + retryResult.additionalCost;
    const elapsedMsTotal = now() - ocrStartMs;

    // Structured observability log — answers "what % of OCR retries
    // succeeded?" once aggregated.
    logger.info("[ocrRecipeImage] Retry outcome", {
      retryCount: retryResult.retryCount,
      retryOutcome: retryResult.retryOutcome,
      elapsed_ms_total: elapsedMsTotal,
      raw_text_length: content.length,
    });

    if (retryResult.recipe) {
      return {
        success: true,
        recipe: retryResult.recipe,
        rawText: content,
        estimatedCost: totalCost,
        promptVersion: retryResult.promptVersion ?? PROMPT_VERSION,
        retryCount: retryResult.retryCount,
        retryOutcome: retryResult.retryOutcome,
      };
    }

    // Retry didn't produce a recipe — return the rawText fallback (existing
    // behavior preserved) plus retry observability fields.
    return {
      success: false,
      rawText: content,
      error: "Kunde inte strukturera texten som ett recept.",
      estimatedCost: totalCost,
      retryCount: retryResult.retryCount,
      retryOutcome: retryResult.retryOutcome,
    };
  } catch (error) {
    logger.error("[ocrRecipeImage] Error:", error);

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
}

// =============================================================================
// Helper Functions
// =============================================================================

/**
 * Build content parts array for Gemini multimodal input.
 * Gemini uses inlineData for base64 images (not image_url like Mistral).
 */
function buildContentParts(
  base64?: string,
  url?: string,
  mimeType?: string,
  textPrompt?: string
): Part[] {
  const parts: Part[] = [];

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
