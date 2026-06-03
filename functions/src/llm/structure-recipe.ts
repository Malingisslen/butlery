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
  parseRecipeResponse,
  parseIngredientLinesResponse,
  calculateGeminiCost,
  stripCodeFences,
  ExtractedRecipe,
  MODEL_ID,
} from "./gemini-client";
import { getPromptsConfig } from "./prompts-config";
import { withRateLimit } from "../middleware/rate_limiter";
import { scrubPii, scrubUrlParams } from "./pii-scrubber";
import { hashUid } from "../shared/hash-uid";

// =============================================================================
// Request/Response Types
// =============================================================================

export interface StructureRecipeRequest {
  /** Raw text to extract recipe from */
  text: string;
  /** Optional partial data to enhance (for enhancement mode) */
  partialData?: Partial<ExtractedRecipe>;
  /** Extraction mode: 'extract' (default), 'enhance', 'spoken', or 'ingredientLines' */
  mode?: "extract" | "enhance" | "spoken" | "ingredientLines";
  /** Source URL for reference */
  sourceUrl?: string;
}

export interface StructureRecipeResponse {
  success: boolean;
  recipe?: ExtractedRecipe;
  error?: string;
  /** Estimated cost in USD */
  estimatedCost: number;
  /** Prompt version used for this extraction */
  promptVersion?: string;
  /**
   * BUT-785: pinned model id used for this call. Threaded through to clients
   * so on-device analytics (`recipe_parse_completed`) can correlate quality
   * and cost regressions to specific Vertex model versions.
   */
  modelId?: string;
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
    return runStructureRecipe(request.data, hashUid(request.auth!.uid));
  })
);

/**
 * BUT-439: kill-switch flag bag, returned by the test seam below. Both
 * fields are optional; missing/undefined means "not killed" (fail open).
 */
export interface KillSwitchConfig {
  aiEnabled?: boolean;
  llmParserEnabled?: boolean;
}

/**
 * Test seam for the BUT-439 kill-switch lookup. Production resolves to a
 * Firestore read of `system/config`; tests inject a stub returning the
 * desired flag combination.
 */
export type LoadKillSwitch = () => Promise<KillSwitchConfig | undefined>;

async function defaultLoadKillSwitch(): Promise<KillSwitchConfig | undefined> {
  const configDoc = await admin.firestore().doc("system/config").get();
  if (!configDoc.exists) return undefined;
  const data = configDoc.data() as KillSwitchConfig | undefined;
  return data;
}

export interface RunStructureRecipeDeps {
  /** Test seam for the kill-switch lookup. */
  loadKillSwitch?: LoadKillSwitch;
}

/**
 * Server-callable core of `structureRecipe`. Used by the callable above and
 * by `ocr-recipe-image.ts` for the in-process OCR retry path (BUT-559) — no
 * HTTP round-trip, same Functions deployment.
 *
 * Throws `HttpsError` for unrecoverable failures (so the callable wrapper
 * surfaces them correctly). For server-to-server callers, wrap in try/catch
 * if the caller needs to fall back instead of failing.
 *
 * The `deps` parameter is optional and exists only for unit tests
 * (BUT-439 kill-switch e2e). Production callers pass nothing and the
 * default Firestore lookup runs.
 */
export async function runStructureRecipe(
  req: StructureRecipeRequest,
  authUidHash: string,
  deps?: RunStructureRecipeDeps
): Promise<StructureRecipeResponse> {
  const { text, partialData, mode = "extract", sourceUrl } = req;

  // Every exit path emits a `structure_recipe.complete` log so a future
  // Cloud Logging distribution-metric filter on `durationMs` (sliced by
  // `mode`) costs zero deploy.
  const startMs = Date.now();
  const textLength = typeof text === "string" ? text.length : 0;
  const emitTiming = (success: boolean, extra?: Record<string, unknown>): void => {
    logger.info("structure_recipe.complete", {
      event: "structure_recipe.complete",
      durationMs: Date.now() - startMs,
      textLength,
      mode,
      success,
      modelId: MODEL_ID,
      ...(extra ?? {}),
    });
  };

  // Validate input
  if (!text || typeof text !== "string") {
    emitTiming(false, { reason: "invalid_text_type" });
    throw new HttpsError("invalid-argument", "Text krävs för extraktion.");
  }

  if (text.length > 50000) {
    emitTiming(false, { reason: "text_too_long" });
    throw new HttpsError(
      "invalid-argument",
      "Texten är för lång (max 50000 tecken)."
    );
  }

  if (text.length < 20) {
    emitTiming(false, { reason: "text_too_short" });
    throw new HttpsError(
      "invalid-argument",
      "Texten är för kort för att innehålla ett recept."
    );
  }

  try {
    // BUT-439: dual-control kill switch.
    //   - `aiEnabled` (master): kills ALL Vertex calls across the app.
    //   - `llmParserEnabled` (per-feature): kills ONLY the recipe-parse
    //     pipeline (structureRecipe + the OCR text-mode retry path).
    //     Use this when AI is functional but a specific prompt regression
    //     is producing junk output and the parse pipeline must be paused
    //     without taking down OCR vision and other LLM-fronted features.
    //
    // Both flags fail open on missing doc / missing field — this is a
    // resilience choice (see docs/ops/llm-kill-switch-runbook.md). On
    // Firestore unreachable the outer catch turns it into an `internal`
    // HttpsError (fail closed for the user, but not silently bypassed).
    const loadKillSwitch = deps?.loadKillSwitch ?? defaultLoadKillSwitch;
    const config = await loadKillSwitch();
    if (config?.aiEnabled === false) {
      emitTiming(false, { reason: "kill_switch_ai" });
      return {
        success: false,
        error: "AI-funktioner är tillfälligt avstängda.",
        estimatedCost: 0,
        modelId: MODEL_ID,
      };
    }
    if (config?.llmParserEnabled === false) {
      emitTiming(false, { reason: "kill_switch_llm_parser" });
      return {
        success: false,
        error: "AI-receptolkning är tillfälligt avstängd.",
        estimatedCost: 0,
        modelId: MODEL_ID,
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

    // BUT-621: prompts come from Firestore (5-min per-instance cache).
    // Falls back to compiled-in defaults on read failure.
    const prompts = await getPromptsConfig();
    const promptVersion = prompts.promptVersion;

    // Select system prompt based on mode
    let systemPrompt: string;
    let userPrompt: string;

    switch (mode) {
      case "enhance":
        systemPrompt = prompts.recipeEnhancementSystemPrompt;
        userPrompt = buildEnhancementPrompt(cleanText, partialData, cleanSourceUrl);
        break;
      case "spoken":
        systemPrompt = prompts.spokenContentSystemPrompt;
        userPrompt = buildSpokenPrompt(cleanText, cleanSourceUrl);
        break;
      case "ingredientLines":
        systemPrompt = prompts.ingredientLineSystemPrompt;
        userPrompt = buildIngredientLinesPrompt(cleanText);
        break;
      default:
        systemPrompt = prompts.recipeExtractionSystemPrompt;
        userPrompt = buildExtractionPrompt(cleanText, cleanSourceUrl);
    }

    logger.info(
      `[structureRecipe] Processing ${text.length} chars in ${mode} mode for user ${authUidHash} (prompt v${promptVersion}, source=${prompts.source})`
    );

    // Call Vertex AI Gemini (`eu` multi-region, EU residency — BUT-1187)
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
      emitTiming(false, { reason: "empty_response" });
      return {
        success: false,
        error: "Inget svar från AI-tjänsten.",
        estimatedCost: 0.01,
        promptVersion,
        modelId: MODEL_ID,
      };
    }

    // Calculate actual cost from API usage
    const actualCost = calculateGeminiCost(response.usageMetadata);

    // Parse response — ingredient lines mode returns array, others return recipe
    if (isIngredientLines) {
      const parsed = parseIngredientLinesResponse(content);
      if (!parsed) {
        logger.error("[structureRecipe] Failed to parse ingredient lines:", content);
        emitTiming(false, { reason: "ingredient_lines_parse_failed" });
        return {
          success: false,
          error: "Kunde inte tolka AI-svaret som ingredienser.",
          estimatedCost: actualCost,
          promptVersion,
          modelId: MODEL_ID,
        };
      }

      const { ingredients, truncated } = parsed;
      if (truncated) {
        // BUT-577: Gemini hit maxOutputTokens mid-array; we recovered the
        // fully-formed prefix. Surface so ops can spot frequency and consider
        // raising INGREDIENT_LINE_MAX_TOKENS or chunking the input.
        logger.warn(
          "[structureRecipe] Ingredient lines response was truncated; partial recovery used",
          { recovered: ingredients.length }
        );
      }

      logger.info(
        `[structureRecipe] Parsed ${ingredients.length} ingredient lines (cost: $${actualCost.toFixed(6)})`
      );

      emitTiming(true, { ingredientCount: ingredients.length, truncated });
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
        promptVersion,
        modelId: MODEL_ID,
      };
    }

    // BUT-679: distinguish "Gemini said this is not a recipe" (returned empty
    // ingredient/instruction arrays per the prompt's hallucination guard) from
    // a true structural parse failure. The user-facing copy differs: the
    // former is "this URL doesn't look like a recipe" (their input was wrong),
    // the latter is "AI couldn't parse the response" (our problem).
    if (isNotRecipeResponse(content)) {
      logger.info(
        "[structureRecipe] Input is not a recipe — empty arrays from Gemini"
      );
      emitTiming(false, { reason: "not_a_recipe" });
      return {
        success: false,
        error:
          "Den här sidan ser inte ut som ett recept. Prova en annan URL eller klistra in texten manuellt.",
        estimatedCost: actualCost,
        promptVersion,
        modelId: MODEL_ID,
      };
    }

    const recipe = parseRecipeResponse(content, promptVersion);
    if (!recipe) {
      logger.error("[structureRecipe] Failed to parse response:", content);
      emitTiming(false, { reason: "recipe_parse_failed" });
      return {
        success: false,
        error: "Kunde inte tolka AI-svaret som ett recept.",
        estimatedCost: actualCost,
        promptVersion,
        modelId: MODEL_ID,
      };
    }

    // Add source if provided
    if (cleanSourceUrl && !recipe.source) {
      recipe.source = cleanSourceUrl;
    }

    logger.info(
      `[structureRecipe] Successfully extracted: "${recipe.title}" with ${recipe.ingredients.length} ingredients (cost: $${actualCost.toFixed(6)})`
    );

    emitTiming(true, { ingredientCount: recipe.ingredients.length });
    return {
      success: true,
      recipe,
      estimatedCost: actualCost,
      promptVersion,
      modelId: MODEL_ID,
    };
  } catch (error) {
    // BUT-566 / ADR-001: server fails fast; the client (llm_tier.dart:120-128)
    // is the sole retry layer (RetryHelper.retryNetworkOperation, maxRetries: 2).
    // Do NOT add retry/loop logic here — stacking server retries with client
    // retries multiplies Gemini API load under the same rate-limit window.
    // See docs/architecture/ADR-001-gemini-retry-policy.md.
    logger.error("[structureRecipe] Error:", error);

    if (error instanceof HttpsError) {
      emitTiming(false, { reason: "https_error", code: error.code });
      throw error;
    }

    // Check for rate limiting
    if (error instanceof Error && error.message.includes("rate limit")) {
      emitTiming(false, { reason: "rate_limited" });
      throw new HttpsError(
        "resource-exhausted",
        "AI-tjänsten är tillfälligt överbelastad. Försök igen om en stund."
      );
    }

    emitTiming(false, { reason: "internal_error" });
    throw new HttpsError(
      "internal",
      "Ett fel uppstod vid AI-bearbetning. Försök igen."
    );
  }
}

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

/**
 * BUT-679: detect Gemini's "this isn't a recipe" sentinel response.
 *
 * The prompt instructs Gemini to return empty `ingredients` / `instructions`
 * arrays when the input isn't a complete recipe. We treat structurally-valid
 * JSON with either array empty as "not a recipe" — distinct from a truly
 * malformed response (which `parseRecipeResponse` will surface as null).
 *
 * Returns true only when the JSON parses cleanly AND at least one of the
 * recipe-defining arrays is empty. Any parse failure falls through to the
 * normal `parseRecipeResponse` path so we don't mask real errors.
 */
function isNotRecipeResponse(content: string): boolean {
  try {
    const parsed = JSON.parse(stripCodeFences(content));
    if (!parsed || typeof parsed !== "object") return false;
    const ingredients = (parsed as { ingredients?: unknown }).ingredients;
    const instructions = (parsed as { instructions?: unknown }).instructions;
    const ingredientsEmpty =
      Array.isArray(ingredients) && ingredients.length === 0;
    const instructionsEmpty =
      Array.isArray(instructions) && instructions.length === 0;
    return ingredientsEmpty || instructionsEmpty;
  } catch {
    return false;
  }
}

/** @internal — exported only for unit tests. Do not import from production code. */
export const __test__ = {
  isNotRecipeResponse,
};

