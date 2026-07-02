/**
 * BUT-621: Remote-Config-style prompt loading from Firestore.
 *
 * Why: a regressed prompt previously required a Cloud Functions redeploy
 * (≈15 minutes minimum) to roll back. With this module, prompts live in
 * Firestore at `system/prompts` and can be hot-edited from the console;
 * each running CF instance picks up the new version within the cache TTL
 * (default 5 minutes) — or immediately on cold start.
 *
 * Resilience contract:
 * - Firestore unreachable / doc missing / malformed → fall back to the
 *   compiled-in prompt constants exported from `gemini-client.ts`. The
 *   fallback is logged ONCE per cache window (so we know prompts have
 *   drifted in production) and then suppressed until the next refresh.
 * - Cache state lives in module scope (per-instance). Cold starts naturally
 *   invalidate; we deliberately avoid a global singleton class so each
 *   isolate gets its own cache and there's no shared mutable state to
 *   reason about.
 *
 * Firestore document shape (`system/prompts`):
 *   {
 *     recipeExtractionSystemPrompt: string,
 *     recipeEnhancementSystemPrompt: string,
 *     imageOcrSystemPrompt: string,
 *     imageOcrHandwrittenSystemPrompt?: string, // BUT-684 handwritten variant (OPTIONAL; per-field fallback)
 *     spokenContentSystemPrompt: string,
 *     ingredientLineSystemPrompt: string,
 *     promptVersion: string,           // bump on every doc edit
 *     updatedAt: Timestamp,
 *   }
 *
 * Operators are expected to bump `promptVersion` on every edit so analytics
 * downstream (parse-correction events, OCR retry outcomes) can correlate
 * regressions to a specific prompt revision.
 */

import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import {
  PROMPT_VERSION as FALLBACK_PROMPT_VERSION,
  RECIPE_EXTRACTION_SYSTEM_PROMPT,
  RECIPE_ENHANCEMENT_SYSTEM_PROMPT,
  IMAGE_OCR_SYSTEM_PROMPT,
  IMAGE_OCR_HANDWRITTEN_SYSTEM_PROMPT,
  SPOKEN_CONTENT_SYSTEM_PROMPT,
  INGREDIENT_LINE_SYSTEM_PROMPT,
} from "./gemini-client";

/** TTL for the per-instance prompts cache. */
export const PROMPTS_CACHE_TTL_MS = 5 * 60 * 1000;

/** Firestore path holding the live prompts bundle. */
export const PROMPTS_DOC_PATH = "system/prompts";

/**
 * Snapshot of all LLM system prompts, plus the version string that
 * downstream analytics keys off. `source` lets callers (and tests) tell
 * whether the snapshot came from Firestore or the compiled-in fallback.
 *
 * BUT-626: `promptVariants` is an optional list of experiment variant names
 * (e.g. `["control", "v2_extraction"]`). When present, callers use
 * `resolvePromptBucket(userId, promptVariants)` to deterministically assign
 * a user to one variant without any additional Firestore reads. When absent,
 * no experiment is active and the single-version fallback applies.
 *
 * Operators add/remove `promptVariants` to the `system/prompts` doc to
 * start/stop an experiment. The doc's 5-min cache TTL governs propagation.
 */
export interface PromptsConfig {
  recipeExtractionSystemPrompt: string;
  recipeEnhancementSystemPrompt: string;
  imageOcrSystemPrompt: string;
  /**
   * BUT-684: system prompt for handwritten recipe images. Firestore-overridable,
   * but OPTIONAL in the remote doc: a doc lacking it still validates as
   * `source: firestore` and this field falls back per-field to the compiled-in
   * `IMAGE_OCR_HANDWRITTEN_SYSTEM_PROMPT` (so pre-existing override docs keep
   * their other tuning). Always a non-empty string on the resolved config. The
   * `ocrRecipeImage` handler selects it when the request sets
   * `isHandwritten: true`.
   */
  imageOcrHandwrittenSystemPrompt: string;
  spokenContentSystemPrompt: string;
  ingredientLineSystemPrompt: string;
  promptVersion: string;
  source: "firestore" | "fallback";
  /**
   * BUT-626: Optional A/B experiment variant names. Present only when an
   * experiment is active in the `system/prompts` Firestore doc.
   */
  promptVariants?: string[];
}

/** Test seam: returns the raw Firestore data, or undefined if doc missing. */
export type PromptsLoader = () => Promise<Record<string, unknown> | undefined>;

export interface GetPromptsConfigDeps {
  /** Test seam for the Firestore read. Production resolves to a doc.get(). */
  loader?: PromptsLoader;
  /** Clock seam for TTL math. Production uses Date.now. */
  now?: () => number;
  /** Override TTL for tests. */
  ttlMs?: number;
}

interface CacheEntry {
  prompts: PromptsConfig;
  fetchedAt: number;
}

let cache: CacheEntry | null = null;

/// In-flight Firestore read shared across concurrent callers on cold start.
/// Without this, N concurrent requests on a fresh instance each fire their own
/// Firestore round-trip and block individually. Coalescing lets all but the
/// first piggy-back on the same network call.
let inflight: Promise<PromptsConfig> | null = null;

/**
 * Test-only: clear the cache between cases. Production callers never invoke
 * this — the TTL handles invalidation.
 */
export function __resetPromptsCacheForTests(): void {
  cache = null;
  inflight = null;
}

function buildFallback(): PromptsConfig {
  return {
    recipeExtractionSystemPrompt: RECIPE_EXTRACTION_SYSTEM_PROMPT,
    recipeEnhancementSystemPrompt: RECIPE_ENHANCEMENT_SYSTEM_PROMPT,
    imageOcrSystemPrompt: IMAGE_OCR_SYSTEM_PROMPT,
    imageOcrHandwrittenSystemPrompt: IMAGE_OCR_HANDWRITTEN_SYSTEM_PROMPT,
    spokenContentSystemPrompt: SPOKEN_CONTENT_SYSTEM_PROMPT,
    ingredientLineSystemPrompt: INGREDIENT_LINE_SYSTEM_PROMPT,
    promptVersion: FALLBACK_PROMPT_VERSION,
    source: "fallback",
  };
}

/**
 * Validate the Firestore doc shape. We require all five prompts to be
 * non-empty strings AND a non-empty `promptVersion`. Anything missing or
 * non-string ⇒ malformed ⇒ fallback.
 *
 * Rationale for "all-or-nothing" validation: a partial overlay (mix prod
 * fallback + Firestore strings) creates a debugging nightmare where the
 * `promptVersion` reported to analytics doesn't match the prompt actually
 * sent. Better to fall back wholesale and log loudly.
 */
function validateRemoteDoc(
  raw: Record<string, unknown> | undefined,
): PromptsConfig | null {
  if (!raw) return null;

  const requiredStringKeys = [
    "recipeExtractionSystemPrompt",
    "recipeEnhancementSystemPrompt",
    "imageOcrSystemPrompt",
    "spokenContentSystemPrompt",
    "ingredientLineSystemPrompt",
    "promptVersion",
  ] as const;

  for (const key of requiredStringKeys) {
    const v = raw[key];
    if (typeof v !== "string" || v.trim().length === 0) {
      return null;
    }
  }

  // BUT-626: optional A/B variant list. Validated as string[]; any invalid
  // element makes the whole field absent (all-or-nothing, same rationale as
  // the required fields). A missing/non-array field is silently ignored —
  // no active experiment is the safe default.
  let promptVariants: string[] | undefined;
  const rawVariants = raw["promptVariants"];
  if (Array.isArray(rawVariants) && rawVariants.length > 0) {
    // Non-empty strings, capped at 64 chars so a stray long value can't bloat
    // the structured analytics log entries that carry the variant name.
    const allStrings = rawVariants.every(
      (v) =>
        typeof v === "string" &&
        (v as string).trim().length > 0 &&
        (v as string).length <= 64,
    );
    if (allStrings) {
      promptVariants = rawVariants as string[];
    }
    // If invalid, silently omit — experiment simply isn't active.
  }

  // BUT-684: the handwritten OCR prompt is OPTIONAL and backward-compatible.
  // A pre-existing `system/prompts` doc (valid under the original 6 keys) must
  // keep validating as `source: firestore` and retain all its other overrides —
  // it must NOT invalidate the whole bundle. So this field falls back
  // PER-FIELD to the compiled-in constant when absent or non-string/empty,
  // rather than being required. This also removes any deploy dependency on an
  // operator hand-editing the prod doc.
  const rawHandwritten = raw.imageOcrHandwrittenSystemPrompt;
  const imageOcrHandwrittenSystemPrompt =
    typeof rawHandwritten === "string" && rawHandwritten.trim().length > 0
      ? rawHandwritten
      : IMAGE_OCR_HANDWRITTEN_SYSTEM_PROMPT;

  return {
    recipeExtractionSystemPrompt: raw.recipeExtractionSystemPrompt as string,
    recipeEnhancementSystemPrompt: raw.recipeEnhancementSystemPrompt as string,
    imageOcrSystemPrompt: raw.imageOcrSystemPrompt as string,
    imageOcrHandwrittenSystemPrompt,
    spokenContentSystemPrompt: raw.spokenContentSystemPrompt as string,
    ingredientLineSystemPrompt: raw.ingredientLineSystemPrompt as string,
    promptVersion: (raw.promptVersion as string).trim(),
    source: "firestore",
    ...(promptVariants !== undefined ? { promptVariants } : {}),
  };
}

async function defaultPromptsLoader(): Promise<
  Record<string, unknown> | undefined
> {
  const snap = await admin.firestore().doc(PROMPTS_DOC_PATH).get();
  if (!snap.exists) return undefined;
  return snap.data();
}

/**
 * Resolve the active prompts bundle.
 *
 * Returns a cache hit if within TTL; otherwise re-reads from Firestore. On
 * any read failure (network, missing doc, malformed shape) returns the
 * compiled-in fallback and logs a single observability entry so the team
 * is aware prompts have drifted.
 *
 * Concurrent cold-start callers coalesce on the same in-flight Firestore
 * read — only the first hits the network; the rest await the shared promise.
 */
export async function getPromptsConfig(
  deps?: GetPromptsConfigDeps,
): Promise<PromptsConfig> {
  const now = deps?.now ?? Date.now;
  const ttl = deps?.ttlMs ?? PROMPTS_CACHE_TTL_MS;
  const loader = deps?.loader ?? defaultPromptsLoader;

  if (cache && now() - cache.fetchedAt < ttl) {
    return cache.prompts;
  }

  if (inflight) {
    return inflight;
  }

  inflight = (async () => {
    let prompts: PromptsConfig;
    try {
      const raw = await loader();
      const validated = validateRemoteDoc(raw);
      if (validated) {
        prompts = validated;
      } else {
        prompts = buildFallback();
        if (raw === undefined) {
          logger.warn(
            "[prompts-config] Firestore doc missing, using fallback",
            {
              path: PROMPTS_DOC_PATH,
              fallbackVersion: prompts.promptVersion,
            },
          );
        } else {
          logger.warn(
            "[prompts-config] Firestore doc malformed, using fallback",
            {
              path: PROMPTS_DOC_PATH,
              fallbackVersion: prompts.promptVersion,
              keys: Object.keys(raw),
            },
          );
        }
      }
    } catch (err) {
      prompts = buildFallback();
      logger.warn("[prompts-config] Firestore read failed, using fallback", {
        path: PROMPTS_DOC_PATH,
        fallbackVersion: prompts.promptVersion,
        err,
      });
    }

    cache = { prompts, fetchedAt: now() };
    return prompts;
  })();

  try {
    return await inflight;
  } finally {
    inflight = null;
  }
}
