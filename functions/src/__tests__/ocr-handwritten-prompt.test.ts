/**
 * BUT-684: handwritten-recipe OCR prompt selection.
 *
 * Coverage:
 *   Handler (runOcrRecipeImage):
 *     [1] isHandwritten: true  → performOcr receives the HANDWRITTEN prompt
 *     [2] isHandwritten absent → performOcr receives the PRINTED prompt (regression)
 *     [3] isHandwritten: false → performOcr receives the PRINTED prompt (regression)
 *   Prompts config round-trip (getPromptsConfig):
 *     [4] fallback bundle exposes the compiled-in handwritten prompt
 *     [5] Firestore override with the new field → remote value is used
 *     [6] Firestore doc missing the new field (pre-existing v2.1.0 shape) still
 *         validates as source:firestore, keeps its other overrides, and yields
 *         the compiled-in handwritten prompt via per-field fallback
 *
 * The handler has no test seam for getPromptsConfig, so [1]–[3] run against the
 * compiled-in fallback bundle (admin is not initialized → the Firestore read
 * rejects → getPromptsConfig falls back). That makes the selected prompt
 * deterministically equal to the imported constants.
 *
 * Uses the repo's hand-rolled harness (no jest). Run with:
 *   npx ts-node src/__tests__/ocr-handwritten-prompt.test.ts
 */

import { runOcrRecipeImage } from "../llm/ocr-recipe-image";
import {
  getPromptsConfig,
  __resetPromptsCacheForTests,
} from "../llm/prompts-config";
import {
  IMAGE_OCR_SYSTEM_PROMPT,
  IMAGE_OCR_HANDWRITTEN_SYSTEM_PROMPT,
  OCR_RETRY_SYSTEM_PROMPT_RULES,
  RECIPE_EXTRACTION_SYSTEM_PROMPT,
  UNREADABLE_MARKER,
} from "../llm/gemini-client";
import * as geminiClient from "../llm/gemini-client";
import type { GenerativeModel, VertexAI } from "@google-cloud/vertexai";
import {
  __test__ as structureRecipeInternals,
  runStructureRecipe,
} from "../llm/structure-recipe";

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

// A valid recipe JSON so the OCR happy-path parses and never enters the
// structureRecipe retry path (which would call the real collaborator).
const VALID_RECIPE_JSON = JSON.stringify({
  title: "Farmors pannkakor",
  description: null,
  portions: 4,
  prepTimeMinutes: 5,
  cookTimeMinutes: 10,
  ingredients: [{ amount: 3, unit: "dl", name: "mjöl", preparation: null }],
  instructions: ["Vispa ihop.", "Stek i smör."],
  tags: [],
  difficulty: "easy",
  source: null,
});

/**
 * Run the OCR core with a performOcr seam that records which system prompt the
 * handler chose. Uses imageBase64 so the URL validator path is skipped.
 */
async function captureSelectedPrompt(
  isHandwritten?: boolean
): Promise<string | undefined> {
  __resetPromptsCacheForTests();
  let selected: string | undefined;
  // The prompt is captured inside the performOcr seam. captureLlmSample() is
  // best-effort and swallows the missing-default-app case in this unit context,
  // so runOcrRecipeImage completes normally; the assertion is on `selected`.
  await runOcrRecipeImage({
    data: {
      imageBase64: "/9j/fakebase64jpegdata",
      isHandwritten,
    },
    authUidHash: "uid-hash-hw-test",
    userId: "uid-hw-test",
    isAiDisabled: async () => false,
    performOcr: async (args) => {
      selected = args.systemPrompt;
      return { content: VALID_RECIPE_JSON, cost: 0.01 };
    },
    now: () => 0,
  });
  return selected;
}

// =============================================================================
// Handler tests
// =============================================================================

async function testHandwrittenSelectsHandwrittenPrompt(): Promise<void> {
  console.log("\n[1] isHandwritten: true → handwritten prompt selected");
  const selected = await captureSelectedPrompt(true);
  record(
    "performOcr receives IMAGE_OCR_HANDWRITTEN_SYSTEM_PROMPT",
    selected === IMAGE_OCR_HANDWRITTEN_SYSTEM_PROMPT
      ? { ok: true }
      : {
          ok: false,
          detail: `selected !== handwritten prompt (matchedPrinted=${
            selected === IMAGE_OCR_SYSTEM_PROMPT
          })`,
        }
  );
}

async function testAbsentSelectsPrintedPrompt(): Promise<void> {
  console.log("\n[2] isHandwritten absent → printed prompt (regression)");
  const selected = await captureSelectedPrompt(undefined);
  record(
    "performOcr receives IMAGE_OCR_SYSTEM_PROMPT when flag omitted",
    selected === IMAGE_OCR_SYSTEM_PROMPT
      ? { ok: true }
      : {
          ok: false,
          detail: `selected !== printed prompt (matchedHandwritten=${
            selected === IMAGE_OCR_HANDWRITTEN_SYSTEM_PROMPT
          })`,
        }
  );
}

async function testFalseSelectsPrintedPrompt(): Promise<void> {
  console.log("\n[3] isHandwritten: false → printed prompt (regression)");
  const selected = await captureSelectedPrompt(false);
  record(
    "performOcr receives IMAGE_OCR_SYSTEM_PROMPT when flag is false",
    selected === IMAGE_OCR_SYSTEM_PROMPT
      ? { ok: true }
      : {
          ok: false,
          detail: `selected !== printed prompt (matchedHandwritten=${
            selected === IMAGE_OCR_HANDWRITTEN_SYSTEM_PROMPT
          })`,
        }
  );
}

// =============================================================================
// Prompts-config round-trip tests
// =============================================================================

function validRemoteDocWithHandwritten(): Record<string, unknown> {
  return {
    recipeExtractionSystemPrompt: "REMOTE_EXTRACTION_PROMPT",
    recipeEnhancementSystemPrompt: "REMOTE_ENHANCEMENT_PROMPT",
    imageOcrSystemPrompt: "REMOTE_OCR_PROMPT",
    imageOcrHandwrittenSystemPrompt: "REMOTE_HANDWRITTEN_OCR_PROMPT",
    spokenContentSystemPrompt: "REMOTE_SPOKEN_PROMPT",
    ingredientLineSystemPrompt: "REMOTE_INGREDIENT_PROMPT",
    promptVersion: "9.9.9-remote",
  };
}

async function testFallbackExposesHandwritten(): Promise<void> {
  console.log("\n[4] fallback bundle exposes compiled-in handwritten prompt");
  __resetPromptsCacheForTests();
  const result = await getPromptsConfig({
    loader: async () => undefined,
    now: () => 0,
  });
  record(
    "fallback imageOcrHandwrittenSystemPrompt === compiled-in constant",
    result.source === "fallback" &&
      result.imageOcrHandwrittenSystemPrompt ===
        IMAGE_OCR_HANDWRITTEN_SYSTEM_PROMPT
      ? { ok: true }
      : { ok: false, detail: `source=${result.source}` }
  );
}

async function testFirestoreOverrideRoundTrips(): Promise<void> {
  console.log("\n[5] Firestore override with the new field round-trips");
  __resetPromptsCacheForTests();
  const result = await getPromptsConfig({
    loader: async () => validRemoteDocWithHandwritten(),
    now: () => 0,
  });
  record(
    "remote imageOcrHandwrittenSystemPrompt is used when present",
    result.source === "firestore" &&
      result.imageOcrHandwrittenSystemPrompt ===
        "REMOTE_HANDWRITTEN_OCR_PROMPT" &&
      result.imageOcrSystemPrompt === "REMOTE_OCR_PROMPT"
      ? { ok: true }
      : {
          ok: false,
          detail: `source=${result.source}, handwritten=${result.imageOcrHandwrittenSystemPrompt}`,
        }
  );
}

async function testPreExistingDocKeepsOverridesWithPerFieldFallback(): Promise<void> {
  console.log(
    "\n[6] Pre-existing doc (no handwritten field) stays firestore + per-field fallback"
  );
  __resetPromptsCacheForTests();
  // The exact shape a v2.1.0 production `system/prompts` override doc has —
  // valid under the original 6 keys, no handwritten field.
  const doc = validRemoteDocWithHandwritten();
  delete doc.imageOcrHandwrittenSystemPrompt;
  const result = await getPromptsConfig({
    loader: async () => doc,
    now: () => 0,
  });
  record(
    "backward-compat: doc validates as firestore, keeps other overrides, " +
      "handwritten falls back to compiled-in const (no whole-bundle revert)",
    result.source === "firestore" &&
      result.imageOcrSystemPrompt === "REMOTE_OCR_PROMPT" &&
      result.recipeExtractionSystemPrompt === "REMOTE_EXTRACTION_PROMPT" &&
      result.promptVersion === "9.9.9-remote" &&
      result.imageOcrHandwrittenSystemPrompt ===
        IMAGE_OCR_HANDWRITTEN_SYSTEM_PROMPT
      ? { ok: true }
      : {
          ok: false,
          detail: `source=${result.source}, printed=${result.imageOcrSystemPrompt}, handwritten=${result.imageOcrHandwrittenSystemPrompt}`,
        }
  );
}

// [7] BUT-2158: both image prompts tell the model to write the marker the app
// reads, never to guess. The app's UnreadLineDetector.unreadMarker must equal
// it byte for byte.
function testImagePromptsMarkUnreadableNeverGuess(): void {
  record(
    "[7] the marker is the app's",
    UNREADABLE_MARKER === "[oläsligt]"
      ? { ok: true }
      : { ok: false, detail: `marker=${UNREADABLE_MARKER}` }
  );
  for (const [name, prompt] of [
    ["printed", IMAGE_OCR_SYSTEM_PROMPT],
    ["handwritten", IMAGE_OCR_HANDWRITTEN_SYSTEM_PROMPT],
  ] as const) {
    record(
      `[7] ${name} prompt asks for the marker, keeps the line, never guesses`,
      prompt.includes(UNREADABLE_MARKER) &&
        prompt.includes("Gissa aldrig") &&
        prompt.includes("Hoppa inte över raden") &&
        prompt.includes(`skriv ${UNREADABLE_MARKER} i preparation`) &&
        !prompt.includes("gissa det mest sannolika")
        ? { ok: true }
        : { ok: false, detail: prompt }
    );
  }
}

// [8] BUT-2317: the OCR retry re-reads the image reader's raw text with the
// text extraction prompt. It gets the image prompts' unreadable rule word for
// word, and only on the retry.
function testOcrRetryKeepsUnreadableMarker(): void {
  const ruleLine = OCR_RETRY_SYSTEM_PROMPT_RULES.split("\n").find((l) =>
    l.startsWith("- Gissa aldrig")
  );
  record(
    "[8] retry rules carry the image prompts' unreadable rule verbatim",
    ruleLine !== undefined &&
      IMAGE_OCR_SYSTEM_PROMPT.includes(ruleLine) &&
      IMAGE_OCR_HANDWRITTEN_SYSTEM_PROMPT.includes(ruleLine) &&
      ruleLine.includes(`skriv ${UNREADABLE_MARKER} i preparation`) &&
      ruleLine.includes("Hoppa inte över raden")
      ? { ok: true }
      : { ok: false, detail: OCR_RETRY_SYSTEM_PROMPT_RULES }
  );
  record(
    "[8] retry rules tell the model to keep a marker already in the text",
    OCR_RETRY_SYSTEM_PROMPT_RULES.includes(
      `Texten kan innehålla ${UNREADABLE_MARKER}`
    ) && OCR_RETRY_SYSTEM_PROMPT_RULES.includes("Ersätt det aldrig med en gissning")
      ? { ok: true }
      : { ok: false, detail: OCR_RETRY_SYSTEM_PROMPT_RULES }
  );

  const { extractionSystemPrompt } = structureRecipeInternals;
  const base = "REMOTE_EXTRACTION_PROMPT";
  const retry = extractionSystemPrompt(base, true);
  record(
    "[8] the retry's extraction prompt ends with the rules, after any override",
    retry === `${base}\n\n${OCR_RETRY_SYSTEM_PROMPT_RULES}`
      ? { ok: true }
      : { ok: false, detail: retry }
  );
  record(
    "[8] a text or URL import keeps the extraction prompt unchanged",
    extractionSystemPrompt(base, undefined) === base &&
      extractionSystemPrompt(base, false) === base &&
      !RECIPE_EXTRACTION_SYSTEM_PROMPT.includes(UNREADABLE_MARKER)
      ? { ok: true }
      : { ok: false }
  );
}

// [9] BUT-2317: runStructureRecipe sends the retry rules as the system
// instruction when, and only when, the call carries fromImageOcr. Same module
// hijack as gemini-cache-telemetry.test.ts.
async function testRunStructureRecipeSendsRetryRules(): Promise<void> {
  const mutable = geminiClient as {
    getGeminiClient: () => VertexAI;
    getTextModel: (client: VertexAI) => GenerativeModel;
  };
  const originalGetClient = geminiClient.getGeminiClient;
  const originalGetTextModel = geminiClient.getTextModel;
  const instructions: unknown[] = [];
  const recipeJson = JSON.stringify({
    title: "Pannkakor",
    description: null,
    portions: 4,
    prepTimeMinutes: 5,
    cookTimeMinutes: 15,
    ingredients: [
      { amount: null, unit: "dl", name: "mjölk", preparation: UNREADABLE_MARKER },
    ],
    instructions: ["Vispa ihop allt."],
    tags: [],
    difficulty: "easy",
    source: null,
  });
  const fakeModel = {
    generateContent: async (req: { systemInstruction?: unknown }) => {
      instructions.push(req.systemInstruction);
      return {
        response: {
          candidates: [
            { content: { role: "model", parts: [{ text: recipeJson }] } },
          ],
          usageMetadata: { promptTokenCount: 1, candidatesTokenCount: 1 },
        },
      };
    },
  } as unknown as GenerativeModel;

  try {
    // Fill the prompts cache with the compiled bundle so no Firestore read runs.
    __resetPromptsCacheForTests();
    await getPromptsConfig({ loader: async () => undefined });
    mutable.getGeminiClient = () => ({}) as unknown as VertexAI;
    mutable.getTextModel = () => fakeModel;

    const text = `Pannkakor: ${UNREADABLE_MARKER} dl mjölk, 2 ägg. Vispa ihop allt.`;
    const deps = {
      loadKillSwitch: async () => ({ aiEnabled: true, llmParserEnabled: true }),
    };
    await runStructureRecipe(
      { text, mode: "extract", fromImageOcr: true },
      "h",
      deps
    );
    await runStructureRecipe({ text, mode: "extract" }, "h", deps);

    const [retry, plain] = instructions;
    record(
      "[9] runStructureRecipe with fromImageOcr ends its system instruction with the retry rules",
      typeof retry === "string" &&
        retry.endsWith(OCR_RETRY_SYSTEM_PROMPT_RULES)
        ? { ok: true }
        : { ok: false, detail: String(retry) }
    );
    record(
      "[9] runStructureRecipe without the flag sends no retry rules",
      typeof plain === "string" &&
        !plain.includes(OCR_RETRY_SYSTEM_PROMPT_RULES) &&
        plain.includes(RECIPE_EXTRACTION_SYSTEM_PROMPT)
        ? { ok: true }
        : { ok: false, detail: String(plain) }
    );
  } finally {
    mutable.getGeminiClient = originalGetClient;
    mutable.getTextModel = originalGetTextModel;
    __resetPromptsCacheForTests();
  }
}

// =============================================================================
// Driver
// =============================================================================

async function main(): Promise<void> {
  console.log("BUT-684: handwritten OCR prompt selection tests");
  console.log("===============================================");

  await testHandwrittenSelectsHandwrittenPrompt();
  await testAbsentSelectsPrintedPrompt();
  await testFalseSelectsPrintedPrompt();
  await testFallbackExposesHandwritten();
  await testFirestoreOverrideRoundTrips();
  await testPreExistingDocKeepsOverridesWithPerFieldFallback();
  testImagePromptsMarkUnreadableNeverGuess();
  testOcrRetryKeepsUnreadableMarker();
  await testRunStructureRecipeSendsRetryRules();

  __resetPromptsCacheForTests();

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
