/**
 * The Vertex host the real client calls must exist and stay in the EU.
 * `location: "eu"` once built `eu-aiplatform.googleapis.com`, a host Google
 * does not serve, and recipe-import AI calls failed without the app
 * showing it. This drives the SDK itself and reads the URL it would fetch.
 *
 * Run: npx ts-node src/__tests__/vertex-region.test.ts
 */

import type { GenerativeModel, VertexAI } from "@google-cloud/vertexai";
import { runTests, UnitCase, assertEqual } from "./_unit-runner";
import {
  getGeminiClient,
  getTextModel,
  getVisionClient,
  getVisionModel,
  VERTEX_LOCATION,
  VISION_MODEL,
} from "../llm/gemini-client";

interface CapturedRequest {
  url: URL;
  body: Record<string, unknown>;
}

async function requestTheClientSends(
  client: VertexAI,
  model: (client: VertexAI) => GenerativeModel,
): Promise<CapturedRequest> {
  (
    client as unknown as {
      googleAuth: { getAccessToken: () => Promise<string> };
    }
  ).googleAuth.getAccessToken = async () => "test-token";
  const realFetch = globalThis.fetch;
  let url = "";
  let body = "{}";
  globalThis.fetch = (async (input: unknown, init?: { body?: unknown }) => {
    url = String(input);
    body = String(init?.body ?? "{}");
    throw new Error("stop after capturing the request");
  }) as typeof fetch;
  try {
    await model(client)
      .generateContent("hej")
      .catch(() => undefined);
  } finally {
    globalThis.fetch = realFetch;
  }
  return { url: new URL(url), body: JSON.parse(body) };
}

const cases: UnitCase[] = [
  {
    name: "the client calls the europe-west4 host the privacy policy names",
    fn: async () => {
      process.env.GOOGLE_CLOUD_PROJECT = "vertex-region-test";
      const { url } = await requestTheClientSends(
        getGeminiClient(),
        getTextModel,
      );
      // Multi-region locations ("eu", "us") are served only on `aiplatform.<loc>.rep.googleapis.com`,
      // which the SDK does not build from `location`.
      // Pinned to the region both privacy policies name for Vertex AI, so the
      // two change together.
      assertEqual(
        url.host,
        "europe-west4-aiplatform.googleapis.com",
        `host for location ${VERTEX_LOCATION}`,
      );
    },
  },
  {
    name: "the photo client calls the EU multi-region host with minimal thinking",
    fn: async () => {
      process.env.GOOGLE_CLOUD_PROJECT = "vertex-region-test";
      const { url, body } = await requestTheClientSends(
        getVisionClient(),
        getVisionModel,
      );
      // The privacy policies name Google's EU multi-region for photos.
      assertEqual(url.host, "aiplatform.eu.rep.googleapis.com", "photo host");
      assertEqual(
        url.pathname.includes("/locations/eu/"),
        true,
        `photo path names locations/eu: ${url.pathname}`,
      );
      assertEqual(
        url.pathname.includes(`models/${VISION_MODEL}`),
        true,
        `photo path names the model: ${url.pathname}`,
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
];

runTests("vertex-region", cases);
