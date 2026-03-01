/**
 * Cloud Function for OCR and recipe extraction from images using Mistral Pixtral.
 *
 * This callable function takes an image (base64 or URL) and extracts
 * a structured recipe using vision capabilities.
 */

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import {
  getMistralClient,
  mistralApiKey,
  PROMPT_VERSION,
  IMAGE_OCR_SYSTEM_PROMPT,
  VISION_MODEL,
  MAX_TOKENS,
  TEMPERATURE,
  parseRecipeResponse,
  ExtractedRecipe,
} from "./mistral-client";
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
    secrets: [mistralApiKey],
    memory: "1GiB", // Vision needs more memory
    timeoutSeconds: 120,
    cors: true,
    region: "europe-west1",
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

      const client = getMistralClient(mistralApiKey.value());

      console.log(
        `[ocrRecipeImage] Processing image for user ${request.auth!.uid} (prompt v${PROMPT_VERSION})`,
        imageUrl ? `URL: ${imageUrl}` : `Base64: ${imageBase64?.length} chars`
      );

      // Build image content for Mistral vision
      const imageContent = buildImageContent(imageBase64, imageUrl, mimeType);

      // Build user prompt — scrub context text for PII
      let userPrompt =
        "Läs texten i denna bild och extrahera receptet. Svara med JSON.";
      if (context) {
        userPrompt += `\n\nKontext: ${scrubPii(context)}`;
      }

      // Call Mistral Vision API
      const response = await client.chat.complete({
        model: VISION_MODEL,
        messages: [
          { role: "system", content: IMAGE_OCR_SYSTEM_PROMPT },
          {
            role: "user",
            content: [
              imageContent,
              { type: "text", text: userPrompt },
            ],
          },
        ],
        maxTokens: MAX_TOKENS,
        temperature: TEMPERATURE,
      });

      const content = response.choices?.[0]?.message?.content;

      // Calculate actual cost from API usage
      // Pixtral: $0.15/1M input tokens, $0.15/1M output tokens
      const usage = response.usage as { promptTokens?: number; completionTokens?: number } | undefined;
      const inputCost = ((usage?.promptTokens ?? 0) / 1_000_000) * 0.15;
      const outputCost = ((usage?.completionTokens ?? 0) / 1_000_000) * 0.15;
      const actualCost = Math.max(inputCost + outputCost, 0.01);

      if (!content || typeof content !== "string") {
        console.error("[ocrRecipeImage] Empty response from Mistral");
        return {
          success: false,
          error: "Inget svar från AI-tjänsten.",
          estimatedCost: actualCost,
        };
      }

      // Try to parse as structured recipe
      const recipe = parseRecipeResponse(content);
      if (recipe) {
        console.log(
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
      console.warn(
        "[ocrRecipeImage] Could not parse as recipe, returning raw text"
      );
      return {
        success: false,
        rawText: content,
        error: "Kunde inte strukturera texten som ett recept.",
        estimatedCost: actualCost,
      };
    } catch (error) {
      console.error("[ocrRecipeImage] Error:", error);

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

interface ImageContent {
  type: "image_url";
  imageUrl: string | { url: string };
}

/**
 * Validate that a URL is safe to pass to an external AI service.
 * Rejects private IPs, localhost, and non-HTTPS protocols to prevent SSRF.
 */
function isAllowedUrl(url: string): boolean {
  try {
    const parsed = new URL(url);

    // Only allow HTTPS
    if (parsed.protocol !== "https:") return false;

    const hostname = parsed.hostname.toLowerCase();

    // Block localhost and loopback
    if (
      hostname === "localhost" ||
      hostname === "127.0.0.1" ||
      hostname === "[::1]" ||
      hostname === "0.0.0.0"
    ) {
      return false;
    }

    // Block private IP ranges
    const parts = hostname.split(".");
    if (parts.length === 4 && parts.every((p) => /^\d+$/.test(p))) {
      const first = parseInt(parts[0]);
      const second = parseInt(parts[1]);
      if (first === 10) return false; // 10.0.0.0/8
      if (first === 172 && second >= 16 && second <= 31) return false; // 172.16.0.0/12
      if (first === 192 && second === 168) return false; // 192.168.0.0/16
      if (first === 169 && second === 254) return false; // link-local
    }

    return true;
  } catch {
    return false;
  }
}

function buildImageContent(
  base64?: string,
  url?: string,
  mimeType?: string
): ImageContent {
  if (url) {
    return {
      type: "image_url",
      imageUrl: url,
    };
  }

  if (base64) {
    // Determine MIME type
    const mime = mimeType || detectMimeType(base64);
    const dataUrl = base64.startsWith("data:")
      ? base64
      : `data:${mime};base64,${base64}`;

    return {
      type: "image_url",
      imageUrl: dataUrl,
    };
  }

  throw new Error("No image data provided");
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
