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
import {
  validateOcrImageUrl,
  OcrUrlValidationResult,
  OcrUrlRejectionReason,
} from "../shared/ocr-url-validator";
import type { Part } from "@google-cloud/vertexai";
import {
  getGeminiClient,
  getTextModel,
  extractResponseText,
  parseRecipeResponse,
  calculateGeminiCost,
  ExtractedRecipe,
  IMAGE_OCR_SYSTEM_PROMPT,
  MODEL_ID,
} from "./gemini-client";
import { getPromptsConfig } from "./prompts-config";
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
   * BUT-785: pinned Vertex model id used for the OCR call. Threaded through
   * to clients so on-device analytics can correlate OCR quality / cost
   * regressions to model version rotations.
   */
  modelId?: string;
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
  /**
   * BUT-425: Test seam for the OCR URL validator (host allowlist + HEAD
   * pre-flight). Production resolves to `validateOcrImageUrl` from
   * `../shared/ocr-url-validator`.
   */
  validateImageUrl?: (
    url: string,
    authUidHash: string
  ) => Promise<OcrUrlValidationResult>;
  /** Test seam: clock. Default `Date.now`. */
  now?: () => number;
}

export interface OcrPerformArgs {
  imageBase64?: string;
  imageUrl?: string;
  mimeType?: string;
  context?: string;
  /**
   * BUT-621: vision system prompt to use. Threaded in by the caller so the
   * Firestore-backed prompts cache governs both branches uniformly.
   * Optional for backward compatibility with older test seams; defaults to
   * the compiled-in `IMAGE_OCR_SYSTEM_PROMPT` from `gemini-client.ts`.
   */
  systemPrompt?: string;
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
    systemInstruction: args.systemPrompt ?? IMAGE_OCR_SYSTEM_PROMPT,
  });

  const response = result.response;
  const content = extractResponseText(response) ?? "";
  const cost = calculateGeminiCost(response.usageMetadata, 0.01);

  // BUT-1032: implicit-cache observability for the vision call. Raw token
  // counts logged as-is — each may be undefined (absence ≠ zero). This file
  // has no `*.complete` timing log (unlike structure-recipe), so the usage
  // is logged here where the response is in scope; the OcrPerformResult test
  // seam intentionally stays `{content, cost}`.
  const usage = response.usageMetadata;
  logger.info("[ocrRecipeImage] Vision call usage", {
    promptTokenCount: usage?.promptTokenCount,
    candidatesTokenCount: usage?.candidatesTokenCount,
    cachedContentTokenCount: usage?.cachedContentTokenCount,
    modelId: MODEL_ID,
  });

  return { content, cost };
}

async function defaultIsAiDisabled(): Promise<boolean> {
  // BUT-439: master kill only. The per-feature `llmParserEnabled` flag is
  // checked inside `runStructureRecipe` (the OCR retry path passes
  // through it), so OCR vision can stay live even when the parser is
  // paused.
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
  const validateImageUrl = opts.validateImageUrl ?? validateOcrImageUrl;
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

  // BUT-425: Strict URL validation. The basic `isAllowedUrl` SSRF gate above
  // rejects obvious abuse (private IPs, non-HTTPS) but still allows ANY
  // public HTTPS host — including attacker-controlled domains. Gemini fetches
  // `fileData.fileUri` server-side from Google's network, so an unbounded URL
  // turns this function into an SSRF/exfiltration relay.
  //
  // The validator pins the host to *this* project's Firebase Storage bucket
  // and runs a HEAD pre-flight to verify content-type + content-length before
  // passing the URL to Gemini.
  if (imageUrl) {
    const validation = await validateImageUrl(imageUrl, authUidHash);
    if (!validation.ok) {
      // Surface as `invalid-argument` (not `internal`) — the request is
      // structurally rejected, no retry will help.
      throw new HttpsError(
        "invalid-argument",
        mapValidationReasonToSwedish(validation.reason)
      );
    }
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
        modelId: MODEL_ID,
      };
    }

    // BUT-621: prompts come from Firestore (5-min per-instance cache).
    // Falls back to compiled-in defaults on read failure.
    const prompts = await getPromptsConfig();
    const promptVersion = prompts.promptVersion;

    logger.info(
      `[ocrRecipeImage] Processing image for user ${authUidHash} (prompt v${promptVersion}, source=${prompts.source})`,
      { inputType: imageUrl ? "url" : "base64" }
    );

    const { content, cost: ocrCost } = await performOcr({
      imageBase64,
      imageUrl,
      mimeType,
      context,
      systemPrompt: prompts.imageOcrSystemPrompt,
    });

    if (!content) {
      logger.error("[ocrRecipeImage] Empty response from Gemini");
      return {
        success: false,
        error: "Inget svar från AI-tjänsten.",
        estimatedCost: ocrCost,
        promptVersion,
        retryCount: 0,
        retryOutcome: null,
        modelId: MODEL_ID,
      };
    }

    // Try to parse as structured recipe
    const recipe = parseRecipeResponse(content, promptVersion);
    if (recipe) {
      logger.info(
        `[ocrRecipeImage] Successfully extracted: "${recipe.title}" with ${recipe.ingredients.length} ingredients (cost: $${ocrCost.toFixed(6)})`
      );
      return {
        success: true,
        recipe,
        estimatedCost: ocrCost,
        promptVersion,
        retryCount: 0,
        retryOutcome: null,
        modelId: MODEL_ID,
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
        promptVersion: retryResult.promptVersion ?? promptVersion,
        retryCount: retryResult.retryCount,
        retryOutcome: retryResult.retryOutcome,
        modelId: MODEL_ID,
      };
    }

    // Retry didn't produce a recipe — return the rawText fallback (existing
    // behavior preserved) plus retry observability fields.
    return {
      success: false,
      rawText: content,
      error: "Kunde inte strukturera texten som ett recept.",
      estimatedCost: totalCost,
      promptVersion: retryResult.promptVersion ?? promptVersion,
      retryCount: retryResult.retryCount,
      retryOutcome: retryResult.retryOutcome,
      modelId: MODEL_ID,
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
 * Gemini uses inlineData for base64 images (legacy providers used image_url).
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
 * BUT-425: Convert a validator rejection reason into a Swedish-language
 * client-facing message. Kept terse — the structured `logger.warn` inside the
 * validator already captured the operator-facing detail (origin, status,
 * authUidHash). The client only needs to know the bucket of the failure so
 * the UI can prompt the user accordingly.
 */
function mapValidationReasonToSwedish(reason: OcrUrlRejectionReason): string {
  switch (reason) {
    case "malformed_url":
    case "disallowed_host":
      return "Ogiltig bild-URL.";
    case "head_request_failed":
      return "Bilden gick inte att nå. Kontrollera länken och försök igen.";
    case "missing_content_type":
    case "disallowed_content_type":
      return "Filtypen stöds inte. Använd JPEG, PNG, WebP, HEIC eller PDF.";
    case "missing_content_length":
    case "oversized":
      return "Bilden är för stor (max 10 MB).";
    default:
      return "Ogiltig bild-URL.";
  }
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
