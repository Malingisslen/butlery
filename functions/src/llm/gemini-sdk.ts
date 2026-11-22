/**
 * Wraps Google's Gemini library (`@google/genai`). The rest of
 * `functions/src` talks to Gemini through the types and helpers here, so a
 * future library change stays inside this file
 * (`git grep -l '@google/genai' -- functions/src` lists this file alone).
 *
 * Vertex AI only (service-account auth, no API key), and only EU hosts:
 * personal data in recipe text and photos must not leave the EU (GDPR
 * Chapter V; both privacy policies name these regions).
 */

import {
  ApiError,
  FinishReason,
  GoogleGenAI,
  ThinkingLevel,
  Type,
  type Content,
  type GenerateContentConfig,
  type GenerateContentResponse,
  type Part,
  type Schema,
} from "@google/genai";

export { FinishReason, ThinkingLevel, Type };
export type { Content, Part, Schema };

export type GeminiClient = GoogleGenAI;
export type GeminiResponse = GenerateContentResponse;

/** Model parameters fixed per model (schema, token cap, thinking). */
export type GeminiModelConfig = Pick<
  GenerateContentConfig,
  | "temperature"
  | "maxOutputTokens"
  | "responseMimeType"
  | "responseSchema"
  | "thinkingConfig"
>;

export interface GeminiRequest {
  contents: Content[];
  systemInstruction?: string;
}

export interface GeminiModel {
  readonly id: string;
  readonly config: GeminiModelConfig;
  generateContent(request: GeminiRequest): Promise<GeminiResponse>;
}

/**
 * Each EU location the server may call, with its host. The base URL is
 * always passed explicitly: without it the library may take one from
 * `GOOGLE_VERTEX_BASE_URL` or another module's process-wide default, and
 * an unset location falls back to `global`, which is not EU-pinned.
 */
const EU_HOSTS: Readonly<Record<string, string>> = {
  "europe-west4": "europe-west4-aiplatform.googleapis.com",
  eu: "aiplatform.eu.rep.googleapis.com",
};

/** Host for an EU location; throws for any other location. */
export function euHostFor(location: string): string {
  const host = EU_HOSTS[location];
  if (!host) {
    throw new Error(`Gemini location "${location}" is not an allowed EU location`);
  }
  return host;
}

/**
 * A Vertex AI client for one EU location. `project`, `location` and the
 * base URL are all explicit, which also makes the library drop any API key
 * found in the environment, so auth stays the function's service account.
 */
export function createVertexClient(project: string, location: string): GeminiClient {
  const host = euHostFor(location);
  return new GoogleGenAI({
    vertexai: true,
    project,
    location,
    // No retryOptions, so the library does not retry: retries belong to the
    // app (ADR-001).
    // v1, the stable API: the library's own default is the v1beta1 preview.
    httpOptions: { baseUrl: `https://${host}/`, apiVersion: "v1" },
  });
}

/**
 * A model id bound to its fixed parameters. A call adds only its contents
 * and system prompt; it cannot replace the schema or token cap.
 */
export function bindModel(
  client: GeminiClient,
  id: string,
  config: GeminiModelConfig,
): GeminiModel {
  return {
    id,
    config,
    generateContent: ({ contents, systemInstruction }) =>
      client.models.generateContent({
        model: id,
        contents,
        config:
          systemInstruction === undefined
            ? { ...config }
            : { ...config, systemInstruction },
      }),
  };
}

/** The HTTP status of a Gemini API error, or undefined for any other error. */
export function geminiErrorStatus(error: unknown): number | undefined {
  // Structural, not `instanceof ApiError`: two copies of the library in
  // node_modules would each have their own class.
  if (!(error instanceof Error)) return undefined;
  const status = (error as { status?: unknown }).status;
  return typeof status === "number" ? status : undefined;
}

/** Builds the error the library throws for a non-2xx answer (for tests). */
export function geminiApiError(status: number, message: string): Error {
  return new ApiError({ status, message });
}

function causeCode(error: Error): string | undefined {
  const code = (error as { cause?: { code?: unknown } }).cause?.code;
  return typeof code === "string" ? code : undefined;
}

/** What may be logged about an error: never the request. */
export function describeError(error: unknown): Record<string, unknown> {
  if (!(error instanceof Error)) return { errorType: typeof error };
  const status = geminiErrorStatus(error);
  return {
    errorName: error.name,
    errorStatus: status,
    errorMessage: error.message.slice(0, 500),
    // A network failure's reason ("ECONNRESET", "ENOTFOUND") is only here.
    errorCauseCode: causeCode(error),
    // A code bug needs its stack; an API error's stack is only the library's.
    errorStack: status === undefined ? error.stack : undefined,
  };
}
