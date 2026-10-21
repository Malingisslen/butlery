/**
 * The Vertex host the real client calls must exist and stay in the EU.
 * `location: "eu"` once built `eu-aiplatform.googleapis.com`, a host Google
 * does not serve, and recipe-import AI calls failed without the app
 * showing it. This drives the SDK itself and reads the URL it would fetch.
 *
 * Run: npx ts-node src/__tests__/vertex-region.test.ts
 */

import { runTests, UnitCase, assertEqual } from "./_unit-runner";
import {
  getGeminiClient,
  getTextModel,
  VERTEX_LOCATION,
} from "../llm/gemini-client";

async function hostTheClientCalls(): Promise<string> {
  process.env.GOOGLE_CLOUD_PROJECT = "vertex-region-test";
  const client = getGeminiClient();
  (
    client as unknown as {
      googleAuth: { getAccessToken: () => Promise<string> };
    }
  ).googleAuth.getAccessToken = async () => "test-token";
  const realFetch = globalThis.fetch;
  let url = "";
  globalThis.fetch = (async (input: unknown) => {
    url = String(input);
    throw new Error("stop after capturing the URL");
  }) as typeof fetch;
  try {
    await getTextModel(client)
      .generateContent("hej")
      .catch(() => undefined);
  } finally {
    globalThis.fetch = realFetch;
  }
  return new URL(url).host;
}

const cases: UnitCase[] = [
  {
    name: "the client calls the europe-west1 host the privacy policy names",
    fn: async () => {
      const host = await hostTheClientCalls();
      // Multi-region locations ("eu", "us") are served only on `aiplatform.<loc>.rep.googleapis.com`,
      // which the SDK does not build from `location`.
      // Pinned to the region both privacy policies name for Vertex AI, so the
      // two change together.
      assertEqual(
        host,
        "europe-west1-aiplatform.googleapis.com",
        `host for location ${VERTEX_LOCATION}`,
      );
    },
  },
];

runTests("vertex-region", cases);
