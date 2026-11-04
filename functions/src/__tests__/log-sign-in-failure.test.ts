/**
 * BUT-2502: logSignInFailure takes no personal data. Every field is a closed
 * list or a short code, so an address or a sentence is refused.
 *
 * Run with: npx ts-node src/__tests__/log-sign-in-failure.test.ts
 */

import {
  logSignInFailure,
  validateSignInFailure,
} from "../events/log-sign-in-failure";
import { assertEqual, runTests, UnitCase } from "./_unit-runner";

const valid = {
  provider: "google",
  stage: "signIn",
  platform: "android",
  code: "internal-error",
};

// firebase-functions/logger writes to stdout/stderr, not console.*.
async function runCapturing(data: unknown): Promise<{ lines: string; err: unknown }> {
  let lines = "";
  const out = process.stdout.write.bind(process.stdout);
  const errw = process.stderr.write.bind(process.stderr);
  const capture = (chunk: unknown): boolean => {
    lines += String(chunk);
    return true;
  };
  process.stdout.write = capture as typeof process.stdout.write;
  process.stderr.write = capture as typeof process.stderr.write;
  let err: unknown = null;
  try {
    await logSignInFailure.run({
      data,
      rawRequest: {},
    } as unknown as Parameters<typeof logSignInFailure.run>[0]);
  } catch (e) {
    err = e;
  } finally {
    process.stdout.write = out;
    process.stderr.write = errw;
  }
  return { lines, err };
}

function reason(data: Record<string, unknown>): string {
  const r = validateSignInFailure(data);
  return r.kind === "invalid" ? r.reason : "log";
}

const cases: UnitCase[] = [
  {
    name: "keeps a valid report as it is",
    fn: async () => {
      const r = validateSignInFailure(valid);
      if (r.kind !== "log") throw new Error("expected log");
      assertEqual(r.payload.provider, "google", "provider");
      assertEqual(r.payload.stage, "signIn", "stage");
      assertEqual(r.payload.platform, "android", "platform");
      assertEqual(r.payload.code, "internal-error", "code");
    },
  },
  {
    name: "accepts the app's own prefixed codes",
    fn: async () => {
      assertEqual(reason({ ...valid, code: "sheet:google.unknownError" }), "log", "sheet");
      assertEqual(reason({ ...valid, code: "dart:TimeoutException" }), "log", "dart");
    },
  },
  {
    name: "refuses values outside the lists",
    fn: async () => {
      assertEqual(reason({ ...valid, provider: "facebook" }), "provider", "provider");
      assertEqual(reason({ ...valid, stage: "reauth" }), "stage", "stage");
      assertEqual(reason({ ...valid, platform: "windows" }), "platform", "platform");
      assertEqual(reason({ ...valid, provider: 1 }), "provider", "non-string");
    },
  },
  {
    name: "refuses a code that could carry personal data or free text",
    fn: async () => {
      assertEqual(reason({ ...valid, code: "malin@example.com" }), "code", "address");
      assertEqual(reason({ ...valid, code: "no user found" }), "code", "spaces");
      assertEqual(reason({ ...valid, code: "a".repeat(65) }), "code", "too long");
      assertEqual(reason({ ...valid, code: "" }), "code", "empty");
      assertEqual(reason({ ...valid, code: undefined }), "code", "missing");
    },
  },
  {
    name: "the handler logs the four checked fields and nothing the caller added",
    fn: async () => {
      const { lines, err } = await runCapturing({
        ...valid,
        extra: "malin@example.com",
      });
      assertEqual(err, null, "no error");
      const entry = JSON.parse(lines.trim().split("\n").pop() ?? "{}");
      const keys = Object.keys(entry)
        .filter((k) => !["severity", "message"].includes(k))
        .sort()
        .join(",");
      assertEqual(keys, "code,event,platform,provider,stage", "keys");
      assertEqual(lines.includes("malin@example.com"), false, "no address");
    },
  },
  {
    name: "the handler refuses an invalid report and logs nothing",
    fn: async () => {
      const { lines, err } = await runCapturing({ ...valid, code: "a b" });
      assertEqual((err as { code?: string })?.code, "invalid-argument", "code");
      assertEqual(lines, "", "nothing logged");
    },
  },
];

runTests("log-sign-in-failure", cases);
