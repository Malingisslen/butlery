/**
 * The Vertex host the real client calls must exist and stay in the EU.
 * `location: "eu"` once built `eu-aiplatform.googleapis.com`, a host Google
 * does not serve, and recipe-import AI calls failed without the app
 * showing it. This drives the library itself and reads the request it
 * would send.
 *
 * Run: npx ts-node src/__tests__/vertex-region.test.ts
 */

import { runTests, UnitCase, assertEqual } from "./_unit-runner";
import {
  captureRequests,
  requestTheModelSends,
  stubGeminiAuth,
} from "./_gemini-test-seams";
import {
  getGeminiClient,
  getTextModel,
  getVisionClient,
  getVisionModel,
  TEXT_MODEL,
  VERTEX_LOCATION,
  VISION_MODEL,
} from "../llm/gemini-client";
import { createVertexClient, euHostFor } from "../llm/gemini-sdk";

const PROJECT = "vertex-region-test";

// Environment the library reads that could move a call out of the EU,
// to an API-key backend, or to another base URL.
const HOSTILE_ENV: Record<string, string> = {
  GOOGLE_API_KEY: "hostile-key",
  GEMINI_API_KEY: "hostile-key",
  GOOGLE_GENAI_USE_VERTEXAI: "false",
  GOOGLE_CLOUD_LOCATION: "global",
  GOOGLE_VERTEX_BASE_URL: "https://attacker.example/",
  GOOGLE_GEMINI_BASE_URL: "https://attacker.example/",
  GOOGLE_GENAI_API_VERSION: "v1beta1",
};

async function withEnv<T>(
  env: Record<string, string>,
  fn: () => Promise<T>,
): Promise<T> {
  const saved: Record<string, string | undefined> = {};
  for (const [k, v] of Object.entries(env)) {
    saved[k] = process.env[k];
    process.env[k] = v;
  }
  try {
    return await fn();
  } finally {
    for (const [k, v] of Object.entries(saved)) {
      if (v === undefined) delete process.env[k];
      else process.env[k] = v;
    }
  }
}

const cases: UnitCase[] = [
  {
    name: "the text client calls europe-west4 on the v1 API",
    fn: async () => {
      process.env.GOOGLE_CLOUD_PROJECT = PROJECT;
      const { url, body } = await requestTheModelSends(
        getGeminiClient(),
        getTextModel,
      );
      // Pinned to the region both privacy policies name for Vertex AI, so the
      // two change together.
      assertEqual(
        url.host,
        "europe-west4-aiplatform.googleapis.com",
        `host for location ${VERTEX_LOCATION}`,
      );
      assertEqual(
        url.pathname,
        `/v1/projects/${PROJECT}/locations/europe-west4/publishers/google/models/${TEXT_MODEL}:generateContent`,
        "text path",
      );
      const generationConfig = body.generationConfig as Record<string, unknown>;
      assertEqual(generationConfig.thinkingConfig, undefined, "no thinking on text");
    },
  },
  {
    name: "the photo client calls the EU multi-region host with minimal thinking",
    fn: async () => {
      process.env.GOOGLE_CLOUD_PROJECT = PROJECT;
      const { url, body } = await requestTheModelSends(
        getVisionClient(),
        getVisionModel,
      );
      // The privacy policies name Google's EU multi-region for photos.
      assertEqual(url.host, "aiplatform.eu.rep.googleapis.com", "photo host");
      assertEqual(
        url.pathname,
        `/v1/projects/${PROJECT}/locations/eu/publishers/google/models/${VISION_MODEL}:generateContent`,
        "photo path",
      );
      const generationConfig = body.generationConfig as
        | { thinkingConfig?: { thinkingLevel?: unknown } }
        | undefined;
      assertEqual(
        generationConfig?.thinkingConfig?.thinkingLevel,
        "MINIMAL",
        "thinkingLevel in the request body",
      );
    },
  },
  {
    name: "a call's system prompt rides along without replacing the model's schema",
    fn: async () => {
      process.env.GOOGLE_CLOUD_PROJECT = PROJECT;
      const { body } = await requestTheModelSends(
        getGeminiClient(),
        getTextModel,
        "SYSTEM-PROMPT",
      );
      const system = body.systemInstruction as
        | { parts?: Array<{ text?: string }> }
        | undefined;
      assertEqual(system?.parts?.[0]?.text, "SYSTEM-PROMPT", "systemInstruction");
      const cfg = body.generationConfig as Record<string, unknown>;
      assertEqual(cfg.responseMimeType, "application/json", "responseMimeType");
      assertEqual(cfg.responseSchema !== undefined, true, "responseSchema");
      assertEqual(cfg.maxOutputTokens, 2000, "maxOutputTokens");
      assertEqual(cfg.temperature, 0.3, "temperature");
    },
  },
  {
    name: "a hostile environment cannot move either client or switch to an API key",
    fn: async () => {
      await withEnv(HOSTILE_ENV, async () => {
        // New project ids so both clients are built under this environment.
        process.env.GOOGLE_CLOUD_PROJECT = "vertex-region-hostile";
        const text = await requestTheModelSends(getGeminiClient(), getTextModel);
        const photo = await requestTheModelSends(getVisionClient(), getVisionModel);
        assertEqual(text.url.host, "europe-west4-aiplatform.googleapis.com", "text host");
        assertEqual(photo.url.host, "aiplatform.eu.rep.googleapis.com", "photo host");
        assertEqual(text.url.pathname.startsWith("/v1/projects/vertex-region-hostile/"), true, text.url.pathname);
        assertEqual(photo.url.pathname.startsWith("/v1/projects/vertex-region-hostile/"), true, photo.url.pathname);
        assertEqual(text.url.pathname.includes("/locations/europe-west4/"), true, text.url.pathname);
        assertEqual(photo.url.pathname.includes("/locations/eu/"), true, photo.url.pathname);
        for (const r of [text, photo]) {
          assertEqual(r.headers.get("x-goog-api-key"), null, "no API key header");
          assertEqual(r.headers.get("authorization"), "Bearer test-token", "service-account bearer");
        }
      });
    },
  },
  {
    name: "a location outside the EU allowlist is refused before any client exists",
    fn: async () => {
      for (const location of ["global", "us", "us-central1", "europe-west1", ""]) {
        let threw = false;
        try {
          euHostFor(location);
        } catch {
          threw = true;
        }
        assertEqual(threw, true, `euHostFor(${JSON.stringify(location)})`);
        threw = false;
        try {
          createVertexClient(PROJECT, location);
        } catch {
          threw = true;
        }
        assertEqual(threw, true, `createVertexClient(${JSON.stringify(location)})`);
      }
    },
  },
  {
    name: "a 429 or 503 answer is sent once, never retried by the library",
    fn: async () => {
      process.env.GOOGLE_CLOUD_PROJECT = PROJECT;
      for (const status of [429, 503]) {
        const client = getGeminiClient();
        stubGeminiAuth(client);
        const sent = await captureRequests(
          () =>
            getTextModel(client).generateContent({
              contents: [{ role: "user", parts: [{ text: "hej" }] }],
            }),
          () =>
            new Response(JSON.stringify({ error: { code: status, message: "busy" } }), {
              status,
              headers: { "content-type": "application/json" },
            }),
        );
        assertEqual(sent.length, 1, `requests for a ${status}`);
      }
    },
  },
];

runTests("vertex-region", cases);
