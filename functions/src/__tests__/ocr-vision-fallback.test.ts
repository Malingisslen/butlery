/**
 * The photo call runs on the vision profile and falls back to the text
 * profile once, only when Vertex answers NOT_FOUND. The id of the model that
 * actually answered is what the OCR events and response carry.
 *
 * Run: npx ts-node src/__tests__/ocr-vision-fallback.test.ts
 */

import {
  ClientError,
  GoogleApiError,
  GoogleGenerativeAIError,
  type GenerateContentResponse,
} from "@google-cloud/vertexai";
import { logger } from "firebase-functions/logger";
import { runTests, UnitCase, assertEqual } from "./_unit-runner";
import {
  defaultPerformOcr,
  runOcrRecipeImage,
  type OcrModelCall,
  type OcrPerformResult,
} from "../llm/ocr-recipe-image";
import {
  MODEL_ID,
  TEXT_PROFILE,
  TEXT_MODEL,
  VISION_MODEL,
  VISION_PROFILE,
  type ModelProfile,
} from "../llm/gemini-client";

interface CapturedLog {
  message: string;
  meta?: Record<string, unknown>;
}
const captured: CapturedLog[] = [];
for (const level of ["info", "warn", "error"] as const) {
  (logger as unknown as Record<string, (...args: unknown[]) => void>)[level] = (
    ...args: unknown[]
  ) => {
    captured.push({
      message: String(args[0] ?? ""),
      meta: (args[1] as Record<string, unknown>) ?? undefined,
    });
  };
}

const RECIPE_JSON = JSON.stringify({
  title: "Pannkakor",
  description: null,
  portions: 4,
  prepTimeMinutes: 5,
  cookTimeMinutes: 15,
  ingredients: [{ amount: 3, unit: "dl", name: "mjölk", preparation: null }],
  instructions: ["Vispa ihop allt."],
  tags: [],
  difficulty: "easy",
  source: null,
});

function okResponse(): GenerateContentResponse {
  return {
    candidates: [
      { index: 0, content: { role: "model", parts: [{ text: RECIPE_JSON }] } },
    ],
    // Large enough to clear the 0.01 floor, so the two price tables give
    // different costs.
    usageMetadata: { promptTokenCount: 100_000, candidatesTokenCount: 10_000 },
  } as GenerateContentResponse;
}

// The shape the SDK's throwErrorIfNotOK builds for a 4xx answer.
function vertexClientError(code: number, status: string): ClientError {
  const body = { error: { code, message: "model not served", status } };
  return new ClientError(
    `got status: ${code} ${status}. ${JSON.stringify(body)}`,
    new GoogleApiError(body.error.message, code, status, undefined),
  );
}

function recordingCall(
  firstError: Error | null,
): { call: OcrModelCall; profiles: ModelProfile[] } {
  const profiles: ModelProfile[] = [];
  const call: OcrModelCall = async (profile) => {
    profiles.push(profile);
    if (profiles.length === 1 && firstError) throw firstError;
    return okResponse();
  };
  return { call, profiles };
}

const ARGS = { imageBase64: "/9j/" + "A".repeat(40) };

async function expectRejects(p: Promise<unknown>, msg: string): Promise<void> {
  let threw = false;
  await p.catch(() => {
    threw = true;
  });
  assertEqual(threw, true, msg);
}

function okSeams(ocr: () => Promise<OcrPerformResult>) {
  return {
    authUidHash: "test-hash",
    userId: "test-uid",
    performOcr: ocr,
    isAiDisabled: async () => false,
    checkGlobalLimit: async () => true,
    checkUserLimit: async () => true,
    now: () => 1000,
  };
}

const cases: UnitCase[] = [
  {
    name: "a vision success calls only the vision profile and stamps VISION_MODEL",
    fn: async () => {
      const { call, profiles } = recordingCall(null);
      const r = await defaultPerformOcr(ARGS, call);
      assertEqual(profiles.length, 1, "calls");
      assertEqual(profiles[0], VISION_PROFILE, "profile");
      assertEqual(r.modelId, VISION_MODEL, "modelId");
      // 100000 * 0.275 / 1e6 + 10000 * 1.65 / 1e6
      assertEqual(Math.abs(r.cost - 0.044) < 1e-9, true, `vision rate, got ${r.cost}`);
    },
  },
  {
    name: "NOT_FOUND from Vertex retries once on the text profile and stamps its id",
    fn: async () => {
      captured.length = 0;
      const { call, profiles } = recordingCall(
        vertexClientError(404, "NOT_FOUND"),
      );
      const r = await defaultPerformOcr(ARGS, call);
      assertEqual(profiles.length, 2, "calls");
      assertEqual(profiles[0], VISION_PROFILE, "first profile");
      assertEqual(profiles[1], TEXT_PROFILE, "second profile");
      assertEqual(r.modelId, TEXT_MODEL, "modelId");
      // 100000 * 0.10 / 1e6 + 10000 * 0.40 / 1e6
      assertEqual(Math.abs(r.cost - 0.014) < 1e-9, true, `text rate, got ${r.cost}`);
      const warn = captured.find(
        (l) => l.message === "ocr_recipe_image.vision_model_not_found",
      );
      assertEqual(warn?.meta?.modelId, TEXT_MODEL, "warn names the used model");
    },
  },
  {
    name: "a NOT_FOUND from the text fallback is not retried again",
    fn: async () => {
      const profiles: ModelProfile[] = [];
      const call: OcrModelCall = async (profile) => {
        profiles.push(profile);
        throw vertexClientError(404, "NOT_FOUND");
      };
      await expectRejects(defaultPerformOcr(ARGS, call), "rejects");
      assertEqual(profiles.length, 2, "calls");
    },
  },
  {
    name: "a 403 from Vertex does not fall back",
    fn: async () => {
      const { call, profiles } = recordingCall(
        vertexClientError(403, "PERMISSION_DENIED"),
      );
      await expectRejects(defaultPerformOcr(ARGS, call), "rejects");
      assertEqual(profiles.length, 1, "calls");
    },
  },
  {
    name: "a 5xx from Vertex does not fall back",
    fn: async () => {
      const { call, profiles } = recordingCall(
        new GoogleGenerativeAIError("got status: 500 Internal Server Error. {}"),
      );
      await expectRejects(defaultPerformOcr(ARGS, call), "rejects");
      assertEqual(profiles.length, 1, "calls");
    },
  },
  {
    name: "the response and complete event carry the model the photo call used",
    fn: async () => {
      captured.length = 0;
      const r = await runOcrRecipeImage({
        data: ARGS,
        ...okSeams(async () => ({
          content: RECIPE_JSON,
          cost: 0.01,
          modelId: TEXT_MODEL,
        })),
      });
      assertEqual(r.modelId, TEXT_MODEL, "response modelId");
      const complete = captured.find(
        (l) => l.message === "ocr_recipe_image.complete",
      );
      assertEqual(complete?.meta?.modelId, TEXT_MODEL, "event modelId");
    },
  },
  {
    name: "a seam without modelId is stamped VISION_MODEL",
    fn: async () => {
      captured.length = 0;
      const r = await runOcrRecipeImage({
        data: ARGS,
        ...okSeams(async () => ({ content: RECIPE_JSON, cost: 0.01 })),
      });
      assertEqual(r.modelId, VISION_MODEL, "response modelId");
      const complete = captured.find(
        (l) => l.message === "ocr_recipe_image.complete",
      );
      assertEqual(complete?.meta?.modelId, VISION_MODEL, "event modelId");
    },
  },
  {
    name: "a recipe produced by the structureRecipe retry is stamped the text id",
    fn: async () => {
      const r = await runOcrRecipeImage({
        data: ARGS,
        ...okSeams(async () => ({
          content: "Pannkakor: 3 dl mjölk, 2 ägg. Vispa ihop allt och stek.",
          cost: 0.01,
          modelId: VISION_MODEL,
        })),
        structureRecipe: async () => ({
          success: true,
          recipe: JSON.parse(RECIPE_JSON),
          estimatedCost: 0.002,
        }),
      });
      assertEqual(r.retryOutcome, "success", "retry ran");
      assertEqual(r.modelId, MODEL_ID, "response modelId");
    },
  },
];

runTests("ocr-vision-fallback", cases);
