/**
 * OCR rawText auto-retry orchestrator (BUT-559).
 *
 * When `ocrRecipeImage`'s image-mode parse fails but Gemini returned legible
 * `rawText`, this module retries by feeding that rawText into
 * `structureRecipe`'s text-mode pipeline. Same Functions deployment, no HTTP
 * round-trip.
 *
 * Budget guard: the parent OCR function has `timeoutSeconds: 120`. We require
 * `MIN_REMAINING_BUDGET_MS` left before invoking the retry — enough for a
 * typical `structureRecipe` call (its own `timeoutSeconds: 60`) plus margin
 * for cold-start, network jitter, and response packaging.
 *
 * The orchestrator is dependency-injected (via `RetryDeps`) so tests can run
 * without spinning up Vertex AI or Firebase Admin.
 */

import { logger } from "firebase-functions/logger";
import type { ExtractedRecipe } from "./gemini-client";
import type {
  StructureRecipeRequest,
  StructureRecipeResponse,
} from "./structure-recipe";

// =============================================================================
// Public types
// =============================================================================

export type RetryOutcome =
  | "success"
  | "failure"
  | "skipped_budget"
  | "skipped_no_text"
  | null;

export interface RetryResult {
  /** Recipe parsed by the structureRecipe retry, if any. */
  recipe?: ExtractedRecipe;
  /** Additional cost the retry incurred (Gemini text-mode). */
  additionalCost: number;
  /** 0 if no retry attempted, 1 if attempted (success or failure). */
  retryCount: 0 | 1;
  /** Observability classifier. */
  retryOutcome: RetryOutcome;
  /** Prompt version used by the retry, when applicable. */
  promptVersion?: string;
}

export interface RetryDeps {
  /**
   * Test seam — production resolves to `runStructureRecipe`. Returns the
   * full response (including `success: false` for parse failures) and may
   * throw `HttpsError` for hard failures (which we catch and treat as a
   * recoverable failure outcome).
   */
  structureRecipe: (
    req: StructureRecipeRequest,
    authUidHash: string
  ) => Promise<StructureRecipeResponse>;
  /** Test seam for time. Production resolves to `Date.now`. */
  now?: () => number;
  /** Override the budget threshold (ms). Default `MIN_REMAINING_BUDGET_MS`. */
  minRemainingBudgetMs?: number;
  /** Total parent-function timeout (ms). Default `OCR_FUNCTION_TIMEOUT_MS`. */
  totalBudgetMs?: number;
}

// =============================================================================
// Budget constants
// =============================================================================

/**
 * Total OCR function timeout in ms. Mirrors `timeoutSeconds: 120` on
 * `ocrRecipeImage` — keep in sync if that value changes.
 */
export const OCR_FUNCTION_TIMEOUT_MS = 120_000;

/**
 * Minimum remaining wall time required to attempt the retry.
 *
 * `structureRecipe` itself runs at `timeoutSeconds: 60`. We need its full
 * 60s ceiling plus a 5s margin for ADC token resolution, network jitter,
 * and the post-call response packaging in `ocrRecipeImage`. Total: 65s.
 */
export const MIN_REMAINING_BUDGET_MS = 65_000;

// =============================================================================
// Orchestrator
// =============================================================================

/**
 * Run the structureRecipe retry path for a failed OCR image-mode parse.
 *
 * Decision tree:
 *  - `rawText` empty/whitespace → skip (`retryOutcome = 'skipped_no_text'`)
 *  - elapsed time leaves < `minRemainingBudgetMs` of headroom → skip
 *    (`retryOutcome = 'skipped_budget'`)
 *  - structureRecipe returns success → forward recipe
 *    (`retryOutcome = 'success'`)
 *  - structureRecipe returns success: false OR throws → record attempt,
 *    fall back to raw text (`retryOutcome = 'failure'`)
 */
export async function runOcrRetry(
  rawText: string | null | undefined,
  ocrStartMs: number,
  authUidHash: string,
  deps: RetryDeps
): Promise<RetryResult> {
  const now = deps.now ?? Date.now;
  const minRemaining =
    deps.minRemainingBudgetMs ?? MIN_REMAINING_BUDGET_MS;
  const totalBudget = deps.totalBudgetMs ?? OCR_FUNCTION_TIMEOUT_MS;

  // Guard 1: no text to retry on.
  if (!rawText || rawText.trim().length === 0) {
    return {
      additionalCost: 0,
      retryCount: 0,
      retryOutcome: "skipped_no_text",
    };
  }

  // Guard 2: budget. If we've already burned more than `totalBudget -
  // minRemaining`, don't even start — the structureRecipe call would
  // probably exceed the parent function's timeout.
  const elapsedMs = now() - ocrStartMs;
  const remainingMs = totalBudget - elapsedMs;
  if (remainingMs < minRemaining) {
    logger.info(
      `[ocrRetry] Skipping retry — budget exceeded ` +
        `(elapsed=${elapsedMs}ms, remaining=${remainingMs}ms, ` +
        `min_required=${minRemaining}ms)`
    );
    return {
      additionalCost: 0,
      retryCount: 0,
      retryOutcome: "skipped_budget",
    };
  }

  // Guard 3: structureRecipe enforces a 20-char minimum. Skip if rawText is
  // below the threshold — there's nothing the LLM can do with that little
  // text, and we'd just throw `invalid-argument`.
  if (rawText.trim().length < 20) {
    return {
      additionalCost: 0,
      retryCount: 0,
      retryOutcome: "skipped_no_text",
    };
  }

  // Attempt the retry.
  try {
    const result = await deps.structureRecipe(
      { text: rawText, mode: "extract" },
      authUidHash
    );

    if (result.success && result.recipe) {
      return {
        recipe: result.recipe,
        additionalCost: result.estimatedCost,
        retryCount: 1,
        retryOutcome: "success",
        promptVersion: result.promptVersion,
      };
    }

    // structureRecipe returned a structured failure (parse error, kill
    // switch, etc). The attempt was made — bill the cost, mark failure.
    return {
      additionalCost: result.estimatedCost ?? 0,
      retryCount: 1,
      retryOutcome: "failure",
      promptVersion: result.promptVersion,
    };
  } catch (error) {
    // structureRecipe threw (HttpsError, rate limit, network, etc).
    // We swallow the error and fall back to the rawText response — losing
    // partial success here is exactly what BUT-559 is fixing.
    logger.warn(
      "[ocrRetry] structureRecipe threw during retry, falling back to rawText",
      error
    );
    return {
      additionalCost: 0,
      retryCount: 1,
      retryOutcome: "failure",
    };
  }
}
