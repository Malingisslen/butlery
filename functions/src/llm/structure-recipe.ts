/**
 * Cloud Function for structuring recipe text using Gemini LLM.
 *
 * This callable function takes raw text (from web scraping, OCR, etc.)
 * and returns a structured recipe object.
 */

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import {
  getGeminiClient,
  getTextModel,
  getIngredientLinesModel,
  extractResponseText,
  PROMPT_VERSION,
  RECIPE_EXTRACTION_SYSTEM_PROMPT,
  RECIPE_ENHANCEMENT_SYSTEM_PROMPT,
  SPOKEN_CONTENT_SYSTEM_PROMPT,
  INGREDIENT_LINE_SYSTEM_PROMPT,
  parseRecipeResponse,
  parseIngredientLinesResponse,
  calculateGeminiCost,
  ExtractedRecipe,
} from "./gemini-client";
import { withRateLimit } from "../middleware/rate_limiter";
import { scrubPii, scrubUrlParams } from "./pii-scrubber";
import { hashUid } from "../shared/hash-uid";

// =============================================================================
// Request/Response Types
// =============================================================================

interface StructureRecipeRequest {
  /** Raw text to extract recipe from */
  text: string;
  /** Optional partial data to enhance (for enhancement mode) */
  partialData?: Partial<ExtractedRecipe>;
  /** Extraction mode: 'extract' (default), 'enhance', 'spoken', or 'ingredientLines' */
  mode?: "extract" | "enhance" | "spoken" | "ingredientLines";
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
 * - ingredientLines: Parse individual ingredient lines
 */
export const structureRecipe = onCall<StructureRecipeRequest>(
  {
    // Vertex AI uses ADC (Cloud Functions service account) — no API key secret needed.
    memory: "512MiB",
    timeoutSeconds: 60,
    cors: ["https://butlery.app", "https://www.butlery.app"],
    enforceAppCheck: true,
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

      const client = getGeminiClient();
      const isIngredientLines = mode === "ingredientLines";

      // Get the appropriate model (with schema baked in)
      const model = isIngredientLines
        ? getIngredientLinesModel(client)
        : getTextModel(client);

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
        case "ingredientLines":
          systemPrompt = INGREDIENT_LINE_SYSTEM_PROMPT;
          userPrompt = buildIngredientLinesPrompt(cleanText);
          break;
        default:
          systemPrompt = RECIPE_EXTRACTION_SYSTEM_PROMPT;
          userPrompt = buildExtractionPrompt(cleanText, cleanSourceUrl);
      }

      logger.info(
        `[structureRecipe] Processing ${text.length} chars in ${mode} mode for user ${hashUid(request.auth!.uid)} (prompt v${PROMPT_VERSION})`
      );

      // Call Vertex AI Gemini (europe-west1, EU residency)
      const result = await model.generateContent({
        contents: [
          { role: "user", parts: [{ text: userPrompt }] },
        ],
        systemInstruction: systemPrompt,
      });

      const response = result.response;
      const content = extractResponseText(response);

      if (!content) {
        logger.error("[structureRecipe] Empty response from Gemini");
        return {
          success: false,
          error: "Inget svar från AI-tjänsten.",
          estimatedCost: 0.01,
        };
      }

      // Calculate actual cost from API usage
      const actualCost = calculateGeminiCost(response.usageMetadata);

      // Parse response — ingredient lines mode returns array, others return recipe
      if (isIngredientLines) {
        const ingredients = parseIngredientLinesResponse(content);
        if (!ingredients) {
          logger.error("[structureRecipe] Failed to parse ingredient lines:", content);
          return {
            success: false,
            error: "Kunde inte tolka AI-svaret som ingredienser.",
            estimatedCost: actualCost,
          };
        }

        logger.info(
          `[structureRecipe] Parsed ${ingredients.length} ingredient lines (cost: $${actualCost.toFixed(6)})`
        );

        // Wrap in minimal recipe so existing response type works
        return {
          success: true,
          recipe: {
            title: "_ingredientLines",
            description: null,
            portions: null,
            prepTimeMinutes: null,
            cookTimeMinutes: null,
            ingredients,
            instructions: [],
            tags: [],
            difficulty: null,
            source: null,
          },
          estimatedCost: actualCost,
          promptVersion: PROMPT_VERSION,
        };
      }

      const recipe = parseRecipeResponse(content);
      if (!recipe) {
        logger.error("[structureRecipe] Failed to parse response:", content);
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

      logger.info(
        `[structureRecipe] Successfully extracted: "${recipe.title}" with ${recipe.ingredients.length} ingredients (cost: $${actualCost.toFixed(6)})`
      );

      return {
        success: true,
        recipe,
        estimatedCost: actualCost,
        promptVersion: PROMPT_VERSION,
      };
    } catch (error) {
      logger.error("[structureRecipe] Error:", error);

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

function buildIngredientLinesPrompt(text: string): string {
  // Text is newline-separated ingredient lines from the Dart side
  const lines = text.split("\n").filter((l) => l.trim().length > 0);
  return `Extrahera ingrediensinformation från dessa ${lines.length} rader:\n${JSON.stringify(lines)}`;
}

function buildSpokenPrompt(transcript: string, sourceUrl?: string): string {
  let prompt = `Extrahera receptet från denna videotranskription:\n\n${transcript}`;
  if (sourceUrl) {
    prompt += `\n\nVideokälla: ${sourceUrl}`;
  }
  return prompt;
}

