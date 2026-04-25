/**
 * Sprint D2 / BUT-559: OCR rawText auto re-extraction.
 *
 * Before this sprint, when `ocrRecipeImage` failed to parse the vision
 * model's response as a structured recipe, it returned the raw OCR text to
 * the client and depended on the client to re-call `structureRecipe`.
 * Most callers dropped the rawText on the floor.
 *
 * After this sprint, `runOcrRecipeImage` (the test-seamable core of the
 * callable) automatically invokes `runStructureRecipe(rawText)` in-process
 * on parse failure, budget permitting, and returns the structured result
 * with `retryCount: 1` + `retryOutcome: 'success'` for observability.
 *
 * This file exercises three layers:
 *
 *   1. The retry orchestrator (`runOcrRetry`) directly — simplest unit, no
 *      Firebase Admin or Vertex AI involved.
 *   2. The OCR core (`runOcrRecipeImage`) end-to-end via test seams —
 *      proves the wiring between OCR parse failure and the retry path.
 *   3. The four observability outcomes called out in the brief: success,
 *      failure (retry threw), skipped_budget, skipped_no_text, and the
 *      "happy path" (parse succeeded, no retry needed).
 *
 * Run with: npx ts-node src/__tests__/ocr-retry.test.ts
 */

import {
  runOcrRetry,
  MIN_REMAINING_BUDGET_MS,
  OCR_FUNCTION_TIMEOUT_MS,
} from "../llm/ocr-retry";
import {
  runOcrRecipeImage,
  OcrPerformResult,
} from "../llm/ocr-recipe-image";
import type {
  StructureRecipeRequest,
  StructureRecipeResponse,
} from "../llm/structure-recipe";
import type { ExtractedRecipe } from "../llm/gemini-client";

// =============================================================================
// Helpers
// =============================================================================

function makeRecipe(title: string): ExtractedRecipe {
  return {
    title,
    description: null,
    portions: 4,
    prepTimeMinutes: 10,
    cookTimeMinutes: 20,
    ingredients: [
      {
        amount: 200,
        unit: "g",
        name: "mjöl",
        preparation: null,
      },
    ],
    instructions: ["Blanda allt.", "Grädda 20 min."],
    tags: [],
    difficulty: "easy",
    source: null,
  };
}

interface AssertionResult {
  ok: boolean;
  detail?: string;
}

let totalFailed = 0;
let totalRun = 0;

function record(name: string, a: AssertionResult): void {
  totalRun++;
  if (a.ok) {
    console.log(`  PASS  ${name}`);
  } else {
    totalFailed++;
    console.log(`  FAIL  ${name}`);
    if (a.detail) console.log(`        ${a.detail}`);
  }
}

// =============================================================================
// Layer 1: runOcrRetry orchestrator
// =============================================================================

async function testOrchestrator(): Promise<void> {
  console.log("\n[1] runOcrRetry orchestrator");

  // Scenario: rawText empty → skipped_no_text
  {
    const calls: StructureRecipeRequest[] = [];
    const r = await runOcrRetry(
      "",
      0,
      "uid-hash",
      {
        structureRecipe: async (req) => {
          calls.push(req);
          return { success: true, recipe: makeRecipe("x"), estimatedCost: 0 };
        },
        now: () => 0,
      }
    );
    record(
      "empty rawText skips retry with skipped_no_text",
      calls.length === 0 && r.retryCount === 0 && r.retryOutcome === "skipped_no_text"
        ? { ok: true }
        : {
            ok: false,
            detail: `calls=${calls.length}, retryCount=${r.retryCount}, outcome=${r.retryOutcome}`,
          }
    );
  }

  // Scenario: whitespace-only rawText → skipped_no_text
  {
    const calls: StructureRecipeRequest[] = [];
    const r = await runOcrRetry(
      "   \n\t  ",
      0,
      "uid-hash",
      {
        structureRecipe: async (req) => {
          calls.push(req);
          return { success: true, recipe: makeRecipe("x"), estimatedCost: 0 };
        },
        now: () => 0,
      }
    );
    record(
      "whitespace-only rawText skips retry with skipped_no_text",
      calls.length === 0 && r.retryCount === 0 && r.retryOutcome === "skipped_no_text"
        ? { ok: true }
        : {
            ok: false,
            detail: `calls=${calls.length}, retryCount=${r.retryCount}, outcome=${r.retryOutcome}`,
          }
    );
  }

  // Scenario: budget exceeded → skipped_budget. We pretend `now` is far past
  // the start time so `remainingMs < MIN_REMAINING_BUDGET_MS`.
  {
    const calls: StructureRecipeRequest[] = [];
    const startMs = 0;
    // Burn enough that less than minRemaining is left.
    const elapsedMs = OCR_FUNCTION_TIMEOUT_MS - MIN_REMAINING_BUDGET_MS + 1;
    const r = await runOcrRetry(
      "Pannkakor 2 dl mjöl 4 dl mjölk 2 ägg 1 nypa salt blanda och stek.",
      startMs,
      "uid-hash",
      {
        structureRecipe: async (req) => {
          calls.push(req);
          return { success: true, recipe: makeRecipe("x"), estimatedCost: 0 };
        },
        now: () => startMs + elapsedMs,
      }
    );
    record(
      "budget exhausted skips retry with skipped_budget",
      calls.length === 0 && r.retryCount === 0 && r.retryOutcome === "skipped_budget"
        ? { ok: true }
        : {
            ok: false,
            detail: `calls=${calls.length}, retryCount=${r.retryCount}, outcome=${r.retryOutcome}`,
          }
    );
  }

  // Scenario: structureRecipe success → success, recipe forwarded.
  {
    const calls: StructureRecipeRequest[] = [];
    const recipe = makeRecipe("Pannkakor");
    const r = await runOcrRetry(
      "Pannkakor 2 dl mjöl 4 dl mjölk 2 ägg blanda stek.",
      0,
      "uid-hash",
      {
        structureRecipe: async (req) => {
          calls.push(req);
          return {
            success: true,
            recipe,
            estimatedCost: 0.002,
            promptVersion: "v9",
          };
        },
        now: () => 1000, // ~1s elapsed, well within budget.
      }
    );
    const ok =
      calls.length === 1 &&
      calls[0].text.startsWith("Pannkakor") &&
      calls[0].mode === "extract" &&
      r.retryCount === 1 &&
      r.retryOutcome === "success" &&
      r.recipe === recipe &&
      r.additionalCost === 0.002 &&
      r.promptVersion === "v9";
    record(
      "structureRecipe success → retry forwards recipe with retryOutcome=success",
      ok
        ? { ok: true }
        : {
            ok: false,
            detail: `calls=${calls.length}, mode=${calls[0]?.mode}, outcome=${r.retryOutcome}, recipe=${r.recipe?.title}, cost=${r.additionalCost}`,
          }
    );
  }

  // Scenario: structureRecipe returns success: false → failure outcome.
  {
    const r = await runOcrRetry(
      "garbled text but long enough to pass length validation.",
      0,
      "uid-hash",
      {
        structureRecipe: async () => ({
          success: false,
          error: "parse failed",
          estimatedCost: 0.001,
        }),
        now: () => 0,
      }
    );
    record(
      "structureRecipe returns success:false → retryCount=1, outcome=failure",
      r.retryCount === 1 && r.retryOutcome === "failure" && !r.recipe
        ? { ok: true }
        : {
            ok: false,
            detail: `retryCount=${r.retryCount}, outcome=${r.retryOutcome}, recipe=${r.recipe?.title}`,
          }
    );
  }

  // Scenario: structureRecipe throws → failure outcome, no rethrow.
  {
    const r = await runOcrRetry(
      "garbled text but long enough to pass length validation.",
      0,
      "uid-hash",
      {
        structureRecipe: async () => {
          throw new Error("vertex ai 503");
        },
        now: () => 0,
      }
    );
    record(
      "structureRecipe throws → retryCount=1, outcome=failure (caught, no rethrow)",
      r.retryCount === 1 && r.retryOutcome === "failure" && !r.recipe
        ? { ok: true }
        : {
            ok: false,
            detail: `retryCount=${r.retryCount}, outcome=${r.retryOutcome}, recipe=${r.recipe?.title}`,
          }
    );
  }
}

// =============================================================================
// Layer 2: runOcrRecipeImage end-to-end (with test seams)
// =============================================================================

interface OcrTestState {
  performOcrCalls: number;
  structureRecipeCalls: StructureRecipeRequest[];
}

function makeOcrSeams(opts: {
  ocr: () => Promise<OcrPerformResult>;
  retry: (req: StructureRecipeRequest) => Promise<StructureRecipeResponse>;
  state: OcrTestState;
  nowSeq?: number[]; // sequential `now()` returns
}) {
  let nowIdx = 0;
  return {
    performOcr: async () => {
      opts.state.performOcrCalls++;
      return opts.ocr();
    },
    structureRecipe: async (req: StructureRecipeRequest) => {
      opts.state.structureRecipeCalls.push(req);
      return opts.retry(req);
    },
    isAiDisabled: async () => false,
    now: () => {
      if (opts.nowSeq) {
        const v = opts.nowSeq[Math.min(nowIdx, opts.nowSeq.length - 1)];
        nowIdx++;
        return v;
      }
      return 1000;
    },
  };
}

async function testCoreEndToEnd(): Promise<void> {
  console.log("\n[2] runOcrRecipeImage end-to-end");

  // MANDATORY: image parse fails, rawText non-empty, structureRecipe
  // succeeds → response carries structured recipe + retryCount=1 +
  // retryOutcome='success'.
  {
    const state: OcrTestState = {
      performOcrCalls: 0,
      structureRecipeCalls: [],
    };
    const recipe = makeRecipe("Köttbullar");
    const seams = makeOcrSeams({
      ocr: async () => ({
        // Non-JSON text → parseRecipeResponse returns null.
        content:
          "Köttbullar: 500g köttfärs, 1 ägg, 1 dl ströbröd, salt och peppar. Forma och stek.",
        cost: 0.012,
      }),
      retry: async () => ({
        success: true,
        recipe,
        estimatedCost: 0.003,
        promptVersion: "vTest",
      }),
      state,
    });

    const resp = await runOcrRecipeImage({
      data: { imageBase64: "/9j/" + "A".repeat(40) },
      authUidHash: "test-hash",
      ...seams,
    });

    const ok =
      resp.success === true &&
      resp.recipe === recipe &&
      resp.retryCount === 1 &&
      resp.retryOutcome === "success" &&
      state.structureRecipeCalls.length === 1 &&
      state.structureRecipeCalls[0].text.startsWith("Köttbullar") &&
      state.structureRecipeCalls[0].mode === "extract" &&
      // Cost is OCR + retry combined.
      Math.abs(resp.estimatedCost - (0.012 + 0.003)) < 1e-9 &&
      resp.rawText !== undefined &&
      resp.promptVersion === "vTest";
    record(
      "MANDATORY: parse-fail + non-empty rawText + structureRecipe success → recovered",
      ok
        ? { ok: true }
        : {
            ok: false,
            detail:
              `success=${resp.success}, retryCount=${resp.retryCount}, ` +
              `outcome=${resp.retryOutcome}, ` +
              `structureCalls=${state.structureRecipeCalls.length}, ` +
              `cost=${resp.estimatedCost}, recipe=${resp.recipe?.title}, ` +
              `promptVersion=${resp.promptVersion}`,
          }
    );
  }

  // BONUS 1: happy path. Image parse succeeds first try → no retry,
  // retryCount: 0, retryOutcome: null.
  {
    const state: OcrTestState = {
      performOcrCalls: 0,
      structureRecipeCalls: [],
    };
    const validJson = JSON.stringify(makeRecipe("Lasagne"));
    const seams = makeOcrSeams({
      ocr: async () => ({ content: validJson, cost: 0.01 }),
      retry: async () => ({
        success: true,
        recipe: makeRecipe("should-not-be-called"),
        estimatedCost: 0,
      }),
      state,
    });

    const resp = await runOcrRecipeImage({
      data: { imageBase64: "/9j/" + "A".repeat(40) },
      authUidHash: "test-hash",
      ...seams,
    });

    const ok =
      resp.success === true &&
      resp.recipe?.title === "Lasagne" &&
      resp.retryCount === 0 &&
      resp.retryOutcome === null &&
      state.structureRecipeCalls.length === 0 &&
      resp.estimatedCost === 0.01;
    record(
      "BONUS: happy path image parse succeeds → retryCount=0, retryOutcome=null, no retry",
      ok
        ? { ok: true }
        : {
            ok: false,
            detail:
              `success=${resp.success}, recipeTitle=${resp.recipe?.title}, ` +
              `retryCount=${resp.retryCount}, outcome=${resp.retryOutcome}, ` +
              `structureCalls=${state.structureRecipeCalls.length}, ` +
              `cost=${resp.estimatedCost}`,
          }
    );
  }

  // BONUS 2: structureRecipe throws → retryCount=1, retryOutcome='failure',
  // falls back to raw-text response.
  {
    const state: OcrTestState = {
      performOcrCalls: 0,
      structureRecipeCalls: [],
    };
    const seams = makeOcrSeams({
      ocr: async () => ({
        content:
          "Some legible OCR text long enough to pass the 20-char minimum.",
        cost: 0.011,
      }),
      retry: async () => {
        throw new Error("simulated vertex ai outage");
      },
      state,
    });

    const resp = await runOcrRecipeImage({
      data: { imageBase64: "/9j/" + "A".repeat(40) },
      authUidHash: "test-hash",
      ...seams,
    });

    const ok =
      resp.success === false &&
      resp.recipe === undefined &&
      resp.rawText !== undefined &&
      resp.rawText.length > 0 &&
      resp.retryCount === 1 &&
      resp.retryOutcome === "failure" &&
      state.structureRecipeCalls.length === 1;
    record(
      "BONUS: structureRecipe throws → retryCount=1, outcome=failure, rawText fallback preserved",
      ok
        ? { ok: true }
        : {
            ok: false,
            detail:
              `success=${resp.success}, recipe=${resp.recipe?.title}, ` +
              `rawTextLen=${resp.rawText?.length ?? 0}, ` +
              `retryCount=${resp.retryCount}, outcome=${resp.retryOutcome}, ` +
              `structureCalls=${state.structureRecipeCalls.length}`,
          }
    );
  }

  // BONUS 3: budget exceeded → no retry, retryCount=0,
  // retryOutcome='skipped_budget'.
  {
    const state: OcrTestState = {
      performOcrCalls: 0,
      structureRecipeCalls: [],
    };
    // First two now() reads (start, OCR-end) put us deep into elapsed
    // territory. The orchestrator asks for now() once when computing
    // remainingMs.
    const baseStart = 0;
    const burnedElapsed =
      OCR_FUNCTION_TIMEOUT_MS - MIN_REMAINING_BUDGET_MS + 1;
    const seams = makeOcrSeams({
      ocr: async () => ({
        content:
          "Some legible OCR text long enough to pass the 20-char minimum.",
        cost: 0.011,
      }),
      retry: async () => ({
        success: true,
        recipe: makeRecipe("should-not-be-called"),
        estimatedCost: 0,
      }),
      state,
      // now() sequence: ocrStartMs, then orchestrator's elapsed check.
      nowSeq: [baseStart, baseStart + burnedElapsed, baseStart + burnedElapsed],
    });

    const resp = await runOcrRecipeImage({
      data: { imageBase64: "/9j/" + "A".repeat(40) },
      authUidHash: "test-hash",
      ...seams,
    });

    const ok =
      resp.success === false &&
      resp.rawText !== undefined &&
      resp.retryCount === 0 &&
      resp.retryOutcome === "skipped_budget" &&
      state.structureRecipeCalls.length === 0;
    record(
      "BONUS: budget exceeded → retryCount=0, outcome=skipped_budget, no retry call",
      ok
        ? { ok: true }
        : {
            ok: false,
            detail:
              `success=${resp.success}, retryCount=${resp.retryCount}, ` +
              `outcome=${resp.retryOutcome}, ` +
              `structureCalls=${state.structureRecipeCalls.length}, ` +
              `rawTextLen=${resp.rawText?.length ?? 0}`,
          }
    );
  }
}

// =============================================================================
// Driver
// =============================================================================

async function main(): Promise<void> {
  console.log("Sprint D2 / BUT-559: OCR rawText auto re-extraction tests");
  console.log("=========================================================");

  await testOrchestrator();
  await testCoreEndToEnd();

  console.log(
    `\n${totalRun - totalFailed}/${totalRun} passed` +
      (totalFailed ? `, ${totalFailed} failed` : "")
  );
  if (totalFailed > 0) process.exit(1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
