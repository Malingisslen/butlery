/**
 * Parser shadow comparison (Track B, ADR-0037) — unit tests for
 * `runShadowCompareImport`.
 *
 * Every Firestore touch is a dep, so each case can prove what was NOT called:
 * at rate 0, with no config or an unreadable one, nothing reaches the AI and
 * nothing is written. The capture case runs the real `captureLlmSample`
 * against an in-memory db to prove exactly one `mode: 'shadow'` row lands,
 * with no image.
 *
 * Run: npx ts-node src/__tests__/shadow-compare-import.test.ts
 */

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-shadow-compare" });
}

import { runTests, assertEqual, UnitCase } from "./_unit-runner";
import {
  runShadowCompareImport,
  normalizeParserOutput,
  ShadowCompareDeps,
  ShadowConfig,
  SHADOW_OPERATION,
  BUDGET_RESERVE_USD,
  hasAiConsentIn,
} from "../llm/shadow-compare-import";
import {
  captureLlmSample,
  LlmSampleInput,
  resetSampleCaptureCacheForTest,
} from "../llm/llm-sample-capture";
import * as sampleCapture from "../llm/llm-sample-capture";
import * as geminiClient from "../llm/gemini-client";
import { runStructureRecipe } from "../llm/structure-recipe";
import type { GenerativeModel, VertexAI } from "@google-cloud/vertexai";
import type { CallableRequest } from "firebase-functions/v2/https";
import type { RunStructureRecipeDeps } from "../llm/structure-recipe";

type Auth = CallableRequest["auth"];

const USER: Auth = {
  uid: "user-1",
  token: { firebase: { sign_in_provider: "password" } },
} as unknown as Auth;
const GUEST: Auth = {
  uid: "guest-1",
  token: { firebase: { sign_in_provider: "anonymous" } },
} as unknown as Auth;

const TEXT = "Pannkakor\n3 dl vetemjöl\n6 dl mjölk\n3 ägg\nVispa ihop och stek.";
const PARSER_OUTPUT = {
  title: "Pannkakor",
  portions: "4",
  ingredients: [
    { name: "vetemjöl", originalLine: "3 dl vetemjöl", quantity: "3", unit: "dl" },
    { name: "mjölk", originalLine: "6 dl mjölk", quantity: "6", unit: "dl" },
  ],
  instructions: ["Vispa ihop och stek."],
};
const PAYLOAD = {
  text: TEXT,
  parserOutput: PARSER_OUTPUT,
  channel: "text",
  successfulTier: "rules",
  parserVersion: "2026.10",
};
const ON: ShadowConfig = { parserShadowRate: 1, parserShadowDailyUsd: 1 };

interface Calls {
  consent: number;
  config: number;
  rateLimit: string[];
  reserve: Array<{ day: string; limit: number; reserve: number }>;
  spend: number[];
  structure: Array<{ text: string; mode?: string; deps: RunStructureRecipeDeps }>;
  capture: LlmSampleInput[];
}

function harness(over: Partial<ShadowCompareDeps> & { config?: ShadowConfig | undefined | "throw" } = {}) {
  const calls: Calls = {
    consent: 0, config: 0, rateLimit: [], reserve: [], spend: [], structure: [], capture: [],
  };
  const config = "config" in over ? over.config : ON;
  const deps: ShadowCompareDeps = {
    hasAiConsent: async () => { calls.consent++; return true; },
    loadConfig: async () => {
      calls.config++;
      if (config === "throw") throw new Error("firestore down");
      return config;
    },
    random: () => 0,
    now: () => new Date("2026-10-29T12:00:00Z"),
    checkRateLimit: async (_uid, op) => { calls.rateLimit.push(op); return { allowed: true, remainingTokens: 1 }; },
    reserveBudget: async (day, limit, reserve) => { calls.reserve.push({ day, limit, reserve }); return true; },
    recordSpend: async (_day, delta) => { calls.spend.push(delta); },
    structure: async (req, _hash, deps) => {
      calls.structure.push({ text: req.text, mode: req.mode, deps });
      return {
        success: true,
        recipe: { title: "Pannkakor", ingredients: [], instructions: [] } as never,
        estimatedCost: 0.004,
        promptVersion: "v9",
        modelId: "gemini-test",
      };
    },
    capture: async (s) => { calls.capture.push(s); },
    ...over,
  };
  return { calls, deps };
}

/** Nothing reached the AI and nothing was written. */
function assertNoSpend(calls: Calls, msg: string): void {
  assertEqual(calls.rateLimit.length, 0, `${msg}: rate-limit bucket untouched`);
  assertEqual(calls.reserve.length, 0, `${msg}: no budget reservation`);
  assertEqual(calls.structure.length, 0, `${msg}: no AI call`);
  assertEqual(calls.spend.length, 0, `${msg}: no spend recorded`);
  assertEqual(calls.capture.length, 0, `${msg}: no sample`);
}

/** In-memory stand-in for the two paths `captureLlmSample` touches. */
function fakeCaptureDb() {
  const added: Array<Record<string, unknown>> = [];
  const db = {
    doc: () => ({ get: async () => ({ exists: false, data: () => undefined }) }),
    collection: (name: string) => ({
      add: async (data: Record<string, unknown>) => { added.push({ __collection: name, ...data }); },
    }),
  } as unknown as admin.firestore.Firestore;
  return { db, added };
}

const cases: UnitCase[] = [
  {
    name: "rate 0: nothing reaches the AI and nothing is written",
    fn: async () => {
      const { calls, deps } = harness({ config: { parserShadowRate: 0, parserShadowDailyUsd: 1 } });
      const r = await runShadowCompareImport(PAYLOAD, USER, deps);
      assertEqual(r.sampled, false, "not sampled");
      assertEqual(r.reason, "rate_off", "reason");
      assertNoSpend(calls, "rate 0");
    },
  },
  {
    name: "missing system/config fails closed",
    fn: async () => {
      const { calls, deps } = harness({ config: undefined });
      const r = await runShadowCompareImport(PAYLOAD, USER, deps);
      assertEqual(r.reason, "no_config", "reason");
      assertNoSpend(calls, "no config");
    },
  },
  {
    name: "a config read error fails closed and does not throw",
    fn: async () => {
      const { calls, deps } = harness({ config: "throw" });
      const r = await runShadowCompareImport(PAYLOAD, USER, deps);
      assertEqual(r.sampled, false, "not sampled");
      assertEqual(r.reason, "error", "reason");
      assertNoSpend(calls, "read error");
    },
  },
  {
    name: "kill switch and capture switch each stop the call",
    fn: async () => {
      for (const [config, reason] of [
        [{ ...ON, aiEnabled: false }, "kill_switch"],
        [{ ...ON, llmParserEnabled: false }, "kill_switch"],
        [{ ...ON, llmSampleCaptureEnabled: false }, "capture_disabled"],
      ] as Array<[ShadowConfig, string]>) {
        const { calls, deps } = harness({ config });
        const r = await runShadowCompareImport(PAYLOAD, USER, deps);
        assertEqual(r.reason, reason, `reason for ${JSON.stringify(config)}`);
        assertNoSpend(calls, reason);
      }
    },
  },
  {
    name: "a missed draw writes nothing",
    fn: async () => {
      const { calls, deps } = harness({ config: { parserShadowRate: 0.1, parserShadowDailyUsd: 1 }, random: () => 0.5 });
      const r = await runShadowCompareImport(PAYLOAD, USER, deps);
      assertEqual(r.reason, "not_drawn", "reason");
      assertNoSpend(calls, "not drawn");
    },
  },
  {
    name: "budget 0 or spent: no AI call",
    fn: async () => {
      const off = harness({ config: { parserShadowRate: 1, parserShadowDailyUsd: 0 } });
      assertEqual((await runShadowCompareImport(PAYLOAD, USER, off.deps)).reason, "budget_off", "budget 0");
      assertEqual(off.calls.structure.length, 0, "budget 0: no AI call");
      assertEqual(off.calls.reserve.length, 0, "budget 0: no reservation");

      const spent = harness({ reserveBudget: async () => false });
      assertEqual((await runShadowCompareImport(PAYLOAD, USER, spent.deps)).reason, "budget_spent", "spent");
      assertEqual(spent.calls.structure.length, 0, "spent: no AI call");
      assertEqual(spent.calls.capture.length, 0, "spent: no sample");
    },
  },
  {
    name: "anonymous and signed-out callers are rejected before any read",
    fn: async () => {
      const guest = harness();
      assertEqual((await runShadowCompareImport(PAYLOAD, GUEST, guest.deps)).reason, "anonymous", "guest");
      assertEqual(guest.calls.consent + guest.calls.config, 0, "guest: no reads");
      assertNoSpend(guest.calls, "guest");

      const none = harness();
      assertEqual((await runShadowCompareImport(PAYLOAD, undefined, none.deps)).reason, "unauthenticated", "no auth");
      assertNoSpend(none.calls, "no auth");
    },
  },
  {
    name: "no AI consent: nothing is sampled",
    fn: async () => {
      const { calls, deps } = harness({ hasAiConsent: async () => false });
      const r = await runShadowCompareImport(PAYLOAD, USER, deps);
      assertEqual(r.reason, "no_consent", "reason");
      assertEqual(calls.config, 0, "config not read without consent");
      assertNoSpend(calls, "no consent");
    },
  },
  {
    name: "oversized or malformed parserOutput is rejected before any read",
    fn: async () => {
      const huge = { ...PARSER_OUTPUT, instructions: Array.from({ length: 30 }, () => "x".repeat(2500)) };
      const bad = [
        huge,
        { ...PARSER_OUTPUT, ingredients: "not a list" },
        { ...PARSER_OUTPUT, ingredients: [{ name: "salt" }] },
        { ...PARSER_OUTPUT, portions: 4 },
        { ...PARSER_OUTPUT, timeMinutes: -1 },
        null,
      ];
      for (const parserOutput of bad) {
        const { calls, deps } = harness();
        const r = await runShadowCompareImport({ ...PAYLOAD, parserOutput }, USER, deps);
        assertEqual(r.reason, "invalid_parser_output", "reason");
        assertEqual(calls.consent, 0, "no consent read");
        assertNoSpend(calls, "bad parser output");
      }
    },
  },
  {
    name: "bad text, channel, labels or flag are rejected",
    fn: async () => {
      const bad: Array<[Record<string, unknown>, string]> = [
        [{ text: "kort" }, "invalid_text"],
        [{ text: "x".repeat(50_001) }, "invalid_text"],
        [{ channel: "voice" }, "invalid_channel"],
        [{ channel: "file" }, "invalid_channel"],
        [{ successfulTier: "has spaces and ü" }, "invalid_label"],
        [{ photoAiFallback: "yes" }, "invalid_flag"],
      ];
      for (const [over, reason] of bad) {
        const { calls, deps } = harness();
        const r = await runShadowCompareImport({ ...PAYLOAD, ...over }, USER, deps);
        assertEqual(r.reason, reason, `reason for ${Object.keys(over)[0]}`);
        assertNoSpend(calls, reason);
      }
    },
  },
  {
    name: "normalizeParserOutput drops unknown keys and scrubs strings",
    fn: async () => {
      const out = normalizeParserOutput({
        ...PARSER_OUTPUT,
        title: "Mormors pannkakor anna@example.com",
        sneaky: "raw uid",
        ingredients: [{ name: "mjölk", originalLine: "6 dl mjölk", extra: 1 }],
      });
      assertEqual(out !== null, true, "accepted");
      assertEqual(JSON.stringify(out).includes("sneaky"), false, "unknown top-level key dropped");
      assertEqual(JSON.stringify(out).includes("extra"), false, "unknown ingredient key dropped");
      assertEqual(out!.title.includes("anna@example.com"), false, "email scrubbed");
    },
  },
  {
    name: "a drawn sample: own bucket, own budget, one AI call with capture suppressed",
    fn: async () => {
      const { calls, deps } = harness();
      const r = await runShadowCompareImport({ ...PAYLOAD, photoAiFallback: true }, USER, deps);
      assertEqual(r.sampled, true, "sampled");
      assertEqual(calls.rateLimit.join(","), SHADOW_OPERATION, "own rate-limit bucket");
      assertEqual(calls.reserve.length, 1, "one reservation");
      assertEqual(calls.reserve[0].day, "2026-10-29", "UTC day key");
      assertEqual(calls.reserve[0].limit, 1, "limit from parserShadowDailyUsd");
      assertEqual(calls.reserve[0].reserve, BUDGET_RESERVE_USD, "reserve");
      assertEqual(calls.structure.length, 1, "one AI call");
      assertEqual(calls.structure[0].mode, "extract", "extract mode");
      assertEqual(calls.structure[0].deps.suppressSampleCapture, true, "core capture suppressed");
      assertEqual(calls.spend.length, 1, "spend recorded once");
      assertEqual(Math.abs(calls.spend[0] - (0.004 - BUDGET_RESERVE_USD)) < 1e-12, true, "spend = cost - reserve");
      assertEqual(calls.capture.length, 1, "one sample");
      const s = calls.capture[0];
      assertEqual(s.mode, "shadow", "mode");
      assertEqual(s.inputKind, "text", "no image input");
      assertEqual(s.channel, "text", "channel");
      assertEqual(s.photoAiFallback, true, "fallback flag");
      assertEqual(s.authUidHash !== "user-1", true, "uid hashed");
    },
  },
  {
    name: "a spent rate-limit bucket stops the call before the budget",
    fn: async () => {
      const { calls, deps } = harness({
        checkRateLimit: async () => ({ allowed: false, remainingTokens: 0 }),
      });
      const r = await runShadowCompareImport(PAYLOAD, USER, deps);
      assertEqual(r.reason, "rate_limited", "reason");
      assertEqual(calls.reserve.length, 0, "no reservation");
      assertEqual(calls.structure.length, 0, "no AI call");
      assertEqual(calls.capture.length, 0, "no sample");
    },
  },
  {
    name: "consent counts only when aiProcessing is exactly true",
    fn: async () => {
      const consentDb = (doc: Record<string, unknown> | undefined) => ({
        doc: (path: string) => {
          assertEqual(path, "users/user-1/consent/current", "consent path");
          return {
            get: async () => ({
              exists: doc !== undefined,
              get: (field: string) => doc?.[field],
            }),
          };
        },
      }) as unknown as admin.firestore.Firestore;
      assertEqual(await hasAiConsentIn(consentDb({ purposes: { aiProcessing: true } }), "user-1"), true, "true");
      assertEqual(await hasAiConsentIn(consentDb({ purposes: { aiProcessing: "yes" } }), "user-1"), false, "truthy string");
      assertEqual(await hasAiConsentIn(consentDb({ purposes: { aiProcessing: false } }), "user-1"), false, "false");
      assertEqual(await hasAiConsentIn(consentDb({ purposes: {} }), "user-1"), false, "field missing");
      assertEqual(await hasAiConsentIn(consentDb({}), "user-1"), false, "purposes missing");
      assertEqual(await hasAiConsentIn(consentDb(undefined), "user-1"), false, "no consent doc");
    },
  },
  {
    name: "runStructureRecipe writes its own sample unless suppressSampleCapture is set",
    fn: async () => {
      // The CJS emit resolves these exports through the module object at call
      // time, as in gemini-cache-telemetry.test.ts.
      const mutableClient = geminiClient as {
        getGeminiClient: () => VertexAI;
        getTextModel: (client: VertexAI) => GenerativeModel;
      };
      const mutableCapture = sampleCapture as { captureLlmSample: typeof captureLlmSample };
      const originals = {
        getGeminiClient: mutableClient.getGeminiClient,
        getTextModel: mutableClient.getTextModel,
        captureLlmSample: mutableCapture.captureLlmSample,
      };
      const recipeJson = JSON.stringify({
        title: "Pannkakor",
        portions: 4,
        ingredients: [{ amount: 3, unit: "dl", name: "mjölk", preparation: null }],
        instructions: ["Vispa ihop allt.", "Stek i smör."],
        tags: [],
      });
      let captured = 0;
      try {
        mutableClient.getGeminiClient = () => ({} as unknown as VertexAI);
        mutableClient.getTextModel = () => ({
          generateContent: async () => ({
            response: {
              candidates: [{ content: { role: "model", parts: [{ text: recipeJson }] } }],
              usageMetadata: { promptTokenCount: 100, candidatesTokenCount: 50 },
            },
          }),
        } as unknown as GenerativeModel);
        mutableCapture.captureLlmSample = async () => { captured++; };
        const run = (suppressSampleCapture?: boolean) => runStructureRecipe(
          { text: "Pannkakor: 3 dl mjölk. Vispa ihop allt. Stek i smör.", mode: "extract" },
          "uid-hash",
          {
            loadKillSwitch: async () => ({ aiEnabled: true, llmParserEnabled: true }),
            suppressSampleCapture,
          },
        );
        assertEqual((await run()).success, true, "plain call succeeds");
        assertEqual(captured, 1, "a plain call writes its sample");
        assertEqual((await run(true)).success, true, "suppressed call succeeds");
        assertEqual(captured, 1, "a suppressed call writes none");
      } finally {
        mutableClient.getGeminiClient = originals.getGeminiClient;
        mutableClient.getTextModel = originals.getTextModel;
        mutableCapture.captureLlmSample = originals.captureLlmSample;
      }
    },
  },
  {
    name: "AI error keeps the reservation and writes no sample",
    fn: async () => {
      const { calls, deps } = harness({ structure: async () => { throw new Error("vertex 500"); } });
      const r = await runShadowCompareImport(PAYLOAD, USER, deps);
      assertEqual(r.reason, "ai_error", "reason");
      assertEqual(calls.reserve.length, 1, "reserved");
      assertEqual(calls.spend.length, 0, "no further spend");
      assertEqual(calls.capture.length, 0, "no sample");
    },
  },
  {
    name: "never throws, whatever a dep does",
    fn: async () => {
      const boom = async () => { throw new Error("boom"); };
      for (const over of [
        { hasAiConsent: boom },
        { checkRateLimit: boom },
        { reserveBudget: boom },
        { recordSpend: boom },
        { capture: boom },
      ] as Array<Partial<ShadowCompareDeps>>) {
        const { deps } = harness(over);
        const r = await runShadowCompareImport(PAYLOAD, USER, deps);
        assertEqual(r.sampled, false, `not sampled for ${Object.keys(over)[0]}`);
      }
      const r = await runShadowCompareImport(undefined, USER, harness().deps);
      assertEqual(r.reason, "invalid_text", "undefined payload");
    },
  },
  {
    name: "the real capture writes exactly one mode 'shadow' row with no image",
    fn: async () => {
      resetSampleCaptureCacheForTest();
      const { db, added } = fakeCaptureDb();
      const { deps } = harness({ capture: (s) => captureLlmSample(s, db) });
      const r = await runShadowCompareImport(PAYLOAD, USER, deps);
      assertEqual(r.sampled, true, "sampled");
      assertEqual(added.length, 1, "exactly one row");
      const row = added[0];
      assertEqual(row.mode, "shadow", "mode");
      assertEqual(row.inputKind, "text", "text input");
      assertEqual(typeof row.scrubbedInput, "string", "scrubbed text stored");
      assertEqual(row.channel, "text", "channel stored");
      assertEqual((row.parserOutput as { title: string }).title, "Pannkakor", "parser output stored");
      assertEqual(Object.keys(row).some((k) => /image/i.test(k)), false, "no image field");
      resetSampleCaptureCacheForTest();
    },
  },
];

runTests("shadow-compare-import", cases);
