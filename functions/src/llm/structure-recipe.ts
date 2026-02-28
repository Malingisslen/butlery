/**
 * Cloud Function for structuring recipe text using Mistral LLM.
 *
 * This callable function takes raw text (from web scraping, OCR, etc.)
 * and returns a structured recipe object.
 */

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import {
  getMistralClient,
  mistralApiKey,
  PROMPT_VERSION,
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
import { scrubPii, scrubUrlParams } from "./pii-scrubber";

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
  /** Prompt version used for this extraction */
  promptVersion?: string;
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

      // Scrub PII before sending to LLM
      const cleanText = scrubPii(text);
      const cleanSourceUrl = sourceUrl ? scrubUrlParams(sourceUrl) : undefined;

      // Select system prompt based on mode
      let systemPrompt: string;
      let userPrompt: string;

      switch (mode) {
        case "enhance":
          systemPrompt = RECIPE_ENHANCEMENT_SYSTEM_PROMPT;
          userPrompt = buildEnhancementPrompt(cleanText, partialData, cleanSourceUrl);
          break;
        case "spoken":
          systemPrompt = SPOKEN_CONTENT_SYSTEM_PROMPT;
          userPrompt = buildSpokenPrompt(cleanText, cleanSourceUrl);
          break;
        default:
          systemPrompt = RECIPE_EXTRACTION_SYSTEM_PROMPT;
          userPrompt = buildExtractionPrompt(cleanText, cleanSourceUrl);
      }

      console.log(
        `[structureRecipe] Processing ${text.length} chars in ${mode} mode for user ${request.auth!.uid} (prompt v${PROMPT_VERSION})`
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

      // Calculate actual cost from API usage
      const actualCost = calculateTextCost(response.usage);

      // Parse response
      const recipe = parseRecipeResponse(content);
      if (!recipe) {
        console.error("[structureRecipe] Failed to parse response:", content);
        return {
          success: false,
          error: "Kunde inte tolka AI-svaret som ett recept.",
          estimatedCost: actualCost,
        };
      }

      // Add source if provided
      if (cleanSourceUrl && !recipe.source) {
        recipe.source = cleanSourceUrl;
      }

      console.log(
        `[structureRecipe] Successfully extracted: "${recipe.title}" with ${recipe.ingredients.length} ingredients (cost: $${actualCost.toFixed(6)})`
      );

      return {
        success: true,
        recipe,
        estimatedCost: actualCost,
        promptVersion: PROMPT_VERSION,
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
 * Calculate actual cost from Mistral API usage data.
 * Mistral Small: $0.1/1M input tokens, $0.3/1M output tokens
 */
function calculateTextCost(usage: { promptTokens?: number; completionTokens?: number } | undefined): number {
  if (!usage) {
    return 0.01; // Fallback estimate
  }

  const inputCost = ((usage.promptTokens ?? 0) / 1_000_000) * 0.1;
  const outputCost = ((usage.completionTokens ?? 0) / 1_000_000) * 0.3;

  return Math.max(inputCost + outputCost, 0.001); // Minimum cost floor
}
