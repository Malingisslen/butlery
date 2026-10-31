/**
 * The consent gate in front of `ocrRecipeImage` and `structureRecipe` (`llm/ai-consent.ts`): only a
 * caller whose stored consent says yes to AI processing reaches the handler.
 *
 * Run: npx ts-node src/__tests__/ai-consent.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import type { CallableRequest } from "firebase-functions/v2/https";
import { HttpsError } from "firebase-functions/v2/https";
import { runTests, UnitCase, assertEqual } from "./_unit-runner";
import { AI_CONSENT_REQUIRED, withAiConsent } from "../llm/ai-consent";

function request(uid: string | null): CallableRequest<unknown> {
  return {
    data: {},
    auth: uid === null ? undefined : { uid, token: {} },
    rawRequest: {},
  } as unknown as CallableRequest<unknown>;
}

async function outcome(
  uid: string | null,
  hasConsent: (uid: string) => Promise<boolean>
): Promise<{ reached: boolean; code?: string; reason?: unknown }> {
  let reached = false;
  const gated = withAiConsent(async () => {
    reached = true;
    return "ok";
  }, hasConsent);
  try {
    await gated(request(uid));
    return { reached };
  } catch (err) {
    const e = err as HttpsError;
    return { reached, code: e.code, reason: (e.details as { reason?: unknown } | undefined)?.reason };
  }
}

const cases: UnitCase[] = [
  {
    name: "consent given: the handler runs",
    fn: async () => {
      const o = await outcome("u1", async () => true);
      assertEqual(o.reached, true, "reached");
      assertEqual(o.code, undefined, "no error");
    },
  },
  {
    name: "no consent: refused before the handler, with the reason the app reads",
    fn: async () => {
      const o = await outcome("u1", async () => false);
      assertEqual(o.reached, false, "reached");
      assertEqual(o.code, "failed-precondition", "code");
      assertEqual(o.reason, AI_CONSENT_REQUIRED, "reason");
    },
  },
  {
    name: "a failed consent read refuses",
    fn: async () => {
      const o = await outcome("u1", async () => {
        throw new Error("unavailable");
      });
      assertEqual(o.reached, false, "reached");
      assertEqual(o.code, "unavailable", "code");
      assertEqual(o.reason, undefined, "reason");
    },
  },
  {
    name: "no signed-in caller: refused as unauthenticated",
    fn: async () => {
      const o = await outcome(null, async () => true);
      assertEqual(o.reached, false, "reached");
      assertEqual(o.code, "unauthenticated", "code");
    },
  },
  {
    name: "ocrRecipeImage and structureRecipe are wrapped in the gate outside the guest quota and rate limit",
    fn: async () => {
      for (const [file, op] of [
        ["ocr-recipe-image.ts", "ocrRecipeImage"],
        ["structure-recipe.ts", "structureRecipe"],
      ]) {
        const src = fs.readFileSync(path.resolve(__dirname, "../llm", file), "utf8");
        const wired = new RegExp(
          `withAiConsent\\(\\s*withGuestImportQuota\\(\\s*withRateLimit\\(\\s*"${op}"`,
        );
        assertEqual(wired.test(src), true, `${file}: wrapper order`);
      }
    },
  },
];

runTests("ai-consent", cases);
