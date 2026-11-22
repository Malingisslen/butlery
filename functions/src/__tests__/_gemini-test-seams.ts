/**
 * Test seams for the Gemini library: fake credentials and a captured fetch,
 * so a test reads the real request the library builds without a network or
 * Google credentials.
 */

import type { GeminiClient, GeminiModel } from "../llm/gemini-sdk";

export interface CapturedRequest {
  url: URL;
  body: Record<string, unknown>;
  headers: Headers;
}

/** Replace the client's Google credentials with a fixed bearer token. */
export function stubGeminiAuth(client: GeminiClient): void {
  const auth = (
    client as unknown as {
      apiClient: {
        clientOptions: {
          auth: { googleAuth?: { getRequestHeaders: () => Promise<Headers> } };
        };
      };
    }
  ).apiClient.clientOptions.auth;
  if (!auth.googleAuth) {
    throw new Error("client has no service-account auth (API key mode?)");
  }
  auth.googleAuth.getRequestHeaders = async () =>
    new Headers({ Authorization: "Bearer test-token" });
}

/**
 * Run `call` with fetch replaced. `answer` decides each response; by default
 * the first request is captured and the call is stopped. Returns every
 * request the library sent.
 */
export async function captureRequests(
  call: () => Promise<unknown>,
  answer?: (n: number) => Response,
): Promise<CapturedRequest[]> {
  const realFetch = globalThis.fetch;
  const sent: CapturedRequest[] = [];
  globalThis.fetch = (async (input: unknown, init?: RequestInit) => {
    sent.push({
      url: new URL(String(input)),
      body: JSON.parse(String(init?.body ?? "{}")),
      headers: new Headers(init?.headers),
    });
    if (!answer) throw new Error("stop after capturing the request");
    return answer(sent.length);
  }) as typeof fetch;
  try {
    await call().catch(() => undefined);
  } finally {
    globalThis.fetch = realFetch;
  }
  return sent;
}

/** The first request a model sends for a one-line prompt. */
export async function requestTheModelSends(
  client: GeminiClient,
  model: (client: GeminiClient) => GeminiModel,
  systemInstruction?: string,
): Promise<CapturedRequest> {
  stubGeminiAuth(client);
  const [first] = await captureRequests(() =>
    model(client).generateContent({
      contents: [{ role: "user", parts: [{ text: "hej" }] }],
      systemInstruction,
    }),
  );
  if (!first) throw new Error("the model sent no request");
  return first;
}
