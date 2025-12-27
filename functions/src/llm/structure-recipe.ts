/**
 * Cloud Function for structuring recipe text using Mistral LLM.
 *
 * This callable function takes raw text (from web scraping, OCR, etc.)
 * and returns a structured recipe object.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import {
  getMistralClient,
  mistralApiKey,
  RECIPE_EXTRACTION_SYSTEM_PROMPT,
  RECIPE_ENHANCEMENT_SYSTEM_PROMPT,
  SPOKEN_CONTENT_SYSTEM_PROMPT,
  TEXT_MODEL,
  MAX_TOKENS,
  TEMPERATURE,
  parseRecipeResponse,
  ExtractedRecipe,
} from "./mistral-client";
import { withRateLimit } from "../middleware/rate_limiter";

// =============================================================================
// Request/Response Types
// =============================================================================

interface StructureRecipeRequest {
  /** Raw text to extract recipe from */
  text: string;
  /** Optional partial data to enhance (for enhancement mode) */
  partialData?: Partial<ExtractedRecipe>;
  /** Extraction mode: 'extract' (default), 'enhance', or 'spoken' */
  mode?: "extract" | "enhance" | "spoken";
  /** Source URL for reference */
  sourceUrl?: string;
}

interface StructureRecipeResponse {
  success: boolean;
  recipe?: ExtractedRecipe;
  error?: string;
  /** Estimated cost in USD */
  estimatedCost: number;
}

// =============================================================================
// Callable Function
// =============================================================================

/**
 * Structure recipe text into a standardized recipe object.
 *
 * Usage modes:
 * - extract: Full extraction from raw text (default)
 * - enhance: Improve partial extraction with original text
 * - spoken: Extract from video transcript (YouTube, TikTok)
 */
export const structureRecipe = onCall<StructureRecipeRequest>(
  {
    secrets: [mistralApiKey],
    memory: "512MiB",
    timeoutSeconds: 60,
    cors: true,
    region: "europe-west1",
  },
  withRateLimit("structureRecipe", async (request): Promise<StructureRecipeResponse> => {
    // Authentication is handled by withRateLimit middleware
    const { text, partialData, mode = "extract", sourceUrl } = request.data;

    // Validate input
    if (!text || typeof text !== "string") {
      throw new HttpsError("invalid-argument", "Text krävs för extraktion.");
    }

    if (text.length > 50000) {
      throw new HttpsError(
        "invalid-argument",
        "Texten är för lång (max 50000 tecken)."
      );
    }

    if (text.length < 20) {
      throw new HttpsError(
        "invalid-argument",
        "Texten är för kort för att innehålla ett recept."
      );
    }

    try {
      const client = getMistralClient(mistralApiKey.value());

      // Select system prompt based on mode
      let systemPrompt: string;
      let userPrompt: string;

      switch (mode) {
        case "enhance":
          systemPrompt = RECIPE_ENHANCEMENT_SYSTEM_PROMPT;
          userPrompt = buildEnhancementPrompt(text, partialData, sourceUrl);
          break;
        case "spoken":
          systemPrompt = SPOKEN_CONTENT_SYSTEM_PROMPT;
          userPrompt = buildSpokenPrompt(text, sourceUrl);
          break;
        default:
          systemPrompt = RECIPE_EXTRACTION_SYSTEM_PROMPT;
          userPrompt = buildExtractionPrompt(text, sourceUrl);
      }

      console.log(
        `[structureRecipe] Processing ${text.length} chars in ${mode} mode for user ${request.auth!.uid}`
      );

      // Call Mistral API
      const response = await client.chat.complete({
        model: TEXT_MODEL,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt },
        ],
        maxTokens: MAX_TOKENS,
        temperature: TEMPERATURE,
        responseFormat: { type: "json_object" },
      });

      const content = response.choices?.[0]?.message?.content;
      if (!content || typeof content !== "string") {
        console.error("[structureRecipe] Empty response from Mistral");
        return {
          success: false,
          error: "Inget svar från AI-tjänsten.",
          estimatedCost: 0.01,
        };
      }

      // Parse response
      const recipe = parseRecipeResponse(content);
      if (!recipe) {
        console.error("[structureRecipe] Failed to parse response:", content);
        return {
          success: false,
          error: "Kunde inte tolka AI-svaret som ett recept.",
          estimatedCost: 0.01,
        };
      }

      // Add source if provided
      if (sourceUrl && !recipe.source) {
        recipe.source = sourceUrl;
      }

      console.log(
        `[structureRecipe] Successfully extracted: "${recipe.title}" with ${recipe.ingredients.length} ingredients`
      );

      return {
        success: true,
        recipe,
        estimatedCost: estimateCost(text.length, mode),
      };
    } catch (error) {
      console.error("[structureRecipe] Error:", error);

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
        "Ett fel uppstod vid AI-bearbetning. Försök igen."
      );
    }
  })
);

// =============================================================================
// Helper Functions
// =============================================================================

function buildExtractionPrompt(text: string, sourceUrl?: string): string {
  let prompt = `Extrahera receptet från följande text:\n\n${text}`;
  if (sourceUrl) {
    prompt += `\n\nKälla: ${sourceUrl}`;
  }
  return prompt;
}

function buildEnhancementPrompt(
  text: string,
  partialData?: Partial<ExtractedRecipe>,
  sourceUrl?: string
): string {
  let prompt = "Förbättra och komplettera detta delvis extraherade recept.\n\n";

  if (partialData) {
    prompt += `Delvis extraherad data:\n${JSON.stringify(partialData, null, 2)}\n\n`;
  }

  prompt += `Originaltext:\n${text}`;

  if (sourceUrl) {
    prompt += `\n\nKälla: ${sourceUrl}`;
  }

  return prompt;
}

function buildSpokenPrompt(transcript: string, sourceUrl?: string): string {
  let prompt = `Extrahera receptet från denna videotranskription:\n\n${transcript}`;
  if (sourceUrl) {
    prompt += `\n\nVideokälla: ${sourceUrl}`;
  }
  return prompt;
}

/**
 * Estimate cost based on input length and mode.
 * Mistral Small: ~$0.2/1M input tokens, ~$0.6/1M output tokens
 */
function estimateCost(textLength: number, mode: string): number {
  // Rough estimation: 4 chars per token
  const inputTokens = textLength / 4;
  const outputTokens = 500; // Typical recipe response

  const inputCost = (inputTokens / 1000000) * 0.2;
  const outputCost = (outputTokens / 1000000) * 0.6;

  // Enhancement mode typically has more context
  const multiplier = mode === "enhance" ? 1.5 : 1.0;

  return Math.round((inputCost + outputCost) * multiplier * 1000) / 1000;
}
