/**
 * Parser shadow comparison (Track B of the parser shadow plan, ADR-0037).
 *
 * After a successful import the app may send the same input plus its own
 * parse. This callable asks the AI for a reference parse and stores both side
 * by side as ONE `llm_samples` row with `mode: 'shadow'`, so the free parser
 * can be scored against the AI offline.
 *
 * It fails CLOSED at every step — a missing or unreadable config means no
 * sample — and never throws to the client: the import has already finished,
 * so nothing here may become a failure the user sees. Spend goes to its own
 * bucket and its own daily USD counter (`system/shadowBudget_{UTC day}`
 * against `parserShadowDailyUsd`), never to `llm_cost`, the global caps or
 * the guest import quota, so sampling can never eat a user's real allowance.
 */
import * as admin from "firebase-admin";
import { onCall, CallableRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import {
  runStructureRecipe,
  RunStructureRecipeDeps,
  StructureRecipeRequest,
  StructureRecipeResponse,
} from "./structure-recipe";
import { captureLlmSample, LlmSampleInput } from "./llm-sample-capture";
import { scrubPii } from "./pii-scrubber";
import { isGuestRequest } from "./guest-import-quota";
import { checkRateLimit, RateLimitCheckResult } from "../middleware/rate_limiter";
import { hashUid } from "../shared/hash-uid";
import { hasAiConsentIn } from "./ai-consent";
import { WEB_CALLABLE_ORIGINS } from "../shared/web-origins";

export { hasAiConsentIn };

export const SHADOW_OPERATION = "shadowCompareImport";

const MIN_TEXT_CHARS = 20;
const MAX_TEXT_CHARS = 50_000;
const MAX_PARSER_OUTPUT_JSON_CHARS = 60_000;
const MAX_INGREDIENTS = 150;
const MAX_INSTRUCTIONS = 100;
const MAX_TITLE_CHARS = 300;
const MAX_SHORT_FIELD_CHARS = 100;
const MAX_ORIGINAL_LINE_CHARS = 500;
const MAX_INSTRUCTION_CHARS = 3000;
const MAX_TIME_MINUTES = 7 * 24 * 60;
// The floor `calculateGeminiCost` charges for any call, so the reservation
// never under-counts a call that is actually made.
export const BUDGET_RESERVE_USD = 0.001;
const CHANNELS = new Set(["photo", "link", "text"]);
const LABEL = /^[A-Za-z0-9_.-]{1,40}$/;

/** Everything arrives as `unknown`: the client is not trusted on shape. */
export interface ShadowCompareRequest {
  text?: unknown;
  parserOutput?: unknown;
  channel?: unknown;
  successfulTier?: unknown;
  parserVersion?: unknown;
  photoAiFallback?: unknown;
}

export interface ShadowParserIngredient {
  name: string;
  originalLine: string;
  quantity?: string;
  unit?: string;
  size?: string;
  preparation?: string;
}

/** The corpus GoldRecipe shape (tools/corpus/corpus_models.dart), without `verified`. */
export interface ShadowParserOutput {
  title: string;
  portions?: string;
  timeMinutes?: number;
  ingredients: ShadowParserIngredient[];
  instructions: string[];
}

export interface ShadowCompareResult {
  sampled: boolean;
  reason: string;
}

export interface ShadowConfig {
  aiEnabled?: unknown;
  llmParserEnabled?: unknown;
  llmSampleCaptureEnabled?: unknown;
  parserShadowRate?: unknown;
  parserShadowDailyUsd?: unknown;
}

export interface ShadowCompareDeps {
  loadConfig?: () => Promise<ShadowConfig | undefined>;
  hasAiConsent?: (uid: string) => Promise<boolean>;
  random?: () => number;
  now?: () => Date;
  checkRateLimit?: (uid: string, op: string) => Promise<RateLimitCheckResult>;
  /** Reserves `reserveUsd` against the day's limit; false when it would exceed it. */
  reserveBudget?: (dayKey: string, limitUsd: number, reserveUsd: number) => Promise<boolean>;
  recordSpend?: (dayKey: string, deltaUsd: number) => Promise<void>;
  structure?: (
    req: StructureRecipeRequest,
    authUidHash: string,
    deps: RunStructureRecipeDeps
  ) => Promise<StructureRecipeResponse>;
  capture?: (sample: LlmSampleInput) => Promise<void>;
}

const budgetRef = (dayKey: string) =>
  admin.firestore().doc(`system/shadowBudget_${dayKey}`);

// Name and code only: a Firestore message can carry a document path, and
// these paths hold the raw uid.
function errorFields(e: unknown): { errName?: string; errCode?: unknown } {
  return { errName: (e as Error)?.name, errCode: (e as { code?: unknown })?.code };
}

async function defaultLoadConfig(): Promise<ShadowConfig | undefined> {
  const doc = await admin.firestore().doc("system/config").get();
  return doc.exists ? (doc.data() as ShadowConfig) : undefined;
}

const defaultHasAiConsent = (uid: string) => hasAiConsentIn(admin.firestore(), uid);

async function defaultReserveBudget(
  dayKey: string,
  limitUsd: number,
  reserveUsd: number
): Promise<boolean> {
  const ref = budgetRef(dayKey);
  return admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const raw = snap.exists ? snap.get("spentUsd") : 0;
    const spent = typeof raw === "number" && Number.isFinite(raw) ? raw : 0;
    if (spent + reserveUsd > limitUsd) return false;
    tx.set(ref, { spentUsd: spent + reserveUsd }, { merge: true });
    return true;
  });
}

async function defaultRecordSpend(dayKey: string, deltaUsd: number): Promise<void> {
  if (deltaUsd <= 0) return;
  await budgetRef(dayKey).set(
    { spentUsd: admin.firestore.FieldValue.increment(deltaUsd) },
    { merge: true }
  );
}

const isPlainObject = (v: unknown): v is Record<string, unknown> =>
  typeof v === "object" && v !== null && !Array.isArray(v);

function cleanString(v: unknown, max: number, allowEmpty = false): string | null {
  if (typeof v !== "string" || v.length > max) return null;
  if (!allowEmpty && v.trim().length === 0) return null;
  return scrubPii(v);
}

function optionalString(v: unknown, max: number): string | undefined | null {
  if (v === undefined || v === null) return undefined;
  return cleanString(v, max, true);
}

function optionalNumber(v: unknown, max: number): number | undefined | null {
  if (v === undefined || v === null) return undefined;
  if (typeof v !== "number" || !Number.isFinite(v) || v < 0 || v > max) return null;
  return v;
}

/**
 * Rebuilds the parser output from whitelisted keys only, scrubbing every
 * string. Returns null on ANY violation rather than repairing it: a sample
 * built from a half-trusted payload would score the wrong thing.
 */
export function normalizeParserOutput(raw: unknown): ShadowParserOutput | null {
  if (!isPlainObject(raw)) return null;
  let json: string;
  try {
    json = JSON.stringify(raw);
  } catch {
    return null;
  }
  if (json.length > MAX_PARSER_OUTPUT_JSON_CHARS) return null;

  const title = cleanString(raw.title, MAX_TITLE_CHARS, true);
  const portions = optionalString(raw.portions, MAX_SHORT_FIELD_CHARS);
  const timeMinutes = optionalNumber(raw.timeMinutes, MAX_TIME_MINUTES);
  if (title === null || portions === null || timeMinutes === null) return null;

  if (!Array.isArray(raw.ingredients) || raw.ingredients.length > MAX_INGREDIENTS) return null;
  if (!Array.isArray(raw.instructions) || raw.instructions.length > MAX_INSTRUCTIONS) return null;

  const ingredients: ShadowParserIngredient[] = [];
  for (const item of raw.ingredients) {
    if (!isPlainObject(item)) return null;
    const name = cleanString(item.name, MAX_TITLE_CHARS, true);
    const originalLine = cleanString(item.originalLine, MAX_ORIGINAL_LINE_CHARS, true);
    const quantity = optionalString(item.quantity, MAX_SHORT_FIELD_CHARS);
    const unit = optionalString(item.unit, MAX_SHORT_FIELD_CHARS);
    const size = optionalString(item.size, MAX_SHORT_FIELD_CHARS);
    const preparation = optionalString(item.preparation, MAX_TITLE_CHARS);
    if (
      name === null || originalLine === null || quantity === null ||
      unit === null || size === null || preparation === null
    ) {
      return null;
    }
    ingredients.push({
      name,
      originalLine,
      ...(quantity !== undefined ? { quantity } : {}),
      ...(unit !== undefined ? { unit } : {}),
      ...(size !== undefined ? { size } : {}),
      ...(preparation !== undefined ? { preparation } : {}),
    });
  }

  const instructions: string[] = [];
  for (const step of raw.instructions) {
    const clean = cleanString(step, MAX_INSTRUCTION_CHARS, true);
    if (clean === null) return null;
    instructions.push(clean);
  }

  return {
    title,
    ...(portions !== undefined ? { portions } : {}),
    ...(timeMinutes !== undefined ? { timeMinutes } : {}),
    ingredients,
    instructions,
  };
}

const optionalLabel = (v: unknown): string | undefined | null => {
  if (v === undefined || v === null) return undefined;
  return typeof v === "string" && LABEL.test(v) ? v : null;
};

const positiveNumber = (v: unknown): number | null =>
  typeof v === "number" && Number.isFinite(v) && v > 0 ? v : null;

const skip = (reason: string): ShadowCompareResult => ({ sampled: false, reason });

export async function runShadowCompareImport(
  data: ShadowCompareRequest | undefined,
  auth: CallableRequest["auth"],
  deps: ShadowCompareDeps = {}
): Promise<ShadowCompareResult> {
  try {
    const uid = auth?.uid;
    if (!uid) return skip("unauthenticated");
    if (isGuestRequest(auth)) return skip("anonymous");

    // Validation precedes every read, so a malformed call costs nothing.
    const text = data?.text;
    if (
      typeof text !== "string" ||
      text.trim().length < MIN_TEXT_CHARS ||
      text.length > MAX_TEXT_CHARS
    ) {
      return skip("invalid_text");
    }
    const parserOutput = normalizeParserOutput(data?.parserOutput);
    if (!parserOutput) return skip("invalid_parser_output");
    const channel = data?.channel;
    if (typeof channel !== "string" || !CHANNELS.has(channel)) return skip("invalid_channel");
    const successfulTier = optionalLabel(data?.successfulTier);
    const parserVersion = optionalLabel(data?.parserVersion);
    if (successfulTier === null || parserVersion === null) return skip("invalid_label");
    const photoAiFallback = data?.photoAiFallback;
    if (photoAiFallback !== undefined && photoAiFallback !== null && typeof photoAiFallback !== "boolean") {
      return skip("invalid_flag");
    }

    // ADR-0037: consent is read here, never taken from the client.
    if (!(await (deps.hasAiConsent ?? defaultHasAiConsent)(uid))) return skip("no_consent");

    const config = await (deps.loadConfig ?? defaultLoadConfig)();
    if (!config) return skip("no_config");
    if (config.aiEnabled === false || config.llmParserEnabled === false) return skip("kill_switch");
    if (config.llmSampleCaptureEnabled === false) return skip("capture_disabled");
    const rate = positiveNumber(config.parserShadowRate);
    if (rate === null || rate > 1) return skip("rate_off");
    if ((deps.random ?? Math.random)() >= rate) return skip("not_drawn");

    // After the draw on purpose: at rate 0 nothing is ever written.
    const limit = await (deps.checkRateLimit ?? checkRateLimit)(uid, SHADOW_OPERATION);
    if (!limit.allowed) return skip("rate_limited");

    const dailyUsd = positiveNumber(config.parserShadowDailyUsd);
    if (dailyUsd === null) return skip("budget_off");
    const dayKey = (deps.now ?? (() => new Date()))().toISOString().slice(0, 10);
    const reserved = await (deps.reserveBudget ?? defaultReserveBudget)(
      dayKey,
      dailyUsd,
      BUDGET_RESERVE_USD
    );
    if (!reserved) return skip("budget_spent");

    let response: StructureRecipeResponse;
    try {
      response = await (deps.structure ?? runStructureRecipe)(
        { text, mode: "extract" },
        hashUid(uid),
        // The config already read above IS the kill switch; reading it twice
        // could let the two disagree mid-call.
        { loadKillSwitch: async () => ({
          aiEnabled: config.aiEnabled as boolean | undefined,
          llmParserEnabled: config.llmParserEnabled as boolean | undefined,
        }), suppressSampleCapture: true }
      );
    } catch (e) {
      // The reservation is kept: a failed call may still have been billed.
      logger.warn("shadow_compare_import.ai_error", errorFields(e));
      return skip("ai_error");
    }

    const cost = typeof response.estimatedCost === "number" ? response.estimatedCost : 0;
    await (deps.recordSpend ?? defaultRecordSpend)(dayKey, Math.max(0, cost - BUDGET_RESERVE_USD));

    if (!response.success || !response.recipe) return skip("ai_no_recipe");

    await (deps.capture ?? captureLlmSample)({
      mode: "shadow",
      inputKind: "text",
      scrubbedInput: scrubPii(text),
      rawLlmResponse: JSON.stringify(response.recipe),
      promptVersion: response.promptVersion,
      authUidHash: hashUid(uid),
      modelId: response.modelId ?? "unknown",
      parserOutput: parserOutput as unknown as Record<string, unknown>,
      channel,
      successfulTier,
      parserVersion,
      ...(typeof photoAiFallback === "boolean" ? { photoAiFallback } : {}),
    });
    return { sampled: true, reason: "sampled" };
  } catch (e) {
    logger.warn("shadow_compare_import.error", errorFields(e));
    return skip("error");
  }
}

export const shadowCompareImport = onCall<ShadowCompareRequest>(
  {
    memory: "512MiB",
    timeoutSeconds: 60,
    cors: WEB_CALLABLE_ORIGINS,
    enforceAppCheck: true,
  },
  async (request) => {
    const result = await runShadowCompareImport(request.data, request.auth);
    logger.info("shadow_compare_import.complete", {
      event: "shadow_compare_import.complete",
      sampled: result.sampled,
      reason: result.reason,
    });
    return { sampled: result.sampled };
  }
);
