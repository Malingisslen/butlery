/**
 * The photo reader returns every recipe on a page. All recipes here are invented.
 * Run: npx ts-node src/__tests__/ocr-photo-recipes.test.ts
 */

import type {
  GenerateContentResponse,
  GenerativeModel,
  VertexAI,
} from "@google-cloud/vertexai";
import { logger } from "firebase-functions/logger";
import { runTests, UnitCase, assertEqual } from "./_unit-runner";
import {
  defaultPerformOcr,
  photoModelFor,
  runOcrRecipeImage,
  type OcrModelCall,
  type OcrPerformResult,
} from "../llm/ocr-recipe-image";
import {
  legacyRecipe,
  normalizeFinishReason,
  parsePhotoRecipesResponse,
  scanLeadingArrayObjects,
} from "../llm/photo-recipes";
import {
  calculateGeminiCost,
  getGeminiClient,
  getTextModel,
  getVisionClient,
  getVisionModel,
  IMAGE_OCR_HANDWRITTEN_SYSTEM_PROMPT,
  IMAGE_OCR_SYSTEM_PROMPT,
  MAX_TOKENS,
  PHOTO_MAX_TOKENS,
  RECIPE_EXTRACTION_SYSTEM_PROMPT,
  TEXT_MODEL,
  TEXT_PROFILE,
  VISION_PRICING,
  VISION_PROFILE,
} from "../llm/gemini-client";

const logged: { message: string; meta?: Record<string, unknown> }[] = [];
for (const level of ["debug", "info", "warn", "error", "log"] as const) {
  (logger as unknown as Record<string, (...a: unknown[]) => void>)[level] = (...args: unknown[]) => {
    logged.push({ message: String(args[0] ?? ""), meta: args[1] as Record<string, unknown> | undefined });
  };
}
// The runner reports through console.log, so console lines are captured AND
// still printed.
const printLine = console.log.bind(console);
for (const level of ["log", "info", "warn", "error"] as const) {
  (console as unknown as Record<string, (...a: unknown[]) => void>)[level] = (
    ...args: unknown[]
  ) => {
    logged.push({ message: args.map((a) => (a instanceof Error ? a.message : String(a))).join(" ") });
    printLine(...args);
  };
}
const allLogText = (): string =>
  logged.map((l) => `${l.message} ${JSON.stringify(l.meta ?? {})}`).join("\n");

function recipe(title: string | null, ingredient: string, extra: Record<string, unknown> = {}) {
  return {
    title,
    description: null,
    portions: 4,
    prepTimeMinutes: 10,
    cookTimeMinutes: 20,
    ingredients: [{ amount: 2, unit: "dl", name: ingredient, preparation: null }],
    instructions: ["Blanda allt."],
    tags: [],
    difficulty: "easy",
    source: null,
    ...extra,
  };
}

const answer = (recipes: unknown[]): string => JSON.stringify({ recipes });

// Distinct strings no log line may contain.
const TITLE_A = "Qwertykaka";
const TITLE_B = "Zxcvbsoppa";
const INGREDIENT_A = "plommonfluff";
const INGREDIENT_B = "krusbärsgrus";
const CONT_INGREDIENT = "lingonsnö";

const TWO_RECIPES = answer([recipe(TITLE_A, INGREDIENT_A), recipe(TITLE_B, INGREDIENT_B)]);

function seams(ocr: () => Promise<OcrPerformResult>, retryRecipe?: unknown) {
  const retryCalls: string[] = [];
  return {
    retryCalls,
    opts: {
      data: { imageBase64: "/9j/" + "A".repeat(40) },
      authUidHash: "test-hash",
      userId: "test-uid",
      performOcr: ocr,
      isAiDisabled: async () => false,
      checkGlobalLimit: async () => true,
      checkUserLimit: async () => true,
      now: () => 1000,
      structureRecipe: async (req: { text: string }) => {
        retryCalls.push(req.text);
        return retryRecipe
          ? { success: true, recipe: retryRecipe as never, estimatedCost: 0.002 }
          : { success: false, estimatedCost: 0.002 };
      },
    },
  };
}

function completeEvent(): Record<string, unknown> | undefined {
  return logged.filter((l) => l.message === "ocr_recipe_image.complete").pop()?.meta;
}

async function requestBody(
  client: VertexAI,
  model: (client: VertexAI) => GenerativeModel,
): Promise<{ url: URL; body: Record<string, unknown> }> {
  (client as unknown as { googleAuth: { getAccessToken: () => Promise<string> } })
    .googleAuth.getAccessToken = async () => "test-token";
  const realFetch = globalThis.fetch;
  let url = "";
  let body = "{}";
  globalThis.fetch = (async (input: unknown, init?: { body?: unknown }) => {
    url = String(input);
    body = String(init?.body ?? "{}");
    throw new Error("stop after capturing the request");
  }) as typeof fetch;
  try {
    await model(client).generateContent("hej").catch(() => undefined);
  } finally {
    globalThis.fetch = realFetch;
  }
  return { url: new URL(url), body: JSON.parse(body) };
}

interface SentConfig {
  maxOutputTokens?: number;
  responseSchema?: {
    properties?: Record<string, { items?: { properties?: Record<string, unknown> } }>;
  };
  thinkingConfig?: unknown;
}

const cases: UnitCase[] = [
  {
    name: "an answer with 0 recipes, or recipes null, gives none and drops none",
    fn: () => {
      const p = parsePhotoRecipesResponse(answer([]));
      assertEqual(p.recipes.length, 0, "recipes");
      assertEqual(p.droppedRecipeCount, 0, "dropped");
      assertEqual(parsePhotoRecipesResponse('{"recipes":null}').recipes.length, 0, "null");
    },
  },
  {
    name: "an answer with 1 recipe gives it",
    fn: () => {
      const p = parsePhotoRecipesResponse(answer([recipe(TITLE_A, INGREDIENT_A)]));
      assertEqual(p.recipes.length, 1, "recipes");
      assertEqual(p.recipes[0].title, TITLE_A, "title");
    },
  },
  {
    name: "an answer with 2 recipes gives both in page order",
    fn: () => {
      const p = parsePhotoRecipesResponse(TWO_RECIPES);
      assertEqual(p.recipes.map((r) => r.title).join("|"), `${TITLE_A}|${TITLE_B}`, "order");
      assertEqual(p.droppedRecipeCount, 0, "dropped");
    },
  },
  {
    name: "an answer with 7 recipes is capped at 6 and the seventh counts as dropped",
    fn: () => {
      const seven = Array.from({ length: 7 }, (_, i) => recipe(`Rätt ${i + 1}`, INGREDIENT_A));
      const p = parsePhotoRecipesResponse(answer(seven));
      assertEqual(p.recipes.length, 6, "recipes");
      assertEqual(p.recipes[5].title, "Rätt 6", "the first six are kept");
      assertEqual(p.droppedRecipeCount, 1, "dropped");
    },
  },
  {
    name: "a continuation without a title is kept with an empty title; an untitled non-continuation is dropped and counted",
    fn: () => {
      const p = parsePhotoRecipesResponse(
        answer([
          recipe("", CONT_INGREDIENT, { continuesFromPreviousPage: true }),
          recipe(null, INGREDIENT_B),
          recipe(TITLE_A, INGREDIENT_A),
        ]),
      );
      assertEqual(p.recipes.length, 2, "recipes");
      assertEqual(p.recipes[0].title, "", "continuation title");
      assertEqual(p.recipes[0].continuesFromPreviousPage, true, "continuation flag");
      assertEqual(p.recipes[1].title, TITLE_A, "titled recipe");
      assertEqual(p.recipes[1].continuesFromPreviousPage, undefined, "no flag on a normal recipe");
      assertEqual(p.droppedRecipeCount, 1, "dropped");
    },
  },
  {
    name: "a steps-only continuation is kept; a continuation with no ingredients and no steps is dropped",
    fn: () => {
      const cont = { continuesFromPreviousPage: true };
      const p = parsePhotoRecipesResponse(
        answer([
          { ...recipe("", CONT_INGREDIENT, cont), ingredients: [] },
          { ...recipe(null, CONT_INGREDIENT, cont), ingredients: [], instructions: ["  "] },
        ]),
      );
      assertEqual(p.recipes.length, 1, "recipes");
      assertEqual(p.recipes[0].ingredients.length, 0, "no placeholder ingredient left");
      assertEqual(p.recipes[0].instructions[0], "Blanda allt.", "steps kept");
      assertEqual(p.recipes[0].title, "", "title");
      assertEqual(p.droppedRecipeCount, 1, "dropped");
    },
  },
  {
    name: "a recipe failing parseRecipeResponse's rules (no ingredients) is dropped and counted",
    fn: () => {
      const p = parsePhotoRecipesResponse(
        answer([{ ...recipe(TITLE_A, INGREDIENT_A), ingredients: [] }, recipe(TITLE_B, INGREDIENT_B)]),
      );
      assertEqual(p.recipes.length, 1, "recipes");
      assertEqual(p.droppedRecipeCount, 1, "dropped");
    },
  },
  {
    name: "a bare one-recipe object (prompt override for the old schema) is one recipe",
    fn: () => {
      const p = parsePhotoRecipesResponse(JSON.stringify(recipe(TITLE_A, INGREDIENT_A)));
      assertEqual(p.recipes.length, 1, "recipes");
      assertEqual(p.recipes[0].title, TITLE_A, "title");
    },
  },
  {
    name: "a MAX_TOKENS answer cut mid-recipe salvages the complete recipes and counts the cut one",
    fn: () => {
      const cut = TWO_RECIPES.slice(0, -2) + ',{"title":"Halv","ingredients":[{"name":"x';
      const p = parsePhotoRecipesResponse(cut, undefined, "MAX_TOKENS");
      assertEqual(p.recipes.length, 2, "recipes");
      assertEqual(p.droppedRecipeCount, 1, "dropped");
      assertEqual(p.salvaged, true, "salvaged");
    },
  },
  {
    name: "a cut answer is salvaged only on MAX_TOKENS, and not when cut inside the first recipe",
    fn: () => {
      const cut = TWO_RECIPES.slice(0, -2) + ',{"title":"Halv"';
      assertEqual(parsePhotoRecipesResponse(cut, undefined, "STOP").recipes.length, 0, "STOP");
      assertEqual(parsePhotoRecipesResponse(cut).recipes.length, 0, "absent");
      const p = parsePhotoRecipesResponse(TWO_RECIPES.slice(0, 40), undefined, "MAX_TOKENS");
      assertEqual(p.recipes.length, 0, "cut in the first");
      assertEqual(p.salvaged, false, "salvaged");
    },
  },
  {
    name: "the scanner ignores braces and escaped quotes inside strings",
    fn: () => {
      const body = '{"a":"} {\\" }"},{"b":{"c":1}} , {"d":"x';
      const r = scanLeadingArrayObjects(body);
      assertEqual(r.objects.length, 2, "objects");
      assertEqual(r.objects[0], '{"a":"} {\\" }"}', "first");
      assertEqual(r.objects[1], '{"b":{"c":1}}', "second");
      assertEqual(r.incompleteTail, true, "tail");
      assertEqual(scanLeadingArrayObjects('{"a":1}]}').incompleteTail, false, "closed array");
    },
  },
  {
    name: "finish reasons are the SDK's fixed values only",
    fn: () => {
      assertEqual(normalizeFinishReason("MAX_TOKENS"), "MAX_TOKENS", "known");
      assertEqual(normalizeFinishReason("STOP"), "STOP", "stop");
      assertEqual(normalizeFinishReason(`${TITLE_A}`), "UNRECOGNIZED", "free text");
      assertEqual(normalizeFinishReason(undefined), undefined, "absent");
    },
  },
  {
    name: "the first titled recipe is never a continuation, even a titled one",
    fn: () => {
      const p = parsePhotoRecipesResponse(
        answer([
          recipe("Rubrik", CONT_INGREDIENT, { continuesFromPreviousPage: true }),
          recipe(TITLE_B, INGREDIENT_B),
        ]),
      );
      assertEqual(legacyRecipe(p.recipes)?.title, TITLE_B, "recipe");
    },
  },

  {
    name: "two recipes: recipes carries both, recipe is the first titled, the complete event counts them",
    fn: async () => {
      logged.length = 0;
      const content = answer([
        recipe("", CONT_INGREDIENT, { continuesFromPreviousPage: true }),
        recipe(TITLE_A, INGREDIENT_A),
        recipe(TITLE_B, INGREDIENT_B),
        recipe(null, INGREDIENT_B),
      ]);
      const { opts, retryCalls } = seams(async () => ({ content, cost: 0.01, finishReason: "STOP" }));
      const r = await runOcrRecipeImage(opts);
      assertEqual(r.success, true, "success");
      assertEqual(r.recipes?.length, 3, "recipes");
      assertEqual(r.recipe?.title, TITLE_A, "recipe");
      assertEqual(retryCalls.length, 0, "no retry");
      const e = completeEvent();
      assertEqual(e?.recipeCount, 3, "recipeCount");
      assertEqual(e?.droppedRecipeCount, 1, "droppedRecipeCount");
      assertEqual(r.droppedRecipeCount, e?.droppedRecipeCount, "response matches the event");
      assertEqual(Number.isInteger(e?.recipeCount) && Number.isInteger(e?.droppedRecipeCount), true, "integers");
      assertEqual(e?.finishReason, "STOP", "finishReason");
    },
  },
  {
    name: "0 valid recipes takes today's retry path; its recipe becomes recipes = [recipe]",
    fn: async () => {
      logged.length = 0;
      const retryRecipe = recipe(TITLE_B, INGREDIENT_B);
      const { opts, retryCalls } = seams(
        async () => ({ content: answer([recipe(null, INGREDIENT_A)]), cost: 0.01 }),
        retryRecipe,
      );
      const r = await runOcrRecipeImage(opts);
      assertEqual(retryCalls.length, 1, "retry ran");
      assertEqual(r.retryOutcome, "success", "retryOutcome");
      assertEqual(r.recipes?.length, 1, "recipes");
      assertEqual(r.recipes?.[0], r.recipe, "recipes = [recipe]");
      assertEqual(completeEvent()?.recipeCount, 1, "recipeCount");
      assertEqual(completeEvent()?.droppedRecipeCount, 1, "droppedRecipeCount");
      assertEqual(r.droppedRecipeCount, 1, "response droppedRecipeCount");
    },
  },
  {
    name: "a MAX_TOKENS answer cut right after a complete recipe still counts one as possibly dropped",
    fn: async () => {
      logged.length = 0;
      const cut = TWO_RECIPES.slice(0, -2) + ",";
      const { opts } = seams(async () => ({ content: cut, cost: 0.01, finishReason: "MAX_TOKENS" }));
      const r = await runOcrRecipeImage(opts);
      assertEqual(r.recipes?.length, 2, "recipes");
      assertEqual(r.droppedRecipeCount, 1, "response droppedRecipeCount");
    },
  },
  {
    name: "a truncated MAX_TOKENS answer with complete recipes returns them without the retry",
    fn: async () => {
      logged.length = 0;
      const cut = TWO_RECIPES.slice(0, -2) + ',{"title":"Halv';
      const { opts, retryCalls } = seams(async () => ({ content: cut, cost: 0.01, finishReason: "MAX_TOKENS" }));
      const r = await runOcrRecipeImage(opts);
      assertEqual(retryCalls.length, 0, "no retry");
      assertEqual(r.recipes?.length, 2, "recipes");
      const e = completeEvent();
      assertEqual(e?.finishReason, "MAX_TOKENS", "finishReason");
      assertEqual(e?.droppedRecipeCount, 1, "droppedRecipeCount");
      assertEqual(r.droppedRecipeCount, 1, "response droppedRecipeCount");
      assertEqual(e?.salvaged, true, "salvaged");
    },
  },
  {
    name: "a truncated MAX_TOKENS answer with nothing complete falls back to the retry",
    fn: async () => {
      const cut = TWO_RECIPES.slice(0, 60);
      const { opts, retryCalls } = seams(async () => ({ content: cut, cost: 0.01, finishReason: "MAX_TOKENS" }));
      const r = await runOcrRecipeImage(opts);
      assertEqual(retryCalls.length, 1, "retry ran");
      assertEqual(retryCalls[0], cut, "retry gets the raw answer");
      assertEqual(r.success, false, "retry failed in this seam");
      assertEqual(r.rawText, cut, "rawText as today");
      assertEqual(r.droppedRecipeCount, 1, "the cut-off recipe is reported after a failed retry");
    },
  },
  {
    name: "no log line or console line carries a recipe title or ingredient text",
    fn: async () => {
      logged.length = 0;
      const prose = `${TITLE_A}: 2 dl ${INGREDIENT_A}. Blanda allt väl.`;
      const cut = TWO_RECIPES.slice(0, -2) + ',{"title":"' + TITLE_B;
      for (const [content, finishReason, retry] of [
        [TWO_RECIPES, "STOP", undefined],
        [cut, "MAX_TOKENS", undefined],
        [prose, "STOP", recipe(TITLE_B, INGREDIENT_B)],
        [prose, "STOP", undefined],
      ] as const) {
        await runOcrRecipeImage(seams(async () => ({ content, cost: 0.01, finishReason }), retry).opts);
      }
      const text = allLogText();
      assertEqual(logged.length > 0, true, "the spy captured lines");
      for (const secret of [TITLE_A, TITLE_B, INGREDIENT_A, INGREDIENT_B]) {
        assertEqual(text.includes(secret), false, `logs contain ${secret}`);
      }
    },
  },
  {
    name: "a continuation-only page gives the legacy recipe field that continuation",
    fn: async () => {
      const content = answer([{ ...recipe("", CONT_INGREDIENT, { continuesFromPreviousPage: true }), ingredients: [] }]);
      const { opts, retryCalls } = seams(async () => ({ content, cost: 0.01 }));
      const r = await runOcrRecipeImage(opts);
      assertEqual(retryCalls.length, 0, "no retry");
      assertEqual(r.success, true, "success");
      assertEqual(r.recipes?.length, 1, "recipes");
      assertEqual(r.recipe, r.recipes?.[0], "recipe = the continuation");
      assertEqual(r.droppedRecipeCount, 0, "response droppedRecipeCount is 0 when none");
    },
  },

  {
    name: "the vision model sends the photo schema and PHOTO_MAX_TOKENS to the EU host",
    fn: async () => {
      process.env.GOOGLE_CLOUD_PROJECT = "ocr-photo-recipes-test";
      const { url, body } = await requestBody(getVisionClient(), getVisionModel);
      const cfg = body.generationConfig as SentConfig;
      assertEqual(url.host, "aiplatform.eu.rep.googleapis.com", "host");
      assertEqual(PHOTO_MAX_TOKENS, 4000, "PHOTO_MAX_TOKENS");
      assertEqual(cfg.maxOutputTokens, PHOTO_MAX_TOKENS, "maxOutputTokens");
      const item = cfg.responseSchema?.properties?.recipes?.items?.properties;
      assertEqual(item !== undefined && "continuesFromPreviousPage" in item && "ingredients" in item, true, "photo schema");
      const viaProfile = await requestBody(getVisionClient(), () => photoModelFor(VISION_PROFILE));
      assertEqual(viaProfile.url.host, "aiplatform.eu.rep.googleapis.com", "photoModelFor(VISION_PROFILE)");
    },
  },
  {
    name: "the NOT_FOUND fallback reads in europe-west4 with the text model and the photo schema",
    fn: async () => {
      process.env.GOOGLE_CLOUD_PROJECT = "ocr-photo-recipes-test";
      const { url, body } = await requestBody(getGeminiClient(), () => photoModelFor(TEXT_PROFILE));
      const cfg = body.generationConfig as SentConfig;
      assertEqual(url.host, "europe-west4-aiplatform.googleapis.com", "host");
      assertEqual(url.pathname.includes("/locations/europe-west4/"), true, `path ${url.pathname}`);
      assertEqual(url.pathname.includes(`models/${TEXT_MODEL}`), true, `model ${url.pathname}`);
      assertEqual(cfg.maxOutputTokens, PHOTO_MAX_TOKENS, "maxOutputTokens");
      assertEqual(cfg.responseSchema?.properties?.recipes !== undefined, true, "photo schema");
      assertEqual(cfg.thinkingConfig, undefined, "no vision extras");
    },
  },
  {
    name: "the text model keeps RECIPE_SCHEMA and MAX_TOKENS 2000",
    fn: async () => {
      process.env.GOOGLE_CLOUD_PROJECT = "ocr-photo-recipes-test";
      const { body } = await requestBody(getGeminiClient(), getTextModel);
      const cfg = body.generationConfig as SentConfig & {
        responseSchema?: { required?: string[] };
      };
      assertEqual(MAX_TOKENS, 2000, "MAX_TOKENS");
      assertEqual(cfg.maxOutputTokens, 2000, "maxOutputTokens");
      assertEqual(cfg.responseSchema?.properties?.recipes, undefined, "no recipes array");
      assertEqual(cfg.responseSchema?.properties?.title !== undefined, true, "one-recipe shape");
      assertEqual(cfg.responseSchema?.required?.join(","), "title,ingredients,instructions,tags", "required");
    },
  },
  {
    name: "both photo prompts ask for every recipe and the continuation flag; the text prompt does not",
    fn: () => {
      for (const p of [IMAGE_OCR_SYSTEM_PROMPT, IMAGE_OCR_HANDWRITTEN_SYSTEM_PROMPT]) {
        assertEqual(p.includes("Läs varje recept på bilden som ett eget recept"), true, "rule");
        assertEqual(p.includes("continuesFromPreviousPage=true"), true, "flag");
      }
      assertEqual(RECIPE_EXTRACTION_SYSTEM_PROMPT.includes("continuesFromPreviousPage"), false, "text prompt");
    },
  },
  {
    name: "the photo user prompt asks for all recipes and the finish reason is threaded out",
    fn: async () => {
      let sent = "";
      const call: OcrModelCall = async (_profile, request) => {
        sent = JSON.stringify(request.contents);
        return {
          candidates: [{ index: 0, finishReason: "MAX_TOKENS", content: { role: "model", parts: [{ text: TWO_RECIPES }] } }],
        } as unknown as GenerateContentResponse;
      };
      const r = await defaultPerformOcr({ imageBase64: "/9j/AAAA" }, call);
      assertEqual(sent.includes("extrahera alla recept"), true, "user prompt");
      assertEqual(r.finishReason, "MAX_TOKENS", "finishReason");
    },
  },
  {
    name: "4000 tokens out + 3000 in on the vision rate stays under the 0.01 floor",
    fn: () => {
      const usage = { promptTokenCount: 3000, candidatesTokenCount: 4000 };
      const raw = calculateGeminiCost(usage, 0, VISION_PRICING);
      assertEqual(raw < 0.01, true, `raw ${raw}`);
      assertEqual(calculateGeminiCost(usage, 0.01, VISION_PRICING), 0.01, "floored");
    },
  },
  {
    name: "thought tokens are priced as output and still raise the warning",
    fn: async () => {
      logged.length = 0;
      const call: OcrModelCall = async () =>
        ({
          candidates: [{ index: 0, content: { role: "model", parts: [{ text: TWO_RECIPES }] } }],
          usageMetadata: { promptTokenCount: 3000, candidatesTokenCount: 4000, thoughtsTokenCount: 2000 },
        }) as unknown as GenerateContentResponse;
      const r = await defaultPerformOcr({ imageBase64: "/9j/AAAA" }, call);
      // 3000 * 0.275 / 1e6 + (4000 + 2000) * 1.65 / 1e6
      assertEqual(Math.abs(r.cost - 0.010725) < 1e-9, true, `cost ${r.cost}`);
      assertEqual(
        logged.some((l) => l.message === "ocr_recipe_image.vision_thoughts_billed"),
        true,
        "warning",
      );
    },
  },
];

runTests("ocr-photo-recipes", cases);
